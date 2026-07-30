# summarize_acceptance.ps1 — turn a batch of acceptance logs into one table.
#
# Reads _simruns/<label>/seed_*.log (written by tools/run_acceptance.ps1) and
# reports, per seed: the day reached, how many colonists died, whether the
# colony was wiped, and the inferred cause of each death.
#
# Causes come from the [SimDeath] triage line that colonist.lua prints in
# simulation mode. A death with wounds is a mauling (the attacking species is
# named when the creature AI recorded one); a death at hypo=severe with no
# wounds is exposure.
#
# Usage: pwsh tools/summarize_acceptance.ps1 -Label after-fix

param([string]$Label = 'run')

$repo = Split-Path -Parent $PSScriptRoot
$dir  = Join-Path $repo "_simruns\$Label"
if (-not (Test-Path $dir)) { throw "no such batch: $dir" }

$rows = @()
foreach ($f in Get-ChildItem "$dir\seed_*.log" | Sort-Object Name) {
  $txt  = Get-Content $f.FullName -Raw
  $seed = $f.BaseName -replace 'seed_',''
  if (-not $txt) {
    $rows += [pscustomobject]@{ Seed=$seed; Days='NO OUTPUT'; Deaths=0; Wiped=''; Causes='' }
    continue
  }

  $days    = [regex]::Match($txt, '(?m)^Days: (\d+)/(\d+)')
  $reached = if ($days.Success) { $days.Groups[1].Value } else { '?' }
  $deaths  = ([regex]::Matches($txt, '\[SimDeath\]')).Count
  $wiped   = if ($txt -match 'Colony wiped on day (\d+)') { "day $($Matches[1])" } else { '' }

  $causes  = @()
  $pattern = '\[SimDeath\] .*?hypo=(\w+).*?mauledBy=(\S+) weapon=(\S+) wounds\[(.*?)\]'
  foreach ($m in [regex]::Matches($txt, $pattern)) {
    $hypo   = $m.Groups[1].Value
    $mauled = $m.Groups[2].Value
    $wounds = $m.Groups[4].Value.Trim()
    $attacker = $mauled.Split('/')[0]
    if ($attacker -ne 'none' -and $attacker -ne 'nil') {
      $causes += "mauled($attacker)"
    } elseif ($wounds -ne '') {
      $causes += 'wounds'
    } elseif ($hypo -eq 'severe') {
      $causes += 'hypothermia'
    } else {
      $causes += 'other'
    }
  }

  # Surviving population: the last figure the colonist agent reported, or the
  # scenario's starting crew if nobody ever died.
  $popMatches = [regex]::Matches($txt, 'now at (\d+)')
  $alive = if ($popMatches.Count -gt 0) { $popMatches[$popMatches.Count - 1].Groups[1].Value } else { '3 (no losses)' }

  $rows += [pscustomobject]@{
    Seed   = $seed
    Days   = $reached
    Alive  = $alive
    Deaths = $deaths
    Wiped  = $wiped
    Causes = ($causes -join ', ')
  }
}

$rows | Format-Table -AutoSize | Out-String -Width 240
$reached5 = ($rows | Where-Object { $_.Days -eq '5' }).Count
$wipes    = ($rows | Where-Object { $_.Wiped -ne '' }).Count
$zero     = ($rows | Where-Object { $_.Deaths -eq 0 }).Count
Write-Host "runs=$($rows.Count) reachedDay5=$reached5 zeroDeathRuns=$zero wipes=$wipes"
