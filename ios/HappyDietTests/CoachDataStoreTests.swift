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

    override func setUp() {
        super.setUp()
        store = CoachDataStore()
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
        let entry = store.journalEntries[0]
        store.deleteJournalEntry(entry)
        XCTAssertEqual(store.journalEntries.count, 0)
    }

    func testAddTask_AddsTask() {
        store.addTask("Log weight", due: "tomorrow")
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertEqual(store.tasks[0].task, "Log weight")
        XCTAssertEqual(store.tasks[0].due, "tomorrow")
        XCTAssertFalse(store.tasks[0].done)
    }

    func testActiveTasks_ExcludesDone() {
        store.addTask("Task 1", due: "today")
        store.addTask("Task 2", due: "tomorrow")
        store.toggleTaskDone(store.tasks[0])
        XCTAssertEqual(store.activeTasks.count, 1)
        XCTAssertEqual(store.activeTasks[0].task, "Task 2")
    }
}
