-- The game menu as 1.x drew it: the old dialog box with its header
-- plate, and the compact red buttons with yellow labels, 144 wide and
-- 21 tall with a few pixels between. Blizzard's menu keeps its buttons,
-- callbacks and vertical layout; its bronze border, header and button
-- art are faded and ours drawn in their place. No field of Blizzard's
-- is written: sizes go through the widget API and the layout follows.
local _, ns = ...

local DIALOG_BG = "Interface\\DialogFrame\\UI-DialogBox-Background"
local DIALOG_BORDER = "Interface\\DialogFrame\\UI-DialogBox-Border"
local DIALOG_HEADER = "Interface\\DialogFrame\\UI-DialogBox-Header"
local PANEL_BUTTON = "Interface\\Buttons\\UI-Panel-Button-"
local PANEL_COORDS = { 0, 0.625, 0, 0.6875 }

-- The old menu button: 144 by 21 of art. The button itself is taller
-- by the gap, so the layout, which stacks buttons edge to edge, leaves
-- the old space between them.
local BUTTON_W, ART_H, GAP = 144, 21, 4

local active = false
local backing

local function FadeRegions(frame)
    if not frame or not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
end

local function SkinButton(button)
    if not button.fcuiMenuButton then
        button.fcuiMenuButton = true
        for _, key in ipairs({ "Left", "Right", "Center" }) do
            if button[key] then button[key]:SetAlpha(0) end
        end
        local ok = button:SetNormalTexture(PANEL_BUTTON .. "Up")
        if ok ~= false then
            button:SetPushedTexture(PANEL_BUTTON .. "Down")
            button:SetDisabledTexture(PANEL_BUTTON .. "Disabled")
            button:SetHighlightTexture(PANEL_BUTTON .. "Highlight")
            for _, tex in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture(), button:GetHighlightTexture() }) do
                if tex then
                    tex:SetTexCoord(unpack(PANEL_COORDS))
                    tex:ClearAllPoints()
                    tex:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -GAP / 2)
                    tex:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, GAP / 2)
                end
            end
            local hl = button:GetHighlightTexture()
            if hl then hl:SetBlendMode("ADD") end
        end
        button:SetNormalFontObject("GameFontNormal")
        button:SetHighlightFontObject("GameFontHighlight")
        button:SetDisabledFontObject("GameFontDisable")
        local text = button:GetFontString()
        if text then
            text:ClearAllPoints()
            text:SetPoint("CENTER", button, "CENTER", 0, -1)
        end
    end
    button:SetSize(BUTTON_W, ART_H + GAP)
end

local function SkinButtons()
    if not active or not GameMenuFrame or not GameMenuFrame.buttonPool then return end
    for button in GameMenuFrame.buttonPool:EnumerateActive() do SkinButton(button) end
    -- Blizzard laid the buttons out at their old size before this ran;
    -- the layout goes again at ours, so the box and the stack fit.
    if GameMenuFrame.Layout then GameMenuFrame:Layout() end
end

local function SkinMenu()
    local menu = GameMenuFrame
    if not menu or menu.fcuiSkinned then return end
    menu.fcuiSkinned = true
    if menu.Border then
        FadeRegions(menu.Border)
        for _, child in ipairs({ menu.Border:GetChildren() }) do FadeRegions(child) end
    end
    backing = CreateFrame("Frame", nil, menu, "BackdropTemplate")
    backing:SetBackdrop({
        bgFile = DIALOG_BG, edgeFile = DIALOG_BORDER, tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    backing:SetAllPoints(menu)
    backing:SetFrameLevel(menu:GetFrameLevel())
    local header = menu.Header
    if header then
        for _, key in ipairs({ "LeftBG", "RightBG", "CenterBG" }) do
            if header[key] then header[key]:SetAlpha(0) end
        end
        local plate = ns.OwnTexture(header, "plate", "BACKGROUND", 0)
        plate:SetTexture(DIALOG_HEADER)
        plate:SetSize(256, 64)
        plate:ClearAllPoints()
        plate:SetPoint("TOP", menu, "TOP", 0, 12)
        plate:Show()
        if header.Text then header.Text:SetFontObject("GameFontNormal") end
    end
    ns.HookMethod(menu, "InitButtons", SkinButtons)
    SkinButtons()
end

local hooked = false
local function Apply()
    active = true
    if not GameMenuFrame then ns.MissingPiece("GameMenuFrame") return end
    if not hooked then
        hooked = true
        GameMenuFrame:HookScript("OnShow", function() if active then SkinMenu() SkinButtons() end end)
    end
    if GameMenuFrame:IsShown() then SkinMenu() SkinButtons() end
end

local function Restore()
    active = false
    ns.needsReload = true
end

ns.RegisterModule("gameMenu", { apply = Apply, restore = Restore })
