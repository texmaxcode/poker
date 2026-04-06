#!/usr/bin/env bash
# Bootstrap CDK in the current AWS account/region (run once per account/region).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${INFRA_ROOT}"

: "${AWS_REGION:=${CDK_DEFAULT_REGION:-us-east-1}}"
export CDK_DEFAULT_REGION="${AWS_REGION}"

echo "==> CDK bootstrap (region=${CDK_DEFAULT_REGION})"
npx cdk bootstrap "aws://${CDK_DEFAULT_ACCOUNT:-}/${CDK_DEFAULT_REGION}"
