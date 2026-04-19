// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/avsession-access-scene
// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-avsession-metadata-check
import { avSession } from '@kit.AVSessionKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { AVPlayerService } from './AVPlayerService';
import { PlaybackState } from '../common/types/PlaybackState';
import { VideoItem } from '../common/types/VideoItem';
import { Logger } from '../common/utils/Logger';

const MODULE: string = 'AVSessionService';

/** Default cover image URI used when a caller does not supply one. */
const DEFAULT_MEDIA_IMAGE: string = 'resource://media/icon.png';

/**
 * Rich metadata describing the currently playing media. Populated by the page or
 * view-model when a new source is loaded so the lock-screen / control center /
 * paired-device UI can render title, artist, cover, and playlist neighbours.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-avsession-metadata-check
 */
export interface VideoMetadata {
  /** Stable identifier for the media item — must be consistent across calls. */
  assetId: string;
  /** Primary title shown in system media UI. */
  title: string;
  /** Total duration in milliseconds; 0 if not yet known. */
  durationMs: number;
  /** Secondary line (e.g. source URL, channel, filename). */
  subtitle?: string;
  /** Author / artist shown under the title. */
  artist?: string;
  /** Cover image URI (file://, resource://, or http(s)://). */
  mediaImage?: string;
  /** Asset ID of the previous track for lock-screen previous button. */
  previousAssetId?: string;
  /** Asset ID of the next track for lock-screen next button. */
  nextAssetId?: string;
}

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
   * Update the session metadata so the system's media UI (lock screen, control
   * center, paired devices) can render a complete description of the current video.
   *
   * Follows the AVSession metadata best practice:
   *   - assetId is stable per source (not Date.now()), so the system can correlate
   *     updates and playlist moves to the same "track".
   *   - title, subtitle, artist, mediaImage, mediaUri fill the visible UI.
   *   - previousAssetId / nextAssetId enable prev/next system buttons.
   *   - Missing title or duration is logged — both are load-bearing for system UI.
   *
   * @param meta - Full metadata for the current media item
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-avsession-metadata-check
   */
  async updateMetadata(meta: VideoMetadata): Promise<void> {
    if (this.session === null) {
      return;
    }
    if (meta.assetId.length === 0 || meta.title.length === 0) {
      Logger.w(MODULE, 'Metadata missing assetId or title — system UI will render blank');
    }
    if (meta.durationMs <= 0) {
      Logger.w(MODULE, 'Metadata duration is 0 — progress bar will not render (update once known)');
    }

    try {
      const metadata: avSession.AVMetadata = {
        assetId: meta.assetId,
        title: meta.title,
        artist: meta.artist !== undefined ? meta.artist : 'Local Network Video Player',
        subtitle: meta.subtitle !== undefined ? meta.subtitle : '',
        mediaImage: meta.mediaImage !== undefined ? meta.mediaImage : DEFAULT_MEDIA_IMAGE,
        duration: meta.durationMs,
        previousAssetId: meta.previousAssetId,
        nextAssetId: meta.nextAssetId
      };
      await this.session.setAVMetadata(metadata);
      Logger.d(MODULE, 'Metadata updated: assetId=%{public}s title=%{public}s duration=%{public}s',
        meta.assetId, meta.title, `${meta.durationMs}`);
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'Failed to set metadata: %{public}s', error.message);
    }
  }

  /**
   * Convenience wrapper that derives a VideoMetadata from a VideoItem and forwards
   * to updateMetadata(). Use this from pages/view-models that already hold a
   * VideoItem and optional playlist neighbours.
   *
   * @param item - The currently playing video item
   * @param previousAssetId - Asset ID of the previous playlist item, if any
   * @param nextAssetId - Asset ID of the next playlist item, if any
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-avsession-metadata-check
   */
  async updateMetadataFromItem(
    item: VideoItem,
    previousAssetId?: string,
    nextAssetId?: string
  ): Promise<void> {
    const source = item.source;
    const subtitle = source.type === 'url' && source.url !== undefined
      ? source.url
      : (source.rawfileName !== undefined ? source.rawfileName : '');

    const meta: VideoMetadata = {
      assetId: item.id,
      title: item.title,
      durationMs: item.durationMs,
      subtitle: subtitle,
      previousAssetId: previousAssetId,
      nextAssetId: nextAssetId
    };
    await this.updateMetadata(meta);
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
