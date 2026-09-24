/**
 * 歌手/专辑详情页
 * 展示本地音乐库中该歌手/专辑的全部歌曲，支持播放全部与歌曲菜单
 */
import { Song } from '../model/Song';
import { C } from '../common/Constants';
import { AppModel } from '../viewmodel/AppModel';
import { PlayerService } from '../service/PlayerService';
import { SongRow } from '../view/SongRow';

@Component
export struct MusicGroupPage {
  @StorageProp(C.K_LIBV) @Watch('reload') libVersion: number = 0;
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;
  @State songs: Song[] = [];
  private model: AppModel = AppModel.getInstance();
  private player: PlayerService = PlayerService.getInstance();

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    const isArtist: boolean = this.model.groupType === 'artist';
    const name: string = this.model.groupName;
    const out: Song[] = [];
    this.model.localSongs.forEach((s: Song) => {
      const key: string = isArtist ? (s.artist || '未知歌手') : (s.album || '未知专辑');
      if (key === name) {
        out.push(s);
      }
    });
    this.songs = out;
  }

  private async songMenu(s: Song): Promise<void> {
    const items: string[] = ['下一首播放', s.isLiked ? '取消收藏' : '收藏', '添加到歌单', '分享'];
    const idx: number = await this.model.actionMenu(s.title, items);
    if (idx === 0) {
      this.player.insertNext(s);
      this.model.toast('将在下一首播放');
    } else if (idx === 1) {
      this.model.toggleLike(s);
    } else if (idx === 2) {
      this.model.pushAddToPlaylist([s.id]);
    } else if (idx === 3) {
      this.model.shareSong(s);
    }
  }

  build() {
    NavDestination() {
      Column() {
        // 头部
        Row({ space: 14 }) {
          Column() {
            Text(this.model.groupType === 'artist' ? '🎤' : '💿').fontSize(28)
          }
          .width(76)
          .height(76)
          .borderRadius(12)
          .justifyContent(FlexAlign.Center)
          .backgroundColor($r('app.color.cm_marker'))
          .border({ width: 2, color: $r('app.color.cm_text') })

          Column({ space: 4 }) {
            Text(this.model.groupName || '未知')
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor($r('app.color.cm_text'))
            Text(`${this.model.groupType === 'artist' ? '歌手' : '专辑'} · ${this.songs.length}首歌曲`)
              .fontSize(11)
              .fontColor($r('app.color.cm_text2'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })

        // 播放全部
        Row({ space: 10 }) {
          Button('▶ 播放全部')
            .height(38)
            .fontSize(14)
            .backgroundColor(this.theme)
            .fontColor('#FFFFFF')
            .onClick(() => {
              if (this.songs.length === 0) {
                this.model.toast('还没有歌曲');
                return;
              }
              this.player.setQueue(this.songs, 0);
            })
          Blank()
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })

        // 歌曲列表
        if (this.songs.length === 0) {
          Column({ space: 10 }) {
            Text('🎼').fontSize(40)
            Text('本地音乐库中没有相关歌曲')
              .fontSize(12)
              .fontColor($r('app.color.cm_text2'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 2 }) {
            ForEach(this.songs, (s: Song, i: number) => {
              ListItem() {
                SongRow({
                  song: s,
                  index: i,
                  onPlay: (x: Song): void => {
                    const idx: number = this.songs.indexOf(x);
                    this.player.setQueue(this.songs, idx >= 0 ? idx : 0);
                  },
                  onMore: (x: Song): void => {
                    this.songMenu(x);
                  }
                })
              }
            }, (s: Song) => `${this.libVersion}_${s.id}`)
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Auto)
          .padding({ left: 8, right: 8 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.cm_bg'))
      .constraintSize({ maxWidth: 760 })
    }
    .title(this.model.groupName || '详情')
  }
}
