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
