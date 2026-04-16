// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arclist-N
// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/data-persistence-by-preferences
// F4: Playback history page with ArcList

import { ArcList, ArcListItem, ComponentContent } from '@kit.ArkUI';
import { VideoHistoryService } from '../services/VideoHistoryService';
import { AVPlayerService } from '../services/AVPlayerService';
import { VideoItem } from '../common/types/VideoItem';
import { EmptyState } from '../view/EmptyState';
import { DisplayUtil } from '../common/utils/DisplayUtil';
import { AppConstants } from '../common/constants/AppConstants';
import { Logger } from '../common/utils/Logger';

const MODULE: string = 'HistoryPage';

/**
 * Standalone @Builder for ArcList header — wrapBuilder requires a non-method function.
 */
@Builder
function historyHeader() {
  Text('History')
    .fontSize(20)
    .fontWeight(FontWeight.Bold)
    .fontColor('#FFF8DC')
    .textAlign(TextAlign.Center)
    .margin({ top: 14, bottom: 10 })
}

/**
 * Displays playback history as a scrollable ArcList.
 * Tapping an item navigates to the player and resumes from last position.
 * Crown rotary scrolls the list automatically via ArcList focus.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arclist-N
 */
@Component
export struct HistoryPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @State private historyItems: VideoItem[] = [];
  @State private isLoading: boolean = true;

  private historyService: VideoHistoryService = VideoHistoryService.getInstance();

  aboutToAppear(): void {
    DisplayUtil.refresh();
    this.loadHistory();
  }

  private loadHistory(): void {
    this.historyItems = this.historyService.getHistory();
    this.isLoading = false;
    Logger.i(MODULE, 'History loaded: %{public}s items', `${this.historyItems.length}`);
  }

  /**
   * Format timestamp to relative time string.
   */
  private formatTime(timestamp: number): string {
    const diff = Date.now() - timestamp;
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);
    if (days > 0) {
      return `${days}d ago`;
    }
    if (hours > 0) {
      return `${hours}h ago`;
    }
    if (minutes > 0) {
      return `${minutes}m ago`;
    }
    return 'Just now';
  }

  /**
   * Format duration in ms to mm:ss string.
   */
  private formatDuration(ms: number): string {
    if (ms <= 0) {
      return '--:--';
    }
    const totalSeconds = Math.floor(ms / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
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
        } else if (this.historyItems.length === 0) {
          EmptyState({ message: 'No history yet', icon: '📽' })
        } else {
          // Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/arkts-arclist-N
          Flex() {
          ArcList({ header: new ComponentContent(this.getUIContext(), wrapBuilder(historyHeader)) }) {
            ForEach(this.historyItems, (item: VideoItem) => {
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

                    Row({ space: 6 }) {
                      Text(this.formatTime(item.lastPlayedAt))
                        .fontSize(10)
                        .fontColor('#A0522D')
                      if (item.durationMs > 0) {
                        Text('·')
                          .fontSize(10)
                          .fontColor('#A0522D')
                        Text(this.formatDuration(item.durationMs))
                          .fontSize(10)
                          .fontColor('#A0522D')
                      }
                    }
                    .width('100%')
                  }
                  .layoutWeight(1)

                  if (item.isFavorite) {
                    Text('♥')
                      .fontSize(14)
                      .fontColor('#CC3333')
                  }
                }
                .alignItems(VerticalAlign.Center)
                .backgroundColor('#FFF8DC')
                .borderRadius(24)
                .padding({ top: 8, bottom: 8, left: 14, right: 14 })
                .margin({ top: 4, bottom: 4, left: 10, right: 10 })
                .width('calc(100% - 20px)')
                .onClick(() => {
                  Logger.i(MODULE, 'Resuming: %{public}s', item.title);
                  const playerService = AVPlayerService.getInstance();
                  if (item.lastPositionMs > 0) {
                    playerService.onStateChange(() => {
                      if (item.lastPositionMs > 0) {
                        setTimeout(() => {
                          playerService.seek(item.lastPositionMs);
                        }, 500);
                      }
                    });
                  }
                  playerService.load(item.source);
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
