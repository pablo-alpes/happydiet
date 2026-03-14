# HappyDiet — Google Cloud Integration

**Objective:** Document how the backend integrates with GCP APIs and how to configure them.

---

## APIs Used

| API | Purpose | SDK | Auth |
|-----|---------|-----|------|
| **Vertex AI** | Vision: image → ingredients, kcal | `@google-cloud/vertexai` | ADC |
| **Firestore** | Meals, diet rules persistence | `@google-cloud/firestore` | ADC |
| **Cloud Text-to-Speech** | TTS for dev playground | `@google-cloud/text-to-speech` | ADC |
| **Cloud Run** | Backend hosting | — | — |

---

## Authentication

All GCP client libraries use **Application Default Credentials (ADC)**:

1. **Local dev:** Run `gcloud auth application-default login`
2. **Service account:** Set `GOOGLE_APPLICATION_CREDENTIALS` to path of JSON key
3. **Cloud Run:** Automatic via service account attached to the service

No API keys are used for Vertex AI or Firestore; they use OAuth2/ADC.

---

## Vertex AI

### Configuration

| Env var | Default | Description |
|---------|---------|-------------|
| `GOOGLE_CLOUD_PROJECT` | — | GCP project ID (required) |
| `GOOGLE_CLOUD_LOCATION` | `us-central1` | Vertex AI region |
| `VERTEX_AI_MODEL` | `gemini-2.5-flash` | Model ID for vision |

### Model IDs

- `gemini-2.5-flash` — Latest stable (recommended)
- `gemini-2.0-flash-001` — Legacy; may 404 on new projects
- `gemini-1.5-flash` — Fallback

### Enable API

```bash
gcloud services enable aiplatform.googleapis.com
```

---

## Cloud Text-to-Speech

Used by the dev playground **Speak** button. Returns MP3 audio.

### Enable API

```bash
gcloud services enable texttospeech.googleapis.com
```

### Voice

Default: `en-US-Neural2-C` (natural female). Edit `google-tts.ts` to change.

### Retry

The client retries on 429, 503, RESOURCE_EXHAUSTED, UNAVAILABLE, DEADLINE_EXCEEDED (3 attempts, exponential backoff).

---

## Firestore

### Configuration

| Env var | Description |
|---------|-------------|
| `GOOGLE_CLOUD_PROJECT` | Firestore project (same as Vertex AI) |
| `FIRESTORE_DATABASE_MEALS` | Database for meals (default: `(default)`). Use `happydiet` if you have a dedicated DB. |
| `FIRESTORE_DATABASE_RULES` | Database for diet rules (default: `(default)`). Use `rules` if you have a dedicated DB. |

### Databases & Collections

| Database | Collection | Purpose |
|----------|------------|---------|
| `happydiet` (or default) | `meals` | Meal records (ingredients, compliance, timestamp) |
| `rules` (or default) | `diet_rules` | Parsed rules per user (allowances, restrictions) |

Set `FIRESTORE_DATABASE_MEALS=happydiet` and `FIRESTORE_DATABASE_RULES=rules` in `.env` for separation of concerns.

### Enable API

```bash
gcloud services enable firestore.googleapis.com
```

### Create Database

- Console → Firestore → Create database
- Native mode, region e.g. `us-central1`

### Retry

Writes use 3 retries with exponential backoff. Reads are single-attempt.

---

## Cloud Run

### Deploy

```bash
cd backend
gcloud run deploy happydiet-backend \
  --source . \
  --region us-central1 \
  --set-env-vars GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID \
  --allow-unauthenticated
```

### Env vars on Cloud Run

`./scripts/deploy.sh` reads `backend/.env` and passes these to Cloud Run:

- `GOOGLE_CLOUD_PROJECT` (required)
- `GOOGLE_CLOUD_LOCATION` (optional, default us-central1)
- `FIRESTORE_DATABASE_MEALS` (optional)
- `FIRESTORE_DATABASE_RULES` (optional)
- `VERTEX_AI_MODEL` (optional)
- `API_KEY` (optional, for X-API-Key)

---

## Enable All APIs

```bash
gcloud services enable \
  aiplatform.googleapis.com \
  firestore.googleapis.com \
  texttospeech.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com
```

Or run `./scripts/setup-production.sh` for full production setup (APIs, Firestore DBs, .env, auth).

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `Missing GOOGLE_CLOUD_PROJECT` | Set in `.env` |
| `403` / `Permission denied` | Run `gcloud auth application-default login` or set `GOOGLE_APPLICATION_CREDENTIALS` |
| `Vertex AI API has not been used` | `gcloud services enable aiplatform.googleapis.com` |
| `Firestore database not found` | Create database in Console |
| `429` / `RESOURCE_EXHAUSTED` | Client retries; check quotas in Console |
