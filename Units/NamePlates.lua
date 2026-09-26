local _, ns = ...

-- 1.x plate: 128x16 border with the level in its right slot, 102x8 health bar, name above, cast bar below.
-- We re-lay the client plate's pieces and fade its retail art; forbidden plates (instances) are left alone.

local Dress, DressNew, FadeKeys, IsSecret = ns.Dress, ns.DressNew, ns.FadeKeys, ns.IsSecret

local BORDER_W, BORDER_H = 128, 16
local INSET_L, INSET_R, INSET_T, INSET_B = 5, 21, 4, 4
local BAR_W, BAR_H = BORDER_W - INSET_L - INSET_R, BORDER_H - INSET_T - INSET_B
local BORDER_GAP = 2       -- health border to cast border
local NAME_GAP = 2         -- name bottom above the border top
local AURA_GAP = 4         -- debuff row above the name
-- Level slot spans 109-124 of the sheet's 128: centre 11.5 from the right.
local LEVEL_X = -11.5
local ICON_SIZE = 14
-- Cast border has no level slot: the left half twice, the second mirrored; the bar runs into the slot's width.
local CAST_EXTRA = INSET_R - INSET_L

local FULL = { 0, 1, 0, 1 }
local BORDER = { own = "border", layer = "OVERLAY", sublevel = 2, coords = { 0, 1, 0.5, 1 }, point = "TOPLEFT", x = -INSET_L, y = INSET_T,
    point2 = "BOTTOMRIGHT", x2 = INSET_R, y2 = -INSET_B, show = true }
local BORDER_L = { own = "borderL", layer = "OVERLAY", sublevel = 2, w = BORDER_W / 2, h = BORDER_H, coords = { 0, 0.5, 0.5, 1 },
    point = "TOPLEFT", x = -INSET_L, y = INSET_T, show = true }
local BORDER_R = { own = "borderR", layer = "OVERLAY", sublevel = 2, w = BORDER_W / 2, h = BORDER_H, coords = { 0.5, 0, 0.5, 1 },
    point = "TOPRIGHT", x = INSET_L, y = INSET_T, show = true }
local BAR_FILL = { coords = FULL }
local HEALTH_ART = { "bgTexture", "selectedBorder", "deselectedOverlay", "Text", "LeftText", "RightText" }
local BADGES = { "LevelFrame", "PlayerLevelDiffFrame", "ClassificationFrame" }
local CAST_ART = { "Background", "Border" }
local PLATE_EVENTS = { "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "UNIT_LEVEL", "PLAYER_TARGET_CHANGED", "UNIT_FACTION", "UNIT_FLAGS",
    "PLAYER_FOCUS_CHANGED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "CVAR_UPDATE",
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED" }
local CAST_EVENTS = { UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_CHANNEL_START = true,
    UNIT_SPELLCAST_CHANNEL_STOP = true, UNIT_SPELLCAST_INTERRUPTED = true }

-- The game's nameplate Size (Small..Huge) at the client's classic-style scale steps.
local SIZE_CVAR = "nameplateSize"
local SIZE_SCALES = { 0.8, 1.0, 1.25, 1.4, 1.6 }
-- Read at most once a second (every plate asks on every re-lay); CVAR_UPDATE clears it.
local plateScale, plateScaleAt = nil, 0
local function PlateScale()
    local now = GetTime()
    if plateScale and now - plateScaleAt < 1 then return plateScale end
    local value = tonumber(ns.GetCVar(SIZE_CVAR))
    plateScale, plateScaleAt = SIZE_SCALES[value or 2] or 1, now
    return plateScale
end

-- Shared with NamePlateOptions.lua; active is written only by SetActive.
local NP = { active = false }
ns.NP = NP

local skinned = setmetatable({}, { __mode = "k" })

local Forbidden = ns.IsForbidden

-- Border sheet around a bar, above its fill.
local function Border(bar)
    return (DressNew(bar, "nameplateBorder", BORDER))
end

local function CastBorder(bar)
    if bar.fcui and bar.fcui.border then bar.fcui.border:Hide() end
    local left = DressNew(bar, "nameplateBorder", BORDER_L)
    DressNew(bar, "nameplateBorder", BORDER_R)
    return left
end

local function ShadedFill(bar)
    local tex = bar.barTexture or (bar.GetStatusBarTexture and bar:GetStatusBarTexture())
    if not tex then return end
    tex:SetAtlas(nil)
    Dress(tex, "barFill", BAR_FILL)
end

local function UpdateLevel(unitFrame)
    local own = unitFrame.fcui
    local level, skull = own and own.level, own and own.skull
    if not level or not unitFrame.unit then return end
    local lvl = UnitLevel(unitFrame.unit)
    if lvl == nil or IsSecret(lvl) then
        level:SetText("")
        skull:Hide()
        return
    end
    if ns.SkullLevel(lvl, unitFrame.unit) then
        level:SetText("")
        skull:Show()
        return
    end
    skull:Hide()
    level:SetText(lvl)
    -- Target frame colour by unit (by level this client says yellow where the frame shows green); gold if not attackable.
    local color
    local foe = UnitCanAttack("player", unitFrame.unit)
    if IsSecret(foe) then foe = false end
    if foe then
        local rate = C_PlayerInfo and C_PlayerInfo.GetContentDifficultyCreatureForPlayer
        if rate and GetDifficultyColor then
            local ok, difficulty = pcall(rate, unitFrame.unit)
            if ok and difficulty then color = GetDifficultyColor(difficulty) end
        end
        if not color and GetCreatureDifficultyColor then color = GetCreatureDifficultyColor(lvl) end
    end
    if color then level:SetTextColor(color.r, color.g, color.b) else level:SetTextColor(1, 0.82, 0) end
end

-- The client's bottom-up chain at 1.x sizes, bars scaled by Size; name and auras keep the client's sizing.
local function LayChain(unitFrame, castContainer, container, health)
    local scale = PlateScale()
    ns.SetScaleIf(castContainer, scale)
    ns.SetScaleIf(container, scale)
    ns.SetSizeIf(castContainer, BAR_W, BAR_H)
    ns.SetPointIf(castContainer, "BOTTOM", unitFrame, "BOTTOM", 0, INSET_B)
    ns.SetSizeIf(container, BAR_W, BAR_H)
    ns.SetPointIf(container, "BOTTOM", castContainer, "TOP", 0, INSET_T + BORDER_GAP + INSET_B)
    ns.SetTwoPointsIf(health, "TOPLEFT", container, "TOPLEFT", 0, 0, "BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
end

-- Cast bar: same fill and border, icon to the left, text inside.
local function LayCast(castContainer)
    local cast = castContainer.castBar
    if not cast then return end
    ns.SetTwoPointsIf(cast, "TOPLEFT", castContainer, "TOPLEFT", 0, 0, "BOTTOMRIGHT", castContainer, "BOTTOMRIGHT", CAST_EXTRA, 0)
    ShadedFill(cast)
    -- 1.x yellow cast, green channel: the client picks colour by bar art, which is ours now.
    if cast.channeling then
        ns.SetBarColorIf(cast, 0, 1, 0)
    else
        ns.SetBarColorIf(cast, 1, 0.7, 0)
    end
    local castBorder = CastBorder(cast)
    FadeKeys(cast, CAST_ART)
    if cast.Icon then
        ns.SetSizeIf(cast.Icon, ICON_SIZE, ICON_SIZE)
        ns.SetPointIf(cast.Icon, "RIGHT", castBorder, "LEFT", -1, 0)
    end
    if cast.Text then
        ns.SetPointIf(cast.Text, "CENTER", cast, "CENTER", 0, 0)
        cast.Text:SetJustifyH("CENTER")
    end
    if cast.CastTargetNameText then ns.SetAlphaIf(cast.CastTargetNameText, 0) end
end

-- Plate pieces, nil for a plate we leave alone.
local function Pieces(unitFrame)
    if not NP.active or Forbidden(unitFrame) then return nil end
    local container = unitFrame.HealthBarsContainer
    local health = container and container.healthBar
    local castContainer = unitFrame.CastBarsContainer
    if not health or not castContainer then return nil end
    return container, health, castContainer
end

-- A cast starting or ending moves only the chain and the cast bar.
local function CastLayout(unitFrame)
    local container, health, castContainer = Pieces(unitFrame)
    if not container then return end
    LayChain(unitFrame, castContainer, container, health)
    LayCast(castContainer)
end

-- Runs after the client has anchored the unit frame.
local function Layout(unitFrame)
    local container, health, castContainer = Pieces(unitFrame)
    if not container then return end
    unitFrame.fcui = unitFrame.fcui or {}
    local own = unitFrame.fcui

    LayChain(unitFrame, castContainer, container, health)

    ShadedFill(health)
    NP.ClassColor(unitFrame)
    local border = Border(health)
    FadeKeys(health, HEALTH_ART)
    FadeKeys(unitFrame, BADGES)

    -- Level in the border slot, a skull when unknown.
    local level = own.level
    if not level then
        level = health:CreateFontString(nil, "OVERLAY", "SystemFont_NamePlateLevel")
        level:SetDrawLayer("OVERLAY", 3)
        level:SetShadowColor(0, 0, 0, 1)
        level:SetShadowOffset(1, -1)
        own.level = level
        local skull = health:CreateTexture(nil, "OVERLAY", nil, 3)
        skull:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
        skull:SetSize(12, 12)
        skull:Hide()
        own.skull = skull
    end
    ns.SetPointIf(level, "CENTER", border, "RIGHT", LEVEL_X, 0)
    ns.SetPointIf(own.skull, "CENTER", border, "RIGHT", LEVEL_X, 0)
    UpdateLevel(unitFrame)

    -- Name centred above the border, sized to its text; debuffs above it.
    local name = unitFrame.name
    if name then
        ns.SetPointIf(name, "BOTTOM", border, "TOP", 0, NAME_GAP)
        name:SetWidth(0)
        name:SetJustifyH("CENTER")
        name:SetShadowColor(0, 0, 0, 1)
        name:SetShadowOffset(1, -1)
        local debuffs = ns.Path(unitFrame, "AurasFrame", "DebuffListFrame")
        if debuffs then
            ns.SetTwoPointsIf(debuffs, "LEFT", border, "LEFT", 0, 0, "BOTTOM", name, "TOP", 0, AURA_GAP)
        end
    end

    LayCast(castContainer)
end

-- From our passes, never a client hook: a pass our code joins is refused unit health for the rest of it.
local function SkinPlate(unitFrame)
    if not NP.active or Forbidden(unitFrame) then return end
    skinned[unitFrame] = true
    Layout(unitFrame)
end

-- The settings sample plate's "preview" token makes the lookup error: that is no plate.
local function PlateFor(unitToken)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unitToken)
    return ok and plate and plate.UnitFrame or nil
end

local function LivePlate(unit)
    local unitFrame = unit and PlateFor(unit)
    if unitFrame and not Forbidden(unitFrame) then return unitFrame end
end

-- Every plate on screen; forbidden ones only with withForbidden. Returns how many fn saw.
local function EachPlate(fn, withForbidden)
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return 0 end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= "table" then return 0 end
    local seen = 0
    for _, plate in ipairs(plates) do
        local unitFrame = plate and plate.UnitFrame
        if unitFrame and (withForbidden or not Forbidden(unitFrame)) then
            seen = seen + 1
            fn(unitFrame)
        end
    end
    return seen
end
NP.EachPlate = EachPlate

-- Plates re-lay after the client's handlers for what re-anchors them (added, faction, target, focus, casts, options, scale),
-- in this frame's pass and the next: a plate registers its events after ours. Only player plates change colour with no
-- event (a duel, a flag, a death): a 0.2 s sweep recolours while one shows.
local SWEEP = 0.2
local driver, sweepJob
-- Plates owed a re-lay in this frame's pass and in the next frame's; all = every plate.
local relaySoon = { plates = setmetatable({}, { __mode = "k" }) }
local relayNext = { plates = setmetatable({}, { __mode = "k" }) }

-- Sole writer of the sweep's awake state.
local function SetSweeping(on)
    if not sweepJob then return end
    if on then sweepJob:Wake() else sweepJob:Sleep() end
end

-- Sole writer of NP.active.
local function SetActive(on)
    NP.active = on
    SetSweeping(on)
end

local function Relay(owed)
    local plates = owed.plates
    if owed.all then
        owed.all = false
        wipe(plates)
        EachPlate(SkinPlate)
        return
    end
    for unitFrame, kind in pairs(plates) do
        plates[unitFrame] = nil
        -- A plate never fully laid gets the whole pass.
        if kind == "cast" and skinned[unitFrame] then CastLayout(unitFrame) else SkinPlate(unitFrame) end
    end
end

local function RelaySoon() Relay(relaySoon) end
local function RelayNext() Relay(relayNext) end

-- kind: true for the whole plate, "cast" for the chain and cast bar; a whole pass owed stays whole.
local function Owe(owed, unitFrame, kind)
    if not unitFrame then
        owed.all = true
    elseif owed.plates[unitFrame] ~= true then
        owed.plates[unitFrame] = kind
    end
end

local function QueueRelay(unitFrame, kind)
    kind = kind or true
    Owe(relaySoon, unitFrame, kind)
    Owe(relayNext, unitFrame, kind)
    ns.Sched.Soon("namePlates.relay", RelaySoon)
    ns.Sched.NextFrame("namePlates.relay", RelayNext)
end

-- A secret answer counts as a player: the sweep then finds out.
local function MaybePlayer(unit)
    local isPlayer = UnitIsPlayer(unit)
    return IsSecret(isPlayer) or isPlayer
end

local swept
local function SweepPlate(unitFrame)
    local unit = unitFrame.unit or unitFrame.displayedUnit
    local isPlayer = unit and UnitIsPlayer(unit)
    local maybe = IsSecret(isPlayer) or isPlayer
    if maybe then swept = swept + 1 end
    -- Not a player: only a fill of ours it still wears needs the pass.
    if not maybe and not NP.Painted(unitFrame) then return end
    NP.ClassColor(unitFrame, isPlayer)
end

local function Sweep()
    if not NP.active then return end
    swept = 0
    EachPlate(SweepPlate)
    -- No player plate in view: sleep until one is added.
    if swept == 0 then SetSweeping(false) end
end

local ALL_EVENTS = { PLAYER_TARGET_CHANGED = true, PLAYER_FOCUS_CHANGED = true, DISPLAY_SIZE_CHANGED = true,
    UI_SCALE_CHANGED = true, CVAR_UPDATE = true }

local function OnEvent(_, event, unit)
    if not NP.active then return end
    if event == "NAME_PLATE_UNIT_ADDED" then
        if MaybePlayer(unit) then SetSweeping(true) end
        local unitFrame = PlateFor(unit)
        if unitFrame then QueueRelay(unitFrame) end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        -- The plate is recycled for another unit.
        local unitFrame = LivePlate(unit)
        if unitFrame then NP.Unpaint(ns.Path(unitFrame, "HealthBarsContainer", "healthBar")) end
    elseif event == "UNIT_FACTION" or event == "UNIT_FLAGS" then
        local unitFrame = LivePlate(unit)
        if unitFrame then
            NP.ClassColor(unitFrame)
            if event == "UNIT_FACTION" then QueueRelay(unitFrame) end
        end
    elseif event == "UNIT_LEVEL" then
        local unitFrame = LivePlate(unit)
        if unitFrame then UpdateLevel(unitFrame) end
    elseif CAST_EVENTS[event] then
        -- Cast start or stop re-lays only that plate's chain and cast bar.
        local unitFrame = unit and PlateFor(unit)
        if unitFrame then QueueRelay(unitFrame, "cast") end
    elseif ALL_EVENTS[event] then
        if event == "CVAR_UPDATE" then plateScale = nil end
        QueueRelay()
    end
end

local function Apply()
    SetActive(true)
    NP.RestoreStyleChoice()
    if not NamePlateDriverFrame then ns.MissingPiece("NamePlateDriverFrame") return end
    if not driver then
        driver = CreateFrame("Frame")
        ns.RegisterEvents(driver, PLATE_EVENTS)
        driver:SetScript("OnEvent", OnEvent)
        sweepJob = ns.Sched.Job({ name = "namePlates.sweep", every = SWEEP, fn = Sweep })
    end
    EachPlate(SkinPlate)
end

local function Restore()
    SetActive(false)
    NP.RestoreStyleChoice()
    for unitFrame in pairs(skinned) do
        if unitFrame.fcui then
            for _, region in pairs(unitFrame.fcui) do region:Hide() end
        end
        if unitFrame.HealthBarsContainer then unitFrame.HealthBarsContainer:SetScale(1) end
        if unitFrame.CastBarsContainer then unitFrame.CastBarsContainer:SetScale(1) end
        local health = ns.Path(unitFrame, "HealthBarsContainer", "healthBar")
        local cast = ns.Path(unitFrame, "CastBarsContainer", "castBar")
        for _, bar in pairs({ health, cast }) do
            if bar.fcui then
                for _, tex in pairs(bar.fcui) do tex:Hide() end
            end
        end
        -- The client's fill back on its own draw step; ours re-pins if turned on again.
        local fill = health and health.fcui and health.fcui.fill
        local tex = fill and fill.fcuiPinnedTo
        if tex and fill.fcuiLayer then tex:SetDrawLayer(fill.fcuiLayer, fill.fcuiSub) end
        if fill then fill.fcuiPinnedTo = nil end
    end
    ns.needsReload = true
end

ns.RegisterModule("namePlates", { apply = Apply, restore = Restore })
