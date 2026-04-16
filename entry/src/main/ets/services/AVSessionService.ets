// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/avsession-access-scene
// F8: AVSession for lock-screen playback controls

import { avSession } from '@kit.AVSessionKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { AVPlayerService } from './AVPlayerService';
import { PlaybackState } from '../common/types/PlaybackState';
import { Logger } from '../common/utils/Logger';

const MODULE: string = 'AVSessionService';

/**
 * Service managing AVSession for lock-screen and system media controls.
 * Bridges system media controls (play/pause/seek) to AVPlayerService.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/avsession-access-scene
 */
export class AVSessionService {
  private static instance: AVSessionService | null = null;
  private session: avSession.AVSession | null = null;
  private playerService: AVPlayerService;

  private constructor() {
    this.playerService = AVPlayerService.getInstance();
  }

  /**
   * Get the singleton instance.
   * @returns The shared AVSessionService instance
   */
  static getInstance(): AVSessionService {
    if (AVSessionService.instance === null) {
      AVSessionService.instance = new AVSessionService();
    }
    return AVSessionService.instance;
  }

  /**
   * Create and activate an AVSession for system media control integration.
   * @param context - UIAbilityContext from EntryAbility
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/avsession-access-scene
   */
  async create(context: common.UIAbilityContext): Promise<void> {
    try {
      this.session = await avSession.createAVSession(context, 'LocalNetworkVideoPlayer', 'video');
      this.registerCommands();
      await this.session.activate();
      Logger.i(MODULE, 'AVSession created and activated');
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'Failed to create AVSession: %{public}s', error.message);
    }
  }

  /**
   * Register command handlers for system media controls.
   * Delegates play/pause/seek/stop to AVPlayerService.
   */
  private registerCommands(): void {
    if (this.session === null) {
      return;
    }

    this.session.on('play', () => {
      Logger.d(MODULE, 'Session command: play');
      this.playerService.play();
    });

    this.session.on('pause', () => {
      Logger.d(MODULE, 'Session command: pause');
      this.playerService.pause();
    });

    this.session.on('seek', (time: number) => {
      Logger.d(MODULE, 'Session command: seek to %{public}s', `${time}`);
      this.playerService.seek(time);
    });

    this.session.on('stop', () => {
      Logger.d(MODULE, 'Session command: stop');
      this.playerService.stop();
    });

    this.session.on('playNext', () => {
      Logger.d(MODULE, 'Session command: next');
      this.playerService.next();
    });

    this.session.on('playPrevious', () => {
      Logger.d(MODULE, 'Session command: previous');
      this.playerService.previous();
    });
  }

  /**
   * Update the session metadata (title, duration, artwork).
   * Call when a new video starts playing.
   * @param title - Video title
   * @param durationMs - Total duration in milliseconds
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/avsession-access-scene
   */
  async updateMetadata(title: string, durationMs: number): Promise<void> {
    if (this.session === null) {
      return;
    }
    try {
      const metadata: avSession.AVMetadata = {
        assetId: `lnvp_${Date.now()}`,
        title: title,
        duration: durationMs
      };
      await this.session.setAVMetadata(metadata);
      Logger.d(MODULE, 'Metadata updated: %{public}s', title);
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'Failed to set metadata: %{public}s', error.message);
    }
  }

  /**
   * Update the session playback state.
   * Call on every AVPlayer state change.
   * @param state - Current PlaybackState
   * @param positionMs - Current position in milliseconds
   * @param speed - Current playback speed (1.0 = normal)
   */
  async updatePlaybackState(state: PlaybackState, positionMs: number, speed: number): Promise<void> {
    if (this.session === null) {
      return;
    }
    try {
      let avState: avSession.PlaybackState;
      switch (state) {
        case PlaybackState.PLAYING:
          avState = avSession.PlaybackState.PLAYBACK_STATE_PLAY;
          break;
        case PlaybackState.PAUSED:
          avState = avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
          break;
        case PlaybackState.STOPPED:
        case PlaybackState.COMPLETED:
          avState = avSession.PlaybackState.PLAYBACK_STATE_STOP;
          break;
        case PlaybackState.PREPARED:
          avState = avSession.PlaybackState.PLAYBACK_STATE_PREPARE;
          break;
        default:
          avState = avSession.PlaybackState.PLAYBACK_STATE_INITIAL;
          break;
      }

      const playbackState: avSession.AVPlaybackState = {
        state: avState,
        speed: speed,
        position: {
          elapsedTime: positionMs,
          updateTime: Date.now()
        }
      };
      await this.session.setAVPlaybackState(playbackState);
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'Failed to set playback state: %{public}s', error.message);
    }
  }

  /**
   * Destroy the AVSession and release resources.
   * Call in EntryAbility.onDestroy.
   */
  async destroy(): Promise<void> {
    if (this.session === null) {
      return;
    }
    try {
      await this.session.destroy();
      this.session = null;
      Logger.i(MODULE, 'AVSession destroyed');
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'Failed to destroy AVSession: %{public}s', error.message);
    }
  }
}
