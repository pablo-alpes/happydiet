# HappyDiet iOS — Setup & Run

See **[docs/setup.md](../docs/setup.md)** for full setup. Quick reference:

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

## Troubleshooting

| Issue | Fix |
|-------|-----|
| XcodeGen not found | `brew install xcodegen` |
| "Could not connect" on phone | Mac's IP in BACKEND_URL; same Wi‑Fi |
| 503 from backend | Set `GOOGLE_CLOUD_PROJECT` in `backend/.env` |
