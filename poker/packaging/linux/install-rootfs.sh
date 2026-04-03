#!/usr/bin/env bash
# Minimal FHS tree under ROOTFS (default: build/rootfs) for chroot, Docker, or "sudo cp -a … /".
#
# Layout (paths as seen after unpacking to /):
#   /usr/bin/texas-holdem-gym
#   /usr/lib/poker-gym/{libexec/Poker,lib/*.so,lib/qt6/plugins/...}
#   /usr/share/{applications,icons/...}
#
# Usage:
#   ./install-rootfs.sh
#   ROOTFS=/tmp/root ./install-rootfs.sh --no-build
#
# Apply on a real system (careful):
#   sudo cp -a build/rootfs/* /
#
set -euo pipefail

export QTFRAMEWORK_BYPASS_LICENSE_CHECK="${QTFRAMEWORK_BYPASS_LICENSE_CHECK:-1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build}"
BINARY="${BUILD_DIR}/poker/Poker"
ROOTFS="${ROOTFS:-${BUILD_DIR}/rootfs}"
DO_BUILD=1

for arg in "$@"; do
  case "$arg" in
    --no-build) DO_BUILD=0 ;;
    -h|--help)
      sed -n '2,22p' "$0"
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

[[ -x "${BINARY}" ]] || die "missing executable: ${BINARY}"

APP_ROOT="/usr/lib/poker-gym"
PREFIX="${ROOTFS}${APP_ROOT}"

echo "==> Rootfs staging: ${ROOTFS}"
install -d "${ROOTFS}/usr/bin" "${ROOTFS}/usr/share/applications" \
  "${ROOTFS}/usr/share/icons/hicolor/512x512/apps"

BINARY="${BINARY}" PREFIX="${PREFIX}" source "${SCRIPT_DIR}/bundle-poker-app.inc.sh"

# Launcher uses absolute paths so the tree works when ROOTFS is copied to /.
LAUNCHER="${ROOTFS}/usr/bin/texas-holdem-gym"
cat > "${LAUNCHER}" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
export LD_LIBRARY_PATH="/usr/lib/poker-gym/lib:/usr/lib/x86_64-linux-gnu:/usr/lib/aarch64-linux-gnu:/usr/lib64:/usr/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
export QT_PLUGIN_PATH="/usr/lib/poker-gym/lib/qt6/plugins"
export QT_QPA_PLATFORM_PLUGIN_PATH="/usr/lib/poker-gym/lib/qt6/plugins/platforms"
export QML_IMPORT_PATH="/usr/lib/poker-gym/lib/qt6/qml${QML_IMPORT_PATH:+:${QML_IMPORT_PATH}}"
if [[ -z "${QT_QPA_PLATFORM:-}" ]]; then
  if [[ -n "${WAYLAND_DISPLAY:-}" || "${XDG_SESSION_TYPE:-}" == wayland ]]; then
    export QT_QPA_PLATFORM=wayland
  fi
fi
if [[ "${QT_QPA_PLATFORM:-}" != wayland ]]; then
  for _p in /usr/lib/x86_64-linux-gnu/libxcb-cursor.so.0 /usr/lib/aarch64-linux-gnu/libxcb-cursor.so.0 /usr/lib/libxcb-cursor.so.0 /usr/lib64/libxcb-cursor.so.0; do
    if [[ -e "${_p}" ]]; then
      export LD_PRELOAD="${_p}${LD_PRELOAD:+:${LD_PRELOAD}}"
      break
    fi
  done
  if [[ -z "${LD_PRELOAD:-}" ]]; then
    echo "texas-holdem-gym: for X11 install: apt install libxcb-cursor0" >&2
  fi
fi
exec /usr/lib/poker-gym/libexec/Poker "$@"
EOF
chmod 755 "${LAUNCHER}"

ICON_SRC="${REPO_ROOT}/poker/qml/assets/images/logo.png"
[[ -f "${ICON_SRC}" ]] || die "missing ${ICON_SRC}"
cp -f "${ICON_SRC}" "${ROOTFS}/usr/share/icons/hicolor/512x512/apps/texas-holdem-gym.png"

cat > "${ROOTFS}/usr/share/applications/texas-holdem-gym.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Texas Hold'em Gym
Comment=Practice Texas Hold'em
Exec=/usr/bin/texas-holdem-gym
Icon=/usr/share/icons/hicolor/512x512/apps/texas-holdem-gym.png
StartupWMClass=Poker
Terminal=false
Categories=Game;
EOF

echo ""
echo "Rootfs ready: ${ROOTFS}"
echo "  Preview:  tree -L 4 \"${ROOTFS}\""
echo "  Test:     chroot \"${ROOTFS}\" /usr/bin/texas-holdem-gym   # needs /dev, /proc, etc. for GUI"
echo "  Merge:    sudo cp -a \"${ROOTFS}\"/* /"
echo ""
