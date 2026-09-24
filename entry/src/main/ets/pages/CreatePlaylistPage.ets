/**
 * 新建/重命名歌单页
 * 新建时若存在待添加歌曲（pendingAddSongIds），创建后自动加入
 */
import { C } from '../common/Constants';
import { AppModel } from '../viewmodel/AppModel';

@Component
export struct CreatePlaylistPage {
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;
  @State name: string = '';
  private model: AppModel = AppModel.getInstance();
  private isEdit: boolean = false;

  aboutToAppear(): void {
    this.isEdit = this.model.editPlaylistId > 0;
    if (this.isEdit) {
      const p = this.model.getPlaylistById(this.model.editPlaylistId);
      if (p) {
        this.name = p.name;
      }
    }
  }

  private save(): void {
    const v: string = this.name.trim();
    if (!v) {
      this.model.toast('请输入歌单名称');
      return;
    }
    if (this.isEdit) {
      this.model.renamePlaylist(this.model.editPlaylistId, v).then(() => {
        this.model.toast('歌单已保存');
        this.model.navStack.pop();
      });
    } else {
      this.model.createPlaylist(v).then((p) => {
        const ids: number[] = this.model.pendingAddSongIds;
        if (ids.length > 0) {
          this.model.addSongsToPlaylist(p.id, ids).then((n: number) => {
            this.model.pendingAddSongIds = [];
            this.model.toast(n > 0 ? `歌单已创建，并添加 ${n} 首歌曲` : '歌单已创建');
            this.model.navStack.pop();
          });
        } else {
          this.model.toast('歌单创建成功');
          this.model.navStack.pop();
        }
      });
    }
  }

  build() {
    NavDestination() {
      Column({ space: 18 }) {
        TextInput({ text: this.name, placeholder: '请输入歌单名称（最多20字）' }).maxLength(20)
          .height(46)
          .fontSize(15)
          .backgroundColor($r('app.color.cm_card'))
          .onChange((v: string) => {
            this.name = v;
          })
          .onSubmit(() => {
            this.save();
          })
        Button(this.isEdit ? '保存' : '创建歌单')
          .width('100%')
          .height(44)
          .fontSize(15)
          .backgroundColor(this.theme)
          .onClick(() => {
            this.save();
          })
        Text(this.isEdit ? '修改后点击保存' : '创建后可将歌曲添加到该歌单')
          .fontSize(12)
          .fontColor($r('app.color.cm_text2'))
      }
      .padding(16)
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.cm_bg'))
      .constraintSize({ maxWidth: 640 })
    }
    .title(this.isEdit ? '重命名歌单' : '新建歌单')
  }
}
