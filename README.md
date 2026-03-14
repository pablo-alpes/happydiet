# HappyDiet

> **The AI diet coach that sees your plate and speaks your plan.**

Built for the **[Gemini Live Agent Challenge](https://geminiliveagentchallenge.devpost.com)** | Runs entirely on **Google Cloud**

---

Take a photo of your meal. The AI tells you — instantly, out loud — whether you're on track with your diet. No typing. No calorie math. Just point, shoot, and listen.

HappyDiet is the first tool that measures **real dietary compliance** — not just calories, but whether the specific foods you ate align with the rules your doctor prescribed. Powered by a 3-agent pipeline (Reader → Processor → Reporter) that combines **Gemini Vision**, a deterministic **Rule Engine**, and the **Gemini Live API** for real-time voice coaching with barge-in.

| Platform | Features |
|----------|----------|
| **Web** | Live Coach (voice + image), Analyze, Diet Rules, Dashboard — demo-ready at `/` |
| **iOS** | Same + camera, photo library, **HeyCyan glasses** (BLE capture) |

### Google Cloud Services Used

| Service | Purpose |
|---------|---------|
| **Vertex AI** (Gemini 2.5 Flash) | Vision (food → ingredients), semantic matching, diet plan parsing |
| **Gemini Live API** | Real-time voice coaching with barge-in and tool calls |
| **Cloud Run** | Serverless backend hosting |
| **Firestore** | `meals` + `diet_rules` persistent storage |
| **Cloud Text-to-Speech** | Spoken compliance feedback |
| **Cloud Build** | CI/CD — tests before deploy |
| **GenAI SDK** | `@google-cloud/vertexai` — official Node.js client |

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

**108 tests across 11 suites** — unit, integration, E2E, and user-acceptance. **100% statement coverage** on domain and application code. Tests run automatically before every Cloud Build deploy. See [docs/testing.md](docs/testing.md).

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

## Judging Criteria Alignment

| Criterion | Weight | Coverage |
|-----------|--------|----------|
| **Demo & Presentation** | 30% | Web showcase with full architecture walkthrough; demo video script ready |
| **Technical Implementation** | 30% | GenAI SDK, 3-agent pipeline, 108 tests (100% coverage), Cloud Build CI/CD |
| **Innovation & Multimodal UX** | 40% | Vision + voice + barge-in; Rule Engine for compliance (not just calories); See/Think/Speak paradigm |

---

## License & Credits

Built for the **[Gemini Live Agent Challenge](https://geminiliveagentchallenge.devpost.com)**. Runs entirely on Google Cloud: Vertex AI, Gemini Live API, Firestore, Cloud Run, Cloud TTS, Cloud Build, GenAI SDK.
