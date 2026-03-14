//
//  DashboardView.swift
//  HappyDiet
//
//  Tab 2: Dashboard with meal list (compliance scores, ingredients)
//

import SwiftUI

struct DashboardView: View {
    @State private var meals: [Meal] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let client = BackendClient()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading meals…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                        Text(err)
                            .multilineTextAlignment(.center)
                        Button("Retry") { loadMeals() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if meals.isEmpty {
                    ContentUnavailableView(
                        "No meals yet",
                        systemImage: "fork.knife",
                        description: Text("Analyze a meal from the Analyze tab to see your history here.")
                    )
                } else {
                    List(meals) { meal in
                        MealRow(meal: meal)
                    }
                }
            }
            .navigationTitle("Dashboard")
            .refreshable { await loadMealsAsync() }
            .task { await loadMealsAsync() }
        }
    }

    private func loadMeals() {
        Task { await loadMealsAsync() }
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

// MARK: - Meal Row

struct MealRow: View {
    let meal: Meal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Score: \(Int(meal.complianceScore))/100")
                    .font(.headline)
                Spacer()
                if let moment = meal.mealMoment {
                    Text(moment.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !meal.ingredients.isEmpty {
                Text(meal.ingredients.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if !meal.compliantItems.isEmpty || !meal.nonCompliantItems.isEmpty {
                HStack(spacing: 8) {
                    if !meal.compliantItems.isEmpty {
                        Label("\(meal.compliantItems.count) compliant", systemImage: "checkmark.circle")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    if !meal.nonCompliantItems.isEmpty {
                        Label("\(meal.nonCompliantItems.count) off", systemImage: "xmark.circle")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }
            if let ts = meal.timestamp {
                Text(formatTimestamp(ts))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatTimestamp(_ s: String) -> String {
        if let date = ISO8601DateFormatter().date(from: s) ?? ISO8601DateFormatter().date(from: s + "Z") {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return s
    }
}
