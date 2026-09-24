/**
 * 下载管理页
 * 正在下载（进度/速度/暂停/继续/取消）、失败（重试/删除）、已完成（播放/删除记录/删除文件）
 */
import { DownloadTask } from '../model/DownloadTask';
import { Song } from '../model/Song';
import { C } from '../common/Constants';
import { FmtUtil } from '../utils/FmtUtil';
import { AppModel } from '../viewmodel/AppModel';
import { PlayerService } from '../service/PlayerService';
import { DownloadService } from '../service/DownloadService';

@Component
export struct DownloadPage {
  @StorageProp(C.K_DLV) @Watch('reload') dlVersion: number = 0;
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;
  @State tasks: DownloadTask[] = [];
  private model: AppModel = AppModel.getInstance();
  private player: PlayerService = PlayerService.getInstance();
  private ds: DownloadService = DownloadService.getInstance();

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    this.tasks = this.ds.tasks.slice();
  }

  private activeTasks(): DownloadTask[] {
    return this.tasks.filter((t: DownloadTask) =>
      t.status === C.ST_PENDING || t.status === C.ST_RUNNING || t.status === C.ST_PAUSED);
  }

  private failedTasks(): DownloadTask[] {
    return this.tasks.filter((t: DownloadTask) => t.status === C.ST_FAILED);
  }

  private doneTasks(): DownloadTask[] {
    return this.tasks.filter((t: DownloadTask) => t.status === C.ST_COMPLETED);
  }

  private qualityTag(q: string): string {
    if (q === C.QUALITY_LOSSLESS) {
      return '无损';
    }
    if (q === C.QUALITY_HIGH) {
      return '320K';
    }
    return '128K';
  }

  /** 播放已下载歌曲 */
  private playTask(t: DownloadTask): void {
    const found: Song | undefined = this.model.localSongs.find((s: Song) => s.filePath === t.filePath);
    if (found) {
      this.player.setQueue([found], 0);
    } else {
      this.model.toast('文件不存在或已被移动');
    }
  }

  private async doneMenu(t: DownloadTask): Promise<void> {
    const idx: number = await this.model.actionMenu(t.title, ['删除记录', '删除记录并删除文件']);
    if (idx === 0) {
      this.ds.deleteCompleted(t, false);
    } else if (idx === 1) {
      const ok: boolean = await this.model.confirm('删除文件', `确定删除「${t.title}」的音频文件吗？`);
      if (ok) {
        this.ds.deleteCompleted(t, true);
      }
    }
  }

  @Builder
  sectionTitle(txt: string) {
    Text(txt)
      .fontSize(15)
      .fontWeight(FontWeight.Bold)
      .fontColor($r('app.color.cm_text'))
      .width('100%')
      .padding({ top: 10, bottom: 4 })
  }

  /** 进行中/暂停/等待 任务行 */
  @Builder
  activeRow(t: DownloadTask) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text(this.qualityTag(t.quality))
          .fontSize(10)
          .fontColor(this.theme)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(6)
          .backgroundColor(`${this.theme}1A`)
        Text(t.title)
          .fontSize(14)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor($r('app.color.cm_text'))
          .layoutWeight(1)
        Text(C.statusLabel(t.status))
          .fontSize(12)
          .fontColor(t.status === C.ST_RUNNING ? this.theme : $r('app.color.cm_text2'))
      }
      .width('100%')

      Row({ space: 8 }) {
        Progress({ value: Math.max(t.progress, t.status === C.ST_RUNNING ? 2 : 0), total: 100, type: ProgressType.Linear })
          .style({ strokeWidth: 5 })
          .layoutWeight(1)
          .color(this.theme)
        Text(t.total > 0
          ? `${t.progress}% · ${FmtUtil.fmtSize(t.received)}/${FmtUtil.fmtSize(t.total)}`
          : `${t.progress}% · ${FmtUtil.fmtSpeed(t.speed)}`)
          .fontSize(10)
          .fontColor($r('app.color.cm_text2'))
      }
      .width('100%')

      Row({ space: 14 }) {
        Blank()
        if (t.status === C.ST_RUNNING) {
          this.ctrlBtn('⏸ 暂停', (): void => {
            this.ds.pauseTask(t);
          })
        } else if (t.status === C.ST_PAUSED) {
          this.ctrlBtn('▶ 继续', (): void => {
            this.ds.resumeTask(t);
          })
        } else {
          Text('等待中...')
            .fontSize(12)
            .fontColor($r('app.color.cm_text2'))
        }
        this.ctrlBtn('✕ 取消', (): void => {
          this.ds.cancelTask(t);
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.cm_card'))
    .margin({ bottom: 8 })
  }

  /** 失败任务行 */
  @Builder
  failedRow(t: DownloadTask) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text(this.qualityTag(t.quality))
          .fontSize(10)
          .fontColor(this.theme)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(6)
          .backgroundColor(`${this.theme}1A`)
        Text(t.title)
          .fontSize(14)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor($r('app.color.cm_text'))
          .layoutWeight(1)
        Text('失败')
          .fontSize(12)
          .fontColor('#E5484D')
      }
      .width('100%')
      Text(t.errMsg)
        .fontSize(10)
        .fontColor($r('app.color.cm_text2'))
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: 14 }) {
        Blank()
        this.ctrlBtn('↻ 重试', (): void => {
          this.ds.retryTask(t);
        })
        this.ctrlBtn('✕ 删除', (): void => {
          this.ds.cancelTask(t);
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.cm_card'))
    .margin({ bottom: 8 })
  }

  /** 已完成任务行 */
  @Builder
  doneRow(t: DownloadTask) {
    Row({ space: 8 }) {
      Text(this.qualityTag(t.quality))
        .fontSize(10)
        .fontColor(this.theme)
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .borderRadius(6)
        .backgroundColor(`${this.theme}1A`)
      Column({ space: 2 }) {
        Text(t.title)
          .fontSize(14)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor($r('app.color.cm_text'))
        Text(`${t.artist} · ${FmtUtil.fmtSize(t.total > 0 ? t.total : t.received)}`)
          .fontSize(11)
          .fontColor($r('app.color.cm_text2'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('▶')
        .fontSize(18)
        .fontColor(this.theme)
        .padding(6)
        .onClick(() => {
          this.playTask(t);
        })
      Text('⋯')
        .fontSize(18)
        .fontColor($r('app.color.cm_text2'))
        .padding(6)
        .onClick(() => {
          this.doneMenu(t);
        })
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.cm_card'))
    .margin({ bottom: 8 })
  }

  @Builder
  ctrlBtn(label: string, onTap: () => void) {
    Text(label)
      .fontSize(12)
      .fontColor($r('app.color.cm_text'))
      .padding({ left: 12, right: 12, top: 5, bottom: 5 })
      .borderRadius(12)
      .backgroundColor($r('app.color.cm_bg'))
      .onClick(() => {
        onTap();
      })
  }

  build() {
    NavDestination() {
      Column() {
        Row({ space: 10 }) {
          Text(`共 ${this.tasks.length} 个任务`)
            .fontSize(12)
            .fontColor($r('app.color.cm_text2'))
            .layoutWeight(1)
          Text('清除已完成')
            .fontSize(13)
            .fontColor(this.theme)
            .onClick(() => {
              this.ds.clearCompleted();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 6, bottom: 6 })

        if (this.tasks.length === 0) {
          Column({ space: 10 }) {
            Text('📥').fontSize(42)
            Text('暂无下载任务')
              .fontSize(14)
              .fontColor($r('app.color.cm_text'))
            Text('到"在线音乐"搜索歌曲并选择音质下载')
              .fontSize(12)
              .fontColor($r('app.color.cm_text2'))
          }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column() {
              if (this.activeTasks().length > 0) {
                this.sectionTitle(`正在下载 (${this.activeTasks().length})`)
                ForEach(this.activeTasks(), (t: DownloadTask) => {
                  this.activeRow(t)
                }, (t: DownloadTask) => `a_${t.id}_${t.status}_${t.progress}`)
              }
              if (this.failedTasks().length > 0) {
                this.sectionTitle(`下载失败 (${this.failedTasks().length})`)
                ForEach(this.failedTasks(), (t: DownloadTask) => {
                  this.failedRow(t)
                }, (t: DownloadTask) => `f_${t.id}_${t.status}`)
              }
              if (this.doneTasks().length > 0) {
                this.sectionTitle(`已完成 (${this.doneTasks().length})`)
                ForEach(this.doneTasks(), (t: DownloadTask) => {
                  this.doneRow(t)
                }, (t: DownloadTask) => `d_${t.id}`)
              }
            }
            .padding({ left: 16, right: 16, bottom: 20 })
            .constraintSize({ maxWidth: 720 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .align(Alignment.Top)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.cm_bg'))
    }
    .title('下载管理')
  }
}
