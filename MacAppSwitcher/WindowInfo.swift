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

    /// Creates a new WindowInfo instance
    init(app: NSRunningApplication, title: String, windowID: CGWindowID, axWindow: AXUIElement) {
        self.app = app
        self.title = title
        self.windowID = windowID
        self.axWindow = axWindow
    }

    /// Display name combining app and window title
    var displayName: String {
        let appName = app.localizedName ?? app.bundleIdentifier ?? "Unknown"
        if title.isEmpty {
            return appName
        }
        return "\(appName) - \(title)"
    }

    /// App name only
    var appName: String {
        return app.localizedName ?? app.bundleIdentifier ?? "Unknown"
    }

    /// Captures a thumbnail image of this window
    /// - Returns: NSImage of the window, or nil if capture fails
    func captureThumbnail() -> NSImage? {
        // Even though CGWindowListCreateImage is deprecated in macOS 15.0+,
        // it still works and is the simplest way to capture window screenshots.
        // We'll use it with @available checks disabled for now.

        // Try to capture the actual window screenshot
        if let screenshot = captureWindowScreenshot() {
            return screenshot
        }

        // Fallback to placeholder if screenshot fails
        return createPlaceholderThumbnail()
    }

    /// Captures actual window screenshot using CGWindowListCreateImage
    /// This API is deprecated but still functional in macOS 15
    private func captureWindowScreenshot() -> NSImage? {
        print("🔍 Attempting to capture screenshot for window ID: \(windowID)")

        // Create a CGImage of just this window
        let windowImage = createWindowImage(windowID)

        guard let cgImage = windowImage else {
            print("⚠️ Failed to capture window \(windowID) - createWindowImage returned nil")
            print("   This usually means Screen Recording permission is not granted")
            return nil
        }

        print("✅ Successfully captured window \(windowID) - size: \(cgImage.width)x\(cgImage.height)")

        // Convert to NSImage
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        return NSImage(cgImage: cgImage, size: size)
    }

    /// Creates a CGImage from a window ID using the deprecated but functional API
    private func createWindowImage(_ windowID: CGWindowID) -> CGImage? {
        // Import the function from the C library
        // This is a workaround to use the deprecated CGWindowListCreateImage

        // Define the function signature
        typealias CGWindowListCreateImageFunc = @convention(c) (
            CGRect,
            CGWindowListOption,
            CGWindowID,
            CGWindowImageOption
        ) -> CGImage?

        // Get the function pointer using dlsym
        let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
        guard let functionPointer = dlsym(RTLD_DEFAULT, "CGWindowListCreateImage") else {
            print("❌ Failed to load CGWindowListCreateImage function")
            return nil
        }

        // Cast to the function type
        let createImageFunc = unsafeBitCast(functionPointer, to: CGWindowListCreateImageFunc.self)

        // Call the function
        // CGRect.null means capture the entire window bounds
        // .optionIncludingWindow means include only this specific window
        // .bestResolution gives us the highest quality image
        let image = createImageFunc(
            CGRect.null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        )

        if image == nil {
            print("❌ CGWindowListCreateImage returned nil for window \(windowID)")
            print("   Possible causes:")
            print("   1. Screen Recording permission not granted")
            print("   2. Window may be hidden or minimized")
            print("   3. Invalid window ID")
        }

        return image
    }

    /// Creates a placeholder thumbnail with app icon and gradient
    /// Used as fallback when screenshot capture fails
    private func createPlaceholderThumbnail() -> NSImage? {
        let size = NSSize(width: 280, height: 210)
        let image = NSImage(size: size)

        image.lockFocus()

        // Draw gradient background
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.2, green: 0.25, blue: 0.35, alpha: 1.0),
            NSColor(calibratedRed: 0.15, green: 0.18, blue: 0.25, alpha: 1.0)
        ])
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 135)

        // Draw app icon in the center (larger)
        if let appIcon = app.icon {
            let iconSize: CGFloat = 80
            let iconRect = NSRect(
                x: (size.width - iconSize) / 2,
                y: (size.height - iconSize) / 2,
                width: iconSize,
                height: iconSize
            )
            appIcon.draw(in: iconRect)
        }

        // Draw app name at the bottom
        let appName = app.localizedName ?? "Unknown"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.9)
        ]
        let textSize = (appName as NSString).size(withAttributes: attributes)
        let textRect = NSRect(
            x: (size.width - textSize.width) / 2,
            y: 15,
            width: textSize.width,
            height: textSize.height
        )
        (appName as NSString).draw(in: textRect, withAttributes: attributes)

        image.unlockFocus()

        return image
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
