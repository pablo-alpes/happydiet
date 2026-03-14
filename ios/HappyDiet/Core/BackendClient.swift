//
//  BackendClient.swift
//  HappyDiet
//
//  HTTP client for HappyDiet backend: POST /analyze-meal, GET /meals
//

import Foundation

// MARK: - Models

struct AnalyzeMealRequest: Encodable {
    let image_base64: String
    let user_id: String
    let diet_text: String?
}

struct ParseDietRequest: Encodable {
    let diet_text: String?
    let dietText: String?
    let image_base64: String?
    let imageBase64: String?
    let user_id: String
    let save: Bool
}

struct ParseDietResponse: Decodable {
    let rules: [DietRuleParsed]
    let saved: Bool?
}

struct DietRuleParsed: Decodable {
    let type: String?
    let items: [String]?
    let reason: String?
    let maxPortion: String?
    let maxPerDay: Int?
    let unit: String?
    let text: String?
}

struct AnalyzeMealResponse: Decodable {
    let score: Double
    let compliantItems: [String]
    let nonCompliantItems: [String]
    let suggestions: [String]
    let detalle: String?
    let message: String?
    let ingredients: [String]?
    let estimatedKcal: Int?

    enum CodingKeys: String, CodingKey { case score, compliantItems, nonCompliantItems, suggestions, detalle, message, ingredients, estimatedKcal }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        score = try c.decode(Double.self, forKey: .score)
        compliantItems = (try? c.decode([String].self, forKey: .compliantItems)) ?? []
        nonCompliantItems = (try? c.decode([String].self, forKey: .nonCompliantItems)) ?? []
        suggestions = (try? c.decode([String].self, forKey: .suggestions)) ?? []
        detalle = try c.decodeIfPresent(String.self, forKey: .detalle)
        message = try c.decodeIfPresent(String.self, forKey: .message)
        ingredients = try c.decodeIfPresent([String].self, forKey: .ingredients)
        if let i = try? c.decodeIfPresent(Int.self, forKey: .estimatedKcal) { estimatedKcal = i }
        else if let d = try? c.decodeIfPresent(Double.self, forKey: .estimatedKcal) { estimatedKcal = Int(d.rounded()) }
        else { estimatedKcal = nil }
    }
}

struct MealsResponse: Decodable {
    let meals: [Meal]
}

struct Meal: Decodable, Identifiable {
    let id: String?
    let userId: String?
    let timestamp: String?
    let mealMoment: String?
    let ingredients: [String]
    let estimatedKcal: Int?
    let complianceScore: Double
    let compliantItems: [String]
    let nonCompliantItems: [String]
    let suggestions: [String]
    let dietVersion: String?

    var displayId: String { id ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case id, userId, timestamp, mealMoment, ingredients, estimatedKcal
        case complianceScore, compliantItems, nonCompliantItems, suggestions, dietVersion
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        userId = try c.decodeIfPresent(String.self, forKey: .userId)
        if let ts = try? c.decode(String.self, forKey: .timestamp) {
            timestamp = ts
        } else if let raw = try? c.decode(Double.self, forKey: .timestamp) {
            let secs = raw > 1e12 ? raw / 1000 : raw
            timestamp = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: secs))
        } else {
            timestamp = nil
        }
        mealMoment = try c.decodeIfPresent(String.self, forKey: .mealMoment)
        ingredients = (try? c.decode([String].self, forKey: .ingredients)) ?? []
        if let intVal = try? c.decodeIfPresent(Int.self, forKey: .estimatedKcal) {
            estimatedKcal = intVal
        } else if let doubleVal = try? c.decodeIfPresent(Double.self, forKey: .estimatedKcal) {
            estimatedKcal = Int(doubleVal.rounded())
        } else {
            estimatedKcal = nil
        }
        complianceScore = (try? c.decode(Double.self, forKey: .complianceScore)) ?? 0
        compliantItems = (try? c.decode([String].self, forKey: .compliantItems)) ?? []
        nonCompliantItems = (try? c.decode([String].self, forKey: .nonCompliantItems)) ?? []
        suggestions = (try? c.decode([String].self, forKey: .suggestions)) ?? []
        dietVersion = try c.decodeIfPresent(String.self, forKey: .dietVersion)
    }
}

// MARK: - BackendClient

enum BackendError: Error {
    case invalidURL
    case httpError(status: Int, message: String?)
    case decodingError(Error)
    case networkError(Error)
}

final class BackendClient {
    private let baseURL: URL
    private let apiKey: String?
    private let session: URLSession

    init(baseURL: URL = HappyDietConfig.backendURL, apiKey: String? = HappyDietConfig.apiKey) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = URLSession.shared
    }

    /// POST /analyze-meal
    func analyzeMeal(imageBase64: String, userId: String = HappyDietConfig.defaultUserId, dietText: String? = nil) async throws -> AnalyzeMealResponse {
        let url = baseURL.appendingPathComponent("analyze-meal")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = apiKey { request.setValue(key, forHTTPHeaderField: "X-API-Key") }

        let body = AnalyzeMealRequest(image_base64: imageBase64, user_id: userId, diet_text: dietText)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(data: data, response: response, url: url)

        do {
            return try JSONDecoder().decode(AnalyzeMealResponse.self, from: data)
        } catch {
            throw BackendError.decodingError(error)
        }
    }

    /// POST /parse-diet (text or image)
    func parseDiet(dietText: String? = nil, imageBase64: String? = nil, userId: String = HappyDietConfig.defaultUserId, save: Bool = false) async throws -> ParseDietResponse {
        let url = baseURL.appendingPathComponent("parse-diet")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = apiKey { request.setValue(key, forHTTPHeaderField: "X-API-Key") }

        var body: [String: Any] = ["user_id": userId, "save": save]
        if let text = dietText, !text.isEmpty { body["diet_text"] = text }
        if let img = imageBase64, !img.isEmpty { body["image_base64"] = img }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(data: data, response: response, url: url)
        return try JSONDecoder().decode(ParseDietResponse.self, from: data)
    }

    /// POST /speak — returns MP3 audio data
    func speak(text: String) async throws -> Data {
        let url = baseURL.appendingPathComponent("speak")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = apiKey { request.setValue(key, forHTTPHeaderField: "X-API-Key") }
        request.httpBody = try JSONEncoder().encode(["text": text])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { return data }
        guard (200...299).contains(http.statusCode) else { throw BackendError.httpError(status: http.statusCode, message: "TTS failed") }
        return data
    }

    /// GET /rules?user_id=
    func fetchRules(userId: String = HappyDietConfig.defaultUserId) async throws -> [DietRuleParsed] {
        var components = URLComponents(url: baseURL.appendingPathComponent("rules"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "user_id", value: userId)]
        guard let url = components.url else { throw BackendError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let key = apiKey { request.setValue(key, forHTTPHeaderField: "X-API-Key") }

        let (data, response) = try await session.data(for: request)
        try validateResponse(data: data, response: response, url: url)

        struct RulesResponse: Decodable { let rules: [DietRuleParsed] }
        let decoded = try JSONDecoder().decode(RulesResponse.self, from: data)
        return decoded.rules
    }

    /// GET /meals?user_id=
    func fetchMeals(userId: String = HappyDietConfig.defaultUserId) async throws -> [Meal] {
        var components = URLComponents(url: baseURL.appendingPathComponent("meals"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "user_id", value: userId)]
        guard let url = components.url else { throw BackendError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let key = apiKey { request.setValue(key, forHTTPHeaderField: "X-API-Key") }

        let (data, response) = try await session.data(for: request)
        try validateResponse(data: data, response: response, url: url)

        do {
            let decoded = try JSONDecoder().decode(MealsResponse.self, from: data)
            return decoded.meals
        } catch {
            throw BackendError.decodingError(error)
        }
    }

    private func validateResponse(data: Data, response: URLResponse, url: URL) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw BackendError.httpError(status: http.statusCode, message: message)
        }
    }
}
