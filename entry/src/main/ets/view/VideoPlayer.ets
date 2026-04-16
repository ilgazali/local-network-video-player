// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-basic-components-xcomponent
// F2: XComponent-based video renderer with full AVPlayerService integration
// F7: Crown event handling for volume control
// F10: Buffering indicator + error retry

import { AVPlayerService } from '../services/AVPlayerService';
import { PlaybackState } from '../common/types/PlaybackState';
import { VideoSource } from '../common/types/VideoItem';
import { DisplayUtil } from '../common/utils/DisplayUtil';
import { PlayerConstants } from '../common/constants/PlayerConstants';
import { AppConstants } from '../common/constants/AppConstants';
import { Logger } from '../common/utils/Logger';

const MODULE: string = 'VideoPlayerComponent';

/** Crown rotation event shape — DigitalCrownEvent is not exported by the SDK */
interface CrownEvent {
  angularVelocity: number;
}

/**
 * XComponent-based video player component with integrated playback controls.
 * Renders video via AVPlayer surfaceId, shows buffering overlay, error retry,
 * and handles crown events for volume.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-basic-components-xcomponent
 */
@Component
export default struct VideoPlayer {
  /** The video source to play */
  @Prop videoSrc: string | Resource = '';
  /** Optional VideoSource for AVPlayerService loading */
  @Prop videoSource: VideoSource | null = null;
  /** Title of the video for display */
  @Prop videoTitle: string = 'Video';

  @State private playerState: PlaybackState = PlaybackState.IDLE;
  @State private isBuffering: boolean = false;
  @State private hasError: boolean = false;
  @State private errorMessage: string = '';
  @State private retryCount: number = 0;
  @State private currentTimeMs: number = 0;
  @State private durationMs: number = 0;
  @State private showControls: boolean = true;
  @State private volume: number = 1.0;
  @State private showVolumePopup: boolean = false;

  private xComponentController: XComponentController = new XComponentController();
  private playerService: AVPlayerService = AVPlayerService.getInstance();
  private surfaceId: string = '';
  private controlTimer: number = -1;

  /**
   * Register all AVPlayerService callbacks when component appears.
   */
  aboutToAppear(): void {
    DisplayUtil.refresh();
    this.registerPlayerCallbacks();
  }

  /**
   * Release callbacks and clear timers when component is destroyed.
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
   */
  aboutToDisappear(): void {
    this.playerService.clearCallbacks();
    if (this.controlTimer !== -1) {
      clearTimeout(this.controlTimer);
    }
    Logger.i(MODULE, 'Component destroyed, callbacks cleared');
  }

  /**
   * Register all necessary callbacks from AVPlayerService.
   */
  private registerPlayerCallbacks(): void {
    this.playerService.onStateChange((state: PlaybackState) => {
      this.playerState = state;
      if (state === PlaybackState.ERROR) {
        this.hasError = true;
      }
      if (state === PlaybackState.PLAYING) {
        this.hasError = false;
        this.isBuffering = false;
        this.autoHideControls();
      }
    });

    this.playerService.onTimeUpdate((timeMs: number) => {
      this.currentTimeMs = timeMs;
    });

    this.playerService.onDurationUpdate((duration: number) => {
      this.durationMs = duration;
    });

    this.playerService.onBufferingUpdate((buffering: boolean) => {
      this.isBuffering = buffering;
    });

    this.playerService.onError((code: number, message: string) => {
      this.hasError = true;
      this.errorMessage = `Error ${code}: ${message}`;
      Logger.e(MODULE, 'Player error: %{public}s', this.errorMessage);
    });
  }

  /**
   * Load the video source into AVPlayerService after surface is ready.
   */
  private async loadVideo(): Promise<void> {
    if (this.videoSource !== null) {
      await this.playerService.load(this.videoSource);
    } else if (typeof this.videoSrc === 'string' && (this.videoSrc as string).length > 0) {
      const source: VideoSource = { type: 'url', url: this.videoSrc as string };
      await this.playerService.load(source);
    }
  }

  /**
   * Retry loading on error, up to MAX_RETRY_COUNT.
   */
  private async retryLoad(): Promise<void> {
    if (this.retryCount >= AppConstants.MAX_RETRY_COUNT) {
      Logger.w(MODULE, 'Max retries reached');
      return;
    }
    this.retryCount++;
    this.hasError = false;
    this.errorMessage = '';
    Logger.i(MODULE, 'Retry attempt %{public}s', `${this.retryCount}`);
    await this.loadVideo();
  }

  /**
   * Auto-hide controls after a delay when playing.
   */
  private autoHideControls(): void {
    if (this.controlTimer !== -1) {
      clearTimeout(this.controlTimer);
    }
    this.controlTimer = setTimeout(() => {
      if (this.playerState === PlaybackState.PLAYING) {
        this.showControls = false;
      }
    }, 3000) as number;
  }

  /**
   * Format milliseconds to mm:ss display string.
   */
  private formatTime(ms: number): string {
    const totalSeconds = Math.floor(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    const minStr = minutes < 10 ? `0${minutes}` : `${minutes}`;
    const secStr = seconds < 10 ? `0${seconds}` : `${seconds}`;
    return `${minStr}:${secStr}`;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // Video rendering surface
      XComponent({
        id: PlayerConstants.XCOMPONENT_ID,
        type: XComponentType.SURFACE,
        controller: this.xComponentController
      })
        .onLoad(() => {
          this.surfaceId = this.xComponentController.getXComponentSurfaceId();
          this.playerService.setSurfaceId(this.surfaceId);
          Logger.i(MODULE, 'XComponent loaded, surfaceId set');
          this.loadVideo();
        })
        .width('100%')
        .height('100%')
        .borderRadius(35)

      // Buffering overlay (F10)
      if (this.isBuffering) {
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color('#FFF8DC')
          Text('Buffering...')
            .fontColor('#FFF8DC')
            .fontSize(12)
            .margin({ top: 8 })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .borderRadius(35)
      }

      // Error overlay with retry (F10)
      if (this.hasError) {
        Column() {
          Text(this.errorMessage.length > 0 ? this.errorMessage : 'Playback Error')
            .fontColor('#FF6B6B')
            .fontSize(14)
            .textAlign(TextAlign.Center)
            .maxLines(2)
            .padding({ left: 16, right: 16 })

          if (this.retryCount < AppConstants.MAX_RETRY_COUNT) {
            Button('Retry')
              .fontColor('#8B4513')
              .backgroundColor('#FFF8DC')
              .borderRadius(20)
              .margin({ top: 12 })
              .width(80)
              .height(32)
              .onClick(() => {
                this.retryLoad();
              })
          } else {
            Text('Max retries reached')
              .fontColor('#FF6B6B')
              .fontSize(12)
              .margin({ top: 8 })
          }
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.7)')
        .borderRadius(35)
      }

      // Playback controls overlay
      if (this.showControls && !this.hasError && !this.isBuffering) {
        Column() {
          // Time display
          Text(`${this.formatTime(this.currentTimeMs)} / ${this.formatTime(this.durationMs)}`)
            .fontColor('#FFF8DC')
            .fontSize(11)
            .margin({ bottom: 8 })

          // Play/Pause button
          Row({ space: 24 }) {
            // Previous
            Text('⏮')
              .fontSize(22)
              .fontColor('#FFF8DC')
              .onClick(() => {
                this.playerService.previous();
              })

            // Play/Pause toggle
            Text(this.playerState === PlaybackState.PLAYING ? '⏸' : '▶')
              .fontSize(28)
              .fontColor('#FFF8DC')
              .onClick(() => {
                this.playerService.togglePlayPause();
              })

            // Next
            Text('⏭')
              .fontSize(22)
              .fontColor('#FFF8DC')
              .onClick(() => {
                this.playerService.next();
              })
          }
          .justifyContent(FlexAlign.Center)

          // Progress bar
          Row() {
            Progress({
              value: this.durationMs > 0
                ? Math.round((this.currentTimeMs / this.durationMs) * 100)
                : 0,
              total: 100,
              type: ProgressType.Linear
            })
              .width('80%')
              .height(4)
              .color('#FFF8DC')
              .backgroundColor('rgba(255, 248, 220, 0.3)')
              .borderRadius(2)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: 8 })
        }
        .justifyContent(FlexAlign.End)
        .padding({ bottom: 20 })
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.3)')
        .borderRadius(35)
      }

      // Volume popup (F7)
      if (this.showVolumePopup) {
        Column() {
          Text(`Vol: ${Math.round(this.volume * 100)}%`)
            .fontColor('#FFF8DC')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
        }
        .position({ x: '35%', y: '15%' })
        .backgroundColor('rgba(0, 0, 0, 0.7)')
        .borderRadius(12)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      }
    }
    .width(DisplayUtil.getCircularBound(PlayerConstants.PLAYER_SIZE_RATIO))
    .height(DisplayUtil.getCircularBound(PlayerConstants.PLAYER_SIZE_RATIO))
    .borderRadius(35)
    .clip(true)
    .onClick(() => {
      this.showControls = !this.showControls;
      if (this.showControls) {
        this.autoHideControls();
      }
    })
    // Crown event for volume control (F7)
    // Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-common-events-crown-event
    .onDigitalCrown((event: CrownEvent) => {
      if (event.angularVelocity > 0) {
        this.playerService.adjustVolume(PlayerConstants.VOLUME_STEP);
      } else if (event.angularVelocity < 0) {
        this.playerService.adjustVolume(-PlayerConstants.VOLUME_STEP);
      }
      this.volume = this.playerService.getVolume();
      this.showVolumePopup = true;
      setTimeout(() => {
        this.showVolumePopup = false;
      }, PlayerConstants.GESTURE_POPUP_DURATION_MS);
    })
  }
}
