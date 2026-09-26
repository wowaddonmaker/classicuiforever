-- TBC side panel: the arrow widens the sheet with its own art; tabs: stats (StatPanes.lua) and the client's equipment manager, anchored in.
local _, ns = ...

local TAB_ART = "Interface\\PaperDollInfoFrame\\PaperDollSidebarTabs"

-- Doll-art px. SIDE_PANEL_WIDTH: how far the sheet widens (TBC panel:sheet ratio); top band repeats from TOP_CUT, plain inset from LOW_CUT.
local SIDE_PANEL_WIDTH = 204
local TOP_CUT, TOP_H = 320, 74
local LOW_CUT, LOW_SHIFT = 348, 2
-- General sheet's lines sit 2px higher at the top, 1px at the foot: inset drawn in two parts.
local UPPER_SRC, UPPER_AT, UPPER_H = 72, 74, 183
local LOWER_AT, LOWER_H = 257, 184
local PANE_H = 438
-- Inset interior in pane coords (general sheet's border at 340).
local INNER_W, INNER_TOP, INNER_BOTTOM = 340 + LOW_SHIFT + SIDE_PANEL_WIDTH - LOW_CUT, -77, -429
local PAGE_INSET, LIST_BAR = 4, 14
-- Set list: its left and top from the pane's top left, its right in from the pane's right, its bottom up from the
-- pane's bottom (rows past it scroll); its scroll bar is the stat page's (StatPanes numbers).
local EQUIP_LIST_LEFT = 0
local EQUIP_LIST_TOP = -5
local EQUIP_LIST_RIGHT_INSET = 23
local EQUIP_LIST_BOTTOM = 55
-- Each set row: the icon's and the name's left middle from the row's (the spec badge rides the icon).
local EQUIP_SET_ICON_X = 4
local EQUIP_SET_ICON_Y = 0
local EQUIP_SET_NAME_X = 55
local EQUIP_SET_NAME_Y = 0
-- Equip and Save buttons: each its top left from the pane's top left (same Y, same row), and its size.
local EQUIP_BUTTON_X = 2
local EQUIP_BUTTON_Y = -328
local EQUIP_BUTTON_WIDTH = 86
local EQUIP_BUTTON_HEIGHT = 22
local SAVE_BUTTON_X = 89
local SAVE_BUTTON_Y = -328
local SAVE_BUTTON_WIDTH = 86
local SAVE_BUTTON_HEIGHT = 22
-- New Set: the client's button in the classic red skin; its bottom middle from the pane's, its size, its label off centre.
local NEW_SET_BUTTON_X = -10
local NEW_SET_BUTTON_Y = 25
local NEW_SET_BUTTON_WIDTH = 178
local NEW_SET_BUTTON_HEIGHT = 22
local NEW_SET_TEXT_X = 0
local NEW_SET_TEXT_Y = -1
local CARD_ATLAS = "UI-Character-Info-OutfitCard"
local NAME_GAP = 4
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
-- The quick equipment button (option, off by default) while the panel is shut: the tab's icon above the gloves slot.
local QUICK_SIZE = 24
local QUICK_X = 0
local QUICK_Y = 4
local savedPoints, popupPoints, listPoints
local Sync

local function Manager()
    return PaperDollFrame and PaperDollFrame.EquipmentManagerPane
end

-- Read by the sheet: how far past its art the open panel reaches.
function ns.EquipmentPaneExtent()
    if active and open and seen then return SIDE_PANEL_WIDTH end
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
    return point == "TOPLEFT" and relativeTo == manager and x == EQUIP_LIST_LEFT
end

local function PlaceList(manager)
    local box, bar = manager.ScrollBox, manager.ScrollBar
    if not box or not bar or OnList(manager, box) then return end
    listPoints = listPoints or { box = PointsOf(box), bar = PointsOf(bar) }
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", manager, "TOPLEFT", EQUIP_LIST_LEFT, EQUIP_LIST_TOP)
    box:SetPoint("BOTTOMRIGHT", manager, "BOTTOMRIGHT", -(PAGE_INSET + EQUIP_LIST_RIGHT_INSET), EQUIP_LIST_BOTTOM)
    ns.PlaceSidePanelScroll(bar, pages[EQUIPMENT])
end

-- New Set in the classic red skin (ns.SkinRedButton): its state art and plus icon faded, its label made the
-- button's own text so the classic fonts follow.
local NEW_SET_ICON = "UI-Character-Info-Icon-Add"
local skinnedNewSet
local function NewSetLabel(region, button)
    if not region:IsObjectType("FontString") then return end
    region:ClearAllPoints()
    region:SetSize(0, 0)
    region:SetJustifyH("CENTER")
    region:SetPoint("CENTER", button, "CENTER", NEW_SET_TEXT_X, NEW_SET_TEXT_Y)
    button:SetFontString(region)
end

local function SkinNewSet(button)
    if skinnedNewSet == button then return end
    skinnedNewSet = button
    if button.StateTexture then button.StateTexture:SetAlpha(0) end
    ns.FadeAtlas(button, NEW_SET_ICON, true)
    ns.EachRegion(button, NewSetLabel, button)
    ns.SkinRedButton(button)
end

-- Equip, Save and New Set at our place and size while the pane is ours, the client's back after.
local buttonWas = setmetatable({}, { __mode = "k" })   -- button -> { points, width, height }
local function PlaceButtons(manager, on)
    local equip, save, newSet = manager.EquipSet, manager.SaveSet, manager.NewSet
    for _, button in pairs({ equip, save, newSet }) do
        if on and not buttonWas[button] then
            buttonWas[button] = { PointsOf(button), button:GetWidth(), button:GetHeight() }
        elseif not on and buttonWas[button] then
            local was = buttonWas[button]
            PutPoints(button, was[1])
            button:SetSize(was[2], was[3])
            buttonWas[button] = nil
        end
    end
    if not on then return end
    if newSet then
        SkinNewSet(newSet)
        ns.SetPointOnce(newSet, "BOTTOM", manager, "BOTTOM", NEW_SET_BUTTON_X, NEW_SET_BUTTON_Y)
        ns.SetSizeIf(newSet, NEW_SET_BUTTON_WIDTH, NEW_SET_BUTTON_HEIGHT)
    end
    if not equip then return end
    ns.SetPointOnce(equip, "TOPLEFT", manager, "TOPLEFT", EQUIP_BUTTON_X, EQUIP_BUTTON_Y)
    ns.SetSizeIf(equip, EQUIP_BUTTON_WIDTH, EQUIP_BUTTON_HEIGHT)
    if save then
        ns.SetPointOnce(save, "TOPLEFT", manager, "TOPLEFT", SAVE_BUTTON_X, SAVE_BUTTON_Y)
        ns.SetSizeIf(save, SAVE_BUTTON_WIDTH, SAVE_BUTTON_HEIGHT)
    end
end

-- A second anchor: the region then spans to it.
local function Pin(region, relativeTo, point, relativePoint, x)
    if not region or not relativeTo or fitted[region] then return end
    fitted[region] = PointsOf(region)
    region:SetPoint(point, relativeTo, relativePoint, x, 0)
end

-- Our points only; the client's kept for Restore.
local function Move(region, point, relativeTo, relativePoint, x, y)
    if not region or not relativeTo or fitted[region] then return end
    fitted[region] = PointsOf(region)
    ns.SetPointOnce(region, point, relativeTo, relativePoint, x, y)
end

-- The card art is a fixed 152 (the client's row is 205 wide): here it ends at the row's edge.
local function PinCard(card)
    if card then Pin(card, card:GetParent(), "TOPRIGHT", "TOPRIGHT", 0) end
end

-- The spec badge's corner on the icon's, as the client lays them (ring at 18,-18 on the row, icon at 4,-4).
local SPEC_RING_X, SPEC_RING_Y = 14, -14

local function FitRow(row)
    ns.FadeAtlas(row, CARD_ATLAS, true, PinCard)
    PinCard(row.HighlightBar)
    PinCard(row.SelectedBar)
    if row.text then
        Pin(row.text, row.Check, "RIGHT", "LEFT", -NAME_GAP)
        row.text:SetPoint("LEFT", row, "LEFT", EQUIP_SET_NAME_X, EQUIP_SET_NAME_Y)
    end
    if row.icon then
        fitted[row.icon] = PointsOf(row.icon)
        Move(row.SpecRing, "TOPLEFT", row.icon, "TOPLEFT", SPEC_RING_X, SPEC_RING_Y)
    end
end

-- Rows come from the client's pool as sets are added; each is fitted once. The client lays the icon again on
-- every fill, so it is put back on each look.
local function FitRows(box)
    for _, row in box:EnumerateFrames() do
        if not rowsFit[row] then
            rowsFit[row] = true
            FitRow(row)
        end
        if row.icon then ns.SetPointIf(row.icon, "LEFT", row, "LEFT", EQUIP_SET_ICON_X, EQUIP_SET_ICON_Y) end
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

-------------------------------------------------------------- placing

-- Our anchors while its tab is up, the client's back on Restore; the icon picker opens beside us.
local function Place(manager)
    PlaceList(manager)
    PlaceButtons(manager, true)
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
    PlaceButtons(manager, false)
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
    Span("charTabTopLeft", "charTabTopRight", TOP_CUT - SIDE_PANEL_WIDTH, 0, TOP_H, TOP_CUT, 0)
    local from = LOW_CUT - SIDE_PANEL_WIDTH - LOW_SHIFT
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

-- The pet view has no gear: no panel, arrow or quick button there.
local function PetView()
    local sheet = ns.sheet
    return sheet and sheet.PetView and sheet.PetView() or false
end

Sync = function()
    if not pane then return end
    local pet = PetView()
    local shown = active and open and not pet
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
    if toggle then ns.SetShownIf(toggle, active and not pet) end
    if quick then ns.SetShownIf(quick, active and not open and not pet and ns.db and ns.db.equipmentQuickButton == true) end
    if shown then SetTabs() end
end
ns.EquipmentPaneSync = function() Sync() end
ns.OnToggle(function(key)
    if key == "equipmentQuickButton" then Sync() end
end)

-- Open or shut is kept (db.sidePaneOpen), so the pane comes back as the player left it.
local function SetOpen(state)
    open = state and true or false
    if ns.db then ns.db.sidePaneOpen = open end
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

-- Above the gloves slot, the head of the right column.
local function BuildQuick(level)
    quick = CreateFrame("Button", "ForeverClassicUIEquipmentQuick", PaperDollFrame)
    quick:SetSize(QUICK_SIZE, QUICK_SIZE)
    local gloves = _G["CharacterHandsSlot"]
    if gloves then
        quick:SetPoint("BOTTOM", gloves, "TOP", QUICK_X, QUICK_Y)
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
    pane:SetSize(SIDE_PANEL_WIDTH + 3, PANE_H)
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

local restored = false
function ns.EquipmentPaneApply()
    active = true
    if not restored and ns.db then
        restored = true
        open = ns.db.sidePaneOpen == true
    end
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
