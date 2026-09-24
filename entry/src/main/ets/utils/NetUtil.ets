/**
 * 网络状态工具
 * 提供无权限依赖的联网检测（connection.hasDefaultNet 无需额外权限）
 */
import { connection } from '@kit.NetworkKit';

export class NetUtil {
  /** 设备是否有可用网络 */
  static async hasNet(): Promise<boolean> {
    try {
      return await connection.hasDefaultNet();
    } catch (err) {
      return false;
    }
  }
}
