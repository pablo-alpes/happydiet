//
//  GoalsView.swift
//  HappyDiet
//
//  Tab: Weight target, compliance goals, target date.
//

import SwiftUI

struct GoalsView: View {
    @EnvironmentObject var dataStore: CoachDataStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    targetsCard
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(Theme.bg)
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.large)
        }
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
                    .frame(width: 140)
            }
            if dataStore.targets.targetWeight != nil || !(dataStore.targets.targetDate ?? "").isEmpty {
                Text(targetBadgeText)
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
            }
            Text("Log weight and meals in the Track tab.")
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
            Text("Compliance goals")
                .font(.subheadline.bold())
                .padding(.top, 8)
            Text("Aim for 80%+ compliance to see results. The coach helps you stay on track.")
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
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

}
