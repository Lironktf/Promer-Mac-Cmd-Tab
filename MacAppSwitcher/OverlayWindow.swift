//
//  OverlayWindow.swift
//  MacAppSwitcher
//
//  Creates and manages the overlay window that displays the window switcher UI.
//  Shows a semi-transparent, centered, floating window with window thumbnails
//  in a horizontal layout, similar to Windows Alt+Tab. Highlights the current selection.
//

import Cocoa

/// Manages the overlay window that displays the window switcher interface
/// Creates a floating window with thumbnail previews of each window
class OverlayWindow {
    /// The overlay window instance
    private var window: NSWindow?

    /// Stack view containing the window preview cards
    private var stackView: NSStackView?

    /// Array of window preview views
    private var windowViews: [WindowPreviewView] = []

    /// Currently selected index (highlighted)
    private var selectedIndex: Int = 0

    /// Currently displayed windows
    private var currentWindows: [WindowInfo] = []

    /// Thumbnail cache to avoid recapturing screenshots
    /// Key: windowID, Value: cached thumbnail image
    private static var thumbnailCache: [CGWindowID: NSImage] = [:]

    /// Maximum cache size (number of thumbnails to keep)
    private static let maxCacheSize = 20

    /// Shows the overlay window with the provided windows
    /// - Parameter windows: Array of windows to display (up to 10)
    func show(with windows: [WindowInfo]) {
        // Wrap entire operation in autoreleasepool to release temporary objects
        autoreleasepool {
            currentWindows = windows

            // Clear cache for windows being displayed to ensure fresh captures
            // This prevents showing stale screenshots when window content has changed
            clearCacheForWindows(windows)

            // Only create window if it doesn't exist yet
            // This prevents memory leaks from creating multiple windows
            if window == nil {
                createWindow(for: windows.count)
            } else {
                // Window exists, just resize if needed
                resizeWindow(for: windows.count)
            }

            // Update the display with current windows
            updateWindowPreviews(with: windows)

            // Reset selection to first window
            selectedIndex = 0
            updateHighlight()

            // Show and center the window
            window?.center()
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Hides the overlay window and releases memory
    func hide() {
        window?.orderOut(nil)

        // Clean up window views to release memory
        windowViews.forEach { view in
            view.cleanup()
            view.removeFromSuperview()
        }
        windowViews.removeAll()
        currentWindows.removeAll()

        // Trim cache if it's getting too large
        if Self.thumbnailCache.count > Self.maxCacheSize {
            // Remove oldest entries (simple strategy: clear half the cache)
            let sortedKeys = Array(Self.thumbnailCache.keys.prefix(Self.maxCacheSize / 2))
            sortedKeys.forEach { Self.thumbnailCache.removeValue(forKey: $0) }
        }
    }

    /// Clears cache entries for specific windows to force fresh captures
    /// - Parameter windows: Windows whose cache entries should be removed
    private func clearCacheForWindows(_ windows: [WindowInfo]) {
        for window in windows {
            Self.thumbnailCache.removeValue(forKey: window.windowID)
        }
    }

    /// Gets a cached thumbnail or captures a new one
    /// - Parameter window: The window to get thumbnail for
    /// - Returns: Cached or newly captured thumbnail, scaled to target size
    static func getCachedThumbnail(for window: WindowInfo) -> NSImage? {
        // Check cache first
        if let cached = thumbnailCache[window.windowID] {
            return cached
        }

        // Not in cache - capture new thumbnail
        guard let thumbnail = window.captureThumbnail() else {
            return nil
        }

        // Scale down immediately to save memory (200x155 target size)
        let targetSize = NSSize(width: 200, height: 155)
        let scaled = scaleImageToFit(thumbnail, targetSize: targetSize)

        // Cache the scaled version
        thumbnailCache[window.windowID] = scaled

        return scaled
    }

    /// Scales an image to fit within target size while maintaining aspect ratio
    /// This is a static version used before WindowPreviewView creation
    private static func scaleImageToFit(_ image: NSImage, targetSize: NSSize) -> NSImage {
        return autoreleasepool {
            let sourceSize = image.size

            // Calculate aspect ratios
            let sourceAspect = sourceSize.width / sourceSize.height
            let targetAspect = targetSize.width / targetSize.height

            var newSize: NSSize

            if sourceAspect > targetAspect {
                // Image is wider - fit to width
                newSize = NSSize(
                    width: targetSize.width,
                    height: targetSize.width / sourceAspect
                )
            } else {
                // Image is taller - fit to height
                newSize = NSSize(
                    width: targetSize.height * sourceAspect,
                    height: targetSize.height
                )
            }

            // Create new image with proper size
            let newImage = NSImage(size: newSize)
            newImage.lockFocus()

            image.draw(
                in: NSRect(origin: .zero, size: newSize),
                from: NSRect(origin: .zero, size: sourceSize),
                operation: .copy,
                fraction: 1.0
            )

            newImage.unlockFocus()
            return newImage
        }
    }

    /// Cycles to the next window in the list
    /// Wraps around to the beginning when reaching the end
    func selectNext() {
        guard !currentWindows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % currentWindows.count
        updateHighlight()
    }

    /// Cycles to the previous window in the list
    /// Wraps around to the end when reaching the beginning
    func selectPrevious() {
        guard !currentWindows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + currentWindows.count) % currentWindows.count
        updateHighlight()
    }

    /// Gets the currently selected window
    /// - Returns: The selected WindowInfo, or nil if none selected
    func getSelectedWindow() -> WindowInfo? {
        guard selectedIndex >= 0 && selectedIndex < currentWindows.count else {
            return nil
        }
        return currentWindows[selectedIndex]
    }

    /// Creates the overlay window with appropriate properties
    /// Configures the window to be floating, semi-transparent, and non-activating
    /// - Parameter windowCount: Number of windows to display (adjusts size accordingly)
    private func createWindow(for windowCount: Int = 5) {
        // Calculate grid dimensions
        let cardsPerRow = 5
        let rowCount = (windowCount + cardsPerRow - 1) / cardsPerRow  // Ceiling division

        // Each card is 216px wide, spacing is 25px
        let cardWidth: CGFloat = 216
        let cardHeight: CGFloat = 220
        let horizontalSpacing: CGFloat = 25
        let verticalSpacing: CGFloat = 20
        let sidePadding: CGFloat = 80
        let verticalPadding: CGFloat = 60

        // Calculate window dimensions
        // For multi-row layouts, always use full row width (5 cards)
        // For single row, use actual window count
        let cardsPerRowToDisplay = min(windowCount, cardsPerRow)
        let windowWidth = CGFloat(cardsPerRowToDisplay) * cardWidth + CGFloat(cardsPerRowToDisplay - 1) * horizontalSpacing + sidePadding
        let windowHeight = CGFloat(rowCount) * cardHeight + CGFloat(rowCount - 1) * verticalSpacing + verticalPadding

        // Create window with specific style
        let windowRect = NSRect(
            x: 0,
            y: 0,
            width: windowWidth,
            height: windowHeight
        )

        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        guard let window = window else { return }

        // Configure window properties with backdrop blur
        window.backgroundColor = .clear  // Clear background to allow rounded corners to show properly
        window.isOpaque = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.hasShadow = true
        window.isMovable = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        // Create content view with rounded corners and blur effect
        let contentView = NSView(frame: windowRect)
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 20
        contentView.layer?.masksToBounds = true

        // Add visual effect view for backdrop blur
        let blurView = NSVisualEffectView(frame: windowRect)
        blurView.material = .hudWindow
        blurView.state = .active
        blurView.blendingMode = .behindWindow
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = 20
        blurView.layer?.masksToBounds = true
        contentView.addSubview(blurView, positioned: .below, relativeTo: nil)

        window.contentView = contentView

        // Create vertical stack view to hold rows
        let stackViewRect = NSRect(
            x: 40,
            y: 30,
            width: windowWidth - 80,
            height: windowHeight - 60
        )

        stackView = NSStackView(frame: stackViewRect)
        guard let stackView = stackView else { return }

        stackView.orientation = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 20  // vertical spacing between rows
        stackView.alignment = .centerX

        contentView.addSubview(stackView)
    }

    /// Resizes the existing window for a different number of windows
    /// - Parameter windowCount: Number of windows to display
    private func resizeWindow(for windowCount: Int) {
        guard let window = window,
              let stackView = stackView,
              let contentView = window.contentView else { return }

        // Calculate grid dimensions
        let cardsPerRow = 5
        let rowCount = (windowCount + cardsPerRow - 1) / cardsPerRow

        // Dimensions
        let cardWidth: CGFloat = 216
        let cardHeight: CGFloat = 220
        let horizontalSpacing: CGFloat = 25
        let verticalSpacing: CGFloat = 20
        let sidePadding: CGFloat = 80
        let verticalPadding: CGFloat = 60

        // Calculate window dimensions
        // For multi-row layouts, always use full row width (5 cards)
        // For single row, use actual window count
        let cardsPerRowToDisplay = min(windowCount, cardsPerRow)
        let windowWidth = CGFloat(cardsPerRowToDisplay) * cardWidth + CGFloat(cardsPerRowToDisplay - 1) * horizontalSpacing + sidePadding
        let windowHeight = CGFloat(rowCount) * cardHeight + CGFloat(rowCount - 1) * verticalSpacing + verticalPadding

        // Update window frame
        let windowRect = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
        window.setFrame(windowRect, display: false)

        // Update content view and blur view frames
        contentView.frame = windowRect
        if let blurView = contentView.subviews.first(where: { $0 is NSVisualEffectView }) {
            blurView.frame = windowRect
        }

        // Update stack view frame
        let stackViewRect = NSRect(x: 40, y: 30, width: windowWidth - 80, height: windowHeight - 60)
        stackView.frame = stackViewRect
    }

    /// Updates the preview views with window thumbnails
    /// - Parameter windows: Array of windows to display
    private func updateWindowPreviews(with windows: [WindowInfo]) {
        guard let stackView = stackView else { return }

        // Clean up old views first to release memory
        autoreleasepool {
            windowViews.forEach { view in
                view.cleanup()
                view.removeFromSuperview()
            }
            stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        }
        windowViews.removeAll()

        // Create rows of 5 cards each
        let cardsPerRow = 5
        var currentRow: NSStackView?

        for (index, window) in windows.enumerated() {
            // Create new horizontal row every 5 cards
            if index % cardsPerRow == 0 {
                currentRow = NSStackView()
                currentRow?.orientation = .horizontal
                currentRow?.distribution = .fillEqually
                currentRow?.spacing = 25  // horizontal spacing between cards
                currentRow?.alignment = .centerY
                stackView.addView(currentRow!, in: .top)
            }

            // Create and add window preview card to current row
            let previewView = WindowPreviewView(window: window)
            windowViews.append(previewView)
            currentRow?.addView(previewView, in: .trailing)
        }

        // Update stack view layout
        stackView.needsLayout = true
    }

    /// Updates the highlight to show the currently selected window
    private func updateHighlight() {
        for (index, view) in windowViews.enumerated() {
            view.setSelected(index == selectedIndex)
        }
    }
}

/// A custom view that displays a window preview card with thumbnail, icon, and title
class WindowPreviewView: NSView {
    private let windowInfo: WindowInfo
    private var thumbnailImageView: NSImageView?
    private var iconImageView: NSImageView?
    private var titleLabel: NSTextField?
    private var selectionBorder: NSBox?

    init(window: WindowInfo) {
        self.windowInfo = window
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = NSColor.darkGray.withAlphaComponent(0.25).cgColor

        // Selection border (hidden by default) with glow effect
        selectionBorder = NSBox(frame: bounds)
        selectionBorder?.boxType = .custom
        selectionBorder?.borderType = .lineBorder
        selectionBorder?.borderColor = NSColor.systemBlue
        selectionBorder?.borderWidth = 4
        selectionBorder?.cornerRadius = 12
        selectionBorder?.fillColor = .clear
        selectionBorder?.isHidden = true
        selectionBorder?.autoresizingMask = [.width, .height]
        selectionBorder?.wantsLayer = true
        selectionBorder?.layer?.shadowColor = NSColor.systemBlue.cgColor
        selectionBorder?.layer?.shadowOpacity = 0.8
        selectionBorder?.layer?.shadowOffset = .zero
        selectionBorder?.layer?.shadowRadius = 8
        if let border = selectionBorder {
            addSubview(border)
        }

        // Thumbnail image view (window screenshot) - properly scaled and centered
        thumbnailImageView = NSImageView(frame: NSRect(x: 8, y: 50, width: 200, height: 155))
        thumbnailImageView?.imageScaling = .scaleProportionallyUpOrDown
        thumbnailImageView?.imageAlignment = .alignCenter
        thumbnailImageView?.imageFrameStyle = .none
        thumbnailImageView?.wantsLayer = true
        thumbnailImageView?.layer?.cornerRadius = 8
        thumbnailImageView?.layer?.masksToBounds = true
        thumbnailImageView?.layer?.borderColor = NSColor.gray.withAlphaComponent(0.4).cgColor
        thumbnailImageView?.layer?.borderWidth = 1
        thumbnailImageView?.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.4).cgColor

        // Get cached thumbnail (or capture new one if not cached)
        // This dramatically reduces memory usage by avoiding repeated captures
        if let cachedThumbnail = OverlayWindow.getCachedThumbnail(for: windowInfo) {
            thumbnailImageView?.image = cachedThumbnail
        } else {
            // Fallback: show app icon if thumbnail fails
            thumbnailImageView?.image = windowInfo.app.icon
        }

        if let thumbnailView = thumbnailImageView {
            addSubview(thumbnailView)
        }

        // App icon (small, overlaid on bottom-left of thumbnail)
        iconImageView = NSImageView(frame: NSRect(x: 14, y: 56, width: 32, height: 32))
        iconImageView?.image = windowInfo.app.icon
        iconImageView?.imageScaling = .scaleProportionallyDown
        iconImageView?.wantsLayer = true
        iconImageView?.layer?.cornerRadius = 6
        iconImageView?.layer?.masksToBounds = true
        iconImageView?.layer?.borderColor = NSColor.black.cgColor
        iconImageView?.layer?.borderWidth = 2
        iconImageView?.layer?.shadowColor = NSColor.black.cgColor
        iconImageView?.layer?.shadowOpacity = 0.6
        iconImageView?.layer?.shadowOffset = NSSize(width: 0, height: -2)
        iconImageView?.layer?.shadowRadius = 3
        if let iconView = iconImageView {
            addSubview(iconView)
        }

        // Title label - ALL WHITE TEXT, larger font, proper wrapping
        let titleText = windowInfo.title.isEmpty ? windowInfo.appName : windowInfo.title
        titleLabel = NSTextField(wrappingLabelWithString: titleText)
        titleLabel?.frame = NSRect(x: 8, y: 12, width: 200, height: 32)
        titleLabel?.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel?.textColor = .white  // Always white!
        titleLabel?.alignment = .center
        titleLabel?.lineBreakMode = .byWordWrapping
        titleLabel?.maximumNumberOfLines = 2
        titleLabel?.usesSingleLineMode = false
        if let label = titleLabel {
            addSubview(label)
        }
    }

    func setSelected(_ selected: Bool) {
        selectionBorder?.isHidden = !selected

        if selected {
            // Selected: blue glow, bold white text, brighter background
            layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.15).cgColor
            titleLabel?.textColor = .white  // Keep white, not yellow!
            titleLabel?.font = NSFont.systemFont(ofSize: 13, weight: .bold)

            // Add subtle scale effect
            layer?.transform = CATransform3DMakeScale(1.02, 1.02, 1.0)
        } else {
            // Not selected: darker background, regular white text
            layer?.backgroundColor = NSColor.darkGray.withAlphaComponent(0.25).cgColor
            titleLabel?.textColor = .white  // Always white
            titleLabel?.font = NSFont.systemFont(ofSize: 12, weight: .medium)

            // Reset scale
            layer?.transform = CATransform3DIdentity
        }
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: 216, height: 220)  // 35% larger
    }

    /// Cleanup method to release image memory
    func cleanup() {
        // Clear images to release memory
        thumbnailImageView?.image = nil
        iconImageView?.image = nil

        // Remove all subviews
        thumbnailImageView?.removeFromSuperview()
        iconImageView?.removeFromSuperview()
        titleLabel?.removeFromSuperview()
        selectionBorder?.removeFromSuperview()

        thumbnailImageView = nil
        iconImageView = nil
        titleLabel = nil
        selectionBorder = nil
    }

    /// Resizes an image to fit within target size while maintaining aspect ratio
    /// Uses autoreleasepool to ensure original large image is released immediately
    private func resizeImageToFit(_ image: NSImage, targetSize: NSSize) -> NSImage {
        return autoreleasepool {
            let sourceSize = image.size

            // Calculate aspect ratios
            let sourceAspect = sourceSize.width / sourceSize.height
            let targetAspect = targetSize.width / targetSize.height

            var newSize: NSSize

            if sourceAspect > targetAspect {
                // Image is wider - fit to width
                newSize = NSSize(
                    width: targetSize.width,
                    height: targetSize.width / sourceAspect
                )
            } else {
                // Image is taller - fit to height
                newSize = NSSize(
                    width: targetSize.height * sourceAspect,
                    height: targetSize.height
                )
            }

            // Create new image with proper size
            let newImage = NSImage(size: newSize)
            newImage.lockFocus()

            image.draw(
                in: NSRect(origin: .zero, size: newSize),
                from: NSRect(origin: .zero, size: sourceSize),
                operation: .copy,
                fraction: 1.0
            )

            newImage.unlockFocus()
            return newImage
        }
    }
}
