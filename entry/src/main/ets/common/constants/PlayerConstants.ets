/**
 * Constants related to the AVPlayer and playback controls.
 */
export class PlayerConstants {
  /** XComponent surface ID key */
  static readonly XCOMPONENT_ID: string = 'lnvp_av_player';

  /** Time update interval in milliseconds for progress tracking */
  static readonly TIME_UPDATE_INTERVAL_MS: number = 100;

  /** Seek threshold: minimum ms change to trigger seek */
  static readonly SEEK_THRESHOLD_MS: number = 500;

  /** Volume step for crown/gesture control (0.0 - 1.0 range) */
  static readonly VOLUME_STEP: number = 0.05;

  /** Brightness step for gesture control (0 - 255 range) */
  static readonly BRIGHTNESS_STEP: number = 10;

  /** Minimum volume */
  static readonly VOLUME_MIN: number = 0.0;

  /** Maximum volume */
  static readonly VOLUME_MAX: number = 1.0;

  /** Minimum brightness */
  static readonly BRIGHTNESS_MIN: number = 0;

  /** Maximum brightness */
  static readonly BRIGHTNESS_MAX: number = 255;

  /** Gesture feedback popup display duration in ms */
  static readonly GESTURE_POPUP_DURATION_MS: number = 1500;

  /** Speed display labels indexed by SpeedValue */
  static readonly SPEED_LABELS: string[] = ['0.5x', '1.0x', '1.5x', '2.0x'];

  /** Player component size ratio relative to screen */
  static readonly PLAYER_SIZE_RATIO: number = 0.9;

  /** Control bar height in vp */
  static readonly CONTROL_BAR_HEIGHT: number = 48;

  /** Progress ring stroke width in vp */
  static readonly PROGRESS_STROKE_WIDTH: number = 4;
}
