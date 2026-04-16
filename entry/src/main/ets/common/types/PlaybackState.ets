// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback

/**
 * Enum representing all possible AVPlayer playback states.
 * Maps directly to the HarmonyOS AVPlayer state machine.
 */
export enum PlaybackState {
  /** Player created but no source set */
  IDLE = 'idle',
  /** Source URL/fd set, awaiting prepare */
  INITIALIZED = 'initialized',
  /** Media prepared, ready to play */
  PREPARED = 'prepared',
  /** Media is currently playing */
  PLAYING = 'playing',
  /** Playback is paused */
  PAUSED = 'paused',
  /** Playback reached end of media */
  COMPLETED = 'completed',
  /** Player stopped, can be prepared again */
  STOPPED = 'stopped',
  /** Player released, cannot be reused */
  RELEASED = 'released',
  /** Player encountered an error */
  ERROR = 'error'
}

/**
 * Enum for buffering info types from AVPlayer.
 */
export enum BufferingType {
  /** Buffering started */
  BUFFERING_START = 1,
  /** Buffering ended */
  BUFFERING_END = 2,
  /** Buffering percentage update */
  BUFFERING_PERCENT = 3,
  /** Cached duration in ms */
  CACHED_DURATION = 4
}

/**
 * Loop mode for playlist playback.
 */
export enum LoopMode {
  /** No looping */
  OFF = 'off',
  /** Repeat current track */
  ONE = 'one',
  /** Repeat entire playlist */
  ALL = 'all'
}
