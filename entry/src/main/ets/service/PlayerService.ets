/**
 * 播放器服务（@ohos.multimedia.media AVPlayer 封装）
 * 职责：
 *  - 播放/暂停/seek/倍速/上一首/下一首/播放模式（单曲循环/列表循环/随机）
 *  - 播放队列管理（跳转/移除/移动/插播下一首）
 *  - 本地文件(fdSrc)与网络URL双源播放
 *  - 后台持续播放（backgroundTaskManager 长时任务）
 *  - 通知栏播放信息（notificationManager）+ 锁屏控制（AVSession）
 *  - 播放状态通过 AppStorage 发布给UI（MVVM）
 */
import { media } from '@kit.MediaKit';
import fs from '@ohos.file.fs';
import { audio } from '@kit.AudioKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent, common } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { Song } from '../model/Song';
import { C, IPlayerHooks, IPlayerListener } from '../common/Constants';
import { AvSessionHelper } from './AvSessionHelper';
import { PrefsService } from './PrefsService';
import { DbService } from './DbService';
import { FmtUtil } from '../utils/FmtUtil';
import { Logger } from '../utils/Logger';

/** IPlayerHooks实现类（ArkTS不支持对象字面量直接赋值给接口类型） */
class PlayerHooksImpl implements IPlayerHooks {
  private svc: PlayerService;
  constructor(svc: PlayerService) {
    this.svc = svc;
  }
  play(): void {
    this.svc.play();
  }
  pause(): void {
    this.svc.pause();
  }
  next(): void {
    this.svc.next();
  }
  prev(): void {
    this.svc.prev();
  }
  stop(): void {
    this.svc.pause();
  }
  seek(ms: number): void {
    this.svc.seek(ms);
  }
}

export class PlayerService {
  private static inst?: PlayerService;

  static getInstance(): PlayerService {
    if (!PlayerService.inst) {
      PlayerService.inst = new PlayerService();
    }
    return PlayerService.inst;
  }

  /** 播放队列（当前播放列表） */
  queue: Song[] = [];
  /** 当前播放索引 */
  index: number = -1;
  /** 事件监听（由AppModel注册） */
  listener?: IPlayerListener;

  private ctx?: common.UIAbilityContext;
  private avPlayer?: media.AVPlayer;
  private autoPlay: boolean = true;
  private speedRate: number = 1.0;
  private lastEmit: number = 0;
  private bgStarted: boolean = false;
  private lastNotifySongId: number = 0;
  private lastNotifyPlaying: boolean = false;
  /** 当前占用中的文件fd（fdSrc要求fd保持打开，切歌时需关闭旧fd避免泄漏） */
  private lastFd: number = -1;
  /** 续播恢复：待跳转的进度（prepared后执行），-1表示无 */
  private pendingSeek: number = -1;
  /** 续播记忆：上次持久化时间 */
  private lastPosSave: number = 0;
  /** 定时关闭：到达时间戳，0表示未启用 */
  private sleepAt: number = 0;
  /** 定时关闭：播完当前歌曲后停止 */
  private sleepAfterSong: boolean = false;

  async init(ctx: common.UIAbilityContext): Promise<void> {
    this.ctx = ctx;
    this.speedRate = PrefsService.getInstance().getNum(C.P_SPEED, 1.0);
    if (!this.avPlayer) {
      try {
        this.avPlayer = await media.createAVPlayer();
        this.setupListeners();
        Logger.i('Player', 'AVPlayer创建成功');
      } catch (err) {
        const e = err as BusinessError;
        Logger.e('Player', `AVPlayer创建失败: ${e.message}`);
      }
    }
    // 注册锁屏/控制中心媒体会话
    const hooks = new PlayerHooksImpl(this);
    await AvSessionHelper.getInstance().init(ctx, hooks);
    // 耳机/蓝牙音频设备断开时自动暂停
    try {
      audio.getAudioManager().on('deviceChange', (action: audio.DeviceChangeAction) => {
        if (action.type !== audio.DeviceChangeType.DISCONNECT) {
          return;
        }
        const playing: boolean = AppStorage.get<boolean>(C.K_PLAYING) ?? false;
        if (!playing) {
          return;
        }
        const list: audio.AudioDeviceDescriptors = action.deviceDescriptors;
        for (let i = 0; i < list.length; i++) {
          const dt: audio.AudioDeviceType = list[i].deviceType;
          if (dt === audio.AudioDeviceType.WIRED_HEADSET ||
            dt === audio.AudioDeviceType.WIRED_HEADPHONES ||
            dt === audio.AudioDeviceType.BLUETOOTH_A2DP) {
            this.pause();
            promptAction.showToast({ message: '耳机已断开，已暂停播放', duration: 2000 });
            break;
          }
        }
      });
    } catch (err) {
      // 设备监听注册失败可忽略
    }
  }

  setListener(l: IPlayerListener): void {
    this.listener = l;
  }

  currentSong(): Song | null {
    if (this.index >= 0 && this.index < this.queue.length) {
      return this.queue[this.index];
    }
    return null;
  }

  // ==================== 续播记忆 ====================
  /** 持久化当前队列/索引/进度（仅保留本地歌曲，在线歌曲重启后无法恢复） */
  private persistQueue(): void {
    if (this.queue.length === 0 || this.index < 0) {
      return;
    }
    try {
      const paths: string[] = [];
      this.queue.forEach((s: Song) => {
        paths.push(s.filePath);
      });
      PrefsService.getInstance().putStr(C.P_LAST_QUEUE, JSON.stringify(paths));
      PrefsService.getInstance().putNum(C.P_LAST_INDEX, this.index);
      const p: media.AVPlayer | undefined = this.avPlayer;
      PrefsService.getInstance().putNum(C.P_LAST_POS, p ? p.currentTime : 0);
    } catch (err) {
      // 持久化失败可忽略
    }
  }

  /** 启动时恢复上次队列与进度（不自动播放，等待用户点播放） */
  restoreQueue(songs: Song[], index: number, posMs: number): void {
    if (songs.length === 0 || !this.avPlayer) {
      return;
    }
    this.queue = songs;
    this.index = Math.max(0, Math.min(index, songs.length - 1));
    const song: Song = this.queue[this.index];
    this.autoPlay = false;
    this.pendingSeek = Math.max(0, posMs);
    AppStorage.setOrCreate(C.K_SONG, song);
    AppStorage.setOrCreate(C.K_LIKED, song.isLiked);
    AppStorage.setOrCreate(C.K_POS, this.pendingSeek);
    AppStorage.setOrCreate(C.K_DUR, song.duration);
    AvSessionHelper.getInstance().setMeta(song);
    this.loadSong(song);
  }

  // ==================== 定时关闭 ====================
  /**
   * 定时关闭
   * @param minutes 分钟数；0=取消定时；-1=播完当前歌曲后停止
   */
  setSleepTimer(minutes: number): void {
    if (minutes === 0) {
      this.sleepAt = 0;
      this.sleepAfterSong = false;
      promptAction.showToast({ message: '已取消定时关闭', duration: 2000 });
      return;
    }
    if (minutes < 0) {
      this.sleepAfterSong = true;
      this.sleepAt = 0;
      promptAction.showToast({ message: '播完当前歌曲后将停止播放', duration: 2000 });
      return;
    }
    this.sleepAt = Date.now() + minutes * 60 * 1000;
    this.sleepAfterSong = false;
    promptAction.showToast({ message: `将在 ${minutes} 分钟后停止播放`, duration: 2000 });
  }

  /** 播放中检查定时关闭是否到时 */
  private checkSleep(): void {
    if (this.sleepAt > 0 && Date.now() >= this.sleepAt) {
      this.sleepAt = 0;
      this.pause();
      promptAction.showToast({ message: '定时关闭：已暂停播放', duration: 2000 });
    }
  }

  // ==================== 队列与播放 ====================
  /**
   * 设置播放队列并从指定索引开始播放
   */
  setQueue(songs: Song[], startIndex: number): void {
    if (songs.length === 0) {
      return;
    }
    this.queue = songs.slice();
    this.notifyQueueChange();
    this.playIndex(startIndex);
  }

  /** "下一首播放"：插播到当前歌曲之后 */
  insertNext(song: Song): void {
    if (this.queue.length === 0) {
      this.setQueue([song], 0);
      return;
    }
    // 已在队列中则先移除旧位置
    const exist: number = this.queue.findIndex((s: Song) => s.id === song.id && s.filePath === song.filePath);
    if (exist >= 0) {
      this.queue.splice(exist, 1);
      if (exist < this.index) {
        this.index--;
      }
    }
    this.queue.splice(this.index + 1, 0, song);
    this.notifyQueueChange();
  }

  /** 队列内移除 */
  removeFromQueue(idx: number): void {
    if (idx < 0 || idx >= this.queue.length) {
      return;
    }
    this.queue.splice(idx, 1);
    if (this.queue.length === 0) {
      this.clearQueue();
      return;
    }
    if (idx < this.index) {
      this.index--;
    } else if (idx === this.index) {
      // 移除的是当前歌曲：播放同位置的新歌曲
      if (this.index >= this.queue.length) {
        this.index = 0;
      }
      this.playIndex(this.index);
      this.notifyQueueChange();
      return;
    }
    this.notifyQueueChange();
  }

  /** 队列内移动（用于排序） */
  moveInQueue(from: number, to: number): void {
    if (from < 0 || from >= this.queue.length || to < 0 || to >= this.queue.length || from === to) {
      return;
    }
    const cur: Song | null = this.currentSong();
    const item: Song = this.queue.splice(from, 1)[0];
    this.queue.splice(to, 0, item);
    // 同步当前索引
    if (cur) {
      const ni: number = this.queue.findIndex((s: Song) => s === cur);
      if (ni >= 0) {
        this.index = ni;
      }
    }
    this.notifyQueueChange();
  }

  clearQueue(): void {
    this.queue = [];
    this.index = -1;
    this.autoPlay = false;
    this.stopBgTask();
    try {
      this.avPlayer?.reset();
    } catch (err) {
      // 播放器可能已释放
    }
    AppStorage.setOrCreate(C.K_PLAYING, false);
    AppStorage.setOrCreate(C.K_POS, 0);
    AppStorage.setOrCreate(C.K_DUR, 0);
    AppStorage.setOrCreate(C.K_SONG, new Song());
    AppStorage.setOrCreate(C.K_LIKED, false);
    notificationManager.cancel(C.NOTIFY_ID).catch(() => {});
    // 清除续播记忆
    PrefsService.getInstance().putStr(C.P_LAST_QUEUE, '');
    PrefsService.getInstance().putNum(C.P_LAST_INDEX, -1);
    PrefsService.getInstance().putNum(C.P_LAST_POS, 0);
    this.notifyQueueChange();
  }

  /**
   * 播放指定索引（支持负数回绕）
   */
  playIndex(i: number): void {
    if (this.queue.length === 0 || !this.avPlayer) {
      return;
    }
    let idx: number = i % this.queue.length;
    if (idx < 0) {
      idx += this.queue.length;
    }
    const song: Song = this.queue[idx];
    // 点击当前歌曲：从头播放
    const cur: Song | null = this.currentSong();
    if (cur && cur.id === song.id && cur.filePath === song.filePath && idx === this.index) {
      this.seek(0);
      this.play();
      return;
    }
    this.index = idx;
    this.autoPlay = true;
    AppStorage.setOrCreate(C.K_SONG, song);
    AppStorage.setOrCreate(C.K_LIKED, song.isLiked);
    AppStorage.setOrCreate(C.K_POS, 0);
    AppStorage.setOrCreate(C.K_DUR, song.duration);
    AvSessionHelper.getInstance().setMeta(song);
    this.loadSong(song);
    this.startBgTask();
    this.listener?.onSongChange(song);
    this.persistQueue();
  }

  /** 加载播放源：本地走fd，网络走url */
  private loadSong(song: Song): void {
    const p: media.AVPlayer | undefined = this.avPlayer;
    if (!p) {
      return;
    }
    const prepare = (): void => {
      try {
        if (song.filePath.startsWith('http')) {
          p.url = song.filePath;
        } else {
          // 关闭上一首占用的fd，避免长时间使用导致句柄泄漏
          if (this.lastFd >= 0) {
            try {
              fs.closeSync(this.lastFd);
            } catch (e) {
              // 旧fd可能已失效
            }
            this.lastFd = -1;
          }
          const st: fs.Stat = fs.statSync(song.filePath);
          const f: fs.File = fs.openSync(song.filePath, fs.OpenMode.READ_ONLY);
          this.lastFd = f.fd;
          p.fdSrc = { fd: f.fd, offset: 0, length: st.size };
        }
      } catch (err) {
        const e = err as BusinessError;
        Logger.e('Player', `加载失败: ${e.message}`);
        AppStorage.setOrCreate(C.K_PLAYING, false);
        this.listener?.onPlayError('播放失败：文件不存在或已损坏');
      }
    };
    try {
      if (p.state === 'idle') {
        prepare();
      } else {
        p.reset().then(() => {
          prepare();
        }).catch(() => {
          prepare();
        });
      }
    } catch (err) {
      const e = err as BusinessError;
      Logger.e('Player', `切换歌曲失败: ${e.message}`);
    }
  }

  // ==================== 基础控制 ====================
  play(): void {
    const p: media.AVPlayer | undefined = this.avPlayer;
    if (!p) {
      return;
    }
    if (this.index < 0 && this.queue.length > 0) {
      this.playIndex(0);
      return;
    }
    const st: string = p.state;
    if (st === 'prepared' || st === 'paused' || st === 'completed') {
      p.play().catch(() => {});
      this.startBgTask();
    }
  }

  pause(): void {
    const p: media.AVPlayer | undefined = this.avPlayer;
    if (!p) {
      return;
    }
    if (p.state === 'playing') {
      p.pause().catch(() => {});
    }
  }

  togglePlay(): void {
    const playing: boolean = AppStorage.get<boolean>(C.K_PLAYING) ?? false;
    if (playing) {
      this.pause();
    } else {
      this.play();
    }
  }

  /** 跳转到指定位置(毫秒) */
  seek(ms: number): void {
    const p: media.AVPlayer | undefined = this.avPlayer;
    if (!p || ms < 0) {
      return;
    }
    const st: string = p.state;
    if (st === 'prepared' || st === 'playing' || st === 'paused' || st === 'completed') {
      Promise.resolve(p.seek(ms, media.SeekMode.SEEK_PREV_SYNC)).catch(() => {});
      AppStorage.setOrCreate(C.K_POS, ms);
      AvSessionHelper.getInstance().setState(AppStorage.get<boolean>(C.K_PLAYING) ?? false, ms);
    }
  }

    /** 设置倍速 0.75/1.0/1.25/1.75/2.0 */
  setSpeed(rate: number): void {
    this.speedRate = rate;
    AppStorage.setOrCreate(C.K_SPEED, rate);
    PrefsService.getInstance().putNum(C.P_SPEED, rate);
    this.applySpeed();
  }

  private applySpeed(): void {
    const p: media.AVPlayer | undefined = this.avPlayer;
    if (!p) {
      return;
    }
    const st: string = p.state;
    if (st !== 'prepared' && st !== 'playing' && st !== 'paused') {
      return;
    }
    let v: media.PlaybackSpeed = media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
    if (this.speedRate === 0.75) {
      v = media.PlaybackSpeed.SPEED_FORWARD_0_75_X;
    } else if (this.speedRate === 1.25) {
      v = media.PlaybackSpeed.SPEED_FORWARD_1_25_X;
    } else if (this.speedRate === 1.75) {
      v = media.PlaybackSpeed.SPEED_FORWARD_1_75_X;
    } else if (this.speedRate === 2.0) {
      v = media.PlaybackSpeed.SPEED_FORWARD_2_00_X;
    }
    Promise.resolve(p.setSpeed(v)).catch(() => {});
  }

  /** 切换播放模式并持久化 */
  setMode(mode: number): void {
    AppStorage.setOrCreate(C.K_MODE, mode);
    PrefsService.getInstance().putNum(C.P_MODE, mode);
  }

  // ==================== 上下曲 ====================
  next(): void {
    if (this.queue.length === 0) {
      return;
    }
    const mode: number = AppStorage.get<number>(C.K_MODE) ?? C.PLAY_MODE_LIST;
    if (mode === C.PLAY_MODE_RANDOM && this.queue.length > 1) {
      this.playRandom();
    } else {
      this.playIndex(this.index + 1);
    }
  }

  prev(): void {
    if (this.queue.length === 0) {
      return;
    }
    this.playIndex(this.index - 1);
  }

  private playRandom(): void {
    if (this.queue.length <= 1) {
      this.playIndex(0);
      return;
    }
    let j: number = this.index;
    while (j === this.index) {
      j = Math.floor(Math.random() * this.queue.length);
    }
    this.playIndex(j);
  }

  /** 播放完成回调：按播放模式决定下一曲 */
  private onComplete(): void {
    // 定时关闭：播完这首就停
    if (this.sleepAfterSong) {
      this.sleepAfterSong = false;
      this.pause();
      promptAction.showToast({ message: '定时关闭：已停止播放', duration: 2000 });
      return;
    }
    const mode: number = AppStorage.get<number>(C.K_MODE) ?? C.PLAY_MODE_LIST;
    if (mode === C.PLAY_MODE_SINGLE) {
      this.seek(0);
      this.play();
    } else if (mode === C.PLAY_MODE_RANDOM) {
      this.playRandom();
    } else if (mode === C.PLAY_MODE_ORDER) {
      // 顺序播放：列表播完即停在第一首开头
      if (this.index >= this.queue.length - 1) {
        this.index = 0;
        const first: Song = this.queue[0];
        this.autoPlay = false;
        this.pendingSeek = 0;
        AppStorage.setOrCreate(C.K_SONG, first);
        AppStorage.setOrCreate(C.K_LIKED, first.isLiked);
        AppStorage.setOrCreate(C.K_POS, 0);
        AppStorage.setOrCreate(C.K_DUR, first.duration);
        this.loadSong(first);
        promptAction.showToast({ message: '列表已播完，顺序播放结束', duration: 2000 });
      } else {
        this.playIndex(this.index + 1);
      }
    } else {
      if (this.queue.length <= 1) {
        this.seek(0);
        this.play();
      } else {
        this.playIndex(this.index + 1);
      }
    }
  }

  // ==================== AVPlayer事件 ====================
  private setupListeners(): void {
    const p: media.AVPlayer | undefined = this.avPlayer;
    if (!p) {
      return;
    }
    p.on('stateChange', (state: string) => {
      if (state === 'initialized') {
        p.prepare().catch(() => {});
      } else if (state === 'prepared') {
        AppStorage.setOrCreate(C.K_DUR, p.duration);
        this.onDurationReady(p.duration);
        this.applySpeed();
        // 续播恢复：跳到上次进度（不自动播放）
        if (this.pendingSeek >= 0) {
          Promise.resolve(p.seek(this.pendingSeek, media.SeekMode.SEEK_PREV_SYNC)).catch(() => {});
          AppStorage.setOrCreate(C.K_POS, this.pendingSeek);
          AvSessionHelper.getInstance().setState(false, this.pendingSeek);
          this.pendingSeek = -1;
        }
        if (this.autoPlay) {
          p.play().catch(() => {});
        }
      } else if (state === 'playing') {
        this.setPlayState(true);
      } else if (state === 'paused') {
        this.setPlayState(false);
      } else if (state === 'completed') {
        this.setPlayState(false);
        this.onComplete();
      } else if (state === 'error') {
        this.setPlayState(false);
      }
    });
    p.on('timeUpdate', () => {
      this.checkSleep();
      const now: number = Date.now();
      if (now - this.lastEmit < 250) {
        return;
      }
      this.lastEmit = now;
      AppStorage.setOrCreate(C.K_POS, p.currentTime);
      // 续播记忆：每5秒保存一次进度
      if (now - this.lastPosSave > 5000) {
        this.lastPosSave = now;
        this.persistQueue();
      }
    });
    p.on('durationUpdate', () => {
      AppStorage.setOrCreate(C.K_DUR, p.duration);
      this.onDurationReady(p.duration);
    });
    p.on('seekDone', () => {
      AppStorage.setOrCreate(C.K_POS, p.currentTime);
    });
    p.on('audioInterrupt', (event: audio.InterruptEvent) => {
      // 音频焦点被抢占时同步UI状态
      if (event.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE ||
        event.hintType === audio.InterruptHint.INTERRUPT_HINT_STOP) {
        this.setPlayState(false);
      }
    });
    p.on('error', (err: BusinessError) => {
      Logger.e('Player', `播放错误: ${err.code} ${err.message}`);
      this.setPlayState(false);
      this.listener?.onPlayError('播放失败：文件损坏或格式不支持');
    });
  }

  /** 时长就绪：回填数据库中未知时长的歌曲 */
  private onDurationReady(dur: number): void {
    const s: Song | null = this.currentSong();
    if (s && s.duration <= 0 && dur > 0) {
      s.duration = dur;
      DbService.getInstance().updateSongDuration(s.id, dur).catch(() => {});
    }
  }

  private setPlayState(playing: boolean): void {
    AppStorage.setOrCreate(C.K_PLAYING, playing);
    const p: media.AVPlayer | undefined = this.avPlayer;
    AvSessionHelper.getInstance().setState(playing, p ? p.currentTime : 0);
    // 暂停时立即保存续播进度
    if (!playing) {
      this.persistQueue();
    }
    // 更新通知栏（按歌曲+状态去重，避免频繁刷新）
    const s: Song | null = this.currentSong();
    if (s && (s.id !== this.lastNotifySongId || playing !== this.lastNotifyPlaying)) {
      this.lastNotifySongId = s.id;
      this.lastNotifyPlaying = playing;
      this.publishNotification(s, playing);
    }
  }

  private notifyQueueChange(): void {
    const v: number = (AppStorage.get<number>(C.K_QUEUEV) ?? 0) + 1;
    AppStorage.setOrCreate(C.K_QUEUEV, v);
    this.persistQueue();
    this.listener?.onQueueChange();
  }

  // ==================== 通知栏 ====================
  private publishNotification(song: Song, playing: boolean): void {
    const req: notificationManager.NotificationRequest = {
      id: C.NOTIFY_ID,
      isOngoing: true,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: `${playing ? '正在播放' : '已暂停'}：${song.title}`,
          text: `${song.artist || '未知歌手'} · ${FmtUtil.fmtDuration(song.duration)} · 识曲`,
          additionalText: ''
        }
      }
    };
    notificationManager.publish(req).catch(() => {});
  }

  // ==================== 后台长时任务 ====================
  private async startBgTask(): Promise<void> {
    if (this.bgStarted || !this.ctx) {
      return;
    }
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [{ bundleName: this.ctx.abilityInfo.bundleName, abilityName: 'EntryAbility' }],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const obj = await wantAgent.getWantAgent(info);
      await backgroundTaskManager.startBackgroundRunning(
        this.ctx, backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, obj);
      this.bgStarted = true;
      Logger.i('Player', '后台播放任务已启动');
    } catch (err) {
      const e = err as BusinessError;
      Logger.w('Player', `后台任务申请失败: ${e.message}`);
    }
  }

  private async stopBgTask(): Promise<void> {
    if (!this.bgStarted || !this.ctx) {
      return;
    }
    this.bgStarted = false;
    try {
      await backgroundTaskManager.stopBackgroundRunning(this.ctx);
    } catch (err) {
      // 忽略
    }
  }

  // ==================== 系统音量 ====================
  /** 读取媒体音量(0-15)，失败返回-1 */
  async getMediaVolume(): Promise<number> {
    try {
      return await audio.getAudioManager().getVolume(audio.AudioVolumeType.MEDIA);
    } catch (err) {
      return -1;
    }
  }

  /** 设置媒体音量(0-15) */
  setMediaVolume(v: number): void {
    try {
      const vol: number = Math.max(0, Math.min(15, Math.round(v)));
      audio.getAudioManager().setVolume(audio.AudioVolumeType.MEDIA, vol);
    } catch (err) {
      // 忽略
    }
  }

  release(): void {
    this.stopBgTask();
    try {
      if (this.lastFd >= 0) {
        fs.closeSync(this.lastFd);
        this.lastFd = -1;
      }
    } catch (err) {
      // 忽略
    }
    try {
      this.avPlayer?.release();
    } catch (err) {
      // 忽略
    }
    this.avPlayer = undefined;
  }
}
