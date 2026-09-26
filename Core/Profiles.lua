local _, ns = ...

-- Named profiles: the look settings (every toggle, bar and micro scale, bag columns) kept by name and picked per
-- character. ns.db stays the one flat table the code reads: a switch stores it into the old profile and fills it from the
-- new. Band places, layout state, hand-back records and the once-only repairs stay account-wide.

local DEFAULT = "Default"
local NAME_MAX = 32
local EXTRA = { "barScale", "microScale", "oneBagColumns" }
-- The game's own setting mirrored, not ours to keep per profile.
local SKIP = { gameDamageNumbers = true }
ns.PROFILE_DEFAULT = DEFAULT

local keys
local function Keys()
    if keys then return keys end
    keys = {}
    for _, entry in ipairs(ns.TOGGLES) do
        if not SKIP[entry[1]] then keys[#keys + 1] = entry[1] end
    end
    for i = 1, #EXTRA do keys[#keys + 1] = EXTRA[i] end
    return keys
end

-- Only what differs from the defaults is kept (all scalars).
local function Snapshot()
    local db, defaults, shot = ns.db, ns.DB_DEFAULTS, {}
    for _, k in ipairs(Keys()) do
        local v = db[k]
        if v ~= nil and v ~= defaults[k] then shot[k] = v end
    end
    return shot
end

-- Fills ns.db from a profile; returns the keys whose value changed.
local function Fill(shot)
    local db, defaults, changed = ns.db, ns.DB_DEFAULTS, {}
    for _, k in ipairs(Keys()) do
        local v = shot[k]
        if v == nil then v = defaults[k] end
        if db[k] ~= v then
            db[k] = v
            changed[#changed + 1] = k
        end
    end
    return changed
end

local function List() return ns.db.profiles end

function ns.ProfileName()
    return ns.char and ns.char.profile or DEFAULT
end

-- Into the character's profile: at logout and before any switch.
function ns.StoreProfile()
    local list = ns.db and List()
    if list and ns.char and list[ns.char.profile] then list[ns.char.profile] = Snapshot() end
end

-- ADDON_LOADED: the first run keeps the current settings as Default; a renamed profile is followed.
function ns.LoadProfile()
    ForeverClassicUICharDB = ForeverClassicUICharDB or {}
    local char = ForeverClassicUICharDB
    ns.char = char
    local db = ns.db
    if type(db.profiles) ~= "table" then db.profiles = { [DEFAULT] = Snapshot() } end
    local list = db.profiles
    -- A damaged entry is dropped, not filled in (settings outlive sessions; one bad value erred every login).
    for name, shot in pairs(list) do
        if type(name) ~= "string" or type(shot) ~= "table" then list[name] = nil end
    end
    list[DEFAULT] = list[DEFAULT] or {}
    if db.profileMoved ~= nil and type(db.profileMoved) ~= "table" then db.profileMoved = nil end
    local name, moved = char.profile, db.profileMoved
    for _ = 1, 10 do
        if name == nil or list[name] or type(moved) ~= "table" or not moved[name] then break end
        name = moved[name]
    end
    if name == nil or not list[name] then name = DEFAULT end
    char.profile = name
    Fill(list[name])
end

-- Default first, the rest by name.
function ns.ProfileNames()
    local names = {}
    for name in pairs(List()) do
        if name ~= DEFAULT then names[#names + 1] = name end
    end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    table.insert(names, 1, DEFAULT)
    return names
end

-- A trimmed name, or nil and why not.
function ns.CheckProfileName(text, except)
    local name = type(text) == "string" and text:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if name == "" then return nil, "Type a name." end
    if #name > NAME_MAX then return nil, "Names are at most " .. NAME_MAX .. " letters." end
    for other in pairs(List()) do
        if other ~= except and other:lower() == name:lower() then return nil, "A profile has that name already." end
    end
    return name
end

function ns.UseProfile(name)
    local list = List()
    if not list[name] or name == ns.ProfileName() then return end
    ns.StoreProfile()
    ns.char.profile = name
    ns.TogglesChanged(Fill(list[name]))
end

-- copy: from the settings in use, else from the defaults. Switches to it.
function ns.NewProfile(text, copy)
    local name, why = ns.CheckProfileName(text)
    if not name then return nil, why end
    List()[name] = copy and Snapshot() or {}
    ns.UseProfile(name)
    return name
end

function ns.RenameProfile(old, text)
    local list = List()
    if old == DEFAULT or not list[old] then return nil, "Default keeps its name." end
    local name, why = ns.CheckProfileName(text, old)
    if not name then return nil, why end
    list[name], list[old] = list[old], nil
    -- Other characters on it follow at their next login.
    ns.DbTable("profileMoved")
    ns.db.profileMoved[old] = name
    ns.db.profileMoved[name] = nil
    if ns.char.profile == old then ns.char.profile = name end
    if ns.RefreshOptionsWindow then ns.RefreshOptionsWindow() end
    return name
end

-- Characters on it go to Default; the one in use switches there now.
function ns.DeleteProfile(name)
    local list = List()
    if name == DEFAULT or not list[name] then return end
    if ns.char.profile == name then ns.UseProfile(DEFAULT) end
    list[name] = nil
    if ns.db.profileMoved then ns.db.profileMoved[name] = nil end
    if ns.RefreshOptionsWindow then ns.RefreshOptionsWindow() end
end
