/**
 * 首页：底部导航栏四Tab（我的音乐 / 在线音乐 / 播放列表 / 我的）
 */
import { C } from '../../common/Constants';
import { LocalTab } from './LocalTab';
import { OnlineTab } from './OnlineTab';
import { PlaylistTab } from './PlaylistTab';
import { MineTab } from './MineTab';

@Component
export struct HomePage {
  // 注意：不能命名为tabIndex，与ArkUI内置属性冲突
  @State curTab: number = 0;
  @StorageProp(C.K_THEME) theme: string = C.DEFAULT_THEME;

  @Builder
  tabItem(idx: number, icon: string, label: string) {
    Column({ space: 2 }) {
      Text(icon)
        .fontSize(21)
        .fontColor(this.curTab === idx ? $r('app.color.cm_text') : $r('app.color.cm_icon'))
      Text(label)
        .fontSize(10)
        .fontColor(this.curTab === idx ? $r('app.color.cm_text') : $r('app.color.cm_text2'))
        .padding({ left: 10, right: 10, top: 2, bottom: 2 })
        .borderRadius(8)
        .backgroundColor(this.curTab === idx ? $r('app.color.cm_marker') : Color.Transparent)
        .animation({ duration: 250, curve: Curve.EaseOut })
    }
    .width('25%')
    .justifyContent(FlexAlign.Center)
    .height('100%')
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.curTab }) {
      TabContent() {
        LocalTab()
      }
      .tabBar(this.tabItem(0, '🎵', '我的音乐'))

      TabContent() {
        OnlineTab()
      }
      .tabBar(this.tabItem(1, '☁️', '在线音乐'))

      TabContent() {
        PlaylistTab()
      }
      .tabBar(this.tabItem(2, '📋', '播放列表'))

      TabContent() {
        MineTab()
      }
      .tabBar(this.tabItem(3, '👤', '我的'))
    }
    .onChange((i: number) => {
      this.curTab = i;
    })
    .scrollable(false)
    .barHeight(54)
    .backgroundColor($r('app.color.cm_card'))
    .width('100%')
    .height('100%')
  }
}
