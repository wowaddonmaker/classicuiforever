-- Offline test under Lua 5.4 for the player frame's name box under a thick health bar (Units/PlayerFrame.lua
-- KeepClassBand). With Thick health bars in the "over the name" style the bar stands on the name box, so the box stays
-- unseen; the pass that keeps its color wrote the color at full alpha and brought it back (a texture's alpha is its
-- vertex alpha). The target and focus frames hide theirs outright. The function is cut out of the file and run.
-- Run from the addon root: lua tools/tests/player_name_box_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Units/PlayerFrame.lua", "r"))
local source = handle:read("a")
handle:close()
local first = source:find("local function KeepClassBand()", 1, true)
local last = source:find("-- Read by the dev addon's band probe.", 1, true)
assert(first and last and last > first, "the name box keeper is in the file")

local thick, nameColor
local box = { shown = false }
local band = { shown = true, IsShown = function(self) return self.shown end, GetVertexColor = function() return 0.2, 0.4, 0.6, 0 end }
local env = setmetatable({
    UF = { active = true, Thick = function() return thick end },
    On = function() return true end,
    nameBg = box,
    classBand = band,
    ns = {
        db = {},
        NameBoxColor = function() if nameColor then return 0.9, 0.8, 0.7 end end,
        SetAlphaIf = function() end,
        AnySecret = function() return false end,
    },
    UnitSelectionColor = function() return 0, 0, 1, 1 end,
    SetShownIf = function(region, shown) region.shown = shown end,
    SetVertexColorIf = function(region, r, g, b, a) region.r, region.alpha = r, a end,
}, { __index = _G })
assert(load(source:sub(first, last - 1) .. "\nreturn KeepClassBand", "name box", "t", env))()()
local Keep = assert(load(source:sub(first, last - 1) .. "\nreturn KeepClassBand", "name box", "t", env))()

thick, nameColor = nil, true
Keep()
Check(box.shown and box.alpha == 1 and box.r == 0.9, "regular bars, class colored name box: the box shows in the class color")
thick = "name"
Keep()
Check(box.alpha == 0, "thick health over the name: the class colored box stays unseen (alpha " .. tostring(box.alpha) .. ")")
nameColor = false
Keep()
Check(box.alpha == 0 and box.r == 0.2, "thick health over the name, the game's own band color: unseen too (alpha " .. tostring(box.alpha) .. ")")
thick = "mana"
Keep()
Check(box.alpha == 1, "thick health over the mana: the name box shows as before")
thick = nil
Keep()
Check(box.shown and box.alpha == 1 and box.r == 0.2, "regular bars: the box in the game's band color")

-- Player picked under Name box color: the game's color for you (blue), as the target frame shows it; unpicked is
-- 1.x's plain box.
band.shown = false
Keep()
Check(not box.shown, "the option off, no band of the game's: no box, as in 1.x")
env.ns.db.nameBoxPlayer = true
Keep()
Check(box.shown and box.r == 0 and box.alpha == 1, "the option on: the box in the game's color for you")
nameColor = true
Keep()
Check(box.r == 0.9, "class colored name box on too: the class color wins")
nameColor = false
thick = "name"
Keep()
Check(box.alpha == 0, "thick health over the name: unseen whatever colors it")

-- No band of the game's at all (Forever's player frame here): the option turned off takes its box away again.
thick = nil
env.classBand = nil
env.ns.Path = function() return nil end
Keep()
Check(box.shown, "no band of the game's, the option on: the box shows")
env.ns.db.nameBoxPlayer = false
Keep()
Check(not box.shown, "no band of the game's, the option turned off: the box goes")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("player_name_box_test: ok")
