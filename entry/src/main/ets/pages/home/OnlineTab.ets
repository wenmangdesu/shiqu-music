/**
 * 在线音乐 Tab：关键词搜索（歌曲/歌手/专辑）+ 在线播放 + 多音质下载
 * 未配置真实API或网络异常时自动使用内置演示数据（可正常播放/下载验证链路）
 */
import { Song } from '../../model/Song';
import { C } from '../../common/Constants';
import { AppModel } from '../../viewmodel/AppModel';
import { PlayerService } from '../../service/PlayerService';
import { OnlineService, SearchResult } from '../../service/OnlineService';
import { DownloadService } from '../../service/DownloadService';
import { SongRow } from '../../view/SongRow';
import { QualityDialog } from '../../view/dialogs/QualityDialog';

@Component
export struct OnlineTab {
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;
  @State keyword: string = '';
  @State results: Song[] = [];
  @State searching: boolean = false;
  @State isDemo: boolean = false;
  @State srcName: string = 'demo';
  @State searched: boolean = false;
  private model: AppModel = AppModel.getInstance();
  private player: PlayerService = PlayerService.getInstance();
  /** 音质对话框的数据载体（同一对象引用，open前更新字段） */
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

  private search(): void {
    const kw: string = this.keyword.trim();
    if (!kw) {
      this.model.toast('请输入搜索关键词');
      return;
    }
    this.searching = true;
    OnlineService.getInstance().search(kw).then((r: SearchResult) => {
      this.results = r.songs;
      this.isDemo = r.isDemo;
      this.srcName = r.sourceName;
      this.searching = false;
      this.searched = true;
    }).catch(() => {
      this.searching = false;
      this.model.toast('搜索失败，请检查网络');
    });
  }

  /** 把选中歌曲字段复制到对话框数据载体 */
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
    Column() {
      // 搜索栏
      Row({ space: 8 }) {
        TextInput({ text: this.keyword, placeholder: '搜索歌曲 / 歌手 / 专辑' })
          .height(38)
          .fontSize(14)
          .layoutWeight(1)
          .backgroundColor($r('app.color.cm_card'))
          .onChange((v: string) => {
            this.keyword = v;
          })
          .onSubmit(() => {
            this.search();
          })
        Button('搜索')
          .height(38)
          .fontSize(14)
          .backgroundColor(this.theme)
          .onClick(() => {
            this.search();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // 数据源提示
      if (this.results.length > 0 && this.isDemo) {
        Text('当前为内置演示数据源（可在 Constants.ONLINE_API_BASE 配置真实API）')
          .fontSize(11)
          .fontColor($r('app.color.cm_text2'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ bottom: 4 })
      } else if (this.results.length > 0 && this.srcName === 'jamendo') {
        Text('音乐来源：Jamendo · CC授权真实曲库（欧美为主，可直接播放/下载）')
          .fontSize(11)
          .fontColor($r('app.color.cm_text2'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ bottom: 4 })
      }

      if (this.searching) {
        Column({ space: 10 }) {
          LoadingProgress().width(36).height(36).color(this.theme)
          Text('正在搜索...').fontSize(13).fontColor($r('app.color.cm_text2'))
        }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
      } else if (this.results.length === 0) {
        // 空态：热门关键词
        Column({ space: 14 }) {
          Text('🔥 热门搜索')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.cm_text'))
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
            ForEach(C.HOT_KEYWORDS, (kw: string) => {
              Text(kw)
                .fontSize(13)
                .fontColor($r('app.color.cm_text'))
                .padding({ left: 14, right: 14, top: 7, bottom: 7 })
                .borderRadius(16)
                .backgroundColor($r('app.color.cm_card'))
                .margin(5)
                .onClick(() => {
                  this.keyword = kw;
                  this.search();
                })
            }, (kw: string) => kw)
          }
          .width('92%')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 2 }) {
          ForEach(this.results, (s: Song, i: number) => {
            ListItem() {
              SongRow({
                song: s,
                index: i,
                onPlay: (x: Song): void => {
                  const idx: number = this.results.indexOf(x);
                  this.player.setQueue(this.results, idx >= 0 ? idx : 0);
                },
                onMore: (x: Song): void => {
                  this.prepareDialog(x);
                  this.qCtrl.open();
                }
              })
            }
          }, (s: Song) => `ol_${s.id}_${s.title}`)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Auto)
        .padding({ left: 8, right: 8 })
      }
    }
    .width('100%')
    .height('100%')
  }
}
