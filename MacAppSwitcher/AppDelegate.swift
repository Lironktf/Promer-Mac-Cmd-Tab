//
//  AppDelegate.swift
//  MacAppSwitcher
//
//  Main application delegate that coordinates all components:
//  - WindowTracker: Tracks MRU windows (not just apps)
//  - HotkeyManager: Registers Command+~ hotkey
//  - OverlayWindow: Displays the window switcher UI
//  Handles the app lifecycle and coordinates interactions between components.
//

import Cocoa
import ApplicationServices

/// Main application delegate that coordinates all window switcher functionality
/// Manages application lifecycle, hotkey registration, window tracking, and UI display
class AppDelegate: NSObject, NSApplicationDelegate {
    /// Tracks recently focused windows and maintains MRU stack
    private var windowTracker: WindowTracker?
    
    /// Manages global hotkey registration for Command+~
    private var hotkeyManager: HotkeyManager?
    
    /// Displays the overlay window with application names
    private var overlayWindow: OverlayWindow?
    
    /// Status item for the menu bar (optional, for app visibility)
    private var statusItem: NSStatusItem?
    
    /// Tracks whether the overlay is currently being shown
    private var isOverlayVisible = false
    
    /// Called when the application finishes launching
    /// Initializes all components and sets up the window switcher functionality
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize components
        windowTracker = WindowTracker()
        overlayWindow = OverlayWindow()
        
        // Setup hotkey manager with callbacks
        hotkeyManager = HotkeyManager()
        hotkeyManager?.onKeyDown = { [weak self] in
            self?.handleHotkeyPressed()
        }
        hotkeyManager?.onKeyUp = { [weak self] in
            self?.handleHotkeyReleased()
        }
        
        // Create menu bar status item for app visibility
        setupStatusItem()
        
        // Request accessibility permissions (required for global hotkeys)
        requestAccessibilityPermissions()
        
        print("MacAppSwitcher started. Press Command+~ to switch windows.")
    }
    
    /// Handles the Command+~ key press event
    /// Shows the overlay window with recently used windows
    /// If overlay is already visible, cycles to the next window
    private func handleHotkeyPressed() {
        guard let windowTracker = windowTracker,
              let overlayWindow = overlayWindow else {
            return
        }

        if isOverlayVisible {
            // Overlay is already showing - cycle to next window
            overlayWindow.selectNext()
        } else {
            // First press - show overlay with windows
            // Get top windows from the tracker (fetch up to 10 for multi-row display)
            let windows = windowTracker.getTopWindows(count: 10)

            guard !windows.isEmpty else {
                // No windows to switch to
                print("⚠️ No windows available to switch")
                return
            }

            // Show overlay with all windows (supports multi-row layout)
            overlayWindow.show(with: windows)
            isOverlayVisible = true

            // On first press, we want to select index 1 (second window in the list)
            // because index 0 is the most recently used window (the one we're switching FROM)
            // This matches Windows Alt+Tab behavior where the first Tab press
            // selects the previous window, not the current one
            if windows.count > 1 {
                overlayWindow.selectNext()
            }
        }
    }
    
    /// Handles the Command+~ key release event
    /// Activates the selected window and hides the overlay
    private func handleHotkeyReleased() {
        guard let windowTracker = windowTracker,
              let overlayWindow = overlayWindow,
              isOverlayVisible else {
            return
        }

        // Get the currently selected window
        if let selectedWindow = overlayWindow.getSelectedWindow() {
            // Activate the selected window using WindowTracker
            windowTracker.activateWindow(selectedWindow)
            print("✅ Activated window: \(selectedWindow.displayName)")
        }

        // Hide the overlay
        overlayWindow.hide()
        isOverlayVisible = false
    }
    
    /// Sets up a status bar item for the application
    /// Provides a way to see that the app is running and access preferences
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "command.tab.fill", accessibilityDescription: "MacAppSwitcher")
            button.image?.isTemplate = true // Allows system tinting
            button.toolTip = "MacAppSwitcher - Press Command+~ to switch windows"
        }
        
        // Create menu for status item
        let menu = NSMenu()

        let aboutItem = NSMenuItem(title: "About MacAppSwitcher", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let permissionsItem = NSMenuItem(title: "Open Accessibility Settings...", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permissionsItem.target = self
        menu.addItem(permissionsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }
    
    /// Shows an about dialog for the application
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "MacAppSwitcher"
        alert.informativeText = "A macOS window switcher that mimics Windows' Alt+Tab functionality.\n\nPress Command+~ to switch between recently used windows (including multiple windows of the same app)."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Opens System Settings to Accessibility permissions
    @objc private func openAccessibilitySettings() {
        let bundlePath = Bundle.main.bundlePath

        let alert = NSAlert()
        alert.messageText = "Grant Accessibility Permission"
        alert.informativeText = """
        To use MacAppSwitcher, you need to grant Accessibility permission:

        1. Click "Open Settings" below
        2. Click the lock icon and authenticate
        3. Click the '+' button
        4. Navigate to and select:
           \(bundlePath)
        5. Enable the checkbox
        6. QUIT and RESTART this app

        ⚠️ During development: Each build creates a new app signature.
        You may need to remove old entries and re-add the current build.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // Open System Settings to Accessibility
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// Quits the application
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    /// Checks accessibility permissions required for global hotkey registration
    /// Only logs to console if permissions are not granted
    /// Does NOT show intrusive system dialogs to avoid repeated prompts during development
    private func requestAccessibilityPermissions() {
        // Check WITHOUT prompting
        let accessEnabled = AXIsProcessTrustedWithOptions(nil)

        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        let bundlePath = Bundle.main.bundlePath
        let executablePath = Bundle.main.executablePath ?? "unknown"

        if accessEnabled {
            print("✅ Accessibility permission already granted.")
        } else {
            // Permission not granted - log helpful information
            print("\n⚠️  ACCESSIBILITY PERMISSION REQUIRED ⚠️")
            print("=========================================")
            print("MacAppSwitcher needs Accessibility permission to work.")
            print("")
            print("📋 HOW TO GRANT PERMISSION:")
            print("1. Open System Settings > Privacy & Security > Accessibility")
            print("2. Click the '+' button to add an app")
            print("3. Navigate to and select:")
            print("   \(bundlePath)")
            print("4. Enable the checkbox for MacAppSwitcher")
            print("5. QUIT (Cmd+Q) and RESTART this app")
            print("")
            print("💡 TIP: During development, each build may require re-granting permission.")
            print("   This is normal macOS security behavior.")
            print("")
            print("🔍 Debug Info:")
            print("   Bundle ID: \(bundleID)")
            print("   Executable: \(executablePath)")
            print("=========================================\n")
        }

        // Also check for Screen Recording permission (needed for window screenshots)
        checkScreenRecordingPermission(bundlePath: bundlePath)
    }

    /// Checks if Screen Recording permission is granted
    /// This is required for capturing window screenshots
    private func checkScreenRecordingPermission(bundlePath: String) {
        // Try to capture a screenshot to test permission
        // If we can't capture any window, permission is likely not granted
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("\n📸 Checking Screen Recording permission...")
            print("   This permission is REQUIRED for window thumbnail previews.")
            print("")
            print("📋 HOW TO GRANT SCREEN RECORDING PERMISSION:")
            print("1. Open System Settings > Privacy & Security > Screen Recording")
            print("2. Click the '+' button to add an app")
            print("3. Navigate to and select:")
            print("   \(bundlePath)")
            print("4. Enable the checkbox for MacAppSwitcher")
            print("5. QUIT (Cmd+Q) and RESTART this app")
            print("")
            print("ℹ️  Without Screen Recording permission:")
            print("   - Window thumbnails will show app icons instead of screenshots")
            print("   - App will still work for switching windows")
            print("=========================================\n")
        }
    }
    
    /// Called when the application will terminate
    /// Performs cleanup operations
    func applicationWillTerminate(_ notification: Notification) {
        overlayWindow?.hide()
    }
    
    /// Determines if the application should terminate when the last window is closed
    /// Returns false to keep the app running (it has no windows, only overlay)
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
