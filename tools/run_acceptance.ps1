# run_acceptance.ps1 — batch acceptance runs of the headless simulation.
#
# Runs the same scenario across several pinned RNG seeds, several at a time, and
# drops one log per seed under _simruns/<label>/. Pinning the seed matters: the
# game otherwise seeds from os.time(), so a batch launched inside the same
# second would replay the identical world.
#
# Usage (from the repo root):
#   pwsh tools/run_acceptance.ps1 -Label after-fix
#   pwsh tools/run_acceptance.ps1 -Label soak -Scenario survival -Seeds 1,2,3 -Parallel 3
#
# Then summarise with:
#   pwsh tools/summarize_acceptance.ps1 -Label after-fix
#
# NEVER run two batches at once. This script kills every love/lovec process at
# both ends of its run, so a second batch decapitates the first: you get logs
# that stop mid-line, and summarize_acceptance reads the truncated day count as
# though the colony had simply stopped there. Wait for one to print ALL DONE.
#
# TimeoutSec is a safety net for a wedged run, not a budget. A 5-day quick run
# takes 350-700s at -Parallel 4 depending on how much pathfinding the colony
# ends up doing, and a truncated log is indistinguishable from a bad result, so
# the default leaves plenty of headroom.

param(
  [string]$Label      = 'run',
  [string]$Scenario   = 'quick',
  [int[]] $Seeds      = @(101,202,303,404,505,606,707,808),
  [int]   $Parallel   = 4,
  [int]   $TimeoutSec = 1800,
  [string]$LoveExe    = 'F:\LOVE\lovec.exe',  # console build, so stdout redirects
  [switch]$Trace                              # add --coldtrace to every run
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$out  = Join-Path $repo "_simruns\$Label"
New-Item -ItemType Directory -Force -Path $out | Out-Null

if (-not (Test-Path $LoveExe)) { throw "LOVE console build not found at $LoveExe (pass -LoveExe)" }

# A stray run from a previous batch would compete for CPU and skew timings.
Get-Process love,lovec -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

$queue = [System.Collections.Generic.Queue[int]]::new()
foreach ($s in $Seeds) { $queue.Enqueue($s) }
$running = @()

while ($queue.Count -gt 0 -or $running.Count -gt 0) {
  while ($running.Count -lt $Parallel -and $queue.Count -gt 0) {
    $seed = $queue.Dequeue()
    $log  = Join-Path $out "seed_$seed.log"
    $args = @('.', '--simulation', '--scenario', $Scenario, '--seed', "$seed")
    if ($Trace) { $args += '--coldtrace' }
    $p = Start-Process -FilePath $LoveExe `
         -ArgumentList $args `
         -WorkingDirectory $repo `
         -RedirectStandardOutput $log -RedirectStandardError "$log.err" `
         -PassThru -WindowStyle Hidden
    $running += [pscustomobject]@{ Seed = $seed; Proc = $p; Start = Get-Date }
    Write-Host "launched seed $seed (pid $($p.Id))"
  }

  Start-Sleep -Seconds 5
  $still = @()
  foreach ($r in $running) {
    $elapsed = ((Get-Date) - $r.Start).TotalSeconds
    if ($r.Proc.HasExited) {
      Write-Host ("seed {0} exited code {1} after {2:N0}s" -f $r.Seed, $r.Proc.ExitCode, $elapsed)
    } elseif ($elapsed -gt $TimeoutSec) {
      Write-Host "seed $($r.Seed) TIMEOUT after $TimeoutSec s - killing"
      Stop-Process -Id $r.Proc.Id -Force -ErrorAction SilentlyContinue
    } else {
      $still += $r
    }
  }
  $running = $still
}

Get-Process love,lovec -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Host "ALL DONE -> $out"
