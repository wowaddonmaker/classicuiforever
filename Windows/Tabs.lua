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

-- Hover glow: 1.x's light blue tab sheet (128 x 32; lit body columns 14 to 115, rows 5 to 24), additive, cut across
-- to its lit body and drawn over the drawn tab's cap pieces by these numbers. A flipped (foot-anchored) face flips it.
local TAB_GLOW_INSET = 11         -- glow: in from the drawn tab's left and right ends (+ narrower)
local TAB_GLOW_TOP = 8            -- glow: its sheet's top above the tab art's top (+ up)
local TAB_GLOW_BOTTOM = 3         -- glow: its sheet's bottom below the tab art's foot (+ lower)
local TAB_GLOW_SHEET_LEFT = 14    -- glow: first sheet column drawn, of 128 (+ cuts more off the left)
local TAB_GLOW_SHEET_RIGHT = 115  -- glow: last sheet column drawn, of 128 (+ shows more of the right)

local function Glow(tab, name, flipped, left, right)
    local tex = ns.OwnTexture(tab, name, "HIGHLIGHT")
    ns.SetTex(tex, "tabHighlight")
    tex:SetBlendMode("ADD")
    tex:SetTexCoord(TAB_GLOW_SHEET_LEFT / 128, TAB_GLOW_SHEET_RIGHT / 128, flipped and 1 or 0, flipped and 0 or 1)
    tex:ClearAllPoints()
    if flipped then
        tex:SetPoint("TOPLEFT", left or tab, "TOPLEFT", TAB_GLOW_INSET, TAB_GLOW_BOTTOM)
        tex:SetPoint("BOTTOMRIGHT", right or tab, "BOTTOMRIGHT", -TAB_GLOW_INSET, -TAB_GLOW_TOP)
    else
        tex:SetPoint("TOPLEFT", left or tab, "TOPLEFT", TAB_GLOW_INSET, TAB_GLOW_TOP)
        tex:SetPoint("BOTTOMRIGHT", right or tab, "BOTTOMRIGHT", -TAB_GLOW_INSET, -TAB_GLOW_BOTTOM)
    end
    return tex
end

-- face names the texture (a two-face tab keeps one per face); a spec with edge "BOTTOM" is a flipped face; left and
-- right are that face's cap pieces, which the glow spans.
function ns.TabGlow(tab, face, spec, left, _, right)
    return Glow(tab, face, spec ~= nil and spec.edge == "BOTTOM", left, right)
end

-- Inactive art: left cap, middle, right cap.
local OFF_COORDS = { { 0, 0.15625, 0, 1 }, { 0.15625, 0.84375, 0, 1 }, { 0.84375, 1, 0, 1 } }

-- The client's six pieces; the middles keep the client's anchors. Both sheets are 128 x 32; the picked face stands
-- 4 higher than the other and opens the window's foot, as 1.x's tabs did.
local BOTTOM_TAB = {
    { field = "LeftActive", key = "tabActive", coords = OFF_COORDS[1], w = 20, h = 32, horizTile = false, point = "TOPLEFT" },
    { field = "RightActive", key = "tabActive", coords = OFF_COORDS[3], w = 20, h = 32, horizTile = false, point = "TOPRIGHT" },
    { field = "MiddleActive", key = "tabActive", coords = OFF_COORDS[2], w = 88, h = 32, horizTile = false },
    { field = "Left", key = "tabInactive", coords = OFF_COORDS[1], w = 20, h = 32, horizTile = false, point = "TOPLEFT", y = -4 },
    { field = "Right", key = "tabInactive", coords = OFF_COORDS[3], w = 20, h = 32, horizTile = false, point = "TOPRIGHT", y = -4 },
    { field = "Middle", key = "tabInactive", coords = OFF_COORDS[2], w = 88, h = 32, horizTile = false },
}
local BOTTOM_GLOW = { key = "tabInactive", coords = OFF_COORDS }

-- Over the window's border frame, so the picked face covers its line and opens it.
local function OverBorder(tab)
    local parent = tab:GetParent()
    local slice = parent and parent.NineSlice
    if slice and slice.GetFrameLevel then ns.SetLevelIf(tab, math.max(tab:GetFrameLevel(), slice:GetFrameLevel() + 1)) end
end

-- The client disables the picked tab (no highlight), so only the inactive face glows.
function ns.SkinBottomTab(tab)
    if not tab or not tab.Left then return end
    ns.DressPieces(tab, BOTTOM_TAB)
    ns.FadeKeys(tab, ns.KEYS.TAB_GLOW)
    tab.fcuiTab = true
    ns.FitBottomTab(tab)
    OverBorder(tab)
    ns.TabGlow(tab, "glow", BOTTOM_GLOW, tab.Left, tab.Middle, tab.Right)
end

-- Bottom tab art flipped and foot-anchored: the taller selected tab rises (macro window).
local TOP_ACTIVE = {
    fields = { "LeftActive", "MiddleActive", "RightActive" }, key = "tabActive", cap = 20, height = 32,
    edge = "BOTTOM", middle = "edge", midW = 88, horizTile = false,
    coords = { { 0, 0.15625, 1, 0 }, { 0.15625, 0.84375, 1, 0 }, { 0.84375, 1, 1, 0 } },
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
    OverBorder(tab)
    ns.TabGlow(tab, "glow", TOP_INACTIVE, tab.Left, tab.Middle, tab.Right)
end
