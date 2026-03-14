# HappyDiet Backend

Tool endpoints for Live API: `analyze_meal`, `meals`.

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

## Deploy to Cloud Run

```bash
gcloud run deploy happydiet-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated
```
