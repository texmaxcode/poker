#!/usr/bin/env bash
# Build Poker.app, run macdeployqt, produce a .dmg for distribution.
#
# Prerequisites:
#   - Xcode CLI tools, CMake, Ninja
#   - Qt 6.x (set CMAKE_PREFIX_PATH or QT_ROOT_DIR to the Qt install, e.g. from Qt Online Installer)
#   - SQLite3: brew install sqlite
#
# Usage (from repo root):
#   export CMAKE_PREFIX_PATH="$HOME/Qt/6.10.0/macos"
#   ./poker/packaging/macos/build-release.sh
#
# Outputs:
#   build/poker/Poker.app          — deployed app
#   dist/macos/TexasHoldemGym-<arch>-<githash>.dmg — disk image
#
set -euo pipefail

export QTFRAMEWORK_BYPASS_LICENSE_CHECK="${QTFRAMEWORK_BYPASS_LICENSE_CHECK:-1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build-macos}"
DIST_DIR="${REPO_ROOT}/dist/macos"
QML_DIR="${REPO_ROOT}/poker/qml"

die() { echo "error: $*" >&2; exit 1; }

command -v cmake >/dev/null || die "cmake not found"
[[ -f "${REPO_ROOT}/CMakeLists.txt" ]] || die "bad REPO_ROOT: ${REPO_ROOT}"
[[ -d "${QML_DIR}" ]] || die "missing ${QML_DIR}"

QT_BIN=""
if [[ -n "${QT_ROOT_DIR:-}" ]]; then
  QT_BIN="${QT_ROOT_DIR}/bin"
elif [[ -n "${CMAKE_PREFIX_PATH:-}" ]]; then
  _first="${CMAKE_PREFIX_PATH%%;*}"
  _first="${_first%%:*}"
  QT_BIN="${_first}/bin"
fi
[[ -n "${QT_BIN}" && -x "${QT_BIN}/macdeployqt" ]] || die "Set QT_ROOT_DIR or CMAKE_PREFIX_PATH to Qt 6 (need bin/macdeployqt)"

SQLITE_ROOT=""
if command -v brew >/dev/null 2>&1 && brew --prefix sqlite &>/dev/null; then
  SQLITE_ROOT="$(brew --prefix sqlite)"
fi

export POKER_GIT_HASH="$(git -C "${REPO_ROOT}" rev-parse --short=8 HEAD 2>/dev/null || echo unknown)"
_ver="$(grep '^project(' "${REPO_ROOT}/CMakeLists.txt" | head -1 | sed -E 's/.*VERSION ([0-9.]+).*/\1/')"
[[ -z "${_ver}" ]] && _ver="0.1"
echo "==> Building macOS bundle version ${_ver}+${POKER_GIT_HASH}"

echo "==> Configuring (${BUILD_DIR})…"
CMAKE_ARGS=(
  -S "${REPO_ROOT}"
  -B "${BUILD_DIR}"
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
)
if [[ -n "${CMAKE_PREFIX_PATH:-}" ]]; then
  CMAKE_ARGS+=(-DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}")
fi
if [[ -n "${SQLITE_ROOT}" ]]; then
  CMAKE_ARGS+=(-DSQLite3_ROOT="${SQLITE_ROOT}")
  echo "    SQLite3_ROOT=${SQLITE_ROOT}"
fi

cmake "${CMAKE_ARGS[@]}"
cmake --build "${BUILD_DIR}" -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 8)"

APP="${BUILD_DIR}/poker/Poker.app"
[[ -d "${APP}" ]] || die "missing ${APP} — MACOSX_BUNDLE must be enabled for Poker (see poker/CMakeLists.txt)"

echo "==> macdeployqt (frameworks + QML)…"
# Sign the bundle after deploy: embedded Qt dylibs must be signed or dyld kills with
# EXC_BAD_ACCESS / CODESIGNING Invalid Page (especially on newer macOS).
rm -f "${BUILD_DIR}/poker/"*.dmg 2>/dev/null || true
ARCH="$(uname -m)"
DMG_NAME="TexasHoldemGym-macOS-${ARCH}-${POKER_GIT_HASH}.dmg"
mkdir -p "${DIST_DIR}"
(
  cd "${BUILD_DIR}/poker"
  "${QT_BIN}/macdeployqt" "Poker.app" -qmldir="${QML_DIR}"
  codesign --force --deep --sign - "Poker.app"
  rm -f "${DMG_NAME}"
  hdiutil create -volname "Texas Hold'em Gym" -srcfolder "Poker.app" -ov -format UDZO "${DMG_NAME}"
)
cp -f "${BUILD_DIR}/poker/${DMG_NAME}" "${DIST_DIR}/${DMG_NAME}"
echo "==> DMG: ${DIST_DIR}/${DMG_NAME}"

echo "==> Done: ${APP}"
