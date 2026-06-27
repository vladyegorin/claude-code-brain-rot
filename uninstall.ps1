#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot

Write-Host ""
Write-Host "Claude Code Brain Rot - Windows Uninstaller" -ForegroundColor Cyan
Write-Host ""

# ── Python check ─────────────────────────────────────────────────────────────
Write-Host "Checking Python..." -NoNewline
$pyCmd = ""
try {
    $pyOut = & python --version 2>&1
    $pyVersion = ($pyOut -replace "Python ", "").Trim()
    $parts = $pyVersion.Split(".")
    if ([int]$parts[0] -lt 3 -or ([int]$parts[0] -eq 3 -and [int]$parts[1] -lt 8)) {
        Write-Host " FAIL" -ForegroundColor Red
        Write-Host "  Python 3.8+ required (found $pyVersion)."
        Write-Host "  Install: winget install Python.Python.3"
        exit 1
    }
    $pyCmd = "python"
    Write-Host " OK ($pyVersion)" -ForegroundColor Green
} catch {
    Write-Host " NOT FOUND" -ForegroundColor Red
    Write-Host "  Install Python: winget install Python.Python.3"
    exit 1
}

# ── Remove settings entries ───────────────────────────────────────────────────
Write-Host "Removing settings entries..." -NoNewline
& $pyCmd (Join-Path $repoRoot "scripts\merge_settings.py") remove --repo-root $repoRoot | Out-Null
Write-Host " OK" -ForegroundColor Green

# ── Remove slash command files ────────────────────────────────────────────────
Write-Host "Removing slash commands..." -NoNewline
$commandsDest = Join-Path $env:USERPROFILE ".claude\commands"
$repoCommandsDir = Join-Path $repoRoot "commands"
if (Test-Path $repoCommandsDir) {
    foreach ($file in (Get-ChildItem -Path $repoCommandsDir -Filter "*.md" -ErrorAction SilentlyContinue)) {
        $target = Join-Path $commandsDest $file.Name
        if (Test-Path $target) {
            Remove-Item -Path $target -Force -Confirm:$false
        }
    }
} else {
    # Fallback: remove brainrot-*.md files installed by this plugin
    if (Test-Path $commandsDest) {
        foreach ($file in (Get-ChildItem -Path $commandsDest -Filter "brainrot-*.md" -ErrorAction SilentlyContinue)) {
            Remove-Item -Path $file.FullName -Force -Confirm:$false
        }
    }
}
Write-Host " OK" -ForegroundColor Green

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Done! Brain rot has been uninstalled." -ForegroundColor Green
Write-Host "Your ~/.brainrot state directory has been preserved."
Write-Host ""
