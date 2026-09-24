/**
 * "添加到歌单"选择对话框
 * 列出：我喜欢 / 全部自定义歌单 / 新建歌单入口
 * 待添加的歌曲id通过 AppModel.pendingAddSongIds 传递
 */
import { Playlist } from '../../model/Playlist';
import { C } from '../../common/Constants';
import { AppModel } from '../../viewmodel/AppModel';

@CustomDialog
export struct PlaylistPickerDialog {
  controller?: CustomDialogController;
  @StorageProp(C.K_PLV) plv: number = 0;
  private model: AppModel = AppModel.getInstance();

  private close(): void {
    this.controller?.close();
  }

  build() {
    Column({ space: 4 }) {
      Text('添加到歌单')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.cm_text'))
        .width('100%')
        .padding({ bottom: 8 })
      // 我喜欢
      Row({ space: 12 }) {
        Text('♥').fontSize(20).fontColor(this.model.likedPlaylist().songIds.length > 0 ? C.DEFAULT_THEME : $r('app.color.cm_text2'))
        Text('我喜欢').fontSize(15).fontColor($r('app.color.cm_text')).layoutWeight(1)
        Text(`${this.model.likedPlaylist().songIds.length}首`).fontSize(12).fontColor($r('app.color.cm_text2'))
      }
      .width('100%')
      .padding(12)
      .borderRadius(12)
      .backgroundColor($r('app.color.cm_bg'))
      .onClick(() => {
        const ids: number[] = this.model.pendingAddSongIds;
        this.model.likeSongs(ids).then(() => {
          this.close();
        });
      })
      // 自定义歌单列表
      if (this.model.playlists.length === 0) {
        Text('还没有自定义歌单')
          .fontSize(13)
          .fontColor($r('app.color.cm_text2'))
          .padding({ top: 14, bottom: 14 })
      } else {
        List({ space: 6 }) {
          ForEach(this.model.playlists, (p: Playlist) => {
            ListItem() {
              Row({ space: 12 }) {
                Text('📋').fontSize(18)
                Text(p.name).fontSize(15).fontColor($r('app.color.cm_text')).maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                Text(`${p.songIds.length}首`).fontSize(12).fontColor($r('app.color.cm_text2'))
              }
              .width('100%')
              .padding(12)
              .borderRadius(12)
              .backgroundColor($r('app.color.cm_bg'))
              .onClick(() => {
                const ids: number[] = this.model.pendingAddSongIds;
                this.model.addSongsToPlaylist(p.id, ids).then((n: number) => {
                  this.model.toast(n > 0 ? `已添加 ${n} 首到「${p.name}」` : '歌曲已在该歌单中');
                  this.close();
                });
              })
            }
          }, (p: Playlist) => `${p.id}_${p.songIds.length}_${this.plv}`)
        }
        .height(Math.min(260, this.model.playlists.length * 62 + 10))
        .scrollBar(BarState.Auto)
      }
      // 新建歌单
      Row({ space: 12 }) {
        Text('＋').fontSize(20).fontColor(this.plv >= 0 ? $r('app.color.cm_text') : $r('app.color.cm_text'))
        Text('新建歌单').fontSize(15).fontColor($r('app.color.cm_text'))
      }
      .width('100%')
      .padding(12)
      .borderRadius(12)
      .backgroundColor($r('app.color.cm_bg'))
      .margin({ top: 6 })
      .onClick(() => {
        this.close();
        this.model.pushCreatePlaylist(-1);
      })
    }
    .padding(20)
    .borderRadius(16)
    .backgroundColor($r('app.color.cm_card'))
    .border({ width: 2, color: $r('app.color.cm_text') })
    .width('88%')
  }
}
