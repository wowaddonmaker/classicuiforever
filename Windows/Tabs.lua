local _, ns = ...

-- Character-sheet tabs on client windows: along the foot, or on a list round end up.

local P = ns.panels

-- Lift window-anchored tabs to the metal (tab-anchored ones follow). Every fit:
-- the client resets the anchor at times.
local function LiftTab(tab)
    local point, rel, relPoint, x, y = tab:GetPoint(1)
    if not point or rel ~= tab:GetParent() then return end
    if tab.fcuiLiftedY == y then return end
    tab.fcuiLiftedY = (y or 0) + (tonumber(tab.fcuiLift) or P.BOTTOM_LIFT)
    tab:SetPoint(point, rel, relPoint, x or 0, tab.fcuiLiftedY)
end

-- Label width plus caps: 25 a side, or fcuiPad where tabs crowd (social window).
function ns.FitBottomTab(tab)
    LiftTab(tab)
    local text = tab.Text or (tab.GetFontString and tab:GetFontString())
    if not text then return end
    local width = math.ceil(text:GetStringWidth() or 0) + (tab.fcuiPad or 50)
    tab:SetWidth(width)
    if tab.Middle then tab.Middle:SetWidth(width - 40) end
    if tab.MiddleActive then tab.MiddleActive:SetWidth(width - 40) end
end
if type(PanelTemplates_TabResize) == "function" then
    hooksecurefunc("PanelTemplates_TabResize", function(tab) if tab and tab.fcuiTab then ns.FitBottomTab(tab) end end)
end

-- Hover glow as on the character window's tabs: each piece's own art again over it, additive.
local GLOW = { fill = true, blend = "ADD", alpha = 0.35 }

local function Glow(tab, name, piece, key, coords)
    if not piece then return nil end
    return (ns.Dress(ns.OwnTexture(tab, name, "HIGHLIGHT"), key, GLOW, piece, nil, nil, nil, nil, coords))
end

-- face names the set (a two-face tab keeps one per face); spec carries key and coords as for ns.ThreeSlice.
function ns.TabGlow(tab, face, spec, left, middle, right)
    local names, key, c = ns.SliceNames(face), spec.key, spec.coords
    return Glow(tab, names[1], left, key, c[1]), Glow(tab, names[2], middle, key, c[2]), Glow(tab, names[3], right, key, c[3])
end

-- Inactive art: left cap, middle, right cap.
local OFF_COORDS = { { 0, 0.15625, 0, 1 }, { 0.15625, 0.84375, 0, 1 }, { 0.84375, 1, 0, 1 } }

-- The client's six pieces; the middles keep the client's anchors.
local BOTTOM_TAB = {
    { field = "LeftActive", key = "tabActive", coords = { 0, 0.15625, 0, 0.546875 }, w = 20, h = 35, horizTile = false, point = "TOPLEFT" },
    { field = "RightActive", key = "tabActive", coords = { 0.84375, 1, 0, 0.546875 }, w = 20, h = 35, horizTile = false, point = "TOPRIGHT" },
    { field = "MiddleActive", key = "tabActive", coords = { 0.15625, 0.84375, 0, 0.546875 }, w = 88, h = 35, horizTile = false },
    { field = "Left", key = "tabInactive", coords = OFF_COORDS[1], w = 20, h = 32, horizTile = false, point = "TOPLEFT", y = -4 },
    { field = "Right", key = "tabInactive", coords = OFF_COORDS[3], w = 20, h = 32, horizTile = false, point = "TOPRIGHT", y = -4 },
    { field = "Middle", key = "tabInactive", coords = OFF_COORDS[2], w = 88, h = 32, horizTile = false },
}
local BOTTOM_GLOW = { key = "tabInactive", coords = OFF_COORDS }

-- The client disables the picked tab (no highlight), so only the inactive face glows.
function ns.SkinBottomTab(tab)
    if not tab or not tab.Left then return end
    ns.DressPieces(tab, BOTTOM_TAB)
    ns.FadeKeys(tab, ns.KEYS.TAB_GLOW)
    tab.fcuiTab = true
    ns.FitBottomTab(tab)
    ns.TabGlow(tab, "glow", BOTTOM_GLOW, tab.Left, tab.Middle, tab.Right)
end

-- Bottom tab art flipped and foot-anchored: the taller selected tab rises (macro window).
local TOP_ACTIVE = {
    fields = { "LeftActive", "MiddleActive", "RightActive" }, key = "tabActive", cap = 20, height = 35,
    edge = "BOTTOM", middle = "edge", midW = 88, horizTile = false,
    coords = { { 0, 0.15625, 0.546875, 0 }, { 0.15625, 0.84375, 0.546875, 0 }, { 0.84375, 1, 0.546875, 0 } },
}
local TOP_INACTIVE = {
    fields = { "Left", "Middle", "Right" }, key = "tabInactive", cap = 20, height = 32,
    edge = "BOTTOM", middle = "edge", midW = 88, horizTile = false,
    coords = { { 0, 0.15625, 1, 0 }, { 0.15625, 0.84375, 1, 0 }, { 0.84375, 1, 1, 0 } },
}
function ns.SkinTopTab(tab)
    if not tab or not tab.Left then return end
    ns.ThreeSlice(tab, nil, TOP_ACTIVE)
    ns.ThreeSlice(tab, nil, TOP_INACTIVE)
    ns.FadeKeys(tab, ns.KEYS.TAB_GLOW)
    tab.fcuiTab = true
    tab.fcuiPad = tab.fcuiPad or 36
    ns.FitBottomTab(tab)
    ns.TabGlow(tab, "glow", TOP_INACTIVE, tab.Left, tab.Middle, tab.Right)
end
