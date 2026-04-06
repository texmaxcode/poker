#!/usr/bin/env bash
# Build a self-contained AppImage for Texas Hold'em Gym (Qt 6 + bundled SQLite3).
#
# For Ubuntu App Center (Snap Store listings), use packaging/linux/build-snap.sh instead.
#
# Prerequisites: CMake, Ninja or Make, Qt 6 dev (qmake/qmake6 on PATH), patchelf (recommended).
# Downloads linuxdeploy + Qt + AppImage plugins into SCRIPT_DIR/.cache/linuxdeploy on first run.
#
# Uses packaging/linux/texas-holdem-gym.desktop. Icon: packaging/linux/texas-holdem-gym.png if present,
# else poker/qml/assets/images/logo.png.
#
# Output (repo root): Texas_Holdem_Gym-x86_64-<githash>.AppImage
#
# Usage:
#   ./build-appimage.sh
#   QMAKE=/path/to/qmake BUILD_DIR=build ./build-appimage.sh
#
set -euo pipefail

export QTFRAMEWORK_BYPASS_LICENSE_CHECK="${QTFRAMEWORK_BYPASS_LICENSE_CHECK:-1}"
export ARCH="${ARCH:-x86_64}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build}"
CACHE="${SCRIPT_DIR}/.cache/linuxdeploy"
BINARY="${BUILD_DIR}/poker/Poker"
APPDIR="${BUILD_DIR}/appimage/AppDir"

export POKER_GIT_HASH="$(git -C "${REPO_ROOT}" rev-parse --short=8 HEAD 2>/dev/null || echo unknown)"
_ver="$(grep '^project(' "${REPO_ROOT}/CMakeLists.txt" | head -1 | sed -E 's/.*VERSION ([0-9.]+).*/\1/')"
[[ -z "${_ver}" ]] && _ver="0.1"
echo "==> Building AppImage version ${_ver}+${POKER_GIT_HASH}"

OUT_IMAGE="${REPO_ROOT}/Texas_Holdem_Gym-${ARCH}-${POKER_GIT_HASH}.AppImage"

LINUXDEPLOY_URL="${LINUXDEPLOY_URL:-https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage}"
PLUGIN_QT_URL="${PLUGIN_QT_URL:-https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage}"
PLUGIN_APPIMAGE_URL="${PLUGIN_APPIMAGE_URL:-https://github.com/linuxdeploy/linuxdeploy-plugin-appimage/releases/download/continuous/linuxdeploy-plugin-appimage-x86_64.AppImage}"

LINUXDEPLOY="${CACHE}/linuxdeploy-x86_64.AppImage"
PLUGIN_QT="${CACHE}/linuxdeploy-plugin-qt-x86_64.AppImage"
PLUGIN_APPIMAGE="${CACHE}/linuxdeploy-plugin-appimage-x86_64.AppImage"

die() { echo "error: $*" >&2; exit 1; }

fetch() {
  local url="$1" dest="$2"
  [[ -f "${dest}" ]] && return 0
  mkdir -p "${CACHE}"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "${dest}.part" "${url}" && mv -f "${dest}.part" "${dest}"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "${dest}.part" "${url}" && mv -f "${dest}.part" "${dest}"
  else
    die "need curl or wget to download linuxdeploy"
  fi
  chmod +x "${dest}"
}

command -v cmake >/dev/null || die "cmake not found"
[[ -f "${REPO_ROOT}/CMakeLists.txt" ]] || die "bad REPO_ROOT: ${REPO_ROOT}"

echo "==> Fetching linuxdeploy tooling…"
fetch "${LINUXDEPLOY_URL}" "${LINUXDEPLOY}"
fetch "${PLUGIN_QT_URL}" "${PLUGIN_QT}"
fetch "${PLUGIN_APPIMAGE_URL}" "${PLUGIN_APPIMAGE}"

export LINUXDEPLOY_PLUGIN_QT="${PLUGIN_QT}"

echo "==> Configuring & building (Release)…"
cmake -S "${REPO_ROOT}" -B "${BUILD_DIR}" -DCMAKE_BUILD_TYPE=Release
cmake --build "${BUILD_DIR}" -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"

[[ -x "${BINARY}" ]] || die "missing executable: ${BINARY}"

QMAKE_BIN="${QMAKE:-}"
if [[ -z "${QMAKE_BIN}" ]]; then
  if command -v qmake6 >/dev/null 2>&1; then
    QMAKE_BIN="$(command -v qmake6)"
  elif command -v qmake >/dev/null 2>&1; then
    QMAKE_BIN="$(command -v qmake)"
  fi
fi
[[ -n "${QMAKE_BIN}" ]] || die "Qt qmake not found; set QMAKE to Qt 6 qmake"
export QMAKE="${QMAKE_BIN}"

DESKTOP_SRC="${SCRIPT_DIR}/texas-holdem-gym.desktop"
[[ -f "${DESKTOP_SRC}" ]] || die "missing ${DESKTOP_SRC}"
ICON_SRC="${SCRIPT_DIR}/texas-holdem-gym.png"
[[ -f "${ICON_SRC}" ]] || ICON_SRC="${REPO_ROOT}/poker/qml/assets/images/logo.png"
[[ -f "${ICON_SRC}" ]] || die "missing icon (add ${SCRIPT_DIR}/texas-holdem-gym.png or poker/qml/assets/images/logo.png)"

echo "==> Staging AppDir…"
rm -rf "${APPDIR}"
install -d "${APPDIR}/usr/bin" "${APPDIR}/usr/share/applications" \
  "${APPDIR}/usr/share/icons/hicolor/512x512/apps"
cp -f "${BINARY}" "${APPDIR}/usr/bin/Poker"
chmod 755 "${APPDIR}/usr/bin/Poker"
cp -f "${DESKTOP_SRC}" "${APPDIR}/usr/share/applications/texas-holdem-gym.desktop"
cp -f "${ICON_SRC}" "${APPDIR}/usr/share/icons/hicolor/512x512/apps/texas-holdem-gym.png"

# Extra library: CMake links SQLite3 directly (not only via Qt plugins).
SQLITE_LIB=""
if SQLITE_LIB="$(ldd "${BINARY}" 2>/dev/null | awk '/libsqlite3\.so/ && $2 == "=>" && $3 ~ /^\// {print $3; exit}')"; then
  [[ -n "${SQLITE_LIB}" && -f "${SQLITE_LIB}" ]] || SQLITE_LIB=""
fi

DEPLOY_EXTRA=( )
[[ -n "${SQLITE_LIB}" ]] && DEPLOY_EXTRA+=(--library "${SQLITE_LIB}")

echo "==> linuxdeploy (Qt plugin + optional SQLite)…"
(
  cd "$(dirname "${APPDIR}")"
  "${LINUXDEPLOY}" \
    --appdir "${APPDIR}" \
    --executable "${APPDIR}/usr/bin/Poker" \
    --desktop-file "${APPDIR}/usr/share/applications/texas-holdem-gym.desktop" \
    --icon-file "${APPDIR}/usr/share/icons/hicolor/512x512/apps/texas-holdem-gym.png" \
    "${DEPLOY_EXTRA[@]}" \
    --plugin qt
)

echo "==> Generating AppImage…"
APPIMAGE_PARENT="$(dirname "${APPDIR}")"
(
  cd "${APPIMAGE_PARENT}"
  rm -f "${OUT_IMAGE}"
  "${PLUGIN_APPIMAGE}" --appdir "${APPDIR}"
)

shopt -s nullglob
_cands=( "${APPIMAGE_PARENT}"/*.AppImage )
shopt -u nullglob
[[ "${#_cands[@]}" -gt 0 ]] || die "AppImage not produced in ${APPIMAGE_PARENT}"
# Prefer the most recently modified file in that directory.
CANDIDATE="$(ls -t "${_cands[@]}" 2>/dev/null | head -1)"
[[ -n "${CANDIDATE}" && -f "${CANDIDATE}" ]] || die "AppImage candidate missing"
mv -f "${CANDIDATE}" "${OUT_IMAGE}"

echo "==> Done: ${OUT_IMAGE}"
