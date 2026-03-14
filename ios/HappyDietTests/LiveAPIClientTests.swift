//
//  LiveAPIClientTests.swift
//  HappyDietTests
//
//  Unit tests for LiveAPIClient (delegate errors, isConnected).
//

import XCTest
@testable import HappyDiet

final class LiveAPIClientTests: XCTestCase {

    func testIsConnected_InitiallyFalse() {
        let client = LiveAPIClient(baseURL: URL(string: "http://localhost:8080")!)
        XCTAssertFalse(client.isConnected)
    }

    func testInvalidURL_ReportsErrorToDelegate() {
        let url = URL(string: "file:///tmp")!
        let client = LiveAPIClient(baseURL: url)
        let delegate = MockLiveDelegate()
        client.delegate = delegate
        client.connect()
        XCTAssertTrue(delegate.receivedErrors.contains { $0.contains("Invalid") || $0.contains("URL") })
    }

    func testConnect_WithValidURL_StartsTask() {
        let client = LiveAPIClient(baseURL: URL(string: "http://localhost:8080")!)
        client.connect()
        XCTAssertTrue(client.isConnected)
        client.disconnect()
    }
}

// MARK: - Test delegate

private class MockLiveDelegate: LiveAPIClientDelegate {
    var receivedErrors: [String] = []

    func liveClient(_ client: LiveAPIClient, didReceive event: LiveAPIEvent) {
        if case .error(let msg) = event {
            receivedErrors.append(msg)
        }
    }
}
