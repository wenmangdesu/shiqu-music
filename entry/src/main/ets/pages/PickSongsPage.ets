/**
 * 选歌加入歌单页
 * 多选本地音乐库歌曲，批量添加到目标歌单（AppModel.pickTargetPlaylistId）
 */
import { Song } from '../model/Song';
import { C } from '../common/Constants';
import { AppModel } from '../viewmodel/AppModel';
import { LibraryService } from '../service/LibraryService';
import { SongRow } from '../view/SongRow';

@Component
export struct PickSongsPage {
  @StorageProp(C.K_LIBV) @Watch('reload') libVersion: number = 0;
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;
  @State songs: Song[] = [];
  @State selectedIds: number[] = [];
  private model: AppModel = AppModel.getInstance();

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    this.songs = this.model.localSongs.slice();
  }

  /** 直接从本地选择音频导入音乐库（导入完成后新歌立即可选） */
  private importLocal(): void {
    LibraryService.getInstance().importPickedAudio().then((n: number) => {
      if (n > 0) {
        this.model.reloadSongs().then(() => {
          this.reload();
        });
      }
    }).catch(() => {
    });
  }

  private toggleSelect(s: Song): void {
    const idx: number = this.selectedIds.indexOf(s.id);
    if (idx >= 0) {
      this.selectedIds = this.selectedIds.filter((x: number) => x !== s.id);
    } else {
      this.selectedIds = this.selectedIds.concat([s.id]);
    }
  }

  private confirm(): void {
    if (this.selectedIds.length === 0) {
      this.model.toast('请先选择歌曲');
      return;
    }
    this.model.addSongsToPlaylist(this.model.pickTargetPlaylistId, this.selectedIds)
      .then((n: number) => {
        this.model.toast(n > 0 ? `已添加 ${n} 首歌曲` : '歌曲已在该歌单中');
        this.model.navStack.pop();
      });
  }

  build() {
    NavDestination() {
      Column() {
        // 全选行
        Row({ space: 12 }) {
          Text(this.selectedIds.length === this.songs.length && this.songs.length > 0 ? '取消全选' : '全选')
            .fontSize(14)
            .fontColor(this.theme)
            .onClick(() => {
              if (this.selectedIds.length === this.songs.length) {
                this.selectedIds = [];
              } else {
                const ids: number[] = [];
                this.songs.forEach((s: Song) => {
                  ids.push(s.id);
                });
                this.selectedIds = ids;
              }
            })
          Blank()
          Text('⤓ 从本地导入')
            .fontSize(14)
            .fontColor($r('app.color.cm_accent'))
            .onClick(() => {
              this.importLocal();
            })
          Text(`已选 ${this.selectedIds.length} 首`)
            .fontSize(13)
            .fontColor($r('app.color.cm_text2'))
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 6, bottom: 6 })

        if (this.songs.length === 0) {
          Column({ space: 8 }) {
            Text('🎵').fontSize(38)
            Text('本地音乐库为空，可点击右上角"从本地导入"')
              .fontSize(12)
              .fontColor($r('app.color.cm_text2'))
              .textAlign(TextAlign.Center)
          }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 2 }) {
            ForEach(this.songs, (s: Song, i: number) => {
              ListItem() {
                SongRow({
                  song: s,
                  index: i,
                  selectMode: true,
                  selected: this.selectedIds.indexOf(s.id) >= 0,
                  onPlay: (_x: Song): void => {
                  },
                  onSelect: (x: Song): void => {
                    this.toggleSelect(x);
                  }
                })
              }
            }, (s: Song) => `${this.libVersion}_${s.id}_${this.selectedIds.indexOf(s.id) >= 0 ? 1 : 0}`)
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 8, right: 8 })
        }

        // 底部确认
        Button(`添加 ${this.selectedIds.length} 首到歌单`)
          .width('92%')
          .height(44)
          .fontSize(15)
          .margin({ bottom: 12 })
          .backgroundColor(this.selectedIds.length > 0 ? this.theme : $r('app.color.cm_divider'))
          .onClick(() => {
            this.confirm();
          })
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.cm_bg'))
    }
    .title('选择歌曲')
  }
}
