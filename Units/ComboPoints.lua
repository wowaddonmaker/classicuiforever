local _, ns = ...

-- 1.x combo points: five orbs curving down the right of the target portrait, each glinting as it lights.
-- The client's ComboFrame (eight-orb arc) is re-laid to the 1.13 shape; without one we build our own.
-- Retail's display under the player frame fades either way.

local POINTS = 5
-- Orb centres on the portrait rim, top right down to just above the level badge.
local RADIUS = 39
local ANGLES = { 50, 32, 14, -4, -22 }   -- 18 degree steps: 12px orbs on a 39px ring just touch
local function OrbCentre(index)
    local a = math.rad(ANGLES[index])
    return RADIUS * math.cos(a), RADIUS * math.sin(a)
end
local SHEET = "comboPoint"
local ORB_BG = { layer = "BACKGROUND", w = 12, h = 16, point = "TOPLEFT", coords = { 0, 0.375, 0, 1 } }
local ORB_FILL = { layer = "ARTWORK", w = 8, h = 16, point = "TOPLEFT", x = 2, coords = { 0.375, 0.5625, 0, 1 }, alpha = 0 }
local ORB_GLOW = { layer = "OVERLAY", w = 14, h = 16, point = "TOPLEFT", y = 4, coords = { 0.5625, 1, 0, 1 }, blend = "ADD", alpha = 0 }
local WORLD_EVENTS = { "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORM" }
local POWER_EVENTS = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }

local active = false
local frame
local lastPoints = 0

local function Ring()
    return ns.Path(TargetFrame, "TargetFrameContainer", "Portrait") or TargetFrame
end

-- Pinned to the portrait so the arc follows it.
local function PinOrb(orb, index)
    local x, y = OrbCentre(index)
    orb:ClearAllPoints()
    orb:SetPoint("CENTER", Ring(), "CENTER", x, y)
end

---------------------------------------------------------------- the client's

local function LayoutBlizzard()
    local cf = ComboFrame
    if not cf or not active then return end
    cf:ClearAllPoints()
    cf:SetPoint("CENTER", Ring(), "CENTER", 0, 0)
    -- Five orbs from the client's start index (2 for five-point classes) take the ring; the rest park at centre.
    local first = cf.startComboPointIndex or 2
    for i, point in ipairs(cf.ComboPoints or ns.EMPTY) do
        local slot = i - first + 1
        if slot >= 1 and slot <= POINTS then
            PinOrb(point, slot)
            point:SetAlpha(1)
        else
            point:ClearAllPoints()
            point:SetPoint("CENTER", cf, "CENTER", 0, 0)
            point:SetAlpha(0)
        end
    end
end

local blizzardHooked = false
local function HookBlizzard()
    if blizzardHooked or not ComboFrame then return end
    blizzardHooked = true
    -- Checked first so a missing global is not reported as a missing piece.
    if ComboFrame_ApplyOverrides then ns.HookGlobal("ComboFrame_ApplyOverrides", LayoutBlizzard) end
    if ComboFrame_UpdateMax then ns.HookGlobal("ComboFrame_UpdateMax", LayoutBlizzard) end
    ns.HookScriptOnce(ComboFrame, "OnShow", LayoutBlizzard)
end

---------------------------------------------------------------- our own

local function Orb(parent)
    local orb = CreateFrame("Frame", nil, parent)
    orb:SetSize(12, 12)
    ns.DressNew(orb, SHEET, ORB_BG)
    orb.lit = ns.DressNew(orb, SHEET, ORB_FILL)
    orb.shine = ns.DressNew(orb, SHEET, ORB_GLOW)
    return orb
end

local function Glint(orb)
    -- Highlight fades in, then the shine flashes over it and fades.
    UIFrameFadeIn(orb.lit, 0.4, orb.lit:GetAlpha(), 1)
    UIFrameFade(orb.shine, {
        mode = "IN", timeToFade = 0.3, startAlpha = 0, endAlpha = 1,
        finishedFunc = function() UIFrameFadeOut(orb.shine, 0.4, 1, 0) end,
    })
end

local function Update()
    if not frame or not active then return end
    local max = ns.Safe(UnitPowerMax("player", Enum.PowerType.ComboPoints), 0)
    local points = ns.Safe(UnitPower("player", Enum.PowerType.ComboPoints), 0)
    if max <= 0 or points <= 0 or not UnitExists("target") or not UnitCanAttack("player", "target") then
        frame:Hide()
        for i = 1, POINTS do
            frame.orbs[i].lit:SetAlpha(0)
            frame.orbs[i].shine:SetAlpha(0)
        end
        lastPoints = 0
        return
    end
    if not frame:IsShown() then
        frame:Show()
        UIFrameFadeIn(frame, 0.3, 0, 1)
    end
    for i = 1, POINTS do
        local orb = frame.orbs[i]
        orb:SetShown(i <= max)
        if i <= points then
            if i > lastPoints then Glint(orb) end
        else
            orb.lit:SetAlpha(0)
            orb.shine:SetAlpha(0)
        end
    end
    lastPoints = points
end

local function Build()
    frame = CreateFrame("Frame", nil, TargetFrame)
    frame:SetSize(64, 64)
    frame:SetPoint("CENTER", Ring(), "CENTER", 0, 0)
    frame:SetFrameLevel(TargetFrame:GetFrameLevel() + 5)
    frame.orbs = {}
    for i = 1, POINTS do
        frame.orbs[i] = Orb(frame)
        PinOrb(frame.orbs[i], i)
    end
    frame:Hide()
    ns.RegisterEvents(frame, WORLD_EVENTS)
    ns.RegisterEvents(frame, POWER_EVENTS, "player")
    frame:SetScript("OnEvent", Update)
end

local function Apply()
    active = true
    if not TargetFrame then ns.MissingPiece("TargetFrame") return end
    -- Retail's display under the player frame.
    ns.Fade(ComboPointPlayerFrame)
    ns.Fade(DruidComboPointBarFrame)
    if ComboFrame then
        HookBlizzard()
        LayoutBlizzard()
        if frame then frame:Hide() end
        return
    end
    if not frame then Build() else for i, orb in ipairs(frame.orbs) do PinOrb(orb, i) end end
    Update()
end

local function Restore()
    active = false
    if frame then frame:Hide() end
    ns.Unfade(ComboPointPlayerFrame)
    ns.Unfade(DruidComboPointBarFrame)
    -- The client's arc keeps our anchors until a reload.
    if ComboFrame then ns.needsReload = true end
end

ns.RegisterModule("comboPoints", { apply = Apply, restore = Restore })
