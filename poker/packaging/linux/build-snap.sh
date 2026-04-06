#!/usr/bin/env bash
# Build a strict-confined Snap for Texas Hold'em Gym (Qt 6 via kde-neon-6, SQLite).
#
# Ubuntu App Center (Ubuntu 24.04+ Software) lists snaps from the Snap Store. Build the
# .snap here, then publish with `snapcraft upload` after registering the name on the store.
#
# Prerequisites: snapcraft (snap install snapcraft --classic), LXD recommended:
#   sudo snap install lxd && sudo lxd init --auto
#   snapcraft  # or: snapcraft --use-lxd
#
# Project file: repo root snap/snapcraft.yaml (source is the repository root).
#
# Output (repo root): texas-holdem-gym_<version>+githash_*.snap (version from adopt-info + git).
#
# Usage:
#   ./build-snap.sh
#   ./build-snap.sh pack --output /tmp/out.snap
#
set -euo pipefail

export QTFRAMEWORK_BYPASS_LICENSE_CHECK="${QTFRAMEWORK_BYPASS_LICENSE_CHECK:-1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

cd "${REPO_ROOT}"
_git="$(git -C "${REPO_ROOT}" rev-parse --short=8 HEAD 2>/dev/null || echo unknown)"
_ver="$(grep '^project(' "${REPO_ROOT}/CMakeLists.txt" | head -1 | sed -E 's/.*VERSION ([0-9.]+).*/\1/')"
[[ -z "${_ver}" ]] && _ver="0.1"
echo "==> Snap package version will be ${_ver}+${_git} (from CMakeLists project() + git)"
exec snapcraft "$@"
