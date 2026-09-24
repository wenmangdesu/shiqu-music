/**
 * 我的音乐 Tab：本地音乐库
 * 功能：歌曲列表、排序（默认/标题/歌手/专辑/时长）、格式筛选、
 *      多选批量添加到歌单、歌曲菜单（下一首播放/收藏/添加到歌单/移除）、导入
 */
import { Song } from '../../model/Song';
import { C } from '../../common/Constants';
import { AppModel } from '../../viewmodel/AppModel';
import { PlayerService } from '../../service/PlayerService';
import { LibraryService } from '../../service/LibraryService';
import { SongRow } from '../../view/SongRow';
import { PlaylistPickerDialog } from '../../view/dialogs/PlaylistPickerDialog';

class Opt {
  key: string = '';
  label: string = '';
}

/** 排序选项（模块级常量，struct内不支持static成员） */
const SORT_OPTS: Opt[] = (() => {
  const arr: Opt[] = [];
  const defs: string[][] = [['added', '默认'], ['title', '标题'], ['artist', '歌手'], ['album', '专辑'], ['duration', '时长']];
  defs.forEach((d: string[]) => {
    const o: Opt = new Opt();
    o.key = d[0];
    o.label = d[1];
    arr.push(o);
  });
  return arr;
})();

/** 格式筛选选项 */
const FILTER_OPTS: string[] = ['全部', 'MP3', 'FLAC', '其他'];

@Component
export struct LocalTab {
  @StorageProp(C.K_LIBV) @Watch('reload') libVersion: number = 0;
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;
  @State songs: Song[] = [];
  @State sortBy: string = 'added';
  @State sortAsc: boolean = false;
  @State filterFmt: string = '全部';
  @State selectMode: boolean = false;
  @State selectedIds: number[] = [];
  private model: AppModel = AppModel.getInstance();
  private player: PlayerService = PlayerService.getInstance();

  private pickCtrl: CustomDialogController = new CustomDialogController({
    builder: PlaylistPickerDialog(),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    const filtered: Song[] = [];
    this.model.localSongs.forEach((s: Song) => {
      let pass: boolean = true;
      if (this.filterFmt === 'MP3') {
        pass = s.format === 'mp3';
      } else if (this.filterFmt === 'FLAC') {
        pass = s.format === 'flac';
      } else if (this.filterFmt === '其他') {
        pass = s.format !== 'mp3' && s.format !== 'flac';
      }
      if (pass) {
        filtered.push(s);
      }
    });
    const asc: boolean = this.sortAsc;
    const by: string = this.sortBy;
    filtered.sort((a: Song, b: Song): number => {
      if (by === 'title') {
        return asc ? a.title.localeCompare(b.title, 'zh-Hans-CN') : b.title.localeCompare(a.title, 'zh-Hans-CN');
      }
      if (by === 'artist') {
        return asc ? a.artist.localeCompare(b.artist, 'zh-Hans-CN') : b.artist.localeCompare(a.artist, 'zh-Hans-CN');
      }
      if (by === 'album') {
        return asc ? a.album.localeCompare(b.album, 'zh-Hans-CN') : b.album.localeCompare(a.album, 'zh-Hans-CN');
      }
      if (by === 'duration') {
        return asc ? a.duration - b.duration : b.duration - a.duration;
      }
      return asc ? a.addedTime - b.addedTime : b.addedTime - a.addedTime;
    });
    this.songs = filtered;
  }

  build() {
    Column() {
      // 标题栏
      Row({ space: 14 }) {
        Text('我的音乐')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.cm_text'))
          .layoutWeight(1)
        Text(this.selectMode ? '完成' : '多选')
          .fontSize(14)
          .fontColor(this.theme)
          .onClick(() => {
            this.selectMode = !this.selectMode;
            this.selectedIds = [];
          })
        Text('⤓')
          .fontSize(20)
          .fontColor($r('app.color.cm_text'))
          .onClick(() => {
            this.showImportMenu();
          })
        Text('⚙')
          .fontSize(18)
          .fontColor($r('app.color.cm_text'))
          .onClick(() => {
            this.model.pushPage('Settings');
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // 搜索栏
      Row({ space: 8 }) {
        Text('🔍').fontSize(14).fontColor($r('app.color.cm_text2'))
        Text('搜索歌曲、歌手、专辑')
          .fontSize(13)
          .fontColor($r('app.color.cm_text2'))
          .layoutWeight(1)
      }
      .width('100%')
      .height(38)
      .padding({ left: 12, right: 12 })
      .borderRadius(19)
      .backgroundColor($r('app.color.cm_card'))
      .onClick(() => {
        this.model.pushPage('Search');
      })
      .margin({ left: 16, right: 16, bottom: 8 })

      // 排序与筛选
      Scroll() {
        Row({ space: 8 }) {
          ForEach(SORT_OPTS, (o: Opt) => {
            Text(o.label)
              .fontSize(12)
              .fontColor(this.sortBy === o.key ? '#FFFFFF' : $r('app.color.cm_text'))
              .padding({ left: 11, right: 11, top: 5, bottom: 5 })
              .borderRadius(13)
              .backgroundColor(this.sortBy === o.key ? this.theme : $r('app.color.cm_card'))
              .onClick(() => {
                if (this.sortBy === o.key) {
                  this.sortAsc = !this.sortAsc;
                } else {
                  this.sortBy = o.key;
                }
                this.reload();
              })
          }, (o: Opt) => o.key)
          Text(this.sortAsc ? '↑' : '↓')
            .fontSize(13)
            .fontColor(this.theme)
            .onClick(() => {
              this.sortAsc = !this.sortAsc;
              this.reload();
            })
          Divider().vertical(true).height(14).color($r('app.color.cm_divider'))
          ForEach(FILTER_OPTS, (f: string) => {
            Text(f)
              .fontSize(12)
              .fontColor(this.filterFmt === f ? '#FFFFFF' : $r('app.color.cm_text2'))
              .padding({ left: 11, right: 11, top: 5, bottom: 5 })
              .borderRadius(13)
              .backgroundColor(this.filterFmt === f ? this.theme : $r('app.color.cm_card'))
              .onClick(() => {
                this.filterFmt = f;
                this.reload();
              })
          }, (f: string) => f)
        }
        .padding({ left: 16, right: 16 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .margin({ bottom: 6 })

      // 歌曲列表 / 空态
      if (this.songs.length === 0) {
        Column({ space: 12 }) {
          Text('🎵').fontSize(44)
          Text('还没有本地音乐')
            .fontSize(16)
            .fontColor($r('app.color.cm_text'))
          Text('点击右上角 ⤓ 导入音频文件，\n或到"在线音乐"搜索下载')
            .fontSize(12)
            .fontColor($r('app.color.cm_text2'))
            .textAlign(TextAlign.Center)
          Button('导入音频文件')
            .backgroundColor(this.theme)
            .onClick(() => {
              this.showImportMenu();
            })
            .margin({ top: 8 })
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
                selectMode: this.selectMode,
                selected: this.selectedIds.indexOf(s.id) >= 0,
                onPlay: (x: Song): void => {
                  const idx: number = this.songs.indexOf(x);
                  this.player.setQueue(this.songs, idx >= 0 ? idx : 0);
                },
                onMore: (x: Song): void => {
                  this.showMenu(x);
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
        .scrollBar(BarState.Auto)
        .padding({ left: 8, right: 8 })
      }

      // 多选操作栏
      if (this.selectMode && this.songs.length > 0) {
        Row({ space: 12 }) {
          Text(this.selectedIds.length === this.songs.length ? '取消全选' : '全选')
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
          Text(`已选 ${this.selectedIds.length} 首`)
            .fontSize(13)
            .fontColor($r('app.color.cm_text2'))
            .layoutWeight(1)
          Button('添加到歌单')
            .height(36)
            .fontSize(13)
            .backgroundColor(this.selectedIds.length > 0 ? this.theme : $r('app.color.cm_divider'))
            .onClick(() => {
              this.model.pushAddToPlaylist(this.selectedIds);
            })
        }
        .width('100%')
        .padding({ left: 16, right: 12, top: 8, bottom: 8 })
        .backgroundColor($r('app.color.cm_card'))
        .border({ width: { top: 0.5 }, color: $r('app.color.cm_divider') })
      }
    }
    .width('100%')
    .height('100%')
  }

  private toggleSelect(s: Song): void {
    const idx: number = this.selectedIds.indexOf(s.id);
    if (idx >= 0) {
      this.selectedIds = this.selectedIds.filter((x: number) => x !== s.id);
    } else {
      this.selectedIds = this.selectedIds.concat([s.id]);
    }
  }

  /** 歌曲长按/更多菜单 */
  private async showMenu(s: Song): Promise<void> {
    const items: string[] = ['下一首播放', s.isLiked ? '取消收藏' : '收藏', '添加到歌单', '从音乐库移除'];
    const idx: number = await this.model.actionMenu(s.title, items);
    if (idx === 0) {
      this.player.insertNext(s);
      this.model.toast('将在下一首播放');
    } else if (idx === 1) {
      this.model.toggleLike(s);
    } else if (idx === 2) {
      this.model.pendingAddSongIds = [s.id];
      this.pickCtrl.open();
    } else if (idx === 3) {
      const ok: boolean = await this.model.confirm('移除歌曲', `确定从音乐库移除「${s.title}」吗？\n（不会删除源文件）`);
      if (ok) {
        this.model.deleteLocalSong(s);
      }
    }
  }

  /** 导入菜单 */
  private async showImportMenu(): Promise<void> {
    const idx: number = await this.model.actionMenu('导入本地音乐',
      ['选择音频文件（推荐）', '重新扫描应用目录']);
    if (idx === 0) {
      LibraryService.getInstance().importPickedAudio().then((n: number) => {
        if (n > 0) {
          this.model.reloadSongs();
        }
      });
    } else if (idx === 1) {
      this.model.rescanLibrary();
    }
  }
}
