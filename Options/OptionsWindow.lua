local _, ns = ...
local L = ns.L

-- The /fcui options dialog (ticked is the classic look), also the Settings page canvas.

local O = ns.options
local TITLE = O.TITLE
local EMPTY = ns.EMPTY
local WIDTH, ROW = 470, 24
local LIST_ROWS, INDENT, COLUMNS = 10, 22, 2
local C = ns.ART.CHECK
local BTN = "Interface\\Buttons\\UI-"
-- Raw paths: no bronze swap.
local OPTION_BOX = { set = "raw", checked = C .. "Check", disabledChecked = C .. "Check-Disabled", add = true }
-- UI-RadioButton's cells: ring, gold dot, glow, grey dot; 16 across in the 24 row.
local RADIO = BTN .. "RadioButton"
local OPTION_RADIO = { set = "raw", checked = RADIO, disabledChecked = RADIO, add = true, center = { 16, 16 },
    states = { "Normal", "Highlight", "Checked", "DisabledChecked" },
    coords = { Normal = { 0, 0.25, 0, 1 }, Checked = { 0.25, 0.5, 0, 1 }, Highlight = { 0.5, 0.75, 0, 1 },
        DisabledChecked = { 0.75, 1, 0, 1 } } }
O.RADIO, O.OPTION_RADIO = RADIO, OPTION_RADIO
local RAW_ADD = { set = "raw", add = true }
local TOPLEVEL = { toplevel = true }

local function TipLabel(self) return self.label end
local function TipBody(self) return self.tooltip end
-- White title, wrapped body; nothing without a body.
local OPTION_TIP = { when = TipBody, text = TipLabel, r = 1, g = 1, b = 1, lines = { { TipBody, nil, nil, nil, true } } }
local PREFERRED_TIP = { text = L["OPTWIN_WHY_GITHUB"], r = 1, g = 1, b = 1, lines = {
    { L["OPTWIN_REPORTS_THERE_ARE_EASIER_TO"], nil, nil, nil, true },
    { " ", nil, nil, nil, true },
    { L["OPTWIN_YOU_NEED_A_GITHUB_ACCOUNT"], 1, 0.82, 0, true },
} }

-- Not part of the classic look, so Toggle none leaves them (the minimap button leads back here), nor the radio picks.
local NOT_IN_NONE = { minimapButton = true, welcomeNote = true, questLevels = true }
local function InNone(key) return not NOT_IN_NONE[key] and not ns.TOGGLE_RADIO[key] end

local window

-- Our standalone dialog shell, hidden: strata nil is DIALOG; opts.toplevel. Welcome and Status share it.
function O.DialogWindow(name, y, strata, opts)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    ns.Backdrop(frame, ns.BACKDROP.DIALOG)
    frame:SetFrameStrata(strata or "DIALOG")
    if opts and opts.toplevel then frame:SetToplevel(true) end
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, y or 0)
    ns.MakeDraggable(frame)
    frame:Hide()
    return frame
end

-- Lowercased once for the search: the name side (label, keywords, its section's title) and the tooltip.
local function Describe(row, key, label, tooltip)
    row.key, row.label, row.tooltip = key, label, tooltip
    row.keyLow, row.tipLow = label:lower(), (tooltip or ""):lower()
    ns.AttachTip(row, OPTION_TIP)
end

-- A soft gold bar behind a matching row's label; the rest of its section is dimmed.
local MATCH_DIM = 0.4
local matchBar = setmetatable({}, { __mode = "k" })
local function ShowMatch(box, on)
    local bar = matchBar[box]
    if not bar and on then
        bar = box:CreateTexture(nil, "BACKGROUND")
        bar:SetColorTexture(1, 0.82, 0, 0.16)
        bar:SetPoint("TOPLEFT", box, "TOPLEFT", -2, -2)
        bar:SetPoint("BOTTOMRIGHT", box.text, "BOTTOMRIGHT", 4, -4)
        matchBar[box] = bar
    end
    if bar then bar:SetShown(on) end
end

local function Arrow(row, kind, x)
    local button = ns.NewFrame("Button", nil, row)
    button:SetSize(16, 16)
    button:SetPoint("LEFT", row, "LEFT", x, 0)
    ns.DressStates(button, BTN .. kind .. "Button-Up", BTN .. kind .. "Button-Down", BTN .. kind .. "Button-Disabled", ns.ART.PLUS_GLOW, RAW_ADD)
    return button
end

-- Number row (minus, value, plus, label) with the checkbox methods, so the list treats it alike.
local function Stepper(parent, key, label, tooltip, low, high, apply)
    local row = ns.NewFrame("Frame", nil, parent)
    row:SetSize(24, 24)
    row.minus = Arrow(row, "Minus", 4)
    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.value:SetPoint("LEFT", row.minus, "RIGHT", 2, 0)
    row.value:SetWidth(20)
    row.value:SetJustifyH("CENTER")
    row.plus = Arrow(row, "Plus", 42)
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", row.plus, "RIGHT", 4, 1)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(label)
    row.text = text
    function row:Sync()
        local value = tonumber(ns.db[key]) or low
        self.value:SetText(value)
        self.minus:SetEnabled(self.on ~= false and value > low)
        self.plus:SetEnabled(self.on ~= false and value < high)
    end
    function row:SetChecked() self:Sync() end
    function row:SetEnabled(on)
        self.on = on and true or false
        self:Sync()
    end
    local function Step(by)
        return function()
            apply(math.max(low, math.min(high, (tonumber(ns.db[key]) or low) + by)))
            row:Sync()
        end
    end
    row.minus:SetScript("OnClick", Step(-1))
    row.plus:SetScript("OnClick", Step(1))
    row:EnableMouse(true)
    Describe(row, key, label, tooltip)
    return row
end

-- The custom theme's colour: a swatch opening the game's colour picker (its hex box included).
local function PickColor(r, g, b)
    ns.Sched.NextFrame("options.themeColor", function() ns.SetThemeColor(r, g, b) end)
end

local function ColorRow(parent, key, label, tooltip)
    local row = ns.NewFrame("Button", nil, parent)
    row:SetSize(24, 24)
    local swatch = row:CreateTexture(nil, "ARTWORK")
    swatch:SetSize(16, 16)
    swatch:SetPoint("LEFT", row, "LEFT", 4, 0)
    local rim = row:CreateTexture(nil, "BACKGROUND")
    rim:SetColorTexture(0, 0, 0, 1)
    rim:SetPoint("TOPLEFT", swatch, "TOPLEFT", -1, 1)
    rim:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", 1, -1)
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", swatch, "RIGHT", 6, 1)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(label)
    row.text = text
    function row:Sync()
        local r, g, b = ns.HexColor(ns.db[key])
        swatch:SetColorTexture(r or 1, g or 1, b or 1)
        swatch:SetAlpha(self.on == false and 0.4 or 1)
    end
    function row:SetChecked() self:Sync() end
    function row:SetEnabled(on)
        self.on = on and true or false
        self:EnableMouse(self.on)
        self:Sync()
    end
    row:SetScript("OnClick", function()
        local r, g, b = ns.HexColor(ns.db[key])
        local was = ns.db[key]
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r or 1, g = g or 1, b = b or 1,
            swatchFunc = function()
                PickColor(ColorPickerFrame:GetColorRGB())
                row:Sync()
            end,
            cancelFunc = function()
                PickColor(ns.HexColor(was))
                row:Sync()
            end,
        })
    end)
    Describe(row, key, label, tooltip)
    return row
end

-- A button for a mode that lasts while the options are open, not a saved setting; Done while on.
-- check: { key, label, tooltip, set } for a saved box beside it.
local function ButtonRow(parent, key, label, tooltip, press, isOn, check)
    local row = ns.NewFrame("Frame", nil, parent)
    row:SetSize(24, 24)
    local button = ns.PanelButton(row, label, check and 130 or 150)
    button:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.button, row.text = button, button:GetFontString()
    local box
    if check then
        box = ns.NewFrame("CheckButton", nil, row)
        box:SetSize(24, 24)
        box:SetPoint("LEFT", button, "RIGHT", 4, 0)
        ns.DressStates(box, C .. "Up", C .. "Down", nil, C .. "Highlight", OPTION_BOX)
        box.label, box.tooltip = check[2], check[3]
        ns.AttachTip(box, OPTION_TIP)
        box:SetScript("OnClick", function(self) check[4](check[1], self:GetChecked() and true or false) end)
    end
    function row.SetChecked()
        local on = isOn()
        button:SetText(on and (DONE or "Done") or label)
        button:SetButtonState(on and "PUSHED" or "NORMAL", on)
        if box then box:SetChecked(ns.db[check[1]] ~= false) end
    end
    function row.SetEnabled(_, on)
        button:SetEnabled(on)
        if box then box:SetEnabled(on) end
    end
    button:SetScript("OnClick", function() press() row:SetChecked() end)
    Describe(row, key, label, tooltip)
    return row
end

-- ToggleChanged refreshes whichever copy of the panel is shown; a radio row only turns on.
local function BoxClick(self)
    ns.db[self.key] = (self.radio or self:GetChecked()) and true or false
    ns.ToggleChanged(self.key)
end

local function Checkbox(parent, key, label, tooltip, radio)
    local box = ns.NewFrame("CheckButton", nil, parent)
    box:SetSize(24, 24)
    if radio then
        box.radio = true
        ns.DressStates(box, RADIO, nil, nil, RADIO, OPTION_RADIO)
    else
        ns.DressStates(box, C .. "Up", C .. "Down", nil, C .. "Highlight", OPTION_BOX)
    end
    local text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", box, "RIGHT", 2, 1)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(label)
    box.text = text
    Describe(box, key, label, tooltip)
    box:SetScript("OnClick", BoxClick)
    return box
end

local DROP_W = 92
local SWING_HANDS = { { "swingColorMain", L["OPTWIN_MAIN_HAND"] }, { "swingColorOff", L["OPTWIN_OFF_HAND"] }, { "swingColorRanged", L["OPTWIN_RANGED"] } }

-- Label, then the old drop down box; items(root) fills its menu.
local function DropShell(parent, label, items)
    local row = ns.NewFrame("Frame", nil, parent)
    row:SetSize(24, 24)
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", row, "LEFT", 4, 1)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(label)
    row.text = text
    local dropdown = ns.NewFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(DROP_W)
    dropdown:SetPoint("LEFT", text, "RIGHT", 4, -1)
    ns.SkinDropdown(dropdown)
    dropdown:SetupMenu(function(_, root) items(root) end)
    row.dropdown = dropdown
    function row:SetChecked() self.dropdown:GenerateMenu() end
    function row:SetEnabled(on) self.dropdown:SetEnabled(on) end
    return row
end

local function PickToggle(key)
    ns.db[key] = true
    ns.ToggleChanged(key)
end

local function ToggleOn(key) return ns.db[key] == true end

-- A drop radio group ("Label: item" rows) as one row.
local function DropRow(parent, group)
    local rows, words, first = {}, {}, nil
    for _, entry in ipairs(ns.TOGGLES) do
        if entry.radio == group then
            first = first or entry
            local item = entry[2]:match(":%s*(.+)$") or entry[2]
            rows[#rows + 1] = { key = entry[1], text = (item:gsub("^%l", string.upper)) }
            words[#words + 1] = item .. " " .. (entry.search or "")
        end
    end
    local label = first and first[2]:match("^(.-):") or group
    local row = DropShell(parent, label, function(root)
        for _, choice in ipairs(rows) do root:CreateRadio(choice.text, ToggleOn, PickToggle, choice.key) end
    end)
    Describe(row, group, label, first and first[3])
    row.keyLow = row.keyLow .. " " .. table.concat(words, " "):lower()
    return row
end

local function FlipToggle(key)
    ns.db[key] = ns.db[key] ~= true
    ns.ToggleChanged(key)
end

-- Several toggles picked in one drop down, as checks (entries with checks = group).
local function DropCheckRow(parent, group)
    local rows, words, first = {}, {}, nil
    for _, entry in ipairs(ns.TOGGLES) do
        if entry.checks == group then
            first = first or entry
            local item = entry[2]:match(":%s*(.+)$") or entry[2]
            rows[#rows + 1] = { key = entry[1], text = item }
            words[#words + 1] = item .. " " .. (entry.search or "")
        end
    end
    local label = first and first[2]:match("^(.-):") or group
    local row = DropShell(parent, label, function(root)
        for _, choice in ipairs(rows) do root:CreateCheckbox(choice.text, ToggleOn, FlipToggle, choice.key) end
    end)
    Describe(row, group, label, first and first[3])
    row.keyLow = row.keyLow .. " " .. table.concat(words, " "):lower()
    return row
end

-- A setting holding one of a list's keys (choices: { key, label }); apply(key, pick) saves and shows it.
-- preview(key) shows a choice while it is hovered, preview(nil) the setting again once the menu shuts.
local function ValueDropRow(parent, key, label, tooltip, choices, apply, preview)
    local row, shut
    local function Hover(choice)
        preview(choice)
        shut = shut or ns.Sched.Job({ name = "options.preview." .. key, every = 0.2, awake = false, fn = function()
            if row.dropdown:IsMenuOpen() then return end
            preview(nil)
            shut:Sleep()
        end })
        shut:Wake()
    end
    row = DropShell(parent, label, function(root)
        for _, choice in ipairs(choices) do
            local item = root:CreateRadio(choice.label, function(pick) return ns.db[key] == pick end,
                function(pick) apply(key, pick) end, choice.key)
            if preview and item and item.SetOnEnter then
                item:SetOnEnter(function() Hover(choice.key) end)
                item:SetOnLeave(function() preview(nil) end)
            end
        end
    end)
    Describe(row, key, label, tooltip)
    return row
end

-- A group's title over its toggles, in the old gold.
local function GroupHead(parent, title, width)
    local head = ns.NewFrame("Frame", nil, parent)
    head:SetSize(width, ROW)
    local text = head:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", 2, 4)
    text:SetText(title)
    head:Hide()
    return head
end

-- Tabs under the window: toggles, then panes (profiles, FAQ, support); the one list scroll frame shows the tab's rows.
local TAB_NAMES = { "OPTWIN_TAB_TOGGLES", "OPTWIN_TAB_PROFILES", "OPTWIN_TAB_FAQ", "OPTWIN_TAB_SUPPORT" }
-- The tab row under the window's foot: the art's top rows are clear, so they tuck behind our border, not under it.
local SETTINGS_TABS_X = 11
local SETTINGS_TABS_Y = 5
local SETTINGS_TABS_GAP = -16
-- The reading tabs (profiles, FAQ, support) have no foot: their list runs down to this far over the window's bottom.
local LIST_BOTTOM_MARGIN = 20
local function AddTabs(frame, list, child, togglesOnly, listRows)
    local function SetRange(height) frame.listBar:SetRange(math.max(0, height - list:GetHeight()), ROW) end
    local function FitList(toggles)
        local height = listRows * ROW
        local top, bottom = list:GetTop(), frame:GetBottom()
        if not toggles and top and bottom then height = math.max(height, top - bottom - LIST_BOTTOM_MARGIN) end
        list:SetHeight(height)
    end
    local panes = {
        [2] = O.ProfilesPane(frame, frame.search, list, SetRange, OPTION_TIP),
        [3] = O.FaqPane(frame, frame.search, list, SetRange),
        [4] = O.SupportPane(frame, frame.search, list, SetRange),
    }
    local tabs = {}
    local function Show(which)
        frame.tab = which
        local toggles = which == 1
        for _, widget in ipairs(togglesOnly) do widget:SetShown(toggles) end
        FitList(toggles)
        for i, pane in pairs(panes) do
            pane:SetShown(i == which)
            pane.child:SetShown(i == which)
        end
        list:SetScrollChild(toggles and child or panes[which].child)
        frame.listBar:SetValue(0)
        if toggles then frame:PlaceBoxes(frame.search:GetText()) else panes[which]:Refresh() end
        for i, tab in ipairs(tabs) do
            if i == which then PanelTemplates_SelectTab(tab) else PanelTemplates_DeselectTab(tab) end
        end
    end
    -- On their own holder: the bottom tab skin lifts tabs anchored to their parent onto a client window's metal.
    local holder = ns.NewFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    for i, name in ipairs(TAB_NAMES) do
        local tab = ns.NewFrame("Button", nil, holder, "PanelTabButtonTemplate")
        tab:SetText(L[name])
        if i == 1 then
            tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", SETTINGS_TABS_X, SETTINGS_TABS_Y)
        else
            tab:SetPoint("LEFT", tabs[i - 1], "RIGHT", SETTINGS_TABS_GAP, 0)
        end
        ns.SkinBottomTab(tab)
        tab:SetScript("OnClick", function() Show(i) end)
        tabs[i] = tab
    end
    frame.panes = panes
    Show(1)
end

-- Built at most twice: the standalone dialog and the Settings canvas.
local function Build(canvas)
    local width = canvas and (canvas:GetWidth() or WIDTH) or WIDTH
    if width < WIDTH then width = WIDTH end
    local listRows = canvas and LIST_ROWS + 6 or LIST_ROWS
    local frame = canvas
    if not frame then
        -- HIGH, not DIALOG: on edit mode's strata its panel backing drew over our boxes.
        frame = O.DialogWindow("ForeverClassicUIOptions", 0, "HIGH", TOPLEVEL)
        -- The old backdrop is see-through; a dark fill keeps the list readable.
        local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        fill:SetColorTexture(0.03, 0.03, 0.03, 0.45)
        fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 11, -12)
        fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 11)
        ns.DialogHeader(frame, TITLE)
        ns.DialogClose(frame, function() frame:Hide() end)
    end

    -- Two scrolling columns, children indented; the bulk buttons sit between search and list.
    local LIST_TOP, LIST_W = canvas and -76 or -110, width - 70
    local list = ns.NewFrame("ScrollFrame", nil, frame)
    list:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, LIST_TOP)
    list:SetSize(LIST_W, listRows * ROW)
    list:SetClipsChildren(true)
    local child = ns.NewFrame("Frame", nil, list)
    child:SetSize(LIST_W, 1)
    list:SetScrollChild(child)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) frame.listBar:SetValue(frame.listBar:GetValue() - delta * ROW) end)
    frame.listBar = ns.ClassicScrollBar(frame, list, function(value) list:SetVerticalScroll(value) end)
    -- No arrows with nothing to scroll (a short profile list).
    frame.listBar.hideWhenIdle = true
    frame.list, frame.listChild = list, child

    -- boxes in list order; kids[key]: the rows under that key, in order; parentOf and depthOf by key (rows nest).
    local boxes, kids, parentOf, depthOf = {}, {}, {}, {}
    frame.boxes = boxes
    local function Add(row, parent)
        row.parent = parent
        row.depth = parent and ((depthOf[parent] or 0) + 1) or 0
        parentOf[row.key], depthOf[row.key] = parent, row.depth
        boxes[#boxes + 1] = row
        if parent then
            local under = kids[parent]
            if not under then
                under = {}
                kids[parent] = under
            end
            under[#under + 1] = row
        end
    end
    -- heads[title]: the group's header row; a row's group is the last one named above it, and search finds it by that too.
    local heads, group, dropped = {}, nil, {}
    local function Grouped(row)
        row.group = group
        if group then row.keyLow = row.keyLow .. " " .. group:lower() end
    end
    -- A stepper or a value drop down row under parent's toggle; words add to what search finds.
    local function ExtraStep(parent, key, label, tip, low, high, apply, words)
        local row = Stepper(child, key, label, tip, low, high, apply)
        row.text:SetWidth(LIST_W / COLUMNS - 70 - INDENT)
        if words then row.keyLow = row.keyLow .. " " .. words end
        Grouped(row)
        Add(row, parent)
    end
    local function ExtraDrop(parent, key, label, tip, choices, apply, words, depth, preview)
        local row = ValueDropRow(child, key, label, tip, choices, apply, preview)
        row.text:SetWidth(LIST_W / COLUMNS - 14 - DROP_W - (depth or 1) * INDENT)
        row.keyLow = row.keyLow .. " " .. words
        Grouped(row)
        Add(row, parent)
    end
    for _, entry in ipairs(ns.TOGGLES) do
        if entry.group then
            group = entry.group
            heads[group] = heads[group] or GroupHead(child, group, LIST_W / COLUMNS - 8)
        end
        local dropGroup = entry.checks or entry.radio
        if entry.drop and not dropped[dropGroup] then
            dropped[dropGroup] = true
            local row = entry.checks and DropCheckRow(child, dropGroup) or DropRow(child, dropGroup)
            Grouped(row)
            Add(row, entry.parent)
            row.text:SetWidth(LIST_W / COLUMNS - 14 - DROP_W - row.depth * INDENT)
        elseif not entry.drop then
            local box = Checkbox(child, entry[1], entry[2], entry[3], entry.radio)
            if entry.search then box.keyLow = box.keyLow .. " " .. entry.search:lower() end
            Grouped(box)
            Add(box, entry.parent)
            box.text:SetWidth(LIST_W / COLUMNS - 30 - box.depth * INDENT)
        end
        -- Settings under their toggle; not toggles, so the bulk buttons skip them.
        if entry[1] == "oneBag" then
            ExtraStep("oneBag", "oneBagColumns", L["OPTWIN_COLUMNS"], L["OPTWIN_HOW_MANY_SLOTS_ACROSS_THE"],
                ns.ONE_BAG_COLUMNS_MIN or 4, ns.ONE_BAG_COLUMNS_MAX or 16, ns.SetOneBagColumns)
        end
        if entry[1] == "hideKeyText" then
            ExtraStep("buttons", "keyTextSize", L["OPTWIN_KEY_TEXT_SIZE"], L["OPTWIN_HOW_BIG_THE_KEY_NAMES"],
                ns.KEY_TEXT_MIN or 8, ns.KEY_TEXT_MAX or 20, ns.SetKeyTextSize, "keybind font hotkey")
        end
        if entry[1] == "themeCustom" then
            local color = ColorRow(child, "themeColor", L["OPTWIN_COLOUR"],
                L["OPTWIN_THE_CUSTOM_THEME_S_COLOUR"])
            color.text:SetWidth(LIST_W / COLUMNS - 40 - INDENT)
            color.keyLow = color.keyLow .. " rgb hex color theme"
            Grouped(color)
            Add(color, "themeCustom")
        end
        if entry[1] == "damageMeter" and ns.METER_BACKGROUNDS then
            ExtraDrop("damageMeter", "meterBackground", L["OPTWIN_BACKGROUND"], L["OPTWIN_THE_METER_S_BACK_THE"],
                ns.METER_BACKGROUNDS, ns.SetMeterBackground, "talent tree damage meter", nil, ns.PreviewMeterBackground)
            ExtraStep("damageMeter", "meterHeader", L["OPTWIN_HEADER_HEIGHT"], L["OPTWIN_EXTRA_HEIGHT_OVER_THE_METER"],
                ns.METER_HEADER_MIN or 0, ns.METER_HEADER_MAX or 16, ns.SetMeterHeader, "damage meter title")
            local pan = ButtonRow(child, "meterPanArt", L["OPT_meterPanArt"], L["OPT_meterPanArt_TIP"],
                function() ns.SetMeterPanning(not ns.MeterPanning()) end, ns.MeterPanning,
                { "meterPanPreview", L["OPT_meterPanPreview"], L["OPT_meterPanPreview_TIP"], ns.SetMeterBackground })
            pan.keyLow = pan.keyLow .. " drag align background art whole preview"
            Grouped(pan)
            Add(pan, "damageMeter")
        end
        if entry[1] == "thickHealthMana" and ns.ENEMY_HEALTH_COLORS then
            ExtraDrop("thickHealth", "thickEnemyColor", L["OPTWIN_ENEMY_HEALTH"], L["OPTWIN_THE_COLOUR_OF_AN_ENEMY"],
                ns.ENEMY_HEALTH_COLORS, ns.SetEnemyHealthColor, "colour color hostile red", 2)
        end
        if entry[1] == "unitFrames" and ns.SetUnitNameSize then
            ExtraStep("unitFrames", "unitNameSize", L["OPTWIN_NAME_SIZE"], L["OPTWIN_TEXT_SIZE_OF_THE_PLAYER"],
                ns.UNIT_NAME_MIN or 8, ns.UNIT_NAME_MAX or 16, ns.SetUnitNameSize, "font unit frame name text")
        end
        if entry[1] == "resourceDisplay" and ns.SetPrdGap then
            ExtraStep("resourceDisplay", "prdGap", L["OPTWIN_BAR_GAP"], L["OPTWIN_SPACE_BETWEEN_THE_HEALTH_AND"],
                ns.PRD_GAP_MIN or 0, ns.PRD_GAP_MAX or 20, ns.SetPrdGap, "personal resource padding spacing")
        end
        if entry[1] == "swingTimers" and ns.SWING_COLORS then
            for _, hand in ipairs(SWING_HANDS) do
                ExtraDrop("swingTimers", hand[1], hand[2], L["OPTWIN_THE_SWING_BAR_S_COLOUR"], ns.SWING_COLORS,
                    ns.SetSwingLook, "swing colour color")
            end
            ExtraStep("swingTimers", "swingBorder", L["OPTWIN_BORDER_THICKNESS"], L["OPTWIN_HOW_THICK_THE_SWING_BARS"],
                ns.SWING_BORDER_MIN or -1, ns.SWING_BORDER_MAX or 5, ns.SetSwingBorder, "swing")
        end
        if entry[1] == "classColorPlates" then
            ExtraStep("namePlates", "plateNameSize", L["OPTWIN_NAME_TEXT_SIZE"], L["OPTWIN_POINTS_BIGGER_OR_SMALLER_THAN"],
                ns.PLATE_NAME_MIN or -6, ns.PLATE_NAME_MAX or 6, ns.SetPlateNameSize, "font")
        end
    end

    -- Word starts in name, keywords or section title first, tooltip only when nothing matched those; whole sections show,
    -- their matches lit and the rest dimmed; empty shows all.
    local search = ns.SearchBox(frame, width - 60, L["OPTWIN_SEARCH_TOGGLES"])
    search:SetPoint("TOP", frame, "TOP", 4, canvas and -16 or -50)
    frame.search = search

    function frame:PlaceBoxes(text)
        text = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        local words = {}
        for word in text:gmatch("%S+") do words[#words + 1] = word:gsub("%p", "%%%0") end
        -- The best level any row reaches decides which rows count as matches.
        local level, best = {}, 0
        for _, box in ipairs(boxes) do
            level[box] = #words > 0 and ns.OptionMatchLevel(box, words) or 0
            if level[box] > best then best = level[box] end
        end
        -- A section shows whole or not at all: any match brings its top row and every line under it.
        local hit, matched = {}, {}
        local function MarkAll(key)
            hit[key] = true
            for _, other in ipairs(kids[key] or EMPTY) do MarkAll(other.key) end
        end
        for _, box in ipairs(boxes) do
            matched[box] = best > 0 and level[box] == best
            if text == "" or matched[box] then
                local head = box.key
                while parentOf[head] do head = parentOf[head] end
                MarkAll(head)
            end
        end
        -- Sections in list order, head first, gathered under their group's header; a block is one header and its rows.
        local blocks, byTitle, count = {}, {}, 0
        -- Every row under key, depth first.
        local function AddKids(block, key)
            for _, other in ipairs(kids[key] or EMPTY) do
                if hit[other.key] then
                    block[#block + 1] = other
                    block.rows = block.rows + 1
                    count = count + 1
                    AddKids(block, other.key)
                end
            end
        end
        for _, box in ipairs(boxes) do
            if not hit[box.key] then
                box:Hide()
            elseif not box.parent then
                local title = box.group or ""
                local block = byTitle[title]
                if not block then
                    block = { head = heads[title], rows = heads[title] and 1 or 0 }
                    byTitle[title] = block
                    blocks[#blocks + 1] = block
                    count = count + block.rows
                end
                block[#block + 1] = box
                block.rows = block.rows + 1
                count = count + 1
                AddKids(block, box.key)
            end
        end
        for title, head in pairs(heads) do
            if not byTitle[title] then head:Hide() end
        end
        -- Column-major, whole groups in order: split where the taller column is shortest.
        local split, shortest, before = #blocks, math.huge, 0
        for i = 0, #blocks do
            if i > 0 then before = before + blocks[i].rows end
            local taller = math.max(before, count - before)
            if taller < shortest then split, shortest = i, taller end
        end
        local colW = LIST_W / COLUMNS
        local column, row, per = 0, 0, 0
        local function Put(row_, box, x)
            ns.SetPointOnce(box, "TOPLEFT", self.listChild, "TOPLEFT", column * colW + x, -row_ * ROW)
            box:Show()
            if box.keyLow then
                ns.SetAlphaIf(box, (text == "" or matched[box]) and 1 or MATCH_DIM)
                ShowMatch(box, text ~= "" and matched[box] == true)
            end
        end
        for i, block in ipairs(blocks) do
            if column < COLUMNS - 1 and i == split + 1 and row > 0 then
                column, row = column + 1, 0
            end
            if block.head then
                Put(row, block.head, 0)
                row = row + 1
            end
            for _, box in ipairs(block) do
                Put(row, box, (box.depth or 0) * INDENT)
                row = row + 1
            end
            if row > per then per = row end
        end
        self.listChild:SetHeight(math.max(1, per * ROW))
        self.listBar:SetRange(math.max(0, per * ROW - listRows * ROW), ROW)
        self.search.hint:SetShown(text == "")
        self.search.clear:SetShown(text ~= "")
    end
    search:SetScript("OnTextChanged", function(self) frame:PlaceBoxes(self:GetText()) end)
    frame:PlaceBoxes("")

    local note = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    note:SetPoint("BOTTOM", frame, "BOTTOM", 0, 78)
    note:SetTextColor(1, 0.35, 0.25)
    frame.note = note

    -- Bulk writes skip ToggleChanged's per-key side effects on purpose; the reload ask runs before Refresh reads it.
    local none = ns.PanelButton(frame, L["OPTWIN_TOGGLE_NONE"], 100)
    none:SetPoint("TOPRIGHT", search, "BOTTOM", -3, -6)
    none:SetScript("OnClick", function()
        for _, entry in ipairs(ns.TOGGLES) do
            if InNone(entry[1]) then ns.db[entry[1]] = false end
        end
        ns.ApplyAll()
        ns.AskReloadIfNeeded()
        frame:Refresh()
    end)
    none.tooltip = L["OPTWIN_TURNS_EVERY_PIECE_OF_THE"]
    none.label = L["OPTWIN_TOGGLE_NONE"]
    ns.AttachTip(none, OPTION_TIP)

    local defaults = ns.PanelButton(frame, L["OPTWIN_RESET_TOGGLES"], 100)
    defaults:SetPoint("TOPLEFT", search, "BOTTOM", 3, -6)
    defaults:SetScript("OnClick", function()
        for _, entry in ipairs(ns.TOGGLES) do
            ns.db[entry[1]] = ns.DB_DEFAULTS[entry[1]]
        end
        -- The number rows too, through their setters so they apply live.
        if ns.SetKeyTextSize then ns.SetKeyTextSize(ns.DB_DEFAULTS.keyTextSize) end
        if ns.SetOneBagColumns then ns.SetOneBagColumns(ns.DB_DEFAULTS.oneBagColumns) end
        if ns.SetPlateNameSize then ns.SetPlateNameSize(ns.DB_DEFAULTS.plateNameSize) end
        ns.ApplyAll()
        ns.AskReloadIfNeeded()
        frame:Refresh()
    end)
    defaults.tooltip = L["OPTWIN_PUTS_EVERY_CHECKBOX_AND_NUMBER"]
    defaults.label = L["OPTWIN_RESET_TOGGLES"]
    ns.AttachTip(defaults, OPTION_TIP)
    -- The foot joins this list once built: the other tabs are reading, not settings.
    local togglesOnly = { search, none, defaults, child }
    AddTabs(frame, list, child, togglesOnly, listRows)

    -- Foot left: layout button over Reload UI; on the classic layout it offers a reset.
    local layout = ns.PanelButton(frame, L["OPTWIN_CLASSIC_LAYOUT"], 130)
    layout:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 26, 46)
    layout:SetScript("OnClick", function()
        if ns.ClassicLayoutActive() then
            StaticPopup_Show("FCUI_LAYOUT_RESET")
        else
            ns.CreateClassicLayout()
        end
    end)
    layout.tooltip = L["OPTWIN_ADDS_AN_EDIT_MODE_LAYOUT"]
    layout.label = L["OPTWIN_CLASSIC_LAYOUT"]
    ns.AttachTip(layout, OPTION_TIP)

    local reload = ns.PanelButton(frame, L["OPTWIN_RELOAD_UI"], 130)
    reload:SetPoint("TOPLEFT", layout, "BOTTOMLEFT", 0, -4)
    reload:SetScript("OnClick", function() StaticPopup_Show("FCUI_RELOAD_CONFIRM") end)

    -- Foot right: feedback buttons, GitHub first (preferred), CurseForge under it.
    local curse, github = O.FeedbackButtons(frame, 130)
    github:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 46)
    github.tooltip = L["OPTWIN_COPIES_THE_ADDRESS_OF_THE"]
    github.label = L["OPTWIN_GITHUB_ISSUES"]
    ns.AttachTip(github, OPTION_TIP)
    curse:SetPoint("TOPRIGHT", github, "BOTTOMRIGHT", 0, -4)
    curse.tooltip = L["OPTWIN_COPIES_THE_ADDON_S_CURSEFORGE"]
    curse.label = L["OPTWIN_CURSEFORGE"]
    ns.AttachTip(curse, OPTION_TIP)
    local preferred = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    preferred:SetPoint("BOTTOMLEFT", github, "TOPLEFT", 2, 3)
    preferred:SetText(L["OPTWIN_PREFERRED"])
    -- A font string takes no mouse: a frame over it carries the tip.
    local preferredHover = ns.NewFrame("Frame", nil, frame)
    preferredHover:SetAllPoints(preferred)
    preferredHover:EnableMouse(true)
    ns.AttachTip(preferredHover, PREFERRED_TIP)
    local status = ns.PanelButton(frame, L["OPTWIN_STATUS_REPORT"], 130)
    status:SetPoint("RIGHT", github, "LEFT", -6, 0)
    status:SetScript("OnClick", function() ns.ShowStatus() end)
    status.tooltip = L["OPTWIN_OPENS_A_WINDOW_WITH_YOUR"]
    status.label = L["OPTWIN_STATUS_REPORT"]
    ns.AttachTip(status, OPTION_TIP)
    local feedback = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    feedback:SetPoint("BOTTOM", github, "TOP", 0, 18)
    feedback:SetText(L["OPTWIN_BUG_REPORTS_FEEDBACK"])
    for _, piece in ipairs({ note, layout, reload, curse, github, preferred, preferredHover, status, feedback }) do
        togglesOnly[#togglesOnly + 1] = piece
    end

    if not canvas then frame:SetSize(WIDTH, 110 + LIST_ROWS * ROW + 108) end

    function frame:Refresh()
        -- The one box mirroring a game setting: read fresh.
        ns.ReadGameDamageNumbers()
        for _, box in ipairs(self.boxes) do
            box:SetChecked(ns.db[box.key] ~= false)
            -- Disabled and grayed under any parent that is off.
            local on, up = true, box.parent
            while up do
                if ns.db[up] == false then on = false break end
                up = parentOf[up]
            end
            box:SetEnabled(on)
            -- A button row's label keeps the button's own fonts.
            if not box.button then box.text:SetFontObject(on and "GameFontHighlight" or "GameFontDisable") end
        end
        -- Same source as the reload prompt: a change still owed a reload.
        local owed = ns.ReloadOwed()
        self.note:SetText(owed and L["OPTWIN_RELOAD_THE_INTERFACE_TO_FINISH"] or "")
        local pane = self.panes and self.panes[self.tab]
        if pane then pane:Refresh() end
    end
    frame:SetScript("OnShow", frame.Refresh)
    frame:HookScript("OnHide", function() if ns.SetMeterPanning then ns.SetMeterPanning(false) end end)
    -- After SetScript, which would wipe its OnShow hooks.
    if not canvas then ns.CloseOnEscape(frame) end
    return frame
end

-- Settings page canvas, built once.
function ns.OptionsCanvas()
    if ns.optionsCanvas then return ns.optionsCanvas end
    local canvas = CreateFrame("Frame", "ForeverClassicUIOptionsCanvas", UIParent)
    canvas:SetSize(620, 560)
    canvas:Hide()
    ns.optionsCanvas = Build(canvas)
    return ns.optionsCanvas
end

-- A toggle changed from outside the panel; either copy may be missing.
function ns.RefreshOptionsWindow()
    if window and window:IsShown() then window:Refresh() end
    local canvas = ns.optionsCanvas
    if canvas and canvas:IsShown() then canvas:Refresh() end
end

function ns.OpenOptions()
    if not window then window = Build() end
    if window:IsShown() then
        window:Hide()
    else
        window:Show()
    end
end
