-- The equipment manager beside the classic sheet. 1.x had no set
-- manager; Wrath, the first old client with one, put a small arrow on
-- the paper doll that opened the sets in a dialog docked to the right of
-- the window. That is what this does: an arrow on the sheet, and
-- Blizzard's own equipment manager pane (its list, Equip, Save and New
-- Set) inside a dialog of ours in the old dialog art. Nothing of
-- Blizzard's state is written; the pane is anchored, shown and hidden.
local _, ns = ...

local DIALOG_BG = "Interface\\DialogFrame\\UI-DialogBox-Background"
local DIALOG_BORDER = "Interface\\DialogFrame\\UI-DialogBox-Border"
local DIALOG_HEADER = "Interface\\DialogFrame\\UI-DialogBox-Header"
local ARROW_OPEN = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"
local ARROW_OPEN_DOWN = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down"
local ARROW_CLOSE = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up"
local ARROW_CLOSE_DOWN = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down"
local HILIGHT = "Interface\\Buttons\\UI-Common-MouseHilight"

-- The dialog's size and where it docks: its border art carries a
-- transparent margin, so its left edge tucks under the sheet's art edge
-- and its visible right edge is MARGIN short of its width.
local PANE_W, PANE_H = 262, 440
local MARGIN = 8
local DOCK_Y = -8
-- The arrow: in the corner between the level line and the first slot.
local ARROW_SIZE = 24
local ARROW_X, ARROW_Y = -40, -50

local active = false
local open = false
local pane, toggle, savedPoints

local function Manager()
    return PaperDollFrame and PaperDollFrame.EquipmentManagerPane
end

-- Read by the sheet: how far past its art the open dialog reaches, so
-- anything else docking beside the sheet goes past the dialog.
function ns.EquipmentPaneExtent()
    if active and open and pane and pane:IsShown() then return PANE_W - 2 * MARGIN end
    return 0
end

function ns.EquipmentPaneOpen()
    return active and open
end

local function SheetArtRight()
    if ns.SheetArtEdges then return (ns.SheetArtEdges()) end
    return 349
end

-- The pane leaves Blizzard's anchors for ours while the dialog is up,
-- and gets them back when the module turns off.
local function Place(manager)
    if not savedPoints then
        savedPoints = {}
        for i = 1, manager:GetNumPoints() do savedPoints[i] = { manager:GetPoint(i) } end
    end
    manager:ClearAllPoints()
    manager:SetPoint("TOPLEFT", pane, "TOPLEFT", MARGIN + 6, -40)
    manager:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -MARGIN - 4, MARGIN + 4)
    for _, region in ipairs({ manager:GetRegions() }) do
        if region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
    if PaperDollFrame then
        pane:SetFrameLevel(math.max(PaperDollFrame:GetFrameLevel(), manager:GetFrameLevel() - 1))
    end
end

local function Unplace(manager)
    if not savedPoints then return end
    manager:ClearAllPoints()
    for _, p in ipairs(savedPoints) do manager:SetPoint(unpack(p)) end
    for _, region in ipairs({ manager:GetRegions() }) do
        if region:IsObjectType("Texture") then region:SetAlpha(1) end
    end
    savedPoints = nil
end

local function SetArrow()
    if not toggle then return end
    ns.SetButtonFile(toggle, "Normal", open and ARROW_CLOSE or ARROW_OPEN)
    ns.SetButtonFile(toggle, "Pushed", open and ARROW_CLOSE_DOWN or ARROW_OPEN_DOWN)
end

local function Sync()
    if not pane then return end
    local manager = Manager()
    if active and open then
        pane:Show()
        if manager then
            Place(manager)
            if not manager:IsShown() then manager:Show() end
        end
    else
        pane:Hide()
        if manager and manager:IsShown() and (active or savedPoints) then manager:Hide() end
    end
    SetArrow()
end

local function SetOpen(state)
    open = state and true or false
    Sync()
    PlaySound(open and SOUNDKIT.IG_CHARACTER_INFO_OPEN or SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    if EventRegistry and EventRegistry.TriggerEvent then EventRegistry:TriggerEvent("ClassicUIForever.CharacterSheetLaid") end
end

local function Build()
    if pane or not PaperDollFrame or not CharacterFrame then return end
    pane = CreateFrame("Frame", "ForeverClassicUIEquipmentPane", PaperDollFrame, "BackdropTemplate")
    pane:SetSize(PANE_W, PANE_H)
    pane:SetBackdrop({
        bgFile = DIALOG_BG, edgeFile = DIALOG_BORDER, tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    ns.BronzeBackdrop(pane)
    pane:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", SheetArtRight() - MARGIN + 2, DOCK_Y)
    pane:EnableMouse(true)
    pane:Hide()

    local header = pane:CreateTexture(nil, "ARTWORK")
    ns.SetFile(header, DIALOG_HEADER)
    header:SetSize(300, 64)
    header:SetPoint("TOP", pane, "TOP", 0, 12)
    local title = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", header, "TOP", 0, -14)
    title:SetText(EQUIPMENT_MANAGER or "Equipment Manager")

    local close = CreateFrame("Button", nil, pane, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() SetOpen(false) end)
    if ns.SkinCloseButton then ns.SkinCloseButton(close, true) end

    toggle = CreateFrame("Button", "ForeverClassicUIEquipmentToggle", PaperDollFrame)
    toggle:SetSize(ARROW_SIZE, ARROW_SIZE)
    toggle:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", ARROW_X, ARROW_Y)
    toggle:SetHighlightTexture(HILIGHT, "ADD")
    toggle:SetScript("OnClick", function() SetOpen(not open) end)
    toggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(EQUIPMENT_MANAGER or "Equipment Manager")
        GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    SetArrow()

    -- Blizzard's expand path shows and hides its panes when the doll
    -- shows; ours settles after it.
    PaperDollFrame:HookScript("OnShow", function()
        if active then C_Timer.After(0, Sync) end
    end)
end

function ns.EquipmentPaneApply()
    active = true
    Build()
    if toggle then toggle:Show() end
    Sync()
end

function ns.EquipmentPaneRestore()
    active = false
    local manager = Manager()
    if pane then pane:Hide() end
    if toggle then toggle:Hide() end
    if manager then
        if manager:IsShown() and savedPoints then manager:Hide() end
        Unplace(manager)
    end
end
