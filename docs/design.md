# HappyDiet — System Design & Best Practices

**Objective:** Define how we build: architecture style, development practices (TDD, DDD), and AI/Google Cloud best practices. Read before coding.

---

## Architecture Style

### Monolith (MVP)
- Single codebase and deployment for now
- Backend: one service on Cloud Run (API + Vision + rules + Firestore)
- No microservices; keeps 3–4 day timeline manageable
- Split later if scale or team demands it

### MCP (Model Context Protocol)
- **Uncertain** whether we'll adopt MCP for tool/data integration
- MCP connects AI models to external tools and data sources
- If we add more tools or external systems later, MCP could be an option
- For MVP: direct tool calls from Live API to backend suffice

---

## Awareness

### Context Awareness (MVP)
- Per-meal context: ingredients, rules, user's diet
- Agent describes what it sees before judging

### Trend Awareness (Phase 2)
- Agent references history: "You've been on plan 5 of 7 days"
- Patterns: "I notice dinners are trickier"
- Gentle reminders based on deviations
- Requires querying Firestore for user's meal history when generating reply

---

## Development Practices

### TDD Throughout the SDLC — All Layers, No Exceptions

TDD is **mandatory** for backend and frontend/iOS. No layer is exempt.

| Phase | TDD Practice |
|-------|--------------|
| **Requirements** | Acceptance criteria written as test scenarios (Given/When/Then). User flows → E2E test cases. |
| **Design** | Define test contracts first: API input/output schemas, tool response format. Tests document expected behavior. |
| **Implementation** | Red → Green → Refactor. Write failing test, implement to pass, refactor. **Backend + iOS.** |
| **Integration** | Integration tests for API; E2E for critical paths (meal → analysis → reply). Mock external services. |
| **Deployment** | Test suite must pass before deploy. CI gate (if automated). No deploy on red. |
| **Maintenance** | Add test when fixing a bug (regression). Refactor with tests as safety net. |

**Backend (all layers):** Domain → unit tests. Application → unit tests. Infrastructure → integration tests. API → integration tests. Mocks for Vertex AI/Firestore.  
**iOS (all layers):** Live API client → unit tests (mock WebSocket). Dashboard → unit tests (data mapping). ViewModels → unit tests. UI → UI tests for critical flows.  
**E2E:** Full flow (optional for MVP): app → backend → Firestore.

### Testing GCP / Google Cloud Interactions

Les interactions avec le backend Google Cloud (Vertex AI, Firestore, Cloud Run) doivent être testées pour garantir un fonctionnement fluide.

| Couche GCP | Type de test | Objectif |
|------------|--------------|-----------|
| **Vertex AI** | Integration (mock ou contract) | Vérifier que le client appelle correctement l’API, gère les erreurs et parse la réponse |
| **Firestore** | Integration (emulator ou mock) | Vérifier read/write, schéma, gestion des erreurs |
| **Cloud Run** | Smoke / health | Vérifier que le service répond (`/health`), que les env vars sont correctes |
| **CI/CD** | Pipeline Cloud Build | Tests passent avant deploy ; pas de deploy si red |

**Stratégie :**
- **Unit / fast :** Mock Vertex AI et Firestore (réponses fictives).
- **Integration (optionnel) :** Firestore Emulator pour tests locaux sans coût.
- **Pre-deploy :** `npm test` / `npm run test:ci` obligatoire ; CI exécute la suite avant `gcloud run deploy`.
- **Post-deploy :** Smoke test sur l’URL Cloud Run (`curl /health`, `curl /analyze-meal` avec image de test).

### Test Reporting & CI Best Practices

| Pratique | Implémentation |
|----------|----------------|
| **Unit tests** | `tests/unit/` — rule engine, domain logic. Vitest. |
| **Integration tests** | `tests/integration/` — use cases avec mocks. Vitest. |
| **E2E tests** | `tests/e2e/` — HTTP API (supertest). Vitest. |
| **JUnit report** | `npm run test:ci` → `test-results/junit.xml` (CI only) |
| **Docker** | `Dockerfile` exécute `npm run test:ci` avant build ; build échoue si tests fail. |
| **Cloud Build** | Step `test:ci` avant deploy ; `waitFor: ['test']` sur deploy. |
| **Après chaque feature** | Exécuter `npm test` ; ne pas merger si red. |
| **Coverage** | 100% pour unit + integration (`domain/`, `application/`). Voir api-guidelines.md. |

**Commandes :**
```bash
npm test        # Local (pas de rapport fichier)
npm run test:ci # CI (JUnit + JSON dans test-results/)
```

### Domain-Driven Design (DDD)
- **Domain:** Nutrition compliance — Meal, DietRules, ComplianceResult
- **Aggregates:** MealRecord (meal + compliance + metadata)
- **Value objects:** Ingredients, MealMoment, ComplianceScore
- **Services:** RuleEngine, VisionAnalyzer, MealService
- **Repositories:** MealRepository, DietRulesRepository (Firestore adapters)
- Keep domain logic independent of GCP/LLM; adapters at the edge

### Clean Architecture
- **Domain layer:** Entities, rules, business logic (no framework deps)
- **Application layer:** Use cases, orchestration (calls domain + adapters)
- **Infrastructure:** Vertex AI client, Firestore client, HTTP handlers
- Dependencies point inward: infrastructure → application → domain

### Project Structure (Backend)

```
backend/
├── domain/           # Entities, value objects, rule logic
│   ├── meal.ts
│   ├── diet-rules.ts
│   └── rule-engine.ts
├── application/     # Use cases, orchestration
│   └── analyze-meal.ts
├── infrastructure/  # Adapters (Vertex AI, Firestore, HTTP)
│   ├── vertex-ai-client.ts
│   ├── firestore-repository.ts
│   └── http-handlers.ts
├── tests/
│   ├── unit/        # Rule engine, scoring
│   ├── integration/ # Use cases (mocked)
│   └── e2e/         # HTTP API (supertest)
├── app.ts           # App factory (for E2E)
└── main.ts
```

### Project Structure (iOS)

```
ios/
├── HappyDiet/
│   ├── App/
│   ├── Features/
│   │   ├── LiveCoach/     # Live API client, voice, camera
│   │   └── Dashboard/     # Meal history, scores
│   ├── Core/              # Shared models, services
│   └── ...
├── HappyDietTests/        # Unit tests — all layers
│   ├── LiveCoachTests/
│   ├── DashboardTests/
│   └── ...
└── HappyDietUITests/      # UI tests
```

---

## AI & Google Cloud Best Practices

### LLM / Vision
- **Structured output:** Request JSON schema from Vision (ingredients, kcal)
- **Prompt versioning:** Version prompts; log which version produced each result
- **Retries:** Exponential backoff for Vertex AI calls; handle rate limits
- **Fallbacks:** If Vision fails, return clear error; allow user to describe meal
- **Grounding:** Rule engine provides deterministic logic; LLM for interpretation only where needed

### Tool / Function Design (Live API)
- **Single responsibility:** `analyze_meal` does one thing
- **Idempotency:** Same image + user → same result (cache or accept duplicate)
- **Clear contract:** Input (image_base64, user_id), Output (score, items, suggestions)
- **Error handling:** Return structured error for agent to relay to user

### Docker (modular)

- **Backend:** `Dockerfile` dans `backend/` ; `docker-compose.yml` pour lancer les services en local.
- **Dev:** `docker-compose.dev.yml` pour hot reload (tsx watch).
- **Production:** `docker build` ; `gcloud run deploy --image` pour Cloud Run.

### Google Cloud
- **Secrets:** Local dev → `.env` (do not commit). Cloud Run → Secret Manager or env vars. Never commit API keys.
- **Environment:** Separate config for dev/staging/prod
- **Logging:** Structured logs (JSON); include request_id, user_id
- **Health checks:** `/health` endpoint for Cloud Run
- **Timeouts:** Set appropriate timeouts for Vision and Firestore calls
- **CI/CD:** Tests obligatoires avant deploy. Voir setup.md Annexe C.

---

## Agent Architecture (Live Agent + Tool Pipeline)

See **[agents.md](./agents.md)** and **[google-spec-crosscheck.md](./google-spec-crosscheck.md)** for full detail.

**Live Agent** = Gemini Live API (users talk to it; barge-in). **Tool** = our backend. **Pipeline** = 3 stages:

| Stage | Role | Persistence |
|-------|------|-------------|
| **Reader** | Image → Vision → text; persist to storage | `meals` (raw), `diet_rules` (from rules image/PDF) |
| **Processor** | Rule matching; compute compliance; persist analysis | `meals` (compliance fields) |
| **Reporter** | Dashboard data; compliance message; audio; user interaction | Reads `meals`; may write `exchanges` |

**Separation of concerns:** Each stage has distinct input, process, output, and persistence. No overlap.

## Storage Separation (2 Collections)

| Collection | Purpose |
|------------|---------|
| **meals** (happydiet) | Meals, time, ingredients, compliance — single user |
| **diet_rules** (rules) | Parsed from image/PDF; allowances, restrictions |

See **[persistence.md](./persistence.md)** for schema and requirements.

## Data Model

### Meal Record (Firestore `meals`)
```
id, userId, timestamp, mealMoment, ingredients[], estimatedKcal,
complianceScore, compliantItems[], nonCompliantItems[], suggestions[], dietVersion
```

### Diet Rules (Firestore `diet_rules`)
```
id, userId, version, name, rules[], kcalTarget?, createdAt, source?
```

### Rules Schema (allowances & restrictions)
- **forbidden/restrictions:** items[], reason
- **allowed/allowances:** items[], maxPortion?
- **limit:** items[], maxPerDay, unit

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Image unclear | Ask user to retake; suggest lighting/angle |
| Vision failure | "Could not analyze. Please describe the meal." |
| No rules | Use hardcoded fallback or prompt user |
| Tool call timeout | Retry once; then return error to agent |
| Firestore write fail | Log; return partial result; retry async if possible |

---

## Security

- **API auth:** API key or shared secret for tool calls from Live agent
- **User data:** MVP: demo userId; Post-MVP: session or phone-scoped
- **Images:** MVP: process in memory; Post-MVP: GCS with short-lived URLs

### iOS Practices
- **TDD (no exceptions):** Every layer has tests. Live API client, dashboard mapping, ViewModels → XCTest. UI → UI tests for critical flows. Mock backend for all tests.
- **Structure:** MVVM or similar; separate Live API client from UI
