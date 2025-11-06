//
//  OverlayWindow.swift
//  MacAppSwitcher
//
//  Creates and manages the overlay window that displays the window switcher UI.
//  Shows a semi-transparent, centered, floating window with window titles
//  in a horizontal layout. Highlights the current selection in yellow.
//

import Cocoa

/// Manages the overlay window that displays the window switcher interface
/// Creates a floating, semi-transparent window with window titles (App - Title)
/// arranged horizontally, highlighting the currently selected window.
class OverlayWindow {
    /// The overlay window instance
    private var window: NSWindow?

    /// Stack view containing the window title labels
    private var stackView: NSStackView?

    /// Array of labels displaying window titles
    private var windowLabels: [NSTextField] = []

    /// Currently selected index (highlighted in yellow)
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
        updateWindowLabels(with: windows)

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
        // Window dimensions
        let windowWidth: CGFloat = 600
        let windowHeight: CGFloat = 120
        
        // Create window with specific style
        let windowRect = NSRect(
            x: 0,
            y: 0,
            width: windowWidth,
            height: windowHeight
        )
        
        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless], // No title bar or borders
            backing: .buffered,
            defer: false
        )
        
        guard let window = window else { return }
        
        // Configure window properties
        window.backgroundColor = NSColor.black.withAlphaComponent(0.7) // Semi-transparent black
        window.isOpaque = false // Allow transparency
        window.level = .floating // Above all other windows
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // Works across all spaces
        window.ignoresMouseEvents = true // Don't interfere with mouse clicks
        window.hasShadow = true // Add shadow for better visibility
        window.isMovable = false // Prevent moving
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        
        // Create content view with rounded corners
        let contentView = NSView(frame: windowRect)
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 12
        contentView.layer?.masksToBounds = true
        window.contentView = contentView
        
        // Create stack view for horizontal layout
        let stackViewRect = NSRect(
            x: 20,
            y: 20,
            width: windowWidth - 40,
            height: windowHeight - 40
        )
        
        stackView = NSStackView(frame: stackViewRect)
        guard let stackView = stackView else { return }
        
        stackView.orientation = .horizontal // Horizontal layout
        stackView.distribution = .fillEqually // Equal spacing
        stackView.spacing = 20 // Space between items
        stackView.alignment = .centerY // Vertically centered
        
        contentView.addSubview(stackView)
    }
    
    /// Updates the labels displaying window titles
    /// - Parameter windows: Array of windows to display
    private func updateWindowLabels(with windows: [WindowInfo]) {
        guard let stackView = stackView else { return }

        // Remove existing labels
        windowLabels.forEach { $0.removeFromSuperview() }
        windowLabels.removeAll()

        // Create labels for each window
        for window in windows {
            let label = createWindowLabel(for: window)
            windowLabels.append(label)
            stackView.addView(label, in: .leading)
        }

        // Update stack view layout
        stackView.needsLayout = true
    }

    /// Creates a label for a window
    /// - Parameter window: The window to create a label for
    /// - Returns: Configured NSTextField displaying "App - Title"
    private func createWindowLabel(for window: WindowInfo) -> NSTextField {
        // Use the displayName which formats as "App - Title"
        let label = NSTextField(labelWithString: window.displayName)
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white // Default white color
        label.alignment = .center
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.wantsLayer = true
        label.lineBreakMode = .byTruncatingMiddle // Truncate long titles in the middle
        label.maximumNumberOfLines = 2 // Allow wrapping to 2 lines

        return label
    }

    /// Updates the highlight to show the currently selected window
    /// Selected window is highlighted in yellow, others remain white
    private func updateHighlight() {
        for (index, label) in windowLabels.enumerated() {
            if index == selectedIndex {
                // Highlight selected window in yellow
                label.textColor = .yellow
                label.font = NSFont.systemFont(ofSize: 16, weight: .bold)
            } else {
                // Other windows remain white
                label.textColor = .white
                label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
            }
        }
    }
}
