#!/usr/bin/env bash
# HappyDiet — Smoke test for deployed backend
# Run: ./scripts/smoke-test.sh [SERVICE_URL]
# Or: ./scripts/smoke-test.sh (fetches URL from gcloud)
# Use after deploy to verify production.

set -e

SERVICE_NAME="${SERVICE_NAME:-happydiet-backend}"
REGION="${REGION:-us-central1}"

if [[ -n "$1" ]]; then
  URL="$1"
else
  URL=$(gcloud run services describe "$SERVICE_NAME" \
    --region "$REGION" \
    --format 'value(status.url)' 2>/dev/null)
fi

if [[ -z "$URL" ]]; then
  echo "Usage: $0 SERVICE_URL"
  echo "  Example: $0 https://happydiet-backend-xxxxx-uc.a.run.app"
  exit 1
fi

echo "=== HappyDiet Smoke Test ==="
echo "URL: $URL"
echo ""

FAIL=0

# Health check
echo "GET /health"
HTTP=$(curl -s -o /tmp/smoke-health.json -w "%{http_code}" "$URL/health")
if [[ "$HTTP" == "200" ]]; then
  echo "  OK ($HTTP)"
  head -c 100 /tmp/smoke-health.json
  echo ""
else
  echo "  FAIL ($HTTP, expected 200)"
  cat /tmp/smoke-health.json
  FAIL=1
fi
echo ""

# Meals (should work without auth)
echo "GET /meals?user_id=demo"
HTTP=$(curl -s -o /tmp/smoke-meals.json -w "%{http_code}" "$URL/meals?user_id=demo")
if [[ "$HTTP" == "200" ]]; then
  echo "  OK ($HTTP)"
else
  echo "  FAIL ($HTTP, expected 200)"
  cat /tmp/smoke-meals.json
  FAIL=1
fi
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo "Smoke test passed."
else
  echo "Smoke test failed."
  exit 1
fi
