//
//  Config.swift
//  HappyDiet
//
//  Reads BACKEND_URL from UserDefaults (override) or HappyDietConfig.plist.
//  On device: set override in More → Settings to your Mac IP (e.g. http://192.168.1.5:8080).
//

import Foundation

enum HappyDietConfig {
    private static let backendURLOverrideKey = "happydiet_backend_url_override"

    /// User-configurable override (e.g. for device: http://YOUR_MAC_IP:8080)
    static var backendURLOverride: String? {
        get { UserDefaults.standard.string(forKey: backendURLOverrideKey) }
        set { UserDefaults.standard.set(newValue, forKey: backendURLOverrideKey) }
    }

    static var backendURL: URL {
        if let override = backendURLOverride, !override.isEmpty,
           let url = URL(string: override.trimmingCharacters(in: .whitespaces)),
           url.scheme != nil, url.host != nil {
            return url
        }
        guard let path = Bundle.main.path(forResource: "HappyDietConfig", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let urlString = dict["BACKEND_URL"] as? String, !urlString.isEmpty,
              let url = URL(string: urlString) else {
            return URL(string: "http://localhost:8080")!
        }
        return url
    }

    static var apiKey: String? {
        guard let path = Bundle.main.path(forResource: "HappyDietConfig", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let key = dict["API_KEY"] as? String, !key.isEmpty else {
            return nil
        }
        return key
    }

    static let defaultUserId = "demo"
}
