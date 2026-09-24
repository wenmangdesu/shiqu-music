/**
 * 下载管理服务（基于 @ohos.request 的 request.agent 后台下载代理）
 * 特性：
 *  - 下载队列 + 最多3个并发任务
 *  - 暂停/继续（会话内使用系统级断点续传）、取消、重试
 *  - 进度/速度实时回调，状态持久化到数据库
 *  - 完成后自动解析元数据并加入本地音乐库
 */
import { request, BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';
import { promptAction } from '@kit.ArkUI';
import { DownloadTask } from '../model/DownloadTask';
import { Song } from '../model/Song';
import { C } from '../common/Constants';
import { DbService } from './DbService';
import { LibraryService } from './LibraryService';
import { OnlineService } from './OnlineService';
import { PrefsService } from './PrefsService';
import { MetaParser } from '../utils/MetaParser';
import { FmtUtil } from '../utils/FmtUtil';
import { Logger } from '../utils/Logger';

/** 下载状态变化监听 */
export interface IDlListener {
  onChange(type: string): void;
}

/** 速度统计辅助 */
class SpeedStat {
  lastReceived: number = 0;
  lastTime: number = 0;
}

export class DownloadService {
  private static inst?: DownloadService;

  static getInstance(): DownloadService {
    if (!DownloadService.inst) {
      DownloadService.inst = new DownloadService();
    }
    return DownloadService.inst;
  }

  /** 全部任务（含已完成，供UI直接读取） */
  tasks: DownloadTask[] = [];
  listener?: IDlListener;

  private ctx?: common.UIAbilityContext;
  private running: Map<number, request.agent.Task> = new Map();
  private startingIds: Set<number> = new Set();
  private stats: Map<number, SpeedStat> = new Map();
  private lastDbWrite: Map<number, number> = new Map();
  private maxConcurrent: number = C.MAX_CONCURRENT;

  async init(ctx: common.UIAbilityContext): Promise<void> {
    this.ctx = ctx;
    this.maxConcurrent = Math.max(1, Math.min(3, PrefsService.getInstance().getNum(C.P_CONCURRENCY, C.MAX_CONCURRENT)));
    try {
      MetaParser.ensureDir(`${ctx.filesDir}/${C.DL_DIR}`);
      MetaParser.ensureDir(`${ctx.cacheDir}/${C.DL_DIR}`);
      const saved: DownloadTask[] = await DbService.getInstance().queryTasks();
      // 应用重启后，系统代理任务不会自动恢复，进行中/等待中的任务置为"已暂停"
      saved.forEach((t: DownloadTask) => {
        if (t.status === C.ST_RUNNING || t.status === C.ST_PENDING) {
          t.status = C.ST_PAUSED;
          DbService.getInstance().updateTask(t).catch(() => {});
        }
        this.tasks.push(t);
      });
      this.notifyChange('task');
      this.pump();
    } catch (err) {
      const e = err as BusinessError;
      Logger.e('Download', `初始化失败: ${e.message}`);
    }
  }

  setListener(l: IDlListener): void {
    this.listener = l;
  }

  private notifyChange(type: string): void {
    this.listener?.onChange(type);
  }

  private statOf(id: number): SpeedStat {
    let s: SpeedStat | undefined = this.stats.get(id);
    if (!s) {
      s = new SpeedStat();
      this.stats.set(id, s);
    }
    return s;
  }

  private async updateTaskQuiet(t: DownloadTask): Promise<void> {
    try {
      await DbService.getInstance().updateTask(t);
    } catch (err) {
      // 持久化失败不影响任务
    }
  }

  /**
   * 新增下载任务
   * @param song 在线歌曲
   * @param quality 音质 standard/high/lossless
   */
  async addTask(song: Song, quality: string): Promise<boolean> {
    if (!this.ctx) {
      return false;
    }
    if (!song.filePath.startsWith('http')) {
      promptAction.showToast({ message: '该歌曲已是本地歌曲，无需下载', duration: 2000 });
      return false;
    }
    // 查重：同名歌曲同音质已在队列或已完成
    const dup: boolean = this.tasks.some((t: DownloadTask) =>
      t.title === song.title && t.quality === quality && t.status !== C.ST_FAILED);
    if (dup) {
      promptAction.showToast({ message: '该音质的任务已在下载列表中', duration: 2000 });
      return false;
    }
    const ext: string = quality === C.QUALITY_LOSSLESS ? 'flac' : 'mp3';
    const base: string = FmtUtil.sanitizeFileName(`${song.title} - ${song.artist}`);
    const url: string = OnlineService.getInstance().getDownloadUrl(song, quality);
    const t: DownloadTask = new DownloadTask();
    t.title = song.title;
    t.artist = song.artist;
    t.url = url;
    t.fileName = `${base}_${Date.now() % 100000}.${ext}`;
    t.filePath = `${this.ctx.filesDir}/${C.DL_DIR}/${t.fileName}`;
    t.status = C.ST_PENDING;
    t.quality = quality;
    t.createTime = Date.now();
    try {
      t.id = await DbService.getInstance().insertTask(t);
      this.tasks.unshift(t);
      this.notifyChange('task');
      this.pump();
      promptAction.showToast({ message: `已加入下载队列：${C.qualityLabel(quality)}`, duration: 2000 });
      return true;
    } catch (err) {
      const e = err as BusinessError;
      Logger.e('Download', `创建任务失败: ${e.message}`);
      promptAction.showToast({ message: '创建下载任务失败', duration: 2000 });
      return false;
    }
  }

  /** 按并发上限调度等待中的任务 */
  private pump(): void {
    for (let i = 0; i < this.tasks.length; i++) {
      const t: DownloadTask = this.tasks[i];
      if (this.running.size + this.startingIds.size >= this.maxConcurrent) {
        break;
      }
      if (t.status === C.ST_PENDING && !this.running.has(t.id) && !this.startingIds.has(t.id)) {
        this.startingIds.add(t.id);
        this.startTask(t);
      }
    }
  }

  private async startTask(t: DownloadTask): Promise<void> {
    if (!this.ctx) {
      this.startingIds.delete(t.id);
      return;
    }
    t.status = C.ST_RUNNING;
    this.updateTaskQuiet(t);
    this.notifyChange('task');
    const cfg: request.agent.Config = {
      action: request.agent.Action.DOWNLOAD,
      url: t.url,
      saveas: `${C.DL_DIR}/${t.fileName}`,
      method: 'GET',
      mode: request.agent.Mode.BACKGROUND,
      overwrite: true,
      network: request.agent.Network.ANY,
      title: t.title,
      description: '云悦音乐下载'
    };
    try {
      const agentTask: request.agent.Task = await request.agent.create(this.ctx, cfg);
      this.running.set(t.id, agentTask);
      this.startingIds.delete(t.id);
      const stat: SpeedStat = this.statOf(t.id);
      stat.lastReceived = t.received;
      stat.lastTime = Date.now();
      agentTask.on('progress', (p: request.agent.Progress) => {
        // sizes为各文件大小数组，单文件任务取sizes[0]
        const total: number = p.sizes.length > 0 ? p.sizes[0] : 0;
        this.onProgress(t, p.processed, total);
      });
      agentTask.on('completed', () => {
        this.onComplete(t);
      });
      agentTask.on('failed', (p: request.agent.Progress) => {
        this.onFailed(t, `state:${p.state}`);
      });
      await agentTask.start();
    } catch (err) {
      const e = err as BusinessError;
      Logger.e('Download', `启动任务失败: ${e.message}`);
      this.startingIds.delete(t.id);
      this.running.delete(t.id);
      t.status = C.ST_FAILED;
      t.errMsg = '无法连接下载服务';
      this.updateTaskQuiet(t);
      this.notifyChange('task');
      this.pump();
    }
  }

  private onProgress(t: DownloadTask, received: number, total: number): void {
    t.received = received;
    t.total = total;
    const stat: SpeedStat = this.statOf(t.id);
    const now: number = Date.now();
    const dt: number = now - stat.lastTime;
    if (dt > 400) {
      t.speed = Math.max(0, Math.floor((received - stat.lastReceived) / (dt / 1000)));
      stat.lastReceived = received;
      stat.lastTime = now;
    }
    t.progress = total > 0 ? Math.min(100, Math.floor(received / total * 100)) : 0;
    if (now - (this.lastDbWrite.get(t.id) ?? 0) > 2000) {
      this.lastDbWrite.set(t.id, now);
      this.updateTaskQuiet(t);
    }
    this.notifyChange('task');
  }

  private async onComplete(t: DownloadTask): Promise<void> {
    const at: request.agent.Task | undefined = this.running.get(t.id);
    if (at) {
      try {
        // 清理系统任务记录（Task无remove方法，使用agent级remove）
        await request.agent.remove(at.tid);
      } catch (err) {
        // 清理失败可忽略
      }
      this.running.delete(t.id);
    }
    // saveas相对路径落在cache目录，完成后转存到files目录持久保存
    if (this.ctx) {
      const cachePath: string = `${this.ctx.cacheDir}/${C.DL_DIR}/${t.fileName}`;
      const finalPath: string = `${this.ctx.filesDir}/${C.DL_DIR}/${t.fileName}`;
      try {
        if (fs.accessSync(cachePath)) {
          MetaParser.ensureDir(`${this.ctx.filesDir}/${C.DL_DIR}`);
          fs.copyFileSync(cachePath, finalPath);
          fs.unlinkSync(cachePath);
          t.filePath = finalPath;
        } else if (!fs.accessSync(t.filePath)) {
          t.errMsg = '下载文件丢失';
        }
      } catch (err) {
        // 转存失败时保留cache路径继续入库
        t.filePath = cachePath;
      }
    }
    t.progress = 100;
    t.status = C.ST_COMPLETED;
    t.speed = 0;
    if (t.total > 0) {
      t.received = t.total;
    }
    this.updateTaskQuiet(t);
    this.notifyChange('task');
    this.pump();
    await this.importToLibrary(t);
  }

  private async onFailed(t: DownloadTask, detail: string): Promise<void> {
    const at: request.agent.Task | undefined = this.running.get(t.id);
    if (at) {
      try {
        await request.agent.remove(at.tid);
      } catch (err) {
        // 忽略
      }
      this.running.delete(t.id);
    }
    t.status = C.ST_FAILED;
    t.errMsg = detail ? `下载失败(${detail.substring(0, 40)})` : '下载失败';
    t.speed = 0;
    this.updateTaskQuiet(t);
    this.notifyChange('task');
    this.pump();
  }

  /** 下载完成后自动加入本地音乐库 */
  private async importToLibrary(t: DownloadTask): Promise<void> {
    try {
      if (!fs.accessSync(t.filePath)) {
        t.errMsg = '下载文件丢失';
        return;
      }
      const meta = MetaParser.parseFile(t.filePath, LibraryService.getInstance().coverDir());
      const song: Song = new Song();
      song.title = t.title;
      song.artist = t.artist || '未知歌手';
      song.album = `云悦音乐·${C.qualityLabel(t.quality)}`;
      song.duration = meta.duration;
      song.filePath = t.filePath;
      song.coverPath = meta.coverPath;
      song.fileSize = fs.statSync(t.filePath).size;
      song.format = FmtUtil.extOf(t.filePath);
      song.source = C.SOURCE_LOCAL;
      song.addedTime = Date.now();
      if (song.duration > 0) {
        song.bitrate = Math.floor(song.fileSize * 8 / (song.duration / 1000) / 1000);
      }
      song.id = await DbService.getInstance().insertSong(song);
      t.songId = song.id;
      this.updateTaskQuiet(t);
      this.notifyChange('library');
      promptAction.showToast({ message: `「${t.title}」下载完成，已加入音乐库`, duration: 2500 });
    } catch (err) {
      const e = err as BusinessError;
      Logger.e('Download', `入库失败: ${e.message}`);
    }
  }

  // ==================== 对外操作 ====================
  async pauseTask(t: DownloadTask): Promise<void> {
    const at: request.agent.Task | undefined = this.running.get(t.id);
    if (at) {
      try {
        await at.pause();
      } catch (err) {
        // 系统侧暂停失败也按暂停处理
      }
      this.running.delete(t.id);
    }
    t.status = C.ST_PAUSED;
    t.speed = 0;
    this.updateTaskQuiet(t);
    this.notifyChange('task');
    this.pump();
  }

  async resumeTask(t: DownloadTask): Promise<void> {
    const at: request.agent.Task | undefined = this.running.get(t.id);
    if (at) {
      try {
        await at.resume();
        t.status = C.ST_RUNNING;
        this.updateTaskQuiet(t);
        this.notifyChange('task');
        return;
      } catch (err) {
        // 系统任务失效则重建
        this.running.delete(t.id);
      }
    }
    t.status = C.ST_PENDING;
    this.updateTaskQuiet(t);
    this.notifyChange('task');
    this.pump();
  }

  /** 取消并删除任务（含未完成的文件） */
  async cancelTask(t: DownloadTask): Promise<void> {
    const at: request.agent.Task | undefined = this.running.get(t.id);
    if (at) {
      try {
        await at.stop();
        await request.agent.remove(at.tid);
      } catch (err) {
        // 忽略
      }
      this.running.delete(t.id);
    }
    // 未完成文件位于cache目录
    if (this.ctx && t.status !== C.ST_COMPLETED) {
      const cachePath: string = `${this.ctx.cacheDir}/${C.DL_DIR}/${t.fileName}`;
      try {
        if (fs.accessSync(cachePath)) {
          fs.unlinkSync(cachePath);
        }
      } catch (err) {
        // 文件删除失败可忽略
      }
    }
    this.tasks = this.tasks.filter((x: DownloadTask) => x.id !== t.id);
    DbService.getInstance().deleteTaskById(t.id).catch(() => {});
    this.notifyChange('task');
    this.pump();
  }

  /** 失败重试 */
  retryTask(t: DownloadTask): void {
    t.status = C.ST_PENDING;
    t.errMsg = '';
    t.progress = 0;
    t.received = 0;
    this.updateTaskQuiet(t);
    this.notifyChange('task');
    this.pump();
  }

  /** 删除已完成任务记录 */
  async deleteCompleted(t: DownloadTask, alsoDeleteFile: boolean): Promise<void> {
    if (alsoDeleteFile) {
      try {
        if (fs.accessSync(t.filePath)) {
          fs.unlinkSync(t.filePath);
        }
      } catch (err) {
        // 文件可能已被用户移除
      }
    }
    this.tasks = this.tasks.filter((x: DownloadTask) => x.id !== t.id);
    DbService.getInstance().deleteTaskById(t.id).catch(() => {});
    this.notifyChange('task');
  }

  /** 清除已完成任务（不删除文件） */
  async clearCompleted(): Promise<void> {
    const done: DownloadTask[] = this.tasks.filter((t: DownloadTask) => t.status === C.ST_COMPLETED);
    for (let i = 0; i < done.length; i++) {
      DbService.getInstance().deleteTaskById(done[i].id).catch(() => {});
    }
    this.tasks = this.tasks.filter((t: DownloadTask) => t.status !== C.ST_COMPLETED);
    this.notifyChange('task');
  }

  /** 设置并发下载数（1-3） */
  setConcurrency(n: number): void {
    this.maxConcurrent = Math.max(1, Math.min(3, n));
    PrefsService.getInstance().putNum(C.P_CONCURRENCY, this.maxConcurrent);
    this.pump();
  }

  getConcurrency(): number {
    return this.maxConcurrent;
  }
}
