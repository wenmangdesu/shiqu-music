/**
 * 我的 Tab：用户信息（登录/Mock）、统计、本地热歌榜、功能入口、最近播放
 */
import { Song } from '../../model/Song';
import { PlayHistory } from '../../model/PlayHistory';
import { C } from '../../common/Constants';
import { FmtUtil } from '../../utils/FmtUtil';
import { AppModel } from '../../viewmodel/AppModel';
import { PlayerService } from '../../service/PlayerService';
import { UserService, UserInfo } from '../../service/UserService';
import { SongRow } from '../../view/SongRow';

@Component
export struct MineTab {
  @StorageProp(C.K_HISTV) @Watch('reload') histVersion: number = 0;
  @StorageProp(C.K_LIBV) @Watch('reload') libVersion: number = 0;
  @StorageProp(C.K_USERV) @Watch('reload') userVersion: number = 0;
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;
  @State recent: Song[] = [];
  @State user?: UserInfo = undefined;
  @State topSongs: Song[] = [];
  @State weekCount: number = 0;
  @State totalCount: number = 0;
  @State topArtist: string = '—';
  private model: AppModel = AppModel.getInstance();
  private player: PlayerService = PlayerService.getInstance();

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    // 按最近播放时间排序映射为歌曲（去重）
    const map: Map<number, Song> = new Map();
    this.model.localSongs.forEach((s: Song) => {
      map.set(s.id, s);
    });
    const out: Song[] = [];
    const seen: Set<number> = new Set();
    this.model.history.forEach((h: PlayHistory) => {
      if (!seen.has(h.songId)) {
        const s: Song | undefined = map.get(h.songId);
        if (s) {
          out.push(s);
          seen.add(h.songId);
        }
      }
    });
    this.recent = out;
    // 播放统计：本周/累计
    const weekAgo: number = Date.now() - 7 * 24 * 3600 * 1000;
    let week: number = 0;
    let total: number = 0;
    this.model.history.forEach((h: PlayHistory) => {
      total++;
      if (h.playTime >= weekAgo) {
        week++;
      }
    });
    this.weekCount = week;
    this.totalCount = total;
    // 最常听歌手（按播放次数求和）
    const amap: Map<string, number> = new Map();
    this.model.localSongs.forEach((s: Song) => {
      if (s.playCount > 0) {
        const key: string = s.artist || '未知歌手';
        amap.set(key, (amap.get(key) ?? 0) + s.playCount);
      }
    });
    let best: string = '—';
    let bestN: number = 0;
    amap.forEach((v: number, k: string) => {
      if (v > bestN) {
        bestN = v;
        best = k;
      }
    });
    this.topArtist = best;
    // 本地热歌榜（播放次数TOP5）
    const hot: Song[] = this.model.localSongs.filter((s: Song) => s.playCount > 0)
      .sort((a: Song, b: Song) => b.playCount - a.playCount)
      .slice(0, 5);
    this.topSongs = hot;
    // 登录用户
    this.user = UserService.getInstance().user;
  }

  private async songMenu(s: Song): Promise<void> {
    const items: string[] =
      ['下一首播放', s.isLiked ? '取消收藏' : '收藏', '添加到歌单', '查看歌手/专辑', '分享'];
    const idx: number = await this.model.actionMenu(s.title, items);
    if (idx === 0) {
      this.player.insertNext(s);
      this.model.toast('将在下一首播放');
    } else if (idx === 1) {
      this.model.toggleLike(s);
    } else if (idx === 2) {
      this.model.pushAddToPlaylist([s.id]);
    } else if (idx === 3) {
      const which: number = await this.model.actionMenu('查看',
        [`歌手：${s.artist || '未知歌手'}`, `专辑：${s.album || '未知专辑'}`]);
      if (which === 0) {
        this.model.pushMusicGroup('artist', s.artist || '未知歌手');
      } else if (which === 1) {
        this.model.pushMusicGroup('album', s.album || '未知专辑');
      }
    } else if (idx === 4) {
      this.model.shareSong(s);
    }
  }

  @Builder
  entryRow(icon: string, label: string, onTap: () => void) {
    Row({ space: 12 }) {
      Text(icon).fontSize(18)
      Text(label).fontSize(15).fontColor($r('app.color.cm_text')).layoutWeight(1)
      Text('›').fontSize(18).fontColor($r('app.color.cm_text2'))
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 13, bottom: 13 })
    .onClick(() => {
      onTap();
    })
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        // 用户卡片（登录后可点击编辑资料）
        Row({ space: 14 }) {
          if (this.user && this.user.avatar) {
            Image(`file://${this.user.avatar}`)
              .width(58)
              .height(58)
              .borderRadius(29)
              .objectFit(ImageFit.Cover)
              .border({ width: 2, color: $r('app.color.cm_text') })
          } else {
            Column() {
              Text('🎧').fontSize(26)
            }
            .width(58)
            .height(58)
            .borderRadius(29)
            .justifyContent(FlexAlign.Center)
            .backgroundColor('#EFE9D8')
            .border({ width: 2, color: $r('app.color.cm_text') })
          }

          if (this.user) {
            Column({ space: 3 }) {
              Text(this.user.nickname || this.user.username)
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.cm_text'))
              Text(`UID: ${this.user.username} · ${C.APP_NAME} v${this.model.versionName}`)
                .fontSize(11)
                .fontColor($r('app.color.cm_text2'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Text('›').fontSize(20).fontColor($r('app.color.cm_text2'))
          } else {
            Column({ space: 3 }) {
              Text('未登录')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.cm_text'))
              Text('登录后可自定义昵称与头像')
                .fontSize(11)
                .fontColor($r('app.color.cm_text2'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Button('登录')
              .height(34)
              .fontSize(13)
              .backgroundColor($r('app.color.cm_marker'))
              .fontColor('#2B3A55')
              .border({ width: 2, color: $r('app.color.cm_text') })
              .onClick(() => {
                this.model.pushPage('Login');
              })
          }
        }
        .width('100%')
        .padding(16)
        .borderRadius(16)
        .backgroundColor($r('app.color.cm_card'))
        .border({ width: 2, color: $r('app.color.cm_text') })
        .margin({ top: 8 })
        .onClick(() => {
          if (this.user) {
            this.model.pushPage('Profile');
          } else {
            this.model.pushPage('Login');
          }
        })

        // 数据统计
        Row() {
          Column({ space: 4 }) {
            Text(FmtUtil.fmtCount(this.model.localSongs.length))
              .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.theme)
            Text('本地歌曲').fontSize(11).fontColor($r('app.color.cm_text2'))
          }.layoutWeight(1)
          Divider().vertical(true).height(26).color($r('app.color.cm_divider'))
          Column({ space: 4 }) {
            Text(FmtUtil.fmtCount(this.model.playlists.length))
              .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.theme)
            Text('自建歌单').fontSize(11).fontColor($r('app.color.cm_text2'))
          }.layoutWeight(1)
          Divider().vertical(true).height(26).color($r('app.color.cm_divider'))
          Column({ space: 4 }) {
            Text(FmtUtil.fmtCount(this.model.likedPlaylist().songIds.length))
              .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.theme)
            Text('收藏歌曲').fontSize(11).fontColor($r('app.color.cm_text2'))
          }.layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 14, bottom: 14 })
        .borderRadius(16)
        .backgroundColor($r('app.color.cm_card'))
        .border({ width: 2, color: $r('app.color.cm_text') })

        // 播放统计
        Row() {
          Column({ space: 4 }) {
            Text(FmtUtil.fmtCount(this.weekCount))
              .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.theme)
            Text('本周播放').fontSize(11).fontColor($r('app.color.cm_text2'))
          }.layoutWeight(1)
          Divider().vertical(true).height(26).color($r('app.color.cm_divider'))
          Column({ space: 4 }) {
            Text(FmtUtil.fmtCount(this.totalCount))
              .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.theme)
            Text('累计播放').fontSize(11).fontColor($r('app.color.cm_text2'))
          }.layoutWeight(1)
          Divider().vertical(true).height(26).color($r('app.color.cm_divider'))
          Column({ space: 4 }) {
            Text(this.topArtist)
              .fontSize(13).fontWeight(FontWeight.Bold).fontColor(this.theme)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('最常听歌手').fontSize(11).fontColor($r('app.color.cm_text2'))
          }.layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 14, bottom: 14 })
        .borderRadius(16)
        .backgroundColor($r('app.color.cm_card'))
        .border({ width: 2, color: $r('app.color.cm_text') })

        // 功能入口
        Column() {
          this.entryRow('♥', '我的收藏', (): void => {
            this.model.pushPlaylistDetail(-1);
          })
          Divider().color($r('app.color.cm_divider')).margin({ left: 44 })
          this.entryRow('⬇', '下载管理', (): void => {
            this.model.pushPage('Download');
          })
          Divider().color($r('app.color.cm_divider')).margin({ left: 44 })
          this.entryRow('⚙', '设置', (): void => {
            this.model.pushPage('Settings');
          })
        }
        .width('100%')
        .borderRadius(16)
        .backgroundColor($r('app.color.cm_card'))
        .border({ width: 2, color: $r('app.color.cm_text') })
        .clip(true)

        // 本地热歌榜
        if (this.topSongs.length > 0) {
          Column({ space: 6 }) {
            Row({ space: 8 }) {
              Text('🔥 本地热歌榜')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.cm_text'))
                .layoutWeight(1)
              Text('按播放次数')
                .fontSize(10)
                .fontColor($r('app.color.cm_text2'))
            }
            .width('100%')

            ForEach(this.topSongs, (s: Song, i: number) => {
              Row({ space: 10 }) {
                Text(`${i + 1}`)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(i < 3 ? $r('app.color.cm_accent') : $r('app.color.cm_text2'))
                  .width(22)
                  .textAlign(TextAlign.Center)
                Column({ space: 2 }) {
                  Text(s.title)
                    .fontSize(14)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .fontColor($r('app.color.cm_text'))
                  Text(`${s.artist} · 播放${s.playCount}次`)
                    .fontSize(10)
                    .fontColor($r('app.color.cm_text2'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding({ top: 6, bottom: 6 })
              .onClick(() => {
                this.player.setQueue(this.topSongs, i);
              })
            }, (s: Song) => `${this.histVersion}_${s.id}_${s.playCount}`)
          }
          .width('100%')
          .padding(14)
          .borderRadius(16)
          .backgroundColor($r('app.color.cm_card'))
          .border({ width: 2, color: $r('app.color.cm_text') })
        }

        // 最近播放
        Row({ space: 10 }) {
          Text('🕘 最近播放')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.cm_text'))
            .layoutWeight(1)
          Text('清空')
            .fontSize(13)
            .fontColor($r('app.color.cm_text2'))
            .onClick(async (): Promise<void> => {
              const ok: boolean = await this.model.confirm('清空历史', '确定清空全部播放历史吗？');
              if (ok) {
                this.model.clearHistory();
              }
            })
        }
        .width('100%')
        .padding({ left: 4, right: 4 })

        if (this.recent.length === 0) {
          Text('暂无播放记录')
            .fontSize(12)
            .fontColor($r('app.color.cm_text2'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 16, bottom: 30 })
        } else {
          Column({ space: 2 }) {
            ForEach(this.recent.slice(0, 30), (s: Song, i: number) => {
              SongRow({
                song: s,
                index: i,
                onPlay: (x: Song): void => {
                  const idx: number = this.recent.indexOf(x);
                  this.player.setQueue(this.recent, idx >= 0 ? idx : 0);
                },
                onMore: (x: Song): void => {
                  this.songMenu(x);
                }
              })
            }, (s: Song) => `${this.histVersion}_${s.id}`)
          }
          .width('100%')
        }
      }
      .padding({ left: 16, right: 16, bottom: 24 })
      .constraintSize({ maxWidth: 720 })
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
  }
}
