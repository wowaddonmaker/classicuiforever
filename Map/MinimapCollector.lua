local _, ns = ...

-- Addon button collector (minimapCollector): other addons' minimap buttons (LibDBIcon's, and named map buttons with
-- "minimap" in the name) moved into a pop-out grid behind one ring button, and handed back where they were as it turns off.

-- PAD clears the dialog border.
local COLS, CELL, PAD = 5, 34, 16
local BAG_ICON = "Interface\\Icons\\INV_Misc_Bag_08"
-- Named map buttons that are no addon's (ours join by name below).
local NOT_ADDONS = { ExpansionLandingPageMinimapButton = true, GarrisonLandingPageMinimapButton = true,
    ForeverClassicUIMinimapButton = true, ForeverClassicUIMinimapCollector = true }
local OURS = "ForeverClassicUIMinimapButton"
-- Over the pop-out's backing, which is a frame at the pop-out's own level.
local ABOVE_BACKING = 5

local collected = {}   -- button -> { parent, points, lib name } it had
local order = {}       -- collected buttons in grid order
local popout
local active = false

local function DBIcon()
    return LibStub and LibStub("LibDBIcon-1.0", true)
end

-- Into the pop-out; again whenever something (its addon, a refresh) pulled it back out.
local function Pocket(button)
    -- Their drag pulls a button back round the map.
    button:RegisterForDrag()
    button:SetParent(popout)
    button:SetFrameStrata(popout:GetFrameStrata())
    button:SetFrameLevel(popout:GetFrameLevel() + ABOVE_BACKING)
    -- LibDBIcon fades show-on-hover buttons as the mouse leaves the map, which the pop-out is not: off while collected.
    button.showOnMouseover = false
    if button.fadeOut then button.fadeOut:Stop() end
    ns.SetAlphaIf(button, 1)
end

local function Take(button, libName)
    if not button then return end
    if collected[button] then
        if button:GetParent() ~= popout then Pocket(button) end
        return
    end
    local record = { parent = button:GetParent(), lib = libName, points = {}, strata = button:GetFrameStrata(),
        level = button:GetFrameLevel(), mouseover = button.showOnMouseover }
    for i = 1, button:GetNumPoints() do record.points[i] = { button:GetPoint(i) } end
    collected[button] = record
    order[#order + 1] = button
    Pocket(button)
end

-- The minimap's own pass leaves these alone (it refreshes LibDBIcon's onto its ring).
function ns.MinimapCollected(button)
    return active and button ~= nil and collected[button] ~= nil
end

local function TakeNamed(child)
    local name = child.GetName and child:GetName()
    if not name or NOT_ADDONS[name] or name:find("^[Mm]ini[Mm]ap") or not name:lower():find("minimap", 1, true) then return end
    if child:IsObjectType("Button") and child:IsShown() then Take(child) end
end

local function Scan()
    local lib = DBIcon()
    if lib and lib.GetButtonList and lib.GetMinimapButton then
        for _, name in ipairs(lib:GetButtonList()) do
            local button = lib:GetMinimapButton(name)
            if button and not (button.db and button.db.hide) then Take(button, name) end
        end
    end
    if Minimap then ns.EachChild(Minimap, TakeNamed) end
    local ours = _G[OURS]
    if ours and ours:IsShown() then Take(ours) end
end

-- Shown buttons only: an addon may hide its own.
local function Layout()
    local shown = 0
    for _, button in ipairs(order) do
        if button:IsShown() then
            local col, row = shown % COLS, math.floor(shown / COLS)
            ns.SetPointOnce(button, "CENTER", popout, "TOPLEFT", PAD + (col + 0.5) * CELL, -(PAD + (row + 0.5) * CELL))
            ns.SetAlphaIf(button, 1)
            shown = shown + 1
        end
    end
    local cols, rows = math.max(1, math.min(COLS, shown)), math.max(1, math.ceil(shown / COLS))
    popout:SetSize(math.max(cols * CELL + PAD * 2, shown == 0 and 150 or 0), rows * CELL + PAD * 2)
    popout.empty:SetShown(shown == 0)
end

local function Popout()
    if popout then return popout end
    popout = CreateFrame("Frame", "ForeverClassicUIMinimapBag", UIParent)
    popout:SetFrameStrata("HIGH")
    popout:SetClampedToScreen(true)
    ns.DialogBacking(popout)
    popout.empty = popout:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    popout.empty:SetPoint("CENTER")
    popout.empty:SetText("No addon buttons")
    popout:Hide()
    ns.CloseOnEscape(popout)
    return popout
end

local function Toggle(ringButton)
    if popout:IsShown() then
        popout:Hide()
        return
    end
    Scan()
    Layout()
    ns.SetPointOnce(popout, "TOPRIGHT", ringButton, "BOTTOMLEFT", 6, 6)
    popout:Show()
end

local ShowRing, HideRing = ns.RingButton({
    name = "ForeverClassicUIMinimapCollector",
    angleKey = "minimapCollectorAngle",
    angle = 160,
    face = function(icon)
        icon:SetTexture(BAG_ICON)
        ns.Dress(icon, nil, ns.RING_ICON_FACE)
    end,
    onClick = function(self) Toggle(self) end,
    tip = { anchor = "ANCHOR_LEFT", text = "Addon buttons", r = 1, g = 1, b = 1, lines = {
        { "Left-click: the other addons' minimap buttons", 0.8, 0.8, 0.8 },
        { "Drag to move around the ring", 0.8, 0.8, 0.8 },
    } },
})

-- Every button back on its parent and points; LibDBIcon puts its own back in place.
local function Release()
    local lib = DBIcon()
    for i = #order, 1, -1 do
        local button = order[i]
        local record = collected[button]
        button:SetParent(record.parent)
        button:SetFrameStrata(record.strata)
        button:SetFrameLevel(record.level)
        button:ClearAllPoints()
        for _, point in ipairs(record.points) do button:SetPoint(unpack(point)) end
        button:RegisterForDrag("LeftButton")
        button.showOnMouseover = record.mouseover
        if record.lib and lib and lib.Refresh then pcall(lib.Refresh, lib, record.lib) end
        collected[button], order[i] = nil, nil
    end
end

-- A button made later joins at once (LibDBIcon says so); others on the next opening.
local listener
local function Listen()
    local lib = DBIcon()
    if listener or not (lib and lib.RegisterCallback) then return end
    listener = {}
    lib.RegisterCallback(listener, "LibDBIcon_IconCreated", function(_, button, name)
        if not active then return end
        Take(button, name)
        if popout:IsShown() then Layout() end
    end)
end

-- Every pass calls this: the sweep only as it turns on (and on each opening).
local function Apply()
    Popout()
    if not active then
        active = true
        Scan()
        Listen()
    end
    ShowRing()
end

local function Restore()
    if not active then return end
    active = false
    popout:Hide()
    Release()
    HideRing()
end

ns.RegisterModule("minimapCollector", { apply = Apply, restore = Restore })
