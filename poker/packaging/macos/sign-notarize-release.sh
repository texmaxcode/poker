#!/usr/bin/env bash
# Sign Poker.app with a Developer ID certificate, optionally notarize + staple (no Gatekeeper nag on other Macs).
#
# Prerequisites (Apple Developer Program, ~$99/yr):
#   - "Developer ID Application" certificate installed in Keychain (local) OR CI-imported .p12
#   - For notarization: App Store Connect API key (recommended for CI) OR Apple ID + app-specific password
#
# Usage (after macdeployqt produced Poker.app):
#   export MACOS_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#   ./poker/packaging/macos/sign-notarize-release.sh /path/to/Poker.app
#
# Optional notarization (pick ONE auth method):
#
#   A) App Store Connect API key (good for CI):
#      export NOTARY_KEY_PATH="$HOME/AuthKey_XXXXXXXX.p8"
#      export NOTARY_KEY_ID="XXXXXXXXXX"
#      export NOTARY_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#
#   B) Apple ID (local / quick tests):
#      export APPLE_ID="you@example.com"
#      export APPLE_TEAM_ID="XXXXXXXXXX"
#      export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"   # from appleid.apple.com
#
#   Then either set NOTARIZE=1 or pass --notarize
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENTITLEMENTS="${SCRIPT_DIR}/entitlements.plist"
die() { echo "error: $*" >&2; exit 1; }

NOTARIZE_FLAG=0
APP=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --notarize) NOTARIZE_FLAG=1; shift ;;
    *) APP="${1:-}"; shift ;;
  esac
done

[[ -n "${APP}" && -d "${APP}" ]] || die "usage: $0 [--notarize] /path/to/Poker.app"
[[ -f "${ENTITLEMENTS}" ]] || die "missing ${ENTITLEMENTS}"

IDENT="${MACOS_SIGN_IDENTITY:-}"
[[ -n "${IDENT}" ]] || die "Set MACOS_SIGN_IDENTITY to your Developer ID Application identity (see: security find-identity -v -p codesigning)"

echo "==> codesign (hardened runtime) → ${APP}"
codesign --force --deep --options runtime \
  --entitlements "${ENTITLEMENTS}" \
  --sign "${IDENT}" \
  "${APP}"

# Optional: verify signature
codesign --verify --verbose=2 "${APP}" || die "codesign verify failed"

DO_NOTARIZE="${NOTARIZE_FLAG}"
if [[ "${DO_NOTARIZE}" -eq 0 && "${NOTARIZE:-0}" == "1" ]]; then
  DO_NOTARIZE=1
fi

if [[ "${DO_NOTARIZE}" -eq 0 ]]; then
  echo "==> Notarization skipped (set NOTARIZE=1 or pass --notarize, plus API key or Apple ID credentials)."
  exit 0
fi

TMPZIP="$(mktemp /tmp/poker-notarize.XXXXXX.zip)"
trap 'rm -f "${TMPZIP}"' EXIT

echo "==> zip for notarytool…"
ditto -c -k --keepParent "${APP}" "${TMPZIP}"

if [[ -n "${NOTARY_KEY_PATH:-}" && -n "${NOTARY_KEY_ID:-}" && -n "${NOTARY_ISSUER_ID:-}" ]]; then
  [[ -f "${NOTARY_KEY_PATH}" ]] || die "NOTARY_KEY_PATH is not a file: ${NOTARY_KEY_PATH}"
  echo "==> notarytool submit (API key)…"
  xcrun notarytool submit "${TMPZIP}" --wait \
    --key "${NOTARY_KEY_PATH}" \
    --key-id "${NOTARY_KEY_ID}" \
    --issuer "${NOTARY_ISSUER_ID}"
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
  echo "==> notarytool submit (Apple ID)…"
  xcrun notarytool submit "${TMPZIP}" --wait \
    --apple-id "${APPLE_ID}" \
    --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
    --team-id "${APPLE_TEAM_ID}"
else
  die "Notarization requested but missing credentials. Set NOTARY_KEY_PATH + NOTARY_KEY_ID + NOTARY_ISSUER_ID, OR APPLE_ID + APPLE_TEAM_ID + APPLE_APP_SPECIFIC_PASSWORD."
fi

echo "==> stapler staple…"
xcrun stapler staple "${APP}"

echo "==> stapler validate…"
xcrun stapler validate "${APP}" || die "stapler validate failed (ticket missing or corrupt)"

echo "==> Gatekeeper assessment (same family of check as opening a downloaded .app)…"
if ! spctl -a -vv -t exec "${APP}"; then
  die "spctl rejected the bundle after notarization — distribution copies may still be blocked."
fi

echo "==> Done: signed + notarized + stapled. Users can open the app without manual Gatekeeper overrides."
exit 0
