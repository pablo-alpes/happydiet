# HappyDiet — Deployment Scripts

Programmatic deployment for Cloud Run. **Bonus:** [Gemini Live Agent Challenge](https://geminiliveagentchallenge.devpost.com) awards points for automated deployment.

## Prerequisites

- `gcloud` CLI installed
- `gcloud auth login` and `gcloud auth application-default login` run

## Scripts

| Script | Purpose |
|-------|---------|
| `setup-gcp.sh` | Enable APIs (Vertex AI, Firestore, Cloud Run, etc.) |
| `deploy.sh` | Run tests + deploy backend to Cloud Run |
| `verify.sh` | Health check deployed service |
| `test-ci.sh` | Simulate Cloud Build test step (npm ci, test:ci, build) |
| `smoke-test.sh` | Post-deploy smoke test (health + meals) |

## Usage

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
