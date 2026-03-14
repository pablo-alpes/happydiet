# HappyDiet — Stack & Architecture

**Objective:** Define technologies, how they connect, and the current system state. Reference when setting up or understanding the system.

---

## Tech Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Client** | Web (index.html, app.html, dev.html), iOS app (Swift/SwiftUI) | Meal capture, diet rules, compliance, dashboard, TTS, Live API |
| **Web Showcase** | index.html | Live API (voice + image), chat, Speak — demo-ready |
| **Backend** | Node.js/Express | REST API, 3 agents, Vision, TTS |
| **Hosting** | Cloud Run | Backend API |
| **Vision** | Vertex AI Gemini 2.5 Flash | Meal analysis (ingredients, kcal); diet rules parsing (text + image) |
| **TTS** | Google Cloud Text-to-Speech | Natural voice for compliance messages |
| **Database** | Firestore | `meals` (happydiet DB), `diet_rules` (rules DB) |
| **GCP APIs** | Vertex AI, Firestore, Cloud TTS, Cloud Run | Required |

### Versions

| Component | Version |
|-----------|---------|
| **iOS** | 17+ |
| **Swift** | 5.9+ |
| **Node.js** | 20 LTS |
| **Vertex AI model** | gemini-2.5-flash |
| **Firestore** | Native mode, separate DBs for meals and rules |

---

## Where We Stand (Current State)

### Implemented ✅

| Area | Features |
|------|----------|
| **Backend** | Vision, 3 agents, Firestore (meals + rules), parse-diet (text + image), TTS, GET /rules, fuzzy + LLM semantic matching, **Live API proxy** (`/live`) |
| **iOS App** | Analyze tab (camera/photo → compliance), Diet tab (parse/save rules, load saved), Dashboard, **Live Coach** (text + image → Live API → audio), backend TTS with AV fallback |
| **Dev Playground** | Diet input (text + image), parse/save, meal upload, analyze, TTS, Rules tab (full diet view), Dashboard |
| **Deployment** | setup-production.sh, deploy.sh, Cloud Run config |

### Pending ⚠️

| Area | Item |
|------|------|
| **Deployment** | First production deploy; Cloud Run env vars |
| **Submission** | Demo video (<4 min), public repo URL |

### Architecture Decision: Multi-Client

- **Web Showcase** (`/`): Live API, voice + image, chat — demo-ready without phone.
- **Web App** (`/app.html`), **Dev Playground** (`/dev.html`): HTTP REST, camera/upload, full flow.
- **iOS App:** Native UX, camera, HeyCyan (BLE+WiFi), Live Coach. **HeyCyan requires native iOS** — web cannot access BLE on iOS Safari.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  CLIENTS                                                                     │
│  • Web: index.html (Live API) | app.html | dev.html                          │
│  • iOS App: Live Coach | Analyze | Diet | Dashboard | HeyCyan (native only) │
└──────────────────────────────┬──────────────────────────────────────────────┘
                               │ HTTPS (REST) + WebSocket (/live)
                               ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  HappyDiet Backend (Cloud Run / localhost:8080)                              │
│  POST /analyze-meal  POST /parse-diet  POST /speak  GET /meals  GET /rules  │
│  ws://host/live (Live API proxy) → Vertex AI Live API                       │
│  Agent 1 (Reader) → Agent 2 (Processor) → Agent 3 (Reporter)               │
└──────────────────────────────┬──────────────────────────────────────────────┘
                               │
          ┌────────────────────┼────────────────────┐
          ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  Vertex AI      │  │  Cloud TTS       │  │  Firestore       │
│  • Vision       │  │  • /speak → MP3  │  │  • meals         │
│  • Parse diet   │  │                  │  │  • diet_rules    │
│  • Semantic     │  │                  │  │                  │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

---

## Data Flow

### Meal Analysis

1. User captures meal image (iOS or playground).
2. Client → `POST /analyze-meal` (image_base64, user_id, optional diet_text).
3. **Reader:** Vertex AI Vision → ingredients, estimatedKcal.
4. **Processor:** Load rules (Firestore or diet_text override); rule-engine (fuzzy match) + optional LLM semantic check → compliance; save meal to Firestore.
5. **Reporter:** Build message (text for TTS or Live API).
6. Response → client; client may call `POST /speak` for TTS.

**Implementation:** See [agents.md](./agents.md) for how Reader, Processor, Reporter are defined and run.

### Diet Rules

1. User enters text or uploads image (iOS Diet tab or playground).
2. Client → `POST /parse-diet` (diet_text or image_base64, save).
3. Vertex AI parses → structured rules (forbidden, allowed, limit, note).
4. If save: persist to Firestore `diet_rules`.
5. Client can fetch via `GET /rules?user_id=`.

### Storage

| Database | Collection | Purpose |
|----------|------------|---------|
| `happydiet` (or default) | `meals` | Meal records, compliance, ingredients |
| `rules` (or default) | `diet_rules` | Parsed diet rules per user |

---

## Component Responsibilities

| Component | Responsibility |
|-----------|----------------|
| **Web Showcase** | index.html — Live API (voice + image), chat, Speak; demo without phone |
| **Web App / Dev Playground** | app.html, dev.html — camera/upload, diet parse, meal analyze, TTS, rules, meals |
| **iOS App** | Image capture (camera, Photo Library, HeyCyan), diet rules, compliance, dashboard, Live Coach, TTS; background modes: Bluetooth (BLE), audio, fetch, processing, location, nearby-interaction, external-accessory |
| **Backend** | REST API; Reader, Processor, Reporter; Vision, parse-diet, TTS, Firestore |
| **Firestore** | `meals`, `diet_rules` |
| **Vertex AI** | Vision (meal → ingredients), parse diet (text/image → rules), semantic compliance check |
| **Cloud TTS** | Text → MP3 for Speak button |

---

## Live API Flow (Implemented)

```
User → iOS Live Coach or Web Showcase → ws://backend/live (proxy) → Vertex AI Live API → tool analyze_meal → Backend → JSON → Live API speaks
```

Live API: voice I/O, barge-in, tool orchestration; backend proxy handles GCP auth and tool execution.

### Proxy Format Translation

Clients (Web and iOS) send messages in camelCase. Vertex AI Live API expects snake_case. The proxy (`live-api-proxy.ts`) translates:

| Client sends | Proxy forwards to Vertex |
|--------------|--------------------------|
| `realtimeInput.audio` | `realtime_input.media_chunks` — Vertex expects `media_chunks[]` for audio; clients send `audio: { data, mimeType }` |
| `realtimeInput.audioStreamEnd` | `realtime_input.audio_stream_end` |
| `realtimeInput.mediaChunks` | `realtime_input.media_chunks` (images/video) |
| `clientContent.turns`, `turnComplete` | `client_content.turns`, `turn_complete` (snake_case) |

**Audio format:** 16 kHz PCM, base64. Clients send `audio/pcm;rate=16000`. The proxy maps `audio` → `media_chunks` because Vertex's wire format uses `media_chunks[]` for realtime audio input.

**Debug logging:** The proxy logs `[live-proxy] fwd realtimeInput` and `[live-proxy] fwd clientContent` when forwarding; use backend logs to troubleshoot mic/text issues.
