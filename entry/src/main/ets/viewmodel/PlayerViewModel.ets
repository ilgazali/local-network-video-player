// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
// Player page business logic bridging UI state to AVPlayerService

import { media } from '@kit.MediaKit';
import { AVPlayerService } from '../services/AVPlayerService';
import { AVSessionService } from '../services/AVSessionService';
import { VideoHistoryService } from '../services/VideoHistoryService';
import { PlaybackState, LoopMode } from '../common/types/PlaybackState';
import { VideoSource, VideoItem } from '../common/types/VideoItem';
import { SpeedValue } from '../common/types/SettingsModel';
import { PreferencesUtil } from '../common/utils/PreferencesUtil';
import { AppConstants } from '../common/constants/AppConstants';
import { Logger } from '../common/utils/Logger';

const MODULE: string = 'PlayerViewModel';

/**
 * ViewModel for the video player pages.
 * Bridges UI state management to AVPlayerService, AVSessionService, and VideoHistoryService.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
 */
export class PlayerViewModel {
  private playerService: AVPlayerService;
  private sessionService: AVSessionService;
  private historyService: VideoHistoryService;

  constructor() {
    this.playerService = AVPlayerService.getInstance();
    this.sessionService = AVSessionService.getInstance();
    this.historyService = VideoHistoryService.getInstance();
  }

  /**
   * Load and play a video from a given source.
   * Also records the item in history and updates AVSession metadata.
   * @param source - The video source to load
   * @param title - Display title for the video
   */
  async loadAndPlay(source: VideoSource, title: string): Promise<void> {
    Logger.i(MODULE, 'loadAndPlay: %{public}s', title);
    await this.playerService.load(source);

    // Record in history
    const item: VideoItem = {
      id: `${Date.now()}`,
      title: title,
      source: source,
      durationMs: 0,
      lastPositionMs: 0,
      lastPlayedAt: Date.now(),
      isFavorite: this.historyService.isFavorite(`${Date.now()}`)
    };
    await this.historyService.addToHistory(item);
  }

  /**
   * Set the surface ID for video rendering.
   * @param surfaceId - Surface ID from XComponent
   */
  setSurfaceId(surfaceId: string): void {
    this.playerService.setSurfaceId(surfaceId);
  }

  /** Toggle play/pause */
  togglePlayPause(): void {
    this.playerService.togglePlayPause();
  }

  /** Seek to position in ms */
  seek(ms: number): void {
    this.playerService.seek(ms);
  }

  /**
   * Set playback speed by SpeedValue enum.
   * @param speedValue - Speed index from SpeedValue enum
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
   */
  setSpeed(speedValue: SpeedValue): void {
    let speed: media.PlaybackSpeed;
    switch (speedValue) {
      case SpeedValue.SPEED_0_5:
        speed = media.PlaybackSpeed.SPEED_FORWARD_0_50_X;
        break;
      case SpeedValue.SPEED_1_5:
        speed = media.PlaybackSpeed.SPEED_FORWARD_1_50_X;
        break;
      case SpeedValue.SPEED_2_0:
        speed = media.PlaybackSpeed.SPEED_FORWARD_2_00_X;
        break;
      case SpeedValue.SPEED_1_0:
      default:
        speed = media.PlaybackSpeed.SPEED_FORWARD_1_00_X;
        break;
    }
    this.playerService.setSpeed(speed);
    PreferencesUtil.putNumber(AppConstants.KEY_SPEED, speedValue);
  }

  /** Set loop mode */
  setLoopMode(mode: LoopMode): void {
    this.playerService.loopMode = mode;
    PreferencesUtil.putString(AppConstants.KEY_LOOP, mode);
  }

  /** Adjust volume by delta */
  adjustVolume(delta: number): void {
    this.playerService.adjustVolume(delta);
  }

  /** Get current playback state */
  getState(): PlaybackState {
    return this.playerService.getState();
  }

  /** Get current time in ms */
  getCurrentTimeMs(): number {
    return this.playerService.getCurrentTimeMs();
  }

  /** Get total duration in ms */
  getDurationMs(): number {
    return this.playerService.getDurationMs();
  }

  /** Get current volume */
  getVolume(): number {
    return this.playerService.getVolume();
  }

  /**
   * Update AVSession state. Call on every state change.
   * @param state - Current playback state
   */
  async updateSessionState(state: PlaybackState): Promise<void> {
    const positionMs = this.playerService.getCurrentTimeMs();
    const speedMap: Map<media.PlaybackSpeed, number> = new Map([
      [media.PlaybackSpeed.SPEED_FORWARD_0_50_X, 0.5],
      [media.PlaybackSpeed.SPEED_FORWARD_1_00_X, 1.0],
      [media.PlaybackSpeed.SPEED_FORWARD_1_50_X, 1.5],
      [media.PlaybackSpeed.SPEED_FORWARD_2_00_X, 2.0]
    ]);
    const speed = speedMap.get(this.playerService.getSpeed()) ?? 1.0;
    await this.sessionService.updatePlaybackState(state, positionMs, speed);
  }

  /**
   * Release player resources. Call from aboutToDisappear.
   */
  async releasePlayer(): Promise<void> {
    this.playerService.clearCallbacks();
    Logger.i(MODULE, 'Player callbacks cleared');
  }

  /**
   * Save the last used network URL.
   * @param url - The network URL string
   */
  async saveLastUrl(url: string): Promise<void> {
    await PreferencesUtil.putString(AppConstants.KEY_LAST_URL, url);
  }

  /**
   * Load the last used network URL.
   * @returns The stored URL or empty string
   */
  async loadLastUrl(): Promise<string> {
    return await PreferencesUtil.getString(AppConstants.KEY_LAST_URL, '');
  }

  /** Get the AVPlayerService instance for direct callback registration */
  getPlayerService(): AVPlayerService {
    return this.playerService;
  }
}
