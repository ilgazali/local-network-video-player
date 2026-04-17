import { LoopMode } from './PlaybackState';

/**
 * Supported playback speed values matching media.PlaybackSpeed enum indices.
 */
export enum SpeedValue {
  SPEED_0_5 = 0,
  SPEED_1_0 = 1,
  SPEED_1_5 = 2,
  SPEED_2_0 = 3
}

/**
 * Supported application languages.
 */
export enum AppLanguage {
  EN = 'en',
  TR = 'tr',
  ZH = 'zh'
}

/**
 * Application settings model persisted via Preferences.
 */
export interface SettingsModel {
  /** Auto-play next video in playlist */
  autoPlay: boolean;
  /** Current loop mode */
  loopMode: LoopMode;
  /** Default playback speed */
  defaultSpeed: SpeedValue;
  /** Application language */
  language: AppLanguage;
}

/**
 * Returns default settings values.
 */
export function getDefaultSettings(): SettingsModel {
  return {
    autoPlay: false,
    loopMode: LoopMode.OFF,
    defaultSpeed: SpeedValue.SPEED_1_0,
    language: AppLanguage.EN
  } as SettingsModel;
}
