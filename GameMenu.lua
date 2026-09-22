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

-- The old menu button: 144 by 21 of art, one button every 22 or so. The
-- client's layout puts a space of its own between buttons, near 4, and
-- that space is a field of its frame and not ours to write. So the
-- button is just its art, no gap of ours added: measured against the old
-- menu the stack was a third too tall with the buttons at 25, and with
-- them at 19 the art all but touched.
local BUTTON_W, ART_H, GAP = 144, 21, 2
-- The client leaves room at the top for its own taller header. The old
-- plate sits on the border, so the stack is lifted by this much and the
-- box shortened to match, through the widget calls alone.
local TOP_TRIM = 18

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
            ns.SetButtonFile(button, "Normal", PANEL_BUTTON .. "Up")
            ns.SetButtonFile(button, "Pushed", PANEL_BUTTON .. "Down")
            ns.SetButtonFile(button, "Disabled", PANEL_BUTTON .. "Disabled")
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
        -- White, as the old menu's buttons were; only the Main Menu
        -- plate above them is gold.
        button:SetNormalFontObject("GameFontHighlight")
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
    -- Never during a fight. What follows lays the menu out again and
    -- moves its buttons, which writes the client's own layout fields in
    -- this addon's name; the client then reads them when it goes to shut
    -- the menu, and a shut in a fight is refused for it. Escape would not
    -- close the menu at all. Out of a fight the client lays the menu out
    -- itself on every opening, so nothing is lost by standing aside.
    if InCombatLockdown() then return end
    for button in GameMenuFrame.buttonPool:EnumerateActive() do SkinButton(button) end
    -- Blizzard laid the buttons out at their old size before this ran;
    -- the layout goes again at ours, so the box and the stack fit.
    if not GameMenuFrame.Layout then return end
    GameMenuFrame:Layout()
    -- Fresh from the layout every time, so the lift is never added twice.
    for button in GameMenuFrame.buttonPool:EnumerateActive() do
        local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
        if point then
            button:ClearAllPoints()
            button:SetPoint(point, relativeTo, relativePoint, x or 0, (y or 0) + TOP_TRIM)
        end
    end
    local height = GameMenuFrame:GetHeight()
    if height and height > TOP_TRIM * 3 then GameMenuFrame:SetHeight(height - TOP_TRIM) end
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
    ns.BronzeBackdrop(backing)
    backing:SetAllPoints(menu)
    backing:SetFrameLevel(menu:GetFrameLevel())
    local header = menu.Header
    if header then
        for _, key in ipairs({ "LeftBG", "RightBG", "CenterBG" }) do
            if header[key] then header[key]:SetAlpha(0) end
        end
        local plate = ns.OwnTexture(header, "plate", "BACKGROUND", 0)
        ns.SetFile(plate, DIALOG_HEADER)
        plate:SetSize(256, 64)
        plate:ClearAllPoints()
        plate:SetPoint("TOP", menu, "TOP", 0, 12)
        plate:Show()
        if header.Text then
            header.Text:SetFontObject(ns.FONT_GOLD)
            -- The old plate said Main Menu.
            if MAIN_MENU then header.Text:SetText(MAIN_MENU) end
        end
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
        GameMenuFrame:HookScript("OnShow", function()
            if not active or InCombatLockdown() then return end
            SkinMenu()
            SkinButtons()
        end)
    end
    if GameMenuFrame:IsShown() then SkinMenu() SkinButtons() end
end

local function Restore()
    active = false
    ns.needsReload = true
end

ns.RegisterModule("gameMenu", { apply = Apply, restore = Restore })
