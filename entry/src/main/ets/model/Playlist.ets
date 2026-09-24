/**
 * 歌单实体
 * 对应数据库 playlists 表；songIds 在库中以JSON字符串存储
 * 约定：id = -1 表示虚拟的默认歌单"我喜欢"（不入库）
 */
export class Playlist {
  id: number = 0;
  name: string = '';
  coverPath: string = '';
  songIds: number[] = [];
  createTime: number = 0;
  updateTime: number = 0;
}
