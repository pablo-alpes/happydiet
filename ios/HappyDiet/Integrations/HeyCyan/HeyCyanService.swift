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

    private init() {}

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
    static func fetchLatestPhoto(ssid: String, password: String = "123456789", completion: @escaping (Result<UIImage, HeyCyanError>) -> Void) {
        let config = NEHotspotConfiguration(ssid: ssid, passphrase: password, isWEP: false)
        config.joinOnce = true

        NEHotspotConfigurationManager.shared.apply(config) { error in
            if let e = error {
                completion(.failure(HeyCyanError(message: "WiFi: \(e.localizedDescription). Ensure glasses are in transfer mode.")))
                return
            }
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 3) {
                discoverAndDownload(completion: completion)
            }
        }
    }

    private static let candidateIPs = ["192.168.43.1", "192.168.4.1", "192.168.1.1", "192.168.0.1", "10.0.0.1"]

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
        let url = URL(string: "http://\(ip)/manifest.json")!
        var req = URLRequest(url: url)
        req.timeoutInterval = 3
        URLSession.shared.dataTask(with: req) { _, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            completion(ok)
        }.resume()
    }

    private static func fetchManifestAndDownload(deviceIP: String, completion: @escaping (Result<UIImage, HeyCyanError>) -> Void) {
        let url = URL(string: "http://\(deviceIP)/manifest.json")!
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let files = json["files"] as? [[String: Any]],
                  let latest = files.first(where: { ($0["type"] as? String)?.lowercased() == "photo" || ($0["type"] as? String)?.lowercased() == "image" })
                      ?? files.first,
                  let filename = latest["filename"] as? String else {
                DispatchQueue.main.async { completion(.failure(HeyCyanError(message: "No photos in manifest"))) }
                return
            }
            let fileURL = "http://\(deviceIP)/files/\(filename)"
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
