//
//  ReliableMuteUnmuteAppApp.swift
//  ReliableMuteUnmuteApp
//
//  Created by Tomasz Kulczycki on 11/07/2024.
//
import SwiftUI

@main
struct SimpleMuteUnmuteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
                    Text("Settings")
                }
    }
}
