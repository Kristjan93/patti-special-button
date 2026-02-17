//
//  pattiSpecialButtonApp.swift
//  pattiSpecialButton
//
//  Created by Kristjan Thorsteinsson on 17.2.2026.
//

import SwiftUI

@main
struct pattiSpecialButtonApp: App {
    // This tells SwiftUI to create and use our AppDelegate,
    // which handles all the menu bar logic.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We need at least one Scene, but we don't want a visible window.
        // Settings with EmptyView is the standard way to have a
        // window-less macOS app using SwiftUI's app lifecycle.
        Settings {
            EmptyView()
        }
    }
}
