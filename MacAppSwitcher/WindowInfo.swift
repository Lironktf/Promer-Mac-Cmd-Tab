//
//  WindowInfo.swift
//  MacAppSwitcher
//
//  Represents a window in the MRU stack with all necessary information
//  to display and activate it. Each window belongs to an application
//  and has a title, position, and other metadata.
//

import Cocoa
import ApplicationServices

/// Represents a window with all information needed to display and activate it
struct WindowInfo: Hashable {
/// The application that owns this window
    let app: NSRunningApplication

    /// The window title (from AXTitle attribute)
    let title: String

    /// The window ID (CGWindowID) for uniquely identifying this window
    let windowID: CGWindowID

    /// AXUIElement reference to the window for activation
    let axWindow: AXUIElement

    /// Display name combining app and window title
    var displayName: String {
        let appName = app.localizedName ?? app.bundleIdentifier ?? "Unknown"
        if title.isEmpty {
            return appName
        }
        return "\(appName) - \(title)"
    }

    /// Hash based on window ID for uniqueness
    func hash(into hasher: inout Hasher) {
        hasher.combine(windowID)
    }

    /// Equality based on window ID
    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        return lhs.windowID == rhs.windowID
    }
}
