//
//  clippyApp.swift
//  clippy
//
//  Created by Serhii Fozykosh on 09.08.2025.
//

import SwiftUI

@main
struct clippyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
