import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { PreferencesUtil } from '../common/utils/PreferencesUtil';
import { VideoHistoryService } from '../services/VideoHistoryService';
import { AVPlayerService } from '../services/AVPlayerService';
import { AVSessionService } from '../services/AVSessionService';
import { Logger } from '../common/utils/Logger';

const MODULE: string = 'EntryAbility';

/**
 * Main application lifecycle ability.
 * Initializes PreferencesUtil, VideoHistoryService, AVPlayerService, and AVSessionService
 * on startup, and properly releases resources on destroy.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/uiability-lifecycle
 */
export default class EntryAbility extends UIAbility {

  /**
   * Called when the ability is created.
   * Initializes all singleton services.
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/uiability-lifecycle
   */
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    Logger.i(MODULE, 'Ability onCreate');

    await PreferencesUtil.init(this.context);
    Logger.i(MODULE, 'PreferencesUtil initialized');

    await VideoHistoryService.getInstance().loadFromPreferences();
    Logger.i(MODULE, 'VideoHistoryService loaded');

    await AVPlayerService.getInstance().init(this.context);
    Logger.i(MODULE, 'AVPlayerService initialized');

    await AVSessionService.getInstance().create(this.context);
    Logger.i(MODULE, 'AVSessionService created');
  }

  /**
   * Called when the ability is destroyed.
   * Releases AVPlayer and AVSession resources.
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/uiability-lifecycle
   */
  async onDestroy(): Promise<void> {
    Logger.i(MODULE, 'Ability onDestroy');

    await AVSessionService.getInstance().destroy();

    await AVPlayerService.getInstance().release();

    Logger.i(MODULE, 'All services released');
  }

  /**
   * Called when the main window stage is created.
   * Loads the main page (pages/Index).
   */
  onWindowStageCreate(windowStage: window.WindowStage): void {
    Logger.i(MODULE, 'onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        Logger.e(MODULE, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      Logger.i(MODULE, 'Content loaded successfully');
    });
  }

  onWindowStageDestroy(): void {
    Logger.i(MODULE, 'onWindowStageDestroy');
  }

  onForeground(): void {
    Logger.i(MODULE, 'onForeground');
  }

  onBackground(): void {
    Logger.i(MODULE, 'onBackground');
  }
}
