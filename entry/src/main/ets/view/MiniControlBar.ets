// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
// F5: Mini control bar for round screen
// F11: Playback speed control

import { media } from '@kit.MediaKit';
import { AVPlayerService } from '../services/AVPlayerService';
import { PlaybackState, LoopMode } from '../common/types/PlaybackState';
import { SpeedValue } from '../common/types/SettingsModel';
import { PlayerConstants } from '../common/constants/PlayerConstants';
import { PreferencesUtil } from '../common/utils/PreferencesUtil';
import { AppConstants } from '../common/constants/AppConstants';
import { Logger } from '../common/utils/Logger';

const MODULE: string = 'MiniControlBar';

/**
 * Compact control bar for the round wearable display.
 * Provides play/pause, previous/next, speed, and loop mode controls.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
 */
@Component
export struct MiniControlBar {
  @Prop playerState: PlaybackState = PlaybackState.IDLE;
  @State private showSpeedSheet: boolean = false;
  @State private currentSpeedIndex: number = 1;
  @State private currentLoopMode: LoopMode = LoopMode.OFF;

  private playerService: AVPlayerService = AVPlayerService.getInstance();

  aboutToAppear(): void {
    this.loadSettings();
  }

  /**
   * Load persisted speed and loop settings.
   */
  private async loadSettings(): Promise<void> {
    this.currentSpeedIndex = await PreferencesUtil.getNumber(AppConstants.KEY_SPEED, SpeedValue.SPEED_1_0);
    const loopStr = await PreferencesUtil.getString(AppConstants.KEY_LOOP, LoopMode.OFF);
    this.currentLoopMode = loopStr as LoopMode;
  }

  /**
   * Cycle through available playback speeds.
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/video-playback
   */
  private cycleSpeed(): void {
    this.currentSpeedIndex = (this.currentSpeedIndex + 1) % PlayerConstants.SPEED_LABELS.length;
    const speedMap: media.PlaybackSpeed[] = [
      media.PlaybackSpeed.SPEED_FORWARD_0_50_X,
      media.PlaybackSpeed.SPEED_FORWARD_1_00_X,
      media.PlaybackSpeed.SPEED_FORWARD_1_50_X,
      media.PlaybackSpeed.SPEED_FORWARD_2_00_X
    ];
    this.playerService.setSpeed(speedMap[this.currentSpeedIndex]);
    PreferencesUtil.putNumber(AppConstants.KEY_SPEED, this.currentSpeedIndex);
    Logger.i(MODULE, 'Speed changed to %{public}s',
      PlayerConstants.SPEED_LABELS[this.currentSpeedIndex]);
  }

  /**
   * Cycle through loop modes: OFF → ONE → ALL → OFF.
   */
  private cycleLoopMode(): void {
    switch (this.currentLoopMode) {
      case LoopMode.OFF:
        this.currentLoopMode = LoopMode.ONE;
        break;
      case LoopMode.ONE:
        this.currentLoopMode = LoopMode.ALL;
        break;
      case LoopMode.ALL:
        this.currentLoopMode = LoopMode.OFF;
        break;
    }
    this.playerService.loopMode = this.currentLoopMode;
    PreferencesUtil.putString(AppConstants.KEY_LOOP, this.currentLoopMode);
    Logger.i(MODULE, 'Loop mode: %{public}s', this.currentLoopMode);
  }

  /**
   * Get loop mode display icon.
   */
  private getLoopIcon(): string {
    switch (this.currentLoopMode) {
      case LoopMode.ONE:
        return '🔂';
      case LoopMode.ALL:
        return '🔁';
      default:
        return '➡';
    }
  }

  build() {
    Row({ space: 8 }) {
      // Loop mode toggle (F12)
      Text(this.getLoopIcon())
        .fontSize(16)
        .fontColor('#FFF8DC')
        .onClick(() => {
          this.cycleLoopMode();
        })

      // Previous track
      Text('⏮')
        .fontSize(18)
        .fontColor('#FFF8DC')
        .onClick(() => {
          this.playerService.previous();
        })

      // Play/Pause
      Text(this.playerState === PlaybackState.PLAYING ? '⏸' : '▶')
        .fontSize(22)
        .fontColor('#FFF8DC')
        .fontWeight(FontWeight.Bold)
        .onClick(() => {
          this.playerService.togglePlayPause();
        })

      // Next track
      Text('⏭')
        .fontSize(18)
        .fontColor('#FFF8DC')
        .onClick(() => {
          this.playerService.next();
        })

      // Speed control (F11)
      Text(PlayerConstants.SPEED_LABELS[this.currentSpeedIndex])
        .fontSize(12)
        .fontColor('#FFF8DC')
        .backgroundColor('rgba(255, 248, 220, 0.2)')
        .borderRadius(10)
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .onClick(() => {
          this.cycleSpeed();
        })
    }
    .width('90%')
    .height(PlayerConstants.CONTROL_BAR_HEIGHT)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor('rgba(139, 69, 19, 0.6)')
    .borderRadius(24)
    .padding({ left: 12, right: 12 })
  }
}
