import { AVPlayerService } from '../services/AVPlayerService';
import { PlayerConstants } from '../common/constants/PlayerConstants';
import { Logger } from '../common/utils/Logger';

const MODULE: string = 'VolumeGesture';

/**
 * Invisible overlay for the right half of the video player.
 * Vertical pan gesture adjusts audio volume via AVPlayerService.
 * Shows a brief popup with current volume level.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-gesture-events-pan-gesture
 */
@Component
export struct VolumeGesture {
  @State private volume: number = 100;
  @State private showPopup: boolean = false;
  private popupTimer: number = -1;
  private playerService: AVPlayerService = AVPlayerService.getInstance();

  aboutToAppear(): void {
    this.volume = Math.round(this.playerService.getVolume() * 100);
  }

  aboutToDisappear(): void {
    if (this.popupTimer !== -1) {
      clearTimeout(this.popupTimer);
    }
  }

  /**
   * Show feedback popup briefly.
   */
  private showFeedback(): void {
    this.showPopup = true;
    if (this.popupTimer !== -1) {
      clearTimeout(this.popupTimer);
    }
    this.popupTimer = setTimeout(() => {
      this.showPopup = false;
    }, PlayerConstants.GESTURE_POPUP_DURATION_MS) as number;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // Invisible gesture area (right half)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .gesture(
          PanGesture({ direction: PanDirection.Vertical })
            .onActionUpdate((event: GestureEvent) => {
              // Swipe up = increase, swipe down = decrease
              const delta = -event.offsetY / 300; // Normalize to 0-1 range
              this.playerService.adjustVolume(delta);
              this.volume = Math.round(this.playerService.getVolume() * 100);
              this.showFeedback();
              Logger.d(MODULE, 'Volume adjusted to %{public}s%%', `${this.volume}`);
            })
        )

      // Volume feedback popup
      if (this.showPopup) {
        Column() {
          Text('🔊')
            .fontSize(18)
            .fontColor('#FFF8DC')
          Text(`${this.volume}%`)
            .fontColor('#FFF8DC')
            .fontSize(12)
        }
        .backgroundColor('rgba(0, 0, 0, 0.7)')
        .borderRadius(12)
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      }
    }
    .width('50%')
    .height('100%')
  }
}
