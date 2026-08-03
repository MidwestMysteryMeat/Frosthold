-- Luacheck configuration for Frosthold.
--
-- The gate that earns its keep is the undefined-GLOBAL check: a `local function`
-- referenced before it is defined resolves to a nil global, and nothing fails
-- until that path runs. Shipping code (src/, main.lua, conf.lua) is strict; the
-- test suite and archived code get the latitude their idioms need.

std = "max"          -- Lua 5.4 + LuaJIT built-ins

-- love is injected by the framework and a LÖVE app SETS its callback fields.
-- The rest are Frosthold's own config flags, set in conf.lua and read across
-- the game — a deliberate global-config convention, declared here so a REAL
-- undefined global still stands out against them.
globals = {
    "love",
    "AUTOPLAY", "AUTOPLAY_DAYS", "SIMULATION_TEST", "SIMULATION_SCENARIO",
    "RUN_SEED", "UI_SHOTS", "COLD_TRACE",
}

ignore = {
    "211",   -- unused local
    "212",   -- unused argument
    "213",   -- unused loop variable
    "231",   -- local never accessed
    "241",   -- local mutated but never accessed (a table built for a future read)
    "311",   -- value assigned is never used
    "411",   -- redefining a local (re-declared per block)
    "412",   -- redefining an argument
    "421",   -- shadowing a local
    "431",   -- shadowing an upvalue (closure-factory / reused math locals)
    "512",   -- loop executed at most once (pairs empty-check / first-value idioms)
    "542",   -- empty if branch
    "581",   -- boolean-equality spelling
    "611", "612", "614", "621", "631",   -- whitespace / indent / line length
}

max_line_length = false

-- Archived, generated and non-source trees are not linted.
exclude_files = {
    "archive/",
    "_simruns/",
    "_uishots/",
    "proposals/",
    "lore/",
    "docs/",
}

-- The tests use a love mock and are written loosely (re-declared locals per
-- block, throwaway globals) — relaxed so the shipping code stays strict.
files["tests/"] = {
    ignore = { "111", "121", "122", "331", "411", "412", "413" },
}
