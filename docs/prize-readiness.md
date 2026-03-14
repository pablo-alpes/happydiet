# HappyDiet — Prize Readiness (Gemini Live Agent Challenge)

**Objective:** Single source of truth for where we stand vs. the big prize. **Deadline: March 16, 2026.**

---

## 1. What's Already in Place ✅

| Area | Status | Details |
|------|--------|---------|
| **Backend** | ✅ | Vision, 3 agents (Reader/Processor/Reporter), Firestore, TTS, parse-diet, fuzzy + LLM semantic matching, retries |
| **Live API** | ✅ | WebSocket proxy at `/live`; iOS LiveCoachView + LiveAPIClient connect; tool `analyze_meal` wired |
| **iOS** | ✅ | Analyze, Diet, Dashboard, **Live Coach** (text + image → Live API → audio response) |
| **Tests** | ✅ | 61 tests passing (unit, integration, E2E, UAT) |
| **Docs** | ✅ | README, architecture diagram, setup instructions, spec index |
| **CI/CD** | ✅ | cloudbuild.yaml, deploy.sh, tests before deploy |
| **Mandatory requirements** | ✅ | Gemini model, GenAI SDK, GCP hosting, ≥1 GCP service |

---

## 2. Gaps to Close for the Prize

| Priority | Gap | Requirement | Action |
|----------|-----|-------------|--------|
| **1** | **Production deploy** | Backend on Cloud Run | Run `./scripts/setup-production.sh` + `./scripts/deploy.sh` |
| **2** | **Demo video** | <4 min, real-time, no mockups | Record: Problem → Solution → Live demo; include architecture diagram + Cloud Run proof |
| **3** | **Public repo** | URL for judging | Publish to GitHub (or similar); add URL to submission |
| **4** | **Verify Live API E2E** | Live Coach → /live → tool → backend | Test: Connect → send image → agent speaks compliance |

---

## 3. Judging Criteria — Our Position

| Criterion | Weight | Our Position | Notes |
|-----------|--------|--------------|-------|
| **Demo & Presentation** | 30% | ⚠️ Blocked | Need video + Cloud Run proof |
| **Technical Implementation** | 30% | ✅ Strong | GenAI SDK, GCP, 3-agent pipeline, error handling |
| **Innovation & Multimodal UX** | 40% | ✅ Strong | Vision + voice, Live API, barge-in, See/Hear/Speak |

**Summary:** Technical and Innovation are solid. Demo & Presentation is the main blocker.

---

## 4. Suggested Priority Order (3 Days Left)

1. **Deploy to Cloud Run** — Required; never cut.
2. **Record demo video** — Required for submission.
3. **Publish repo** — Required for judging.
4. **Verify Live API flow** — Ensure Live Coach → proxy → tool → backend works end-to-end.

---

## 5. Cut List (If Time Is Tight)

From tasks.md:

| Cut | Keep |
|-----|------|
| Rules from image (use hardcoded) | Rules from Firestore |
| Exchange registration | Meals + dashboard |
| ~~Live API (use TTS fallback)~~ | **Keep Live API** — we have it; it's a differentiator |

**Never cut:** Deploy to Cloud Run, image capture, compliance reply, README, **Live API**.

---

## 6. Demo Video Script (Suggested)

| Section | Duration | Content |
|---------|----------|---------|
| **Problem** | ~45 s | Diet compliance is hard; users forget rules; no real-time feedback at meal time |
| **Solution** | ~45 s | HappyDiet: capture meal → AI analyzes → compliance + voice; Live Coach for conversation |
| **Architecture** | ~30 s | Show diagram: iOS → Live API → Backend (Reader/Processor/Reporter) → Vertex AI, Firestore |
| **Live demo** | ~90 s | 1) Analyze tab: photo → compliance + TTS. 2) Live Coach: connect → send image → agent speaks. 3) Cloud Run console proof |
| **Total** | <4 min | |

---

## 7. Quick Commands

```bash
# Deploy
cd backend && ./scripts/setup-production.sh YOUR_PROJECT_ID
./scripts/deploy.sh

# Verify
curl https://YOUR-CLOUD-RUN-URL/health
# Test /analyze-meal with base64 image
```

---

## 8. References

- [google-spec-crosscheck.md](./google-spec-crosscheck.md) — Requirements vs implementation
- [tasks.md](./tasks.md) — Phased plan
- [deployment-cicd.md](./deployment-cicd.md) — Deploy steps
- [architecture-diagram.md](./architecture-diagram.md) — For video
