
import { ArcList, ArcListItem, ComponentContent } from '@kit.ArkUI';
import { SettingsViewModel } from '../viewmodel/SettingsViewModel';
import { SpeedValue, AppLanguage } from '../common/types/SettingsModel';
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
 * Each setting field is a separate @State so ArkUI detects changes and re-renders.
 * Using a single @State SettingsModel object would only track the reference, not
 * nested property mutations — so Loop/Speed/Language taps would appear to do nothing.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arclist-N
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/data-persistence-by-preferences
 */
@Component
export struct SettingsPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State private autoPlay: boolean = false;
  @State private loopMode: LoopMode = LoopMode.OFF;
  @State private defaultSpeed: SpeedValue = SpeedValue.SPEED_1_0;
  @State private language: AppLanguage = AppLanguage.EN;
  @State private clearSuccess: boolean = false;

  private viewModel: SettingsViewModel = new SettingsViewModel();

  async aboutToAppear(): Promise<void> {
    DisplayUtil.refresh();
    const s = await this.viewModel.load();
    this.autoPlay = s.autoPlay;
    this.loopMode = s.loopMode;
    this.defaultSpeed = s.defaultSpeed;
    this.language = s.language;
    Logger.i(MODULE, 'Settings page appeared');
  }

  private getLoopLabel(): string {
    switch (this.loopMode) {
      case LoopMode.ONE:
        return 'Repeat One';
      case LoopMode.ALL:
        return 'Repeat All';
      default:
        return 'Off';
    }
  }

  private getSpeedLabel(): string {
    return PlayerConstants.SPEED_LABELS[this.defaultSpeed];
  }

  private getLangLabel(): string {
    switch (this.language) {
      case AppLanguage.TR:
        return 'Türkçe';
      case AppLanguage.ZH:
        return '中文';
      default:
        return 'English';
    }
  }

  private cycleLoopMode(): void {
    switch (this.loopMode) {
      case LoopMode.OFF:
        this.loopMode = LoopMode.ONE;
        break;
      case LoopMode.ONE:
        this.loopMode = LoopMode.ALL;
        break;
      case LoopMode.ALL:
        this.loopMode = LoopMode.OFF;
        break;
    }
    this.viewModel.setLoopMode(this.loopMode);
  }

  private cycleSpeed(): void {
    this.defaultSpeed = (this.defaultSpeed + 1) % 4 as SpeedValue;
    this.viewModel.setDefaultSpeed(this.defaultSpeed);
  }

  private cycleLang(): void {
    switch (this.language) {
      case AppLanguage.EN:
        this.language = AppLanguage.TR;
        break;
      case AppLanguage.TR:
        this.language = AppLanguage.ZH;
        break;
      case AppLanguage.ZH:
        this.language = AppLanguage.EN;
        break;
    }
    this.viewModel.setLanguage(this.language);
  }

  build() {
    NavDestination() {
      Flex() {
        // Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arclist-N
        ArcList({ header: new ComponentContent(this.getUIContext(), wrapBuilder(settingsHeader)) }) {

          // Auto-play toggle
          ArcListItem() {
            Row() {
              Text('Auto-play')
                .fontSize(13)
                .fontColor('#8B4513')
                .fontWeight(FontWeight.Medium)
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.autoPlay })
                .selectedColor('#8B4513')
                .switchPointColor('#FFF8DC')
                .width(40)
                .height(22)
                .onChange((val: boolean) => {
                  this.autoPlay = val;
                  this.viewModel.setAutoPlay(val);
                })
            }
            .width('calc(100% - 44px)')
            .justifyContent(FlexAlign.SpaceBetween)
            .alignItems(VerticalAlign.Center)
            .backgroundColor('#FFF8DC')
            .borderRadius(24)
            .padding({ top: 10, bottom: 10, left: 14, right: 14 })
            .margin({ top: 4, bottom: 4, left: 10, right: 10 })
          }

          // Loop mode — tap cycles OFF → ONE → ALL → OFF
          ArcListItem() {
            Row() {
              Text('Loop')
                .fontSize(13)
                .fontColor('#8B4513')
                .fontWeight(FontWeight.Medium)
                .layoutWeight(1)
              Text(this.getLoopLabel())
                .fontSize(12)
                .fontColor('#A0522D')
                .backgroundColor('rgba(139,69,19,0.1)')
                .borderRadius(10)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            }
            .width('calc(100% - 44px)')
            .justifyContent(FlexAlign.SpaceBetween)
            .alignItems(VerticalAlign.Center)
            .backgroundColor('#FFF8DC')
            .borderRadius(24)
            .padding({ top: 10, bottom: 10, left: 14, right: 14 })
            .margin({ top: 4, bottom: 4, left: 10, right: 10 })
            .onClick(() => {
              this.cycleLoopMode();
            })
          }

          // Playback speed — tap cycles 0.5x → 1.0x → 1.5x → 2.0x
          ArcListItem() {
            Row() {
              Text('Speed')
                .fontSize(13)
                .fontColor('#8B4513')
                .fontWeight(FontWeight.Medium)
                .layoutWeight(1)
              Text(this.getSpeedLabel())
                .fontSize(12)
                .fontColor('#A0522D')
                .backgroundColor('rgba(139,69,19,0.1)')
                .borderRadius(10)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            }
            .width('calc(100% - 44px)')
            .justifyContent(FlexAlign.SpaceBetween)
            .alignItems(VerticalAlign.Center)
            .backgroundColor('#FFF8DC')
            .borderRadius(24)
            .padding({ top: 10, bottom: 10, left: 14, right: 14 })
            .margin({ top: 4, bottom: 4, left: 10, right: 10 })
            .onClick(() => {
              this.cycleSpeed();
            })
          }

          // Language — tap cycles EN → TR → ZH → EN
          ArcListItem() {
            Row() {
              Text('Language')
                .fontSize(13)
                .fontColor('#8B4513')
                .fontWeight(FontWeight.Medium)
                .layoutWeight(1)
              Text(this.getLangLabel())
                .fontSize(12)
                .fontColor('#A0522D')
                .backgroundColor('rgba(139,69,19,0.1)')
                .borderRadius(10)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            }
            .width('calc(100% - 43px)')
            .justifyContent(FlexAlign.SpaceBetween)
            .alignItems(VerticalAlign.Center)
            .backgroundColor('#FFF8DC')
            .borderRadius(24)
            .padding({ top: 10, bottom: 10, left: 14, right: 14 })
            .margin({ top: 4, bottom: 4, left: 10, right: 10 })
            .onClick(() => {
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
            .width('calc(100% - 44px)')
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
      }
      .width(AppConstants.WATCH_SIZE)
      .height(AppConstants.WATCH_SIZE)
      .backgroundColor('#8B4513')
    }
    .hideTitleBar(true)
    .hideBackButton(true)
  }
}
