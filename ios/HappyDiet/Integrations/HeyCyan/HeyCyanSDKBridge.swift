//
//  HeyCyanSDKBridge.swift
//  HappyDiet
//
//  Bridge to QCSDK for BLE control. Only active when HEYCYAN_SDK_LINKED.
//  Full flow: BLE scan → connect → take photo → transfer mode → WiFi → download.
//

import Foundation
import UIKit
import NetworkExtension

#if HEYCYAN_SDK_LINKED

/// Bridges Swift to QCSDK for HeyCyan BLE + WiFi capture.
final class HeyCyanSDKBridge: NSObject {
    static let shared = HeyCyanSDKBridge()
    private var captureCompletion: ((Result<UIImage, HeyCyanError>) -> Void)?
    private var captureOnCancel: (() -> Void)?
    private var scanViewController: QCScanViewController?
    private weak var presentingViewController: UIViewController?

    override private init() { super.init() }

    func capturePhoto(completion: @escaping (Result<UIImage, HeyCyanError>) -> Void, onCancel: @escaping () -> Void) {
        captureCompletion = completion
        captureOnCancel = onCancel

        let qc = QCCentralManager.shared()
        if qc.deviceState == QCStateConnected {
            runCaptureFlow(completion: completion)
        } else {
            showDevicePicker(completion: completion, onCancel: onCancel)
        }
    }

    private func showDevicePicker(completion: @escaping (Result<UIImage, HeyCyanError>) -> Void, onCancel: @escaping () -> Void) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            completion(.failure(HeyCyanError(message: "No window")))
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
        nav.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        top.present(nav, animated: true) { [weak self] in
            QCCentralManager.shared().delegate = scanVC
        }
    }

    private func runCaptureFlow(completion: @escaping (Result<UIImage, HeyCyanError>) -> Void) {
        // 1. Take photo via BLE
        QCSDKCmdCreator.setDeviceMode(QCOperatorDeviceModePhoto, success: { [weak self] in
            // 2. Wait for photo to save, then switch to transfer mode
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self?.switchToTransferAndDownload(completion: completion)
            }
        }, fail: { [weak self] mode in
            DispatchQueue.main.async {
                self?.captureCompletion?(.failure(HeyCyanError(message: "Take photo failed (mode: \(mode))")))
            }
        })
    }

    private func switchToTransferAndDownload(completion: @escaping (Result<UIImage, HeyCyanError>) -> Void) {
        QCSDKCmdCreator.openWifi(with: QCOperatorDeviceModeTransfer, success: { [weak self] ssid, password in
            let ss = ssid ?? ""
            let pw = password ?? "123456789"
            if ss.isEmpty {
                DispatchQueue.main.async {
                    self?.captureCompletion?(.failure(HeyCyanError(message: "No SSID from glasses")))
                }
                return
            }
            HeyCyanWiFiTransfer.fetchLatestPhoto(ssid: ss, password: pw) { result in
                DispatchQueue.main.async {
                    self?.captureCompletion?(result)
                }
            }
        }, fail: { [weak self] mode in
            DispatchQueue.main.async {
                self?.captureCompletion?(.failure(HeyCyanError(message: "Transfer mode failed (mode: \(mode))")))
            }
        })
    }
}

#endif
