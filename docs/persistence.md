# HappyDiet — Persistence

**Objective:** Ensure correct, durable persistence across storage layers.

---

## Storage Layout

### Collection: `meals` (happydiet)

| Field | Type | Description |
|-------|------|-------------|
| id | string | Auto |
| userId | string | Single user (MVP) |
| timestamp | Date | Meal time |
| mealMoment | string | breakfast, lunch, dinner, snack |
| ingredients | string[] | From Vision |
| estimatedKcal | number? | From Vision |
| complianceScore | number | 0–100 |
| compliantItems | string[] | |
| nonCompliantItems | string[] | |
| suggestions | string[] | |
| dietVersion | string? | Rules version used |

**Written by:** Agent 1 (Reader) for raw; Agent 2 (Processor) for compliance fields.

### Collection: `diet_rules` (rules)

| Field | Type | Description |
|-------|------|-------------|
| id | string | Auto |
| userId | string | |
| version | number | |
| name | string | |
| rules | DietRule[] | allowances, restrictions, limits |
| source | string? | "image" \| "pdf" \| "manual" |
| createdAt | Date | |

**Written by:** Agent 1 (Reader) when parsing rules from image/PDF.

### Collection: `exchanges` (optional)

| Field | Type | Description |
|-------|------|-------------|
| id | string | Auto |
| userId | string | |
| timestamp | Date | |
| type | string | "meal_analysis" \| "compliance_reply" |
| payload | object | Exchange content |

**Written by:** Agent 3 (Reporter) when registering user–agent interactions.

---

## Persistence Requirements

1. **Durability:** All writes must be acknowledged before returning success.
2. **Retries:** On Firestore write failure, retry (exponential backoff); log and surface error to user if persistent.
3. **Idempotency:** Same image + user → same result; avoid duplicate meals for same timestamp window.
4. **Audit:** Log write operations (request_id, collection, doc_id) for debugging.

---

## Current Gaps

- [ ] Retry logic on Firestore write fail
- [ ] Exchange registration (user–agent log)
- [ ] Idempotency check for meal saves
- [ ] Structured logging for persistence ops
