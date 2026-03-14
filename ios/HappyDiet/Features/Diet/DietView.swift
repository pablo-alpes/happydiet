//
//  DietView.swift
//  HappyDiet
//
//  Diet rules matching website: intro, How it works, parse & save, full rules display.
//

import SwiftUI

struct DietView: View {
    @State private var dietText = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var showHeyCyanSheet = false
    @State private var isParsing = false
    @State private var parsedRules: [DietRuleParsed] = []
    @State private var errorMessage: String?
    @State private var feedbackText = ""
    @EnvironmentObject var dataStore: CoachDataStore

    private let client = BackendClient()
    private let feedbackQuick = ["Dinners", "Weekends", "Eating out", "Soda cravings", "Stress eating", "Breakfast skip", "Social events"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    rulesIntroCard
                    uploadCard
                    if !parsedRules.isEmpty {
                        rulesHowCard
                        fullRulesCard
                    }
                    feedbackCard
                    if let err = errorMessage {
                        ErrorBanner(message: err)
                    }
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(Theme.bg)
            .navigationTitle("Diet & Behaviour")
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: imagePickerSource, onImagePicked: handleImagePicked, onCancel: { showImagePicker = false })
            }
            .sheet(isPresented: $showHeyCyanSheet) {
                HeyCyanCaptureSheet(
                    onImagePicked: { img in
                        showHeyCyanSheet = false
                        selectedImage = img
                        errorMessage = nil
                    },
                    onCancel: { showHeyCyanSheet = false }
                )
            }
        }
    }

    private var rulesIntroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How it works")
                .font(.headline)
                .foregroundStyle(Theme.accent)
            Text("Your plan is parsed into four types of rules. The coach and meal analyzer use these to guide you — ask \"why can't I eat X?\" and the coach will explain based on your rules.")
                .font(.subheadline)
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.accentMutedGradient)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius)
                .stroke(Theme.accent.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
    }

    private var uploadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upload or type your diet plan")
                .font(.headline)
            Text("From text or image (printed plan, handwritten notes, PDF screenshot)")
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
            TextField("e.g. No sugar, no soda, avoid white bread. Allowed: vegetables, lean protein.", text: $dietText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(.primary)
                .lineLimit(3...6)
            FlowLayout(spacing: 10) {
                Button { parseAndSave(save: false) } label: {
                    Label("Parse", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.bordered)
                .disabled((dietText.isEmpty && selectedImage == nil) || isParsing)

                Button { parseAndSave(save: true) } label: {
                    Label("Parse & Save", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled((dietText.isEmpty && selectedImage == nil) || isParsing)

                Button {
                    imagePickerSource = .camera
                    showImagePicker = true
                } label: {
                    Label("Camera", systemImage: "camera.fill")
                }
                .buttonStyle(.bordered)
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

                Button {
                    imagePickerSource = .photoLibrary
                    showImagePicker = true
                } label: {
                    Label("Photo", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)

                Button {
                    showHeyCyanSheet = true
                } label: {
                    Label("Lenses", systemImage: "eyeglasses")
                }
                .buttonStyle(.bordered)

                Button { loadSavedRules() } label: {
                    Label("Load saved", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)
            }

            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Button("Clear image") { selectedImage = nil }
                    .font(.caption)
            }

            if isParsing {
                ProgressView("Parsing…")
                    .padding()
            }
        }
        .padding()
        .cardStyle()
    }

    private var rulesHowCard: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            rulesHowItem(icon: "🚫", label: "Avoid", desc: "Foods to skip", color: Theme.red)
            rulesHowItem(icon: "✓", label: "Prefer", desc: "Foods to choose", color: Theme.green)
            rulesHowItem(icon: "⚖", label: "Limit", desc: "Max per day", color: Theme.orange)
            rulesHowItem(icon: "📝", label: "Notes", desc: "Tips & reasons", color: Theme.gray)
        }
    }

    private func rulesHowItem(icon: String, label: String, desc: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(icon)
                .font(.title2)
            Text(label)
                .font(.subheadline.bold())
                .foregroundStyle(color)
            Text(desc)
                .font(.caption2)
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var fullRulesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your diet plan")
                .font(.headline)
            FullDietRulesView(rules: parsedRules)
        }
        .padding()
        .cardStyle()
    }

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compliance feedback — what's difficult?")
                .font(.headline)
            Text("Log what you struggle with. The coach uses this for coaching sessions.")
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
            Text("Quick choices")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(feedbackQuick, id: \.self) { q in
                        Button(q) {
                            dataStore.addFeedback(q)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.orange.opacity(0.2))
                        .foregroundStyle(Theme.orange)
                        .clipShape(Capsule())
                    }
                }
            }
            HStack {
                TextField("e.g. Dinners slip when I eat out…", text: $feedbackText)
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(.primary)
                Button("Add") {
                    let t = feedbackText.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty {
                        dataStore.addFeedback(t)
                        feedbackText = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(feedbackText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if !dataStore.feedbackEntries.isEmpty {
                ForEach(dataStore.feedbackEntries.prefix(10)) { e in
                    HStack {
                        Text(e.text)
                            .font(.subheadline)
                        Spacer()
                        Text(e.date)
                            .font(.caption2)
                            .foregroundStyle(Theme.gray)
                    }
                    .padding(8)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .cardStyle()
    }

    private func handleImagePicked(_ image: UIImage) {
        showImagePicker = false
        selectedImage = image
        errorMessage = nil
    }

    private func loadSavedRules() {
        errorMessage = nil
        Task {
            do {
                let rules = try await client.fetchRules()
                await MainActor.run {
                    parsedRules = rules
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func parseAndSave(save: Bool) {
        parsedRules = []
        errorMessage = nil
        isParsing = true
        Task {
            do {
                let response: ParseDietResponse
                if let img = selectedImage, let base64 = img.toJPEGBase64() {
                    response = try await client.parseDiet(imageBase64: base64, save: save)
                } else if !dietText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    response = try await client.parseDiet(dietText: dietText.trimmingCharacters(in: .whitespacesAndNewlines), save: save)
                } else {
                    await MainActor.run {
                        errorMessage = "Enter diet text or add an image."
                        isParsing = false
                    }
                    return
                }
                await MainActor.run {
                    parsedRules = response.rules
                    isParsing = false
                }
            } catch let e as BackendError {
                await MainActor.run {
                    errorMessage = errorDescription(e)
                    isParsing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isParsing = false
                }
            }
        }
    }

    private func errorDescription(_ e: BackendError) -> String {
        switch e {
        case .httpError(let status, let msg):
            if status == 503 { return "Backend not configured. Set GOOGLE_CLOUD_PROJECT." }
            return msg ?? "HTTP \(status)"
        case .decodingError(let err): return "Invalid response: \(err.localizedDescription)"
        case .networkError(let err): return "Network: \(err.localizedDescription)"
        case .invalidURL: return "Invalid URL"
        }
    }

    private func addFeedback(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        dataStore.addFeedback(t)
    }
}

// MARK: - Full Diet Rules Display (nicer: chips, why explanations)

private let RULE_WHY: [String: String] = [
    "forbidden": "These foods work against your goals. The coach can explain why each is restricted when you ask.",
    "allowed": "These fit your plan. Prioritize them when building meals — the coach can suggest combos.",
    "limit": "Enjoy in moderation. Staying under the limit keeps you on track.",
    "note": "Extra guidance from your plan. Use these to steer daily choices.",
]

struct FullDietRulesView: View {
    let rules: [DietRuleParsed]

    private var forbidden: [String] {
        rules.filter { ($0.type ?? "forbidden") == "forbidden" }.flatMap { $0.items ?? [] }.filter { !$0.isEmpty }
    }
    private var allowed: [String] {
        rules.filter { $0.type == "allowed" }.flatMap { $0.items ?? [] }.filter { !$0.isEmpty }
    }
    private var limits: [(items: [String], max: Int, unit: String)] {
        rules.compactMap { r -> (items: [String], max: Int, unit: String)? in
            guard r.type == "limit", let max = r.maxPerDay, let unit = r.unit else { return nil }
            return (r.items ?? [], max, unit)
        }
    }
    private var notes: [String] {
        rules.compactMap { r -> String? in
            guard r.type == "note", let t = r.text, !t.isEmpty else { return nil }
            return t
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !forbidden.isEmpty {
                RuleSectionChips(title: "🚫 Avoid", items: forbidden, color: Theme.red, why: RULE_WHY["forbidden"] ?? "")
            }
            if !allowed.isEmpty {
                RuleSectionChips(title: "✓ Prefer", items: allowed, color: Theme.green, why: RULE_WHY["allowed"] ?? "")
            }
            ForEach(Array(limits.enumerated()), id: \.offset) { _, lim in
                VStack(alignment: .leading, spacing: 8) {
                    RuleSectionChips(title: "⚖ Limit", items: lim.items, color: Theme.orange, why: RULE_WHY["limit"] ?? "")
                    Text("max \(lim.max) \(lim.unit)/day")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.orange)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.orange.opacity(0.08))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.orange)
                        .frame(width: 5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            if !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("📝 Notes & reasons")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.gray)
                    Text(notes.joined(separator: " • "))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textMuted)
                    Text(RULE_WHY["note"] ?? "")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                        .italic()
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.gray.opacity(0.08))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.gray)
                        .frame(width: 5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

struct RuleSectionChips: View {
    let title: String
    let items: [String]
    let color: Color
    let why: String

    private var cleanedItems: [String] {
        items.flatMap { item in
            var s = item
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
            while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
            s = s.trimmingCharacters(in: .whitespaces)
            // Consolidate parentheticals broken across lines (newlines already replaced above)
            // Split by semicolons into separate items
            return s.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }
        }
        .filter { item in
            let trimmed = item.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return false }
            let withoutPunctuation = trimmed.trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespaces)
            return !withoutPunctuation.isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(color)
            FlowLayout(spacing: 8) {
                ForEach(cleanedItems, id: \.self) { item in
                    Text(item)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(color.opacity(0.2))
                        .foregroundStyle(color)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            if !why.isEmpty {
                Text(why)
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                    .italic()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(color)
                .frame(width: 5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
