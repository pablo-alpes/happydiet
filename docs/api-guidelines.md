# HappyDiet — API Guidelines

**Source:** [design.md](./design.md), [stack-architecture.md](./stack-architecture.md).

---

## Tool Contract: `analyze_meal`

**Input:**
```json
{
  "image_base64": "string",
  "user_id": "string"
}
```

**Output:**
```json
{
  "score": 0-100,
  "compliantItems": ["string"],
  "nonCompliantItems": ["string"],
  "suggestions": ["string"],
  "detalle": "string"
}
```

---

## HTTP Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/health` | — | Health check |
| POST | `/analyze-meal` | X-API-Key (optional) | Analyze meal image |
| GET | `/meals?user_id=` | X-API-Key (optional) | List meals |

---

## Testing Requirements

### Mandatory

- **Tests must always pass** before merge or deploy.
- **Unit tests:** 100% coverage for `domain/` and `application/`.
- **Integration tests:** 100% coverage for use cases (with mocks).
- **E2E tests:** Cover all HTTP endpoints.

### Commands

```bash
npm test        # Run all tests
npm run test:ci # CI mode (JUnit report)
```

### Coverage

- **Unit + integration:** **100% coverage** enforced for `domain/` and `application/` (Vitest thresholds).
- **E2E:** All critical paths covered.
- **Gate:** No deploy if tests fail. No merge if coverage drops below target.

---

## Error Handling

- Return structured JSON errors.
- `400` — missing/invalid input.
- `401` — invalid API key.
- `503` — backend not configured (e.g. missing GOOGLE_CLOUD_PROJECT).
