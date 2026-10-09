-- Offline test under Lua 5.4 for keeping players' own edit mode layouts unwritten (Options/LayoutCopy.lua). Band pins
-- were written into whatever layout was up as our reload press ran, the classic layout's setup press included, so a
-- player who turned the addon off kept bars at our spots, overlapping. Now only layouts of ours are pinned.
-- Run from the addon root: lua tools/tests/layout_copy_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

Enum = { EditModeLayoutType = { Preset = 0, Account = 1, Character = 2 } }

local layouts, active, pinned, unpinned
local ns = { sessionEnding = true }
ns.ActiveLayoutInfo = function() return layouts[active] end
ns.ClassicLayoutActive = function() return layouts[active].layoutName == "ClassicUI Forever" end
ns.PinBandBars = function() pinned = pinned + 1 end
ns.UnpinBandBars = function() unpinned = unpinned + 1 end
ns.SafeCall = function(fn, ...) return pcall(fn, ...) end
ns.DbTable = function(key)
    ns.db[key] = ns.db[key] or {}
    return ns.db[key]
end
assert(loadfile(ROOT .. "/Options/LayoutCopy.lua"))("ClassicUIForever", ns)

local function Press(index, db)
    layouts = {
        { layoutName = "Modern", layoutType = 0 }, { layoutName = "Classic", layoutType = 0 },
        { layoutName = "Mine", layoutType = 1 }, { layoutName = "ClassicUI Forever", layoutType = 1 },
    }
    active, pinned, unpinned = index, 0, 0
    ns.db = db or {}
    ns.BandLayoutStep()
end

Press(3)
Check(pinned == 0 and #layouts == 4, "a player's own layout: no pins and no new layout from a plain reload")
Press(4)
Check(pinned == 1, "the classic layout keeps its pins up")
Press(1)
Check(pinned == 0, "a game preset is never written")
Press(3, { layoutJobs = { classic = {} } })
Check(pinned == 0, "leaving for the classic layout: the layout left is not pinned")
Press(4, { layoutJobs = { select = true } })
Check(pinned == 0, "a switch still queued: nothing pinned before it")
Press(4, { classicBar = false })
Check(unpinned == 1 and pinned == 0, "band off: our pins handed back")

local data = { systems = { { system = 0, systemIndex = 1, isInDefaultPosition = true },
    { system = 0, systemIndex = 2, isInDefaultPosition = false, anchorInfo = { point = "CENTER", relativeTo = "UIParent" } } } }
ns.db = {}
ns.PinLayoutData(data, {
    { name = "MainActionBar", system = 0, systemIndex = 1, anchorInfo = { point = "BOTTOMLEFT", relativeTo = "UIParent",
        relativePoint = "BOTTOM", offsetX = -250, offsetY = 0 } },
    { name = "MultiBarBottomLeft", system = 0, systemIndex = 2, anchorInfo = { point = "BOTTOMLEFT", relativeTo = "UIParent",
        relativePoint = "BOTTOM", offsetX = -250, offsetY = 40 } } }, "ClassicUI Forever", false)
Check(data.systems[1].anchorInfo.point == "BOTTOMLEFT" and not data.systems[1].isInDefaultPosition, "a default bar is pinned")
Check(data.systems[2].anchorInfo.point == "CENTER" and ns.db.barPins["ClassicUI Forever"].MultiBarBottomLeft == nil,
    "a bar the player placed is left where it is")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("layout_copy_test: ok")
