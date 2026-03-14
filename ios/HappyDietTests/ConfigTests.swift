//
//  ConfigTests.swift
//  HappyDietTests
//
//  Unit tests for HappyDietConfig (backend URL, override).
//

import XCTest
@testable import HappyDiet

final class ConfigTests: XCTestCase {

    override func tearDown() {
        HappyDietConfig.backendURLOverride = nil
        super.tearDown()
    }

    func testBackendURLOverride_WhenSet_ReturnsOverride() {
        HappyDietConfig.backendURLOverride = "http://192.168.1.5:8080"
        let url = HappyDietConfig.backendURL
        XCTAssertEqual(url.absoluteString, "http://192.168.1.5:8080")
    }

    func testBackendURLOverride_WhenEmpty_IgnoresOverride() {
        HappyDietConfig.backendURLOverride = ""
        let url = HappyDietConfig.backendURL
        XCTAssertNotEqual(url.absoluteString, "")
        XCTAssertTrue(url.absoluteString.contains("localhost") || url.absoluteString.contains("8080"))
    }

    func testBackendURLOverride_WhenNil_ClearsOverride() {
        HappyDietConfig.backendURLOverride = "http://192.168.1.5:8080"
        HappyDietConfig.backendURLOverride = nil
        let url = HappyDietConfig.backendURL
        XCTAssertTrue(url.absoluteString.contains("localhost") || url.absoluteString.contains("8080"))
    }

    func testBackendURLOverride_TrimsWhitespace() {
        HappyDietConfig.backendURLOverride = "  http://192.168.1.5:8080  "
        let url = HappyDietConfig.backendURL
        XCTAssertEqual(url.absoluteString, "http://192.168.1.5:8080")
    }

    func testDefaultUserId() {
        XCTAssertEqual(HappyDietConfig.defaultUserId, "demo")
    }
}
