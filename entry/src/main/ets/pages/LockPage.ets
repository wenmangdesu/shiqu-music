/**
 * 应用锁页
 * 启动应用时若开启了应用锁，启动页会跳转到本页；输入4位密码解锁后进入主页
 */
import { router } from '@kit.ArkUI';
import { curves } from '@kit.ArkUI';
import { C } from '../common/Constants';
import { PrefsService } from '../service/PrefsService';
import { CryptoUtil } from '../utils/CryptoUtil';

@Entry
@Component
struct LockPage {
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;
  @State pwd: string = '';
  @State shakeX: number = 0;
  @State verifying: boolean = false;

  private verifyingNow: boolean = false;

  /** 数字键盘输入 */
  private input(d: string): void {
    if (this.verifyingNow || this.pwd.length >= 4) {
      return;
    }
    this.pwd += d;
    if (this.pwd.length === 4) {
      this.verify();
    }
  }

  private backspace(): void {
    if (this.verifyingNow) {
      return;
    }
    this.pwd = this.pwd.substring(0, this.pwd.length - 1);
  }

  private async verify(): Promise<void> {
    this.verifyingNow = true;
    this.verifying = true;
    const input: string = this.pwd;
    const saved: string = PrefsService.getInstance().getStr(C.P_LOCK_HASH, '');
    const hash: string = await CryptoUtil.sha256Hex(input);
    if (hash === saved) {
      router.replaceUrl({ url: 'pages/Index' }).catch(() => {});
      return;
    }
    // 错误：抖动 + 清空
    this.verifying = false;
    this.verifyingNow = false;
    this.getUIContext().animateTo({ duration: 80, curve: Curve.Sharp }, () => {
      this.shakeX = -12;
    });
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 80, curve: Curve.Sharp }, () => {
        this.shakeX = 12;
      });
    }, 80);
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 80, curve: Curve.Sharp }, () => {
        this.shakeX = 0;
      });
    }, 160);
    this.pwd = '';
  }

  @Builder
  key(d: string, label: string) {
    Column() {
      Text(label)
        .fontSize(24)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.cm_text'))
    }
    .width(76)
    .height(60)
    .borderRadius(14)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.cm_card'))
    .border({ width: 2, color: $r('app.color.cm_text') })
    .onClick(() => {
      if (d === 'del') {
        this.backspace();
      } else if (d !== 'none') {
        this.input(d);
      }
    })
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
      .hitTestBehavior(HitTestMode.None)

      Column({ space: 20 }) {
        Image($r('app.media.startIcon'))
          .width(72)
          .height(72)
          .borderRadius(18)
          .border({ width: 3, color: $r('app.color.cm_text') })
          .margin({ top: 30 })

        Text('识曲已锁定')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.cm_text'))
        Text('输入4位密码解锁')
          .fontSize(12)
          .fontColor($r('app.color.cm_text2'))

        // 密码点
        Row({ space: 18 }) {
          ForEach([0, 1, 2, 3], (i: number) => {
            Circle()
              .width(14)
              .height(14)
              .fill(i < this.pwd.length ? '#E5484D' : Color.Transparent)
              .stroke('#2B3A55')
              .strokeWidth(2)
          }, (i: number) => `${i}`)
        }
        .translate({ x: this.shakeX })
        .animation({ duration: 80, curve: Curve.Sharp })

        if (this.verifying) {
          LoadingProgress().width(28).height(28).color('#E5484D')
        }

        // 数字键盘
        Grid() {
          ForEach(['1', '2', '3', '4', '5', '6', '7', '8', '9', 'none', '0', 'del'], (d: string) => {
            GridItem() {
              if (d === 'none') {
                Blank()
              } else {
                this.key(d, d === 'del' ? '⌫' : d)
              }
            }
          }, (d: string) => d)
        }
        .columnsTemplate('1fr 1fr 1fr')
        .rowsGap(14)
        .columnsGap(18)
        .width(268)
        .height(300)

        Blank()
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.cm_bg'))
  }
}
