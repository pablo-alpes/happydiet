//
//  HeyCyanCaptureSheet.swift
//  HappyDiet
//
//  Sheet for capturing a meal photo from HeyCyan glasses.
//  Full BLE + WiFi when HEYCYAN_SDK_LINKED, WiFi-only otherwise, Camera/Photo fallback.
//

import SwiftUI

struct HeyCyanCaptureSheet: View {
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var statusMessage = ""
    @State private var isConnecting = false
    @State private var manualSSID = ""
    @State private var manualPassword = "123456789"
    @State private var errorMessage: String?
    @State private var showCamera = false
    @State private var showPhotoLibrary = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

#if HEYCYAN_SDK_LINKED
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Capture via Bluetooth", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.headline)
                            .foregroundStyle(Theme.accent)
                        Text("Scan, connect, take photo and transfer — all automatic. If it hangs at \"Scanning for glasses\", a 35s timeout will recover. Use WiFi transfer below as fallback.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            captureViaBLE()
                        } label: {
                            Label("Start BLE capture", systemImage: "antenna.radiowaves.left.and.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .disabled(isConnecting)
                    }
                    .padding()
                    .background(Theme.accentMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
#endif

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Transfer via WiFi", systemImage: "wifi")
                            .font(.headline)
                            .foregroundStyle(Theme.accent)
                        Text("Put glasses in transfer mode, then enter the WiFi name shown on the glasses display.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("WiFi name (e.g. W630_xxxx)", text: $manualSSID)
                            .textFieldStyle(.roundedBorder)
                            .foregroundStyle(.primary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Password (often 123456789)", text: $manualPassword)
                            .textFieldStyle(.roundedBorder)
                            .foregroundStyle(.primary)
                            .textInputAutocapitalization(.never)
                        Button {
                            fetchViaWiFi()
                        } label: {
                            Label("Fetch latest photo", systemImage: "arrow.down.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .disabled(manualSSID.trimmingCharacters(in: .whitespaces).isEmpty || isConnecting)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Camera / Photo Library", systemImage: "camera.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Use phone camera or pick a photo as fallback.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Button {
                                showCamera = true
                            } label: {
                                Label("Camera", systemImage: "camera.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

                            Button {
                                showPhotoLibrary = true
                            } label: {
                                Label("Photo", systemImage: "photo.on.rectangle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if isConnecting {
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(1.2)
                            if !statusMessage.isEmpty {
                                Text(statusMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                    }

                    if let err = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Theme.orange)
                            Text(err)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.orange.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

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
            .navigationTitle("Capture meal")
            .sheet(isPresented: $showCamera) {
                ImagePicker(sourceType: .camera, onImagePicked: { img in showCamera = false; onImagePicked(img) }, onCancel: { showCamera = false })
            }
            .sheet(isPresented: $showPhotoLibrary) {
                ImagePicker(sourceType: .photoLibrary, onImagePicked: { img in showPhotoLibrary = false; onImagePicked(img) }, onCancel: { showPhotoLibrary = false })
            }
        }
    }

#if HEYCYAN_SDK_LINKED
    private func captureViaBLE() {
        isConnecting = true
        errorMessage = nil
        statusMessage = "Scanning for glasses…"
        HeyCyanService.shared.capturePhoto { img in
            isConnecting = false
            statusMessage = ""
            onImagePicked(img)
        } onCancel: {
            isConnecting = false
            errorMessage = HeyCyanService.shared.lastError ?? "BLE capture cancelled."
            statusMessage = ""
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
            statusMessage = ""
            onImagePicked(img)
        } onCancel: {
            isConnecting = false
            errorMessage = HeyCyanService.shared.lastError ?? "WiFi transfer failed. Check SSID and password."
            statusMessage = ""
        }
    }
}
