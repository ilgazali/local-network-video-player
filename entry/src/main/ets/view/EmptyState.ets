
/**
 * Reusable "no content" placeholder for empty lists (history, favorites, etc.).
 * Displays an icon and message centered on the round display.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/arkui
 */
@Component
export struct EmptyState {
  /** Display message */
  @Prop message: string = 'No items found';
  /** Icon text (emoji or symbol) */
  @Prop icon: string = '📭';

  build() {
    Column() {
      Text(this.icon)
        .fontSize(36)
        .margin({ bottom: 12 })

      Text(this.message)
        .fontColor('#FFF8DC')
        .fontSize(14)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .padding({ left: 32, right: 32 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
