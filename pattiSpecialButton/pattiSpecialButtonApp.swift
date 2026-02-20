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
        Settings {
            EmptyView()
        }
    }
}
