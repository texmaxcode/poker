#Requires -Version 5.1
<#
.SYNOPSIS
  Build a single-file Windows setup (.exe) with Inno Setup from an already-staged dist\windows tree.

.PARAMETER StagingDir
  Folder produced by build-release.ps1 (default: repo\dist\windows).

.PARAMETER IssPath
  Path to TexasHoldemGym.iss (default: next to this script).

.PARAMETER IsccPath
  Full path to ISCC.exe; if empty, searches Program Files and PATH.

.EXAMPLE
  .\build-release.ps1
  .\build-installer.ps1
#>

param(
    [string] $StagingDir = "",
    [string] $IssPath = "",
    [string] $IsccPath = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir "..\..\..")).Path

if (-not $StagingDir) { $StagingDir = Join-Path $RepoRoot "dist\windows" }
if (-not $IssPath) { $IssPath = Join-Path $ScriptDir "TexasHoldemGym.iss" }

$stage = (Resolve-Path -LiteralPath $StagingDir).Path
$iss = (Resolve-Path -LiteralPath $IssPath).Path

if (-not (Test-Path -LiteralPath (Join-Path $stage "Poker.exe"))) {
    throw "Staged Poker.exe not found. Run build-release.ps1 first. StagingDir=$stage"
}

$gitHash = "unknown"
Push-Location $RepoRoot
try {
    $raw = (& git rev-parse --short=8 HEAD 2>$null)
    if ($raw) { $gitHash = $raw.Trim() }
} finally {
    Pop-Location
}

$projVer = "0.1.0"
$projLine = Select-String -Path (Join-Path $RepoRoot "CMakeLists.txt") -Pattern '^project\(' | Select-Object -First 1
if ($projLine -match 'VERSION\s+([0-9.]+)') { $projVer = $Matches[1] }

function Find-Iscc {
    param([string] $Explicit)
    if ($Explicit -and (Test-Path -LiteralPath $Explicit)) { return $Explicit }
    $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($p in @(
            (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
            (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
        )) {
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

$iscc = Find-Iscc -Explicit $IsccPath
if (-not $iscc) {
    throw "ISCC.exe not found. Install Inno Setup 6 from https://jrsoftware.org/isdl.php or pass -IsccPath."
}

Write-Host "==> Inno Setup: $iscc"
Write-Host "    Staging:  $stage"
Write-Host "    Version:  $projVer ($gitHash)"

$stagingArg = "/DStagingAbs=$stage"
$verArg = "/DMyAppVersion=$projVer"
$hashArg = "/DMyGitHash=$gitHash"

& $iscc $stagingArg $verArg $hashArg $iss
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> Installer output under $(Join-Path $RepoRoot 'dist')"
