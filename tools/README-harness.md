# REFramework load-test harness

## Why this exists

On 2026-09-23 a script shipped that passed `luac -p` cleanly and still threw
the moment REFramework ran it:

```
global 'restore_pins' is not callable (a nil value)
```

A text edit had accidentally nested a `local function` inside another
function, so the name was out of scope at its call site. That is valid Lua.
Syntax checking cannot see it. A bytecode scan for `_ENV` lookups missed it
too, because Lua prints large constant indices on a separate line and the
grep only matched the inline form.

The only check that catches this class of bug is **actually running the
chunk**. That is what this does.

## Usage

```bash
lua refstub.lua <path-to-script.lua>
REF_TAB=4 REF_DATA=<datadir> REF_EXPECT="researched from" lua refstub.lua script.lua
```

- `REF_DATA` — a folder standing in for `reframework/data/`.
- `REF_TAB`  — which imgui tab index reports as selected.
- `REF_EXPECT` — a string the rendered panel text must contain. This is the
  difference between "it did not throw" and "it actually said the right
  thing"; use it to assert a data file really loaded.

Exit code 0 and `HARNESS PASS` means: the chunk ran, every registered
`on_frame` / `on_draw_ui` / `on_config_save` callback ran, no undeclared
global was read, and any `REF_EXPECT` string was rendered.

## What it is and is not

**Lenient about the ENGINE, strict about LUA.** It cannot simulate Dragon's
Dogma, so `sdk` returns nil for everything — which models "the game is not
loaded" and therefore also tests whether the script guards its lookups. It
IS strict about the script's own control flow, scope and nil-handling.

`sdk.find_type_definition` deliberately returns **nil**, not a chainable
stub. That is a feature: a script that chains straight off it without a
guard will fail here, and should.

## Known results, 2026-09-23

- **44 of 44 dd2-forge scripts pass**, including the questguide across all
  six tabs.
- **CURVES (Nexus #407) fails, and the finding is real but not ours.** It
  does `sdk.find_type_definition("app.BodyEditID"):get_field(...):get_data()`
  unguarded, 21 times, at chunk scope. It works today because those types
  exist. If a title update ever renames one, the whole script dies at load
  with `attempt to index a nil value` and simply stops working. Third-party
  code; recorded, not patched.
- **TrueWarfarerSkillSwapper fails on `require("Hotkeys/Hotkeys")`** — a
  harness limitation, not a bug. That module ships with _ScriptCore and is
  present in game.
- **Menu Performance Fix passes clean.**
