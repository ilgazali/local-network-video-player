// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/data-persistence-by-preferences
// Settings page business logic

import { SettingsModel, SpeedValue, AppLanguage, getDefaultSettings } from '../common/types/SettingsModel';
import { LoopMode } from '../common/types/PlaybackState';
import { AppConstants } from '../common/constants/AppConstants';
import { PreferencesUtil } from '../common/utils/PreferencesUtil';
import { VideoHistoryService } from '../services/VideoHistoryService';
import { AVPlayerService } from '../services/AVPlayerService';
import { Logger } from '../common/utils/Logger';

const MODULE: string = 'SettingsViewModel';

/**
 * ViewModel for the Settings page.
 * Manages loading/saving of user preferences and applying them to services.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/data-persistence-by-preferences
 */
export class SettingsViewModel {
  private settings: SettingsModel;

  constructor() {
    this.settings = getDefaultSettings();
  }

  /**
   * Load all settings from Preferences.
   * Call in SettingsPage.aboutToAppear.
   * @returns The current SettingsModel
   */
  async load(): Promise<SettingsModel> {
    try {
      const autoPlay = await PreferencesUtil.getBoolean(AppConstants.KEY_AUTOPLAY, false);
      const loopStr = await PreferencesUtil.getString(AppConstants.KEY_LOOP, LoopMode.OFF);
      const speedNum = await PreferencesUtil.getNumber(AppConstants.KEY_SPEED, SpeedValue.SPEED_1_0);
      const langStr = await PreferencesUtil.getString(AppConstants.KEY_LANG, AppLanguage.EN);

      this.settings = {
        autoPlay: autoPlay,
        loopMode: loopStr as LoopMode,
        defaultSpeed: speedNum as SpeedValue,
        language: langStr as AppLanguage
      };

      Logger.i(MODULE, 'Settings loaded: autoPlay=%{public}s, loop=%{public}s, speed=%{public}s, lang=%{public}s',
        `${autoPlay}`, loopStr, `${speedNum}`, langStr);
    } catch (err) {
      Logger.e(MODULE, 'Failed to load settings, using defaults');
      this.settings = getDefaultSettings();
    }
    return this.settings;
  }

  /**
   * Save auto-play setting.
   * @param enabled - Whether auto-play is enabled
   */
  async setAutoPlay(enabled: boolean): Promise<void> {
    this.settings.autoPlay = enabled;
    await PreferencesUtil.putBoolean(AppConstants.KEY_AUTOPLAY, enabled);
    Logger.d(MODULE, 'Auto-play set to %{public}s', `${enabled}`);
  }

  /**
   * Save loop mode setting and apply to AVPlayerService.
   * @param mode - The LoopMode to set
   */
  async setLoopMode(mode: LoopMode): Promise<void> {
    this.settings.loopMode = mode;
    await PreferencesUtil.putString(AppConstants.KEY_LOOP, mode);
    AVPlayerService.getInstance().loopMode = mode;
    Logger.d(MODULE, 'Loop mode set to %{public}s', mode);
  }

  /**
   * Save default playback speed.
   * @param speed - The SpeedValue to set
   */
  async setDefaultSpeed(speed: SpeedValue): Promise<void> {
    this.settings.defaultSpeed = speed;
    await PreferencesUtil.putNumber(AppConstants.KEY_SPEED, speed);
    Logger.d(MODULE, 'Default speed set to %{public}s', `${speed}`);
  }

  /**
   * Save application language preference.
   * @param lang - The AppLanguage to set
   */
  async setLanguage(lang: AppLanguage): Promise<void> {
    this.settings.language = lang;
    await PreferencesUtil.putString(AppConstants.KEY_LANG, lang);
    Logger.d(MODULE, 'Language set to %{public}s', lang);
  }

  /**
   * Clear all playback history via VideoHistoryService.
   */
  async clearHistory(): Promise<void> {
    await VideoHistoryService.getInstance().clearHistory();
    Logger.i(MODULE, 'History cleared from settings');
  }

  /**
   * Get current settings model (in-memory).
   * @returns The current SettingsModel
   */
  getSettings(): SettingsModel {
    return this.settings;
  }
}
