/**
 * 歌词视图组件
 * 功能：逐行歌词滚动 + 当前行高亮 + 逐字卡拉OK渲染（增强LRC） + 点击歌词跳转播放位置
 */
import { Song } from '../model/Song';
import { C } from '../common/Constants';
import { LrcData, LrcLine, LrcParser } from '../utils/LrcParser';
import { LyricsService } from '../service/LyricsService';
import { PlayerService } from '../service/PlayerService';

@Component
export struct LyricView {
  @StorageLink(C.K_SONG) @Watch('onSongChange') song: Song = new Song();
  @StorageProp(C.K_POS) @Watch('onPos') pos: number = 0;
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;
  @State lines: LrcLine[] = [];
  @State enhanced: boolean = false;
  @State curIdx: number = -1;
  @State loading: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.load();
  }

  private onSongChange(): void {
    this.load();
  }

  private load(): void {
    const song: Song = this.song;
    this.loading = true;
    this.lines = [];
    this.curIdx = -1;
    LyricsService.getInstance().getLyrics(song).then((text: string) => {
      const data: LrcData = LrcParser.parse(text);
      this.lines = data.lines;
      this.enhanced = data.enhanced;
      this.loading = false;
      // 定位到当前行
      const idx: number = LrcParser.findIndex(this.lines, this.pos);
      if (idx >= 0) {
        this.curIdx = idx;
        this.scroller.scrollToIndex(idx, false, ScrollAlign.CENTER);
      }
    }).catch(() => {
      this.loading = false;
    });
  }

  private onPos(): void {
    if (this.lines.length === 0) {
      return;
    }
    const idx: number = LrcParser.findIndex(this.lines, this.pos);
    if (idx !== this.curIdx) {
      this.curIdx = idx;
      if (idx >= 0) {
        this.scroller.scrollToIndex(idx, true, ScrollAlign.CENTER);
      }
    }
  }

  /** 逐字歌词：已唱部分 */
  private sungPart(l: LrcLine): string {
    let s: string = '';
    for (let i = 0; i < l.words.length; i++) {
      if (this.pos >= l.words[i].start) {
        s += l.words[i].text;
      } else {
        break;
      }
    }
    return s;
  }

  build() {
    Stack() {
      if (this.loading) {
        LoadingProgress().width(36).height(36).color(this.theme)
      } else if (this.lines.length === 0) {
        Column({ space: 10 }) {
          Text('♪').fontSize(40).fontColor(this.theme)
          Text('暂无歌词，尽情欣赏音乐')
            .fontSize(14)
            .fontColor($r('app.color.cm_text2'))
        }
      } else {
        List({ scroller: this.scroller, space: 18 }) {
          ForEach(this.lines, (l: LrcLine, i: number) => {
            ListItem() {
              this.lineItem(l, i)
            }
          }, (l: LrcLine, i: number) => `${i}_${l.time}`)
        }
        .width('100%')
        .height('100%')
        .padding({ top: 140, bottom: 140, left: 24, right: 24 })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  lineItem(l: LrcLine, i: number) {
    Column() {
      if (this.enhanced && i === this.curIdx && l.words.length > 0) {
        // 逐字歌词：已唱部分高亮为主题色
        Text() {
          Span(this.sungPart(l)).fontColor(this.theme)
          Span(l.text.substring(this.sungPart(l).length)).fontColor($r('app.color.cm_text2'))
        }
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Center)
        .width('100%')
      } else {
        Text(l.text)
          .fontSize(i === this.curIdx ? 20 : 15)
          .fontColor(i === this.curIdx ? this.theme : $r('app.color.cm_text2'))
          .fontWeight(i === this.curIdx ? FontWeight.Bold : FontWeight.Normal)
          .textAlign(TextAlign.Center)
          .width('100%')
      }
    }
    .width('100%')
    .opacity(i === this.curIdx ? 1 : 0.8)
    .onClick(() => {
      // 点击歌词跳转到对应播放位置
      PlayerService.getInstance().seek(l.time);
    })
  }
}
