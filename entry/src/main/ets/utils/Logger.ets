/**
 * 日志工具：基于hilog的统一封装
 */
import { hilog } from '@kit.PerformanceAnalysisKit';

export class Logger {
  private static readonly DOMAIN: number = 0x0001;
  private static readonly TAG: string = 'ShiQu';

  static d(tag: string, msg: string): void {
    hilog.debug(Logger.DOMAIN, Logger.TAG, '%{public}s %{public}s', tag, msg);
  }

  static i(tag: string, msg: string): void {
    hilog.info(Logger.DOMAIN, Logger.TAG, '%{public}s %{public}s', tag, msg);
  }

  static w(tag: string, msg: string): void {
    hilog.warn(Logger.DOMAIN, Logger.TAG, '%{public}s %{public}s', tag, msg);
  }

  static e(tag: string, msg: string): void {
    hilog.error(Logger.DOMAIN, Logger.TAG, '%{public}s %{public}s', tag, msg);
  }
}
