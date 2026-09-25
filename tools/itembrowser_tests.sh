#!/bin/bash
# dd2forge item browser -- behaviour tests, driven through the real filter.
# REF_FAKE_GRANT=2 = grant script loaded, no save: falls back to the snapshot.
cd "$(dirname "$0")"
pass=0; fail=0
t() {
  local q="$1"; local exp="$2"; shift 2
  out=$(env REF_TAB=1 REF_FAKE_GRANT=2 REF_DATA=$(dirname "$0")/data \
        REF_GLOBALS=DD2FORGE_GRANT REF_QUERY="$q" REF_EXPECT="$exp" "$@" \
        lua refstub.lua dd2forge_5item_browser.lua 2>&1)
  if echo "$out" | grep -q "HARNESS PASS"; then
    printf '  ok    %-26s -> %s\n' "[$q]" "$exp"; pass=$((pass+1))
  else
    printf '  FAIL  %-26s -> %s\n' "[$q]" "$exp"; echo "$out" | tail -4 | sed 's/^/        /'; fail=$((fail+1))
  fi
}
echo "-- search grammar (1004 snapshot entries, 143 of them named Invalid)"
t ""              "861 of 1004 items shown"
t "rift"          "2 of 1004 items shown"
t "hunk of rift"  "2 of 1004 items shown"
t '"giant hunk"'  "1 of 1004 items shown"
t "rift -giant"   "1 of 1004 items shown"
t "ferrystone"    "1 of 1004 items shown"
t "zzzznothing"   "nothing matches"
echo "-- #id is exact when that id exists, fuzzy only when it does not"
t "#61"           "1 of 1004 items shown"
t "#999999"       "nothing matches"
t "#106"          "10 of 1004 items shown"
echo "-- the search-field selector actually restricts the field"
t "1005"          "1 of 1004 items shown"
t "1005"          "nothing matches"              REF_MODE=1
t "ferrystone"    "nothing matches"              REF_MODE=2
echo "-- Invalid entries are hidden by default and kept, never dropped"
t ""              "1004 of 1004 items shown"     REF_SHOW_INVALID=1
echo "-- category filter"
t ""              "2 of 1004 items shown"        REF_CAT=RiftCrystal
echo "-- the seam to dd2forge_2do_grant.lua (both chunks, one environment)"
i() { # i <tab> <expected>
  out=$(env REF_TAB="$1" REF_FRAMES=3 REF_DATA=$(dirname "$0")/data \
        REF_PRELOAD=$(dirname "$0")/dd2forge_2do_grant.lua REF_EXPECT="$2" \
        lua refstub.lua dd2forge_5item_browser.lua 2>&1)
  if echo "$out" | grep -q "HARNESS PASS"; then
    printf '  ok    %-26s -> %s\n' "tab $1 + grant" "$2"; pass=$((pass+1))
  else
    printf '  FAIL  %-26s -> %s\n' "tab $1 + grant" "$2"; echo "$out" | tail -4 | sed 's/^/        /'; fail=$((fail+1))
  fi
}
# Reads pace=8 off the real API, and reports no undeclared globals, which
# together prove the global actually crossed the chunk boundary.
i 4 "chunk every 8 frames"
i 1 "items shown"

echo "-- the virtualised list survives every scroll position"
for sc in 0 400 4000 18000 100000; do
  out=$(env REF_TAB=1 REF_FRAMES=3 REF_SCROLL=$sc REF_FAKE_GRANT=2 \
        REF_DATA=$(dirname "$0")/data REF_GLOBALS=DD2FORGE_GRANT \
        lua refstub.lua dd2forge_5item_browser.lua 2>&1)
  if echo "$out" | grep -q "PANEL ERROR\|FAILED\|DO NOT EXIST"; then
    printf '  FAIL  scroll %-20s\n' "$sc"; echo "$out" | tail -4 | sed 's/^/        /'; fail=$((fail+1))
  else
    printf '  ok    scroll %-20s -> no panel error\n' "$sc"; pass=$((pass+1))
  fi
done

echo
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
