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
    button:SetHighlightTexture(PANEL_BUTTON .. "Highlight")
    for _, tex in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture() }) do
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
        ns.ApplyAll()
        window:Refresh()
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
        frame:SetFrameStrata("DIALOG")
        frame:SetPoint("CENTER")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetClampedToScreen(true)
        frame:Hide()

        local header = frame:CreateTexture(nil, "ARTWORK")
        header:SetTexture(DIALOG_HEADER)
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
    local LIST_TOP, LIST_W = canvas and -46 or -80, width - 70
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
        box.text:SetWidth(LIST_W / COLUMNS - 30 - (entry.parent and INDENT or 0))
        frame.boxes[#frame.boxes + 1] = box
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
        -- A matching child brings its parent along as its header; a
        -- parent matched on its own words brings every child.
        for _, box in ipairs(self.boxes) do
            if box.parent and own[box.key] then hit[box.parent] = true end
            if box.parent and own[box.parent] then hit[box.key] = true end
        end
        -- Two columns, filled down the first then down the second, so a
        -- parent and its children stay together.
        local shown = {}
        for _, box in ipairs(self.boxes) do
            if hit[box.key] then shown[#shown + 1] = box else box:Hide() end
        end
        local per = math.max(1, math.ceil(#shown / COLUMNS))
        local colW = LIST_W / COLUMNS
        for i, box in ipairs(shown) do
            local column = math.floor((i - 1) / per)
            local row = (i - 1) % per
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", self.listChild, "TOPLEFT", column * colW + (box.parent and INDENT or 0), -row * ROW)
            box:Show()
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

    local note = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    note:SetPoint("BOTTOM", frame, "BOTTOM", 0, 78)
    note:SetTextColor(1, 0.82, 0)
    frame.note = note

    -- Bottom rows: Classic layout, Reset toggles and Reload UI centered
    -- as one row, then CurseForge and GitHub issues centered under them.
    local layout = ns.PanelButton(frame, "Classic layout", 110)
    layout:SetScript("OnClick", function() ns.CreateClassicLayout() end)
    layout.tooltip = "Adds an edit mode layout with every bar in its 1.x place and switches to it. Your current layout and keybinds stay."
    layout.label = "Classic layout"
    layout:SetScript("OnEnter", ShowTooltip)
    layout:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Puts every checkbox above back to its default (all on). Nothing to
    -- do with edit mode layouts; that is the button beside it.
    local defaults = ns.PanelButton(frame, "Reset toggles", 100)
    defaults:SetPoint("BOTTOM", frame, "BOTTOM", 0, 48)
    layout:SetPoint("RIGHT", defaults, "LEFT", -6, 0)
    defaults:SetScript("OnClick", function()
        for _, entry in ipairs(rows) do ns.db[entry[1]] = ns.DB_DEFAULTS[entry[1]] end
        ns.ApplyAll()
        frame:Refresh()
    end)
    defaults.tooltip = "Turns every checkbox above back on. Edit mode layouts are not touched."
    defaults.label = "Reset toggles"
    defaults:SetScript("OnEnter", ShowTooltip)
    defaults:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local reload = ns.PanelButton(frame, "Reload UI", 80)
    reload:SetPoint("LEFT", defaults, "RIGHT", 6, 0)
    reload:SetScript("OnClick", function() if C_UI and C_UI.Reload then C_UI.Reload() end end)

    -- Feedback: the same copy-the-address boxes the welcome note uses.
    local curse = ns.PanelButton(frame, "CurseForge", 120)
    curse:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -4, 18)
    curse:SetScript("OnClick", function() if ns.CopyLink then ns.CopyLink("ClassicUI Forever on CurseForge", ns.CURSEFORGE_URL) end end)
    curse.tooltip = "Copies the addon's CurseForge address, for comments and reports there."
    curse.label = "CurseForge"
    curse:SetScript("OnEnter", ShowTooltip)
    curse:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local github = ns.PanelButton(frame, "GitHub issues", 120)
    github:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 4, 18)
    github:SetScript("OnClick", function() if ns.CopyLink then ns.CopyLink("ClassicUI Forever issues on GitHub", ns.GITHUB_URL) end end)
    github.tooltip = "Copies the address of the GitHub issue tracker, for bug reports and requests."
    github.label = "GitHub issues"
    github:SetScript("OnEnter", ShowTooltip)
    github:SetScript("OnLeave", function() GameTooltip:Hide() end)

    if not canvas then frame:SetSize(WIDTH, 80 + LIST_ROWS * ROW + 108) end

    function frame:Refresh()
        for _, box in ipairs(self.boxes) do
            box:SetChecked(ns.db[box.key] ~= false)
            -- A child under a parent that is off is off too, and grayed.
            local on = not box.parent or ns.db[box.parent] ~= false
            box:SetEnabled(on)
            box.text:SetFontObject(on and "GameFontHighlight" or "GameFontDisable")
        end
        self.note:SetText(ns.needsReload and "A piece was switched to the modern look; reload to clear its art fully." or "")
    end
    frame:SetScript("OnShow", frame.Refresh)
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
