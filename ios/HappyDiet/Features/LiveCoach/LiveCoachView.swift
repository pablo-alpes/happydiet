//
//  LiveCoachView.swift
//  HappyDiet
//
//  Live Coach tab: voice + vision via Gemini Live API.
//  Status bar, chat bubbles, quick prompts, mic, image sharing.
//

import SwiftUI
import AVFoundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let text: String
}

struct LiveCoachView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var dataStore: CoachDataStore
    @State private var client: LiveAPIClient?
    @State private var isConnected = false
    @State private var connectionStatus = "Disconnected"
    @State private var coachState = "idle"
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var showImagePicker = false
    @State private var showHeyCyanSheet = false
    @State private var selectedImage: UIImage?
    @State private var audioPlayer: LivePCMPlayer?
    @State private var liveDelegate: LiveCoachDelegate?
    @State private var isListening = false
    @State private var audioCapture: LiveAudioCapture?
    @State private var coachTextBuffer = ""
    @State private var streamingCoachText = ""
    @State private var waitingForCoachResponse = false
    @State private var lastSentWasMeal = false

    private let quickPrompts = [
        "Let's do a coaching session on my compliance",
        "Am I on track with my weight?",
        "What does my compliance trend mean?",
        "Give me tasks to work on",
        "What's my overall status and what do you advise?",
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statusBar
                    .padding(.horizontal)
                    .padding(.top, 8)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            if isConnected {
                                transcriptBubbles
                                if waitingForCoachResponse {
                                    thinkingIndicator
                                }
                            } else {
                                disconnectedPrompt
                            }
                        }
                        .padding()
                        .id("bottom")
                    }
                    .onChange(of: messages.count) {
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                    .onChange(of: streamingCoachText) {
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }

                if isConnected {
                    Divider()
                    quickPromptsRow
                    inputBar
                }
            }
            .background(Theme.bg)
            .navigationTitle("Live Coach")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(
                    sourceType: .photoLibrary,
                    onImagePicked: { img in
                        showImagePicker = false
                        handleImagePicked(img)
                    },
                    onCancel: { showImagePicker = false }
                )
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
            configureAudioSessionForCoach()
        }
        .onDisappear {
            audioCapture?.stop()
            audioPlayer?.stop()
            client?.disconnect()
        }
    }

    private func configureAudioSessionForCoach() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("LiveCoachView: audio session setup failed: \(error)")
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            Button(isConnected ? "Disconnect" : "Connect") {
                if isConnected {
                    audioPlayer?.stop()
                    client?.disconnect()
                    isConnected = false
                    connectionStatus = "Disconnected"
                    coachState = "idle"
                } else {
                    connect()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(isConnected ? Color.red : Theme.accent)
            .controlSize(.small)

            Spacer()

            statusDot(color: isConnected ? Theme.green : Theme.gray, label: isConnected ? "Connected" : connectionStatus)
            statusDot(color: isListening ? Theme.red : Theme.gray, label: isListening ? "Mic on" : "Mic off")
            statusDot(color: coachDotColor, label: coachStateLabel)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func statusDot(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textMuted)
                .lineLimit(1)
        }
    }

    private var coachDotColor: Color {
        switch coachState {
        case "speaking": return Theme.orange
        case "thinking": return Theme.orange.opacity(0.7)
        default: return Theme.gray
        }
    }

    private var coachStateLabel: String {
        switch coachState {
        case "speaking": return "Speaking"
        case "thinking": return "Thinking"
        default: return "Idle"
        }
    }

    // MARK: - Transcript Bubbles

    private var transcriptBubbles: some View {
        VStack(alignment: .leading, spacing: 10) {
            if messages.isEmpty && streamingCoachText.isEmpty {
                Text("Say hi or share a meal photo to start.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
            ForEach(messages) { msg in
                chatBubble(role: msg.role, text: msg.text)
            }
            if !streamingCoachText.isEmpty {
                chatBubble(role: "coach", text: streamingCoachText)
            }
        }
    }

    private func chatBubble(role: String, text: String) -> some View {
        HStack {
            if role == "user" { Spacer(minLength: 48) }
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(role == "user" ? Theme.accent : Color(.tertiarySystemBackground))
                .foregroundStyle(role == "user" ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            if role == "coach" { Spacer(minLength: 48) }
        }
    }

    private var thinkingIndicator: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(lastSentWasMeal ? "Analyzing meal…" : "Coach is thinking…")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)
                LoadingProgressBar()
                    .frame(height: 8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            Spacer(minLength: 48)
        }
    }

    private var disconnectedPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent.opacity(0.4))
            Text("Tap Connect to start your coaching session")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Backend: \(HappyDietConfig.backendURL.absoluteString)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Quick Prompts

    private var quickPromptsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickPrompts, id: \.self) { prompt in
                    Button {
                        inputText = prompt
                    } label: {
                        Text(prompt)
                            .font(.caption)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.accentMuted)
                            .foregroundStyle(Theme.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            Button {
                toggleVoice()
            } label: {
                Image(systemName: isListening ? "stop.circle.fill" : "mic.fill")
                    .font(.title3)
                    .foregroundStyle(isListening ? .red : Theme.accent)
            }
            .disabled(!isConnected)

            Button {
                showHeyCyanSheet = true
            } label: {
                Image(systemName: "eyeglasses")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
            }

            Button {
                showImagePicker = true
            } label: {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
            }

            TextField("Type a message...", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit { sendText() }

            Button {
                sendText()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(inputText.isEmpty ? Theme.gray : Theme.accent)
            }
            .disabled(inputText.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Networking

    private func connect() {
        connectionStatus = "Connecting..."
        let c = LiveAPIClient()
        let delegate = LiveCoachDelegate(
            onEvent: { event in
                Task { @MainActor in
                    handleEvent(event)
                }
            }
        )
        liveDelegate = delegate
        c.delegate = liveDelegate
        client = c
        let ctx = buildCoachContext()
        c.connect(context: ctx)
    }

    private func buildCoachContext() -> [String: Any] {
        var ctx: [String: Any] = [:]
        if let rules = UserDefaults.standard.string(forKey: "happydiet_rules"), !rules.isEmpty {
            ctx["rules"] = rules
        }
        if let profile = UserDefaults.standard.array(forKey: "happydiet_profile") as? [String], !profile.isEmpty {
            ctx["profile"] = profile.joined(separator: "; ")
        }
        let tasksStr = dataStore.activeTasks.map { $0.task + ($0.due.isEmpty ? "" : " (\($0.due))") }.joined(separator: "\n")
        if !tasksStr.isEmpty { ctx["tasks"] = tasksStr }
        let weightStr = dataStore.weightEntries.prefix(5).map { "\($0.date): \($0.kg) kg" }.joined(separator: "\n")
        if !weightStr.isEmpty { ctx["weight"] = weightStr }
        if let tw = dataStore.targets.targetWeight {
            ctx["targets"] = "Goal: \(dataStore.targets.goal), Target: \(Int(tw)) kg"
        }
        return ctx
    }

    private func handleEvent(_ event: LiveAPIEvent) {
        switch event {
        case .connected:
            isConnected = true
            connectionStatus = "Connected"
        case .disconnected(let reason):
            isConnected = false
            connectionStatus = reason ?? "Disconnected"
            coachState = "idle"
            waitingForCoachResponse = false
            lastSentWasMeal = false
        case .setupComplete:
            isConnected = true
            connectionStatus = "Connected"
            coachState = "idle"
            if let img = appState.consumePendingImageForCoach(), let b64 = img.toJPEGBase64() {
                client?.sendImage(base64: b64)
                messages.append(ChatMessage(role: "user", text: "[sent meal photo]"))
                lastSentWasMeal = true
                waitingForCoachResponse = true
                coachState = "thinking"
            }
        case .text(let s):
            coachState = "speaking"
            coachTextBuffer += s
            streamingCoachText = coachTextBuffer
        case .turnComplete:
            waitingForCoachResponse = false
            lastSentWasMeal = false
            coachState = "idle"
            if !coachTextBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messages.append(ChatMessage(role: "coach", text: coachTextBuffer.trimmingCharacters(in: .whitespacesAndNewlines)))
                dataStore.addJournalEntry(text: coachTextBuffer.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            coachTextBuffer = ""
            streamingCoachText = ""
        case .audio(let data):
            coachState = "speaking"
            if audioPlayer == nil {
                audioPlayer = LivePCMPlayer()
            }
            audioPlayer?.enqueue(data: data)
        case .interrupted:
            waitingForCoachResponse = false
            lastSentWasMeal = false
            coachState = "idle"
            coachTextBuffer = ""
            streamingCoachText = ""
        case .error(let msg):
            waitingForCoachResponse = false
            lastSentWasMeal = false
            coachState = "idle"
            connectionStatus = "Error"
            messages.append(ChatMessage(role: "coach", text: "Error: \(msg)"))
        }
    }

    private func sendText() {
        guard !inputText.isEmpty else { return }
        let text = inputText
        inputText = ""
        client?.sendText(text)
        messages.append(ChatMessage(role: "user", text: text))
        lastSentWasMeal = false
        waitingForCoachResponse = true
        coachState = "thinking"
    }

    private func handleImagePicked(_ image: UIImage) {
        guard let base64 = image.toJPEGBase64() else { return }
        client?.sendImage(base64: base64)
        messages.append(ChatMessage(role: "user", text: "[sent meal photo]"))
        lastSentWasMeal = true
        waitingForCoachResponse = true
        coachState = "thinking"
    }

    private func toggleVoice() {
        if isListening {
            audioCapture?.stop()
            client?.sendAudioStreamEnd()
            isListening = false
        } else {
            guard isConnected, let c = client else { return }
            let capture = LiveAudioCapture()
            capture.onChunk = { data in
                let b64 = data.base64EncodedString()
                c.sendAudioChunk(base64PCM: b64)
            }
            capture.onError = { msg in
                Task { @MainActor in
                    connectionStatus = msg
                    isListening = false
                }
            }
            capture.start()
            audioCapture = capture
            isListening = true
        }
    }

}

private final class LiveCoachDelegate: LiveAPIClientDelegate {
    let onEvent: (LiveAPIEvent) -> Void

    init(onEvent: @escaping (LiveAPIEvent) -> Void) {
        self.onEvent = onEvent
    }

    func liveClient(_ client: LiveAPIClient, didReceive event: LiveAPIEvent) {
        onEvent(event)
    }
}

// MARK: - PCM Audio Player (24kHz 16-bit mono from Live API)
// Queues audio chunks and plays them sequentially so coach voice is not cut off.

final class LivePCMPlayer {
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioQueue: [Data] = []
    private var isPlaying = false
    private let format = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)!

    func enqueue(data: Data) {
        guard data.count >= 2 else { return }
        audioQueue.append(data)
        if !isPlaying {
            processQueue()
        }
    }

    private func processQueue() {
        guard !audioQueue.isEmpty else {
            isPlaying = false
            return
        }
        let data = audioQueue.removeFirst()
        let frameCount = UInt32(data.count / 2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            processQueue()
            return
        }
        buffer.frameLength = frameCount
        data.withUnsafeBytes { raw in
            guard let ptr = raw.bindMemory(to: Int16.self).baseAddress else { return }
            buffer.int16ChannelData?[0].update(from: ptr, count: Int(frameCount))
        }
        if engine == nil {
            setupAudioSession()
            // Re-activate session to ensure we have audio focus for playback
            try? AVAudioSession.sharedInstance().setActive(true)
            let eng = AVAudioEngine()
            let node = AVAudioPlayerNode()
            eng.attach(node)
            eng.connect(node, to: eng.mainMixerNode, format: format)
            try? eng.start()
            engine = eng
            playerNode = node
        }
        guard let node = playerNode else { processQueue(); return }
        isPlaying = true
        node.scheduleBuffer(buffer) { [weak self] in
            DispatchQueue.main.async {
                self?.processQueue()
            }
        }
        node.play()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Use playAndRecord + defaultToSpeaker so coach voice plays through speaker (not earpiece)
            // when app uses both mic (voice input) and playback (coach response).
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            try session.overrideOutputAudioPort(.speaker)
        } catch {
            print("LivePCMPlayer: audio session setup failed: \(error)")
        }
    }

    func stop() {
        audioQueue.removeAll()
        isPlaying = false
        playerNode?.stop()
        engine?.stop()
        engine = nil
        playerNode = nil
    }
}
