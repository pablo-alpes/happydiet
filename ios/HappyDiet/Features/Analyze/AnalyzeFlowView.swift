//
//  AnalyzeFlowView.swift
//  HappyDiet
//
//  Tab: Capture (Lenses first) → analyze → compliance hero + analysis grid.
//

import SwiftUI

struct AnalyzeFlowView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var dataStore: CoachDataStore
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showHeyCyanSheet = false
    @State private var useCamera = true
    @State private var isAnalyzing = false
    @State private var result: AnalyzeMealResponse?
    @State private var errorMessage: String?
    @State private var checkinWeight: Double?
    @State private var checkinEnergy = ""
    @State private var checkinMood = ""
    @State private var checkinHunger = ""

    private let client = BackendClient()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let image = selectedImage {
                        imagePreviewSection(image: image)
                    } else {
                        captureSection
                    }
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(Theme.bg)
            .navigationTitle("Analyze Meal")
            .navigationBarTitleDisplayMode(.large)
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
        .onAppear {
            if let img = appState.consumePendingImageForAnalyze() {
                handleImagePicked(img)
            }
        }
    }

    private var captureSection: some View {
        VStack(spacing: 20) {
            Text("Capture or upload meal photo")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Analyze the meal — connect the coach to hear the result in Gemini's voice.")
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)

            // Lenses first (HeyCyan)
            Button {
                showHeyCyanSheet = true
            } label: {
                HStack {
                    Image(systemName: "eyeglasses")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("From Lenses")
                            .font(.headline)
                        Text("HeyCyan glasses — hands-free capture")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Theme.headerGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            }
            .buttonStyle(.plain)

            // Camera & Photo
            HStack(spacing: 16) {
                Button {
                    useCamera = true
                    showImagePicker = true
                } label: {
                    Label("Camera", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

                Button {
                    useCamera = false
                    showImagePicker = true
                } label: {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
        }
        .padding()
        .cardStyle()
    }

    private func imagePreviewSection(image: UIImage) -> some View {
        VStack(spacing: 20) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radius))

            if isAnalyzing {
                VStack(spacing: 12) {
                    ProgressView("Analyzing meal…")
                    LoadingProgressBar()
                        .frame(width: 200, height: 6)
                        .padding(.horizontal)
                }
                .padding()
            } else if let r = result {
                ComplianceHeroCard(response: r, onSpeak: { speakCompliance(r) }, onHearFromCoach: {
                    appState.requestCoachForImage(selectedImage)
                })
                Text("Connect the coach to hear the analysis in Gemini's voice.")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                AnalysisGridCard(response: r)
                if let kcal = r.estimatedKcal {
                    Text("Est. \(kcal) kcal")
                        .font(.subheadline)
                        .foregroundStyle(Theme.gray)
                }
                mealCheckinCard
            } else if let err = errorMessage {
                ErrorBanner(message: err)
            }

            Button("Choose Another") {
                resetFlow()
            }
            .buttonStyle(.bordered)
        }
    }

    private var mealCheckinCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick check-in (optional)")
                .font(.headline)
            Text("Weight & how you feel — the coach uses this. Or ask in chat: \"How's my weight today?\"")
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    TextField("Weight (kg)", value: $checkinWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                    Spacer()
                }
                HStack(spacing: 12) {
                    Picker("Energy", selection: $checkinEnergy) {
                        Text("Energy").tag("")
                        Text("Great").tag("great")
                        Text("Okay").tag("okay")
                        Text("Tired").tag("tired")
                    }
                    .pickerStyle(.menu)
                    Picker("Mood", selection: $checkinMood) {
                        Text("Mood").tag("")
                        Text("Good").tag("good")
                        Text("Neutral").tag("neutral")
                        Text("Low").tag("low")
                    }
                    .pickerStyle(.menu)
                    Picker("Hunger", selection: $checkinHunger) {
                        Text("Hunger").tag("")
                        Text("Satisfied").tag("satisfied")
                        Text("Okay").tag("okay")
                        Text("Hungry").tag("hungry")
                    }
                    .pickerStyle(.menu)
                    Spacer()
                }
                Button("Save") {
                    dataStore.addCheckin(
                        weight: checkinWeight,
                        energy: checkinEnergy.isEmpty ? nil : checkinEnergy,
                        mood: checkinMood.isEmpty ? nil : checkinMood,
                        hunger: checkinHunger.isEmpty ? nil : checkinHunger
                    )
                    checkinWeight = nil
                    checkinEnergy = ""
                    checkinMood = ""
                    checkinHunger = ""
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .frame(maxWidth: .infinity)
                .disabled(checkinWeight == nil && checkinEnergy.isEmpty && checkinMood.isEmpty && checkinHunger.isEmpty)
            }
        }
        .padding()
        .cardStyle()
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

// MARK: - Compliance Hero Card (website-style)

struct ComplianceHeroCard: View {
    let response: AnalyzeMealResponse
    let onSpeak: () -> Void
    let onHearFromCoach: () -> Void

    private var scoreColor: Color {
        let s = response.score
        if s >= 80 { return Theme.green }
        if s >= 50 { return Theme.orange }
        return Theme.red
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(response.score))/100")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(scoreColor)
                if let msg = response.message, !msg.isEmpty {
                    Text(msg)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textMuted)
                }
            }
            Spacer()
            VStack(spacing: 8) {
                Button(action: onHearFromCoach) {
                    Label("Hear from coach", systemImage: "bubble.left.and.bubble.right.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                Button(action: onSpeak) {
                    Image(systemName: "speaker.wave.2.fill")
                }
            }
        }
        .padding()
        .background(Theme.accentMuted)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
    }
}

// MARK: - Analysis Grid (full results: all blocks, all items)

struct AnalysisGridCard: View {
    let response: AnalyzeMealResponse

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if !(response.ingredients ?? []).isEmpty {
                AnalysisBlock(title: "Detected ingredients", items: response.ingredients ?? [], color: Theme.gray)
            }
            if !response.compliantItems.isEmpty {
                AnalysisBlock(title: "✓ Compliant", items: response.compliantItems, color: Theme.green)
            }
            if !response.nonCompliantItems.isEmpty {
                AnalysisBlock(title: "✗ Not compliant", items: response.nonCompliantItems, color: Theme.red)
            }
            if !response.suggestions.isEmpty {
                AnalysisBlock(title: "Suggestions", items: response.suggestions, color: Theme.orange)
            }
        }
        .padding()
        .cardStyle()
    }
}

struct AnalysisBlock: View {
    let title: String
    let items: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(color)
            ForEach(items, id: \.self) { item in
                Text("• \(item)")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct LoadingProgressBar: View {
    @State private var isAnimating = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.accent.opacity(0.2))
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [Theme.accent, Theme.accentLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * 0.35)
                    .offset(x: isAnimating ? geo.size.width : -geo.size.width * 0.35)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.orange.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
