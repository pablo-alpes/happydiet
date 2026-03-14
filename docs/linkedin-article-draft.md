# Friction Kills Compliance: How I Built an AI Diet Coach with Gemini Live API

**Author:** Pablo Miranda
**LinkedIn:** [linkedin.com/in/pablomirandamba/](https://linkedin.com/in/pablomirandamba/)
**Built for:** [Gemini Live Agent Challenge](https://geminiliveagentchallenge.devpost.com) — Deadline: March 16, 2026

---

Last year, a nutritionist at a clinic in Madrid told me something that stuck: *"I prescribe a diet plan, the patient nods, walks out the door, and I have zero visibility into what happens for the next four weeks — until they come back and the scale tells us the truth."*

That gap — between prescription and adherence — is the problem I built HappyDiet to solve.

**80% of diet plans fail by week 8.** Not because the plans are bad. Because tracking is friction, and friction happens at the worst possible moment: at the table, with food in front of you. Every diet app on the market asks you to search a database, weigh portions, log macros. By the time you've done all that, the meal is cold and the habit is dead.

And here's the thing nobody talks about: **those apps measure the wrong thing.** They count calories. But that's not what doctors prescribe. Doctors prescribe *rules* — forbidden foods, allowed foods, portion limits, specific notes. "No gluten." "Max 2 coffees per day." "Stay under 1,800 kcal." No tool on the market measures whether you actually followed those rules.

I built HappyDiet to fix that. **Take a photo of your meal, and an AI coach tells you — instantly, out loud — whether you're on track with your diet.** No typing. No searching. No calorie math. Just point, shoot, and listen.

---

## The Intelligent Loop: See, Think, Speak

Under the surface, every meal goes through a 3-stage agent pipeline I call **See, Think, Speak**:

**Stage 1 — See (Reader Agent)**
The meal photo is sent to **Vertex AI (Gemini 2.5 Flash Vision)**. The model identifies every ingredient on the plate, estimates total calories, and returns structured JSON. A parrillada becomes: `["grilled chicken", "chorizo", "grilled peppers", "chimichurri", "bread"]` with an estimated 2,400 kcal.

**Stage 2 — Think (Processor Agent)**
The extracted ingredients are matched against your personal diet rules stored in **Firestore**. The Rule Engine uses three layers of matching:
- **Precise matching** — exact keyword hits ("chorizo" matches "chorizo")
- **Fuzzy matching** — word-overlap similarity >= 0.6 ("grilled peppers" ≈ "peppers")
- **LLM semantic matching** — Gemini reasoning ("bread" violates "no gluten" — not a keyword match, that's AI understanding that bread contains gluten)

The Processor calculates a compliance score, applies calorie penalties (meal-level and daily totals), flags non-compliant items, and persists the meal to Firestore.

**Stage 3 — Speak (Reporter Agent)**
The compliance result is transformed into a human-friendly message: score, what was good, what was off-plan, calorie warnings, and actionable suggestions. This message is delivered as text and spoken aloud via the **Gemini Live API** — a real-time voice conversation the user can interrupt, question, and learn from.

```
📸 Meal photo
  → Reader (Gemini Vision: what's on the plate?)
  → Processor (Rule Engine: is this allowed? How many kcal today?)
  → Reporter (Coach: here's what I think, here's what to do next)
  → Voice output (Gemini Live API — real-time, interruptible)
```

This is not another calorie counter. This is **the first tool that measures real dietary compliance** — the thing nutritionists actually prescribe — and coaches you while you can still make a different choice.

---

## Why Voice-First Changes Everything

The flagship feature is the **Live Coach**, powered by the Gemini Live API.

Users open a voice conversation with the AI. They can speak naturally: *"Hey coach, I'm about to eat this pasta — is it okay?"* They can share a meal photo mid-conversation. The coach analyzes it in real time, calls the backend as a tool, and speaks the compliance verdict. If the user interrupts, the coach stops and listens. That's barge-in — and it's what makes this feel like talking to a person, not using an app.

This matters because **the people who need diet help the most are the ones traditional apps fail:**
- The elderly, who struggle with tiny search bars and food databases
- Low-literacy populations, who can't navigate complex UIs
- Busy parents, who don't have 5 minutes to log every meal
- Anyone who just wants a simple answer: *"Am I on track?"*

Voice-first, photo-based interaction removes every one of those barriers. You point your camera and listen. That's it.

---

## The Rule Engine: Our Moat

Most diet apps stop at "you ate 1,800 calories." That tells you nothing about whether the specific foods you ate are allowed by your specific plan.

HappyDiet's Rule Engine transforms dietary logic into **executable, persistent rules** that the system enforces meal after meal:

| Type | Example | Purpose |
|------|---------|---------|
| **Forbidden** | No gluten, no soda, no fried foods | Items the patient must avoid |
| **Allowed** | Vegetables, lean protein, whole grains | Explicitly permitted foods |
| **Limit** | Max 2 coffees per day | Portion or frequency constraints |
| **Note** | Stay under 1,800 kcal, eat before 8 PM | General instructions and calorie targets |

The semantic matching is what sets it apart. When a patient photographs a sandwich and the rule says "no gluten," the system understands that **bread contains gluten**. That's not keyword matching — that's Gemini reasoning about food composition. We combine precise, fuzzy, and LLM semantic matching to catch what simpler systems miss.

**Calorie-aware scoring** adds another dimension. A meal can have compliant ingredients but still be a calorie bomb. The system tracks meal-level calories against progressive thresholds and daily totals against the user's kcal target. A 4,000 kcal parrillada gets flagged hard, even if every ingredient is technically allowed. This was calibrated through real user testing and iterative threshold tuning.

---

## The Competitive Landscape: What Exists and What's Missing

The AI-for-food space is growing fast. Here's what's out there:

| Product | Focus | What it lacks |
|---------|-------|---------------|
| **[Calorie Lens](https://ai.google.dev/competition/projects/calorie-lens)** (Google AI winner) | Calorie estimation + allergens | No personalized rule compliance |
| **[NutriLens AI](https://www.nutrilensai.net/)** | Image-based nutrition analysis | No rule matching or voice coaching |
| **[FoodLens AI](https://foodlens-ai.com/)** | Allergen/label scanning | Label-focused, not meal compliance |
| **[Azumio Food Lens](https://www.azumio.com/solutions/food-lens/overview)** | API for food recognition (5,000+ dishes) | No end-user compliance loop |
| **[DietGlance](https://arxiv.org/abs/2502.01317)** (academic, 2025) | Wearable AI dietary monitoring | Research only; no production app, no rule engine |

**What they all share:** they tell you *what* you ate (calories, nutrients, allergens). **What none of them do:** tell you *whether what you ate aligns with the dietary rules your doctor prescribed* — and coach you about it in real time.

A [2024 systematic review (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC11621677/) confirms the gap: AI tools for food recognition are advancing, but **real-time compliance feedback tied to individual dietary prescriptions** remains an open problem. HappyDiet is built precisely for that gap.

---

## The Stack: Built Entirely on Google Cloud

| Layer | Service | Role |
|-------|---------|------|
| **Vision** | Vertex AI (Gemini 2.5 Flash) | Food photo → ingredients, kcal, context |
| **Conversation** | Gemini Live API | Real-time voice with barge-in, tool calls |
| **Semantic matching** | Vertex AI (Gemini) | "bread" violates "no gluten" — AI reasoning |
| **Diet parsing** | Vertex AI (Gemini) | Handwritten/text diet plans → structured rules |
| **Hosting** | Cloud Run | Serverless backend, scales to zero |
| **Storage** | Firestore | `meals` collection + `diet_rules` collection |
| **Voice** | Cloud Text-to-Speech | Natural compliance feedback audio |
| **SDK** | @google-cloud/vertexai (GenAI SDK) | Official Node.js client |
| **CI/CD** | Cloud Build | Tests before deploy, automated |

**AI runs across the entire value chain** — from reading the diet plan, to understanding the meal photo, to reasoning about rule compliance, to speaking the verdict. No external AI providers. No third-party services. Everything runs on Google Cloud.

---

## The Engineering Journey: From Prompt to Production

I want to be transparent about the process. Building AI products is messy, and I think the honest story matters.

**Phase 1 — One giant prompt.** The first HappyDiet was a single Gemini prompt containing all the logic: diet rules, matching, scoring, response. It worked for demos. It was also fragile, untestable, and impossible to maintain.

**Phase 2 — Architecture-first rebuild.** I redesigned the entire system before writing code. Two Firestore collections, a 3-agent pipeline, clean separation between AI inference and deterministic logic. The Rule Engine is pure code — no LLM in the loop for matching, except as a final semantic fallback. Fast, predictable, testable.

**Phase 3 — Test-driven development.** The backend has **108 tests across 11 test suites** — unit, integration, E2E, and user-acceptance. **100% statement coverage** on all domain and application code. Tests run before every deploy. This discipline saved me repeatedly, especially when calibrating calorie penalties: change a threshold, run tests, verify no regressions.

**Phase 4 — Live API integration.** The hardest part. I built a WebSocket proxy that translates between the client's camelCase and Vertex's snake_case, intercepts tool calls, executes the analysis pipeline, and returns structured results for the model to speak. Getting barge-in, audio streaming, and tool call interception to work together required careful state management.

**Phase 5 — Calorie calibration.** Real users tested the app and reported that a 4,000 kcal barbecue scored 71% compliant. That exposed a gap: the Rule Engine checked ingredients correctly but ignored caloric excess. I added progressive calorie penalties (meal-level and daily totals), daily kcal tracking in Firestore, and calorie warnings in the coach's response. The scoring now reflects both *what* you eat and *how much*.

**What I learned:** The biggest challenge was not the AI — it was the **glue**. API format translation, WebSocket reconnections, audio state, scoring calibration, deterministic edge cases. The AI reasoning is the headline; the engineering makes it actually work.

---

## Innovation: What Makes This Different

The **Gemini Live Agent Challenge** asks for experiences that go "beyond the text box" — multimodal, real-time, context-aware. Here's how HappyDiet delivers on each dimension:

| Dimension | How HappyDiet delivers |
|-----------|----------------------|
| **Multimodal input** | Camera (meal photos) + voice + text — all in one conversation |
| **Multimodal output** | Spoken compliance verdict + visual dashboard + text breakdown |
| **Real-time** | Live API WebSocket — no request/response delay, continuous conversation |
| **Context-aware** | Rules are personal (per-user Firestore), daily calorie tracking persists, trends build over time |
| **Barge-in** | Users interrupt the coach mid-sentence; it stops and listens |
| **Tool use** | The Live API agent calls `analyze_meal` as a tool — the backend does the real work |
| **Beyond text box** | Voice-first design: the primary interaction is speaking and listening, not typing |
| **Accessible hardware** | HeyCyan integration — affordable lenses (<$100) for hands-free capture on iOS. App works with glasses; image transfer manual (iOS limits). Dev paused (budget); seamless auto-transfer requires manufacturer dev program access. AI on low-cost hardware to reach more users |

**The paradigm shift:** Traditional diet apps are forms you fill out. HappyDiet is a conversation you have. That's the difference between passive logging and active behavioral guidance.

---

## Impact: Why This Matters Beyond Technology

Diet-related diseases are the leading preventable cause of death worldwide ([WHO, 2025](https://www.who.int/europe/news/item/25-06-2025-1.8-million-avoidable-deaths-annually-in-europe)). The burden falls hardest on those with the least access to professional guidance.

**Accessibility.** Voice-first, photo-based interaction makes dietary coaching accessible to the elderly, low-literacy populations, people with disabilities, and anyone who struggles with traditional app UIs. No typing. No databases. No math. I also built support for affordable smart lenses (under $100) — the app works with the glasses; image transfer is manual (iOS limits). Development paused due to budget; seamless auto-transfer would require access to the manufacturer's developer program.

**Clinical visibility.** Nutritionists prescribe diets and lose visibility for weeks. HappyDiet generates objective adherence data — automatically, from meal photos. The dashboard is ready for the doctor's follow-up on day one.

**Coaching without shame.** Diet culture is saturated with guilt. HappyDiet tells you what happened and what to do next — not that you failed. Lasting behavioral change starts with understanding, not punishment.

**The framework scales.** The architecture — AI vision, rule engine, compliance scoring, voice coaching — applies to any domain where a professional prescribes rules and a patient needs real-time adherence support. Diabetes management. Post-surgery recovery. Allergy tracking. The Rule Engine doesn't care whether the rule is "no sugar" or "no high-sodium foods."

---

## Early Validation

Before building the current version, I validated the concept with a local nutrition clinic. Their reaction: they called it **"ground-breaking"** and asked to be on the waitlist for the SaaS service.

The gap they described is the same one every nutritionist faces: prescribe a plan, patient goes home, zero data until the follow-up. HappyDiet fills that gap with real, objective compliance data — generated automatically from meal photos.

---

## What's Next

- **2026:** Pilot with digital health clinics in Madrid and Paris
- **2027:** API integrations for insurers and clinical platforms
- **Smart lenses:** HeyCyan integration — affordable lenses under $100 for hands-free capture on iOS. The app works with the glasses; image transfer requires a manual trigger (iOS limits). Development paused due to budget; the next step for seamless auto-transfer would require access to the manufacturer's developer program (enrolled developers / org team only). Goal: hands-free capture for everyone. True See, Hear, Speak.
- **Doctor-facing reports:** Weekly aggregate compliance data for clinical follow-ups
- **Proactive coaching:** Score alerts, trend nudges, pattern detection

HappyDiet is looking for pilot partners (clinics, nutritionists, insurers) and preparing for a pre-seed round. If you work in digital health, nutrition, or AI-driven prevention — I'd love to connect.

---

## Try It

HappyDiet runs entirely on Google Cloud. Built for the Gemini Live Agent Challenge.

- **Web:** Open the Cloud Run URL — no install needed. Live Coach, Analyze, Diet Rules, Dashboard.
- **iOS:** Native app with camera, photo library, Live Coach, and HeyCyan glasses support.
- **Code:** Public repository with full README, architecture diagrams, and 108 tests (100% coverage).

---

*Pablo Miranda — Founder & CEO, HappyDiet. MSc (c) Computer Science, MBA, BSc Software Engineering & Political Science. 12+ years in (re)insurance, business intelligence, cybersecurity, and data protection (GDPR, HIPAA, DORA, AI Act) across Europe, US, and Latam. Now building AI that automates nutritional adherence and compliance reporting.*

*[linkedin.com/in/pablomirandamba/](https://linkedin.com/in/pablomirandamba/)*

---

## LinkedIn Post (Short Version for Feed)

> **80% of diets fail by week 8. Not because the plans are bad — because tracking creates friction at the worst moment: at the table, with food in front of you.**
>
> I built **HappyDiet** — an AI diet coach powered by **Gemini Live API**. Take a photo of your meal, and it tells you *out loud* whether you're on track with *your* diet. No typing. No calorie math. Point, shoot, listen.
>
> Under the hood: Gemini Vision identifies every ingredient. A Rule Engine matches them against your personal diet rules (forbidden, allowed, limits). The Gemini Live API delivers the verdict as a real-time voice conversation — with barge-in, so you can interrupt and ask follow-ups naturally.
>
> The gap: every diet app counts calories. None of them check whether what you ate aligns with the specific rules your doctor prescribed. That's what nutritionists actually care about. That's what HappyDiet does.
>
> **108 tests. 100% coverage. 3-agent pipeline. Entirely on Google Cloud.** HeyCyan lenses support (<$100) — app works with glasses; image transfer manual (iOS limits). Dev paused (budget); seamless auto-transfer requires manufacturer dev program access.
>
> Full article below 👇
>
> #GeminiLiveAgentChallenge #GoogleCloud #VertexAI #GeminiAPI #LiveAPI #CloudRun #Firestore #GenAI #HealthTech #DigitalHealth #AI #VoiceFirst #Accessibility

---

## Images to Include

When publishing, add these visuals at the relevant section breaks:

1. **Cover image** — Use `happydiet-hero.jpg` or a screenshot of the web showcase hero
2. **After "The Intelligent Loop"** — Screenshot of the architecture diagram from the web showcase page
3. **After "The Rule Engine"** — Screenshot of the Diet Rules tab showing the emoji food cards (Forbidden red, Allowed green, Limit orange)
4. **After "The Competitive Landscape"** — The comparison table renders well in LinkedIn articles as-is
5. **After "The Stack"** — Screenshot of the web showcase Architecture section (layered diagram)
6. **After "The Engineering Journey"** — Screenshot of the test output (108 passed, 100% coverage)
7. **After "Impact"** — Screenshot of the Live Coach conversation (voice interaction with meal analysis)
8. **Author bio** — Your professional headshot
