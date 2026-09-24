/**
 * 搜索页：本地搜索 / 在线搜索 双模式
 * 本地：按标题/歌手/专辑过滤本地音乐库
 * 在线：调用OnlineService（含演示数据回退），支持播放与下载
 */
import { Song } from '../model/Song';
import { C } from '../common/Constants';
import { AppModel } from '../viewmodel/AppModel';
import { PlayerService } from '../service/PlayerService';
import { OnlineService, SearchResult } from '../service/OnlineService';
import { DownloadService } from '../service/DownloadService';
import { PrefsService } from '../service/PrefsService';
import { NetUtil } from '../utils/NetUtil';
import { SongRow } from '../view/SongRow';
import { QualityDialog } from '../view/dialogs/QualityDialog';

@Component
export struct SearchPage {
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;
  @StorageProp(C.K_LIBV) @Watch('doLocalSearch') libVersion: number = 0;
  @State modeLocal: boolean = true;
  @State keyword: string = '';
  @State inputText: string = '';
  @State localResults: Song[] = [];
  @State onlineResults: Song[] = [];
  @State searching: boolean = false;
  @State isDemo: boolean = false;
  @State srcName: string = 'demo';
  @State searched: boolean = false;
  @State history: string[] = [];
  @State suggest: string[] = [];
  private model: AppModel = AppModel.getInstance();
  private player: PlayerService = PlayerService.getInstance();
  private dlgSong: Song = new Song();
  private qCtrl: CustomDialogController = new CustomDialogController({
    builder: QualityDialog({
      song: this.dlgSong,
      onPick: (q: string): void => {
        DownloadService.getInstance().addTask(this.dlgSong, q);
      }
    }),
    autoCancel: true,
    alignment: DialogAlignment.Center
  });

  private loadHistory(): void {
    this.history = PrefsService.getInstance().getStrArr(C.P_SEARCH_HISTORY);
  }

  /** 输入时给出本地库搜索建议 */
  private updateSuggest(v: string): void {
    const kw: string = v.trim().toLowerCase();
    if (!kw || this.searched) {
      this.suggest = [];
      return;
    }
    const out: string[] = [];
    this.model.localSongs.forEach((s: Song) => {
      if (out.length >= 6) {
        return;
      }
      if (s.title.toLowerCase().indexOf(kw) >= 0 && out.indexOf(s.title) < 0) {
        out.push(s.title);
      }
      if (out.length < 6 && s.artist.toLowerCase().indexOf(kw) >= 0 && out.indexOf(s.artist) < 0) {
        out.push(s.artist);
      }
    });
    this.suggest = out;
  }

  /** 删除单条搜索历史 */
  private removeHistory(kw: string): void {
    const hist: string[] = this.history.filter((x: string) => x !== kw);
    PrefsService.getInstance().putStrArr(C.P_SEARCH_HISTORY, hist);
    this.history = hist;
  }

  /** 清空搜索历史 */
  private clearHistory(): void {
    PrefsService.getInstance().putStrArr(C.P_SEARCH_HISTORY, []);
    this.history = [];
    this.model.toast('搜索历史已清空');
  }

  private doLocalSearch(): void {
    const kw: string = this.keyword.trim().toLowerCase();
    if (!kw) {
      this.localResults = [];
      return;
    }
    const out: Song[] = [];
    this.model.localSongs.forEach((s: Song) => {
      if (s.title.toLowerCase().indexOf(kw) >= 0 ||
        s.artist.toLowerCase().indexOf(kw) >= 0 ||
        s.album.toLowerCase().indexOf(kw) >= 0) {
        out.push(s);
      }
    });
    this.localResults = out;
  }

  private async search(): Promise<void> {
    const kw: string = this.inputText.trim();
    if (!kw) {
      this.model.toast('请输入搜索关键词');
      return;
    }
    this.keyword = kw;
    this.searched = true;
    this.suggest = [];
    // 保存搜索历史（去重、最多10条）
    const hist: string[] = PrefsService.getInstance().getStrArr(C.P_SEARCH_HISTORY);
    const idx: number = hist.indexOf(kw);
    if (idx >= 0) {
      hist.splice(idx, 1);
    }
    hist.unshift(kw);
    if (hist.length > 10) {
      hist.length = 10;
    }
    PrefsService.getInstance().putStrArr(C.P_SEARCH_HISTORY, hist);
    this.history = hist;
    if (this.modeLocal) {
      this.doLocalSearch();
    } else {
      this.searching = true;
      const netOk: boolean = await NetUtil.hasNet();
      if (!netOk) {
        this.searching = false;
        this.model.toast('当前无网络连接，无法搜索在线音乐');
        return;
      }
      OnlineService.getInstance().search(kw).then((r: SearchResult) => {
        this.onlineResults = r.songs;
        this.isDemo = r.isDemo;
        this.srcName = r.sourceName;
        this.searching = false;
      }).catch(() => {
        this.searching = false;
        this.model.toast('搜索失败，请检查网络');
      });
    }
  }

  private async localMenu(s: Song): Promise<void> {
    const items: string[] =
      ['下一首播放', s.isLiked ? '取消收藏' : '收藏', '添加到歌单', '查看歌手/专辑', '分享'];
    const idx: number = await this.model.actionMenu(s.title, items);
    if (idx === 0) {
      this.player.insertNext(s);
      this.model.toast('将在下一首播放');
    } else if (idx === 1) {
      this.model.toggleLike(s);
    } else if (idx === 2) {
      this.model.pushAddToPlaylist([s.id]);
    } else if (idx === 3) {
      const which: number = await this.model.actionMenu('查看',
        [`歌手：${s.artist || '未知歌手'}`, `专辑：${s.album || '未知专辑'}`]);
      if (which === 0) {
        this.model.pushMusicGroup('artist', s.artist || '未知歌手');
      } else if (which === 1) {
        this.model.pushMusicGroup('album', s.album || '未知专辑');
      }
    } else if (idx === 4) {
      this.model.shareSong(s);
    }
  }

  private prepareDialog(s: Song): void {
    this.dlgSong.id = s.id;
    this.dlgSong.title = s.title;
    this.dlgSong.artist = s.artist;
    this.dlgSong.album = s.album;
    this.dlgSong.duration = s.duration;
    this.dlgSong.filePath = s.filePath;
    this.dlgSong.coverUrl = s.coverUrl;
    this.dlgSong.coverPath = s.coverPath;
    this.dlgSong.format = s.format;
    this.dlgSong.source = s.source;
    this.dlgSong.qStd = s.qStd;
    this.dlgSong.qHigh = s.qHigh;
    this.dlgSong.qLossless = s.qLossless;
  }

  build() {
    NavDestination() {
      Column() {
        // 模式切换
        Row({ space: 8 }) {
          Row({ space: 0 }) {
            Text('本地')
              .fontSize(13)
              .fontColor(this.modeLocal ? '#FFFFFF' : $r('app.color.cm_text'))
              .padding({ left: 16, right: 16, top: 6, bottom: 6 })
              .borderRadius({ topLeft: 16, bottomLeft: 16 })
              .backgroundColor(this.modeLocal ? this.theme : $r('app.color.cm_card'))
              .onClick(() => {
                this.modeLocal = true;
                this.doLocalSearch();
              })
            Text('在线')
              .fontSize(13)
              .fontColor(!this.modeLocal ? '#FFFFFF' : $r('app.color.cm_text'))
              .padding({ left: 16, right: 16, top: 6, bottom: 6 })
              .borderRadius({ topRight: 16, bottomRight: 16 })
              .backgroundColor(!this.modeLocal ? this.theme : $r('app.color.cm_card'))
              .onClick(() => {
                this.modeLocal = false;
              })
          }

          TextInput({ text: this.inputText, placeholder: this.modeLocal ? '搜索本地歌曲' : '搜索在线音乐' })
            .height(36)
            .fontSize(13)
            .layoutWeight(1)
            .backgroundColor($r('app.color.cm_card'))
            .onChange((v: string) => {
              this.inputText = v;
              this.updateSuggest(v);
            })
            .onSubmit(() => {
              this.search();
            })
          Button('搜索')
            .height(36)
            .fontSize(13)
            .padding({ left: 14, right: 14 })
            .backgroundColor(this.theme)
            .onClick(() => {
              this.search();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 10 })

        // 内容区
        if (!this.searched) {
          // 关键词为空：搜索建议 + 历史 + 热门
          Scroll() {
            Column({ space: 14 }) {
              if (this.suggest.length > 0) {
                Text('搜索建议').fontSize(14).fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.cm_text')).width('100%')
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.suggest, (kw: string) => {
                    Text(kw)
                      .fontSize(12)
                      .fontColor($r('app.color.cm_text'))
                      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                      .borderRadius(14)
                      .backgroundColor($r('app.color.cm_marker'))
                      .margin(4)
                      .onClick(() => {
                        this.inputText = kw;
                        this.search();
                      })
                  }, (kw: string) => `sg_${kw}`)
                }
                .width('100%')
              }
              if (this.history.length > 0) {
                Row({ space: 10 }) {
                  Text('搜索历史').fontSize(14).fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.cm_text')).layoutWeight(1)
                  Text('清空')
                    .fontSize(12)
                    .fontColor($r('app.color.cm_accent'))
                    .onClick(() => {
                      this.clearHistory();
                    })
                }
                .width('100%')
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.history, (kw: string) => {
                    Text(kw)
                      .fontSize(12)
                      .fontColor($r('app.color.cm_text'))
                      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                      .borderRadius(14)
                      .backgroundColor($r('app.color.cm_card'))
                      .border({ width: 2, color: $r('app.color.cm_text') })
                      .margin(4)
                      .onClick(() => {
                        this.inputText = kw;
                        this.search();
                      })
                      .gesture(LongPressGesture({ repeat: false })
                        .onAction(() => {
                          // 长按删除单条历史
                          this.removeHistory(kw);
                          this.model.toast('已删除该条历史');
                        }))
                  }, (kw: string) => kw)
                }
                .width('100%')
                Text('长按历史条目可单条删除')
                  .fontSize(10)
                  .fontColor($r('app.color.cm_text2'))
                  .width('100%')
              }
              Text('热门推荐').fontSize(14).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.cm_text')).width('100%')
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(C.HOT_KEYWORDS, (kw: string) => {
                  Text(kw)
                    .fontSize(12)
                    .fontColor($r('app.color.cm_text'))
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .borderRadius(14)
                    .backgroundColor($r('app.color.cm_card'))
                    .border({ width: 2, color: $r('app.color.cm_text') })
                    .margin(4)
                    .onClick(() => {
                      this.inputText = kw;
                      this.search();
                    })
                }, (kw: string) => `hot_${kw}`)
              }
              .width('100%')
            }
            .padding({ left: 16, right: 16 })
            .constraintSize({ maxWidth: 720 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .align(Alignment.Top)
        } else if (this.searching) {
          Column({ space: 10 }) {
            LoadingProgress().width(36).height(36).color(this.theme)
            Text('正在搜索...').fontSize(13).fontColor($r('app.color.cm_text2'))
          }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
        } else if (this.modeLocal) {
          // 本地结果
          if (this.localResults.length === 0) {
            Column({ space: 8 }) {
              Text('🔍').fontSize(36)
              Text('本地没有找到相关歌曲').fontSize(13).fontColor($r('app.color.cm_text2'))
            }
              .width('100%')
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
          } else {
            List({ space: 2 }) {
              ForEach(this.localResults, (s: Song, i: number) => {
                ListItem() {
                  SongRow({
                    song: s,
                    index: i,
                    onPlay: (x: Song): void => {
                      const idx: number = this.localResults.indexOf(x);
                      this.player.setQueue(this.localResults, idx >= 0 ? idx : 0);
                    },
                    onMore: (x: Song): void => {
                      this.localMenu(x);
                    }
                  })
                }
              }, (s: Song) => `sl_${this.libVersion}_${s.id}`)
            }
            .layoutWeight(1)
            .width('100%')
            .padding({ left: 8, right: 8 })
          }
        } else {
          // 在线结果
          if (this.isDemo && this.onlineResults.length > 0) {
            Text('当前为内置演示数据源（可在 Constants.ONLINE_API_BASE 配置真实API）')
              .fontSize(11)
              .fontColor($r('app.color.cm_text2'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ bottom: 4 })
          } else if (this.srcName === 'jamendo' && this.onlineResults.length > 0) {
            Text('音乐来源：Jamendo · CC授权真实曲库（欧美为主，可直接播放/下载）')
              .fontSize(11)
              .fontColor($r('app.color.cm_text2'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ bottom: 4 })
          }
          if (this.onlineResults.length === 0) {
            Column({ space: 8 }) {
              Text('☁️').fontSize(36)
              Text('没有找到相关歌曲').fontSize(13).fontColor($r('app.color.cm_text2'))
            }
              .width('100%')
              .layoutWeight(1)
              .justifyContent(FlexAlign.Center)
          } else {
            List({ space: 2 }) {
              ForEach(this.onlineResults, (s: Song, i: number) => {
                ListItem() {
                  SongRow({
                    song: s,
                    index: i,
                    onPlay: (x: Song): void => {
                      const idx: number = this.onlineResults.indexOf(x);
                      this.player.setQueue(this.onlineResults, idx >= 0 ? idx : 0);
                    },
                    onMore: (x: Song): void => {
                      this.prepareDialog(x);
                      this.qCtrl.open();
                    }
                  })
                }
              }, (s: Song) => `so_${s.id}_${s.title}`)
            }
            .layoutWeight(1)
            .width('100%')
            .padding({ left: 8, right: 8 })
          }
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.cm_bg'))
    }
    .title('搜索')
    .onShown(() => {
      this.loadHistory();
    })
  }
}
