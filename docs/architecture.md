# HappyDiet — Architecture

**Source:** [stack-architecture.md](./stack-architecture.md), [design.md](./design.md), [agents.md](./agents.md), [features.md](./features.md).

**Storage:** 2 collections — `meals` (happydiet), `diet_rules` (rules). See [persistence.md](./persistence.md).

**Current state:** See [stack-architecture.md § Where We Stand](./stack-architecture.md#where-we-stand-current-state).

---

## Tech Stack

| Layer | Technology |
|-------|-------------|
| Client | Web (index.html, app.html, dev.html), iOS (Swift/SwiftUI) |
| Backend | Node.js/Express on Cloud Run |
| Vision | Vertex AI Gemini 2.5 Flash |
| TTS | Google Cloud Text-to-Speech |
| Database | Firestore (meals, diet_rules) |

---

## Client Matrix

| Client | Live API | HTTP REST | Capture |
|--------|----------|-----------|---------|
| Web Showcase (`/`) | ✅ WebSocket `/live` | — | Camera, upload |
| Web App (`/app.html`) | — | ✅ | Camera, upload |
| Dev Playground (`/dev.html`) | — | ✅ | Camera, upload |
| iOS App | ✅ Live Coach | ✅ | Camera, Photo Library, **HeyCyan** (native only) |

**HeyCyan:** Requires native iOS (BLE + WiFi). Web cannot use HeyCyan. See [heycyan-integration.md](./heycyan-integration.md).

---

## Data Flow

**HTTP:** Client → `POST /analyze-meal`, `POST /parse-diet`, `GET /meals`, `GET /rules` → Backend → Vision → Rule Engine → Firestore → JSON. Optional `POST /speak` for TTS.

**Live API:** Client (Web or iOS) → `ws://backend/live` (proxy translates formats: `audio` → `media_chunks`, camelCase → snake_case) → Vertex AI Live API → tool `analyze_meal` → Backend → JSON → Live API speaks (barge-in supported). See [stack-architecture.md § Proxy Format Translation](./stack-architecture.md#proxy-format-translation).

**Agent pipeline:** Both entry points invoke `analyzeMeal()` → `readerAgent()` → `processorAgent()` → `reporterAgent()`. See [agents.md](./agents.md) for implementation (files, orchestration, entry points).

---

## Architecture Style

- **Monolith (MVP):** Single backend on Cloud Run.
- **No MCP** for MVP — direct REST calls.
- **Docker:** Services run modularly via `docker-compose`.

---

## CI/CD

| Trigger | Environment | Service |
|---------|-------------|---------|
| Push to `main` | prod | happydiet-backend |
| Push to `dev` | dev | happydiet-backend-dev |
| PR to main/dev | — | Tests only |
| Manual | prod or dev | `./scripts/trigger-deploy.sh [prod\|dev]` |

Tests run before every deploy; smoke test runs after. See [deployment-cicd.md](./deployment-cicd.md).

---

## Component Responsibilities

| Component | Responsibility |
|-----------|----------------|
| iOS App | Live Coach (Live API), Analyze, Diet, Dashboard; TTS; HeyCyan capture (native only); background modes: Bluetooth (BLE central/peripheral), audio, fetch, processing, location, nearby-interaction, external-accessory |
| Web Showcase | index.html — Live API (voice + image), chat, Speak |
| Web App | app.html — same look/feel as iOS: Analyze, Diet, Dashboard |
| Dev Playground | dev.html — full flow testing: diet parse, meal analyze, TTS, rules, meals |
| Backend | Vision, parse-diet, rule matching, TTS, Firestore |
| Firestore | `meals`, `diet_rules` collections |
