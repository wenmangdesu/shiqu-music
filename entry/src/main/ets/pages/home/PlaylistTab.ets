/**
 * 播放列表 Tab：歌单管理
 * 我喜欢（默认歌单）+ 自定义歌单（新建/重命名/删除/设置封面）
 */
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import fs from '@ohos.file.fs';
import { Playlist } from '../../model/Playlist';
import { Song } from '../../model/Song';
import { C } from '../../common/Constants';
import { AppModel } from '../../viewmodel/AppModel';
import { LibraryService } from '../../service/LibraryService';
import { InputDialog, InputDialogData } from '../../view/dialogs/InputDialog';

@Component
export struct PlaylistTab {
  @StorageProp(C.K_PLV) @Watch('reload') plVersion: number = 0;
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;
  @State playlists: Playlist[] = [];
  private model: AppModel = AppModel.getInstance();
  /** 输入对话框数据载体（对象引用，open前更新字段） */
  private dlgData: InputDialogData = new InputDialogData();
  private editTargetId: number = -1;
  private inputCtrl: CustomDialogController = new CustomDialogController({
    builder: InputDialog({
      data: this.dlgData,
      onConfirm: (v: string): void => {
        this.onInputConfirm(v);
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
    customStyle: true
  });

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    this.playlists = this.model.playlists.slice();
  }

  private onInputConfirm(v: string): void {
    if (this.editTargetId > 0) {
      this.model.renamePlaylist(this.editTargetId, v).then(() => {
        this.model.toast('歌单已重命名');
      });
    } else {
      this.model.createPlaylist(v).then(() => {
        this.model.toast('歌单创建成功');
      });
    }
    this.editTargetId = -1;
  }

  /** 歌单封面：优先自定义封面 -> 歌单内第一首歌封面 */
  private firstCover(pl: Playlist): string {
    if (pl.coverPath) {
      return pl.coverPath;
    }
    const songs: Song[] = this.model.getPlaylistSongs(pl);
    for (let i = 0; i < songs.length; i++) {
      if (songs[i].coverPath || songs[i].coverUrl) {
        return songs[i].coverPath || songs[i].coverUrl;
      }
    }
    return '';
  }

  private async plMenu(pl: Playlist): Promise<void> {
    const idx: number = await this.model.actionMenu(pl.name, ['重命名', '设置封面', '删除歌单']);
    if (idx === 0) {
      this.editTargetId = pl.id;
      this.dlgData.title = '重命名歌单';
      this.dlgData.defaultValue = pl.name;
      this.inputCtrl.open();
    } else if (idx === 1) {
      this.pickCover(pl);
    } else if (idx === 2) {
      const ok: boolean = await this.model.confirm('删除歌单', `确定删除歌单「${pl.name}」吗？\n（歌曲不会被删除）`);
      if (ok) {
        this.model.deletePlaylistById(pl.id).then(() => {
          this.model.toast('歌单已删除');
        });
      }
    }
  }

  /** 从相册选择封面图并复制到沙箱（无需存储权限） */
  private async pickCover(pl: Playlist): Promise<void> {
    if (!this.model.context) {
      return;
    }
    try {
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const opts: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      opts.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      opts.maxSelectNumber = 1;
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(opts);
      if (result.photoUris.length === 0) {
        return;
      }
      const uri: string = result.photoUris[0];
      const dest: string =
        `${this.model.context.filesDir}/${C.COVER_DIR}/pl_${pl.id}_${Date.now() % 100000}.img`;
      LibraryService.getInstance().copyUriToFile(uri, dest);
      if (fs.accessSync(dest)) {
        await this.model.setPlaylistCover(pl.id, dest);
        this.model.toast('封面已更新');
      } else {
        this.model.toast('封面设置失败');
      }
    } catch (err) {
      this.model.toast('未选择封面');
    }
  }

  @Builder
  plCard(pl: Playlist) {
    Column({ space: 6 }) {
      if (this.firstCover(pl) !== '') {
        Image(this.firstCover(pl).startsWith('http') ? this.firstCover(pl) : `file://${this.firstCover(pl)}`)
          .width('100%')
          .height(76)
          .borderRadius(10)
          .objectFit(ImageFit.Cover)
      } else {
        Column() {
          Text('♪').fontSize(26).fontColor('#8C8570')
        }
        .width('100%')
        .height(76)
        .borderRadius(10)
        .justifyContent(FlexAlign.Center)
        .linearGradient({ angle: 135, colors: [['#EFE9D8', 0], ['#DCD4BE', 1]] })
      }
      Text(pl.name)
        .fontSize(13)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontColor($r('app.color.cm_text'))
      Text(`${pl.songIds.length}首`)
        .fontSize(11)
        .fontColor($r('app.color.cm_text2'))
    }
    .width('100%')
    .padding(10)
    .borderRadius(14)
    .backgroundColor($r('app.color.cm_card'))
    .border({ width: 2, color: $r('app.color.cm_text') })
    .onClick(() => {
      this.model.pushPlaylistDetail(pl.id);
    })
    .gesture(LongPressGesture().onAction(() => {
      this.plMenu(pl);
    }))
  }

  build() {
    Column() {
      Row({ space: 14 }) {
        Text('播放列表')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.cm_text'))
          .layoutWeight(1)
        Text('＋ 新建')
          .fontSize(14)
          .fontColor(this.theme)
          .onClick(() => {
            this.editTargetId = -1;
            this.dlgData.title = '新建歌单';
            this.dlgData.defaultValue = '';
            this.inputCtrl.open();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 10 })

      Scroll() {
        Column({ space: 12 }) {
          // 我喜欢（默认歌单）
          Row({ space: 12 }) {
            Column() {
              Text('♥').fontSize(26).fontColor('#E5484D')
            }
            .width(54)
            .height(54)
            .borderRadius(12)
            .justifyContent(FlexAlign.Center)
            .backgroundColor($r('app.color.cm_marker'))

            Column({ space: 3 }) {
              Text('我喜欢')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.cm_text'))
              Text(`${this.model.likedPlaylist().songIds.length}首歌曲 · 自动收集你收藏的歌`)
                .fontSize(11)
                .fontColor($r('app.color.cm_text2'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Text('›').fontSize(20).fontColor($r('app.color.cm_text2'))
          }
          .width('100%')
          .padding(14)
          .borderRadius(14)
          .backgroundColor('#59FFE45C')
          .border({ width: 2, color: $r('app.color.cm_text') })
          .onClick(() => {
            this.model.pushPlaylistDetail(-1);
          })

          // 自定义歌单
          if (this.playlists.length === 0) {
            Column({ space: 8 }) {
              Text('📋').fontSize(36)
              Text('还没有自定义歌单，点击右上角"＋ 新建"创建')
                .fontSize(12)
                .fontColor($r('app.color.cm_text2'))
            }
            .width('100%')
            .padding({ top: 40 })
          } else {
            Grid() {
              ForEach(this.playlists, (pl: Playlist) => {
                GridItem() {
                  this.plCard(pl)
                }
              }, (pl: Playlist) => `${this.plVersion}_${pl.id}_${pl.songIds.length}_${pl.coverPath}`)
            }
            .columnsTemplate('1fr 1fr')
            .columnsGap(10)
            .rowsGap(10)
            .width('100%')
            .height(Math.max(1, Math.ceil(this.playlists.length / 2)) * 152)
          }
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
  }
}
