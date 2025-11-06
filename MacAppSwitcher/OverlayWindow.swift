//
//  OverlayWindow.swift
//  MacAppSwitcher
//
//  Creates and manages the overlay window that displays the app switcher UI.
//  Shows a semi-transparent, centered, floating window with application names
//  in a horizontal layout. Highlights the current selection in yellow.
//

import Cocoa

/// Manages the overlay window that displays the app switcher interface
/// Creates a floating, semi-transparent window with application names
/// arranged horizontally, highlighting the currently selected app.
class OverlayWindow {
    /// The overlay window instance
    private var window: NSWindow?
    
    /// Stack view containing the application name labels
    private var stackView: NSStackView?
    
    /// Array of labels displaying application names
    private var appLabels: [NSTextField] = []
    
    /// Currently selected index (highlighted in yellow)
    private var selectedIndex: Int = 0
    
    /// Currently displayed applications
    private var currentApps: [NSRunningApplication] = []
    
    /// Shows the overlay window with the provided applications
    /// - Parameter apps: Array of applications to display (up to 5)
    func show(with apps: [NSRunningApplication]) {
        currentApps = apps
        
        // Create window if it doesn't exist
        if window == nil {
            createWindow()
        }
        
        // Update the display with current applications
        updateAppLabels(with: apps)
        
        // Reset selection to first app
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
    
    /// Cycles to the next application in the list
    /// Wraps around to the beginning when reaching the end
    func selectNext() {
        guard !currentApps.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % currentApps.count
        updateHighlight()
    }
    
    /// Cycles to the previous application in the list
    /// Wraps around to the end when reaching the beginning
    func selectPrevious() {
        guard !currentApps.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + currentApps.count) % currentApps.count
        updateHighlight()
    }
    
    /// Gets the currently selected application
    /// - Returns: The selected NSRunningApplication, or nil if none selected
    func getSelectedApp() -> NSRunningApplication? {
        guard selectedIndex >= 0 && selectedIndex < currentApps.count else {
            return nil
        }
        return currentApps[selectedIndex]
    }
    
    /// Creates the overlay window with appropriate properties
    /// Configures the window to be floating, semi-transparent, and non-activating
    private func createWindow() {
        // Calculate window size based on screen dimensions
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
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
    
    /// Updates the labels displaying application names
    /// - Parameter apps: Array of applications to display
    private func updateAppLabels(with apps: [NSRunningApplication]) {
        guard let stackView = stackView else { return }
        
        // Remove existing labels
        appLabels.forEach { $0.removeFromSuperview() }
        appLabels.removeAll()
        
        // Create labels for each application
        for app in apps {
            let label = createAppLabel(for: app)
            appLabels.append(label)
            stackView.addView(label, in: .leading)
        }
        
        // Update stack view layout
        stackView.needsLayout = true
    }
    
    /// Creates a label for an application name
    /// - Parameter app: The application to create a label for
    /// - Returns: Configured NSTextField displaying the app name
    private func createAppLabel(for app: NSRunningApplication) -> NSTextField {
        // Get application name, fallback to bundle identifier if name is unavailable
        let appName = app.localizedName ?? app.bundleIdentifier ?? "Unknown App"
        
        let label = NSTextField(labelWithString: appName)
        label.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        label.textColor = .white // Default white color
        label.alignment = .center
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.wantsLayer = true
        
        return label
    }
    
    /// Updates the highlight to show the currently selected application
    /// Selected app is highlighted in yellow, others remain white
    private func updateHighlight() {
        for (index, label) in appLabels.enumerated() {
            if index == selectedIndex {
                // Highlight selected app in yellow
                label.textColor = .yellow
                label.font = NSFont.systemFont(ofSize: 20, weight: .bold)
            } else {
                // Other apps remain white
                label.textColor = .white
                label.font = NSFont.systemFont(ofSize: 18, weight: .medium)
            }
        }
    }
}
