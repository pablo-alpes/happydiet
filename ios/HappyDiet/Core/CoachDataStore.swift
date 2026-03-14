//
//  CoachDataStore.swift
//  HappyDiet
//
//  Shared state: tasks, diet profile, weight, checkins, targets. Persisted to UserDefaults.
//

import Foundation

// MARK: - Task

struct CoachTask: Identifiable, Codable {
    var id: String { uid }
    var uid: String
    let task: String
    let due: String
    var done: Bool

    init(task: String, due: String, done: Bool = false) {
        self.uid = UUID().uuidString
        self.task = task
        self.due = due
        self.done = done
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uid = (try? c.decode(String.self, forKey: .id)) ?? (try? c.decode(String.self, forKey: .uid)) ?? UUID().uuidString
        task = try c.decode(String.self, forKey: .task)
        due = (try? c.decode(String.self, forKey: .due)) ?? ""
        done = (try? c.decode(Bool.self, forKey: .done)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(uid, forKey: .uid)
        try c.encode(task, forKey: .task)
        try c.encode(due, forKey: .due)
        try c.encode(done, forKey: .done)
    }

    enum CodingKeys: String, CodingKey { case id, uid, task, due, done }
}

// MARK: - Diet Profile

struct DietProfileItem: Identifiable {
    let id: String
    let label: String
}

let DIET_PROFILES: [DietProfileItem] = [
    DietProfileItem(id: "weekend_slip", label: "I slip on weekends"),
    DietProfileItem(id: "stress_eat", label: "I eat more when stressed"),
    DietProfileItem(id: "skip_breakfast", label: "I often skip breakfast"),
    DietProfileItem(id: "social_eat", label: "I struggle eating out"),
    DietProfileItem(id: "late_snack", label: "I snack late at night"),
]

// MARK: - Predefined Tasks

struct PredefinedTask {
    let task: String
    let due: String
}

let PREDEFINED_TASKS: [PredefinedTask] = [
    PredefinedTask(task: "Log my weight tomorrow morning", due: "tomorrow"),
    PredefinedTask(task: "Eat a compliant breakfast 5 days this week", due: "this week"),
    PredefinedTask(task: "Share my next meal photo", due: ""),
    PredefinedTask(task: "Drink 2L water today", due: "today"),
    PredefinedTask(task: "No soda for 3 days", due: "3 days"),
]

// MARK: - Quick Prompts (tab-specific)

let COACH_PROMPTS: [String: [String]] = [
    "diet": [
        "Suggest meal ideas and show me what they look like",
        "Let's do a coaching session on my compliance",
        "What I find difficult: [see my feedback]",
        "Help me improve where I slip",
        "Give me tasks to work on",
        "What's my overall status and what do you advise?",
    ],
    "analyze": [
        "Suggest meal ideas and show me what they look like",
        "What made this meal non-compliant?",
        "How's my weight today? How do I feel?",
        "Suggest a similar compliant meal",
        "Give me tasks to work on",
        "What's my overall status and what do you advise?",
    ],
    "dashboard": [
        "Suggest meal ideas and show me what they look like",
        "Let's do a coaching session on my compliance",
        "Am I on track with my weight?",
        "What does my compliance trend mean?",
        "Give me tasks to work on",
        "What's my overall status and what do you advise?",
    ],
]

// MARK: - Data Store

@MainActor
final class CoachDataStore: ObservableObject {
    static let shared = CoachDataStore()

    @Published var tasks: [CoachTask] = []
    private let backendClient = BackendClient()
    @Published var dietProfileIds: Set<String> = []
    @Published var weightEntries: [WeightEntry] = []
    @Published var checkins: [CheckinEntry] = []
    @Published var targets: TargetData = TargetData()
    @Published var feedbackEntries: [FeedbackEntry] = []
    @Published var journalEntries: [CoachJournalEntry] = []

    private let profileKey = "happydiet_profile"
    private let weightKey = "happydiet_weight"
    private let checkinsKey = "happydiet_checkins"
    private let targetsKey = "happydiet_targets"
    private let feedbackKey = "happydiet_feedback"
    private let journalKey = "happydiet_journal"

    init() {
        loadAll()
    }

    private func loadAll() {
        tasks = []
        if let arr = UserDefaults.standard.array(forKey: profileKey) as? [String] {
            dietProfileIds = Set(arr)
        }
        weightEntries = load([WeightEntry].self, key: weightKey) ?? []
        checkins = load([CheckinEntry].self, key: checkinsKey) ?? []
        if let t = load(TargetData.self, key: targetsKey) { targets = t }
        feedbackEntries = load([FeedbackEntry].self, key: feedbackKey) ?? []
        journalEntries = load([CoachJournalEntry].self, key: journalKey) ?? []
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(type, from: data) else { return nil }
        return decoded
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // Tasks (shared via backend Firestore)
    func refreshTasks() async {
        do {
            let list = try await backendClient.fetchTasks()
            tasks = list
        } catch {
            // Keep existing tasks on network error
        }
    }

    func addTask(_ task: String, due: String) {
        guard !task.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard !tasks.contains(where: { $0.task == task && $0.due == due && !$0.done }) else { return }
        Task {
            do {
                try await backendClient.addTask(task: task.trimmingCharacters(in: .whitespaces), due: due)
                await refreshTasks()
            } catch {
                // Optimistically add for offline UX; will sync on next refresh
                let t = CoachTask(task: task, due: due, done: false)
                tasks.insert(t, at: 0)
            }
        }
    }

    func toggleTaskDone(_ task: CoachTask) {
        Task {
            do {
                try await backendClient.toggleTaskDone(taskId: task.uid)
                await refreshTasks()
            } catch {
                if let i = tasks.firstIndex(where: { $0.uid == task.uid }) {
                    tasks[i].done.toggle()
                }
            }
        }
    }

    var activeTasks: [CoachTask] { tasks.filter { !$0.done } }

    // Diet profile
    func toggleProfile(_ id: String) {
        if dietProfileIds.contains(id) { dietProfileIds.remove(id) }
        else { dietProfileIds.insert(id) }
        UserDefaults.standard.set(Array(dietProfileIds), forKey: profileKey)
    }

    func isProfileSelected(_ id: String) -> Bool { dietProfileIds.contains(id) }

    // Weight
    func addWeight(kg: Double, note: String = "") {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let e = WeightEntry(date: formatter.string(from: Date()), kg: kg, note: note)
        weightEntries.insert(e, at: 0)
        save(weightEntries, key: weightKey)
    }

    // Checkins
    func addCheckin(weight: Double?, energy: String?, mood: String?, hunger: String?) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let e = CheckinEntry(
            date: formatter.string(from: Date()),
            weight: weight,
            energy: energy,
            mood: mood,
            hunger: hunger
        )
        checkins.insert(e, at: 0)
        save(checkins, key: checkinsKey)
        if let w = weight, w >= 30, w <= 300 {
            addWeight(kg: w, note: [energy, mood, hunger].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", "))
        }
    }

    // Targets
    func saveTargets(goal: String, targetWeight: Double?, targetDate: String?) {
        targets = TargetData(goal: goal, targetWeight: targetWeight, targetDate: targetDate)
        save(targets, key: targetsKey)
    }

    // Coach Journal
    func addJournalEntry(text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let e = CoachJournalEntry(date: formatter.string(from: Date()), text: t)
        journalEntries.insert(e, at: 0)
        if journalEntries.count > 100 { journalEntries = Array(journalEntries.prefix(100)) }
        save(journalEntries, key: journalKey)
    }

    func deleteJournalEntry(_ entry: CoachJournalEntry) {
        journalEntries.removeAll { $0.uid == entry.uid }
        save(journalEntries, key: journalKey)
    }

    // Feedback
    func addFeedback(_ text: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let e = FeedbackEntry(date: formatter.string(from: Date()), text: text)
        feedbackEntries.insert(e, at: 0)
        save(feedbackEntries, key: feedbackKey)
    }

    /// Clear all local data (weight, checkins, targets, feedback, journal). Tasks are in Firestore — not cleared here.
    func clearLocalData() {
        weightEntries = []
        checkins = []
        targets = TargetData()
        feedbackEntries = []
        journalEntries = []
        save(weightEntries, key: weightKey)
        save(checkins, key: checkinsKey)
        save(targets, key: targetsKey)
        save(feedbackEntries, key: feedbackKey)
        save(journalEntries, key: journalKey)
    }
}

struct WeightEntry: Codable, Identifiable {
    var id: String { date + String(kg) }
    let date: String
    let kg: Double
    let note: String
}

struct CheckinEntry: Codable, Identifiable {
    var id: String { date + (weight.map { String($0) } ?? "") }
    let date: String
    let weight: Double?
    let energy: String?
    let mood: String?
    let hunger: String?
}

struct TargetData: Codable {
    var goal: String = "maintain"
    var targetWeight: Double?
    var targetDate: String?
}

struct FeedbackEntry: Identifiable, Codable {
    var id: String { date + text }
    let date: String
    let text: String
}

// MARK: - Coach Journal (main things learnt)

struct CoachJournalEntry: Identifiable, Codable {
    var id: String { uid }
    var uid: String
    let date: String
    let text: String

    init(date: String, text: String) {
        self.uid = UUID().uuidString
        self.date = date
        self.text = text
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uid = (try? c.decode(String.self, forKey: .uid)) ?? UUID().uuidString
        date = try c.decode(String.self, forKey: .date)
        text = try c.decode(String.self, forKey: .text)
    }

    enum CodingKeys: String, CodingKey { case uid, date, text }
}
