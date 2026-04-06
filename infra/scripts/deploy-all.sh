#!/usr/bin/env bash
# Deploy both CDK stacks: download assets, then Amplify (needs GITHUB_* like deploy-amplify.sh).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/deploy-downloads.sh"
"${SCRIPT_DIR}/deploy-amplify.sh"
