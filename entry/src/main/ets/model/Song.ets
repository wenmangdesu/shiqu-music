/**
 * 歌曲实体
 * 对应数据库 songs 表（qStd/qHigh/qLossless 为在线歌曲的音质地址，不入库）
 */
export class Song {
  id: number = 0;
  /** 歌曲名 */
  title: string = '';
  /** 歌手 */
  artist: string = '';
  /** 专辑 */
  album: string = '';
  /** 时长(毫秒) */
  duration: number = 0;
  /** 文件路径（本地为沙箱绝对路径，在线为URL） */
  filePath: string = '';
  /** 网络封面地址 */
  coverUrl: string = '';
  /** 本地封面文件路径（从音频元数据中提取） */
  coverPath: string = '';
  /** 文件大小(字节) */
  fileSize: number = 0;
  /** 比特率(kbps)，0表示未知 */
  bitrate: number = 0;
  /** 音频格式：mp3/flac/wav/aac/ogg/m4a */
  format: string = '';
  /** 来源：local-本地 / online-在线 */
  source: string = 'local';
  /** 歌词文件路径 */
  lyricsPath: string = '';
  /** 是否已收藏(我喜欢) */
  isLiked: boolean = false;
  /** 播放次数 */
  playCount: number = 0;
  /** 添加时间(毫秒时间戳) */
  addedTime: number = 0;
  /** 在线-标准音质地址 */
  qStd: string = '';
  /** 在线-高清音质地址 */
  qHigh: string = '';
  /** 在线-无损音质地址 */
  qLossless: string = '';
}
