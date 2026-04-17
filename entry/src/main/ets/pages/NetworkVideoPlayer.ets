// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/streaming-media-playback-development-guide
// F2: XComponent-based player  F3: Persistent last URL  F10: Buffering + retry

import { AVPlayerService } from '../services/AVPlayerService';
import { VideoHistoryService } from '../services/VideoHistoryService';
import { BackgroundUtil } from '../common/utils/BackgroundUtil';
import { VideoSource, VideoItem } from '../common/types/VideoItem';
import { PlaybackState } from '../common/types/PlaybackState';
import VideoPlayerComponent from '../view/VideoPlayer';
import { MiniControlBar } from '../view/MiniControlBar';
import { BrightnessGesture } from '../view/BrightnessGesture';
import { VolumeGesture } from '../view/VolumeGesture';
import { DisplayUtil } from '../common/utils/DisplayUtil';
import { PreferencesUtil } from '../common/utils/PreferencesUtil';
import { AppConstants } from '../common/constants/AppConstants';
import { Logger } from '../common/utils/Logger';

const MODULE: string = 'NetworkVideoPlayer';

/**
 * Network video player page.
 * Provides URL input with last-URL restore, streaming playback via AVPlayerService,
 * and integrates buffering, gesture controls, and background playback.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/streaming-media-playback-development-guide
 */
@Component
export struct NetworkVideoPlayer {
  @Consume('pathStack') pathStack: NavPathStack;
  @State private videoUrl: string = 'https://avtshare01.rz.tu-ilmenau.de/avt-vqdb-uhd-1/test_1/segments/bigbuck_bunny_8bit_200kbps_360p_60.0fps_h264.mp4';
  @State private showPlayer: boolean = false;
  @State private playerState: PlaybackState = PlaybackState.IDLE;
  @State private isLoading: boolean = true;
  @State private currentSource: VideoSource | null = null;
  @State private isFavorite: boolean = false;

  private playerService: AVPlayerService = AVPlayerService.getInstance();
  private historyService: VideoHistoryService = VideoHistoryService.getInstance();
  private currentVideoItem: VideoItem | null = null;

  async aboutToAppear(): Promise<void> {
    DisplayUtil.refresh();
    // F3: Restore last URL from Preferences
    const lastUrl = await PreferencesUtil.getString(AppConstants.KEY_LAST_URL, '');
    if (lastUrl.length > 0) {
      this.videoUrl = lastUrl;
      Logger.i(MODULE, 'Restored last URL: %{public}s', lastUrl);
    }
    this.isLoading = false;
    this.registerCallbacks();
  }

  /**
   * Release AVPlayer callbacks and stop background task on page exit.
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
   */
  aboutToDisappear(): void {
    this.playerService.clearCallbacks();
    const ctx = getContext(this);
    BackgroundUtil.stopOnStopOrPause(ctx);
    Logger.i(MODULE, 'NetworkVideoPlayer disappeared');
  }

  private registerCallbacks(): void {
    this.playerService.onStateChange((state: PlaybackState) => {
      this.playerState = state;

      const ctx = getContext(this);
      if (state === PlaybackState.PLAYING) {
        BackgroundUtil.startOnPlay(ctx);
      } else if (state === PlaybackState.PAUSED || state === PlaybackState.STOPPED) {
        BackgroundUtil.stopOnStopOrPause(ctx);
      }
    });

    this.playerService.onDurationUpdate(async (durationMs: number) => {
      if (this.currentSource !== null) {
        const videoId = `net_${this.videoUrl.trim()}`;
        const item: VideoItem = {
          id: videoId,
          title: this.extractTitle(this.videoUrl),
          source: this.currentSource,
          durationMs: durationMs,
          lastPositionMs: 0,
          lastPlayedAt: Date.now(),
          isFavorite: this.historyService.isFavorite(videoId)
        };
        this.currentVideoItem = item;
        this.isFavorite = item.isFavorite;
        await this.historyService.addToHistory(item);
        Logger.d(MODULE, 'Added to history: %{public}s', item.title);
      }
    });
  }

  /**
   * Extract a display title from a URL.
   * @param url - The video URL
   * @returns A human-readable title string
   */
  private extractTitle(url: string): string {
    const parts = url.split('/');
    const lastPart = parts[parts.length - 1];
    if (lastPart.length > 0) {
      return lastPart.split('?')[0];
    }
    const host = url.replace('https://', '').replace('http://', '').split('/')[0];
    return host.length > 0 ? host : 'Network Video';
  }

  /**
   * Start streaming from the entered URL.
   * Persists the URL to Preferences for next session.
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/streaming-media-playback-development-guide
   */
  private async startPlayback(): Promise<void> {
    const trimmedUrl = this.videoUrl.trim();
    if (trimmedUrl.length === 0) {
      return;
    }
    // F3: Save last URL
    await PreferencesUtil.putString(AppConstants.KEY_LAST_URL, trimmedUrl);

    const source: VideoSource = { type: 'url', url: trimmedUrl };
    this.currentSource = source;
    const videoId = `net_${trimmedUrl}`;
    const initialItem: VideoItem = {
      id: videoId,
      title: this.extractTitle(trimmedUrl),
      source: source,
      durationMs: 0,
      lastPositionMs: 0,
      lastPlayedAt: Date.now(),
      isFavorite: this.historyService.isFavorite(videoId)
    };
    this.currentVideoItem = initialItem;
    this.isFavorite = initialItem.isFavorite;
    await this.historyService.addToHistory(initialItem);
    this.showPlayer = true;
    await this.playerService.load(source);
    Logger.i(MODULE, 'Starting network stream: %{public}s', trimmedUrl);
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        if (this.showPlayer) {
          // Playing state
          Column() {
            Stack({ alignContent: Alignment.Center }) {
              VideoPlayerComponent({
                videoSource: this.currentSource,
                videoTitle: this.extractTitle(this.videoUrl)
              })

              // Gesture overlays (F6)
              Row() {
                BrightnessGesture()
                VolumeGesture()
              }
              .width('100%')
              .height('100%')
              .hitTestBehavior(HitTestMode.Transparent)

              // Favorites toggle — top-right corner overlay
              Text(this.isFavorite ? '♥' : '♡')
                .fontSize(20)
                .fontColor(this.isFavorite ? '#FF4444' : '#FFFFFF')
                .backgroundColor('rgba(0, 0, 0, 0.5)')
                .borderRadius(14)
                .padding({ left: 6, right: 6, top: 3, bottom: 3 })
                .position({ x: '73%', y: '5%' })
                .onClick(async () => {
                  if (this.currentVideoItem !== null) {
                    this.isFavorite = await this.historyService.toggleFavorite(this.currentVideoItem);
                    Logger.i(MODULE, 'Favorite toggled: %{public}s → %{public}s',
                      this.currentVideoItem.title, `${this.isFavorite}`);
                  }
                })
            }
            .width(AppConstants.WATCH_SIZE)
            .height('calc(100% - 56px)')

            MiniControlBar({ playerState: this.playerState })
          }
          .width(AppConstants.WATCH_SIZE)
          .height(AppConstants.WATCH_SIZE)
          .backgroundColor('#000000')
        } else {
          // URL input state
          Column({ space: 12 }) {
            Text('Stream Video')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFF8DC')
              .margin({ top: 60, bottom: 4 })

            TextInput({
              placeholder: 'Enter video URL...',
              text: this.videoUrl
            })
              .fontColor('#8B4513')
              .placeholderColor('#A0522D')
              .backgroundColor('#FFF8DC')
              .borderRadius(20)
              .padding({ left: 14, right: 14, top: 10, bottom: 10 })
              .width('80%')
              .fontSize(12)
              .onChange((value: string) => {
                this.videoUrl = value;
              })

            Button('Play')
              .fontColor('#FFF8DC')
              .backgroundColor('#8B4513')
              .borderRadius(20)
              .width(100)
              .height(36)
              .fontSize(14)
              .onClick(() => {
                this.startPlayback();
              })

            if (this.videoUrl.length > 0) {
              Text('Tap Play to stream')
                .fontSize(11)
                .fontColor('#FFF8DC')
                .opacity(0.7)
            }
          }
          .width(AppConstants.WATCH_SIZE)
          .height(AppConstants.WATCH_SIZE)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#8B4513')
        }
      }
      .width(AppConstants.WATCH_SIZE)
      .height(AppConstants.WATCH_SIZE)
    }
    .hideTitleBar(true)
    .hideBackButton(true)
  }
}
