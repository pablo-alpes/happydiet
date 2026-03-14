# HappyDiet — Deployment & CI/CD

**Objective:** Deploy the backend to Google Cloud Run and ensure it runs correctly. Step-by-step instructions.

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
| 2 | Enable APIs (§2) |
| 3 | Create Firestore database |
| 4 | `gcloud auth application-default login` |
| 5 | Deploy: `gcloud run deploy happydiet-backend --source backend --region us-central1 --allow-unauthenticated --set-env-vars GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID` |
| 6 | Verify: `curl https://YOUR-URL/health` |
| 7 | Update iOS `BACKEND_URL` to Cloud Run URL |
| 8 | (Optional) Connect GitHub + create trigger, or use GitHub Actions with `GCP_PROJECT_ID` + `GCP_SA_KEY` |

---

## 10. Troubleshooting

| Issue | Fix |
|-------|-----|
| 503 from `/analyze-meal` | Set `GOOGLE_CLOUD_PROJECT` on Cloud Run |
| Permission denied | Ensure Cloud Run service account has `roles/aiplatform.user` and Firestore access |
| Build fails | Check `npm run test:ci` passes locally |
| Deploy from wrong dir | Use `--source backend` when running from repo root |

---

## 11. Terraform (Optional IaC)

For infrastructure-as-code, use Terraform:

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with project_id
terraform init && terraform apply
```

See [infra/terraform/README.md](../infra/terraform/README.md).

---

## 12. Summary

| Question | Answer |
|----------|--------|
| **How to deploy?** | `gcloud run deploy happydiet-backend --source backend --region us-central1 --allow-unauthenticated --set-env-vars GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID` |
| **Required env vars?** | `GOOGLE_CLOUD_PROJECT` (required); `GOOGLE_CLOUD_LOCATION` (optional, default us-central1) |
| **Where is cloudbuild.yaml?** | Repo root; steps run in `backend/` |
| **How to verify?** | `curl https://YOUR-URL/health` |
| **Full bootstrap?** | `./scripts/bootstrap-cloud.sh PROJECT_ID` |
| **GitHub Actions?** | Add `GCP_PROJECT_ID`, `GCP_SA_KEY` secrets; push to main |
