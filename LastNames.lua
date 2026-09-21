local _, ns = ...

-- The Forever client gives characters a last name and draws it with the
-- first. The toggle turns off every surname setting the client carries
-- and takes the surname off the names this UI draws, and it stays in
-- step with the game's own box for it: turning that box back on turns
-- the toggle off, and the other way about.
--
-- The name is trimmed where it is written rather than on a pass of our
-- own: every name string is hooked, so our word lands in the same frame
-- as the client's and the two never trade places.

local CANDIDATES = { "UnitSurnameOwn", "UnitSurname", "UnitSurnameOther", "UnitSurnameFriendly",
    "UnitSurnameEnemy", "ShowSurnames", "showSurnames" }
local active = false
local wroteAt = 0
local writing = false
local driver
local watched = {}

local function Known()
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
    return found
end
-- What the debug print reports: which settings this client answers to.
ns.SurnameSettings = Known

-- The first name out of a drawn name. The surname is whatever follows
-- the first word, so the client's own string is the one word it starts
-- with; a name with nothing after it is already short.
local function Trim(value)
    -- A name the client keeps from an addon (in a dungeon) comes sealed:
    -- it cannot be compared or cut, and is left as the client wrote it.
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value) ~= "string" or value == "" then return nil end
    local first = value:match("^(%S+)")
    if first and first ~= value then return first end
    return nil
end

local function Shorten(text, unit, value)
    if not active or writing or not text or not text.SetText then return end
    if not unit or not UnitIsPlayer then return end
    local isPlayer = UnitIsPlayer(unit)
    if (issecretvalue and issecretvalue(isPlayer)) or not isPlayer then return end
    local source = value
    if type(source) == "nil" then source = text.GetText and text:GetText() end
    local short = Trim(source)
    if not short then return end
    writing = true
    text:SetText(short)
    writing = false
end

-- Put the client's own name back where ours was drawn, for the moment
-- the toggle goes off; whatever the client writes next wins anyway.
local function Lengthen(text, unit)
    if not text or not text.SetText or not unit then return end
    if not (UnitExists and UnitExists(unit)) then return end
    local full = UnitName(unit)
    if issecretvalue and issecretvalue(full) then return end
    if type(full) == "string" and full ~= "" then
        writing = true
        text:SetText(full)
        writing = false
    end
end

-- Every name string this UI draws is listed, and a pass of our own
-- trims whatever the client has just written into it. Trimming from
-- inside the client's own write instead would put our code in the
-- middle of its pass over the frame, and the client refuses the rest of
-- such a pass its unit's health, which costs the frame far more than a
-- surname is worth.
local function Watch(text, unitOf)
    if not text or not text.SetText or not unitOf then return end
    if watched[text] then return end
    watched[text] = unitOf
    Shorten(text, unitOf(), nil)
end

local function Unit(token) return function() return token end end

-- The unit frames this UI dresses, each with the unit its name belongs to.
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

-- A nameplate's name string belongs to whichever unit the plate holds
-- at the time, so its unit is read when the name is written.
local function WatchPlate(frame)
    if type(frame) ~= "table" or not frame.name then return end
    Watch(frame.name, function() return frame.unit or frame.displayedUnit end)
    Shorten(frame.name, frame.unit or frame.displayedUnit, nil)
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

local hooked = false
local SWEEP = 0.2
local function Hook()
    if hooked then return end
    hooked = true
    driver = CreateFrame("Frame")
    -- The client writes a name whenever it pleases; the trim follows it
    -- from here rather than from inside its own write.
    driver:SetScript("OnUpdate", function(self, elapsed)
        if not active then return end
        self.since = (self.since or 0) + elapsed
        if self.since < SWEEP then return end
        self.since = 0
        for text, unitOf in pairs(watched) do Shorten(text, unitOf(), nil) end
    end)
    for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
        "UNIT_PET", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "INSTANCE_ENCOUNTER_ENGAGE_UNIT" }) do
        pcall(driver.RegisterEvent, driver, event)
    end
    driver:RegisterEvent("CVAR_UPDATE")
    driver:SetScript("OnEvent", function(_, event, name, value)
        if event == "CVAR_UPDATE" then
            if not active or not name then return end
            if not tostring(name):lower():find("surname", 1, true) then return end
            if value == "0" or value == 0 or value == false then return end
            -- Our own write comes back as an update, and the client
            -- replays its saved settings a moment after login; neither
            -- is the player asking for surnames back.
            if (GetTime() - wroteAt) < 3 then return end
            -- The player put surnames back from the game's own settings:
            -- the toggle follows them.
            ns.db.hideLastNames = false
            ns.db.savedSurnames = nil
            active = false
            if ns.RefreshOptionsWindow then ns.RefreshOptionsWindow() end
            return
        end
        if active then WatchAll() end
    end)
end

local function Apply()
    active = true
    Hook()
    if C_CVar and C_CVar.GetCVar and C_CVar.SetCVar then
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
    WatchAll()
end

local function Restore()
    active = false
    local saved = ns.db.savedSurnames
    ns.db.savedSurnames = nil
    if saved and C_CVar and C_CVar.SetCVar then
        wroteAt = GetTime()
        for name, value in pairs(saved) do ns.SetCVar(name, value) end
    end
    for text, unitOf in pairs(watched) do Lengthen(text, unitOf()) end
end

ns.RegisterModule("hideLastNames", { apply = Apply, restore = Restore })
