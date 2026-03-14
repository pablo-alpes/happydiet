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

**Option A: Edit plist (build-time default)**

Edit `HappyDiet/HappyDietConfig.plist`:

| Target | BACKEND_URL |
|--------|-------------|
| Simulator | `http://localhost:8080` (default) |
| Physical iPhone | `http://YOUR_MAC_IP:8080` |
| Production (Cloud) | `https://YOUR-CLOUD-RUN-URL.run.app` |

Mac IP: System Settings → Network → Wi‑Fi → Details, or `ipconfig getifaddr en0`

**Option B: In-app Settings (no rebuild)**

1. Open the app → **More** tab → **Settings**.
2. Enter the backend URL (e.g. `http://192.168.0.21:8080`).
3. Tap **Save**, then **Test Connection**.
4. If "OK — Backend reachable (200)" appears, you're good. Go to Coach tab and connect.

The in-app override persists across restarts and takes priority over the plist. Clear the field to revert.

### Backend auto-discovery (physical device only)

On a physical device, the app can auto-discover the backend on the local network. **No hardcoded subnets** — fully configurable per rollout:

| Plist key | Purpose |
|-----------|---------|
| `BACKEND_DISCOVERY_ENABLED` | `false` = skip discovery (use for cloud builds) |
| `BACKEND_DISCOVERY_SUBNETS` | Array of subnet prefixes, e.g. `["192.168.1.", "10.0.0."]` — if absent, uses device's own subnet only |
| `BACKEND_DISCOVERY_PORT` | Port to probe (default 8080) |
| `BACKEND_DISCOVERY_PATH` | Health path (default `/health`) |

**Local dev:** No config needed — device subnet is used dynamically.  
**Cloud deployment:** Set `BACKEND_DISCOVERY_ENABLED` = `false` and `BACKEND_URL` to your Cloud Run URL.

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

## Background Modes & Capabilities

The iOS target includes several background modes in `Info.plist` (`UIBackgroundModes`) to support HeyCyan and future features:

| Mode | Purpose |
|------|---------|
| `bluetooth-central` | BLE scanning/connection to HeyCyan glasses |
| `bluetooth-peripheral` | BLE peripheral role for HeyCyan |
| `audio` | Live Coach voice playback in background |
| `fetch` | Background data refresh |
| `processing` | Background task processing |
| `location` | Location-based features (if needed) |
| `nearby-interaction` | U1/Nearby Interaction (HeyCyan) |
| `external-accessory` | MFi accessories |

**Privacy descriptions** (Info.plist): Bluetooth, Camera, Microphone, Photo Library, Local Network — required for HeyCyan and Live Coach.

## HeyCyan SDK (Lenses BLE)

**Single scheme — `HappyDiet`** — handles both simulator and device automatically:

| Build target | HeyCyan BLE | How |
|-------------|-------------|-----|
| **Simulator** | Disabled (Camera/Photo/WiFi only) | QCSDK `.m` files excluded, flag not set |
| **Physical device** | Enabled (full BLE + WiFi) | QCSDK linked, `HEYCYAN_SDK_LINKED` set automatically |

QCSDK is a static framework (device-only, no simulator slice). The build system auto-excludes it on simulator.

**First-time setup:**
```bash
./ios/scripts/setup-heycyan.sh
cd ios && xcodegen generate
```
Then in Xcode: select **HappyDiet** scheme, choose your iPhone, set signing team, run (⌘R).

## Troubleshooting

| Issue | Fix |
|-------|-----|
| XcodeGen not found | `brew install xcodegen` |
| **Live Coach can't connect** | Start backend: `cd backend && npm run dev`. Then in-app: More → Settings → enter URL → Test Connection. |
| "Could not connect" on phone | Use Mac's IP in backend URL; same Wi‑Fi; test with More → Settings → Test Connection |
| "Send failed" in Coach | Wait for "Connected" before sending. Check backend URL in More → Settings. |
| 503 from backend | Set `GOOGLE_CLOUD_PROJECT` in `backend/.env` |
| Code signing / developer certificate | Add Apple ID in Xcode → Settings → Accounts → Signing & Capabilities → set Team |
