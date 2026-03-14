//
//  RulesTabView.swift
//  HappyDiet
//
//  Tab: Display saved diet rules. Parse from Diet tab.
//

import SwiftUI

struct RulesTabView: View {
    @State private var rules: [DietRuleParsed] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    private let client = BackendClient()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isLoading {
                        ProgressView("Loading rules…")
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if let err = errorMessage {
                        ErrorBanner(message: err)
                            .padding(.horizontal)
                    } else if rules.isEmpty {
                        ContentUnavailableView(
                            "No diet rules yet",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("Go to the Diet tab to parse and save your diet plan.")
                        )
                        .padding()
                    } else {
                        FullDietRulesView(rules: rules)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 100)
            }
            .background(Theme.bg)
            .navigationTitle("Diet Rules")
            .refreshable { await loadRules() }
            .task { await loadRules() }
        }
    }

    private func loadRules() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let list = try await client.fetchRules()
            await MainActor.run {
                rules = list
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
