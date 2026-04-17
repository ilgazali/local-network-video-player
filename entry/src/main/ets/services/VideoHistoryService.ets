// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/data-persistence-by-preferences
// F4: Video history and favorites management with Preferences persistence

import { VideoItem, serializeVideoItems, deserializeVideoItems } from '../common/types/VideoItem';
import { AppConstants } from '../common/constants/AppConstants';
import { PreferencesUtil } from '../common/utils/PreferencesUtil';
import { Logger } from '../common/utils/Logger';

const MODULE: string = 'VideoHistoryService';

/**
 * Service managing video playback history and favorites.
 * Persists data via PreferencesUtil (JSON serialized arrays).
 * Enforces FIFO limit of MAX_HISTORY_ITEMS for history.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/data-persistence-by-preferences
 */
export class VideoHistoryService {
  private static instance: VideoHistoryService | null = null;
  private historyItems: VideoItem[] = [];
  private favoriteItems: VideoItem[] = [];

  private constructor() {
  }

  /**
   * Get the singleton instance.
   * @returns The shared VideoHistoryService instance
   */
  static getInstance(): VideoHistoryService {
    if (VideoHistoryService.instance === null) {
      VideoHistoryService.instance = new VideoHistoryService();
    }
    return VideoHistoryService.instance;
  }

  /**
   * Load history and favorites from Preferences.
   * Call once at app startup after PreferencesUtil.init().
   */
  async loadFromPreferences(): Promise<void> {
    try {
      const historyJson = await PreferencesUtil.getString(AppConstants.KEY_HISTORY, '[]');
      this.historyItems = deserializeVideoItems(historyJson);

      const favoritesJson = await PreferencesUtil.getString(AppConstants.KEY_FAVORITES, '[]');
      this.favoriteItems = deserializeVideoItems(favoritesJson);

      Logger.i(MODULE, 'Loaded %{public}s history, %{public}s favorites',
        `${this.historyItems.length}`, `${this.favoriteItems.length}`);
    } catch (err) {
      Logger.e(MODULE, 'Failed to load from preferences');
      this.historyItems = [];
      this.favoriteItems = [];
    }
  }

  /**
   * Save current history to Preferences.
   */
  private async saveHistory(): Promise<void> {
    const json = serializeVideoItems(this.historyItems);
    await PreferencesUtil.putString(AppConstants.KEY_HISTORY, json);
  }

  /**
   * Save current favorites to Preferences.
   */
  private async saveFavorites(): Promise<void> {
    const json = serializeVideoItems(this.favoriteItems);
    await PreferencesUtil.putString(AppConstants.KEY_FAVORITES, json);
  }

  /**
   * Add or update a video in the playback history.
   * If the item already exists (by id), update its lastPlayedAt and position.
   * Enforces FIFO limit of MAX_HISTORY_ITEMS.
   * @param item - The video item to add/update
   */
  async addToHistory(item: VideoItem): Promise<void> {
    // Remove existing entry if present (will re-add at top)
    this.historyItems = this.historyItems.filter(
      (existing: VideoItem) => existing.id !== item.id
    );

    // Add to front (most recent first)
    item.lastPlayedAt = Date.now();
    this.historyItems.unshift(item);

    // Enforce FIFO limit
    if (this.historyItems.length > AppConstants.MAX_HISTORY_ITEMS) {
      this.historyItems = this.historyItems.slice(0, AppConstants.MAX_HISTORY_ITEMS);
    }

    await this.saveHistory();
    Logger.d(MODULE, 'Added to history: %{public}s (total: %{public}s)',
      item.title, `${this.historyItems.length}`);
  }

  /**
   * Remove a video from history by its ID.
   * @param id - The video item ID to remove
   */
  async removeFromHistory(id: string): Promise<void> {
    this.historyItems = this.historyItems.filter(
      (item: VideoItem) => item.id !== id
    );
    await this.saveHistory();
    Logger.d(MODULE, 'Removed from history: %{public}s', id);
  }

  /**
   * Clear all playback history.
   */
  async clearHistory(): Promise<void> {
    this.historyItems = [];
    await this.saveHistory();
    Logger.i(MODULE, 'History cleared');
  }

  /**
   * Get all history items, most recent first.
   * @returns Array of VideoItem in reverse chronological order
   */
  getHistory(): VideoItem[] {
    return this.historyItems;
  }

  /**
   * Toggle favorite status for a video item.
   * @param item - The video item to toggle
   * @returns true if the item is now a favorite
   */
  async toggleFavorite(item: VideoItem): Promise<boolean> {
    const existingIndex = this.favoriteItems.findIndex(
      (fav: VideoItem) => fav.id === item.id
    );

    if (existingIndex >= 0) {
      // Remove — filter creates a new array so ArkUI @State detects the reference change
      item.isFavorite = false;
      this.favoriteItems = this.favoriteItems.filter(
        (fav: VideoItem) => fav.id !== item.id
      );
      await this.saveFavorites();
      Logger.d(MODULE, 'Removed from favorites: %{public}s', item.title);
      return false;
    } else {
      // Add — slice + unshift creates a new array so ArkUI @State detects the reference change
      item.isFavorite = true;
      const newFavs: VideoItem[] = this.favoriteItems.slice();
      newFavs.unshift(item);
      this.favoriteItems = newFavs;
      await this.saveFavorites();
      Logger.d(MODULE, 'Added to favorites: %{public}s', item.title);
      return true;
    }
  }

  /**
   * Check if a video is in favorites.
   * @param id - The video item ID
   * @returns true if the item is a favorite
   */
  isFavorite(id: string): boolean {
    return this.favoriteItems.some((fav: VideoItem) => fav.id === id);
  }

  /**
   * Remove a video from favorites by its ID.
   * @param id - The video item ID
   */
  async removeFromFavorites(id: string): Promise<void> {
    this.favoriteItems = this.favoriteItems.filter(
      (item: VideoItem) => item.id !== id
    );
    await this.saveFavorites();
    Logger.d(MODULE, 'Removed from favorites: %{public}s', id);
  }

  /**
   * Get all favorite items.
   * @returns Array of favorite VideoItem
   */
  getFavorites(): VideoItem[] {
    return this.favoriteItems;
  }

  /**
   * Update the last playback position for a history item.
   * @param id - The video item ID
   * @param positionMs - Current position in milliseconds
   */
  async updatePosition(id: string, positionMs: number): Promise<void> {
    const item = this.historyItems.find((v: VideoItem) => v.id === id);
    if (item !== undefined) {
      item.lastPositionMs = positionMs;
      await this.saveHistory();
    }
  }

  /** Get history count */
  getHistoryCount(): number {
    return this.historyItems.length;
  }

  /** Get favorites count */
  getFavoritesCount(): number {
    return this.favoriteItems.length;
  }
}
