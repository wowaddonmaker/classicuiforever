local _, ns = ...

-- unitFrames module: driver, events, apply/restore.

local UF = ns.UF
local On, Keeper, KeepFrames, Update, UpdateAll, RepaintKept = UF.On, UF.Keeper, UF.KeepFrames, UF.Update, UF.UpdateAll, UF.RepaintKept
local IsPetUnit = UF.IsPetUnit
local HoverGate, HoverReset = UF.HoverGate, UF.HoverReset
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
    "PLAYER_SPECIALIZATION_CHANGED",
    -- Party art (PartyMemberFrame.lua UpdateMember/UpdateArt), the pet frame's refresh (PetFrame.lua OnEvent) and
    -- a layout applied outside edit mode (focus size and its ToT, raid-style party frames).
    "UNIT_CONNECTION", "UPDATE_ACTIVE_BATTLEFIELD", "PET_UI_UPDATE", "EDIT_MODE_LAYOUTS_UPDATED" }
-- Driver events carrying a unit: they come for every nameplate and group member, so only units our frames show pass.
local UNIT_DRIVER_EVENTS = { UNIT_ENTERED_VEHICLE = true, UNIT_EXITED_VEHICLE = true, UNIT_PET = true,
    UNIT_CLASSIFICATION_CHANGED = true, UNIT_FACTION = true, UNIT_LEVEL = true, UNIT_CONNECTION = true,
    PLAYER_FLAGS_CHANGED = true }
local SHOWN_UNITS = { player = true, pet = true, vehicle = true, target = true, focus = true, targettarget = true,
    focustarget = true }
for i = 1, 4 do
    SHOWN_UNITS["party" .. i] = true
    SHOWN_UNITS["partypet" .. i] = true
end
-- UNIT_NAME_UPDATE: the client rewrites the player's name then, so the name keeper answers after it.
local PLAYER_UNIT_EVENTS = { "UNIT_EXITING_VEHICLE", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE" }
local ROSTER_EVENTS = { GROUP_ROSTER_UPDATE = true, PARTY_MEMBER_ENABLE = true, PARTY_MEMBER_DISABLE = true,
    PLAYER_LEVEL_UP = true, PLAYER_LEVEL_CHANGED = true }
local LAYOUT_EVENTS = { EDIT_MODE_LAYOUTS_UPDATED = true, PLAYER_SPECIALIZATION_CHANGED = true }
local POWER_FREQUENT = { "UNIT_POWER_FREQUENT" }
-- The client re-lays the aura row on these: UNIT_TARGET via the ToT-constrained rows (TargetFrame.lua 222-226),
-- threat when the threat number shows or hides (its OnShow/OnHide, TargetFrame.lua 1220-1221).
local AURA_EVENTS = { "UNIT_AURA", "UNIT_TARGET", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE" }
local TARGET_EVENTS = { "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED" }
-- The pet frame's UnitFrame_Update paints its mana bar white on these (UnitFrame.lua OnEvent, the vehicle data).
local PET_EVENTS = { "UNIT_NAME_UPDATE", "PLAYER_GAINS_VEHICLE_DATA", "PLAYER_LOSES_VEHICLE_DATA" }
local SNAP_FRAMES = { "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame" }
local KEEPER_OF = { target = "target.frame", focus = "focus.frame" }

local driver, auraJob, editJob
-- Whether a target or focus frame can show; the aura beat sleeps while not.
local auraLive = false
-- Frames left in the hot window after a re-lay trigger: the first two put the row blind, the rest look (readable only
-- out of combat), so a late re-lay goes back on its frame.
local AURA_HOT, AURA_LOOK = 6, 4
local auraFrames = 0

-- Sole writer of the jobs' wake: the aura beat while a target or focus can show, the keeper beat in edit mode.
local function RefreshJobs()
    if not auraJob then return end
    if UF.active and auraLive then auraJob:Wake() else auraJob:Sleep() end
    if UF.active and ns.EditMode.state then editJob:Wake() else editJob:Sleep() end
end

-- Sole writer of UF.active; the driver gets events either way.
local function SetActive(on)
    UF.active = on
    RefreshJobs()
end

-- Sole writer of auraLive. Frames show in the client's target, focus, roster and PEW handlers, before ours.
local function SetAuraLive()
    auraLive = (ns.EditMode.state or UnitExists("target") or UnitExists("focus")
        or (TargetFrame and TargetFrame:IsShown()) or (FocusFrame and FocusFrame:IsShown())) and true or false
    if not auraLive then auraFrames = 0 end
    RefreshJobs()
end

-- A change the client re-lays the aura row on: the window starts on this frame's pass.
local function AuraHot()
    if not auraJob or not auraLive or not UF.active then return end
    auraFrames = AURA_HOT
    auraJob:Kick()
end
UF.AuraHot = AuraHot

-- The frame after a trigger, in case the client's own handler ran after ours: party art, pet bars, raid manager.
local function AfterTrigger()
    if not UF.active then return end
    KeepParty()
    RepaintKept("pet")
    WatchRaidManager()
end

local function SoonAfter()
    ns.Sched.NextFrame("unitFrames.after", AfterTrigger)
end

local function KeepAgain()
    if UF.active then KeepFrames() end
end

-- No unit, or an unreadable one, counts as shown.
local function ShownUnit(unit)
    if type(unit) ~= "string" or ns.IsSecret(unit) or SHOWN_UNITS[unit] then return true end
    for _, entry in pairs(UF.frames) do
        if entry.unit == unit then return true end
    end
    return false
end

local function OnEvent(_, event, unit)
    if UNIT_DRIVER_EVENTS[event] and not ShownUnit(unit) then return end
    UF.lastDriverEventAt = GetTime()
    if not UF.active then return end
    UF.HoverRelist()
    SetAuraLive()
    if ROSTER_EVENTS[event] then
        SkinPartySoon()
        ns.Sched.AfterPerFrame("unitFrames.party", 1, SkinParty)
        -- The party is laid out on later frames: its art then too, in combat where the skin waits.
        ns.Sched.AfterPerFrame("unitFrames.after", 0.3, AfterTrigger)
        ns.Sched.AfterPerFrame("unitFrames.after", 1, AfterTrigger)
    elseif event == "PLAYER_ENTERING_WORLD" then
        SkinPartySoon()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Re-apply what combat blocked.
        if UF.combatPending then
            UF.combatPending = false
            ns.QueueApply()
        end
    elseif LAYOUT_EVENTS[event] then
        -- The layout's systems may be set after our handler: every keeper once more on the next frame.
        ns.Sched.NextFrame("unitFrames.layout", KeepAgain)
    end
    KeepFrames()
    UpdateAll()
    RepaintKept("pet")
    WatchRaidManager()
    AuraHot()
    SoonAfter()
end

-- The killing blow sends only health and the corpse flag can trail it: the level spot's skull follows both.
local UnitIsDead, UnitIsCorpse = _G.UnitIsDead, _G.UnitIsCorpse
local deadWas, corpseWas = {}, {}
local function LevelFlip(unit)
    local key = KEEPER_OF[unit]
    local keep = key and UF.keepers[key]
    if not keep then return false end
    local dead, corpse = UnitIsDead(unit), UnitIsCorpse and UnitIsCorpse(unit)
    if ns.AnySecret(dead, corpse) then return false end
    dead, corpse = dead and true or false, corpse and true or false
    if dead == deadWas[unit] and corpse == corpseWas[unit] then return false end
    local died = dead and not deadWas[unit]
    deadWas[unit], corpseWas[unit] = dead, corpse
    ns.SafeCall(keep)
    return died
end

local function LevelFlips()
    if not UF.active then return end
    LevelFlip("target")
    LevelFlip("focus")
end

local function OnBarEvent(_, event, unit)
    if not UF.active then return end
    local what = HEALTH_EVENTS[event] and "health" or "power"
    RepaintKept(unit)
    -- The pet frame's own handler for its max and power type may come after ours.
    if event ~= "UNIT_HEALTH" and event ~= "UNIT_POWER_UPDATE" and IsPetUnit(unit) then SoonAfter() end
    for _, entry in pairs(UF.frames) do
        if entry.unit == unit then Update(entry, what) end
    end
    if what == "health" and LevelFlip(unit) then
        ns.Sched.AfterPerFrame("unitFrames.level", 0.5, LevelFlips)
        ns.Sched.AfterPerFrame("unitFrames.level", 1.5, LevelFlips)
    end
end

local function OnPetEvent(_, _, unit)
    if not UF.active or not IsPetUnit(unit) then return end
    RepaintKept("pet")
    SoonAfter()
end

local function KeepAuras(force)
    local frames = UF.frames
    if TargetFrame and frames[TargetFrame] and TargetFrame:IsShown() then KeepAuraRow(TargetFrame, force) end
    if FocusFrame and frames[FocusFrame] and FocusFrame:IsShown() then KeepAuraRow(FocusFrame, force) end
end

-- Forced on the beat and the window's first frames: blind while its anchor is secret (in combat), else only when moved.
local function AuraPass(job)
    if not UF.active then return end
    KeepAuras(auraFrames == 0 or auraFrames > AURA_LOOK)
    if auraFrames > 0 then
        auraFrames = auraFrames - 1
        if auraFrames > 0 then job:Kick() end
    end
end

-- In edit mode the client re-lays party, pet and target frames on setting clicks, with no event.
local function EditBeat()
    if not UF.active then return end
    WatchRaidManager()
    RepaintKept("pet")
    KeepFrames(true)
end

-- Pure child watchers: their OnShow/OnHide run only on the host's visibility edges.
local watchers = setmetatable({}, { __mode = "k" })
local function Watch(host, onEdge)
    if not host or watchers[host] then return end
    local watch = CreateFrame("Frame", nil, host)
    watch:SetScript("OnShow", onEdge)
    watch:SetScript("OnHide", onEdge)
    watchers[host] = watch
end

local function UIShown()
    AuraHot()
    SoonAfter()
end

-- The threat number re-lays the aura row from its OnShow/OnHide (TargetFrame.lua 1220-1221); the UI's show resets
-- party art, pet bars and aura rows; the raid manager's arrow shows and hides with its collapse.
local function WatchEdges()
    Watch(TargetFrame and TargetFrame.threatNumericIndicator, AuraHot)
    Watch(FocusFrame and FocusFrame.threatNumericIndicator, AuraHot)
    Watch(UIParent, UIShown)
    Watch(CompactRaidFrameManager and CompactRaidFrameManager.toggleButtonForward, SoonAfter)
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
    local _, _, setPoint = ns.BaseSetters(frame)
    setPoint(frame, point, rel, relPoint, nx / scale, ny / scale)
end

-- The client writes no name for your own character with UnitSurnameOwn at 0 and no surname part
-- (NameUtil.GetUnitFirstName), and "Unknown" before names load: filled from UnitName, never over a real name.
local function OwnName(text, unit)
    if not text then return end
    local mine = UnitIsUnit(unit, "player")
    if ns.IsSecret(mine) or not mine then return end
    local shown = text:GetText()
    if ns.IsSecret(shown) or (shown ~= nil and shown ~= "" and shown ~= UNKNOWNOBJECT) then return end
    local name = UnitName("player")
    if ns.IsSecret(name) or type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then return end
    text:SetText(name)
end

local function KeepOwnName()
    OwnName(PlayerName, "player")
    OwnName(ns.Path(TargetFrame, "TargetFrameContent", "TargetFrameContentMain", "Name"), "target")
    OwnName(ns.Path(FocusFrame, "TargetFrameContent", "TargetFrameContentMain", "Name"), "focus")
end

local function Apply()
    SetActive(true)
    -- Watched even when the skin below is blocked: a reload in combat leaves only the client's art.
    Keeper("player.art", KeepPlayerArt)
    Keeper("player.name", KeepOwnName)
    Keeper("party", KeepParty)
    if not driver then
        driver = CreateFrame("Frame")
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
            KeepAuras(true)
            AuraHot()
        end)
        ns.EventFrame(PET_EVENTS, OnPetEvent, "pet", "player")
        auraJob = ns.Sched.Job({ name = "unitFrames.auras", every = 0.25, awake = false, fn = AuraPass })
        editJob = ns.Sched.Job({ name = "unitFrames.edit", every = 0.25, awake = false, fn = EditBeat })
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
    WatchEdges()
    for i = 1, #SNAP_FRAMES do SnapToPixels(_G[SNAP_FRAMES[i]]) end
    UF.HoverRelist()
    HoverGate()
    SetAuraLive()
end

-- Our art stays until a reload; only the live pieces step aside.
local function Restore()
    SetActive(false)
    HoverReset()
    HoverGate()
    LayoutRaidManager()
    RestorePlayer()
    RestoreTargetLike(TargetFrame)
    RestoreTargetLike(FocusFrame)
    RestoreParty()
    ns.needsReload = true
end

ns.RegisterModule("unitFrames", { apply = Apply, restore = Restore })
