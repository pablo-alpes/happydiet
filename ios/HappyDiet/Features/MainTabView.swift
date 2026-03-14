//
//  MainTabView.swift
//  HappyDiet
//
//  Main tab navigation: Live Coach | Analyze | Diet | Dashboard
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            LiveCoachView()
                .tabItem {
                    Label("Live", systemImage: "waveform.circle.fill")
                }
                .tag(0)
            AnalyzeFlowView()
                .tabItem {
                    Label("Analyze", systemImage: "camera.viewfinder")
                }
                .tag(1)
            DietView()
                .tabItem {
                    Label("Diet", systemImage: "list.clipboard")
                }
                .tag(2)
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.doc.horizontal")
                }
                .tag(3)
        }
        .environmentObject(appState)
    }
}
