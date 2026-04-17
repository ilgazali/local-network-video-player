/**
 * Application-wide constants for Preferences keys, limits, and defaults.
 */
export class AppConstants {
  /** Preferences store name */
  static readonly PREF_NAME: string = 'lnvp_prefs';

  /** Preferences key: video playback history (JSON array) */
  static readonly KEY_HISTORY: string = 'video_history';

  /** Preferences key: favorite videos (JSON array) */
  static readonly KEY_FAVORITES: string = 'video_favorites';

  /** Preferences key: default playback speed */
  static readonly KEY_SPEED: string = 'playback_speed';

  /** Preferences key: auto-play next toggle */
  static readonly KEY_AUTOPLAY: string = 'autoplay';

  /** Preferences key: loop mode setting */
  static readonly KEY_LOOP: string = 'loop_mode';

  /** Preferences key: last entered network URL */
  static readonly KEY_LAST_URL: string = 'last_network_url';

  /** Preferences key: application language */
  static readonly KEY_LANG: string = 'lang';

  /** Maximum number of history items to retain (FIFO) */
  static readonly MAX_HISTORY_ITEMS: number = 200;

  /** Maximum retry count for network video loading */
  static readonly MAX_RETRY_COUNT: number = 3;

  /** Default watch display size in px */
  static readonly WATCH_SIZE_PX: number = 466;

  /** Default watch display size string */
  static readonly WATCH_SIZE: string = '466px';

  /** Safe area margin for round display */
  static readonly ROUND_MARGIN: number = 26;

  /** App version */
  static readonly APP_VERSION: string = '1.0.0';

  /** App name */
  static readonly APP_NAME: string = 'Local Network Video Player';

  /** License type */
  static readonly LICENSE: string = 'MIT';
}
