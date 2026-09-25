/**
 * 网络状态工具（借鉴 accountDL 的实时监听方案）
 * 1. startMonitor：注册 NetConnection 实时监听，结果写入 AppStorage（isOnline），
 *    UI 通过 @StorageProp 响应式展示离线横幅
 * 2. hasNet：一次性权威检测（操作前的兜底校验）
 * 注意：ArkTS 静态方法内不允许使用 this，统一以类名引用静态成员
 */
import { connection } from '@kit.NetworkKit';

export class NetUtil {
  private static conn?: connection.NetConnection;
  private static registered: boolean = false;

  /** 启动实时网络监听（EntryAbility 启动时调用一次） */
  static startMonitor(): void {
    if (NetUtil.registered) {
      return;
    }
    NetUtil.registered = true;
    // 乐观初始化：默认在线，避免启动瞬间误报离线
    AppStorage.setOrCreate('kIsOnline', true);
    connection.hasDefaultNet().then((has: boolean) => {
      AppStorage.setOrCreate('kIsOnline', has);
    }).catch(() => {
      AppStorage.setOrCreate('kIsOnline', false);
    });

    NetUtil.conn = connection.createNetConnection();
    NetUtil.conn.on('netAvailable', () => {
      AppStorage.setOrCreate('kIsOnline', true);
    });
    NetUtil.conn.on('netLost', () => {
      AppStorage.setOrCreate('kIsOnline', false);
    });
    NetUtil.conn.on('netUnavailable', () => {
      AppStorage.setOrCreate('kIsOnline', false);
    });
    NetUtil.conn.register(() => {
      // 注册结果无需处理
    });
  }

  /** 设备当前是否有可用网络（一次性权威检测） */
  static async hasNet(): Promise<boolean> {
    try {
      return await connection.hasDefaultNet();
    } catch (err) {
      return false;
    }
  }
}
