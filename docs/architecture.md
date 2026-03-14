# HappyDiet — Architecture

**Source:** [stack-architecture.md](./stack-architecture.md), [design.md](./design.md), [agents.md](./agents.md), [features.md](./features.md).

**Storage:** 2 collections — `meals` (happydiet), `diet_rules` (rules). See [persistence.md](./persistence.md).

**Current state:** See [stack-architecture.md § Where We Stand](./stack-architecture.md#where-we-stand-current-state).

---

## Tech Stack

| Layer | Technology |
|-------|-------------|
| Client | iOS (Swift/SwiftUI), Web App (app.html), Dev Playground (dev.html) |
| Backend | Node.js/Express on Cloud Run |
| Vision | Vertex AI Gemini 2.5 Flash |
| TTS | Google Cloud Text-to-Speech |
| Database | Firestore (meals, diet_rules) |

---

## Data Flow (Current)

1. iOS or Dev Playground → Backend (HTTP REST)
2. `POST /analyze-meal` or `POST /parse-diet` or `POST /speak`
3. Backend: Vision → Rule Engine (fuzzy + LLM semantic) → Firestore
4. Backend returns JSON; client may call `/speak` for TTS
5. Dashboard: `GET /meals`, `GET /rules`

**Target (Live API):** iOS → Gemini Live API (WebSocket) → tool call → Backend → JSON → Live API speaks

---

## Architecture Style

- **Monolith (MVP):** Single backend on Cloud Run.
- **No MCP** for MVP — direct REST calls.
- **Docker:** Services run modularly via `docker-compose`.

---

## Component Responsibilities

| Component | Responsibility |
|-----------|----------------|
| iOS App | Analyze, Diet, Dashboard; TTS; HeyCyan capture (stub) |
| Web App | app.html — same look/feel as iOS: Analyze, Diet, Dashboard |
| Dev Playground | dev.html — full flow testing: diet parse, meal analyze, TTS, rules, meals |
| Backend | Vision, parse-diet, rule matching, TTS, Firestore |
| Firestore | `meals`, `diet_rules` collections |
