# HappyDiet

AI diet compliance app for the Gemini Live Agent Challenge. Capture meal photos, get compliance feedback, and track your diet in a dashboard.

## Architecture

- **Backend** (Node.js/Express on Cloud Run): Vertex AI Vision → ingredients, rule engine → compliance, Firestore persistence. Live API proxy at `ws://host/live`.
- **Clients:** Web (index.html with Live API, app.html, dev.html), iOS app (SwiftUI). HeyCyan glasses require native iOS only.

See [docs/architecture-diagram.md](docs/architecture-diagram.md) for the full diagram and client matrix.

## Tests (Regression Protection)

All tests run with one command:

```bash
cd backend && npm test
```

**50 tests** (unit, integration, E2E, UAT). Runs in CI before every deploy. See [docs/testing.md](docs/testing.md) and [docs/uat.md](docs/uat.md).

---

## Interactive Dev Playground (Real GCP)

```bash
cd backend
# Set .env: GOOGLE_CLOUD_PROJECT=your-project
# Run: gcloud auth application-default login
npm run dev
```

Open **http://localhost:8080/dev.html** — upload a meal image, get **real** Vertex AI analysis and Firestore persistence.

**Web showcase (demo):** Open **http://localhost:8080/** — Live API (voice + image), chat, Speak. Demo-ready without phone. Also: Overview, My Plan, Analyze, Dashboard.

See [docs/dev-environment.md](docs/dev-environment.md).

---

## How to Launch

**Full guide:** [docs/how-to-launch.md](docs/how-to-launch.md)

### Quick start

| Step | Command |
|------|---------|
| Backend | `cd backend && npm install && npm run dev` |
| iOS (simulator) | `cd ios && xcodegen generate && open HappyDiet.xcodeproj` → ⌘R |
| iOS (physical iPhone) | Set `BACKEND_URL` in `HappyDietConfig.plist` to `http://YOUR_MAC_IP:8080` → Add Apple ID in Xcode → ⌘R |

**Physical device:** Requires Apple ID (free) for signing. See [docs/how-to-launch.md](docs/how-to-launch.md) for details.

## Project structure

```
happydiet/
├── backend/          # Node.js API, Vertex AI, Firestore
├── ios/               # SwiftUI app
├── docs/              # Spec, design, tasks
└── v1/                # Legacy assets
```

## Deploy to Google Cloud

**Programmatic (recommended):**
```bash
chmod +x scripts/*.sh
./scripts/setup-gcp.sh    # Enable APIs (one-time)
./scripts/deploy.sh       # Tests + deploy
./scripts/verify.sh       # Health check
```

**Manual:**
```bash
cd backend
gcloud run deploy happydiet-backend --source . --region us-central1 \
  --allow-unauthenticated --set-env-vars "GOOGLE_CLOUD_PROJECT=$(gcloud config get-value project)"
```

Full instructions: [docs/deployment-cicd.md](docs/deployment-cicd.md) | [scripts/README.md](scripts/README.md)

---

## API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/analyze-meal` | POST | `{ image_base64, user_id }` → compliance |
| `/meals` | GET | `?user_id=` → meal list |

## Environment

| Variable | Purpose |
|----------|---------|
| `GOOGLE_CLOUD_PROJECT` | GCP project for Vertex AI + Firestore (required) |
| `GOOGLE_CLOUD_LOCATION` | Vertex AI region (default: us-central1) |
| `VERTEX_AI_MODEL` | Model ID (default: gemini-2.0-flash-001) |
| `API_KEY` | Optional X-API-Key for backend auth |

Auth uses Application Default Credentials (`gcloud auth application-default login`) or `GOOGLE_APPLICATION_CREDENTIALS` for service account.

See [docs/gcp-integration.md](docs/gcp-integration.md), [docs/deployment-cicd.md](docs/deployment-cicd.md), and [docs/setup.md](docs/setup.md) for full setup.
