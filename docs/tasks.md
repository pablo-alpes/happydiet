# HappyDiet — Implementation Tasks

**Objective:** Define what to do and in what order. Aligned with current state and project goal.

**Deadline:** March 16, 2026

**TDD:** Mandatory for all layers. See design.md.

---

## Current Status

| Area | Done | Pending |
|------|------|---------|
| **Backend** | Vision, 3 agents, Firestore, TTS, parse-diet, retries, Live API proxy | — |
| **iOS** | Image capture, Diet tab, backend TTS, dashboard, **Live Coach** (Live API) | — |
| **Deployment** | cloudbuild.yaml, Dockerfile | Set env vars, first deploy |
| **Compliance** | Architecture diagram, README, Live API | Demo video, public repo |

---

## Phase 1: Deploy to Google Cloud (Priority)

### 1.1 First-Time GCP Setup
- [ ] Create GCP project (or use existing)
- [ ] Run `./scripts/setup-production.sh PROJECT_ID` (enables APIs including TTS, creates Firestore DBs, generates .env)
- [ ] Or manually: enable `aiplatform`, `firestore`, `texttospeech`, `run`, `cloudbuild`, `artifactregistry`; create Firestore DB; `gcloud auth application-default login`

### 1.2 Deploy Backend to Cloud Run
- [ ] Run `./scripts/deploy.sh` (reads .env for GOOGLE_CLOUD_PROJECT, Firestore DBs, API_KEY)
- [ ] Verify: `curl https://YOUR-URL/health` and `POST /analyze-meal` with test image

### 1.3 Connect Repo (Optional)
- [ ] Push to GitHub (public)
- [ ] Connect GitHub to Cloud Build
- [ ] Create trigger for `main` branch

See **[deployment-cicd.md](./deployment-cicd.md)** for step-by-step instructions.

---

## Phase 2: Live API Integration (Compliance)

### 2.1 iOS WebSocket Client
- [ ] Add Gemini Live API WebSocket client
- [ ] Configure tool: `analyze_meal` → backend URL
- [ ] Handle tool response → audio playback

### 2.2 Barge-in
- [ ] Verify user can interrupt agent
- [ ] Test voice + vision flow end-to-end

---

## Phase 3: Polish & Submission

### 3.1 Demo Video
- [ ] Record <4 min: problem, solution, live demo
- [ ] Show Cloud Run console or deployment proof
- [ ] No mockups; actual software

### 3.2 Rules from Image (Optional)
- [ ] Endpoint: upload rules image/PDF
- [ ] LLM parses → persist to diet_rules

---

## Cut List (If Time Runs Out)

| Priority | Cut | Keep |
|----------|-----|------|
| 1 | Rules from image (use hardcoded) | Rules from Firestore |
| 2 | Exchange registration | Meals + dashboard |
| 3 | Live API (use TTS fallback) | Image capture + backend |

**Never cut:** Deploy to Cloud Run, image capture, compliance reply, README, **Live API**.

**See [prize-readiness.md](./prize-readiness.md)** for consolidated status vs. the big prize.
