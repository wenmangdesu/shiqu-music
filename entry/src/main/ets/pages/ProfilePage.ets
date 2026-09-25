/**
 * 个人资料页
 * 修改头像（相册选择，Mock阶段保存到本地沙箱）、昵称、性别、生日、地区、简介；退出登录
 */
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import fs from '@ohos.file.fs';
import { UserService } from '../service/UserService';
import { LibraryService } from '../service/LibraryService';
import { AppModel } from '../viewmodel/AppModel';
import { C } from '../common/Constants';

@Component
export struct ProfilePage {
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;
  @State nickname: string = '';
  @State gender: string = '男';
  @State birthday: string = '';
  @State region: string = '';
  @State bio: string = '';
  @State avatarPath: string = '';
  private model: AppModel = AppModel.getInstance();
  private userSvc: UserService = UserService.getInstance();

  aboutToAppear(): void {
    const u = this.userSvc.user;
    if (u) {
      this.nickname = u.nickname;
      this.gender = u.gender;
      this.birthday = u.birthday;
      this.region = u.region;
      this.bio = u.bio;
      this.avatarPath = u.avatar;
    }
  }

  private saveAll(): void {
    this.userSvc.updateProfile(this.nickname, this.gender, this.birthday, this.region, this.bio);
    this.model.bump(C.K_USERV);
    this.model.toast('资料已保存');
  }

  /** 从相册选择头像并复制到沙箱（无需存储权限） */
  private pickAvatar(): void {
    if (!this.model.context) {
      return;
    }
    try {
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const opts: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      opts.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      opts.maxSelectNumber = 1;
      picker.select(opts).then((result: photoAccessHelper.PhotoSelectResult) => {
        if (result.photoUris.length === 0) {
          return;
        }
        const dest: string =
          `${this.model.context!.filesDir}/avatar_${Date.now() % 100000}.img`;
        LibraryService.getInstance().copyUriToFile(result.photoUris[0], dest);
        if (fs.accessSync(dest)) {
          this.userSvc.setAvatar(dest);
          this.avatarPath = dest;
          this.model.bump(C.K_USERV);
          this.model.toast('头像已更新');
        }
      }).catch(() => {
        this.model.toast('未选择头像');
      });
    } catch (err) {
      this.model.toast('未选择头像');
    }
  }

  private logout(): void {
    this.userSvc.logout();
    this.model.bump(C.K_USERV);
    this.model.toast('已退出登录');
    this.model.navStack.pop();
  }

  @Builder
  genderChip(label: string) {
    Text(label)
      .fontSize(13)
      .fontColor($r('app.color.cm_text'))
      .padding({ left: 16, right: 16, top: 7, bottom: 7 })
      .borderRadius(15)
      .backgroundColor(this.gender === label ? $r('app.color.cm_marker') : $r('app.color.cm_card'))
      .border({ width: 2, color: $r('app.color.cm_text') })
      .onClick(() => {
        this.gender = label;
      })
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 14 }) {
          // 头像
          Column({ space: 6 }) {
            if (this.avatarPath) {
              Image(`file://${this.avatarPath}`)
                .width(96)
                .height(96)
                .borderRadius(48)
                .objectFit(ImageFit.Cover)
                .border({ width: 3, color: $r('app.color.cm_text') })
            } else {
              Column() {
                Text('🎧').fontSize(36)
              }
                .width(96)
                .height(96)
                .borderRadius(48)
                .justifyContent(FlexAlign.Center)
                .backgroundColor($r('app.color.cm_marker'))
                .border({ width: 3, color: $r('app.color.cm_text') })
            }
            Text('点击修改头像')
              .fontSize(12)
              .fontColor($r('app.color.cm_accent'))
              .onClick(() => {
                this.pickAvatar();
              })
          }
          .width('100%')
          .margin({ top: 8 })

          // 资料表单
          Column({ space: 12 }) {
            Row({ space: 10 }) {
              Text('昵称').fontSize(14).fontColor($r('app.color.cm_text2')).width(52)
              TextInput({ text: this.nickname, placeholder: '给自己起个名字' })
                .height(42)
                .fontSize(14)
                .layoutWeight(1)
                .backgroundColor($r('app.color.cm_card'))
                .border({ width: 2, color: $r('app.color.cm_text') })
                .onChange((v: string) => {
                  this.nickname = v;
                })
            }
            .width('100%')

            Row({ space: 10 }) {
              Text('性别').fontSize(14).fontColor($r('app.color.cm_text2')).width(52)
              Row({ space: 8 }) {
                this.genderChip('男')
                this.genderChip('女')
                this.genderChip('保密')
              }
            }
            .width('100%')

            Row({ space: 10 }) {
              Text('生日').fontSize(14).fontColor($r('app.color.cm_text2')).width(52)
              TextInput({ text: this.birthday, placeholder: '如 2000-01-01' })
                .height(42)
                .fontSize(14)
                .layoutWeight(1)
                .backgroundColor($r('app.color.cm_card'))
                .border({ width: 2, color: $r('app.color.cm_text') })
                .onChange((v: string) => {
                  this.birthday = v;
                })
            }
            .width('100%')

            Row({ space: 10 }) {
              Text('地区').fontSize(14).fontColor($r('app.color.cm_text2')).width(52)
              TextInput({ text: this.region, placeholder: '如 中国 / 四川 / 成都' })
                .height(42)
                .fontSize(14)
                .layoutWeight(1)
                .backgroundColor($r('app.color.cm_card'))
                .border({ width: 2, color: $r('app.color.cm_text') })
                .onChange((v: string) => {
                  this.region = v;
                })
            }
            .width('100%')

            Column({ space: 6 }) {
              Text('个人简介').fontSize(14).fontColor($r('app.color.cm_text2')).width('100%')
              TextInput({ text: this.bio, placeholder: '写点什么介绍自己吧' })
                .height(72)
                .fontSize(14)
                .backgroundColor($r('app.color.cm_card'))
                .border({ width: 2, color: $r('app.color.cm_text') })
                .onChange((v: string) => {
                  this.bio = v;
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .borderRadius(14)
          .backgroundColor($r('app.color.cm_card'))
          .border({ width: 2, color: $r('app.color.cm_text') })

          Button('保存资料')
            .width('100%')
            .height(46)
            .fontSize(15)
            .backgroundColor(this.theme)
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.saveAll();
            })

          Button('退出登录')
            .width('100%')
            .height(44)
            .fontSize(14)
            .backgroundColor($r('app.color.cm_card'))
            .fontColor($r('app.color.cm_accent'))
            .border({ width: 2, color: $r('app.color.cm_accent') })
            .onClick(async (): Promise<void> => {
              const ok: boolean = await this.model.confirm('退出登录', '确定退出当前账号吗？');
              if (ok) {
                this.logout();
              }
            })
        }
        .padding({ left: 16, right: 16, bottom: 24 })
        .constraintSize({ maxWidth: 640 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .width('100%')
      .height('100%')
    }
    .title('个人资料')
  }
}
