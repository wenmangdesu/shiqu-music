/**
 * 歌词服务
 * 获取优先级：
 *  1. 歌曲对象记录的歌词文件
 *  2. 音频同目录同名 .lrc 文件
 *  3. 缓存目录（在线获取成功后缓存）
 *  4. 在线歌词接口（Constants.ONLINE_API_BASE/lyrics）
 *  5. 内置演示歌词（rawfile/lyrics/demo.lrc，仅在线歌曲）
 */
import { common } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { Song } from '../model/Song';
import { C } from '../common/Constants';
import { MetaParser } from '../utils/MetaParser';
import { Logger } from '../utils/Logger';

interface LyricsResp {
  lyrics?: string;
}

/** LRCLIB公开歌词库搜索单条结果 */
interface LrcLibItem {
  trackName?: string;
  artistName?: string;
  instrumental?: boolean;
  plainLyrics?: string;
  syncedLyrics?: string;
}

export class LyricsService {
  private static inst?: LyricsService;

  static getInstance(): LyricsService {
    if (!LyricsService.inst) {
      LyricsService.inst = new LyricsService();
    }
    return LyricsService.inst;
  }

  private ctx?: common.UIAbilityContext;

  init(ctx: common.UIAbilityContext): void {
    this.ctx = ctx;
  }

  /**
   * 获取歌词LRC文本；获取不到返回空字符串
   */
  async getLyrics(song: Song): Promise<string> {
    try {
      // 1. 歌曲记录的歌词路径
      if (song.lyricsPath && fs.accessSync(song.lyricsPath)) {
        return this.readTextFile(song.lyricsPath);
      }
      // 2. 同目录同名.lrc
      if (song.filePath && !song.filePath.startsWith('http')) {
        const sideCar: string = song.filePath.replace(/\.[^.\/\\]+$/, '.lrc');
        if (fs.accessSync(sideCar)) {
          return this.readTextFile(sideCar);
        }
      }
      if (!song.title) {
        return '';
      }
      // 3. 缓存
      const cachePath: string = `${this.ctx ? this.ctx.cacheDir : ''}/${C.LYRIC_DIR}/${this.cacheKey(song.title, song.artist)}.lrc`;
      if (this.ctx && fs.accessSync(cachePath)) {
        return this.readTextFile(cachePath);
      }
      // 4. 在线获取（自建API）
      const online: string = await this.fetchOnline(song.title, song.artist);
      if (online) {
        if (this.ctx) {
          this.writeCache(cachePath, online);
        }
        return online;
      }
      // 5. LRCLIB公开歌词库（真实在线歌曲大概率命中）
      const lrcLib: string = await this.fetchLrcLib(song.title, song.artist);
      if (lrcLib) {
        if (this.ctx) {
          this.writeCache(cachePath, lrcLib);
        }
        return lrcLib;
      }
      // 6. 在线歌曲回退内置演示歌词
      if (song.source === C.SOURCE_ONLINE) {
        return await this.readRawDemo();
      }
    } catch (err) {
      const e = err as BusinessError;
      Logger.w('Lyrics', `获取歌词失败: ${e.message}`);
    }
    return '';
  }

  private async fetchOnline(title: string, artist: string): Promise<string> {
    const url: string =
      `${C.ONLINE_API_BASE}/lyrics?title=${encodeURIComponent(title)}&artist=${encodeURIComponent(artist)}`;
    try {
      const cli: http.HttpRequest = http.createHttp();
      try {
        const resp: http.HttpResponse = await cli.request(url, {
          method: http.RequestMethod.GET,
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 6000,
          readTimeout: 8000
        });
        if (resp.responseCode !== 200) {
          return '';
        }
        const resp2 = JSON.parse(resp.result as string) as LyricsResp;
        return resp2.lyrics ?? '';
      } finally {
        cli.destroy();
      }
    } catch (err) {
      return '';
    }
  }

  /** LRCLIB公开歌词库：按歌名+歌手搜索，取第一条带时间轴LRC的结果 */
  private async fetchLrcLib(title: string, artist: string): Promise<string> {
    const url: string =
      `${C.LRCLIB_API_BASE}/api/search?track_name=${encodeURIComponent(title)}&artist_name=${encodeURIComponent(artist)}`;
    try {
      const cli: http.HttpRequest = http.createHttp();
      try {
        const resp: http.HttpResponse = await cli.request(url, {
          method: http.RequestMethod.GET,
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 6000,
          readTimeout: 8000,
          header: { 'User-Agent': 'ShiQu/1.0.0' }
        });
        if (resp.responseCode !== 200) {
          return '';
        }
        const arr = JSON.parse(resp.result as string) as Array<LrcLibItem>;
        for (let i = 0; i < arr.length; i++) {
          const item: LrcLibItem = arr[i];
          if (item.syncedLyrics && item.syncedLyrics.length > 0) {
            return item.syncedLyrics;
          }
        }
        return '';
      } finally {
        cli.destroy();
      }
    } catch (err) {
      return '';
    }
  }

  private async readRawDemo(): Promise<string> {
    try {
      if (!this.ctx) {
        return '';
      }
      const data: Uint8Array =
        await this.ctx.resourceManager.getRawFileContent('lyrics/demo.lrc');
      const td: util.TextDecoder = util.TextDecoder.create('utf-8');
      return td.decodeToString(data);
    } catch (err) {
      return '';
    }
  }

  private readTextFile(path: string): string {
    try {
      const file: fs.File = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const size: number = fs.statSync(path).size;
      const buf: ArrayBuffer = new ArrayBuffer(size);
      fs.readSync(file.fd, buf, { length: size });
      fs.closeSync(file);
      const td: util.TextDecoder = util.TextDecoder.create('utf-8');
      return td.decodeToString(new Uint8Array(buf));
    } catch (err) {
      return '';
    }
  }

  private writeCache(path: string, text: string): void {
    try {
      const slash: number = path.lastIndexOf('/');
      if (slash > 0) {
        MetaParser.ensureDir(path.substring(0, slash));
      }
      const f: fs.File =
        fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(f.fd, text);
      fs.closeSync(f);
    } catch (err) {
      // 缓存写失败可忽略
    }
  }

  private cacheKey(title: string, artist: string): string {
    const raw: string = `${title}_${artist}`;
    return raw.replace(/[^a-zA-Z0-9\u4e00-\u9fa5]/g, '_').substring(0, 80);
  }
}
