//
//  Config.swift
//  HappyDiet
//
//  Backend URL and API key configuration.
//  Edit HappyDietConfig.plist or use .xcconfig for Cloud Run URL.
//

import Foundation

enum HappyDietConfig {
    private static let configPlistName = "HappyDietConfig"
    private static let backendURLKey = "BACKEND_URL"
    private static let apiKeyKey = "API_KEY"

    /// Base URL for the HappyDiet backend (default: http://localhost:8080 for dev)
    static var backendURL: URL {
        if let urlString = value(for: backendURLKey), !urlString.isEmpty,
           let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return url
        }
        return URL(string: "http://localhost:8080")!
    }

    /// Optional API key for X-API-Key header
    static var apiKey: String? {
        value(for: apiKeyKey).flatMap { $0.isEmpty ? nil : $0 }
    }

    /// User ID for API calls (default: demo)
    static var defaultUserId: String { "demo" }

    private static func value(for key: String) -> String? {
        guard let path = Bundle.main.path(forResource: configPlistName, ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let value = dict[key] as? String else {
            return nil
        }
        return value
    }
}
