//
//  CoachDataStoreTests.swift
//  HappyDietTests
//
//  Unit tests for CoachDataStore (journal, tasks).
//

import XCTest
@testable import HappyDiet

@MainActor
final class CoachDataStoreTests: XCTestCase {

    var store: CoachDataStore!
    private let profileKey = "happydiet_profile"
    private let weightKey = "happydiet_weight"
    private let checkinsKey = "happydiet_checkins"
    private let targetsKey = "happydiet_targets"
    private let feedbackKey = "happydiet_feedback"
    private let journalKey = "happydiet_journal"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: profileKey)
        UserDefaults.standard.removeObject(forKey: weightKey)
        UserDefaults.standard.removeObject(forKey: checkinsKey)
        UserDefaults.standard.removeObject(forKey: targetsKey)
        UserDefaults.standard.removeObject(forKey: feedbackKey)
        UserDefaults.standard.removeObject(forKey: journalKey)
        store = CoachDataStore()
        store.tasks = []
        store.journalEntries = []
    }

    override func tearDown() {
        store.journalEntries = []
        store.tasks = []
        store = nil
        super.tearDown()
    }

    func testAddJournalEntry_AddsEntry() {
        store.addJournalEntry(text: "Eat more vegetables")
        XCTAssertEqual(store.journalEntries.count, 1)
        XCTAssertTrue(store.journalEntries[0].text.contains("vegetables"))
    }

    func testAddJournalEntry_IgnoresEmpty() {
        store.addJournalEntry(text: "")
        store.addJournalEntry(text: "   ")
        XCTAssertEqual(store.journalEntries.count, 0)
    }

    func testAddJournalEntry_TrimsWhitespace() {
        store.addJournalEntry(text: "  Key insight  ")
        XCTAssertEqual(store.journalEntries.count, 1)
        XCTAssertEqual(store.journalEntries[0].text, "Key insight")
    }

    func testDeleteJournalEntry_RemovesEntry() {
        store.addJournalEntry(text: "To delete")
        XCTAssertEqual(store.journalEntries.count, 1)
        let entry = store.journalEntries[0]
        store.deleteJournalEntry(entry)
        XCTAssertEqual(store.journalEntries.count, 0)
    }

    func testAddTask_DuplicateIsIgnoredSynchronously() {
        store.tasks = [CoachTask(task: "Log weight", due: "tomorrow", done: false)]
        store.addTask("Log weight", due: "tomorrow")
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertEqual(store.tasks[0].task, "Log weight")
        XCTAssertEqual(store.tasks[0].due, "tomorrow")
        XCTAssertFalse(store.tasks[0].done)
    }

    func testActiveTasks_ExcludesDone() {
        store.tasks = [
            CoachTask(task: "Task 1", due: "today", done: true),
            CoachTask(task: "Task 2", due: "tomorrow", done: false),
        ]
        XCTAssertEqual(store.activeTasks.count, 1)
        XCTAssertEqual(store.activeTasks[0].task, "Task 2")
    }
}
