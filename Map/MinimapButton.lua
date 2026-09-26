local _, ns = ...

-- Buttons on the minimap ring, 1.x tracking-button style, dragged round it with their angle saved: our options button
-- (gryphon) here, the addon button collector in MinimapCollector.lua.

local SIZE = 32
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
local GRYPHON = { layer = "ARTWORK", coords = Turned(0.578, 0.586, 0.436, 22), w = FACE, h = FACE,
    point = "CENTER", relPoint = "TOPLEFT", x = CX, y = CY }
-- An icon file's face, cropped past its own border.
local ICON_FACE = { layer = "ARTWORK", coords = { 0.08, 0.92, 0.08, 0.92 }, w = FACE, h = FACE,
    point = "CENTER", relPoint = "TOPLEFT", x = CX, y = CY }
ns.RING_ICON_FACE = ICON_FACE
-- Black disc under it: the zoomed art's own disc no longer reaches the ring everywhere.
local BACK = { layer = "BACKGROUND", w = FACE, h = FACE, point = "CENTER", relPoint = "TOPLEFT", x = CX, y = CY,
    vertex = { 0, 0, 0 } }
local RING = { layer = "OVERLAY", w = RING_SIZE, h = RING_SIZE, point = "TOPLEFT" }
local HL_RING = { coords = FULL, fill = true, add = true, states = { "Highlight" } }

local rings = {}

local function Radius()
    local map = Minimap
    return (map and map:GetWidth() or 140) / 2 + 5
end

-- Only we move these buttons, so an unchanged angle and radius means no move.
-- Not while collected into the addon button bag (another parent).
local function Position(ring)
    local button = ring.button
    if not button or not Minimap or button:GetParent() ~= Minimap then return end
    local degrees = ns.db and ns.db[ring.angleKey] or ring.angle
    local r = Radius()
    if degrees == ring.placedAngle and r == ring.placedRadius then return end
    ring.placedAngle, ring.placedRadius = degrees, r
    local angle = math.rad(degrees)
    ns.SetPointOnce(button, "CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function PositionAll()
    for i = 1, #rings do
        if rings[i].active then Position(rings[i]) end
    end
end

-- Last cursor and map per ring, to skip idle frames.
local function OnDragUpdate(job)
    local ring = job.ring
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    if cx == ring.dragX and cy == ring.dragY and mx == ring.dragMX and my == ring.dragMY and scale == ring.dragScale then return end
    ring.dragX, ring.dragY, ring.dragMX, ring.dragMY, ring.dragScale = cx, cy, mx, my, scale
    cx, cy = cx / scale, cy / scale
    local angle = math.deg(math.atan2(cy - my, cx - mx))
    if angle < 0 then angle = angle + 360 end
    ns.db[ring.angleKey] = angle
    Position(ring)
end

-- HookMethod dedups per frame and method, so this Layout hook is dropped when Minimap.lua
-- hooked first; the SetSize hook, fired by that Layout, does the repositioning.
local hooked = false
local function HookMap()
    if hooked then return end
    hooked = true
    if MinimapCluster then ns.HookMethod(MinimapCluster, "Layout", PositionAll) end
    ns.HookMethod(Minimap, "SetSize", PositionAll)
end

local function Build(ring)
    local b = CreateFrame("Button", ring.name, Minimap)
    b:SetSize(SIZE, SIZE)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel((Minimap:GetFrameLevel() or 2) + 8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    -- Pure child watcher, asleep until a drag starts.
    local dragJob = ns.Sched.OnFrame(CreateFrame("Frame", nil, b),
        { name = ring.name .. ".drag", every = 0, awake = false, fn = OnDragUpdate })
    dragJob.ring = ring
    b:SetMovable(true)
    ns.DressNew(b, "portraitMask", BACK)
    -- Round mask first: RoundIcon sets its own crop, which the dress then replaces.
    b.icon = b:CreateTexture()
    ns.RoundIcon(b.icon)
    ring.face(b.icon)
    ns.DressNew(b, "trackingBorder", RING)
    ns.DressStates(b, nil, nil, nil, "zoomHighlight", HL_RING)
    b:SetScript("OnClick", ring.onClick)
    b:SetScript("OnDragStart", function()
        ring.dragX = nil
        dragJob:Wake()
    end)
    b:SetScript("OnDragStop", function()
        dragJob:Sleep()
        Position(ring)
    end)
    ns.AttachTip(b, ring.tip)
    return b
end

-- spec: { name, angleKey, angle (default degrees), face(texture), onClick(button, mouse), tip }; returns show and hide.
function ns.RingButton(spec)
    rings[#rings + 1] = spec
    local function Show()
        spec.active = true
        if not Minimap then return end
        spec.button = spec.button or Build(spec)
        Position(spec)
        spec.button:Show()
        HookMap()
    end
    local function Hide()
        spec.active = false
        if spec.button then spec.button:Hide() end
    end
    return Show, Hide
end

local ShowOptions, HideOptions = ns.RingButton({
    name = "ForeverClassicUIMinimapButton",
    angleKey = "minimapButtonAngle",
    angle = 200,
    face = function(icon) ns.Dress(icon, "gryphonIcon", GRYPHON) end,
    onClick = function(_, mouse)
        if mouse == "RightButton" then
            if ns.ShowWelcome then ns.ShowWelcome() end
        else
            ns.OpenOptions()
        end
    end,
    tip = { anchor = "ANCHOR_LEFT", text = "ClassicUI Forever", r = 1, g = 1, b = 1, lines = {
        { "Left-click: options", 0.8, 0.8, 0.8 },
        { "Right-click: welcome note", 0.8, 0.8, 0.8 },
        { "Drag to move around the ring", 0.8, 0.8, 0.8 },
    } },
})

ns.RegisterModule("minimapButton", { apply = ShowOptions, restore = HideOptions })
