/**
 * 用户服务（第一阶段为本地Mock实现）
 * 用户信息持久化在 preferences；后续接入真实账号系统时，
 * 只需替换本类内部实现（login/register 走服务器接口），UI层无需改动。
 */
import { C } from '../common/Constants';
import { PrefsService } from './PrefsService';
import { Logger } from '../utils/Logger';

/** 用户资料 */
export class UserInfo {
  username: string = '';
  nickname: string = '';
  /** 本地头像文件路径（空=默认头像） */
  avatar: string = '';
  gender: string = '男';
  birthday: string = '';
  region: string = '';
  bio: string = '';
}

export class UserService {
  private static inst?: UserService;

  static getInstance(): UserService {
    if (!UserService.inst) {
      UserService.inst = new UserService();
    }
    return UserService.inst;
  }

  user?: UserInfo;

  /** 启动时从偏好恢复登录态 */
  load(): void {
    const json: string = PrefsService.getInstance().getStr(C.P_USER, '');
    if (!json) {
      return;
    }
    try {
      this.user = JSON.parse(json) as UserInfo;
    } catch (err) {
      Logger.w('User', '用户信息解析失败');
      this.user = undefined;
    }
  }

  isLoggedIn(): boolean {
    return this.user !== undefined;
  }

  /**
   * Mock登录/注册：本地校验后直接建立会话
   * 接真实后端时：替换为接口调用，成功后写入 user
   */
  login(username: string, password: string): Promise<UserInfo> {
    return new Promise<UserInfo>((resolve: (u: UserInfo) => void, reject: (e: Error) => void) => {
      const name: string = username.trim();
      if (!name) {
        reject(new Error('请输入用户名'));
        return;
      }
      if (password.trim().length < 4) {
        reject(new Error('密码至少4位'));
        return;
      }
      const u: UserInfo = new UserInfo();
      u.username = name;
      u.nickname = name;
      this.user = u;
      this.save();
      resolve(u);
    });
  }

  /** 保存资料 */
  save(): void {
    if (this.user) {
      PrefsService.getInstance().putStr(C.P_USER, JSON.stringify(this.user));
    }
  }

  /** 更新资料字段 */
  updateProfile(nickname: string, gender: string, birthday: string, region: string, bio: string): void {
    if (!this.user) {
      return;
    }
    this.user.nickname = nickname.trim() || this.user.nickname;
    this.user.gender = gender;
    this.user.birthday = birthday.trim();
    this.user.region = region.trim();
    this.user.bio = bio.trim();
    this.save();
  }

  /** 设置本地头像路径 */
  setAvatar(path: string): void {
    if (this.user) {
      this.user.avatar = path;
      this.save();
    }
  }

  /** 退出登录（Mock：清除本地会话） */
  logout(): void {
    this.user = undefined;
    PrefsService.getInstance().putStr(C.P_USER, '');
  }
}
