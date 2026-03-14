# HappyDiet

**Your AI diet coach — see, hear, and speak.** Capture meal photos, get instant compliance feedback, and chat with a voice-first coach powered by Gemini Live API.

---

## What It Does

HappyDiet helps you stick to your diet in real time. Take a photo of your meal, and the AI analyzes it against your rules — compliant items, off-plan items, and suggestions. Connect the **Live Coach** to talk naturally: ask why certain foods are off limits, share a meal photo and hear the analysis spoken aloud, or get tasks to stay on track. Diet is the core; the coach can also suggest related habits (sleep, exercise) when they support your goals.

| Platform | Features |
|----------|----------|
| **Web** | Live Coach (voice + image), Analyze, Diet Rules, Dashboard — demo-ready at `/` |
| **iOS** | Same + camera, photo library, **HeyCyan glasses** (BLE capture) |

---

## Key Features

### 🎙️ Live Coach (Gemini Live API)

- **Voice-first:** Speak or type; the coach replies in text and voice.
- **Meal photos:** Share an image → coach calls `analyze_meal` → speaks the compliance result.
- **Tasks:** Coach assigns diet-related tasks (log weight, share next meal, 30-min walk) — they appear in your list automatically.
- **Spoken welcome:** Coach greets you out loud when you connect.
- **Barge-in:** Interrupt while the coach is speaking.

### 📷 Meal Analysis

- **Vision → ingredients:** Vertex AI extracts items from the photo.
- **Rule engine:** Fuzzy + semantic matching against your diet rules (forbidden, allowed, limits).
- **Composite dishes:** Parrillada, paella, stir-fry, etc. are broken into components for accurate scoring.
- **Output:** Score, compliant/non-compliant items, suggestions, estimated kcal.

### 📋 Diet Rules

- **Parse from text or image:** Upload a diet plan (typed or photo) → rules are extracted.
- **Rule types:** Avoid, Prefer, Limit (max/day), Notes.
- **Persist:** Save to Firestore; coach and analyzer use them.

### 📊 Dashboard

- **Compliance trend:** 14-day view with average.
- **Meal suggestions:** Next meal time with photo.
- **Tasks:** Coach-assigned tasks; mark done.
- **Weight & goals:** Log weight, set targets.

### 👓 HeyCyan Glasses (iOS)

- **BLE capture:** Take a meal photo with HeyCyan glasses; send to Analyze or Live Coach.
- **Native iOS only** — web cannot access BLE.

---

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌──────────────────────────┐
│  Web / iOS      │────▶│  Backend        │────▶│  Vertex AI + Firestore    │
│  Live Coach     │     │  /live (WS)     │     │  Vision, Live API, TTS    │
│  Analyze, Diet  │     │  /analyze-meal  │     │  meals, diet_rules        │
└─────────────────┘     └─────────────────┘     └──────────────────────────┘
```

- **Backend:** Node.js/Express on Cloud Run. WebSocket proxy at `/live` for Gemini Live API; REST for analyze, parse-diet, meals, rules.
- **Clients:** Web (index.html, app.html, dev.html), iOS (SwiftUI).
- **GCP:** Vertex AI (Vision, Live API, TTS), Firestore.

See [docs/architecture-diagram.md](docs/architecture-diagram.md) for the full diagram.

---

## Quick Start

| Step | Command |
|------|---------|
| Backend | `cd backend && npm install && npm run dev` |
| Web | Open **http://localhost:8080** — Live Coach, Analyze, Diet, Dashboard |
| iOS (simulator) | `cd ios && xcodegen generate && open HappyDiet.xcodeproj` → ⌘R |
| iOS (physical) | Set `BACKEND_URL` in `HappyDietConfig.plist` to `http://YOUR_MAC_IP:8080` → ⌘R |

**Prerequisites:** Node.js 20+, Xcode 16+, `gcloud auth application-default login` for real Vertex AI.

**Full guide:** [docs/how-to-launch.md](docs/how-to-launch.md)

---

## Dev Playground

For real GCP analysis without the full UI:

```bash
cd backend
# Set .env: GOOGLE_CLOUD_PROJECT=your-project
# Run: gcloud auth application-default login
npm run dev
```

Open **http://localhost:8080/dev.html** — upload a meal image, get **real** Vertex AI analysis and Firestore persistence. See [docs/dev-environment.md](docs/dev-environment.md).

---

## Project Structure

```
happydiet/
├── backend/          # Node.js API, Vertex AI, Firestore, Live API proxy
├── ios/               # SwiftUI app (Live Coach, Analyze, Diet, Dashboard, Goals, Meals)
├── docs/              # Spec, architecture, setup, deployment
└── scripts/           # deploy.sh, setup-gcp.sh, verify.sh
```

---

## API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/analyze-meal` | POST | `{ image_base64, user_id }` → compliance score, items, suggestions |
| `/parse-diet` | POST | `{ diet_text|image_base64, user_id, save }` → rules |
| `/meals` | GET | `?user_id=` → meal list |
| `/rules` | GET | `?user_id=` → diet rules |
| `/speak` | POST | Text-to-speech → MP3 |
| `/live` | WebSocket | Live API proxy → Vertex AI Live API |

---

## Environment

| Variable | Purpose |
|----------|---------|
| `GOOGLE_CLOUD_PROJECT` | GCP project (required) |
| `GOOGLE_CLOUD_LOCATION` | Vertex AI region (default: us-central1) |
| `VERTEX_AI_MODEL` | Model ID (default: gemini-2.0-flash-001) |
| `API_KEY` | Optional X-API-Key for backend auth |

Auth: `gcloud auth application-default login` or `GOOGLE_APPLICATION_CREDENTIALS`.

---

## Deploy to Google Cloud

```bash
chmod +x scripts/*.sh
./scripts/setup-gcp.sh    # Enable APIs (one-time)
./scripts/deploy.sh       # Tests + deploy to Cloud Run
./scripts/verify.sh       # Health check
```

Manual: [docs/deployment-cicd.md](docs/deployment-cicd.md) | [scripts/README.md](scripts/README.md)

---

## Tests

```bash
cd backend && npm test
```

**50+ tests** (unit, integration, E2E, UAT). Runs in CI before deploy. See [docs/testing.md](docs/testing.md).

---

## Docs

| Doc | Description |
|-----|-------------|
| [docs/how-to-launch.md](docs/how-to-launch.md) | Step-by-step launch guide |
| [docs/features.md](docs/features.md) | Full feature inventory |
| [docs/architecture-diagram.md](docs/architecture-diagram.md) | Architecture diagram |
| [docs/setup.md](docs/setup.md) | Backend setup |
| [docs/heycyan-integration.md](docs/heycyan-integration.md) | HeyCyan glasses setup |

---

## License & Credits

Built for the **Gemini Live Agent Challenge**. Uses Vertex AI, Gemini Live API, Firestore, Cloud Run.
