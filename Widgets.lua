-- The old controls, put onto the client's modern widgets: the red
-- panel button, the check box, the slider bar, the drop down, the page
-- arrow steppers, the thin scroll bar's knob and arrows, and the tabs.
-- Each skinner takes the widget Blizzard made and fades its art; the
-- widget's behavior is untouched.
local _, ns = ...

local PANEL_BUTTON = "Interface\\Buttons\\UI-Panel-Button-"
local PANEL_COORDS = { 0, 0.625, 0, 0.6875 }
local CHECK = "Interface\\Buttons\\UI-CheckBox-"
local SLIDER_BORDER = "Interface\\Buttons\\UI-SliderBar-Border"
local SLIDER_BG = "Interface\\Buttons\\UI-SliderBar-Background"
local SLIDER_THUMB = "Interface\\Buttons\\UI-SliderBar-Button-Horizontal"
local DROPDOWN = "Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame"
local DROPDOWN_ARROW = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-"
local PAGE_PREV = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-"
local PAGE_NEXT = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-"
local HILIGHT = "Interface\\Buttons\\UI-Common-MouseHilight"

local function FadeRegions(frame)
    if not frame or not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
end
ns.FadeRegions = FadeRegions

-- The red button of the old panels on a modern three-slice or panel
-- button: its pieces fade, the old sheet goes on the button's own
-- states, the label in the old yellow.
function ns.SkinRedButton(button)
    if not button or button.fcuiRed then return end
    button.fcuiRed = true
    for _, key in ipairs({ "Left", "Right", "Center", "Middle", "TopLeft", "TopRight", "BottomLeft", "BottomRight", "TopMiddle", "MiddleLeft", "MiddleRight", "BottomMiddle", "MiddleMiddle" }) do
        local tex = button[key]
        if tex and tex.SetAlpha and tex.IsObjectType and tex:IsObjectType("Texture") then tex:SetAlpha(0) end
    end
    local ok = button:SetNormalTexture(PANEL_BUTTON .. "Up")
    if ok == false then return end
    button:SetPushedTexture(PANEL_BUTTON .. "Down")
    button:SetDisabledTexture(PANEL_BUTTON .. "Disabled")
    button:SetHighlightTexture(PANEL_BUTTON .. "Highlight")
    for _, tex in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture(), button:GetHighlightTexture() }) do
        if tex then
            tex:SetTexCoord(unpack(PANEL_COORDS))
            tex:ClearAllPoints()
            tex:SetAllPoints(button)
        end
    end
    local hl = button:GetHighlightTexture()
    if hl then hl:SetBlendMode("ADD") end
    button:SetNormalFontObject("GameFontNormal")
    button:SetHighlightFontObject("GameFontHighlight")
    button:SetDisabledFontObject("GameFontDisable")
end

-- The old check box: the box, the check, the glow.
function ns.SkinCheckbox(check)
    if not check or check.fcuiCheck then return end
    check.fcuiCheck = true
    if check.HoverBackground then check.HoverBackground:SetAlpha(0) end
    local ok = check:SetNormalTexture(CHECK .. "Up")
    if ok == false then return end
    check:SetPushedTexture(CHECK .. "Down")
    check:SetHighlightTexture(CHECK .. "Highlight")
    check:SetCheckedTexture(CHECK .. "Check")
    check:SetDisabledCheckedTexture(CHECK .. "Check-Disabled")
    for _, tex in ipairs({ check:GetNormalTexture(), check:GetPushedTexture(), check:GetHighlightTexture(), check:GetCheckedTexture(), check:GetDisabledCheckedTexture() }) do
        if tex then
            tex:SetTexCoord(0, 1, 0, 1)
            tex:ClearAllPoints()
            tex:SetAllPoints(check)
        end
    end
    local hl = check:GetHighlightTexture()
    if hl then hl:SetBlendMode("ADD") end
end

-- A page arrow on a modern icon button (the steppers beside a drop
-- down or slider).
function ns.SkinStepper(button, forward)
    if not button or button.fcuiStepper then return end
    button.fcuiStepper = true
    FadeRegions(button)
    local sheet = forward and PAGE_NEXT or PAGE_PREV
    local ok = button:SetNormalTexture(sheet .. "Up")
    if ok == false then return end
    button:SetPushedTexture(sheet .. "Down")
    button:SetDisabledTexture(sheet .. "Disabled")
    button:SetHighlightTexture(HILIGHT, "ADD")
    for _, tex in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture(), button:GetHighlightTexture() }) do
        if tex then
            tex:ClearAllPoints()
            tex:SetPoint("CENTER", button, "CENTER", 0, 0)
            tex:SetSize(26, 26)
        end
    end
end

-- The old slider bar under a modern slider: the bordered track and
-- the round button, the steppers as page arrows.
function ns.SkinSliderWithSteppers(frame)
    if not frame or frame.fcuiSlider then return end
    frame.fcuiSlider = true
    local slider = frame.Slider or frame
    for _, key in ipairs({ "Left", "Right", "Middle" }) do
        if slider[key] then slider[key]:SetAlpha(0) end
    end
    local track = CreateFrame("Frame", nil, slider, "BackdropTemplate")
    track:SetBackdrop({
        bgFile = SLIDER_BG, edgeFile = SLIDER_BORDER, tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    track:SetHeight(17)
    track:SetFrameLevel(math.max(0, slider:GetFrameLevel() - 1))
    frame.fcuiTrack = track
    if slider.SetThumbTexture then
        slider:SetThumbTexture(SLIDER_THUMB)
        local thumb = slider:GetThumbTexture()
        if thumb then
            thumb:SetTexCoord(0, 1, 0, 1)
            thumb:SetSize(32, 32)
        end
    end
    -- The old slider had no steppers; the bar's ends are the range.
    for _, key in ipairs({ "Back", "Forward" }) do
        local button = frame[key]
        if button then
            button:SetAlpha(0)
            button:EnableMouse(false)
        end
    end
end

-- The old drop down: the label frame in three pieces and the round
-- arrow at its right; the modern plate and arrow fade.
function ns.SkinDropdown(dropdown)
    if not dropdown or dropdown.fcuiDropdown then return end
    dropdown.fcuiDropdown = true
    if dropdown.Background then dropdown.Background:SetAlpha(0) end
    if dropdown.Arrow then dropdown.Arrow:SetAlpha(0) end
    local hl = dropdown.GetHighlightTexture and dropdown:GetHighlightTexture()
    if hl then hl:SetAlpha(0) end
    local pieces = {
        { "ddLeft", { 0, 0.1953125, 0, 1 }, 25, "TOPLEFT", -17, 17, "BOTTOMLEFT", -17, -17 },
        { "ddRight", { 0.8046875, 1, 0, 1 }, 25, "TOPRIGHT", 17, 17, "BOTTOMRIGHT", 17, -17 },
    }
    for _, p in ipairs(pieces) do
        local tex = ns.OwnTexture(dropdown, p[1], "BACKGROUND", 0)
        tex:SetTexture(DROPDOWN)
        tex:SetTexCoord(unpack(p[2]))
        tex:SetWidth(p[3])
        tex:ClearAllPoints()
        tex:SetPoint(p[4], dropdown, p[4], p[5], p[6])
        tex:SetPoint(p[7], dropdown, p[7], p[8], p[9])
        tex:Show()
    end
    local middle = ns.OwnTexture(dropdown, "ddMiddle", "BACKGROUND", 0)
    middle:SetTexture(DROPDOWN)
    middle:SetTexCoord(0.1953125, 0.8046875, 0, 1)
    middle:ClearAllPoints()
    middle:SetPoint("TOPLEFT", dropdown.fcui.ddLeft, "TOPRIGHT", 0, 0)
    middle:SetPoint("BOTTOMRIGHT", dropdown.fcui.ddRight, "BOTTOMLEFT", 0, 0)
    middle:Show()
    local arrow = ns.OwnTexture(dropdown, "ddArrow", "ARTWORK", 0)
    arrow:SetTexture(DROPDOWN_ARROW .. "Up")
    arrow:SetSize(24, 24)
    arrow:ClearAllPoints()
    arrow:SetPoint("RIGHT", dropdown, "RIGHT", -2, -1)
    arrow:Show()
    local glow = ns.OwnTexture(dropdown, "ddArrowGlow", "HIGHLIGHT", 0)
    glow:SetTexture(HILIGHT)
    glow:SetBlendMode("ADD")
    glow:SetSize(24, 24)
    glow:ClearAllPoints()
    glow:SetPoint("RIGHT", dropdown, "RIGHT", -2, -1)
    glow:Show()
    if dropdown.Text then
        dropdown.Text:SetFontObject("GameFontHighlightSmall")
        dropdown.Text:ClearAllPoints()
        dropdown.Text:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
        dropdown.Text:SetPoint("RIGHT", arrow, "LEFT", -2, 0)
        dropdown.Text:SetJustifyH("LEFT")
    end
end

-- The thin scroll bar's track fades; its thumb wears the old knob and
-- its steppers the old arrows.
-- The old knob on a modern thin scroll bar. Blizzard's thumb is a long
-- piece whose length follows the content, so a knob drawn at its center
-- never reaches the arrows; the knob is placed on the track from the
-- scroll fraction instead, top of the track at 0, bottom at 1.
local KNOB_H = 24
function ns.ClassicKnob(bar)
    local track = bar.Track
    local thumb = track and track.Thumb
    if not thumb then return end
    for _, key in ipairs({ "Begin", "Middle", "End" }) do
        if thumb[key] then thumb[key]:SetAlpha(0) end
    end
    local knob = ns.OwnTexture(track, "knob", "ARTWORK")
    ns.SetTex(knob, "scrollKnob")
    knob:SetSize(18, KNOB_H)
    knob:SetTexCoord(0.2, 0.8, 0.125, 0.875)
    local function Place()
        local pct = bar.fcuiPct or 0
        -- The client's track stops three pixels short of its own arrows
        -- at both ends; the old knob ran right up to them, so it is given
        -- that much again at each end of its travel.
        local reach = bar.fcuiKnobReach or 3
        local room = math.max(0, (track:GetHeight() or 0) - KNOB_H)
        -- The knob takes the line its own arrows are on: the track can
        -- sit off to one side, and a bar may hold its arrows off centre.
        local dx = 0
        local arrow = bar.Back or bar.Forward
        local refX = arrow and arrow.GetCenter and arrow:GetCenter()
        if not refX and bar.GetCenter then refX = bar:GetCenter() end
        local trackX = track.GetCenter and track:GetCenter()
        if refX and trackX then dx = refX - trackX end
        dx = dx + (bar.fcuiArrowOffset or 0)
        knob:ClearAllPoints()
        knob:SetPoint("TOP", track, "TOP", dx, reach - pct * (room + reach * 2))
        knob:Show()
    end
    if not bar.fcuiKnobHooked then
        bar.fcuiKnobHooked = true
        if bar.SetScrollPercentageInternal then
            hooksecurefunc(bar, "SetScrollPercentageInternal", function(self, pct) self.fcuiPct = pct or 0 Place() end)
        end
        if bar.Update then hooksecurefunc(bar, "Update", Place) end
        track:HookScript("OnSizeChanged", Place)
    end
    Place()
end

function ns.SkinMinimalScrollBar(bar)
    if not bar or bar.fcuiSkinned then return end
    bar.fcuiSkinned = true
    local track = bar.Track
    if track then
        for _, key in ipairs({ "Begin", "Middle", "End" }) do
            if track[key] then track[key]:SetAlpha(0) end
        end
        if track.Thumb then track.Thumb:SetWidth(16) end
        -- The arrow art is drawn a pixel right of its button; the knob
        -- follows it so the three line up.
        bar.fcuiArrowOffset = 1
        ns.ClassicKnob(bar)
    end
    local function Arrow(button, kind)
        if not button then return end
        if button.Texture then button.Texture:SetAlpha(0) end
        button:SetSize(16, 16)
        local tex = ns.OwnTexture(button, "arrow", "ARTWORK")
        ns.SetTex(tex, "scroll" .. kind .. "ButtonUp")
        tex:SetTexCoord(0.25, 0.75, 0.25, 0.75)
        -- A pixel right of the client's own spot: the old track sits
        -- that far over inside these windows.
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", button, "TOPLEFT", 1, 0)
        tex:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, 0)
        tex:Show()
    end
    Arrow(bar.Back, "Up")
    Arrow(bar.Forward, "Down")
end

-- Every thin scroll bar inside a window, a few levels down: the gossip
-- and quest text panes, the mail, trade and other lists.
-- A forbidden frame somewhere under a window (the bank keeps one) may
-- not even be asked for its children, so each is checked before the walk.
function ns.SkinScrollBarsUnder(frame, depth)
    if not frame or (depth or 0) <= 0 or type(frame) ~= "table" or not frame.GetChildren then return end
    if frame.IsForbidden and frame:IsForbidden() then return end
    local bar = rawget(frame, "ScrollBar")
    if type(bar) == "table" and not (bar.IsForbidden and bar:IsForbidden()) and bar.Track and bar.Back and bar.Forward then
        ns.SkinMinimalScrollBar(bar)
    end
    local ok, children = pcall(function() return { frame:GetChildren() } end)
    if not ok then return end
    for _, child in ipairs(children) do ns.SkinScrollBarsUnder(child, depth - 1) end
end

-- A modern minimal tab (a top tab of a panel) in the old tab pieces
-- turned over, so the tab's base sits on the box below it; the active
-- sheet while it is selected.
local function TabSelected(tab)
    if tab.IsSelected then return tab:IsSelected() end
    return tab.selected or false
end

local function DressMinimalTab(tab)
    local selected = TabSelected(tab)
    local key = selected and "optionsTabActive" or "optionsTabInactive"
    local pieces = {
        { "mtLeft", { 0, 0.15625, 0, 1 }, 20, "BOTTOMLEFT" },
        { "mtRight", { 0.84375, 1, 0, 1 }, 20, "BOTTOMRIGHT" },
    }
    for _, p in ipairs(pieces) do
        local tex = ns.OwnTexture(tab, p[1], "BACKGROUND", 0)
        ns.SetTex(tex, key)
        tex:SetTexCoord(unpack(p[2]))
        tex:SetSize(p[3], 32)
        tex:ClearAllPoints()
        tex:SetPoint(p[4], tab, p[4], 0, 0)
        tex:Show()
    end
    local middle = ns.OwnTexture(tab, "mtMiddle", "BACKGROUND", 0)
    ns.SetTex(middle, key)
    middle:SetTexCoord(0.15625, 0.84375, 0, 1)
    middle:SetHeight(32)
    middle:ClearAllPoints()
    middle:SetPoint("BOTTOMLEFT", tab.fcui.mtLeft, "BOTTOMRIGHT", 0, 0)
    middle:SetPoint("BOTTOMRIGHT", tab.fcui.mtRight, "BOTTOMLEFT", 0, 0)
    middle:Show()
    if tab.Text then tab.Text:SetFontObject(selected and "GameFontHighlightSmall" or "GameFontNormalSmall") end
end

function ns.SkinMinimalTab(tab)
    if not tab then return end
    if not tab.fcuiTab then
        tab.fcuiTab = true
        for _, key in ipairs({ "Left", "Middle", "Right" }) do
            if tab[key] then tab[key]:SetAlpha(0) end
        end
        for _, method in ipairs({ "SetSelected", "SetSelectedState", "UpdateTab" }) do
            if type(tab[method]) == "function" then
                hooksecurefunc(tab, method, function(self) DressMinimalTab(self) end)
            end
        end
        tab:HookScript("OnShow", DressMinimalTab)
        tab:HookScript("OnClick", function(self) C_Timer.After(0, function() DressMinimalTab(self) end) end)
    end
    DressMinimalTab(tab)
end


-- The old item name plate: its art sits inside a border of empty pixels,
-- 11 of the file's 128 across and 11 of its 64 down, so a texture drawn
-- at the size you want comes out smaller than you asked. This takes the
-- size the plate should read at and sets the texture that gives it.
local PLATE_W, PLATE_H, PLATE_PAD = 106 / 128, 42 / 64, 11 / 128
function ns.FitNamePlate(box, host, leftInset, width, height)
    local texW, texH = width / PLATE_W, height / PLATE_H
    box:SetSize(texW, texH)
    box:ClearAllPoints()
    box:SetPoint("LEFT", host, "LEFT", leftInset - PLATE_PAD * texW, 0)
end

---------------------------------------------------------------------------
-- The plates the old who list carried above its columns.
local COLUMN_TABS = "Interface\\FriendsFrame\\WhoFrame-ColumnTabs"

-- Pieces the 1.x list windows are built from: a section of a window, a
-- stone divider between two of them, and a sortable column plate.
---------------------------------------------------------------------------

function ns.SectionBox(parent)
    local box = CreateFrame("Frame", nil, parent)
    -- A breath of light over the window's own floor: the sections were
    -- so dark they read as one.
    local lift = box:CreateTexture(nil, "BACKGROUND")
    lift:SetAllPoints(box)
    lift:SetColorTexture(1, 0.96, 0.88, 0.03)
    return box
end

-- A divider between the sections: a bar of the window's own stone, lit
-- along its top and dark at its foot, run from one inner edge to the
-- other the way the old windows split their panes.
function ns.StoneFill(frame, layer)
    local stone = frame:CreateTexture(nil, layer or "ARTWORK")
    stone:SetTexture(ns.TexPath("rockBg"), "REPEAT", "REPEAT")
    stone:SetHorizTile(true)
    stone:SetVertTile(true)
    stone:SetTexCoord(0, 1, 0, 1)
    stone:SetVertexColor(1.25, 1.2, 1.1)
    return stone
end

-- A panel that stands on its own over the world: the old menus were
-- solid black behind their words with a thin silver line around them,
-- never the see-through plate a section inside a window can afford.
function ns.BlackPanel(parent)
    local panel = CreateFrame("Frame", nil, parent or UIParent)
    local fill = panel:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(panel)
    fill:SetColorTexture(0, 0, 0, 0.94)
    local edges = {
        { "TOPLEFT", "TOPRIGHT", 0, 0, 0, 0, 1 },
        { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 0, 0, 0, 1 },
        { "TOPLEFT", "BOTTOMLEFT", 0, 0, 0, 0, 0 },
        { "TOPRIGHT", "BOTTOMRIGHT", 0, 0, 0, 0, 0 },
    }
    for _, edge in ipairs(edges) do
        local line = panel:CreateTexture(nil, "BORDER")
        line:SetColorTexture(0.62, 0.62, 0.6, 1)
        line:SetPoint(edge[1], panel, edge[1], 0, 0)
        line:SetPoint(edge[2], panel, edge[2], 0, 0)
        if edge[7] == 1 then line:SetHeight(1) else line:SetWidth(1) end
    end
    return panel
end

-- The little menu the old lists opened under the cursor on a right
-- click: a name over a short column of actions, each one shown only
-- where it applies. Entries are { text, onClick, allowed }.
function ns.RowMenu(entries)
    local menu = ns.BlackPanel(UIParent)
    menu:SetSize(140, 24)
    menu:SetFrameStrata("DIALOG")
    menu:EnableMouse(true)
    menu:Hide()

    menu.title = menu:CreateFontString(nil, "ARTWORK")
    menu.title:SetFontObject(ns.FONT_GOLD_SMALL or "GameFontNormalSmall")
    menu.title:SetPoint("TOP", menu, "TOP", 0, -4)

    -- The old menus ended in a Cancel, which is also the plain way out
    -- of one opened on a row nothing can be done to.
    local rows = {}
    for i, entry in ipairs(entries) do rows[i] = entry end
    rows[#rows + 1] = { CANCEL or "Cancel", function() end }

    menu.items = {}
    for i, entry in ipairs(rows) do
        local item = CreateFrame("Button", nil, menu)
        item:SetHeight(15)
        item:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -18 - (i - 1) * 15)
        item:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -6, -18 - (i - 1) * 15)
        local label = item:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("LEFT", item, "LEFT", 4, 0)
        label:SetText(entry[1])
        item.Label = label
        local highlight = item:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(item)
        highlight:SetColorTexture(1, 0.82, 0, 0.16)
        item.allowed = entry[3]
        item:SetScript("OnClick", function(self)
            menu:Hide()
            if self.entry then entry[2](self.entry) end
        end)
        menu.items[i] = item
    end
    menu:SetScript("OnHide", function(self) self.entry = nil end)

    -- A press anywhere off the menu closes it. Without this it stayed up
    -- until one of its rows was picked, over whatever was opened next.
    -- The press that closes it may be the start of a right click on the
    -- same row, whose release would open it straight back: that row is
    -- remembered for a moment so the second click closes, as it did.
    pcall(menu.RegisterEvent, menu, "GLOBAL_MOUSE_DOWN")
    menu:SetScript("OnEvent", function(self)
        if not self:IsShown() or self:IsMouseOver() then return end
        self.closedEntry, self.closedAt = self.entry, GetTime()
        self:Hide()
    end)

    -- The menu goes when the window it was opened from goes.
    function menu:Follow(frame)
        if not frame or self.following == frame then return end
        self.following = frame
        frame:HookScript("OnHide", function() self:Hide() end)
    end

    -- A second right click on the same row closes it, as the old menus did.
    function menu:Open(entry, title)
        if self:IsShown() and self.entry == entry then self:Hide() return end
        if self.closedEntry == entry and GetTime() - (self.closedAt or 0) < 0.4 then
            self.closedEntry = nil
            return
        end
        self.closedEntry = nil
        self.entry = entry
        self.title:SetText(title or "")
        local shown = 0
        for _, item in ipairs(self.items) do
            local allowed = (not item.allowed) or item.allowed(entry) and true or false
            item.entry = entry
            item:SetShown(allowed and true or false)
            if allowed then
                shown = shown + 1
                item:ClearAllPoints()
                item:SetPoint("TOPLEFT", self, "TOPLEFT", 6, -18 - (shown - 1) * 15)
                item:SetPoint("TOPRIGHT", self, "TOPRIGHT", -6, -18 - (shown - 1) * 15)
            end
        end
        self:SetHeight(24 + shown * 15)
        local scale = UIParent:GetEffectiveScale()
        local x, y = GetCursorPosition()
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        self:Show()
    end
    return menu
end

function ns.StoneBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(6)
    local stone = bar:CreateTexture(nil, "ARTWORK")
    stone:SetTexture(ns.TexPath("rockBg"), "REPEAT", "REPEAT")
    stone:SetHorizTile(true)
    stone:SetVertTile(true)
    stone:SetTexCoord(0, 1, 0, 1)
    stone:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -1)
    stone:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 1)
    stone:SetVertexColor(1.25, 1.2, 1.1)
    for _, edge in ipairs({ { "TOP", 0.52, 0.48, 0.40 }, { "BOTTOM", 0.06, 0.05, 0.04 } }) do
        local line = bar:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(edge[2], edge[3], edge[4], 1)
        line:SetHeight(1)
        line:SetPoint(edge[1] .. "LEFT", bar, edge[1] .. "LEFT", 0, 0)
        line:SetPoint(edge[1] .. "RIGHT", bar, edge[1] .. "RIGHT", 0, 0)
    end
    return bar
end

-- A column header: the old who-list tab cut in three, one per column, so
-- the row above the list reads as separate plates rather than one strip.
function ns.ColumnHeader(parent, column, previous, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(column.w, 20)
    if previous then
        button:SetPoint("LEFT", previous, "RIGHT", 0, 0)
    else
        button:SetPoint("LEFT", parent, "LEFT", 0, 0)
    end
    button.key = column.key

    local left = button:CreateTexture(nil, "BACKGROUND")
    left:SetTexture(COLUMN_TABS)
    left:SetSize(5, 20)
    left:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    left:SetTexCoord(0, 0.078125, 0, 0.625)

    local right = button:CreateTexture(nil, "BACKGROUND")
    right:SetTexture(COLUMN_TABS)
    right:SetSize(4, 20)
    right:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    right:SetTexCoord(0.90625, 0.96875, 0, 0.625)

    local middle = button:CreateTexture(nil, "BACKGROUND")
    middle:SetTexture(COLUMN_TABS)
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
    middle:SetTexCoord(0.078125, 0.90625, 0, 0.625)

    local text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("LEFT", button, "LEFT", 8, 0)
    text:SetText(column.label)
    button.Text = text

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -2)
    highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 2)
    highlight:SetColorTexture(1, 0.82, 0, 0.12)
    button:SetScript("OnClick", onClick)
    return button
end

-- Escape closes a window of ours. The client's own list for that
-- (UISpecialFrames) is read by the client in the middle of its Escape
-- handling, and an entry of ours there makes that handling ours, which
-- it holds against the addon where it matters most, in a fight. So the
-- key is taken instead: while one of these windows is up, Escape is
-- bound to a button of ours that closes the topmost of them, and handed
-- back the moment none is. Bindings cannot be changed during a fight,
-- so the key is always handed back as a fight begins, when that is
-- still allowed, and taken again after it if a window is still up.
local escButton
local escFrames = {}

local function EscUpdate()
    if not escButton or InCombatLockdown() then return end
    ClearOverrideBindings(escButton)
    for _, frame in ipairs(escFrames) do
        if frame:IsShown() then
            SetOverrideBindingClick(escButton, true, "ESCAPE", "ForeverClassicUIEscButton")
            return
        end
    end
end

function ns.CloseOnEscape(frame)
    if not frame then return end
    if not escButton then
        escButton = CreateFrame("Button", "ForeverClassicUIEscButton", UIParent)
        -- A key bound to a button clicks it on the press or on the
        -- release depending on the game's cast-on-key-down setting, and
        -- a button listens for the release only unless told otherwise:
        -- with that setting on, the press arrived and was not heard.
        escButton:RegisterForClicks("AnyDown", "AnyUp")
        escButton:SetScript("OnClick", function()
            for i = #escFrames, 1, -1 do
                if escFrames[i]:IsShown() then
                    escFrames[i]:Hide()
                    return
                end
            end
        end)
        escButton:RegisterEvent("PLAYER_REGEN_DISABLED")
        escButton:RegisterEvent("PLAYER_REGEN_ENABLED")
        escButton:SetScript("OnEvent", function(self, event)
            if event == "PLAYER_REGEN_DISABLED" then
                ClearOverrideBindings(self)
            else
                EscUpdate()
            end
        end)
    end
    escFrames[#escFrames + 1] = frame
    frame:HookScript("OnShow", EscUpdate)
    frame:HookScript("OnHide", EscUpdate)
end
