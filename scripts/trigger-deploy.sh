#!/usr/bin/env bash
# HappyDiet — Trigger deployment when main (or dev) evolves
#
# Usage:
#   ./scripts/trigger-deploy.sh [prod|dev]
#   ./scripts/trigger-deploy.sh prod   # Deploy prod (default)
#   ./scripts/trigger-deploy.sh dev    # Deploy dev
#
# Options:
#   --local   Run deploy.sh locally instead of triggering GitHub Actions
#   --push    Push current branch first, then trigger (for main: merge first)
#
# When main evolves: Push to main triggers GitHub Actions automatically.
# This script lets you:
#   1. Deploy locally (./scripts/trigger-deploy.sh prod --local)
#   2. Trigger workflow via GitHub API (requires gh CLI)
#   3. Pull latest main and deploy locally
#
# Prerequisites: gcloud (--local), gh (for API trigger)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ID="${GCP_PROJECT_ID:-happydiet-1-490118}"
ENV="${1:-prod}"
USE_LOCAL=""
DO_PUSH=""

for arg in "$@"; do
  case "$arg" in
    --local) USE_LOCAL=1 ;;
    --push)  DO_PUSH=1 ;;
  esac
done

echo "=== HappyDiet Trigger Deploy ==="
echo "Environment: $ENV"
echo ""

if [[ -n "$DO_PUSH" ]]; then
  echo ">>> Pulling latest from remote..."
  cd "$REPO_ROOT"
  if [[ "$ENV" == "prod" ]]; then
    git fetch origin main
    git checkout main
    git pull origin main
  else
    git fetch origin dev
    git checkout dev
    git pull origin dev
  fi
  echo ""
fi

if [[ -n "$USE_LOCAL" ]]; then
  echo ">>> Deploying locally via deploy.sh..."
  ENV="$ENV" "$SCRIPT_DIR/deploy.sh" "$PROJECT_ID"
  echo ""
  echo ">>> Verifying..."
  "$SCRIPT_DIR/verify.sh"
  exit 0
fi

# Trigger via GitHub Actions (requires gh CLI)
if command -v gh &>/dev/null; then
  echo ">>> Triggering GitHub Actions workflow..."
  gh workflow run deploy.yml -f environment="$ENV"
  echo ""
  echo "Workflow triggered. View runs: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions"
  exit 0
fi

echo "No gh CLI found. Use one of:"
echo "  1. ./scripts/trigger-deploy.sh $ENV --local   # Deploy locally"
echo "  2. brew install gh && gh auth login           # Then re-run for API trigger"
echo "  3. Push to main (prod) or dev (dev)          # Triggers automatically"
exit 1
