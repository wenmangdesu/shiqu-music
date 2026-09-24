/**
 * 添加到歌单页
 * 将 AppModel.pendingAddSongIds 中的歌曲添加到选中的歌单
 */
import { Playlist } from '../model/Playlist';
import { C } from '../common/Constants';
import { AppModel } from '../viewmodel/AppModel';

@Component
export struct AddToPlaylistPage {
  @StorageProp(C.K_PLV) plVersion: number = 0;
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;
  private model: AppModel = AppModel.getInstance();

  private count(): number {
    return this.model.pendingAddSongIds.length;
  }

  build() {
    NavDestination() {
      Column() {
        Text(`已选择 ${this.count()} 首歌曲，选择要添加到的歌单`)
          .fontSize(13)
          .fontColor($r('app.color.cm_text2'))
          .width('100%')
          .padding({ left: 16, right: 16, top: 4, bottom: 10 })

        Scroll() {
          Column({ space: 8 }) {
            // 我喜欢
            Row({ space: 12 }) {
              Column() {
                Text('♥').fontSize(20).fontColor('#E5484D')
              }
              .width(44)
              .height(44)
              .borderRadius(10)
              .justifyContent(FlexAlign.Center)
              .backgroundColor($r('app.color.cm_marker'))

              Text('我喜欢')
                .fontSize(15)
                .fontColor($r('app.color.cm_text'))
                .layoutWeight(1)
              Text(`${this.model.likedPlaylist().songIds.length}首`)
                .fontSize(12)
                .fontColor($r('app.color.cm_text2'))
            }
            .width('100%')
            .padding(12)
            .borderRadius(12)
            .backgroundColor($r('app.color.cm_card'))
            .border({ width: 2, color: $r('app.color.cm_text') })
            .onClick(() => {
              this.model.likeSongs(this.model.pendingAddSongIds).then(() => {
                this.model.navStack.pop();
              });
            })

            // 自定义歌单
            ForEach(this.model.playlists, (p: Playlist) => {
              Row({ space: 12 }) {
                Column() {
                  Text('📋').fontSize(18)
                }
                .width(44)
                .height(44)
                .borderRadius(10)
                .justifyContent(FlexAlign.Center)
                .backgroundColor($r('app.color.cm_bg'))

                Text(p.name)
                  .fontSize(15)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .fontColor($r('app.color.cm_text'))
                  .layoutWeight(1)
                Text(`${p.songIds.length}首`)
                  .fontSize(12)
                  .fontColor($r('app.color.cm_text2'))
              }
              .width('100%')
              .padding(12)
              .borderRadius(12)
              .backgroundColor($r('app.color.cm_card'))
              .border({ width: 2, color: $r('app.color.cm_text') })
              .onClick(() => {
                const ids: number[] = this.model.pendingAddSongIds;
                this.model.addSongsToPlaylist(p.id, ids).then((n: number) => {
                  this.model.toast(n > 0 ? `已添加 ${n} 首到「${p.name}」` : '歌曲已在该歌单中');
                  this.model.navStack.pop();
                });
              })
            }, (p: Playlist) => `${this.plVersion}_${p.id}`)

            // 新建歌单
            Row({ space: 12 }) {
              Column() {
                Text('＋').fontSize(20).fontColor(this.theme)
              }
              .width(44)
              .height(44)
              .borderRadius(10)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(`'#59FFE45C'`)

              Text('新建歌单')
                .fontSize(15)
                .fontColor(this.theme)
            }
            .width('100%')
            .padding(12)
            .borderRadius(12)
            .backgroundColor($r('app.color.cm_card'))
            .border({ width: 2, color: $r('app.color.cm_text') })
            .onClick(() => {
              this.model.pushCreatePlaylist(-1);
            })
          }
          .padding({ left: 16, right: 16, bottom: 20 })
          .constraintSize({ maxWidth: 720 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.cm_bg'))
    }
    .title('添加到歌单')
  }
}
