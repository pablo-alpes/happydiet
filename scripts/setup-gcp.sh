#!/usr/bin/env bash
# HappyDiet — GCP setup (enable APIs, verify auth)
# Run from repo root: ./scripts/setup-gcp.sh [PROJECT_ID]
# Or: ./scripts/setup-gcp.sh (uses gcloud config project)

set -e

PROJECT_ID="${1:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${REGION:-us-central1}"

if [[ -z "$PROJECT_ID" ]]; then
  echo "Usage: $0 PROJECT_ID"
  echo "  Or set project: gcloud config set project YOUR_PROJECT_ID"
  exit 1
fi

echo "=== HappyDiet GCP Setup ==="
echo "Project: $PROJECT_ID"
echo "Region:  $REGION"
echo ""

# Set project
gcloud config set project "$PROJECT_ID"

# Enable APIs
echo "Enabling APIs..."
gcloud services enable \
  aiplatform.googleapis.com \
  firestore.googleapis.com \
  texttospeech.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com

echo ""
echo "APIs enabled. Next steps:"
echo "  1. Create Firestore DB (Console): https://console.cloud.google.com/firestore"
echo "  2. Run: gcloud auth application-default login"
echo "  3. Deploy: ./scripts/deploy.sh"
