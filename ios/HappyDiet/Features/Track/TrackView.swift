//
//  TrackView.swift
//  HappyDiet
//
//  Tab: Weight, self-reported (checkins), recent meals.
//

import SwiftUI

struct TrackView: View {
    @EnvironmentObject var dataStore: CoachDataStore
    @EnvironmentObject var appState: AppState
    @State private var meals: [Meal] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var weightInput: Double?
    @State private var weightNote = ""
    @State private var showCheckinSheet = false
    @State private var checkinWeight: Double?
    @State private var checkinEnergy = ""
    @State private var checkinMood = ""
    @State private var checkinHunger = ""

    private let client = BackendClient()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    weightCard
                    checkinsCard
                    recentMealsCard
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(Theme.bg)
            .navigationTitle("Track")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await loadMealsAsync() }
            .task { await loadMealsAsync() }
            .sheet(isPresented: $showCheckinSheet) {
                NavigationStack {
                    Form {
                        TextField("Weight (kg)", value: $checkinWeight, format: .number)
                            .keyboardType(.decimalPad)
                        Picker("Energy", selection: $checkinEnergy) {
                            Text("—").tag("")
                            Text("Low").tag("low")
                            Text("Medium").tag("medium")
                            Text("High").tag("high")
                        }
                        Picker("Mood", selection: $checkinMood) {
                            Text("—").tag("")
                            Text("Good").tag("good")
                            Text("Okay").tag("okay")
                            Text("Low").tag("low")
                        }
                        Picker("Hunger", selection: $checkinHunger) {
                            Text("—").tag("")
                            Text("Not hungry").tag("not")
                            Text("Moderate").tag("moderate")
                            Text("Very hungry").tag("very")
                        }
                    }
                    .navigationTitle("Add Check-in")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showCheckinSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                dataStore.addCheckin(
                                    weight: checkinWeight,
                                    energy: checkinEnergy.isEmpty ? nil : checkinEnergy,
                                    mood: checkinMood.isEmpty ? nil : checkinMood,
                                    hunger: checkinHunger.isEmpty ? nil : checkinHunger
                                )
                                checkinWeight = nil
                                checkinEnergy = ""
                                checkinMood = ""
                                checkinHunger = ""
                                showCheckinSheet = false
                            }
                            .disabled(checkinWeight == nil && checkinEnergy.isEmpty && checkinMood.isEmpty && checkinHunger.isEmpty)
                        }
                    }
                }
            }
        }
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weight")
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
                ForEach(dataStore.weightEntries.prefix(8)) { e in
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

    private var checkinsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Self-reported")
                .font(.headline)
            Text("Quick check-ins: weight, energy, mood, hunger. The coach uses these.")
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
            Button("Add check-in") {
                showCheckinSheet = true
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            if !dataStore.checkins.isEmpty {
                ForEach(dataStore.checkins.prefix(5)) { c in
                    HStack {
                        Text(c.date)
                            .font(.caption)
                            .foregroundStyle(Theme.gray)
                        if let w = c.weight {
                            Text("\(w) kg")
                                .font(.caption.bold())
                        }
                        if let e = c.energy { Text("Energy: \(e)").font(.caption2) }
                        if let m = c.mood { Text("Mood: \(m)").font(.caption2) }
                        if let h = c.hunger { Text("Hunger: \(h)").font(.caption2) }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .cardStyle()
    }

    private var recentMealsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Meals")
                    .font(.headline)
                Spacer()
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
                Text("No meals yet. Analyze a meal from the Analyze tab.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.gray)
            } else {
                ForEach(meals.prefix(10)) { meal in
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
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}
