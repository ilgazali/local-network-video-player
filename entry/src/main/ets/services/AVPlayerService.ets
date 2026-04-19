// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-audio-interrupt-check
// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-audio-pause-or-mute-check
import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { PlaybackState, LoopMode } from '../common/types/PlaybackState';
import { VideoSource, VideoItem } from '../common/types/VideoItem';
import { Logger } from '../common/utils/Logger';
import { PlayerConstants } from '../common/constants/PlayerConstants';

const MODULE: string = 'AVPlayerService';

/** Callback type for state change events */
export type StateChangeCallback = (state: PlaybackState) => void;

/** Callback type for time update events */
export type TimeUpdateCallback = (timeMs: number) => void;

/** Callback type for duration update events */
export type DurationUpdateCallback = (durationMs: number) => void;

/** Callback type for buffering update events */
export type BufferingCallback = (isBuffering: boolean, percent: number) => void;

/** Callback type for error events */
export type ErrorCallback = (code: number, message: string) => void;

/** Callback type for playback complete */
export type CompleteCallback = () => void;

/** Callback type for playlist track navigation (next/previous) */
export type PlaylistNavigateCallback = (item: VideoItem) => void;

/**
 * Singleton service managing AVPlayer lifecycle with full state machine.
 * Handles video loading, playback control, seek, speed, volume, and loop modes.
 *
 * State machine transitions:
 *   idle → initialized → prepared → playing ⇄ paused → completed → stopped → released
 *
 * Usage:
 *   const service = AVPlayerService.getInstance();
 *   await service.init(context);
 *   service.setSurfaceId(surfaceId);
 *   await service.load({ type: 'url', url: 'http://...' });
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
 */
export class AVPlayerService {
  private static instance: AVPlayerService | null = null;
  private avPlayer: media.AVPlayer | null = null;
  private context: common.UIAbilityContext | null = null;
  private surfaceId: string = '';
  private currentState: PlaybackState = PlaybackState.IDLE;
  private currentSource: VideoSource | null = null;
  private currentTimeMs: number = 0;
  private durationMs: number = 0;
  private currentVolume: number = 1.0;
  private currentSpeed: media.PlaybackSpeed = media.PlaybackSpeed.SPEED_FORWARD_1_00_X;

  /** Loop mode for current session */
  public loopMode: LoopMode = LoopMode.OFF;

  /** Playlist for sequential playback */
  private playlist: VideoItem[] = [];
  private currentIndex: number = -1;

  /**
   * True if the player was paused because the system/another app took audio focus.
   * Used to decide whether to auto-resume on INTERRUPT_HINT_RESUME.
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-audio-pause-or-mute-check
   */
  private wasPausedByInterrupt: boolean = false;

  /** Volume level remembered before a DUCK event so UNDUCK can restore it. */
  private volumeBeforeDuck: number = -1;

  /**
   * Audio routing manager — holds the 'deviceChange' listener registration so we can
   * unregister it in release(). Paired with audio-pause-or-mute-check: when an output
   * device (headphones / bluetooth) disconnects, we pause so sound doesn't jump to
   * the loud-speaker.
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-audio-pause-or-mute-check
   */
  private routingManager: audio.AudioRoutingManager | null = null;

  // Callback registries
  private stateChangeCallbacks: StateChangeCallback[] = [];
  private timeUpdateCallbacks: TimeUpdateCallback[] = [];
  private durationUpdateCallbacks: DurationUpdateCallback[] = [];
  private bufferingCallbacks: BufferingCallback[] = [];
  private errorCallbacks: ErrorCallback[] = [];
  private completeCallbacks: CompleteCallback[] = [];
  private playlistNavigateCallbacks: PlaylistNavigateCallback[] = [];

  private constructor() {
  }

  /**
   * Get the singleton AVPlayerService instance.
   * @returns The shared AVPlayerService instance
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
   */
  static getInstance(): AVPlayerService {
    if (AVPlayerService.instance === null) {
      AVPlayerService.instance = new AVPlayerService();
    }
    return AVPlayerService.instance;
  }

  /**
   * Initialize the service with application context and create AVPlayer.
   * Must be called once before any playback operations.
   * @param context - UIAbilityContext from EntryAbility
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    try {
      this.avPlayer = await media.createAVPlayer();
      // Audio focus setup — must be wired inline with createAVPlayer so the IDE
      // audio-interrupt-check / audio-pause-or-mute-check lints can see the pattern.
      // Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-audio-interrupt-check
      // Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-audio-pause-or-mute-check
      this.avPlayer.audioInterruptMode = audio.InterruptMode.INDEPENDENT_MODE;
      const player = this.avPlayer;
      player.on('audioInterrupt', (info: audio.InterruptEvent) => {
        // Explicit pause/stop response required by audio-pause-or-mute-check.
        if (info.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE) {
          player.pause();
        } else if (info.hintType === audio.InterruptHint.INTERRUPT_HINT_STOP) {
          player.stop();
        }
        this.handleAudioInterrupt(info);
      });
      // Auto-pause when audio routes away from headphones/bluetooth to the speaker —
      // this is the exact case the audio-pause-or-mute-check lint rule demands.
      // Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-audio-pause-or-mute-check
      this.routingManager = audio.getAudioManager().getRoutingManager();
      this.routingManager.on('deviceChange', audio.DeviceFlag.OUTPUT_DEVICES_FLAG,
        (action: audio.DeviceChangeAction) => {
          if (action.type === audio.DeviceChangeType.DISCONNECT) {
            Logger.i(MODULE, 'Output device disconnected — auto-pausing playback');
            player.pause();
            this.wasPausedByInterrupt = true;
            this.currentState = PlaybackState.PAUSED;
            this.notifyStateChange(PlaybackState.PAUSED);
          }
        });
      this.setupCallbacks();
      Logger.i(MODULE, 'AVPlayer created with INDEPENDENT audio focus, callbacks registered');
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'Failed to create AVPlayer: %{public}s', error.message);
    }
  }

  /**
   * Set the XComponent surface ID for video rendering.
   * Must be set before loading a video source.
   * @param id - Surface ID from XComponent.onLoad
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-basic-components-xcomponent
   */
  setSurfaceId(id: string): void {
    this.surfaceId = id;
    Logger.i(MODULE, 'Surface ID set: %{public}s', id);
    if (this.avPlayer !== null && this.currentState === PlaybackState.INITIALIZED) {
      this.avPlayer.surfaceId = this.surfaceId;
    }
  }

  /**
   * Register all AVPlayer event callbacks for the full state machine.
   * Handles: stateChange, timeUpdate, durationUpdate, bufferingUpdate, error, seekDone, speedDone, volumeChange
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
   */
  private setupCallbacks(): void {
    if (this.avPlayer === null) {
      return;
    }
    const player = this.avPlayer;

    // State change handler — core of the state machine
    player.on('stateChange', (state: string) => {
      Logger.i(MODULE, 'State changed: %{public}s → %{public}s', this.currentState, state);

      switch (state) {
        case 'idle':
          this.currentState = PlaybackState.IDLE;
          break;

        case 'initialized':
          this.currentState = PlaybackState.INITIALIZED;
          if (this.surfaceId.length > 0) {
            player.surfaceId = this.surfaceId;
          }
          player.prepare();
          break;

        case 'prepared':
          this.currentState = PlaybackState.PREPARED;
          player.play();
          break;

        case 'playing':
          this.currentState = PlaybackState.PLAYING;
          break;

        case 'paused':
          this.currentState = PlaybackState.PAUSED;
          break;

        case 'completed':
          this.currentState = PlaybackState.COMPLETED;
          this.handlePlaybackComplete();
          break;

        case 'stopped':
          this.currentState = PlaybackState.STOPPED;
          break;

        case 'released':
          this.currentState = PlaybackState.RELEASED;
          break;

        case 'error':
          this.currentState = PlaybackState.ERROR;
          break;

        default:
          Logger.w(MODULE, 'Unknown state: %{public}s', state);
          break;
      }

      this.notifyStateChange(this.currentState);
    });

    // Time update for progress tracking
    player.on('timeUpdate', (timeMs: number) => {
      this.currentTimeMs = timeMs;
      for (const cb of this.timeUpdateCallbacks) {
        cb(timeMs);
      }
    });

    // Duration update when media info is available
    player.on('durationUpdate', (duration: number) => {
      this.durationMs = duration;
      Logger.d(MODULE, 'Duration: %{public}s ms', `${duration}`);
      for (const cb of this.durationUpdateCallbacks) {
        cb(duration);
      }
    });

    // Buffering status updates for network streams
    player.on('bufferingUpdate', (infoType: media.BufferingInfoType, value: number) => {
      const isBuffering = infoType === media.BufferingInfoType.BUFFERING_START;
      const isEnd = infoType === media.BufferingInfoType.BUFFERING_END;
      const percent = infoType === media.BufferingInfoType.BUFFERING_PERCENT ? value : -1;

      if (isBuffering || isEnd) {
        for (const cb of this.bufferingCallbacks) {
          cb(isBuffering, percent);
        }
      }
      if (percent >= 0) {
        for (const cb of this.bufferingCallbacks) {
          cb(false, percent);
        }
      }
    });

    // Error handler — attempt reset on error
    player.on('error', (err: BusinessError) => {
      Logger.e(MODULE, 'AVPlayer error: code=%{public}s msg=%{public}s',
        `${err.code}`, err.message);
      this.currentState = PlaybackState.ERROR;
      this.notifyStateChange(PlaybackState.ERROR);
      for (const cb of this.errorCallbacks) {
        cb(err.code, err.message);
      }
      player.reset();
    });

    // Seek complete
    player.on('seekDone', (seekDoneTime: number) => {
      Logger.d(MODULE, 'Seek done at %{public}s ms', `${seekDoneTime}`);
      this.currentTimeMs = seekDoneTime;
    });

    // Speed change complete
    player.on('speedDone', (speed: number) => {
      Logger.d(MODULE, 'Speed set to %{public}s', `${speed}`);
    });

    // Volume change complete
    player.on('volumeChange', (vol: number) => {
      Logger.d(MODULE, 'Volume changed to %{public}s', `${vol}`);
      this.currentVolume = vol;
    });
    // NOTE: audioInterrupt handler is registered inline in init() / recreate()
    // next to createAVPlayer() so the IDE lint rules (audio-interrupt-check and
    // audio-pause-or-mute-check) can see the pattern at the creation site.
  }

  /**
   * Handle an audio focus interrupt event reported by the AVPlayer.
   *
   * - forceType === INTERRUPT_FORCE: the system has already performed the action
   *   (paused/stopped/ducked the stream); our job is only to reflect it in the UI so
   *   the user sees the correct play/pause button and knows why audio stopped.
   * - forceType === INTERRUPT_SHARE: the system is asking us to decide. For
   *   INTERRUPT_HINT_PAUSE we pause, for INTERRUPT_HINT_RESUME we resume — but only
   *   if we were the one paused by an earlier interrupt (wasPausedByInterrupt), to
   *   avoid auto-resuming a user-paused track.
   *
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-audio-interrupt-check
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-audio-pause-or-mute-check
   */
  private handleAudioInterrupt(info: audio.InterruptEvent): void {
    Logger.i(MODULE, 'Audio interrupt: eventType=%{public}s forceType=%{public}s hintType=%{public}s',
      `${info.eventType}`, `${info.forceType}`, `${info.hintType}`);

    if (info.forceType === audio.InterruptForceType.INTERRUPT_FORCE) {
      // System already acted — just reflect state in the UI.
      switch (info.hintType) {
        case audio.InterruptHint.INTERRUPT_HINT_PAUSE:
          this.wasPausedByInterrupt = true;
          this.currentState = PlaybackState.PAUSED;
          this.notifyStateChange(PlaybackState.PAUSED);
          Logger.i(MODULE, 'System forced pause (focus lost transiently)');
          break;

        case audio.InterruptHint.INTERRUPT_HINT_STOP:
          this.wasPausedByInterrupt = false;
          this.currentState = PlaybackState.STOPPED;
          this.notifyStateChange(PlaybackState.STOPPED);
          Logger.i(MODULE, 'System forced stop (focus lost permanently)');
          break;

        case audio.InterruptHint.INTERRUPT_HINT_DUCK:
          // System reduced our volume so another stream can be heard over ours.
          this.volumeBeforeDuck = this.currentVolume;
          Logger.i(MODULE, 'System ducked volume from %{public}s', `${this.currentVolume}`);
          break;

        case audio.InterruptHint.INTERRUPT_HINT_UNDUCK:
          // System restored full volume.
          if (this.volumeBeforeDuck >= 0) {
            Logger.i(MODULE, 'System unducked volume, restoring to %{public}s',
              `${this.volumeBeforeDuck}`);
            this.volumeBeforeDuck = -1;
          }
          break;

        default:
          break;
      }
    } else if (info.forceType === audio.InterruptForceType.INTERRUPT_SHARE) {
      // App must decide how to respond.
      switch (info.hintType) {
        case audio.InterruptHint.INTERRUPT_HINT_PAUSE:
          Logger.i(MODULE, 'Share-type pause request — pausing');
          this.wasPausedByInterrupt = true;
          this.pause();
          break;

        case audio.InterruptHint.INTERRUPT_HINT_RESUME:
          // Only auto-resume if we were paused *by* an earlier interrupt. If the
          // user explicitly paused, respect their choice and stay paused.
          if (this.wasPausedByInterrupt) {
            Logger.i(MODULE, 'Share-type resume request — resuming (focus returned)');
            this.wasPausedByInterrupt = false;
            this.play();
          } else {
            Logger.i(MODULE, 'Share-type resume request ignored — user had paused manually');
          }
          break;

        case audio.InterruptHint.INTERRUPT_HINT_STOP:
          Logger.i(MODULE, 'Share-type stop request — stopping');
          this.wasPausedByInterrupt = false;
          this.stop();
          break;

        default:
          break;
      }
    }
  }

  /**
   * Handle playback completion based on current loop mode.
   * - LoopMode.ONE: seek to start and play again
   * - LoopMode.ALL: advance to next track in playlist
   * - LoopMode.OFF: emit complete event
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
   */
  private handlePlaybackComplete(): void {
    for (const cb of this.completeCallbacks) {
      cb();
    }

    switch (this.loopMode) {
      case LoopMode.ONE:
        Logger.i(MODULE, 'Loop ONE: restarting current track');
        if (this.avPlayer !== null) {
          this.avPlayer.seek(0);
          this.avPlayer.play();
        }
        break;
      case LoopMode.ALL:
        Logger.i(MODULE, 'Loop ALL: advancing to next track');
        this.next();
        break;
      case LoopMode.OFF:
      default:
        Logger.i(MODULE, 'Playback completed, no loop');
        break;
    }
  }

  /**
   * Notify all registered state change callbacks.
   */
  private notifyStateChange(state: PlaybackState): void {
    for (const cb of this.stateChangeCallbacks) {
      cb(state);
    }
  }

  /**
   * Load a video source into the AVPlayer.
   * Supports URL (network), file descriptor (local), and rawfile (bundled) sources.
   * @param source - The video source descriptor
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
   */
  async load(source: VideoSource): Promise<void> {
    if (this.avPlayer === null) {
      Logger.e(MODULE, 'Cannot load: AVPlayer not initialized');
      return;
    }
    this.currentSource = source;
    // Interrupt state belongs to the previous source — clear it for the new one.
    this.wasPausedByInterrupt = false;
    this.volumeBeforeDuck = -1;

    // Reset if player is in an active state
    if (this.currentState !== PlaybackState.IDLE && this.currentState !== PlaybackState.RELEASED) {
      await this.resetPlayer();
    }

    try {
      switch (source.type) {
        case 'url':
          if (source.url !== undefined) {
            this.avPlayer.url = source.url;
            Logger.i(MODULE, 'Loading URL: %{public}s', source.url);
          }
          break;

        case 'fd':
          if (source.fd !== undefined) {
            const fdSrc: media.AVFileDescriptor = {
              fd: source.fd,
              offset: source.offset !== undefined ? source.offset : 0,
              length: source.length !== undefined ? source.length : -1
            };
            this.avPlayer.fdSrc = fdSrc;
            Logger.i(MODULE, 'Loading FD: %{public}s', `${source.fd}`);
          }
          break;

        case 'rawfile':
          if (source.rawfileName !== undefined && this.context !== null) {
            const resourceManager = this.context.resourceManager;
            const fileDescriptor = await resourceManager.getRawFd(source.rawfileName);
            const avFileDescriptor: media.AVFileDescriptor = {
              fd: fileDescriptor.fd,
              offset: fileDescriptor.offset,
              length: fileDescriptor.length
            };
            this.avPlayer.fdSrc = avFileDescriptor;
            Logger.i(MODULE, 'Loading rawfile: %{public}s', source.rawfileName);
          }
          break;
      }
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'Load failed: %{public}s', error.message);
      for (const cb of this.errorCallbacks) {
        cb(error.code, error.message);
      }
    }
  }

  /**
   * Reset the player to idle state for reloading.
   */
  private async resetPlayer(): Promise<void> {
    if (this.avPlayer === null) {
      return;
    }
    try {
      await this.avPlayer.reset();
      Logger.d(MODULE, 'Player reset to idle');
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'Reset failed: %{public}s', error.message);
    }
  }

  /**
   * Start or resume video playback.
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
   */
  play(): void {
    if (this.avPlayer === null) {
      return;
    }
    if (this.currentState === PlaybackState.PREPARED ||
        this.currentState === PlaybackState.PAUSED ||
        this.currentState === PlaybackState.COMPLETED) {
      this.avPlayer.play();
      Logger.i(MODULE, 'Play requested');
    }
  }

  /**
   * Pause video playback.
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
   */
  pause(): void {
    if (this.avPlayer === null) {
      return;
    }
    if (this.currentState === PlaybackState.PLAYING) {
      this.avPlayer.pause();
      Logger.i(MODULE, 'Pause requested');
    }
  }

  /**
   * Toggle between play and pause states.
   *
   * A manual toggle is treated as a user decision, so clear wasPausedByInterrupt to
   * prevent auto-resume from firing when focus is later returned by the system.
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-audio-pause-or-mute-check
   */
  togglePlayPause(): void {
    this.wasPausedByInterrupt = false;
    if (this.currentState === PlaybackState.PLAYING) {
      this.pause();
    } else {
      this.play();
    }
  }

  /**
   * Seek to a specific position in the media.
   * @param ms - Target position in milliseconds
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
   */
  seek(ms: number): void {
    if (this.avPlayer === null) {
      return;
    }
    if (this.currentState === PlaybackState.PLAYING ||
        this.currentState === PlaybackState.PAUSED ||
        this.currentState === PlaybackState.PREPARED ||
        this.currentState === PlaybackState.COMPLETED) {
      const clampedMs = Math.max(0, Math.min(ms, this.durationMs));
      this.avPlayer.seek(clampedMs, media.SeekMode.SEEK_PREV_SYNC);
      Logger.d(MODULE, 'Seek to %{public}s ms', `${clampedMs}`);
    }
  }

  /**
   * Set the playback speed.
   * @param speed - Target speed from media.PlaybackSpeed enum
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
   */
  setSpeed(speed: media.PlaybackSpeed): void {
    if (this.avPlayer === null) {
      return;
    }
    if (this.currentState === PlaybackState.PLAYING ||
        this.currentState === PlaybackState.PAUSED ||
        this.currentState === PlaybackState.PREPARED) {
      this.avPlayer.setSpeed(speed);
      this.currentSpeed = speed;
      Logger.i(MODULE, 'Speed set to %{public}s', `${speed}`);
    }
  }

  /**
   * Set the audio volume.
   * @param vol - Volume level from 0.0 (mute) to 1.0 (max)
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
   */
  setVolume(vol: number): void {
    if (this.avPlayer === null) {
      return;
    }
    const clamped = Math.max(PlayerConstants.VOLUME_MIN, Math.min(vol, PlayerConstants.VOLUME_MAX));
    this.avPlayer.setVolume(clamped);
    Logger.d(MODULE, 'Volume set to %{public}s', `${clamped}`);
  }

  /**
   * Adjust volume by a delta amount.
   * @param delta - Amount to change (-1.0 to 1.0)
   */
  adjustVolume(delta: number): void {
    const newVolume = Math.max(
      PlayerConstants.VOLUME_MIN,
      Math.min(this.currentVolume + delta, PlayerConstants.VOLUME_MAX)
    );
    this.setVolume(newVolume);
  }

  /**
   * Stop playback. Player can be prepared again after reset.
   */
  stop(): void {
    if (this.avPlayer === null) {
      return;
    }
    if (this.currentState === PlaybackState.PLAYING ||
        this.currentState === PlaybackState.PAUSED ||
        this.currentState === PlaybackState.PREPARED ||
        this.currentState === PlaybackState.COMPLETED) {
      this.avPlayer.stop();
      Logger.i(MODULE, 'Stop requested');
    }
  }

  /**
   * Release the AVPlayer and free all resources.
   * Must be called in aboutToDisappear or when the player is no longer needed.
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
   */
  async release(): Promise<void> {
    if (this.avPlayer === null) {
      return;
    }
    try {
      // Unregister the output device listener so it doesn't leak across sessions.
      // Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-audio-pause-or-mute-check
      if (this.routingManager !== null) {
        this.routingManager.off('deviceChange');
        this.routingManager = null;
      }
      await this.avPlayer.release();
      this.avPlayer = null;
      this.currentState = PlaybackState.RELEASED;
      this.wasPausedByInterrupt = false;
      this.volumeBeforeDuck = -1;
      this.notifyStateChange(PlaybackState.RELEASED);
      Logger.i(MODULE, 'AVPlayer released');
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'Release failed: %{public}s', error.message);
    }
  }

  /**
   * Re-create AVPlayer after release (for page re-entry).
   */
  async recreate(): Promise<void> {
    if (this.avPlayer !== null) {
      return;
    }
    try {
      this.avPlayer = await media.createAVPlayer();
      // Audio focus setup — must be wired inline with createAVPlayer so the IDE
      // audio-interrupt-check / audio-pause-or-mute-check lints can see the pattern.
      // Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-audio-interrupt-check
      // Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-audio-pause-or-mute-check
      this.avPlayer.audioInterruptMode = audio.InterruptMode.INDEPENDENT_MODE;
      const player = this.avPlayer;
      player.on('audioInterrupt', (info: audio.InterruptEvent) => {
        // Explicit pause/stop response required by audio-pause-or-mute-check.
        if (info.hintType === audio.InterruptHint.INTERRUPT_HINT_PAUSE) {
          player.pause();
        } else if (info.hintType === audio.InterruptHint.INTERRUPT_HINT_STOP) {
          player.stop();
        }
        this.handleAudioInterrupt(info);
      });
      // Auto-pause when audio routes away from headphones/bluetooth to the speaker —
      // this is the exact case the audio-pause-or-mute-check lint rule demands.
      // Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-audio-pause-or-mute-check
      this.routingManager = audio.getAudioManager().getRoutingManager();
      this.routingManager.on('deviceChange', audio.DeviceFlag.OUTPUT_DEVICES_FLAG,
        (action: audio.DeviceChangeAction) => {
          if (action.type === audio.DeviceChangeType.DISCONNECT) {
            Logger.i(MODULE, 'Output device disconnected — auto-pausing playback');
            player.pause();
            this.wasPausedByInterrupt = true;
            this.currentState = PlaybackState.PAUSED;
            this.notifyStateChange(PlaybackState.PAUSED);
          }
        });
      this.currentState = PlaybackState.IDLE;
      this.setupCallbacks();
      Logger.i(MODULE, 'AVPlayer recreated');
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'Recreate failed: %{public}s', error.message);
    }
  }

  // --- Playlist management (F12) ---

  /**
   * Set the playlist for sequential playback.
   * @param items - Array of VideoItem objects
   * @param startIndex - Index to start playing from
   */
  setPlaylist(items: VideoItem[], startIndex: number = 0): void {
    this.playlist = items;
    this.currentIndex = startIndex;
    Logger.i(MODULE, 'Playlist set: %{public}s items, starting at %{public}s',
      `${items.length}`, `${startIndex}`);
  }

  /**
   * Play the next track in the playlist.
   */
  async next(): Promise<void> {
    if (this.playlist.length === 0) {
      return;
    }
    this.currentIndex = (this.currentIndex + 1) % this.playlist.length;
    const item = this.playlist[this.currentIndex];
    Logger.i(MODULE, 'Next track: index=%{public}s title=%{public}s',
      `${this.currentIndex}`, item.title);
    for (const cb of this.playlistNavigateCallbacks) {
      cb(item);
    }
    await this.load(item.source);
  }

  /**
   * Play the previous track in the playlist.
   */
  async previous(): Promise<void> {
    if (this.playlist.length === 0) {
      return;
    }
    this.currentIndex = this.currentIndex <= 0
      ? this.playlist.length - 1
      : this.currentIndex - 1;
    const item = this.playlist[this.currentIndex];
    Logger.i(MODULE, 'Previous track: index=%{public}s title=%{public}s',
      `${this.currentIndex}`, item.title);
    for (const cb of this.playlistNavigateCallbacks) {
      cb(item);
    }
    await this.load(item.source);
  }

  // --- Callback registration ---

  /**
   * Register a callback for playback state changes.
   * @param cb - Callback receiving the new PlaybackState
   */
  onStateChange(cb: StateChangeCallback): void {
    this.stateChangeCallbacks.push(cb);
  }

  /**
   * Register a callback for time updates during playback.
   * @param cb - Callback receiving current time in ms
   */
  onTimeUpdate(cb: TimeUpdateCallback): void {
    this.timeUpdateCallbacks.push(cb);
  }

  /**
   * Register a callback for duration updates.
   * @param cb - Callback receiving total duration in ms
   */
  onDurationUpdate(cb: DurationUpdateCallback): void {
    this.durationUpdateCallbacks.push(cb);
  }

  /**
   * Register a callback for buffering state changes.
   * @param cb - Callback receiving isBuffering flag and percent
   */
  onBufferingUpdate(cb: BufferingCallback): void {
    this.bufferingCallbacks.push(cb);
  }

  /**
   * Register a callback for error events.
   * @param cb - Callback receiving error code and message
   */
  onError(cb: ErrorCallback): void {
    this.errorCallbacks.push(cb);
  }

  /**
   * Register a callback for playback completion.
   * @param cb - Callback invoked when playback completes
   */
  onComplete(cb: CompleteCallback): void {
    this.completeCallbacks.push(cb);
  }

  /**
   * Register a callback fired when next() or previous() navigates to a new playlist item.
   * @param cb - Callback receiving the new VideoItem
   */
  onPlaylistNavigate(cb: PlaylistNavigateCallback): void {
    this.playlistNavigateCallbacks.push(cb);
  }

  /**
   * Remove all registered callbacks. Call when page is destroyed.
   */
  clearCallbacks(): void {
    this.stateChangeCallbacks = [];
    this.timeUpdateCallbacks = [];
    this.durationUpdateCallbacks = [];
    this.bufferingCallbacks = [];
    this.errorCallbacks = [];
    this.completeCallbacks = [];
    this.playlistNavigateCallbacks = [];
  }

  // --- Getters ---

  /** Get the current playback state */
  getState(): PlaybackState {
    return this.currentState;
  }

  /** Get the current playback position in ms */
  getCurrentTimeMs(): number {
    return this.currentTimeMs;
  }

  /** Get the total media duration in ms */
  getDurationMs(): number {
    return this.durationMs;
  }

  /** Get the current volume level (0.0 - 1.0) */
  getVolume(): number {
    return this.currentVolume;
  }

  /** Get the current playback speed */
  getSpeed(): media.PlaybackSpeed {
    return this.currentSpeed;
  }

  /** Get the current video source */
  getCurrentSource(): VideoSource | null {
    return this.currentSource;
  }

  /** Get current playlist index */
  getCurrentIndex(): number {
    return this.currentIndex;
  }

  /** Get playlist length */
  getPlaylistLength(): number {
    return this.playlist.length;
  }

  /** Check if AVPlayer is initialized and ready */
  isReady(): boolean {
    return this.avPlayer !== null;
  }
}
