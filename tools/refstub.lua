-- REFramework load-test harness.
-- Actually EXECUTES a mod chunk against stub engine APIs, then drives every
-- registered callback. luac -p only proves a file parses; this proves the
-- chunk RUNS, which is the only thing REFramework actually cares about.
-- Written 2026-09-23 after a nil-call at chunk scope shipped past a clean
-- syntax check and a bytecode global scan that had a blind spot.

local target   = ...
local datadir  = os.getenv("REF_DATA") or "."

local strict = {}
local unknown = {}
setmetatable(strict, { __index = function(_, k)
    unknown[#unknown + 1] = k
    return nil
end })

local callbacks = { frame = {}, ui = {}, save = {} }
_G.__said = {}

-- ------------------------------------------------------------ engine stubs
local function noop() end
local function mkmethod()
    return setmetatable({}, { __index = function() return function() return nil end end,
        __call = function() return nil end })
end

local td_stub
td_stub = setmetatable({}, { __index = function()
    return function() return nil end
end })

-- The engine surface is large and version-dependent. Rather than enumerate it
-- and keep discovering gaps one failure at a time, anything not named here
-- resolves to a function returning nil -- the same shape a real engine call
-- takes when the game is not loaded. The harness is deliberately lenient about
-- the ENGINE and strict about LUA: it cannot simulate Dragon's Dogma, but it
-- can prove the script's own control flow runs.
local sdk = setmetatable({
    find_type_definition   = function() return nil end,
    get_managed_singleton  = function() return nil end,
    to_managed_object      = function() return nil end,
    hook                   = noop,
    to_ptr                 = function(v) return v end,
    typeof                 = function() return nil end,
    call_object_func       = function() return nil end,
    PreHookResult          = { SKIP_ORIGINAL = 1, CALL_ORIGINAL = 0 },
    PostHookResult         = { CALL_ORIGINAL = 0 },
}, { __index = function() return function() return nil end end })

local imgui_calls = 0

-- ⛔ THE STUB USED TO ANSWER TO ANY NAME, which meant a call to an imgui
-- function REFramework does not have sailed straight through the harness and
-- blew up in game instead. That is how imgui.begin_child (real name:
-- begin_child_window) shipped.
--
-- This allowlist is EVIDENCE, not memory: it is every imgui.* name used by
-- the mods in this install that are known to work, plus the ones our own
-- scripts call behind an existence check. Anything outside it is reported.
-- AUTHORITATIVE list, read from REFramework's own binding source
-- (src/mods/bindings/ImGui.cpp) at our exact build commit d1461375 and
-- diffed against master: identical. 143 registrations. If a name is not
-- here, REFramework does not bind it and calling it throws.
local IMGUI_REAL = {}
for _, n in ipairs({
  -- windows / layout
  "begin_window","end_window","begin_child_window","end_child_window",
  "begin_group","end_group","begin_rect","end_rect","begin_disabled",
  "end_disabled","separator","spacing","new_line","same_line","indent",
  "unindent","set_next_window_pos","set_next_window_size","get_window_size",
  "get_window_pos","get_display_size","get_cursor_pos","get_cursor_start_pos",
  "get_cursor_screen_pos","set_cursor_pos","set_cursor_screen_pos",
  "calc_text_size",
  -- widgets
  "button","small_button","invisible_button","arrow_button","checkbox",
  "combo","drag_float","drag_float2","drag_float3","drag_float4","drag_int",
  "slider_float","slider_int","input_text","input_text_multiline",
  "progress_bar","menu_item","color_picker","color_picker_argb",
  "color_picker3","color_picker4","color_edit","color_edit_argb",
  "color_edit3","color_edit4","begin_list_box","end_list_box",
  "begin_menu_bar","end_menu_bar","begin_main_menu_bar","end_main_menu_bar",
  "begin_menu","end_menu","open_popup","begin_popup",
  "begin_popup_context_item","end_popup","close_current_popup","is_popup_open",
  -- trees
  "tree_node","tree_node_ptr_id","tree_node_str_id","tree_pop",
  "collapsing_header","set_next_item_open",
  -- tables
  "begin_table","end_table","table_next_row","table_next_column",
  "table_set_column_index","table_setup_column","table_setup_scroll_freeze",
  "table_headers_row","table_header","table_get_sort_specs",
  "table_get_column_count","table_get_column_index","table_get_row_index",
  "table_get_column_name","table_get_column_flags","table_set_bg_color",
  -- style / ids / text
  "push_style_color","pop_style_color","push_style_var","pop_style_var",
  "push_item_width","pop_item_width","set_next_item_width","calc_item_width",
  "item_size","item_add","text","text_colored","push_id","pop_id","get_id",
  -- tooltips / item state
  "is_item_hovered","is_item_active","is_item_focused","begin_tooltip",
  "end_tooltip","set_tooltip","set_item_default_focus",
  -- fonts / scroll / input / draw
  "load_font","push_font","pop_font","push_font_size","pop_font_size",
  "get_default_font_size","get_scroll_x","get_scroll_y","set_scroll_x",
  "set_scroll_y","get_scroll_max_x","get_scroll_max_y","set_scroll_here_x",
  "set_scroll_here_y","set_scroll_from_pos_x","set_scroll_from_pos_y",
  "get_mouse","get_key_index","is_key_down","is_key_pressed","is_key_released",
  "is_mouse_down","is_mouse_clicked","is_mouse_released","is_mouse_double_clicked",
  "get_window_draw_list","get_background_draw_list","get_foreground_draw_list",
  "draw_list_path_clear","draw_list_path_line_to","draw_list_path_stroke",
  "set_clipboard","get_clipboard",
}) do IMGUI_REAL[n] = true end

-- Nothing is "maybe" any more. These are the names most often assumed to
-- exist that REFramework does NOT bind -- calling any of them is a bug even
-- behind an `if imgui.x then` guard, because the guard silently disables a
-- feature you thought you shipped.
local IMGUI_ABSENT = {}
for _, n in ipairs({
  "selectable","text_wrapped","text_disabled","bullet","bullet_text",
  "begin_child","begin_tab_bar","end_tab_bar","begin_tab_item","end_tab_item",
  "dummy","separator_text","get_content_region_avail","list_box",
  "begin_combo","end_combo","radio_button","input_float","input_int","image",
  "columns","next_column","is_item_clicked","is_window_hovered",
}) do IMGUI_ABSENT[n] = true end

local imgui_unknown = {}
local imgui = setmetatable({}, { __index = function(_, k)
        if not IMGUI_REAL[k] then
            imgui_unknown[k] = true
            return nil          -- same as the real binding: calling it throws
        end
    return function(...)
        imgui_calls = imgui_calls + 1
        -- Capture rendered text so the harness can assert on what the panel
        -- actually SAYS, not merely that it did not throw.
        if k == "text" or k == "text_colored" or k == "text_wrapped" then
            local a = ...
            if type(a) == "string" then _G.__said[#_G.__said + 1] = a end
        end
        -- Return shapes that make the draw code walk as much of itself as
        -- possible: containers open, widgets report "unchanged".
        -- Real imgui returns true for exactly ONE tab item -- the selected
        -- one. A stub that returns true for all of them makes every tab look
        -- identical and hides whichever tab is actually broken.
        if k == "begin_tab_item" then
            _G.__tabn = (_G.__tabn or 0) + 1
            return _G.__tabn == (tonumber(os.getenv("REF_TAB") or "1"))
        end
        if k == "begin_tab_bar" then _G.__tabn = 0 ; return true end
        if k == "tree_node" or k == "begin_window" or k == "collapsing_header" then
            if k == "begin_window" then return true, true end
            return true
        end
        -- begin_child_window's 2nd argument is a SIZE (Vector2f or a
        -- 2-element table), never a bare number. Passing two floats silently
        -- shifted every later argument and cost a release.
        if k == "begin_child_window" then
            local _, size = ...
            if type(size) == "number" then
                _G.__said[#_G.__said + 1] = "!!HARNESS: begin_child_window got a number for size"
            end
            return true
        end
        -- GEOMETRY. These used to return nil, which meant any mod doing its
        -- own layout maths -- a hand-rolled list clipper, say -- threw on the
        -- first ".y" and the throw got swallowed by the panel's own pcall.
        -- The harness reported PASS on a panel that rendered nothing but an
        -- error string. Returning plausible numbers is what makes the
        -- virtualisation path actually get walked.
        if k == "get_cursor_pos" or k == "get_cursor_start_pos"
           or k == "get_cursor_screen_pos" then
            _G.__cursor_y = (_G.__cursor_y or 0) + 22   -- a believable row step
            return { x = 8, y = _G.__cursor_y }
        end
        if k == "get_window_size"  then return { x = 1000, y = 640 } end
        if k == "get_window_pos"   then return { x = 0, y = 0 } end
        if k == "get_display_size" then return { x = 2560, y = 1440 } end
        if k == "calc_text_size"   then return { x = 80, y = 16 } end
        if k == "get_scroll_y" then return tonumber(os.getenv("REF_SCROLL") or "0") end
        if k == "get_scroll_x" then return 0 end
        if k == "get_scroll_max_y" or k == "get_scroll_max_x" then return 100000 end
        if k == "get_default_font_size" then return 16 end
        if k == "checkbox" then local _, v = ...; return false, v end
        if k == "drag_int" or k == "slider_int" or k == "input_text_multiline"
           or k == "drag_float2" or k == "drag_float3" or k == "drag_float4" then
            local _, v = ...; return false, v
        end
        if k == "input_text" or k == "combo" or k == "slider_float"
           or k == "drag_float" then local _, v = ...; return false, v end
        if k == "button" or k == "small_button" or k == "selectable" then return false end
        return nil
    end
end })

local re = {
    on_frame       = function(f) callbacks.frame[#callbacks.frame + 1] = f end,
    on_draw_ui     = function(f) callbacks.ui[#callbacks.ui + 1] = f end,
    on_config_save = function(f) callbacks.save[#callbacks.save + 1] = f end,
    on_script_reset= noop,
    on_pre_application_entry = noop,
    on_application_entry = noop,
}

local log = { info = noop, warn = noop, error = noop, debug = noop }

local function read_json(path)
    local f = io.open(datadir .. "/" .. path, "rb")
    if not f then return nil end
    local raw = f:read("a") ; f:close()
    -- A real parser is overkill: the harness only needs the shape, and the
    -- file has already been validated by python's json module upstream.
    local ok, decoded = pcall(function()
        local h = io.popen("python3 -c \"import json,sys;print(json.dumps(json.load(open(sys.argv[1]))))\" '"
                           .. datadir .. "/" .. path .. "' 2>/dev/null")
        local out = h:read("a") ; h:close()
        if out == nil or out == "" then return nil end
        return out
    end)
    if not ok or decoded == nil then return nil end
    return decoded
end

-- ---------------------------------------------------------------- json
-- Added 2026-09-24 for the ITEM BROWSER. The harness used to answer nil to
-- every json.load_file except quest_steps, which meant a data-driven mod's
-- whole load path went untested: the browser builds its entire index out of
-- item_catalog.json, and "returns nil" is the one case that never exercises
-- it. A real (small, strict) decoder is worth forty lines.
local function json_decode(str)
    local pos = 1
    local function err(m) error(m .. " at " .. pos, 0) end
    local function skip()
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c == " " or c == "\t" or c == "\n" or c == "\r" then pos = pos + 1 else break end
        end
    end
    local parse
    local function parse_string()
        pos = pos + 1
        local out = {}
        while true do
            local c = str:sub(pos, pos)
            if c == "" then err("unterminated string") end
            if c == '"' then pos = pos + 1 ; break end
            if c == "\\" then
                local e = str:sub(pos + 1, pos + 1)
                local map = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f",
                              ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
                if e == "u" then
                    local hex = str:sub(pos + 2, pos + 5)
                    local cp = tonumber(hex, 16) or 63
                    out[#out + 1] = (cp < 128) and string.char(cp) or "?"
                    pos = pos + 6
                else
                    out[#out + 1] = map[e] or e
                    pos = pos + 2
                end
            else
                out[#out + 1] = c ; pos = pos + 1
            end
        end
        return table.concat(out)
    end
    parse = function()
        skip()
        local c = str:sub(pos, pos)
        if c == "{" then
            pos = pos + 1
            local o = {}
            skip()
            if str:sub(pos, pos) == "}" then pos = pos + 1 ; return o end
            while true do
                skip()
                local k = parse_string()
                skip()
                if str:sub(pos, pos) ~= ":" then err("expected :") end
                pos = pos + 1
                o[k] = parse()
                skip()
                local d = str:sub(pos, pos)
                pos = pos + 1
                if d == "}" then return o end
                if d ~= "," then err("expected , or }") end
            end
        elseif c == "[" then
            pos = pos + 1
            local a = {}
            skip()
            if str:sub(pos, pos) == "]" then pos = pos + 1 ; return a end
            while true do
                a[#a + 1] = parse()
                skip()
                local d = str:sub(pos, pos)
                pos = pos + 1
                if d == "]" then return a end
                if d ~= "," then err("expected , or ]") end
            end
        elseif c == '"' then
            return parse_string()
        elseif str:sub(pos, pos + 3) == "true"  then pos = pos + 4 ; return true
        elseif str:sub(pos, pos + 4) == "false" then pos = pos + 5 ; return false
        elseif str:sub(pos, pos + 3) == "null"  then pos = pos + 4 ; return nil
        else
            local n = str:match("^%-?%d+%.?%d*[eE]?[-+]?%d*", pos)
            if n == nil or n == "" then err("bad value") end
            pos = pos + #n
            return tonumber(n)
        end
    end
    local ok, v = pcall(parse)
    if not ok then return nil end
    return v
end

local json = {
    load_file = function(path)
        -- The walkthrough file has a hand-built Lua fixture; keep that path.
        if path:find("quest_steps") then
            local f = io.open(datadir .. "/" .. path, "rb")
            if not f then return nil end
            f:close()
            local fx = "/tmp/claude-0/-home-claude/873c2103-a33f-5dcb-942f-7eea37e4881b/scratchpad/harness/walk_lua.lua"
            local lf = io.open(fx, "rb")
            if lf then lf:close() ; return dofile(fx) end
            return nil
        end
        -- Prefs: force the window open and pin the tab, so the harness can
        -- drive every tab's draw path instead of only the collapsed panel.
        if path:find("questguide_prefs") then
            return { open = true, tab = tonumber(os.getenv("REF_TAB") or "1"),
                     pv = tonumber(os.getenv("REF_PV") or "6") }
        end
        if path:find("itembrowser_prefs") then
            -- REF_QUERY / REF_MODE / REF_CAT drive the search end to end, so
            -- the query parser is tested through the real filter rather than
            -- by a copy of itself in a test file.
            return { open = true, pv = 1, tab = tonumber(os.getenv("REF_TAB") or "1"),
                     query = os.getenv("REF_QUERY"),
                     mode = tonumber(os.getenv("REF_MODE") or "3"),
                     cat = os.getenv("REF_CAT"),
                     hide_invalid = (os.getenv("REF_SHOW_INVALID") ~= "1") }
        end
        -- Everything else: read the real file out of REF_DATA if it is there.
        -- A missing file still returns nil, which is a legitimate case the mod
        -- must survive -- that is why this does not error.
        local f = io.open(datadir .. "/" .. path, "rb")
        if not f then return nil end
        local body = f:read("*a")
        f:close()
        return json_decode(body)
    end,
    dump_file = function() return true end,
}

local reframework = { is_drawing_ui = function() return true end }



-- REFramework exposes these three globals too. Leaving them out made
-- CURVES (#407) look broken when it is fine -- a harness gap reported as a
-- mod bug is worse than no harness, so they are stubbed explicitly.
local fs     = { glob = function() return {} end,
                 read = function() return nil end,
                 write = function() return true end }
-- draw: world_to_screen must be able to RETURN A POINT, or any mod that draws
-- in the world never draws and the harness happily reports PASS on a blank
-- screen. REF_NO_PROJECT=1 forces the nil (behind-camera) answer instead, so
-- both branches get walked.
_G.__drawn = {}
local draw = setmetatable({
    world_to_screen = function(pos)
        if os.getenv("REF_NO_PROJECT") == "1" then return nil end
        local x = (pos and pos.x) or 0
        local z = (pos and pos.z) or 0
        return { x = 960 + x, y = 540 + z }
    end,
    text = function(s, x, y, col)
        _G.__drawn[#_G.__drawn + 1] = tostring(s)
        _G.__said[#_G.__said + 1] = tostring(s)
        return nil
    end,
    -- world_text projects and draws in one call. REF_NO_PROJECT=1 makes it a
    -- no-op, standing in for "behind the camera".
    world_text = function(s, pos, col)
        if os.getenv("REF_NO_PROJECT") == "1" then return nil end
        _G.__drawn[#_G.__drawn + 1] = tostring(s)
        _G.__said[#_G.__said + 1] = tostring(s)
        return nil
    end,
}, { __index = function() return function() return nil end end })
local thread = { get_hash = function() return 0 end, get_id = function() return 0 end }

local Vector3f = { new = function(x, y, z) return { x = x, y = y, z = z } end }

-- REF_FAKE_NPCS=<n> builds a believable app.NPCManager: a holder dictionary
-- with nil holes (the real one has hundreds), live transforms, CharaIDs, and
-- an app.CharacterID type definition whose static fields map value -> name.
-- Without this the whole nameplate path short-circuits on the first nil and
-- the harness proves only that the mod loads.
local function build_fake_npc_world(n)
    local function vec(x, y, z) return { x = x, y = y, z = z } end
    -- Names for the first few only, so the "game has no name for this one"
    -- branch is exercised by the rest.
    local named = { [1] = "Wilhelmina", [2] = "Cliodhna", [3] = "Ulrika",
                    [4] = "Brant", [5] = "Sven", [6] = "Ulrika's Brother" }
    local chars = {}
    for i = 1, n do
        local cid = 310000 + i
        local px, py, pz = (i % 12) * 4.0, 0.0, math.floor(i / 12) * 4.0
        local d2 = px * px + pz * pz
        local hasjoint = (i % 10 ~= 0)   -- one in ten has no Head_0
        chars[i] = {
            call = function(self, m, a)
                if m == "get_CharaID" then return cid end
                if m == "get_DistanceSqFromPlayer" then return d2 end
                if m == "get_GameObject" then
                    return { call = function(_, m2)
                        if m2 ~= "get_Transform" then return nil end
                        return { call = function(_, m3, jn)
                            if m3 == "getJointByName" then
                                if not hasjoint then return nil end
                                if jn ~= "Head_0" then
                                    _G.__said[#_G.__said + 1] =
                                        "!!HARNESS: getJointByName asked for " .. tostring(jn)
                                end
                                return { call = function(_, m4)
                                    if m4 == "get_Position" then return vec(px, py + 1.7, pz) end
                                end }
                            end
                            if m3 == "get_Position" then return vec(px, py, pz) end
                        end }
                    end }
                end
            end,
        }
    end
    local list = {
        call = function(_, m, i)
            if m == "get_Count" then return n end
            if m == "get_Item" then return chars[i + 1] end
        end,
    }
    local singletons = {
        ["app.CharacterListHolder"] = {
            call = function(_, m) if m == "getAllCharacters" then return list end end,
        },
        ["app.NPCManager"] = {
            call = function(_, m, cid)
                if m ~= "getNPCData" then return nil end
                -- REF_NO_NPCDATA=1 makes the game's own name source answer
                -- nothing, so the enum-JSON fallback path gets exercised.
                if os.getenv("REF_NO_NPCDATA") == "1" then return nil end
                local nm = named[(cid or 0) - 310000]
                if nm == nil then return nil end
                return { call = function(_, m2) if m2 == "get_Name" then return nm end end }
            end,
            get_field = function() return nil end,
        },
        ["app.CharacterManager"] = { call = function() return nil end },
    }
    rawset(sdk, "get_managed_singleton", function(name) return singletons[name] end)
    rawset(sdk, "find_type_definition", function(name)
        if name ~= "app.CharacterID" then return nil end
        local fs = {}
        for i = 1, n do
            local cid = 310000 + i
            fs[i] = { is_static = function() return true end,
                      get_name = function() return "ch" .. cid end,
                      get_data = function() return cid end }
        end
        return { get_fields = function() return fs end }
    end)
end
local _fn = tonumber(os.getenv("REF_FAKE_NPCS") or "0")
if _fn > 0 then build_fake_npc_world(_fn) end

-- ------------------------------------------------------------- environment
local env = {
    sdk = sdk, imgui = imgui, re = re, log = log, json = json,
    reframework = reframework, Vector3f = Vector3f,
    fs = fs, draw = draw, thread = thread,
    Vector2f = { new = function(x, y) return { x = x, y = y } end },
    Vector4f = { new = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end },
    require = function(n) error("no module '" .. n .. "'", 0) end,
    -- real stdlib
    pairs = pairs, ipairs = ipairs, type = type, tostring = tostring,
    tonumber = tonumber, table = table, math = math, string = string,
    os = os, pcall = pcall, select = select, error = error, print = print,
    setmetatable = setmetatable, getmetatable = getmetatable, rawget = rawget,
    next = next, unpack = table.unpack, assert = assert,
}
setmetatable(env, { __index = function(_, k)
    unknown[#unknown + 1] = k
    return nil
end })

-- REF_FAKE_GRANT=1 publishes a stand-in for dd2forge_2do_grant.lua's public
-- API, so a dependent mod's "the grant script IS loaded" path gets driven too.
-- Without it only the degraded branch runs, and the branch you ship is the one
-- the harness never saw.
local _fg = os.getenv("REF_FAKE_GRANT")
if _fg == "1" or _fg == "2" then
    local fake_list = {}
    for i = 1, 40 do fake_list[i] = { id = 500 + i, name = "Live Item " .. i } end
    rawset(env, "DD2FORGE_GRANT", {
        version = "HARNESS", pace = 8,
        busy = function() return os.getenv("REF_QUEUE_BUSY") == "1" end,
        dest = function() return "storage" end,
        set_dest = function() end,
        stop = function() end,
        -- REF_FAKE_GRANT=2 means "grant script loaded but no save" -- the API
        -- answers, the live catalog is empty, and the mod must fall back to
        -- its on-disk snapshot. That is the state the game is in at the main
        -- menu, so it is the state a browser gets opened in first.
        catalog = function()
            if os.getenv("REF_FAKE_GRANT") == "2" then return {}, {}, 0 end
            return {}, fake_list, #fake_list
        end,
        submit = function(label, entries)
            _G.__said[#_G.__said + 1] = string.format(
                "HARNESS submit: %s, %d entries", tostring(label), #entries)
            return true, "fake"
        end,
        status = function()
            if os.getenv("REF_QUEUE_BUSY") == "1" then
                return { on = true, at = 3, total = 10, given = 3, failed = 0, label = "FAKE" }
            end
            return { on = false, at = 0, total = 0, given = 0, failed = 0, label = "" }
        end,
    })
end

-- ------------------------------------------------------------------- run
-- REF_PRELOAD runs other mod chunks into the SAME environment first, which is
-- the only way to test a seam between two autorun scripts. dd2forge's item
-- browser talks to the grant script through a global; a harness that can only
-- load one file at a time can prove each half runs and nothing about the wire
-- between them.
for path in (os.getenv("REF_PRELOAD") or ""):gmatch("[^,]+") do
    local pc, pe = loadfile(path, "t", env)
    if not pc then
        print("PRELOAD FAIL (parse) " .. path .. ": " .. tostring(pe))
        os.exit(1)
    end
    local ok, e2 = pcall(pc)
    if not ok then
        print("PRELOAD FAIL (run) " .. path .. ": " .. tostring(e2))
        os.exit(1)
    end
    print("preloaded: " .. path)
end

local chunk, err = loadfile(target, "t", env)
if not chunk then
    print("LOAD FAIL (parse): " .. tostring(err))
    os.exit(1)
end

local ok, rerr = pcall(chunk)
if not ok then
    print("RUN FAIL (chunk scope): " .. tostring(rerr))
    print("  ^ this is the class of bug luac -p cannot see")
    os.exit(1)
end
print(string.format("chunk ran clean. callbacks: %d frame, %d draw_ui, %d config_save",
    #callbacks.frame, #callbacks.ui, #callbacks.save))

local failures = 0
-- REF_FRAMES drives on_frame more than once. One frame is not enough for any
-- mod whose first frame MEASURES something and whose later frames use the
-- measurement -- a hand-rolled list clipper measures row height on frame 1 and
-- only virtualises from frame 2, so a single-frame harness tests the path that
-- does not ship and skips the one that does.
local frames = tonumber(os.getenv("REF_FRAMES") or "2")
for n = 1, frames do
    _G.__frame = n
    for i, f in ipairs(callbacks.frame) do
        local o, e = pcall(f)
        if not o then
            print(string.format("FRAME CALLBACK %d FAILED on frame %d: %s", i, n, tostring(e)))
            failures = failures + 1
        end
    end
end
for i, f in ipairs(callbacks.ui) do
    local o, e = pcall(f)
    if not o then print("DRAW_UI CALLBACK " .. i .. " FAILED: " .. tostring(e)) ; failures = failures + 1 end
end
for i, f in ipairs(callbacks.save) do
    local o, e = pcall(f)
    if not o then print("CONFIG_SAVE CALLBACK " .. i .. " FAILED: " .. tostring(e)) ; failures = failures + 1 end
end

print("imgui calls exercised: " .. imgui_calls)
if imgui_calls < 20 then
    print("WARNING: very few imgui calls -- the draw path probably did not run")
end

local seen = {}
local list = {}
for _, k in ipairs(unknown) do
    if not seen[k] then seen[k] = true ; list[#list + 1] = k end
end
-- Cross-chunk globals are legitimate: two autorun scripts are two Lua chunks
-- and a local cannot cross that boundary, so the item browser reads
-- DD2FORGE_GRANT which the grant script publishes. Declaring them keeps the
-- check strict about typos while not calling a deliberate seam a bug.
local declared = {}
for n in (os.getenv("REF_GLOBALS") or ""):gmatch("[^,%s]+") do declared[n] = true end
local undeclared = {}
for _, k in ipairs(list) do if not declared[k] then undeclared[#undeclared + 1] = k end end
list = undeclared

if #list > 0 then
    print("UNDECLARED GLOBALS READ: " .. table.concat(list, ", "))
    failures = failures + 1
else
    print("no undeclared globals read")
end

local ig = {}
for k in pairs(imgui_unknown) do ig[#ig + 1] = k end
table.sort(ig)
if #ig > 0 then
    print("IMGUI FUNCTIONS THAT DO NOT EXIST IN REFRAMEWORK: " .. table.concat(ig, ", "))
    failures = failures + 1
end

for _, t in ipairs(_G.__said) do
    if t:find("!!HARNESS", 1, true) then
        print(t) ; failures = failures + 1 ; break
    end
end

-- REF_DUMP_DRAWN=1 prints every string the mod rendered, one per line, so a
-- test can assert on what is NOT there as easily as on what is. REF_EXPECT
-- only ever answered the positive question.
if os.getenv("REF_DUMP_DRAWN") == "1" then
    for _, t in ipairs(_G.__said) do print("DRAWN| " .. t) end
end

local want = os.getenv("REF_EXPECT")
if want and want ~= "" then
    local hit = false
    for _, t in ipairs(_G.__said) do if t:find(want, 1, true) then hit = true break end end
    if hit then print('rendered text contains: "' .. want .. '"')
    else print('EXPECTED TEXT MISSING: "' .. want .. '"') ; failures = failures + 1 end
end

if failures > 0 then os.exit(1) end
print("HARNESS PASS")
