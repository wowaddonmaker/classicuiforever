local _, ns = ...

-- Skill window shell shared by the trade skill and trainer windows: All tab
-- outlined with the list, filter button, list pane with rows and scroll
-- column, detail pane and the lighter foot border. Definitions only; other
-- files' helpers are looked up at call time.

local ROW_H, LIST_ROWS = 16, 8
-- Scroll column's black rim stops under the window's metal line, which ends 2 in from the frame's right.
local LIST_RIGHT = -17
-- Marble brightened: nothing lies or shines under it here, and plain it read near black.
local MARBLE = 1.35
local MARBLE_TILE = { coords = { 0, 1, 0, 1 } }
local LIST_HL = "Interface\\Buttons\\UI-Listbox-Highlight2"
local HEADER_R, HEADER_G, HEADER_B = 1, 0.82, 0

-- Sunken pane: dark marble in the game menu's metal border. edge sets border
-- weight; bare omits the floor (the foot stands on stone); fillAlpha adds a black fill.
function ns.SkillInsetBox(parent, edge, bare, fillAlpha)
    edge = edge or 16
    local inset = edge / 4
    local box = CreateFrame("Frame", nil, parent, ns.BACKDROP_TEMPLATE)
    if not bare then
        local floor = ns.TileTex(box:CreateTexture(nil, "BACKGROUND"), "marbleBg", MARBLE_TILE, MARBLE)
        floor:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -inset)
        floor:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset, inset)
        box.floor = floor
    end
    ns.Backdrop(box, ns.DialogEdge(edge))
    if fillAlpha then
        local fill = box:CreateTexture(nil, "BACKGROUND")
        fill:SetColorTexture(0, 0, 0, fillAlpha)
        fill:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
        fill:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 4)
    end
    return box
end

-- Stone strip over border edges the old window tucked under its stone.
local function StoneStrip(parent, level)
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetFrameLevel(level)
    local stone = strip:CreateTexture(nil, "ARTWORK")
    stone:SetAllPoints(strip)
    ns.TileTex(stone, "rockBg")
    return strip
end

-- A list row: selection bar, hover glow, fold toggle and label.
-- selectedAlpha nil leaves the bar at full alpha.
function ns.SkillListRow(parent, index, onClick, selectedAlpha)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(index - 1) * ROW_H)
    row:RegisterForClicks("LeftButtonUp")
    local sel = row:CreateTexture(nil, "BACKGROUND")
    sel:SetAllPoints(row)
    sel:SetTexture(LIST_HL)
    if selectedAlpha then sel:SetAlpha(selectedAlpha) end
    sel:Hide()
    row.selectedTex = sel
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    highlight:SetTexture(LIST_HL)
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.25)
    local toggle = row:CreateTexture(nil, "ARTWORK")
    toggle:SetSize(14, 14)
    toggle:SetPoint("LEFT", row, "LEFT", 3, 0)
    row.toggle = toggle
    local text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    row.text = text
    row:SetScript("OnClick", onClick)
    return row
end

-- The folding header list: lines hold { header = true, id, name } or the
-- caller's items; collapsed maps a header id to true.
local SkillList = {}
ns.SkillList = SkillList

function SkillList.AllCollapsed(lines, collapsed)
    local any = false
    for _, line in ipairs(lines) do
        if line.header then
            any = true
            if not collapsed[line.id] then return false end
        end
    end
    return any
end

-- Fold every header, or unfold all if all are folded.
function SkillList.FoldAll(lines, collapsed)
    local fold = not SkillList.AllCollapsed(lines, collapsed)
    for _, line in ipairs(lines) do
        if line.header then collapsed[line.id] = fold or nil end
    end
end

-- The rows from the scroll offset on; headers drawn here, items by drawItem(row, line).
function SkillList.Draw(panel, lines, collapsed, drawItem)
    local offset = math.floor((panel.bar:GetValue() or 0) + 0.5)
    for i, row in ipairs(panel.rows) do
        local line = lines[offset + i]
        row.line = line
        if not line then
            row:Hide()
        else
            row:Show()
            if line.header then
                ns.SetCollapseIcon(row.toggle, collapsed[line.id])
                row.toggle:Show()
                row.text:SetPoint("LEFT", row, "LEFT", 21, 0)
                row.text:SetText(line.name)
                row.text:SetTextColor(HEADER_R, HEADER_G, HEADER_B)
                row.selectedTex:Hide()
            else
                drawItem(row, line)
            end
        end
    end
end

function SkillList.FoldIcon(panel, lines, collapsed)
    ns.SetCollapseIcon(panel.collapseAll.icon, SkillList.AllCollapsed(lines, collapsed))
end

-- A page of ours over the client's window, level with its content.
function ns.ShellPage(name, host)
    local page = CreateFrame("Frame", name, host)
    page:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    page:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
    page:SetFrameLevel(host:GetFrameLevel() + 120)
    return page
end

-- Detail header: icon button, name and requirement line; returns the icon button.
function ns.ShellDetailHeader(detail, onEnter)
    local iconButton = CreateFrame("Button", nil, detail)
    iconButton:SetSize(37, 37)
    iconButton:SetPoint("TOPLEFT", detail, "TOPLEFT", 20, -18)
    detail.icon = iconButton:CreateTexture(nil, "ARTWORK")
    detail.icon:SetAllPoints(iconButton)
    iconButton:SetScript("OnEnter", onEnter)
    iconButton:SetScript("OnLeave", ns.HideTip)
    detail.name = detail:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    detail.name:SetPoint("TOPLEFT", iconButton, "TOPRIGHT", 8, -2)
    detail.name:SetJustifyH("LEFT")
    detail.requires = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail.requires:SetPoint("TOPLEFT", detail.name, "BOTTOMLEFT", 0, -3)
    detail.requires:SetPoint("RIGHT", detail, "RIGHT", -14, 0)
    detail.requires:SetJustifyH("LEFT")
    return iconButton
end

-- Exit, closing the host window (a global name, looked up on the click).
function ns.ShellExitButton(panel, hostName, width)
    local exit = ns.PanelButton(panel, EXIT or "Exit", width)
    exit:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 11)
    exit:SetScript("OnClick", function()
        local host = _G[hostName]
        if HideUIPanel and host then HideUIPanel(host) end
    end)
    return exit
end

-- opts: rows (visible count), createRow(list, index), onScroll(). Row content,
-- panel.detail and the foot are the caller's.
function ns.OldSkillShell(panel, opts)
    local rowCount = opts.rows or LIST_ROWS
    -- Fold or unfold every header at once.
    local all = CreateFrame("Button", nil, panel)
    all:SetSize(60, 18)
    all:SetPoint("TOPLEFT", panel, "TOPLEFT", 17, -68)
    all.icon = all:CreateTexture(nil, "ARTWORK")
    all.icon:SetSize(14, 14)
    all.icon:SetPoint("LEFT", all, "LEFT", 0, 0)
    local allText = all:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    allText:SetPoint("LEFT", all.icon, "RIGHT", 4, 0)
    allText:SetText(ALL or "All")
    panel.collapseAll = all

    -- The old drop down: dark label frame, gold arrow, word against the arrow.
    local filter = CreateFrame("Button", nil, panel)
    filter:SetSize(118, 27)
    filter:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -9, -57)
    -- Over the stone strips along the list's top.
    filter:SetFrameLevel(panel:GetFrameLevel() + 12)
    local filterArrow = ns.DressDropdown(filter, 14)
    local filterText = filter:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    filterText:SetPoint("RIGHT", filterArrow, "LEFT", 1, 1)
    filterText:SetText(FILTER or "Filter")
    panel.filter = filter

    -- List pane: runs under the window border (drawn above this page), past the
    -- left edge and a little on the right, where the scroll column covers it.
    local listBox = ns.SkillInsetBox(panel, 32)
    listBox:SetPoint("TOPLEFT", panel, "TOPLEFT", -2, -75)
    listBox:SetPoint("RIGHT", panel, "RIGHT", LIST_RIGHT, 0)
    listBox:SetHeight(rowCount * ROW_H + 25)
    -- All tab: the list's left border carried up, across and back down to its top
    -- edge, one outline round tab and list. A separate box showed the list's
    -- corner, inset the tab's side and ran its right side into the list.
    local EDGE = 32
    local BORDER_FILE = ns.ART.DIALOG_BORDER
    local V0, V1 = 0.0625, 0.9375
    local tab = CreateFrame("Frame", nil, panel)
    tab:SetSize(80, 22)
    tab:SetPoint("BOTTOMLEFT", listBox, "TOPLEFT", 0, 0)
    tab:SetFrameLevel(listBox:GetFrameLevel() + 3)
    local function Piece(layer)
        local tex = tab:CreateTexture(nil, layer or "BORDER")
        ns.SetFile(tex, BORDER_FILE)
        return tex
    end
    -- The list's own corner, replaced by the tab's left side.
    if listBox.TopLeftCorner then listBox.TopLeftCorner:SetAlpha(0) end
    local corner = Piece()
    corner:SetSize(EDGE, EDGE)
    corner:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    corner:SetTexCoord(0.5078125, 0.6171875, V0, V1)
    local leftSide = Piece()
    leftSide:SetWidth(EDGE)
    leftSide:SetPoint("TOPLEFT", corner, "BOTTOMLEFT", 0, 0)
    leftSide:SetPoint("BOTTOM", listBox, "TOP", 0, -EDGE)
    leftSide:SetTexCoord(0.0078125, 0.1171875, V0, V1)
    local farCorner = Piece()
    farCorner:SetSize(EDGE, EDGE)
    farCorner:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 0, 0)
    farCorner:SetTexCoord(0.6328125, 0.7421875, V0, V1)
    local top = Piece()
    top:SetHeight(EDGE)
    top:SetPoint("TOPLEFT", corner, "TOPRIGHT", 0, 0)
    top:SetPoint("TOPRIGHT", farCorner, "TOPLEFT", 0, 0)
    -- A border sheet's edge pieces lie on their side in the file.
    top:SetTexCoord(0.2578125, V1, 0.3671875, V1, 0.2578125, V0, 0.3671875, V0)
    local rightSide = Piece()
    rightSide:SetWidth(EDGE)
    rightSide:SetPoint("TOPRIGHT", farCorner, "BOTTOMRIGHT", 0, 0)
    -- Down to the foot of the list's top edge: the two meet in a plain corner.
    rightSide:SetPoint("BOTTOM", listBox, "TOP", 0, -11)
    rightSide:SetTexCoord(0.1328125, 0.2421875, V0, V1)
    -- The floor, under the border's metal and down onto the list's own.
    local floor = tab:CreateTexture(nil, "BACKGROUND")
    ns.TileTex(floor, "marbleBg", nil, MARBLE)
    floor:SetPoint("TOPLEFT", tab, "TOPLEFT", 8, -8)
    floor:SetPoint("RIGHT", tab, "RIGHT", -8, 0)
    floor:SetPoint("BOTTOM", listBox, "TOP", 0, -13)
    all:SetFrameLevel(tab:GetFrameLevel() + 2)
    panel.allTab = tab
    panel.listBox = listBox
    panel.listRight = LIST_RIGHT
    local list = CreateFrame("Frame", nil, listBox)
    list:SetPoint("TOPLEFT", listBox, "TOPLEFT", 17, -17)
    list:SetPoint("BOTTOMRIGHT", listBox, "BOTTOMRIGHT", -14, 10)
    list:EnableMouseWheel(true)
    panel.list = list
    panel.rows = {}
    for i = 1, rowCount do panel.rows[i] = opts.createRow(list, i) end
    panel.bar = ns.ClassicScrollBar(panel, list, function() opts.onScroll() end)
    -- The old window kept its scroll column whether the list ran past it or not.
    panel.bar.hideWhenIdle = false
    panel.bar:ClearAllPoints()
    panel.bar:SetPoint("TOPLEFT", listBox, "TOPRIGHT", -9, -27)
    panel.bar:SetPoint("BOTTOMLEFT", listBox, "BOTTOMRIGHT", -9, 22)
    -- Above the pane, so the column's left edge covers the pane's right.
    panel.bar:SetFrameLevel(listBox:GetFrameLevel() + 6)
    if ns.ScrollColumnOn then ns.ScrollColumnOn(panel.bar) end
    -- The knob's run in the panes' marble, over the column's grey, under the knob.
    local run = panel.bar:CreateTexture(nil, "BORDER")
    ns.TileTex(run, "marbleBg", nil, MARBLE)
    run:SetPoint("TOPLEFT", panel.bar, "TOPLEFT", 0, 0)
    run:SetPoint("BOTTOMRIGHT", panel.bar, "BOTTOMRIGHT", 0, 0)
    -- Stone over the outer rim of the list's top edge and the tab's top and right,
    -- inside the panes so the filter stays uncovered.
    local level = listBox:GetFrameLevel() + 4
    local overList = StoneStrip(panel, level)
    overList:SetPoint("TOPLEFT", panel.allTab, "BOTTOMRIGHT", 0, 0)
    overList:SetPoint("RIGHT", listBox, "RIGHT", 0, 0)
    overList:SetHeight(8)
    local overTab = StoneStrip(panel, level)
    overTab:SetPoint("TOPLEFT", panel.allTab, "TOPLEFT", 0, 0)
    overTab:SetPoint("TOPRIGHT", panel.allTab, "TOPRIGHT", 0, 0)
    overTab:SetHeight(8)
    local besideTab = StoneStrip(panel, level)
    besideTab:SetPoint("TOPRIGHT", panel.allTab, "TOPRIGHT", 0, 0)
    -- As far down as the list's strip, or a square of bare metal shows in the angle.
    besideTab:SetPoint("BOTTOMRIGHT", panel.allTab, "BOTTOMRIGHT", 0, -8)
    besideTab:SetWidth(8)
    list:SetScript("OnMouseWheel", function(_, delta)
        panel.bar:SetValue((panel.bar:GetValue() or 0) - delta * 2)
    end)

    -- Detail pane overlaps the list's bottom edge, drawn above it, so the borders
    -- read as one heavy line (the metal runs 4 to 11 px in at this weight).
    local detailBox = ns.SkillInsetBox(panel, 32)
    detailBox:SetPoint("TOPLEFT", listBox, "BOTTOMLEFT", 0, 12)
    detailBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 33)
    detailBox:SetFrameLevel(listBox:GetFrameLevel() + 2)
    -- Foot: a lighter floorless border round its buttons, top edge under the detail pane's.
    local footBox = ns.SkillInsetBox(panel, 20, true)
    footBox:SetPoint("TOPLEFT", detailBox, "BOTTOMLEFT", 0, 7)
    footBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 1, 2)
    footBox:SetFrameLevel(listBox:GetFrameLevel() + 1)
    local detail = CreateFrame("Frame", nil, detailBox)
    detail:SetAllPoints(detailBox)
    panel.detail = detail
    panel.detailBox, panel.footBox = detailBox, footBox
end
