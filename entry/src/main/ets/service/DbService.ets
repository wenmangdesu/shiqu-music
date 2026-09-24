/**
 * 结构化数据存储服务（@ohos.data.relationalStore / RDB）
 * 表：songs(歌曲) / playlists(歌单) / download_tasks(下载任务) / play_history(播放历史)
 */
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Song } from '../model/Song';
import { Playlist } from '../model/Playlist';
import { DownloadTask } from '../model/DownloadTask';
import { PlayHistory } from '../model/PlayHistory';
import { Logger } from '../utils/Logger';

export class DbService {
  private static inst?: DbService;

  static getInstance(): DbService {
    if (!DbService.inst) {
      DbService.inst = new DbService();
    }
    return DbService.inst;
  }

  private store?: relationalStore.RdbStore;

  get ready(): boolean {
    return this.store !== undefined;
  }

  async init(ctx: common.UIAbilityContext): Promise<void> {
    if (this.store) {
      return;
    }
    const config: relationalStore.StoreConfig = {
      name: 'cloudmusic.db',
      securityLevel: relationalStore.SecurityLevel.S1
    };
    this.store = await relationalStore.getRdbStore(ctx, config);
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS songs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL, artist TEXT, album TEXT,
      duration INTEGER, filePath TEXT, coverUrl TEXT, coverPath TEXT,
      fileSize INTEGER, bitrate INTEGER, format TEXT, source TEXT,
      lyricsPath TEXT, isLiked INTEGER, playCount INTEGER, addedTime INTEGER)`);
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS playlists (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL, coverPath TEXT, songIds TEXT,
      createTime INTEGER, updateTime INTEGER)`);
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS download_tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      songId INTEGER, title TEXT, artist TEXT, url TEXT, fileName TEXT, filePath TEXT,
      received INTEGER, total INTEGER, progress INTEGER, status TEXT, speed INTEGER,
      quality TEXT, errMsg TEXT, createTime INTEGER)`);
    await this.store.executeSql(`CREATE TABLE IF NOT EXISTS play_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT, songId INTEGER, playTime INTEGER)`);
    Logger.i('Db', '数据库初始化完成');
  }

  // ==================== 歌曲 ====================
  async queryAllSongs(): Promise<Song[]> {
    const out: Song[] = [];
    if (!this.store) {
      return out;
    }
    const preds = new relationalStore.RdbPredicates('songs');
    preds.orderByDesc('addedTime');
    const rs = await this.store.query(preds);
    try {
      while (rs.goToNextRow()) {
        out.push(DbService.rowToSong(rs));
      }
    } finally {
      rs.close();
    }
    return out;
  }

  private static rowToSong(rs: relationalStore.ResultSet): Song {
    const s: Song = new Song();
    s.id = rs.getLong(rs.getColumnIndex('id'));
    s.title = rs.getString(rs.getColumnIndex('title'));
    s.artist = rs.getString(rs.getColumnIndex('artist')) ?? '';
    s.album = rs.getString(rs.getColumnIndex('album')) ?? '';
    s.duration = rs.getLong(rs.getColumnIndex('duration'));
    s.filePath = rs.getString(rs.getColumnIndex('filePath')) ?? '';
    s.coverUrl = rs.getString(rs.getColumnIndex('coverUrl')) ?? '';
    s.coverPath = rs.getString(rs.getColumnIndex('coverPath')) ?? '';
    s.fileSize = rs.getLong(rs.getColumnIndex('fileSize'));
    s.bitrate = rs.getLong(rs.getColumnIndex('bitrate'));
    s.format = rs.getString(rs.getColumnIndex('format')) ?? '';
    s.source = rs.getString(rs.getColumnIndex('source')) ?? 'local';
    s.lyricsPath = rs.getString(rs.getColumnIndex('lyricsPath')) ?? '';
    s.isLiked = rs.getLong(rs.getColumnIndex('isLiked')) === 1;
    s.playCount = rs.getLong(rs.getColumnIndex('playCount'));
    s.addedTime = rs.getLong(rs.getColumnIndex('addedTime'));
    return s;
  }

  private static songBucket(s: Song): relationalStore.ValuesBucket {
    const bucket: relationalStore.ValuesBucket = {
      'title': s.title,
      'artist': s.artist,
      'album': s.album,
      'duration': s.duration,
      'filePath': s.filePath,
      'coverUrl': s.coverUrl,
      'coverPath': s.coverPath,
      'fileSize': s.fileSize,
      'bitrate': s.bitrate,
      'format': s.format,
      'source': s.source,
      'lyricsPath': s.lyricsPath,
      'isLiked': s.isLiked ? 1 : 0,
      'playCount': s.playCount,
      'addedTime': s.addedTime
    };
    return bucket;
  }

  async insertSong(s: Song): Promise<number> {
    if (!this.store) {
      return 0;
    }
    return await this.store.insert('songs', DbService.songBucket(s));
  }

  async updateSong(s: Song): Promise<void> {
    if (!this.store) {
      return;
    }
    const preds = new relationalStore.RdbPredicates('songs');
    preds.equalTo('id', s.id);
    await this.store.update(DbService.songBucket(s), preds);
  }

  /** 播放时回填未知时长 */
  async updateSongDuration(id: number, duration: number): Promise<void> {
    if (!this.store || duration <= 0) {
      return;
    }
    const bucket: relationalStore.ValuesBucket = { 'duration': duration };
    const preds = new relationalStore.RdbPredicates('songs');
    preds.equalTo('id', id);
    preds.and();
    preds.equalTo('duration', 0);
    await this.store.update(bucket, preds);
  }

  async deleteSongById(id: number): Promise<void> {
    if (!this.store) {
      return;
    }
    const preds = new relationalStore.RdbPredicates('songs');
    preds.equalTo('id', id);
    await this.store.delete(preds);
  }

  // ==================== 歌单 ====================
  async queryAllPlaylists(): Promise<Playlist[]> {
    const out: Playlist[] = [];
    if (!this.store) {
      return out;
    }
    const preds = new relationalStore.RdbPredicates('playlists');
    preds.orderByDesc('updateTime');
    const rs = await this.store.query(preds);
    try {
      while (rs.goToNextRow()) {
        const p: Playlist = new Playlist();
        p.id = rs.getLong(rs.getColumnIndex('id'));
        p.name = rs.getString(rs.getColumnIndex('name'));
        p.coverPath = rs.getString(rs.getColumnIndex('coverPath')) ?? '';
        p.songIds = DbService.parseIds(rs.getString(rs.getColumnIndex('songIds')));
        p.createTime = rs.getLong(rs.getColumnIndex('createTime'));
        p.updateTime = rs.getLong(rs.getColumnIndex('updateTime'));
        out.push(p);
      }
    } finally {
      rs.close();
    }
    return out;
  }

  private static parseIds(json: string): number[] {
    const out: number[] = [];
    if (!json) {
      return out;
    }
    try {
      const arr = JSON.parse(json) as Array<Object>;
      arr.forEach((v: Object) => {
        out.push(Number(v));
      });
    } catch (err) {
      // JSON损坏时返回空数组
    }
    return out;
  }

  private static playlistBucket(p: Playlist): relationalStore.ValuesBucket {
    const bucket: relationalStore.ValuesBucket = {
      'name': p.name,
      'coverPath': p.coverPath,
      'songIds': JSON.stringify(p.songIds),
      'createTime': p.createTime,
      'updateTime': p.updateTime
    };
    return bucket;
  }

  async insertPlaylist(p: Playlist): Promise<number> {
    if (!this.store) {
      return 0;
    }
    return await this.store.insert('playlists', DbService.playlistBucket(p));
  }

  async updatePlaylist(p: Playlist): Promise<void> {
    if (!this.store) {
      return;
    }
    const preds = new relationalStore.RdbPredicates('playlists');
    preds.equalTo('id', p.id);
    await this.store.update(DbService.playlistBucket(p), preds);
  }

  async deletePlaylistById(id: number): Promise<void> {
    if (!this.store) {
      return;
    }
    const preds = new relationalStore.RdbPredicates('playlists');
    preds.equalTo('id', id);
    await this.store.delete(preds);
  }

  // ==================== 下载任务 ====================
  async queryTasks(): Promise<DownloadTask[]> {
    const out: DownloadTask[] = [];
    if (!this.store) {
      return out;
    }
    const preds = new relationalStore.RdbPredicates('download_tasks');
    preds.orderByDesc('createTime');
    const rs = await this.store.query(preds);
    try {
      while (rs.goToNextRow()) {
        const t: DownloadTask = new DownloadTask();
        t.id = rs.getLong(rs.getColumnIndex('id'));
        t.songId = rs.getLong(rs.getColumnIndex('songId'));
        t.title = rs.getString(rs.getColumnIndex('title')) ?? '';
        t.artist = rs.getString(rs.getColumnIndex('artist')) ?? '';
        t.url = rs.getString(rs.getColumnIndex('url')) ?? '';
        t.fileName = rs.getString(rs.getColumnIndex('fileName')) ?? '';
        t.filePath = rs.getString(rs.getColumnIndex('filePath')) ?? '';
        t.received = rs.getLong(rs.getColumnIndex('received'));
        t.total = rs.getLong(rs.getColumnIndex('total'));
        t.progress = rs.getLong(rs.getColumnIndex('progress'));
        t.status = rs.getString(rs.getColumnIndex('status')) ?? 'pending';
        t.speed = rs.getLong(rs.getColumnIndex('speed'));
        t.quality = rs.getString(rs.getColumnIndex('quality')) ?? 'standard';
        t.errMsg = rs.getString(rs.getColumnIndex('errMsg')) ?? '';
        t.createTime = rs.getLong(rs.getColumnIndex('createTime'));
        out.push(t);
      }
    } finally {
      rs.close();
    }
    return out;
  }

  private static taskBucket(t: DownloadTask): relationalStore.ValuesBucket {
    const bucket: relationalStore.ValuesBucket = {
      'songId': t.songId,
      'title': t.title,
      'artist': t.artist,
      'url': t.url,
      'fileName': t.fileName,
      'filePath': t.filePath,
      'received': t.received,
      'total': t.total,
      'progress': t.progress,
      'status': t.status,
      'speed': t.speed,
      'quality': t.quality,
      'errMsg': t.errMsg,
      'createTime': t.createTime
    };
    return bucket;
  }

  async insertTask(t: DownloadTask): Promise<number> {
    if (!this.store) {
      return 0;
    }
    return await this.store.insert('download_tasks', DbService.taskBucket(t));
  }

  async updateTask(t: DownloadTask): Promise<void> {
    if (!this.store || t.id <= 0) {
      return;
    }
    const preds = new relationalStore.RdbPredicates('download_tasks');
    preds.equalTo('id', t.id);
    await this.store.update(DbService.taskBucket(t), preds);
  }

  async deleteTaskById(id: number): Promise<void> {
    if (!this.store) {
      return;
    }
    const preds = new relationalStore.RdbPredicates('download_tasks');
    preds.equalTo('id', id);
    await this.store.delete(preds);
  }

  // ==================== 播放历史 ====================
  async insertHistory(songId: number): Promise<void> {
    if (!this.store) {
      return;
    }
    const bucket: relationalStore.ValuesBucket = { 'songId': songId, 'playTime': Date.now() };
    await this.store.insert('play_history', bucket);
    // 只保留最近200条
    await this.store.executeSql(
      `DELETE FROM play_history WHERE id NOT IN (SELECT id FROM play_history ORDER BY playTime DESC LIMIT 200)`);
  }

  async queryHistory(limit: number): Promise<PlayHistory[]> {
    const out: PlayHistory[] = [];
    if (!this.store) {
      return out;
    }
    const preds = new relationalStore.RdbPredicates('play_history');
    preds.orderByDesc('playTime');
    preds.limitAs(limit);
    const rs = await this.store.query(preds);
    try {
      while (rs.goToNextRow()) {
        const h: PlayHistory = new PlayHistory();
        h.id = rs.getLong(rs.getColumnIndex('id'));
        h.songId = rs.getLong(rs.getColumnIndex('songId'));
        h.playTime = rs.getLong(rs.getColumnIndex('playTime'));
        out.push(h);
      }
    } finally {
      rs.close();
    }
    return out;
  }

  async clearHistory(): Promise<void> {
    if (!this.store) {
      return;
    }
    const preds = new relationalStore.RdbPredicates('play_history');
    await this.store.delete(preds);
  }
}
