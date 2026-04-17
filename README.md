> **Note:** To access all shared projects, get information about environment setup, and view other guides, please visit [Explore-In-HMOS-Wearable Index](https://github.com/Explore-In-HMOS-Wearable/hmos-index).

# LocalNetworkVideoPlayer

LocalNetworkVideoPlayer is a demo app for Huawei Watch 5 that lets users play videos from local rawfile storage or from a network URL, with full playback controls, history, favorites, and settings.

# Preview

<div>
  <img src="screenshots/D1.png" width="24%">
  <img src="screenshots/D2.png" width="24%">
  <img src="screenshots/D3.png" width="24%">
  <img src="screenshots/output5.png" width="24%">
</div>

# Use Cases

LocalNetworkVideoPlayer lets users:
- Select and play bundled rawfile videos from the device.
- Enter a video URL to stream and play network content.
- Control playback with play/pause, stop, previous/next, speed, and loop mode.
- Adjust volume via crown rotation and brightness via vertical swipe gestures.
- Track playback history and manage a favorites list.
- Persist settings (speed, loop mode) across sessions.

# Tech Stack 

Languages: ArkTS
Frameworks: HarmonyOS SDK 5.1.0(18)
Tools: DevEco Studio Vers 5.1.0.820
Libraries: @kit.ArkUI, @kit.MediaKit, @kit.BackgroundTasksKit, @kit.AbilityKit

# Directory Structure

```
entry/src/main/ets/
|---common
|   |---constants
|   |   |---AppConstants.ets             // Preference keys, limits, watch size
|   |   |---PlayerConstants.ets          // XComponent ID, volume/brightness steps
|   |---types
|   |   |---PlaybackState.ets            // PlaybackState and LoopMode enums
|   |   |---VideoItem.ets                // VideoSource interface and VideoItem model
|   |   |---SettingsModel.ets            // SpeedValue, AppLanguage enums, SettingsModel
|   |---utils
|   |   |---Logger.ets                   // hilog wrapper
|   |   |---PreferencesUtil.ets          // Key-value persistent storage
|   |   |---DisplayUtil.ets              // Round display helpers
|   |   |---PermissionUtil.ets           // Runtime permission request helper
|   |   |---BackgroundUtil.ets           // Background audio playback task
|---entryability
|   |---EntryAbility.ets                 // App entry: initializes services
|---services
|   |---AVPlayerService.ets              // Singleton AVPlayer state machine
|   |---AVSessionService.ets             // Lock-screen playback controls
|   |---VideoHistoryService.ets          // History and favorites with persistence
|---viewmodel
|   |---HomeViewModel.ets                // Menu item list
|   |---PlayerViewModel.ets              // Playback logic bridge
|   |---SettingsViewModel.ets            // Load/save settings
|---view
|   |---VideoPlayer.ets                  // XComponent surface + controls overlay
|   |---ProgressSlider.ets               // Circular progress ring + seek
|   |---BrightnessGesture.ets            // Left-half swipe for brightness
|   |---VolumeGesture.ets                // Right-half swipe for volume
|   |---EmptyState.ets                   // Empty list placeholder
|---pages
|   |---Index.ets                        // ArcList main menu
|   |---LocalVideoPlayer.ets             // Rawfile browser + player
|   |---NetworkVideoPlayer.ets           // URL input + streaming player
|   |---HistoryPage.ets                  // Playback history list
|   |---FavoritesPage.ets                // Favorites list
|   |---SettingsPage.ets                 // App settings
```

# Constraints and Restrictions
## Supported Devices
Huawei Watch 5

# LICENSE

LocalNetworkVideoPlayer is distributed under the terms of the MIT License.  
See the [LICENSE](/LICENSE) for more information.