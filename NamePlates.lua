local _, ns = ...

-- The 1.x plate, drawn from the old sheet at its own size: a 128x16
-- rounded border with the level in the slot at its right end, a 102x8
-- health bar in the shaded fill inside it, and the name above. A cast
-- bar in the same border sits under it with the spell icon to its left.
-- Blizzard's nameplate unit frame keeps all its logic; after each of its
-- own anchoring passes the pieces are re-laid and its retail art is
-- faded, the rare and elite badge with it, since the old plate had none.
-- Forbidden plates (instanced content on 12.x) are left alone.

local BORDER_W, BORDER_H = 128, 16
local INSET_L, INSET_R, INSET_T, INSET_B = 5, 21, 4, 4
local BAR_W, BAR_H = BORDER_W - INSET_L - INSET_R, BORDER_H - INSET_T - INSET_B
local BORDER_GAP = 2       -- between the health border and the cast border
local NAME_GAP = 2         -- name bottom above the border top
local AURA_GAP = 4         -- debuff row above the name
local LEVEL_X = -10        -- slot center, from the border's right edge
local ICON_SIZE = 14
local CVAR = "nameplateStyle"

local active = false
local skinned = setmetatable({}, { __mode = "k" })

local function Forbidden(frame)
    return not frame or (frame.IsForbidden and frame:IsForbidden())
end

-- The border sheet wrapped around a bar, drawn above its fill.
local function Border(bar)
    local border = ns.OwnTexture(bar, "border", "OVERLAY", 2)
    ns.SetTex(border, "nameplateBorder")
    border:SetTexCoord(0, 1, 0.5, 1)
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", bar, "TOPLEFT", -INSET_L, INSET_T)
    border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", INSET_R, -INSET_B)
    border:Show()
    return border
end

local function ShadedFill(bar)
    local tex = bar.barTexture or (bar.GetStatusBarTexture and bar:GetStatusBarTexture())
    if not tex then return end
    tex:SetAtlas(nil)
    ns.SetTex(tex, "barFill")
    tex:SetTexCoord(0, 1, 0, 1)
end

local function UpdateLevel(unitFrame)
    local own = unitFrame.fcui
    local level, skull = own and own.level, own and own.skull
    if not level or not unitFrame.unit then return end
    local lvl = UnitLevel(unitFrame.unit)
    if lvl == nil or (issecretvalue and issecretvalue(lvl)) then
        level:SetText("")
        skull:Hide()
        return
    end
    if ns.SkullLevel(lvl) then
        level:SetText("")
        skull:Show()
        return
    end
    skull:Hide()
    level:SetText(lvl)
    local color = GetCreatureDifficultyColor and GetCreatureDifficultyColor(lvl)
    if color then level:SetTextColor(color.r, color.g, color.b) else level:SetTextColor(1, 0.82, 0) end
end

-- A player's plate takes their class color while the toggle asks for
-- it; everything else keeps the color the client gives it. Blizzard
-- repaints on every health update, so this runs after that too.
local function ClassColor(unitFrame)
    if not active or not ns.db.classColorPlates then return end
    local health = ns.Path(unitFrame, "HealthBarsContainer", "healthBar")
    local unit = unitFrame.unit or (unitFrame.displayedUnit)
    if not health or not unit then return end
    if not (UnitIsPlayer and UnitIsPlayer(unit)) then return end
    local _, class = UnitClass(unit)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then health:SetStatusBarColor(color.r, color.g, color.b) end
end
ns.NamePlateClassColor = ClassColor

-- Runs after Blizzard's own anchoring pass on the unit frame.
local function Layout(unitFrame)
    if not active or Forbidden(unitFrame) then return end
    local container = unitFrame.HealthBarsContainer
    local health = container and container.healthBar
    local castContainer = unitFrame.CastBarsContainer
    if not health or not castContainer then return end
    unitFrame.fcui = unitFrame.fcui or {}
    local own = unitFrame.fcui

    -- The bars keep Blizzard's bottom-up chain, at the old sizes: the cast
    -- bar at the plate's foot, the health bar a border's gap above it.
    castContainer:ClearAllPoints()
    castContainer:SetSize(BAR_W, BAR_H)
    castContainer:SetPoint("BOTTOM", unitFrame, "BOTTOM", 0, INSET_B)
    container:ClearAllPoints()
    container:SetSize(BAR_W, BAR_H)
    container:SetPoint("BOTTOM", castContainer, "TOP", 0, INSET_T + BORDER_GAP + INSET_B)
    health:ClearAllPoints()
    health:SetAllPoints(container)

    ShadedFill(health)
    ClassColor(unitFrame)
    local border = Border(health)
    for _, key in ipairs({ "bgTexture", "selectedBorder", "deselectedOverlay", "Text", "LeftText", "RightText" }) do
        if health[key] then health[key]:SetAlpha(0) end
    end
    if unitFrame.LevelFrame then ns.Fade(unitFrame.LevelFrame) end
    if unitFrame.PlayerLevelDiffFrame then ns.Fade(unitFrame.PlayerLevelDiffFrame) end
    if unitFrame.ClassificationFrame then ns.Fade(unitFrame.ClassificationFrame) end

    -- Level in the border's slot, a skull when it cannot be told.
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

    -- The name centered above the border, sized to its text.
    local name = unitFrame.name
    if name then
        name:ClearAllPoints()
        name:SetPoint("BOTTOM", border, "TOP", 0, NAME_GAP)
        name:SetWidth(0)
        name:SetJustifyH("CENTER")
        name:SetShadowColor(0, 0, 0, 1)
        name:SetShadowOffset(1, -1)
        -- Debuffs go above the name now that the name is above the bar.
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
        cast:SetAllPoints(castContainer)
        ShadedFill(cast)
        local castBorder = Border(cast)
        if cast.Background then cast.Background:SetAlpha(0) end
        if cast.Border then cast.Border:SetAlpha(0) end
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

-- The plate is laid out from a pass of our own rather than from a hook
-- on the client's. A hook there runs inside the client's own update of
-- the plate, and the rest of that update, which reads the unit's health,
-- is refused once our code has been part of the pass.
local function SkinPlate(unitFrame)
    if not active or Forbidden(unitFrame) then return end
    skinned[unitFrame] = true
    Layout(unitFrame)
end

-- The settings panel's sample plate arrives with a "preview" token the
-- lookup refuses, so a failed lookup means no plate rather than an error.
local function PlateFor(unitToken)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unitToken)
    return ok and plate and plate.UnitFrame or nil
end

local function OnPlateAdded(unitToken)
    if not active then return end
    local unitFrame = PlateFor(unitToken)
    if unitFrame then SkinPlate(unitFrame) end
end

-- Every plate on screen, whatever the client is holding at the time.
local function EachPlate(fn)
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(plates) ~= "table" then return end
    for _, plate in ipairs(plates) do
        local unitFrame = plate and plate.UnitFrame
        if unitFrame and not Forbidden(unitFrame) then fn(unitFrame) end
    end
end

-- The color pass is the quick one; the client repaints a bar on every
-- health change. Laying a plate out again is the slow one, since asking
-- a plate where it sits is a measurement the client refuses on some of
-- them, so the pass cannot tell a moved plate from a placed one and
-- simply places them all on the slow beat. The moves that show are the
-- ones with an event of their own, and those are answered at once.
local SWEEP, RELAY = 0.2, 1
local driver

-- An earlier build switched the game's own nameplate style instead and
-- kept the player's choice; put that choice back if it is still held.
local function RestoreStyleChoice()
    local saved = ns.db.savedNamePlateStyle
    if saved == nil then return end
    ns.db.savedNamePlateStyle = nil
    ns.SetCVar(CVAR, saved)
end

local function Apply()
    active = true
    RestoreStyleChoice()
    if not NamePlateDriverFrame then ns.MissingPiece("NamePlateDriverFrame") return end
    if not driver then
        driver = CreateFrame("Frame")
        for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "UNIT_LEVEL", "PLAYER_TARGET_CHANGED",
            "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED",
            "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START",
            "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED" }) do
            pcall(driver.RegisterEvent, driver, event)
        end
        driver:SetScript("OnEvent", function(_, event, unit)
            if not active then return end
            if event == "NAME_PLATE_UNIT_ADDED" then
                OnPlateAdded(unit)
            elseif event == "UNIT_LEVEL" then
                local unitFrame = unit and PlateFor(unit)
                if unitFrame and not Forbidden(unitFrame) then UpdateLevel(unitFrame) end
            elseif event:find("SPELLCAST", 1, true) then
                -- A cast bar coming or going re-anchors that one plate.
                local unitFrame = unit and PlateFor(unit)
                if unitFrame then SkinPlate(unitFrame) end
            else
                EachPlate(SkinPlate)
            end
        end)
        driver:SetScript("OnUpdate", function(self, elapsed)
            if not active then return end
            self.since = (self.since or 0) + elapsed
            if self.since < SWEEP then return end
            self.since = 0
            self.held = (self.held or 0) + SWEEP
            local place = self.held >= RELAY
            if place then self.held = 0 end
            EachPlate(function(unitFrame)
                if place or not skinned[unitFrame] then
                    SkinPlate(unitFrame)
                else
                    ClassColor(unitFrame)
                end
            end)
        end)
    end
    EachPlate(SkinPlate)
end

local function Restore()
    active = false
    RestoreStyleChoice()
    for unitFrame in pairs(skinned) do
        if unitFrame.fcui then
            for _, region in pairs(unitFrame.fcui) do region:Hide() end
        end
        local health = ns.Path(unitFrame, "HealthBarsContainer", "healthBar")
        local cast = ns.Path(unitFrame, "CastBarsContainer", "castBar")
        for _, bar in pairs({ health, cast }) do
            if bar.fcui then
                for _, tex in pairs(bar.fcui) do tex:Hide() end
            end
        end
    end
    ns.needsReload = true
end

ns.RegisterModule("namePlates", { apply = Apply, restore = Restore })

-- Class colors on the plates are a toggle of their own; flipping it
-- repaints what is on screen, and turning it off asks the client for
-- its own colors back.
local function ColorApply()
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            if plate.UnitFrame then ClassColor(plate.UnitFrame) end
        end
    end
end

local function ColorRestore()
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local unitFrame = plate.UnitFrame
        if unitFrame and type(unitFrame.UpdateHealthColor) == "function" then
            pcall(unitFrame.UpdateHealthColor, unitFrame)
        end
    end
end

ns.RegisterModule("classColorPlates", { apply = ColorApply, restore = ColorRestore })

-- 1.x had no cut-down plates. Retail draws friendly players, friendly
-- NPCs, minions and minor mobs at a reduced size until targeted; this
-- turns that off and remembers the setting for when it is switched back.
local SIMPLIFIED_CVAR = "nameplateSimplifiedTypes"

local function FullPlatesApply()
    if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return end
    local current = C_CVar.GetCVar(SIMPLIFIED_CVAR)
    -- The Forever client answers this setting with an empty string; only
    -- a real non-zero value is worth remembering and clearing.
    local value = tonumber(current)
    if not value or value == 0 then return end
    if ns.db.savedSimplifiedTypes == nil then ns.db.savedSimplifiedTypes = current end
    ns.SetCVar(SIMPLIFIED_CVAR, 0)
end

local function FullPlatesRestore()
    local saved = ns.db.savedSimplifiedTypes
    ns.db.savedSimplifiedTypes = nil
    if tonumber(saved) then ns.SetCVar(SIMPLIFIED_CVAR, saved) end
end

ns.RegisterModule("fullPlates", { apply = FullPlatesApply, restore = FullPlatesRestore })
