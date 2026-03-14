//
//  LiveAPIClient.swift
//  HappyDiet
//
//  WebSocket client for Gemini Live API via backend proxy.
//  Connects to ws://backend/live for real-time voice + tool (analyze_meal).
//

import Foundation

enum LiveAPIEvent {
    case connected
    case disconnected(String?)
    case setupComplete
    case text(String)
    case audio(Data)
    case turnComplete
    case interrupted
    case error(String)
}

protocol LiveAPIClientDelegate: AnyObject {
    func liveClient(_ client: LiveAPIClient, didReceive event: LiveAPIEvent)
}

final class LiveAPIClient {
    weak var delegate: LiveAPIClientDelegate?
    private var task: URLSessionWebSocketTask?
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = HappyDietConfig.backendURL) {
        self.baseURL = baseURL
        self.session = URLSession.shared
    }

    private var liveURL: URL? {
        guard let host = baseURL.host else { return nil }
        let scheme = baseURL.scheme == "https" ? "wss" : "ws"
        let port = baseURL.port ?? (scheme == "wss" ? 443 : 80)
        let portSuffix = (scheme == "wss" && port == 443) || (scheme == "ws" && port == 80) ? "" : ":\(port)"
        return URL(string: "\(scheme)://\(host)\(portSuffix)/live")
    }

    var isConnected: Bool { task != nil }

    func connect(context: [String: Any]? = nil) {
        guard let url = liveURL else {
            delegate?.liveClient(self, didReceive: .error("Invalid Live API URL"))
            return
        }
        task = session.webSocketTask(with: url)
        task?.resume()
        if let ctx = context, !ctx.isEmpty {
            let msg: [String: Any] = ["type": "context", "payload": ctx]
            sendJSON(msg)
        }
        receiveLoop()
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    func sendText(_ text: String) {
        let msg: [String: Any] = [
            "clientContent": [
                "turns": [["role": "user", "parts": [["text": text]]]],
                "turnComplete": true,
            ],
        ]
        sendJSON(msg)
    }

    func sendAudioChunk(base64PCM: String) {
        let msg: [String: Any] = [
            "realtimeInput": [
                "audio": ["data": base64PCM, "mimeType": "audio/pcm;rate=16000"],
            ],
        ]
        sendJSON(msg)
    }

    func sendAudioStreamEnd() {
        let msg: [String: Any] = ["realtimeInput": ["audioStreamEnd": true]]
        sendJSON(msg)
    }

    func sendImage(base64: String, mimeType: String = "image/jpeg") {
        // Send image + text in one clientContent turn so the agent receives both together
        let msg: [String: Any] = [
            "clientContent": [
                "turns": [[
                    "role": "user",
                    "parts": [
                        ["inlineData": ["mimeType": mimeType, "data": base64]],
                        ["text": "What do you see in this meal? Analyze it for my diet."],
                    ],
                ]],
                "turnComplete": true,
            ],
        ]
        sendJSON(msg)
    }

    private func sendJSON(_ obj: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: obj),
              let str = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(str)) { [weak self] err in
            if let e = err {
                self?.delegate?.liveClient(self!, didReceive: .error("Send failed: \(e.localizedDescription)"))
            }
        }
    }

    private func receiveLoop() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let msg):
                switch msg {
                case .string(let s):
                    self.handleMessage(s)
                case .data(let d):
                    if let s = String(data: d, encoding: .utf8) { self.handleMessage(s) }
                @unknown default:
                    break
                }
            case .failure(let err):
                let msg = err.localizedDescription
                let hint = "Check Settings → Backend URL. On device use Mac IP (e.g. http://192.168.1.5:8080)."
                self.delegate?.liveClient(self, didReceive: .error("\(msg). \(hint)"))
                self.task = nil
                return
            }
            if self.task != nil { self.receiveLoop() }
        }
    }

    private func handleMessage(_ raw: String) {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        if let type = json["type"] as? String, type == "error",
           let msg = json["message"] as? String {
            delegate?.liveClient(self, didReceive: .error(msg))
            return
        }

        if json["setup_complete"] != nil {
            delegate?.liveClient(self, didReceive: .setupComplete)
            return
        }

        if let turnComplete = json["server_content"] as? [String: Any], turnComplete["turn_complete"] as? Bool == true {
            delegate?.liveClient(self, didReceive: .turnComplete)
            return
        }

        if let interrupted = json["server_content"] as? [String: Any], interrupted["interrupted"] != nil {
            delegate?.liveClient(self, didReceive: .interrupted)
            return
        }

        if let parts = (json["server_content"] as? [String: Any])?["model_turn"] as? [String: Any],
           let partList = parts["parts"] as? [[String: Any]] {
            for part in partList {
                if let text = part["text"] as? String, !text.isEmpty {
                    delegate?.liveClient(self, didReceive: .text(text))
                }
                if let inline = part["inline_data"] as? [String: Any],
                   let b64 = inline["data"] as? String,
                   let audioData = Data(base64Encoded: b64) {
                    delegate?.liveClient(self, didReceive: .audio(audioData))
                }
            }
        }
    }
}
