local _, ns = ...

-- Gryphon button on the minimap ring, 1.x tracking-button style; its drag angle is saved.

local SIZE = 32
local DEFAULT_ANGLE = 200
local FULL = { 0, 1, 0, 1 }

-- Ring centre is at (20, 19) on its 64px sheet; the face's edge hides under the ring.
local RING_SIZE = 54
local CX, CY = RING_SIZE * 20 / 64, -RING_SIZE * 19 / 64
local FACE = 24

-- 8-value coords: centre (u, v), half span, turned counter-clockwise by degrees.
local function Turned(u, v, half, degrees)
    local c, s = math.cos(math.rad(degrees)) * half, math.sin(math.rad(degrees)) * half
    return { u - c + s, v - s - c, u - c - s, v - s + c, u + c + s, v + s - c, u + c - s, v + s + c }
end

-- The art's gryphon sits low and leans forward: centre on its body, zoom in, stand it upright.
local ICON = { layer = "ARTWORK", coords = Turned(0.578, 0.586, 0.436, 22), w = FACE, h = FACE,
    point = "CENTER", relPoint = "TOPLEFT", x = CX, y = CY }
-- Black disc under it: the zoomed art's own disc no longer reaches the ring everywhere.
local BACK = { layer = "BACKGROUND", w = FACE, h = FACE, point = "CENTER", relPoint = "TOPLEFT", x = CX, y = CY,
    vertex = { 0, 0, 0 } }
local RING = { layer = "OVERLAY", w = RING_SIZE, h = RING_SIZE, point = "TOPLEFT" }
local HL_RING = { coords = FULL, fill = true, add = true, states = { "Highlight" } }
local TIP = { anchor = "ANCHOR_LEFT", text = "ClassicUI Forever", r = 1, g = 1, b = 1, lines = {
    { "Left-click: options", 0.8, 0.8, 0.8 },
    { "Right-click: welcome note", 0.8, 0.8, 0.8 },
    { "Drag to move around the ring", 0.8, 0.8, 0.8 },
} }

local button
local active = false
local placedAngle, placedRadius       -- last placement, to skip no-op moves
local dragX, dragY, dragMX, dragMY, dragScale   -- last cursor and map, to skip idle frames

local function Radius()
    local map = Minimap
    return (map and map:GetWidth() or 140) / 2 + 5
end

-- Only we move this button, so an unchanged angle and radius means no move.
local function Position()
    if not button or not Minimap then return end
    local degrees = ns.db and ns.db.minimapButtonAngle or DEFAULT_ANGLE
    local r = Radius()
    if degrees == placedAngle and r == placedRadius then return end
    placedAngle, placedRadius = degrees, r
    local angle = math.rad(degrees)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    if cx == dragX and cy == dragY and mx == dragMX and my == dragMY and scale == dragScale then return end
    dragX, dragY, dragMX, dragMY, dragScale = cx, cy, mx, my, scale
    cx, cy = cx / scale, cy / scale
    local angle = math.deg(math.atan2(cy - my, cx - mx))
    if angle < 0 then angle = angle + 360 end
    ns.db.minimapButtonAngle = angle
    Position()
end

local function Build()
    local b = CreateFrame("Button", "ForeverClassicUIMinimapButton", Minimap)
    b:SetSize(SIZE, SIZE)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel((Minimap:GetFrameLevel() or 2) + 8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetMovable(true)

    ns.DressNew(b, "portraitMask", BACK)
    -- Round mask first: RoundIcon sets its own crop, which the dress then replaces.
    b.icon = b:CreateTexture()
    ns.RoundIcon(b.icon)
    ns.Dress(b.icon, "gryphonIcon", ICON)
    ns.DressNew(b, "trackingBorder", RING)
    ns.DressStates(b, nil, nil, nil, "zoomHighlight", HL_RING)

    b:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            if ns.ShowWelcome then ns.ShowWelcome() end
        else
            ns.OpenOptions()
        end
    end)
    b:SetScript("OnDragStart", function(self)
        dragX = nil
        self:SetScript("OnUpdate", OnDragUpdate)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        Position()
    end)
    ns.AttachTip(b, TIP)
    return b
end

-- HookMethod dedups per frame and method, so this Layout hook is dropped when Minimap.lua
-- hooked first; the SetSize hook, fired by that Layout, does the repositioning.
local hooked = false
local function Apply()
    active = true
    if not Minimap then return end
    if not button then button = Build() end
    Position()
    button:Show()
    if not hooked then
        hooked = true
        if MinimapCluster then
            ns.HookMethod(MinimapCluster, "Layout", function() if active then Position() end end)
        end
        ns.HookMethod(Minimap, "SetSize", function() if active then Position() end end)
    end
end

local function Restore()
    active = false
    if button then button:Hide() end
end

ns.RegisterModule("minimapButton", { apply = Apply, restore = Restore })
