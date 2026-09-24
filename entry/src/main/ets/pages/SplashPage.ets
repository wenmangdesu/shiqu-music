/**
 * 启动页：Logo + 版本信息
 * 等待应用初始化完成（最多2.2秒）后进入主页；4秒兜底强制跳转
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
      Column({ space: 16 }) {
        // Logo
        Column() {
          Text('♪').fontSize(54).fontColor('#FFFFFF')
        }
        .width(116)
        .height(116)
        .borderRadius(58)
        .justifyContent(FlexAlign.Center)
        .linearGradient({ angle: 135, colors: [['#F3536C', 0], ['#B15CE0', 1]] })
        .shadow({ radius: 26, color: '#55F3536C', offsetY: 8 })

        Text(C.APP_NAME)
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.cm_text'))
        Text('CLOUD JOY MUSIC')
          .fontSize(12)
          .letterSpacing(4)
          .fontColor($r('app.color.cm_text2'))
        Text(`版本 ${C.VERSION} · HarmonyOS`)
          .fontSize(12)
          .fontColor($r('app.color.cm_text2'))
          .margin({ top: 6 })

        // 加载指示点
        Row({ space: 6 }) {
          ForEach([0, 1, 2], (i: number) => {
            Circle()
              .width(7)
              .height(7)
              .fill(this.dotIdx === i ? '#F3536C' : $r('app.color.cm_divider'))
          }, (i: number) => `${i}`)
        }
        .margin({ top: 16 })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .linearGradient({ angle: 180, colors: [['#FDECEF', 0], ['#F7F8FA', 1]] })
  }
}
