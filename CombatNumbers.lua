local _, ns = ...

-- Vanilla damage numbers: our own text over the mob you hit, popping in
-- and floating up, crits bigger, melee white and spells yellow, in place
-- of the engine's. The 12.x client keeps the combat log from addons (it
-- never fires on Forever), but UNIT_COMBAT still says, per unit, what
-- it just took: the action, the crit flag, the amount and the school.
-- The numbers are built from that. A unit's own nameplate is the only
-- handle an addon has on where the unit is on screen, and the client
-- withholds even the plate's position, so the text is hung on the plate
-- as a child and moves with it without a coordinate ever being read.
-- With enemy nameplates off the engine keeps drawing its own and ours
-- stay out of it. The event does not carry the source, so anything
-- hitting the target shows, not only you.

local function FontPath()
    if DAMAGE_TEXT_FONT then return DAMAGE_TEXT_FONT end
    if STANDARD_TEXT_FONT then return STANDARD_TEXT_FONT end
    if GameFontNormal and GameFontNormal.GetFont then
        local path = GameFontNormal:GetFont()
        if path then return path end
    end
    return "Fonts\\FRIZQT__.TTF"
end
local FONT = FontPath()
local fontFailed = false
local function Size(text, size)
    if text:SetFont(FONT, size, "OUTLINE") then return true end
    fontFailed = true
    text:SetFontObject(NumberFontNormalHuge or GameFontNormalHuge or GameFontNormal)
    return false
end
local SIZE, CRIT_SIZE = 22, 32
-- Measured from a 1.x recording at 30 frames a second: a plain hit
-- appears just above the nameplate and climbs about 33 pixels a second
-- for near two seconds, fading at the end. A crit appears huge, faint
-- and high above the mob, then drops and shrinks into place in a
-- quarter second, and climbs from there like any hit.
local RISE_SPEED, LIFE, FADE = 33, 1.8, 0.5   -- pixels a second, seconds shown, seconds of fade at the end
local CRIT_LIFE = 2.2
local CRIT_DROP_TIME, CRIT_DROP_HEIGHT = 0.25, 70   -- the crit comes down this far in this long
local CRIT_START_SCALE = 1.7                       -- and shrinks from this many times its rest size
local SCATTER, DRIFT = 36, 12            -- every number lands this far off center at random, and drifts this much sideways
local STACK_GAP = 24                     -- a number arriving before the last one has climbed this far starts above it instead
-- The numbers start just above the plate, where the old engine put
-- them over the mob's head.
local ABOVE_PLATE = 4
local CVAR_NAMES = { "floatingCombatTextCombatDamage", "floatingCombatTextCombatDamage_v2" }
local CVAR   -- the first of those the client knows
local PLATES_CVAR = "nameplateShowEnemies"
-- The game's own scrolling text over the player (damage taken, heals):
-- 1.x always had it, so classic mode turns it on.
local PLAYER_TEXT_CVAR = "enableFloatingCombatText"
local savedPlayerText
local savedPlates   -- enemy nameplates are turned on for the numbers; the old value comes back
-- The numbers live on the enemy plate, so the plates are turned on once
-- for them. Turning them off again is the player's call and is kept:
-- every later pass of ours leaves the setting alone.
local settingPlates = false
local WHITE, YELLOW, GREEN = { 1, 1, 1 }, { 1, 1, 0 }, { 0.1, 1, 0.1 }
local WORDS = {
    MISS = "Miss", DODGE = "Dodge", PARRY = "Parry", BLOCK = "Block", RESIST = "Resist",
    ABSORB = "Absorb", IMMUNE = "Immune", EVADE = "Evade", DEFLECT = "Deflect", REFLECT = "Reflect",
}

local active = false
local root
local trace = {}
local function Trace(line)
    trace[#trace + 1] = line
    if #trace > 12 then table.remove(trace, 1) end
end
local live = {}
local lastHit = {}       -- guid -> { key, time }: the same hit arrives once per unit token
local savedCVar

local function Secret(value)
    return issecretvalue and issecretvalue(value)
end

local function Plate(unit)
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and plate and plate:IsShown() then return plate end
end

-- Each plate gets one holder frame, a child pinned under the plate's
-- bottom edge; the numbers are its font strings and pool per holder.
-- The plate is recycled between units by the client, the holder stays.
local function Holder(plate)
    local holder = plate.fcuiNumbers
    if not holder then
        holder = CreateFrame("Frame", nil, plate)
        holder:SetSize(1, 1)
        holder:SetPoint("BOTTOM", plate, "TOP", 0, ABOVE_PLATE)
        holder:SetFrameLevel(plate:GetFrameLevel() + 10)
        holder.pool = {}
        plate.fcuiNumbers = holder
    end
    return holder
end

local function Acquire(holder)
    local text = table.remove(holder.pool)
    if not text then
        text = holder:CreateFontString(nil, "OVERLAY")
    end
    text:Show()
    return text
end

local function Release(entry)
    entry.text:Hide()
    entry.text:ClearAllPoints()
    entry.holder.pool[#entry.holder.pool + 1] = entry.text
end

local function Place(entry)
    entry.text:ClearAllPoints()
    entry.text:SetPoint("BOTTOM", entry.holder, "BOTTOM", entry.dx + entry.drift * entry.progress, entry.base + entry.rise)
end

-- The client recycles a plate for the next unit; whatever is still
-- floating on it goes at once.
local function DropPlate(plate)
    for i = #live, 1, -1 do
        if live[i].plate == plate then
            Release(live[i])
            table.remove(live, i)
        end
    end
end

local function OnUpdate()
    local now = GetTime()
    for i = #live, 1, -1 do
        local entry = live[i]
        local t = now - entry.start
        local life = entry.crit and CRIT_LIFE or LIFE
        if t >= life then
            Release(entry)
            table.remove(live, i)
        else
            entry.progress = t / life
            local alpha = 1
            if entry.crit then
                if t < CRIT_DROP_TIME then
                    local u = t / CRIT_DROP_TIME
                    local left = (1 - u) * (1 - u)
                    entry.rise = CRIT_DROP_HEIGHT * left
                    Size(entry.text, CRIT_SIZE * (1 + (CRIT_START_SCALE - 1) * left))
                    alpha = 0.4 + 0.6 * u
                else
                    if not entry.settled then
                        entry.settled = true
                        Size(entry.text, CRIT_SIZE)
                    end
                    entry.rise = RISE_SPEED * (t - CRIT_DROP_TIME)
                end
            else
                entry.rise = RISE_SPEED * t
            end
            if t > life - FADE then alpha = math.min(alpha, (life - t) / FADE) end
            entry.text:SetAlpha(alpha)
            Place(entry)
        end
    end
    if #live == 0 then root:SetScript("OnUpdate", nil) end
end

local function Show(unit, action, flag, amount, school)
    Trace(string.format("%s %s %s %s %s", tostring(unit), tostring(action), tostring(flag), Secret(amount) and "<secret>" or tostring(amount), tostring(school)))
    if not active or not unit or unit == "player" or UnitIsUnit(unit, "player") then return end
    local label, color
    if action == "WOUND" then
        if not UnitCanAttack("player", unit) then return end
        label = amount
        color = (school == 1) and WHITE or YELLOW
    elseif action == "HEAL" then
        label = amount
        color = GREEN
    elseif WORDS[action] then
        if not UnitCanAttack("player", unit) then return end
        label = WORDS[action]
        color = WHITE
    else
        return
    end
    local guid = UnitGUID(unit)
    local now = GetTime()
    if guid then
        local key = Secret(amount) and action or (action .. ":" .. tostring(amount))
        local last = lastHit[guid]
        if last and last.key == key and now - last.time < 0.05 then return end
        lastHit[guid] = { key = key, time = now }
    end
    local plate = Plate(unit)
    if not plate then Trace("  no plate for " .. unit) return end
    local holder = Holder(plate)
    Trace("  hung on " .. (plate:GetDebugName() or "plate"))
    local crit = flag == "CRITICAL"
    local text = Acquire(holder)
    if not Size(text, crit and CRIT_SIZE * CRIT_START_SCALE or SIZE) then Trace("  font did not load, font object used") end
    text:SetTextColor(color[1], color[2], color[3])
    if action == "HEAL" and not Secret(amount) then
        text:SetText("+" .. tostring(amount))
    else
        text:SetText(label)
    end
    text:SetAlpha(crit and 0.4 or 1)
    -- Stack above whatever is still near the start on this plate, the
    -- way the old engine kept a burst of hits readable.
    local base = 0
    for _, other in ipairs(live) do
        if other.holder == holder then
            local top = other.base + other.rise
            if top < base + STACK_GAP then base = top + STACK_GAP end
        end
    end
    local entry = {
        text = text, plate = plate, holder = holder, start = now, crit = crit, rise = 0, progress = 0, base = base,
        dx = math.random(-SCATTER, SCATTER), drift = math.random(-DRIFT, DRIFT),
    }
    live[#live + 1] = entry
    Place(entry)
    root:SetScript("OnUpdate", OnUpdate)
end

local function PlatesOn()
    if not GetCVar then return false end
    local ok, value = pcall(GetCVar, PLATES_CVAR)
    return ok and value ~= nil and value ~= "0"
end

local function FindCVar()
    if CVAR or not GetCVar then return end
    for _, name in ipairs(CVAR_NAMES) do
        local ok, value = pcall(GetCVar, name)
        if ok and value ~= nil then CVAR = name break end
    end
end

-- The engine's own numbers step aside only while ours can be placed,
-- that is while enemy nameplates are on; the setting comes back when
-- plates go off or the toggle does.
-- The client remembers cvars between sessions, so a "0" written by an
-- earlier session is still there at the next login: when the engine's
-- numbers are wanted they are switched on outright, never merely
-- restored from what this session saved.
local function EngineNumbers(shown)
    if not SetCVar or InCombatLockdown() then return end
    if shown then
        savedCVar = nil
        for _, name in ipairs(CVAR_NAMES) do
            local ok, value = pcall(GetCVar, name)
            if ok and value == "0" then pcall(SetCVar, name, "1") end
        end
    elseif CVAR then
        local ok, value = pcall(GetCVar, CVAR)
        if ok and value ~= nil and value ~= "0" then
            if savedCVar == nil then savedCVar = value end
            pcall(SetCVar, CVAR, "0")
        end
    end
end

local function Sync()
    if not active then return end
    EngineNumbers(not PlatesOn())
end

local function Build()
    root = CreateFrame("Frame", "ForeverClassicUICombatNumbers", UIParent)
    root:SetAllPoints(UIParent)
    root:SetFrameStrata("MEDIUM")
    root:SetScript("OnEvent", function(_, event, ...)
        if event == "UNIT_COMBAT" then
            if PlatesOn() then Show(...) end
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            local plate = Plate(...)
            if plate then DropPlate(plate) end
        elseif event == "CVAR_UPDATE" then
            local name, value = ...
            if name == PLATES_CVAR then
                if not settingPlates and (value == "0" or value == 0 or value == false) then
                    ns.db.platesHiddenByPlayer = true
                    savedPlates = nil
                end
                Sync()
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            Sync()
        end
    end)
end

local function Apply()
    active = true
    if not root then Build() end
    root:RegisterEvent("UNIT_COMBAT")
    root:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    root:RegisterEvent("CVAR_UPDATE")
    root:RegisterEvent("PLAYER_REGEN_ENABLED")
    FindCVar()
    if GetCVar and SetCVar and not InCombatLockdown() then
        -- Enemy nameplates on: the plate is where the numbers live. Not
        -- if the player has turned them off since; that choice stands.
        local ok, value = pcall(GetCVar, PLATES_CVAR)
        if ok and value == "0" and not ns.db.platesHiddenByPlayer then
            if savedPlates == nil then savedPlates = value end
            settingPlates = true
            pcall(SetCVar, PLATES_CVAR, "1")
            C_Timer.After(0, function() settingPlates = false end)
        end
        ok, value = pcall(GetCVar, PLAYER_TEXT_CVAR)
        if ok and value ~= nil and value ~= "1" then
            if savedPlayerText == nil then savedPlayerText = value end
            pcall(SetCVar, PLAYER_TEXT_CVAR, "1")
        end
    end
    Sync()
end

local function Restore()
    active = false
    if root then
        root:UnregisterAllEvents()
        for i = #live, 1, -1 do Release(live[i]) live[i] = nil end
        root:SetScript("OnUpdate", nil)
    end
    EngineNumbers(true)
    if SetCVar and not InCombatLockdown() then
        if savedPlayerText ~= nil then
            pcall(SetCVar, PLAYER_TEXT_CVAR, savedPlayerText)
            savedPlayerText = nil
        end
        if savedPlates ~= nil then
            pcall(SetCVar, PLATES_CVAR, savedPlates)
            savedPlates = nil
        end
    end
end

function ns.CombatNumbersInfo()
    local cvar = "?"
    if GetCVar and CVAR then local ok, v = pcall(GetCVar, CVAR) if ok then cvar = tostring(v) end end
    return {
        active = active, registered = root and root:IsEventRegistered("UNIT_COMBAT") or false,
        cvarName = CVAR, cvar = cvar, saved = savedCVar, live = #live, font = FONT, fontFailed = fontFailed, trace = trace, plates = PlatesOn(),
    }
end

ns.RegisterModule("combatNumbers", { apply = Apply, restore = Restore })
