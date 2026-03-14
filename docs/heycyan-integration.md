# HeyCyan Smart Glasses Integration

**Objective:** Use HeyCyan glasses as a capture source for meal images and audio in HappyDiet.

**Google Challenge alignment:** Glasses + Live API = **See, Hear, Speak** — wearable, hands-free, voice-first diet coaching. See [roadmap-google-alignment.md](./roadmap-google-alignment.md).

---

## Overview

HeyCyan (W610) smart glasses provide:

- **BLE (Bluetooth Low Energy):** Device control (take photo, record video/audio)
- **WiFi:** Media transfer via hotspot (SSID `W630_[MAC]`)

The official app is HeyCyan; we use the community SDK from [ebowwa/HeyCyanSmartGlassesSDK](https://github.com/ebowwa/HeyCyanSmartGlassesSDK).

---

## Integration Layer

HappyDiet abstracts capture sources via `MealCaptureSource` (see `ios/HappyDiet/Core/CaptureSource.swift`):

| Source        | Platform | Status                          |
|---------------|----------|----------------------------------|
| Camera        | iOS, Web | Implemented                     |
| Photo Library | iOS, Web | Implemented                     |
| HeyCyan       | **iOS only** | **Full BLE + WiFi** when SDK linked; Manual WiFi fallback always available |

**HeyCyan requires native iOS.** Web browsers cannot use HeyCyan because:
- **Web Bluetooth** is not supported on iOS Safari (BLE connection to glasses)
- **WiFi hotspot** handling for media transfer requires native APIs

Using the web app on an iPhone (e.g. `https://your-app.run.app/`) **does not work** with HeyCyan. Use the native iOS app for glasses.

---

## iOS Setup (HeyCyan SDK)

### 1. Add QCSDK Framework

1. Clone the SDK:
   ```bash
   cd ios
   git submodule add https://github.com/ebowwa/HeyCyanSmartGlassesSDK.git HeyCyanSDK
   ```

2. In Xcode: add `HeyCyanSDK/QCSDK.framework` to the HappyDiet target (Embed & Sign).

3. Add to `Info.plist`:
   ```xml
   <key>NSBluetoothAlwaysUsageDescription</key>
   <string>HappyDiet needs Bluetooth to connect to HeyCyan glasses for meal capture.</string>
   <key>NSBluetoothPeripheralUsageDescription</key>
   <string>HappyDiet needs Bluetooth to communicate with HeyCyan glasses.</string>
   ```

### 2. Implement HeyCyanService

The stub in `HeyCyanService.swift` must be replaced with the full flow:

1. **BLE:** Scan → connect via `QCCentralManager`
2. **Take photo:** `[QCSDKCmdCreator setDeviceMode:QCOperatorDeviceModePhoto ...]`
3. **Transfer mode:** `[QCSDKCmdCreator openWifiWithMode:QCOperatorDeviceModeTransfer ...]` → get SSID, password
4. **WiFi:** Connect via `NEHotspotConfiguration` (NetworkExtension)
5. **HTTP:** `GET http://{deviceIP}/manifest.json` → parse files
6. **Download:** `GET http://{deviceIP}/files/{filename}` for latest photo
7. Convert to `UIImage` → call `onImagePicked(image)`

See [WIFI_TRANSFER_ARCHITECTURE.md](https://github.com/ebowwa/HeyCyanSmartGlassesSDK/blob/main/WIFI_TRANSFER_ARCHITECTURE.md) in the SDK repo for protocol details.

### 3. Build Flag

`HEYCYAN_SDK_LINKED` is set in Build Settings when the framework is linked. The setup script and project configuration handle this.

### 4. Wi‑Fi transfer: automatic vs manual

**Automatic join** (dialog → tap Join → app joins and downloads) requires the **Hotspot Configuration** entitlement. That capability can only be enabled in [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list), which is available only to **paid Apple Developer Program** members ($99/year). Without it, the entitlement cannot be included in the app’s profile and the project is built without it so it compiles.

**Manual join** (current behavior): When the system can’t complete the join, the app shows “Join the glasses’ Wi‑Fi in Settings → Wi‑Fi, then tap Fetch below” with **Copy network & password** and **Open Settings**. After you join the glasses’ network in Settings, return to the app and tap **Fetch latest photo** (the network name is pre-filled). The app also tries discovery a few seconds after certain errors, in case you did tap Join and the device joined.

**If you later enroll** in the Apple Developer Program, you can add the Hotspot Configuration capability to your App ID and to the project’s entitlements to get the same automatic flow as the official HeyCyan app.

### 5. Build on Device

HeyCyan BLE requires a **physical iOS device**. Build and run on a connected iPhone/iPad; the simulator does not support Bluetooth.

**Note:** The QCSDK exposes `getThumbnail` (small image over BLE) but not full-size photo transfer over BLE. Full photos are transferred over Wi‑Fi after the glasses report SSID/password via BLE.

---

## Web — HeyCyan Not Supported

The web app uses **camera** and **file upload** only. **HeyCyan cannot be used from the web**, including when the web app is opened in a browser on the iPhone:

- **Web Bluetooth** is not supported on iOS Safari
- **WiFi hotspot** APIs are not exposed to browsers

**To use HeyCyan:** Use the **native iOS app** (not the web app on the phone). See [architecture-diagram.md](./architecture-diagram.md) for the client matrix.

**Workarounds for web + glasses:**
- **Option A:** Use the iOS app as bridge — capture on phone with glasses, view on web dashboard
- **Option B:** Connect to glasses WiFi from a device on the same network and fetch `http://{glassesIP}/manifest.json` (requires CORS or same-origin)

---

## Data Flow

```
[User] → HeyCyan glasses (BLE photo) or Camera/Upload
    ↓
[Reader] → Vision → ingredients → Persist
    ↓
[Processor] → Rule match → compliance
    ↓
[Reporter] → Message + TTS
```

The integration layer only affects the **input** (image source). The rest of the pipeline is unchanged.

---

## AI Enhancement (Live Coach + Glasses)

To align with Google's **Innovation & Multimodal UX** (See, Hear, Speak):

| Mode | Flow | Google Alignment |
|------|------|-------------------|
| **Photo → Live Coach** | Glasses capture → `LiveAPIClient.sendImage()` → Live API → agent speaks | ✅ Hands-free capture, voice response |
| **Video stream** (future) | Glasses frames → `realtimeInput` → Live API sees POV | ✅✅ Full See, Hear, Speak |

**Quick win:** Wire HeyCyan capture to Live Coach tab. User wears glasses, taps capture, image goes to Live API; agent analyzes and speaks. No video streaming required.

---

## Troubleshooting: BLE hangs

| Issue | Fix |
|-------|-----|
| Stuck at "Scanning for glasses" after selecting device | A 35s timeout will recover. The SDK can hang during CRC check. **Workaround:** Use **WiFi transfer** — put glasses in transfer mode, enter SSID (e.g. W630_xxxx) from the glasses display, tap "Fetch latest photo". |
| No devices in list | Ensure Bluetooth is on; glasses are powered and in pairing mode; try moving closer. |
| Connection timeout | Put glasses closer; use WiFi transfer as fallback. |
