# HappyDiet — Deployment Scripts

Programmatic deployment for Cloud Run. See [docs/deployment-cicd.md](../docs/deployment-cicd.md) for full CI/CD pipeline documentation.

## Prerequisites

- `gcloud` CLI installed
- `gcloud auth login` and `gcloud auth application-default login` run

## Scripts

| Script | Purpose |
|-------|---------|
| `bootstrap-cloud.sh` | **Full programmatic setup** — APIs, Firestore, SA, deploy, GitHub secrets instructions |
| `setup-gcp.sh` | Enable APIs (Vertex AI, Firestore, Cloud Run, etc.) |
| `setup-production.sh` | Full production setup (APIs, Firestore DBs, .env) |
| `deploy.sh` | Run tests + deploy backend to Cloud Run (supports ENV=dev for dev) |
| `trigger-deploy.sh` | Trigger deploy when main/dev evolves (local or via GitHub API) |
| `verify.sh` | Health check deployed service |
| `test-ci.sh` | Simulate Cloud Build test step (npm ci, test:ci, build) |
| `smoke-test.sh` | Post-deploy smoke test (health + meals) |

## Usage

### Future updates (deploy latest from main)

```bash
# From repo root — use when GCP is already set up
git checkout main && git pull origin main
./scripts/deploy.sh happydiet-1-490118
./scripts/verify.sh
```

Or push to `main` — GitHub Actions deploys automatically if secrets are configured.

### Trigger deploy when main evolves

```bash
# Deploy prod locally (pull latest main first)
./scripts/trigger-deploy.sh prod --push --local

# Deploy dev locally
./scripts/trigger-deploy.sh dev --local

# Trigger via GitHub Actions (requires gh CLI)
./scripts/trigger-deploy.sh prod
```

### Quick start (full bootstrap)

```bash
# From repo root — one command for everything
chmod +x scripts/*.sh
gcloud auth login && gcloud auth application-default login
./scripts/bootstrap-cloud.sh YOUR_PROJECT_ID
# Follow output to add GitHub secrets (GCP_PROJECT_ID, GCP_SA_KEY)
```

### Step-by-step

```bash
# From repo root
chmod +x scripts/*.sh

# 1. Set project (or pass as arg)
gcloud config set project YOUR_PROJECT_ID

# 2. Setup GCP (enable APIs)
./scripts/setup-gcp.sh

# 3. Create Firestore DB
#    Console → Firestore → Create database (Native mode)

# 4. Authenticate
gcloud auth application-default login

# 5. Deploy
./scripts/deploy.sh

# 6. Verify
./scripts/verify.sh
```

## With custom project

```bash
./scripts/setup-gcp.sh my-project-id
./scripts/deploy.sh my-project-id
./scripts/verify.sh https://happydiet-backend-xxxxx-uc.a.run.app
```

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REGION` | us-central1 | Cloud Run region |
| `SERVICE_NAME` | happydiet-backend | Cloud Run service name |
