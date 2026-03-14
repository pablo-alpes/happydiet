//
//  LiveAudioCapture.swift
//  HappyDiet
//
//  Captures microphone audio, converts to 16-bit PCM 16kHz, and streams to Live API.
//

import Foundation
import AVFoundation

final class LiveAudioCapture {
    private var engine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var isCapturing = false
    private let targetSampleRate: Double = 16000

    var onChunk: ((Data) -> Void)?
    var onError: ((String) -> Void)?

    func start() {
        guard !isCapturing else { return }
        let eng = AVAudioEngine()
        let input = eng.inputNode
        let format = input.outputFormat(forBus: 0)
        let targetFormat = AVAudioFormat(standardFormatWithSampleRate: targetSampleRate, channels: 1)!

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] (buffer: AVAudioPCMBuffer, _: AVAudioTime) in
            self?.processBuffer(buffer, from: format, to: targetFormat)
        }

        do {
            try eng.start()
            engine = eng
            inputNode = input
            isCapturing = true
        } catch {
            onError?("Mic: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard isCapturing else { return }
        inputNode?.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        inputNode = nil
        isCapturing = false
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer, from format: AVAudioFormat, to targetFormat: AVAudioFormat) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        let inputRate = format.sampleRate
        let outputRate = targetFormat.sampleRate
        let ratio = inputRate / outputRate
        let outputCount = Int(Double(frameCount) / ratio)

        var pcm = [Int16](repeating: 0, count: outputCount)
        for i in 0..<outputCount {
            let src = Double(i) * ratio
            let idx = Int(src)
            let frac = src - Double(idx)
            let s: Float
            if idx < frameCount - 1 {
                s = channelData[idx] * Float(1 - frac) + channelData[idx + 1] * Float(frac)
            } else {
                s = channelData[min(idx, frameCount - 1)]
            }
            pcm[i] = Int16(max(-32768, min(32767, s * 32768)))
        }
        let data = pcm.withUnsafeBufferPointer { Data(buffer: $0) }
        onChunk?(data)
    }
}
