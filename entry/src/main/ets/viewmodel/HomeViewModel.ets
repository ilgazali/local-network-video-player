
import { Logger } from '../common/utils/Logger';

const MODULE: string = 'HomeViewModel';

/**
 * Represents a menu item on the home page ArcList.
 */
export interface MenuItemModel {
  /** Display label */
  title: string;
  /** Icon resource reference */
  icon: Resource;
  /** Navigation target page name */
  pageName: string;
}

/**
 * ViewModel for the home (Index) page.
 * Provides the menu item list for navigation.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/arkui
 */
export class HomeViewModel {
  /**
   * Get the list of menu items for the home ArcList.
   * @returns Array of MenuItemModel for navigation
   */
  static getMenuItems(): MenuItemModel[] {
    Logger.d(MODULE, 'Loading menu items');
    return [
      {
        title: 'Local Video',
        icon: $r('app.media.directory'),
        pageName: 'LocalVideoPlayer'
      } as MenuItemModel,
      {
        title: 'Network Video',
        icon: $r('app.media.url'),
        pageName: 'NetworkVideoPlayer'
      } as MenuItemModel,
      {
        title: 'History',
        icon: $r('app.media.search'),
        pageName: 'HistoryPage'
      } as MenuItemModel,
      {
        title: 'Favorites',
        icon: $r('app.media.file'),
        pageName: 'FavoritesPage'
      } as MenuItemModel,
      {
        title: 'Settings',
        icon: $r('app.media.search'),
        pageName: 'SettingsPage'
      } as MenuItemModel,
      {
        title: 'About',
        icon: $r('app.media.file'),
        pageName: 'AboutPage'
      } as MenuItemModel
    ];
  }
}
