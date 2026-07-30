# collect_uishots.ps1 — capture a screenshot of every major panel.
#
# Runs the game with --uishots, which boots a colony, opens each panel in turn
# and writes a PNG into the Love save directory, then copies those PNGs into the
# gitignored _uishots\ folder in the repo (images are never committed).
#
# Usage (from the repo root):
#   pwsh tools/collect_uishots.ps1
#   pwsh tools/collect_uishots.ps1 -Label after-overhaul

param(
  [string]$Label      = 'panels',
  [int]   $TimeoutSec = 240,
  [string]$LoveExe    = 'F:\LOVE\lovec.exe',
  [string]$SaveDir    = "$env:APPDATA\LOVE\frosthold"
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$out  = Join-Path $repo "_uishots\$Label"

if (-not (Test-Path $LoveExe)) { throw "LOVE console build not found at $LoveExe (pass -LoveExe)" }

# Old shots in the save dir would be copied as if they were from this run.
if (Test-Path $SaveDir) {
  Get-ChildItem -Path $SaveDir -Filter 'uishot_*.png' -ErrorAction SilentlyContinue |
    Remove-Item -Force
}

New-Item -ItemType Directory -Force -Path $out | Out-Null
$log = Join-Path $out 'run.log'

Write-Host "running $LoveExe . --uishots"
$p = Start-Process -FilePath $LoveExe `
     -ArgumentList '.', '--uishots' `
     -WorkingDirectory $repo `
     -RedirectStandardOutput $log -RedirectStandardError "$log.err" `
     -PassThru

if (-not $p.WaitForExit($TimeoutSec * 1000)) {
  Write-Host "TIMEOUT after $TimeoutSec s - killing"
  Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
}

$shots = Get-ChildItem -Path $SaveDir -Filter 'uishot_*.png' -ErrorAction SilentlyContinue
if (-not $shots) { throw "no screenshots produced; see $log" }

foreach ($s in $shots) {
  Copy-Item -Path $s.FullName -Destination (Join-Path $out $s.Name) -Force
  Write-Host ("  {0}  ({1:N0} KB)" -f $s.Name, ($s.Length / 1KB))
}

Write-Host "$($shots.Count) screenshots -> $out"
