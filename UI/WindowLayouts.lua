local _, ns = ...

-- The pieces moved in the game's edit mode (the gryphons) keep their place and size per edit mode layout, as the game's
-- own pieces do: a layout picked puts them where it had them, Save writes them into the active one, a preset holds none.
-- db.windowPos and db.windowScale stay the places everything reads; a layout's record is worn into them.

local W = ns.windowEdit
local Places, Scales = W.Places, W.Scales
local PIECES = {}
for _, entry in ipairs(W.WINDOWS) do
    if entry.gameEdit then PIECES[#PIECES + 1] = entry end
end
local EVENTS = { "EDIT_MODE_LAYOUTS_UPDATED", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_ENTERING_WORLD" }

local current   -- the layout the live places belong to: "account:Name", "char:Name" or "preset:Name"
local known     -- every layout as last seen, in the game's order; nil before the first look
local carry     -- places left unsaved as edit mode shut, for a layout the game makes as it shuts
local carryAt   -- when: a layout made later than CARRY_FOR is no part of that press
local CARRY_FOR = 10

local function IdOf(layout)
    local name = layout and layout.layoutName
    if type(name) ~= "string" then return nil end
    local types = Enum.EditModeLayoutType
    if layout.layoutType == types.Preset then return "preset:" .. name end
    if layout.layoutType == types.Character then return "char:" .. name end
    return "account:" .. name
end

-- An account layout's records are the account's, a character's own layout's that character's; a preset has none.
local function StoreOf(id, make)
    local kind, name = id:match("^(%a+):(.*)$")
    if kind == "char" and ns.char then
        if make and type(ns.char.layoutSpots) ~= "table" then ns.char.layoutSpots = {} end
        return ns.char.layoutSpots, name
    elseif kind == "account" then
        return make and ns.DbTable("layoutSpots") or ns.db.layoutSpots, name
    end
end

local function Get(id)
    local store, name = StoreOf(id)
    local record = type(store) == "table" and store[name]
    return type(record) == "table" and record or nil
end

local function Put(id, record)
    local store, name = StoreOf(id, record ~= nil)
    if type(store) == "table" then store[name] = record end
    return store ~= nil
end

-- What stands now, as a record.
local function Live()
    local record = { pos = {}, scale = {} }
    local places, scales = Places(), Scales()
    for _, entry in ipairs(PIECES) do
        local pos = places[entry.key]
        if pos then record.pos[entry.key] = { pos[1], pos[2] } end
        record.scale[entry.key] = scales[entry.key]
    end
    return record
end

-- A record worn: each piece at its place and size, home and its own size where the record has none (nil: all home).
local function Wear(record)
    local places, scales = Places(), Scales()
    local pos, scale = record and record.pos or ns.EMPTY, record and record.scale or ns.EMPTY
    for _, entry in ipairs(PIECES) do
        local key = entry.key
        local placed, spot = places[key] ~= nil, pos[key]
        local valid = type(spot) == "table" and type(spot[1]) == "number" and type(spot[2]) == "number"
        places[key] = valid and { spot[1], spot[2] } or nil
        scales[key] = type(scale[key]) == "number" and scale[key] or nil
        if placed and not places[key] then W.Return(entry) end
    end
    W.PlaceAll()
    for _, entry in ipairs(PIECES) do W.LayHandle(entry) end
    W.Refresh()
    if W.GameSettled then W.GameSettled() end
end

local function Layouts()
    local mgr = EditModeManagerFrame
    local list = mgr and mgr.GetLayouts and mgr:GetLayouts()
    if type(list) ~= "table" then return nil end
    local ids = {}
    for i, layout in ipairs(list) do ids[i] = IdOf(layout) or "" end
    return ids
end

local function Has(ids, id)
    for i = 1, #ids do
        if ids[i] == id then return true end
    end
    return false
end

-- A renamed layout keeps its record: the list is as long as before and differs in one spot.
local function Renamed(before, after)
    if not before or #before ~= #after then return nil end
    local from, to
    for i = 1, #after do
        if before[i] ~= after[i] then
            if from then return nil end
            from, to = before[i], after[i]
        end
    end
    return from, to
end

-- Records of layouts the player deleted; only while edit mode is up, where layouts are deleted (at login the game's
-- list may not be whole yet).
local function Prune(ids)
    local stores = { account = ns.db.layoutSpots, char = ns.char and ns.char.layoutSpots }
    for kind, store in pairs(stores) do
        if type(store) == "table" then
            for name in pairs(store) do
                if not Has(ids, kind .. ":" .. name) then store[name] = nil end
            end
        end
    end
end

local function CopyRecord(record)
    local copy = { pos = {}, scale = {} }
    for key, spot in pairs(record.pos or ns.EMPTY) do copy.pos[key] = { spot[1], spot[2] } end
    for key, size in pairs(record.scale or ns.EMPTY) do copy.scale[key] = size end
    return copy
end

-- Upgraders from before records per layout: the one old place, once, into each listed layout without a record of its
-- own (account layouts once, a character's own on its first login); never a preset, never a fallback after.
local function TakeOldPlaces(ids)
    local old = ns.db.layoutSpotsOld
    if type(old) ~= "table" then return end
    local open = { account = not ns.db.layoutSpotsTaken, char = ns.char ~= nil and not ns.char.layoutSpotsTaken }
    for _, id in ipairs(ids) do
        if open[id:match("^(%a+):")] and not Get(id) then
            Put(id, CopyRecord(old))
            if ns.debugSink then ns.Persist("layout spots: " .. id .. " takes the old places") end
        end
    end
    ns.db.layoutSpotsTaken = true
    if ns.char then ns.char.layoutSpotsTaken = true end
end

-- The active layout changed, or the game's list did: the pieces wear the active layout's record, home with none, as
-- the game's own pieces stand. A preset is always home: it cannot be saved, so a place worn there could never go.
local function Sync()
    if not ns.db then return end
    local id = IdOf(ns.ActiveLayoutInfo())
    local ids = id and Layouts()
    if not ids then return end
    local editing = ns.EditMode.Live()
    local left = not editing and carry and GetTime() - carryAt <= CARRY_FOR and carry or nil
    -- Layouts are made, renamed and deleted in edit mode only (or as it shuts): at login the list may come in parts.
    if known and editing then
        local from, to = Renamed(known, ids)
        if from then
            Put(to, Get(from))
            Put(from, nil)
            if current == from then current = to end
        end
    end
    if known and (editing or left) then
        -- A layout just made (new, a copy, the one Save asks for on a preset) takes what stood as it was made.
        for i = 1, #ids do
            local made = ids[i]
            if made ~= "" and not Has(known, made) and not Get(made) and Put(made, left or Live()) then
                carry = nil
                if ns.debugSink then ns.Persist("layout spots: " .. made .. " made, takes what stood") end
            end
        end
    end
    TakeOldPlaces(ids)
    if id ~= current then
        local record = Get(id)
        if ns.debugSink then
            ns.Persist(string.format("layout spots: %s worn (%s), was %s", id, record and "its record" or "home",
                tostring(current)))
        end
        Wear(record)
        current = id
    end
    known = ids
    if editing then Prune(ids) end
end

local function QueueSync() ns.Sched.NextFrame("windows.layoutSpots", Sync) end
-- After the game's own listener: it reads the layouts in on the same events.
ns.EventFrame(EVENTS, QueueSync)
W.SyncLayoutSpots = Sync

-- The game's Save pressed: the active layout takes what stands. False on a preset, which the game cannot save: it asks
-- for a new layout, and that one takes the places as it is made.
function W.SaveLayoutSpots()
    local id = IdOf(ns.ActiveLayoutInfo())
    if not (id and Put(id, Live())) then return false end
    current = id
    if ns.debugSink then ns.Persist("layout spots: " .. id .. " saved") end
    return true
end

-- Edit mode shut with a change unsaved (the caller drops it): kept a moment for a layout made in the same press.
function W.LayoutEditLeft() carry, carryAt = Live(), GetTime() end
function W.LayoutEditBegan() carry = nil end

-- A place written outside edit mode (an old place carried over) goes into the active layout; on a preset, which keeps
-- none, the player's layouts without a record take it.
function ns.KeepLayoutSpots()
    if W.SaveLayoutSpots() then return end
    ns.db.layoutSpotsOld, ns.db.layoutSpotsTaken = Live(), nil
    if ns.char then ns.char.layoutSpotsTaken = nil end
end

-- Upgrade to records per layout: the one place each piece had on every layout, for the player's layouts to take.
function ns.KeepPieceSpots()
    local record = Live()
    if next(record.pos) or next(record.scale) then ns.db.layoutSpotsOld = record end
    ns.db.dbVersion = 15
end

-- The classic layout set up (no record yet) or reset (anyway): its pieces at home, never the old places. The
-- player's other layouts keep theirs.
function ns.HomeLayoutSpots(name, anyway)
    local id = "account:" .. name
    if anyway or not Get(id) then Put(id, { pos = {}, scale = {} }) end
end
