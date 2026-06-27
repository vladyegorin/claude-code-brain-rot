#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot

Write-Host ""
Write-Host "Claude Code Brain Rot - Windows Installer" -ForegroundColor Cyan
Write-Host ""

# ── Python check ─────────────────────────────────────────────────────────────
Write-Host "Checking Python..." -NoNewline
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
    Write-Host " OK ($pyVersion)" -ForegroundColor Green
} catch {
    Write-Host " NOT FOUND" -ForegroundColor Red
    Write-Host "  Install Python: winget install Python.Python.3"
    exit 1
}

# ── mpv check ─────────────────────────────────────────────────────────────────
Write-Host "Checking mpv..." -NoNewline
$mpvCandidates = @(
    "mpv",
    "C:\Program Files\MPV Player\mpv.exe",
    "C:\Program Files\mpv\mpv.exe",
    "C:\Program Files (x86)\mpv\mpv.exe",
    (Join-Path $env:USERPROFILE "scoop\shims\mpv.exe")
)
$mpvFound = $false
foreach ($c in $mpvCandidates) {
    try {
        $result = & $c --version 2>&1
        if ($LASTEXITCODE -eq 0) { $mpvFound = $true; break }
    } catch {}
}
if ($mpvFound) {
    Write-Host " OK" -ForegroundColor Green
} else {
    Write-Host " NOT FOUND" -ForegroundColor Yellow
    Write-Host "  Videos won't play until mpv is installed."
    Write-Host "  Install: winget install mpv"
    Write-Host "  Then re-run this installer (or just start using Claude Code - it will warn)."
}

# ── Merge settings into ~/.claude/settings.json ───────────────────────────────
Write-Host "Merging hooks and permissions into ~/.claude/settings.json..." -NoNewline
& python (Join-Path $repoRoot "scripts/merge_settings.py") add --repo-root $repoRoot --py-cmd "python" | Out-Null
Write-Host " OK" -ForegroundColor Green

# ── Copy slash commands to ~/.claude/commands/ (with absolute path substitution) ─
Write-Host "Installing slash commands to ~/.claude/commands/..." -NoNewline
$claudeCommandsDir = Join-Path $env:USERPROFILE ".claude\commands"
New-Item -ItemType Directory -Force $claudeCommandsDir | Out-Null
$brainRotAbs = (Join-Path $repoRoot "brain_rot.py") -replace "\\", "/"
foreach ($file in (Get-ChildItem -Path (Join-Path $repoRoot "commands") -Filter "*.md")) {
    $content = Get-Content $file.FullName -Raw
    $content = $content -replace "brain_rot\.py", $brainRotAbs
    Set-Content -Path (Join-Path $claudeCommandsDir $file.Name) -Value $content -NoNewline
}
Write-Host " OK" -ForegroundColor Green

# ── Create state directory ────────────────────────────────────────────────────
Write-Host "Creating ~/.brainrot state directory..." -NoNewline
New-Item -ItemType Directory -Force (Join-Path $env:USERPROFILE ".brainrot") | Out-Null
Write-Host " OK" -ForegroundColor Green

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Done!" -ForegroundColor Green
Write-Host "Brain rot is now active in every Claude Code project."
Write-Host "Try /brainrot-severity max for the full experience."
Write-Host ""
