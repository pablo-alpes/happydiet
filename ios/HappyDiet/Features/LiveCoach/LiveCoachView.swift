//
//  LiveCoachView.swift
//  HappyDiet
//
//  Live Agent tab: voice + vision via Gemini Live API.
//  Connect to backend proxy, send text/image, receive audio.
//

import SwiftUI
import AVFoundation

struct LiveCoachView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var dataStore: CoachDataStore
    @State private var client: LiveAPIClient?
    @State private var isConnected = false
    @State private var statusText = "Tap Connect to start"
    @State private var transcript = ""
    @State private var inputText = ""
    @State private var showImagePicker = false
    @State private var showHeyCyanSheet = false
    @State private var selectedImage: UIImage?
    @State private var audioPlayer: LivePCMPlayer?
    @State private var liveDelegate: LiveCoachDelegate?
    @State private var isListening = false
    @State private var audioCapture: LiveAudioCapture?
    @State private var coachTextBuffer = ""
    @State private var waitingForCoachResponse = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statusCard
                    if isConnected {
                        transcriptCard
                        inputSection
                        imageSection
                    }
                }
                .padding()
            }
            .navigationTitle("Live Coach")
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
        .onDisappear {
            audioCapture?.stop()
            client?.disconnect()
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(isConnected ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)
                Text(statusText)
                    .font(.subheadline)
                Spacer()
                Button(isConnected ? "Disconnect" : "Connect") {
                    if isConnected {
                        client?.disconnect()
                        isConnected = false
                        statusText = "Disconnected"
                    } else {
                        connect()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            Text("Backend: \(HappyDietConfig.backendURL.absoluteString)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var transcriptCard: some View {
        Group {
            if !transcript.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcript")
                        .font(.headline)
                    Text(transcript)
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Send message")
                .font(.headline)
            HStack(spacing: 8) {
                Button {
                    toggleVoice()
                } label: {
                    Image(systemName: isListening ? "stop.circle.fill" : "mic.fill")
                        .font(.title2)
                        .foregroundStyle(isListening ? .red : Theme.accent)
                }
                .buttonStyle(.borderedProminent)
                .tint(isListening ? .red.opacity(0.3) : Theme.accent)
                .disabled(!isConnected)
                TextField("Type a message…", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                Button("Send") {
                    sendText()
                }
                .disabled(inputText.isEmpty)
            }
        }
    }

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Share meal photo")
                .font(.headline)
            HStack(spacing: 12) {
                Button {
                    showImagePicker = true
                } label: {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button {
                    showHeyCyanSheet = true
                } label: {
                    Label("Lenses", systemImage: "eyeglasses")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func connect() {
        statusText = "Connecting…"
        let c = LiveAPIClient()
        let delegate = LiveCoachDelegate(
            onEvent: { event in
                Task { @MainActor in
                    handleEvent(event)
                }
            }
        )
        liveDelegate = delegate  // Strong ref so weak delegate on client stays valid
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
        return ctx
    }

    private func handleEvent(_ event: LiveAPIEvent) {
        switch event {
        case .connected:
            isConnected = true
            statusText = "Connected"
        case .disconnected(let reason):
            isConnected = false
            statusText = reason ?? "Disconnected"
        case .setupComplete:
            isConnected = true
            statusText = "Ready — say hi or share a photo!"
            if let img = appState.consumePendingImageForCoach(), let b64 = img.toJPEGBase64() {
                client?.sendImage(base64: b64)
                transcript += (transcript.isEmpty ? "" : "\n") + "You: [sent meal photo]"
                waitingForCoachResponse = true
            }
        case .text(let s):
            waitingForCoachResponse = false
            transcript += (transcript.isEmpty ? "" : "\n") + s
            coachTextBuffer += s
        case .turnComplete:
            waitingForCoachResponse = false
            if !coachTextBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                dataStore.addJournalEntry(text: coachTextBuffer.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            coachTextBuffer = ""
        case .audio(let data):
            waitingForCoachResponse = false
            playPCM(data)
        case .interrupted:
            waitingForCoachResponse = false
            transcript += " [interrupted]"
            coachTextBuffer = ""
        case .error(let msg):
            waitingForCoachResponse = false
            statusText = "Error: \(msg)"
        }
    }

    private func sendText() {
        guard !inputText.isEmpty else { return }
        client?.sendText(inputText)
        transcript += (transcript.isEmpty ? "" : "\n") + "You: \(inputText)"
        inputText = ""
        waitingForCoachResponse = true
    }

    private func handleImagePicked(_ image: UIImage) {
        guard let base64 = image.toJPEGBase64() else { return }
        client?.sendImage(base64: base64)
        transcript += (transcript.isEmpty ? "" : "\n") + "You: [sent meal photo]"
        waitingForCoachResponse = true
    }

    private func toggleVoice() {
        if isListening {
            audioCapture?.stop()
            client?.sendAudioStreamEnd()
            isListening = false
            statusText = "Ready — say hi or share a photo!"
        } else {
            guard isConnected, let c = client else { return }
            let capture = LiveAudioCapture()
            capture.onChunk = { data in
                let b64 = data.base64EncodedString()
                c.sendAudioChunk(base64PCM: b64)
            }
            capture.onError = { msg in
                Task { @MainActor in
                    statusText = msg
                    isListening = false
                }
            }
            capture.start()
            audioCapture = capture
            isListening = true
            statusText = "Listening… speak now, then tap mic to stop"
        }
    }

    private func playPCM(_ data: Data) {
        audioPlayer?.stop()
        let player = LivePCMPlayer()
        audioPlayer = player
        player.play(data: data)
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

final class LivePCMPlayer {
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?

    func play(data: Data) {
        stop()
        let format = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)!
        let frameCount = UInt32(data.count / 2)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        data.withUnsafeBytes { raw in
            guard let ptr = raw.bindMemory(to: Int16.self).baseAddress else { return }
            buffer.int16ChannelData?[0].update(from: ptr, count: Int(frameCount))
        }
        let eng = AVAudioEngine()
        let node = AVAudioPlayerNode()
        eng.attach(node)
        eng.connect(node, to: eng.mainMixerNode, format: format)
        try? eng.start()
        node.scheduleBuffer(buffer, completionHandler: nil)
        node.play()
        engine = eng
        playerNode = node
    }

    func stop() {
        playerNode?.stop()
        engine?.stop()
        engine = nil
        playerNode = nil
    }
}
