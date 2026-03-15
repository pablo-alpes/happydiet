#!/usr/bin/env bash
# Create and push the dev branch so you can deploy to dev without touching prod.
# Usage: ./scripts/create-dev-branch.sh
# After this: push to 'dev' → deploys to happydiet-backend-dev; push to 'main' → prod.
set -e
git fetch origin 2>/dev/null || true
if git show-ref --verify refs/heads/dev 2>/dev/null; then
  echo "Branch 'dev' already exists. Checking it out and pushing..."
  git checkout dev
else
  echo "Creating dev from current branch..."
  git checkout -b dev
fi
echo "Pushing dev to origin..."
git push -u origin dev 2>/dev/null || git push origin dev
echo "Done. Push to 'dev' → deploys to dev; merge to main → prod."
