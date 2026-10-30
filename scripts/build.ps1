<#
.SYNOPSIS
    Builds the ThirdAge-Recomp Windows executable from a local default.xbe.

.DESCRIPTION
    Runs the verified XBE analysis, seeded disassembly, function identification,
    ABI analysis, recompilation, and CMake build pipeline. Every python step
    runs with the working directory set to vendor\xboxrecomp. Requires the repo
    virtualenv (.venv), config/seed_functions.json, and
    dump/game_files/default.xbe to be present.

.PARAMETER SkipAnalysis
    Skip the analysis/recompilation steps (1-5) and run only CMake configure
    and build.

.PARAMETER Debug
    Build the Debug configuration instead of the default Release.

.PARAMETER DryRun
    Print every planned command without executing anything. No build output is
    created.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1 -DryRun

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1 -SkipAnalysis -Debug
#>

# Note: [CmdletBinding()] is intentionally omitted because it auto-defines a
# common -Debug parameter that would collide with the [switch]$Debug below.
param(
    [switch]$SkipAnalysis,
    [switch]$Debug,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Resolve the repo root from this script's own location so the build works
# from any current directory. Never rely on the caller's CWD.
# ---------------------------------------------------------------------------
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

$Python        = Join-Path $RepoRoot '.venv\Scripts\python.exe'
$SeedFunctions = Join-Path $RepoRoot 'config\seed_functions.json'
$ManualC       = Join-Path $RepoRoot 'src\recomp_manual.c'
$AnalysisJson  = Join-Path $RepoRoot 'dump\game_files\tta_analysis.json'
$GenDir        = Join-Path $RepoRoot 'src\recomp\gen'
$XbePath       = Join-Path $RepoRoot 'dump\game_files\default.xbe'
$ToolsDir      = Join-Path $RepoRoot 'vendor\xboxrecomp'
$BuildDir      = Join-Path $RepoRoot 'build'

$Configuration = 'Release'
if ($Debug) { $Configuration = 'Debug' }

# Verified generator for Visual Studio 2026; VS 2022 users change this to
# "Visual Studio 17 2022".
$Generator = 'Visual Studio 18 2026'
$CmakeExe  = 'C:\Program Files\CMake\bin\cmake.exe'
if (-not (Test-Path $CmakeExe)) { $CmakeExe = 'cmake' }

# ---------------------------------------------------------------------------
# Pre-flight checks (fail fast, before any pipeline step).
# ---------------------------------------------------------------------------
if (-not (Test-Path $XbePath)) {
    Write-Host ''
    Write-Host 'ERROR: default.xbe not found.' -ForegroundColor Red
    Write-Host "Expected: $XbePath"
    Write-Host 'This game executable is not distributed with the repository.'
    Write-Host 'Extract your own legally owned North American Xbox copy so the'
    Write-Host 'file exists at the path above, then run this script again.'
    exit 1
}

if (-not (Test-Path $Python)) {
    Write-Host ''
    Write-Host 'ERROR: Python virtualenv interpreter not found.' -ForegroundColor Red
    Write-Host "Expected: $Python"
    Write-Host 'Create the venv and install the tooling dependencies listed in'
    Write-Host 'vendor/xboxrecomp, then run this script again.'
    exit 1
}

if (-not (Test-Path $SeedFunctions)) {
    Write-Host ''
    Write-Host 'ERROR: config/seed_functions.json not found.' -ForegroundColor Red
    Write-Host "Expected: $SeedFunctions"
    Write-Host 'This file is required for correct function detection.'
    exit 1
}

if (-not (Test-Path $ToolsDir)) {
    Write-Host ''
    Write-Host 'ERROR: vendor/xboxrecomp is missing.' -ForegroundColor Red
    Write-Host "Expected: $ToolsDir"
    Write-Host 'Initialize the pinned runtime submodule with:'
    Write-Host '  git submodule update --init --recursive'
    exit 1
}

if (-not (Test-Path $CmakeExe) -and -not (Get-Command 'cmake' -ErrorAction SilentlyContinue)) {
    Write-Host ''
    Write-Host 'ERROR: CMake not found.' -ForegroundColor Red
    Write-Host "Looked for: $CmakeExe and 'cmake' on PATH."
    Write-Host 'Install CMake 3.20 or newer and run this script again.'
    exit 1
}

# ---------------------------------------------------------------------------
# Invoke-Step: print and run one pipeline step, stopping on the first failure.
# ---------------------------------------------------------------------------
function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $false)][string[]]$Arguments = @(),
        [Parameter(Mandatory = $false)][string]$WorkingDirectory = $RepoRoot
    )

    Write-Host ''
    Write-Host "=== $Label ===" -ForegroundColor Cyan

    $parts = @()
    $exeDisplay = $Executable
    if ($exeDisplay -match '\s') { $exeDisplay = '"' + $exeDisplay + '"' }
    $parts += $exeDisplay
    foreach ($arg in $Arguments) {
        if ($arg -match '\s') {
            $parts += '"' + $arg + '"'
        } else {
            $parts += $arg
        }
    }
    $line = $parts -join ' '

    if ($DryRun) {
        Write-Host "[dry-run] would run: $line  (cwd: $WorkingDirectory)"
        return
    }

    Write-Host "> $line"

    Push-Location $WorkingDirectory
    try {
        & $Executable @Arguments
        $code = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    if ($code -ne 0) {
        Write-Host ''
        Write-Host "ERROR: '$Label' failed with exit code $code." -ForegroundColor Red
        exit $code
    }
}

# ---------------------------------------------------------------------------
# Pipeline
# ---------------------------------------------------------------------------
$stepIndex = 0
$totalSteps = 7
if ($SkipAnalysis) { $totalSteps = 2 }

Write-Host ''
Write-Host 'ThirdAge-Recomp build' -ForegroundColor Cyan
Write-Host "Repo root    : $RepoRoot"
Write-Host "Configuration: $Configuration"
if ($DryRun) {
    Write-Host 'Mode         : dry-run (commands are printed, nothing executes)'
} elseif ($SkipAnalysis) {
    Write-Host 'Mode         : build only (analysis/recomp skipped)'
} else {
    Write-Host 'Mode         : full pipeline'
}

if (-not $SkipAnalysis) {
    $stepIndex++
    Invoke-Step -Label "[$stepIndex/$totalSteps] Parsing XBE" -Executable $Python -WorkingDirectory $ToolsDir -Arguments @('-m', 'tools.xbe_parser', $XbePath, '--json', $AnalysisJson)

    # --seed-functions is MANDATORY: without it the detector finds 13,816
    # functions instead of 13,829 and the executable fails early at boot.
    $stepIndex++
    Invoke-Step -Label "[$stepIndex/$totalSteps] Disassembling (seeded, all executable sections)" -Executable $Python -WorkingDirectory $ToolsDir -Arguments @('-m', 'tools.disasm', $XbePath, '--text-only', '-v', '--seed-functions', $SeedFunctions, '--extra-sections', 'D3D,XPP,XGRPH,D3DX,DSOUND,DOLBY')

    $stepIndex++
    Invoke-Step -Label "[$stepIndex/$totalSteps] Identifying functions" -Executable $Python -WorkingDirectory $ToolsDir -Arguments @('-m', 'tools.func_id', $XbePath, '-v')

    $stepIndex++
    Invoke-Step -Label "[$stepIndex/$totalSteps] ABI analysis" -Executable $Python -WorkingDirectory $ToolsDir -Arguments @('-m', 'tools.abi_analysis', $XbePath, '-v')

    # --exclude-manual is MANDATORY: without it the link fails with LNK2005
    # (sub_000E4540 already defined) and LNK1169.
    $stepIndex++
    Invoke-Step -Label "[$stepIndex/$totalSteps] Recompiling" -Executable $Python -WorkingDirectory $ToolsDir -Arguments @('-m', 'tools.recomp', $XbePath, '--all', '--split', '1000', '--exclude-manual', $ManualC, '--gen-dir', $GenDir)
}

$stepIndex++
Invoke-Step -Label "[$stepIndex/$totalSteps] CMake configure" -Executable $CmakeExe -Arguments @('-S', $RepoRoot, '-B', $BuildDir, '-G', $Generator, '-A', 'x64')

$stepIndex++
Invoke-Step -Label "[$stepIndex/$totalSteps] CMake build ($Configuration)" -Executable $CmakeExe -Arguments @('--build', $BuildDir, '--config', $Configuration)

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
$ExePath = Join-Path $BuildDir (Join-Path $Configuration 'third_age_recomp.exe')
Write-Host ''
if ($DryRun) {
    Write-Host 'Dry-run finished: no commands were executed and no build output was created.' -ForegroundColor Green
    Write-Host "Planned executable: $ExePath"
} else {
    Write-Host 'Build complete.' -ForegroundColor Green
    Write-Host "Executable: $ExePath"
    Write-Host 'Run it from the repo root so relative data paths resolve:'
    Write-Host "  cd `"$RepoRoot`""
    Write-Host "  .`"$ExePath`""
}
