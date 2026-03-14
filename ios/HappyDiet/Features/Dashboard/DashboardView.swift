//
//  DashboardView.swift
//  HappyDiet
//
//  Dashboard: compliance trend (top) with average, suggested meal with photo,
//  coach tasks, single weight number.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var dataStore: CoachDataStore

    private let mockTrend: [Double] = [72, 78, 85, 82, 88, 65, 90, 92, 88, 75, 82, 86, 91, 84]
    private let mealSuggestions: [String: [String]] = [
        "breakfast": ["Oatmeal with berries and almonds", "Greek yogurt with banana", "Eggs with avocado and whole grain toast"],
        "lunch": ["Grilled chicken salad with quinoa", "Turkey wrap with hummus", "Grilled fish with spinach and sweet potato"],
        "dinner": ["Salmon with broccoli and rice", "Grilled chicken with vegetables", "Lean protein with salad and whole grains"],
    ]
    private let mealImages: [String: String] = [
        "breakfast": "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=320&h=240&fit=crop",
        "lunch": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=320&h=240&fit=crop",
        "dinner": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=320&h=240&fit=crop",
    ]

    private var complianceAverage: Int {
        guard !mockTrend.isEmpty else { return 0 }
        return Int(mockTrend.reduce(0, +) / Double(mockTrend.count))
    }

    private var nextMealKey: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 11 { return "breakfast" }
        if hour < 17 { return "lunch" }
        return "dinner"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    complianceTrendCard
                    suggestedMealCard
                    coachTasksCard
                    weightSnapshotCard
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(Theme.bg)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Compliance Trend (top)

    private var complianceTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Compliance Trend")
                        .font(.headline)
                    Text("14-day average")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                }
                Spacer()
                Text("\(complianceAverage)%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(complianceAverage >= 80 ? Theme.green : complianceAverage >= 50 ? Theme.orange : Theme.red)
            }
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(mockTrend.enumerated()), id: \.offset) { idx, v in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor(v))
                            .frame(height: max(6, (v / 100) * 70))
                    }
                }
            }
            .frame(height: 70)
            HStack {
                Text("D1")
                    .font(.caption2)
                    .foregroundStyle(Theme.gray)
                Spacer()
                Text("D7")
                    .font(.caption2)
                    .foregroundStyle(Theme.gray)
                Spacer()
                Text("D14")
                    .font(.caption2)
                    .foregroundStyle(Theme.gray)
            }
        }
        .padding()
        .cardStyle()
    }

    private func barColor(_ value: Double) -> Color {
        if value >= 80 { return Theme.accent }
        if value >= 50 { return Theme.orange }
        return Theme.red.opacity(0.7)
    }

    // MARK: - Suggested Meal

    private var suggestedMealCard: some View {
        let key = nextMealKey
        let suggestion = mealSuggestions[key]?.randomElement() ?? "Balanced meal with lean protein and vegetables"
        let imageURL = mealImages[key] ?? ""

        return VStack(alignment: .leading, spacing: 12) {
            Text("Next meal: \(key.capitalized)")
                .font(.headline)
            HStack(alignment: .top, spacing: 14) {
                AsyncImage(url: URL(string: imageURL)) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    case .failure:
                        mealPlaceholder
                    default:
                        ProgressView()
                            .frame(width: 120, height: 90)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(suggestion)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Text("Based on your diet plan")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                    Button("Analyze this meal") {
                        appState.selectedTab = 3
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                }
            }
        }
        .padding()
        .cardStyle()
    }

    private var mealPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.accentMuted)
                .frame(width: 120, height: 90)
            Image(systemName: "fork.knife")
                .font(.title2)
                .foregroundStyle(Theme.accent)
        }
    }

    // MARK: - Coach Tasks

    private var coachTasksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coach Tasks")
                .font(.headline)
            if dataStore.tasks.isEmpty {
                Text("No tasks yet. Chat with the coach to get some.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.gray)
            } else {
                ForEach(dataStore.tasks.prefix(5)) { t in
                    HStack {
                        Button {
                            dataStore.toggleTaskDone(t)
                        } label: {
                            Image(systemName: t.done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(t.done ? Theme.green : Theme.gray)
                        }
                        Text(t.task)
                            .font(.subheadline)
                            .strikethrough(t.done)
                            .foregroundStyle(t.done ? Theme.gray : .primary)
                        if !t.due.isEmpty {
                            Spacer()
                            Text(t.due)
                                .font(.caption2)
                                .foregroundStyle(Theme.gray)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .cardStyle()
    }

    // MARK: - Weight Snapshot (single number)

    private var weightSnapshotCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weight")
                .font(.headline)
            if let latest = dataStore.weightEntries.first {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(latest.kg))")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                    Text("kg")
                        .font(.title3)
                        .foregroundStyle(Theme.textMuted)
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(latest.date)
                            .font(.caption)
                            .foregroundStyle(Theme.gray)
                        if let target = dataStore.targets.targetWeight {
                            Text("Target: \(Int(target)) kg")
                                .font(.caption)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
            } else {
                Text("No weight logged yet")
                    .font(.subheadline)
                    .foregroundStyle(Theme.gray)
            }
            Button("Log weight or set goals") {
                appState.selectedTab = 6
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .tint(Theme.accent)
        }
        .padding()
        .cardStyle()
    }
}
