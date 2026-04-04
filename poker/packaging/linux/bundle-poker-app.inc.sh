# shellcheck shell=bash
# Source after setting: BINARY (built Poker), PREFIX (private app root, e.g. …/libexec/poker-gym or ~/poker-gym).
# Populates: PREFIX/{libexec/Poker,lib,lib/qt6/plugins}
[[ -n "${BINARY:-}" && -n "${PREFIX:-}" ]] || {
  echo "bundle-poker-app.inc.sh: set BINARY and PREFIX before sourcing" >&2
  return 1 2>/dev/null || exit 1
}

is_system_lib() {
  local f="$1"
  case "$f" in
    /lib/*|/lib64/*|/usr/lib/*|/usr/lib64/*) return 0 ;;
  esac
  return 1
}

first_qt="$(ldd "${BINARY}" 2>/dev/null | awk '/libQt6Core\.so/ {print $3; exit}')"
[[ -n "${first_qt}" && -f "${first_qt}" ]] || {
  echo "could not locate libQt6Core via ldd on ${BINARY}" >&2
  return 1 2>/dev/null || exit 1
}
QT_LIB_DIR="$(dirname "$(readlink -f "${first_qt}")")"
QT_PREFIX="$(cd "${QT_LIB_DIR}/.." && pwd)"
[[ -d "${QT_PREFIX}/plugins" ]] || {
  echo "expected Qt plugins at ${QT_PREFIX}/plugins" >&2
  return 1 2>/dev/null || exit 1
}

echo "==> Qt prefix: ${QT_PREFIX}"

install -d "${PREFIX}/libexec" "${PREFIX}/lib" \
  "${PREFIX}/lib/qt6/plugins/platforms" \
  "${PREFIX}/lib/qt6/plugins/imageformats" \
  "${PREFIX}/lib/qt6/plugins/xcbglintegrations" \
  "${PREFIX}/lib/qt6/plugins/wayland-decoration-client" \
  "${PREFIX}/lib/qt6/plugins/wayland-shell-integration" \
  "${PREFIX}/lib/qt6/plugins/wayland-graphics-integration-client"

cp -f "${BINARY}" "${PREFIX}/libexec/Poker"
chmod 755 "${PREFIX}/libexec/Poker"

# Poker links SQLite::SQLite3 (persist_sqlite.cpp). Non-Qt deps under /usr/lib are normally left on the
# system (is_system_lib); copy libsqlite3 so PREFIX is self-contained when LD_LIBRARY_PATH prefers
# ${PREFIX}/lib (AppImage, air-gapped trees). Qt's libqsqlite.so also resolves against this copy.
if sqlite_bundle_path="$(ldd "${PREFIX}/libexec/Poker" 2>/dev/null | awk '/libsqlite3\.so/ && $2 == "=>" && $3 ~ /^\// {print $3; exit}')"; then
  if [[ -n "${sqlite_bundle_path}" && -f "${sqlite_bundle_path}" ]]; then
    sqlite_real="$(readlink -f "${sqlite_bundle_path}")"
    sqlite_bn="$(basename "${sqlite_real}")"
    if [[ ! -f "${PREFIX}/lib/${sqlite_bn}" ]]; then
      cp -f "${sqlite_real}" "${PREFIX}/lib/${sqlite_bn}"
      echo "    bundled ${sqlite_bn} (SQLite3, linked by Poker)"
    fi
  fi
fi

declare -A SEEN
queue=()
enqueue() {
  local p="$1"
  [[ -f "$p" ]] || return
  local r
  r="$(readlink -f "$p")"
  [[ -n "${SEEN[$r]:-}" ]] && return
  SEEN[$r]=1
  is_system_lib "$r" && return
  queue+=("$r")
}

while IFS= read -r dep; do
  [[ -n "$dep" && -f "$dep" ]] && enqueue "$dep"
done < <(ldd "${PREFIX}/libexec/Poker" 2>/dev/null | awk '$2 == "=>" && $3 ~ /^\// {print $3}')

enqueue_qt6_soname() {
  local f="${QT_LIB_DIR}/${1}"
  [[ -e "$f" ]] || return
  enqueue "$(readlink -f "$f")"
}
# Minimum set (always enqueue before full SDK sweep).
for son in libQt6Quick.so.6 libQt6QuickControls2.so.6 libQt6QuickControls2Impl.so.6 libQt6QuickTemplates2.so.6 \
           libQt6QuickLayouts.so.6 libQt6QmlModels.so.6 libQt6QmlMeta.so.6 libQt6OpenGL.so.6; do
  enqueue_qt6_soname "$son"
done

# Entire Qt 6 versioned *.so.* set from this SDK (~100MB) so QML/plugins never miss an Impl/style/network dep.
echo "==> Enqueue all libQt6*.so.[0-9]* from ${QT_LIB_DIR}"
shopt -s nullglob
for f in "${QT_LIB_DIR}"/libQt6*.so.[0-9]*; do
  [[ -f "$f" ]] || continue
  enqueue "$(readlink -f "$f")"
done
shopt -u nullglob

idx=0
process_queue() {
  while [[ "${idx}" -lt "${#queue[@]}" ]]; do
    lib="${queue[idx]}"
    idx=$((idx + 1))
    base="$(basename "$lib")"
    is_system_lib "$lib" && continue
    [[ -f "${PREFIX}/lib/${base}" ]] && continue
    cp -f "$lib" "${PREFIX}/lib/${base}"
    while IFS= read -r dep; do
      [[ -n "$dep" && -f "$dep" ]] && enqueue "$dep"
    done < <(ldd "$lib" 2>/dev/null | awk '$2 == "=>" && $3 ~ /^\// {print $3}')
  done
}
process_queue

copy_plugin_tree() {
  local name="$1"
  local src="${QT_PREFIX}/plugins/${name}"
  local dst="${PREFIX}/lib/qt6/plugins/${name}"
  if [[ -d "$src" ]]; then
    mapfile -t _plugs < <(find "${src}" -name '*.so' -type f 2>/dev/null || true)
    for plug in "${_plugs[@]:-}"; do
      [[ -f "$plug" ]] || continue
      while IFS= read -r dep; do
        [[ -n "$dep" && -f "$dep" ]] && enqueue "$dep"
      done < <(ldd "$plug" 2>/dev/null | awk '$2 == "=>" && $3 ~ /^\// {print $3}')
    done
    mkdir -p "$dst"
    cp -a "${src}/." "${dst}/"
    echo "    plugins/${name}"
  fi
}

echo "==> Copying Qt plugins"
copy_plugin_tree sqldrivers
copy_plugin_tree platforms
copy_plugin_tree imageformats
copy_plugin_tree iconengines
copy_plugin_tree generic
copy_plugin_tree tls
copy_plugin_tree xcbglintegrations
copy_plugin_tree wayland-decoration-client
copy_plugin_tree wayland-shell-integration
copy_plugin_tree wayland-graphics-integration-client

process_queue

# QML import plugins (e.g. QtQuick/Controls/*.so) dlopen extra Qt libs (QuickControls2Impl, style Impl, …).
if [[ -d "${QT_PREFIX}/qml" ]]; then
  echo "==> Resolving dependencies of QML import plugins (SDK tree)"
  mapfile -t _qmlplugs < <(find "${QT_PREFIX}/qml" -name '*.so' -type f 2>/dev/null || true)
  for plug in "${_qmlplugs[@]:-}"; do
    [[ -f "$plug" ]] || continue
    while IFS= read -r dep; do
      [[ -n "$dep" && -f "$dep" ]] && enqueue "$dep"
    done < <(ldd "$plug" 2>/dev/null | awk '$2 == "=>" && $3 ~ /^\// {print $3}')
  done
  process_queue
fi

# Copies use real versioned filenames (libQt6Qml.so.6.10.0); the dynamic linker resolves SONAMEs like
# libQt6Qml.so.6. Recreate distro-style symlinks so direct libexec/Poker and ldd work.
bundle_link_sonames() {
  local f soname bn
  shopt -s nullglob
  for f in "${PREFIX}/lib"/lib*.so*; do
    [[ -f "$f" && ! -L "$f" ]] || continue
    bn="$(basename "$f")"
    soname="$(LC_ALL=C readelf -d "$f" 2>/dev/null | sed -n '/SONAME/s/.*\[\([^]]*\)\].*/\1/p' | head -1)"
    if [[ -z "$soname" ]]; then
      # Fallback: libQt6Foo.so.6.10.0 → libQt6Foo.so.6 ; libicu*.so.73.2 → libicu*.so.73
      if [[ "$bn" =~ \.so\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        soname="${bn%.*}"
        soname="${soname%.*}"
      elif [[ "$bn" =~ ^libicu.+\.so\.[0-9]+\.[0-9]+$ ]]; then
        soname="${bn%.*}"
      else
        continue
      fi
    fi
    [[ "$bn" == "$soname" ]] && continue
    if [[ ! -e "${PREFIX}/lib/${soname}" ]]; then
      ln -sfn "$bn" "${PREFIX}/lib/${soname}"
    fi
  done
  shopt -u nullglob
}

# QML engine loads QtQuick / Controls / Layouts from the Qt install tree, not only from .so files.
if [[ -d "${QT_PREFIX}/qml" ]]; then
  mkdir -p "${PREFIX}/lib/qt6"
  rm -rf "${PREFIX}/lib/qt6/qml"
  cp -a "${QT_PREFIX}/qml" "${PREFIX}/lib/qt6/qml"
  echo "    bundled Qt/qml (imports: QtQuick, QtQuick.Controls, …)"
else
  echo "==> WARNING: missing ${QT_PREFIX}/qml; QML imports will fail at runtime." >&2
fi

# Staged QML plugins: ldd with bundled lib/ on the path (catches edge deps after tree copy).
if [[ -d "${PREFIX}/lib/qt6/qml" ]]; then
  echo "==> Resolving dependencies of staged QML import plugins"
  _save_ld="${LD_LIBRARY_PATH:-}"
  export LD_LIBRARY_PATH="${PREFIX}/lib:${QT_LIB_DIR}:/usr/lib/x86_64-linux-gnu:/usr/lib/aarch64-linux-gnu:/usr/lib64:/usr/lib"
  mapfile -t _qmlstaged < <(find "${PREFIX}/lib/qt6/qml" -name '*.so' -type f 2>/dev/null || true)
  for plug in "${_qmlstaged[@]:-}"; do
    [[ -f "$plug" ]] || continue
    while IFS= read -r dep; do
      [[ -n "$dep" && -f "$dep" ]] && enqueue "$dep"
    done < <(ldd "$plug" 2>/dev/null | awk '$2 == "=>" && $3 ~ /^\// {print $3}')
  done
  export LD_LIBRARY_PATH="${_save_ld}"
  process_queue
fi

echo "==> SONAME symlinks (e.g. libQt6Qml.so.6 → libQt6Qml.so.6.10.0)"
bundle_link_sonames

bundle_verify_ldd() {
  local line missing=0
  export LD_LIBRARY_PATH="${PREFIX}/lib:/usr/lib/x86_64-linux-gnu:/usr/lib/aarch64-linux-gnu:/usr/lib64:/usr/lib"
  while IFS= read -r line; do
    [[ "$line" == *"not found"* ]] || continue
    echo "==> WARNING: $line" >&2
    missing=1
  done < <(ldd "${PREFIX}/libexec/Poker" 2>/dev/null || true)
  if [[ "${missing}" -eq 0 ]]; then
    echo "==> ldd Poker: no missing libraries (with bundled lib + system paths)"
  fi
}
bundle_verify_ldd

# Do NOT bundle libxcb-cursor: libqxcb.so has RUNPATH \$ORIGIN/../../../lib → this directory. A copy here is
# loaded before a working distro lib; Qt 6.5+ then fails dlopen checks. Use libxcb-cursor0 from the OS
# (LD_LIBRARY_PATH in the launcher includes /usr/lib/.../multiarch).
rm -f "${PREFIX}/lib"/libxcb-cursor.so.0 "${PREFIX}/lib"/libxcb-cursor.so.0.* 2>/dev/null || true

if command -v patchelf >/dev/null 2>&1; then
  echo "==> Setting RUNPATH on bundled ELF files (patchelf)"
  patchelf --set-rpath '$ORIGIN/../lib' "${PREFIX}/libexec/Poker"
  shopt -s nullglob
  for so in "${PREFIX}/lib/"*.so*; do
    [[ -f "$so" && ! -L "$so" ]] || continue
    patchelf --set-rpath '$ORIGIN' "$so" 2>/dev/null || true
  done
  # Qt's libqxcb.so embeds RUNPATH \$ORIGIN/../../../lib → bundled lib/. That shadows distro libxcb-cursor.
  for qxcb in "${PREFIX}/lib/qt6/plugins/platforms"/libqxcb.so*; do
    [[ -f "$qxcb" ]] || continue
    patchelf --remove-rpath "$qxcb" 2>/dev/null || true
  done
  echo "    cleared RUNPATH on platforms/libqxcb.so* (use OS libxcb-cursor0)"
  shopt -u nullglob
else
  echo "==> patchelf not found; install: sudo apt install patchelf  (optional but fixes xcb RPATH). Launcher uses LD_PRELOAD for libxcb-cursor on X11." >&2
fi
