-- Offline tests for Core/Profiles.lua under Lua 5.4: first run, switching, copying, renaming (followed by other
-- characters) and deleting, over a stubbed settings table.
-- Run from the addon root: lua tools/tests/profiles_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local passed, failed = 0, 0
local function Check(ok, msg)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. msg)
    end
end

local ns = {}
ns.DB_DEFAULTS = { a = true, b = false, barScale = 1, microScale = 1, oneBagColumns = 8, gameDamageNumbers = true }
ns.TOGGLES = { { "a" }, { "b" }, { "gameDamageNumbers" } }
local changedLog
function ns.TogglesChanged(changed) changedLog = table.concat(changed, ",") end
ns.db = { a = false, b = false, barScale = 1.2, microScale = 1, oneBagColumns = 8, gameDamageNumbers = false,
    whatsNewSeen = 3 }

-- The real shared helpers (ns.DbTable) first, as the addon loads them.
assert(loadfile(ROOT .. "/Core/Settings.lua"))("ClassicUIForever", ns)
assert(loadfile(ROOT .. "/Core/Profiles.lua"))("ClassicUIForever", ns)

ForeverClassicUICharDB = nil
ns.LoadProfile()
Check(ns.ProfileName() == "Default", "starts on Default")
Check(ns.db.profiles.Default.a == false and ns.db.profiles.Default.barScale == 1.2, "Default keeps the settings in use")
Check(ns.db.profiles.Default.gameDamageNumbers == nil, "the game's own setting is left out")

local name = ns.NewProfile("  Tank  ", false)
Check(name == "Tank" and ns.ProfileName() == "Tank", "new profile trimmed and in use")
Check(ns.db.a == true and ns.db.barScale == 1, "a new profile starts from the defaults")
Check(changedLog == "a,barScale", "only the changed keys are reported: " .. tostring(changedLog))
Check(ns.db.whatsNewSeen == 3, "account-wide state untouched")

ns.db.b = true
ns.UseProfile("Default")
Check(ns.db.a == false and ns.db.b == false and ns.db.barScale == 1.2, "switching back fills Default's values")
Check(ns.db.profiles.Tank.b == true, "the profile left stored its change")
Check(select(2, ns.NewProfile("tank")) ~= nil, "a duplicate name is refused, case-blind")

local copy = ns.NewProfile("Copy", true)
Check(copy == "Copy" and ns.db.barScale == 1.2 and ns.db.a == false, "a copy starts from the settings in use")
ns.UseProfile("Tank")

Check(ns.RenameProfile("Tank", "Healer") == "Healer" and ns.ProfileName() == "Healer", "renamed while in use")
ForeverClassicUICharDB = { profile = "Tank" }
ns.StoreProfile()
ns.LoadProfile()
Check(ns.ProfileName() == "Healer", "another character on the old name follows the rename")

ns.DeleteProfile("Healer")
Check(ns.ProfileName() == "Default" and ns.db.profiles.Healer == nil, "deleting the one in use falls back to Default")
Check(ns.RenameProfile("Default", "X") == nil, "Default keeps its name")
ns.DeleteProfile("Default")
Check(ns.db.profiles.Default ~= nil, "Default can't be deleted")

-- Damaged saved data: a non-table entry and a broken rename map are dropped at login, not erred on.
ns.db.profiles.Broken = 5
ns.db.profileMoved = "junk"
ForeverClassicUICharDB = { profile = "Broken" }
local ok = pcall(ns.LoadProfile)
Check(ok and ns.ProfileName() == "Default" and ns.db.profiles.Broken == nil and ns.db.profileMoved == nil,
    "damaged profile data is dropped at login")

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
