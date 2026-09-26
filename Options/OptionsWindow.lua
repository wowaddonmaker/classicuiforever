local _, ns = ...

-- The /fcui options dialog (ticked is the classic look), also the Settings page canvas.

local O = ns.options
local TITLE = O.TITLE
local EMPTY = ns.EMPTY
local WIDTH, ROW = 470, 24
local LIST_ROWS, INDENT, COLUMNS = 10, 22, 2
local P, C = ns.ART.PANEL_BUTTON, ns.ART.CHECK
local BTN = "Interface\\Buttons\\UI-"
local PANEL_COORDS = ns.RED_COORDS
-- Raw paths: no bronze swap.
local PANEL_RAW = { set = "raw", coords = PANEL_COORDS, add = true }
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

-- Not part of the classic look, so Toggle none leaves them (the minimap button leads back here), nor the radio picks.
local NOT_IN_NONE = { minimapButton = true, welcomeNote = true }
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

function ns.PanelButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 96, 22)
    local ok = button:SetNormalTexture(P .. "Up")
    if ok == false then
        -- Old sheet missing on this client: fall back to the modern button.
        button:Hide()
        button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetSize(width or 96, 22)
        button:SetText(text)
        return button
    end
    -- Disabled is gray like the old buttons, not a red face.
    ns.DressStates(button, nil, P .. "Down", P .. "Disabled", P .. "Highlight", PANEL_RAW)
    local label = button:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(ns.FONT_GOLD or "GameFontNormal")
    label:SetPoint("CENTER", 0, -1)
    label:SetText(text)
    button:SetFontString(label)
    -- Normal font set too or the highlight font sticks after leave; old gold, not bronze.
    button:SetNormalFontObject(ns.FONT_GOLD or "GameFontNormal")
    button:SetDisabledFontObject("GameFontDisable")
    button:SetHighlightFontObject("GameFontHighlight")
    return button
end

-- Lowercased once for the search: the name side (label, keywords, its section's title) and the tooltip.
local function Describe(row, key, label, tooltip)
    row.key, row.label, row.tooltip = key, label, tooltip
    row.keyLow, row.tipLow = label:lower(), (tooltip or ""):lower()
    ns.AttachTip(row, OPTION_TIP)
end

-- Every query word starts a word of text: "ring" finds rings, never hovering.
local function WordsIn(text, words)
    for i = 1, #words do
        if not text:find("%f[%w]" .. words[i]) then return false end
    end
    return true
end

-- 2: the name side has every word; 1: only with the tooltip; 0: no.
local function MatchLevel(box, words)
    if WordsIn(box.keyLow, words) then return 2 end
    if WordsIn(box.keyLow .. " " .. box.tipLow, words) then return 1 end
    return 0
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
    local button = CreateFrame("Button", nil, row)
    button:SetSize(16, 16)
    button:SetPoint("LEFT", row, "LEFT", x, 0)
    ns.DressStates(button, BTN .. kind .. "Button-Up", BTN .. kind .. "Button-Down", BTN .. kind .. "Button-Disabled", ns.ART.PLUS_GLOW, RAW_ADD)
    return button
end

-- Number row (minus, value, plus, label) with the checkbox methods, so the list treats it alike.
local function Stepper(parent, key, label, tooltip, low, high, apply)
    local row = CreateFrame("Frame", nil, parent)
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

-- ToggleChanged refreshes whichever copy of the panel is shown; a radio row only turns on.
local function BoxClick(self)
    ns.db[self.key] = (self.radio or self:GetChecked()) and true or false
    ns.ToggleChanged(self.key)
end

local function Checkbox(parent, key, label, tooltip, radio)
    local box = CreateFrame("CheckButton", nil, parent)
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

-- A group's title over its toggles, in the old gold.
local function GroupHead(parent, title, width)
    local head = CreateFrame("Frame", nil, parent)
    head:SetSize(width, ROW)
    local text = head:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", 2, 4)
    text:SetText(title)
    head:Hide()
    return head
end

-- Tabs under the window, toggles and profiles: the one list scroll frame shows either tab's rows.
local TAB_NAMES = { "Toggles", "Profiles" }
local function AddTabs(frame, list, child, togglesOnly, listRows)
    local function SetRange(height) frame.listBar:SetRange(math.max(0, height - listRows * ROW), ROW) end
    local profiles = O.ProfilesPane(frame, frame.search, list, SetRange, OPTION_TIP)
    local tabs = {}
    local function Show(which)
        frame.tab = which
        local toggles = which == 1
        for _, widget in ipairs(togglesOnly) do widget:SetShown(toggles) end
        profiles:SetShown(not toggles)
        profiles.child:SetShown(not toggles)
        list:SetScrollChild(toggles and child or profiles.child)
        frame.listBar:SetValue(0)
        if toggles then frame:PlaceBoxes(frame.search:GetText()) else profiles:Refresh() end
        for i, tab in ipairs(tabs) do
            if i == which then PanelTemplates_SelectTab(tab) else PanelTemplates_DeselectTab(tab) end
        end
    end
    -- On their own holder: the bottom tab skin lifts tabs anchored to their parent onto a client window's metal.
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    for i, name in ipairs(TAB_NAMES) do
        local tab = CreateFrame("Button", nil, holder, "PanelTabButtonTemplate")
        tab:SetText(name)
        if i == 1 then
            tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 11, 2)
        else
            tab:SetPoint("LEFT", tabs[i - 1], "RIGHT", -16, 0)
        end
        ns.SkinBottomTab(tab)
        tab:SetScript("OnClick", function() Show(i) end)
        tabs[i] = tab
    end
    frame.profiles = profiles
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
    local list = CreateFrame("ScrollFrame", nil, frame)
    list:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, LIST_TOP)
    list:SetSize(LIST_W, listRows * ROW)
    list:SetClipsChildren(true)
    local child = CreateFrame("Frame", nil, list)
    child:SetSize(LIST_W, 1)
    list:SetScrollChild(child)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) frame.listBar:SetValue(frame.listBar:GetValue() - delta * ROW) end)
    frame.listBar = ns.ClassicScrollBar(frame, list, function(value) list:SetVerticalScroll(value) end)
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
    local heads, group = {}, nil
    local function Grouped(row)
        row.group = group
        if group then row.keyLow = row.keyLow .. " " .. group:lower() end
    end
    for _, entry in ipairs(ns.TOGGLES) do
        if entry.group then
            group = entry.group
            heads[group] = heads[group] or GroupHead(child, group, LIST_W / COLUMNS - 8)
        end
        local box = Checkbox(child, entry[1], entry[2], entry[3], entry.radio)
        if entry.search then box.keyLow = box.keyLow .. " " .. entry.search:lower() end
        Grouped(box)
        Add(box, entry.parent)
        box.text:SetWidth(LIST_W / COLUMNS - 30 - box.depth * INDENT)
        -- One bag width stepper; not a toggle, so the bulk buttons skip it.
        if entry[1] == "oneBag" then
            local columns = Stepper(child, "oneBagColumns", "Columns",
                "How many slots across the one bag window is. The old bags were four across.",
                ns.ONE_BAG_COLUMNS_MIN or 4, ns.ONE_BAG_COLUMNS_MAX or 16, ns.SetOneBagColumns)
            columns.text:SetWidth(LIST_W / COLUMNS - 70 - INDENT)
            Grouped(columns)
            Add(columns, "oneBag")
        end
    end

    -- Word starts in name, keywords or section title first, tooltip only when nothing matched those; whole sections show,
    -- their matches lit and the rest dimmed; empty shows all.
    local search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    search:SetSize(width - 60, 20)
    search:SetPoint("TOP", frame, "TOP", 4, canvas and -16 or -50)
    search:SetAutoFocus(false)
    search:SetFontObject("ChatFontNormal")
    search:SetMaxLetters(40)
    -- The client's input edges are bronze; silver off the theme, as every other box.
    ns.DrainInput(search)
    local hint = search:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    hint:SetPoint("LEFT", search, "LEFT", 2, 0)
    hint:SetText("Search toggles")
    search.hint = hint
    frame.search = search
    -- The X clears it; shown only while there is text.
    local clear = ns.SearchClear(search)
    search.clear = clear

    function frame:PlaceBoxes(text)
        text = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        local words = {}
        for word in text:gmatch("%S+") do words[#words + 1] = word:gsub("%p", "%%%0") end
        -- The best level any row reaches decides which rows count as matches.
        local level, best = {}, 0
        for _, box in ipairs(boxes) do
            level[box] = #words > 0 and MatchLevel(box, words) or 0
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
        -- Column-major: column 1 takes whole groups until the next would pass half.
        local half = math.max(1, math.ceil(count / COLUMNS))
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
        for _, block in ipairs(blocks) do
            if column < COLUMNS - 1 and row > 0 and row + block.rows > half then
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
    search:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    frame:PlaceBoxes("")

    local note = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    note:SetPoint("BOTTOM", frame, "BOTTOM", 0, 78)
    note:SetTextColor(1, 0.35, 0.25)
    frame.note = note

    -- Bulk writes skip ToggleChanged's per-key side effects on purpose; the reload ask runs before Refresh reads it.
    local none = ns.PanelButton(frame, "Toggle none", 100)
    none:SetPoint("TOPRIGHT", search, "BOTTOM", -3, -6)
    none:SetScript("OnClick", function()
        for _, entry in ipairs(ns.TOGGLES) do
            if InNone(entry[1]) then ns.db[entry[1]] = false end
        end
        ns.ApplyAll()
        ns.AskReloadIfNeeded()
        frame:Refresh()
    end)
    none.tooltip = "Turns every piece of the classic look off, to see the game's own interface without disabling the addon. Reset toggles brings the defaults back; a profile keeps a set of your own."
    none.label = "Toggle none"
    ns.AttachTip(none, OPTION_TIP)

    local defaults = ns.PanelButton(frame, "Reset toggles", 100)
    defaults:SetPoint("TOPLEFT", search, "BOTTOM", 3, -6)
    defaults:SetScript("OnClick", function()
        local wasBig = ns.db.defaultBarSize == true
        for _, entry in ipairs(ns.TOGGLES) do
            ns.db[entry[1]] = ns.DB_DEFAULTS[entry[1]]
        end
        -- The bar size also set the icon counts; turning it off puts them back.
        if wasBig and ns.db.defaultBarSize ~= true then ns.FitBarsToSize(false) end
        ns.ApplyAll()
        ns.AskReloadIfNeeded()
        frame:Refresh()
    end)
    defaults.tooltip = "Puts every checkbox back to its default. Nothing to do with edit mode layouts."
    defaults.label = "Reset toggles"
    ns.AttachTip(defaults, OPTION_TIP)
    AddTabs(frame, list, child, { search, none, defaults, child }, listRows)

    -- Foot left: layout button over Reload UI; on the classic layout it offers a reset.
    local layout = ns.PanelButton(frame, "Classic layout", 130)
    layout:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 26, 46)
    layout:SetScript("OnClick", function()
        if ns.ClassicLayoutActive() then
            StaticPopup_Show("FCUI_LAYOUT_RESET")
        else
            ns.CreateClassicLayout()
        end
    end)
    layout.tooltip = "Adds an edit mode layout with every bar in its 1.x place and switches to it. Your current layout and keybinds stay, and edit mode switches between layouts as ever. Once the classic layout is on, this button resets it to its defaults."
    layout.label = "Classic layout"
    ns.AttachTip(layout, OPTION_TIP)

    local reload = ns.PanelButton(frame, "Reload UI", 130)
    reload:SetPoint("TOPLEFT", layout, "BOTTOMLEFT", 0, -4)
    reload:SetScript("OnClick", function() ns.ReloadForLayout() end)

    -- Foot right: feedback buttons.
    local curse, github = O.FeedbackButtons(frame, 130)
    curse:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 46)
    curse.tooltip = "Copies the addon's CurseForge address, for comments and reports there."
    curse.label = "CurseForge"
    ns.AttachTip(curse, OPTION_TIP)
    github:SetPoint("TOPRIGHT", curse, "BOTTOMRIGHT", 0, -4)
    github.tooltip = "Copies the address of the GitHub issue tracker, for bug reports and requests."
    github.label = "GitHub issues"
    ns.AttachTip(github, OPTION_TIP)
    local status = ns.PanelButton(frame, "Status report", 130)
    status:SetPoint("RIGHT", curse, "LEFT", -6, 0)
    status:SetScript("OnClick", function() ns.ShowStatus() end)
    status.tooltip = "Opens a window with your addon version, game build, changed settings and other addons, to screenshot or copy into a bug report."
    status.label = "Status report"
    ns.AttachTip(status, OPTION_TIP)
    local feedback = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    feedback:SetPoint("BOTTOM", curse, "TOP", 0, 5)
    feedback:SetText("Bug reports/Feedback:")

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
            box.text:SetFontObject(on and "GameFontHighlight" or "GameFontDisable")
        end
        -- Same source as the reload prompt: a change still owed a reload.
        local owed = ns.ReloadOwed()
        self.note:SetText(owed and "Reload the interface to finish some of the changes you made." or "")
        if self.tab == 2 then self.profiles:Refresh() end
    end
    frame:SetScript("OnShow", frame.Refresh)
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
