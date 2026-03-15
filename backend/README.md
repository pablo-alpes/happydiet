# HappyDiet Backend

Tool endpoints for Live API: `analyze_meal`, `meals`.

**Live API proxy** (`ws://host/live`): Proxies WebSocket to Vertex AI Live API. Translates client formats (camelCase, `audio`) to Vertex wire format (snake_case, `media_chunks`). See [docs/stack-architecture.md](../docs/stack-architecture.md#proxy-format-translation).

## Quick Start

```bash
# 1. Add to .env (project root or backend/)
GOOGLE_CLOUD_PROJECT=your-project-id
GOOGLE_CLOUD_LOCATION=us-central1
API_KEY=$(openssl rand -hex 32)

# 2. Run (choose one)
npm install && npm run dev

# Or with Docker (modular)
docker compose up
# Dev mode: docker compose -f docker-compose.dev.yml up
```

Backend runs at `http://localhost:8080`.

## Test UI

Open `http://localhost:8080/test.html` to test GCP integration:
- Health check
- Analyze meal (upload image)
- Get meals

## Tests

```bash
npm test        # Unit + integration + E2E
npm run test:ci # Avec rapport JUnit (test-results/junit.xml)
```

**Règle :** Ne pas merger si les tests échouent.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check |
| POST | `/analyze-meal` | Analyze meal image (body: `{ image_base64, user_id }`) |
| GET | `/meals?user_id=demo` | List meals for user |

## Coach voice: Google TTS vs phone voice

The app uses **backend `POST /speak`** (Google Cloud Text-to-Speech) for the coach voice when available. If the backend returns 503/500 or the request fails, the app falls back to the **phone’s built-in TTS** (AVSpeechSynthesizer), so you still hear the coach but with the device voice.

To get **Google’s natural voice** (same as on the web) in the app:

1. **Enable the API** in your GCP project:
   ```bash
   gcloud services enable texttospeech.googleapis.com --project=YOUR_PROJECT_ID
   ```
   Or in the console: [Cloud Text-to-Speech API](https://console.cloud.google.com/apis/library/texttospeech.googleapis.com) → Enable.
2. **Cloud Run**: The default service account usually has access. If `/speak` returns 503, grant **Cloud Text-to-Speech User** to the Cloud Run service account in IAM.

Then redeploy; the app will use the same backend URL and get MP3 from `/speak` instead of the phone’s built-in TTS.

## Analyze meal fails ("Could not analyze")

When `POST /analyze-meal` returns 500, the response includes an `error` hint and `detail` (the real exception). Check **backend logs** (Cloud Run → Logs, or `npm run dev` terminal) for the full stack.

**404 "Publisher Model was not found or your project does not have access":** Enable Vertex AI API, grant the Cloud Run service account `roles/aiplatform.user`, and ensure billing is on. If it still fails, use the global endpoint and a stable model by setting env vars (e.g. in Cloud Run → Edit → Variables): `VERTEX_AI_LOCATION=global`, `VERTEX_AI_MODEL=gemini-2.0-flash-001`. Then redeploy or restart.

**"The query requires an index" (getDailyKcal):** The `meals` collection needs a composite index on `userId` + `timestamp`. Click the link in the error to create it in Firebase Console, or deploy indexes with `firebase deploy --only firestore:indexes` (requires `firebase.json` pointing at `backend/firestore.indexes.json`). See `backend/firestore.indexes.json` for the definition. Until the index exists, daily kcal defaults to 0 and the rest of the flow still runs.

**Common causes:**

| Cause | What you see | Fix |
|-------|----------------|-----|
| **Quota** | 429, RESOURCE_EXHAUSTED | Wait or increase Vertex AI quota in GCP; free tier has limits. |
| **Project / API** | 403, "not found" | Set `GOOGLE_CLOUD_PROJECT` in `.env`; enable [Vertex AI API](https://console.cloud.google.com/apis/library/aiplatform.googleapis.com). |
| **Auth** | 401, unauthenticated | On Cloud Run: service account needs **Vertex AI User**. Local: `gcloud auth application-default login`. |
| **Service down** | 503, UNAVAILABLE | Retry later; check [GCP status](https://status.cloud.google.com/). |
| **Vision no result** | "no response from model" | Image too small, blurry, or not a meal; try another photo. |

The web and app show the backend `detail` when present so you can see the exact error.

## Deploy to Cloud Run

### Option A: From your machine (gcloud CLI)

1. **Install and log in** (if needed):
   ```bash
   gcloud auth login
   gcloud config set project YOUR_GCP_PROJECT_ID
   ```

2. **From the repo root** (not inside `backend/`), run:
   ```bash
   cd /path/to/happydiet
   gcloud builds submit --config cloudbuild.yaml .
   ```
   This runs tests in `backend/` then deploys the backend to Cloud Run. The first time you may be asked to enable the Cloud Build API.

3. **Or deploy only the backend** (no tests, from repo root):
   ```bash
   cd backend
   gcloud run deploy happydiet-backend \
     --source . \
     --region us-central1 \
     --allow-unauthenticated \
     --set-env-vars "GOOGLE_CLOUD_PROJECT=YOUR_GCP_PROJECT_ID,GOOGLE_CLOUD_LOCATION=us-central1"
   ```
   Replace `YOUR_GCP_PROJECT_ID` with your actual GCP project ID (e.g. from the Cloud Run URL or `gcloud config get-value project`).

### Option B: Via GitHub (push to main)

If your repo has the deploy workflow and secrets set (e.g. `GCP_PROJECT_ID`, `GCP_SA_KEY`):

1. Commit and push your changes to `main`:
   ```bash
   git add -A && git commit -m "Backend: better analyze-meal errors" && git push origin main
   ```
2. Open **Actions** on GitHub and watch the "Deploy to Cloud Run" workflow. When it finishes, the backend is redeployed.
