//
//  ReliableMuteUnmuteAppApp.swift
//  ReliableMuteUnmuteApp
//
//  Created by Tomasz Kulczycki on 11/07/2024.
//

import Cocoa

class GlobalShortcutHandler {
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?

    func setupEventMonitors(callback: @escaping () -> Void) {
        // Local event monitor to intercept the key event
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = event.keyCode
            let cmdPressed = event.modifierFlags.contains(.command)
            
            // Check for your specific key combination (Cmd + '=')
            if cmdPressed && keyCode == 24 {
                print("Global shortcut key combination detected locally")
                callback()
                // Return nil to prevent the event from being passed to the system
                return nil
            }
            // Return the event to allow it to be processed normally
            return event
        }
        
        // Global event monitor as a fallback
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = event.keyCode
            let cmdPressed = event.modifierFlags.contains(.command)
            
            // Check for your specific key combination (Cmd + '=')
            if cmdPressed && keyCode == 24 {
                print("Global shortcut key combination detected globally")
                callback()
            }
        }
    }

    func stopEventMonitors() {
        if let localEventMonitor = localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        if let globalEventMonitor = globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
        print("Event monitors stopped")
    }
}
