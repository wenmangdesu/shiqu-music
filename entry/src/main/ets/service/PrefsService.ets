/**
 * 用户偏好持久化服务（@ohos.data.preferences）
 * 同步API + 异步flush，简单键值存储
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Logger } from '../utils/Logger';

export class PrefsService {
  private static inst?: PrefsService;

  static getInstance(): PrefsService {
    if (!PrefsService.inst) {
      PrefsService.inst = new PrefsService();
    }
    return PrefsService.inst;
  }

  private store?: preferences.Preferences;

  init(ctx: common.UIAbilityContext): void {
    try {
      this.store = preferences.getPreferencesSync(ctx, { name: 'shiqu_prefs' });
    } catch (err) {
      Logger.e('Prefs', '初始化失败');
    }
  }

  private has(): boolean {
    return this.store !== undefined;
  }

  getStr(key: string, def: string): string {
    if (!this.has()) {
      return def;
    }
    try {
      const v = this.store!.getSync(key, def) as string;
      return v === undefined || v === null ? def : v;
    } catch (err) {
      return def;
    }
  }

  getNum(key: string, def: number): number {
    if (!this.has()) {
      return def;
    }
    try {
      const v = this.store!.getSync(key, def) as number;
      return v === undefined || v === null ? def : v;
    } catch (err) {
      return def;
    }
  }

  getBool(key: string, def: boolean): boolean {
    if (!this.has()) {
      return def;
    }
    try {
      const v = this.store!.getSync(key, def) as boolean;
      return v === undefined || v === null ? def : v;
    } catch (err) {
      return def;
    }
  }

  putStr(key: string, v: string): void {
    if (!this.has()) {
      return;
    }
    try {
      this.store!.putSync(key, v);
      this.store!.flush().catch(() => {});
    } catch (err) {
      Logger.w('Prefs', `写入失败 ${key}`);
    }
  }

  putNum(key: string, v: number): void {
    if (!this.has()) {
      return;
    }
    try {
      this.store!.putSync(key, v);
      this.store!.flush().catch(() => {});
    } catch (err) {
      Logger.w('Prefs', `写入失败 ${key}`);
    }
  }

  putBool(key: string, v: boolean): void {
    if (!this.has()) {
      return;
    }
    try {
      this.store!.putSync(key, v);
      this.store!.flush().catch(() => {});
    } catch (err) {
      Logger.w('Prefs', `写入失败 ${key}`);
    }
  }

  /** 字符串数组（以JSON存储，用于搜索历史等） */
  getStrArr(key: string): string[] {
    const json: string = this.getStr(key, '[]');
    try {
      const arr = JSON.parse(json) as Array<Object>;
      const out: string[] = [];
      arr.forEach((v: Object) => {
        out.push(`${v}`);
      });
      return out;
    } catch (err) {
      return [];
    }
  }

  putStrArr(key: string, arr: string[]): void {
    this.putStr(key, JSON.stringify(arr));
  }
}
