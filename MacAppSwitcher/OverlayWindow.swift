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

    /// Shows the overlay window with the provided windows
    /// - Parameter windows: Array of windows to display (up to 5)
    func show(with windows: [WindowInfo]) {
        currentWindows = windows

        // Create window if it doesn't exist
        if window == nil {
            createWindow()
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

    /// Hides the overlay window
    func hide() {
        window?.orderOut(nil)
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
    private func createWindow() {
        // Window dimensions - larger to accommodate thumbnails
        let windowWidth: CGFloat = 900
        let windowHeight: CGFloat = 260

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

        // Configure window properties
        window.backgroundColor = NSColor.black.withAlphaComponent(0.85)
        window.isOpaque = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.hasShadow = true
        window.isMovable = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        // Create content view with rounded corners
        let contentView = NSView(frame: windowRect)
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 16
        contentView.layer?.masksToBounds = true
        window.contentView = contentView

        // Create stack view for horizontal layout
        let stackViewRect = NSRect(
            x: 30,
            y: 20,
            width: windowWidth - 60,
            height: windowHeight - 40
        )

        stackView = NSStackView(frame: stackViewRect)
        guard let stackView = stackView else { return }

        stackView.orientation = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 20
        stackView.alignment = .centerY

        contentView.addSubview(stackView)
    }

    /// Updates the preview views with window thumbnails
    /// - Parameter windows: Array of windows to display
    private func updateWindowPreviews(with windows: [WindowInfo]) {
        guard let stackView = stackView else { return }

        // Remove existing views
        windowViews.forEach { $0.removeFromSuperview() }
        windowViews.removeAll()

        // Create preview view for each window
        for window in windows {
            let previewView = WindowPreviewView(window: window)
            windowViews.append(previewView)
            stackView.addView(previewView, in: .leading)
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
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.darkGray.withAlphaComponent(0.3).cgColor

        // Selection border (hidden by default)
        selectionBorder = NSBox(frame: bounds)
        selectionBorder?.boxType = .custom
        selectionBorder?.borderType = .lineBorder
        selectionBorder?.borderColor = NSColor.systemBlue
        selectionBorder?.borderWidth = 3
        selectionBorder?.cornerRadius = 8
        selectionBorder?.fillColor = .clear
        selectionBorder?.isHidden = true
        selectionBorder?.autoresizingMask = [.width, .height]
        if let border = selectionBorder {
            addSubview(border)
        }

        // Thumbnail image view (window screenshot)
        thumbnailImageView = NSImageView(frame: NSRect(x: 10, y: 50, width: 140, height: 105))
        thumbnailImageView?.imageScaling = .scaleProportionallyUpOrDown
        thumbnailImageView?.wantsLayer = true
        thumbnailImageView?.layer?.cornerRadius = 4
        thumbnailImageView?.layer?.masksToBounds = true
        thumbnailImageView?.layer?.borderColor = NSColor.gray.withAlphaComponent(0.5).cgColor
        thumbnailImageView?.layer?.borderWidth = 1

        // Capture thumbnail
        if let thumbnail = windowInfo.captureThumbnail() {
            thumbnailImageView?.image = thumbnail
        } else {
            // Fallback: show app icon if thumbnail fails
            thumbnailImageView?.image = windowInfo.app.icon
        }

        if let thumbnailView = thumbnailImageView {
            addSubview(thumbnailView)
        }

        // App icon (small, overlaid on bottom-left of thumbnail)
        iconImageView = NSImageView(frame: NSRect(x: 15, y: 55, width: 24, height: 24))
        iconImageView?.image = windowInfo.app.icon
        iconImageView?.imageScaling = .scaleProportionallyUpOrDown
        iconImageView?.wantsLayer = true
        iconImageView?.layer?.cornerRadius = 4
        iconImageView?.layer?.masksToBounds = true
        iconImageView?.layer?.borderColor = NSColor.black.cgColor
        iconImageView?.layer?.borderWidth = 1
        if let iconView = iconImageView {
            addSubview(iconView)
        }

        // Title label
        titleLabel = NSTextField(labelWithString: windowInfo.title.isEmpty ? windowInfo.appName : windowInfo.title)
        titleLabel?.frame = NSRect(x: 10, y: 20, width: 140, height: 40)
        titleLabel?.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        titleLabel?.textColor = .white
        titleLabel?.alignment = .center
        titleLabel?.lineBreakMode = .byTruncatingTail
        titleLabel?.maximumNumberOfLines = 2
        if let label = titleLabel {
            addSubview(label)
        }

        // App name label (smaller, below title)
        let appLabel = NSTextField(labelWithString: windowInfo.appName)
        appLabel.frame = NSRect(x: 10, y: 5, width: 140, height: 14)
        appLabel.font = NSFont.systemFont(ofSize: 9, weight: .regular)
        appLabel.textColor = NSColor.white.withAlphaComponent(0.7)
        appLabel.alignment = .center
        appLabel.lineBreakMode = .byTruncatingTail
        addSubview(appLabel)
    }

    func setSelected(_ selected: Bool) {
        selectionBorder?.isHidden = !selected

        if selected {
            layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.2).cgColor
            titleLabel?.textColor = .yellow
            titleLabel?.font = NSFont.systemFont(ofSize: 12, weight: .bold)
        } else {
            layer?.backgroundColor = NSColor.darkGray.withAlphaComponent(0.3).cgColor
            titleLabel?.textColor = .white
            titleLabel?.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        }
    }

    override var intrinsicContentSize: NSSize {
        return NSSize(width: 160, height: 200)
    }
}
