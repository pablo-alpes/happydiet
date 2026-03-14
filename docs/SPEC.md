# HappyDiet — Spec Index

**Objective:** Entry point for the project spec. Navigate to the right document for objectives, architecture, design, or tasks.

**Hackathon:** [Gemini Live Agent Challenge](https://geminiliveagentchallenge.devpost.com) | **Deadline:** March 16, 2026

---

## Spec Files

| File | Objective |
|------|-----------|
| **[scope.md](./scope.md)** | What we're building, why, in/out scope |
| **[features.md](./features.md)** | Feature inventory and status |
| **[stack-architecture.md](./stack-architecture.md)** | Tech stack, architecture, data flow |
| **[design.md](./design.md)** | How we build: TDD, DDD, AI/GCP, agents |
| **[agents.md](./agents.md)** | 3-agent architecture (Reader, Processor, Reporter) |
| **[persistence.md](./persistence.md)** | Storage separation, durability, retries |
| **[setup.md](./setup.md)** | Prerequisites, environment, deployment |
| **[tasks.md](./tasks.md)** | What to do and when: phased plan |
| **[gemini-live-challenge-compliance.md](./gemini-live-challenge-compliance.md)** | Google challenge requirements & compliance checklist |
| **[google-spec-crosscheck.md](./google-spec-crosscheck.md)** | Google spec cross-check: requirements vs implementation |
| **[roadmap-google-alignment.md](./roadmap-google-alignment.md)** | Roadmap (Coach, diet evolution, doctor reports, glasses) vs Google requirements |
| **[prize-readiness.md](./prize-readiness.md)** | Where we stand vs. the big prize; gaps; priority order |
| **[architecture-diagram.md](./architecture-diagram.md)** | System architecture (for judges) |
| **[deployment-cicd.md](./deployment-cicd.md)** | Deploy to Cloud Run — step-by-step |
| **[testing.md](./testing.md)** | Test strategy, coverage, regression protection |
| **[uat.md](./uat.md)** | UAT formalization, suites, centralized commands |
| **[dev-environment.md](./dev-environment.md)** | Interactive dev playground, simulation |
| **[coding-standards.md](./coding-standards.md)** | TDD, DDD, structure — Cursor rules |
| **[architecture.md](./architecture.md)** | Tech stack, data flow — Cursor rules |
| **[api-guidelines.md](./api-guidelines.md)** | API contract, testing — Cursor rules |

---

## Quick Reference

**Flow:** iOS app (voice + photo) → Gemini Live API → tool(analyze_meal) → Backend (Vision, rules) → Firestore → voice reply

**Voice persona:** Describe what you see → judge (fair/exception/off) → inform

**Data model:** `Date;Meal;Items;Compliance;Detalle;Peso;Kcal` (v1)

**App surfaces:** Live coach (voice + vision) + Dashboard (tracking, scores, trends)

**TDD:** Mandatory for all layers (backend + iOS). No exceptions. See design.md.

**Ne jamais committer :** `.env`, clés API, credentials. Voir setup.md Annexe B (.gitignore).

**CI/CD & GCP :** Tests obligatoires avant deploy ; smoke tests post-deploy. Voir design.md (Testing GCP) et setup.md Annexe C.

**Docker :** Services modulaires via `docker-compose` (backend). Voir setup.md section 2.1.

**Tests :** Unit + integration + E2E obligatoires. `npm test` avant chaque merge. `npm run test:ci` en CI (JUnit). Voir design.md (Test Reporting) et setup.md Annexe D.
