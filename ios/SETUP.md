# HappyDiet iOS — Setup & Run

**Full launch guide:** [docs/how-to-launch.md](../docs/how-to-launch.md)

See **[docs/setup.md](../docs/setup.md)** for GCP setup. Quick reference:

## 1. Install XcodeGen

```bash
brew install xcodegen
```

## 2. Generate project and open Xcode

From **repo root**:

```bash
cd ios
xcodegen generate
open -a Xcode HappyDiet.xcodeproj
```

**Use `open -a Xcode`** — plain `open` may open Finder instead of Xcode.

## 3. Configure BACKEND_URL

Edit `HappyDiet/HappyDietConfig.plist`:

| Target | BACKEND_URL |
|--------|-------------|
| Simulator | `http://localhost:8080` (default) |
| Physical iPhone | `http://YOUR_MAC_IP:8080` |
| Production | `https://YOUR-CLOUD-RUN-URL.run.app` |

Mac IP: System Settings → Network → Wi‑Fi → Details, or `ipconfig getifaddr en0`

## 4. Run backend (separate terminal)

```bash
cd backend
npm run dev
```

## 5. Run app in Xcode

1. Select **iPhone 16** (or any simulator) or your physical device.
2. Press **⌘R**.

### Physical device: Apple ID signing

Xcode will ask for your Apple ID to sign the app. Add it in **Xcode → Settings → Accounts**, then enable **Automatically manage signing** in the target's **Signing & Capabilities**. A free Apple ID works; the app may expire after ~7 days.

## HeyCyan SDK (Lenses BLE)

**Two schemes:**

| Scheme | Use for | HeyCyan BLE |
|--------|---------|-------------|
| **HappyDiet** | Simulator | No (Camera/Photo/WiFi only) |
| **HappyDiet-Device** | Physical device | Yes (full BLE) |

QCSDK is device-only (no simulator slice). Use **HappyDiet-Device** when building for a real iPhone.

**First-time setup for device:**
```bash
./ios/scripts/setup-heycyan.sh
cd ios && xcodegen generate
```
Then in Xcode: select scheme **HappyDiet-Device**, choose your iPhone, run (⌘R).

## Troubleshooting

| Issue | Fix |
|-------|-----|
| XcodeGen not found | `brew install xcodegen` |
| **Live Coach can't connect** | Start backend: `cd backend && npm run dev`. Simulator: `http://localhost:8080`. Device: `http://YOUR_MAC_IP:8080` in HappyDietConfig.plist. |
| "Could not connect" on phone | Mac's IP in BACKEND_URL; same Wi‑Fi |
| 503 from backend | Set `GOOGLE_CLOUD_PROJECT` in `backend/.env` |
| Code signing / developer certificate | Add Apple ID in Xcode → Settings → Accounts |
