#!/usr/bin/env bash
# Install Texas Hold'em Gym under $HOME for local use (bundles Qt/ICU libs + plugins).
#
# Default prefix: $HOME/poker-gym
#   bin/texas-holdem-gym   — launcher (add to PATH or symlink from ~/bin)
#   libexec/Poker          — binary
#   lib/                   — copied shared libraries
#   lib/qt6/plugins/       — platform + image format plugins
#
# Usage:
#   ./install-local.sh              # build + install
#   ./install-local.sh --no-build   # install only (existing build/poker/Poker)
#   PREFIX=$HOME/myapp ./install-local.sh
#   ./install-local.sh --link-home-bin   # ln -sf into $HOME/bin
#
set -euo pipefail

export QTFRAMEWORK_BYPASS_LICENSE_CHECK="${QTFRAMEWORK_BYPASS_LICENSE_CHECK:-1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# packaging/linux -> repo root (…/sources/poker)
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build}"
BINARY="${BUILD_DIR}/poker/Poker"
PREFIX="${PREFIX:-${HOME}/poker-gym}"
DO_BUILD=1
LINK_HOME_BIN=0

for arg in "$@"; do
  case "$arg" in
    --no-build) DO_BUILD=0 ;;
    --link-home-bin) LINK_HOME_BIN=1 ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }

command -v cmake >/dev/null || die "cmake not found"
[[ -f "${REPO_ROOT}/CMakeLists.txt" ]] || die "bad REPO_ROOT: ${REPO_ROOT}"

if [[ "${DO_BUILD}" -eq 1 ]]; then
  echo "==> Configuring & building (Release)…"
  cmake -S "${REPO_ROOT}" -B "${BUILD_DIR}" -DCMAKE_BUILD_TYPE=Release
  cmake --build "${BUILD_DIR}" -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
fi

[[ -x "${BINARY}" ]] || die "missing executable: ${BINARY} (build first or fix BUILD_DIR)"

echo "==> Installing tree to ${PREFIX}"
install -d "${PREFIX}/bin" "${PREFIX}/share/icons/hicolor/512x512/apps"

# shellcheck source=./bundle-poker-app.inc.sh
source "${SCRIPT_DIR}/bundle-poker-app.inc.sh"

LAUNCHER="${PREFIX}/bin/texas-holdem-gym"
cat > "${LAUNCHER}" << EOF
#!/usr/bin/env bash
set -euo pipefail
PREFIX="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/.." && pwd)"
# Bundled Qt first; then distro libs (libxcb-cursor must come from OS — do not ship a copy in PREFIX/lib).
export LD_LIBRARY_PATH="\${PREFIX}/lib:/usr/lib/x86_64-linux-gnu:/usr/lib/aarch64-linux-gnu:/usr/lib64:/usr/lib\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}"
export QT_PLUGIN_PATH="\${PREFIX}/lib/qt6/plugins"
export QT_QPA_PLATFORM_PLUGIN_PATH="\${PREFIX}/lib/qt6/plugins/platforms"
export QML_IMPORT_PATH="\${PREFIX}/lib/qt6/qml\${QML_IMPORT_PATH:+:\${QML_IMPORT_PATH}}"
# Prefer Wayland when present so the xcb plugin (needs libxcb-cursor0) is not used.
if [[ -z "\${QT_QPA_PLATFORM:-}" ]]; then
  if [[ -n "\${WAYLAND_DISPLAY:-}" || "\${XDG_SESSION_TYPE:-}" == wayland ]]; then
    export QT_QPA_PLATFORM=wayland
  fi
fi
# X11/xcb: Qt 6.5+ needs libxcb-cursor loaded; RUNPATH on bundled libqxcb can block resolution — LD_PRELOAD must be set before exec.
if [[ "\${QT_QPA_PLATFORM:-}" != wayland ]]; then
  for _p in /usr/lib/x86_64-linux-gnu/libxcb-cursor.so.0 /usr/lib/aarch64-linux-gnu/libxcb-cursor.so.0 /usr/lib/libxcb-cursor.so.0 /usr/lib64/libxcb-cursor.so.0; do
    if [[ -e "\$_p" ]]; then
      export LD_PRELOAD="\$_p\${LD_PRELOAD:+:\${LD_PRELOAD}}"
      break
    fi
  done
  if [[ -z "\${LD_PRELOAD:-}" ]]; then
    echo "texas-holdem-gym: for X11 install: sudo apt install libxcb-cursor0" >&2
  fi
fi
exec "\${PREFIX}/libexec/Poker" "\$@"
EOF
chmod 755 "${LAUNCHER}"

ICON_SRC="${REPO_ROOT}/poker/qml/assets/images/logo.png"
[[ -f "${ICON_SRC}" ]] || die "missing ${ICON_SRC}"
cp -f "${ICON_SRC}" "${PREFIX}/share/icons/hicolor/512x512/apps/texas-holdem-gym.png"
install -d "${HOME}/.local/share/icons/hicolor/512x512/apps"
cp -f "${ICON_SRC}" "${HOME}/.local/share/icons/hicolor/512x512/apps/texas-holdem-gym.png"

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "${HOME}/.local/share/icons/hicolor" 2>/dev/null || true
fi

DESKTOP_LOCAL="${HOME}/.local/share/applications/texas-holdem-gym.desktop"
install -d "${HOME}/.local/share/applications"
ICON_FILE_LOCAL="${HOME}/.local/share/icons/hicolor/512x512/apps/texas-holdem-gym.png"
cat > "${DESKTOP_LOCAL}" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Texas Hold'em Gym
Comment=Practice Texas Hold'em
Exec=${LAUNCHER}
Icon=${ICON_FILE_LOCAL}
StartupWMClass=Poker
Terminal=false
Categories=Game;
EOF

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true
fi

if [[ "${LINK_HOME_BIN}" -eq 1 ]]; then
  mkdir -p "${HOME}/bin"
  ln -sfn "${LAUNCHER}" "${HOME}/bin/texas-holdem-gym"
  echo "==> Symlink: ${HOME}/bin/texas-holdem-gym -> ${LAUNCHER}"
  echo "    Ensure ${HOME}/bin is on your PATH."
fi

echo ""
echo "Install complete."
echo "  Run:    ${LAUNCHER}"
echo "  Or add to PATH:  export PATH=\"${PREFIX}/bin:\$PATH\""
if [[ "${LINK_HOME_BIN}" -eq 0 ]]; then
  echo "  Optional:  ${SCRIPT_DIR}/install-local.sh --link-home-bin"
fi
echo "  Menu icon: ~/.local/share/applications/texas-holdem-gym.desktop"
echo ""
