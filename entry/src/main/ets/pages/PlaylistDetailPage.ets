/**
 * 歌单详情页
 * 展示歌单内歌曲，支持：播放全部、添加歌曲、左滑移除、
 * 重命名/设置封面/删除歌单（"我喜欢"为只读默认歌单，左滑取消收藏）
 */
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import fs from '@ohos.file.fs';
import { Playlist } from '../model/Playlist';
import { Song } from '../model/Song';
import { C } from '../common/Constants';
import { AppModel } from '../viewmodel/AppModel';
import { PlayerService } from '../service/PlayerService';
import { LibraryService } from '../service/LibraryService';
import { SongRow } from '../view/SongRow';

@Component
export struct PlaylistDetailPage {
  @StorageProp(C.K_PLV) @Watch('reload') plVersion: number = 0;
  @StorageProp(C.K_LIBV) @Watch('reload') libVersion: number = 0;
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;
  @State pl: Playlist = new Playlist();
  @State songs: Song[] = [];
  @State plName: string = '歌单';
  @State kw: string = '';
  private model: AppModel = AppModel.getInstance();
  private player: PlayerService = PlayerService.getInstance();

  aboutToAppear(): void {
    this.reload();
  }

  /** 歌单内搜索后的展示列表 */
  private shown(): Song[] {
    const k: string = this.kw.trim().toLowerCase();
    if (!k) {
      return this.songs;
    }
    const out: Song[] = [];
    this.songs.forEach((s: Song) => {
      if (s.title.toLowerCase().indexOf(k) >= 0 || s.artist.toLowerCase().indexOf(k) >= 0) {
        out.push(s);
      }
    });
    return out;
  }

  /** 歌单内歌曲上移/下移（我喜欢为自动汇总不支持） */
  private moveSong(i: number, dir: number): void {
    if (this.isLikedPl()) {
      return;
    }
    const ti: number = i + dir;
    if (ti < 0 || ti >= this.songs.length) {
      return;
    }
    const ids: number[] = this.pl.songIds.slice();
    const si: number = ids.indexOf(this.songs[i].id);
    const sj: number = ids.indexOf(this.songs[ti].id);
    if (si < 0 || sj < 0) {
      return;
    }
    ids[si] = this.songs[ti].id;
    ids[sj] = this.songs[i].id;
    this.model.reorderPlaylist(this.pl.id, ids);
  }

  reload(): void {
    const id: number = this.model.currentPlaylistId;
    const found: Playlist | null = id === -1 ? this.model.likedPlaylist() : this.model.getPlaylistById(id);
    if (found) {
      this.pl = found;
      this.plName = found.name;
      this.songs = this.model.getPlaylistSongs(found);
    } else {
      this.pl = new Playlist();
      this.pl.name = '歌单不存在';
      this.songs = [];
    }
  }

  private isLikedPl(): boolean {
    return this.pl.id === -1;
  }

  private coverSrc(): string {
    if (this.pl.coverPath) {
      return `file://${this.pl.coverPath}`;
    }
    for (let i = 0; i < this.songs.length; i++) {
      if (this.songs[i].coverPath) {
        return `file://${this.songs[i].coverPath}`;
      }
      if (this.songs[i].coverUrl) {
        return this.songs[i].coverUrl;
      }
    }
    return '';
  }

  private removeSong(s: Song): void {
    if (this.isLikedPl()) {
      this.model.toggleLike(s);
    } else {
      this.model.removeSongFromPlaylist(this.pl.id, s.id).then(() => {
        this.model.toast('已移出歌单');
      });
    }
  }

  private async plMenu(): Promise<void> {
    const idx: number = await this.model.actionMenu(this.pl.name, ['重命名歌单', '设置封面', '删除歌单']);
    if (idx === 0) {
      this.model.pushCreatePlaylist(this.pl.id);
    } else if (idx === 1) {
      this.pickCover();
    } else if (idx === 2) {
      const ok: boolean =
        await this.model.confirm('删除歌单', `确定删除歌单「${this.pl.name}」吗？\n（歌曲不会被删除）`);
      if (ok) {
        this.model.deletePlaylistById(this.pl.id).then(() => {
          this.model.toast('歌单已删除');
          this.model.navStack.pop();
        });
      }
    }
  }

  /** 从相册选择封面（无需存储权限） */
  private async pickCover(): Promise<void> {
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
      const dest: string =
        `${this.model.context.filesDir}/${C.COVER_DIR}/pl_${this.pl.id}_${Date.now() % 100000}.img`;
      LibraryService.getInstance().copyUriToFile(result.photoUris[0], dest);
      if (fs.accessSync(dest)) {
        await this.model.setPlaylistCover(this.pl.id, dest);
        this.model.toast('封面已更新');
      }
    } catch (err) {
      this.model.toast('未选择封面');
    }
  }

  build() {
    NavDestination() {
      Column() {
        // 头部
        Row({ space: 14 }) {
          if (this.coverSrc() !== '') {
            Image(this.coverSrc())
              .width(76)
              .height(76)
              .borderRadius(12)
              .objectFit(ImageFit.Cover)
          } else {
            Column() {
              Text(this.isLikedPl() ? '♥' : '♪').fontSize(28)
                .fontColor(this.isLikedPl() ? '#E5484D' : '#8C8570')
            }
            .width(76)
            .height(76)
            .borderRadius(12)
            .justifyContent(FlexAlign.Center)
            .backgroundColor($r('app.color.cm_marker'))
          }

          Column({ space: 4 }) {
            Text(this.plName)
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor($r('app.color.cm_text'))
            Text(`${this.songs.length}首歌曲${this.isLikedPl() ? ' · 收藏自动汇总' : ''}`)
              .fontSize(11)
              .fontColor($r('app.color.cm_text2'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          if (!this.isLikedPl()) {
            Text('⋯')
              .fontSize(20)
              .fontColor($r('app.color.cm_text'))
              .padding({ left: 8, right: 4 })
              .onClick(() => {
                this.plMenu();
              })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })

        // 操作行
        Row({ space: 10 }) {
          Button('▶ 播放全部')
            .height(38)
            .fontSize(14)
            .backgroundColor(this.theme)
            .onClick(() => {
              if (this.songs.length === 0) {
                this.model.toast('歌单还没有歌曲');
                return;
              }
              this.player.setQueue(this.songs, 0);
            })
          if (!this.isLikedPl()) {
            Button('＋ 添加歌曲')
              .height(38)
              .fontSize(14)
              .backgroundColor($r('app.color.cm_card'))
              .fontColor($r('app.color.cm_text'))
              .onClick(() => {
                this.model.pushPickSongs(this.pl.id);
              })
          }
          Blank()
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })

        // 歌单内搜索
        Row({ space: 8 }) {
          Text('🔍').fontSize(13).fontColor($r('app.color.cm_text2'))
          TextInput({ text: this.kw, placeholder: '在当前歌单内搜索' })
            .height(34)
            .fontSize(12)
            .layoutWeight(1)
            .backgroundColor($r('app.color.cm_card'))
            .border({ width: 1.5, color: $r('app.color.cm_divider') })
            .onChange((v: string) => {
              this.kw = v;
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 6 })

        // 歌曲列表
        if (this.songs.length === 0) {
          Column({ space: 10 }) {
            Text('🎼').fontSize(40)
            Text(this.isLikedPl() ? '还没有收藏的歌曲\n在歌曲菜单中选择"收藏"即可添加'
              : '歌单还是空的\n点击"＋ 添加歌曲"开始创建')
              .fontSize(12)
              .fontColor($r('app.color.cm_text2'))
              .textAlign(TextAlign.Center)
          }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
        } else if (this.shown().length === 0) {
          Column({ space: 10 }) {
            Text('🔍').fontSize(36)
            Text(`歌单内没有包含"${this.kw}"的歌曲`)
              .fontSize(12)
              .fontColor($r('app.color.cm_text2'))
              .textAlign(TextAlign.Center)
          }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 2 }) {
            ForEach(this.shown(), (s: Song, i: number) => {
              ListItem() {
                Row({ space: 4 }) {
                  // 歌单排序（我喜欢为自动汇总，不支持手动排序）
                  if (!this.isLikedPl() && !this.kw.trim()) {
                    Column({ space: 10 }) {
                      Text('↑')
                        .fontSize(13)
                        .fontColor(i > 0 ? $r('app.color.cm_text2') : $r('app.color.cm_divider'))
                        .onClick(() => {
                          this.moveSong(i, -1);
                        })
                      Text('↓')
                        .fontSize(13)
                        .fontColor(i < this.shown().length - 1 ? $r('app.color.cm_text2') : $r('app.color.cm_divider'))
                        .onClick(() => {
                          this.moveSong(i, 1);
                        })
                    }
                    .width(20)
                  }
                  SongRow({
                    song: s,
                    index: i,
                    onPlay: (x: Song): void => {
                      const idx: number = this.shown().indexOf(x);
                      this.player.setQueue(this.shown(), idx >= 0 ? idx : 0);
                    },
                    onMore: (x: Song): void => {
                      this.removeSong(x);
                    }
                  })
                  .layoutWeight(1)
                }
                .width('100%')
              }
              .swipeAction({ end: this.removeBtn(s) })
            }, (s: Song) => `${this.plVersion}_${this.libVersion}_${s.id}_${this.kw}`)
          }
          .layoutWeight(1)
          .width('100%')
          .scrollBar(BarState.Auto)
          .padding({ left: 8, right: 8 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.cm_bg'))
      .constraintSize({ maxWidth: 760 })
    }
    .title(this.plName)
  }

  /** 左滑移除按钮 */
  @Builder
  removeBtn(s: Song) {
    Row() {
      Text(this.isLikedPl() ? '取消收藏' : '移除')
        .fontSize(13)
        .fontColor('#FFFFFF')
    }
    .width(72)
    .height('82%')
    .justifyContent(FlexAlign.Center)
    .borderRadius(10)
    .backgroundColor('#E5484D')
    .margin({ left: 8, top: 4, bottom: 4 })
    .onClick(() => {
      this.removeSong(s);
    })
  }
}
