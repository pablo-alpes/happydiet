#!/usr/bin/env bash
# HappyDiet — UAT against deployed backend URL
# Run: ./scripts/uat-against-url.sh [SERVICE_URL]
# Requires: curl, a running backend (local or Cloud Run)

set -e

URL="${1:-http://localhost:8080}"

# Minimal valid JPEG base64 (1x1 pixel)
BASE64='/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAM'

echo "=== HappyDiet UAT (against $URL) ==="
echo ""

# 1. Health
echo "1. GET /health"
HTTP=$(curl -s -o /tmp/uat-health.json -w "%{http_code}" "$URL/health")
if [[ "$HTTP" != "200" ]]; then
  echo "   FAIL ($HTTP)"
  exit 1
fi
echo "   OK"

# 2. Analyze meal (requires real Vertex AI if backend uses it)
echo "2. POST /analyze-meal"
HTTP=$(curl -s -o /tmp/uat-analyze.json -w "%{http_code}" -X POST "$URL/analyze-meal" \
  -H "Content-Type: application/json" \
  -d "{\"image_base64\":\"$BASE64\",\"user_id\":\"uat-user\"}")

if [[ "$HTTP" == "503" ]]; then
  echo "   SKIP (backend not configured - set GOOGLE_CLOUD_PROJECT)"
  echo ""
  echo "For full UAT with real Vision, configure GCP and run backend locally."
  exit 0
fi

if [[ "$HTTP" != "200" ]]; then
  echo "   FAIL ($HTTP)"
  cat /tmp/uat-analyze.json
  exit 1
fi

SCORE=$(jq -r '.score' /tmp/uat-analyze.json 2>/dev/null || echo "?")
MESSAGE=$(jq -r '.message' /tmp/uat-analyze.json 2>/dev/null || echo "?")
echo "   OK (score: $SCORE)"
echo "   Message: ${MESSAGE:0:60}..."

# 3. Meals (dashboard)
echo "3. GET /meals"
HTTP=$(curl -s -o /tmp/uat-meals.json -w "%{http_code}" "$URL/meals?user_id=uat-user")
if [[ "$HTTP" != "200" ]]; then
  echo "   FAIL ($HTTP)"
  exit 1
fi
COUNT=$(jq '.meals | length' /tmp/uat-meals.json 2>/dev/null || echo "0")
echo "   OK (meals: $COUNT)"

echo ""
echo "=== UAT passed ==="
