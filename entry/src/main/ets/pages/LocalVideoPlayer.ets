// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arclist-N
// F2: XComponent-based player  F13: Local file picker/rawfile browser

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
  @State private isPlaying: boolean = false;
  @State private playerState: PlaybackState = PlaybackState.IDLE;
  @State private currentSource: VideoSource | null = null;
  @State private currentTitle: string = '';
  @State private pickerUnsupportedVisible: boolean = false;

  private playerService: AVPlayerService = AVPlayerService.getInstance();
  private historyService: VideoHistoryService = VideoHistoryService.getInstance();

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
      this.isPlaying = state === PlaybackState.PLAYING;

      const ctx = getContext(this);
      if (state === PlaybackState.PLAYING) {
        BackgroundUtil.startOnPlay(ctx);
      } else if (state === PlaybackState.PAUSED || state === PlaybackState.STOPPED) {
        BackgroundUtil.stopOnStopOrPause(ctx);
      }
    });

    this.playerService.onDurationUpdate(async (durationMs: number) => {
      if (this.currentSource !== null) {
        const item: VideoItem = {
          id: `local_${this.currentTitle}`,
          title: this.currentTitle,
          source: this.currentSource,
          durationMs: durationMs,
          lastPositionMs: 0,
          lastPlayedAt: Date.now(),
          isFavorite: false
        };
        await this.historyService.addToHistory(item);
      }
    });
  }

  /**
   * Load and play a rawfile video.
   * @param entry - The rawfile video entry to play
   */
  private async playRawfile(entry: RawVideoEntry): Promise<void> {
    const source: VideoSource = { type: 'rawfile', rawfileName: entry.rawfileName };
    this.currentSource = source;
    this.currentTitle = entry.title;
    await this.playerService.load(source);
    this.isPlaying = true;
    Logger.i(MODULE, 'Playing rawfile: %{public}s', entry.rawfileName);
  }

  /**
   * File picker is not available on wearable devices.
   * SystemCapability.FileManagement.UserFileService is not included
   * in the default wearable system capabilities.
   * Rawfile browser above is the primary local file source on Watch 5.
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/syscap
   */
  private showPickerUnsupported(): void {
    Logger.w(MODULE, 'File picker not supported on wearable — use rawfile browser');
    this.pickerUnsupportedVisible = true;
    setTimeout(() => {
      this.pickerUnsupportedVisible = false;
    }, 2500);
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        if (this.isPlaying || this.playerState === PlaybackState.PREPARED ||
            this.playerState === PlaybackState.PAUSED) {
          // Playing state: show XComponent player
          Column() {
            Stack({ alignContent: Alignment.Center }) {
              VideoPlayerComponent({
                videoSource: this.currentSource,
                videoTitle: this.currentTitle
              })

              // Brightness gesture — left half (F6)
              Row() {
                BrightnessGesture()
                VolumeGesture()
              }
              .width('100%')
              .height('100%')
              .hitTestBehavior(HitTestMode.Transparent)
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

              // Browse Files — not available on wearable (no UserFileService capability)
              ArcListItem() {
                Row({ space: 10 }) {
                  Image($r('app.media.search'))
                    .fillColor(this.pickerUnsupportedVisible ? '#CC3333' : '#A0A0A0')
                    .width(24)
                    .height(24)
                  Text(this.pickerUnsupportedVisible ? 'Not on Watch' : 'Browse Files')
                    .fontColor(this.pickerUnsupportedVisible ? '#CC3333' : '#A0A0A0')
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                }
                .alignItems(VerticalAlign.Center)
                .backgroundColor('#FFF8DC')
                .borderRadius(24)
                .padding({ top: 10, bottom: 10, left: 14, right: 14 })
                .margin({ top: 4, bottom: 4, left: 10, right: 10 })
                .opacity(0.6)
                .onClick(() => {
                  this.showPickerUnsupported();
                })
              }
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
