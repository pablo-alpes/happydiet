//
//  Theme.swift
//  HappyDiet
//
//  Design system matching website: DM Sans / Space Grotesk feel, green accent.
//

import SwiftUI

enum Theme {
    static let accent = Color(red: 45/255, green: 106/255, blue: 79/255)
    static let accentLight = Color(red: 64/255, green: 145/255, blue: 108/255)
    static let accentMuted = Color(red: 45/255, green: 106/255, blue: 79/255).opacity(0.12)
    static let green = accent
    static let red = Color(red: 214/255, green: 40/255, blue: 40/255)
    static let orange = Color(red: 247/255, green: 127/255, blue: 0)
    static let gray = Color(red: 108/255, green: 117/255, blue: 125/255)
    static let textMuted = Color(red: 73/255, green: 80/255, blue: 87/255)
    static let bg = Color(red: 250/255, green: 249/255, blue: 246/255)
    static let card = Color.white
    static let radius: CGFloat = 14
    static let shadow = Color.black.opacity(0.06)

    static var headerGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentLight, Color(red: 27/255, green: 67/255, blue: 50/255)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var accentMutedGradient: LinearGradient {
        LinearGradient(
            colors: [accentMuted, accentLight.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .shadow(color: Theme.shadow, radius: 4, x: 0, y: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

