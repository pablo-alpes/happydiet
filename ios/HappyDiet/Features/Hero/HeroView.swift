//
//  HeroView.swift
//  HappyDiet
//
//  Full-screen hero matching website: gradient, tagline, Get started.
//

import SwiftUI

struct HeroView: View {
    let onEnter: () -> Void

    var body: some View {
        ZStack {
            Theme.heroGradient
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                Text("HappyDiet")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Your AI diet coach — type or speak freely. Track meals, weight, and goals. The coach is always here.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineLimit(4)
                Button(action: onEnter) {
                    Text("Get started")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .padding(.top, 8)
                Spacer()
            }
        }
    }
}
