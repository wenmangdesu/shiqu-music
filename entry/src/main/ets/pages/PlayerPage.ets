/**
 * 播放页（全屏）
 * 功能：专辑封面（侧滑切歌手势/点击切换歌词视图）、进度条拖拽、
 *      播放模式切换、收藏、倍速、播放队列管理（删除/排序/跳转）、
 *      音效均衡器面板、下载、系统音量（右侧边缘上下滑动手势 + 面板）、桌面歌词开关
 */
import { Song } from '../model/Song';
import { C } from '../common/Constants';
import { FmtUtil } from '../utils/FmtUtil';
import { AppModel } from '../viewmodel/AppModel';
import { PlayerService } from '../service/PlayerService';
import { DownloadService } from '../service/DownloadService';
import { PrefsService } from '../service/PrefsService';
import { CoverImage } from '../view/CoverImage';
import { LyricView } from '../view/LyricView';
import { QualityDialog } from '../view/dialogs/QualityDialog';

/** 次级操作项参数（按引用传递给@Builder，保证状态变化时UI刷新） */
class SubItemParam {
  label: string = '';
  icon: string = '';
  onTap: () => void = () => {
  };
}

@Component
export struct PlayerPage {
  @StorageLink(C.K_SONG) song: Song = new Song();
  @StorageProp(C.K_PLAYING) playing: boolean = false;
  @StorageProp(C.K_POS) pos: number = 0;
  @StorageProp(C.K_DUR) dur: number = 0;
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;
  @StorageProp(C.K_LIKED) liked: boolean = false;
  @StorageProp(C.K_MODE) mode: number = C.PLAY_MODE_LIST;
  @StorageProp(C.K_SPEED) speed: number = 1;
  @StorageProp(C.K_QUEUEV) @Watch('reloadQueue') queueV: number = 0;
  @State queue: Song[] = [];
  @State lyricMode: boolean = false;
  @State dragging: boolean = false;
  @State dragPos: number = 0;
  @State dragX: number = 0;
  @State showSheet: boolean = false;
  @State sheetMode: string = 'queue';
  @State eqPreset: number = 0;
  @State eqBands: number[] = [0, 0, 0, 0, 0];
  @State vol: number = 8;
  @State volShow: boolean = false;
  @State muted: boolean = false;
  @State playPressed: boolean = false;
  private prevVol: number = 8;
  private volStart: number = 8;
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
    customStyle: true
  });

  aboutToAppear(): void {
    this.reloadQueue();
    this.eqPreset = PrefsService.getInstance().getNum(C.P_EQ_PRESET, 0);
    this.eqBands = this.loadBands();
    this.player.getMediaVolume().then((v: number) => {
      if (v >= 0) {
        this.vol = v;
      }
    }).catch(() => {
    });
  }

  reloadQueue(): void {
    this.queue = this.player.queue.slice();
  }

  private loadBands(): number[] {
    try {
      const arr = JSON.parse(PrefsService.getInstance().getStr(C.P_EQ_BANDS, '[]')) as Array<Object>;
      if (arr.length === C.EQ_FREQS.length) {
        const out: number[] = [];
        arr.forEach((v: Object) => {
          out.push(Number(v));
        });
        return out;
      }
    } catch (err) {
      // JSON损坏时使用预设
    }
    return C.EQ_PRESET_BANDS[this.eqPreset].slice();
  }

  private saveEq(): void {
    PrefsService.getInstance().putNum(C.P_EQ_PRESET, this.eqPreset);
    PrefsService.getInstance().putStr(C.P_EQ_BANDS, JSON.stringify(this.eqBands));
  }

  private modeIcon(): string {
    if (this.mode === C.PLAY_MODE_SINGLE) {
      return '🔂';
    }
    if (this.mode === C.PLAY_MODE_RANDOM) {
      return '🔀';
    }
    if (this.mode === C.PLAY_MODE_ORDER) {
      return '➡️';
    }
    return '🔁';
  }

  private hasSong(): boolean {
    return this.song.id !== 0 || this.song.title !== '';
  }

  private prepareDownload(): void {
    // 复制当前歌曲信息到对话框数据载体
    this.dlgSong.id = this.song.id;
    this.dlgSong.title = this.song.title;
    this.dlgSong.artist = this.song.artist;
    this.dlgSong.album = this.song.album;
    this.dlgSong.duration = this.song.duration;
    this.dlgSong.filePath = this.song.filePath;
    this.dlgSong.coverUrl = this.song.coverUrl;
    this.dlgSong.coverPath = this.song.coverPath;
    this.dlgSong.format = this.song.format;
    this.dlgSong.source = this.song.source;
    this.dlgSong.qStd = this.song.qStd;
    this.dlgSong.qHigh = this.song.qHigh;
    this.dlgSong.qLossless = this.song.qLossless;
    this.qCtrl.open();
  }

  private openSheet(mode: string): void {
    this.sheetMode = mode;
    this.showSheet = true;
  }

  private async topMenu(): Promise<void> {
    const floatOn: boolean = AppStorage.get<boolean>(C.K_FLOAT) ?? false;
    const idx: number = await this.model.actionMenu('更多操作',
      ['音效均衡器', '播放队列', '倍速调节', '系统音量', '定时关闭', floatOn ? '关闭桌面歌词' : '开启桌面歌词']);
    if (idx === 0) {
      this.openSheet('eq');
    } else if (idx === 1) {
      this.openSheet('queue');
    } else if (idx === 2) {
      this.openSheet('speed');
    } else if (idx === 3) {
      this.openSheet('volume');
    } else if (idx === 4) {
      const choice: number = await this.model.actionMenu('定时关闭',
        ['取消定时', '15分钟后', '30分钟后', '45分钟后', '60分钟后', '更多选项']);
      if (choice === 0) {
        this.player.setSleepTimer(0);
      } else if (choice === 1) {
        this.player.setSleepTimer(15);
      } else if (choice === 2) {
        this.player.setSleepTimer(30);
      } else if (choice === 3) {
        this.player.setSleepTimer(45);
      } else if (choice === 4) {
        this.player.setSleepTimer(60);
      } else if (choice === 5) {
        const more: number = await this.model.actionMenu('更多定时选项', ['90分钟后', '播完这首就停']);
        if (more === 0) {
          this.player.setSleepTimer(90);
        } else if (more === 1) {
          this.player.setSleepTimer(-1);
        }
      }
    } else if (idx === 5) {
      const next: boolean = !floatOn;
      AppStorage.setOrCreate(C.K_FLOAT, next);
      PrefsService.getInstance().putBool(C.P_FLOAT, next);
      this.model.toast(next ? '桌面歌词已开启' : '桌面歌词已关闭');
    }
  }

  build() {
    NavDestination() {
      Stack() {
        // ===== 背景：作业本横线纸 =====
        Column() {
          ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], (n: number) => {
            Divider()
              .color($r('app.color.cm_line'))
              .strokeWidth(2)
              .margin({ top: 46 })
          }, (n: number) => `rule_${n}`)
        }
        .width('100%')
        .height('100%')

        // ===== 主内容 =====
        Column() {
          // 顶部栏
          Row({ space: 12 }) {
            Text('⌄')
              .fontSize(24)
              .fontColor($r('app.color.cm_text'))
              .onClick(() => {
                this.model.navStack.pop();
              })
            Column({ space: 2 }) {
              Text(this.hasSong() ? this.song.title : '未在播放')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .fontColor($r('app.color.cm_text'))
              Text(`${this.song.artist || '未知歌手'} · ${this.song.album || '未知专辑'}`)
                .fontSize(11)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .fontColor($r('app.color.cm_text2'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)

            Text('⋯')
              .fontSize(20)
              .fontColor($r('app.color.cm_text'))
              .padding({ left: 6, right: 6 })
              .onClick(() => {
                this.topMenu();
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 6 })

          // 中部：封面 / 歌词
          if (!this.lyricMode) {
            Stack() {
              Column() {
                Column() {
                  Stack() {
                    CoverImage({
                      coverPath: this.song.coverPath,
                      coverUrl: this.song.coverUrl,
                      imgSize: 290,
                      radius: 20
                    })
                      .translate({ x: this.dragX })
                      .rotate({ y: 1, angle: this.dragX * 0.06 })
                      .scale({ x: this.playing ? 1 : 0.95, y: this.playing ? 1 : 0.95 })
                      .animation({ duration: 260, curve: Curve.EaseOut })
                      .shadow({ radius: 30, color: '#33000000', offsetY: 8 })
                    // 贴照片的胶带
                    Text(' ')
                      .width(96)
                      .height(26)
                      .backgroundColor('#F6E7A9')
                      .opacity(0.92)
                      .rotate({ angle: -32 })
                      .position({ x: 6, y: -8 })
                    Text(' ')
                      .width(96)
                      .height(26)
                      .backgroundColor('#F6E7A9')
                      .opacity(0.92)
                      .rotate({ angle: 32 })
                      .position({ x: 190, y: -8 })
                  }
                }
                .justifyContent(FlexAlign.Center)
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
            }
            .width('100%')
            .layoutWeight(1)
            .animation({ duration: 200, curve: Curve.EaseOut })
            .onClick(() => {
              this.lyricMode = true;
            })
            .gesture(PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 24 })
              .onActionUpdate((e: GestureEvent) => {
                this.dragX = Math.max(-110, Math.min(110, e.offsetX));
              })
              .onActionEnd((e: GestureEvent) => {
                const dx: number = e.offsetX;
                this.dragX = 0;
                if (dx < -60) {
                  this.player.next();
                } else if (dx > 60) {
                  this.player.prev();
                }
              }))
          } else {
            Column() {
              LyricView()
                .layoutWeight(1)
              Text('♫ 点击封面返回')
                .fontSize(11)
                .fontColor($r('app.color.cm_text2'))
                .padding({ bottom: 8 })
                .onClick(() => {
                  this.lyricMode = false;
                })
            }
            .width('100%')
            .layoutWeight(1)
          }

          // ===== 进度条 =====
          Row({ space: 10 }) {
            Text(FmtUtil.fmtDuration(this.dragging ? this.dragPos : this.pos))
              .fontSize(11)
              .fontColor($r('app.color.cm_text2'))
              .width(42)
              .textAlign(TextAlign.Center)
            Slider({
              value: this.dragging ? this.dragPos : Math.min(this.pos, this.dur > 0 ? this.dur : 1),
              min: 0,
              max: this.dur > 0 ? this.dur : 1,
              step: 1,
              style: SliderStyle.OutSet
            })
              .layoutWeight(1)
              .selectedColor(this.theme)
              .trackColor($r('app.color.cm_divider'))
              .onChange((v: number, m: SliderChangeMode) => {
                if (m === SliderChangeMode.Begin) {
                  this.dragging = true;
                  this.dragPos = v;
                } else if (m === SliderChangeMode.Moving) {
                  this.dragPos = v;
                } else {
                  this.dragging = false;
                  this.player.seek(v);
                }
              })
            Text(FmtUtil.fmtDuration(this.dur))
              .fontSize(11)
              .fontColor($r('app.color.cm_text2'))
              .width(42)
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })

          // ===== 主控制区 =====
          Row({ space: 26 }) {
            Text(this.modeIcon())
              .fontSize(24)
              .onClick(() => {
                const m: number = (this.mode + 1) % 4;
                this.player.setMode(m);
                this.model.toast(C.playModeLabel(m));
              })
            Text('⏮')
              .fontSize(30)
              .fontColor($r('app.color.cm_text'))
              .onClick(() => {
                this.player.prev();
              })
              .gesture(LongPressGesture({ repeat: false })
                .onAction(() => {
                  // 长按上一首：快退15秒
                  this.player.seek(Math.max(0, this.pos - 15000));
                  this.model.toast('快退 15 秒');
                }))
            Text(this.playing ? '⏸' : '▶')
              .fontSize(34)
              .fontColor('#FFFFFF')
              .width(76)
              .height(76)
              .textAlign(TextAlign.Center)
              .borderRadius(38)
              .backgroundColor(this.theme)
              .shadow({ radius: 14, color: '#332B3A55', offsetY: 4 })
              .scale({ x: this.playPressed ? 0.92 : 1, y: this.playPressed ? 0.92 : 1 })
              .animation({ duration: 130, curve: Curve.EaseOut })
              .onTouch((event: TouchEvent) => {
                if (event.type === TouchType.Down) {
                  this.playPressed = true;
                } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                  this.playPressed = false;
                }
              })
              .onClick(() => {
                this.player.togglePlay();
              })
            Text('⏭')
              .fontSize(30)
              .fontColor($r('app.color.cm_text'))
              .onClick(() => {
                this.player.next();
              })
              .gesture(LongPressGesture({ repeat: false })
                .onAction(() => {
                  // 长按下一首：快进15秒
                  this.player.seek(this.pos + 15000);
                  this.model.toast('快进 15 秒');
                }))
            Text(this.liked ? '♥' : '♡')
              .fontSize(26)
              .fontColor(this.liked ? $r('app.color.cm_accent') : $r('app.color.cm_text2'))
              .onClick(() => {
                if (this.hasSong()) {
                  this.model.toggleLike(this.song);
                }
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 10, bottom: 6 })

          // ===== 次级操作区 =====
          Row({ space: 0 }) {
            this.subItem({ label: '倍速', icon: `${this.speed}x`, onTap: (): void => {
              this.openSheet('speed');
            } })
            this.subItem({ label: '队列', icon: '≡', onTap: (): void => {
              this.openSheet('queue');
            } })
            this.subItem({ label: '歌词页', icon: '词', onTap: (): void => {
              this.model.pushPage('Lyrics');
            } })
            this.subItem({ label: '下载', icon: '⬇', onTap: (): void => {
              if (this.hasSong()) {
                this.prepareDownload();
              }
            } })
            this.subItem({ label: '音量', icon: '🔊', onTap: (): void => {
              this.openSheet('volume');
            } })
          }
          .width('92%')
          .padding({ bottom: 14 })
        }
        .width('100%')
        .height('100%')
        .constraintSize({ maxWidth: 680 })

        // ===== 音量手势区（右侧边缘上下滑动） =====
        Column()
          .width(36)
          .height('100%')
          .position({ x: '88%', y: 0 })
          .hitTestBehavior(HitTestMode.Transparent)
          .gesture(PanGesture({ fingers: 1, direction: PanDirection.Vertical, distance: 4 })
            .onActionStart(() => {
              this.player.getMediaVolume().then((v: number) => {
                this.volStart = v >= 0 ? v : this.vol;
              }).catch(() => {
                this.volStart = this.vol;
              });
              this.volShow = true;
            })
            .onActionUpdate((e: GestureEvent) => {
              const v: number = Math.max(0, Math.min(15, Math.round(this.volStart - e.offsetY * 0.08)));
              this.vol = v;
              this.player.setMediaVolume(v);
            })
            .onActionEnd(() => {
              this.volShow = false;
            }))

        // ===== 音量浮层 =====
        if (this.volShow) {
          Column({ space: 6 }) {
            Text('🔊').fontSize(22)
            Text(`${this.vol}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .width(84)
          .height(84)
          .borderRadius(42)
          .backgroundColor('#AA000000')
          .justifyContent(FlexAlign.Center)
        }

        // ===== 底部功能面板 =====
      }
      .width('100%')
      .height('100%')
      .bindSheet($$this.showSheet, this.sheetBuilder(), {
        height: this.sheetMode === 'queue' ? 520 : 440,
        dragBar: true,
        backgroundColor: $r('app.color.cm_card'),
        title: { title: this.sheetMode === 'queue' ? '播放队列' :
          (this.sheetMode === 'eq' ? '音效均衡器' : (this.sheetMode === 'speed' ? '倍速播放' : '系统音量')) }
      })
    }
    .hideTitleBar(true)
  }

  @Builder
  subItem($$: SubItemParam) {
    Column({ space: 3 }) {
      Text($$.icon)
        .fontSize(18)
        .fontColor($r('app.color.cm_text'))
      Text($$.label)
        .fontSize(10)
        .fontColor($r('app.color.cm_text2'))
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      $$.onTap();
    })
  }

  @Builder
  sheetBuilder() {
    if (this.sheetMode === 'queue') {
      this.queueSheet()
    } else if (this.sheetMode === 'eq') {
      this.eqSheet()
    } else if (this.sheetMode === 'speed') {
      this.speedSheet()
    } else {
      this.volumeSheet()
    }
  }

  /** 播放队列面板：跳转 / 上下移动排序 / 删除 */
  @Builder
  queueSheet() {
    Column({ space: 6 }) {
      Row({ space: 10 }) {
        Text(`共 ${this.queue.length} 首`)
          .fontSize(12)
          .fontColor($r('app.color.cm_text2'))
          .layoutWeight(1)
        Text(C.playModeLabel(this.mode))
          .fontSize(12)
          .fontColor(this.theme)
          .onClick(() => {
            const m: number = (this.mode + 1) % 4;
            this.player.setMode(m);
          })
        Text('清空')
          .fontSize(12)
          .fontColor($r('app.color.cm_accent'))
          .onClick(() => {
            this.player.clearQueue();
          })
      }
      .width('100%')

      if (this.queue.length === 0) {
        Text('队列为空')
          .fontSize(13)
          .fontColor($r('app.color.cm_text2'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 40 })
      } else {
        List({ space: 2 }) {
          ForEach(this.queue, (s: Song, i: number) => {
            ListItem() {
              Row({ space: 8 }) {
                Text(this.song.id === s.id && this.song.filePath === s.filePath ? '▶' : `${i + 1}`)
                  .fontSize(12)
                  .fontColor(this.song.id === s.id ? this.theme : $r('app.color.cm_text2'))
                  .width(24)
                  .textAlign(TextAlign.Center)
                Column({ space: 2 }) {
                  Text(s.title)
                    .fontSize(14)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .fontColor(this.song.id === s.id ? this.theme : $r('app.color.cm_text'))
                  Text(s.artist)
                    .fontSize(11)
                    .fontColor($r('app.color.cm_text2'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Text('↑')
                  .fontSize(15)
                  .fontColor(i > 0 ? $r('app.color.cm_text2') : $r('app.color.cm_divider'))
                  .width(28)
                  .textAlign(TextAlign.Center)
                  .onClick(() => {
                    if (i > 0) {
                      this.player.moveInQueue(i, i - 1);
                    }
                  })
                Text('↓')
                  .fontSize(15)
                  .fontColor(i < this.queue.length - 1 ? $r('app.color.cm_text2') : $r('app.color.cm_divider'))
                  .width(28)
                  .textAlign(TextAlign.Center)
                  .onClick(() => {
                    if (i < this.queue.length - 1) {
                      this.player.moveInQueue(i, i + 1);
                    }
                  })
                Text('✕')
                  .fontSize(14)
                  .fontColor($r('app.color.cm_text2'))
                  .width(28)
                  .textAlign(TextAlign.Center)
                  .onClick(() => {
                    this.player.removeFromQueue(i);
                  })
              }
              .width('100%')
              .padding({ top: 8, bottom: 8, left: 4, right: 4 })
              .borderRadius(8)
              .backgroundColor(this.song.id === s.id ? '#59FFE45C' : Color.Transparent)
              .onClick(() => {
                this.player.playIndex(i);
              })
            }
          }, (s: Song, i: number) => `${this.queueV}_${i}_${s.id}`)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, bottom: 12 })
  }

  /** 均衡器面板：预设 + 五段自定义（设置将保存） */
  @Builder
  eqSheet() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        ForEach(C.EQ_PRESETS, (name: string, i: number) => {
          Text(name)
            .fontSize(12)
            .fontColor(this.eqPreset === i ? '#FFFFFF' : $r('app.color.cm_text'))
            .padding({ left: 13, right: 13, top: 6, bottom: 6 })
            .borderRadius(14)
            .backgroundColor(this.eqPreset === i ? this.theme : $r('app.color.cm_bg'))
            .onClick(() => {
              this.eqPreset = i;
              this.eqBands = C.EQ_PRESET_BANDS[i].slice();
              this.saveEq();
            })
        }, (name: string) => name)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      ForEach([0, 1, 2, 3, 4], (i: number) => {
        Row({ space: 10 }) {
          Text(C.EQ_FREQS[i] >= 1000 ? `${C.EQ_FREQS[i] / 1000}kHz` : `${C.EQ_FREQS[i]}Hz`)
            .fontSize(11)
            .fontColor($r('app.color.cm_text2'))
            .width(48)
            .textAlign(TextAlign.Center)
          Slider({ value: this.eqBands[i], min: -12, max: 12, step: 1, style: SliderStyle.OutSet })
            .layoutWeight(1)
            .selectedColor(this.theme)
            .trackColor($r('app.color.cm_divider'))
            .onChange((v: number, m: SliderChangeMode) => {
              this.eqBands[i] = Math.round(v);
              if (m === SliderChangeMode.End || m === SliderChangeMode.Click) {
                this.eqPreset = 4;
                // 重新赋值触发UI刷新（dB标签联动）
                this.eqBands = this.eqBands.slice();
                this.saveEq();
              }
            })
          Text(`${this.eqBands[i] > 0 ? '+' : ''}${this.eqBands[i]}dB`)
            .fontSize(11)
            .fontColor($r('app.color.cm_text2'))
            .width(52)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
      }, (i: number) => `band_${i}_${this.eqPreset}`)

      Text('预设将自动保存；实际音效依赖系统音频能力')
        .fontSize(11)
        .fontColor($r('app.color.cm_text2'))
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 16 })
  }

  /** 倍速面板 */
  @Builder
  speedSheet() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        ForEach([0.75, 1.0, 1.25, 1.75, 2.0], (v: number) => {
          Text(`${v}x`)
            .fontSize(14)
            .fontColor(this.speed === v ? '#FFFFFF' : $r('app.color.cm_text'))
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .borderRadius(16)
            .backgroundColor(this.speed === v ? this.theme : $r('app.color.cm_bg'))
            .onClick(() => {
              this.player.setSpeed(v);
            })
        }, (v: number) => `sp_${v}`)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      Text('倍速设置即时生效并保存')
        .fontSize(11)
        .fontColor($r('app.color.cm_text2'))
    }
    .width('100%')
    .padding(20)
  }

  /** 系统音量面板 */
  @Builder
  volumeSheet() {
    Column({ space: 14 }) {
      Row({ space: 12 }) {
        Text('🔈').fontSize(18)
        Slider({ value: this.vol, min: 0, max: 15, step: 1, style: SliderStyle.OutSet })
          .layoutWeight(1)
          .selectedColor(this.theme)
          .trackColor($r('app.color.cm_divider'))
          .onChange((v: number, m: SliderChangeMode) => {
            this.vol = Math.round(v);
            if (m === SliderChangeMode.End || m === SliderChangeMode.Click) {
              this.player.setMediaVolume(this.vol);
            }
          })
        Text('🔊').fontSize(18)
        Text(`${this.vol}`)
          .fontSize(14)
          .fontColor($r('app.color.cm_text2'))
          .width(26)
          .textAlign(TextAlign.Center)
      }
      .width('100%')

      Row({ space: 10 }) {
        Button(this.muted ? '取消静音' : '静音')
          .height(36)
          .fontSize(13)
          .backgroundColor($r('app.color.cm_card'))
          .fontColor($r('app.color.cm_text'))
          .border({ width: 2, color: $r('app.color.cm_text') })
          .onClick(() => {
            if (this.muted) {
              this.player.setMediaVolume(this.prevVol);
              this.vol = this.prevVol;
              this.muted = false;
              this.model.toast('已恢复音量');
            } else {
              this.prevVol = this.vol > 0 ? this.vol : 8;
              this.player.setMediaVolume(0);
              this.vol = 0;
              this.muted = true;
              this.model.toast('已静音');
            }
          })
        Blank()
      }
      .width('100%')

      Text('调节系统媒体音量（也可在播放页右侧边缘上下滑动调节）')
        .fontSize(11)
        .fontColor($r('app.color.cm_text2'))
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .width('100%')
    .padding(20)
  }
}
