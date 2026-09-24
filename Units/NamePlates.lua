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
    "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "CVAR_UPDATE",
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED" }
local CAST_EVENTS = { UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_CHANNEL_START = true,
    UNIT_SPELLCAST_CHANNEL_STOP = true, UNIT_SPELLCAST_INTERRUPTED = true }

-- The game's nameplate Size (Small..Huge) at the client's classic-style scale steps.
local SIZE_CVAR = "nameplateSize"
local SIZE_SCALES = { 0.8, 1.0, 1.25, 1.4, 1.6 }
local function PlateScale()
    local value = C_CVar and C_CVar.GetCVar and tonumber(C_CVar.GetCVar(SIZE_CVAR))
    return SIZE_SCALES[value or 2] or 1
end

-- Shared with NamePlateOptions.lua; active is written only by SetActive.
local NP = { active = false }
ns.NP = NP

local skinned = setmetatable({}, { __mode = "k" })

local function Forbidden(frame)
    return not frame or (frame.IsForbidden and frame:IsForbidden())
end

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

-- Runs after the client has anchored the unit frame.
local function Layout(unitFrame)
    if not NP.active or Forbidden(unitFrame) then return end
    local container = unitFrame.HealthBarsContainer
    local health = container and container.healthBar
    local castContainer = unitFrame.CastBarsContainer
    if not health or not castContainer then return end
    unitFrame.fcui = unitFrame.fcui or {}
    local own = unitFrame.fcui

    -- The client's bottom-up chain at 1.x sizes, bars scaled by Size; name and auras keep the client's sizing.
    local scale = PlateScale()
    castContainer:SetScale(scale)
    container:SetScale(scale)
    castContainer:ClearAllPoints()
    castContainer:SetSize(BAR_W, BAR_H)
    castContainer:SetPoint("BOTTOM", unitFrame, "BOTTOM", 0, INSET_B)
    container:ClearAllPoints()
    container:SetSize(BAR_W, BAR_H)
    container:SetPoint("BOTTOM", castContainer, "TOP", 0, INSET_T + BORDER_GAP + INSET_B)
    health:ClearAllPoints()
    health:SetAllPoints(container)

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
    level:ClearAllPoints()
    level:SetPoint("CENTER", border, "RIGHT", LEVEL_X, 0)
    own.skull:ClearAllPoints()
    own.skull:SetPoint("CENTER", border, "RIGHT", LEVEL_X, 0)
    UpdateLevel(unitFrame)

    -- Name centred above the border, sized to its text; debuffs above it.
    local name = unitFrame.name
    if name then
        name:ClearAllPoints()
        name:SetPoint("BOTTOM", border, "TOP", 0, NAME_GAP)
        name:SetWidth(0)
        name:SetJustifyH("CENTER")
        name:SetShadowColor(0, 0, 0, 1)
        name:SetShadowOffset(1, -1)
        local debuffs = ns.Path(unitFrame, "AurasFrame", "DebuffListFrame")
        if debuffs then
            debuffs:ClearAllPoints()
            debuffs:SetPoint("LEFT", border, "LEFT", 0, 0)
            debuffs:SetPoint("BOTTOM", name, "TOP", 0, AURA_GAP)
        end
    end

    -- Cast bar: same fill and border, icon to the left, text inside.
    local cast = castContainer.castBar
    if cast then
        cast:ClearAllPoints()
        cast:SetPoint("TOPLEFT", castContainer, "TOPLEFT", 0, 0)
        cast:SetPoint("BOTTOMRIGHT", castContainer, "BOTTOMRIGHT", CAST_EXTRA, 0)
        ShadedFill(cast)
        -- 1.x yellow cast, green channel: the client picks colour by bar art, which is ours now.
        if cast.channeling then
            cast:SetStatusBarColor(0, 1, 0)
        else
            cast:SetStatusBarColor(1, 0.7, 0)
        end
        local castBorder = CastBorder(cast)
        FadeKeys(cast, CAST_ART)
        if cast.Icon then
            cast.Icon:ClearAllPoints()
            cast.Icon:SetSize(ICON_SIZE, ICON_SIZE)
            cast.Icon:SetPoint("RIGHT", castBorder, "LEFT", -1, 0)
        end
        if cast.Text then
            cast.Text:ClearAllPoints()
            cast.Text:SetPoint("CENTER", cast, "CENTER", 0, 0)
            cast.Text:SetJustifyH("CENTER")
        end
        if cast.CastTargetNameText then cast.CastTargetNameText:SetAlpha(0) end
    end
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

-- Every non-forbidden plate on screen.
local function EachPlate(fn)
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= "table" then return end
    for _, plate in ipairs(plates) do
        local unitFrame = plate and plate.UnitFrame
        if unitFrame and not Forbidden(unitFrame) then fn(unitFrame) end
    end
end

-- 0.2 s sweep recolours plates (no event for a duel, flag or death). Some plates' anchors cannot be read,
-- so all are re-laid each second; evented moves are handled at once.
local SWEEP, RELAY = 0.2, 1
local driver
local held, place = 0, false

-- Sole writer of NP.active; hidden while off, the driver still gets events.
local function SetActive(on)
    NP.active = on
    if driver then
        if on then driver:Show() else driver:Hide() end
    end
end

local function SweepPlate(unitFrame)
    if place or not skinned[unitFrame] then
        SkinPlate(unitFrame)
    else
        NP.ClassColor(unitFrame)
    end
end

local function Sweep()
    if not NP.active then return end
    held = held + SWEEP
    place = held >= RELAY
    if place then held = 0 end
    EachPlate(SweepPlate)
end

local function OnEvent(_, event, unit)
    if not NP.active then return end
    if event == "NAME_PLATE_UNIT_ADDED" then
        local unitFrame = PlateFor(unit)
        if unitFrame then SkinPlate(unitFrame) end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        -- The plate is recycled for another unit.
        local unitFrame = LivePlate(unit)
        if unitFrame then NP.Unpaint(ns.Path(unitFrame, "HealthBarsContainer", "healthBar")) end
    elseif event == "UNIT_FACTION" or event == "UNIT_FLAGS" then
        local unitFrame = LivePlate(unit)
        if unitFrame then NP.ClassColor(unitFrame) end
    elseif event == "UNIT_LEVEL" then
        local unitFrame = LivePlate(unit)
        if unitFrame then UpdateLevel(unitFrame) end
    elseif CAST_EVENTS[event] then
        -- Cast start or stop re-lays only that plate.
        local unitFrame = unit and PlateFor(unit)
        if unitFrame then SkinPlate(unitFrame) end
    else
        EachPlate(SkinPlate)
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
        ns.Sched.OnFrame(driver, { name = "namePlates.sweep", every = SWEEP, fn = Sweep })
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
