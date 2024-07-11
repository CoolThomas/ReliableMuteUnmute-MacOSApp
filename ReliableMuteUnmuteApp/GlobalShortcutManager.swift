//
//  ReliableMuteUnmuteAppApp.swift
//  ReliableMuteUnmuteApp
//
//  Created by Tomasz Kulczycki on 11/07/2024.
//
import Cocoa
import Combine
import CoreAudio
import AVFoundation
import Foundation

class GlobalShortcutManager: ObservableObject {
    var eventTap: CFMachPort?
    @Published var isMuted: Bool = false
    var onToggleMute: (() -> Void)? // Callback to notify when mute is toggled

    func setupGlobalShortcut(callback: @escaping () -> Void) {
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                     place: .headInsertEventTap,
                                     options: .defaultTap,
                                     eventsOfInterest: CGEventMask(eventMask),
                                     callback: GlobalShortcutManager.globalEventCallback,
                                     userInfo: selfPointer)
        if let eventTap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            print("Global shortcut set up successfully")
        } else {
            print("Failed to create event tap")
        }
    }

    func stopGlobalShortcut() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0), .commonModes)
            self.eventTap = nil
            print("Global shortcut stopped")
        }
    }

    static let globalEventCallback: CGEventTapCallBack = { (proxy, type, event, refcon) in
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let cmdPressed = event.flags.contains(.maskCommand)
        // Use key code for '=' which is 24
        if cmdPressed && keyCode == 24 {
            print("Global shortcut key combination detected")
            let shortcutManager = Unmanaged<GlobalShortcutManager>.fromOpaque(refcon!).takeUnretainedValue()
            DispatchQueue.main.async {
                shortcutManager.toggleMute() // Call the toggle function
            }
            return nil
        }
        return Unmanaged.passRetained(event)
    }

    func toggleMute() {
        isMuted.toggle() // Update the state before performing mute/unmute
        print("Toggle mute, new state isMuted: \(isMuted)")
        
        // Notify the status bar controller about the mute toggle
        onToggleMute?()

        muteAllInputDevices(mute: isMuted)
    }
    
    // New method to get all input devices
    private func getAllInputDevices() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var propertySize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize)
        if status != noErr {
            print("Error getting device count: \(status)")
            return []
        }
        
        let deviceCount = propertySize / UInt32(MemoryLayout<AudioObjectID>.size)
        var deviceIDs = [AudioObjectID](repeating: AudioObjectID(), count: Int(deviceCount))
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &deviceIDs)
        if status != noErr {
            print("Error getting device IDs: \(status)")
            return []
        }
        
        return deviceIDs
    }
    
    // New method to mute/unmute a device
    private func muteDevice(_ deviceID: AudioObjectID, mute: Bool) {
        // Define property address to get the device's stream configuration
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        // Get the stream configuration of the device to check if it has input streams
        var propertySize = UInt32(0)
        var status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &propertySize)
        if status != noErr || propertySize == 0 {
            return // Skip if the device has no input streams
        }
        
        // Get the device name
        var name: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        var namePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        status = AudioObjectGetPropertyData(deviceID, &namePropertyAddress, 0, nil, &nameSize, &name)
        if status != noErr {
            name = "Unknown Device" as CFString
        }
        
        let deviceNameString = name as String
        
        // Prepare to set the mute property for the input device
        var mutePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var muteValue: UInt32 = mute ? 1 : 0
        propertySize = UInt32(MemoryLayout.size(ofValue: muteValue))
        
        let muteStatus = AudioObjectSetPropertyData(
            deviceID,
            &mutePropertyAddress,
            0,
            nil,
            propertySize,
            &muteValue
        )
        
        if muteStatus == noErr {
            print("\(deviceNameString) \(mute ? "muted" : "unmuted") successfully.")
        } else {
            print("Error setting mute property for device \(deviceNameString). Error code: \(muteStatus)")
        }
    }
    
    func unmuteAllInputs() {
            muteAllInputDevices(mute: false)
        }
    
    // Refactored method to mute/unmute all input devices
    private func muteAllInputDevices(mute: Bool) {
        let deviceIDs = getAllInputDevices()
        for deviceID in deviceIDs {
            muteDevice(deviceID, mute: mute)
        }
    }
    
    // New method to mute all inputs
    func muteAllInputs() {
        muteAllInputDevices(mute: true)
    }
}
