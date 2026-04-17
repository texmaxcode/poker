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
    # Visual Studio multi-config: exe may be under poker\Release\, poker\x64\Release\, or CMake/MSBuild may
    # place it under top-level Release\, bin\, etc. Prefer Release over Debug when multiple exist.
    $candidates = @(
        (Join-Path $Root "poker\Release\Poker.exe"),
        (Join-Path $Root "poker\x64\Release\Poker.exe"),
        (Join-Path $Root "Poker\Release\Poker.exe"),
        (Join-Path $Root "Poker\x64\Release\Poker.exe"),
        (Join-Path $Root "poker\RelWithDebInfo\Poker.exe"),
        (Join-Path $Root "poker\x64\RelWithDebInfo\Poker.exe"),
        (Join-Path $Root "Release\Poker.exe"),
        (Join-Path $Root "x64\Release\Poker.exe"),
        (Join-Path $Root "bin\Release\Poker.exe"),
        (Join-Path $Root "poker\Poker.exe")
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    if (-not (Test-Path -LiteralPath $Root)) {
        throw "Build directory does not exist: $Root — build Release first."
    }
    # Last resort: any Poker.exe under the build tree (-Filter with -Recurse is unreliable in Windows PowerShell).
    $all = @(Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ieq "Poker.exe" })
    if ($all.Count -eq 0) {
        Write-Host "==> Debug: listing top-level of build dir $Root"
        Get-ChildItem -LiteralPath $Root -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "     $($_.Name)" }
        throw "Poker.exe not found under $Root — build Release first."
    }
    $release = $all | Where-Object { $_.FullName -match '\\Release\\' -or $_.FullName -match '\\RelWithDebInfo\\' }
    if ($release) {
        return ($release | Select-Object -First 1).FullName
    }
    return $all[0].FullName
}

function Find-DumpBin {
    $cmd = Get-Command dumpbin -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path -LiteralPath $vswhere)) { return $null }
    $inst = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
    if (-not $inst) { return $null }
    $msvcRoot = Join-Path $inst "VC\Tools\MSVC"
    if (-not (Test-Path -LiteralPath $msvcRoot)) { return $null }
    $msvc = Get-ChildItem -LiteralPath $msvcRoot -Directory -ErrorAction SilentlyContinue | Sort-Object { $_.Name } -Descending | Select-Object -First 1
    if (-not $msvc) { return $null }
    $db = Join-Path $msvc.FullName "bin\Hostx64\x64\dumpbin.exe"
    if (Test-Path -LiteralPath $db) { return $db }
    return $null
}

function Get-PeImportDlls {
    param(
        [Parameter(Mandatory = $true)][string] $DumpBin,
        [Parameter(Mandatory = $true)][string] $PePath
    )
    if (-not (Test-Path -LiteralPath $PePath)) { return @() }
    $out = @(& $DumpBin /nologo /dependents $PePath 2>&1 | ForEach-Object { "$_" })
    if ($LASTEXITCODE -ne 0) { return @() }
    $deps = New-Object System.Collections.Generic.List[string]
    foreach ($line in $out) {
        if ($line -match '(?i)^\s+(\S+\.dll)\s*$') {
            $deps.Add($Matches[1])
        }
    }
    return $deps
}

# Windows system DLLs that ship with every install; never missing, so we skip them
# to cut log noise and avoid pointless vcpkg/Qt searches. Plugin chains (e.g. qwindows.dll)
# import many of these, and they are resolved by the OS loader from %SystemRoot%\System32.
$Script:WindowsSystemDlls = @(
    'kernel32.dll','user32.dll','gdi32.dll','gdi32full.dll','advapi32.dll','shell32.dll','ole32.dll',
    'oleaut32.dll','ws2_32.dll','msvcrt.dll','ntdll.dll','winmm.dll','imm32.dll','dwmapi.dll',
    'uxtheme.dll','winspool.drv','netapi32.dll','userenv.dll','crypt32.dll','wintrust.dll',
    'dbghelp.dll','comdlg32.dll','wldap32.dll','iphlpapi.dll','secur32.dll','dnsapi.dll',
    'bcrypt.dll','bcryptprimitives.dll','ncrypt.dll','version.dll','shlwapi.dll','comctl32.dll',
    'rpcrt4.dll','authz.dll','sspicli.dll','d3d9.dll','d3d11.dll','dxgi.dll','d2d1.dll',
    'dwrite.dll','windowscodecs.dll','mf.dll','mfplat.dll','mfreadwrite.dll','propsys.dll',
    'setupapi.dll','cfgmgr32.dll','powrprof.dll','dhcpcsvc.dll','ucrtbase.dll','shcore.dll',
    'combase.dll','coremessaging.dll','kernelbase.dll','sechost.dll','cryptbase.dll',
    'msvcp_win.dll','profapi.dll','winhttp.dll','wtsapi32.dll','userenv.dll','pdh.dll'
) | ForEach-Object { $_.ToLowerInvariant() }
$Script:WindowsSystemDllSet = @{}
foreach ($n in $Script:WindowsSystemDlls) { $Script:WindowsSystemDllSet[$n] = $true }

function Test-IsWindowsSystemDll {
    param([string]$Name)
    if (-not $Name) { return $false }
    $lc = $Name.ToLowerInvariant()
    if ($Script:WindowsSystemDllSet.ContainsKey($lc)) { return $true }
    if ($lc -match '^(api-ms-|ext-ms-)') { return $true }
    # Loader resolves these from %SystemRoot%\System32; not a packaging concern.
    $sysDir = Join-Path $env:SystemRoot "System32\$lc"
    if (Test-Path -LiteralPath $sysDir) { return $true }
    return $false
}

function Copy-TransitiveDllsFromSearchBins {
    <#
    .SYNOPSIS
      For every PE in staging, copy missing dependent .dll from search roots (vcpkg bin, Qt bin).
      Catches zlib→sqlite and any Qt DLL windeployqt did not place (e.g. optional imports).
      Scans staging RECURSIVELY so plugin DLLs in platforms\, styles\, imageformats\,
      iconengines\, sqldrivers\, tls\, and qml\** are also walked (their transitive deps,
      e.g. openssl for tls\qopensslbackend.dll, are copied next to Poker.exe otherwise the
      plugin fails to load at startup with "DLL not found").
    #>
    param(
        [Parameter(Mandatory = $true)][string] $StagingDir,
        [Parameter(Mandatory = $true)][string[]] $SearchBins,
        [string] $DumpBin = ""
    )
    $roots = @($SearchBins | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique)
    if ($roots.Count -eq 0) { return }
    if (-not $DumpBin) {
        $DumpBin = Find-DumpBin
    }
    if (-not $DumpBin -or -not (Test-Path -LiteralPath $DumpBin)) {
        Write-Host "    (skip transitive DLL sync: dumpbin not found — install VS C++ tools or use Developer shell)"
        return
    }
    $queue = New-Object System.Collections.Queue
    Get-ChildItem -LiteralPath $StagingDir -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -match '(?i)^\.(exe|dll)$' } |
        ForEach-Object { $queue.Enqueue($_.FullName) }
    $processed = @{}
    while ($queue.Count -gt 0) {
        $pe = [string]$queue.Dequeue()
        if ($processed.ContainsKey($pe)) { continue }
        $processed[$pe] = $true
        foreach ($dep in (Get-PeImportDlls -DumpBin $DumpBin -PePath $pe)) {
            $name = Split-Path -Leaf $dep
            if (Test-IsWindowsSystemDll $name) { continue }
            # Loader looks next to the PE first, then in Poker.exe's dir (staging root).
            $peDir = Split-Path -Parent $pe
            if (Test-Path -LiteralPath (Join-Path $peDir $name)) { continue }
            $dest = Join-Path $StagingDir $name
            if (Test-Path -LiteralPath $dest) { continue }
            foreach ($bin in $roots) {
                $src = Join-Path $bin $name
                if (Test-Path -LiteralPath $src) {
                    Copy-Item -LiteralPath $src -Destination $dest
                    Write-Host "    Copied runtime: $name (from $bin)"
                    $queue.Enqueue($dest)
                    break
                }
            }
        }
    }
}

function Assert-StagingImportsResolved {
    <#
    .SYNOPSIS
      Walk every PE in staging, enumerate its imports via dumpbin, and report any DLL
      that is neither next to the PE, in the staging root, nor a Windows system DLL.
      This surfaces "app won't start, DLL missing" failures at BUILD time instead of
      runtime on a user's machine.
    #>
    param(
        [Parameter(Mandatory = $true)][string] $StagingDir,
        [string] $DumpBin = ""
    )
    if (-not $DumpBin) { $DumpBin = Find-DumpBin }
    if (-not $DumpBin -or -not (Test-Path -LiteralPath $DumpBin)) {
        Write-Host "    (skip dependency verification: dumpbin not found)"
        return
    }
    $missing = New-Object System.Collections.Generic.List[string]
    $pes = Get-ChildItem -LiteralPath $StagingDir -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -match '(?i)^\.(exe|dll)$' }
    foreach ($pe in $pes) {
        $peDir = $pe.Directory.FullName
        foreach ($dep in (Get-PeImportDlls -DumpBin $DumpBin -PePath $pe.FullName)) {
            $name = Split-Path -Leaf $dep
            if (Test-IsWindowsSystemDll $name) { continue }
            if (Test-Path -LiteralPath (Join-Path $peDir $name)) { continue }
            if (Test-Path -LiteralPath (Join-Path $StagingDir $name)) { continue }
            $rel = [System.IO.Path]::GetRelativePath($StagingDir, $pe.FullName)
            $missing.Add("$rel → $name") | Out-Null
        }
    }
    if ($missing.Count -gt 0) {
        Write-Warning "Unresolved imports in staging (app will fail to start unless these DLLs ship elsewhere on PATH):"
        foreach ($m in ($missing | Select-Object -Unique)) { Write-Warning "    $m" }
        throw "Staging is incomplete: $($missing.Count) unresolved import(s). Fix deployment or extend SearchBins."
    }
    Write-Host "    All PE imports resolve inside the staging tree."
}

function Get-VcpkgInstalledBin {
    if (-not $env:VCPKG_ROOT) { return $null }
    $trip = if ($env:VCPKG_DEFAULT_TRIPLET) { $env:VCPKG_DEFAULT_TRIPLET } else { "x64-windows" }
    $bin = Join-Path $env:VCPKG_ROOT "installed\$trip\bin"
    if (Test-Path -LiteralPath $bin) { return $bin }
    return $null
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

$VcpkgBin = Get-VcpkgInstalledBin
if ($VcpkgBin) {
    $sqliteDll = Join-Path $VcpkgBin "sqlite3.dll"
    if (Test-Path -LiteralPath $sqliteDll) {
        Copy-Item -LiteralPath $sqliteDll -Destination $StagingDir
        Write-Host "    Copied sqlite3.dll from vcpkg ($VcpkgBin)"
    } else {
        Write-Warning "sqlite3.dll not found under vcpkg bin: $VcpkgBin — app will fail at runtime if SQLite is dynamic."
    }
} elseif ($env:VCPKG_ROOT) {
    Write-Warning "VCPKG_ROOT is set but installed\bin not found (check VCPKG_DEFAULT_TRIPLET)."
} else {
    Write-Warning "VCPKG_ROOT not set: sqlite3.dll will not be copied; use vcpkg or place sqlite3.dll next to Poker.exe."
}

Write-Host "==> windeployqt (Qt + QML + MSVC runtime)…"
# --compiler-runtime bundles vcruntime/msvcp/concrt next to the exe so clean Windows installs work without a separate VC++ Redistributable install.
& $Windeployqt --qmldir $QmlDir --release --compiler-runtime $StageExe
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$QtBin = Join-Path $QtInstall "bin"
$extraBins = New-Object System.Collections.Generic.List[string]
if ($VcpkgBin) { [void]$extraBins.Add($VcpkgBin) }
if (Test-Path -LiteralPath $QtBin) { [void]$extraBins.Add($QtBin) }
if ($extraBins.Count -gt 0) {
    Write-Host "==> Transitive DLLs (vcpkg + Qt bin, via dumpbin, recursive into plugins)…"
    Copy-TransitiveDllsFromSearchBins -StagingDir $StagingDir -SearchBins @($extraBins)
}

Write-Host "==> Verifying all imports resolve inside staging…"
Assert-StagingImportsResolved -StagingDir $StagingDir

if (-not $SkipZip) {
    $zipName = Join-Path $RepoRoot "TexasHoldemGym-Windows-x64-${gitHash}.zip"
    Write-Host "==> ZIP: $zipName"
    if (Test-Path $zipName) { Remove-Item -Force $zipName }
    Compress-Archive -Path (Join-Path $StagingDir "*") -DestinationPath $zipName
}

Write-Host "==> Done. Run: $StageExe"
