-- Game menu in 1.x art: dialog box, header plate, compact red buttons. The client keeps
-- its buttons, callbacks and layout; its art is faded. No client field is written:
-- sizes go through the widget API.
local _, ns = ...

local PANEL_COORDS = ns.RED_COORDS

-- The client adds its own gap (about 4) between buttons, so a button is just its art.
local BUTTON_W, ART_H, GAP = 144, 21, 2
-- Room the client leaves for its taller header: lift the stack and shorten the box by this.
local TOP_TRIM = 18

local MENU_BUTTON = { set = "file", highlightSet = "raw", coords = PANEL_COORDS, inset = { 0, -GAP / 2, 0, GAP / 2 }, add = true }
local HEADER_BG = { "LeftBG", "RightBG", "CenterBG" }
local MENU_HEADER = { own = "plate", layer = "BACKGROUND", restyle = true, fontObject = ns.FONT_GOLD, keepTitle = true }
local CHILDREN = { children = true }

local active = false

local function SkinButton(button)
    if ns.Once(button, "menuButton") then
        ns.FadeKeys(button, ns.KEYS.LRC)
        ns.RedButtonArt(button, MENU_BUTTON)
        -- White labels as the old menu had; only its plate is gold.
        button:SetNormalFontObject("GameFontHighlight")
        button:SetHighlightFontObject("GameFontHighlight")
        button:SetDisabledFontObject("GameFontDisable")
        ns.SetPointOnce(button:GetFontString(), "CENTER", button, "CENTER", 0, -1)
    end
    button:SetSize(BUTTON_W, ART_H + GAP)
end

local function SkinButtons()
    if not active or not GameMenuFrame or not GameMenuFrame.buttonPool then return end
    -- Never in combat: our Layout() taints its fields, then its close is refused and
    -- Escape fails. Out of combat the client lays it out on every open.
    if InCombatLockdown() then return end
    for button in GameMenuFrame.buttonPool:EnumerateActive() do SkinButton(button) end
    -- Lay out again at our button size.
    if not GameMenuFrame.Layout then return end
    GameMenuFrame:Layout()
    -- Read fresh from that layout, so the lift is never added twice.
    for button in GameMenuFrame.buttonPool:EnumerateActive() do
        local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
        if point then ns.SetPointOnce(button, point, relativeTo, relativePoint, x or 0, (y or 0) + TOP_TRIM) end
    end
    local height = GameMenuFrame:GetHeight()
    if height and height > TOP_TRIM * 3 then GameMenuFrame:SetHeight(height - TOP_TRIM) end
end

local function SkinMenu()
    local menu = GameMenuFrame
    if not menu or not ns.Once(menu, "gameMenu") then return end
    ns.FadeTextures(menu.Border, 0, CHILDREN)
    ns.DialogBacking(menu)
    local header = menu.Header
    if header then
        ns.FadeKeys(header, HEADER_BG)
        -- The old plate said Main Menu.
        ns.DialogHeader(menu, MAIN_MENU, MENU_HEADER, header, header.Text)
    end
    ns.HookMethod(menu, "InitButtons", SkinButtons)
    SkinButtons()
end

-- In a fight, from the show after the client's own layout, before the menu draws: our look, our button size, the stack
-- closed up by the height each button above lost (section gaps kept), its width as its layout gives. Widget calls only.
local function SkinInFight()
    local menu = GameMenuFrame
    if not (active and menu and menu.buttonPool and InCombatLockdown()) then return end
    SkinMenu()
    local rows = {}
    for button in menu.buttonPool:EnumerateActive() do
        local top, height = button:GetTop(), button:GetHeight()
        if top and height then rows[#rows + 1] = { button = button, top = top, height = height } end
    end
    table.sort(rows, function(a, b) return a.top > b.top end)
    local lost = 0
    for _, row in ipairs(rows) do
        local button = row.button
        local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
        SkinButton(button)
        if point then ns.SetPointOnce(button, point, relativeTo, relativePoint, x or 0, (y or 0) + lost + TOP_TRIM) end
        lost = lost + row.height - button:GetHeight()
    end
    local height = menu:GetHeight()
    if height and height > (lost + TOP_TRIM) * 2 then menu:SetHeight(height - lost - TOP_TRIM) end
    menu:SetWidth(BUTTON_W + (menu.leftPadding or 0) + (menu.rightPadding or 0))
end

local hooked = false
local function Apply()
    active = true
    if not GameMenuFrame then ns.MissingPiece("GameMenuFrame") return end
    if not hooked then
        hooked = true
        GameMenuFrame:HookScript("OnShow", function()
            if not active then return end
            if InCombatLockdown() then
                SkinInFight()
                return
            end
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
