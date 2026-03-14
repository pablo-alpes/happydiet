#!/usr/bin/env bash
# HappyDiet — Add GitHub Actions secrets securely
# Run from repo root: ./scripts/setup-github-secrets.sh [PROJECT_ID]
#
# Prerequisites: gh CLI (gh auth login), gcloud (gcloud auth application-default login)
# Creates or uses existing service account key, adds to GitHub via gh secret set.
# Key is never logged or committed. Delete key after: rm scripts/.cicd-sa-key.json

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ID="${1:-happydiet-1-490118}"
KEY_FILE="$REPO_ROOT/scripts/.cicd-sa-key.json"

echo "=== HappyDiet — Setup GitHub Secrets ==="
echo "Project: $PROJECT_ID"
echo ""

# 1. Ensure gh is installed
if ! command -v gh &>/dev/null; then
  echo "Error: gh CLI not found. Install: brew install gh"
  echo ""
  echo "Manual alternative: Add secrets at https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo 'OWNER/REPO')/settings/secrets/actions"
  echo "  GCP_PROJECT_ID = $PROJECT_ID"
  echo "  GCP_SA_KEY    = (contents of $KEY_FILE)"
  exit 1
fi

# 2. Ensure key exists (run bootstrap if needed)
if [[ ! -f "$KEY_FILE" ]]; then
  echo ">>> Creating service account and key..."
  "$SCRIPT_DIR/bootstrap-cloud.sh" "$PROJECT_ID"
else
  echo ">>> Using existing key: $KEY_FILE"
fi

if [[ ! -f "$KEY_FILE" ]]; then
  echo "Error: Key file not found after bootstrap."
  exit 1
fi

# 3. Authenticate gh if GITHUB_TOKEN provided
if [[ -n "$GITHUB_TOKEN" ]] && ! gh auth status &>/dev/null; then
  echo ">>> Authenticating with GITHUB_TOKEN..."
  echo "$GITHUB_TOKEN" | gh auth login --with-token
fi

# 4. Add secrets to GitHub (values never appear in logs)
echo ""
if ! gh auth status &>/dev/null; then
  echo ">>> gh not authenticated. Run once: gh auth login"
  echo "   Or: GITHUB_TOKEN=ghp_xxx ./scripts/setup-github-secrets.sh"
  echo "   (Create token at https://github.com/settings/tokens — scope: repo)"
  echo ""
  echo "Then re-run this script, or add secrets manually:"
  REPO=$(cd "$REPO_ROOT" && git remote get-url origin 2>/dev/null | sed -E 's|.*github.com[:/]([^/]+/[^/.]+).*|\1|')
  echo "  https://github.com/${REPO:-pablo-alpes/happydiet}/settings/secrets/actions"
  echo ""
  echo "  GCP_PROJECT_ID = $PROJECT_ID"
  echo "  GCP_SA_KEY    = cat $KEY_FILE | pbcopy   # then paste in GitHub"
  exit 1
fi

echo ">>> Adding secrets to GitHub (via gh — values never logged)..."
gh secret set GCP_PROJECT_ID --body "$PROJECT_ID"
gh secret set GCP_SA_KEY < "$KEY_FILE"

echo ""
echo "=== Done ==="
echo "Secrets GCP_PROJECT_ID and GCP_SA_KEY have been added."
echo ""
echo "Security: Delete the key file now (it's in GitHub):"
echo "  rm $KEY_FILE"
echo ""
echo "Push to main to trigger deploy."
echo ""
