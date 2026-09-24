/**
 * 底部迷你播放条（常驻首页）
 * 显示当前歌曲封面/标题/进度，支持点击进入播放页、播放暂停、下一首
 */
import { Song } from '../model/Song';
import { C } from '../common/Constants';
import { FmtUtil } from '../utils/FmtUtil';
import { AppModel } from '../viewmodel/AppModel';
import { PlayerService } from '../service/PlayerService';
import { CoverImage } from './CoverImage';

@Component
export struct MiniPlayerBar {
  @StorageLink(C.K_SONG) song: Song = new Song();
  @StorageProp(C.K_PLAYING) playing: boolean = false;
  @StorageProp(C.K_POS) pos: number = 0;
  @StorageProp(C.K_DUR) dur: number = 0;
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;

  build() {
    Stack() {
      if (this.song.id !== 0 || this.song.title !== '') {
        Column() {
          // 细进度条（红笔）
          Progress({
            value: this.dur > 0 ? Math.min(100, this.pos / this.dur * 100) : 0,
            total: 100,
            type: ProgressType.Linear
          })
            .style({ strokeWidth: 2 })
            .width('100%')
            .color($r('app.color.cm_accent'))
          Row({ space: 10 }) {
            CoverImage({
              coverPath: this.song.coverPath,
              coverUrl: this.song.coverUrl,
              imgSize: 42,
              radius: 8
            })
            Column({ space: 2 }) {
              Text(this.song.title)
                .fontSize(14)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .fontColor($r('app.color.cm_text'))
              Text(`${this.song.artist || '未知歌手'} · ${FmtUtil.fmtDuration(this.song.duration)}`)
                .fontSize(11)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .fontColor($r('app.color.cm_text2'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .onClick(() => {
              AppModel.getInstance().pushPlayer();
            })

            Text(this.playing ? '⏸' : '▶')
              .fontSize(24)
              .fontColor($r('app.color.cm_text'))
              .padding({ left: 6, right: 6 })
              .onClick(() => {
                PlayerService.getInstance().togglePlay();
              })
            Text('⏭')
              .fontSize(20)
              .fontColor($r('app.color.cm_text'))
              .padding({ left: 4, right: 4 })
              .onClick(() => {
                PlayerService.getInstance().next();
              })
          }
          .width('100%')
          .padding({ left: 12, right: 14, top: 6, bottom: 8 })
          .onClick(() => {
            AppModel.getInstance().pushPlayer();
          })
        }
        .width('100%')
        .backgroundColor($r('app.color.cm_card'))
        .borderRadius({ topLeft: 14, topRight: 14 })
        .border({ width: 2, color: $r('app.color.cm_text') })
        .shadow({ radius: 12, color: '#22000000', offsetY: -2 })
      } else {
        Blank().height(0)
      }
    }
    .width('100%')
  }
}
