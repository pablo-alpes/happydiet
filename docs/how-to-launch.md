# How to Launch HappyDiet

Step-by-step guide to run the backend and iOS app locally.

---

## Prerequisites

- **Node.js 20+** (backend)
- **Xcode 16+** (or 15+), **iOS 17+** (iOS app)
- **Apple ID** (free) — required for running on a physical iPhone
- **gcloud CLI** (optional) — for real Vertex AI; run `gcloud auth application-default login` if using GCP

---

## 1. Backend

```bash
cd backend
npm install
```

Ensure `backend/.env` exists with at least:

```
GOOGLE_CLOUD_PROJECT=your-project-id
PORT=8080
```

Then:

```bash
npm run dev
```

Backend runs at **http://localhost:8080**.

| Issue | Fix |
|-------|-----|
| 503 / "Backend not configured" | Run `gcloud auth application-default login` |
| Missing .env | Copy from `.env.example` and set `GOOGLE_CLOUD_PROJECT` |

---

## 2. iOS App — Simulator

**Use this when:** You don't need HeyCyan glasses or a physical device.

```bash
cd ios
# If using XcodeGen:
brew install xcodegen
xcodegen generate

open HappyDiet.xcodeproj
```

In Xcode:

1. Select an **iPhone simulator** (e.g. iPhone 16) as the run destination
2. Press **⌘R**

`HappyDietConfig.plist` uses `http://localhost:8080` by default — works for simulator.

---

## 3. iOS App — Physical iPhone

**Use this when:** You need HeyCyan glasses (BLE) or want to test on a real device.

### 3.1 Configure backend URL

**Option A — In-app Settings (recommended):** Open the app → **More** → **Settings** → set Backend URL to `http://YOUR_MAC_IP:8080` (e.g. `http://192.168.1.5:8080`) → Save. Reconnect the Coach tab to use the new URL.

**Option B — Edit plist:** Edit `ios/HappyDiet/HappyDietConfig.plist` and set `BACKEND_URL` to `http://YOUR_MAC_IP:8080`.

Mac and iPhone must be on the **same Wi‑Fi**. Find your Mac IP: **System Settings → Network → Wi‑Fi → Details**, or run `ipconfig getifaddr en0`

### 3.2 Apple ID signing

1. **Xcode → Settings → Accounts**
2. Click **+** → add your Apple ID (free iCloud account)
3. Select the **HappyDiet** target in the project navigator
4. Open **Signing & Capabilities**
5. Enable **Automatically manage signing**
6. Choose your **Team** (your Apple ID appears as "Personal Team")

**Note:** With a free Apple ID, the app may expire after ~7 days; rebuild and reinstall to refresh.

### 3.3 Run

1. Connect your iPhone via USB
2. Select your **iPhone** as the run destination (not a simulator)
3. Press **⌘R**
4. On first run: **Settings → General → VPN & Device Management** → trust your developer certificate

---

## 4. HeyCyan Glasses (Optional)

**Use this when:** You have HeyCyan smart glasses and want hands-free meal capture.

### Requirements

- Physical iPhone (BLE does not work in simulator)
- HeyCyan glasses (W610/W630)

### Setup

```bash
# From project root
./ios/scripts/setup-heycyan.sh
```

Then in Xcode:

1. Add `ios/Frameworks/QCSDK.framework` to the HappyDiet target → **Embed & Sign**
2. **Build Settings → Swift Compiler → Active Compilation Conditions** → add `HEYCYAN_SDK_LINKED`
3. Add bridging header if required (see script output)

**Note:** `QCSDK.framework` is device-only. Simulator builds may fail when HeyCyan is linked; use a physical device.

---

## Quick Reference

| Step | Command / Action |
|------|------------------|
| Backend | `cd backend && npm run dev` |
| iOS (simulator) | Open `ios/HappyDiet.xcodeproj` → Select simulator → ⌘R |
| iOS (device) | Set `BACKEND_URL` to Mac IP → Add Apple ID → Select device → ⌘R |
| HeyCyan | Run `./ios/scripts/setup-heycyan.sh` → Configure Xcode → Use physical device |

---

## Running iOS unit tests

```bash
cd ios
xcodebuild test -scheme HappyDiet -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' -only-testing:HappyDietTests
```

Or in Xcode: **Product → Test** (⌘U). Ensure the HappyDiet scheme includes the HappyDietTests target (Edit Scheme → Test → add HappyDietTests).

---

## Troubleshooting: CodeSign failed

| Cause | Fix |
|-------|-----|
| Wrong development team | Xcode → HappyDiet target → **Signing & Capabilities** → **Team** → select your Apple ID (Personal Team) |
| Keychain prompt | Click **Allow** and enter your **Mac login password** |
| QCSDK framework | Project now uses "Embed Without Signing" for QCSDK; if it still fails, ensure you're building for a **physical device** (QCSDK is device-only) |
| No team selected | Add Apple ID in **Xcode → Settings → Accounts**, then select your team in Signing & Capabilities |

---

## See Also

- [ios/SETUP.md](../ios/SETUP.md) — iOS-specific setup
- [docs/heycyan-integration.md](./heycyan-integration.md) — HeyCyan integration details
- [docs/dev-environment.md](./dev-environment.md) — Web dev playground
