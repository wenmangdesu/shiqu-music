/**
 * 登录/注册页（第一阶段Mock实现）
 * 本地校验后直接建立会话；接入真实后端时替换 UserService.login 内部实现即可
 */
import { UserService } from '../service/UserService';
import { AppModel } from '../viewmodel/AppModel';
import { C } from '../common/Constants';

@Component
export struct LoginPage {
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;
  @State username: string = '';
  @State password: string = '';
  @State busy: boolean = false;
  private model: AppModel = AppModel.getInstance();
  private userSvc: UserService = UserService.getInstance();

  private doLogin(): void {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.userSvc.login(this.username, this.password).then(() => {
      this.busy = false;
      this.model.bump(C.K_USERV);
      this.model.toast(`欢迎回来，${this.userSvc.user?.nickname ?? ''}`);
      this.model.navStack.pop();
    }).catch((e: Error) => {
      this.busy = false;
      this.model.toast(e.message);
    });
  }

  build() {
    NavDestination() {
      Column({ space: 16 }) {
        // 涂鸦Logo
        Image($r('app.media.startIcon'))
          .width(88)
          .height(88)
          .borderRadius(20)
          .border({ width: 3, color: $r('app.color.cm_text') })
          .margin({ top: 24 })

        Text('登录识曲')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.cm_text'))
        Text('本地Mock账号，输入即注册')
          .fontSize(11)
          .fontColor($r('app.color.cm_text2'))

        TextInput({ text: this.username, placeholder: '用户名' })
          .height(46)
          .fontSize(15)
          .backgroundColor($r('app.color.cm_card'))
          .border({ width: 2, color: $r('app.color.cm_text') })
          .onChange((v: string) => {
            this.username = v;
          })

        TextInput({ text: this.password, placeholder: '密码（至少4位）' })
          .type(InputType.Password)
          .height(46)
          .fontSize(15)
          .backgroundColor($r('app.color.cm_card'))
          .border({ width: 2, color: $r('app.color.cm_text') })
          .onChange((v: string) => {
            this.password = v;
          })
          .onSubmit(() => {
            this.doLogin();
          })

        Button(this.busy ? '登录中...' : '登录 / 注册')
          .width('100%')
          .height(46)
          .fontSize(15)
          .backgroundColor(this.theme)
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.doLogin();
          })

        Text('游客模式')
          .fontSize(13)
          .fontColor($r('app.color.cm_text2'))
          .onClick(() => {
            this.model.navStack.pop();
          })
          .margin({ top: 6 })

        Blank()
      }
      .width('100%')
      .height('100%')
      .padding({ left: 24, right: 24 })
      .backgroundColor($r('app.color.cm_bg'))
      .constraintSize({ maxWidth: 560 })
    }
    .title('登录')
  }
}
