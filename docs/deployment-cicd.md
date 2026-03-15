# HappyDiet — Deployment & CI/CD

**Objective:** Deploy the backend to Google Cloud Run and ensure it runs correctly. Step-by-step instructions.

---

## Quick Start — Future Updates (Deploy from main)

**Use this when:** GCP is already set up and you want to deploy the latest code.

```bash
# From repo root
git checkout main && git pull origin main
./scripts/deploy.sh happydiet-1-490118
./scripts/verify.sh
```

**Or let CI/CD do it:** Push to `main` — GitHub Actions runs tests and deploys automatically (see [CI/CD Pipeline](#ci-cd-pipeline) below).

---

## Dev pipeline (deploy without touching prod)

**Use this when:** You want to push and deploy to a **dev** environment so prod stays unchanged.

| Branch | Deploys to | Service name |
|--------|------------|--------------|
| `dev` | Dev | `happydiet-backend-dev` |
| `main` (or `master`) | Prod | `happydiet-backend` |

**First time — create the dev branch and push it:**

```bash
chmod +x scripts/create-dev-branch.sh
./scripts/create-dev-branch.sh
```

**Then:** Push your changes to `dev` instead of `main`. GitHub Actions will run tests and deploy to **happydiet-backend-dev** only. When you’re ready for prod, merge `dev` into `main` and push.

```bash
# Daily workflow: push to dev for testing
git checkout dev
git merge main    # optional: get latest from main
# ... make changes ...
git add . && git commit -m "Your message" && git push origin dev

# When ready for prod: merge dev → main
git checkout main && git merge dev && git push origin main
```

You can also trigger a deploy from the Actions tab: **Run workflow** → choose branch `dev` or `main` and (for manual run) environment **dev** or **prod**.

---

## Current Deployment Record

| Item | Value |
|------|-------|
| **Project** | `happydiet-1-490118` |
| **Region** | `us-central1` |
| **Service (prod)** | `happydiet-backend` |
| **Service (dev)** | `happydiet-backend-dev` |
| **Prod URL** | `https://happydiet-backend-718973726500.us-central1.run.app` |
| **Firestore DBs** | `happydiet` (meals), `rules` (diet rules) |

**iOS:** Set `BACKEND_URL` in `HappyDietConfig.plist` or in-app Settings to the Service URL above.

---

## Deployment Overview

```
┌─────────────────┐     push/PR      ┌──────────────────┐     deploy      ┌─────────────────┐
│  GitHub         │ ───────────────► │  Cloud Build     │ ──────────────► │  Cloud Run      │
│  (source)       │   or Actions     │  (test + build)  │                 │  (backend)       │
└─────────────────┘                  └──────────────────┘                 └─────────────────┘
                                                                                   │
                                                                                   ▼
┌─────────────────┐     ADC           ┌──────────────────┐
│  Vertex AI      │ ◄──────────────── │  Cloud Run       │
│  Firestore      │                  │  (same project)   │
└─────────────────┘                  └──────────────────┘
```

---

## CI/CD Pipeline

HappyDiet supports two CI/CD options: **GitHub Actions** (recommended) and **Cloud Build**. Two environments: **dev** (staging) and **prod** (production).

### GitHub Actions (`.github/workflows/deploy.yml`)

| Trigger | Environment | Action |
|---------|-------------|--------|
| **Push** to `main` or `master` | prod | Tests → Deploy `happydiet-backend` → Smoke test |
| **Push** to `dev` | dev | Tests → Deploy `happydiet-backend-dev` → Smoke test |
| **Pull request** to main/dev | — | Tests only (no deploy) |
| **Manual** (`workflow_dispatch`) | prod or dev | Choose environment → Tests → Deploy → Smoke test |

**Required secrets** (Settings → Secrets and variables → Actions):

| Secret | Description |
|--------|-------------|
| `GCP_PROJECT_ID` | GCP project ID (e.g. `happydiet-1-490118`) |
| `GCP_SA_KEY` | Service account JSON key (contents of `scripts/.cicd-sa-key.json`) |

**Pipeline steps:**
1. Checkout code
2. Setup Node.js 20, install deps (`npm ci`)
3. Run tests (`npm run test:ci`) — **must pass before deploy**
4. Upload test results artifact
5. *(On push/manual only)* Authenticate to GCP, deploy to Cloud Run, smoke test `/health`

**To add secrets (recommended):** Run `./scripts/setup-github-secrets.sh` — uses existing key and `gh` to add secrets securely. One-time: `gh auth login` first.

**Alternative:** Run `./scripts/bootstrap-cloud.sh PROJECT_ID` — creates the key, then copy `scripts/.cicd-sa-key.json` into `GCP_SA_KEY` in GitHub.

### Trigger deployment when main evolves

| Method | Command |
|--------|---------|
| **Automatic** | Push to `main` (prod) or `dev` (dev) — pipeline runs automatically |
| **Manual (local)** | `./scripts/trigger-deploy.sh prod --local` or `./scripts/trigger-deploy.sh dev --local` |
| **Manual (GitHub API)** | `./scripts/trigger-deploy.sh prod` (requires `gh` CLI) |
| **Pull latest + deploy** | `./scripts/trigger-deploy.sh prod --push --local` |

### Cloud Build (`cloudbuild.yaml`)

| Trigger | Action |
|---------|--------|
| `gcloud builds submit` or Cloud Build trigger on push | Run tests → Deploy to Cloud Run |

**Location:** Repo root. Steps run in `backend/` via `dir: backend`.

**Substitutions:** `_REGION` (us-central1), `_SERVICE_NAME` (happydiet-backend). `PROJECT_ID` is provided by Cloud Build.

**To run manually:**
```bash
gcloud builds submit --config cloudbuild.yaml .
```

**To connect GitHub:** [Cloud Build → Repositories](https://console.cloud.google.com/cloud-build/repositories) → Connect repo → Create trigger for push to `main`, config path `cloudbuild.yaml`.

### Environment Variables Passed to Cloud Run

| Variable | Required | Source |
|----------|----------|--------|
| `GOOGLE_CLOUD_PROJECT` | Yes | Project ID |
| `GOOGLE_CLOUD_LOCATION` | No (default us-central1) | Region |
| `FIRESTORE_DATABASE_MEALS` | No (default happydiet) | `backend/.env` |
| `FIRESTORE_DATABASE_RULES` | No (default rules) | `backend/.env` |
| `API_KEY` | No | `backend/.env` (optional) |
| `VERTEX_AI_MODEL` | No | Default `gemini-2.5-flash` in code |

**Region:** One place controls it: `GOOGLE_CLOUD_LOCATION` (default `us-central1`). It is used for Vertex AI (vision, semantic) and for the Live API WebSocket URL. Cloud Build sets it from `_REGION` (us-central1). No need to set a different region elsewhere.

**Model:** Backend uses `gemini-2.5-flash` by default; Live API uses `gemini-live-2.5-flash-native-audio`. Both are set in code; no override in Cloud Build.

The `deploy.sh` script reads `backend/.env` and forwards env vars to Cloud Run. GitHub Actions and Cloud Build use project/region only; add Firestore DB names via `.env` if using non-default DBs.

### How we ensure CI/CD

| Guarantee | How |
|-----------|-----|
| **Tests before deploy** | `test` job runs first; `deploy` jobs `need: test`. If tests fail, deploy never runs. |
| **Two environments** | dev (staging) and prod (production) — test changes in dev before merging to main. |
| **Automatic on push** | Push to `main` or `dev` triggers the pipeline; no manual step required. |
| **Smoke test after deploy** | Each deploy runs `curl /health`; fails the job if unhealthy. |
| **Manual trigger** | `workflow_dispatch` or `./scripts/trigger-deploy.sh` for on-demand deploys. |

**Verification:** After setup, push a small change to `main` and confirm the Actions tab shows: Test → Deploy to Prod → Smoke test. Same for `dev` branch.

**Create dev branch (if needed):** `git checkout -b dev && git push -u origin dev` — then pushes to `dev` deploy to the dev environment.

---

## 0. Full Programmatic Bootstrap (Recommended)

One command to set up GCP, deploy, and prepare CI/CD:

```bash
# Prerequisites: gcloud CLI, gcloud auth login, gcloud auth application-default login
chmod +x scripts/*.sh
./scripts/bootstrap-cloud.sh YOUR_PROJECT_ID
```

This script:

1. Enables APIs (Vertex AI, Firestore, Cloud Run, etc.)
2. Creates Firestore database
3. Creates `happydiet-cicd` service account
4. Generates SA key for GitHub Actions
5. Deploys backend to Cloud Run
6. Outputs instructions for GitHub secrets

**GitHub Actions setup:** Add these secrets to your repo (Settings → Secrets → Actions):

| Secret | Value |
|--------|-------|
| `GCP_PROJECT_ID` | Your GCP project ID |
| `GCP_SA_KEY` | Contents of `scripts/.cicd-sa-key.json` (from bootstrap output) |

After adding secrets, push to `main` or `master` to trigger deploy.

**Optional — Cloud Build trigger:** If your repo is connected to Cloud Build, create trigger:

```bash
GITHUB_REPO_OWNER=your-org GITHUB_REPO_NAME=happydiet ./scripts/bootstrap-cloud.sh YOUR_PROJECT_ID
```

---

## 1. Prerequisites

| Item | Status |
|------|--------|
| GCP project | Create with `gcloud projects create` or use existing |
| Billing enabled | [Console → Billing](https://console.cloud.google.com/billing) |
| gcloud CLI | [Install](https://cloud.google.com/sdk/docs/install) |
| APIs enabled | See §2 below |

---

## 2. Enable APIs (One-Time)

```bash
# Set your project
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable \
  aiplatform.googleapis.com \
  firestore.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com
```

### Create Firestore Database

1. [Console → Firestore](https://console.cloud.google.com/firestore)
2. **Create database** → Native mode → Region (e.g. `us-central1`)

---

## 3. Authenticate

```bash
gcloud auth login
gcloud auth application-default login
```

---

## 4. Deploy Backend to Cloud Run

### Option A: Programmatic (Scripts) — Recommended

```bash
# From repo root
chmod +x scripts/*.sh
./scripts/setup-gcp.sh              # Enable APIs (one-time)
./scripts/deploy.sh                 # Tests + deploy
./scripts/verify.sh                 # Health check
```

See [scripts/README.md](../scripts/README.md). **Bonus:** Automated deployment qualifies for challenge bonus points.

### Option B: Manual Deploy

```bash
# From project root
cd backend

# Deploy with Cloud Build (builds + test + deploy)
gcloud run deploy happydiet-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars "GOOGLE_CLOUD_PROJECT=$(gcloud config get-value project)"
```

**Important:** `GOOGLE_CLOUD_PROJECT` is required for Vertex AI and Firestore. Without it, `/analyze-meal` returns 503.

### Option B: With Additional Env Vars

```bash
gcloud run deploy happydiet-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars "GOOGLE_CLOUD_PROJECT=$(gcloud config get-value project),GOOGLE_CLOUD_LOCATION=us-central1"
```

### Option C: Cloud Build (CI/CD)

```bash
# From project root (happydiet/)
gcloud builds submit --config cloudbuild.yaml .
```

**Note:** This runs tests and deploys. The `cloudbuild.yaml` uses `PROJECT_ID` automatically. See §7.

### Option D: GitHub Actions (CI/CD)

Push to `main` or `master` triggers deploy automatically. Requires secrets `GCP_PROJECT_ID` and `GCP_SA_KEY`. See §0.

---

## 5. Verify Deployment

### Smoke Test (Recommended)

```bash
./scripts/smoke-test.sh https://YOUR-Cloud-Run-URL
# Or: ./scripts/smoke-test.sh  (fetches URL from gcloud)
```

Tests: GET /health (200), GET /meals (200).

### Manual Check

After deploy, Cloud Run returns the service URL:

```
Service [happydiet-backend] revision [...] has been deployed and is serving 100 percent of traffic.
Service URL: https://happydiet-backend-XXXXX-uc.a.run.app
```

### Health Check

```bash
curl https://YOUR-Cloud-Run-URL/health
# Expected: {"status":"ok","service":"happydiet-backend"}
```

### Analyze Meal (Requires Image)

```bash
# Base64-encode a small test image first
curl -X POST https://YOUR-Cloud-Run-URL/analyze-meal \
  -H "Content-Type: application/json" \
  -d '{"image_base64":"BASE64_STRING","user_id":"demo"}'
```

---

## 6. Update iOS App

Edit `ios/HappyDiet/HappyDietConfig.plist`:

- Set `BACKEND_URL` to your Cloud Run URL (e.g. `https://happydiet-backend-xxxxx-uc.a.run.app`)

---

## 7. CI/CD with Cloud Build

### 7.1 cloudbuild.yaml Location

The config is at **repo root**: `cloudbuild.yaml`

It runs tests in `backend/` and deploys from `backend/`. Cloud Build provides `PROJECT_ID` automatically. Substitutions `_REGION` and `_SERVICE_NAME` are configurable.

### 7.2 Connect GitHub to Cloud Build

1. [Cloud Build → Repositories](https://console.cloud.google.com/cloud-build/repositories)
2. **Connect repository** → GitHub (Cloud Build GitHub App)
3. Select org/repo and `happydiet`

### 7.3 Create Trigger

1. [Cloud Build → Triggers](https://console.cloud.google.com/cloud-build/triggers)
2. **Create trigger**
3. **Event:** Push to branch `main`
4. **Source:** Connected repo
5. **Config:** Cloud Build configuration file
6. **Config path:** `cloudbuild.yaml` (at repo root)

**Important:** Cloud Build runs from the repo root. The config uses `dir: backend` so steps run in the backend folder. The `--source .` in the deploy step deploys the backend directory.

---

## 8. CI Test Simulation (Pre-Deploy)

To verify the same steps Cloud Build runs:

```bash
./scripts/test-ci.sh
```

Runs: `npm ci` → `npm run test:ci` → `npm run build`. See [testing.md](./testing.md).

---

## 9. Checklist: Ensure Deployment Works

| Step | Action |
|------|--------|
| 1 | `gcloud config set project YOUR_PROJECT_ID` |
| 2 | Enable APIs (§2) or run `./scripts/setup-gcp.sh` |
| 3 | Create Firestore database: `./scripts/setup-production.sh` or [Console](https://console.cloud.google.com/firestore) |
| 4 | `gcloud auth application-default login` |
| 5 | Deploy: `./scripts/deploy.sh YOUR_PROJECT_ID` (from repo root) |
| 6 | Verify: `./scripts/verify.sh` or `curl https://YOUR-URL/health` |
| 7 | Update iOS `BACKEND_URL` to Cloud Run URL |
| 8 | (Optional) Add GitHub secrets `GCP_PROJECT_ID`, `GCP_SA_KEY` for automatic deploys on push to main |

---

## 10. Script Behavior

Deployment scripts use `--quiet` on gcloud commands to avoid interactive prompts (e.g. "Do you want to continue (Y/n)?"). If a command still prompts, answer `Y` or run with `yes | ./scripts/deploy.sh PROJECT_ID`.

- **deploy.sh:** Runs from repo root; uses `backend/.env` for Firestore DBs and optional vars
- **bootstrap-cloud.sh:** One-time setup; skips auth if already authenticated
- **setup-production.sh:** Creates `(default)` Firestore DB first, then `happydiet` and `rules`

---

## 11. Troubleshooting

| Issue | Fix |
|-------|-----|
| **Works locally, fails on Cloud** | **Identity:** locally you use your user (e.g. `gcloud auth application-default login`); Cloud Run uses the default compute service account. Same code, same region, same model. Grant that compute SA `roles/aiplatform.user` and `roles/datastore.user` via the "Cloud Run runtime identity" block in `scripts/serviceaccount.sh`. |
| 503 from `/analyze-meal` | Set `GOOGLE_CLOUD_PROJECT` on Cloud Run |
| 404 "model not found" on Cloud | Grant Cloud Run's compute SA `roles/aiplatform.user`; ensure Vertex AI API is enabled. We use `gemini-2.5-flash` in `us-central1` (set via `GOOGLE_CLOUD_LOCATION`). No need to switch to 2.0. |
| Permission denied | Ensure Cloud Run service account (compute SA) has `roles/aiplatform.user` and `roles/datastore.user` |
| Build fails | Check `npm run test:ci` passes locally in `backend/` |
| Deploy from wrong dir | Run `./scripts/deploy.sh` from repo root (it uses `backend/` internally) |
| Firestore DB errors | Run `./scripts/setup-production.sh` to create DBs; or create manually in [Console](https://console.cloud.google.com/firestore) |

### Using logs to find where analyze-meal fails

After deploying, trigger an analyze-meal request and open **Cloud Run → Logs** (or `gcloud run services logs read happydiet-backend --region=us-central1`). Look for `[analyze-meal]` and `[vertex-ai]`:

1. **Request start** — `[analyze-meal] <requestId> request start | content-length=... hasBody=... bodyKeys=[...]`  
   - If `hasBody=false` or body is empty: body parser failed (payload too large or invalid JSON). Reduce image size or check client sends JSON.
2. **Body ok** — `[analyze-meal] <requestId> body ok | userId=... imageBase64Len=...`  
   - Confirms the handler received the image.
3. **Stage = reader start** — next step is Vertex Vision.  
   - If you see **`[vertex-ai] analyzeImage request start`** but no **`analyzeImage generateContent done`**: failure is inside Vertex (network, IAM, model, or timeout). Check `[vertex-ai] analyzeImage generateContent failed after X ms` for the error.
4. **Stage = reader done** — Vision succeeded. If the failure is later, you’ll see **stage=processor start** and then either **stage=processor done** or an error (e.g. Firestore).
5. **Failed after Xms** — `[analyze-meal] <requestId> failed after Xms` plus the error. Use the same `requestId` to match all log lines for that request.

The frontend uses a **60s timeout**; if the backend is slow or stuck, you’ll see “Request timed out” and the logs will show how far the request got (e.g. reader start but no reader done = Vertex call hanging or erroring).

---

## 12. Terraform (Optional IaC)

For infrastructure-as-code, use Terraform:

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with project_id
terraform init && terraform apply
```

See [infra/terraform/README.md](../infra/terraform/README.md).

---

## 13. Summary

| Question | Answer |
|----------|--------|
| **How to deploy?** | `gcloud run deploy happydiet-backend --source backend --region us-central1 --allow-unauthenticated --set-env-vars GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID` |
| **Required env vars?** | `GOOGLE_CLOUD_PROJECT` (required); `GOOGLE_CLOUD_LOCATION` (optional, default us-central1) |
| **Where is cloudbuild.yaml?** | Repo root; steps run in `backend/` |
| **How to verify?** | `curl https://YOUR-URL/health` |
| **Full bootstrap?** | `./scripts/bootstrap-cloud.sh PROJECT_ID` |
| **GitHub Actions?** | Add `GCP_PROJECT_ID`, `GCP_SA_KEY` secrets; push to main |
