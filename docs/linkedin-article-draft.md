# LinkedIn Article Draft — HappyDiet

**Purpose:** LinkedIn article for the Gemini Live Agent Challenge submission (bonus content). Targets Google judges, the developer community, investors, and healthtech stakeholders.

**Author:** Pablo Miranda  
**LinkedIn:** linkedin.com/in/pablomirandamba/  
**Suggested publish date:** Before March 16, 2026 (challenge deadline)

---

## Title Options (pick one)

1. **How I Built an AI Diet Coach Using Google's Gemini Live API — And Why Nutrition Compliance Needs It**
2. **Friction Kills Compliance: How I'm Rebuilding Diet Tracking with Gemini Vision and Voice**
3. **See, Hear, Speak: Building HappyDiet — An AI Coach That Understands Your Plate**

---

## Article

---

### Nutrition Is the Only Major Health Driver Without Measurable Feedback

Think about it. We have wearables for heart rate, blood pressure, sleep, and step count — all measured objectively, in real time. But nutrition? The single factor most controllable by patients and most impactful for prevention? We still rely on self-reported food diaries and calorie-counting apps that most people abandon within weeks.

The numbers are stark:

- **80% of diet plans fail by week 8.**
- Manual food tracking creates friction at the exact moment it matters most — at the table, with food in front of you.
- Clinics and insurers lack objective adherence data. Nutritionists prescribe plans, patients nod, and then real life happens.

The digital health market exceeds **$20 billion**, and the top players focus heavily on calories as the key metric. But real diet compliance is not about counting calories — it is about following rules: what is forbidden, what is allowed, what has a daily limit. That is what nutritionists actually prescribe, and that is what no tool measures well today.

**Friction kills compliance.** I built HappyDiet to fix that.

---

### What Is HappyDiet

**HappyDiet automates nutrition tracking — from your meal to insight and compliance.**

The concept is simple: **take a photo of your meal, and an AI coach tells you — instantly, out loud — whether you are on track with your diet.** No typing. No searching food databases. No calorie math. Just point, shoot, and listen.

But behind that simplicity is what I call **The Intelligent Loop**:

1. **AI reads the diet plan** issued by the nutritionist (text, image, handwritten notes) and parses it into structured, executable rules
2. **The Rule Engine** defines compliance logic — forbidden items, allowed items, portion limits, notes
3. **Vision AI matches meals** — the patient snaps a photo, and Gemini identifies every ingredient on the plate
4. **The Rule Engine confirms compliance** — each ingredient is checked against the personal diet rules using fuzzy and semantic matching
5. **The Dashboard shows adherence** — for the patient in real time, and ready for the doctor's follow-up

This transforms meal tracking from **passive logging to active behavioral guidance**.

---

### The Rule Engine — Our Superpower

Most diet apps stop at "you ate 1,800 calories." That tells you nothing about whether the specific foods you ate are allowed by your specific plan.

HappyDiet's Rule Engine **transforms dietary logic into executable and persistent rules** that the system can enforce meal after meal. It understands four rule types:

| Type | Example | Purpose |
|------|---------|---------|
| **Forbidden** | No sugar, no soda, no white bread | Items the patient must avoid |
| **Allowed** | Vegetables, lean protein, whole grains | Explicitly permitted foods |
| **Limit** | Max 2 coffees per day | Portion or frequency constraints |
| **Note** | Stay under 1,800 kcal, eat before 8pm | General instructions |

The matching goes beyond simple keywords. When a patient photographs a sandwich and the rule says "no gluten," the system understands that **bread contains gluten** — that is not keyword matching, that is AI reasoning. We combine precise matching, fuzzy word-overlap matching (similarity >= 0.6), and **LLM semantic matching** powered by Gemini.

The Rule Engine remains **adaptive and explainable**. Combined with AI, it enables coaching on deviations, weekly meal plans, and even supermarket purchase lists — all grounded in the actual rules the nutritionist prescribed.

---

### Why Google Cloud and Gemini

When Google announced the **Gemini Live Agent Challenge** — asking developers to go beyond static chatbots and create immersive, multimodal experiences — I knew it was the right moment to rebuild HappyDiet's architecture on a production-grade stack.

I had already validated the concept with a PoC running on a multimodal LLM with the business logic built into a prompt (rule engine, dataset, reporting). But to scale, the system needed a proper architecture — microservices, persistent storage, real-time voice interaction. Google Cloud gave me all of that.

| Layer | Technology | Why |
|-------|-----------|-----|
| **Vision** | Vertex AI (Gemini 2.5 Flash) | Understands food photos — ingredients, estimated calories, context |
| **Conversation** | Gemini Live API | Real-time voice interaction with barge-in — users can interrupt and ask follow-ups naturally |
| **Hosting** | Cloud Run | Serverless, scales to zero, deploys in seconds |
| **Storage** | Firestore | Two collections — `meals` for tracking, `diet_rules` for personalized plans |
| **Voice** | Cloud Text-to-Speech | Natural-sounding compliance feedback |
| **SDK** | @google-cloud/vertexai (GenAI SDK) | Official Node.js client, clean integration |

Every component runs on Google Cloud. The entire backend is a single Cloud Run service — no external dependencies, no third-party AI providers. **AI runs across the entire value chain**: LLM + AI Vision → Rule Engine → Dashboard → Insights + AI.

---

### The Architecture: Three Agents, One Pipeline

HappyDiet uses a **3-stage agent pipeline** to process every meal:

**Stage 1 — Reader Agent** (See)
Takes the meal image, sends it to Vertex AI Vision, and extracts structured data: ingredients, estimated calories, and visual context.

**Stage 2 — Processor Agent** (Think)
Loads the user's diet rules from Firestore and matches each detected ingredient against them — precise, fuzzy, and semantic. Produces a compliance score and a breakdown of compliant vs. non-compliant items. Persists the meal to Firestore.

**Stage 3 — Reporter Agent** (Speak)
Composes a human-friendly message with the verdict, suggestions, and encouragement. Delivered as JSON to the client and spoken aloud via the Live API or Cloud TTS.

```
User snaps a photo
    → Reader (Vision: what's on the plate?)
    → Processor (Rules: is this allowed?)
    → Reporter (Coach: here's what I think)
    → Voice output (Live API or TTS)
```

The **Gemini Live API** acts as the conversational agent — users talk to it, it can be interrupted (barge-in), and it calls the backend as a tool when it needs to analyze a meal. I call this the **See, Hear, Speak** paradigm.

---

### Real-Time Feedback, Not Passive Logging

This is the shift that matters. Traditional diet apps ask you to log what you ate after the fact. HappyDiet gives you feedback **in the moment**, while you can still make a different choice.

**Live Coach** — The flagship feature. Users open a voice conversation with the AI coach. They can speak naturally ("I'm about to eat this pasta"), share a meal photo, and the coach responds in real time. If the user interrupts, the coach stops and listens. Powered by Gemini Live API with WebSocket streaming.

**Trend-Awareness and Gentle Reminders** — HappyDiet identifies deviations and trends over time. "Your dinners have been off-plan 4 of the last 7 days." "You've been really consistent at breakfast — keep it up." The coach provides gentle reminders and insights on patterns — behavioral guidance, not shame.

**Personalized Meal Plans** — Given its knowledge of the diet rules, the AI can suggest what to eat next: a compliant lunch, a weekly meal plan, or even a grocery list. All grounded in the actual rules prescribed by the nutritionist.

---

### Early Validation

This is not a theoretical exercise. Before building the current version, I validated the concept with a local nutrition clinic. Their reaction was telling: they called it **"ground-breaking"** and asked to be on the waitlist for the SaaS service.

The gap they described is the same one every nutritionist faces: they prescribe a plan, the patient goes home, and the nutritionist has no idea what happens next until the follow-up appointment weeks later. HappyDiet fills that gap with real, objective compliance data — generated automatically from meal photos, not self-reported.

---

### Two Journeys: B2C and B2B

HappyDiet serves both sides of the table:

**B2C — Effortless daily tracking.** Patients use the app to photograph meals and get instant compliance feedback. Voice-first coaching removes the literacy and tech-savviness barriers that traditional diet apps impose. Not everyone is comfortable typing food names into search bars. But everyone can point a camera and listen.

**B2B — Clinics and insurers gain measurable data.** Nutritionists prescribe a diet, patients use HappyDiet, and the clinic receives real adherence data — not estimates. Insurers get the objective prevention metrics they have been missing. The dashboard is ready for the doctor's follow-up on day one.

This dual model opens a clear path:

| Phase | Focus |
|-------|-------|
| **Phase 1** | B2B SaaS / API for clinics and insurers |
| **Phase 2** | Consumer freemium app |
| **Phase 3** | Analytics insights and integrations |
| **Phase 4** | AI wearable devices (smart glasses and beyond) |

---

### The Social Impact

**Making healthy eating accessible to everyone** is not a tagline — it is the design principle.

Voice-first coaching removes barriers. Personalized support without judgment removes shame. When you eat something off-plan, HappyDiet tells you what happened and what you might do next — not that you failed. Because lasting change starts with understanding, not shame.

The framework is scalable beyond nutrition. The same architecture — AI vision, rule engine, compliance scoring, behavioral coaching — can extend into broader **lifestyle and chronic condition management**. Diabetes management, post-surgery recovery diets, allergy tracking. The Rule Engine does not care whether the rule is "no sugar" or "no high-sodium foods" — it enforces whatever the clinician prescribes.

---

### What I Learned Building This

**1. Validate the need before the stack.** The clinic validation came first. The technology choice came after. Google Cloud and Gemini were selected because they matched the requirements — multimodal vision, real-time voice, scalable hosting — not the other way around.

**2. A clear mental model beats more time.** I designed the 3-agent pipeline, the two Firestore collections, and the tool contract on paper before writing code. When the architecture is clear, implementation feels like filling in the blanks.

**3. Gemini is genuinely multimodal.** Passing a food photo to Gemini and getting back structured JSON with ingredients and calories — that just works. The semantic understanding is strong enough to catch "bread contains gluten" when matching against a gluten-free rule. That is not keyword matching; that is reasoning.

**4. The Live API changes everything.** Traditional REST APIs feel transactional. The Live API feels conversational. Users can talk, interrupt, ask follow-ups, share images mid-conversation. It is what diet coaching should feel like — a conversation, not a form.

**5. The Rule Engine is the moat.** Anyone can call a vision API. The differentiation is in **what you do with the ingredients** — matching them against persistent, personalized, explainable rules that evolve with the patient's diet. That is the superpower.

---

### What's Next

- **2026:** Pilot with digital health clinics in Madrid and Paris
- **2027:** API integrations and scaling for insurers and AI wearables
- **Smart glasses:** HeyCyan integration for hands-free, first-person meal capture — true See, Hear, Speak
- **Doctor-facing reports:** Aggregate compliance data into weekly reports that nutritionists can use in follow-ups
- **Proactive coaching:** Nudges, score alerts, trend-aware suggestions powered by Gemini

HappyDiet is looking for pilot partners (clinics, nutritionists, insurers) and preparing for a pre-seed round. If you are working in digital health, nutrition, or AI-driven prevention — I would love to connect.

---

### Try It

HappyDiet is built for the **Gemini Live Agent Challenge** and runs entirely on Google Cloud.

- **Web:** Open the Cloud Run URL in any browser — no install required
- **iOS:** Native app with camera, photo library, and Live Coach
- **Code:** Public repository with full README, architecture diagrams, and 61 tests

---

*Pablo Miranda — Founder & CEO, HappyDiet. MSc (c) Computer Science, MBA, BSc Software Engineering & Political Science. 12+ years in (re)insurance, business intelligence, cybersecurity, and data protection (GDPR, HIPAA, DORA, AI Act) across Europe, US, and Latam. Now building AI systems that automate nutritional adherence and compliance reporting.*

*linkedin.com/in/pablomirandamba/*

---

## Suggested LinkedIn Post (Short Version for Feed)

> **Nutrition is the only major health driver without measurable feedback.** We have wearables for heart rate, sleep, and steps. But diet? Still relies on self-reported logs that 80% of people abandon by week 8.
>
> I built **HappyDiet** — an AI diet coach that works like this: take a photo of your meal, and the AI tells you out loud whether you are on track with your diet. No typing. No calorie math. Just point, shoot, and listen.
>
> Under the hood: a 3-agent pipeline on Google Cloud. Vertex AI for vision. Gemini Live API for real-time voice. A Rule Engine that transforms dietary logic into executable compliance checks — our superpower.
>
> A nutrition clinic called it "ground-breaking." Clinics and insurers finally get objective adherence data. Patients get a coach that guides without judging.
>
> Built for the #GeminiLiveAgentChallenge. Running entirely on #GoogleCloud. Piloting in Madrid & Paris in 2026.
>
> Full article below. Would love your thoughts — especially from anyone in digital health, nutrition, or AI-driven prevention.
>
> #AI #Gemini #VertexAI #CloudRun #HealthTech #LiveAPI #GenAI #DigitalHealth #NutritionTech #SocialImpact

---

## Suggested Visuals

1. **Hero image** — The HappyDiet hero image (healthy meal, clean styling) — at `backend/public/happydiet-hero.jpg`
2. **Architecture diagram** — The 3-agent pipeline system diagram from `docs/architecture-diagram.md`
3. **The Intelligent Loop** — Infographic: Diet Plan → Rule Engine → Vision AI → Compliance → Dashboard (matches pitch deck slide 5)
4. **App screenshots** — Web showcase (Live Coach with a conversation), compliance card, dashboard with meal history
5. **Rule Engine visual** — The four rule types: Forbidden (red), Allowed (green), Limit (orange), Note (gray) — matches the website's rule cards
6. **Founder photo** — Professional headshot for the author bio

---

## Hashtags

`#GeminiLiveAgentChallenge` `#GoogleCloud` `#VertexAI` `#GeminiAPI` `#LiveAPI` `#CloudRun` `#Firestore` `#GenAI` `#HealthTech` `#DigitalHealth` `#NutritionTech` `#AI` `#DietCoach` `#Multimodal` `#VoiceFirst` `#Accessibility` `#SocialImpact` `#PreventionHealth` `#B2BSaaS`

---

## Cross-Reference: Pitch Deck Slides → Article Sections

| Pitch Deck Slide | Article Section |
|------------------|-----------------|
| 1. The Problem | "Nutrition Is the Only Major Health Driver..." |
| 2. The Opportunity | Market stats in opening section |
| 3. Solution Overview | "What Is HappyDiet" |
| 4. Proof of Concept | "Early Validation" |
| 5. The Intelligent Loop | "What Is HappyDiet" — the 5-step loop |
| 6. Real-time Feedback | "Real-Time Feedback, Not Passive Logging" |
| 7. Trend-awareness | "Trend-Awareness and Gentle Reminders" |
| 8. Personalized meal plan | "Personalized Meal Plans" |
| 9. The Rule Engine | "The Rule Engine — Our Superpower" |
| 10. Technical Architecture | "Why Google Cloud and Gemini" + "The Architecture" |
| 11. B2C & B2B Journeys | "Two Journeys: B2C and B2B" |
| 12. Business Model | Phase table in "Two Journeys" |
| 13. Go-To-Market | "What's Next" |
| 14. Founder & Next Steps | Author bio + "What's Next" |

---

## Notes for Author

- **Investor angle:** The article is structured as a thought-leadership piece but contains all investor pitch elements (market, problem, solution, validation, business model, GTM, team). It can be shared with investors as "here's the public narrative" alongside the deck.
- **Google compliance:** Every required Google service is named (Gemini, Vertex AI, Cloud Run, Firestore, GenAI SDK). The judging language is used throughout ("See, Hear, Speak", "beyond text box", "multimodal", "Live & context-aware").
- **Challenge bonus:** The Gemini Live Agent Challenge awards bonus points for content (blog, podcast). Publish before March 16.
- **Tone:** Professional, personal ("I built", "I validated"), and narrative-driven. The pitch deck's punchy one-liners are woven into the article's longer-form storytelling.
- **No sensitive data:** The article does not include email addresses, API keys, or internal URLs. The author bio uses the public LinkedIn URL only.
