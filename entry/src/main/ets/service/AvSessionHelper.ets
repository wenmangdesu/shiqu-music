/**
 * AVSession媒体会话服务
 * 用于：锁屏/控制中心显示播放信息与控制按钮（播放在后台时的系统级控制）
 */
import { avSession } from '@kit.AVSessionKit';
import { common } from '@kit.AbilityKit';
import { Song } from '../model/Song';
import { IPlayerHooks } from '../common/Constants';
import { Logger } from '../utils/Logger';

export class AvSessionHelper {
  private static inst?: AvSessionHelper;

  static getInstance(): AvSessionHelper {
    if (!AvSessionHelper.inst) {
      AvSessionHelper.inst = new AvSessionHelper();
    }
    return AvSessionHelper.inst;
  }

  private session?: avSession.AVSession;
  private inited: boolean = false;

  async init(ctx: common.UIAbilityContext, hooks: IPlayerHooks): Promise<void> {
    if (this.inited) {
      return;
    }
    this.inited = true;
    try {
      this.session = await avSession.createAVSession(ctx, 'cloudMusicSession', 'audio');
      const s: avSession.AVSession = this.session;
      // 注册系统媒体控制命令
      s.on('play', () => {
        hooks.play();
      });
      s.on('pause', () => {
        hooks.pause();
      });
      s.on('playNext', () => {
        hooks.next();
      });
      s.on('playPrevious', () => {
        hooks.prev();
      });
      s.on('stop', () => {
        hooks.stop();
      });
      s.on('seek', (time: number) => {
        hooks.seek(Number(time));
      });
      await s.activate();
      Logger.i('AVSession', '媒体会话创建成功');
    } catch (err) {
      const e = err as BusinessError;
      Logger.e('AVSession', `创建失败: ${e.code} ${e.message}`);
      this.inited = false;
    }
  }

  /** 更新锁屏/控制中心展示的歌曲信息 */
  setMeta(song: Song): void {
    if (!this.session) {
      return;
    }
    const meta: avSession.AVMetadata = {
      assetId: `${song.id}_${song.title}`,
      title: song.title,
      artist: song.artist || '未知歌手',
      album: song.album || '未知专辑',
      duration: song.duration
    };
    this.session.setAVMetadata(meta).catch(() => {});
  }

  /** 更新播放状态（锁屏进度条联动） */
  setState(playing: boolean, pos: number): void {
    if (!this.session) {
      return;
    }
    const st: avSession.AVPlaybackState = {
      state: playing ? avSession.PlaybackState.PLAYBACK_STATE_PLAY : avSession.PlaybackState.PLAYBACK_STATE_PAUSE,
      position: { elapsedTime: pos, updateTime: Date.now() }
    };
    this.session.setAVPlaybackState(st).catch(() => {});
  }
}
