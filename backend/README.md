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

## Deploy to Cloud Run

```bash
gcloud run deploy happydiet-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated
```
