#!/usr/bin/env bash
# HappyDiet — Verify deployment (health check)
# Run: ./scripts/verify.sh [SERVICE_URL]
# Or: ./scripts/verify.sh (fetches URL from gcloud)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVICE_NAME="${SERVICE_NAME:-happydiet-backend}"
REGION="${REGION:-us-central1}"

if [[ -n "$1" ]]; then
  URL="$1"
else
  echo "Fetching URL from Cloud Run..."
  URL=$(gcloud run services describe "$SERVICE_NAME" \
    --region "$REGION" \
    --format 'value(status.url)' 2>/dev/null)
fi

if [[ -z "$URL" ]]; then
  echo "Usage: $0 SERVICE_URL"
  echo "  Or: gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)'"
  exit 1
fi

echo "=== HappyDiet Verify ==="
echo "URL: $URL"
echo ""

# Health check
echo "GET /health"
HTTP_CODE=$(curl -s -o /tmp/happydiet-health.json -w "%{http_code}" "$URL/health")
BODY=$(cat /tmp/happydiet-health.json)

if [[ "$HTTP_CODE" == "200" ]]; then
  echo "  Status: $HTTP_CODE OK"
  echo "  Body:   $BODY"
  echo ""
  echo "Deployment verified."
else
  echo "  Status: $HTTP_CODE (expected 200)"
  echo "  Body:   $BODY"
  exit 1
fi
