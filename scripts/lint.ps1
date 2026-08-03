# scripts/lint.ps1 — run luacheck the way CI does.
#
# The gate exists for the undefined-GLOBAL class: a `local function` referenced
# before it is defined resolves to a nil global, and nothing fails until that
# path runs. Shipping code (src/, main.lua, conf.lua) is strict; tests get the
# latitude their idioms need. See .luacheckrc.
#
#   powershell -File scripts\lint.ps1

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

$lc = Get-Command luacheck -ErrorAction SilentlyContinue
if (-not $lc) {
    Write-Host "luacheck not found on PATH. Install:  luarocks install luacheck" -ForegroundColor Yellow
    exit 2
}

& luacheck src main.lua conf.lua tests
exit $LASTEXITCODE
