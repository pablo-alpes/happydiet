# HappyDiet — Testing

**Objective:** Test strategy, coverage, CI/CD integration, and regression protection.

---

## Centralized Test Command

**All tests (unit, integration, E2E, UAT) run with:**

```bash
cd backend
npm test
```

This is the **single source of truth**. No separate UAT command for regression — UAT tests are part of the suite.

---

## Regression Protection

| Gate | Command | When |
|------|---------|------|
| **Local** | `npm test` | Before commit/push |
| **CI** | `npm run test:ci` | Cloud Build, Dockerfile |
| **Pre-deploy** | `npm run test:ci:full` | npm ci + test + build |

**If tests fail:** No deploy. Cloud Build `waitFor: ['test']` blocks deploy step.

---

## Test Pyramid

| Layer | Location | Purpose |
|-------|----------|---------|
| **Unit** | `tests/unit/` | Domain logic, agents |
| **Integration** | `tests/integration/` | Use cases with mocked deps |
| **E2E** | `tests/e2e/` | HTTP API (health, analyze-meal, meals) |
| **UAT** | `tests/uat/` | Full flow, error scenarios, API contract |
| **Smoke** | `scripts/smoke-test.sh` | Post-deploy (production URL) |

---

## Test Inventory

### Unit (18 tests)

| File | Tests |
|------|-------|
| `rule-engine.test.ts` | 4 |
| `agent-reader.test.ts` | 3 |
| `agent-processor.test.ts` | 3 |
| `agent-reporter.test.ts` | 8 |

### Integration (4 tests)

| File | Tests |
|------|-------|
| `analyze-meal.test.ts` | 4 |

### E2E (12 tests)

| File | Tests |
|------|-------|
| `api.test.ts` | 12 |

### UAT (16 tests)

| File | Tests |
|------|-------|
| `uat-full-flow.test.ts` | 7 — Full flow: parse → process → persist → advice → UX |
| `uat-error-scenarios.test.ts` | 6 — 503, 400, 500, empty rules, Vision throw |
| `uat-api-contract.test.ts` | 3 — Response shape for iOS/Live API |

**Total: 50 tests**

---

## UAT Documentation

See **[uat.md](./uat.md)** for:
- UAT strategy and suites
- Full flow, error, and API contract scenarios
- How to add UAT tests

---

## Running Tests

```bash
cd backend

# All tests (local)
npm test

# CI (JUnit, coverage)
npm run test:ci

# Full CI simulation
npm run test:ci:full

# Live UAT (optional, boots server)
npm run test:uat
```

---

## Coverage

- **Target:** 100% for `domain/` and `application/`
- **Excluded:** main.ts, type-only files, uat-helpers
- **Report:** `coverage/lcov-report/index.html`

---

## CI/CD Integration

| Step | Runs |
|------|------|
| Cloud Build | `npm ci` → `npm run test:ci` → deploy |
| Dockerfile | `npm run test:ci` → build |
| `scripts/test-ci.sh` | Same as Cloud Build test step |

---

## Adding Tests

1. **Unit:** `tests/unit/`
2. **Integration:** `tests/integration/`
3. **E2E:** `tests/e2e/`
4. **UAT:** `tests/uat/` (use `uat-helpers.ts`)

**TDD:** Write failing test first. See design.md.
