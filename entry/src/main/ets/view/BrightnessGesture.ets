import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { PlayerConstants } from '../common/constants/PlayerConstants';
import { Logger } from '../common/utils/Logger';

const MODULE: string = 'BrightnessGesture';

/**
 * Invisible overlay for the left half of the video player.
 * Vertical pan gesture adjusts screen brightness.
 * Shows a brief popup with current brightness level.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-gesture-events-pan-gesture
 */
@Component
export struct BrightnessGesture {
  @State private brightnessLevel: number = 128;
  @State private showPopup: boolean = false;
  private popupTimer: number = -1;

  aboutToDisappear(): void {
    if (this.popupTimer !== -1) {
      clearTimeout(this.popupTimer);
    }
  }

  /**
   * Apply brightness to the current window.
   * @param value - Brightness value 0-255
   */
  private applyBrightness(value: number): void {
    try {
      const windowStage = window.getLastWindow(this.getUIContext().getHostContext()!);
      windowStage.then((win: window.Window) => {
        const normalizedBrightness = value / PlayerConstants.BRIGHTNESS_MAX;
        win.setWindowBrightness(normalizedBrightness);
      });
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'Failed to set brightness: %{public}s', error.message);
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
      // Invisible gesture area (left half)
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Transparent)
        .gesture(
          PanGesture({ direction: PanDirection.Vertical })
            .onActionUpdate((event: GestureEvent) => {
              // Swipe up = increase, swipe down = decrease
              const delta = -event.offsetY / 3; // Scale factor
              this.brightnessLevel = Math.max(
                PlayerConstants.BRIGHTNESS_MIN,
                Math.min(PlayerConstants.BRIGHTNESS_MAX,
                  Math.round(this.brightnessLevel + delta))
              );
              this.applyBrightness(this.brightnessLevel);
              this.showFeedback();
            })
        )

      // Brightness feedback popup
      if (this.showPopup) {
        Column() {
          Text('☀')
            .fontSize(18)
            .fontColor('#FFF8DC')
          Text(`${Math.round((this.brightnessLevel / PlayerConstants.BRIGHTNESS_MAX) * 100)}%`)
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
