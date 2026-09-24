/**
 * 本地音乐库服务
 * 职责：
 *  1. 扫描应用沙箱内的音乐目录（download/imported/music），自动导入音频文件
 *  2. 通过 DocumentViewPicker 让用户手动选择音频文件导入（HarmonyOS NEXT
 *     对第三方应用不开放整盘扫描权限，选择器方式无需任何敏感权限）
 *  3. 调用 MetaParser 解析标题/歌手/专辑/时长/封面并入库
 */
import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import fs from '@ohos.file.fs';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { Song } from '../model/Song';
import { C } from '../common/Constants';
import { DbService } from './DbService';
import { MetaParser } from '../utils/MetaParser';
import { FmtUtil } from '../utils/FmtUtil';
import { Logger } from '../utils/Logger';

export class LibraryService {
  private static inst?: LibraryService;

  static getInstance(): LibraryService {
    if (!LibraryService.inst) {
      LibraryService.inst = new LibraryService();
    }
    return LibraryService.inst;
  }

  private ctx?: common.UIAbilityContext;

  init(ctx: common.UIAbilityContext): void {
    this.ctx = ctx;
  }

  /** 封面缓存目录 */
  coverDir(): string {
    return (this.ctx ? this.ctx.cacheDir : '') + '/' + C.COVER_DIR;
  }

  /** 歌词缓存目录 */
  lyricDir(): string {
    return (this.ctx ? this.ctx.cacheDir : '') + '/' + C.LYRIC_DIR;
  }

  /**
   * 扫描沙箱音乐目录
   * @returns 新增歌曲数量
   */
  async scanSandbox(): Promise<number> {
    if (!this.ctx || !DbService.getInstance().ready) {
      return 0;
    }
    const dirs: string[] = [
      `${this.ctx.filesDir}/${C.DL_DIR}`,
      `${this.ctx.filesDir}/${C.IMPORT_DIR}`,
      `${this.ctx.filesDir}/music`
    ];
    // 已存在的路径集合（去重）
    const existed: Set<string> = new Set<string>();
    const known: Song[] = await DbService.getInstance().queryAllSongs();
    known.forEach((s: Song) => {
      existed.add(s.filePath);
    });
    let added: number = 0;
    for (let i = 0; i < dirs.length; i++) {
      added += await this.walkDir(dirs[i], existed, 0);
    }
    Logger.i('Library', `扫描完成，新增${added}首`);
    return added;
  }

  private async walkDir(dir: string, existed: Set<string>, depth: number): Promise<number> {
    let added: number = 0;
    if (depth > 3) {
      return added;
    }
    try {
      if (!fs.accessSync(dir)) {
        return added;
      }
      const names: string[] = fs.listFileSync(dir);
      for (let i = 0; i < names.length; i++) {
        const full: string = `${dir}/${names[i]}`;
        let isDir: boolean = false;
        try {
          isDir = fs.statSync(full).isDirectory();
        } catch (err) {
          continue;
        }
        if (isDir) {
          added += await this.walkDir(full, existed, depth + 1);
        } else if (C.AUDIO_EXTS.indexOf(FmtUtil.extOf(full)) >= 0 && !existed.has(full)) {
          existed.add(full);
          const s: Song | null = await this.importSongFile(full);
          if (s !== null) {
            added++;
          }
        }
      }
    } catch (err) {
      const e = err as BusinessError;
      Logger.w('Library', `遍历失败 ${dir}: ${e.message}`);
    }
    return added;
  }

  /**
   * 解析并入库单个音频文件
   * @returns 入库后的Song（含自增id）；失败返回null
   */
  async importSongFile(path: string): Promise<Song | null> {
    try {
      const meta = MetaParser.parseFile(path, this.coverDir());
      const song: Song = new Song();
      song.title = meta.title || FmtUtil.baseName(path);
      song.artist = meta.artist || '未知歌手';
      song.album = meta.album || '未知专辑';
      song.duration = meta.duration;
      song.coverPath = meta.coverPath;
      song.bitrate = meta.bitrate;
      song.filePath = path;
      song.fileSize = fs.statSync(path).size;
      song.format = FmtUtil.extOf(path);
      song.source = C.SOURCE_LOCAL;
      song.addedTime = Date.now();
      song.id = await DbService.getInstance().insertSong(song);
      return song;
    } catch (err) {
      const e = err as BusinessError;
      Logger.w('Library', `导入失败 ${path}: ${e.message}`);
      return null;
    }
  }

  /**
   * 手动选择音频文件导入（DocumentViewPicker，无需权限）
   * @returns 成功导入数量
   */
  async importPickedAudio(): Promise<number> {
    if (!this.ctx) {
      return 0;
    }
    let added: number = 0;
    try {
      const docPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker();
      const opts: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 99;
      // 以扩展名过滤音频文件（API 12+使用fileSuffixFilters）
      opts.fileSuffixFilters = C.AUDIO_EXTS.map((e: string) => `.${e}`);
      const uris: string[] = await docPicker.select(opts);
      for (let i = 0; i < uris.length; i++) {
        const dest: string = await this.copyUriToImported(uris[i]);
        if (dest) {
          const s: Song | null = await this.importSongFile(dest);
          if (s !== null) {
            added++;
          }
        }
      }
      promptAction.showToast({
        message: added > 0 ? `成功导入 ${added} 首歌曲` : '未导入新歌曲',
        duration: 2000
      });
    } catch (err) {
      const e = err as BusinessError;
      Logger.w('Library', `选择导入失败: ${e.message}`);
      promptAction.showToast({ message: '导入已取消或失败', duration: 2000 });
    }
    return added;
  }

  /** 将选择器返回的URI复制到沙箱imported目录（流式复制，支持大文件） */
  private async copyUriToImported(uri: string): Promise<string> {
    try {
      const importedDir: string = `${this.ctx!.filesDir}/${C.IMPORT_DIR}`;
      MetaParser.ensureDir(importedDir);
      // 从URI中解析文件名
      let rawName: string = 'audio';
      try {
        const seg: string = uri.substring(uri.lastIndexOf('/') + 1);
        rawName = decodeURIComponent(seg);
      } catch (err) {
        rawName = `audio_${Date.now()}`;
      }
      const safeName: string = FmtUtil.sanitizeFileName(rawName);
      let dest: string = `${importedDir}/${safeName}`;
      if (fs.accessSync(dest)) {
        dest = `${importedDir}/${Date.now()}_${safeName}`;
      }
      const ok: boolean = this.copyUriToFile(uri, dest);
      return ok ? dest : '';
    } catch (err) {
      const e = err as BusinessError;
      Logger.w('Library', `复制文件失败: ${e.message}`);
      return '';
    }
  }

  /**
   * 通用URI复制：把选择器授予的文件URI复制到指定沙箱路径
   * @returns 是否成功
   */
  copyUriToFile(uri: string, dest: string): boolean {
    try {
      const src: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const dst: fs.File =
        fs.openSync(dest, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      const buf: ArrayBuffer = new ArrayBuffer(512 * 1024);
      let pos: number = 0;
      for (;;) {
        const n: number = fs.readSync(src.fd, buf, { offset: pos });
        if (n <= 0) {
          break;
        }
        fs.writeSync(dst.fd, buf, { length: n });
        pos += n;
      }
      fs.closeSync(src);
      fs.closeSync(dst);
      return true;
    } catch (err) {
      const e = err as BusinessError;
      Logger.w('Library', `复制失败: ${e.message}`);
      return false;
    }
  }
}
