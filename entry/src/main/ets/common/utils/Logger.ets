// Doc: https://developer.huawei.com/consumer/en/doc/harmonyos-guides/hilog-guidelines
// F18: hilog wrapper with structured logging

import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * Structured logging utility wrapping HarmonyOS hilog.
 * Provides domain-tagged log methods for the entire application.
 *
 * Usage:
 *   Logger.info('AVPlayerService', 'Player state changed to: %{public}s', state);
 */
export class Logger {
  /** Application log domain identifier */
  private static readonly DOMAIN: number = 0xAA01;

  /** Application log tag */
  private static readonly TAG: string = 'LNVP';

  /**
   * Log a debug-level message.
   * @param module - The source module name
   * @param msg - The format string
   * @param args - Format arguments
   */
  static d(module: string, msg: string, ...args: string[]): void {
    if (hilog.isLoggable(Logger.DOMAIN, Logger.TAG, hilog.LogLevel.DEBUG)) {
      hilog.debug(Logger.DOMAIN, Logger.TAG, `[${module}] ${msg}`, args);
    }
  }

  /**
   * Log an info-level message.
   * @param module - The source module name
   * @param msg - The format string
   * @param args - Format arguments
   */
  static i(module: string, msg: string, ...args: string[]): void {
    if (hilog.isLoggable(Logger.DOMAIN, Logger.TAG, hilog.LogLevel.INFO)) {
      hilog.info(Logger.DOMAIN, Logger.TAG, `[${module}] ${msg}`, args);
    }
  }

  /**
   * Log a warning-level message.
   * @param module - The source module name
   * @param msg - The format string
   * @param args - Format arguments
   */
  static w(module: string, msg: string, ...args: string[]): void {
    if (hilog.isLoggable(Logger.DOMAIN, Logger.TAG, hilog.LogLevel.WARN)) {
      hilog.warn(Logger.DOMAIN, Logger.TAG, `[${module}] ${msg}`, args);
    }
  }

  /**
   * Log an error-level message.
   * @param module - The source module name
   * @param msg - The format string
   * @param args - Format arguments
   */
  static e(module: string, msg: string, ...args: string[]): void {
    if (hilog.isLoggable(Logger.DOMAIN, Logger.TAG, hilog.LogLevel.ERROR)) {
      hilog.error(Logger.DOMAIN, Logger.TAG, `[${module}] ${msg}`, args);
    }
  }
}
