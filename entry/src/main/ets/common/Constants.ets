/**
 * 全局常量与共享接口定义
 * 包含：应用信息、AppStorage键名、偏好键名、播放模式、音质定义、均衡器预设、在线API约定等
 */
import { Song } from '../model/Song';

/** 播放器对外暴露的远程控制接口（供AVSession媒体会话调用） */
export interface IPlayerHooks {
  play(): void;
  pause(): void;
  next(): void;
  prev(): void;
  stop(): void;
  seek(ms: number): void;
}

/** 播放器事件监听（供AppModel订阅，实现历史记录/主题色/通知等联动） */
export interface IPlayerListener {
  onSongChange(song: Song): void;
  onQueueChange(): void;
  onPlayError(msg: string): void;
}

/** 音质选项行（下载音质选择弹窗使用） */
export class QualityRow {
  key: string = '';
  label: string = '';
  desc: string = '';
}

export class C {
  // ============ 应用信息 ============
  static readonly APP_NAME: string = '识曲';
  static readonly VERSION: string = '1.0.0';
  /** 主题色：墨蓝（笔记本涂鸦风） */
  static readonly DEFAULT_THEME: string = '#2B3A55';
  /** 红笔强调色（收藏/进度） */
  static readonly ACCENT_RED: string = '#E5484D';
  /** 荧光笔黄（选中高亮） */
  static readonly MARKER: string = '#FFE45C';
  /** 固定主题色备选盘 */
  static readonly THEME_PALETTE: string[] =
    ['#2B3A55', '#E5484D', '#2ECC71', '#4A90E2', '#9B59B6', '#FF9F43'];

  // ============ 本地音乐 ============
  /** 支持的音频格式 */
  static readonly AUDIO_EXTS: string[] = ['mp3', 'flac', 'wav', 'aac', 'ogg', 'm4a'];

  // ============ 在线服务 ============
  /**
   * 在线音乐API基地址（可替换为自己的服务端）
   * 约定的接口：
   *   GET /search?keyword=xxx        -> {"data":[{"id","title","artist","album","duration","url","cover","standardUrl","highUrl","losslessUrl"}]}
   *   GET /lyrics?title=xx&artist=xx -> {"lyrics":"[00:00.00]..."}
   * 请求失败或未配置时，自动回退为内置演示数据（可在线播放的示例曲目）。
   */
  static readonly ONLINE_API_BASE: string = 'https://music-api.example.com';
  /**
   * Jamendo真实曲库（CC授权音乐，免费client_id）
   * 填入后在线搜索优先使用Jamendo（不再回退演示数据）；留空则走自建API/演示数据
   */
  static readonly JAMENDO_CLIENT_ID: string = '4288a021';
  static readonly JAMENDO_API_BASE: string = 'https://api.jamendo.com/v3.0';
  /** LRCLIB公开歌词库（免费无需注册，为在线歌曲匹配LRC歌词） */
  static readonly LRCLIB_API_BASE: string = 'https://lrclib.net';
  /** 演示音源（公开示例曲目，用于功能演示） */
  static readonly DEMO_URL_TPL: string = 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-%d.mp3';
  static readonly HOT_KEYWORDS: string[] =
    ['华语流行', '经典老歌', '轻音乐', '摇滚', '民谣', '电子', '爵士', '钢琴曲', '治愈', '助眠'];

  // ============ 歌曲来源 ============
  static readonly SOURCE_LOCAL: string = 'local';
  static readonly SOURCE_ONLINE: string = 'online';

  // ============ 播放模式 ============
  static readonly PLAY_MODE_SINGLE: number = 0;
  static readonly PLAY_MODE_LIST: number = 1;
  static readonly PLAY_MODE_RANDOM: number = 2;
  static readonly PLAY_MODE_ORDER: number = 3;

  // ============ 音质 ============
  static readonly QUALITY_STANDARD: string = 'standard';
  static readonly QUALITY_HIGH: string = 'high';
  static readonly QUALITY_LOSSLESS: string = 'lossless';

  static qualityLabel(q: string): string {
    if (q === C.QUALITY_HIGH) {
      return '高清 320K';
    }
    if (q === C.QUALITY_LOSSLESS) {
      return '无损 FLAC';
    }
    return '标准 128K';
  }

  static playModeLabel(m: number): string {
    if (m === C.PLAY_MODE_SINGLE) {
      return '单曲循环';
    }
    if (m === C.PLAY_MODE_RANDOM) {
      return '随机播放';
    }
    if (m === C.PLAY_MODE_ORDER) {
      return '顺序播放';
    }
    return '列表循环';
  }

  // ============ 均衡器 ============
  static readonly EQ_FREQS: number[] = [60, 230, 910, 3600, 12000];
  static readonly EQ_PRESETS: string[] = ['流行', '摇滚', '古典', '爵士', '自定义'];
  static readonly EQ_PRESET_BANDS: number[][] = [
    [3, 1, -1, -2, 1],
    [4, 2, -2, -1, 3],
    [2, 0, -1, 0, 3],
    [2, 1, -2, 1, 2],
    [0, 0, 0, 0, 0]
  ];

  // ============ 下载 ============
  static readonly MAX_CONCURRENT: number = 3;
  static readonly DL_DIR: string = 'download';
  static readonly IMPORT_DIR: string = 'imported';
  static readonly COVER_DIR: string = 'covers';
  static readonly LYRIC_DIR: string = 'lyrics';
  static readonly NOTIFY_ID: number = 1001;

  // ============ 下载状态 ============
  static readonly ST_PENDING: string = 'pending';
  static readonly ST_RUNNING: string = 'running';
  static readonly ST_PAUSED: string = 'paused';
  static readonly ST_COMPLETED: string = 'completed';
  static readonly ST_FAILED: string = 'failed';

  static statusLabel(s: string): string {
    if (s === C.ST_RUNNING) {
      return '下载中';
    }
    if (s === C.ST_PAUSED) {
      return '已暂停';
    }
    if (s === C.ST_COMPLETED) {
      return '已完成';
    }
    if (s === C.ST_FAILED) {
      return '失败';
    }
    return '等待中';
  }

  // ============ AppStorage 键名 ============
  static readonly K_PLAYING: string = 'kPlaying';        // 是否正在播放
  static readonly K_POS: string = 'kPosition';           // 当前播放位置(ms)
  static readonly K_DUR: string = 'kDuration';           // 当前歌曲时长(ms)
  static readonly K_SONG: string = 'kCurrentSong';       // 当前歌曲(Song对象)
  static readonly K_LIKED: string = 'kCurrentLiked';     // 当前歌曲是否已收藏
  static readonly K_MODE: string = 'kPlayMode';          // 播放模式
  static readonly K_SPEED: string = 'kSpeed';            // 播放倍速
  static readonly K_THEME: string = 'kThemeColor';       // 主题色
  static readonly K_LIBV: string = 'kLibVersion';        // 本地音乐库版本号(变更刷新)
  static readonly K_PLV: string = 'kPlVersion';          // 歌单版本号
  static readonly K_DLV: string = 'kDlVersion';          // 下载任务版本号
  static readonly K_QUEUEV: string = 'kQueueVersion';    // 播放队列版本号
  static readonly K_HISTV: string = 'kHistVersion';      // 播放历史版本号
  static readonly K_FLOAT: string = 'kFloatLyrics';      // 桌面歌词开关
  static readonly K_USERV: string = 'kUserVersion';      // 登录用户版本号

  // ============ 偏好键名 ============
  static readonly P_COLOR_MODE: string = 'pref_color_mode';      // auto/light/dark
  static readonly P_THEME_AUTO: string = 'pref_theme_auto';      // 主题色跟随封面
  static readonly P_THEME_FIXED: string = 'pref_theme_fixed';    // 固定主题色
  static readonly P_QUALITY: string = 'pref_default_quality';    // 默认下载音质
  static readonly P_EQ_PRESET: string = 'pref_eq_preset';        // 均衡器预设索引
  static readonly P_EQ_BANDS: string = 'pref_eq_bands';          // 均衡器自定义频段(JSON)
  static readonly P_SPEED: string = 'pref_speed';                // 播放倍速
  static readonly P_MODE: string = 'pref_play_mode';             // 播放模式
  static readonly P_FLOAT: string = 'pref_float_lyrics';         // 桌面歌词
  static readonly P_SEARCH_HISTORY: string = 'pref_search_history'; // 搜索历史(JSON数组)
  static readonly P_CONCURRENCY: string = 'pref_dl_concurrency'; // 并发下载数
  static readonly P_LAST_QUEUE: string = 'pref_last_queue';   // 续播记忆：上次队列(filePath数组)
  static readonly P_LAST_INDEX: string = 'pref_last_index';   // 续播记忆：上次播放索引
  static readonly P_LAST_POS: string = 'pref_last_pos';       // 续播记忆：上次播放进度(ms)
  static readonly P_WIFI_ONLY: string = 'pref_wifi_only';     // 仅Wi-Fi网络下载
  static readonly P_USER: string = 'pref_user';               // 登录用户信息(JSON)
  static readonly P_LOCK_ON: string = 'pref_lock_on';         // 应用锁开关
  static readonly P_LOCK_HASH: string = 'pref_lock_hash';     // 应用锁密码的SHA-256
  static readonly P_DEMO_AUDIO: string = 'pref_demo_audio';   // 内置演示音频已解压标记
}
