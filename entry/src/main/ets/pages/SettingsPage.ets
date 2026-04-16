// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/data-persistence-by-preferences
// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arclist-N
// F16: Settings page with ArcList for wearable

import { ArcList, ArcListItem, ComponentContent } from '@kit.ArkUI';
import { SettingsViewModel } from '../viewmodel/SettingsViewModel';
import { SettingsModel, SpeedValue, AppLanguage } from '../common/types/SettingsModel';
import { LoopMode } from '../common/types/PlaybackState';
import { DisplayUtil } from '../common/utils/DisplayUtil';
import { PlayerConstants } from '../common/constants/PlayerConstants';
import { AppConstants } from '../common/constants/AppConstants';
import { Logger } from '../common/utils/Logger';

const MODULE: string = 'SettingsPage';

/**
 * Standalone @Builder for ArcList header — wrapBuilder requires a non-method function.
 */
@Builder
function settingsHeader() {
  Text('Settings')
    .fontSize(20)
    .fontWeight(FontWeight.Bold)
    .fontColor('#FFF8DC')
    .textAlign(TextAlign.Center)
    .margin({ top: 14, bottom: 10 })
}

/**
 * Settings page rendered as a scrollable ArcList.
 * Manages auto-play, loop mode, default speed, language, and history clearing.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arclist-N
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/data-persistence-by-preferences
 */
@Component
export struct SettingsPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State private settings: SettingsModel = {
    autoPlay: false,
    loopMode: LoopMode.OFF,
    defaultSpeed: SpeedValue.SPEED_1_0,
    language: AppLanguage.EN
  };
  @State private showClearConfirm: boolean = false;
  @State private clearSuccess: boolean = false;

  private viewModel: SettingsViewModel = new SettingsViewModel();

  async aboutToAppear(): Promise<void> {
    DisplayUtil.refresh();
    this.settings = await this.viewModel.load();
    Logger.i(MODULE, 'Settings page appeared');
  }

  private getLoopLabel(): string {
    switch (this.settings.loopMode) {
      case LoopMode.ONE:
        return 'Repeat One';
      case LoopMode.ALL:
        return 'Repeat All';
      default:
        return 'Off';
    }
  }

  private getSpeedLabel(): string {
    return PlayerConstants.SPEED_LABELS[this.settings.defaultSpeed];
  }

  private getLangLabel(): string {
    switch (this.settings.language) {
      case AppLanguage.TR:
        return 'Türkçe';
      case AppLanguage.ZH:
        return '中文';
      default:
        return 'English';
    }
  }

  private cycleLoopMode(): void {
    switch (this.settings.loopMode) {
      case LoopMode.OFF:
        this.settings.loopMode = LoopMode.ONE;
        break;
      case LoopMode.ONE:
        this.settings.loopMode = LoopMode.ALL;
        break;
      case LoopMode.ALL:
        this.settings.loopMode = LoopMode.OFF;
        break;
    }
    this.viewModel.setLoopMode(this.settings.loopMode);
  }

  private cycleSpeed(): void {
    this.settings.defaultSpeed = (this.settings.defaultSpeed + 1) % 4 as SpeedValue;
    this.viewModel.setDefaultSpeed(this.settings.defaultSpeed);
  }

  private cycleLang(): void {
    switch (this.settings.language) {
      case AppLanguage.EN:
        this.settings.language = AppLanguage.TR;
        break;
      case AppLanguage.TR:
        this.settings.language = AppLanguage.ZH;
        break;
      case AppLanguage.ZH:
        this.settings.language = AppLanguage.EN;
        break;
    }
    this.viewModel.setLanguage(this.settings.language);
  }

  @Builder
  SettingRow(label: string, value: string, onTap: () => void) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('#8B4513')
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)

      Text(value)
        .fontSize(12)
        .fontColor('#A0522D')
        .backgroundColor('rgba(139,69,19,0.1)')
        .borderRadius(10)
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
    .backgroundColor('#FFF8DC')
    .borderRadius(24)
    .padding({ top: 10, bottom: 10, left: 14, right: 14 })
    .margin({ top: 4, bottom: 4, left: 10, right: 10 })
    .onClick(onTap)
  }

  @Builder
  ToggleRow(label: string, checked: boolean, onChange: (val: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('#8B4513')
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: checked })
        .selectedColor('#8B4513')
        .switchPointColor('#FFF8DC')
        .onChange(onChange)
        .width(40)
        .height(22)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
    .backgroundColor('#FFF8DC')
    .borderRadius(24)
    .padding({ top: 10, bottom: 10, left: 14, right: 14 })
    .margin({ top: 4, bottom: 4, left: 10, right: 10 })
  }

  build() {
    NavDestination() {
      Stack() {
        // Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arclist-N
        ArcList({ header: new ComponentContent(this.getUIContext(), wrapBuilder(settingsHeader)) }) {
          // Auto-play toggle
          ArcListItem() {
            this.ToggleRow('Auto-play', this.settings.autoPlay, (val: boolean) => {
              this.settings.autoPlay = val;
              this.viewModel.setAutoPlay(val);
            })
          }

          // Loop mode
          ArcListItem() {
            this.SettingRow('Loop', this.getLoopLabel(), () => {
              this.cycleLoopMode();
            })
          }

          // Default speed
          ArcListItem() {
            this.SettingRow('Speed', this.getSpeedLabel(), () => {
              this.cycleSpeed();
            })
          }

          // Language
          ArcListItem() {
            this.SettingRow('Language', this.getLangLabel(), () => {
              this.cycleLang();
            })
          }

          // Clear history
          ArcListItem() {
            Row() {
              Text(this.clearSuccess ? 'Cleared!' : 'Clear History')
                .fontSize(13)
                .fontColor(this.clearSuccess ? '#4CAF50' : '#CC3333')
                .fontWeight(FontWeight.Medium)
                .width('100%')
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .backgroundColor('#FFF8DC')
            .borderRadius(24)
            .padding({ top: 10, bottom: 10, left: 14, right: 14 })
            .margin({ top: 4, bottom: 4, left: 10, right: 10 })
            .onClick(async () => {
              await this.viewModel.clearHistory();
              this.clearSuccess = true;
              setTimeout(() => {
                this.clearSuccess = false;
              }, 2000);
              Logger.i(MODULE, 'History cleared');
            })
          }
        }
        .width(AppConstants.WATCH_SIZE)
        .height(AppConstants.WATCH_SIZE)
      }
      .width(AppConstants.WATCH_SIZE)
      .height(AppConstants.WATCH_SIZE)
      .backgroundColor('#8B4513')
    }
    .hideTitleBar(true)
    .hideBackButton(true)
  }
}
