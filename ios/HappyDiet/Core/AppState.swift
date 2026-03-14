//
//  AppState.swift
//  HappyDiet
//
//  Shared app state for cross-tab communication (e.g. Analyze → Coach tab).
//

import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    /// When set, Coach tab sends this image when connected (e.g. from "Hear from coach" in Analyze).
    @Published var pendingImageForCoach: UIImage?

    /// When set, Analyze tab uses this image (e.g. from Lenses capture in More).
    @Published var pendingImageForAnalyze: UIImage?

    /// When set, Coach tab pre-fills this prompt (e.g. from Meal Suggestions).
    @Published var mealSuggestionPrompt: String?

    /// Selected tab index (0=Dashboard, 1=Diet, 2=Rules, 3=Analyze, 4=Coach, 5=Track, 6=Goals, 7=More)
    @Published var selectedTab: Int = 0

    /// Incremented when backend is auto-discovered — triggers views to refresh.
    @Published var backendDiscoveredVersion: Int = 0

    /// Switch to Coach tab and queue image for when user connects.
    func requestCoachForImage(_ image: UIImage?) {
        pendingImageForCoach = image
        selectedTab = 4
    }

    func consumePendingImageForCoach() -> UIImage? {
        defer { pendingImageForCoach = nil }
        return pendingImageForCoach
    }

    /// Queue image for Analyze tab and switch to it.
    func requestAnalyzeForImage(_ image: UIImage?) {
        pendingImageForAnalyze = image
        selectedTab = 3
    }

    func consumePendingImageForAnalyze() -> UIImage? {
        defer { pendingImageForAnalyze = nil }
        return pendingImageForAnalyze
    }

    func consumeMealSuggestionPrompt() -> String? {
        defer { mealSuggestionPrompt = nil }
        return mealSuggestionPrompt
    }
}
