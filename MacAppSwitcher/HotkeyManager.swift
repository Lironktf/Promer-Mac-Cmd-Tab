//
//  HotkeyManager.swift
//  MacAppSwitcher
//
//  Manages global hotkey registration using CGEventTap API.
//  Registers Command+~ (tilde) hotkey and handles key down/up events.
//  Uses CGEventTap for reliable detection of modifier key changes.
//

import Cocoa
import Carbon
import ApplicationServices

/// Manages global hotkey registration and event handling
/// Uses CGEventTap API to monitor keyboard events system-wide
/// and detect Command+~ key combinations, including modifier key releases.
class HotkeyManager {
    /// Reference to the CGEventTap
    private var eventTap: CFMachPort?

    /// Run loop source for the event tap
    private var runLoopSource: CFRunLoopSource?

    /// Callback invoked when Command+~ is pressed (key down)
    var onKeyDown: (() -> Void)?

    /// Callback invoked when Command+~ is released (key up)
    var onKeyUp: (() -> Void)?

    /// Flag to track if Command+~ is currently active
    private var isHotkeyActive = false

    /// Flag to track if ~ key is currently pressed
    private var isTabPressed = false

    /// Initializes the HotkeyManager and registers the Command+~ hotkey
    init() {
        registerHotkey()
    }

    /// Registers the Command+~ hotkey using CGEventTap
    /// Creates an event tap that monitors keyboard events globally
    /// to detect Command+~ key combinations and modifier releases.
    private func registerHotkey() {
        // Verify Accessibility permission before creating event tap
        // Wait a moment in case permission was just granted
        // Increased delay to 1.0 second to allow TCC (Transparency, Consent, and Control)
        // database to fully update after permission is granted
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.actuallyRegisterHotkey()
        }
    }
    
    /// Actually performs the hotkey registration after permission check
    private func actuallyRegisterHotkey() {
        // Verify Accessibility permission before creating event tap
        let isTrusted = AXIsProcessTrustedWithOptions(nil)
        if !isTrusted {
            print("ERROR: Accessibility permission not granted. Cannot create event tap.")
            print("Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
            print("Please enable Accessibility permission in System Settings and restart the app.")
            return
        }
        
        // Define the events we want to monitor
        // CGEventMask includes key down, key up, and flags changed events
        // flagsChanged events detect modifier key (Control) state changes
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue) |
                        (1 << CGEventType.flagsChanged.rawValue)
        
        // Create the event tap callback
        // This function is called for every matching keyboard event
        let eventTapCallback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            // Extract the HotkeyManager instance from refcon
            guard let refcon = refcon else {
                return Unmanaged.passUnretained(event)
            }
            
            let hotkeyManager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
            
            // Handle different event types
            switch type {
            case .keyDown, .keyUp:
                // Keyboard key press/release event
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags
                let isCommandPressed = flags.contains(.maskCommand)
                let isTildeKey = (keyCode == 50)  // Backtick/Tilde key (~)

                if isTildeKey && isCommandPressed {
                    if type == .keyDown {
                        if !hotkeyManager.isHotkeyActive {
                            // Command+~ was just pressed for the first time
                            hotkeyManager.isHotkeyActive = true
                            hotkeyManager.isTabPressed = true
                            hotkeyManager.onKeyDown?()
                            // Consume the event to prevent it from reaching other apps
                            return nil
                        } else if hotkeyManager.isHotkeyActive {
                            // ~ pressed again while Command is still held - cycle to next window
                            hotkeyManager.isTabPressed = true
                            hotkeyManager.onKeyDown?()
                            // Consume the event
                            return nil
                        }
                    } else if type == .keyUp && isTildeKey {
                        // ~ key was released
                        hotkeyManager.isTabPressed = false
                        // Don't activate yet - wait for Command to be released
                        // Consume the event
                        return nil
                    }
                } else if isTildeKey && !isCommandPressed && hotkeyManager.isHotkeyActive {
                    // ~ key released and Command is no longer pressed
                    // This means Command was released first, then ~
                    hotkeyManager.handleHotkeyRelease()
                    return nil
                }

            case .flagsChanged:
                // Modifier key (Command, Shift, etc.) state changed
                let flags = event.flags
                let isCommandPressed = flags.contains(.maskCommand)

                // If Command was released while hotkey was active, activate selection
                if !isCommandPressed && hotkeyManager.isHotkeyActive {
                    hotkeyManager.handleHotkeyRelease()
                }
                
            default:
                break
            }
            
            // Pass the event through to other handlers
            return Unmanaged.passUnretained(event)
        }
        
        // Create opaque pointer to self for the callback
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        // Try creating event tap at session level first (requires less privileges)
        // If that fails, try HID level (requires more privileges, may need Input Monitoring)
        var eventTap: CFMachPort?
        
        // First attempt: Session-level event tap
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventTapCallback,
            userInfo: selfPtr
        )
        
        // If session-level fails, try HID-level (may require Input Monitoring)
        if eventTap == nil {
            print("Session-level event tap failed, trying HID-level...")
            eventTap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(eventMask),
                callback: eventTapCallback,
                userInfo: selfPtr
            )
        }
        
        guard let eventTap = eventTap else {
            print("ERROR: Failed to create event tap at both session and HID levels.")
            print("Possible causes:")
            print("  1. Accessibility permission not granted")
            print("  2. Input Monitoring permission may also be required")
            print("  3. App Sandbox may be enabled (must be disabled)")
            print("  4. Another app may be using the same event tap location")
            print("Please check System Settings > Privacy & Security > Accessibility")
            print("And also check: System Settings > Privacy & Security > Input Monitoring")
            return
        }
        
        // Create a run loop source from the event tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        
        guard let runLoopSource = runLoopSource else {
            print("Failed to create run loop source.")
            return
        }
        
        // Add the run loop source to the current run loop
        CFRunLoopAddSource(
            CFRunLoopGetCurrent(),
            runLoopSource,
            .commonModes
        )
        
        // Enable the event tap
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        print("Command+~ hotkey registered successfully.")
    }
    
    /// Handles the release of the Command+~ hotkey
    /// Activates the selected window and resets state
    private func handleHotkeyRelease() {
        isHotkeyActive = false
        isTabPressed = false
        onKeyUp?()
    }
    
    /// Unregisters the hotkey and cleans up event handlers
    deinit {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                runLoopSource,
                .commonModes
            )
        }
    }
}
