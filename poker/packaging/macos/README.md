# macOS packaging (Texas Hold'em Gym)

Produces a **`.app` bundle** (required for Gatekeeper and `macdeployqt`) and a **`.dmg`** for distribution.

## Prerequisites

- **Xcode** (Command Line Tools sufficient for linking)
- **CMake** ≥ 3.26, **Ninja**
- **Qt 6.10** Desktop for macOS (e.g. `clang_64` kit from the [Qt Online Installer](https://www.qt.io/download))
- **SQLite** (Homebrew): `brew install sqlite`

Ensure CMake finds Qt and SQLite, e.g.:

```bash
export CMAKE_PREFIX_PATH="$HOME/Qt/6.10.0/macos"
# optional if FindSQLite3 fails:
export SQLite3_ROOT="$(brew --prefix sqlite)"
```

## Build & package

From the **repository root**:

```bash
chmod +x poker/packaging/macos/build-release.sh
export CMAKE_PREFIX_PATH="$HOME/Qt/6.10.0/macos"
./poker/packaging/macos/build-release.sh
```

Artifacts:

- `build-macos/poker/Poker.app` — Qt frameworks embedded by `macdeployqt` (with `-libpath=$(brew --prefix sqlite)/lib` so Homebrew's `libsqlite3.dylib` is pulled in and its `LC_LOAD_DYLIB` rewritten to `@rpath/...`), then **signed** (ad-hoc by default, or **Developer ID + optional notarization** if you set the env vars below)
- `dist/macos/TexasHoldemGym-macOS-arm64-<githash>.dmg` or `…-x86_64-…` (architecture from `uname -m`)

After `macdeployqt`, the script walks the bundle with `otool -L` and **fails the build** if any `Poker` or embedded dylib/framework still references `/opt/homebrew/...` or `/usr/local/...` — so a missing Homebrew dependency is caught at build time rather than at launch (where it would be a `dyld: Library not loaded` crash on a user's machine).

Override build dir: `BUILD_DIR=/tmp/poker-build ./poker/packaging/macos/build-release.sh`

The DMG is built with **`hdiutil`** after signing so the image contains a consistently signed bundle. (Building the DMG with `macdeployqt -dmg` *before* signing can ship an app that crashes at launch with **Code Signature Invalid** / **CODESIGNING Invalid Page** while dyld loads a Qt library.)

## Developer ID + notarization (so users are not blocked by Gatekeeper)

You still need an **Apple Developer Program** membership and certificates from Apple — this repo cannot bypass that. What it **does** provide is automation so you do not manually run `xattr`, **Open Anyway**, or one-off `notarytool` commands every time.

### One-time setup (local builds)

1. Create a **Developer ID Application** certificate in Xcode / [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/certificates/list).
2. Note the exact identity string, e.g. `Developer ID Application: Your Name (TEAMID)` (`security find-identity -v -p codesigning`).
3. For notarization, either:
   - **API key (recommended):** create an App Store Connect API key with **Developer** access; download the `.p8` file and note **Key ID** and **Issuer ID** from App Store Connect → Users and Access → Keys.
   - **Apple ID:** create an [app-specific password](https://appleid.apple.com) and use your Apple ID + **Team ID** (10-character team id from the developer account).

### Build with signing + staple (same `build-release.sh`)

From the repo root, **before** `./poker/packaging/macos/build-release.sh`:

```bash
export MACOS_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
# Notarization (optional but required for “download from web opens cleanly”):
export NOTARIZE=1
# Pick ONE auth method:
export NOTARY_KEY_PATH="$HOME/AuthKey_XXXXXXXX.p8"
export NOTARY_KEY_ID="XXXXXXXXXX"
export NOTARY_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
# OR:
# export APPLE_ID="you@example.com"
# export APPLE_TEAM_ID="XXXXXXXXXX"
# export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"

chmod +x poker/packaging/macos/build-release.sh poker/packaging/macos/sign-notarize-release.sh
./poker/packaging/macos/build-release.sh
```

If **`MACOS_SIGN_IDENTITY` is unset**, the script keeps **ad-hoc** signing (current default). If it **is** set, `build-release.sh` calls **`sign-notarize-release.sh`**, which uses **`entitlements.plist`** (hardened runtime + Qt-friendly flags), then optionally **`notarytool submit --wait`** and **`stapler staple`**.

### GitHub Actions (optional repository secrets)

The **macOS** CI job will **Developer ID–sign and notarize** when you add secrets (fork PRs from contributors will not have them, and will keep ad-hoc signing).

| Secret | Purpose |
|--------|--------|
| `MACOS_SIGN_IDENTITY` | Full string, e.g. `Developer ID Application: Name (TEAMID)` |
| `MACOS_CERTIFICATE_P12` | Base64-encoded `.p12` export of the Developer ID **Application** cert + private key |
| `MACOS_CERTIFICATE_PASSWORD` | Password for that `.p12` |
| `MACOS_NOTARIZE` | Set to `1` to run notarization when credentials below are present |
| `APP_STORE_CONNECT_API_KEY_P8` | Base64-encoded contents of the API key `.p8` file |
| `APP_STORE_CONNECT_KEY_ID` | API Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer UUID |

Alternatively for notarization with **Apple ID** instead of the API key:

| Secret | Purpose |
|--------|--------|
| `APPLE_ID_FOR_NOTARY` | Apple ID email |
| `APPLE_TEAM_ID` | 10-character Team ID |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password |

If **`MACOS_SIGN_IDENTITY`** is empty, CI behavior is unchanged (ad-hoc `codesign --sign -`).

## “Malware” / “can’t be opened” / Gatekeeper (this is not a virus scan failure)

Apple’s UI often sounds alarming, but **unsigned or ad-hoc–signed apps are routinely blocked or flagged** even when they are harmless. Builds from this repo are **not** submitted to Apple’s notarization service unless you add **Developer ID Application** signing and run **`notarytool`** yourself.

**If you built or copied the app locally**

- **First launch:** In Finder, **Control-click (or right-click) the app → Open → Open** once. That records an exception for that binary on that Mac.
- **Downloaded / copied from the internet:** The file may have the **quarantine** flag. Remove it (only for files you trust), then open again:
  ```bash
  xattr -dr com.apple.quarantine /path/to/Poker.app
  ```
- **System Settings → Privacy & Security:** After a block, macOS often shows **“Open Anyway”** for a short time; use that if it appears.

**Proper fix for end users (no scary dialogs)**

1. Enroll in the **Apple Developer Program** (~$99/year).
2. Create a **Developer ID Application** certificate in Xcode / developer.apple.com.
3. Sign the **`.app`** with that identity (and hardened runtime / entitlements as required for Qt).
4. **Notarize** with `xcrun notarytool submit` and **`stapler staple`** the app (or DMG), then distribute.

Apple documents this flow under [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution). Until then, treat Gatekeeper messages as **policy**, not proof of malware.

## GitHub Actions

See `.github/workflows/ci.yml` — macOS job on `macos-latest`, uploads the DMG as an artifact. With the optional secrets above, the artifact is suitable for distribution without manual Gatekeeper overrides.
