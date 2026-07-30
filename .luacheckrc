-- Static analysis config for Frosthold.
--
--   luacheck .          -- must exit with 0 errors; run before every commit
--
-- The goal is a meaningful gate, not a wall of noise. Anything that can crash or
-- silently misbehave at runtime fails. Purely cosmetic warnings are muted below,
-- each with a stated reason.

std = "lua51+love"
cache = true
codes = true

exclude_files = {
    "proposals/**",   -- generator output, untracked
    "assets/**",
    "archive/**",     -- kept for reference, not built
    "tools/**",       -- Python and standalone editors
}

-- Debug/automation switches read across modules. All are set from the launch
-- scripts or the simulation harness, never by gameplay code.
globals = {
    "AUTOPLAY",             -- run the colony unattended (run.bat / launch scripts)
    "AUTOPLAY_DAYS",        -- how many in-game days AUTOPLAY should run
    "SIMULATION_TEST",      -- tests/run_simulation_test.bat
    "SIMULATION_SCENARIO",  -- which scenario the simulation harness loads
    "RUN_SEED",             -- pinned RNG seed for reproducible runs
    "COLD_TRACE",           -- verbose cold/thermal logging
    "UI_SHOTS",             -- headless UI screenshot capture
}

-- Not enforced yet. Style debt, not defects:
ignore = {
    "211",  -- unused local
    "212",  -- unused argument (interface-conformance stubs)
    "213",  -- unused loop variable, idiomatic in `for _, v in ipairs(...)`
    "542",  -- empty if branch, used as explicit "do nothing" markers
    "421",  -- shadowing a local, common in long draw/update functions
}

-- This codebase predates any line-length rule. Reflowing wide data tables
-- mechanically risks corrupting string literals for no functional gain.
max_line_length = false

files["main.lua"] = { allow_defined_top = true }
files["conf.lua"] = { globals = { "love" } }
files["tests/**"] = {
    -- The harness installs a mock love and shares helpers between test files.
    globals = { "love" },
    allow_defined_top = true,
}
