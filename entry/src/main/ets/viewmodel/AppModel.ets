/**
 * 全局状态模型（MVVM中的ViewModel层）
 * 职责：
 *  - 应用初始化编排（偏好 -> 数据库 -> 播放器 -> 下载 -> 媒体库 -> 通知授权）
 *  - 业务数据聚合：本地音乐/歌单/播放历史/收藏
 *  - 跨页面导航（NavPathStack）
 *  - 播放联动：历史记录、播放次数、主题色跟随封面、通知授权
 */
import { common, ConfigurationConstant, bundleManager } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { Song } from '../model/Song';
import { Playlist } from '../model/Playlist';
import { PlayHistory } from '../model/PlayHistory';
import { C, IPlayerListener } from '../common/Constants';
import { PlayerService } from '../service/PlayerService';
import { DbService } from '../service/DbService';
import { PrefsService } from '../service/PrefsService';
import { LibraryService } from '../service/LibraryService';
import { DownloadService, IDlListener } from '../service/DownloadService';
import { ColorUtil } from '../utils/ColorUtil';
import { Logger } from '../utils/Logger';

/** IPlayerListener实现类 */
class AppPlayerListener implements IPlayerListener {
  private model: AppModel;
  constructor(model: AppModel) {
    this.model = model;
  }
  onSongChange(song: Song): void {
    this.model.onSongChanged(song);
  }
  onQueueChange(): void {
  }
  onPlayError(msg: string): void {
    this.model.toast(msg);
  }
}

/** IDlListener实现类 */
class AppDlListener implements IDlListener {
  private model: AppModel;
  constructor(model: AppModel) {
    this.model = model;
  }
  onChange(type: string): void {
    const v: number = (AppStorage.get<number>(C.K_DLV) ?? 0) + 1;
    AppStorage.setOrCreate(C.K_DLV, v);
    if (type === 'library') {
      this.model.reloadSongs();
    }
  }
}

export class AppModel {
  private static inst?: AppModel;

  static getInstance(): AppModel {
    if (!AppModel.inst) {
      AppModel.inst = new AppModel();
    }
    return AppModel.inst;
  }

  // ==================== 全局状态 ====================
  context?: common.UIAbilityContext;
  /** 全局导航栈（Index中挂载） */
  navStack: NavPathStack = new NavPathStack();
  /** 本地音乐库 */
  localSongs: Song[] = [];
  /** 自定义歌单 */
  playlists: Playlist[] = [];
  /** 最近播放记录 */
  history: PlayHistory[] = [];
  /** 播放器 */
  player: PlayerService = PlayerService.getInstance();
  /** 应用就绪Promise（启动页等待初始化完成） */
  readyPromise: Promise<void> = Promise.resolve();
  /** 应用版本名 */
  versionName: string = C.VERSION;

  // ==================== 页面间传参 ====================
  /** 待添加到歌单的歌曲id集合（多选批量添加） */
  pendingAddSongIds: number[] = [];
  /** 当前查看的歌单id（歌单详情页） */
  currentPlaylistId: number = -1;
  /** 正在编辑（重命名）的歌单id，-1表示新建 */
  editPlaylistId: number = -1;
  /** 选歌加入的目标歌单id */
  pickTargetPlaylistId: number = -1;

  private lastRecordSongId: number = 0;
  private lastRecordTime: number = 0;

  // ==================== 初始化 ====================
  /** 应用入口调用（EntryAbility.onCreate） */
  initApp(ctx: common.UIAbilityContext): void {
    this.context = ctx;
    this.readyPromise = this.doInit(ctx);
  }

  private async doInit(ctx: common.UIAbilityContext): Promise<void> {
    try {
      // 1. AppStorage 初始值
      AppStorage.setOrCreate(C.K_PLAYING, false);
      AppStorage.setOrCreate(C.K_POS, 0);
      AppStorage.setOrCreate(C.K_DUR, 0);
      AppStorage.setOrCreate(C.K_SONG, new Song());
      AppStorage.setOrCreate(C.K_LIKED, false);
      AppStorage.setOrCreate(C.K_MODE, PrefsService.getInstance().getNum(C.P_MODE, C.PLAY_MODE_LIST));
      AppStorage.setOrCreate(C.K_SPEED, PrefsService.getInstance().getNum(C.P_SPEED, 1.0));
      AppStorage.setOrCreate(C.K_FLOAT, PrefsService.getInstance().getBool(C.P_FLOAT, false));
      AppStorage.setOrCreate(C.K_LIBV, 0);
      AppStorage.setOrCreate(C.K_PLV, 0);
      AppStorage.setOrCreate(C.K_DLV, 0);
      AppStorage.setOrCreate(C.K_QUEUEV, 0);
      AppStorage.setOrCreate(C.K_HISTV, 0);
      AppStorage.setOrCreate(C.K_THEME, C.DEFAULT_THEME);
      // 2. 主题色
      const themeAuto: boolean = PrefsService.getInstance().getBool(C.P_THEME_AUTO, true);
      if (!themeAuto) {
        AppStorage.setOrCreate(C.K_THEME,
          PrefsService.getInstance().getStr(C.P_THEME_FIXED, C.DEFAULT_THEME));
      }
      // 3. 数据库与业务数据
      await DbService.getInstance().init(ctx);
      this.localSongs = await DbService.getInstance().queryAllSongs();
      this.playlists = await DbService.getInstance().queryAllPlaylists();
      this.history = await DbService.getInstance().queryHistory(100);
      // 4. 播放器
      const pl = new AppPlayerListener(this);
      this.player.setListener(pl);
      await this.player.init(ctx);
      // 5. 下载服务（恢复未完成任务）
      const dl = new AppDlListener(this);
      DownloadService.getInstance().setListener(dl);
      await DownloadService.getInstance().init(ctx);
      // 6. 媒体库服务并执行首轮扫描
      LibraryService.getInstance().init(ctx);
      LibraryService.getInstance().scanSandbox().then((n: number) => {
        if (n > 0) {
          this.reloadSongs();
        }
      }).catch(() => {});
      // 7. 通知授权（首次弹窗）
      notificationManager.requestEnableNotification(ctx).catch(() => {});
      // 8. 版本名
      try {
        const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
        this.versionName = info.versionName || C.VERSION;
      } catch (err) {
        this.versionName = C.VERSION;
      }
      this.bump(C.K_LIBV);
      this.bump(C.K_PLV);
      this.bump(C.K_DLV);
      this.bump(C.K_HISTV);
      Logger.i('AppModel', '初始化完成');
    } catch (err) {
      const e = err as BusinessError;
      Logger.e('AppModel', `初始化失败: ${e.message}`);
    }
  }

  // ==================== 数据访问 ====================
  /** 虚拟歌单"我喜欢"（id = -1） */
  likedPlaylist(): Playlist {
    const p: Playlist = new Playlist();
    p.id = -1;
    p.name = '我喜欢';
    p.createTime = 0;
    p.updateTime = 0;
    const ids: number[] = [];
    this.localSongs.forEach((s: Song) => {
      if (s.isLiked) {
        ids.push(s.id);
      }
    });
    p.songIds = ids;
    return p;
  }

  getPlaylistById(id: number): Playlist | null {
    for (let i = 0; i < this.playlists.length; i++) {
      if (this.playlists[i].id === id) {
        return this.playlists[i];
      }
    }
    return null;
  }

  /** 歌单内歌曲（过滤已被删除的歌曲；我喜欢按isLiked计算） */
  getPlaylistSongs(pl: Playlist): Song[] {
    const out: Song[] = [];
    if (pl.id === -1) {
      this.localSongs.forEach((s: Song) => {
        if (s.isLiked) {
          out.push(s);
        }
      });
      return out;
    }
    const map: Map<number, Song> = new Map();
    this.localSongs.forEach((s: Song) => {
      map.set(s.id, s);
    });
    pl.songIds.forEach((id: number) => {
      const s: Song | undefined = map.get(id);
      if (s) {
        out.push(s);
      }
    });
    return out;
  }

  // ==================== 收藏 ====================
  toggleLike(song: Song): void {
    song.isLiked = !song.isLiked;
    DbService.getInstance().updateSong(song).then(async () => {
      await this.reloadSongs();
      if (this.player.currentSong() && this.player.currentSong()!.id === song.id) {
        AppStorage.setOrCreate(C.K_LIKED, song.isLiked);
      }
      this.toast(song.isLiked ? '已添加到"我喜欢"' : '已取消收藏');
    }).catch(() => {
      song.isLiked = !song.isLiked;
      this.toast('操作失败，请重试');
    });
  }

  /** 批量收藏 */
  async likeSongs(ids: number[]): Promise<void> {
    for (let i = 0; i < this.localSongs.length; i++) {
      const s: Song = this.localSongs[i];
      if (ids.indexOf(s.id) >= 0 && !s.isLiked) {
        s.isLiked = true;
        await DbService.getInstance().updateSong(s);
      }
    }
    await this.reloadSongs();
    this.toast(`已收藏 ${ids.length} 首歌曲`);
  }

  // ==================== 歌单管理 ====================
  async createPlaylist(name: string): Promise<Playlist> {
    const p: Playlist = new Playlist();
    p.name = name.trim() || `歌单${Date.now() % 1000}`;
    p.createTime = Date.now();
    p.updateTime = Date.now();
    p.id = await DbService.getInstance().insertPlaylist(p);
    await this.reloadPlaylists();
    return p;
  }

  async renamePlaylist(id: number, name: string): Promise<void> {
    const p: Playlist | null = this.getPlaylistById(id);
    if (!p) {
      return;
    }
    p.name = name.trim() || p.name;
    p.updateTime = Date.now();
    await DbService.getInstance().updatePlaylist(p);
    await this.reloadPlaylists();
  }

  async deletePlaylistById(id: number): Promise<void> {
    await DbService.getInstance().deletePlaylistById(id);
    await this.reloadPlaylists();
  }

  async setPlaylistCover(id: number, path: string): Promise<void> {
    const p: Playlist | null = this.getPlaylistById(id);
    if (!p) {
      return;
    }
    p.coverPath = path;
    p.updateTime = Date.now();
    await DbService.getInstance().updatePlaylist(p);
    await this.reloadPlaylists();
  }

  /**
   * 批量添加歌曲到歌单（自动去重）
   * @returns 实际新增数量
   */
  async addSongsToPlaylist(playlistId: number, songIds: number[]): Promise<number> {
    if (playlistId === -1) {
      await this.likeSongs(songIds);
      return songIds.length;
    }
    const p: Playlist | null = this.getPlaylistById(playlistId);
    if (!p) {
      return 0;
    }
    let added: number = 0;
    songIds.forEach((id: number) => {
      if (p.songIds.indexOf(id) < 0) {
        p.songIds.push(id);
        added++;
      }
    });
    if (added > 0) {
      p.updateTime = Date.now();
      await DbService.getInstance().updatePlaylist(p);
      await this.reloadPlaylists();
    }
    return added;
  }

  async removeSongFromPlaylist(playlistId: number, songId: number): Promise<void> {
    const p: Playlist | null = this.getPlaylistById(playlistId);
    if (!p) {
      return;
    }
    p.songIds = p.songIds.filter((x: number) => x !== songId);
    p.updateTime = Date.now();
    await DbService.getInstance().updatePlaylist(p);
    await this.reloadPlaylists();
  }

  // ==================== 播放历史 ====================
  /** 供播放器监听器调用（AppPlayerListener） */
  onSongChanged(song: Song): void {
    AppStorage.setOrCreate(C.K_LIKED, song.isLiked);
    this.recordPlay(song);
    // 主题色跟随封面
    const themeAuto: boolean = PrefsService.getInstance().getBool(C.P_THEME_AUTO, true);
    if (themeAuto) {
      const cover: string = song.coverPath || song.coverUrl;
      if (cover) {
        const cacheDir: string = this.context ? this.context.cacheDir : '';
        ColorUtil.extractDominant(cover, cacheDir).then((c: string) => {
          if (c) {
            AppStorage.setOrCreate(C.K_THEME, c);
          }
        }).catch(() => {});
      } else {
        AppStorage.setOrCreate(C.K_THEME, C.DEFAULT_THEME);
      }
    }
  }

  /** 记录播放历史并累加播放次数（10秒内重复播放不重复记录） */
  private recordPlay(song: Song): void {
    const now: number = Date.now();
    if (song.id === this.lastRecordSongId && now - this.lastRecordTime < 10000) {
      return;
    }
    this.lastRecordSongId = song.id;
    this.lastRecordTime = now;
    DbService.getInstance().insertHistory(song.id).then(async () => {
      this.history = await DbService.getInstance().queryHistory(100);
      this.bump(C.K_HISTV);
    }).catch(() => {});
    song.playCount++;
    DbService.getInstance().updateSong(song).catch(() => {});
  }

  async clearHistory(): Promise<void> {
    await DbService.getInstance().clearHistory();
    this.history = [];
    this.bump(C.K_HISTV);
    this.toast('播放历史已清空');
  }

  // ==================== 音乐库 ====================
  async reloadSongs(): Promise<void> {
    try {
      this.localSongs = await DbService.getInstance().queryAllSongs();
      this.bump(C.K_LIBV);
    } catch (err) {
      // 数据库异常时保留内存数据
    }
  }

  async reloadPlaylists(): Promise<void> {
    try {
      this.playlists = await DbService.getInstance().queryAllPlaylists();
      this.bump(C.K_PLV);
    } catch (err) {
      // 保留内存数据
    }
  }

  /** 重新扫描沙箱音乐目录 */
  async rescanLibrary(): Promise<void> {
    this.toast('正在扫描本地音乐...');
    try {
      const n: number = await LibraryService.getInstance().scanSandbox();
      await this.reloadSongs();
      this.toast(n > 0 ? `扫描完成，新增 ${n} 首歌曲` : '扫描完成，暂无新歌曲');
    } catch (err) {
      this.toast('扫描失败，请重试');
    }
  }

  /** 删除本地歌曲记录 */
  async deleteLocalSong(song: Song): Promise<void> {
    await DbService.getInstance().deleteSongById(song.id);
    await this.reloadSongs();
    this.toast('已从音乐库移除');
  }

  // ==================== 设置 ====================
  /** 深浅色模式：auto/light/dark */
  applyColorMode(mode: string): void {
    PrefsService.getInstance().putStr(C.P_COLOR_MODE, mode);
    if (!this.context) {
      return;
    }
    try {
      const appCtx = this.context.getApplicationContext();
      if (mode === 'dark') {
        appCtx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else if (mode === 'light') {
        appCtx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } else {
        appCtx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
      this.toast(mode === 'dark' ? '已切换为深色模式' : (mode === 'light' ? '已切换为浅色模式' : '已跟随系统'));
    } catch (err) {
      this.toast('切换失败');
    }
  }

  getColorMode(): string {
    return PrefsService.getInstance().getStr(C.P_COLOR_MODE, 'auto');
  }

  /** 设置固定主题色 */
  setFixedTheme(color: string): void {
    PrefsService.getInstance().putBool(C.P_THEME_AUTO, false);
    PrefsService.getInstance().putStr(C.P_THEME_FIXED, color);
    AppStorage.setOrCreate(C.K_THEME, color);
  }

  setThemeAuto(auto: boolean): void {
    PrefsService.getInstance().putBool(C.P_THEME_AUTO, auto);
    if (!auto) {
      AppStorage.setOrCreate(C.K_THEME,
        PrefsService.getInstance().getStr(C.P_THEME_FIXED, C.DEFAULT_THEME));
    }
  }

  // ==================== 通用 ====================
  bump(key: string): void {
    const v: number = (AppStorage.get<number>(key) ?? 0) + 1;
    AppStorage.setOrCreate(key, v);
  }

  toast(msg: string): void {
    promptAction.showToast({ message: msg, duration: 2000 });
  }

  /** 确认对话框：返回是否点击了确定 */
  confirm(title: string, msg: string): Promise<boolean> {
    return new Promise<boolean>((resolve: (v: boolean) => void) => {
      promptAction.showDialog({
        title: title,
        message: msg,
        buttons: [
          { text: '取消', color: $r('app.color.cm_text2') },
          { text: '确定', color: '#E5484D' }
        ]
      }).then((result: promptAction.ShowDialogSuccessResponse) => {
        resolve(result.index === 1);
      }).catch(() => {
        resolve(false);
      });
    });
  }

  /** 操作菜单：返回选中项索引，取消返回-1 */
  actionMenu(title: string, items: string[]): Promise<number> {
    return new Promise<number>((resolve: (v: number) => void) => {
      // buttons为元组类型(最多6项)，需显式构造
      const color: ResourceColor = $r('app.color.cm_text');
      const b0: promptAction.Button = { text: items[0] ?? '', color: color };
      const b1: promptAction.Button = { text: items[1] ?? '', color: color };
      const b2: promptAction.Button = { text: items[2] ?? '', color: color };
      const b3: promptAction.Button = { text: items[3] ?? '', color: color };
      promptAction.showActionMenu({ title: title, buttons: [b0, b1, b2, b3] })
        .then((r: promptAction.ActionMenuSuccessResponse) => {
          resolve(r.index);
        })
        .catch(() => {
          resolve(-1);
        });
    });
  }

  // ==================== 导航 ====================
  pushPage(name: string): void {
    this.navStack.pushPathByName(name, '');
  }

  pushPlayer(): void {
    this.pushPage('Player');
  }

  pushPlaylistDetail(id: number): void {
    this.currentPlaylistId = id;
    this.pushPage('PlaylistDetail');
  }

  /** 打开"添加到歌单"（携带待添加歌曲） */
  pushAddToPlaylist(songIds: number[]): void {
    if (songIds.length === 0) {
      this.toast('请先选择歌曲');
      return;
    }
    this.pendingAddSongIds = songIds;
    this.pushPage('AddToPlaylist');
  }

  /** 打开新建/重命名歌单页 */
  pushCreatePlaylist(editId: number): void {
    this.editPlaylistId = editId;
    this.pushPage('CreatePlaylist');
  }

  /** 打开"选择歌曲加入歌单"页 */
  pushPickSongs(targetPlaylistId: number): void {
    this.pickTargetPlaylistId = targetPlaylistId;
    this.pushPage('PickSongs');
  }
}
