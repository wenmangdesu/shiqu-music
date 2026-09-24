/**
 * 歌词页：全屏歌词浏览
 * 支持逐行/逐字歌词滚动、当前行高亮、点击歌词跳转播放位置
 */
import { Song } from '../model/Song';
import { C } from '../common/Constants';
import { AppModel } from '../viewmodel/AppModel';
import { PlayerService } from '../service/PlayerService';
import { LyricView } from '../view/LyricView';

@Component
export struct LyricsPage {
  @StorageLink(C.K_SONG) song: Song = new Song();
  @StorageProp(C.K_PLAYING) playing: boolean = false;
  private model: AppModel = AppModel.getInstance();
  private player: PlayerService = PlayerService.getInstance();

  build() {
    NavDestination() {
      Column({ space: 8 }) {
        // 歌曲信息
        Column({ space: 4 }) {
          Text(this.song.title || '未在播放')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
            .fontColor($r('app.color.cm_text'))
          Text(`${this.song.artist || '未知歌手'} · ${this.song.album || '未知专辑'}`)
            .fontSize(12)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontColor($r('app.color.cm_text2'))
        }
        .width('100%')
        .padding({ top: 8 })

        // 歌词滚动区
        LyricView()
          .layoutWeight(1)

        // 底部控制
        Row({ space: 40 }) {
          Text('⏮')
            .fontSize(26)
            .fontColor($r('app.color.cm_text'))
            .onClick(() => {
              this.player.prev();
            })
          Text(this.playing ? '⏸' : '▶')
            .fontSize(26)
            .fontColor('#FFFFFF')
            .width(58)
            .height(58)
            .textAlign(TextAlign.Center)
            .borderRadius(29)
            .backgroundColor(this.modelColor())
            .onClick(() => {
              this.player.togglePlay();
            })
          Text('⏭')
            .fontSize(26)
            .fontColor($r('app.color.cm_text'))
            .onClick(() => {
              this.player.next();
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 6, bottom: 24 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.cm_bg'))
    }
    .title('歌词')
  }

  private modelColor(): string {
    const t: string = AppStorage.get<string>(C.K_THEME) ?? C.DEFAULT_THEME;
    return t;
  }
}
