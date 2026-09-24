/**
 * 通用文本输入对话框（新建歌单/重命名等）
 * 通过 InputDialogData 对象传递动态内容（CustomDialog builder参数在创建时固定，
 * 动态值需放在同一对象引用内，open前修改字段即可）
 */
import { C } from '../../common/Constants';

export class InputDialogData {
  title: string = '请输入';
  placeholder: string = '';
  defaultValue: string = '';
}

@CustomDialog
export struct InputDialog {
  controller?: CustomDialogController;
  data: InputDialogData = new InputDialogData();
  onConfirm: (v: string) => void = (_v: string) => {
  };
  @State input: string = '';
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;

  aboutToAppear(): void {
    this.input = this.data.defaultValue;
  }

  build() {
    Column({ space: 18 }) {
      Text(this.data.title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.cm_text'))
        .width('100%')
      TextInput({ text: this.input, placeholder: this.data.placeholder })
        .height(44)
        .fontSize(15)
        .backgroundColor($r('app.color.cm_bg'))
        .onChange((v: string) => {
          this.input = v;
        })
      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .height(40)
          .backgroundColor($r('app.color.cm_divider'))
          .fontColor($r('app.color.cm_text'))
          .onClick(() => {
            this.controller?.close();
          })
        Button('确定')
          .layoutWeight(1)
          .height(40)
          .backgroundColor(this.theme)
          .fontColor('#FFFFFF')
          .onClick(() => {
            const v: string = this.input.trim();
            if (v.length > 0) {
              this.onConfirm(v);
            }
            this.controller?.close();
          })
      }
      .width('100%')
    }
    .padding(20)
    .borderRadius(16)
    .backgroundColor($r('app.color.cm_card'))
    .width('88%')
  }
}
