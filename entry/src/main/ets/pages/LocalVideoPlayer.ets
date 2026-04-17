import { ArcList, ArcListItem, ComponentContent } from '@kit.ArkUI';
import { AVPlayerService } from '../services/AVPlayerService';
import { VideoHistoryService } from '../services/VideoHistoryService';
import { BackgroundUtil } from '../common/utils/BackgroundUtil';
import { VideoSource, VideoItem } from '../common/types/VideoItem';
import { PlaybackState } from '../common/types/PlaybackState';
import VideoPlayerComponent from '../view/VideoPlayer';
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
    BackgroundUtil.stopOnStopOrPause(this.getUIContext().getHostContext()!);
    Logger.i(MODULE, 'LocalVideoPlayer disappeared, callbacks cleared');
  }

  private registerCallbacks(): void {
    this.playerService.onStateChange((state: PlaybackState) => {
      this.playerState = state;

      const ctx = this.getUIContext().getHostContext()!;
      if (state === PlaybackState.PLAYING) {
        BackgroundUtil.startOnPlay(ctx);
      } else if (state === PlaybackState.PAUSED || state === PlaybackState.STOPPED) {
        BackgroundUtil.stopOnStopOrPause(ctx);
      }
    });

    // Updates duration in the history record once AVPlayer reports it.
    this.playerService.onDurationUpdate(async (durationMs: number) => {
      if (this.currentVideoItem !== null) {
        this.currentVideoItem.durationMs = durationMs;
        await this.historyService.addToHistory(this.currentVideoItem);
      }
    });

    // Fired by next()/previous() — update page state to match the new track.
    this.playerService.onPlaylistNavigate(async (item: VideoItem) => {
      this.currentSource = item.source;
      this.currentTitle = item.title;
      this.currentVideoItem = item;
      this.isFavorite = this.historyService.isFavorite(item.id);
      await this.historyService.addToHistory(item);
      Logger.i(MODULE, 'Playlist navigated to: %{public}s', item.title);
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

    // Build playlist from all rawVideos so next()/previous() work.
    const playlist: VideoItem[] = this.rawVideos.map((e: RawVideoEntry) => {
      const id = `local_${e.title}`;
      return {
        id: id,
        title: e.title,
        source: { type: 'rawfile', rawfileName: e.rawfileName } as VideoSource,
        durationMs: 0,
        lastPositionMs: 0,
        lastPlayedAt: 0,
        isFavorite: this.historyService.isFavorite(id)
      } as VideoItem;
    });
    const selectedIndex = this.rawVideos.findIndex((e: RawVideoEntry) => e.rawfileName === entry.rawfileName);
    this.playerService.setPlaylist(playlist, selectedIndex);

    // Activate player view before load so VideoPlayer.ets mounts once and stays mounted.
    this.playerModeActive = true;
    await this.playerService.load(source);
    Logger.i(MODULE, 'Playing rawfile: %{public}s (index %{public}s/%{public}s)',
      entry.rawfileName, `${selectedIndex}`, `${playlist.length}`);
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
                .position({ x: '62%', y: '10%' })
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
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .layoutWeight(1)
                    Blank()
                      .width(24)
                      .height(24)
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
