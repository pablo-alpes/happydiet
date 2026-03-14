//
//  DietView.swift
//  HappyDiet
//
//  Diet rules: text input, image capture, parse & save to backend.
//

import SwiftUI

struct DietView: View {
    @State private var dietText = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var useCamera = true
    @State private var isParsing = false
    @State private var parsedRules: [DietRuleParsed] = []
    @State private var errorMessage: String?

    private let client = BackendClient()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Enter diet rules or capture an image (printed plan, handwritten notes)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField("e.g. No sugar, no soda, avoid bread", text: $dietText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)

                    HStack(spacing: 12) {
                        Button {
                            parseAndSave(save: false)
                        } label: {
                            Label("Parse", systemImage: "doc.text.magnifyingglass")
                        }
                        .buttonStyle(.bordered)
                        .disabled(dietText.isEmpty && selectedImage == nil || isParsing)

                        Button {
                            parseAndSave(save: true)
                        } label: {
                            Label("Parse & Save", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(dietText.isEmpty && selectedImage == nil || isParsing)

                        Button {
                            useCamera = true
                            showImagePicker = true
                        } label: {
                            Label("Camera", systemImage: "camera.fill")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

                        Button {
                            useCamera = false
                            showImagePicker = true
                        } label: {
                            Label("Photo", systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            loadSavedRules()
                        } label: {
                            Label("Load saved", systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.bordered)
                    }

                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Button("Clear image") {
                            selectedImage = nil
                        }
                        .font(.caption)
                    }

                    if isParsing {
                        ProgressView("Parsing…")
                            .padding()
                    }

                    if !parsedRules.isEmpty {
                        FullDietRulesView(rules: parsedRules)
                    }

                    if let err = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(err)
                                .font(.subheadline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
            }
            .navigationTitle("Diet Rules")
            .sheet(isPresented: $showImagePicker) {
                if useCamera {
                    ImagePicker(sourceType: .camera, onImagePicked: handleImagePicked, onCancel: { showImagePicker = false })
                } else {
                    ImagePicker(sourceType: .photoLibrary, onImagePicked: handleImagePicked, onCancel: { showImagePicker = false })
                }
            }
        }
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
                    if let first = response.rules.first(where: { ($0.type ?? "forbidden") == "forbidden" }), let firstItems = first.items, !firstItems.isEmpty {
                        dietText = "Avoid: \(firstItems.joined(separator: ", "))"
                    }
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
}

// MARK: - Full Diet Rules Display

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
        VStack(alignment: .leading, spacing: 12) {
            if !forbidden.isEmpty {
                RuleSection(title: "Not allowed", items: forbidden, color: .red)
            }
            if !allowed.isEmpty {
                RuleSection(title: "Allowed", items: allowed, color: .green)
            }
            ForEach(Array(limits.enumerated()), id: \.offset) { _, lim in
                VStack(alignment: .leading, spacing: 4) {
                    RuleSection(title: "Limit", items: lim.items, color: .orange)
                    Text("max \(lim.max) \(lim.unit)/day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            if !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                    Text(notes.joined(separator: " • "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct RuleSection: View {
    let title: String
    let items: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(color)
            Text(items.joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(color)
                .lineLimit(nil)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

