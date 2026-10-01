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

-- Era rows (its dump): unpicked under the border, faces at the shared spots.
local ERA_STEP = -16      -- next tab's left from this one's right (- overlaps); a row may give its own
local ERA_TAB_PAD = 40    -- tab width: label plus both caps
local eraRows = setmetatable({}, { __mode = "k" })   -- tab -> the tab it follows (true for the first)
local eraSteps = setmetatable({}, { __mode = "k" })  -- tab -> its row's step

-- Label width plus caps: 25 a side, fcuiPad where tabs crowd (social window), Era's on an Era row.
function ns.FitBottomTab(tab)
    LiftTab(tab)
    local text = tab.Text or (tab.GetFontString and tab:GetFontString())
    if not text then return end
    local pad = eraRows[tab] and ERA_TAB_PAD or tab.fcuiPad or 50
    local width = math.ceil(text:GetStringWidth() or 0) + pad
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
local TAB_GLOW_TOP = 4            -- glow: its sheet's top above the tab art's top (+ up)
local TAB_GLOW_BOTTOM = 1         -- glow: its sheet's bottom below the tab art's foot (+ lower)
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

-- Every foot tab row. Faces at their spots; the label at one height, picked or not.
local TAB_PICKED_Y = 1   -- picked face: above the tab's top (+ up; covers the window's foot line)
local TAB_OFF_Y = 2      -- unpicked faces: above the tab's top (+ up; the art's top 2 rows are clear)
local TAB_EXTRA = 0      -- both faces: the plain body under the window's foot lengthened by this (+ longer tabs); Era's 0
local TAB_TEXT_Y = 2    -- label: over the tab's middle, picked or not (+ up); Era's 2
ns.TAB_PICKED_Y, ns.TAB_OFF_Y = TAB_PICKED_Y, TAB_OFF_Y
function ns.TabTextY() return TAB_TEXT_Y end

-- The 32 row art in three: rows 0 to 16 (the opening and body) as drawn, 16 to 20 stretched by TAB_EXTRA, 20 to 32 (the
-- chamfered foot) as drawn. Both faces' sides run straight on rows 8 to 21 (the chamfers start at 22 and 26).
local SLICE_BODY, SLICE_RIM, ROWS = 16, 20, 32
local slices = setmetatable({}, { __mode = "k" })   -- piece -> its body and rim textures

-- piece: a dressed full height face piece hung by its top; u0, u1: its across coords; more: added length. Again after every dress.
function ns.LengthenTabPiece(piece, u0, u1, more)
    if not piece then return end
    local pair = slices[piece]
    if not pair then
        local owner, layer, sub = piece:GetParent(), piece:GetDrawLayer()
        pair = { owner:CreateTexture(nil, layer, nil, sub), owner:CreateTexture(nil, layer, nil, sub) }
        pair[1]:SetPoint("TOPLEFT", piece, "BOTTOMLEFT", 0, 0)
        pair[1]:SetPoint("TOPRIGHT", piece, "BOTTOMRIGHT", 0, 0)
        pair[2]:SetPoint("TOPLEFT", pair[1], "BOTTOMLEFT", 0, 0)
        pair[2]:SetPoint("TOPRIGHT", pair[1], "BOTTOMRIGHT", 0, 0)
        slices[piece] = pair
    end
    piece:SetHeight(SLICE_BODY)
    piece:SetTexCoord(u0, u1, 0, SLICE_BODY / ROWS)
    local file, r, g, b = piece:GetTexture(), piece:GetVertexColor()
    local desat = piece:IsDesaturated()
    local rows = { { SLICE_BODY, SLICE_RIM, SLICE_RIM - SLICE_BODY + TAB_EXTRA + (more or 0) }, { SLICE_RIM, ROWS, ROWS - SLICE_RIM } }
    for i, tex in ipairs(pair) do
        local from, to, h = rows[i][1], rows[i][2], rows[i][3]
        tex:SetTexture(file)
        tex:SetTexCoord(u0, u1, from / ROWS, to / ROWS)
        tex:SetHeight(h)
        tex:SetVertexColor(r, g, b)
        tex:SetDesaturated(desat)
        tex:SetShown(piece:IsShown())
    end
end

-- A piece shown or hidden with its body and rim.
function ns.ShowTabPiece(piece, shown)
    piece:SetShown(shown)
    local pair = slices[piece]
    if pair then
        pair[1]:SetShown(shown)
        pair[2]:SetShown(shown)
    end
end

-- The lowest texture of a piece (its rim once lengthened), for what spans the whole face.
function ns.TabPieceFoot(piece)
    local pair = piece and slices[piece]
    return pair and pair[2] or piece
end

-- The client's six pieces; the middles keep the client's anchors. Both sheets are 128 x 32.
local BOTTOM_TAB = {
    { field = "LeftActive", key = "tabActive", coords = OFF_COORDS[1], w = 20, h = ROWS, horizTile = false,
        point = "TOPLEFT", y = TAB_PICKED_Y },
    { field = "RightActive", key = "tabActive", coords = OFF_COORDS[3], w = 20, h = ROWS, horizTile = false,
        point = "TOPRIGHT", y = TAB_PICKED_Y },
    { field = "MiddleActive", key = "tabActive", coords = OFF_COORDS[2], w = 88, h = ROWS, horizTile = false },
    { field = "Left", key = "tabInactive", coords = OFF_COORDS[1], w = 20, h = ROWS, horizTile = false,
        point = "TOPLEFT", y = TAB_OFF_Y },
    { field = "Right", key = "tabInactive", coords = OFF_COORDS[3], w = 20, h = ROWS, horizTile = false,
        point = "TOPRIGHT", y = TAB_OFF_Y },
    { field = "Middle", key = "tabInactive", coords = OFF_COORDS[2], w = 88, h = ROWS, horizTile = false },
}
local BOTTOM_GLOW = { key = "tabInactive", coords = OFF_COORDS }

local function PickedFace(tab) return tab.LeftActive ~= nil and tab.LeftActive:IsShown() end

-- Over the window's border frame, so the picked face covers its line and opens it; an Era row's unpicked tab under it.
local function OverBorder(tab)
    local parent = tab:GetParent()
    local slice = parent and parent.NineSlice
    if not (slice and slice.GetFrameLevel) then return end
    local level = slice:GetFrameLevel()
    if eraRows[tab] and not PickedFace(tab) then
        ns.SetLevelIf(tab, math.max(1, level - 1))
    else
        ns.SetLevelIf(tab, math.max(tab:GetFrameLevel(), level + 1))
    end
end

local function EraPlace(tab)
    local after = eraRows[tab]
    if not after then return end
    if after ~= true then ns.SetPointOnce(tab, "LEFT", after, "RIGHT", eraSteps[tab] or ERA_STEP, 0) end
    OverBorder(tab)
end

-- tabs: a foot row in order, laid on Era's numbers from here on; step: its overlap when not the vendor's.
function ns.EraTabRow(tabs, step)
    for i, tab in ipairs(tabs) do
        eraRows[tab] = tabs[i - 1] or true
        eraSteps[tab] = step
        ns.FitBottomTab(tab)
        EraPlace(tab)
    end
end

-- Label: one spot, picked or not; the client moves it on select and deselect, so it is set again after.
local function PlaceText(tab)
    local text = tab.Text
    if not text then return end
    ns.SetPointOnce(text, "CENTER", tab, "CENTER", 0, TAB_TEXT_Y)
end
-- The client shows and hides the faces on select and deselect; their body and rim follow.
local FACE_FIELDS = { "LeftActive", "MiddleActive", "RightActive", "Left", "Middle", "Right" }
local function TextAfterClient(tab)
    if not (tab and tab.fcuiTab) then return end
    PlaceText(tab)
    EraPlace(tab)
    for _, field in ipairs(FACE_FIELDS) do
        local piece = tab[field]
        if piece then ns.ShowTabPiece(piece, piece:IsShown()) end
    end
end
ns.HookGlobal("PanelTemplates_SelectTab", TextAfterClient)
ns.HookGlobal("PanelTemplates_DeselectTab", TextAfterClient)

-- The client disables the picked tab (no highlight), so only the inactive face glows.
function ns.SkinBottomTab(tab)
    if not tab or not tab.Left then return end
    ns.DressPieces(tab, BOTTOM_TAB)
    for _, piece in ipairs(BOTTOM_TAB) do
        ns.LengthenTabPiece(tab[piece.field], piece.coords[1], piece.coords[2], piece.key == "tabInactive" and TAB_OFF_Y or TAB_PICKED_Y)
    end
    ns.FadeKeys(tab, ns.KEYS.TAB_GLOW)
    tab.fcuiTab = true
    ns.FitBottomTab(tab)
    OverBorder(tab)
    ns.TabGlow(tab, "glow", BOTTOM_GLOW, tab.Left, tab.Middle, ns.TabPieceFoot(tab.Right))
    PlaceText(tab)
    EraPlace(tab)
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
