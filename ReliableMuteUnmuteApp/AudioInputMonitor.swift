//
//  ReliableMuteUnmuteAppApp.swift
//  ReliableMuteUnmuteApp
//
//  Created by Tomasz Kulczycki on 11/07/2024.
//
import Foundation
import AVFoundation

class AudioInputMonitor: ObservableObject {
    private var timer: Timer?
    @Published var isInputUnmutedByOtherApp: Bool = false
    private var previousMuteStates: [AudioObjectID: Bool] = [:]
    var isMonitoring: Bool = false

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.checkAudioInputState()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
        previousMuteStates.removeAll()
    }

    private func checkAudioInputState() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var propertySize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize)
        if status != noErr {
            print("Error getting device count: \(status)")
            return
        }

        let deviceCount = propertySize / UInt32(MemoryLayout<AudioObjectID>.size)
        var deviceIDs = [AudioObjectID](repeating: AudioObjectID(), count: Int(deviceCount))
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &deviceIDs)
        if status != noErr {
            print("Error getting device IDs: \(status)")
            return
        }

        var anyDeviceUnmuted = false

        for deviceID in deviceIDs {
            var inputPropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            var mute: UInt32 = 0
            var muteSize = UInt32(MemoryLayout.size(ofValue: mute))
            status = AudioObjectGetPropertyData(deviceID, &inputPropertyAddress, 0, nil, &muteSize, &mute)
            if status == noErr {
                let isMuted = mute != 0
                if let previousMuteState = previousMuteStates[deviceID], previousMuteState != isMuted {
                    if !isMuted {
                        anyDeviceUnmuted = true
                    }
                }
                previousMuteStates[deviceID] = isMuted
            }
        }

        DispatchQueue.main.async {
            self.isInputUnmutedByOtherApp = anyDeviceUnmuted
        }
    }
}
