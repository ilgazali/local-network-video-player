import { ArcList, ArcListItem, ComponentContent } from '@kit.ArkUI';
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
import { AppConstants } from '../common/constants/AppConstants';
import { Logger } from '../common/utils/Logger';

const MODULE: string = 'LocalVideoPlayer';

/** Built-in rawfile video entries */
interface RawVideoEntry {
  title: string;
  rawfileName: string;
}

/**
 * Standalone @Builder for ArcList header — wrapBuilder requires a non-method function.
 */
@Builder
function localVideosHeader() {
  Text('Local Videos')
    .fontSize(18)
    .fontWeight(FontWeight.Bold)
    .fontColor('#FFF8DC')
    .textAlign(TextAlign.Center)
    .margin({ top: 10, bottom: 8 })
}

/**
 * Local video player page.
 * Provides a built-in rawfile video browser and optional file picker.
 * Integrates with AVPlayerService (singleton), VideoHistoryService, and BackgroundUtil.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
 */
@Component
export struct LocalVideoPlayer {
  @Consume('pathStack') pathStack: NavPathStack;
  // playerModeActive controls player vs. browse view.
  // Driven only by playRawfile(), NOT by AVPlayer state transitions — this prevents
  // VideoPlayer.ets from disappearing (and calling clearCallbacks()) during the IDLE
  // state that occurs between videos when load() calls reset() internally.
  @State private playerModeActive: boolean = false;
  @State private playerState: PlaybackState = PlaybackState.IDLE;
  @State private currentSource: VideoSource | null = null;
  @State private currentTitle: string = '';
  @State private isFavorite: boolean = false;

  private playerService: AVPlayerService = AVPlayerService.getInstance();
  private historyService: VideoHistoryService = VideoHistoryService.getInstance();
  private currentVideoItem: VideoItem | null = null;

  /** Bundled rawfile videos available offline */
  private rawVideos: RawVideoEntry[] = [
    { title: 'Huawei Video 1', rawfileName: 'huawei_video_1.mp4' },
    { title: 'Huawei Video 2', rawfileName: 'huawei_video_2.mp4' },
    { title: 'Huawei Video 3', rawfileName: 'huawei_video_3.mp4' },
    { title: 'Huawei Video 4', rawfileName: 'huawei_video_4.mp4' }
  ];

  async aboutToAppear(): Promise<void> {
    DisplayUtil.refresh();
    this.registerCallbacks();
    Logger.i(MODULE, 'LocalVideoPlayer appeared');
  }

  /**
   * Release AVPlayer callbacks and stop background task on exit.
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
   */
  aboutToDisappear(): void {
    this.playerService.clearCallbacks();
    const ctx = getContext(this);
    BackgroundUtil.stopOnStopOrPause(ctx);
    Logger.i(MODULE, 'LocalVideoPlayer disappeared, callbacks cleared');
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

    // Saves to history and refreshes currentVideoItem / isFavorite for every video.
    this.playerService.onDurationUpdate(async (durationMs: number) => {
      if (this.currentSource !== null) {
        const videoId = `local_${this.currentTitle}`;
        const item: VideoItem = {
          id: videoId,
          title: this.currentTitle,
          source: this.currentSource,
          durationMs: durationMs,
          lastPositionMs: 0,
          lastPlayedAt: Date.now(),
          isFavorite: this.historyService.isFavorite(videoId)
        };
        this.currentVideoItem = item;
        this.isFavorite = item.isFavorite;
        await this.historyService.addToHistory(item);
        Logger.i(MODULE, 'Saved to history: %{public}s', videoId);
      }
    });
  }

  /**
   * Load and play a rawfile video.
   * Sets playerModeActive to keep VideoPlayer.ets mounted across all subsequent
   * AVPlayer state transitions (including the IDLE reset between videos).
   * @param entry - The rawfile video entry to play
   */
  private async playRawfile(entry: RawVideoEntry): Promise<void> {
    const source: VideoSource = { type: 'rawfile', rawfileName: entry.rawfileName };
    const videoId = `local_${entry.title}`;
    this.currentSource = source;
    this.currentTitle = entry.title;
    // Create item immediately so ♥ button works before onDurationUpdate fires
    this.currentVideoItem = {
      id: videoId,
      title: entry.title,
      source: source,
      durationMs: 0,
      lastPositionMs: 0,
      lastPlayedAt: Date.now(),
      isFavorite: this.historyService.isFavorite(videoId)
    };
    this.isFavorite = this.currentVideoItem.isFavorite;
    await this.historyService.addToHistory(this.currentVideoItem);
    // Activate player view before load so VideoPlayer.ets mounts once and stays mounted.
    this.playerModeActive = true;
    await this.playerService.load(source);
    Logger.i(MODULE, 'Playing rawfile: %{public}s', entry.rawfileName);
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        if (this.playerModeActive) {
          // Player view — stays mounted for all AVPlayer state transitions
          Column() {
            Stack({ alignContent: Alignment.Center }) {
              VideoPlayerComponent({
                videoSource: this.currentSource,
                videoTitle: this.currentTitle
              })

              // Brightness/Volume gesture overlays — left/right halves (F6)
              Row() {
                BrightnessGesture()
                VolumeGesture()
              }
              .width('100%')
              .height('100%')
              .hitTestBehavior(HitTestMode.Transparent)

              // Favorites toggle — top-right corner
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
          // Browse state: rawfile list
          Column() {
            // Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arclist-N
            ArcList({ header: new ComponentContent(this.getUIContext(), wrapBuilder(localVideosHeader)) }) {
              ForEach(this.rawVideos, (entry: RawVideoEntry) => {
                ArcListItem() {
                  Row({ space: 10 }) {
                    Image($r('app.media.file'))
                      .fillColor('#8B4513')
                      .width(24)
                      .height(24)
                    Text(entry.title)
                      .fontColor('#8B4513')
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .layoutWeight(1)
                  }
                  .alignItems(VerticalAlign.Center)
                  .backgroundColor('#FFF8DC')
                  .borderRadius(24)
                  .padding({ top: 10, bottom: 10, left: 14, right: 14 })
                  .margin({ top: 4, bottom: 4, left: 10, right: 10 })
                  .onClick(() => {
                    this.playRawfile(entry);
                  })
                }
              })

            }
          }
          .width(AppConstants.WATCH_SIZE)
          .height(AppConstants.WATCH_SIZE)
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
