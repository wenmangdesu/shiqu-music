/**
 * 应用主框架页
 * Navigation(主页四Tab + 迷你播放条) + 全部子页面路由 + 桌面歌词悬浮层
 */
import { C } from '../common/Constants';
import { AppModel } from '../viewmodel/AppModel';
import { HomePage } from './home/HomePage';
import { MiniPlayerBar } from '../view/MiniPlayerBar';
import { FloatLyrics } from '../view/FloatLyrics';
import { SearchPage } from './SearchPage';
import { PlayerPage } from './PlayerPage';
import { LyricsPage } from './LyricsPage';
import { PlaylistDetailPage } from './PlaylistDetailPage';
import { AddToPlaylistPage } from './AddToPlaylistPage';
import { CreatePlaylistPage } from './CreatePlaylistPage';
import { PickSongsPage } from './PickSongsPage';
import { DownloadPage } from './DownloadPage';
import { SettingsPage } from './SettingsPage';
import { LoginPage } from './LoginPage';
import { ProfilePage } from './ProfilePage';
import { MusicGroupPage } from './MusicGroupPage';

@Entry
@Component
struct Index {
  private model: AppModel = AppModel.getInstance();
  @StorageProp(C.K_FLOAT) floatOn: boolean = false;

  /** 子页面路由表 */
  @Builder
  PageMap(name: string) {
    if (name === 'Search') {
      SearchPage()
    } else if (name === 'Player') {
      PlayerPage()
    } else if (name === 'Lyrics') {
      LyricsPage()
    } else if (name === 'PlaylistDetail') {
      PlaylistDetailPage()
    } else if (name === 'AddToPlaylist') {
      AddToPlaylistPage()
    } else if (name === 'CreatePlaylist') {
      CreatePlaylistPage()
    } else if (name === 'PickSongs') {
      PickSongsPage()
    } else if (name === 'Download') {
      DownloadPage()
    } else if (name === 'Settings') {
      SettingsPage()
    } else if (name === 'Login') {
      LoginPage()
    } else if (name === 'Profile') {
      ProfilePage()
    } else if (name === 'MusicGroup') {
      MusicGroupPage()
    }
  }

  build() {
    Stack() {
      Navigation(this.model.navStack) {
        Column() {
          HomePage()
            .layoutWeight(1)
          MiniPlayerBar()
        }
        .width('100%')
        .height('100%')
      }
      .navDestination(this.PageMap)
      .mode(NavigationMode.Stack)
      .hideTitleBar(true)
      .hideToolBar(true)
      .backgroundColor($r('app.color.cm_bg'))

      // 桌面歌词悬浮层（应用内悬浮，可拖拽）
      if (this.floatOn) {
        FloatLyrics()
      }
    }
    .width('100%')
    .height('100%')
  }
}
