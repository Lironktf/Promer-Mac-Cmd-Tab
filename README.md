# MacAppSwitcher (Proper Command Tab on Mac)

A modern macOS window switcher that brings Windows-style Alt+Tab functionality to Mac. Switch between individual windows (not just applications) with a beautiful, thumbnail-based interface.

## Features

- **Window-level switching**: Switch between individual windows, not just applications
- **Most Recently Used (MRU) tracking**: Windows are ordered by recent usage
- **Live thumbnails**: Real-time window previews with automatic updates
- **Beautiful UI**: Modern interface with blur effects, rounded corners, and smooth animations
- **Keyboard-driven**: Fully keyboard-controlled workflow using `Cmd+~`
- **Multi-row layout**: Displays up to 10 windows in a grid layout
- **Menu bar integration**: Quick access to settings and permissions

## Requirements

- macOS 12.0 or later (recommended: macOS 13.0+)
- Xcode 14.0+ for building from source
- Two system permissions required:
  - **Accessibility** (required for hotkey detection)
  - **Screen Recording** (required for window thumbnails)

## Installation

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/MacAppSwitcher.git
   cd MacAppSwitcher
   ```

2. Open the project in Xcode:
   ```bash
   open MacAppSwitcher.xcodeproj
   ```

3. Build and run:
   - Select the "MacAppSwitcher" scheme
   - Press `Cmd+R` to build and run

### Grant Permissions

After the first launch, you'll need to grant two permissions:

#### 1. Accessibility Permission

1. Open **System Settings** > **Privacy & Security** > **Accessibility**
2. Click the **+** button
3. Navigate to and select the MacAppSwitcher app
4. Enable the checkbox
5. **Quit and restart** the app

#### 2. Screen Recording Permission

1. Open **System Settings** > **Privacy & Security** > **Screen Recording**
2. Click the **+** button
3. Navigate to and select the MacAppSwitcher app
4. Enable the checkbox
5. **Quit and restart** the app

> **Note**: Without Screen Recording permission, the app will still work but will show app icons instead of live window thumbnails.

## Usage

### Basic Usage

1. Press `Cmd+~` to open the window switcher
2. Keep holding `Cmd` and press `~` repeatedly to cycle through windows
3. Release `Cmd` to activate the selected window

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+~` | Open window switcher / Cycle to next window |
| Release `Cmd` | Activate selected window |
| `Cmd+Q` (when menu bar icon is selected) | Quit MacAppSwitcher |

### Menu Bar

Click the menu bar icon (⌘⇥) to access:
- About information
- Open Accessibility Settings
- Quit the application

## How It Works

### Architecture

The app consists of several key components:

1. **WindowTracker**: Monitors window focus events and maintains an MRU (Most Recently Used) stack of windows
2. **HotkeyManager**: Registers and handles the global `Cmd+~` hotkey using CGEventTap
3. **OverlayWindow**: Displays the window switcher UI with thumbnails
4. **WindowInfo**: Captures and manages window screenshots using CGWindowListCreateImage

### Window Detection

- Uses macOS Accessibility APIs to track window focus changes
- Filters out windows without titles (like menulets and helper windows)
- Maintains a stack of up to 10 recently used windows
- Automatically updates when windows are opened or closed

### Screenshot Capture

- Captures window thumbnails using CGWindowListCreateImage (deprecated but functional)
- Implements smart caching to improve performance
- Cache is invalidated on each switcher open to show current window state
- Scales thumbnails to 200x155px to reduce memory usage

## Project Structure

```
MacAppSwitcher/
├── MacAppSwitcher/
│   ├── main.swift              # App entry point
│   ├── AppDelegate.swift       # Main coordinator
│   ├── HotkeyManager.swift     # Global hotkey handling
│   ├── WindowTracker.swift     # Window focus tracking
│   ├── WindowInfo.swift        # Window data & screenshots
│   ├── OverlayWindow.swift     # UI display
│   └── AppTracker.swift        # Application tracking
├── MacAppSwitcher.entitlements # Required permissions
└── info.plist                  # App configuration
```

## Development

### Entitlements

The app requires the following entitlements (configured in `MacAppSwitcher.entitlements`):

```xml
<key>com.apple.security.app-sandbox</key>
<false/>  <!-- Disabled for Accessibility API access -->
<key>com.apple.security.cs.allow-jit</key>
<true/>
<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
<true/>
```

> **Important**: App Sandbox must be disabled for the app to access Accessibility APIs and capture window screenshots.

### Building for Release

1. Set the scheme to "Release"
2. Archive the project: **Product** > **Archive**
3. Export the app bundle
4. (Optional) Code sign and notarize for distribution

## Troubleshooting

### Hotkey Not Working

- **Check Accessibility permission**: System Settings > Privacy & Security > Accessibility
- **Restart the app** after granting permission
- **Remove old entries**: During development, each build creates a new signature. Remove old entries and re-add the current build.

### No Window Thumbnails

- **Check Screen Recording permission**: System Settings > Privacy & Security > Screen Recording
- **Restart the app** after granting permission
- Without this permission, app icons will be shown instead of window screenshots

### Overlay Not Appearing

- Ensure at least one other window is open to switch to
- Check Console.app for error messages
- Verify that both Accessibility and Screen Recording permissions are granted

### Development Builds

During development, macOS may require re-granting permissions after each build due to code signature changes. This is normal security behavior.

## Known Limitations

- CGWindowListCreateImage is deprecated in macOS 15.0+ but still functional
- Requires App Sandbox to be disabled for full functionality
- Each development build may require re-granting permissions
- Some system windows (like Notification Center) cannot be captured

## Future Enhancements

Potential improvements for future versions:
- [ ] Customizable hotkey configuration
- [ ] Window filtering options
- [ ] Support for ScreenCaptureKit (modern alternative to CGWindowListCreateImage)
- [ ] Configurable number of windows to display
- [ ] Search/filter windows by name
- [ ] Support for multiple displays

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
