//
//  WindowTracker.swift
//  MacAppSwitcher
//
//  Tracks recently focused windows using Accessibility API and NSWorkspace notifications.
//  Maintains a Most Recently Used (MRU) stack of windows across all applications.
//  Unlike AppTracker, this tracks individual windows so two Chrome windows appear separately.
//

import Cocoa
import ApplicationServices

/// Manages the Most Recently Used (MRU) stack of windows across all applications
/// Uses Accessibility API to detect window focus changes and maintain window list
class WindowTracker {
    /// Maximum number of windows to track in the MRU stack
    private let maxWindowsToTrack = 20

    /// The MRU stack - most recently focused window is at index 0
    private var mruStack: [WindowInfo] = []

    /// Lock for thread-safe access to the MRU stack
    private let lock = NSLock()

    /// Reference to the workspace notification observer for app activation
    private var appActivationObserver: NSObjectProtocol?

    /// Timer to periodically poll for window changes (fallback)
    private var pollTimer: Timer?

    /// Last known frontmost window to detect changes
    private var lastFrontmostWindow: WindowInfo?

    /// Initializes the WindowTracker and starts observing window events
    init() {
        startTracking()
    }

    /// Begins tracking window activations
    private func startTracking() {
        // Register for application activation notifications
        let workspace = NSWorkspace.shared
        appActivationObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: workspace,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            // When an app is activated, check which window is focused
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self.updateFrontmostWindow(for: app)
            }
        }

        // Start polling timer to detect window switches within the same app
        // This is necessary because macOS doesn't provide reliable window focus notifications
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pollForWindowChanges()
        }

        // Initial population with current frontmost window
        if let frontApp = workspace.frontmostApplication {
            updateFrontmostWindow(for: frontApp)
        }
    }

    /// Polls for window changes by checking the current frontmost window
    private func pollForWindowChanges() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        updateFrontmostWindow(for: frontApp)
    }

    /// Updates the MRU stack with the currently focused window of an application
    /// - Parameter app: The application to check for focused windows
    private func updateFrontmostWindow(for app: NSRunningApplication) {
        // Skip our own application
        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            return
        }

        // Get the focused window using Accessibility API
        guard let window = getFocusedWindow(for: app) else {
            return
        }

        // Only add if it's different from the last known window
        if let lastWindow = lastFrontmostWindow, lastWindow == window {
            return
        }

        lastFrontmostWindow = window
        addToMRU(window: window)
    }

    /// Gets the currently focused window for an application using Accessibility API
    /// - Parameter app: The application to query
    /// - Returns: WindowInfo for the focused window, or nil if unavailable
    private func getFocusedWindow(for app: NSRunningApplication) -> WindowInfo? {
        // Create AXUIElement for the application
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        // Get the focused window
        var focusedWindowRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowRef
        )

        guard result == .success,
              let axWindow = focusedWindowRef as! AXUIElement? else {
            return nil
        }

        // Get window title
        var titleRef: AnyObject?
        AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef)
        let title = titleRef as? String ?? ""

        // Get window ID (for uniqueness)
        var windowIDRef: CGWindowID = 0
        let idResult = _AXUIElementGetWindow(axWindow, &windowIDRef)

        guard idResult == .success else {
            // If we can't get window ID, try to use a combination of app PID and title
            // This is a fallback for some windows that don't expose their ID
            let fallbackID = CGWindowID(app.processIdentifier) ^ CGWindowID(title.hashValue)
            return WindowInfo(app: app, title: title, windowID: fallbackID, axWindow: axWindow)
        }

        // Check if window is minimized - skip minimized windows
        var minimizedRef: AnyObject?
        AXUIElementCopyAttributeValue(axWindow, kAXMinimizedAttribute as CFString, &minimizedRef)
        if let isMinimized = minimizedRef as? Bool, isMinimized {
            return nil
        }

        return WindowInfo(app: app, title: title, windowID: windowIDRef, axWindow: axWindow)
    }

    /// Adds a window to the MRU stack
    /// If the window already exists, it's moved to the top
    /// - Parameter window: The window to add
    private func addToMRU(window: WindowInfo) {
        lock.lock()
        defer { lock.unlock() }

        // Remove if already exists
        mruStack.removeAll { $0.windowID == window.windowID }

        // Add to front
        mruStack.insert(window, at: 0)

        print("🟢 WindowTracker: Added '\(window.displayName)' to MRU stack")
        print("📊 Current MRU stack (\(mruStack.count) windows):")
        for (index, win) in mruStack.prefix(5).enumerated() {
            print("  [\(index)] \(win.displayName)")
        }

        // Trim to max size
        if mruStack.count > maxWindowsToTrack {
            mruStack.removeLast(mruStack.count - maxWindowsToTrack)
        }
    }

    /// Returns the top N windows from the MRU stack
    /// - Parameter count: Number of windows to return
    /// - Returns: Array of WindowInfo instances, most recent first
    func getTopWindows(count: Int = 5) -> [WindowInfo] {
        lock.lock()
        defer { lock.unlock() }

        return Array(mruStack.prefix(count))
    }

    /// Activates a specific window
    /// - Parameter window: The window to activate
    func activateWindow(_ window: WindowInfo) {
        // First activate the application
        window.app.activate(options: [.activateIgnoringOtherApps])

        // Then raise the specific window
        AXUIElementSetAttributeValue(
            window.axWindow,
            kAXMainAttribute as CFString,
            true as CFTypeRef
        )

        AXUIElementSetAttributeValue(
            window.axWindow,
            kAXFocusedAttribute as CFString,
            true as CFTypeRef
        )

        // Also try to raise it
        AXUIElementPerformAction(window.axWindow, kAXRaiseAction as CFString)
    }

    /// Cleans up observers and timers
    deinit {
        pollTimer?.invalidate()
        if let observer = appActivationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// Private C function to get window ID from AXUIElement
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError
