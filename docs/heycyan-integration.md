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
| HeyCyan       | iOS      | **Full BLE + WiFi** when SDK linked; Manual WiFi fallback always available |

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

### 4. Build on Device

HeyCyan BLE requires a **physical iOS device**. Build and run on a connected iPhone/iPad; the simulator does not support Bluetooth.

---

## Web

The web app (`/app.html`) uses **camera** and **file upload** only. Browsers cannot access BLE to HeyCyan glasses directly (Web Bluetooth is limited and not supported on iOS Safari). For web + glasses:

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
