-- Offline test under Lua 5.4 for keeping players' own edit mode layouts unwritten (Options/LayoutCopy.lua). Band pins
-- were written into whatever layout was up as our reload press ran, the classic layout's setup press included, so a
-- player who turned the addon off kept bars at our spots, overlapping. Now only layouts of ours are pinned, and pins
-- older versions left in the player's own layouts are handed back as a reload or our Turn off starts.
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
local ACTION_BAR, HOLDER = 0, 1
MainActionBar = { system = ACTION_BAR, systemIndex = 1 }
MultiBarBottomLeft = { system = ACTION_BAR, systemIndex = 2 }
MultiBarRight = { system = ACTION_BAR, systemIndex = 4 }
MainStatusTrackingBarContainer = { system = HOLDER, systemIndex = 1 }
SecondaryStatusTrackingBarContainer = { system = HOLDER, systemIndex = 2 }
EditModePresetLayoutManager = {
    GetDefaultSystemAnchorInfo = function(_, system, index)
        return { point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = system, offsetY = index }
    end,
}
local saves, fighting, editing = 0, false, false
C_EditMode = { SaveLayouts = function() saves = saves + 1 end }
function InCombatLockdown() return fighting end
EditModeManagerFrame = {}

local layouts, active, pinned, unpinned
local ns = { sessionEnding = true, LAYOUT_NAME = "ClassicUI Forever" }
ns.band = { PIN_NAMES = { "MainActionBar", "MultiBarBottomLeft", "MultiBarRight", "MainStatusTrackingBarContainer",
    "SecondaryStatusTrackingBarContainer" } }
ns.EditMode = { Live = function() return editing end }
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
    EditModeManagerFrame.layoutInfo = { layouts = layouts }
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

------------------------------------------------------------------ old pins in the player's own layouts

local PIN = { point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = -250, offsetY = 0 }
local COLUMN = { point = "TOPRIGHT", relativeTo = "UIParent", relativePoint = "BOTTOMRIGHT", offsetX = -2, offsetY = 602 }
local PLACED = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", offsetX = 40, offsetY = 10 }
local RECORDED = { point = "TOP", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 1, offsetY = 2 }
local MOVED = { point = "TOP", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 90, offsetY = 2 }
local function Bar(system, index, anchor, isDefault)
    return { system = system, systemIndex = index, anchorInfo = anchor, isInDefaultPosition = isDefault or false }
end
local mine, classic, preset
local function Lay(db)
    mine = { layoutName = "Mine", layoutType = 1, systems = { Bar(0, 1, PIN), Bar(0, 2, PLACED), Bar(0, 4, COLUMN),
        Bar(1, 1, RECORDED), Bar(0, 3, PIN), Bar(1, 2, MOVED) } }
    classic = { layoutName = "ClassicUI Forever", layoutType = 1, systems = { Bar(0, 1, PIN) } }
    preset = { layoutName = "Modern", layoutType = 0, systems = { Bar(0, 1, PIN) } }
    EditModeManagerFrame.layoutInfo = { layouts = { preset, mine, classic } }
    ns.db = db or { barPins = { Mine = { MainStatusTrackingBarContainer = { point = "TOP", relativePoint = "BOTTOM",
        offsetX = 1, offsetY = 2 }, SecondaryStatusTrackingBarContainer = { point = "TOP", relativePoint = "BOTTOM",
        offsetX = 1, offsetY = 2 } }, ["ClassicUI Forever"] = { MainActionBar = {} } } }
    saves = 0
end

Lay()
Check(ns.HandBackPlayerPins() == true and saves == 1, "old pins in a player's layout are handed back, one save")
Check(mine.systems[1].isInDefaultPosition and mine.systems[1].anchorInfo.point == "BOTTOM", "a bar at a band pin goes to the game's default")
Check(mine.systems[3].isInDefaultPosition, "a right column at its band corner goes back too")
Check(mine.systems[4].isInDefaultPosition, "a bar still at our record's spot goes back, whatever its shape")
Check(not mine.systems[6].isInDefaultPosition and mine.systems[6].anchorInfo == MOVED,
    "a bar our record names but the player moved since stays where they put it")
Check(not mine.systems[2].isInDefaultPosition and mine.systems[2].anchorInfo == PLACED, "a bar the player placed stays")
Check(not mine.systems[5].isInDefaultPosition and mine.systems[5].anchorInfo == PIN, "a system that is no band bar stays")
Check(ns.db.barPins.Mine == nil and ns.db.barPins["ClassicUI Forever"] ~= nil, "only the player's pin records go")
Check(classic.systems[1].anchorInfo == PIN and preset.systems[1].anchorInfo == PIN,
    "our layout and the game's presets are left alone")
Check(ns.HandBackPlayerPins() == false and saves == 1, "a second run finds nothing and writes nothing")

Lay()
editing = true
Check(ns.HandBackPlayerPins() == false and saves == 0 and mine.systems[1].anchorInfo == PIN,
    "edit mode open: nothing written (its unsaved changes would be saved too)")
editing = false
Lay()
fighting = true
Check(ns.HandBackPlayerPins() == false and mine.systems[1].anchorInfo == PIN, "in a fight: nothing written")
fighting = false
Lay()
ns.sessionEnding = false
Check(ns.HandBackPlayerPins() == false and mine.systems[1].anchorInfo == PIN, "mid-session: nothing written")
ns.sessionEnding = true

-- The reload press runs it on any layout, the band on or off.
Lay()
layouts = EditModeManagerFrame.layoutInfo.layouts
active, pinned, unpinned = 2, 0, 0
ns.BandLayoutStep()
Check(mine.systems[1].isInDefaultPosition and pinned == 0, "a reload on the player's layout hands back old pins, pins nothing")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("layout_copy_test: ok")
