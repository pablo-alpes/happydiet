# HappyDiet — Google Challenge Spec Cross-Check

**Source:** [Gemini Live Agent Challenge](https://geminiliveagentchallenge.devpost.com) | **Deadline:** March 16, 2026

This document maps Google's requirements to our implementation and identifies gaps.

---

## 1. Mandatory Requirements (All Categories)

| Google Requirement | Our Implementation | Status |
|--------------------|-------------------|--------|
| **Leverage a Gemini model** | Vertex AI `gemini-2.5-flash` for Vision, parse-diet, semantic compliance | ✅ |
| **Agents built using GenAI SDK or ADK** | `@google-cloud/vertexai` (official Node.js GenAI SDK for Vertex AI) | ✅ |
| **Agents hosted on Google Cloud** | Backend on Cloud Run; tool endpoints for Live API | ✅ |
| **Use at least one Google Cloud service** | Vertex AI, Firestore, Cloud TTS, Cloud Run | ✅ |

---

## 2. Live Agents Category — Specifics

| Google Requirement | Our Implementation | Status |
|--------------------|-------------------|--------|
| **Must use Gemini Live API or ADK** | Backend WebSocket proxy at `/live`; iOS Live Coach tab connects | ✅ |
| **Build an agent users can talk to naturally** | Live Coach: text + image; voice via realtimeInput (audio) | ✅ |
| **Can be interrupted (barge-in)** | Live API supports barge-in; proxy forwards all messages | ✅ |
| **Real-time Interaction (Audio/Vision)** | Text + image input; audio output (24kHz PCM) | ✅ |

**Flow:** User → iOS Live Coach → `ws://backend/live` (proxy) → Vertex AI Live API → tool `analyze_meal` → Backend → JSON → Live API speaks to user.

---

## 3. Agent vs Service Terminology

### What Google Means by "Agent"

| Term | Google's Meaning | Our Mapping |
|------|------------------|-------------|
| **Live Agent** | The conversational agent users talk to = **Gemini Live API** | The agent is the Live API. Users speak to it; it can interrupt. |
| **Agent logic** (judging) | Sound backend logic, error handling, grounding | Our Reader/Processor/Reporter implement the tool logic. |
| **Agents hosted on Google Cloud** | Backend/tool logic runs on GCP | Our backend on Cloud Run. |

### Our Architecture Alignment

| Component | Role | Google-Aligned Name |
|-----------|------|---------------------|
| **Gemini Live API** | The agent users talk to (voice, vision, barge-in) | **Live Agent** |
| **Backend (Cloud Run)** | Tool the agent calls; hosts processing logic | **Agent Tool / Backend** |
| **Reader** | Image → Vision → ingredients | **Tool logic: Reader stage** |
| **Processor** | Rule matching → compliance | **Tool logic: Processor stage** |
| **Reporter** | Build message → JSON | **Tool logic: Reporter stage** |

**Conclusion:** Our Reader/Processor/Reporter are **processing stages** within the agent's tool. They are not autonomous LLM agents (like ADK agents). They implement the `analyze_meal` tool that the Live Agent invokes. This is valid: the agent architecture is the Live API + tool backend; our pipeline is the tool implementation.

---

## 4. Submission Requirements

| Item | Status | Location |
|------|--------|----------|
| **Public code repository URL** | — | Required for judging |
| **README with spin-up instructions** | ✅ | [README.md](../README.md), [setup.md](./setup.md) |
| **Architecture diagram** | ✅ | [architecture-diagram.md](./architecture-diagram.md) |
| **Demo video (<4 min)** | — | Real-time demo; problem + solution; no mockups |

---

## 5. Judging Criteria

| Criterion (30%) | Our Alignment |
|-----------------|---------------|
| **Demo & Presentation** | Video: problem, solution, architecture diagram, Cloud deployment proof, actual software |
| **Technical Implementation & Agent Architecture** | GenAI SDK ✓, backend on GCP ✓, tool logic (Reader/Processor/Reporter) ✓, error handling ✓ |
| **Innovation & Multimodal UX (40%)** | Beyond text box: vision + voice; "See, Hear, Speak"; Live & context-aware when Live API added |

---

## 6. Gaps to Address

| Priority | Gap | Action |
|----------|-----|--------|
| 1 | **Demo video** | Record <4 min: problem, solution, live demo |
| 2 | **Architecture diagram** | Ensure diagram clearly shows Live API as the agent; backend as tool |

---

## 7. What We Have (Current State)

| Area | Implemented |
|------|-------------|
| **Backend** | Vision, parse-diet, rule matching (fuzzy + LLM semantic), TTS, Firestore, tool endpoints |
| **iOS** | Analyze, Diet, Dashboard; TTS (backend or AV fallback) |
| **Dev Playground** | Full flow testing |
| **GCP** | Vertex AI, Firestore, Cloud TTS, Cloud Run config |
| **Deployment** | setup-production.sh, deploy.sh, Cloud Build |

---

## 8. Roadmap & Glasses

Planned features (Coach, diet evolution, doctor reports, HeyCyan + AI) are mapped to Google requirements in **[roadmap-google-alignment.md](./roadmap-google-alignment.md)**. Glasses + Live API = See, Hear, Speak — strong Innovation & Multimodal UX.

---

## 9. Recommended Architecture Wording

For judges and docs, use this framing:

- **The Agent** = Gemini Live API (when integrated). Users talk to it; it sees, hears, speaks; it can be interrupted.
- **The Tool** = Our backend `POST /analyze-meal`. The agent calls it with image + user_id.
- **Tool Implementation** = Reader → Processor → Reporter pipeline. Clear separation of concerns.

This aligns with Google's "agent" terminology: the agent is the conversational interface; our backend is the tool logic.
