# HappyDiet — Roadmap & Google Challenge Alignment

**Objective:** Ensure all planned features (Coach, diet evolution, doctor reports, glasses + AI) align with [Gemini Live Agent Challenge](https://geminiliveagentchallenge.devpost.com) requirements.

---

## 1. Google Requirements Summary

| Criterion | Weight | Key Points |
|-----------|--------|------------|
| **Demo & Presentation** | 30% | Problem, solution, architecture diagram, Cloud deployment, actual software |
| **Technical Implementation & Agent Architecture** | 30% | GenAI SDK, backend on GCP, agent logic, error handling |
| **Innovation & Multimodal UX** | 40% | Beyond text box; **See, Hear, Speak**; Live & context-aware |

---

## 2. Roadmap Features → Google Alignment

### Reporter → Coach Extension

| Feature | Description | Google Alignment |
|---------|-------------|------------------|
| **Conversational exchange** | Two-way coaching via Live API | ✅ **Live & context-aware** — agent talks naturally |
| **Meal notifications** | Reminders, nudges when no meal logged | ✅ **Innovation** — proactive, multimodal |
| **Score-change alerts** | Notify when compliance drops/improves | ✅ **Context-aware** — uses Firestore history |
| **Trend awareness** | "5 of 7 days on plan", "dinners trickier" | ✅ **Innovation & Multimodal UX** |

**Implementation:** All via Live API + Firestore on GCP. No new services; extends Reporter/Coach logic.

---

### Diet Evolution & Doctor Reports

| Feature | Description | Google Alignment |
|---------|-------------|------------------|
| **Diet evolution** | Track rule changes over time; phased plans | ✅ **Technical** — Firestore `diet_versions`; backend on GCP |
| **Doctor-facing report** | Behaviors, patterns, improvement areas | ✅ **Innovation** — supports user journey |
| **Dashboard insights** | "Where to improve" for user | ✅ **Multimodal UX** — visual + agent |

**Implementation:** New Processor/Analytics stage or Reporter extension. All on Cloud Run + Firestore. Uses Gemini for summarization (e.g., "Summarize this week's patterns for doctor").

---

### HeyCyan Glasses + AI Enhancement

| Aspect | Current | Enhanced (Google-Aligned) |
|--------|---------|---------------------------|
| **Capture** | Photo from glasses → Analyze tab | Same + **Live Coach + Glasses** mode |
| **See** | One-off image | **POV stream** — glasses camera → Live API `realtimeInput` (video) |
| **Hear** | User taps, selects photo | **Voice-first** — "Is this okay?" via glasses mic or phone |
| **Speak** | TTS after analysis | **Live API** — real-time audio response, barge-in |

**Flow (enhanced):**
```
[User wears HeyCyan glasses]
    ↓
[Live Coach + Glasses mode]
    ├─ Stream video frames (or periodic images) → Live API realtimeInput
    ├─ User speaks: "Analyze this meal" → Live API
    └─ Agent sees POV, calls analyze_meal tool → speaks result
```

**Google alignment:**
- **See, Hear, Speak** — Glasses = See (first-person), Voice = Hear, Live API = Speak
- **Innovation & Multimodal UX (40%)** — Wearable, hands-free, voice-first diet coaching
- **Real-time Interaction** — Live API supports video input; glasses provide POV

---

## 3. Implementation Path (Google-Compliant)

| Phase | Scope | Google Services |
|-------|-------|-----------------|
| **Current** | Live Coach (text + image), Analyze, Diet, Dashboard | Vertex AI, Firestore, Cloud Run, Live API |
| **Phase 2a** | Coach: notifications, score alerts, trends | Same + Cloud Scheduler or Cloud Functions for cron |
| **Phase 2b** | Diet evolution, doctor report (dashboard) | Same + new endpoints |
| **Phase 2c** | HeyCyan + Live Coach | Same; glasses → Live API realtimeInput |

---

## 4. HeyCyan Glasses + AI — Technical Notes

### Prerequisites
- HeyCyanService with QCSDK: BLE connect, take photo, WiFi transfer
- Live API proxy at `/live` (already implemented)

### Enhancement Options

| Option | Complexity | Google Alignment |
|--------|------------|------------------|
| **A. Photo capture → Live Coach** | Low | User taps glasses button → image → Live Coach → agent analyzes. ✅ |
| **B. Video stream → Live API** | High | Stream frames via `realtimeInput` (video). Hands-free, real-time. ✅✅ |
| **C. Voice trigger + photo** | Medium | "Hey coach, analyze" → capture photo → send to Live API. ✅ |

**Recommendation:** Start with **Option A** (quick win, uses existing flow). Option B is strongest for Innovation & Multimodal UX but requires video streaming from glasses.

### Data Flow (Option A — Quick Win)
```
HeyCyan glasses → BLE photo → WiFi transfer → UIImage
    ↓
Live Coach tab (or Analyze) → sendImage(base64) → Live API
    ↓
Agent receives image, calls analyze_meal → speaks result
```

### Data Flow (Option B — Full Enhancement)
```
HeyCyan glasses → video stream (if SDK supports) or 1 FPS frames
    ↓
iOS → realtimeInput { media_chunks: [{ mime_type: "image/jpeg", data: base64 }] }
    ↓
Live API sees POV → user says "analyze" → tool call → speaks
```

---

## 5. Checklist: All Features Match Google Requirements

| Requirement | Coach | Diet Evolution | Doctor Report | Glasses + AI |
|-------------|-------|---------------|---------------|--------------|
| Gemini model | ✅ Live API | ✅ Summarization | ✅ Summarization | ✅ Live API |
| GenAI SDK / ADK | ✅ | ✅ | ✅ | ✅ |
| Hosted on GCP | ✅ | ✅ | ✅ | ✅ |
| Live API / real-time | ✅ | — | — | ✅ |
| See, Hear, Speak | ✅ | — | — | ✅✅ (glasses POV) |
| Innovation & Multimodal | ✅ | ✅ | ✅ | ✅✅ |

---

## 6. References

- [google-spec-crosscheck.md](./google-spec-crosscheck.md) — Current compliance
- [heycyan-integration.md](./heycyan-integration.md) — Glasses setup
- [agents.md](./agents.md) — Architecture
