//
//  Config.swift
//  HappyDiet
//
//  Backend URL is auto-detected at build time:
//    Simulator → http://localhost:8080
//    Device    → http://<Mac IP>:8080
//  Override in More → Settings if needed (e.g. Cloud Run URL).
//

import Foundation

enum HappyDietConfig {
    private static let backendURLOverrideKey = "happydiet_backend_url_override"

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
