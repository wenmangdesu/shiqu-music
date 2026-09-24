/**
 * 设置页
 * 外观（深浅模式/主题色跟随封面/固定主题色）、播放（默认模式/音质偏好）、
 * 下载（并发数/目录）、数据（缓存清理/历史清理/重新扫描）、关于
 */
import fs from '@ohos.file.fs';
import { C } from '../common/Constants';
import { FmtUtil } from '../utils/FmtUtil';
import { AppModel } from '../viewmodel/AppModel';
import { PlayerService } from '../service/PlayerService';
import { DownloadService } from '../service/DownloadService';
import { PrefsService } from '../service/PrefsService';

@Component
export struct SettingsPage {
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;
  @State colorMode: string = 'auto';
  @State themeAuto: boolean = true;
  @State fixedTheme: string = C.DEFAULT_THEME;
  @State defMode: number = C.PLAY_MODE_LIST;
  @State defQuality: string = C.QUALITY_STANDARD;
  @State concurrency: number = C.MAX_CONCURRENT;
  @State cacheSize: string = '计算中...';
  private model: AppModel = AppModel.getInstance();
  private player: PlayerService = PlayerService.getInstance();
  private ds: DownloadService = DownloadService.getInstance();

  aboutToAppear(): void {
    const p: PrefsService = PrefsService.getInstance();
    this.colorMode = this.model.getColorMode();
    this.themeAuto = p.getBool(C.P_THEME_AUTO, true);
    this.fixedTheme = p.getStr(C.P_THEME_FIXED, C.DEFAULT_THEME);
    this.defMode = AppStorage.get<number>(C.K_MODE) ?? C.PLAY_MODE_LIST;
    this.defQuality = p.getStr(C.P_QUALITY, C.QUALITY_STANDARD);
    this.concurrency = this.ds.getConcurrency();
    setTimeout(() => {
      this.cacheSize = FmtUtil.fmtSize(this.calcCacheSize());
    }, 80);
  }

  // ==================== 缓存 ====================
  private dirSize(path: string): number {
    let total: number = 0;
    try {
      if (!fs.accessSync(path)) {
        return 0;
      }
      const names: string[] = fs.listFileSync(path);
      names.forEach((n: string) => {
        const full: string = `${path}/${n}`;
        try {
          const st: fs.Stat = fs.statSync(full);
          if (st.isDirectory()) {
            total += this.dirSize(full);
          } else {
            total += st.size;
          }
        } catch (err) {
          // 单个文件统计失败可忽略
        }
      });
    } catch (err) {
      // 目录不存在
    }
    return total;
  }

  private calcCacheSize(): number {
    if (!this.model.context) {
      return 0;
    }
    const cache: string = this.model.context.cacheDir;
    return this.dirSize(`${cache}/${C.COVER_DIR}`) + this.dirSize(`${cache}/${C.LYRIC_DIR}`);
  }

  private clearCache(): void {
    if (!this.model.context) {
      return;
    }
    const cache: string = this.model.context.cacheDir;
    const dirs: string[] = [`${cache}/${C.COVER_DIR}`, `${cache}/${C.LYRIC_DIR}`];
    let n: number = 0;
    dirs.forEach((d: string) => {
      try {
        if (fs.accessSync(d)) {
          fs.listFileSync(d).forEach((f: string) => {
            try {
              fs.unlinkSync(`${d}/${f}`);
              n++;
            } catch (err) {
              // 单个文件删除失败可忽略
            }
          });
        }
      } catch (err) {
        // 目录不存在
      }
    });
    this.cacheSize = FmtUtil.fmtSize(this.calcCacheSize());
    this.model.toast(`缓存已清理（${n}个文件）`);
  }

  // ==================== UI ====================
  @Builder
  sectionTitle(txt: string) {
    Text(txt)
      .fontSize(13)
      .fontColor($r('app.color.cm_text2'))
      .width('100%')
      .padding({ left: 6, top: 12, bottom: 6 })
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 8 }) {
          // ===== 外观 =====
          this.sectionTitle('外观')
          Column({ space: 14 }) {
            Row({ space: 10 }) {
              Text('深浅模式').fontSize(15).fontColor($r('app.color.cm_text')).layoutWeight(1)
              Row({ space: 6 }) {
                ChipItem({
                  label: '跟随系统',
                  active: this.colorMode === 'auto',
                  onTap: (): void => {
                    this.colorMode = 'auto';
                    this.model.applyColorMode('auto');
                  }
                })
                ChipItem({
                  label: '浅色',
                  active: this.colorMode === 'light',
                  onTap: (): void => {
                    this.colorMode = 'light';
                    this.model.applyColorMode('light');
                  }
                })
                ChipItem({
                  label: '深色',
                  active: this.colorMode === 'dark',
                  onTap: (): void => {
                    this.colorMode = 'dark';
                    this.model.applyColorMode('dark');
                  }
                })
              }
            }
            .width('100%')

            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text('主题色跟随封面').fontSize(15).fontColor($r('app.color.cm_text'))
                Text('播放时自动提取专辑封面主色').fontSize(11).fontColor($r('app.color.cm_text2'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Toggle({ type: ToggleType.Switch, isOn: this.themeAuto })
                .selectedColor(this.theme)
                .onChange((on: boolean) => {
                  this.themeAuto = on;
                  this.model.setThemeAuto(on);
                })
            }
            .width('100%')

            if (!this.themeAuto) {
              Row({ space: 12 }) {
                Text('固定主题色').fontSize(15).fontColor($r('app.color.cm_text')).layoutWeight(1)
                ForEach(C.THEME_PALETTE, (color: string) => {
                  Column()
                    .width(26)
                    .height(26)
                    .borderRadius(13)
                    .backgroundColor(color)
                    .border({
                      width: 2,
                      color: this.fixedTheme === color ? $r('app.color.cm_text') : Color.Transparent
                    })
                    .onClick(() => {
                      this.fixedTheme = color;
                      this.model.setFixedTheme(color);
                    })
                }, (color: string) => color)
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding(14)
          .borderRadius(14)
          .backgroundColor($r('app.color.cm_card'))

          // ===== 播放 =====
          this.sectionTitle('播放')
          Column({ space: 14 }) {
            Row({ space: 10 }) {
              Text('默认播放模式').fontSize(15).fontColor($r('app.color.cm_text')).layoutWeight(1)
              Row({ space: 6 }) {
                ChipItem({
                  label: '单曲循环',
                  active: this.defMode === C.PLAY_MODE_SINGLE,
                  onTap: (): void => {
                    this.defMode = C.PLAY_MODE_SINGLE;
                    this.player.setMode(C.PLAY_MODE_SINGLE);
                  }
                })
                ChipItem({
                  label: '列表循环',
                  active: this.defMode === C.PLAY_MODE_LIST,
                  onTap: (): void => {
                    this.defMode = C.PLAY_MODE_LIST;
                    this.player.setMode(C.PLAY_MODE_LIST);
                  }
                })
                ChipItem({
                  label: '随机',
                  active: this.defMode === C.PLAY_MODE_RANDOM,
                  onTap: (): void => {
                    this.defMode = C.PLAY_MODE_RANDOM;
                    this.player.setMode(C.PLAY_MODE_RANDOM);
                  }
                })
              }
            }
            .width('100%')

            Row({ space: 10 }) {
              Text('下载音质偏好').fontSize(15).fontColor($r('app.color.cm_text')).layoutWeight(1)
              Row({ space: 6 }) {
                ChipItem({
                  label: '标准',
                  active: this.defQuality === C.QUALITY_STANDARD,
                  onTap: (): void => {
                    this.defQuality = C.QUALITY_STANDARD;
                    PrefsService.getInstance().putStr(C.P_QUALITY, C.QUALITY_STANDARD);
                  }
                })
                ChipItem({
                  label: '高清',
                  active: this.defQuality === C.QUALITY_HIGH,
                  onTap: (): void => {
                    this.defQuality = C.QUALITY_HIGH;
                    PrefsService.getInstance().putStr(C.P_QUALITY, C.QUALITY_HIGH);
                  }
                })
                ChipItem({
                  label: '无损',
                  active: this.defQuality === C.QUALITY_LOSSLESS,
                  onTap: (): void => {
                    this.defQuality = C.QUALITY_LOSSLESS;
                    PrefsService.getInstance().putStr(C.P_QUALITY, C.QUALITY_LOSSLESS);
                  }
                })
              }
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .borderRadius(14)
          .backgroundColor($r('app.color.cm_card'))

          // ===== 下载 =====
          this.sectionTitle('下载')
          Column({ space: 14 }) {
            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text('并发下载数').fontSize(15).fontColor($r('app.color.cm_text'))
                Text('同时下载的任务数量（1-3）').fontSize(11).fontColor($r('app.color.cm_text2'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Slider({ value: this.concurrency, min: 1, max: 3, step: 1, style: SliderStyle.OutSet })
                .width(130)
                .selectedColor(this.theme)
                .trackColor($r('app.color.cm_divider'))
                .onChange((v: number, m: SliderChangeMode) => {
                  if (m === SliderChangeMode.End || m === SliderChangeMode.Click) {
                    this.concurrency = Math.round(v);
                    this.ds.setConcurrency(this.concurrency);
                    this.model.toast(`已设置同时下载 ${this.concurrency} 个任务`);
                  }
                })
              Text(`${this.concurrency}`)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme)
                .width(22)
                .textAlign(TextAlign.Center)
            }
            .width('100%')

            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text('下载目录').fontSize(15).fontColor($r('app.color.cm_text'))
                Text(this.model.context ? `${this.model.context.filesDir}/${C.DL_DIR}` : '应用沙箱目录')
                  .fontSize(11)
                  .fontColor($r('app.color.cm_text2'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .borderRadius(14)
          .backgroundColor($r('app.color.cm_card'))

          // ===== 数据 =====
          this.sectionTitle('数据')
          Column() {
            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text('清理缓存').fontSize(15).fontColor($r('app.color.cm_text'))
                Text(`封面与歌词缓存：${this.cacheSize}`).fontSize(11).fontColor($r('app.color.cm_text2'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              Text('清理')
                .fontSize(13)
                .fontColor(this.theme)
                .onClick(() => {
                  this.clearCache();
                })
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
          }
          .width('100%')
          .padding({ left: 14, right: 14 })
          .borderRadius(14)
          .backgroundColor($r('app.color.cm_card'))

          Column() {
            Row({ space: 10 }) {
              Text('清除播放历史').fontSize(15).fontColor($r('app.color.cm_text')).layoutWeight(1)
              Text('清除')
                .fontSize(13)
                .fontColor(this.theme)
                .onClick(async (): Promise<void> => {
                  const ok: boolean = await this.model.confirm('清除历史', '确定清空全部播放历史吗？');
                  if (ok) {
                    this.model.clearHistory();
                  }
                })
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })

            Row({ space: 10 }) {
              Column({ space: 2 }) {
                Text('重新扫描本地音乐').fontSize(15).fontColor($r('app.color.cm_text'))
                Text('扫描应用目录（下载/导入目录）').fontSize(11).fontColor($r('app.color.cm_text2'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              Text('扫描')
                .fontSize(13)
                .fontColor(this.theme)
                .onClick(() => {
                  this.model.rescanLibrary();
                })
            }
            .width('100%')
            .padding({ top: 12, bottom: 12 })
          }
          .width('100%')
          .padding({ left: 14, right: 14 })
          .borderRadius(14)
          .backgroundColor($r('app.color.cm_card'))

          // ===== 关于 =====
          this.sectionTitle('关于')
          Column({ space: 8 }) {
            Text(`${C.APP_NAME}`)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.cm_text'))
            Text(`版本 ${this.model.versionName} · 最低兼容 API 23`)
              .fontSize(11)
              .fontColor($r('app.color.cm_text2'))
            Text('不识字，但识曲')
              .fontSize(13)
              .fontColor(this.theme)
            Text('一款使用 ArkTS + ArkUI 开发的鸿蒙原生音乐播放器，\n支持本地导入、在线搜索下载、歌词、歌单与后台播放。')
              .fontSize(12)
              .fontColor($r('app.color.cm_text2'))
              .textAlign(TextAlign.Center)
            Text('在线演示数据仅用于功能验证，请支持正版音乐')
              .fontSize(10)
              .fontColor($r('app.color.cm_text2'))
          }
          .width('100%')
          .padding(16)
          .borderRadius(14)
          .backgroundColor($r('app.color.cm_card'))
          .alignItems(HorizontalAlign.Center)
        }
        .padding({ left: 16, right: 16, bottom: 24 })
        .constraintSize({ maxWidth: 680 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .width('100%')
      .height('100%')
    }
    .title('设置')
  }
}

/**
 * 选择芯片组件
 * 说明：不能用@Builder按值传参实现（状态变化不会刷新Builder内UI），
 * 必须用子组件的@Prop属性才能让选中态随父状态刷新
 */
@Component
struct ChipItem {
  @Prop label: string = '';
  @Prop active: boolean = false;
  onTap: () => void = () => {
  };
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;

  build() {
    Text(this.label)
      .fontSize(13)
      .fontColor(this.active ? '#FFFFFF' : $r('app.color.cm_text'))
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .borderRadius(15)
      .backgroundColor(this.active ? this.theme : $r('app.color.cm_bg'))
      .onClick(() => {
        this.onTap();
      })
  }
}
