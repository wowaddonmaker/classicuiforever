-- TBC side panel: the arrow widens the sheet with its own art; tabs: stats (StatPanes.lua) and the client's equipment manager, anchored in.
local _, ns = ...

local TAB_ART = "Interface\\PaperDollInfoFrame\\PaperDollSidebarTabs"

-- Doll-art px. EXT: how far the sheet widens (TBC panel:sheet ratio); top band repeats from TOP_CUT, plain inset from LOW_CUT.
local EXT = 214
local TOP_CUT, TOP_H = 320, 74
local LOW_CUT, LOW_SHIFT = 348, 2
-- General sheet's lines sit 2px higher at the top, 1px at the foot: inset drawn in two parts.
local UPPER_SRC, UPPER_AT, UPPER_H = 72, 74, 183
local LOWER_AT, LOWER_H = 257, 184
local PANE_H = 438
-- Inset interior in pane coords (general sheet's border at 340).
local INNER_W, INNER_TOP, INNER_BOTTOM = 340 + LOW_SHIFT + EXT - LOW_CUT, -77, -429
local PAGE_INSET, LIST_BAR = 4, 14
-- Set list: rows from the stat page's inset (the client's view pads them 3) to its list edge, the
-- bar beside them as there; top and foot room are the client's.
local ROW_PAD, BAR_GAP, LIST_TOP, LIST_FOOT = 3, 4, -8, 105
local CARD_ATLAS = "UI-Character-Info-OutfitCard"
local NAME_GAP = 4
-- Our tint covers the client's grey on a disabled stepper, so it dims instead.
local STEP_DIM = 0.5
local ENDS = { "Begin", "Middle", "End" }
-- Tabs sit on the inset's top line, centred as a pair over the list column (both pages' rows run 4..190).
local TABS_Y, TAB_GAP = -40, 4
local LIST_MID = (INNER_W - LIST_BAR) / 2
-- The arrow: in the sheet's bottom strip, under the right column of slots.
local ARROW_SIZE = 26
local ARROW_X, ARROW_Y = 324, -416

local STATS, EQUIPMENT = 1, 2
-- The client's own sidebar tabs: the stats tab is the player's portrait.
local TABS = {
    { name = _G.PAPERDOLL_SIDEBAR_STATS or "Character Stats" },
    { name = _G.PAPERDOLL_EQUIPMENTMANAGER or EQUIPMENT_MANAGER or "Equipment Manager",
        coords = { 0.015625, 0.53125, 0.46875, 0.60546875 } },
}
-- Laid out as the mainline PaperDollSidebarTabTemplate.
local TAB_BG = { set = "raw", layer = "BACKGROUND", tint = true, w = 50, h = 43, point = "BOTTOMLEFT", x = -9, y = -2 }
local TAB_ICON = { set = "raw", layer = "ARTWORK", w = 33, h = 35, point = "BOTTOM", x = 1, y = -2 }
local TAB_PORTRAIT = { layer = "ARTWORK", coords = { 0.109375, 0.890625, 0.09375, 0.90625 }, w = 29, h = 31, point = "BOTTOM", x = 1 }
local TAB_HIDER = { set = "raw", layer = "OVERLAY", coords = { 0.015625, 0.546875, 0.11328125, 0.1875 }, w = 34, h = 19, point = "BOTTOM" }
local TAB_GLOW = { set = "raw", layer = "HIGHLIGHT", coords = { 0.015625, 0.5, 0.1953125, 0.31640625 }, w = 31, h = 31, point = "TOPLEFT", x = 2, y = -3 }
local ARROW_FILES = { set = "file" }
local UNIT_PORTRAIT = { "UNIT_PORTRAIT_UPDATE" }

local active, open, seen, current = false, false, false, STATS
local pane, toggle, tabs, pages, quick
-- The quick equipment button while the panel is shut: the tab's icon, under the resistance column.
local QUICK_SIZE, QUICK_GAP = 24, 4
local savedPoints, popupPoints, listPoints
local Sync

local function Manager()
    return PaperDollFrame and PaperDollFrame.EquipmentManagerPane
end

-- Read by the sheet: how far past its art the open panel reaches.
function ns.EquipmentPaneExtent()
    if active and open and seen then return EXT end
    return 0
end

-- Whether the equipment manager pane is ours to keep up.
function ns.EquipmentPaneOpen()
    return active and open and current == EQUIPMENT
end

-- Whether the manager already hangs from both of our points.
local function OnPane(manager)
    if manager:GetNumPoints() ~= 2 then return false end
    local p1, r1, rp1, x1, y1 = manager:GetPoint(1)
    local p2, r2, rp2, x2, y2 = manager:GetPoint(2)
    if ns.AnySecret(p1, r1, rp1, x1, y1, p2, r2, rp2, x2, y2) then return false end
    return p1 == "TOPLEFT" and r1 == pane and rp1 == "TOPLEFT" and x1 == 0 and y1 == INNER_TOP
        and p2 == "BOTTOMRIGHT" and r2 == pane and rp2 == "TOPLEFT" and x2 == INNER_W and y2 == INNER_BOTTOM
end

local function PointsOf(region)
    local points = {}
    for i = 1, region:GetNumPoints() do points[i] = { region:GetPoint(i) } end
    return points
end

local function PutPoints(region, points)
    region:ClearAllPoints()
    for _, p in ipairs(points) do region:SetPoint(unpack(p)) end
end

------------------------------------------------------------ the set list

-- The client's list is laid for its wider pane: its bar sat over the rows' right end.
local fitted, rowsFit = {}, {}  -- region -> the client's points; rows done

local function OnList(manager, box)
    if box:GetNumPoints() ~= 2 then return false end
    local point, relativeTo, _, x = box:GetPoint(1)
    if ns.AnySecret(point, relativeTo, x) then return false end
    return point == "TOPLEFT" and relativeTo == manager and x == PAGE_INSET - ROW_PAD
end

local function PlaceList(manager)
    local box, bar = manager.ScrollBox, manager.ScrollBar
    if not box or not bar or OnList(manager, box) then return end
    listPoints = listPoints or { box = PointsOf(box), bar = PointsOf(bar) }
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", manager, "TOPLEFT", PAGE_INSET - ROW_PAD, LIST_TOP)
    box:SetPoint("BOTTOMRIGHT", manager, "BOTTOMRIGHT", -(PAGE_INSET + LIST_BAR), LIST_FOOT)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", box, "TOPRIGHT", BAR_GAP, 0)
    bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", BAR_GAP, 0)
end

-- A second anchor: the region then spans to it.
local function Pin(region, relativeTo, point, relativePoint, x)
    if not region or not relativeTo or fitted[region] then return end
    fitted[region] = PointsOf(region)
    region:SetPoint(point, relativeTo, relativePoint, x, 0)
end

-- The card art is a fixed 152 (the client's row is 205 wide): here it ends at the row's edge.
local function PinCard(card)
    if card then Pin(card, card:GetParent(), "TOPRIGHT", "TOPRIGHT", 0) end
end

-- Rows come from the client's pool as sets are added; each is fitted once.
local function FitRows(box)
    for _, row in box:EnumerateFrames() do
        if not rowsFit[row] then
            rowsFit[row] = true
            ns.FadeAtlas(row, CARD_ATLAS, true, PinCard)
            PinCard(row.HighlightBar)
            PinCard(row.SelectedBar)
            Pin(row.text, row.Check, "RIGHT", "LEFT", -NAME_GAP)
        end
    end
end

local function UnfitList(manager)
    for region, points in pairs(fitted) do PutPoints(region, points) end
    wipe(fitted)
    wipe(rowsFit)
    if not listPoints then return end
    PutPoints(manager.ScrollBox, listPoints.box)
    PutPoints(manager.ScrollBar, listPoints.bar)
    listPoints = nil
end

------------------------------------------------------------- bar metal

-- The panel's thin modern bars (this list's, the stat page's): silver, bronze with the theme.
local metal = {}  -- bar -> { on, pieces }

local function MetalPieces(bar)
    local pieces = {}
    local function Add(tex, owner, dims)
        if tex then pieces[#pieces + 1] = { tex = tex, owner = owner, dims = dims } end
    end
    local track = bar.Track
    local thumb = track.Thumb
    if bar.Back then Add(bar.Back.Texture, bar.Back, true) end
    if bar.Forward then Add(bar.Forward.Texture, bar.Forward, true) end
    for _, key in ipairs(ENDS) do
        Add(track[key])
        if thumb then Add(thumb[key], thumb) end
    end
    return pieces
end

local function KeepMetal(bar)
    local state = metal[bar]
    if not state.on then return end
    for _, piece in ipairs(state.pieces) do
        local tex = piece.tex
        -- The client clears desaturation each time a stepper or the thumb turns enabled.
        if not (tex.IsDesaturated and tex:IsDesaturated()) then ns.BronzeTint(tex, nil, true) end
        if piece.dims then
            local alpha = piece.owner:IsEnabled() and 1 or STEP_DIM
            if piece.alpha ~= alpha then
                piece.alpha = alpha
                tex:SetAlpha(alpha)
            end
        end
    end
end

-- The keep runs on host (ours), so only while the bar is up.
function ns.SidePanelBar(bar, host)
    if not bar or not bar.Track or not host then return end
    local state = metal[bar]
    if not state then
        state = { pieces = MetalPieces(bar) }
        metal[bar] = state
        ns.Sched.OnFrame(CreateFrame("Frame", nil, host), { name = "sidePanel.metal", every = 0, fn = function() KeepMetal(bar) end })
    end
    if not state.on then
        state.on = true
        -- Disabled pieces start desaturated, which the keep reads as done: tint all once.
        for _, piece in ipairs(state.pieces) do ns.BronzeTint(piece.tex, nil, true) end
    end
    KeepMetal(bar)
end

-- The client's own bar back as it draws it.
local function Unmetal(bar)
    local state = bar and metal[bar]
    if not state or not state.on then return end
    state.on = false
    for _, piece in ipairs(state.pieces) do
        local tex = piece.tex
        ns.UntintBronze(tex)
        tex:SetAlpha(1)
        piece.alpha = nil
        tex:SetDesaturated(piece.owner ~= nil and not piece.owner:IsEnabled())
    end
end

-------------------------------------------------------------- placing

-- Our anchors while its tab is up, the client's back on Restore; the icon picker opens beside us.
local function Place(manager)
    PlaceList(manager)
    ns.SidePanelBar(manager.ScrollBar, pages[EQUIPMENT])
    if OnPane(manager) then return end
    savedPoints = savedPoints or PointsOf(manager)
    manager:ClearAllPoints()
    manager:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, INNER_TOP)
    manager:SetPoint("BOTTOMRIGHT", pane, "TOPLEFT", INNER_W, INNER_BOTTOM)
    ns.FadeTextures(manager)
    local popup = _G.GearManagerPopupFrame
    if popup and not popupPoints then
        popupPoints = PointsOf(popup)
        ns.SetPointOnce(popup, "TOPLEFT", pane, "TOPRIGHT", 2, -14)
    end
end

local function Unplace(manager)
    if popupPoints and _G.GearManagerPopupFrame then PutPoints(_G.GearManagerPopupFrame, popupPoints) end
    popupPoints = nil
    UnfitList(manager)
    Unmetal(manager.ScrollBar)
    if not savedPoints then return end
    PutPoints(manager, savedPoints)
    ns.FadeTextures(manager, 1)
    savedPoints = nil
end

----------------------------------------------------------------- the art

-- Columns a..384 of a 256+128 sheet pair, rows sy..sy+h, drawn 1:1 at doll x, y.
local function SpanPart(key, base, width, a, sy, h, x, y)
    local from, stop = math.max(a, base), base + width
    if from < stop then
        local tex = pane:CreateTexture(nil, "BACKGROUND")
        ns.SetTex(tex, key)
        tex:SetTexCoord((from - base) / width, 1, sy / 256, (sy + h) / 256)
        tex:SetSize(stop - from, h)
        tex:SetPoint("TOPLEFT", pane, "TOPLEFT", x + from - a - LOW_CUT, -y)
    end
end

local function Span(leftKey, rightKey, a, sy, h, x, y)
    SpanPart(leftKey, 0, 256, a, sy, h, x, y)
    SpanPart(rightKey, 256, 128, a, sy, h, x, y)
end

local function BuildArt()
    Span("charTabTopLeft", "charTabTopRight", TOP_CUT - EXT, 0, TOP_H, TOP_CUT, 0)
    local from = LOW_CUT - EXT - LOW_SHIFT
    Span("charGeneralTopLeft", "charGeneralTopRight", from, UPPER_SRC, UPPER_H, LOW_CUT, UPPER_AT)
    Span("charGeneralBotLeft", "charGeneralBotRight", from, 0, LOWER_H, LOW_CUT, LOWER_AT)
end

-------------------------------------------------------------------- tabs

local function SetTabs()
    for i, tab in ipairs(tabs) do
        local selected = i == current
        tab.bg:SetTexCoord(0.015625, 0.796875, selected and 0.7890625 or 0.61328125, selected and 0.95703125 or 0.78125)
        tab.hider:SetShown(not selected)
        tab.glow:SetShown(not selected)
    end
end

local function Pick(index)
    if index == current then return end
    current = index
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    Sync()
end

local function TabName(self) return TABS[self.index].name end
local TAB_TIP = { text = TabName, r = 1, g = 1, b = 1 }

local function Portrait(icon)
    SetPortraitTexture(icon, "player")
end

local function PortraitEvent(self) Portrait(self.icon) end

local function Tab(index)
    local tab = CreateFrame("Button", nil, pane)
    tab:SetSize(33, 35)
    tab.index = index
    tab.bg = ns.DressNew(tab, TAB_ART, TAB_BG)
    local coords = TABS[index].coords
    if coords then
        tab.icon = ns.DressNew(tab, TAB_ART, TAB_ICON, nil, nil, nil, nil, nil, coords)
    else
        tab.icon = ns.DressNew(tab, nil, TAB_PORTRAIT)
        Portrait(tab.icon)
        tab:RegisterEvent("PORTRAITS_UPDATED")
        ns.RegisterEvents(tab, UNIT_PORTRAIT, "player")
        tab:SetScript("OnEvent", PortraitEvent)
    end
    tab.hider = ns.DressNew(tab, TAB_ART, TAB_HIDER)
    tab.glow = ns.DressNew(tab, TAB_ART, TAB_GLOW)
    tab:SetScript("OnClick", function() Pick(index) end)
    ns.AttachTip(tab, TAB_TIP)
    return tab
end

--------------------------------------------------------------- the panel

Sync = function()
    if not pane then return end
    local shown = active and open
    pane:SetShown(shown)
    for i, page in ipairs(pages) do page:SetShown(shown and i == current) end
    local manager = Manager()
    if manager then
        if shown and current == EQUIPMENT then
            Place(manager)
            -- The side-pane pass faded it while its tab was down.
            ns.KeepSidePane(manager)
            if not manager:IsShown() then manager:Show() end
        elseif manager:IsShown() and (active or savedPoints) then
            manager:Hide()
        end
    end
    ns.PanelToggleFace(toggle, open, ARROW_FILES)
    if quick then quick:SetShown(active and not open) end
    if shown then SetTabs() end
end

local function SetOpen(state)
    open = state and true or false
    Sync()
    PlaySound(open and SOUNDKIT.IG_CHARACTER_INFO_OPEN or SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    ns.SignalSheetLaid()
end

local function ArrowText()
    if open then return _G.CHARACTER_FRAME_HIDE_DETAILS_TOOLTIP or "Hide Character Details" end
    return _G.CHARACTER_FRAME_SHOW_DETAILS_TOOLTIP or "Show Character Details"
end
local ARROW_TIP = { text = ArrowText }

local function ToggleClick(self)
    SetOpen(not open)
    if GameTooltip:GetOwner() == self then ns.ShowTip(self) end
end

local function QuickClick()
    current = EQUIPMENT
    SetOpen(true)
end
local QUICK_TIP = { text = TABS[EQUIPMENT].name, r = 1, g = 1, b = 1 }

-- Under the resistance column when there is one (Forever), else where it would stand.
local function BuildQuick(level)
    quick = CreateFrame("Button", "ForeverClassicUIEquipmentQuick", PaperDollFrame)
    quick:SetSize(QUICK_SIZE, QUICK_SIZE)
    local rows = ns.sheet.resistances
    local last = rows and rows[#rows]
    if last and last:GetParent():IsShown() then
        quick:SetPoint("TOP", last, "BOTTOM", 0, -QUICK_GAP)
    else
        quick:SetPoint("TOPRIGHT", PaperDollFrame, "TOPLEFT", 297, -77)
    end
    quick:SetFrameLevel(level)
    local icon = quick:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(TAB_ART)
    icon:SetTexCoord(unpack(TABS[EQUIPMENT].coords))
    icon:SetAllPoints()
    quick:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    quick:SetScript("OnClick", QuickClick)
    ns.AttachTip(quick, QUICK_TIP)
end

-- The sheet's close button and title move out with the panel.
local function Seen(state)
    seen = state
    ns.PlaceSheetChrome()
end

-- The client hides its sidebars on its own (doll show and more); reshow the manager that frame.
local function EquipmentWatch()
    local manager = Manager()
    if not manager then return end
    if not manager:IsShown() then Sync() end
    if listPoints then FitRows(manager.ScrollBox) end
end

local function Build()
    if pane or not PaperDollFrame or not CharacterFrame then return end
    pane = CreateFrame("Frame", "ForeverClassicUIEquipmentPane", PaperDollFrame)
    pane:SetSize(EXT + 3, PANE_H)
    pane:SetPoint("TOPLEFT", PaperDollFrame, "TOPLEFT", LOW_CUT, 0)
    -- Over the doll's art, level with the manager pane, whose lists and buttons stand above it.
    pane:SetFrameLevel(PaperDollFrame:GetFrameLevel() + 1)
    -- Only the art past the sheet takes the mouse, not the air above it.
    pane:EnableMouse(true)
    pane:SetHitRectInsets(0, 1, 14, 2)
    pane:Hide()
    BuildArt()

    tabs = { Tab(STATS), Tab(EQUIPMENT) }
    tabs[STATS]:SetPoint("TOPRIGHT", pane, "TOPLEFT", LIST_MID - TAB_GAP / 2, TABS_Y)
    tabs[EQUIPMENT]:SetPoint("LEFT", tabs[STATS], "RIGHT", TAB_GAP, 0)

    pages = { ns.StatList(pane), CreateFrame("Frame", nil, pane) }
    for _, page in ipairs(pages) do
        page:SetPoint("TOPLEFT", pane, "TOPLEFT", PAGE_INSET, INNER_TOP - 3)
        page:SetPoint("BOTTOMRIGHT", pane, "TOPLEFT", INNER_W - PAGE_INSET, INNER_BOTTOM + 3)
        page:Hide()
    end
    ns.Sched.OnFrame(pages[EQUIPMENT], { name = "equipment.watch", every = 0, fn = EquipmentWatch })
    pane:SetScript("OnShow", function()
        Portrait(tabs[STATS].icon)
        SetTabs()
        Seen(true)
    end)
    pane:SetScript("OnHide", function() Seen(false) end)

    local over = CharacterModelScene and CharacterModelScene:GetFrameLevel() or PaperDollFrame:GetFrameLevel()
    toggle = ns.PanelToggle(PaperDollFrame, "ForeverClassicUIEquipmentToggle", ARROW_SIZE, "CENTER", PaperDollFrame,
        "TOPLEFT", ARROW_X, ARROW_Y, over + 10, ToggleClick, ARROW_TIP)
    ns.PanelToggleFace(toggle, open, ARROW_FILES)
    BuildQuick(over + 10)
end

function ns.EquipmentPaneApply()
    active = true
    Build()
    if toggle then toggle:Show() end
    Sync()
end

function ns.EquipmentPaneRestore()
    active = false
    local manager = Manager()
    if pane then pane:Hide() end
    if toggle then toggle:Hide() end
    if quick then quick:Hide() end
    if manager then
        if manager:IsShown() and savedPoints then manager:Hide() end
        Unplace(manager)
    end
end
