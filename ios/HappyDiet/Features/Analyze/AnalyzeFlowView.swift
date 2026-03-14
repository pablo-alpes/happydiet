//
//  AnalyzeFlowView.swift
//  HappyDiet
//
//  Tab 1: Capture → analyze → show compliance (score, message, items)
//

import SwiftUI

struct AnalyzeFlowView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showHeyCyanSheet = false
    @State private var useCamera = true
    @State private var isAnalyzing = false
    @State private var result: AnalyzeMealResponse?
    @State private var errorMessage: String?

    private let client = BackendClient()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        if isAnalyzing {
                            ProgressView("Analyzing meal…")
                                .padding()
                        } else if let r = result {
                            ComplianceCard(response: r, onSpeak: { speakCompliance(r) }, onHearFromCoach: { appState.requestCoachForImage(selectedImage) })
                        } else if let err = errorMessage {
                            ErrorBanner(message: err)
                        }

                        Button("Choose Another") {
                            resetFlow()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        VStack(spacing: 16) {
                            Text("Capture or select a meal photo")
                                .font(.headline)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 16) {
                                Button {
                                    useCamera = true
                                    showImagePicker = true
                                } label: {
                                    Label("Camera", systemImage: "camera.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

                                Button {
                                    useCamera = false
                                    showImagePicker = true
                                } label: {
                                    Label("Photo Library", systemImage: "photo.on.rectangle")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)

                                Button {
                                    showHeyCyanSheet = true
                                } label: {
                                    Label("HeyCyan", systemImage: "eyeglasses")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Analyze Meal")
            .sheet(isPresented: $showImagePicker) {
                if useCamera {
                    ImagePicker(sourceType: .camera, onImagePicked: handleImagePicked, onCancel: { showImagePicker = false })
                } else {
                    ImagePicker(sourceType: .photoLibrary, onImagePicked: handleImagePicked, onCancel: { showImagePicker = false })
                }
            }
            .sheet(isPresented: $showHeyCyanSheet) {
                HeyCyanCaptureSheet(
                    onImagePicked: { img in
                        showHeyCyanSheet = false
                        handleImagePicked(img)
                    },
                    onCancel: { showHeyCyanSheet = false }
                )
            }
        }
    }

    private func handleImagePicked(_ image: UIImage) {
        showImagePicker = false
        selectedImage = image
        result = nil
        errorMessage = nil
        isAnalyzing = true
        Task {
            await analyzeImage(image)
        }
    }

    private func analyzeImage(_ image: UIImage) async {
        guard let base64 = image.toJPEGBase64() else {
            await MainActor.run {
                errorMessage = "Could not encode image"
                isAnalyzing = false
            }
            return
        }
        do {
            let response = try await client.analyzeMeal(imageBase64: base64)
            await MainActor.run {
                result = response
                isAnalyzing = false
            }
        } catch let e as BackendError {
            await MainActor.run {
                errorMessage = errorDescription(e)
                isAnalyzing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isAnalyzing = false
            }
        }
    }

    private func errorDescription(_ e: BackendError) -> String {
        switch e {
        case .httpError(let status, let msg):
            if status == 503 { return "Backend not configured. Start the server or set GOOGLE_CLOUD_PROJECT." }
            return msg ?? "HTTP \(status)"
        case .decodingError(let err): return "Invalid response: \(err.localizedDescription)"
        case .networkError(let err): return "Network: \(err.localizedDescription)"
        case .invalidURL: return "Invalid URL"
        }
    }

    private func speakCompliance(_ r: AnalyzeMealResponse) {
        let text = r.message ?? buildFallbackMessage(r)
        Task {
            await TTSHelper.speak(text, backend: client)
        }
    }

    private func buildFallbackMessage(_ r: AnalyzeMealResponse) -> String {
        var parts: [String] = []
        parts.append("Compliance score: \(Int(r.score)) out of 100.")
        if !r.compliantItems.isEmpty {
            parts.append("Compliant: \(r.compliantItems.joined(separator: ", ")).")
        }
        if !r.nonCompliantItems.isEmpty {
            parts.append("Not compliant: \(r.nonCompliantItems.joined(separator: ", ")).")
        }
        if !r.suggestions.isEmpty {
            parts.append("Suggestions: \(r.suggestions.joined(separator: ", ")).")
        }
        return parts.joined(separator: " ")
    }

    private func resetFlow() {
        selectedImage = nil
        result = nil
        errorMessage = nil
    }
}

// MARK: - Compliance Card

struct ComplianceCard: View {
    let response: AnalyzeMealResponse
    let onSpeak: () -> Void
    var onHearFromCoach: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Score: \(Int(response.score))/100")
                    .font(.title2.bold())
                Spacer()
                if let coach = onHearFromCoach {
                    Button(action: coach) {
                        Label("Hear from coach", systemImage: "bubble.left.and.bubble.right.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button(action: onSpeak) {
                    Image(systemName: "speaker.wave.2.fill")
                }
            }

            if let msg = response.message, !msg.isEmpty {
                Text(msg)
                    .font(.body)
            }

            if !response.compliantItems.isEmpty {
                Label("Compliant: \(response.compliantItems.joined(separator: ", "))", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
            if !response.nonCompliantItems.isEmpty {
                Label("Not compliant: \(response.nonCompliantItems.joined(separator: ", "))", systemImage: "xmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
            if !response.suggestions.isEmpty {
                Text("Suggestions: \(response.suggestions.joined(separator: "; "))")
                    .font(.subheadline)
            }
            if let kcal = response.estimatedKcal {
                Text("Est. \(kcal) kcal")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
