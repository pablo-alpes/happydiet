#!/usr/bin/env bash
# HappyDiet — Fix CI/CD service account permissions for Cloud Run deploy
# Run from repo root: ./scripts/fix-cicd-permissions.sh [PROJECT_ID]
#
# Fixes PERMISSION_DENIED: Permission 'run.services.get' denied when deploying from GitHub Actions.

set -e

PROJECT_ID="${1:-happydiet-1-490118}"
SA_EMAIL="happydiet-cicd@${PROJECT_ID}.iam.gserviceaccount.com"

echo "=== Fix CI/CD Permissions ==="
echo "Project: $PROJECT_ID"
echo "Service account: $SA_EMAIL"
echo ""

gcloud config set project "$PROJECT_ID"

echo ">>> Granting roles to happydiet-cicd (required for gcloud builds submit)..."
for role in \
  roles/run.admin \
  roles/artifactregistry.writer \
  roles/cloudbuild.builds.builder \
  roles/cloudbuild.builds.viewer \
  roles/iam.serviceAccountUser \
  roles/storage.objectAdmin \
  roles/aiplatform.user; do
  echo "  Adding $role..."
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="$role" \
    --quiet
done

# Cloud Build default SA also needs run.admin (it performs the deploy)
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')
CB_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"
echo ""
echo ">>> Granting Cloud Run Admin to Cloud Build SA ($CB_SA)..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$CB_SA" \
  --role="roles/run.admin" \
  --quiet

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:$CB_SA" \
  --role="roles/iam.serviceAccountUser" \
  --quiet

echo ""
echo "=== Done. IAM may take 1-2 minutes to propagate. Then re-run the GitHub Actions workflow. ==="
