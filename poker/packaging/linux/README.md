# Linux packaging

## Ubuntu App Center (Snap Store)

Ubuntu’s **Software** app (App Center on Ubuntu 24.04+) shows **snaps** from the [Snap Store](https://snapcraft.io/store). That is the supported path for a graphical Qt app to appear alongside other desktop software.

1. **Build the snap** (from the repository root, after installing Snapcraft):

   ```bash
   sudo snap install snapcraft --classic
   sudo snap install lxd && sudo lxd init --auto   # recommended for clean builds
   ./poker/packaging/linux/build-snap.sh
   # or: snapcraft --use-lxd
   ```

   This uses `snap/snapcraft.yaml` (base **core24**, **kde-neon-6** for Qt 6, strict confinement). The artifact is `texas-holdem-gym_<ver>+githash_*.snap` in the repo root (version from `CMakeLists.txt` `project()` + `git rev-parse --short=8`).

2. **Register and publish** (one-time account on [snapcraft.io](https://snapcraft.io)):

   ```bash
   snapcraft login
   snapcraft register texas-holdem-gym
   snapcraft upload --release=edge texas-holdem-gym_*.snap
   ```

   Promote the revision from **edge** to **stable** in the store dashboard when ready.

3. **AppStream**: `io.github.texasholdemgym.metainfo.xml` is installed on Linux and merged into snap metadata via `parse-info` in `snap/snapcraft.yaml`. After the snap is published, set the `<url type="homepage">` in that file to `https://snapcraft.io/texas-holdem-gym` so store and validator URLs match.

## AppImage

`build-appimage.sh` exports `POKER_GIT_HASH` (8-character prefix of the current commit) for CMake and writes `Texas_Holdem_Gym-x86_64-<githash>.AppImage` at the repo root. Useful for direct downloads; it is not what Ubuntu App Center indexes by default.

Override the hash CMake sees: `POKER_GIT_HASH=abcdef12 ./build-appimage.sh` or `-DPOKER_GIT_HASH_OVERRIDE=…` at configure time.

## Flatpak

See `flatpak/io.github.texasholdemgym.yaml` (stub). Flathub is an alternative store; it does not replace the Snap path for Ubuntu’s default software UI.
