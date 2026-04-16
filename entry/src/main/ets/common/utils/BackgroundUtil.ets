// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/continuous-task
// F9: Background task management for continuous audio/video playback

import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent, WantAgent } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from './Logger';

const MODULE: string = 'BackgroundUtil';

/**
 * Utility for managing background continuous tasks.
 * Enables audio/video playback to continue when the screen is off or app is in background.
 *
 * Requires ohos.permission.KEEP_BACKGROUND_RUNNING in module.json5.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/continuous-task
 */
export class BackgroundUtil {
  private static isRunning: boolean = false;

  /**
   * Start background running task for audio playback.
   * Call when video playback begins.
   * @param context - The UIAbility context
   * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/continuous-task
   */
  static async startOnPlay(context: Context): Promise<void> {
    if (BackgroundUtil.isRunning) {
      Logger.d(MODULE, 'Background task already running');
      return;
    }

    try {
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: 'com.hmosdemos.wearable.local_network_video_player',
            abilityName: 'EntryAbility'
          }
        ],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };

      const agent: WantAgent = await wantAgent.getWantAgent(wantAgentInfo);

      await backgroundTaskManager.startBackgroundRunning(context,
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, agent);

      BackgroundUtil.isRunning = true;
      Logger.i(MODULE, 'Background running started for audio playback');
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'Failed to start background running: %{public}s', error.message);
    }
  }

  /**
   * Stop the background running task.
   * Call when playback is paused, stopped, or released.
   * @param context - The UIAbility context
   */
  static async stopOnStopOrPause(context: Context): Promise<void> {
    if (!BackgroundUtil.isRunning) {
      return;
    }

    try {
      await backgroundTaskManager.stopBackgroundRunning(context);
      BackgroundUtil.isRunning = false;
      Logger.i(MODULE, 'Background running stopped');
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'Failed to stop background running: %{public}s', error.message);
    }
  }

  /**
   * Check if background task is currently active.
   * @returns true if background running
   */
  static isBackgroundRunning(): boolean {
    return BackgroundUtil.isRunning;
  }
}
