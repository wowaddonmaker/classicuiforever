local _, ns = ...

-- The 1.x options dialog: the dialog box border and dark background, the
-- header plate with the title, one classic checkbox per module (checked
-- is the classic look, unchecked the modern one) and the old panel
-- buttons. This is what /fcui opens; the same toggles also live in the
-- game's own Settings window.

local TITLE = "ClassicUI Forever"
local WIDTH, ROW = 470, 24
local LIST_ROWS, INDENT, COLUMNS = 10, 22, 2
local DIALOG_BG = "Interface\\DialogFrame\\UI-DialogBox-Background"
local DIALOG_BORDER = "Interface\\DialogFrame\\UI-DialogBox-Border"
local DIALOG_HEADER = "Interface\\DialogFrame\\UI-DialogBox-Header"
local CHECK = "Interface\\Buttons\\UI-CheckBox-"
local PANEL_BUTTON = "Interface\\Buttons\\UI-Panel-Button-"

local window

function ns.PanelButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 96, 22)
    local ok = button:SetNormalTexture(PANEL_BUTTON .. "Up")
    if ok == false then
        -- The old button sheet is gone from this client: the modern button.
        button:Hide()
        button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetSize(width or 96, 22)
        button:SetText(text)
        return button
    end
    button:SetPushedTexture(PANEL_BUTTON .. "Down")
    -- Gray when it cannot be pressed, as the old buttons were; without
    -- this a disabled button kept the red face and only dimmed its words.
    button:SetDisabledTexture(PANEL_BUTTON .. "Disabled")
    button:SetHighlightTexture(PANEL_BUTTON .. "Highlight")
    for _, tex in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture(), button:GetHighlightTexture() }) do
        tex:SetTexCoord(0, 0.625, 0, 0.6875)
    end
    button:GetHighlightTexture():SetBlendMode("ADD")
    local label = button:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(ns.FONT_GOLD or "GameFontNormal")
    label:SetPoint("CENTER", 0, -1)
    label:SetText(text)
    button:SetFontString(label)
    -- The normal font must be named too, or the highlight font never
    -- gives the label back when the mouse leaves.
    -- The old gold, not the client's bronze normal font.
    button:SetNormalFontObject(ns.FONT_GOLD or "GameFontNormal")
    button:SetDisabledFontObject("GameFontDisable")
    button:SetHighlightFontObject("GameFontHighlight")
    return button
end

local function ShowTooltip(self)
    if not self.tooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.label, 1, 1, 1)
    GameTooltip:AddLine(self.tooltip, nil, nil, nil, true)
    GameTooltip:Show()
end

-- A row that holds a number instead of a tick: minus, the number, plus,
-- then the label. It stands in the list like a checkbox and answers to
-- the same calls, so the list places, searches and grays it the same.
local function Stepper(parent, key, label, tooltip, low, high, apply)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(24, 24)
    row.key, row.label, row.tooltip = key, label, tooltip
    local function Arrow(kind, x)
        local button = CreateFrame("Button", nil, row)
        button:SetSize(16, 16)
        button:SetPoint("LEFT", row, "LEFT", x, 0)
        button:SetNormalTexture("Interface\\Buttons\\UI-" .. kind .. "Button-Up")
        button:SetPushedTexture("Interface\\Buttons\\UI-" .. kind .. "Button-Down")
        button:SetDisabledTexture("Interface\\Buttons\\UI-" .. kind .. "Button-Disabled")
        button:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
        button:GetHighlightTexture():SetBlendMode("ADD")
        return button
    end
    row.minus = Arrow("Minus", 4)
    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.value:SetPoint("LEFT", row.minus, "RIGHT", 2, 0)
    row.value:SetWidth(20)
    row.value:SetJustifyH("CENTER")
    row.plus = Arrow("Plus", 42)
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
    row:SetScript("OnEnter", ShowTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function Checkbox(parent, key, label, tooltip)
    local box = CreateFrame("CheckButton", nil, parent)
    box:SetSize(24, 24)
    box:SetNormalTexture(CHECK .. "Up")
    box:SetPushedTexture(CHECK .. "Down")
    box:SetHighlightTexture(CHECK .. "Highlight")
    box:GetHighlightTexture():SetBlendMode("ADD")
    box:SetCheckedTexture(CHECK .. "Check")
    box:SetDisabledCheckedTexture(CHECK .. "Check-Disabled")
    box.key, box.label, box.tooltip = key, label, tooltip
    local text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", box, "RIGHT", 2, 1)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(label)
    box.text = text
    box:SetScript("OnEnter", ShowTooltip)
    box:SetScript("OnLeave", function() GameTooltip:Hide() end)
    box:SetScript("OnClick", function(self)
        ns.db[self.key] = self:GetChecked() and true or false
        ns.ToggleChanged(self.key)
        -- The panel this box belongs to: the standalone window, or the
        -- copy built into the game's settings, where there may be no
        -- standalone window yet and asking it to refresh was an error.
        local owner = self.owner or window
        if owner and owner.Refresh then owner:Refresh() end
    end)
    return box
end

-- The same panel twice: on its own as the old dialog, and inside the
-- game's settings window as that page's canvas, where it brings its
-- search and its columns with it.
local function Build(canvas)
    local width = canvas and (canvas:GetWidth() or WIDTH) or WIDTH
    if width < WIDTH then width = WIDTH end
    local listRows = canvas and LIST_ROWS + 6 or LIST_ROWS
    local frame = canvas
    if not frame then
        frame = CreateFrame("Frame", "ForeverClassicUIOptions", UIParent, "BackdropTemplate")
        frame:SetBackdrop({
            bgFile = DIALOG_BG, edgeFile = DIALOG_BORDER, tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        ns.BronzeBackdrop(frame)
        -- One strata below the client's own dialogs. On the same strata
        -- as edit mode's panels the two were sorted level by level, and
        -- this window's boxes and labels came out on top of a panel
        -- whose background covered the window itself.
        frame:SetFrameStrata("HIGH")
        frame:SetToplevel(true)
        -- The old dialog background is see-through by design, and over a
        -- busy scene the list of toggles was hard to read through it. A
        -- dark fill stands under it, inside the border.
        local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        fill:SetColorTexture(0.03, 0.03, 0.03, 0.45)
        fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 11, -12)
        fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 11)
        frame:SetPoint("CENTER")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetClampedToScreen(true)
        frame:Hide()

        local header = frame:CreateTexture(nil, "ARTWORK")
        ns.SetFile(header, DIALOG_HEADER)
        header:SetSize(256, 64)
        header:SetPoint("TOP", frame, "TOP", 0, 12)
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", header, "TOP", 0, -14)
        title:SetText(TITLE)

        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
        close:SetScript("OnClick", function() frame:Hide() end)
        if ns.SkinCloseButton then ns.SkinCloseButton(close, true) end
    end

    -- The toggles: one column in a scrolling list, a child toggle
    -- indented under its parent. The list shows LIST_ROWS at a time.
    -- The list starts a row lower than the search box alone would need:
    -- Toggle all and Reset toggles stand between the two.
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

    frame.boxes = {}
    local rows = {}
    for _, entry in ipairs(ns.TOGGLES) do rows[#rows + 1] = entry end
    for _, entry in ipairs(rows) do
        local box = Checkbox(child, entry[1], entry[2], entry[3])
        box.parent = entry.parent
        box.owner = frame
        box.text:SetWidth(LIST_W / COLUMNS - 30 - (entry.parent and INDENT or 0))
        frame.boxes[#frame.boxes + 1] = box
        -- How wide the one bag window is, right under its toggle. Not a
        -- toggle itself, so Toggle all and Reset toggles pass it by.
        if entry[1] == "oneBag" and ns.SetOneBagColumns then
            local columns = Stepper(child, "oneBagColumns", "One bag columns",
                "How many slots across the one bag window is. The old bags were four across; more makes the window wider and shorter.",
                ns.ONE_BAG_COLUMNS_MIN or 4, ns.ONE_BAG_COLUMNS_MAX or 16, ns.SetOneBagColumns)
            columns.parent = "oneBag"
            columns.owner = frame
            columns.text:SetWidth(LIST_W / COLUMNS - 70 - INDENT)
            frame.boxes[#frame.boxes + 1] = columns
        end
    end

    -- A search box above the list: typing keeps the toggles whose name
    -- or description holds the words, with their parents and children,
    -- stacked from the top; clearing it brings every toggle back.
    local search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    search:SetSize(width - 60, 20)
    search:SetPoint("TOP", frame, "TOP", 4, canvas and -16 or -50)
    search:SetAutoFocus(false)
    search:SetFontObject("ChatFontNormal")
    search:SetMaxLetters(40)
    local hint = search:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    hint:SetPoint("LEFT", search, "LEFT", 2, 0)
    hint:SetText("Search toggles")
    search.hint = hint
    frame.search = search
    -- The X at the box's right end clears it; only there while it holds text.
    local clear = CreateFrame("Button", nil, search)
    clear:SetSize(17, 17)
    clear:SetPoint("RIGHT", search, "RIGHT", -3, 0)
    clear:SetNormalTexture("Interface\\FriendsFrame\\ClearBroadcastIcon")
    clear:SetHighlightTexture("Interface\\FriendsFrame\\ClearBroadcastIcon", "ADD")
    clear:GetNormalTexture():SetAlpha(0.6)
    clear:SetScript("OnClick", function() search:SetText("") search:ClearFocus() end)
    clear:Hide()
    search.clear = clear

    function frame:PlaceBoxes(text)
        text = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        local own, hit = {}, {}
        for _, box in ipairs(self.boxes) do
            if text == "" or box.label:lower():find(text, 1, true) or (box.tooltip or ""):lower():find(text, 1, true) then
                own[box.key] = true
                hit[box.key] = true
            end
        end
        -- A section is a toggle and the ones indented under it, and it is
        -- shown whole or not at all: a match anywhere in it brings the
        -- header and every line under it, so nothing turns up indented
        -- under nothing or without the lines that go with it.
        for _, box in ipairs(self.boxes) do
            if own[box.key] then
                local head = box.parent or box.key
                hit[head] = true
                for _, other in ipairs(self.boxes) do
                    if other.parent == head then hit[other.key] = true end
                end
            end
        end
        -- The sections in the list's order, each header followed by its
        -- own lines wherever in the list those were written.
        local groups, count = {}, 0
        for _, box in ipairs(self.boxes) do
            if not hit[box.key] then
                box:Hide()
            elseif not box.parent then
                local group = { box }
                for _, other in ipairs(self.boxes) do
                    if other.parent == box.key and hit[other.key] then group[#group + 1] = other end
                end
                groups[#groups + 1] = group
                count = count + #group
            end
        end
        -- Two columns, filled down the first then down the second. A
        -- section is never cut by the column break: the first column
        -- takes whole sections until the next would take it past half.
        local half = math.max(1, math.ceil(count / COLUMNS))
        local colW = LIST_W / COLUMNS
        local column, row, per = 0, 0, 0
        for _, group in ipairs(groups) do
            if column < COLUMNS - 1 and row > 0 and row + #group > half then
                column, row = column + 1, 0
            end
            for _, box in ipairs(group) do
                box:ClearAllPoints()
                box:SetPoint("TOPLEFT", self.listChild, "TOPLEFT", column * colW + (box.parent and INDENT or 0), -row * ROW)
                box:Show()
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

    -- The two buttons that act on the toggles stand with the toggles,
    -- between the search box and the first row: everything on, or
    -- everything off if it already is, and everything back to its default.
    -- Not part of the classic look, so not part of "all": the minimap
    -- button is the way back into this window, and the welcome note is
    -- a courtesy, neither of which anyone means to switch with the rest.
    local NOT_IN_ALL = { minimapButton = true, welcomeNote = true }
    local function InAll(key) return ns.DB_DEFAULTS[key] ~= false and not NOT_IN_ALL[key] end
    local all = ns.PanelButton(frame, "Toggle all", 100)
    all:SetPoint("TOPRIGHT", search, "BOTTOM", -3, -6)
    all:SetScript("OnClick", function()
        local anyOff = false
        for _, entry in ipairs(rows) do
            if InAll(entry[1]) and ns.db[entry[1]] == false then anyOff = true end
        end
        -- Only the pieces that are on by default: the extras that start
        -- off (one bar, one bag, the bar size) are choices, not pieces.
        local wentOff = false
        for _, entry in ipairs(rows) do
            if InAll(entry[1]) then
                local on = anyOff and true or false
                if not on and ns.db[entry[1]] ~= false and ns.RELOAD_KEYS[entry[1]] then wentOff = true end
                ns.db[entry[1]] = on
            end
        end
        ns.ApplyAll()
        frame:Refresh()
        -- The same question a single toggle asks when a piece that
        -- leaves its art on screen is turned off.
        if wentOff and StaticPopup_Show then StaticPopup_Show("FOREVERCLASSICUI_RELOAD") end
    end)
    all.tooltip = "Turns every piece of the classic look on, or off if they are all on already. The extras that start off (One bar, One bag, Default interface bar size), the minimap button and the welcome note are left as they are."
    all.label = "Toggle all"
    all:SetScript("OnEnter", ShowTooltip)
    all:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local defaults = ns.PanelButton(frame, "Reset toggles", 100)
    defaults:SetPoint("TOPLEFT", search, "BOTTOM", 3, -6)
    defaults:SetScript("OnClick", function()
        local wentOff = false
        local wasBig = ns.db.defaultBarSize == true
        for _, entry in ipairs(rows) do
            local want = ns.DB_DEFAULTS[entry[1]]
            if want == false and ns.db[entry[1]] ~= false and ns.RELOAD_KEYS[entry[1]] then wentOff = true end
            ns.db[entry[1]] = want
        end
        -- The bar size toggle also sets how many icons the bars show, and
        -- a reset that turns it off has to put those back as the checkbox
        -- itself would: set here directly, the bars were left at ten and
        -- eight with the size back to normal.
        if wasBig and ns.db.defaultBarSize ~= true and ns.FitBarsToSize then ns.FitBarsToSize(false) end
        ns.ApplyAll()
        frame:Refresh()
        if wentOff and StaticPopup_Show then StaticPopup_Show("FOREVERCLASSICUI_RELOAD") end
    end)
    defaults.tooltip = "Puts every checkbox back to its default. Nothing to do with edit mode layouts."
    defaults.label = "Reset toggles"
    defaults:SetScript("OnEnter", ShowTooltip)
    defaults:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Foot of the window, two short stacks. Left: the layout button over
    -- Reload UI. Right: where to send a report, under its own heading.
    -- The layout button is the way to the classic layout and nothing
    -- else: any other layout is picked where layouts are picked, in edit
    -- mode. It once turned into a "Back to" button while the classic
    -- layout was on, which hid the reset behind it.
    local layout = ns.PanelButton(frame, "Classic layout", 130)
    layout:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 26, 46)
    layout:SetScript("OnClick", function()
        if ns.ClassicLayoutActive and ns.ClassicLayoutActive() then
            -- Already on it: offer to put it back to its defaults.
            StaticPopup_Show("FCUI_LAYOUT_RESET")
        else
            ns.CreateClassicLayout()
        end
    end)
    layout.tooltip = "Adds an edit mode layout with every bar in its 1.x place and switches to it. Your current layout and keybinds stay, and edit mode switches between layouts as ever. Once the classic layout is on, this button resets it to its defaults."
    layout.label = "Classic layout"
    frame.layoutButton = layout
    layout:SetScript("OnEnter", ShowTooltip)
    layout:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local reload = ns.PanelButton(frame, "Reload UI", 130)
    reload:SetPoint("TOPLEFT", layout, "BOTTOMLEFT", 0, -4)
    reload:SetScript("OnClick", function() ns.ReloadForLayout() end)

    -- Feedback: the same copy-the-address boxes the welcome note uses.
    local curse = ns.PanelButton(frame, "CurseForge", 130)
    curse:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 46)
    curse:SetScript("OnClick", function() if ns.CopyLink then ns.CopyLink("ClassicUI Forever on CurseForge", ns.CURSEFORGE_URL) end end)
    curse.tooltip = "Copies the addon's CurseForge address, for comments and reports there."
    curse.label = "CurseForge"
    curse:SetScript("OnEnter", ShowTooltip)
    curse:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local github = ns.PanelButton(frame, "GitHub issues", 130)
    github:SetPoint("TOPRIGHT", curse, "BOTTOMRIGHT", 0, -4)
    github:SetScript("OnClick", function() if ns.CopyLink then ns.CopyLink("ClassicUI Forever issues on GitHub", ns.GITHUB_URL) end end)
    github.tooltip = "Copies the address of the GitHub issue tracker, for bug reports and requests."
    github.label = "GitHub issues"
    github:SetScript("OnEnter", ShowTooltip)
    github:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local status = ns.PanelButton(frame, "Status report", 130)
    status:SetPoint("RIGHT", curse, "LEFT", -6, 0)
    status:SetScript("OnClick", function() if ns.ShowStatus then ns.ShowStatus() end end)
    status.tooltip = "Opens a window with your addon version, game build, changed settings and other addons, to screenshot or copy into a bug report."
    status.label = "Status report"
    status:SetScript("OnEnter", ShowTooltip)
    status:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local feedback = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    feedback:SetPoint("BOTTOM", curse, "TOP", 0, 5)
    feedback:SetText("Bug reports/Feedback:")

    if not canvas then frame:SetSize(WIDTH, 110 + LIST_ROWS * ROW + 108) end

    function frame:Refresh()
        -- The one box that shows a setting of the game's: read it fresh.
        if ns.ReadGameDamageNumbers then ns.ReadGameDamageNumbers() end
        for _, box in ipairs(self.boxes) do
            box:SetChecked(ns.db[box.key] ~= false)
            -- A child under a parent that is off is off too, and grayed.
            local on = not box.parent or ns.db[box.parent] ~= false
            box:SetEnabled(on)
            box.text:SetFontObject(on and "GameFontHighlight" or "GameFontDisable")
        end
        self.note:SetText(ns.needsReload and "Reload the interface to clear the old art from the pieces you turned off." or "")
        if self.layoutButton then
            -- One name, whatever layout is on: on the classic layout the
            -- press offers its reset, which the prompt says.
            self.layoutButton:SetText("Classic layout")
        end
    end
    frame:SetScript("OnShow", frame.Refresh)
    -- After the line above, which sets the window's own script: a hook
    -- added before it is wiped by it, and Escape was never taken.
    if not canvas and ns.CloseOnEscape then ns.CloseOnEscape(frame) end
    return frame
end

-- The panel as the settings window's own page.
function ns.OptionsCanvas()
    if ns.optionsCanvas then return ns.optionsCanvas end
    local canvas = CreateFrame("Frame", "ForeverClassicUIOptionsCanvas", UIParent)
    canvas:SetSize(620, 560)
    canvas:Hide()
    ns.optionsCanvas = Build(canvas)
    return ns.optionsCanvas
end

-- A toggle changed from outside the window (the game's Settings).
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
