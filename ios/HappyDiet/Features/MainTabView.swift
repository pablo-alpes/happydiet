//
//  MainTabView.swift
//  HappyDiet
//
//  Tab navigation: Dashboard | Diet | Rules | Analyze | Coach | Meals | Goals | More
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
                    Label("Diet & Behaviour", systemImage: "list.clipboard")
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

            TrackView()
                .tabItem {
                    Label("Track", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(5)

            GoalsView()
                .tabItem {
                    Label("Goals", systemImage: "target")
                }
                .tag(6)

            MoreTabView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .tag(7)
        }
        .tint(Theme.accent)
        .environmentObject(appState)
        .environmentObject(dataStore)
        .task {
            await dataStore.refreshTasks()
        }
    }
}
