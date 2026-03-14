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
    var imageData: Data?
    var imageCaption: String?

    init(role: String, text: String, imageData: Data? = nil, imageCaption: String? = nil) {
        self.role = role
        self.text = text
        self.imageData = imageData
        self.imageCaption = imageCaption
    }
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
    @State private var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var showImageSourceActionSheet = false
    @State private var showHeyCyanSheet = false
    @State private var selectedImage: UIImage?
    @State private var audioPlayer: LivePCMPlayer?
    @State private var liveDelegate: LiveCoachDelegate?
    @State private var isListening = false
    @State private var audioCapture: LiveAudioCapture?
    @State private var coachTextBuffer = ""
    @State private var streamingCoachText = ""
    @State private var userVoiceBuffer = ""
    @State private var waitingForCoachResponse = false
    @State private var lastSentWasMeal = false
    @State private var reconnectTask: Task<Void, Never>?
    @State private var thinkingTimeoutTask: Task<Void, Never>?
    @State private var receivedAudioThisTurn = false
    @State private var pendingMealPromptToSend: String?

    private let quickPrompts = [
        "Suggest meal ideas and show me what they look like",
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
                    if waitingForCoachResponse || coachState == "speaking" {
                        Button {
                            sendInterrupt()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                                .font(.subheadline)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .padding(.horizontal)
                    }
                    quickPromptsRow
                    inputBar
                }
            }
            .background(Theme.bg)
            .navigationTitle("Live Coach")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(
                    sourceType: imagePickerSource,
                    onImagePicked: { img in
                        showImagePicker = false
                        handleImagePicked(img)
                    },
                    onCancel: { showImagePicker = false }
                )
            }
            .confirmationDialog("Add photo", isPresented: $showImageSourceActionSheet) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") {
                        imagePickerSource = .camera
                        showImagePicker = true
                    }
                }
                Button("Choose from Library") {
                    imagePickerSource = .photoLibrary
                    showImagePicker = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Camera captures a new photo. Library picks from your Photos.")
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
        .onChange(of: appState.backendDiscoveredVersion) {
            if !isConnected { connect() }
        }
        .onChange(of: isConnected) {
            if isConnected, let prompt = pendingMealPromptToSend, !prompt.isEmpty, let c = client {
                pendingMealPromptToSend = nil
                c.sendText(prompt)
                messages.append(ChatMessage(role: "user", text: prompt))
                receivedAudioThisTurn = false
                waitingForCoachResponse = true
                coachState = "thinking"
                startThinkingTimeout()
            }
        }
        .onAppear {
            configureAudioSessionForCoach()
            Task { await dataStore.refreshTasks() }
            if !isConnected {
                connect()
            }
            if let prompt = appState.consumeMealSuggestionPrompt(), !prompt.isEmpty {
                inputText = prompt
                pendingMealPromptToSend = prompt
                if isConnected, let c = client {
                    pendingMealPromptToSend = nil
                    c.sendText(prompt)
                    messages.append(ChatMessage(role: "user", text: prompt))
                    receivedAudioThisTurn = false
                    waitingForCoachResponse = true
                    coachState = "thinking"
                    startThinkingTimeout()
                }
            }
            if isConnected, let c = client, let img = appState.consumePendingImageForCoach(), let b64 = img.toJPEGBase64() {
                c.sendImage(base64: b64)
                let imgData = img.jpegData(compressionQuality: 0.8)
                messages.append(ChatMessage(role: "user", text: "[sent meal photo]", imageData: img.jpegData(compressionQuality: 0.8)))
                lastSentWasMeal = true
                waitingForCoachResponse = true
                coachState = "thinking"
            }
        }
        .onDisappear {
            reconnectTask?.cancel()
            reconnectTask = nil
            audioCapture?.stop()
            audioPlayer?.stop()
            client?.disconnect()
        }
    }

    private func configureAudioSessionForCoach() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
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
                    reconnectTask?.cancel()
                    reconnectTask = nil
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
                chatBubble(msg: msg)
            }
            if !streamingCoachText.isEmpty {
                chatBubble(msg: ChatMessage(role: "coach", text: streamingCoachText))
            }
        }
    }

    private func chatBubble(msg: ChatMessage) -> some View {
        HStack {
            if msg.role == "user" { Spacer(minLength: 48) }
            VStack(alignment: msg.role == "user" ? .trailing : .leading, spacing: 8) {
                if let data = msg.imageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 220, maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                if !msg.text.isEmpty {
                    Text(msg.text)
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(msg.role == "user" ? Theme.accent : Color(.tertiarySystemBackground))
                        .foregroundStyle(msg.role == "user" ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            if msg.role == "coach" { Spacer(minLength: 48) }
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
                showImageSourceActionSheet = true
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
        let baseURL = HappyDietConfig.backendURL
        let healthURL = baseURL.appendingPathComponent("health")

        connectionStatus = "Checking backend..."
        var request = URLRequest(url: healthURL)
        request.timeoutInterval = 5
        URLSession.shared.dataTask(with: request) { [self] _, response, error in
            Task { @MainActor in
                let httpOk = (response as? HTTPURLResponse)?.statusCode == 200
                if error != nil || !httpOk {
                    connectionStatus = "Backend unreachable"
                    let hint = connectionHint(baseURL: baseURL)
                    handleEvent(.error("Cannot reach backend at \(baseURL.absoluteString). \(hint)"))
                    return
                }
                doConnect(baseURL: baseURL)
            }
        }.resume()
    }

    private func startThinkingTimeout() {
        thinkingTimeoutTask?.cancel()
        thinkingTimeoutTask = Task {
            try? await Task.sleep(nanoseconds: 90_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard waitingForCoachResponse else { return }
                thinkingTimeoutTask = nil
                waitingForCoachResponse = false
                lastSentWasMeal = false
                coachState = "idle"
                connectionStatus = "Response timeout"
                messages.append(ChatMessage(role: "coach", text: "The coach took too long to respond. Try again or check your connection."))
            }
        }
    }

    private func connectionHint(baseURL: URL) -> String {
        let host = baseURL.host ?? ""
        if host == "localhost" || host == "127.0.0.1" {
            return "On a physical device, use your Mac's IP (e.g. http://192.168.1.5:8080). Mac and iPhone must be on same Wi‑Fi. Start backend: npm run dev in backend folder."
        }
        return "Ensure backend is running (npm run dev), Mac and iPhone on same Wi‑Fi, and URL is correct. Test in More > Settings."
    }

    private func doConnect(baseURL: URL) {
        connectionStatus = "Connecting..."
        let c = LiveAPIClient(baseURL: baseURL)
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

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task {
            connectionStatus = "Reconnecting in 3s…"
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled, !isConnected else { return }
            connect()
        }
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
            thinkingTimeoutTask?.cancel()
            thinkingTimeoutTask = nil
            isConnected = false
            connectionStatus = reason ?? "Disconnected"
            coachState = "idle"
            waitingForCoachResponse = false
            lastSentWasMeal = false
            userVoiceBuffer = ""
            scheduleReconnect()
        case .setupComplete:
            isConnected = true
            connectionStatus = "Connected"
            coachState = "idle"
            if let img = appState.consumePendingImageForCoach(), let b64 = img.toJPEGBase64() {
                client?.sendImage(base64: b64)
                messages.append(ChatMessage(role: "user", text: "[sent meal photo]"))
                lastSentWasMeal = true
                receivedAudioThisTurn = false
                waitingForCoachResponse = true
                coachState = "thinking"
                startThinkingTimeout()
            } else if let prompt = pendingMealPromptToSend, !prompt.isEmpty {
                pendingMealPromptToSend = nil
                client?.sendText(prompt)
                messages.append(ChatMessage(role: "user", text: prompt))
                receivedAudioThisTurn = false
                waitingForCoachResponse = true
                coachState = "thinking"
                startThinkingTimeout()
            }
        case .text(let s):
            coachState = "speaking"
            coachTextBuffer += s
            streamingCoachText = coachTextBuffer
        case .turnComplete:
            thinkingTimeoutTask?.cancel()
            thinkingTimeoutTask = nil
            waitingForCoachResponse = false
            lastSentWasMeal = false
            coachState = "idle"
            let trimmed = coachTextBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                messages.append(ChatMessage(role: "coach", text: trimmed))
                dataStore.addJournalEntry(text: trimmed)
                // TTS fallback: if we got text but no audio, speak it so the agent is heard
                if !receivedAudioThisTurn {
                    Task {
                        await TTSHelper.speak(trimmed, backend: nil)
                    }
                }
            }
            coachTextBuffer = ""
            streamingCoachText = ""
        case .audio(let data):
            receivedAudioThisTurn = true
            coachState = "speaking"
            if audioPlayer == nil {
                audioPlayer = LivePCMPlayer()
            }
            audioPlayer?.enqueue(data: data)
        case .interrupted:
            thinkingTimeoutTask?.cancel()
            thinkingTimeoutTask = nil
            audioPlayer?.stop()
            waitingForCoachResponse = false
            lastSentWasMeal = false
            coachState = "idle"
            coachTextBuffer = ""
            streamingCoachText = ""
            userVoiceBuffer = ""
        case .mealImage(let data, let caption):
            messages.append(ChatMessage(role: "coach", text: caption ?? "Generated meal", imageData: data, imageCaption: caption))
        case .task(let task, let due):
            dataStore.addTask(task, due: due)
        case .userTranscription(let text, let finished):
            let t = text.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty {
                userVoiceBuffer += (userVoiceBuffer.isEmpty ? "" : " ") + t
            }
            if finished && !userVoiceBuffer.isEmpty {
                messages.append(ChatMessage(role: "user", text: userVoiceBuffer.trimmingCharacters(in: .whitespaces)))
                userVoiceBuffer = ""
            }
        case .error(let msg):
            thinkingTimeoutTask?.cancel()
            thinkingTimeoutTask = nil
            waitingForCoachResponse = false
            lastSentWasMeal = false
            coachState = "idle"
            connectionStatus = "Error"
            messages.append(ChatMessage(role: "coach", text: "Error: \(msg)"))
            if !isConnected { scheduleReconnect() }
        }
    }

    private func sendText() {
        guard !inputText.isEmpty else { return }
        let text = inputText
        inputText = ""
        client?.sendText(text)
        messages.append(ChatMessage(role: "user", text: text))
        lastSentWasMeal = false
        receivedAudioThisTurn = false
        waitingForCoachResponse = true
        coachState = "thinking"
        startThinkingTimeout()
    }

    private func handleImagePicked(_ image: UIImage) {
        guard let base64 = image.toJPEGBase64() else { return }
        client?.sendImage(base64: base64)
        messages.append(ChatMessage(role: "user", text: "[sent meal photo]", imageData: image.jpegData(compressionQuality: 0.8)))
        lastSentWasMeal = true
        receivedAudioThisTurn = false
        waitingForCoachResponse = true
        coachState = "thinking"
        startThinkingTimeout()
    }

    private func sendInterrupt() {
        audioPlayer?.stop()
        coachTextBuffer = ""
        streamingCoachText = ""
        waitingForCoachResponse = false
        coachState = "idle"
        client?.sendInterrupt()
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
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
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
