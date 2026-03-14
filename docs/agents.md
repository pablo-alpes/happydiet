# HappyDiet — Agent Architecture (Separation of Concerns)

**Objective:** Define the 3 processing stages and their responsibilities. Each stage has a distinct role; persistence is explicit.

---

## Terminology Alignment (Google Challenge)

| Term | Google's Meaning | Our Mapping |
|------|------------------|-------------|
| **Live Agent** | The conversational agent users talk to | **Gemini Live API** — users speak to it; it can be interrupted (barge-in) |
| **Agent logic** (judging) | Sound backend logic, error handling | Our Reader → Processor → Reporter pipeline |
| **Tool** | Backend the agent calls | Our Cloud Run backend (`POST /analyze-meal`) |

**Our Reader, Processor, Reporter** are **processing stages** (tool logic) within the agent's backend. They are not autonomous LLM agents; they implement the `analyze_meal` tool that the Live Agent invokes. See [google-spec-crosscheck.md](./google-spec-crosscheck.md) for full alignment.

---

## Stage 1 — Reader

**Role:** Ingest image, translate to structured text, persist.

| Responsibility | Details |
|----------------|---------|
| **Input** | Image (meal or diet rules doc) from storage or upload |
| **Process** | Vertex AI Vision → structured text (ingredients or rules) |
| **Output** | Structured data (ingredients[], or rules[]) |
| **Persistence** | Save translated result to storage layer |
| **Scope** | Read + translate + persist. No matching, no reporting. |

**Storage:** Writes to `meals` (raw ingredients) or `diet_rules` (parsed rules from image/PDF).

---

## Stage 2 — Processor

**Role:** Pure processing + rule matching + persist analysis.

| Responsibility | Details |
|----------------|---------|
| **Input** | Ingredients (from Reader or direct), rules (from Rules DB) |
| **Process** | Rule matching; compute compliance score, compliant/non-compliant items, suggestions |
| **Output** | `{ score, compliantItems, nonCompliantItems, suggestions, detalle }` |
| **Persistence** | Save analysis result to `meals` (with compliance fields) |
| **Scope** | Process + match + persist. No user interaction, no dashboard. |

**Storage:** Reads from `diet_rules`; writes to `meals` (analysis result).

---

## Stage 3 — Reporter / Compliance

**Role:** Build dashboard data; generate compliance messages; interact with user.

| Responsibility | Details |
|----------------|---------|
| **Input** | Analysis result (from Processor), meal history (from `meals`) |
| **Process** | Build dashboard payload; generate compliance message for user; prepare audio reply |
| **Output** | Dashboard data; compliance message (text); audio (via Live API) |
| **Persistence** | Optionally persist user–agent exchanges |
| **Scope** | Report + compliance + user interaction. No vision, no rule matching. |

**Storage:** Reads from `meals`; may write to `exchanges` (user–agent log).

---

## Data Flow (Live Agent + Tool Pipeline)

```
[User] → Image + Voice
    ↓
[Live Agent: Gemini Live API] ←→ User (speak, interrupt)
    ↓ tool call: analyze_meal
[Backend Tool]
    ├─ [Stage 1 Reader]   → Vision → ingredients/rules → Persist
    ├─ [Stage 2 Processor] → Load rules; match; compliance → Persist
    └─ [Stage 3 Reporter] → Build message → JSON → Live API speaks to user
```

---

## Storage Separation (2 Databases / Collections)

| Collection | Purpose | Written by |
|------------|---------|------------|
| **meals** | Meals, time, ingredients, compliance, single user | Reader (raw), Processor (analysis) |
| **diet_rules** | Parsed rules from image/PDF; allowances, restrictions | Reader (from rules image/PDF) |

**Formalization:** Rules are structured as:
- **allowances:** items[], maxPortion?
- **restrictions:** items[], reason
- **limits:** items[], maxPerDay, unit

---

## Implementation Note

For MVP, the three stages are **logical modules** within the same backend (Reader, Processor, Reporter). Each module has clear boundaries and persistence points. Split into separate services later if needed. The **Live Agent** (Gemini Live API) is invoked from the iOS app via WebSocket; the backend serves as the tool.

---

## Roadmap (Google-Aligned)

| Extension | Description | Doc |
|-----------|-------------|-----|
| **Reporter → Coach** | Notifications, score alerts, trends, conversational exchange | [roadmap-google-alignment.md](./roadmap-google-alignment.md) |
| **Diet evolution** | Rule versioning, phased plans | Same |
| **Doctor report** | Behaviors, improvement areas, dashboard export | Same |
| **HeyCyan + Live Coach** | Glasses capture → Live API; See, Hear, Speak | [heycyan-integration.md](./heycyan-integration.md) |
