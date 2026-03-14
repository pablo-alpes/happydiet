//
//  MainTabView.swift
//  HappyDiet
//
//  Tab navigation: Dashboard | Diet | Rules | Analyze | Agent | More
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var dataStore: CoachDataStore

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.doc.horizontal")
                }
                .tag(0)

            DietView()
                .tabItem {
                    Label("Diet", systemImage: "list.clipboard")
                }
                .tag(1)

            RulesTabView()
                .tabItem {
                    Label("Rules", systemImage: "doc.text.magnifyingglass")
                }
                .tag(2)

            AnalyzeFlowView()
                .tabItem {
                    Label("Analyze", systemImage: "camera.viewfinder")
                }
                .tag(3)

            LiveCoachView()
                .tabItem {
                    Label("Coach", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(4)

            MoreTabView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .tag(5)
        }
        .tint(Theme.accent)
        .environmentObject(appState)
        .environmentObject(dataStore)
    }
}
