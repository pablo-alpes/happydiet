//
//  AppState.swift
//  HappyDiet
//
//  Shared app state for cross-tab communication (e.g. Analyze → Live Coach).
//

import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    /// When set, Live Coach should send this image when connected.
    @Published var pendingImageForCoach: UIImage?

    /// Selected tab index (0=Live, 1=Analyze, 2=Diet, 3=Dashboard)
    @Published var selectedTab: Int = 0

    func requestCoachForImage(_ image: UIImage?) {
        pendingImageForCoach = image
        selectedTab = 0
    }

    func consumePendingImageForCoach() -> UIImage? {
        defer { pendingImageForCoach = nil }
        return pendingImageForCoach
    }
}
