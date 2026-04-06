#!/usr/bin/env bash
# Deploy S3 + CloudFront for Windows/macOS installers (TexasHoldemGym-DownloadAssets).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${INFRA_ROOT}"

: "${AWS_REGION:=${CDK_DEFAULT_REGION:-us-east-1}}"
export CDK_DEFAULT_REGION="${AWS_REGION}"

echo "==> Deploy TexasHoldemGym-DownloadAssets"
npx cdk deploy TexasHoldemGym-DownloadAssets --require-approval never "$@"

echo ""
echo "==> Copy stack outputs from the table above:"
echo "    NEXT_PUBLIC_DOWNLOAD_BASE_URL = NextPublicDownloadBaseUrl (no trailing slash)"
