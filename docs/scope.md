# HappyDiet — Scope

**Objective:** Define what we're building, why, what's in and out of scope, and what we assume or risk. Read first to align on goals and constraints.

**Timeline:** 3–4 days | **Deadline:** March 16, 2026

---

## Objectives

### Business
- Assist users to collect diet data with minimal friction (photo + voice)
- Track compliance against a diet plan with per-meal scoring
- Surface insights via **dashboard** in the app: meal history, compliance scores, trends

### Hackathon (Live Agents)
- Use Gemini Live API (voice + vision, barge-in)
- Host on Google Cloud (Cloud Run, Firestore, Vertex AI)
- Multimodal: beyond text-in/text-out

---

## User Flow

What the user sees and does, step by step:

1. **Open app** — User opens HappyDiet iOS app on iPhone
2. **Start session** — Taps mic, optionally speaks ("I'm about to eat this")
3. **Show meal** — Uses camera or photo library
4. **Wait** — Sees "analyzing…" or similar; hears/sees that processing is in progress
5. **Hear reply** — Agent speaks: describes what it sees, judges (fair/exception/off), informs
6. **Interrupt** — User can speak over the agent at any time (barge-in)
7. **Follow-up** — User can ask questions; conversation continues
8. **View dashboard** — User can switch to dashboard tab/screen to see meal history, compliance scores, and trends

### Optional: Smart Lenses (Future)

1. **Pair device** — User pairs Bluetooth lenses with phone
2. **Capture** — User captures meal via lenses (hands-free)
3. **Speak** — User speaks to coach via lenses mic
4. **Hear reply** — Coach voice plays through lenses (in-ear)
5. **Interrupt** — User can speak over coach (barge-in)

---

## Scope (3–4 Days)

### In Scope
| Feature | Notes |
|---------|-------|
| **iOS app** | Image capture, transfer to backend, receive reply (compliance + audio), dashboard |
| **Dashboard (in app)** | Meal history, compliance scores per meal, trends |
| **Storage: happydiet** | Meals, time, ingredients, full data model (single user) |
| **Storage: rules** | Parsed rules from image/PDF; allowances & restrictions |
| **Rule parsing** | LLM parses image/PDF → structured allowances & restrictions |
| **Rule engine** | Match ingredients vs rules → compliance |
| **Vision** | Vertex AI: image → ingredients, kcal |
| **3 agents** | Reader (image→text, persist); Processor (match, persist); Reporter (dashboard, compliance, audio) |
| **Persistence** | Correct, durable writes; retries; exchange registration |
| **Voice reply** | Compliance message → audio via Live API |

### Out of Scope (MVP)
| Feature | Notes |
|---------|-------|
| WhatsApp / OpenClaw | Post-MVP |
| Trend interaction | Phase 2 |
| Multi-user, doctor view | Post-MVP |

### Optional (Future)
| Feature | Notes |
|---------|-------|
| **Smart lenses (Bluetooth)** | Connect simple lenses via Bluetooth to capture meal photo and hear coach reply. Hands-free: user wears lenses, captures image, receives voice feedback in-ear. Requires Bluetooth SDK, device pairing, and audio routing to lenses. |

| # | Assumption |
|---|------------|
| 1 | User has iPhone with HappyDiet app; mic and camera access |
| 2 | Diet rules: parsed from image (working) or hardcoded |
| 3 | Single user / demo userId for MVP |
| 4 | Vision detection good enough for ingredient matching |
| 5 | Kcal estimation is approximate; not medical-grade |
| 6 | Data model aligns with v1 (`Date;Meal;Items;Compliance;Detalle;Peso;Kcal`) |

---

## Risks

| Risk | Mitigation |
|------|------------|
| Live API complexity | Validate Day 1 with official examples; start voice-only, add image |
| 3–4 days too short | Cut list: diet rules → hardcoded; Firestore → return only; camera → upload |
| Vision misidentifies food | Improve prompts; accept approximate for demo |
| GCP costs | Billing alerts; free tier where possible |
