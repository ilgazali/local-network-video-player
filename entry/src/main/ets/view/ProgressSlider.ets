// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
// F5: Circular progress slider with seek support for round wearable display

import { PlayerConstants } from '../common/constants/PlayerConstants';
import { Logger } from '../common/utils/Logger';

const MODULE: string = 'ProgressSlider';

/**
 * Circular progress indicator with pan gesture seek for round wearable displays.
 * Displays a ring-shaped progress bar around the video player.
 *
 * Props:
 *   currentMs: current playback position in milliseconds
 *   durationMs: total media duration in milliseconds
 *   onSeek: callback to invoke when user seeks to a new position
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
 */
@Component
export struct ProgressSlider {
  /** Current playback position in ms */
  @Prop currentMs: number = 0;
  /** Total duration in ms */
  @Prop durationMs: number = 0;
  /** Seek callback with target position in ms */
  onSeek: (ms: number) => void = () => {};

  @State private isDragging: boolean = false;
  @State private dragProgress: number = 0;

  /**
   * Calculate progress percentage (0-100).
   */
  private getProgress(): number {
    if (this.durationMs <= 0) {
      return 0;
    }
    if (this.isDragging) {
      return this.dragProgress;
    }
    return Math.round((this.currentMs / this.durationMs) * 100);
  }

  /**
   * Format milliseconds to mm:ss for display.
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
      // Background ring
      Circle()
        .width('100%')
        .height('100%')
        .fill(Color.Transparent)
        .stroke('rgba(255, 248, 220, 0.2)')
        .strokeWidth(PlayerConstants.PROGRESS_STROKE_WIDTH)

      // Progress ring using Progress component
      Progress({
        value: this.getProgress(),
        total: 100,
        type: ProgressType.Ring
      })
        .width('100%')
        .height('100%')
        .color('#FFF8DC')
        .backgroundColor(Color.Transparent)
        .style({
          strokeWidth: PlayerConstants.PROGRESS_STROKE_WIDTH
        })

      // Center time display
      Column() {
        Text(this.formatTime(this.isDragging
          ? (this.dragProgress / 100) * this.durationMs
          : this.currentMs))
          .fontColor('#FFF8DC')
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
      }
    }
    .width(60)
    .height(60)
    // Pan gesture for seeking along the ring
    // Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-gesture-events-pan-gesture
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal })
        .onActionStart(() => {
          this.isDragging = true;
          this.dragProgress = this.getProgress();
        })
        .onActionUpdate((event: GestureEvent) => {
          // Map horizontal pan offset to progress percentage
          const delta = event.offsetX / 200 * 100; // 200px = full range
          this.dragProgress = Math.max(0, Math.min(100, this.dragProgress + delta));
        })
        .onActionEnd(() => {
          this.isDragging = false;
          const seekMs = Math.round((this.dragProgress / 100) * this.durationMs);
          Logger.d(MODULE, 'Seek to %{public}s ms', `${seekMs}`);
          this.onSeek(seekMs);
        })
    )
  }
}
