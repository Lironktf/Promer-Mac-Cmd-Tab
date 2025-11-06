//
//  main.swift
//  MacAppSwitcher
//
//  Entry point for the MacAppSwitcher application.
//  This minimal main.swift file initializes and runs the NSApplication,
//  creating the AppDelegate and starting the application event loop.
//

import Cocoa

/// Creates the shared NSApplication instance and sets up the AppDelegate
let app = NSApplication.shared

/// Set the app delegate which will handle application lifecycle events
let delegate = AppDelegate()
app.delegate = delegate

/// Start the application's main run loop
/// This blocks until the application terminates
app.run()
