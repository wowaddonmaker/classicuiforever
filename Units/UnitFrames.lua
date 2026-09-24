local _, ns = ...

-- unitFrames module: driver, events, apply/restore.

local UF = ns.UF
local On, Keeper, KeepFrames, Update, UpdateAll, RepaintKept = UF.On, UF.Keeper, UF.KeepFrames, UF.Update, UF.UpdateAll, UF.RepaintKept
local HoverPass, HoverReset = UF.HoverPass, UF.HoverReset
local SkinPlayer, RestorePlayer, KeepPlayerArt = UF.SkinPlayer, UF.RestorePlayer, UF.KeepPlayerArt
local SkinTarget, RestoreTargetLike, KeepAuraRow = UF.SkinTarget, UF.RestoreTargetLike, UF.KeepAuraRow
local SkinPet, SkinParty, SkinPartySoon, KeepParty, RestoreParty = UF.SkinPet, UF.SkinParty, UF.SkinPartySoon, UF.KeepParty, UF.RestoreParty
local LayoutRaidManager, WatchRaidManager, SkinRaidManager = UF.LayoutRaidManager, UF.WatchRaidManager, UF.SkinRaidManager

-- Unit-filtered frames, two units each: our bars show only these; RepaintKept acts only on the pet.
local BAR_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }
local HEALTH_EVENTS = { UNIT_HEALTH = true, UNIT_MAXHEALTH = true }
-- A party frame shows partypetN while its member is in a vehicle, and skinning records it (PartyMemberFrame.lua 154).
local BAR_UNITS = { { "player", "pet" }, { "target", "focus" }, { "party1", "party2" }, { "party3", "party4" },
    { "partypet1", "partypet2" }, { "partypet3", "partypet4" } }
-- Unfiltered: each runs the full keeper pass.
local DRIVER_EVENTS = { "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "PLAYER_ENTERING_WORLD", "UNIT_ENTERED_VEHICLE",
    "UNIT_EXITED_VEHICLE", "GROUP_ROSTER_UPDATE", "PARTY_MEMBER_ENABLE", "PARTY_MEMBER_DISABLE", "PLAYER_REGEN_ENABLED",
    "UNIT_PET", "PLAYER_UPDATE_RESTING", "PLAYER_REGEN_DISABLED", "PLAYER_FLAGS_CHANGED", "UNIT_CLASSIFICATION_CHANGED",
    "UNIT_FACTION", "UNIT_LEVEL", "PLAYER_LEVEL_UP", "PLAYER_LEVEL_CHANGED",
    -- The rest of the player frame's own writers (Mainline/PlayerFrame.lua OnEvent, the alternate power bar).
    "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "PLAYER_ROLES_ASSIGNED", "HONOR_LEVEL_UPDATE", "PVP_TIMER_UPDATE",
    "PLAYER_SPECIALIZATION_CHANGED" }
local PLAYER_UNIT_EVENTS = { "UNIT_EXITING_VEHICLE", "UNIT_DISPLAYPOWER" }
local ROSTER_EVENTS = { GROUP_ROSTER_UPDATE = true, PARTY_MEMBER_ENABLE = true, PARTY_MEMBER_DISABLE = true,
    PLAYER_LEVEL_UP = true, PLAYER_LEVEL_CHANGED = true }
local POWER_FREQUENT = { "UNIT_POWER_FREQUENT" }
-- The client re-lays the aura row on these: UNIT_TARGET via the ToT-constrained rows (TargetFrame.lua 222-226),
-- threat when the threat number shows or hides (its OnShow/OnHide, TargetFrame.lua 1220-1221).
local AURA_EVENTS = { "UNIT_AURA", "UNIT_TARGET", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE" }
local TARGET_EVENTS = { "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED" }
local SNAP_FRAMES = { "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame" }

local driver
-- Whether a target or focus frame can show; the per-frame aura keep sleeps while not.
local auraLive = true

-- Sole writer of UF.active; hidden while off, the driver still gets events.
local function SetActive(on)
    UF.active = on
    if driver then
        if on then driver:Show() else driver:Hide() end
    end
end

-- Sole writer of auraLive. Frames show in the client's target, focus, roster and PEW handlers, before ours.
local function SetAuraLive()
    local live = (ns.EditMode.state or UnitExists("target") or UnitExists("focus")
        or (TargetFrame and TargetFrame:IsShown()) or (FocusFrame and FocusFrame:IsShown())) and true or false
    if live == auraLive or not driver then return end
    auraLive = live
    if live then
        -- What the forced-frame count had decayed to.
        driver.auraForce = 0
    else
        driver.threatT, driver.threatF = false, false
    end
end

local function OnEvent(_, event)
    UF.lastDriverEventAt = GetTime()
    if not UF.active then return end
    UF.HoverRelist()
    SetAuraLive()
    if ROSTER_EVENTS[event] then
        SkinPartySoon()
        ns.Sched.AfterPerFrame("unitFrames.party", 1, SkinParty)
    elseif event == "PLAYER_ENTERING_WORLD" then
        SkinPartySoon()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Re-apply what combat blocked.
        if UF.combatPending then
            UF.combatPending = false
            ns.QueueApply()
        end
    end
    KeepFrames()
    UpdateAll()
end

local function OnBarEvent(_, event, unit)
    if not UF.active then return end
    local what = HEALTH_EVENTS[event] and "health" or "power"
    RepaintKept(unit)
    for _, entry in pairs(UF.frames) do
        if entry.unit == unit then Update(entry, what) end
    end
end

local function KeepAuras(force)
    local frames = UF.frames
    if TargetFrame and frames[TargetFrame] and TargetFrame:IsShown() then KeepAuraRow(TargetFrame, force) end
    if FocusFrame and frames[FocusFrame] and FocusFrame:IsShown() then KeepAuraRow(FocusFrame, force) end
end

-- The client re-lays the aura row when the threat number shows or hides, from its own timer with no event.
local function ThreatFlipped()
    local t, f = TargetFrame and TargetFrame.threatNumericIndicator, FocusFrame and FocusFrame.threatNumericIndicator
    local ts, fs = (t and t:IsShown()) and true or false, (f and f:IsShown()) and true or false
    if ts == driver.threatT and fs == driver.threatF then return false end
    driver.threatT, driver.threatF = ts, fs
    return true
end

-- Per frame: hover numbers and aura rows; the row is put blind for two frames after a change and on the beat.
local function EveryFrame(job, elapsed)
    if not UF.active then return end
    HoverPass()
    if not auraLive then return end
    if ThreatFlipped() then driver.auraForce = 2 end
    local force = driver.auraForce > 0
    if force then driver.auraForce = driver.auraForce - 1 end
    if job:DueWith(elapsed) then force = true end
    KeepAuras(force)
end

local function Beat()
    if not UF.active then return end
    WatchRaidManager()
    RepaintKept("pet")
    KeepFrames(true)
end

-- A frame on half a pixel draws everything in it half a pixel off: round its offsets (own scale) in screen pixels.
local function SnapToPixels(frame)
    if not frame or InCombatLockdown() or not frame.GetPoint then return end
    local point, rel, relPoint, x, y = frame:GetPoint(1)
    if not point or not x then return end
    local scale = frame:GetScale()
    if not scale or scale <= 0 then scale = 1 end
    local sx, sy = x * scale, y * scale
    local nx, ny = math.floor(sx + 0.5), math.floor(sy + 0.5)
    if ns.Near(sx, nx, 0.01) and ns.Near(sy, ny, 0.01) then return end
    frame:SetPoint(point, rel, relPoint, nx / scale, ny / scale)
end

local function Apply()
    SetActive(true)
    -- Watched even when the skin below is blocked: a reload in combat leaves only the client's art.
    Keeper("player.art", KeepPlayerArt)
    Keeper("party", KeepParty)
    if not driver then
        driver = CreateFrame("Frame")
        -- Forced frames left; the dev addon's P1 probe reads it here.
        driver.auraForce = 0
        driver:SetScript("OnEvent", OnEvent)
        ns.RegisterEvents(driver, DRIVER_EVENTS)
        ns.RegisterEvents(driver, PLAYER_UNIT_EVENTS, "player")
        for i = 1, #BAR_UNITS do
            local bars = CreateFrame("Frame")
            ns.RegisterEvents(bars, BAR_EVENTS, BAR_UNITS[i][1], BAR_UNITS[i][2])
            bars:SetScript("OnEvent", OnBarEvent)
        end
        -- Player power per point (UNIT_POWER_UPDATE comes in steps), not per frame: it is secret even out of combat.
        local powerKick = CreateFrame("Frame")
        ns.RegisterEvents(powerKick, POWER_FREQUENT, "player")
        powerKick:SetScript("OnEvent", function()
            if UF.active and UF.frames.player then Update(UF.frames.player, "power") end
        end)
        -- Own frame: the aura row goes back at once, then blind for the next two frames.
        local auraKick = CreateFrame("Frame")
        ns.RegisterEvents(auraKick, AURA_EVENTS, "target", "focus")
        ns.RegisterEvents(auraKick, TARGET_EVENTS)
        auraKick:SetScript("OnEvent", function()
            if not UF.active then return end
            SetAuraLive()
            driver.auraForce = 2
            KeepAuras(true)
        end)
        ns.Sched.OnFrame(driver, { name = "unitFrames.beat", every = 0.25, pre = EveryFrame, fn = Beat })
        -- Edit mode shows unitless previews of the target, focus and party frames.
        ns.OnEditMode(function()
            UF.HoverRelist()
            SetAuraLive()
        end)
    end
    if On("player") then SkinPlayer() else RestorePlayer() end
    if On("target") then SkinTarget(TargetFrame, "target") else RestoreTargetLike(TargetFrame) end
    if On("focus") then SkinTarget(FocusFrame, "focus") else RestoreTargetLike(FocusFrame) end
    if On("pet") then SkinPet() end
    if On("party") then SkinParty() else RestoreParty() end
    SkinRaidManager()
    for i = 1, #SNAP_FRAMES do SnapToPixels(_G[SNAP_FRAMES[i]]) end
    UF.HoverRelist()
    SetAuraLive()
end

-- Our art stays until a reload; only the live pieces step aside.
local function Restore()
    SetActive(false)
    HoverReset()
    LayoutRaidManager()
    RestorePlayer()
    RestoreTargetLike(TargetFrame)
    RestoreTargetLike(FocusFrame)
    RestoreParty()
    ns.needsReload = true
end

ns.RegisterModule("unitFrames", { apply = Apply, restore = Restore })
