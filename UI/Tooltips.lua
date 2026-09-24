local _, ns = ...

-- Client tooltips in the 1.x white rim; the bronze theme gives back Forever's own.
-- Watch only: our rim is a scriptless child of each NineSlice, so the client's show, hide and
-- re-layout carry it, and ApplyLayout never touches the region alpha that fades its bronze.

local ART = ns.ART
local pairs, type = pairs, type

-- Load-on-demand ones turn up on ADDON_LOADED. Not globals here: AuraButtonTooltip (styled below),
-- PrivateAurasTooltip and CatalogShopTooltip (unreachable, stay bronze); no NamePlate/SmallTextTooltip.
local TIPS = {
    "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ItemRefShoppingTooltip1",
    "ItemRefShoppingTooltip2", "EmbeddedItemTooltip", "GameNoHeaderTooltip", "GameSmallHeaderTooltip",
    "BuffFrameTooltip", "LootHistoryExtraTooltip", "SettingsTooltip", "QuickKeybindTooltip",
    "CustomizationNoHeaderTooltip", "FriendsTooltip", "PartyMemberBuffTooltip", "EncounterJournalTooltip",
    "LFGBrowseSearchEntryTooltip", "ConquestTooltip", "QueueStatusFrame", "BattlePetTooltip",
    "FloatingBattlePetTooltip", "FrameStackTooltip", "EventTraceTooltip", "PerksProgramTooltip",
}
local PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }

-- UI-Tooltip-Border cells as BackdropTemplate cuts them, stretched not tiled: no size math on secret widths.
local S, E = 0.0625, 0.9375
local EDGE, INSET = 16, 5

local rims = {}      -- tooltip -> our rim, false once a dress failed
local active = false
local theme = {}     -- theme.on: last painted, true bronze, false classic

local function Corner(rim, point, left, right)
    local tex = rim:CreateTexture(nil, "BORDER")
    tex:SetTexture(ART.TIP_BORDER)
    tex:SetTexCoord(left, right, S, E)
    tex:SetSize(EDGE, EDGE)
    tex:SetPoint(point, rim, point)
    return tex
end

local function Edge(rim, from, fromPoint, to, toPoint, ...)
    local tex = rim:CreateTexture(nil, "BORDER")
    tex:SetTexture(ART.TIP_BORDER)
    tex:SetTexCoord(...)
    tex:SetPoint("TOPLEFT", from, fromPoint)
    tex:SetPoint("BOTTOMRIGHT", to, toPoint)
end

local function MakeRim(slice)
    local rim = CreateFrame("Frame", nil, slice)
    rim:SetAllPoints(slice)
    -- At the tooltip's level so its text and bars draw over the rim.
    if rim.SetUsingParentLevel then rim:SetUsingParentLevel(true) else rim:SetFrameLevel(slice:GetFrameLevel()) end
    local tl = Corner(rim, "TOPLEFT", 0.5078125, 0.6171875)
    local tr = Corner(rim, "TOPRIGHT", 0.6328125, 0.7421875)
    local bl = Corner(rim, "BOTTOMLEFT", 0.7578125, 0.8671875)
    local br = Corner(rim, "BOTTOMRIGHT", 0.8828125, 0.9921875)
    -- Top and bottom cells are stored upright: rotated coords.
    Edge(rim, tl, "TOPRIGHT", tr, "BOTTOMLEFT", 0.2578125, E, 0.3671875, E, 0.2578125, S, 0.3671875, S)
    Edge(rim, bl, "TOPRIGHT", br, "BOTTOMLEFT", 0.3828125, E, 0.4921875, E, 0.3828125, S, 0.4921875, S)
    Edge(rim, tl, "BOTTOMLEFT", bl, "TOPRIGHT", 0.0078125, 0.1171875, S, E)
    Edge(rim, tr, "BOTTOMLEFT", br, "TOPRIGHT", 0.1328125, 0.2421875, S, E)
    -- Under the client's fill, which keeps its own colours; shows only where that stops short of the rim.
    local fill = rim:CreateTexture(nil, "BACKGROUND", nil, -8)
    fill:SetTexture(ART.TIP_BG)
    fill:SetPoint("TOPLEFT", rim, "TOPLEFT", INSET, -INSET)
    fill:SetPoint("BOTTOMRIGHT", rim, "BOTTOMRIGHT", -INSET, INSET)
    local color = _G.TOOLTIP_DEFAULT_BACKGROUND_COLOR
    if color then fill:SetVertexColor(color:GetRGB()) else fill:SetVertexColor(0.09, 0.09, 0.19) end
    return rim
end

local function Paint(tip, on)
    local slice = tip.NineSlice
    for i = 1, #PIECES do
        local piece = slice[PIECES[i]]
        if piece then piece:SetAlpha(on and 1 or 0) end
    end
    rims[tip]:SetShown(not on)
end

local function Dress(tip)
    if ns.IsForbidden(tip) then return end
    local slice = tip.NineSlice
    if type(slice) ~= "table" or not slice.GetFrameLevel then return end
    rims[tip] = MakeRim(slice)
    Paint(tip, theme.on)
end

local function DressNew()
    for i = 1, #TIPS do
        local tip = _G[TIPS[i]]
        if tip and rims[tip] == nil then
            rims[tip] = false
            ns.SafeCall(Dress, tip)
        end
    end
end

-- The target and focus aura tooltip is forbidden; the client's own secure delegate styles it.
local auraClassic = false
local function StyleAuras()
    local want = active and theme.on == false
    local inbound = _G.AuraContainerInbound
    if want == auraClassic or not inbound then return end
    if want then
        local ok = pcall(inbound.SetTooltipBackdrop, {
            backdropInfo = { bgFile = ART.TIP_BG, edgeFile = ART.TIP_BORDER, tile = true, tileEdge = true,
                tileSize = 16, edgeSize = EDGE, insets = { left = INSET, right = INSET, top = INSET, bottom = INSET } },
            borderColor = CreateColor(1, 1, 1, 1),
            centerColor = _G.TOOLTIP_DEFAULT_BACKGROUND_COLOR,
        })
        if ok then auraClassic = true end
    elseif pcall(inbound.ResetTooltipStyle) then
        auraClassic = false
    end
end

local watch
local function OnAddonLoaded()
    if not active then return end
    DressNew()
    if auraClassic ~= (theme.on == false) and _G.AuraContainerInbound then ns.WhenCalm("tooltipAuras", StyleAuras) end
end

-- Every pass calls these: work only on a change.
local function Apply()
    if not watch then watch = ns.EventFrame("ADDON_LOADED", OnAddonLoaded) end
    active = true
    if ns.ThemeTurned(theme) then
        for tip, rim in pairs(rims) do
            if rim then ns.SafeCall(Paint, tip, theme.on) end
        end
        ns.WhenCalm("tooltipAuras", StyleAuras)
    end
    DressNew()
end

local function Restore()
    if not active then return end
    active, theme.on = false, nil
    for tip, rim in pairs(rims) do
        if rim then ns.SafeCall(Paint, tip, true) end
    end
    ns.WhenCalm("tooltipAuras", StyleAuras)
end

ns.RegisterModule("tooltips", { apply = Apply, restore = Restore })
