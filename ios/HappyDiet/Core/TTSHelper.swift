//
//  TTSHelper.swift
//  HappyDiet
//
//  TTS: backend /speak (Google Cloud TTS) when available, else AVSpeechSynthesizer.
//

import AVFoundation

enum TTSHelper {
    private static let synthesizer = AVSpeechSynthesizer()

    /// Speak text: tries backend TTS first, falls back to AVSpeechSynthesizer.
    static func speak(_ text: String, backend: BackendClient? = nil) async {
        let client = backend ?? BackendClient()
        do {
            let audioData = try await client.speak(text: text)
            try await playAudio(data: audioData)
        } catch {
            fallbackSpeak(text)
        }
    }

    private static func playAudio(data: Data) async throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        let player = try AVAudioPlayer(data: data)
        player.prepareToPlay()
        player.play()
        while player.isPlaying {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private static func fallbackSpeak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    static func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
