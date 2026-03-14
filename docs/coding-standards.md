# HappyDiet — Coding Standards

**Source:** Extracted from [design.md](./design.md). Refer to design.md for full context.

**Architecture:** 3 agents (Reader, Processor, Reporter). Storage: `meals` + `diet_rules`. See [agents.md](./agents.md), [persistence.md](./persistence.md).

---

## TDD — Mandatory, No Exceptions

- **Backend:** Domain → unit tests. Application → unit tests. Infrastructure → integration tests. API → integration tests.
- **iOS:** Live API client, Dashboard, ViewModels → XCTest. UI → UI tests for critical flows.
- **Red → Green → Refactor:** Write failing test first, implement to pass, refactor.
- **Never merge** if `npm test` fails.

---

## Domain-Driven Design (DDD)

- **Domain:** Entities, value objects, business logic — no framework deps.
- **Application:** Use cases, orchestration.
- **Infrastructure:** Adapters at the edge (Vertex AI, Firestore, HTTP).
- **Dependencies:** Point inward: infrastructure → application → domain.

---

## Project Structure (Backend)

```
backend/
├── domain/           # Entities, rule logic
├── application/     # Use cases
├── infrastructure/  # Adapters
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
└── main.ts
```

---

## Secrets & Security

- **Never commit:** `.env`, API keys, credentials. See [setup.md](./setup.md) Annexe B.
- **Local:** `.env` in project root or `backend/`.
- **Cloud Run:** Secret Manager or `--set-env-vars`.

---

## After Each Feature

1. Run `npm test`.
2. Fix any failures before continuing.
3. Do not merge if tests are red.
