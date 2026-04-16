// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arclist-N
// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arcbutton-N
// F4: Main menu with ArcList for wearable round display

import { ArcList, ArcListItem, ComponentContent } from '@kit.ArkUI';
import { NetworkVideoPlayer } from './NetworkVideoPlayer';
import { LocalVideoPlayer } from './LocalVideoPlayer';
import { HistoryPage } from './HistoryPage';
import { FavoritesPage } from './FavoritesPage';
import { SettingsPage } from './SettingsPage';
import { AboutPage } from './AboutPage';
import { DisplayUtil } from '../common/utils/DisplayUtil';
import { AppConstants } from '../common/constants/AppConstants';
import { Logger } from '../common/utils/Logger';

const MODULE: string = 'Index';

// Docs:
// - ArcList: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arclist-N
// - ArcButton: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arcbutton-N

/**
 * Menu item model for the home ArcList.
 */
interface MenuItemData {
  title: string;
  icon: Resource;
  pageName: string;
  iconColor: string;
}

@Builder
function headerBuilder() {
  Text('Media Player')
    .fontSize(22)
    .fontWeight(FontWeight.Bold)
    .textAlign(TextAlign.Center)
    .margin({ top: 14, bottom: 10 })
    .fontColor('#FFF8DC')
}

/**
 * Main entry page with ArcList navigation for the Watch 5 round display.
 * Provides 6 navigation items: Local, Network, History, Favorites, Settings, About.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arclist-N
 */
@Entry
@Component
export struct VideoPlayer {
  private context: UIContext = this.getUIContext();
  private header: ComponentContent<object> = new ComponentContent(this.context, wrapBuilder(headerBuilder));

  @Provide('pathStack') pathStack: NavPathStack = new NavPathStack();

  private menuItems: MenuItemData[] = [
    { title: 'Local Video', icon: $r('app.media.directory'), pageName: 'LocalVideoPlayer', iconColor: '#8B4513' },
    { title: 'Network Video', icon: $r('app.media.url'), pageName: 'NetworkVideoPlayer', iconColor: '#8B4513' },
    { title: 'History', icon: $r('app.media.search'), pageName: 'HistoryPage', iconColor: '#6B4226' },
    { title: 'Favorites', icon: $r('app.media.file'), pageName: 'FavoritesPage', iconColor: '#CC3333' },
    { title: 'Settings', icon: $r('app.media.search'), pageName: 'SettingsPage', iconColor: '#556B2F' },
    { title: 'About', icon: $r('app.media.file'), pageName: 'AboutPage', iconColor: '#4682B4' }
  ];

  aboutToAppear(): void {
    DisplayUtil.refresh();
    Logger.i(MODULE, 'Index appeared');
  }

  @Builder
  PageMap(name: string) {
    if (name === 'LocalVideoPlayer') {
      LocalVideoPlayer()
    } else if (name === 'NetworkVideoPlayer') {
      NetworkVideoPlayer()
    } else if (name === 'HistoryPage') {
      HistoryPage()
    } else if (name === 'FavoritesPage') {
      FavoritesPage()
    } else if (name === 'SettingsPage') {
      SettingsPage()
    } else if (name === 'AboutPage') {
      AboutPage()
    }
  }

  build() {
    Navigation(this.pathStack) {
      Flex() {
        // Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arclist-N
        ArcList({ header: this.header }) {
          ForEach(this.menuItems, (item: MenuItemData) => {
            ArcListItem() {
              Row({ space: 10 }) {
                Image(item.icon)
                  .fillColor(item.iconColor)
                  .width(28)
                  .height(28)
                  .objectFit(ImageFit.Contain)

                Text(item.title)
                  .fontColor('#8B4513')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .layoutWeight(1)
              }
              .alignItems(VerticalAlign.Center)
              .backgroundColor('#FFF8DC')
              .borderRadius(30)
              .margin({ top: 5, bottom: 5, left: 12, right: 12 })
              .padding({ top: 10, bottom: 10, left: 16, right: 16 })
              .onClick(() => {
                Logger.i(MODULE, 'Navigate to: %{public}s', item.pageName);
                this.pathStack.pushPathByName(item.pageName, null);
              })
            }
          })
        }
      }
      .width(AppConstants.WATCH_SIZE)
      .height(AppConstants.WATCH_SIZE)
      .backgroundColor('#8B4513')
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .hideBackButton(true)
    .navDestination(this.PageMap)
  }
}
