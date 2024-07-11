//
//  ReliableMuteUnmuteAppApp.swift
//  ReliableMuteUnmuteApp
//
//  Created by Tomasz Kulczycki on 11/07/2024.
//


import SwiftUI
import Cocoa
import Combine

class StatusBarController: ObservableObject {
    private var statusItem: NSStatusItem
    @Published var isMuted: Bool = false
    private var audioInputMonitor = AudioInputMonitor()
    var currentKeyCode: UInt16 = 29 // Default key code for '0'
    var currentModifierFlags: NSEvent.ModifierFlags = .command // Default modifier flags
    var onToggleMute: (() -> Void)?
    
    private var cancellables = Set<AnyCancellable>()
    private var changeShortcutMenuItem: NSMenuItem?
    private var currentShortcutMenuItem: NSMenuItem?
    private var unmuteCountMenuItem: NSMenuItem? // Add this property
    
    private var isSettingNewShortcut = false
    private var isColorModeEnabled = true // New variable to track color mode
    
    private var globalShortcutManager = GlobalShortcutManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    private var mutedColor: NSColor = NSColor.green
    private var unmutedColor: NSColor = NSColor.red
    
    private var unmuteCounter: Int = 0
    
    init() {
        print("Initializing StatusBarController")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Unmute all audio inputs on startup
        globalShortcutManager.unmuteAllInputs()
        
        loadColorsFromFile()
        loadShortcutFromUserDefaults()
        setupMenuBar()
        setupGlobalShortcut(callback: {
            print("Global shortcut callback triggered")
            self.userToggledMute()
        })
        setupAudioInputMonitor()
        updateMenuBarTitle() // Ensure the title is updated on initialization
    }
    
    private func setupMenuBar() {
        if let button = statusItem.button {
            button.action = #selector(leftClickAction)
            button.sendAction(on: [.leftMouseUp])
            updateMenuBarTitle()
            print("Menu bar item set up")
        } else {
            print("Failed to set up menu bar item")
        }
        
        let menu = NSMenu()
        
        currentShortcutMenuItem = NSMenuItem(title: "Current Shortcut: \(formatShortcut())", action: nil, keyEquivalent: "")
        menu.addItem(currentShortcutMenuItem!)
        
        changeShortcutMenuItem = NSMenuItem(title: "Change Shortcut", action: #selector(changeShortcut), keyEquivalent: "")
        changeShortcutMenuItem?.target = self
        changeShortcutMenuItem?.isEnabled = true
        menu.addItem(changeShortcutMenuItem!)
        
        let toggleColorModeMenuItem = NSMenuItem(title: "Toggle Color Mode", action: #selector(toggleColorMode), keyEquivalent: "")
        toggleColorModeMenuItem.target = self
        menu.addItem(toggleColorModeMenuItem)
        
        let changeColorsMenuItem = NSMenuItem(title: "Change Colors", action: #selector(openColorConfigFile), keyEquivalent: "")
        changeColorsMenuItem.target = self
        menu.addItem(changeColorsMenuItem)
        
        unmuteCountMenuItem = NSMenuItem(title: "Mic Protector Events: \(unmuteCounter)", action: nil, keyEquivalent: "")
        menu.addItem(unmuteCountMenuItem!)
        
        menu.addItem(NSMenuItem.separator())
        
            
        // Add thank you and donation message with line break using attributed string
        let thankYouText = "Thank you for support 🙏\nDonate $5 or more..."
        let attributedTitle = NSMutableAttributedString(string: thankYouText)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.alignment = .left
        attributedTitle.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: thankYouText.count))
           
        let donationMenuItem = NSMenuItem(title: "", action: #selector(openDonationPage), keyEquivalent: "")
        donationMenuItem.target = self
        donationMenuItem.attributedTitle = attributedTitle
        menu.addItem(donationMenuItem)
        
        menu.addItem(NSMenuItem.separator())
       
        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)
        
        statusItem.menu = menu
    }
    
    
    @objc private func openDonationPage() {
        if let url = URL(string: "https://revolut.me/tomaszhbcm") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func leftClickAction(sender: NSStatusBarButton) {
        print("Left click action triggered")
        statusItem.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    
    @objc private func userToggledMute() {
        print("Toggling mute from user action")
        globalShortcutManager.toggleMute()
        isMuted = globalShortcutManager.isMuted
        if isMuted {
            audioInputMonitor.startMonitoring()
        } else {
            audioInputMonitor.stopMonitoring()
        }
        updateMenuBarTitle()
    }
    
    @objc private func changeShortcut() {
        print("Change Shortcut selected")
        isSettingNewShortcut = true
        currentShortcutMenuItem?.title = "Press new shortcut..."
        updateMenuBarTitle(forNewShortcut: true)
        
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isSettingNewShortcut else { return }
            self.stopGlobalShortcut()
            self.currentKeyCode = event.keyCode
            self.currentModifierFlags = event.modifierFlags.intersection([.control, .option, .shift, .command, .function])
            self.setupGlobalShortcut(callback: {
                print("Global shortcut callback triggered")
                self.userToggledMute()
            })
            self.currentShortcutMenuItem?.title = "Current Shortcut: \(self.formatShortcut())"
            self.isSettingNewShortcut = false
            self.saveShortcutToUserDefaults()
            self.updateMenuBarTitle(forNewShortcut: false)
        }
    }
    
    @objc private func toggleColorMode() {
        isColorModeEnabled.toggle()
        updateMenuBarTitle()
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(self)
    }
    
    private func formatShortcut() -> String {
        let keyName = keyNames[currentKeyCode] ?? "\(currentKeyCode)"
        let modifierNames = [
            currentModifierFlags.contains(.control) ? "Control" : "",
            currentModifierFlags.contains(.option) ? "Option" : "",
            currentModifierFlags.contains(.shift) ? "Shift" : "",
            currentModifierFlags.contains(.command) ? "Command" : "",
            currentModifierFlags.contains(.function) ? "Fn" : ""
        ].filter { !$0.isEmpty }
        
        let modifierString = modifierNames.joined(separator: " + ")
        return "\(modifierString) + \(keyName)"
    }
    
    private func updateMenuBarTitle(forNewShortcut isSettingNewShortcut: Bool = false) {
        if let button = statusItem.button {
            if isSettingNewShortcut {
                button.attributedTitle = NSAttributedString(string: "Press new shortcut...", attributes: [.foregroundColor: NSColor.black])
                button.layer?.backgroundColor = NSColor.clear.cgColor
            } else {
                let title = isMuted ? "Muted" : "Unmuted"
                let color: NSColor = isColorModeEnabled ? (isMuted ? mutedColor : unmutedColor) : NSColor.clear
                let textColor: NSColor = isColorModeEnabled ? NSColor.white : NSColor.black
                
                button.attributedTitle = NSAttributedString(string: title, attributes: [.foregroundColor: textColor])
                button.layer?.backgroundColor = color.cgColor
            }
            button.sizeToFit()
            button.wantsLayer = true
            button.layer?.cornerRadius = 5 // Ensure the button remains rounded
            button.layer?.masksToBounds = true
            button.frame.size.width += 20 // Add padding to the button width for proper centering
            button.alignment = .center // Ensure the text is centered
            print("Updated menu bar title to \(button.title)")
        }
    }
    
    private func setupGlobalShortcut(callback: @escaping () -> Void) {
        print("Setting up global shortcut")
        stopGlobalShortcut() // Ensure any existing monitor is removed
        
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                     place: .headInsertEventTap,
                                     options: .defaultTap,
                                     eventsOfInterest: CGEventMask(eventMask),
                                     callback: StatusBarController.globalEventCallback,
                                     userInfo: selfPointer)
        if let eventTap = eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            if let runLoopSource = runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
                CGEvent.tapEnable(tap: eventTap, enable: true)
                print("Global shortcut set up successfully")
            } else {
                print("Failed to create run loop source")
            }
        } else {
            print("Failed to create event tap")
        }
    }
    
    private static let globalEventCallback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let statusBarController = Unmanaged<StatusBarController>.fromOpaque(refcon!).takeUnretainedValue()
        print("Key down detected: keyCode=\(keyCode), flags=\(flags)")
        if flags.intersection(statusBarController.convertToCGEventFlags(modifierFlags: statusBarController.currentModifierFlags)) == statusBarController.convertToCGEventFlags(modifierFlags: statusBarController.currentModifierFlags) && keyCode == statusBarController.currentKeyCode {
            print("Global shortcut key combination detected")
            DispatchQueue.main.async {
                statusBarController.userToggledMute() // Call the toggle function
            }
            return nil // Suppress the event
        }
        return Unmanaged.passRetained(event)
    }
    
    private func stopGlobalShortcut() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            if let runLoopSource = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
                self.runLoopSource = nil
            }
            self.eventTap = nil
            print("Global shortcut stopped")
        }
    }
    
    private func saveShortcutToUserDefaults() {
        let combinedKey = UInt64(currentKeyCode) | (UInt64(currentModifierFlags.rawValue) << 32)
        UserDefaults.standard.set(combinedKey, forKey: "globalShortcutKey")
        print("Saved shortcut to UserDefaults: \(formatShortcut())")
    }
    
    private func loadShortcutFromUserDefaults() {
        if let combinedKey = UserDefaults.standard.value(forKey: "globalShortcutKey") as? UInt64 {
            currentKeyCode = UInt16(combinedKey & 0xFFFF)
            currentModifierFlags = NSEvent.ModifierFlags(rawValue: UInt(combinedKey >> 32))
            print("Loaded shortcut from UserDefaults: \(formatShortcut())")
        }
    }
    
    @objc private func openColorConfigFile() {
        let fileManager = FileManager.default
        if let homeDirectory = fileManager.homeDirectoryForCurrentUser as URL? {
            let appFolderURL = homeDirectory.appendingPathComponent("MuteUnmuteApp")
            let colorConfigURL = appFolderURL.appendingPathComponent("colorConfig.txt")
            
            // Create app folder if it doesn't exist
            if !fileManager.fileExists(atPath: appFolderURL.path) {
                try? fileManager.createDirectory(at: appFolderURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Check if file exists, if not create it with default colors
            if !fileManager.fileExists(atPath: colorConfigURL.path) {
                let defaultConfig = "mutedColor=#00FF00\nunmutedColor=#FF0000"
                try? defaultConfig.write(to: colorConfigURL, atomically: true, encoding: .utf8)
            }
            
            // Open the file in the default text editor
            NSWorkspace.shared.open(colorConfigURL)
        }
    }
    
    private func loadColorsFromFile() {
        let fileManager = FileManager.default
        if let homeDirectory = fileManager.homeDirectoryForCurrentUser as URL? {
            let appFolderURL = homeDirectory.appendingPathComponent("MuteUnmuteApp")
            let colorConfigURL = appFolderURL.appendingPathComponent("colorConfig.txt")
            if let configContent = try? String(contentsOf: colorConfigURL, encoding: .utf8) {
                let lines = configContent.split(separator: "\n")
                for line in lines {
                    let components = line.split(separator: "=")
                    if components.count == 2 {
                        let key = components[0]
                        let value = components[1]
                        if key == "mutedColor", let color = NSColor(hex: String(value)) {
                            mutedColor = color
                        } else if key == "unmutedColor", let color = NSColor(hex: String(value)) {
                            unmutedColor = color
                        }
                    }
                }
            }
        }
    }

    private func convertToCGEventFlags(modifierFlags: NSEvent.ModifierFlags) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifierFlags.contains(.control) { flags.insert(.maskControl) }
        if modifierFlags.contains(.option) { flags.insert(.maskAlternate) }
        if modifierFlags.contains(.shift) { flags.insert(.maskShift) }
        if modifierFlags.contains(.command) { flags.insert(.maskCommand) }
        if modifierFlags.contains(.function) { flags.insert(.maskSecondaryFn) }
        return flags
    }
    
    private func setupAudioInputMonitor() {
        audioInputMonitor.$isInputUnmutedByOtherApp
            .sink { [weak self] isUnmuted in
                guard let self = self else { return }
                if self.isMuted && isUnmuted {
                    self.unmuteCounter += 1
                    print("Audio input was unmuted by another app. This has happened \(self.unmuteCounter) times.")
                    self.globalShortcutManager.muteAllInputs()
                    self.unmuteCountMenuItem?.title = "Mic Protector Events: \(self.unmuteCounter)"
                    if let sound = NSSound(named: "Hero") {
                        sound.play()
                    }
                    // Take additional action or notify user if needed
                }
            }
            .store(in: &cancellables)
    }
}

extension NSColor {
    convenience init?(hex: String) {
        let r, g, b, a: CGFloat

        var start = hex.index(hex.startIndex, offsetBy: 0)
        if hex.hasPrefix("#") {
            start = hex.index(hex.startIndex, offsetBy: 1)
        }

        let hexColor = String(hex[start...])
        if hexColor.count == 8 {
            let scanner = Scanner(string: hexColor)
            var hexNumber: UInt64 = 0

            if scanner.scanHexInt64(&hexNumber) {
                r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
                g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
                b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
                a = CGFloat(hexNumber & 0x000000ff) / 255

                self.init(red: r, green: g, blue: b, alpha: a)
                return
            }
        } else if hexColor.count == 6 {
            let scanner = Scanner(string: hexColor)
            var hexNumber: UInt64 = 0

            if scanner.scanHexInt64(&hexNumber) {
                r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                b = CGFloat(hexNumber & 0x0000ff) / 255
                a = 1.0

                self.init(red: r, green: g, blue: b, alpha: a)
                return
            }
        }

        return nil
    }
}
