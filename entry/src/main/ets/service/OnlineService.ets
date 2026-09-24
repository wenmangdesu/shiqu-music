/**
 * 在线音乐服务（@ohos.net.http）
 * 1. 优先请求真实API（Constants.ONLINE_API_BASE，可替换为自己的服务端）
 * 2. 网络异常 / 未配置API / 结果为空时，自动回退为内置演示数据
 *    （演示音源为公开示例曲目，可直接播放与下载，用于验证完整链路）
 */
import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Song } from '../model/Song';
import { C } from '../common/Constants';
import { Logger } from '../utils/Logger';

/** 服务端搜索返回的单条数据结构约定 */
interface OnlineItem {
  id?: number;
  title?: string;
  name?: string;
  artist?: string;
  singer?: string;
  album?: string;
  duration?: number;
  url?: string;
  cover?: string;
  standardUrl?: string;
  highUrl?: string;
  losslessUrl?: string;
}

interface OnlineResp {
  code?: number;
  data?: Array<OnlineItem>;
}

/** Jamendo曲库返回的单条曲目 */
interface JamendoTrack {
  id?: string;
  name?: string;
  /** 时长(秒,字符串) */
  duration?: string;
  artist_name?: string;
  album_name?: string;
  image?: string;
  /** 流媒体播放直链 */
  audio?: string;
  /** 下载直链 */
  audiodownload?: string;
  audiodownload_allowed?: boolean;
}

interface JamendoResp {
  results?: Array<JamendoTrack>;
}

export class SearchResult {
  /** 是否为演示数据 */
  isDemo: boolean = false;
  /** 数据来源：demo-演示 jamendo-Jamendo曲库 api-自建API */
  sourceName: string = 'demo';
  songs: Song[] = [];
}

export class OnlineService {
  private static inst?: OnlineService;

  static getInstance(): OnlineService {
    if (!OnlineService.inst) {
      OnlineService.inst = new OnlineService();
    }
    return OnlineService.inst;
  }

  /**
   * 关键词搜索（歌曲/歌手/专辑）
   * 优先级：Jamendo真实曲库(已配置client_id) -> 自建API -> 内置演示数据
   */
  async search(keyword: string): Promise<SearchResult> {
    // 1. Jamendo真实曲库（配置了client_id即启用，搜索无结果也不回退演示数据）
    if (C.JAMENDO_CLIENT_ID) {
      return await this.searchJamendo(keyword);
    }
    // 2. 自建API
    const url: string =
      `${C.ONLINE_API_BASE}/search?keyword=${encodeURIComponent(keyword)}&page=1&size=30`;
    try {
      const text: string = await this.httpGet(url);
      const resp = JSON.parse(text) as OnlineResp;
      const items: Array<OnlineItem> = resp.data ?? [];
      const songs: Song[] = [];
      items.forEach((it: OnlineItem, i: number) => {
        const s: Song | null = OnlineService.itemToSong(it, i);
        if (s !== null) {
          songs.push(s);
        }
      });
      if (songs.length > 0) {
        const r: SearchResult = new SearchResult();
        r.isDemo = false;
        r.sourceName = 'api';
        r.songs = songs;
        Logger.i('Online', `API搜索成功: ${songs.length}条`);
        return r;
      }
    } catch (err) {
      const e = err as BusinessError;
      Logger.w('Online', `在线搜索失败，回退演示数据: ${e.message}`);
    }
    const r2: SearchResult = new SearchResult();
    r2.isDemo = true;
    r2.sourceName = 'demo';
    r2.songs = OnlineService.buildDemo(keyword);
    return r2;
  }

  /** Jamendo曲库搜索 */
  private async searchJamendo(keyword: string): Promise<SearchResult> {
    const r: SearchResult = new SearchResult();
    r.sourceName = 'jamendo';
    const url: string =
      `${C.JAMENDO_API_BASE}/tracks/?client_id=${C.JAMENDO_CLIENT_ID}&format=json&limit=30&search=${encodeURIComponent(keyword)}`;
    try {
      const text: string = await this.httpGet(url);
      const resp = JSON.parse(text) as JamendoResp;
      const items: Array<JamendoTrack> = resp.results ?? [];
      items.forEach((it: JamendoTrack, i: number) => {
        const s: Song | null = OnlineService.jamendoToSong(it, i);
        if (s !== null) {
          r.songs.push(s);
        }
      });
      Logger.i('Online', `Jamendo搜索: ${r.songs.length}条`);
    } catch (err) {
      const e = err as BusinessError;
      Logger.w('Online', `Jamendo搜索失败: ${e.message}`);
    }
    return r;
  }

  /** Jamendo曲目 -> Song（id取负数避免与本地库自增id冲突） */
  private static jamendoToSong(it: JamendoTrack, idx: number): Song | null {
    if (!it.name || !it.audio) {
      return null;
    }
    const s: Song = new Song();
    const n: number = Number(it.id);
    s.id = isNaN(n) ? -(idx + 100) : -(n + 1000000);
    s.title = it.name;
    s.artist = it.artist_name ?? '未知歌手';
    s.album = it.album_name ?? 'Jamendo';
    const d: number = Number(it.duration);
    s.duration = isNaN(d) ? 0 : d * 1000;
    s.filePath = it.audio;
    s.coverUrl = it.image ?? '';
    s.format = 'mp3';
    s.bitrate = 128;
    s.source = C.SOURCE_ONLINE;
    // Jamendo单音质：三档指向下载直链（允许下载时用audiodownload，否则用播放直链）
    const dl: string = (it.audiodownload_allowed === false || !it.audiodownload) ? it.audio : it.audiodownload!;
    s.qStd = dl;
    s.qHigh = dl;
    s.qLossless = dl;
    return s;
  }

  /** 按音质取下载地址 */
  getDownloadUrl(song: Song, quality: string): string {
    if (quality === C.QUALITY_HIGH) {
      return song.qHigh || song.filePath;
    }
    if (quality === C.QUALITY_LOSSLESS) {
      return song.qLossless || song.filePath;
    }
    return song.qStd || song.filePath;
  }

  private static itemToSong(it: OnlineItem, idx: number): Song | null {
    const title: string = it.title ?? it.name ?? '';
    const url: string = it.url ?? it.standardUrl ?? '';
    if (!title || !url) {
      return null;
    }
    const s: Song = new Song();
    s.id = it.id ?? -(idx + 1);
    s.title = title;
    s.artist = it.artist ?? it.singer ?? '未知歌手';
    s.album = it.album ?? '未知专辑';
    let d: number = it.duration ?? 0;
    if (d > 0 && d < 100000) {
      d = d * 1000; // 秒 -> 毫秒
    }
    s.duration = d;
    s.filePath = url;
    s.coverUrl = it.cover ?? '';
    s.format = 'mp3';
    s.source = C.SOURCE_ONLINE;
    s.qStd = it.standardUrl ?? url;
    s.qHigh = it.highUrl ?? url;
    s.qLossless = it.losslessUrl ?? url;
    return s;
  }

  /** 生成演示搜索结果（可在线播放） */
  private static buildDemo(keyword: string): Song[] {
    const kw: string = keyword.trim() || '识曲';
    const suffixes: string[] =
      ['（Demo版）', '钢琴版', '现场版', '伴奏版', '纯音乐', '混音版', '合唱版', '独奏版'];
    const artists: string[] = ['识曲电台', 'Demo乐队', '晨星组合', '旅途合唱团', '南巷乐团', '云端少年', '北岛歌者', '夏日计划'];
    const albums: string[] = ['识曲精选集', 'Demo合集 Vol.1', '在线试听榜', '热歌速递', '轻音慢享', '城市夜曲', '晨光歌单', '耳机里的世界'];
    const durations: number[] = [371000, 412000, 385000, 443000, 356000, 398000, 421000, 367000];
    const songs: Song[] = [];
    for (let i = 0; i < 8; i++) {
      const s: Song = new Song();
      s.id = -(i + 1);
      s.title = `${kw}${suffixes[i]}`;
      s.artist = artists[i];
      s.album = albums[i];
      s.duration = durations[i];
      s.filePath = C.DEMO_URL_TPL.replace('%d', `${i + 1}`);
      s.coverUrl = '';
      s.format = 'mp3';
      s.bitrate = 128;
      s.source = C.SOURCE_ONLINE;
      // 演示音源仅一档音质，三个画质地址指向同一文件
      s.qStd = s.filePath;
      s.qHigh = s.filePath;
      s.qLossless = s.filePath;
      songs.push(s);
    }
    return songs;
  }

  private async httpGet(url: string): Promise<string> {
    const cli: http.HttpRequest = http.createHttp();
    try {
      const resp: http.HttpResponse = await cli.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 8000,
        readTimeout: 10000,
        header: { 'User-Agent': 'ShiQu/1.0.0' }
      });
      if (resp.responseCode !== 200) {
        throw new Error(`HTTP ${resp.responseCode}`);
      }
      return resp.result as string;
    } finally {
      cli.destroy();
    }
  }
}
