//
//  AppTracker.swift
//  MacAppSwitcher
//
//  Tracks recently activated applications using NSWorkspace notifications
//  and maintains a Most Recently Used (MRU) stack of applications.
//

import Cocoa

/// Manages the Most Recently Used (MRU) stack of applications
/// Tracks application activation events using NSWorkspace notifications
/// to build and maintain a list of recently used applications.
class AppTracker {
    /// Maximum number of applications to track in the MRU stack
    private let maxAppsToTrack = 10
    
    /// The MRU stack - most recently used app is at index 0
    /// Contains NSRunningApplication instances ordered by most recent activation
    private var mruStack: [NSRunningApplication] = []
    
    /// Lock for thread-safe access to the MRU stack
    private let lock = NSLock()
    
    /// Reference to the workspace notification observer
    private var notificationObserver: NSObjectProtocol?
    
    /// Initializes the AppTracker and starts observing application activation events
    init() {
        startTracking()
    }
    
    /// Begins tracking application activations using NSWorkspace notifications
    /// Registers for NSWorkspace.didActivateApplicationNotification to detect
    /// when applications become active and updates the MRU stack accordingly.
    private func startTracking() {
        let workspace = NSWorkspace.shared
        
        // Register for application activation notifications
        // This notification is posted whenever an application becomes active
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: workspace,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            // Extract the activated application from the notification
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self.addToMRU(app: app)
            }
        }
        
        // Initialize MRU stack with currently active application
        if let activeApp = workspace.frontmostApplication {
            addToMRU(app: activeApp)
        }
    }
    
    /// Adds an application to the MRU stack if it's not already the most recent
    /// If the app is already in the stack, it's moved to the top (most recent position)
    /// - Parameter app: The application to add to the MRU stack
    private func addToMRU(app: NSRunningApplication) {
        lock.lock()
        defer { lock.unlock() }

        // Skip if this is our own application
        // Comparing by bundle identifier to avoid self-tracking
        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            print("🔵 AppTracker: Skipping own app")
            return
        }

        // Remove the app if it already exists in the stack (to avoid duplicates)
        mruStack.removeAll { $0.processIdentifier == app.processIdentifier }

        // Add to the front (most recent position)
        mruStack.insert(app, at: 0)

        print("🟢 AppTracker: Added '\(app.localizedName ?? "Unknown")' to MRU stack")
        print("📊 Current MRU stack (\(mruStack.count) apps):")
        for (index, stackApp) in mruStack.enumerated() {
            print("  [\(index)] \(stackApp.localizedName ?? "Unknown")")
        }

        // Trim to maximum size
        if mruStack.count > maxAppsToTrack {
            mruStack.removeLast(mruStack.count - maxAppsToTrack)
        }
    }
    
    /// Returns the top N applications from the MRU stack
    /// - Parameter count: Number of applications to return (default: 5)
    /// - Returns: Array of NSRunningApplication instances, most recent first
    func getTopApps(count: Int = 5) -> [NSRunningApplication] {
        lock.lock()
        defer { lock.unlock() }
        
        // Return up to 'count' applications from the top of the stack
        return Array(mruStack.prefix(count))
    }
    
    /// Gets the current position of an application in the MRU stack
    /// - Parameter app: The application to find
    /// - Returns: The index in the MRU stack, or nil if not found
    func getAppIndex(_ app: NSRunningApplication) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        
        return mruStack.firstIndex { $0.processIdentifier == app.processIdentifier }
    }
    
    /// Cleans up notification observers when deallocating
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
