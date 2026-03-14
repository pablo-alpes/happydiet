# HappyDiet — Demo Video Script (4 Minutes)

**Format:** Screen recording + voiceover (or camera on you for intro/outro)
**Deadline:** Before March 16, 2026
**Requirements:** Real software, no mockups, architecture diagram, Cloud deployment proof

---

## TIMELINE OVERVIEW

| Section | Time | Duration | What's on screen |
|---------|------|----------|------------------|
| 1. Hook | 0:00 | 20s | You on camera (or showcase hero) |
| 2. Problem | 0:20 | 30s | Showcase: Problem section |
| 3. Solution | 0:50 | 30s | Showcase: Solution + pipeline |
| 4. Architecture | 1:20 | 30s | Showcase: Architecture diagram |
| 5. Google Compliance | 1:50 | 20s | Showcase: Compliance section |
| 6. Live Demo — Analyze a meal | 2:10 | 50s | App: upload meal → compliance result → speak |
| 7. Live Demo — Voice Coach | 3:00 | 40s | App: Live Coach conversation + meal photo |
| 8. Impact + Close | 3:40 | 20s | Showcase: Social Impact + your face |
| **Total** | | **4:00** | |

---

## FULL SCRIPT

### 1. HOOK (0:00–0:20)

*[You on camera, or screen on the showcase hero page]*

> "A nutritionist in Madrid told me: 'I prescribe a diet, the patient walks out, and I have zero data until the next appointment.' 80% of diets fail by week 8 — not because the plans are bad, but because tracking is friction. I built HappyDiet to fix that, using Google's Gemini Live API. Let me show you."

*[Click: scroll begins]*

---

### 2. THE PROBLEM (0:20–0:50)

*[Screen: scroll to the Problem section on the showcase page. Slow scroll across the 4 cards.]*

> "The problem is simple. Nutritionists prescribe diets, but they have zero visibility into what patients actually eat between appointments. Patients try to track manually, but food logging creates friction at the exact moment it matters — at the table, with food in front of you.
>
> And here's the thing: every diet app on the market counts calories. But that's not what doctors prescribe. They prescribe rules — forbidden foods, allowed foods, portion limits. No tool measures that."

---

### 3. THE SOLUTION (0:50–1:20)

*[Screen: scroll to the Solution section. Pause on the 3-stage pipeline (Reader → Processor → Reporter).]*

> "HappyDiet works like this: take a photo of your meal, and an AI coach tells you — instantly, out loud — whether you're on track.
>
> Under the hood, three agents process every meal. The Reader uses Gemini Vision to identify ingredients and estimate calories. The Processor matches each ingredient against your personal diet rules — using exact matching, fuzzy matching, and LLM semantic reasoning. If you eat bread and your rule says 'no gluten,' it catches that. The Reporter delivers the verdict as a voice conversation."

*[Point to the pipeline visual as you describe each stage]*

---

### 4. ARCHITECTURE (1:20–1:50)

*[Screen: scroll to the Architecture diagram. Pause and point to each layer.]*

> "The entire stack runs on Google Cloud. Clients connect via WebSocket for real-time voice, or HTTPS for REST. The backend runs on Cloud Run — a single serverless container.
>
> The Gemini Live API is the conversational agent. When it needs to analyze a meal, it calls our backend as a tool. The backend runs the Reader, Processor, Reporter pipeline, stores results in Firestore, and returns structured compliance data for the model to speak.
>
> Vertex AI powers four functions: Vision for food recognition, the Live API for voice, semantic matching for ingredient-rule compliance, and diet plan parsing. Everything uses the official GenAI SDK."

*[Trace the flow: Clients → Backend → GCP services]*

---

### 5. GOOGLE CLOUD COMPLIANCE (1:50–2:10)

*[Screen: scroll to the Compliance section. Quick scan of the three layers.]*

> "Every mandatory requirement for the Gemini Live Agent Challenge is met. Gemini model, GenAI SDK, Live API with barge-in, Cloud Run hosting, Firestore for data, Cloud TTS for voice, and over 100 tests.
>
> We run a full CI/CD pipeline: dev and prod environments, tests before every deploy, and automatic deploys when we push to main. Nothing goes to production without passing the test suite.
>
> Now let me show you it working."

*[Click "Try the Live Demo" or "Launch Live Demo" button]*

---

### 6. LIVE DEMO — ANALYZE A MEAL (2:10–3:00)

*[Screen: the app is now open. Go to the Analyze tab (or use the Coach).]*

**Option A — Quick analyze via upload:**

> "I'll upload a meal photo. This is a grilled chicken salad with avocado."

*[Upload the image. Wait for the compliance result to appear.]*

> "The Reader identified 6 ingredients. The Processor matched them against my diet rules and scored 87% compliance — the chicken, salad, and avocado are all allowed. It flagged the dressing as uncertain.
>
> I can hit the Speak button to hear it."

*[Click Speak. Let the TTS play for 3–5 seconds.]*

> "Now let me try something off-plan."

*[Upload a second image — something with forbidden items, like a burger with fries or a pizza.]*

> "This one scored 42%. The bread triggers 'no gluten,' the fries are forbidden, and it flagged 1,800 calories for this single meal. The calorie warning is clear — this was a calorie bomb."

---

### 7. LIVE DEMO — VOICE COACH (3:00–3:40)

*[Screen: switch to the Live Coach panel (web or iOS). Connect.]*

> "This is the Live Coach — powered by the Gemini Live API. I can talk to it naturally."

*[The coach should greet you. Speak to it:]*

> "Hey coach, how am I doing today?"

*[Let the coach respond for 5–8 seconds.]*

> "I can also share a meal photo mid-conversation."

*[Upload an image while the coach is active. Wait for the tool call and response.]*

> "It analyzed the meal, called the backend tool, and spoke the compliance verdict — all in real time. And if I interrupt it..."

*[Talk over the coach to demonstrate barge-in.]*

> "...it stops and listens. That's the Live API's barge-in."

---

### 8. IMPACT + CLOSE (3:40–4:00)

*[Screen: scroll back to the showcase Social Impact section, or switch to camera on you.]*

> "HappyDiet isn't just a tech demo. Voice-first coaching makes healthy eating accessible to people who can't use traditional diet apps — the elderly, low-literacy populations, anyone who just wants to point a camera and listen.
>
> I also built support for affordable smart lenses — under $100 — so users can capture meals hands-free on iOS. The app works with the glasses; image transfer requires a manual trigger due to iOS limits. I stopped development there due to lack of budget — the next step for seamless auto-transfer would require access to the manufacturer's developer program, which is only for enrolled developers or org team members.
>
> A nutrition clinic called it 'ground-breaking.' We're piloting in Madrid and Paris in 2026.
>
> HappyDiet — the AI diet coach that sees your plate and speaks your plan. Built entirely on Google Cloud."

*[End on the showcase hero or your face.]*

---

## PREPARATION CHECKLIST

### Before recording:

- [ ] Backend deployed to Cloud Run (or running locally with `npm run dev`)
- [ ] Open the web showcase at full width in Chrome
- [ ] Prepare 2 meal photos:
  - **Good meal** — salad, grilled chicken, vegetables (should score 80%+)
  - **Off-plan meal** — burger, pizza, or high-calorie BBQ (should score < 50%)
- [ ] Test the Live Coach connection works (audio out through speakers so it captures in the recording)
- [ ] Close all other tabs, notifications, do-not-disturb mode
- [ ] Screen recording tool ready (QuickTime, OBS, or Loom)

### During recording:

- Speak naturally — not too fast, not scripted-sounding
- Pause briefly on each visual section so judges can read
- Let the coach speak for a few seconds (don't cut it off immediately)
- Show the compliance score appearing in real time (the "thinking" indicator → result)

### After recording:

- Trim dead time, but keep it feeling real (no jump cuts during the demo)
- Keep total under 4 minutes
- No background music (judges need to hear the coach voice)

---

## MEAL PHOTOS TO PREPARE

| Photo | Expected Score | Why |
|-------|---------------|-----|
| Grilled chicken salad with veggies | 85–95% | All compliant, reasonable calories |
| Burger with fries and soda | 30–45% | Gluten (bread), fried (fries), sugar (soda), high kcal |
| Parrillada / BBQ platter | 40–55% | High kcal (calorie bomb), chorizo (forbidden), but some good items |

Pick two with clear contrast. The best demo shows one good meal and one bad meal — the audience sees the system work in both directions.

---

## OPTIONAL: CLOUD RUN PROOF

If you have time in the video (or as a quick flash):

*[Open Google Cloud Console → Cloud Run → show the happydiet service running]*

> "And here's the service running on Cloud Run — deployed via Cloud Build with tests before deploy."

This takes 5 seconds and satisfies the "Cloud deployment proof" judging criterion.
