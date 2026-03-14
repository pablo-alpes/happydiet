//
//  HeyCyanCaptureSheet.swift
//  HappyDiet
//
//  Sheet for capturing a meal photo from HeyCyan glasses.
//  Options: 1) Full BLE+WiFi (when SDK linked) 2) Manual WiFi (enter SSID when glasses in transfer mode)
//

import SwiftUI

struct HeyCyanCaptureSheet: View {
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var statusMessage = "Connect your HeyCyan glasses"
    @State private var isConnecting = false
    @State private var manualSSID = ""
    @State private var manualPassword = "123456789"
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "eyeglasses")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text("HeyCyan Glasses")
                        .font(.title2.bold())

                    Text(statusMessage)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    if isConnecting {
                        ProgressView()
                            .scaleEffect(1.2)
                            .padding()
                    }

#if HEYCYAN_SDK_LINKED
                    // BLE capture (full flow: scan → connect → take photo → transfer)
                    Button {
                        captureViaBLE()
                    } label: {
                        Label("Capture via Bluetooth", systemImage: "antenna.radiowaves.left.and.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isConnecting)
                    .padding(.horizontal)
#endif

                    // Manual WiFi option (works without SDK)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Fetch via WiFi")
                            .font(.headline)
                        Text("1. Put glasses in transfer mode (HeyCyan app or button)\n2. Note the WiFi name (e.g. W630_xxxx)\n3. Enter it below and tap Fetch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Glasses WiFi name (SSID)", text: $manualSSID)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Password (often 123456789)", text: $manualPassword)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                        Button {
                            fetchViaWiFi()
                        } label: {
                            Label("Fetch latest photo", systemImage: "arrow.down.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(manualSSID.trimmingCharacters(in: .whitespaces).isEmpty || isConnecting)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

#if !HEYCYAN_SDK_LINKED
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Full BLE + WiFi (optional)")
                            .font(.headline)
                        Text("""
                        For automatic BLE capture, add QCSDK.framework:
                        1. Run: ./ios/scripts/setup-heycyan.sh
                        2. Add QCSDK.framework to the HappyDiet target
                        3. Set HEYCYAN_SDK_LINKED in Build Settings
                        See docs/heycyan-integration.md
                        """)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
#endif

                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isConnecting = false
                        onCancel()
                    }
                }
            }
        }
    }

#if HEYCYAN_SDK_LINKED
    private func captureViaBLE() {
        isConnecting = true
        errorMessage = nil
        statusMessage = "Connecting to glasses…"
        HeyCyanService.shared.capturePhoto { img in
            isConnecting = false
            onImagePicked(img)
        } onCancel: {
            isConnecting = false
            errorMessage = HeyCyanService.shared.lastError
            statusMessage = "BLE capture failed."
        }
    }
#endif

    private func fetchViaWiFi() {
        let ssid = manualSSID.trimmingCharacters(in: .whitespaces)
        guard !ssid.isEmpty else { return }
        isConnecting = true
        errorMessage = nil
        statusMessage = "Connecting to \(ssid)…"
        HeyCyanService.shared.capturePhotoViaWiFi(ssid: ssid, password: manualPassword) { img in
            isConnecting = false
            onImagePicked(img)
        } onCancel: {
            isConnecting = false
            errorMessage = HeyCyanService.shared.lastError
            statusMessage = "Connection failed. Check SSID and password."
        }
    }
}
