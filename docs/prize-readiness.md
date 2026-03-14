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
| **Architecture** | ~30 s | Show diagram: Client (web or iOS) → Live API → Backend (Reader/Processor/Reporter) → Vertex AI, Firestore |
| **Live demo** | ~90 s | 1) Web: open Cloud Run URL. 2) Live Coach: connect → upload image → agent speaks. 3) Or Analyze tab: upload → compliance + Speak. 4) Cloud Run console proof |
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

## 8. Web-Only Demo Path (No Phone, No iOS)

**You do not need the iOS app or a phone for the demo.** The web interface has everything required:

| Surface | URL | Live API | Features |
|---------|-----|----------|----------|
| **Showcase** | `/` or `index.html` | ✅ WebSocket to `/live` | Chat, voice input, image upload, compliance, Speak |
| **App** | `/app.html` | — | Analyze, Diet, Dashboard (camera/upload, TTS) |
| **Dev Playground** | `/dev.html` | — | Full flow: diet parse, meal analyze, TTS |

**Demo flow (web-only):**
1. Deploy backend to Cloud Run.
2. Open `https://YOUR-SERVICE.run.app/` in a browser.
3. Use the **Live Coach** tab: connect → upload meal image → agent speaks compliance.
4. Or use **Analyze** tab: upload → compliance card → Speak button.
5. Record the screen for the demo video.

**Phone testing (optional):** If you want to show it on a phone, use the same URL in the phone's browser — no Xcode, no install. See [phone-testing.md](./phone-testing.md).

---

## 9. Glasses (HeyCyan) — Optional, Omit If Worried

- **Not required** for the challenge. The challenge does not require or prohibit glasses.
- **Copyright:** Using a camera (or glasses as a camera) to capture photos is standard. The HeyCyan community SDK is open source. No copyright issue for using hardware to capture images.
- **If unsure:** Simply **do not mention or show glasses** in the demo. The app works fully with camera/photo library/upload. Glasses are a future roadmap item.
- **Current status:** HeyCyan integration is a stub; full BLE+WiFi requires the QCSDK framework. It's not part of the core demo path.

---

## 10. References

- [google-spec-crosscheck.md](./google-spec-crosscheck.md) — Requirements vs implementation
- [tasks.md](./tasks.md) — Phased plan
- [deployment-cicd.md](./deployment-cicd.md) — Deploy steps
- [architecture-diagram.md](./architecture-diagram.md) — For video
