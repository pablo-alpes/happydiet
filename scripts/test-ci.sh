#!/usr/bin/env bash
# HappyDiet — CI test simulation (mirrors Cloud Build test step)
# Run from repo root: ./scripts/test-ci.sh
# Ensures: npm ci, test:ci, build — same as Cloud Build before deploy

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== HappyDiet CI Test (Cloud Build simulation) ==="
cd "$REPO_ROOT/backend"

echo "1. npm ci"
npm ci

echo "2. npm run test:ci"
CI=1 npm run test:ci

echo "3. npm run build"
npm run build

echo ""
echo "CI test passed. Ready for deploy."
