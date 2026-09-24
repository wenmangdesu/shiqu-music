/**
 * 下载任务实体
 * 对应数据库 download_tasks 表
 */
export class DownloadTask {
  id: number = 0;
  /** 下载完成后入库的歌曲id，未完成时为0 */
  songId: number = 0;
  title: string = '';
  artist: string = '';
  /** 下载地址 */
  url: string = '';
  /** 保存文件名 */
  fileName: string = '';
  /** 完整保存路径 */
  filePath: string = '';
  /** 已接收字节数 */
  received: number = 0;
  /** 文件总字节数，0表示未知 */
  total: number = 0;
  /** 进度百分比 0-100 */
  progress: number = 0;
  /** 状态：pending/running/paused/completed/failed */
  status: string = 'pending';
  /** 实时速度(字节/秒) */
  speed: number = 0;
  /** 音质：standard/high/lossless */
  quality: string = 'standard';
  /** 失败信息 */
  errMsg: string = '';
  /** 创建时间 */
  createTime: number = 0;
}
