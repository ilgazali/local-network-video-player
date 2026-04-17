/**
 * Represents a video source type for AVPlayer loading.
 */
export type VideoSourceType = 'url' | 'fd' | 'rawfile';

/**
 * Describes a video source that AVPlayerService can load.
 */
export interface VideoSource {
  /** Source type: url for network, fd for file descriptor, rawfile for bundled assets */
  type: VideoSourceType;
  /** Network URL (when type is 'url') */
  url?: string;
  /** File descriptor (when type is 'fd') */
  fd?: number;
  /** File offset in bytes (when type is 'fd') */
  offset?: number;
  /** File length in bytes (when type is 'fd') */
  length?: number;
  /** Raw file name under resources/rawfile (when type is 'rawfile') */
  rawfileName?: string;
}

/**
 * Model representing a video item for history, favorites, and playlist.
 */
export interface VideoItem {
  /** Unique identifier (timestamp-based) */
  id: string;
  /** Display title of the video */
  title: string;
  /** Source information for playback */
  source: VideoSource;
  /** Duration in milliseconds (0 if unknown) */
  durationMs: number;
  /** Last playback position in milliseconds */
  lastPositionMs: number;
  /** Timestamp when this item was last played */
  lastPlayedAt: number;
  /** Whether this item is marked as favorite */
  isFavorite: boolean;
}

/**
 * Serializable version of VideoItem for Preferences storage.
 * Preferences only supports string/number/boolean, so we serialize to JSON string.
 */
export function serializeVideoItem(item: VideoItem): string {
  return JSON.stringify(item);
}

/**
 * Deserialize a VideoItem from JSON string stored in Preferences.
 */
export function deserializeVideoItem(json: string): VideoItem {
  const parsed = JSON.parse(json) as VideoItem;
  return parsed;
}

/**
 * Deserialize an array of VideoItems from JSON string.
 */
export function deserializeVideoItems(json: string): VideoItem[] {
  if (json.length === 0) {
    return [];
  }
  const parsed = JSON.parse(json) as VideoItem[];
  return parsed;
}

/**
 * Serialize an array of VideoItems to JSON string.
 */
export function serializeVideoItems(items: VideoItem[]): string {
  return JSON.stringify(items);
}
