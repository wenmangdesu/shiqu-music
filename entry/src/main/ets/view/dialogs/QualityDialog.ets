/**
 * 下载音质选择对话框（标准128K / 高清320K / 无损FLAC）
 */
import { Song } from '../../model/Song';
import { C, QualityRow } from '../../common/Constants';
import { FmtUtil } from '../../utils/FmtUtil';

@CustomDialog
export struct QualityDialog {
  controller?: CustomDialogController;
  song: Song = new Song();
  onPick: (q: string) => void = (_q: string) => {
  };
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;

  private rows(): QualityRow[] {
    const out: QualityRow[] = [];
    const hasDur: boolean = this.song.duration > 0;
    const dsec: number = hasDur ? this.song.duration / 1000 : 240;
    const mk = (key: string, label: string, kbps: number): QualityRow => {
      const r: QualityRow = new QualityRow();
      r.key = key;
      r.label = label;
      r.desc = hasDur ? `预计约 ${FmtUtil.fmtSize(Math.floor(dsec * kbps * 1000 / 8))}` : '音质选项';
      return r;
    };
    out.push(mk(C.QUALITY_STANDARD, C.qualityLabel(C.QUALITY_STANDARD), 128));
    out.push(mk(C.QUALITY_HIGH, C.qualityLabel(C.QUALITY_HIGH), 320));
    out.push(mk(C.QUALITY_LOSSLESS, C.qualityLabel(C.QUALITY_LOSSLESS), 900));
    return out;
  }

  build() {
    Column({ space: 6 }) {
      Text('选择下载音质')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.cm_text'))
        .width('100%')
        .padding({ bottom: 6 })
      ForEach(this.rows(), (r: QualityRow) => {
        Row({ space: 12 }) {
          Column({ space: 2 }) {
            Text(r.label)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.cm_text'))
            Text(r.desc)
              .fontSize(11)
              .fontColor($r('app.color.cm_text2'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text('下载')
            .fontSize(13)
            .fontColor('#FFFFFF')
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .borderRadius(14)
            .backgroundColor(this.theme)
        }
        .width('100%')
        .padding(12)
        .borderRadius(12)
        .backgroundColor($r('app.color.cm_bg'))
        .margin({ top: 6 })
        .onClick(() => {
          this.onPick(r.key);
          this.controller?.close();
        })
      }, (r: QualityRow) => r.key)
    }
    .padding(20)
    .borderRadius(16)
    .backgroundColor($r('app.color.cm_card'))
    .border({ width: 2, color: $r('app.color.cm_text') })
    .width('88%')
  }
}
