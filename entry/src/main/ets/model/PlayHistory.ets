/**
 * 播放历史实体
 * 对应数据库 play_history 表
 */
export class PlayHistory {
  id: number = 0;
  songId: number = 0;
  /** 播放时间(毫秒时间戳) */
  playTime: number = 0;
}
