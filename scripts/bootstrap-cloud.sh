#!/usr/bin/env bash
# HappyDiet — Full programmatic CI/CD bootstrap
# Sets up GCP, deploys backend, creates CI/CD credentials.
# Run from repo root: ./scripts/bootstrap-cloud.sh [PROJECT_ID]
#
# Prerequisites: gcloud CLI, gcloud auth login, gcloud auth application-default login
# Optional: GITHUB_REPO_OWNER, GITHUB_REPO_NAME for Cloud Build trigger

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ID="${1:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${REGION:-us-central1}"
SERVICE_NAME="${SERVICE_NAME:-happydiet-backend}"
SA_NAME="${SA_NAME:-happydiet-cicd}"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if [[ -z "$PROJECT_ID" ]]; then
  echo "Usage: $0 PROJECT_ID"
  echo "  Or: gcloud config set project YOUR_PROJECT_ID"
  exit 1
fi

echo "=== HappyDiet CI/CD Bootstrap ==="
echo "Project:  $PROJECT_ID"
echo "Region:   $REGION"
echo "Service:  $SERVICE_NAME"
echo ""

# 1. Set project
gcloud config set project "$PROJECT_ID"

# 2. Enable APIs and create Firestore (via setup-production)
echo ">>> Running production setup (APIs, Firestore, .env)..."
"$SCRIPT_DIR/setup-production.sh" "$PROJECT_ID" 2>/dev/null || {
  echo "  Running setup-gcp as fallback..."
  "$SCRIPT_DIR/setup-gcp.sh" "$PROJECT_ID"
}

# 3. Create service account for CI/CD
echo ""
echo ">>> Creating service account for CI/CD..."
if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" 2>/dev/null; then
  echo "  Service account $SA_EMAIL already exists."
else
  gcloud iam service-accounts create "$SA_NAME" \
    --display-name="HappyDiet CI/CD" \
    --project="$PROJECT_ID" \
    --quiet
fi

# 4. Grant IAM roles to SA
echo ""
echo ">>> Granting IAM roles..."
for role in roles/run.admin roles/artifactregistry.writer roles/cloudbuild.builds.builder roles/iam.serviceAccountUser; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="$role" \
    --condition=None \
    --quiet 2>/dev/null || true
done

# Vertex AI and Firestore for Cloud Run runtime
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/aiplatform.user" \
  --quiet 2>/dev/null || true

# 5. Create and download SA key for GitHub Actions
KEY_FILE="$REPO_ROOT/scripts/.cicd-sa-key.json"
echo ""
echo ">>> Creating service account key for GitHub Actions..."
gcloud iam service-accounts keys create "$KEY_FILE" \
  --iam-account="$SA_EMAIL" \
  --project="$PROJECT_ID" \
  --quiet 2>/dev/null || {
  echo "  Key may already exist. Creating new key..."
  rm -f "$KEY_FILE"
  gcloud iam service-accounts keys create "$KEY_FILE" \
    --iam-account="$SA_EMAIL" \
    --project="$PROJECT_ID" \
    --quiet
}

# 6. Deploy backend
echo ""
echo ">>> Deploying backend to Cloud Run..."
cd "$REPO_ROOT"
"$SCRIPT_DIR/deploy.sh" "$PROJECT_ID"

# 7. Get service URL
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
  --region "$REGION" \
  --format 'value(status.url)' \
  --project "$PROJECT_ID" 2>/dev/null)

# 8. Create Cloud Build trigger (if GitHub repo connected)
if [[ -n "$GITHUB_REPO_OWNER" && -n "$GITHUB_REPO_NAME" ]]; then
  echo ""
  echo ">>> Creating Cloud Build trigger..."
  if gcloud builds triggers describe happydiet-deploy --project="$PROJECT_ID" 2>/dev/null; then
    echo "  Trigger happydiet-deploy already exists."
  else
    gcloud builds triggers create github \
      --name="happydiet-deploy" \
      --repo-owner="$GITHUB_REPO_OWNER" \
      --repo-name="$GITHUB_REPO_NAME" \
      --branch-pattern="^main$|^master$" \
      --build-config="cloudbuild.yaml" \
      --service-account="projects/$PROJECT_ID/serviceAccounts/$SA_EMAIL" \
      --project="$PROJECT_ID" 2>/dev/null || {
      echo "  Note: Connect GitHub repo first: https://console.cloud.google.com/cloud-build/repositories"
      echo "  Then run: GITHUB_REPO_OWNER=owner GITHUB_REPO_NAME=repo $0 $PROJECT_ID"
    }
  fi
fi

# 9. Output instructions
echo ""
echo "=== Bootstrap complete ==="
echo ""
echo "Service URL: $SERVICE_URL"
echo ""
echo "--- GitHub Actions setup ---"
echo "1. Add these secrets to your GitHub repo (Settings → Secrets and variables → Actions):"
echo ""
echo "   GCP_PROJECT_ID = $PROJECT_ID"
echo "   GCP_SA_KEY    = (contents of $KEY_FILE)"
echo ""
echo "   To copy the key: cat $KEY_FILE | pbcopy   # macOS"
echo "   Or: cat $KEY_FILE"
echo ""
echo "2. Push to main/master to trigger deploy."
echo ""
echo "--- Security ---"
echo "Delete the key file after adding to GitHub: rm $KEY_FILE"
echo "Add to .gitignore: scripts/.cicd-sa-key.json"
echo ""
echo "--- iOS ---"
echo "Update ios/HappyDiet/HappyDietConfig.plist: BACKEND_URL = $SERVICE_URL"
echo ""
