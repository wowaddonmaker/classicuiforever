local _, ns = ...

-- Forever characters have surnames: zero every surname setting and trim the names we draw.
-- Re-enabling the game's own setting turns the toggle off.

local IsSecret = ns.IsSecret

local CANDIDATES = { "UnitSurnameOwn", "UnitSurname", "UnitSurnameOther", "UnitSurnameFriendly",
    "UnitSurnameEnemy", "ShowSurnames", "showSurnames" }
local TRIM_EVENTS = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
    "UNIT_PET", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "INSTANCE_ENCOUNTER_ENGAGE_UNIT" }
local active = false
local wroteAt = 0
local writing = false
local driver
-- text -> unit getter for every name text seen; Restore lengthens them all.
local watched = {}
-- What the trim walks: unit frame names plus currently added plates.
local trimmed = {}
-- plate token -> name text: by NAME_PLATE_UNIT_REMOVED the plate's unit frame is gone.
local plateText = {}

-- Sole writer of active; hidden while off, the driver still gets events.
local function SetActive(on)
    active = on
    if driver then
        if on then driver:Show() else driver:Hide() end
    end
end

-- Settings are fixed per session and the scan lowercases every command: cache the first non-empty result.
local knownCache
local function Known()
    if knownCache then return knownCache end
    local found, seen = {}, {}
    local function add(name)
        if type(name) ~= "string" or seen[name] then return end
        seen[name] = true
        found[#found + 1] = name
    end
    if C_Console and C_Console.GetAllCommands then
        local ok, commands = pcall(C_Console.GetAllCommands)
        if ok and type(commands) == "table" then
            for _, entry in ipairs(commands) do
                local name = type(entry) == "table" and entry.command or nil
                if type(name) == "string" and name:lower():find("surname", 1, true) then add(name) end
            end
        end
    end
    if C_CVar and C_CVar.GetCVar then
        for _, name in ipairs(CANDIDATES) do
            local ok, value = pcall(C_CVar.GetCVar, name)
            if ok and value ~= nil then add(name) end
        end
    end
    if #found > 0 then knownCache = found end
    return found
end
-- /fcui debug: the surname settings this client knows.
ns.SurnameSettings = Known

-- First word of a name; nil for one-word or secret (dungeon) names, left as the client wrote them.
local function Trim(value)
    if IsSecret(value) then return nil end
    if type(value) ~= "string" or value == "" then return nil end
    local first = value:match("^(%S+)")
    if first and first ~= value then return first end
    return nil
end

local function Shorten(text, unit, value)
    if not active or writing or not text or not text.SetText then return end
    if not unit or not UnitIsPlayer then return end
    local isPlayer = UnitIsPlayer(unit)
    if IsSecret(isPlayer) or not isPlayer then return end
    local source = value
    if type(source) == "nil" then source = text.GetText and text:GetText() end
    local short = Trim(source)
    if not short then return end
    writing = true
    text:SetText(short)
    writing = false
end

-- Full name back when the toggle goes off.
local function Lengthen(text, unit)
    if not text or not text.SetText or not unit then return end
    if not (UnitExists and UnitExists(unit)) then return end
    local full = UnitName(unit)
    if IsSecret(full) then return end
    if type(full) == "string" and full ~= "" then
        writing = true
        text:SetText(full)
        writing = false
    end
end

-- Trimmed from our own pass after the client writes: code inside its write would get that pass refused unit health.
local function Watch(text, unitOf)
    if not text or not text.SetText or not unitOf then return end
    if watched[text] then return end
    watched[text] = unitOf
    trimmed[text] = unitOf
    Shorten(text, unitOf(), nil)
end

local unitGetters = {}
local function Unit(token)
    local fn = unitGetters[token]
    if not fn then
        fn = function() return token end
        unitGetters[token] = fn
    end
    return fn
end

-- Our unit frames' name texts, each with its unit.
local function WatchFrames()
    local target, focus = TargetFrame, FocusFrame
    Watch(PlayerName, Unit("player"))
    Watch(PetName, Unit("pet"))
    Watch(ns.Path(target, "TargetFrameContent", "TargetFrameContentMain", "Name"), Unit("target"))
    Watch(ns.Path(target, "totFrame", "Name"), Unit("targettarget"))
    Watch(ns.Path(focus, "TargetFrameContent", "TargetFrameContentMain", "Name"), Unit("focus"))
    Watch(ns.Path(focus, "totFrame", "Name"), Unit("focustarget"))
    for i = 1, 4 do
        local party = _G["PartyMemberFrame" .. i]
        if party then Watch(party.Name, Unit("party" .. i)) end
    end
    for i = 1, 5 do
        local boss = _G["Boss" .. i .. "TargetFrame"]
        local name = boss and (ns.Path(boss, "TargetFrameContent", "TargetFrameContentMain", "Name") or boss.Name)
        if name then Watch(name, Unit("boss" .. i)) end
    end
end

-- A plate name belongs to whatever unit the plate holds at write time.
local function WatchPlate(frame)
    if type(frame) ~= "table" or not frame.name then return end
    local name = frame.name
    -- A plate name is never ours to hide.
    if name:GetAlpha() < 1 then name:SetAlpha(1) end
    if not watched[name] then
        Watch(name, function() return frame.unit or frame.displayedUnit end)
    end
    trimmed[name] = watched[name]
    if frame.unit then plateText[frame.unit] = name end
    Shorten(name, frame.unit or frame.displayedUnit, nil)
end

local function WatchPlates()
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= "table" then return end
    for _, plate in ipairs(plates) do
        if plate and plate.UnitFrame then WatchPlate(plate.UnitFrame) end
    end
end

local function WatchAll()
    WatchFrames()
    WatchPlates()
end

-- Per frame: the client rewrites a hovered plate's name as the mouse moves.
local function TrimAll()
    if not active then return end
    for text, unitOf in pairs(trimmed) do
        local shown = text.GetText and text:GetText()
        if not IsSecret(shown) and type(shown) == "string" and shown:find("%s") then
            Shorten(text, unitOf(), shown)
        end
    end
end

local hooked = false

local function Hook()
    if hooked then return end
    hooked = true
    driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", TrimAll)

    -- Plates rewrite names on mouseover, which can follow our OnUpdate: listen too, re-registered behind each new plate.
    local after = CreateFrame("Frame")
    local function Requeue()
        after:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
        after:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    end
    Requeue()
    pcall(after.RegisterEvent, after, "NAME_PLATE_CREATED")
    after:SetScript("OnEvent", function(_, event)
        if event == "NAME_PLATE_CREATED" then
            Requeue()
            return
        end
        TrimAll()
    end)
    ns.RegisterEvents(driver, TRIM_EVENTS)
    driver:RegisterEvent("CVAR_UPDATE")
    driver:SetScript("OnEvent", function(_, event, name, value)
        if event == "NAME_PLATE_UNIT_REMOVED" then
            -- A removed plate is not drawn; ADDED brings it back.
            local text = name and plateText[name]
            if text then
                plateText[name] = nil
                trimmed[text] = nil
            end
            return
        end
        if event == "CVAR_UPDATE" then
            if not active or not name then return end
            if not tostring(name):lower():find("surname", 1, true) then return end
            if value == "0" or value == 0 or value == false then return end
            -- Read the live value, not the event's: answering the event looped writes, each redrawing every name.
            local ok, now = pcall(C_CVar.GetCVar, name)
            if not ok or now == nil or tostring(now) == "0" then return end
            -- Our own write echoes and the client replays saved settings after login: re-zero without extending the window.
            if (GetTime() - wroteAt) < 3 then
                ns.SetCVar(name, "0")
                return
            end
            -- The player re-enabled surnames in the game's settings: follow.
            ns.db.hideLastNames = false
            ns.db.savedSurnames = nil
            SetActive(false)
            if ns.RefreshOptionsWindow then ns.RefreshOptionsWindow() end
            return
        end
        if not active then return end
        -- Entering the world may lay the client's saved settings back over ours.
        if event == "PLAYER_ENTERING_WORLD" and ns.SurnamesOff then ns.SurnamesOff() end
        WatchAll()
    end)
end

-- Zero every surname setting, saving each original value once for restore.
function ns.SurnamesOff()
    if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return end
    ns.db.savedSurnames = ns.db.savedSurnames or {}
    for _, name in ipairs(Known()) do
        local ok, value = pcall(C_CVar.GetCVar, name)
        if ok and value ~= nil and value ~= "0" then
            if ns.db.savedSurnames[name] == nil then ns.db.savedSurnames[name] = value end
            wroteAt = GetTime()
            ns.SetCVar(name, "0")
        end
    end
end

local function Apply()
    SetActive(true)
    Hook()
    ns.SurnamesOff()
    WatchAll()
end

local function Restore()
    SetActive(false)
    local saved = ns.db.savedSurnames
    ns.db.savedSurnames = nil
    if saved and C_CVar and C_CVar.SetCVar then
        wroteAt = GetTime()
        for name, value in pairs(saved) do ns.SetCVar(name, value) end
    end
    for text, unitOf in pairs(watched) do Lengthen(text, unitOf()) end
end

ns.RegisterModule("hideLastNames", { apply = Apply, restore = Restore })
