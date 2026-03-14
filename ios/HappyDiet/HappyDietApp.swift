//
//  HappyDietApp.swift
//  HappyDiet
//
//  Main app entry point.
//

import SwiftUI

@main
struct HappyDietApp: App {
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
        }
    }
}
