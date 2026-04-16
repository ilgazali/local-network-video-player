// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arclist-N
// F17: About page with version info, license, and doc links

import { ArcList, ArcListItem, ComponentContent } from '@kit.ArkUI';
import { Want, common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { DisplayUtil } from '../common/utils/DisplayUtil';
import { AppConstants } from '../common/constants/AppConstants';
import { Logger } from '../common/utils/Logger';

const MODULE: string = 'AboutPage';

/**
 * Standalone @Builder for ArcList header — wrapBuilder requires a non-method function.
 */
@Builder
function aboutHeader() {
  Text('About')
    .fontSize(20)
    .fontWeight(FontWeight.Bold)
    .fontColor('#FFF8DC')
    .textAlign(TextAlign.Center)
    .margin({ top: 14, bottom: 10 })
}

/**
 * About page showing app version, license, and links to official documentation.
 * "Open Docs" button launches the browser to HarmonyOS developer docs.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arclist-N
 */
@Component
export struct AboutPage {
  @Consume('pathStack') pathStack: NavPathStack;

  aboutToAppear(): void {
    DisplayUtil.refresh();
  }

  /**
   * Open official HarmonyOS documentation in the system browser.
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/arkui
   */
  private openDocs(): void {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: 'https://developer.huawei.com/consumer/en/doc/harmonyos-guides/media-kit'
      };
      context.startAbility(want);
      Logger.i(MODULE, 'Opening docs in browser');
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'Failed to open docs: %{public}s', error.message);
    }
  }

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor('#A0522D')
        .layoutWeight(1)
      Text(value)
        .fontSize(12)
        .fontColor('#8B4513')
        .fontWeight(FontWeight.Medium)
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
      Flex() {
        // Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arclist-N
        ArcList({ header: new ComponentContent(this.getUIContext(), wrapBuilder(aboutHeader)) }) {
          // App name
          ArcListItem() {
            this.InfoRow('App', AppConstants.APP_NAME)
          }

          // Version
          ArcListItem() {
            this.InfoRow('Version', AppConstants.APP_VERSION)
          }

          // License
          ArcListItem() {
            this.InfoRow('License', AppConstants.LICENSE)
          }

          // SDK
          ArcListItem() {
            this.InfoRow('SDK', 'HarmonyOS 5.1 API 18')
          }

          // Target device
          ArcListItem() {
            this.InfoRow('Device', 'Huawei Watch 5')
          }

          // Open docs button
          ArcListItem() {
            Row() {
              Text('Open HarmonyOS Docs')
                .fontSize(13)
                .fontColor('#8B4513')
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
            .onClick(() => {
              this.openDocs();
            })
          }

          // Repo link row
          ArcListItem() {
            Column() {
              Text('github.com/ilgazali/')
                .fontSize(10)
                .fontColor('#A0522D')
                .textAlign(TextAlign.Center)
              Text('local-network-video-player')
                .fontSize(10)
                .fontColor('#A0522D')
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .backgroundColor('#FFF8DC')
            .borderRadius(24)
            .padding({ top: 10, bottom: 10, left: 14, right: 14 })
            .margin({ top: 4, bottom: 4, left: 10, right: 10 })
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
