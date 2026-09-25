#!/bin/bash
# dd2forge nameplates v2 -- behaviour tests.
# The fake world: 30 spawned characters, 6 of which the game has names for,
# one in ten missing a Head_0 joint, distances 0,4,8,... metres.
cd "$(dirname "$0")"
D="$(dirname "$0")/data"
pass=0; fail=0
cfg() { python3 -c "
import json,sys
c=dict(on=True,radius=40,max_plates=24,hide_unnamed=True,show_id=False,show_dist=True,
       include_pawns=False,y_offset=0.20,colour=4293984255,colour_near=4287024008,near_m=8,
       use_font=False,font_file='simsun.ttc',font_size=24)
for kv in sys.argv[1:]:
    k,v=kv.split('=',1); c[k]=json.loads(v)
json.dump(c,open('$D/dd2forge/nameplates_prefs.json','w'))
" "$@"; }
t() { local label="$1"; local exp="$2"; shift 2
  local neg=0; case "$exp" in !*) neg=1; exp="${exp#!}";; esac
  out=$(env REF_FRAMES=3 REF_FAKE_NPCS=30 REF_DUMP_DRAWN=1 REF_DATA="$D" "$@" \
        lua refstub.lua dd2forge_6see_nameplates.lua 2>&1)
  local hit=0; echo "$out" | grep -qF "$exp" && hit=1
  local ok=0
  [ $neg -eq 0 ] && [ $hit -eq 1 ] && ok=1
  [ $neg -eq 1 ] && [ $hit -eq 0 ] && ok=1
  echo "$out" | grep -q "FAILED\|DO NOT EXIST\|UNDECLARED\|!!HARNESS" && ok=0
  if [ $ok -eq 1 ]; then printf '  ok    %-40s\n' "$label"; pass=$((pass+1))
  else printf '  FAIL  %-40s (expect%s "%s")\n' "$label" "$([ $neg -eq 1 ] && echo ' NOT')" "$exp"
       echo "$out" | tail -5 | sed 's/^/        /'; fail=$((fail+1)); fi
}

echo "-- names come from the game's own NPC data first"
cfg; t "named NPC plated"                    "Wilhelmina"
cfg; t "uses the live NPC source"            "from the game's own NPC data"
cfg; t "unnamed characters hidden"           '!ch310030'
cfg hide_unnamed=false; \
     t "untick -> unnamed plated by id"      "ch310030"

echo "-- the enum JSON is the fallback, not the primary"
cfg; t "fallback used when getNPCData is nil" "from the enum fallback"  REF_NO_NPCDATA=1
cfg; t "fallback still yields a real name"    "Wilhelmina"              REF_NO_NPCDATA=1

echo "-- the engine's own distance drives culling and sort"
cfg radius=5;  t "5m radius keeps the 4m one"  "Wilhelmina"
cfg radius=5;  t "5m radius drops the 8m one"  '!Cliodhna'
cfg max_plates=1; t "cap 1 keeps the nearest"  "Wilhelmina"
cfg max_plates=1; t "cap 1 drops the rest"     '!Cliodhna'
cfg; t "distance suffix from get_DistanceSqFromPlayer" "4m"

echo "-- head bone, and the characters that lack one"
# every 10th fake character has no Head_0 joint; #20 sits at ~32m so the
# nearest-first cap does not eat it before the joint fallback is reached
cfg hide_unnamed=false; t "no Head_0 still gets a plate"  "ch310020"

echo "-- degraded states"
cfg; t "behind camera -> nothing drawn"      '!Wilhelmina'  REF_NO_PROJECT=1
cfg on=false; t "toggled off -> nothing drawn" '!Wilhelmina'
cfg;              t "id hidden by default"    '!\[310001\]'
cfg show_id=true; t "id suffix when asked for" "[310001]"

echo
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
