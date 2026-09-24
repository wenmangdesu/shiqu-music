/**
 * 我的 Tab：用户信息、统计、功能入口、最近播放
 */
import { Song } from '../../model/Song';
import { PlayHistory } from '../../model/PlayHistory';
import { C } from '../../common/Constants';
import { FmtUtil } from '../../utils/FmtUtil';
import { AppModel } from '../../viewmodel/AppModel';
import { PlayerService } from '../../service/PlayerService';
import { SongRow } from '../../view/SongRow';

@Component
export struct MineTab {
  @StorageProp(C.K_HISTV) @Watch('reload') histVersion: number = 0;
  @StorageProp(C.K_LIBV) @Watch('reload') libVersion: number = 0;
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;
  @State recent: Song[] = [];
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
  }

  private async songMenu(s: Song): Promise<void> {
    const items: string[] = ['下一首播放', s.isLiked ? '取消收藏' : '收藏', '添加到歌单'];
    const idx: number = await this.model.actionMenu(s.title, items);
    if (idx === 0) {
      this.player.insertNext(s);
      this.model.toast('将在下一首播放');
    } else if (idx === 1) {
      this.model.toggleLike(s);
    } else if (idx === 2) {
      this.model.pushAddToPlaylist([s.id]);
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
        // 用户卡片
        Row({ space: 14 }) {
          Column() {
            Text('🎧').fontSize(26)
          }
          .width(58)
          .height(58)
          .borderRadius(29)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(`${this.theme}22`)

          Column({ space: 3 }) {
            Text('识曲用户')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.cm_text'))
            Text(`ID: 88888888 · ${C.APP_NAME} v${this.model.versionName}`)
              .fontSize(11)
              .fontColor($r('app.color.cm_text2'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(16)
        .borderRadius(16)
        .backgroundColor($r('app.color.cm_card'))
        .margin({ top: 8 })

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
        .clip(true)

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
