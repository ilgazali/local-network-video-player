// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/request-user-authorization
// Permission utility for INTERNET and other runtime permissions

import { abilityAccessCtrl, bundleManager, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from './Logger';

const MODULE: string = 'PermissionUtil';

/**
 * Utility class for checking and requesting runtime permissions.
 * Handles INTERNET and KEEP_BACKGROUND_RUNNING permissions required by the app.
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/request-user-authorization
 */
export class PermissionUtil {
  /**
   * Check whether a specific permission is already granted.
   * @param permission - The permission to check
   * @returns true if the permission is granted
   */
  static async checkPermission(permission: Permissions): Promise<boolean> {
    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      const tokenId = bundleInfo.appInfo.accessTokenId;
      const atManager = abilityAccessCtrl.createAtManager();
      const grantStatus = atManager.checkAccessTokenSync(tokenId, permission);
      const granted = grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      Logger.d(MODULE, 'Permission %{public}s granted: %{public}s', permission, `${granted}`);
      return granted;
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'checkPermission failed: %{public}s', error.message);
      return false;
    }
  }

  /**
   * Request permissions from the user at runtime.
   * @param context - The UIAbility context
   * @param permissions - Array of permissions to request
   * @returns true if all permissions were granted
   */
  static async requestPermissions(context: Context, permissions: Permissions[]): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(context, permissions);
      const allGranted = result.authResults.every(
        (status: number) => status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
      );
      Logger.i(MODULE, 'Permissions request result: all granted = %{public}s', `${allGranted}`);
      return allGranted;
    } catch (err) {
      const error = err as BusinessError;
      Logger.e(MODULE, 'requestPermissions failed: %{public}s', error.message);
      return false;
    }
  }

  /**
   * Ensure INTERNET permission is granted.
   * @param context - The UIAbility context
   * @returns true if INTERNET permission is available
   */
  static async ensureInternet(context: Context): Promise<boolean> {
    const permission: Permissions = 'ohos.permission.INTERNET';
    const granted = await PermissionUtil.checkPermission(permission);
    if (granted) {
      return true;
    }
    return await PermissionUtil.requestPermissions(context, [permission]);
  }
}
