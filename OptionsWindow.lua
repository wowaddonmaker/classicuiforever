local _, ns = ...

-- The 1.x options dialog: the dialog box border and dark background, the
-- header plate with the title, one classic checkbox per module (checked
-- is the classic look, unchecked the modern one) and the old panel
-- buttons. This is what /fcui opens; the same toggles also live in the
-- game's own Settings window.

local TITLE = "Forever Classic UI"
local WIDTH, COLUMN, ROW = 400, 190, 26
local DIALOG_BG = "Interface\\DialogFrame\\UI-DialogBox-Background"
local DIALOG_BORDER = "Interface\\DialogFrame\\UI-DialogBox-Border"
local DIALOG_HEADER = "Interface\\DialogFrame\\UI-DialogBox-Header"
local CHECK = "Interface\\Buttons\\UI-CheckBox-"
local PANEL_BUTTON = "Interface\\Buttons\\UI-Panel-Button-"

local window

local function PanelButton(parent, text, width)
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
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", 0, 1)
    label:SetText(text)
    button:SetFontString(label)
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
    text:SetWidth(COLUMN - 30)
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

local function Build()
    local frame = CreateFrame("Frame", "ForeverClassicUIOptions", UIParent, "BackdropTemplate")
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
    if ns.SkinCloseButton then ns.SkinCloseButton(close, true) end

    frame.boxes = {}
    local rows = { { "enabled", "Enable " .. TITLE, "Master switch. Off restores the modern look everywhere; some pieces finish restoring on reload." } }
    for _, entry in ipairs(ns.TOGGLES) do rows[#rows + 1] = entry end
    local perColumn = math.ceil(#rows / 2)
    for i, entry in ipairs(rows) do
        local box = Checkbox(frame, entry[1], entry[2], entry[3])
        local column = (i - 1) < perColumn and 0 or 1
        local row = (i - 1) % perColumn
        box:SetPoint("TOPLEFT", frame, "TOPLEFT", 22 + column * COLUMN, -52 - row * ROW)
        frame.boxes[#frame.boxes + 1] = box
    end

    local note = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    note:SetPoint("BOTTOM", frame, "BOTTOM", 0, 48)
    note:SetTextColor(1, 0.82, 0)
    frame.note = note

    local layout = PanelButton(frame, "Classic layout", 110)
    layout:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 18)
    layout:SetScript("OnClick", function() ns.CreateClassicLayout() end)
    layout.tooltip = "Adds an edit mode layout with every bar in its 1.x place and switches to it. Your current layout and keybinds stay."
    layout.label = "Classic layout"
    layout:SetScript("OnEnter", ShowTooltip)
    layout:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local defaults = PanelButton(frame, "Defaults", 80)
    defaults:SetPoint("LEFT", layout, "RIGHT", 6, 0)
    defaults:SetScript("OnClick", function()
        for _, entry in ipairs(rows) do ns.db[entry[1]] = ns.DB_DEFAULTS[entry[1]] end
        ns.ApplyAll()
        frame:Refresh()
    end)

    local reload = PanelButton(frame, "Reload UI", 80)
    reload:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 18)
    reload:SetScript("OnClick", function() if C_UI and C_UI.Reload then C_UI.Reload() end end)

    local okay = PanelButton(frame, "Okay", 70)
    okay:SetPoint("RIGHT", reload, "LEFT", -6, 0)
    okay:SetScript("OnClick", function() frame:Hide() end)

    frame:SetSize(WIDTH, 52 + perColumn * ROW + 78)

    function frame:Refresh()
        local master = ns.db.enabled ~= false
        for _, box in ipairs(self.boxes) do
            box:SetChecked(ns.db[box.key] ~= false)
            if box.key ~= "enabled" then
                box:SetEnabled(master)
                box.text:SetFontObject(master and "GameFontHighlight" or "GameFontDisable")
            end
        end
        self.note:SetText(ns.needsReload and "A piece was switched to the modern look; reload to clear its art fully." or "")
    end
    frame:SetScript("OnShow", frame.Refresh)
    return frame
end

function ns.OpenOptions()
    if not window then window = Build() end
    if window:IsShown() then
        window:Hide()
    else
        window:Show()
    end
end
