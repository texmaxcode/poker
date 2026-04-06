#Requires -Version 5.1
<#
.SYNOPSIS
  Configure Release build, compile Poker, run windeployqt, optional ZIP.

.PARAMETER QtRoot
  Qt 6 install root (contains bin\windeployqt.exe). If empty, uses CMAKE_PREFIX_PATH or QT_ROOT_DIR.

.PARAMETER BuildDir
  CMake build directory (default: repo\build-win)

.PARAMETER StagingDir
  Output folder (default: repo\dist\windows)

.PARAMETER SkipZip
  Do not create TexasHoldemGym-Windows-x64-<githash>.zip

.PARAMETER NoConfigure
  Skip cmake configure/build — only stage, copy sqlite3.dll, windeployqt, zip (CI uses a separate build step).

.EXAMPLE
  $env:CMAKE_PREFIX_PATH = "C:\Qt\6.10.0\msvc2022_64"
  $env:VCPKG_ROOT = "C:\vcpkg"
  .\build-release.ps1
#>

param(
    [string] $QtRoot = "",
    [string] $BuildDir = "",
    [string] $StagingDir = "",
    [switch] $SkipZip,
    [switch] $NoConfigure
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir "..\..\..")).Path

if (-not $BuildDir) { $BuildDir = Join-Path $RepoRoot "build-win" }
if (-not $StagingDir) { $StagingDir = Join-Path $RepoRoot "dist\windows" }

$env:QTFRAMEWORK_BYPASS_LICENSE_CHECK = "1"

$gitHash = "unknown"
Push-Location $RepoRoot
try {
    $raw = (& git rev-parse --short=8 HEAD 2>$null)
    if ($raw) { $gitHash = $raw.Trim() }
} finally {
    Pop-Location
}
$env:POKER_GIT_HASH = $gitHash
$projVer = "0.1"
$projLine = Select-String -Path (Join-Path $RepoRoot "CMakeLists.txt") -Pattern '^project\(' | Select-Object -First 1
if ($projLine -match 'VERSION\s+([0-9.]+)') { $projVer = $Matches[1] }
Write-Host "==> Building Windows package version ${projVer}+${gitHash}"

function Find-QtRoot {
    if ($QtRoot) { return $QtRoot }
    if ($env:CMAKE_PREFIX_PATH) {
        $first = ($env:CMAKE_PREFIX_PATH -split ";")[0].Trim()
        if ($first) { return $first }
    }
    if ($env:QT_ROOT_DIR) { return $env:QT_ROOT_DIR }
    throw "Set -QtRoot, CMAKE_PREFIX_PATH, or QT_ROOT_DIR to your Qt 6 installation."
}

function Get-ExePath {
    param([string]$Root)
    # Visual Studio generator: Release output may be poker\Release\ or poker\x64\Release\ (toolset/arch).
    $candidates = @(
        (Join-Path $Root "poker\Release\Poker.exe"),
        (Join-Path $Root "poker\x64\Release\Poker.exe"),
        (Join-Path $Root "poker\RelWithDebInfo\Poker.exe"),
        (Join-Path $Root "poker\x64\RelWithDebInfo\Poker.exe"),
        (Join-Path $Root "poker\Poker.exe")
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    $pokerDir = Join-Path $Root "poker"
    if (Test-Path -LiteralPath $pokerDir) {
        $found = Get-ChildItem -LiteralPath $pokerDir -Filter "Poker.exe" -Recurse -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    throw "Poker.exe not found under $Root — build Release first."
}

$QtInstall = Find-QtRoot
$Windeployqt = Join-Path $QtInstall "bin\windeployqt.exe"
if (-not (Test-Path $Windeployqt)) {
    throw "windeployqt not found: $Windeployqt"
}

$QmlDir = Join-Path $RepoRoot "poker\qml"
if (-not (Test-Path $QmlDir)) { throw "Missing QML dir: $QmlDir" }

if (-not $NoConfigure) {
    $toolchainArg = @()
    if ($env:VCPKG_ROOT) {
        $tc = Join-Path $env:VCPKG_ROOT "scripts\buildsystems\vcpkg.cmake"
        if (Test-Path $tc) {
            $toolchainArg = @("-DCMAKE_TOOLCHAIN_FILE=$tc")
            Write-Host "    vcpkg toolchain: $tc"
        }
    }

    Write-Host "==> Configuring CMake (Release)…"
    $useNinja = [bool](Get-Command ninja -ErrorAction SilentlyContinue)
    if ($useNinja) {
        & cmake -S $RepoRoot -B $BuildDir -G Ninja `
            -DCMAKE_BUILD_TYPE=Release `
            -DCMAKE_PREFIX_PATH=$QtInstall `
            @toolchainArg
    } else {
        & cmake -S $RepoRoot -B $BuildDir -G "Visual Studio 17 2022" -A x64 `
            -DCMAKE_PREFIX_PATH=$QtInstall `
            @toolchainArg
    }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Host "==> Building…"
    if ($useNinja) {
        cmake --build $BuildDir --parallel
    } else {
        cmake --build $BuildDir --config Release --parallel
    }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Host "==> Skipping configure/build (-NoConfigure)"
}

$Exe = Get-ExePath $BuildDir
Write-Host "==> Executable: $Exe"

Write-Host "==> Staging to $StagingDir …"
if (Test-Path $StagingDir) { Remove-Item -Recurse -Force $StagingDir }
New-Item -ItemType Directory -Path $StagingDir | Out-Null
$StageExe = Join-Path $StagingDir "Poker.exe"
Copy-Item -Path $Exe -Destination $StageExe

if ($env:VCPKG_ROOT) {
    $sqliteDll = Join-Path $env:VCPKG_ROOT "installed\x64-windows\bin\sqlite3.dll"
    if (Test-Path $sqliteDll) {
        Copy-Item $sqliteDll $StagingDir
        Write-Host "    Copied sqlite3.dll from vcpkg"
    }
}

Write-Host "==> windeployqt (Qt + QML)…"
& $Windeployqt --qmldir $QmlDir --release $StageExe
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not $SkipZip) {
    $zipName = Join-Path $RepoRoot "TexasHoldemGym-Windows-x64-${gitHash}.zip"
    Write-Host "==> ZIP: $zipName"
    if (Test-Path $zipName) { Remove-Item -Force $zipName }
    Compress-Archive -Path (Join-Path $StagingDir "*") -DestinationPath $zipName
}

Write-Host "==> Done. Run: $StageExe"
