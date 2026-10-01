local _, ns = ...

-- Old skins on the client's modern controls; client art fades, behaviour is untouched.

local ART, KEYS = ns.ART, ns.KEYS
local DressStates, FadeKeys = ns.DressStates, ns.FadeKeys
local Once = ns.Once

local PANEL_BUTTON = ART.PANEL_BUTTON
local CHECK = ART.CHECK
local HILIGHT = ART.HILIGHT
local DROPDOWN = "Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame"
local DROPDOWN_ARROW = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-"

local FULL = { 0, 1, 0, 1 }
local TEXTURES_ONLY = { texture = true }
-- The 1.x red button's texture coords and state dress; read only.
ns.RED_COORDS = { 0, 0.625, 0, 0.6875 }
ns.RED_STATES = { set = "file", highlightSet = "raw", coords = ns.RED_COORDS, fill = true, add = true }
local RED = ns.RED_STATES
local BOX = { set = "file", highlightSet = "raw", checked = CHECK .. "Check", disabledChecked = CHECK .. "Check-Disabled",
    coords = FULL, fill = true, add = true, states = { "Normal", "Pushed", "Highlight", "Checked", "DisabledChecked" } }

-- The 1.x red button sheet; false when this client lacks the file.
function ns.RedButtonArt(button, how)
    if button:SetNormalTexture(PANEL_BUTTON .. "Up") == false then return false end
    DressStates(button, PANEL_BUTTON .. "Up", PANEL_BUTTON .. "Down", PANEL_BUTTON .. "Disabled",
        PANEL_BUTTON .. "Highlight", how)
    return true
end

-- Our own red button (options, welcome, status); raw paths: no bronze swap.
local PANEL_RAW = { set = "raw", coords = ns.RED_COORDS, add = true }
function ns.PanelButton(parent, text, width)
    local button = ns.NewFrame("Button", nil, parent)
    button:SetSize(width or 96, 22)
    local ok = button:SetNormalTexture(PANEL_BUTTON .. "Up")
    if ok == false then
        -- Old sheet missing on this client: fall back to the modern button.
        button:Hide()
        button = ns.NewFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetSize(width or 96, 22)
        button:SetText(text)
        return button
    end
    -- Disabled is gray like the old buttons, not a red face.
    DressStates(button, nil, PANEL_BUTTON .. "Down", PANEL_BUTTON .. "Disabled", PANEL_BUTTON .. "Highlight", PANEL_RAW)
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

-- Takes a modern three-slice or panel button.
function ns.SkinRedButton(button)
    if not button or not Once(button, "red") then return end
    FadeKeys(button, KEYS.PANEL, 0, TEXTURES_ONLY)
    if not ns.RedButtonArt(button, RED) then return end
    button:SetNormalFontObject("GameFontNormal")
    button:SetHighlightFontObject("GameFontHighlight")
    button:SetDisabledFontObject("GameFontDisable")
end

function ns.SkinCheckbox(check)
    if not check or not Once(check, "check") then return end
    if check.HoverBackground then check.HoverBackground:SetAlpha(0) end
    local ok = check:SetNormalTexture(CHECK .. "Up")
    if ok == false then return end
    DressStates(check, CHECK .. "Up", CHECK .. "Down", nil, CHECK .. "Highlight", BOX)
end

-- A page-arrow toggle on a window; the global name is kept.
function ns.PanelToggle(parent, name, size, point, rel, relPoint, x, y, level, onClick, tip)
    local button = ns.NewFrame("Button", name, parent)
    button:SetSize(size, size)
    button:SetPoint(point, rel, relPoint, x, y)
    button:SetFrameLevel(level)
    button:SetHighlightTexture(HILIGHT, "ADD")
    button:SetScript("OnClick", onClick)
    ns.AttachTip(button, tip)
    return button
end

local PREV_UP, PREV_DOWN = ART.PAGE_PREV .. "Up", ART.PAGE_PREV .. "Down"
local NEXT_UP, NEXT_DOWN = ART.PAGE_NEXT .. "Up", ART.PAGE_NEXT .. "Down"

-- Open shows the back arrow, shut the forward one; dressed only on a change (.open on our own button).
function ns.PanelToggleFace(button, open, how)
    if not button or button.open == open then return end
    button.open = open
    if open then
        DressStates(button, PREV_UP, PREV_DOWN, nil, nil, how)
    else
        DressStates(button, NEXT_UP, NEXT_DOWN, nil, nil, how)
    end
end

-- A list's first row from its scroll bar.
function ns.ListOffset(bar)
    return math.floor((bar:GetValue() or 0) + 0.5)
end

local CLEAR_ICON = "Interface\\FriendsFrame\\ClearBroadcastIcon"

local function ClearBox(self)
    local box = self:GetParent()
    box:SetText("")
    box:ClearFocus()
end

-- The client's X at a search box's right end, hidden; callers show it while there is text.
function ns.SearchClear(box)
    local clear = ns.NewFrame("Button", nil, box)
    clear:SetSize(17, 17)
    clear:SetPoint("RIGHT", box, "RIGHT", -3, 0)
    clear:SetNormalTexture(CLEAR_ICON)
    clear:SetHighlightTexture(CLEAR_ICON, "ADD")
    clear:GetNormalTexture():SetAlpha(0.6)
    clear:SetScript("OnClick", ClearBox)
    clear:Hide()
    return clear
end

-- A search box in the old input look: hint text while empty, the X to clear; callers show those two by the text.
function ns.SearchBox(parent, width, hintText)
    local box = ns.NewFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box:SetFontObject("ChatFontNormal")
    box:SetMaxLetters(40)
    -- The client's input edges are bronze; silver off the theme, as every other box.
    ns.DrainInput(box)
    local hint = box:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    hint:SetPoint("LEFT", box, "LEFT", 2, 0)
    hint:SetText(hintText)
    box.hint = hint
    box.clear = ns.SearchClear(box)
    box:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return box
end

-- Shared by settings drop downs and our own list openers.
local DD_SLICE = { own = "dd", layer = "BACKGROUND", sublevel = 0, set = "file", key = DROPDOWN,
    coords = { { 0, 0.1953125, 0, 1 }, { 0.1953125, 0.8046875, 0, 1 }, { 0.8046875, 1, 0, 1 } }, cap = 25, show = true }
function ns.DressDropdown(dropdown, inset)
    inset = inset or 17
    ns.ThreeSlice(dropdown, nil, DD_SLICE, dropdown, inset, inset)
    local arrow = ns.OwnTexture(dropdown, "ddArrow", "ARTWORK", 0)
    ns.SetFile(arrow, DROPDOWN_ARROW .. "Up")
    arrow:SetSize(24, 24)
    ns.SetPointOnce(arrow, "RIGHT", dropdown, "RIGHT", 1, 2)
    arrow:Show()
    local glow = ns.OwnTexture(dropdown, "ddArrowGlow", "HIGHLIGHT", 0)
    glow:SetTexture(HILIGHT)
    glow:SetBlendMode("ADD")
    glow:SetSize(24, 24)
    ns.SetPointOnce(glow, "RIGHT", dropdown, "RIGHT", 1, 2)
    glow:Show()
    return arrow
end

function ns.SkinDropdown(dropdown)
    if not dropdown or not Once(dropdown, "dropdown") then return end
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

