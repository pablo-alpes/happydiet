//
//  MoreTabView.swift
//  HappyDiet
//
//  Tab: Recent Meals, Meal Suggestions, Coach Tasks.
//

import SwiftUI

struct MoreTabView: View {
    @EnvironmentObject var dataStore: CoachDataStore
    @EnvironmentObject var appState: AppState
    @State private var showLensesSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showLensesSheet = true
                    } label: {
                        Label("Capture from Lenses", systemImage: "eyeglasses")
                    }
                } header: {
                    Text("HeyCyan Lenses")
                        .font(.headline)
                        .foregroundStyle(Theme.textMuted)
                } footer: {
                    Text("HeyCyan glasses: Camera, WiFi, or BLE. Captured photos go to Analyze.")
                }

                Section {
                    NavigationLink {
                        RecentMealsView()
                    } label: {
                        Label("Recent Meals", systemImage: "fork.knife")
                    }
                    NavigationLink {
                        MealSuggestionsView()
                    } label: {
                        Label("Meal Suggestions", systemImage: "lightbulb.fill")
                    }
                    NavigationLink {
                        CoachTasksView()
                    } label: {
                        Label("Coach Tasks", systemImage: "checkmark.circle")
                    }
                    NavigationLink {
                        CoachJournalView()
                    } label: {
                        Label("Coach Journal", systemImage: "book.closed")
                    }
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                } header: {
                    Text("Overview")
                        .font(.headline)
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .background(Theme.bg)
            .navigationTitle("More")
            .sheet(isPresented: $showLensesSheet) {
                HeyCyanCaptureSheet(
                    onImagePicked: { img in
                        showLensesSheet = false
                        appState.requestAnalyzeForImage(img)
                    },
                    onCancel: { showLensesSheet = false }
                )
            }
        }
    }
}

// MARK: - Recent Meals

struct RecentMealsView: View {
    @State private var meals: [Meal] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    private let client = BackendClient()

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let err = errorMessage {
                ErrorBanner(message: err)
                    .padding()
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
            }
        }
        .background(Theme.bg)
        .navigationTitle("Recent Meals")
        .refreshable { await loadMeals() }
        .task { await loadMeals() }
    }

    private func loadMeals() async {
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

// MARK: - Meal Suggestions

struct MealSuggestionsView: View {
    private let mealSuggestions: [String: [String]] = [
        "breakfast": ["Oatmeal with berries and almonds", "Greek yogurt with banana", "Eggs with avocado and whole grain toast"],
        "lunch": ["Grilled chicken salad with quinoa", "Turkey wrap with hummus", "Grilled fish with spinach and sweet potato"],
        "dinner": ["Salmon with broccoli and rice", "Grilled chicken with vegetables", "Lean protein with salad and whole grains"],
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Meal ideas based on your plan")
                    .font(.headline)
                    .foregroundStyle(.primary)

                ForEach(["breakfast", "lunch", "dinner"], id: \.self) { meal in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(meal.capitalized)
                            .font(.title3.bold())
                            .foregroundStyle(Theme.accent)

                        if let ideas = mealSuggestions[meal] {
                            ForEach(ideas, id: \.self) { idea in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .foregroundStyle(Theme.accent)
                                    Text(idea)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
                    .shadow(color: Theme.shadow, radius: 4, x: 0, y: 2)
                }
            }
            .padding()
        }
        .background(Theme.bg)
        .navigationTitle("Meal Suggestions")
    }
}

// MARK: - Settings (Backend URL for device testing)

struct SettingsView: View {
    @State private var backendURLText: String = ""
    @State private var savedMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("Backend URL (e.g. http://192.168.1.5:8080)", text: $backendURLText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                Text("On device: use your Mac's IP. Simulator: leave empty for localhost.")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                Button("Save") {
                    let trimmed = backendURLText.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty {
                        HappyDietConfig.backendURLOverride = nil
                        savedMessage = "Using default from plist"
                    } else {
                        HappyDietConfig.backendURLOverride = trimmed
                        savedMessage = "Saved. Reconnect Coach to use new URL."
                    }
                }
                if let msg = savedMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                }
            } header: {
                Text("Backend URL")
            } footer: {
                Text("Current: \(HappyDietConfig.backendURL.absoluteString)")
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            backendURLText = HappyDietConfig.backendURLOverride ?? ""
        }
    }
}

// MARK: - Coach Journal (main things learnt from the coach)

struct CoachJournalView: View {
    @EnvironmentObject var dataStore: CoachDataStore

    var body: some View {
        Group {
            if dataStore.journalEntries.isEmpty {
                ContentUnavailableView(
                    "No journal entries yet",
                    systemImage: "book.closed",
                    description: Text("Key insights from your coach will appear here as you chat.")
                )
            } else {
                List {
                    ForEach(dataStore.journalEntries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.text)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(entry.date)
                                .font(.caption)
                                .foregroundStyle(Theme.textMuted)
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                dataStore.deleteJournalEntry(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .background(Theme.bg)
        .navigationTitle("Coach Journal")
    }
}

// MARK: - Coach Tasks

struct CoachTasksView: View {
    @EnvironmentObject var dataStore: CoachDataStore

    var body: some View {
        List {
            if dataStore.tasks.isEmpty {
                ContentUnavailableView(
                    "No tasks yet",
                    systemImage: "checkmark.circle",
                    description: Text("The coach will assign tasks when you chat. Or add your own in the Agent tab.")
                )
            } else {
                ForEach(dataStore.tasks) { t in
                    HStack(spacing: 12) {
                        Button {
                            dataStore.toggleTaskDone(t)
                        } label: {
                            Image(systemName: t.done ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(t.done ? Theme.green : Theme.gray)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t.task)
                                .font(.body)
                                .foregroundStyle(t.done ? Theme.gray : .primary)
                                .strikethrough(t.done)
                            if !t.due.isEmpty {
                                Text("Due: \(t.due)")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .background(Theme.bg)
        .navigationTitle("Coach Tasks")
    }
}
