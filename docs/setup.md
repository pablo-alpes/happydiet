# HappyDiet — Setup & Deployment

**Objective:** Prerequisites, environment setup, and deployment steps to run the full architecture.

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| **Google Cloud SDK** | Latest | `gcloud` CLI for GCP |
| **Node.js** | 20 LTS | Backend runtime |
| **Xcode** | 15+ (16+ recommended) | iOS app (Swift/SwiftUI) |
| **XcodeGen** | Latest | Generate iOS Xcode project (`brew install xcodegen`) |
| **Homebrew** | Latest | Install XcodeGen on macOS |
| **Git** | — | Version control |

---

## 1. Google Cloud Setup

### 1.1 Create Project

```bash
gcloud projects create happydiet-PROJECT_ID --name="HappyDiet"
gcloud config set project happydiet-PROJECT_ID
```

### 1.2 Enable Billing

- Go to [Cloud Console](https://console.cloud.google.com) → Billing
- Link a billing account to the project

### 1.3 Enable APIs

APIs requises pour l'architecture HappyDiet (voir stack-architecture.md) :

| API | Usage |
|-----|-------|
| **Vertex AI** | Vision (analyse repas → ingrédients, kcal) dans le backend |
| **Cloud Run** | Hébergement du backend (tool endpoints) |
| **Firestore** | Base de données (meals, diet_rules) |
| **Cloud Build** | Build du container lors de `gcloud run deploy --source` |
| **Artifact Registry** | Stockage des images Docker pour Cloud Run |

**Note :** Le **Gemini Live API** (voice + vision côté iOS) utilise Google AI Studio (clé API) — pas d’API GCP à activer pour celui-ci.

### Mapping des capacités AI → APIs

| Capacité | API / Service | Où |
|----------|--------------|-----|
| **Vision (image → structured data)** | Vertex AI Gemini | Backend : analyse repas → ingrédients, kcal |
| **OCR / Règles depuis image** | Vertex AI Gemini (multimodal) | Backend : parsing image régime → règles structurées |
| **LLM (traitement, réponses)** | Vertex AI Gemini | Backend : structured output, logique |
| **Text → Audio (TTS)** | Gemini Live API | Intégré : reçoit JSON → génère parole directement (pas de TTS séparé) |
| **Voice I/O + Vision input** | Gemini Live API | iOS : mic, caméra, WebSocket, speaker |

Tout est couvert par **Vertex AI** (aiplatform) côté backend et **Gemini Live API** (Google AI) côté client. Aucune API supplémentaire (Cloud Vision, Cloud TTS) n'est requise.

Voir **[gcp-integration.md](./gcp-integration.md)** pour les détails d'intégration Vertex AI, Firestore et Cloud Run.

```bash
gcloud services enable \
  aiplatform.googleapis.com \
  firestore.googleapis.com \
  texttospeech.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com
```

Or run `./scripts/setup-gcp.sh` to enable all APIs (including Text-to-Speech).

### 1.4 Authentication & Codes d'accès

#### GCP (gcloud)

```bash
gcloud auth login
gcloud auth application-default login
```

#### Récapitulatif des codes d'accès

| Variable / Clé | Où l'obtenir | Usage |
|----------------|--------------|-------|
| **GCP Project ID** | Console Cloud → Sélection du projet | `GOOGLE_CLOUD_PROJECT` |
| **API Key (Backend)** | Générer un secret partagé (ex. `openssl rand -hex 32`) | Authentification des appels outil Live API → Backend |
| **GEMINI_API_KEY** | [Google AI Studio](https://aistudio.google.com/apikey) | Live API (Gemini) côté client |
| **Service Account** | Console → IAM → Comptes de service | Vertex AI / Firestore (alternative à API key) |

#### Obtenir une clé API Gemini

1. Aller sur [Google AI Studio](https://aistudio.google.com/apikey)
2. Créer une clé API
3. Copier la clé dans `GEMINI_API_KEY` (iOS) ou `.env` (backend)

#### Générer une API Key pour le Backend

```bash
# Générer un secret pour les appels outil (Live API → Backend)
openssl rand -hex 32
```

Utiliser cette valeur pour `API_KEY` dans le backend et l'app iOS.

### 1.5 Firestore

- Console → Firestore → Create database
- Choose **Native mode**
- Select region (e.g. `us-central1`)

**Or run the production setup script** (enables APIs, creates Firestore DBs, generates `.env`):

```bash
./scripts/setup-production.sh YOUR_PROJECT_ID
```

---

## 2. Backend Setup

### 2.1 Local Development

**Option A — npm (direct):**
```bash
cd backend
npm install
npm run dev
```

**Option B — Docker (modular):**
```bash
# Production build
docker compose up

# Dev mode (hot reload)
docker compose -f docker-compose.dev.yml up
```

Backend runs at `http://localhost:8080`. Test UI: `http://localhost:8080/test.html`.

**Project structure:** Follow DDD layout (`domain/`, `application/`, `infrastructure/`). See design.md.

### 2.2 Environment Variables & Secrets

**Local dev:** Create `.env` (do not commit). Voir Annexe B pour la liste complète des fichiers à ignorer.

```bash
# .env — voir section 1.4 pour l'obtention des clés
GOOGLE_CLOUD_PROJECT=happydiet-PROJECT_ID
GOOGLE_CLOUD_LOCATION=us-central1
BACKEND_URL=https://YOUR-CLOUD-RUN-URL.run.app
API_KEY=<générer avec: openssl rand -hex 32>
```

**Cloud Run:** Use Secret Manager or `--set-env-vars`; never commit secrets. See design.md.

### 2.4 Run Locally

```bash
npm run dev   # or: uvicorn main:app --reload
```

Backend runs at `http://localhost:8080` (or configured port).

### 2.5 Run Tests Before Deploy (TDD: Deployment)

```bash
# Backend
cd backend && npm test   # or: pytest

# iOS (if applicable)
cd ios && xcodebuild test -scheme HappyDiet -destination 'platform=iOS Simulator,name=iPhone 16'
```

Tests must pass before deploying. **TDD: all layers (backend + iOS), no exceptions.** See design.md.

### 2.6 Deploy to Cloud Run

```bash
cd backend   # or from project root:
gcloud run deploy happydiet-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated
```

From project root: `gcloud run deploy happydiet-backend --source backend --region us-central1`

**Or with Docker (modular):**
```bash
cd backend
docker build -t happydiet-backend .
docker tag happydiet-backend gcr.io/PROJECT_ID/happydiet-backend
docker push gcr.io/PROJECT_ID/happydiet-backend
gcloud run deploy happydiet-backend --image gcr.io/PROJECT_ID/happydiet-backend --region us-central1
```

**Or deploy pre-built image:**
```bash
gcloud run deploy happydiet-backend \
  --image gcr.io/PROJECT_ID/happydiet-backend \
  --region us-central1 \
  --set-env-vars GOOGLE_CLOUD_PROJECT=PROJECT_ID
```

**Note:** Set `BACKEND_URL` in iOS app to the Cloud Run URL after deployment.

---

## 3. iOS App Setup

### 3.1 Requirements

| Tool | Version | Purpose |
|------|---------|---------|
| **Xcode** | 15+ (16+ recommended) | Build and run the app |
| **XcodeGen** | Latest | Generate Xcode project from `project.yml` |
| **Homebrew** | Latest | Install XcodeGen (`brew install xcodegen`) |
| **iOS** | 17+ | Deployment target (simulator or device) |

Apple Developer account required only for running on a **physical device**.

### 3.2 Install XcodeGen

The iOS project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project from `ios/project.yml`.

```bash
# Install Homebrew if needed: https://brew.sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install XcodeGen
brew install xcodegen
```

### 3.3 Generate Xcode Project and Open

From the **repo root**:

```bash
cd ios
xcodegen generate
open -a Xcode HappyDiet.xcodeproj
```

**Important:** Use `open -a Xcode` (not `open` alone). Plain `open` may open Finder instead of Xcode.

Or in one line from repo root:

```bash
cd ios && xcodegen generate && open -a Xcode HappyDiet.xcodeproj
```

This creates `HappyDiet.xcodeproj` and opens it in Xcode. **Re-run `xcodegen generate`** whenever `project.yml` or source files change.

### 3.4 Configure Backend URL

Edit `ios/HappyDiet/HappyDietConfig.plist`:

| Scenario | BACKEND_URL |
|----------|-------------|
| **Simulator** (default) | `http://localhost:8080` |
| **Physical iPhone** | `http://YOUR_MAC_IP:8080` (e.g. `http://192.168.1.5:8080`) |
| **Production** | `https://YOUR-CLOUD-RUN-URL.run.app` |

**To find your Mac's IP:**

- macOS: System Settings → Network → Wi‑Fi → Details → IP Address
- Or: `ipconfig getifaddr en0` (Wi‑Fi) or `ipconfig getifaddr en1`

**For physical iPhone:** Mac and iPhone must be on the same Wi‑Fi.
**API_KEY:** Optional. Set if your backend requires `X-API-Key` header (same value as backend `.env`).

### 3.5 Run the Backend First

The app needs the backend running. In a **separate terminal**:

```bash
cd backend
npm install
npm run dev
```

You should see: `HappyDiet backend listening on port 8080`. Ensure `backend/.env` has `GOOGLE_CLOUD_PROJECT` set for Vertex AI and Firestore.

### 3.6 Run the App

**Option A — Simulator (easiest):**

1. In Xcode, select a simulator from the device menu (e.g. **iPhone 16**).
2. Press **⌘R** (or click the Run ▶ button).
3. The app launches in the simulator. It uses `http://localhost:8080` by default.

**Option B — Physical iPhone:**

1. Connect the iPhone via USB.
2. In Xcode, select your device from the device menu.
3. Press **⌘R**.
4. If prompted: on the iPhone, go to Settings → General → VPN & Device Management → trust the developer certificate.
5. Ensure `BACKEND_URL` in `HappyDietConfig.plist` is your Mac's IP (e.g. `http://192.168.1.5:8080`).

### 3.7 App Surfaces

The iOS app has three tabs:

- **Analyze** — Capture meal (camera or photo library) → analyze → compliance score + TTS
- **Diet** — Enter or capture diet rules, parse, save to backend
- **Dashboard** — Meal history, compliance scores

### 3.8 Troubleshooting iOS

| Issue | Fix |
|-------|-----|
| "No such module" or project won't build | Run `cd ios && xcodegen generate` again |
| "Backend not configured" / 503 | Start backend (`npm run dev` in `backend/`); set `GOOGLE_CLOUD_PROJECT` in `.env` |
| "Could not connect" on phone | Use Mac's IP in `BACKEND_URL`; same Wi‑Fi |
| Camera not working | Check Info.plist permissions; grant in Settings |
| XcodeGen not found | `brew install xcodegen` |
| `open` opens Finder instead of Xcode | Always use `open -a Xcode HappyDiet.xcodeproj` (the `-a Xcode` forces Xcode) |
| "Missing bundle ID" / app won't launch | Use **iPhone Simulator** (not physical device). Or: Xcode → Signing & Capabilities → select your Team. |

---

## 4. Deployment Order

**Local development (full stack):**

1. **GCP** — Project, APIs, Firestore, `gcloud auth application-default login`
2. **Backend** — `cd backend && npm install && npm run dev`
3. **iOS** — `cd ios && xcodegen generate && open -a Xcode HappyDiet.xcodeproj` → select simulator → ⌘R

**Production:**

1. **GCP** — `./scripts/setup-production.sh PROJECT_ID`
2. **Backend** — `./scripts/deploy.sh`
3. **iOS** — Set `BACKEND_URL` in `HappyDietConfig.plist` to Cloud Run URL → build and run

---

## 5. Verification

| Check | How |
|-------|-----|
| Tests pass | `npm test` or `pytest` before deploy |
| Backend health | `curl https://YOUR-URL.run.app/health` |
| Firestore | Console → Firestore → Check `meals` collection |
| iOS → Backend | Send meal from app; verify tool call in backend logs |
| Live API | Speak + show photo; hear coach reply |

---

## 6. Hackathon Submission (GCP Proof)

For judges:

1. **Screen recording** — Cloud Run console, logs, Firestore with meal data
2. **Or** — Link to code file showing Vertex AI / Firestore API calls
3. **Demo video** — iOS app in action; voice + vision + barge-in

---

## Annexe A — Sélection et configuration du projet GCP

Si le projet créé n’apparaît pas dans la console ou si tu dois utiliser un projet existant :

### Lister les projets disponibles

```bash
gcloud projects list
```

### Définir le projet actif

```bash
gcloud config set project YOUR_PROJECT_ID
```

### Vérifier le projet actif

```bash
gcloud config get-value project
```

### Si le projet n’apparaît pas dans la console

- Attendre quelques minutes après la création
- Rafraîchir la page (F5)
- Vérifier le compte connecté : `gcloud auth list`
- Vérifier le bon compte dans la console (avatar en haut à droite)

### Créer un projet avec ID unique

```bash
# L’ID doit être unique dans tout GCP — un timestamp évite les conflits
gcloud projects create happydiet-$(date +%s) --name="HappyDiet"

# Puis le sélectionner
gcloud config set project happydiet-<timestamp>
```

---

## Annexe B — Fichiers à ignorer (.gitignore)

Ne jamais committer les éléments suivants. Le fichier `.gitignore` à la racine du projet les exclut déjà.

| Catégorie | Fichiers / dossiers |
|-----------|---------------------|
| **Secrets & env** | `.env`, `.env.*`, `*.pem`, `*.key`, `credentials.json`, `service-account*.json` |
| **Dependencies** | `node_modules/`, `__pycache__/`, `venv/`, `.venv/` |
| **Build** | `dist/`, `build/`, `*.egg-info/` |
| **IDE / OS** | `.idea/`, `.vscode/`, `.DS_Store` |
| **Logs** | `*.log`, `tmp/`, `temp/` |
| **iOS** | `DerivedData/`, `*.xcuserstate` |
| **Tests** | `.coverage`, `.pytest_cache/` |
| **Docker** | (aucun — `docker-compose*.yml` et `Dockerfile` sont commités) |

**Exception :** `.env.example` (template sans valeurs sensibles) peut être commité pour documenter les variables requises.

---

## Annexe C — CI/CD avec Google Cloud

Garantir que les interactions avec le backend GCP fonctionnent correctement avant et après déploiement.

### Tests avant deploy (obligatoire)

```bash
cd backend
npm test        # Local — pas de rapport fichier
npm run test:ci # CI — produit JUnit (test-results/junit.xml) et JSON
# Aucun deploy si les tests échouent
```

**Rapports :** En CI (`CI=1`), Vitest génère `test-results/junit.xml` pour les dashboards et l’historique.

### Pipeline Cloud Build

Le fichier `cloudbuild.yaml` à la racine du projet :

1. `npm ci` — installe les dépendances
2. `npm run test:ci` — exécute unit + integration + E2E ; produit JUnit
3. `gcloud run deploy` — ne s’exécute que si les tests passent (`waitFor: ['test']`)

Déclencher : `gcloud builds submit --config cloudbuild.yaml .`

### Smoke tests post-deploy

Après déploiement, vérifier que le backend répond :

```bash
# Health check
curl https://YOUR-CLOUD-RUN-URL.run.app/health

# Analyse (image base64 en base64)
curl -X POST https://YOUR-CLOUD-RUN-URL.run.app/analyze-meal \
  -H "Content-Type: application/json" \
  -H "X-API-Key: YOUR_API_KEY" \
  -d '{"image_base64":"...","user_id":"demo"}'
```

### Tests d’intégration GCP

| Test | Outil | Objectif |
|------|-------|----------|
| Vertex AI client | Mock ou contract test | Vérifier format d’appel et parsing |
| Firestore | Emulator ou mock | Vérifier read/write, schéma |
| Cloud Run | `curl /health` | Vérifier disponibilité |
| End-to-end | `curl /analyze-meal` | Vérifier flux complet (Vision → rules → Firestore) |

Voir design.md section « Testing GCP / Google Cloud Interactions ».

---

## Annexe D — Si quelque chose manque (checklist)

### Tests échouent

| Action | Commande / vérification |
|--------|-------------------------|
| Lancer les tests | `cd backend && npm test` |
| Vérifier les logs | Les erreurs s’affichent dans la sortie |
| Corriger puis relancer | Ne pas merger tant que les tests échouent |
| TDD : test d’abord | Écrire le test avant l’implémentation |

### Rapport JUnit absent

| Action | Vérification |
|--------|--------------|
| Variable CI | `CI=1` doit être définie (ou `npm run test:ci`) |
| Dossier test-results | Créé automatiquement par `test:ci` |
| Fichier | `backend/test-results/junit.xml` après `npm run test:ci` |

### Docker build échoue

| Action | Vérification |
|--------|--------------|
| Tests avant build | Le Dockerfile exécute `npm run test:ci` ; si les tests échouent, le build s’arrête |
| Lancer les tests localement | `cd backend && npm test` |
| Vérifier .dockerignore | `tests/` et `test-results/` ne sont pas exclus (sauf si voulu) |

### Cloud Build échoue

| Action | Vérification |
|--------|--------------|
| Projet GCP | `gcloud config get-value project` |
| APIs activées | Vertex AI, Cloud Run, Firestore, Cloud Build, Artifact Registry |
| Permissions | Le compte de service Cloud Build doit pouvoir déployer sur Cloud Run |

### Variables d’environnement manquantes

| Variable | Où | Usage |
|----------|-----|-------|
| `GOOGLE_CLOUD_PROJECT` | `.env` | Obligatoire pour Vertex AI et Firestore |
| `GOOGLE_CLOUD_LOCATION` | `.env` | Région (ex. `us-central1`) |
| `API_KEY` | `.env` | Optionnel ; authentification des appels outil |

### Règle de vérification

**Après chaque prompt ou feature :** exécuter `npm test` ; si les tests échouent, corriger avant de continuer.
