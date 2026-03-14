# HappyDiet — Software Features

**Objective:** Complete inventory of implemented features, organized by component. Reference for demos, documentation, and onboarding.

**Last updated:** March 2026

---

## 1. Backend API

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check; returns `{ status, service }` |
| POST | `/analyze-meal` | Analyze meal image; returns compliance score, items, message |
| POST | `/parse-diet` | Parse diet from text or image; optional save to Firestore |
| POST | `/speak` | Text-to-speech; returns MP3 audio |
| GET | `/meals` | List meals for user (`?user_id=`) |
| GET | `/rules` | List saved diet rules for user (`?user_id=`) |
| WebSocket | `/live` | Live API proxy → Vertex AI Live API; tool `analyze_meal` |

### Analyze Meal

- **Input:** `image_base64`, `user_id`, optional `diet_text` or `diet_rules`
- **Output:** `score`, `compliantItems`, `nonCompliantItems`, `suggestions`, `message`, `ingredients`, `estimatedKcal`
- **Flow:** Vision → rule matching (fuzzy + LLM semantic) → persist → reporter message

### Parse Diet

- **Input:** `diet_text` or `image_base64`, `user_id`, `save` (boolean)
- **Output:** `rules` (array), `saved` (boolean)
- **Rule types:** `forbidden`, `allowed`, `limit`, `note`
- **Robustness:** JSON mode, fallback parsing, markdown extraction

---

## 2. Diet Rules Engine

### Rule Types

| Type | Fields | Purpose |
|------|--------|---------|
| `forbidden` | items[], reason? | Not allowed |
| `allowed` | items[], maxPortion? | Explicitly allowed |
| `limit` | items[], maxPerDay, unit | Max per day |
| `note` | text | Other instructions (kcal, timing) |

### Matching

- **Precise:** Exact and substring match
- **Fuzzy:** Word overlap, similarity ≥ 0.6
- **Semantic (LLM):** When custom rules exist, LLM checks e.g. "bread contains gluten" → non-compliant

---

## 3. iOS App

### Tabs

| Tab | Features |
|-----|----------|
| **Live Coach** | Live API (WebSocket to `/live`); text + image → agent speaks; barge-in supported |
| **Analyze** | Camera, photo library, or HeyCyan → analyze → compliance card; Speak button (backend TTS or AV fallback) |
| **Diet** | Text input, camera/photo for diet image; Parse, Parse & Save, Load saved; full diet display |
| **Dashboard** | Meal history with compliance scores and ingredients |

### Capabilities

- Camera, photo library, **HeyCyan** (native iOS only — BLE + WiFi)
- Backend URL config: **More → Settings** (override) or `HappyDietConfig.plist` (`BACKEND_URL`, `API_KEY`)
- TTS: tries backend `/speak` first, falls back to `AVSpeechSynthesizer`

---

## 4. Web App (iOS Look & Feel)

**URL:** `http://localhost:8080/app.html` (when backend running)

Same tabs and flow as iOS: Analyze, Diet, Dashboard. Uses camera/upload for capture. **HeyCyan requires native iOS** — web cannot access BLE.

**Showcase (index.html):** Polished web interface at `/` with **Live API** (WebSocket to `/live`), voice input, image upload, chat, Speak. Demo-ready without phone. Also: Overview, My Plan, Analyze, Dashboard.

### Tabs

| Tab | Features |
|-----|----------|
| **Analyze** | Take photo or upload → Analyze Meal → compliance card with Speak |
| **Diet** | Text or image input; Parse, Parse & Save, Load saved; full diet rules display |
| **Dashboard** | Meal list with compliance scores |

---

## 5. Dev Playground

**URL:** `http://localhost:8080/dev.html` (when backend running)

### Tabs

| Tab | Features |
|-----|----------|
| **Full View** | Diet rules (text + image), parse/save; meal image (camera/upload); analyze; result with Speak button |
| **Rules** | Full parsed diet: Not allowed, Allowed, Limits, Notes; Refresh from backend |
| **Dashboard** | Meal list with compliance scores |

### Diet Input

- Text area for diet description
- Image: file upload or camera capture
- Parse text / Parse & Save
- Parse image / Parse & Save
- Rules preview with "Not allowed" and "Allowed"

### Meal Analysis

- Take photo or upload file
- Analyze Meal button
- Result: score, message, compliant/non-compliant items, suggestions, kcal
- Speak button: backend TTS or Web Speech API fallback

---

## 6. HeyCyan Glasses Integration

| Component | Status |
|-----------|--------|
| **Capture source abstraction** | `MealCaptureSource` enum (camera, photoLibrary, heycyan) |
| **iOS HeyCyan button** | Analyze tab: Camera, Photo Library, HeyCyan |
| **HeyCyanCaptureSheet** | Setup instructions when SDK not linked |
| **HeyCyanService** | Stub; full BLE + WiFi flow requires QCSDK framework |

See [heycyan-integration.md](./heycyan-integration.md) for setup.

---

## 7. Google Cloud Integration

| Service | Usage |
|---------|-------|
| **Vertex AI** | Vision (meal → ingredients), parse diet (text/image → rules), semantic compliance |
| **Firestore** | `meals`, `diet_rules`; separate DBs configurable via env |
| **Cloud TTS** | `/speak` endpoint; voice `en-US-Neural2-C` |
| **Cloud Run** | Backend hosting |

---

## 8. Scripts & Deployment

| Script | Purpose |
|--------|---------|
| `./scripts/setup-gcp.sh` | Enable GCP APIs |
| `./scripts/setup-production.sh` | Full setup: APIs, Firestore DBs, .env, auth |
| `./scripts/deploy.sh` | Run tests, deploy to Cloud Run (reads .env) |
| `./scripts/verify.sh` | Smoke test deployed backend |

---

## 9. Configuration

### Backend (.env)

| Variable | Required | Description |
|----------|----------|-------------|
| `GOOGLE_CLOUD_PROJECT` | Yes | GCP project ID |
| `GOOGLE_CLOUD_LOCATION` | No | Default `us-central1` |
| `FIRESTORE_DATABASE_MEALS` | No | Default `(default)` or `happydiet` |
| `FIRESTORE_DATABASE_RULES` | No | Default `(default)` or `rules` |
| `API_KEY` | No | X-API-Key header |
| `VERTEX_AI_MODEL` | No | Default `gemini-2.5-flash` |

### iOS (HappyDietConfig.plist)

| Key | Description |
|-----|-------------|
| `BACKEND_URL` | Backend base URL (localhost for simulator, Mac IP for device) |
| `API_KEY` | Optional; same as backend |

---

## 10. Testing

| Component | Location | Command |
|----------|----------|---------|
| Backend unit | `backend/tests/unit/` | `npm test` |
| Backend E2E | `backend/tests/e2e/` | `npm test` |
| Live API proxy | `backend/tests/unit/live-api-proxy.test.ts` | `npm test` |
| iOS unit | `ios/HappyDietTests/` | Xcode ⌘U or `xcodebuild test` |

---

## 11. Not Yet Implemented

| Feature | Notes |
|---------|-------|
| **Demo video** | <4 min for submission |
| **Production deploy** | First Cloud Run deploy with env vars |
