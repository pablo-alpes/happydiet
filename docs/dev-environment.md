# HappyDiet — Dev Environment (Real GCP)

**Objective:** Run the tool in motion with **real** Vertex AI and Firestore.

---

## Quick Start

```bash
cd backend
# 1. Set .env: GOOGLE_CLOUD_PROJECT=your-project-id
# 2. Run: gcloud auth application-default login
# 3. Enable APIs: ./scripts/setup-gcp.sh
# 4. Create Firestore database (Console)
npm run dev
```

Open **http://localhost:8080/dev.html** — upload a meal image and get real Vision analysis.

---

## Dev Playground (`/dev.html`)

| Feature | Description |
|---------|-------------|
| **Analyze Meal** | Upload image → real Vertex AI → compliance score, message, ingredients, suggestions |
| **Dashboard** | View meal history from Firestore |

### Flow

1. **Upload** — Drop or click to select a meal image
2. **Analyze** — Click "Analyze Meal" → Vertex AI + rule engine returns compliance
3. **Result** — Score badge, message, compliant/non-compliant items, suggestions
4. **Dashboard** — Switch tab → see persisted meals from Firestore

---

## Real Backend (GCP)

```bash
cd backend
# Prerequisites: .env with GOOGLE_CLOUD_PROJECT, gcloud auth application-default login
npm run dev
```

Open **http://localhost:8080/dev.html** — real Vertex AI Vision, real Firestore.

---

## Mock Mode (Fallback)

If you can't use GCP yet: `npm run dev:demo` runs on port 8081 with mock Vision. Use `http://localhost:8081/dev.html`.

---

## URLs

| URL | Purpose |
|-----|---------|
| http://localhost:8080/dev.html | Dev playground (**real GCP**) |
| http://localhost:8080/test.html | Raw API test |
| http://localhost:8080/health | Health check |

---

## Mobile Testing

With `npm run dev` running, use your Mac's IP for phone testing:

1. Find IP: `ifconfig | grep "inet "` (e.g. 192.168.1.5)
2. On phone browser: http://192.168.1.5:8080/dev.html
3. Upload image from phone camera/library
