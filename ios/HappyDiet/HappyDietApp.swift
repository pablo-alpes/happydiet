//
//  HappyDietApp.swift
//  HappyDiet
//
//  Main app entry point. Hero → main app. Coach is a dedicated tab (not floating).
//

import SwiftUI

@main
struct HappyDietApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var coachData = CoachDataStore.shared
    @AppStorage("happydiet_seen_hero") private var seenHero = false

    var body: some Scene {
        WindowGroup {
            Group {
                if !seenHero {
                    HeroView(onEnter: enterApp)
                } else {
                    MainTabView()
                        .environmentObject(appState)
                        .environmentObject(coachData)
                }
            }
            .environmentObject(appState)
            .environmentObject(coachData)
        }
    }

    private func enterApp() {
        seenHero = true
    }
}
