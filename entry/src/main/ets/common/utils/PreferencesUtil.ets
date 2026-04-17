import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppConstants } from '../constants/AppConstants';
import { Logger } from './Logger';

const MODULE: string = 'PreferencesUtil';

/**
 * Utility class wrapping @kit.ArkData preferences for persistent key-value storage.
 * Must be initialized once via init() in EntryAbility.onCreate before use.
 */
export class PreferencesUtil {
  private static prefs: preferences.Preferences | null = null;

  /**
   * Initialize the preferences store. Call once at app startup.
   * @param context - The application context from UIAbility
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/data-persistence-by-preferences
   */
  static async init(context: Context): Promise<void> {
    try {
      PreferencesUtil.prefs = await preferences.getPreferences(context, AppConstants.PREF_NAME);
      Logger.i(MODULE, 'Preferences initialized successfully');
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'Failed to init preferences: %{public}s', error.message);
    }
  }

  /**
   * Get the preferences instance, throwing if not initialized.
   */
  private static getPrefs(): preferences.Preferences {
    if (PreferencesUtil.prefs === null) {
      throw new Error('PreferencesUtil not initialized. Call init() first.');
    }
    return PreferencesUtil.prefs;
  }

  /**
   * Store a string value and flush to disk.
   * @param key - The preference key
   * @param value - The string value to store
   */
  static async putString(key: string, value: string): Promise<void> {
    try {
      const prefs = PreferencesUtil.getPrefs();
      await prefs.put(key, value);
      await prefs.flush();
      Logger.d(MODULE, 'putString key=%{public}s', key);
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'putString failed for key=%{public}s: %{public}s', key, error.message);
    }
  }

  /**
   * Retrieve a string value from preferences.
   * @param key - The preference key
   * @param defaultValue - Fallback if key is absent
   * @returns The stored string or default
   */
  static async getString(key: string, defaultValue: string): Promise<string> {
    try {
      const prefs = PreferencesUtil.getPrefs();
      const value = await prefs.get(key, defaultValue);
      return value as string;
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'getString failed for key=%{public}s: %{public}s', key, error.message);
      return defaultValue;
    }
  }

  /**
   * Store a number value and flush to disk.
   * @param key - The preference key
   * @param value - The number value to store
   */
  static async putNumber(key: string, value: number): Promise<void> {
    try {
      const prefs = PreferencesUtil.getPrefs();
      await prefs.put(key, value);
      await prefs.flush();
      Logger.d(MODULE, 'putNumber key=%{public}s', key);
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'putNumber failed for key=%{public}s: %{public}s', key, error.message);
    }
  }

  /**
   * Retrieve a number value from preferences.
   * @param key - The preference key
   * @param defaultValue - Fallback if key is absent
   * @returns The stored number or default
   */
  static async getNumber(key: string, defaultValue: number): Promise<number> {
    try {
      const prefs = PreferencesUtil.getPrefs();
      const value = await prefs.get(key, defaultValue);
      return value as number;
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'getNumber failed for key=%{public}s: %{public}s', key, error.message);
      return defaultValue;
    }
  }

  /**
   * Store a boolean value and flush to disk.
   * @param key - The preference key
   * @param value - The boolean value to store
   */
  static async putBoolean(key: string, value: boolean): Promise<void> {
    try {
      const prefs = PreferencesUtil.getPrefs();
      await prefs.put(key, value);
      await prefs.flush();
      Logger.d(MODULE, 'putBoolean key=%{public}s', key);
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'putBoolean failed for key=%{public}s: %{public}s', key, error.message);
    }
  }

  /**
   * Retrieve a boolean value from preferences.
   * @param key - The preference key
   * @param defaultValue - Fallback if key is absent
   * @returns The stored boolean or default
   */
  static async getBoolean(key: string, defaultValue: boolean): Promise<boolean> {
    try {
      const prefs = PreferencesUtil.getPrefs();
      const value = await prefs.get(key, defaultValue);
      return value as boolean;
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'getBoolean failed for key=%{public}s: %{public}s', key, error.message);
      return defaultValue;
    }
  }

  /**
   * Remove a key from preferences and flush.
   * @param key - The preference key to remove
   */
  static async remove(key: string): Promise<void> {
    try {
      const prefs = PreferencesUtil.getPrefs();
      await prefs.delete(key);
      await prefs.flush();
      Logger.d(MODULE, 'remove key=%{public}s', key);
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'remove failed for key=%{public}s: %{public}s', key, error.message);
    }
  }

  /**
   * Clear all preferences data and flush.
   */
  static async clear(): Promise<void> {
    try {
      const prefs = PreferencesUtil.getPrefs();
      await prefs.clear();
      await prefs.flush();
      Logger.i(MODULE, 'All preferences cleared');
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'clear failed: %{public}s', error.message);
    }
  }
}
