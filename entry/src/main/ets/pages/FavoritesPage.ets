import { ArcList, ArcListItem, ComponentContent } from '@kit.ArkUI';
import { VideoHistoryService } from '../services/VideoHistoryService';
import { AVPlayerService } from '../services/AVPlayerService';
import { VideoItem } from '../common/types/VideoItem';
import { EmptyState } from '../view/EmptyState';
import { DisplayUtil } from '../common/utils/DisplayUtil';
import { AppConstants } from '../common/constants/AppConstants';
import { Logger } from '../common/utils/Logger';

const MODULE: string = 'FavoritesPage';

/**
 * Standalone @Builder for ArcList header — wrapBuilder requires a non-method function.
 */
@Builder
function favoritesHeader() {
  Text('Favorites')
    .fontSize(20)
    .fontWeight(FontWeight.Bold)
    .fontColor('#FFF8DC')
    .textAlign(TextAlign.Center)
    .margin({ top: 14, bottom: 10 })
}

/**
 * Displays favorite videos as a scrollable ArcList.
 * Tapping an item starts playback. Long-press removes from favorites.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arclist-N
 */
@Component
export struct FavoritesPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State private favoriteItems: VideoItem[] = [];
  @State private isLoading: boolean = true;

  private historyService: VideoHistoryService = VideoHistoryService.getInstance();

  aboutToAppear(): void {
    DisplayUtil.refresh();
    this.loadFavorites();
  }

  private loadFavorites(): void {
    this.favoriteItems = this.historyService.getFavorites();
    this.isLoading = false;
    Logger.i(MODULE, 'Favorites loaded: %{public}s items', `${this.favoriteItems.length}`);
  }

  build() {
    NavDestination() {
      Flex() {
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .color('#FFF8DC')
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else if (this.favoriteItems.length === 0) {
          EmptyState({ message: 'No favorites yet', icon: '♡' })
        } else {
          // Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arclist-N
          Flex() {
          ArcList({ header: new ComponentContent(this.getUIContext(), wrapBuilder(favoritesHeader)) }) {
            ForEach(this.favoriteItems, (item: VideoItem) => {
              ArcListItem() {
                Row({ space: 8 }) {
                  Column() {
                    Text(item.title)
                      .fontSize(13)
                      .fontColor('#8B4513')
                      .fontWeight(FontWeight.Medium)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')

                  }
                  .layoutWeight(1)

                  Text('♥')
                    .fontSize(16)
                    .fontColor('#CC3333')
                    .onClick(async () => {
                      await this.historyService.removeFromFavorites(item.id);
                      this.loadFavorites();
                    })
                }
                .alignItems(VerticalAlign.Center)
                .backgroundColor('#FFF8DC')
                .borderRadius(24)
                .padding({ top: 8, bottom: 8, left: 14, right: 14 })
                .margin({ top: 4, bottom: 4, left: 10, right: 10 })
                .width('calc(100% - 44px)')
                .onClick(() => {
                  Logger.i(MODULE, 'Playing favorite: %{public}s', item.title);
                  AVPlayerService.getInstance().load(item.source);
                  this.pathStack.pushPathByName(
                    item.source.type === 'url' ? 'NetworkVideoPlayer' : 'LocalVideoPlayer',
                    null
                  );
                })
              }
            })
          }
          }
          .width(AppConstants.WATCH_SIZE)
          .height(AppConstants.WATCH_SIZE)
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
