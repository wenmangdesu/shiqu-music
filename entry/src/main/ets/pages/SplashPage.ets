/**
 * 启动页：笔记本涂鸦风
 * 作业本纸张 + 涂鸦图标 + 版本信息；等待初始化完成后进入主页
 */
import { router } from '@kit.ArkUI';
import { C } from '../common/Constants';
import { AppModel } from '../viewmodel/AppModel';

@Entry
@Component
struct SplashPage {
  @State dotIdx: number = 0;
  private jumped: boolean = false;
  private animId: number = -1;
  private backId: number = -1;

  aboutToAppear(): void {
    // 加载点动画
    this.animId = setInterval(() => {
      this.dotIdx = (this.dotIdx + 1) % 3;
    }, 380);
    // 等待初始化完成（数据库/播放器/下载恢复/媒体库扫描）
    const delay: Promise<void> = new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, 2200);
    });
    Promise.race([AppModel.getInstance().readyPromise, delay]).then(() => {
      this.jump();
    });
    // 兜底跳转
    this.backId = setTimeout(() => {
      this.jump();
    }, 4000);
  }

  aboutToDisappear(): void {
    clearInterval(this.animId);
    clearTimeout(this.backId);
  }

  private jump(): void {
    if (this.jumped) {
      return;
    }
    this.jumped = true;
    router.replaceUrl({ url: 'pages/Index' }).catch(() => {
      // 跳转失败保持当前页
    });
  }

  build() {
    Stack() {
      // 作业本横线
      Column() {
        ForEach([1, 2, 3, 4, 5, 6, 7, 8], (n: number) => {
          Divider()
            .color($r('app.color.cm_line'))
            .strokeWidth(2)
            .margin({ top: 52 })
        }, (n: number) => `rule_${n}`)
      }
      .width('100%')
      .height('100%')

      // 红色边线
      Row()
        .width(26)
        .height('100%')
        .backgroundColor('#F2A9A9')
        .position({ x: 34, y: 0 })

      Column({ space: 14 }) {
        // 涂鸦图标
        Image($r('app.media.startIcon'))
          .width(120)
          .height(120)
          .borderRadius(24)
          .border({ width: 3, color: $r('app.color.cm_text') })
          .shadow({ radius: 18, color: '#33000000', offsetY: 6 })

        Text(C.APP_NAME)
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.cm_text'))
        Text('不识字，但识曲')
          .fontSize(14)
          .fontColor($r('app.color.cm_text2'))
        Text(`版本 ${C.VERSION} · HarmonyOS`)
          .fontSize(12)
          .fontColor($r('app.color.cm_text2'))
          .margin({ top: 4 })

        // 加载指示点（红笔）
        Row({ space: 6 }) {
          ForEach([0, 1, 2], (i: number) => {
            Circle()
              .width(7)
              .height(7)
              .fill(this.dotIdx === i ? '#E5484D' : $r('app.color.cm_divider'))
          }, (i: number) => `${i}`)
        }
        .margin({ top: 12 })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.cm_bg'))
  }
}
