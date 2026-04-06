#!/usr/bin/env bash
# Deploy Amplify Hosting (TexasHoldemGym-AmplifyHosting).
# Requires GitHub repo access: create a fine-grained or classic PAT with repo scope.
#
# Usage:
#   export GITHUB_OWNER=your-org
#   export GITHUB_REPO=poker
#   export GITHUB_TOKEN=ghp_...   # or: export GITHUB_TOKEN_FILE=~/.github/amplify-pat
#   ./scripts/deploy-amplify.sh
#
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${INFRA_ROOT}"

: "${AWS_REGION:=${CDK_DEFAULT_REGION:-us-east-1}}"
export CDK_DEFAULT_REGION="${AWS_REGION}"

GITHUB_OWNER="${GITHUB_OWNER:?Set GITHUB_OWNER}"
GITHUB_REPO="${GITHUB_REPO:?Set GITHUB_REPO}"

if [[ -n "${GITHUB_TOKEN_FILE:-}" && -f "${GITHUB_TOKEN_FILE}" ]]; then
  GITHUB_TOKEN="$(tr -d '\n\r' < "${GITHUB_TOKEN_FILE}")"
fi
GITHUB_TOKEN="${GITHUB_TOKEN:?Set GITHUB_TOKEN or GITHUB_TOKEN_FILE}"

PRODUCTION_BRANCH="${PRODUCTION_BRANCH:-main}"

echo "==> Deploy TexasHoldemGym-AmplifyHosting (repo=${GITHUB_OWNER}/${GITHUB_REPO}, branch=${PRODUCTION_BRANCH})"

npx cdk deploy TexasHoldemGym-AmplifyHosting \
  --require-approval never \
  -c "githubOwner=${GITHUB_OWNER}" \
  -c "githubRepo=${GITHUB_REPO}" \
  -c "githubToken=${GITHUB_TOKEN}" \
  -c "productionBranch=${PRODUCTION_BRANCH}" \
  "$@"

echo ""
echo "==> In Amplify Console: add env vars (DATABASE_URL, STRIPE_*, RESEND_*, ADMIN_*, NEXT_PUBLIC_*)"
echo "    Attach custom domain under App settings → Domain management."
