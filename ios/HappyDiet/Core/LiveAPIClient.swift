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

final class LiveAPIClient: NSObject, URLSessionWebSocketDelegate {
    weak var delegate: LiveAPIClientDelegate?
    private var task: URLSessionWebSocketTask?
    private let baseURL: URL
    private var session: URLSession!
    private var pendingContext: [String: Any]?
    private var connectTimeoutTimer: Timer?

    init(baseURL: URL = HappyDietConfig.backendURL) {
        self.baseURL = baseURL
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
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
            delegate?.liveClient(self, didReceive: .error("Invalid Live API URL from \(baseURL.absoluteString)"))
            return
        }
        pendingContext = context
        let t = session.webSocketTask(with: url)
        task = t
        t.resume()

        connectTimeoutTimer?.invalidate()
        connectTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            guard let self, self.task != nil else { return }
            let wsURL = self.liveURL?.absoluteString ?? self.baseURL.absoluteString
            self.delegate?.liveClient(self, didReceive: .error("Connection timeout (10s). Check backend at \(wsURL). On device use Mac IP in Settings."))
            self.disconnect()
        }
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        connectTimeoutTimer?.invalidate()
        connectTimeoutTimer = nil
        delegate?.liveClient(self, didReceive: .connected)
        if let ctx = pendingContext, !ctx.isEmpty {
            let msg: [String: Any] = ["type": "context", "payload": ctx]
            sendJSON(msg)
        }
        pendingContext = nil
        receiveLoop()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        connectTimeoutTimer?.invalidate()
        connectTimeoutTimer = nil
        let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) }
        delegate?.liveClient(self, didReceive: .disconnected(reasonStr ?? "Connection closed"))
        task = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        connectTimeoutTimer?.invalidate()
        connectTimeoutTimer = nil
        guard let error else { return }
        let url = liveURL?.absoluteString ?? baseURL.absoluteString
        let msg = error.localizedDescription
        let hint = "Backend URL: \(url). On device, use Mac IP (e.g. http://192.168.x.x:8080). Check More > Settings."
        delegate?.liveClient(self, didReceive: .error("\(msg). \(hint)"))
        self.task = nil
    }

    func disconnect() {
        connectTimeoutTimer?.invalidate()
        connectTimeoutTimer = nil
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
            if let e = err, let self {
                self.delegate?.liveClient(self, didReceive: .error("Send failed: \(e.localizedDescription)"))
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
                let url = self.liveURL?.absoluteString ?? self.baseURL.absoluteString
                self.delegate?.liveClient(self, didReceive: .error("Connection lost: \(err.localizedDescription). URL: \(url)"))
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

        if json["setup_complete"] != nil || json["setupComplete"] != nil {
            delegate?.liveClient(self, didReceive: .setupComplete)
            return
        }

        let sc = json["server_content"] as? [String: Any] ?? json["serverContent"] as? [String: Any]

        if sc?["interrupted"] != nil {
            delegate?.liveClient(self, didReceive: .interrupted)
            return
        }

        // Process model_turn parts FIRST (text + audio) — same message can have both parts and turn_complete.
        // If we checked turn_complete first and returned, we'd never deliver the audio.
        let modelTurn = sc?["model_turn"] as? [String: Any] ?? sc?["modelTurn"] as? [String: Any]
        if let partList = modelTurn?["parts"] as? [[String: Any]] {
            for part in partList {
                if let text = part["text"] as? String, !text.isEmpty {
                    delegate?.liveClient(self, didReceive: .text(text))
                }
                let inline = part["inline_data"] as? [String: Any] ?? part["inlineData"] as? [String: Any]
                if let b64 = inline?["data"] as? String,
                   let audioData = Data(base64Encoded: b64) {
                    delegate?.liveClient(self, didReceive: .audio(audioData))
                }
            }
        }

        // Fire turnComplete LAST so progress bar stays until full response (text + audio) is delivered.
        if sc?["turn_complete"] as? Bool == true || sc?["turnComplete"] as? Bool == true {
            delegate?.liveClient(self, didReceive: .turnComplete)
            return
        }
        if let gc = sc?["generation_complete"] as? Bool, gc {
            delegate?.liveClient(self, didReceive: .turnComplete)
        }
    }
}
