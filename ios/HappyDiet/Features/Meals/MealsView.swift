//
//  MealsView.swift
//  HappyDiet
//
//  Tab: Recent meals history.
//

import SwiftUI

struct MealsView: View {
    @EnvironmentObject var dataStore: CoachDataStore
    @State private var meals: [Meal] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let client = BackendClient()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = errorMessage {
                    ContentUnavailableView(
                        "Error loading meals",
                        systemImage: "exclamationmark.triangle",
                        description: Text(err)
                    )
                } else if meals.isEmpty {
                    ContentUnavailableView(
                        "No meals yet",
                        systemImage: "fork.knife",
                        description: Text("Analyze a meal from the Analyze tab to see your history here.")
                    )
                } else {
                    List {
                        ForEach(meals) { meal in
                            MealRow(meal: meal)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Theme.bg)
            .navigationTitle("Meals")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await loadMealsAsync() }
            .task { await loadMealsAsync() }
        }
    }

    private func loadMealsAsync() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let list = try await client.fetchMeals()
            await MainActor.run {
                meals = list
                isLoading = false
            }
        } catch let e as BackendError {
            await MainActor.run {
                errorMessage = errorDescription(e)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func errorDescription(_ e: BackendError) -> String {
        switch e {
        case .httpError(let status, let msg):
            if status == 503 { return "Backend not configured." }
            return msg ?? "HTTP \(status)"
        case .decodingError(let err): return "Invalid response: \(err.localizedDescription)"
        case .networkError(let err): return "Network: \(err.localizedDescription)"
        case .invalidURL: return "Invalid URL"
        }
    }
}

struct MealRow: View {
    let meal: Meal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let moment = meal.mealMoment {
                        Text(moment.capitalized)
                            .font(.subheadline.bold())
                    }
                    if !meal.ingredients.isEmpty {
                        Text(meal.ingredients.prefix(3).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(Theme.textMuted)
                            .lineLimit(2)
                    }
                }
                Spacer()
                scoreBadge(Int(meal.complianceScore))
            }
            if let ts = meal.timestamp {
                Text(formatTimestamp(ts))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func scoreBadge(_ score: Int) -> some View {
        Text("\(score)%")
            .font(.subheadline.bold())
            .foregroundStyle(scoreColor(score))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(scoreColor(score).opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return Theme.green }
        if score >= 50 { return Theme.orange }
        return Theme.red
    }

    private func formatTimestamp(_ s: String) -> String {
        if let date = ISO8601DateFormatter().date(from: s) ?? ISO8601DateFormatter().date(from: s + "Z") {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return s
    }
}
