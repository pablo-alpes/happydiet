# Gemini Live Agent Challenge — Compliance Checklist

**Source:** [Gemini Live Agent Challenge](https://geminiliveagentchallenge.devpost.com) | **Deadline:** March 16, 2026

**Full spec cross-check:** See [google-spec-crosscheck.md](./google-spec-crosscheck.md) for requirements vs implementation mapping and terminology alignment.

---

## Mandatory Requirements

| Requirement | Status | Implementation |
|-------------|--------|-----------------|
| **Use a Gemini model** | ✅ | Vertex AI `gemini-2.0-flash-001` for vision (backend) |
| **GenAI SDK or ADK** | ✅ | `@google-cloud/vertexai` (official Node.js client for Vertex AI / Gemini) |
| **At least one Google Cloud service** | ✅ | Vertex AI, Firestore, Cloud Run |
| **Live Agent category: Gemini Live API** | ⚠️ | Backend is tool-ready; Live API must be invoked from iOS app |
| **Agents hosted on Google Cloud** | ✅ | Backend on Cloud Run; tool endpoints for Live API |

---

## Live Agent Category — Specifics

| Requirement | Status | Notes |
|-------------|--------|-------|
| Real-time audio/vision interaction | ⚠️ | TTS fallback; Live API WebSocket not yet in iOS |
| User can talk naturally, can be interrupted (barge-in) | ⚠️ | Requires Live API |
| Must use Gemini Live API or ADK | ⚠️ | Backend is tool-ready; iOS app must connect to Live API |

**Target flow:** iOS → Gemini Live API (WebSocket) → tool call `analyze_meal` → Backend → JSON → Live API speaks to user.

---

## What to Submit

| Item | Status | Location |
|------|--------|----------|
| **Public code repository URL** | — | Required for judging |
| **README with spin-up instructions** | ✅ | [README.md](../README.md) |
| **Architecture diagram** | ✅ | [architecture-diagram.md](./architecture-diagram.md) |
| **Demo video (<4 min)** | — | Real-time demo, no mockups; problem + solution |

---

## Judging Criteria (30% / 30% / 40%)

| Criterion | Alignment |
|-----------|-----------|
| **Demo & Presentation (30%)** | Video must show actual software; architecture diagram; Cloud deployment proof |
| **Technical Implementation (30%)** | GenAI SDK ✓, backend on Google Cloud ✓, agent logic (Reader/Processor/Reporter) ✓, error handling ✓ |
| **Innovation & Multimodal UX (40%)** | Beyond text box: vision + voice; "See, Hear, Speak"; Live & context-aware |

---

## Bonus Points

| Item | Status |
|------|--------|
| **Automated Cloud deployment** | ✅ `cloudbuild.yaml` + `scripts/deploy.sh` — tests before deploy |
| **GDG membership** | Optional |
| **Content (blog, podcast)** | Optional |

---

## GCP Services Used

| Service | Purpose |
|---------|---------|
| **Vertex AI** | Gemini model for meal image → ingredients, kcal |
| **Firestore** | `meals`, `diet_rules` collections |
| **Cloud Run** | Backend hosting |

---

## Compliance Gaps to Address

1. **Live API integration in iOS** — For full Live Agent compliance, the iOS app should connect to Gemini Live API (WebSocket) and use the backend as a tool. Current flow: direct HTTP to backend + TTS fallback.
2. **Architecture diagram** — Add a clear visual diagram (e.g. Mermaid or image) to the repo for judges.
3. **Demo video** — Record real-time demo showing the app working end-to-end.

---

## Quick Reference

- **Backend tool contract:** `POST /analyze-meal` with `image_base64`, `user_id` → JSON compliance
- **Deploy:** `gcloud builds submit --config cloudbuild.yaml backend`
- **APIs to enable:** `aiplatform.googleapis.com`, `firestore.googleapis.com`, `run.googleapis.com`, `cloudbuild.googleapis.com`, `artifactregistry.googleapis.com`
