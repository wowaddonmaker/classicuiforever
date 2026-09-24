local _, ns = ...

-- Plate colours and options: class colours, full-size plates, old nameplate style clean-up.

local NP = ns.NP
local Dress, IsSecret = ns.Dress, ns.IsSecret

local BAR_FILL = { coords = { 0, 1, 0, 1 } }
-- Game setting: class colours on enemy plates.
local ENEMY_CLASS_CVAR = "nameplateShowClassColor"
local STYLE_CVAR = "nameplateStyle"
local SIMPLIFIED_CVAR = "nameplateSimplifiedTypes"

-- Colour on our own fill pinned over the client's: its repaint can land after ours in the same frame.
local function Paint(health, r, g, b)
    local tex = health.barTexture or (health.GetStatusBarTexture and health:GetStatusBarTexture())
    if not tex then return end
    local fill = ns.OwnTexture(health, "fill", "ARTWORK", 0)
    if fill.fcuiPinnedTo ~= tex then
        fill.fcuiPinnedTo = tex
        Dress(fill, "barFill", BAR_FILL)
        -- Ours takes the client fill's draw step and it drops one: one above would tie with the heal absorb. Saved for restore.
        if not fill.fcuiLayer then
            local layer, sub = tex:GetDrawLayer()
            fill.fcuiLayer, fill.fcuiSub = layer or "ARTWORK", sub or 0
        end
        tex:SetDrawLayer(fill.fcuiLayer, math.max(fill.fcuiSub - 1, -8))
        fill:SetDrawLayer(fill.fcuiLayer, fill.fcuiSub)
        fill:ClearAllPoints()
        fill:SetPoint("TOPLEFT", tex, "TOPLEFT", 0, 0)
        fill:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", 0, 0)
    end
    fill:SetVertexColor(r, g, b)
    fill:Show()
end

-- Show the client's own fill again.
function NP.Unpaint(health)
    local fill = health and health.fcui and health.fcui.fill
    if fill then fill:Hide() end
end

-- Class colour, or nothing while the class is secret (dungeons).
local function ClassRGB(unit)
    local _, class = UnitClass(unit)
    if not class or IsSecret(class) then return end
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then return color.r, color.g, color.b end
end

-- Our colour for a player plate, or nothing to keep the client's.
local function WantedColor(unit)
    local isPlayer = UnitIsPlayer and UnitIsPlayer(unit)
    if IsSecret(isPlayer) then return end
    if not isPlayer then return end
    -- A corpse's fill may be hidden rather than shrunk; ours, pinned to it, would stick at its last width.
    local isDead = _G["UnitIsDead"]
    local dead = isDead and isDead(unit)
    if IsSecret(dead) then dead = false end
    if dead then return end
    if ns.db.classColorPlates then return ClassRGB(unit) end
    -- 1.x friendly players were plain blue (the client's pale blue looks lilac on the old fill); secret: client's colour.
    local friendly = UnitIsFriend and UnitIsFriend("player", unit)
    if IsSecret(friendly) then return end
    if not friendly then return end
    -- Attackable friend (duel): enemy colour, the class colour if the game's enemy class colours are on, else red.
    local foe = UnitCanAttack("player", unit)
    if IsSecret(foe) then foe = false end
    if foe then
        local r, g, b
        if ns.GetCVarBool(ENEMY_CLASS_CVAR) then
            r, g, b = ClassRGB(unit)
        end
        if r then return r, g, b end
        return 1, 0, 0
    end
    -- 1.x selection colour: blue, green when PvP flagged (like a flagged friendly guard).
    local flagged = UnitIsPVP and UnitIsPVP(unit)
    if IsSecret(flagged) then flagged = false end
    if flagged then return 0, 1, 0 end
    return 0, 0, 1
end

function NP.ClassColor(unitFrame)
    if not NP.active then return end
    local health = ns.Path(unitFrame, "HealthBarsContainer", "healthBar")
    if not health then return end
    local unit = unitFrame.unit or (unitFrame.displayedUnit)
    local r, g, b
    if unit then r, g, b = WantedColor(unit) end
    if r then Paint(health, r, g, b) else NP.Unpaint(health) end
end

-- An earlier build changed nameplateStyle and saved the player's value: restore it if still held.
function NP.RestoreStyleChoice()
    local saved = ns.db.savedNamePlateStyle
    if saved == nil then return end
    ns.db.savedNamePlateStyle = nil
    ns.SetCVar(STYLE_CVAR, saved)
end

local function RestoreColor(unitFrame)
    if type(unitFrame.UpdateHealthColor) == "function" then pcall(unitFrame.UpdateHealthColor, unitFrame) end
end

-- Own toggle: on repaints the visible plates, off asks the client for its colours back; forbidden plates too.
local function ColorApply()
    NP.EachPlate(NP.ClassColor, true)
end

local function ColorRestore()
    NP.EachPlate(RestoreColor, true)
end

ns.RegisterModule("classColorPlates", { apply = ColorApply, restore = ColorRestore })

-- 1.x had no simplified plates (friendlies, minions, minor mobs small until targeted): off, value saved.
local function FullPlatesApply()
    if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return end
    local current = ns.GetCVar(SIMPLIFIED_CVAR)
    -- Forever answers an empty string: only save and clear a real non-zero value.
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
