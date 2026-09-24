/**
 * 歌曲列表行组件
 * 支持三种形态：普通播放行 / 序号行 / 多选行；当前播放歌曲高亮
 */
import { Song } from '../model/Song';
import { C } from '../common/Constants';
import { FmtUtil } from '../utils/FmtUtil';
import { CoverImage } from './CoverImage';

@Component
export struct SongRow {
  song: Song = new Song();
  index: number = 0;
  showIndex: boolean = false;
  showDuration: boolean = true;
  selectMode: boolean = false;
  selected: boolean = false;
  onPlay: (s: Song) => void = (_s: Song) => {
  };
  onMore: (s: Song) => void = (_s: Song) => {
  };
  onSelect: (s: Song) => void = (_s: Song) => {
  };

  @StorageLink(C.K_SONG) currentSong: Song = new Song();
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;

  private isCurrent(): boolean {
    return this.currentSong.id === this.song.id && this.currentSong.filePath === this.song.filePath;
  }

  build() {
    Row({ space: 10 }) {
      if (this.selectMode) {
        Text(this.selected ? '✓' : '')
          .fontSize(13)
          .width(22)
          .height(22)
          .borderRadius(11)
          .textAlign(TextAlign.Center)
          .fontColor('#FFFFFF')
          .backgroundColor(this.selected ? this.theme : Color.Transparent)
          .border({ width: 1.5, color: this.selected ? this.theme : $r('app.color.cm_divider') })
          .onClick(() => {
            this.onSelect(this.song);
          })
      } else if (this.showIndex) {
        Text(`${this.index + 1}`)
          .fontSize(13)
          .fontColor(this.isCurrent() ? this.theme : $r('app.color.cm_text2'))
          .width(22)
          .textAlign(TextAlign.Center)
      }
      CoverImage({
        coverPath: this.song.coverPath,
        coverUrl: this.song.coverUrl,
        imgSize: 46,
        radius: 6
      })
      Column({ space: 3 }) {
        Text(this.song.title)
          .fontSize(15)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(this.isCurrent() ? this.theme : $r('app.color.cm_text'))
          .fontWeight(this.isCurrent() ? FontWeight.Bold : FontWeight.Normal)
        Text(`${this.song.artist} · ${this.song.album}`)
          .fontSize(12)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor($r('app.color.cm_text2'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.showDuration) {
        Text(FmtUtil.fmtDuration(this.song.duration))
          .fontSize(12)
          .fontColor($r('app.color.cm_text2'))
      }
      Text('⋮')
        .fontSize(20)
        .fontColor($r('app.color.cm_text2'))
        .width(30)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.onMore(this.song);
        })
    }
    .width('100%')
    .padding({ left: 12, right: 4, top: 6, bottom: 6 })
    .borderRadius(10)
    .backgroundColor(this.isCurrent() ? `${this.theme}14` : Color.Transparent)
    .onClick(() => {
      if (this.selectMode) {
        this.onSelect(this.song);
      } else {
        this.onPlay(this.song);
      }
    })
  }
}
