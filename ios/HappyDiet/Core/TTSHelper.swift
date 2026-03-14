//
//  TTSHelper.swift
//  HappyDiet
//
//  TTS: backend POST /speak (Google Cloud TTS) when available → natural voice.
//  If that fails (503, network), falls back to AVSpeechSynthesizer (phone’s built-in voice).
//

import AVFoundation

enum TTSHelper {
    private static let synthesizer = AVSpeechSynthesizer()

    private static let lastErrorKey = "happydiet_last_tts_error"
    private static let lastUsedGoogleKey = "happydiet_last_tts_used_google"

    /// Last TTS error message when we fell back to device voice (for Settings diagnostic).
    static var lastTTSError: String? {
        get { UserDefaults.standard.string(forKey: lastErrorKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastErrorKey) }
    }

    /// True if the last successful speak used Google TTS.
    static var lastTTSUsedGoogle: Bool {
        get { UserDefaults.standard.bool(forKey: lastUsedGoogleKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastUsedGoogleKey) }
    }

    /// Speak text: tries backend /speak (Google TTS) first, else device AVSpeechSynthesizer.
    /// Truncates to 4500 chars (Google TTS limit 5000). Retries once on failure.
    static func speak(_ text: String, backend: BackendClient? = nil) async {
        let client = backend ?? BackendClient(baseURL: HappyDietConfig.ttsBaseURL)
        let truncated = text.count > 4500 ? String(text.prefix(4500)) : text
        do {
            let audioData = try await client.speak(text: truncated)
            try await playAudio(data: audioData)
            lastTTSError = nil
            lastTTSUsedGoogle = true
        } catch {
            // Retry once after a short delay (e.g. cold start, transient 503)
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 s
            do {
                let audioData = try await client.speak(text: truncated)
                try await playAudio(data: audioData)
                lastTTSError = nil
                lastTTSUsedGoogle = true
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                lastTTSError = message
                lastTTSUsedGoogle = false
                fallbackSpeak(text)
            }
        }
    }

    private static func playAudio(data: Data) async throws {
        guard !data.isEmpty else {
            throw NSError(domain: "TTSHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Backend returned no data"])
        }
        // Server may return JSON/HTML on error (e.g. proxy) even with 200.
        let first = data.first ?? 0
        if first == 0x7B {
            throw NSError(domain: "TTSHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server returned JSON instead of audio (check TTS is configured on backend)"])
        }
        if first == 0x3C {
            throw NSError(domain: "TTSHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server returned HTML instead of audio"])
        }

        // Play from temp file; AVAudioPlayer can fail with in-memory data on device.
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp3")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try data.write(to: tempURL)

        let player: AVAudioPlayer? = await MainActor.run {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try? session.setActive(true)
            let p = try? AVAudioPlayer(contentsOf: tempURL)
            p?.prepareToPlay()
            return p
        }
        guard let player else {
            throw NSError(domain: "TTSHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not create audio player (invalid or unsupported format)"])
        }

        let didStart = await MainActor.run { player.play() }
        guard didStart else {
            throw NSError(domain: "TTSHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "AVAudioPlayer failed to start"])
        }

        while player.isPlaying {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private static func fallbackSpeak(_ text: String) {
        DispatchQueue.main.async {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
            try? session.setActive(true)
            let utterance = AVSpeechUtterance(string: text)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            synthesizer.speak(utterance)
        }
    }

    static func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
