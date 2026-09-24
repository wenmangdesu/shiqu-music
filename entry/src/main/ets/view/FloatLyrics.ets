/**
 * 桌面歌词悬浮层（应用内悬浮窗）
 * 可拖拽移动，实时显示当前歌词行，可在设置/播放页开关
 * 说明：跨应用悬浮窗需要系统级权限(SYSTEM_FLOAT_WINDOW)，此处实现为应用内悬浮展示
 */
import { Song } from '../model/Song';
import { C } from '../common/Constants';
import { LrcData, LrcLine, LrcParser } from '../utils/LrcParser';
import { LyricsService } from '../service/LyricsService';
import { PrefsService } from '../service/PrefsService';

@Component
export struct FloatLyrics {
  @StorageLink(C.K_SONG) @Watch('onSongChange') song: Song = new Song();
  @StorageProp(C.K_POS) @Watch('onPos') pos: number = 0;
  @State lines: LrcLine[] = [];
  @State curText: string = '桌面歌词已开启';
  @State ox: number = 0;
  @State oy: number = 0;
  private baseX: number = 0;
  private baseY: number = 0;

  aboutToAppear(): void {
    this.load();
  }

  private onSongChange(): void {
    this.load();
  }

  private load(): void {
    LyricsService.getInstance().getLyrics(this.song).then((text: string) => {
      const d: LrcData = LrcParser.parse(text);
      this.lines = d.lines;
      this.updateText();
    }).catch(() => {
      this.lines = [];
    });
  }

  private onPos(): void {
    this.updateText();
  }

  private updateText(): void {
    if (this.lines.length === 0) {
      return;
    }
    const idx: number = LrcParser.findIndex(this.lines, this.pos);
    if (idx >= 0 && idx !== this.curIdxCache) {
      this.curIdxCache = idx;
      this.curText = this.lines[idx].text;
    }
  }

  private curIdxCache: number = -1;

  build() {
    Column({ space: 4 }) {
      Row() {
        Text('桌面歌词')
          .fontSize(10)
          .fontColor('#AAFFFFFF')
        Blank()
        Text('✕')
          .fontSize(13)
          .fontColor('#FFFFFF')
          .onClick(() => {
            AppStorage.setOrCreate(C.K_FLOAT, false);
            PrefsService.getInstance().putBool(C.P_FLOAT, false);
          })
      }
      .width('100%')

      Text(this.curText)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.MARQUEE })
        .width('100%')
    }
    .padding({ left: 14, right: 14, top: 8, bottom: 10 })
    .backgroundColor('#B3000000')
    .borderRadius(20)
    .width(280)
    .margin({ top: 90 })
    .offset({ x: this.ox, y: this.oy })
    .shadow({ radius: 16, color: '#44000000' })
    .gesture(PanGesture({ fingers: 1, direction: PanDirection.All, distance: 5 })
      .onActionStart((e: GestureEvent) => {
        this.baseX = this.ox;
        this.baseY = this.oy;
      })
      .onActionUpdate((e: GestureEvent) => {
        this.ox = this.baseX + e.offsetX;
        this.oy = Math.max(-60, this.baseY + e.offsetY);
      }))
  }
}
