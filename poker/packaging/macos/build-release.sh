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
QT_ROOT="$(cd "${QT_BIN}/.." && pwd)"

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

# macdeployqt resolves linked dylibs via the Mach-O load commands, but Homebrew dylibs
# live under /opt/homebrew/... (Apple Silicon) or /usr/local/... (Intel) which aren't
# on dyld's default fallback path. Passing -libpath points macdeployqt at the sqlite
# Cellar so libsqlite3.dylib is embedded and its LC_LOAD_DYLIB patched to @rpath/...
DEPLOY_EXTRA=()
if [[ -n "${SQLITE_ROOT}" && -d "${SQLITE_ROOT}/lib" ]]; then
  DEPLOY_EXTRA+=(-libpath="${SQLITE_ROOT}/lib")
fi

(
  cd "${BUILD_DIR}/poker"
  # macdeployqt tries to analyze/copy *all* Qt SQL driver plugins it can see
  # (ODBC/PostgreSQL/Mimer/...), even if the app never loads them. Those plugins
  # often have optional third‑party dependencies installed only on the build host
  # (e.g. Homebrew's libiodbc, Postgres.app's libpq), which makes macdeployqt emit
  # noisy "can't open file" / "no file at ..." errors during inspection.
  #
  # Since this project doesn't use QtSql drivers at runtime (we delete them from the
  # bundle below), temporarily hide Qt's sqldrivers folder so macdeployqt won't
  # attempt to process them in the first place. Always restore it on exit.
  _qt_sqldrivers="${QT_ROOT}/plugins/sqldrivers"
  _qt_sqldrivers_stash=""
  if [[ -d "${_qt_sqldrivers}" ]]; then
    _qt_sqldrivers_stash="$(mktemp -d)"
    mv "${_qt_sqldrivers}" "${_qt_sqldrivers_stash}/sqldrivers"
    trap 'if [[ -n "${_qt_sqldrivers_stash}" && -d "${_qt_sqldrivers_stash}/sqldrivers" ]]; then mkdir -p "$(dirname "${_qt_sqldrivers}")"; mv "${_qt_sqldrivers_stash}/sqldrivers" "${_qt_sqldrivers}"; rmdir "${_qt_sqldrivers_stash}" 2>/dev/null || true; fi' EXIT
  fi

  "${QT_BIN}/macdeployqt" "Poker.app" -qmldir="${QML_DIR}" "${DEPLOY_EXTRA[@]}"
  # persist_sqlite.cpp uses the SQLite3 C API directly (not QSqlDatabase), so none of
  # the Qt SQL driver plugins (ODBC, PostgreSQL, Mimer, MySQL, …) are used at runtime.
  # macdeployqt copies them anyway, and their LC_LOAD_DYLIB entries reference the build
  # host's Homebrew / Postgres.app paths (/opt/homebrew/opt/libiodbc/…, /usr/local/lib/
  # libmimerapi.dylib, /Applications/Postgres.app/…) that won't exist on user machines
  # and break our otool verification. Drop the whole plugin dir.
  rm -rf "Poker.app/Contents/PlugIns/sqldrivers"
  codesign --force --deep --sign - "Poker.app"
  rm -f "${DMG_NAME}"
  hdiutil create -volname "Texas Hold'em Gym" -srcfolder "Poker.app" -ov -format UDZO "${DMG_NAME}"
)
cp -f "${BUILD_DIR}/poker/${DMG_NAME}" "${DIST_DIR}/${DMG_NAME}"
echo "==> DMG: ${DIST_DIR}/${DMG_NAME}"

# Surface any leftover absolute Homebrew/local paths at build time instead of at launch
# (where they would show as "dyld: Library not loaded: /opt/homebrew/...").
echo "==> Verifying bundle dylib references…"
BUNDLE_BIN="${APP}/Contents/MacOS/Poker"
_bad=0
# Walk the Mach-O executable and every embedded dylib/framework binary.
while IFS= read -r -d '' _macho; do
  # Skip the Mach-O being asked (otool prints its own path as first line).
  while IFS= read -r _line; do
    # Strip leading whitespace; keep just the dylib install path before any " (compat...".
    _path="${_line#"${_line%%[![:space:]]*}"}"
    _path="${_path%% (*}"
    case "${_path}" in
      /opt/homebrew/*|/usr/local/*)
        echo "  UNRESOLVED: ${_macho#${APP}/} depends on ${_path}" >&2
        _bad=1
        ;;
    esac
  done < <(otool -L "${_macho}" 2>/dev/null | tail -n +2)
done < <(find "${APP}" \( -name '*.dylib' -o -name 'Poker' -o -path '*/Frameworks/*/Versions/*/*' \) -type f -print0)
if [[ "${_bad}" -ne 0 ]]; then
  echo "error: ${APP} still references Homebrew/local dylibs outside the bundle." >&2
  echo "       pass -libpath to macdeployqt or install into a path it already scans." >&2
  exit 1
fi
echo "    No external (Homebrew/local) dylib references remain."

echo "==> Done: ${APP}"
