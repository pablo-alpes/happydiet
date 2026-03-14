# HappyDiet — UAT (User Acceptance Testing)

**Objective:** Formalize UAT tests for regression protection. All UAT tests run with `npm test` and are part of CI.

---

## UAT Strategy

| Type | Location | When | Purpose |
|------|----------|------|---------|
| **Vitest UAT** | `backend/tests/uat/` | Every `npm test`, `npm run test:ci` | Regression protection |
| **Live UAT** | `backend/scripts/uat-live.mjs` | `npm run test:uat` | Boots server, full flow |
| **URL UAT** | `scripts/uat-against-url.sh` | Post-deploy | Against deployed backend |

---

## UAT Test Suites

### 1. Full Flow (`uat-full-flow.test.ts`)

Simulates: **image → parse → process → persist → advice → UX**

| # | Scenario | Assertion |
|---|----------|-----------|
| 1 | POST image | Vision returns ingredients |
| 2 | Processing | Rules applied, soda non-compliant |
| 3 | Reporter | Advice message built |
| 4 | Persistence | Meal saved to store |
| 5 | Dashboard | GET /meals returns persisted data |
| 6 | Multi-user | Meals isolated by userId |
| 7 | Response shape | score, message, items for UX |

### 2. Error & Edge (`uat-error-scenarios.test.ts`)

| Scenario | Expected |
|----------|----------|
| Vertex AI not configured | 503 |
| image_base64 missing | 400 |
| image_base64 empty | 400 |
| Default rules (empty diet_rules) | 100% compliant |
| Vision throws | 500 |
| GET /meals no data | 200, empty array |

### 3. API Contract (`uat-api-contract.test.ts`)

Ensures response shape for iOS app and Live API:

| Endpoint | Required fields |
|----------|-----------------|
| POST /analyze-meal | score, compliantItems, nonCompliantItems, suggestions, message, ingredients |
| GET /meals | meals[] with id, userId, ingredients, complianceScore, compliantItems, nonCompliantItems, suggestions |

---

## Centralized Test Commands

**Single command to run all tests (including UAT):**

```bash
cd backend
npm test
```

| Command | Runs | When |
|---------|------|------|
| `npm test` | Unit + Integration + E2E + **UAT** | Local dev |
| `npm run test:ci` | Same + JUnit output | CI (Cloud Build, Dockerfile) |
| `npm run test:ci:full` | npm ci + test:ci + build | Pre-deploy |
| `npm run test:uat` | Live UAT (server boot) | Optional manual |

---

## Regression Protection

1. **All tests run on every `npm test`** — No separate UAT command; UAT is part of the suite.
2. **CI gate** — Cloud Build and Dockerfile run `test:ci` before deploy. Fail = no deploy.
3. **Coverage** — 100% for domain/application; thresholds enforced.
4. **Pre-commit** — Run `npm test` before pushing. See design.md.

---

## Adding UAT Tests

1. Add to `backend/tests/uat/`
2. Use helpers from `uat-helpers.ts` (in-memory stores, mocks)
3. Follow naming: `uat-<scenario>.test.ts`
4. Run `npm test` — new tests run automatically.
