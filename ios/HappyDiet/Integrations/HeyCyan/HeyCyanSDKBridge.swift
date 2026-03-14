//
//  HeyCyanSDKBridge.swift
//  HappyDiet
//
//  Bridge to QCSDK for BLE control. Only active when HEYCYAN_SDK_LINKED.
//  Includes 25s global timeout to recover from SDK hangs (e.g. CRC check stall).
//

import Foundation
import UIKit
import NetworkExtension

#if HEYCYAN_SDK_LINKED

final class HeyCyanSDKBridge: NSObject {
    static let shared = HeyCyanSDKBridge()
    private var captureCompletion: ((Result<UIImage, HeyCyanError>) -> Void)?
    private var captureOnCancel: (() -> Void)?
    private var scanViewController: QCScanViewController?
    private var captureTimeoutTimer: Timer?

    override private init() { super.init() }

    // MARK: - Timeout and cleanup

    private func startCaptureTimeout(seconds: TimeInterval) {
        captureTimeoutTimer?.invalidate()
        captureTimeoutTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            guard let self, self.captureCompletion != nil else { return }
            self.cleanupAndFail(message: "BLE capture timed out. Glasses may not have responded. Try WiFi transfer instead.")
        }
    }

    private func cleanupAndFail(message: String) {
        captureTimeoutTimer?.invalidate()
        captureTimeoutTimer = nil
        if let scanVC = scanViewController {
            scanVC.dismiss(animated: true)
            scanViewController = nil
        }
        QCCentralManager.shared().stopScan()
        QCCentralManager.shared().remove()
        let cb = captureCompletion
        captureCompletion = nil
        captureOnCancel = nil
        cb?(.failure(HeyCyanError(message: message)))
    }

    private func finishSuccess(image: UIImage) {
        captureTimeoutTimer?.invalidate()
        captureTimeoutTimer = nil
        let cb = captureCompletion
        captureCompletion = nil
        captureOnCancel = nil
        cb?(.success(image))
    }

    private func finishFailure(message: String) {
        captureTimeoutTimer?.invalidate()
        captureTimeoutTimer = nil
        let cb = captureCompletion
        captureCompletion = nil
        captureOnCancel = nil
        cb?(.failure(HeyCyanError(message: message)))
    }

    // MARK: - Public capture

    func capturePhoto(completion: @escaping (Result<UIImage, HeyCyanError>) -> Void, onCancel: @escaping () -> Void) {
        captureCompletion = completion
        captureOnCancel = onCancel

        let qc = QCCentralManager.shared()
        switch qc.bleState {
        case .unsupported:
            completion(.failure(HeyCyanError(message: "Bluetooth not supported on this device")))
            return
        case .unauthorized:
            completion(.failure(HeyCyanError(message: "Bluetooth permission denied. Enable in Settings > HappyDiet > Bluetooth.")))
            return
        case .poweredOff:
            completion(.failure(HeyCyanError(message: "Bluetooth is turned off. Enable it in Control Center or Settings.")))
            return
        default:
            break
        }

        startCaptureTimeout(seconds: 25)

        if qc.deviceState == .connected {
            runCaptureFlow(completion: completion)
        } else {
            showDevicePicker(completion: completion, onCancel: onCancel)
        }
    }

    // MARK: - Device picker

    private func showDevicePicker(completion: @escaping (Result<UIImage, HeyCyanError>) -> Void, onCancel: @escaping () -> Void) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            finishFailure(message: "Cannot present scanner - no active window")
            return
        }

        var top = root
        while let presented = top.presentedViewController { top = presented }

        let scanVC = QCScanViewController(onDeviceSelected: { [weak self] _ in
            self?.scanViewController?.dismiss(animated: true)
            self?.scanViewController = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.runCaptureFlow(completion: completion)
            }
        })
        scanViewController = scanVC
        let nav = UINavigationController(rootViewController: scanVC)
        nav.modalPresentationStyle = .pageSheet
        top.present(nav, animated: true) {
            QCCentralManager.shared().delegate = scanVC
        }
    }

    // MARK: - Capture flow

    private func runCaptureFlow(completion: @escaping (Result<UIImage, HeyCyanError>) -> Void) {
        QCSDKCmdCreator.setDeviceMode(.photo, success: { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self?.switchToTransferAndDownload(completion: completion)
            }
        }, fail: { [weak self] mode in
            DispatchQueue.main.async {
                self?.finishFailure(message: "Take photo failed (mode: \(mode))")
            }
        })
    }

    private func switchToTransferAndDownload(completion: @escaping (Result<UIImage, HeyCyanError>) -> Void) {
        QCSDKCmdCreator.openWifi(with: .transfer, success: { [weak self] ssid, password in
            let ss = ssid
            let pw = password.isEmpty ? "123456789" : password
            if ss.isEmpty {
                DispatchQueue.main.async {
                    self?.finishFailure(message: "No SSID from glasses")
                }
                return
            }
            HeyCyanWiFiTransfer.fetchLatestPhoto(ssid: ss, password: pw) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let image):
                        self?.finishSuccess(image: image)
                    case .failure(let err):
                        self?.finishFailure(message: err.message)
                    }
                }
            }
        }, fail: { [weak self] mode in
            DispatchQueue.main.async {
                self?.finishFailure(message: "Transfer mode failed (mode: \(mode))")
            }
        })
    }
}

#endif
