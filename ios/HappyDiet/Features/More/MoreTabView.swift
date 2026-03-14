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

// MARK: - Meal Suggestions (link to agent)

struct MealSuggestionsView: View {
    @EnvironmentObject var appState: AppState

    private let promptForCoach = "Suggest some healthy meal options for my diet and show me what they look like. Generate images of the meals you recommend."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Meal suggestions with images")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Ask the coach for personalized meal ideas. The coach can suggest options based on your diet plan and generate images so you can see what the meals look like.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)

                VStack(alignment: .leading, spacing: 12) {
                    Text("How it works")
                        .font(.subheadline.bold())
                    Text("1. Tap the button below to open the Coach")
                    Text("2. The coach will suggest meals and can generate images")
                    Text("3. You'll see both the suggestions and visual examples")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Button {
                    appState.mealSuggestionPrompt = promptForCoach
                    appState.selectedTab = 4
                } label: {
                    Label("Ask coach for meal suggestions", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
            .padding()
        }
        .background(Theme.bg)
        .navigationTitle("Meal Suggestions")
    }
}

// MARK: - Settings (Backend URL for device testing)

struct SettingsView: View {
    @EnvironmentObject var dataStore: CoachDataStore
    @State private var backendURLText: String = ""
    @State private var savedMessage: String?
    @State private var testResult: String?
    @State private var isTesting = false
    @State private var showClearConfirm = false
    @State private var isClearing = false
    @State private var clearResult: String?
    private let client = BackendClient()

    var body: some View {
        Form {
            Section {
                TextField("Backend URL override (optional)", text: $backendURLText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                Text("Leave empty for automatic backend discovery on device. Set only if you want a fixed URL (e.g. Cloud Run).")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                HStack {
                    Button("Save") {
                        let trimmed = backendURLText.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty {
                            HappyDietConfig.backendURLOverride = nil
                            savedMessage = "Using automatic backend selection"
                        } else {
                            let url = Self.normalizeBackendURL(trimmed)
                            HappyDietConfig.backendURLOverride = url
                            savedMessage = "Saved. Reconnect Coach to use new URL."
                        }
                    }
                    Spacer()
                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(isTesting)
                }
                if let msg = savedMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                }
                if isTesting {
                    ProgressView("Testing…")
                        .font(.caption)
                }
                if let result = testResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(result.hasPrefix("OK") ? Theme.accent : Theme.red)
                }
            } header: {
                Text("Backend URL")
            } footer: {
                let u = HappyDietConfig.backendURL
                let host = u.host ?? "?"
                let port = u.port ?? (u.scheme == "https" ? 443 : 8080)
                let ws = (u.scheme == "https" ? "wss" : "ws") + "://\(host):\(port)/live"
                Text("Current: \(HappyDietConfig.backendURL.absoluteString)\nLive Coach: \(ws)")
            }

            Section {
                let ttsURL = HappyDietConfig.ttsBaseURL.absoluteString
                Text("TTS URL: \(ttsURL)")
                    .font(.caption)
                    .textSelection(.enabled)
                if TTSHelper.lastTTSUsedGoogle {
                    Label("Last coach response: Google TTS", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                } else if let err = TTSHelper.lastTTSError, !err.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last coach response: device voice")
                            .font(.caption)
                        Text("Error: \(err)")
                            .font(.caption2)
                            .foregroundStyle(Theme.red)
                            .textSelection(.enabled)
                    }
                } else {
                    Text("Last coach response: —")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                }
            } header: {
                Text("Coach voice (TTS)")
            } footer: {
                Text("Voice uses POST /speak on the TTS URL above. If you see an error here, the app fell back to the device voice.")
            }

            Section {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("Clear all data", systemImage: "trash")
                }
                .disabled(isClearing)
                if isClearing {
                    ProgressView("Clearing…")
                }
                if let msg = clearResult {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                }
            } header: {
                Text("Data")
            } footer: {
                Text("Clears meals (backend), weight, tasks, checkins, targets, feedback, and journal. Cannot be undone.")
            }
        }
        .confirmationDialog("Clear all data?", isPresented: $showClearConfirm) {
            Button("Clear", role: .destructive) {
                Task { await clearAllData() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all your meals, weight logs, tasks, and other data. This cannot be undone.")
        }
        .navigationTitle("Settings")
        .onAppear {
            backendURLText = HappyDietConfig.backendURLOverride ?? HappyDietConfig.backendURL.absoluteString
        }
    }

    private static func normalizeBackendURL(_ input: String) -> String {
        var s = input.trimmingCharacters(in: .whitespaces)
        if !s.isEmpty && !s.hasPrefix("http://") && !s.hasPrefix("https://") {
            s = "http://" + s
        }
        return s
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        let base = HappyDietConfig.backendURL
        let healthURL = base.appendingPathComponent("health")
        var request = URLRequest(url: healthURL)
        request.timeoutInterval = 5
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                isTesting = false
                if let error {
                    testResult = "FAIL: \(error.localizedDescription)"
                } else if let http = response as? HTTPURLResponse {
                    if (200...299).contains(http.statusCode) {
                        testResult = "OK — Backend reachable (\(http.statusCode))"
                    } else {
                        testResult = "FAIL: HTTP \(http.statusCode)"
                    }
                } else {
                    testResult = "FAIL: No response"
                }
            }
        }.resume()
    }

    private func clearAllData() async {
        isClearing = true
        clearResult = nil
        var parts: [String] = []
        do {
            let n = try await client.clearMeals()
            if n > 0 { parts.append("\(n) meals") }
        } catch {
            parts.append("meals: \(error.localizedDescription)")
        }
        await MainActor.run {
            dataStore.clearLocalData()
            parts.append("local data")
            clearResult = parts.isEmpty ? "Cleared." : "Cleared: \(parts.joined(separator: ", "))."
            isClearing = false
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
        .task { await dataStore.refreshTasks() }
    }
}
