local _, ns = ...

-- A small round button on the minimap ring in the old tracking-button
-- style: the gryphon head from the end cap sheet inside the stone ring.
-- Left-click opens the options window; drag it around the ring. Its
-- angle on the ring is remembered.

local SIZE = 32
local ICON_COORDS = { 0.5, 1, 0.18, 0.68 }
local DEFAULT_ANGLE = 200

local button
local active = false

local function Radius()
    local map = Minimap
    return (map and map:GetWidth() or 140) / 2 + 5
end

local function Position()
    if not button or not Minimap then return end
    local angle = math.rad(ns.db and ns.db.minimapButtonAngle or DEFAULT_ANGLE)
    local r = Radius()
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end
ns.PositionMinimapButton = Position

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
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

    local bg = b:CreateTexture(nil, "BACKGROUND")
    ns.SetTex(bg, "minimapBackground")
    bg:SetSize(25, 25)
    bg:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -4)
    bg:SetAlpha(0.6)

    local icon = b:CreateTexture(nil, "ARTWORK")
    ns.SetTex(icon, "endCap")
    icon:SetTexCoord(unpack(ICON_COORDS))
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", b, "TOPLEFT", 6, -6)
    b.icon = icon

    local border = b:CreateTexture(nil, "OVERLAY")
    ns.SetTex(border, "trackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)

    ns.SetButtonTex(b, "Highlight", "zoomHighlight")
    local hl = b:GetHighlightTexture()
    if hl then
        hl:SetTexCoord(0, 1, 0, 1)
        hl:ClearAllPoints()
        hl:SetAllPoints(b)
        hl:SetBlendMode("ADD")
    end

    b:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            if ns.ShowWelcome then ns.ShowWelcome() end
        else
            ns.OpenOptions()
        end
    end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", OnDragUpdate)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        Position()
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("ClassicUI Forever", 1, 1, 1)
        GameTooltip:AddLine("Left-click: options", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: welcome note", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag to move around the ring", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

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
