local _, ns = ...

-- Old skins on the client's modern controls; client art fades, behaviour is untouched.

local ART, KEYS = ns.ART, ns.KEYS
local DressStates, FadeKeys = ns.DressStates, ns.FadeKeys
local Once = ns.Once

local PANEL_BUTTON = ART.PANEL_BUTTON
local CHECK = ART.CHECK
local HILIGHT = ART.HILIGHT
local SLIDER_BORDER = "Interface\\Buttons\\UI-SliderBar-Border"
local SLIDER_BG = "Interface\\Buttons\\UI-SliderBar-Background"
local SLIDER_THUMB = "Interface\\Buttons\\UI-SliderBar-Button-Horizontal"
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
local STEPPER = { set = "file", highlightSet = "raw", center = { 26, 26 }, add = true }

-- The 1.x red button sheet; false when this client lacks the file.
function ns.RedButtonArt(button, how)
    if button:SetNormalTexture(PANEL_BUTTON .. "Up") == false then return false end
    DressStates(button, PANEL_BUTTON .. "Up", PANEL_BUTTON .. "Down", PANEL_BUTTON .. "Disabled",
        PANEL_BUTTON .. "Highlight", how)
    return true
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

-- The steppers beside a drop down or slider.
function ns.SkinStepper(button, forward)
    if not button or not Once(button, "stepper") then return end
    ns.FadeRegions(button)
    local sheet = forward and ART.PAGE_NEXT or ART.PAGE_PREV
    local ok = button:SetNormalTexture(sheet .. "Up")
    if ok == false then return end
    DressStates(button, sheet .. "Up", sheet .. "Down", sheet .. "Disabled", HILIGHT, STEPPER)
end

local SLIDER_BACKDROP = {
    bgFile = SLIDER_BG, edgeFile = SLIDER_BORDER, tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 6, bottom = 6 },
}
local STEP_ENDS = { "Back", "Forward" }

local function Drain(tex) ns.DrainBronze(tex) end

function ns.SkinSliderWithSteppers(frame)
    if not frame or not Once(frame, "slider") then return end
    local slider = frame.Slider or frame
    FadeKeys(slider, KEYS.LRM)
    local track = CreateFrame("Frame", nil, slider, "BackdropTemplate")
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    track:SetHeight(17)
    track:SetFrameLevel(math.max(0, slider:GetFrameLevel() - 1))
    ns.Backdrop(track, SLIDER_BACKDROP)
    if slider.SetThumbTexture then
        slider:SetThumbTexture(SLIDER_THUMB)
        local thumb = slider:GetThumbTexture()
        if thumb then
            ns.SetFile(thumb, SLIDER_THUMB)
            thumb:SetTexCoord(0, 1, 0, 1)
            thumb:SetSize(32, 32)
        end
    end
    -- Drain, not hide: the client re-shows the end arrows on every slider setup.
    for _, key in ipairs(STEP_ENDS) do
        local button = frame[key]
        if button then
            button:SetAlpha(1)
            button:EnableMouse(true)
            ns.EachTexture(button, Drain)
            ns.EachState(button, KEYS.STATES, Drain)
        end
    end
end

-- A page-arrow toggle on a window; the global name is kept.
function ns.PanelToggle(parent, name, size, point, rel, relPoint, x, y, level, onClick, tip)
    local button = CreateFrame("Button", name, parent)
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
    local clear = CreateFrame("Button", nil, box)
    clear:SetSize(17, 17)
    clear:SetPoint("RIGHT", box, "RIGHT", -3, 0)
    clear:SetNormalTexture(CLEAR_ICON)
    clear:SetHighlightTexture(CLEAR_ICON, "ADD")
    clear:GetNormalTexture():SetAlpha(0.6)
    clear:SetScript("OnClick", ClearBox)
    clear:Hide()
    return clear
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

-- Minimal tabs (a panel's top tabs) wear the old tab art flipped onto the box below.
local function TabSelected(tab)
    if tab.IsSelected then return tab:IsSelected() end
    return tab.selected or false
end

local MINIMAL_TAB = { own = "mt", layer = "BACKGROUND", cap = 20, height = 32, edge = "BOTTOM", middle = "edge", show = true,
    coords = { { 0, 0.15625, 0, 1 }, { 0.15625, 0.84375, 0, 1 }, { 0.84375, 1, 0, 1 } } }
local TAB_HOOKS = { "SetSelected", "SetSelectedState", "UpdateTab" }

local function DressMinimalTab(tab)
    local selected = TabSelected(tab)
    ns.ThreeSlice(tab, selected and "optionsTabActive" or "optionsTabInactive", MINIMAL_TAB, tab)
    if tab.Text then tab.Text:SetFontObject(selected and "GameFontHighlightSmall" or "GameFontNormalSmall") end
end

function ns.SkinMinimalTab(tab)
    if not tab then return end
    if not tab.fcuiTab then
        tab.fcuiTab = true
        FadeKeys(tab, KEYS.LMR)
        for _, method in ipairs(TAB_HOOKS) do
            if type(tab[method]) == "function" then
                hooksecurefunc(tab, method, function(self) DressMinimalTab(self) end)
            end
        end
        tab:HookScript("OnShow", DressMinimalTab)
        -- Redress after the client's click has run; one closure per tab keeps one pending wait.
        local function Redress() DressMinimalTab(tab) end
        tab:HookScript("OnClick", function() ns.Sched.NextFrame(tab, Redress) end)
    end
    DressMinimalTab(tab)
end
