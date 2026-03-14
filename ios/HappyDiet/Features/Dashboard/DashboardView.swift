//
//  DashboardView.swift
//  HappyDiet
//
//  Full dashboard: hero, targets, next meal, weight, trend, impact, coach tasks, insights, meals.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var dataStore: CoachDataStore
    @State private var meals: [Meal] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var weightInput: Double?
    @State private var weightNote = ""

    private let client = BackendClient()
    private let mockTrend: [Double] = [72, 78, 85, 82, 88, 65, 90, 92, 88, 75, 82, 86, 91, 84]
    private let mealSuggestions: [String: [String]] = [
        "breakfast": ["Oatmeal with berries and almonds", "Greek yogurt with banana", "Eggs with avocado and whole grain toast"],
        "lunch": ["Grilled chicken salad with quinoa", "Turkey wrap with hummus", "Grilled fish with spinach and sweet potato"],
        "dinner": ["Salmon with broccoli and rice", "Grilled chicken with vegetables", "Lean protein with salad and whole grains"],
    ]
    private let insights = [
        "Focus on dinners — they tend to slip. Prep compliant options on Sunday.",
        "Swap soda for sparkling water. Keep allowed snacks visible.",
        "Breakfasts are your strongest. Replicate that structure for lunch.",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    dashboardHero
                    targetsCard
                    nextMealTipCard
                    weightCard
                    complianceTrendCard
                    impactCards
                    coachTasksCard
                    insightsCard
                    recentMealsCard
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(Theme.bg)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await loadMealsAsync() }
            .task { await loadMealsAsync() }
        }
    }

    private var dashboardHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your progress")
                .font(.title2.bold())
            Text("Track weight, compliance, and meals. Good choices add up — the coach explains the impact below.")
                .font(.subheadline)
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.headerGradient)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
    }

    private var targetsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your targets")
                .font(.headline)
            Text("Set your goals — the coach uses these to guide you.")
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
            HStack(spacing: 12) {
                Picker("Goal", selection: Binding(
                    get: { dataStore.targets.goal },
                    set: { dataStore.saveTargets(goal: $0, targetWeight: dataStore.targets.targetWeight, targetDate: dataStore.targets.targetDate) }
                )) {
                    Text("Lose weight").tag("lose")
                    Text("Maintain").tag("maintain")
                    Text("Build muscle").tag("build")
                }
                .pickerStyle(.menu)
                TextField("Target kg", value: Binding(
                    get: { dataStore.targets.targetWeight },
                    set: { dataStore.saveTargets(goal: dataStore.targets.goal, targetWeight: $0, targetDate: dataStore.targets.targetDate) }
                ), format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(.primary)
                    .frame(width: 90)
                TextField("Date (yyyy-mm-dd)", text: Binding(
                    get: { dataStore.targets.targetDate ?? "" },
                    set: { dataStore.saveTargets(goal: dataStore.targets.goal, targetWeight: dataStore.targets.targetWeight, targetDate: $0.isEmpty ? nil : $0) }
                ))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(.primary)
                    .frame(width: 120)
            }
            if dataStore.targets.targetWeight != nil || !(dataStore.targets.targetDate ?? "").isEmpty {
                Text(targetBadgeText)
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding()
        .cardStyle()
    }

    private var targetBadgeText: String {
        var parts: [String] = []
        let g = dataStore.targets.goal
        if g == "lose" { parts.append("Lose weight") }
        else if g == "build" { parts.append("Build muscle") }
        else { parts.append("Maintain") }
        if let w = dataStore.targets.targetWeight { parts.append("Target: \(Int(w)) kg") }
        if let d = dataStore.targets.targetDate, !d.isEmpty { parts.append("By \(d)") }
        return parts.joined(separator: " • ")
    }

    private var nextMealTipCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next meal time")
                .font(.headline)
            nextMealTipContent
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accentMutedGradient)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Theme.accent)
                .frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
    }

    private var nextMealTipContent: some View {
        let tip = nextMealTip()
        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(tip.icon) \(tip.meal)")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.accent)
                Text(tip.text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func nextMealTip() -> (meal: String, text: String, icon: String) {
        let h = Calendar.current.component(.hour, from: Date())
        if h >= 5 && h < 9 {
            return ("Breakfast", "Aim for 7–9am. Start with something compliant to set the tone.", "🍳")
        }
        if h >= 9 && h < 11 {
            return ("Lunch", "Your next meal could be around 12–1pm. Plan a compliant option now.", "🥗")
        }
        if h >= 11 && h < 14 {
            return ("Lunch", "Around 12–2pm. Keep it balanced and on plan.", "🥗")
        }
        if h >= 14 && h < 17 {
            return ("Dinner", "Could be around 6–8pm. Prep something you'll enjoy.", "🍽")
        }
        if h >= 17 && h < 21 {
            return ("Dinner", "Around 6–8pm. End the day strong with a compliant meal.", "🍽")
        }
        return ("Breakfast", "It's late — your next meal: Breakfast around 7–9am. Rest well!", "🍳")
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weight & self-reported")
                .font(.headline)
            Text("Log your weight and optional note (e.g. how you feel, hunger level).")
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
            HStack(spacing: 12) {
                TextField("kg", value: $weightInput, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(.primary)
                    .frame(width: 80)
                TextField("Optional note", text: $weightNote)
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(.primary)
                Button("Log") {
                    if let kg = weightInput, kg >= 30, kg <= 300 {
                        dataStore.addWeight(kg: kg, note: weightNote)
                        weightInput = nil
                        weightNote = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(weightInput == nil)
            }
            if !dataStore.weightEntries.isEmpty {
                ForEach(dataStore.weightEntries.prefix(5)) { e in
                    HStack {
                        Text("\(e.kg) kg")
                            .font(.subheadline.bold())
                        Text(e.date)
                            .font(.caption)
                            .foregroundStyle(Theme.gray)
                        if !e.note.isEmpty {
                            Text("• \(e.note)")
                                .font(.caption)
                                .foregroundStyle(Theme.textMuted)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .cardStyle()
    }

    private var complianceTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compliance trend (14 days)")
                .font(.headline)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(mockTrend.enumerated()), id: \.offset) { _, v in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.headerGradient)
                        .frame(height: max(6, (v / 100) * 80))
                }
            }
            .frame(height: 80)
            HStack {
                ForEach(0..<7, id: \.self) { i in
                    Text("D\(i + 1)")
                        .font(.caption2)
                        .foregroundStyle(Theme.gray)
                }
                Spacer()
                ForEach(7..<14, id: \.self) { i in
                    Text("D\(i + 1)")
                        .font(.caption2)
                        .foregroundStyle(Theme.gray)
                }
            }
        }
        .padding()
        .cardStyle()
    }

    private var impactCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Impact: good vs poor compliance")
                .font(.headline)
            Text("What the coach says about sticking to your plan.")
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
            VStack(spacing: 12) {
                impactCard(
                    title: "✓ Good results (80%+ compliance)",
                    text: "More energy, steadier weight, better sleep. Your body responds when you stay consistent.",
                    color: Theme.green
                )
                impactCard(
                    title: "✗ Poor results (<50% compliance)",
                    text: "Slips happen. The coach doesn't judge — it helps you understand why certain foods set you back.",
                    color: Theme.red
                )
            }
        }
        .padding()
        .cardStyle()
    }

    private func impactCard(title: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(color)
            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.08))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(color)
                .frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var coachTasksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coach tasks")
                .font(.headline)
            Text("Tasks from your coach to keep you engaged. Mark done when complete.")
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
            if dataStore.tasks.isEmpty {
                Text("No tasks yet. The coach will assign some when you chat.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.gray)
            } else {
                ForEach(dataStore.tasks) { t in
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
                            Text("(\(t.due))")
                                .font(.caption)
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

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights & meal suggestions")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Tips to steer your diet and meal ideas based on your plan.")
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
            Text("Tips")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.accent)
            ForEach(insights, id: \.self) { i in
                Text(i)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.accentMuted)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Theme.accent)
                            .frame(width: 4)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Text("Meal ideas")
                .font(.subheadline.bold())
                .foregroundStyle(Theme.accent)
                .padding(.top, 8)
            ForEach(["breakfast", "lunch", "dinner"], id: \.self) { meal in
                if let ideas = mealSuggestions[meal] {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meal.capitalized)
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.accent)
                        ForEach(ideas.prefix(2), id: \.self) { idea in
                            Text("• \(idea)")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .cardStyle()
    }

    private var recentMealsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent meals")
                    .font(.headline)
                Spacer()
                Button("Refresh") { Task { await loadMealsAsync() } }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)
            }
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(Theme.red)
            } else if meals.isEmpty {
                ContentUnavailableView(
                    "No meals yet",
                    systemImage: "fork.knife",
                    description: Text("Analyze a meal from the Analyze tab to see your history here.")
                )
            } else {
                ForEach(meals) { meal in
                    MealRow(meal: meal)
                }
            }
        }
        .padding()
        .cardStyle()
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
