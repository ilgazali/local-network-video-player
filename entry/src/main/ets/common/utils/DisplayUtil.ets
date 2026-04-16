// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-display
// F15: Responsive display utilities for round wearable screen

import { display } from '@kit.ArkUI';
import { Logger } from './Logger';
import { AppConstants } from '../constants/AppConstants';

const MODULE: string = 'DisplayUtil';

/**
 * Display metrics for the current device screen.
 */
export interface DisplayMetrics {
  /** Screen width in px */
  width: number;
  /** Screen height in px */
  height: number;
  /** Pixel density */
  densityPixels: number;
}

/**
 * Utility class for responsive layout calculations on round wearable displays.
 * Provides methods to compute safe areas and circular bounds for Watch 5 (466x466).
 *
 * Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-display
 */
export class DisplayUtil {
  private static metrics: DisplayMetrics = {
    width: AppConstants.WATCH_SIZE_PX,
    height: AppConstants.WATCH_SIZE_PX,
    densityPixels: 2.0
  };

  /**
   * Refresh display metrics from the system.
   * Call in aboutToAppear of each page to get current display info.
   */
  static refresh(): void {
    try {
      const defaultDisplay: display.Display = display.getDefaultDisplaySync();
      DisplayUtil.metrics = {
        width: defaultDisplay.width,
        height: defaultDisplay.height,
        densityPixels: defaultDisplay.densityPixels
      };
      Logger.d(MODULE, 'Display refreshed: %{public}s x %{public}s @ %{public}s',
        `${DisplayUtil.metrics.width}`, `${DisplayUtil.metrics.height}`,
        `${DisplayUtil.metrics.densityPixels}`);
    } catch (err) {
      Logger.w(MODULE, 'Failed to get display, using defaults');
    }
  }

  /**
   * Get current display metrics.
   * @returns DisplayMetrics with width, height, and density
   */
  static getMetrics(): DisplayMetrics {
    return DisplayUtil.metrics;
  }

  /**
   * Get the minimum dimension (for round displays, width === height).
   * @returns Minimum of width and height in px
   */
  static getMinDimension(): number {
    return Math.min(DisplayUtil.metrics.width, DisplayUtil.metrics.height);
  }

  /**
   * Calculate circular safe area bound for a given scale factor.
   * @param scale - Scale factor (0.0 to 1.0), default 0.9
   * @returns Diameter in px for the circular content area
   */
  static getCircularBound(scale: number = 0.9): number {
    const minDim = DisplayUtil.getMinDimension();
    return Math.floor(minDim * scale);
  }

  /**
   * Get the safe content area accounting for round display margins.
   * @returns Content size in px string (e.g., '414px')
   */
  static getSafeContentSize(): string {
    const size = DisplayUtil.metrics.width - (AppConstants.ROUND_MARGIN * 2);
    return `${size}px`;
  }

  /**
   * Convert vp to px based on current density.
   * @param vp - Value in virtual pixels
   * @returns Value in physical pixels
   */
  static vpToPx(vp: number): number {
    return Math.round(vp * DisplayUtil.metrics.densityPixels);
  }

  /**
   * Convert px to vp based on current density.
   * @param px - Value in physical pixels
   * @returns Value in virtual pixels
   */
  static pxToVp(px: number): number {
    return Math.round(px / DisplayUtil.metrics.densityPixels);
  }
}
