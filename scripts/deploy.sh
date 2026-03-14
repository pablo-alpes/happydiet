#!/usr/bin/env bash
# HappyDiet — Deploy backend to Cloud Run
# Run from repo root: ./scripts/deploy.sh [PROJECT_ID]
# Or: ./scripts/deploy.sh (uses gcloud config project)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ID="${1:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${REGION:-us-central1}"
SERVICE_NAME="${SERVICE_NAME:-happydiet-backend}"

if [[ -z "$PROJECT_ID" ]]; then
  echo "Usage: $0 PROJECT_ID"
  echo "  Or set project: gcloud config set project YOUR_PROJECT_ID"
  exit 1
fi

echo "=== HappyDiet Deploy ==="
echo "Project: $PROJECT_ID"
echo "Region:  $REGION"
echo "Service: $SERVICE_NAME"
echo ""

# Run tests first
echo "Running tests..."
cd "$REPO_ROOT/backend"
npm ci
npm run test:ci

# Load .env for optional vars (Firestore DBs, API_KEY)
ENV_FILE="$REPO_ROOT/backend/.env"
ENV_VARS="GOOGLE_CLOUD_PROJECT=$PROJECT_ID,GOOGLE_CLOUD_LOCATION=$REGION"
if [[ -f "$ENV_FILE" ]]; then
  for key in FIRESTORE_DATABASE_MEALS FIRESTORE_DATABASE_RULES API_KEY VERTEX_AI_MODEL; do
    val=$(grep -E "^${key}=" "$ENV_FILE" 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d "'")
    if [[ -n "$val" && "$val" != "your-project-id" ]]; then
      ENV_VARS="$ENV_VARS,${key}=${val}"
    fi
  done
fi

# Deploy
echo ""
echo "Deploying to Cloud Run..."
gcloud run deploy "$SERVICE_NAME" \
  --source . \
  --region "$REGION" \
  --allow-unauthenticated \
  --set-env-vars "$ENV_VARS" \
  --project "$PROJECT_ID"

echo ""
echo "Deploy complete. Run ./scripts/verify.sh to check."
