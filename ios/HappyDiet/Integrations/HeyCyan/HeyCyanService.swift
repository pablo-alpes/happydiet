//
//  HeyCyanService.swift
//  HappyDiet
//
//  Integration with HeyCyan smart glasses: BLE control + WiFi transfer.
//  Flow: Connect BLE → Take photo → Switch to transfer mode → Connect WiFi → Fetch manifest → Download latest image
//
//  Setup: Run ios/scripts/setup-heycyan.sh, add QCSDK.framework to target, set HEYCYAN_SDK_LINKED in build settings.
//  See docs/heycyan-integration.md
//

import Foundation
import UIKit
import NetworkExtension

struct HeyCyanError: Error {
    let message: String
}

/// Service for capturing photos from HeyCyan smart glasses.
final class HeyCyanService: ObservableObject {
    static let shared = HeyCyanService()

    @Published private(set) var connectionState: HeyCyanConnectionState = .disconnected
    @Published private(set) var lastError: String?
    /// After BLE capture, glasses WiFi details for manual transfer if auto-join fails.
    @Published private(set) var lastTransferSSID: String?
    @Published private(set) var lastTransferPassword: String?

    private init() {}

    /// Called by SDK bridge when glasses report WiFi details (so user can manually connect if auto-join fails).
    func setLastTransferWiFi(ssid: String, password: String) {
        lastTransferSSID = ssid
        lastTransferPassword = password
    }

    /// Capture a photo from glasses: BLE+WiFi when SDK linked, or WiFi-only with manual SSID.
    func capturePhoto(onImagePicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
#if HEYCYAN_SDK_LINKED
        capturePhotoWithSDK(onImagePicked: onImagePicked, onCancel: onCancel)
#else
        // Without SDK: show sheet with manual WiFi option
        onCancel()
#endif
    }

    /// WiFi-only capture: connect to glasses hotspot (user puts glasses in transfer mode first).
    /// SSID is typically W630_<MAC> from the glasses. Password often 123456789.
    func capturePhotoViaWiFi(ssid: String, password: String = "123456789", onImagePicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        connectionState = .transferring
        lastError = nil
        HeyCyanWiFiTransfer.fetchLatestPhoto(ssid: ssid, password: password) { [weak self] result in
            DispatchQueue.main.async {
                self?.connectionState = .disconnected
                switch result {
                case .success(let img): onImagePicked(img)
                case .failure(let err):
                    self?.lastError = err.message
                    onCancel()
                }
            }
        }
    }

#if HEYCYAN_SDK_LINKED
    private var captureOnImagePicked: ((UIImage) -> Void)?
    private var captureOnCancel: (() -> Void)?

    private func capturePhotoWithSDK(onImagePicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        captureOnImagePicked = onImagePicked
        captureOnCancel = onCancel
        connectionState = .scanning
        lastError = nil

        HeyCyanSDKBridge.shared.capturePhoto { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let image):
                    self.connectionState = .connected
                    self.lastError = nil
                    onImagePicked(image)
                case .failure(let err):
                    self.connectionState = .error(err.message)
                    self.lastError = err.message
                    onCancel()
                }
                self.captureOnImagePicked = nil
                self.captureOnCancel = nil
            }
        } onCancel: { [weak self] in
            DispatchQueue.main.async {
                self?.connectionState = .disconnected
                self?.captureOnImagePicked = nil
                self?.captureOnCancel = nil
                onCancel()
            }
        }
    }
#endif
}

enum HeyCyanConnectionState {
    case disconnected
    case scanning
    case connecting
    case connected
    case transferring
    case error(String)
}

// MARK: - WiFi Transfer (works without SDK - for manual transfer mode)

final class HeyCyanWiFiTransfer {
    /// Connect to glasses WiFi and fetch latest photo. Call when glasses are already in transfer mode.
    /// With Hotspot Configuration entitlement, iOS shows an in-app "Join [network]?" dialog — user taps Join once.
    static func fetchLatestPhoto(ssid: String, password: String = "123456789", completion: @escaping (Result<UIImage, HeyCyanError>) -> Void) {
        let config = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
        config.joinOnce = true

        NEHotspotConfigurationManager.shared.apply(config) { error in
            if let e = error as NSError? {
                let isConfigError = e.domain == "NEHotspotConfigurationErrorDomain" && (e.code == 7 || e.code == 8)
                if isConfigError {
                    // User may have tapped "Join" — iOS sometimes still reports an error. Try discovery anyway after a delay.
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 6) {
                        discoverAndDownload(completion: completion)
                    }
                    return
                }
                let message = "Join the glasses' Wi‑Fi in Settings → Wi‑Fi, then tap Fetch below."
                completion(.failure(HeyCyanError(message: message)))
                return
            }
            // Success: iOS joined the network. Wait for interface to be ready then discover.
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 5) {
                discoverAndDownload(completion: completion)
            }
        }
    }

    // HeyCyan/Android hotspot defaults; SDK uses /files/media.config for connectivity test
    private static let candidateIPs = ["192.168.43.1", "192.168.4.1", "192.168.1.1", "192.168.0.1", "10.0.0.1", "192.168.49.1"]

    private static func discoverAndDownload(completion: @escaping (Result<UIImage, HeyCyanError>) -> Void) {
        let group = DispatchGroup()
        var foundIP: String?
        let queue = DispatchQueue(label: "heycyan.discover")

        for ip in candidateIPs {
            group.enter()
            testConnection(ip: ip) { reachable in
                queue.async {
                    if reachable && foundIP == nil { foundIP = ip }
                    group.leave()
                }
            }
        }

        group.notify(queue: queue) {
            guard let ip = foundIP else {
                DispatchQueue.main.async { completion(.failure(HeyCyanError(message: "Could not find glasses on network"))) }
                return
            }
            fetchManifestAndDownload(deviceIP: ip, completion: completion)
        }
    }

    private static func testConnection(ip: String, completion: @escaping (Bool) -> Void) {
        // HeyCyan SDK uses /files/media.config for connectivity; some devices use /manifest.json
        let urls = ["http://\(ip)/files/media.config", "http://\(ip)/manifest.json"]
        var remaining = urls.makeIterator()
        func tryNext() {
            guard let urlString = remaining.next(), let url = URL(string: urlString) else {
                completion(false)
                return
            }
            var req = URLRequest(url: url)
            req.timeoutInterval = 3
            URLSession.shared.dataTask(with: req) { _, response, _ in
                if (response as? HTTPURLResponse)?.statusCode == 200 {
                    completion(true)
                } else {
                    tryNext()
                }
            }.resume()
        }
        tryNext()
    }

    private static func fetchManifestAndDownload(deviceIP: String, completion: @escaping (Result<UIImage, HeyCyanError>) -> Void) {
        // Try manifest.json first (files array with filename/type)
        let jsonURL = URL(string: "http://\(deviceIP)/manifest.json")!
        URLSession.shared.dataTask(with: jsonURL) { data, _, _ in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let files = json["files"] as? [[String: Any]],
               let latest = files.first(where: { ($0["type"] as? String)?.lowercased() == "photo" || ($0["type"] as? String)?.lowercased() == "image" })
                   ?? files.first,
               let filename = latest["filename"] as? String {
                let fileURL = "http://\(deviceIP)/files/\(filename)"
                downloadImage(urlString: fileURL, completion: completion)
                return
            }
            // Fallback: /files/media.config (line-based list of filenames)
            tryMediaConfig(deviceIP: deviceIP, completion: completion)
        }.resume()
    }

    private static func tryMediaConfig(deviceIP: String, completion: @escaping (Result<UIImage, HeyCyanError>) -> Void) {
        let url = URL(string: "http://\(deviceIP)/files/media.config")!
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let text = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { completion(.failure(HeyCyanError(message: "No manifest or media.config found on device"))) }
                return
            }
            let lines = text.components(separatedBy: .newlines)
            let filenames = lines
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasPrefix("#") }
                .compactMap { line -> String? in
                    if line.hasPrefix("http") { return URL(string: line)?.lastPathComponent }
                    return line.contains("/") ? String(line.split(separator: "/").last ?? "") : line
                }
            guard let first = filenames.first else {
                DispatchQueue.main.async { completion(.failure(HeyCyanError(message: "No media files in media.config"))) }
                return
            }
            let fileURL = "http://\(deviceIP)/files/\(first)"
            downloadImage(urlString: fileURL, completion: completion)
        }.resume()
    }

    private static func downloadImage(urlString: String, completion: @escaping (Result<UIImage, HeyCyanError>) -> Void) {
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async { completion(.failure(HeyCyanError(message: "Invalid URL"))) }
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion(.failure(HeyCyanError(message: error?.localizedDescription ?? "Invalid image"))) }
                return
            }
            DispatchQueue.main.async { completion(.success(image)) }
        }.resume()
    }
}
