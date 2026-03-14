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
    @State private var meals: [Meal] = []
    @State private var isLoadingMeals = false
    @State private var showImpactInfo = false
    @State private var backendUnreachable = false
    @State private var loadMealsRetryCount = 0

    private let client = BackendClient()
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

    private var complianceTrend: [Double] {
        let cal = Calendar.current
        var dailyScores: [Date: [Double]] = [:]
        for meal in meals {
            guard let ts = meal.timestamp,
                  let date = ISO8601DateFormatter().date(from: ts) ?? ISO8601DateFormatter().date(from: ts + "Z") else { continue }
            let dayStart = cal.startOfDay(for: date)
            dailyScores[dayStart, default: []].append(meal.complianceScore)
        }
        let today = cal.startOfDay(for: Date())
        return (0..<14).reversed().map { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return 0 }
            let dayStart = cal.startOfDay(for: day)
            let scores = dailyScores[dayStart] ?? []
            return scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
        }
    }

    private var complianceAverage: Int {
        let trend = complianceTrend.filter { $0 > 0 }
        guard !trend.isEmpty else { return 0 }
        return Int(trend.reduce(0, +) / Double(trend.count))
    }

    private var weightPoints: [(day: Int, kg: Double)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let fromStore: [(day: Int, kg: Double)] = dataStore.weightEntries.prefix(14).enumerated().compactMap { idx, e -> (day: Int, kg: Double)? in
            guard let d = formatter.date(from: e.date) else { return nil }
            let todayDate = formatter.date(from: today) ?? Date()
            let daysAgo = Calendar.current.dateComponents([.day], from: d, to: todayDate).day ?? idx
            return (day: min(max(0, daysAgo), 13), kg: e.kg)
        }
        let sortedFromStore = fromStore.sorted { $0.day < $1.day }
        if !sortedFromStore.isEmpty { return sortedFromStore }
        return (0..<14).map { i in (day: i, kg: 75.0 - Double(i) * 0.1 + Double(i % 3) * 0.3) }
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
                    if backendUnreachable {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Theme.orange)
                            Text("Backend unreachable. Using demo data. Set URL in More > Settings (e.g. http://YOUR_MAC_IP:8080).")
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.orange.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    complianceTrendCard
                    suggestedMealCard
                    coachTasksCard
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(Theme.bg)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadMeals()
                await dataStore.refreshTasks()
            }
            .task {
                await loadMeals()
                await dataStore.refreshTasks()
            }
            .onChange(of: appState.backendDiscoveredVersion) {
                Task { await loadMeals(); await dataStore.refreshTasks() }
            }
        }
    }

    private func loadMeals() async {
        await MainActor.run { isLoadingMeals = true; backendUnreachable = false }
        do {
            var list = try await client.fetchMeals()
            if list.isEmpty && HappyDietConfig.defaultUserId == "demo" {
                list = Self.demoMealsFallback
            }
            await MainActor.run { meals = list; isLoadingMeals = false; backendUnreachable = false; loadMealsRetryCount = 0 }
        } catch {
            await MainActor.run {
                isLoadingMeals = false
                backendUnreachable = true
                if meals.isEmpty { meals = Self.demoMealsFallback }
                if loadMealsRetryCount < 1 {
                    loadMealsRetryCount += 1
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        await loadMeals()
                    }
                }
            }
        }
    }

    /// Same date range as web app: today back 14 days so compliance/weight chart shows data.
    private static var demoMealsFallback: [Meal] {
        let cal = Calendar.current
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var fallback: [Meal] = []
        let ingredientsList = [
            ["greek yogurt", "berries", "honey"], ["eggs", "avocado", "whole grain toast"],
            ["oatmeal", "banana", "almonds"], ["smoothie", "spinach", "banana"],
            ["grilled fish", "asparagus", "sweet potato"], ["oatmeal", "blueberries", "walnuts"],
            ["chicken salad", "quinoa", "olive oil"], ["grilled fish", "spinach", "sweet potato"],
            ["turkey wrap", "hummus", "carrots"], ["pizza", "soda"],
            ["smoothie", "spinach", "banana", "protein powder"], ["chicken stir-fry", "vegetables", "brown rice"],
            ["grilled chicken", "salad", "quinoa"], ["salmon", "broccoli", "rice"],
        ]
        let scores: [Double] = [78, 90, 92, 95, 96, 94, 88, 98, 85, 35, 95, 92, 95, 88]
        for i in 0..<14 {
            guard let date = cal.date(byAdding: .day, value: -i, to: now),
                  let at10 = cal.date(bySettingHour: 10, minute: 0, second: 0, of: date) else { continue }
            var ts = formatter.string(from: at10)
            if !ts.hasSuffix("Z") { ts += "Z" }
            let moment = i % 3 == 0 ? "breakfast" : (i % 3 == 1 ? "lunch" : "dinner")
            let ing = ingredientsList[i % ingredientsList.count]
            let score = scores[i % scores.count]
            fallback.append(Meal(
                id: "demo-\(i)",
                userId: "demo",
                timestamp: ts,
                mealMoment: moment,
                ingredients: ing,
                estimatedKcal: 350 + (i * 20) % 400,
                complianceScore: score,
                compliantItems: score >= 50 ? ing : [],
                nonCompliantItems: score < 50 ? ing : [],
                suggestions: [],
                dietVersion: nil
            ))
        }
        return fallback.sorted { (m1, m2) in (m1.timestamp ?? "") > (m2.timestamp ?? "") }
    }

    // MARK: - Compliance Trend (top)

    private var complianceTrendCard: some View {
        let trend = complianceTrend
        let hasData = !trend.isEmpty || !weightPoints.isEmpty

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Compliance & Weight")
                            .font(.headline)
                        Button {
                            showImpactInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textMuted)
                        }
                        .popover(isPresented: $showImpactInfo) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Impact")
                                    .font(.headline)
                                Text("Good compliance (80%+) supports your goals. Poor compliance adds up — the coach helps you understand what to adjust.")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textMuted)
                            }
                            .padding()
                            .frame(width: 260)
                        }
                    }
                    Text(hasData ? "14-day trend" : "Analyze meals to see trend")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                }
                Spacer()
                if complianceAverage > 0 {
                    Text("\(complianceAverage)%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(complianceAverage >= 80 ? Theme.green : complianceAverage >= 50 ? Theme.orange : Theme.red)
                }
            }
            ComplianceWeightChart(complianceTrend: trend, weightPoints: weightPoints)
                .frame(height: 120)
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

}

// MARK: - Compliance & Weight Chart (lines)

struct ComplianceWeightChart: View {
    let complianceTrend: [Double]
    let weightPoints: [(day: Int, kg: Double)]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pad: CGFloat = 4
            let maxCompliance = 100.0
            let weightKgs = weightPoints.map(\.kg)
            let minW = (weightKgs.min() ?? 50) - 5
            let maxW = (weightKgs.max() ?? 100) + 5
            let weightRange = max(maxW - minW, 1)

            ZStack(alignment: .bottomLeading) {
                // Compliance line
                if !complianceTrend.isEmpty {
                    Path { path in
                        let step = (w - pad * 2) / max(1, CGFloat(complianceTrend.count - 1))
                        for (i, v) in complianceTrend.enumerated() {
                            let x = pad + CGFloat(i) * step
                            let y = h - pad - (v / maxCompliance) * (h - pad * 2)
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(Theme.accent, lineWidth: 2)
                }
                // Weight line
                if !weightPoints.isEmpty {
                    Path { path in
                        let step = (w - pad * 2) / 13
                        for (i, pt) in weightPoints.enumerated() {
                            let x = pad + CGFloat(pt.day) * step
                            let norm = (pt.kg - minW) / weightRange
                            let y = h - pad - CGFloat(norm) * (h - pad * 2)
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(Theme.orange, lineWidth: 2)
                }
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 12) {
                    if !complianceTrend.isEmpty {
                        HStack(spacing: 4) {
                            Circle().fill(Theme.accent).frame(width: 12, height: 12)
                            Text("Compliance").font(.caption2).foregroundStyle(Theme.textMuted)
                        }
                    }
                    if !weightPoints.isEmpty {
                        HStack(spacing: 4) {
                            Circle().fill(Theme.orange).frame(width: 12, height: 12)
                            Text("Weight").font(.caption2).foregroundStyle(Theme.textMuted)
                        }
                    }
                }
            }
        }
    }
}
