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
    ns.SetButtonFile(button, "Normal", PANEL_BUTTON .. "Up")
    ns.SetButtonFile(button, "Pushed", PANEL_BUTTON .. "Down")
    ns.SetButtonFile(button, "Disabled", PANEL_BUTTON .. "Disabled")
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
    ns.SetButtonFile(check, "Normal", CHECK .. "Up")
    ns.SetButtonFile(check, "Pushed", CHECK .. "Down")
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
    ns.SetButtonFile(button, "Normal", sheet .. "Up")
    ns.SetButtonFile(button, "Pushed", sheet .. "Down")
    ns.SetButtonFile(button, "Disabled", sheet .. "Disabled")
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
-- the round button, the client's end arrows kept in silver.
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
    ns.BronzeBackdrop(track)
    frame.fcuiTrack = track
    if slider.SetThumbTexture then
        slider:SetThumbTexture(SLIDER_THUMB)
        local thumb = slider:GetThumbTexture()
        if thumb then
            ns.SetFile(thumb, SLIDER_THUMB)
            thumb:SetTexCoord(0, 1, 0, 1)
            thumb:SetSize(32, 32)
        end
    end
    -- The arrows at the bar's ends stay, in silver to go with the old
    -- bar: the client's are bronze. They were hidden once, but the client
    -- brings them back up whenever it sets a slider up again, bronze and
    -- all. Drained of color they read as the old metal, and the setting
    -- holds through whatever art the client puts on them next.
    for _, key in ipairs({ "Back", "Forward" }) do
        local button = frame[key]
        if button then
            button:SetAlpha(1)
            button:EnableMouse(true)
            for _, region in ipairs({ button:GetRegions() }) do
                if region:IsObjectType("Texture") then ns.DrainBronze(region) end
            end
            for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
                local getter = button["Get" .. state .. "Texture"]
                ns.DrainBronze(getter and getter(button))
            end
        end
    end
end

-- The old drop down: the label frame in three pieces and the round
-- arrow at its right; the modern plate and arrow fade.
-- The old label frame in three pieces with the round arrow at its right,
-- drawn on any frame. The drop downs in the settings window wear this,
-- and so does anything of ours that opens a list.
function ns.DressDropdown(dropdown, inset)
    inset = inset or 17
    local pieces = {
        { "ddLeft", { 0, 0.1953125, 0, 1 }, 25, "TOPLEFT", -17, 17, "BOTTOMLEFT", -17, -17 },
        { "ddRight", { 0.8046875, 1, 0, 1 }, 25, "TOPRIGHT", 17, 17, "BOTTOMRIGHT", 17, -17 },
    }
    for _, p in ipairs(pieces) do
        local tex = ns.OwnTexture(dropdown, p[1], "BACKGROUND", 0)
        ns.SetFile(tex, DROPDOWN)
        tex:SetTexCoord(unpack(p[2]))
        tex:SetWidth(p[3])
        tex:ClearAllPoints()
        tex:SetPoint(p[4], dropdown, p[4], p[5] < 0 and -inset or inset, p[6] < 0 and -inset or inset)
        tex:SetPoint(p[7], dropdown, p[7], p[8] < 0 and -inset or inset, p[9] < 0 and -inset or inset)
        tex:Show()
    end
    local middle = ns.OwnTexture(dropdown, "ddMiddle", "BACKGROUND", 0)
    ns.SetFile(middle, DROPDOWN)
    middle:SetTexCoord(0.1953125, 0.8046875, 0, 1)
    middle:ClearAllPoints()
    middle:SetPoint("TOPLEFT", dropdown.fcui.ddLeft, "TOPRIGHT", 0, 0)
    middle:SetPoint("BOTTOMRIGHT", dropdown.fcui.ddRight, "BOTTOMLEFT", 0, 0)
    middle:Show()
    -- The arrow sits at the right end of the frame, a little in and a
    -- little up from its corner, where the old one sat.
    local arrow = ns.OwnTexture(dropdown, "ddArrow", "ARTWORK", 0)
    ns.SetFile(arrow, DROPDOWN_ARROW .. "Up")
    arrow:SetSize(24, 24)
    arrow:ClearAllPoints()
    arrow:SetPoint("RIGHT", dropdown, "RIGHT", 1, 2)
    arrow:Show()
    local glow = ns.OwnTexture(dropdown, "ddArrowGlow", "HIGHLIGHT", 0)
    glow:SetTexture(HILIGHT)
    glow:SetBlendMode("ADD")
    glow:SetSize(24, 24)
    glow:ClearAllPoints()
    glow:SetPoint("RIGHT", dropdown, "RIGHT", 1, 2)
    glow:Show()
    return arrow
end

function ns.SkinDropdown(dropdown)
    if not dropdown or dropdown.fcuiDropdown then return end
    dropdown.fcuiDropdown = true
    if dropdown.Background then dropdown.Background:SetAlpha(0) end
    if dropdown.Arrow then dropdown.Arrow:SetAlpha(0) end
    local hl = dropdown.GetHighlightTexture and dropdown:GetHighlightTexture()
    if hl then hl:SetAlpha(0) end
    local arrow = ns.DressDropdown(dropdown)
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
        -- Nothing to scroll, no knob, as the old scroll bars had it and
        -- as the client does with its own thumb. The mouse wheel still
        -- moves the bar's percentage when the page fits its window, and
        -- the knob followed it up and down a column with nothing to
        -- scroll; the client never showed that, its thumb being hidden.
        if bar.HasScrollableExtent then
            local ok, can = pcall(bar.HasScrollableExtent, bar)
            if ok and not can then
                knob:Hide()
                return
            end
        end
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

-- The old scroll column behind a thin scroll bar: the bordered track
-- with a socket for the arrow at each end, from the character sheet's
-- scroll sheet. That sheet is a top piece up to 256 long and a foot of
-- 108; a longer bar gets a stretch of the top piece's plain run between
-- them. The pieces follow the bar's length, which the client changes.
-- The arrows here stand where the client has them, so the art is set
-- round them: 10 left of the bar, 5 above it and 4 below.
local TRACK_FOOT = 108
function ns.ScrollTrackArt(bar)
    if not bar or bar.fcuiTrackArt or not bar.GetHeight then return end
    bar.fcuiTrackArt = true
    -- A bar that already has a track drawn for it, the character
    -- sheet's lists, keeps that one.
    if bar.fcui and bar.fcui.trackTop then return end
    local top = ns.OwnTexture(bar, "trackTop", "BACKGROUND", 0)
    local middle = ns.OwnTexture(bar, "trackMiddle", "BACKGROUND", 0)
    local foot = ns.OwnTexture(bar, "trackBottom", "BACKGROUND", 1)
    for _, tex in ipairs({ top, middle, foot }) do
        ns.SetTex(tex, "charScrollBar")
        tex:SetWidth(31)
        tex:ClearAllPoints()
    end
    -- The head two higher, and its arrow with it, as the foot is two
    -- lower: the column runs the full height of the text area.
    top:SetPoint("TOPLEFT", bar, "TOPLEFT", -10.5, 7)
    local back = bar.Back
    if back and not back.fcuiRaised then
        local point, relativeTo, relativePoint, x, y = back:GetPoint(1)
        if point then
            back.fcuiRaised = true
            back:ClearAllPoints()
            back:SetPoint(point, relativeTo, relativePoint, x or 0, (y or 0) + 2)
        end
    end
    -- Two lower than the arrow's own spot asks for, and the arrow with
    -- it: the column stopped short of the button row and left a gap.
    foot:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -10.5, -6)
    local forward = bar.Forward
    if forward and not forward.fcuiLowered then
        local point, relativeTo, relativePoint, x, y = forward:GetPoint(1)
        if point then
            forward.fcuiLowered = true
            forward:ClearAllPoints()
            forward:SetPoint(point, relativeTo, relativePoint, x or 0, (y or 0) - 2)
        end
    end
    foot:SetHeight(TRACK_FOOT)
    foot:SetTexCoord(0.515625, 1, 0, TRACK_FOOT / 256)
    middle:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    middle:SetPoint("BOTTOMLEFT", foot, "TOPLEFT", 0, 0)
    middle:SetTexCoord(0, 0.484375, 0.3, 0.7)
    local function Fit()
        local total = (bar:GetHeight() or 0) + 13
        -- Too short for the foot and a socket above it: no column at
        -- all is better than two pieces lying across each other.
        if total < TRACK_FOOT + 24 then
            top:Hide() middle:Hide() foot:Hide()
            return
        end
        local head = math.min(256, total - TRACK_FOOT)
        top:SetHeight(head)
        top:SetTexCoord(0, 0.484375, 0, head / 256)
        top:Show()
        foot:Show()
        middle:SetShown(total - TRACK_FOOT - head > 0.5)
    end
    -- Fitted whenever the bar's size changes, heard through a frame of
    -- our own laid over the bar. A hook on the bar's own size script was
    -- not always called: the first time the macro window opened, the
    -- column was fitted to the height the bar had before the window laid
    -- it out, a tall one, never heard of the real height, and ran on down
    -- past the window's foot. A script of the client's bar can be set
    -- afresh by the client after a hook is put on it; ours cannot.
    local ear = CreateFrame("Frame", nil, bar)
    ear:SetAllPoints(bar)
    ear:SetScript("OnSizeChanged", Fit)
    ear:SetScript("OnShow", Fit)
    Fit()
    -- The arrows stand two further out at each end here, so the knob
    -- travels that much further to meet them.
    bar.fcuiKnobReach = 7
    if bar.Track then ns.ClassicKnob(bar) end
end

-- The same column behind one of the addon's own scroll bars, whose
-- arrows stand outside the bar, above and below it. Shown and hidden
-- with the bar.
function ns.ScrollColumnOn(bar)
    if not bar or bar.fcuiColumn or not bar.up or not bar.down then return end
    bar.fcuiColumn = true
    local top = bar:CreateTexture(nil, "BACKGROUND", nil, 0)
    local middle = bar:CreateTexture(nil, "BACKGROUND", nil, 0)
    local foot = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    for _, tex in ipairs({ top, middle, foot }) do
        ns.SetTex(tex, "charScrollBar")
        tex:SetWidth(31)
    end
    top:SetPoint("TOPLEFT", bar.up, "TOPLEFT", -7.5, 5)
    foot:SetPoint("BOTTOMLEFT", bar.down, "BOTTOMLEFT", -7.5, -4)
    foot:SetHeight(TRACK_FOOT)
    foot:SetTexCoord(0.515625, 1, 0, TRACK_FOOT / 256)
    middle:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    middle:SetPoint("BOTTOMLEFT", foot, "TOPLEFT", 0, 0)
    middle:SetTexCoord(0, 0.484375, 0.3, 0.7)
    local function Fit()
        local total = (bar:GetHeight() or 0) + 32 + 9
        if total < TRACK_FOOT + 24 then
            top:Hide() middle:Hide() foot:Hide()
            return
        end
        local head = math.min(256, total - TRACK_FOOT)
        top:SetHeight(head)
        top:SetTexCoord(0, 0.484375, 0, head / 256)
        top:Show()
        foot:Show()
        middle:SetShown(total - TRACK_FOOT - head > 0.5)
    end
    bar:HookScript("OnSizeChanged", Fit)
    Fit()
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
        ns.ScrollTrackArt(bar)
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

-- How bright the dark marble of a list pane is drawn: one shade for the
-- social lists and the trade skill window alike.
ns.PANE_SHADE = 0.9

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
    ns.BronzeTint(stone)
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

-- The list an old drop down opened: the dialog border the game menu
-- wears, on the dark dialog ground, a radio mark beside each line with
-- the chosen one filled, hung under the drop down it belongs to. Entries
-- are { text, onPick, isChosen }. A press anywhere else closes it, and so
-- does the frame it follows going away.
local LIST_ROW, LIST_PAD_X, LIST_PAD_Y = 16, 15, 14
function ns.DropList(entries)
    local list = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:EnableMouse(true)
    list:SetClampedToScreen(true)
    list:Hide()
    if list.SetBackdrop then
        list:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        ns.BronzeBackdrop(list)
        list:SetBackdropColor(1, 1, 1, 1)
        list:SetBackdropBorderColor(1, 1, 1, 1)
    end
    list.items = {}
    local widest = 0
    for i, entry in ipairs(entries) do
        local item = CreateFrame("Button", nil, list)
        item:SetHeight(LIST_ROW)
        item:SetPoint("TOPLEFT", list, "TOPLEFT", LIST_PAD_X, -LIST_PAD_Y - (i - 1) * LIST_ROW)
        item:SetPoint("TOPRIGHT", list, "TOPRIGHT", -LIST_PAD_X, -LIST_PAD_Y - (i - 1) * LIST_ROW)
        local mark = item:CreateTexture(nil, "ARTWORK")
        mark:SetTexture("Interface\\Common\\UI-DropDownRadioChecks")
        mark:SetSize(16, 16)
        mark:SetPoint("LEFT", item, "LEFT", 0, 0)
        item.mark = mark
        local label = item:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("LEFT", mark, "RIGHT", 4, 0)
        label:SetText(entry[1])
        widest = math.max(widest, label:GetStringWidth() or 0)
        local highlight = item:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        highlight:SetBlendMode("ADD")
        highlight:SetAllPoints(item)
        item:SetScript("OnClick", function()
            list:Hide()
            PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
            entry[2]()
        end)
        item.entry = entry
        list.items[i] = item
    end
    list:SetSize(math.ceil(widest) + 20 + LIST_PAD_X * 2, #entries * LIST_ROW + LIST_PAD_Y * 2)

    pcall(list.RegisterEvent, list, "GLOBAL_MOUSE_DOWN")
    list:SetScript("OnEvent", function(self)
        if not self:IsShown() or self:IsMouseOver() then return end
        -- A press on the drop down itself is its own to answer: it
        -- would open the list straight back otherwise.
        if self.owner and self.owner:IsMouseOver() then return end
        self:Hide()
    end)

    function list:Follow(frame)
        if not frame or self.following == frame then return end
        self.following = frame
        frame:HookScript("OnHide", function() self:Hide() end)
    end

    -- Opens under the given drop down, or closes if it is already up.
    function list:Toggle(owner)
        if self:IsShown() then self:Hide() return end
        self.owner = owner
        for _, item in ipairs(self.items) do
            local chosen = item.entry[3] and item.entry[3]() and true or false
            if chosen then item.mark:SetTexCoord(0, 0.5, 0.5, 1) else item.mark:SetTexCoord(0.5, 1, 0.5, 1) end
        end
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, 6)
        self:Show()
        self:Raise()
    end
    if ns.CloseOnEscape then ns.CloseOnEscape(list) end
    return list
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
    ns.BronzeTint(stone)
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

-- Escape closes a window of ours.
--
-- Neither of the client's own lists is used for that. The older one,
-- UISpecialFrames, makes the rest of the client's pass over it ours. So
-- does the newer one: an entry of ours in the client's list of Escape
-- handlers taints its whole walk of that list, and the walk's second
-- handler calls SpellStopCasting, which is forbidden to an addon. With
-- one line of ours in the list the client's own Escape key drew a
-- refusal at the player, in a fight and out of one, on every press.
-- Nothing of ours goes in a list the client walks itself.
--
-- The key is taken instead, and only while a window of ours is up:
-- Escape is bound to a button of ours that closes the topmost of them
-- and does nothing else. It is handed back the moment none is up. A
-- binding cannot be changed during a fight, so a window closed in one
-- leaves the key ours with nothing to close: there the button lets the
-- target go, which is what Escape does in a fight with nothing open.
--
-- The spellbook is not on this list at all. Its casting layer hangs
-- under the client's own spellbook window, and the client's own Escape
-- closes that window, layer and all, in its own name: nothing here is
-- needed, in a fight or out of one.
local escButton = CreateFrame("Button", "ForeverClassicUIEscButton", UIParent, "SecureActionButtonTemplate")
local escFrames = {}

-- What the click carries.
--
-- With nothing of ours left to close it lets the target go, which is
-- what Escape does in a fight. Out of a fight the key is handed back
-- the moment the last window closes, so the conditional never fires
-- there.
--
-- While a window is up it carries no such thing, or the window would
-- close and the target drop on the one press. What it carries instead
-- is the write that arms the other text for the press after this one:
-- the key cannot be handed back during a fight, and neither can this
-- be written in Lua there, so the press that closes the last window is
-- the one thing that can leave the next press right.
local ESC_IDLE = "/cleartarget [combat]"
local ESC_WINDOW = "/click ForeverClassicUIEscIdle"

local escIdle = CreateFrame("Button", "ForeverClassicUIEscIdle", UIParent, "SecureActionButtonTemplate")
escIdle:SetSize(1, 1)
escIdle:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
escIdle:EnableMouse(false)
escIdle:RegisterForClicks("AnyUp", "AnyDown")
escIdle:SetAttribute("useOnKeyDown", false)
escIdle:SetAttribute("type", "attribute")
escIdle:SetAttribute("attribute-frame", escButton)
escIdle:SetAttribute("attribute-name", "macrotext")
escIdle:SetAttribute("attribute-value", ESC_IDLE)

-- The button a key is bound to has to be a real target: one with no
-- size and nowhere to stand is not clicked at all, and the key went to
-- the client, which let the target go instead of closing the window. A
-- pixel in the screen's corner is enough.
escButton:SetSize(1, 1)
escButton:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
escButton:EnableMouse(false)
escButton:Show()
-- A key bound to a button clicks it on the press or on the release
-- depending on the game's cast-on-key-down setting, and a button listens
-- for the release only unless told otherwise: with that setting on, the
-- press arrived and was not heard.
escButton:RegisterForClicks("AnyDown", "AnyUp")
escButton:SetAttribute("useOnKeyDown", false)
escButton:SetAttribute("type", "macro")
escButton:SetAttribute("macrotext", "")

-- The one shown last goes first, as the client's own do.
local function EscTop()
    local top
    for _, frame in ipairs(escFrames) do
        -- A window that says so is left out: it stands on one of the
        -- client's panels and the client's own key closes it. Taking
        -- the key for that one would close ours and leave the client's
        -- standing, and the next press would be eaten closing it.
        -- Only what is on the screen counts: a drop-down list left shown
        -- inside a window that has closed still says it is shown, and held
        -- the key (and the box below) with nothing to close, so every
        -- menu took two presses. A window faded out of the way is gone.
        if frame:IsVisible() and frame:GetEffectiveAlpha() > 0 and not frame.fcuiEscSkip
            and (not top or (frame.fcuiEscAt or 0) >= (top.fcuiEscAt or 0)) then top = frame end
    end
    return top
end

-- What the key does now: ours, the client's own, or another addon's.
local function EscHolder()
    if not GetBindingAction then return "" end
    local ok, action = pcall(GetBindingAction, "ESCAPE", true)
    if not ok or type(action) ~= "string" then return "" end
    if action:find("ForeverClassicUIEscButton", 1, true) then return "ours" end
    if action == "" or action == "TOGGLEGAMEMENU" then return "free" end
    return "other"
end

-- Set out of a fight, since neither can be set during one: what the
-- click carries, and whether the key is ours.
local function EscUpdate()
    if InCombatLockdown() then return end
    local want = EscTop() ~= nil
    -- The spellbook's own close, where its casting layer is up: that
    -- one cannot be closed in Lua alone.
    local text = (ns.SpellBookEscText and ns.SpellBookEscText())
        or (want and ESC_WINDOW or ESC_IDLE)
    if escButton:GetAttribute("macrotext") ~= text then
        escButton:SetAttribute("macrotext", text)
    end
    local holder = EscHolder()
    if not want then
        if holder == "ours" then ClearOverrideBindings(escButton) end
        return
    end
    if holder == "ours" then return end
    ClearOverrideBindings(escButton)
    SetOverrideBindingClick(escButton, true, "ESCAPE", "ForeverClassicUIEscButton")
end

-- One press closes every window of ours that is up, as the client's own
-- Escape closes all of its panels at once; one at a time, a spellbook
-- standing beside the talents took a second press.
local function EscCloseAll()
    local open = {}
    for _, frame in ipairs(escFrames) do
        if frame:IsVisible() and frame:GetEffectiveAlpha() > 0 and not frame.fcuiEscSkip then
            open[#open + 1] = frame
        end
    end
    for _, frame in ipairs(open) do
        if frame.fcuiEscClose then frame.fcuiEscClose(frame) else frame:Hide() end
    end
    -- The spellbook that hangs on the client's window, where that may be
    -- closed from here.
    if ns.SpellBookEscClose then ns.SpellBookEscClose() end
end

escButton:SetScript("PostClick", function(_, _, down)
    -- Both halves of the press arrive; the window closes on the release.
    if down then return end
    EscCloseAll()
end)

-- The key is taken again if anything else takes it while a window of
-- ours is up: the show and hide of the window alone was not enough, and
-- Escape went to the client, which let the target go.
local escWatch = CreateFrame("Frame")
escWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
escWatch:SetScript("OnEvent", EscUpdate)
escWatch:SetScript("OnUpdate", function(self, elapsed)
    self.since = (self.since or 0) + elapsed
    if self.since < 0.3 then return end
    self.since = 0
    EscUpdate()
end)

-- A window of ours opened during a fight cannot take the key: a binding
-- cannot be set there. The client's own Escape then walks its list, and
-- let the target go before anything of ours was asked. So while a window
-- of ours is up, one small frame of the client's is kept shown, unseen and
-- deaf, that the client's walk closes itself near the top of that list:
-- the color picker's opacity box, which it hides on Escape before it
-- closes panels or lets the target go (Blizzard_ColorPickerFrame,
-- priority FrameworkPre). Nothing of ours goes into the list; the client
-- only finds a frame of its own shown and hides it, in its own name. When
-- that box goes, the window of ours on top closes, as the key would have
-- closed it.
local sentinelOurs = false

local function Sentinel()
    local box = _G["OpacityFrame"]
    if not box or not box.IsShown then return nil end
    return box
end

-- Its own show puts up a catcher the size of the screen that hides the
-- box on a click anywhere, which here would read as Escape and close the
-- window being clicked in. Deaf and down for as long as the box is ours.
local function SentinelCatcher(ours)
    local catcher = _G["OpacityFrameCloseButton"]
    if not catcher then return end
    catcher:EnableMouse(not ours)
    if ours and catcher:IsShown() then catcher:Hide() end
end

-- Seen and heard again as the client made it, for whoever uses it next.
local function SentinelRestore(box)
    box:SetAlpha(1)
    box:EnableMouse(true)
    local slider = _G["OpacityFrameSlider"]
    if slider then slider:EnableMouse(true) end
    SentinelCatcher(false)
end

local function SentinelArm(on)
    local box = Sentinel()
    if not box then return end
    if on then
        -- Somebody else's box stays theirs.
        if box:IsShown() then return end
        box:SetAlpha(0)
        box:EnableMouse(false)
        local slider = _G["OpacityFrameSlider"]
        if slider then slider:EnableMouse(false) end
        SentinelCatcher(true)
        box:Show()
        SentinelCatcher(true)
        sentinelOurs = true
    elseif sentinelOurs then
        sentinelOurs = false
        if box:IsShown() then box:Hide() end
        SentinelRestore(box)
    end
end

local function SentinelUpdate()
    local box = Sentinel()
    if not box then return end
    if sentinelOurs and not box:IsShown() then
        -- Escape hid it: every window of ours goes, as on the key. Gone
        -- on the heels of a mouse click it was not Escape, and nothing
        -- closes; the box comes back.
        sentinelOurs = false
        SentinelRestore(box)
        local clicked = GetTime() - (ns.lastMouseDownAt or 0) < 0.25
        if not clicked then EscCloseAll() end
    end
    SentinelArm(EscTop() ~= nil)
end

local sentinelWatch = CreateFrame("Frame")
-- The client's own notice of a mouse press anywhere; heard, not hooked.
pcall(sentinelWatch.RegisterEvent, sentinelWatch, "GLOBAL_MOUSE_DOWN")
pcall(sentinelWatch.RegisterEvent, sentinelWatch, "GLOBAL_MOUSE_UP")
sentinelWatch:SetScript("OnEvent", function() ns.lastMouseDownAt = GetTime() end)
sentinelWatch:SetScript("OnUpdate", function()
    -- Every frame, so the window closes on the press itself.
    if sentinelOurs then SentinelCatcher(true) end
    if sentinelOurs or EscTop() then SentinelUpdate() end
end)

local escShows = 0
function ns.CloseOnEscape(frame, closer)
    if not frame then return end
    frame.fcuiEscClose = closer
    escFrames[#escFrames + 1] = frame
    frame:HookScript("OnShow", function(self)
        escShows = escShows + 1
        self.fcuiEscAt = escShows
    end)
    frame:HookScript("OnShow", EscUpdate)
    frame:HookScript("OnHide", EscUpdate)
    frame:HookScript("OnShow", SentinelUpdate)
    frame:HookScript("OnHide", SentinelUpdate)
    EscUpdate()
end
