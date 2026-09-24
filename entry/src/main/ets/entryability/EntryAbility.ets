/**
 * 应用入口 Ability（Stage模型）
 * onCreate：启动全局初始化（偏好/数据库/播放器/下载/媒体库）
 * onWindowStageCreate：加载启动页
 */
import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppModel } from '../viewmodel/AppModel';
import { PlayerService } from '../service/PlayerService';

const DOMAIN: number = 0x0001;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 跟随系统深浅色（用户可在设置页手动切换）
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'CloudMusic', 'setColorMode失败: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'CloudMusic', '应用创建');
    // 异步初始化，不阻塞窗口加载；启动页会等待其完成
    AppModel.getInstance().initApp(this.context);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'CloudMusic', '应用销毁');
    PlayerService.getInstance().release();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'CloudMusic', '窗口创建，加载启动页');
    windowStage.loadContent('pages/SplashPage', (err: BusinessError) => {
      if (err.code) {
        hilog.error(DOMAIN, 'CloudMusic', '加载启动页失败: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'CloudMusic', '启动页加载完成');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'CloudMusic', '窗口销毁');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'CloudMusic', '回到前台');
  }

  onBackground(): void {
    // 退到后台时播放由长时任务(AUDIO_PLAYBACK)保持
    hilog.info(DOMAIN, 'CloudMusic', '退到后台');
  }
}
