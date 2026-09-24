local _, ns = ...

-- Old window chrome on client panels: metal nine-slice, round portrait, small X,
-- stone title strip. Panels.lua lists the windows.

-- Shared by WindowChrome, Tabs, Loot, NpcWindows, PanelAfters and Panels.
local P = {
    active = false,
    skinned = {},                                      -- window -> dressed; keeps an after from running twice
    windowAfter = setmetatable({}, { __mode = "k" }),  -- window -> after, for the map's re-skin
    after = {},                                        -- window name -> after, read by Panels' WINDOWS
    BOTTOM_LIFT = 10,
    MAP_LIFT = 5,   -- full lift cut the map's coordinate line, none left a gap
}
ns.panels = P

local CORNER, EDGE = 132, 128
local METAL = "frameMetal"
local FULL = { 0, 1, 0, 1 }

-- Corner cuts from the UIFrameMetal sheet: portrait ring top left, or plain.
local CORNERS = {
    portrait = {
        TopLeftCorner = { 0.263671875, 0.521484375, 0.263671875, 0.521484375 },
        TopRightCorner = { 0.001953125, 0.259765625, 0.263671875, 0.521484375 },
        BottomLeftCorner = { 0.001953125, 0.259765625, 0.001953125, 0.259765625 },
        BottomRightCorner = { 0.263671875, 0.521484375, 0.001953125, 0.259765625 },
    },
    plain = {
        TopLeftCorner = { 0.525390625, 0.783203125, 0.001953125, 0.259765625 },
        TopRightCorner = { 0.001953125, 0.259765625, 0.263671875, 0.521484375 },
        BottomLeftCorner = { 0.001953125, 0.259765625, 0.001953125, 0.259765625 },
        BottomRightCorner = { 0.263671875, 0.521484375, 0.001953125, 0.259765625 },
    },
}
local EDGES = {
    -- 48 rows only: this client's sheet has a dark bar of other art ~55 rows in.
    TopEdge = { key = "frameMetalH", coords = { 0, 1, 0.263671875, 0.263671875 + 48 / 512 }, w = EDGE, h = 48, tileH = true },
    BottomEdge = { key = "frameMetalH", coords = { 0, 1, 0.001953125, 0.259765625 }, w = EDGE, h = CORNER, tileH = true },
    LeftEdge = { key = "frameMetalV", coords = { 0.001953125, 0.259765625, 0, 1 }, w = CORNER, h = EDGE, tileV = true },
    RightEdge = { key = "frameMetalV", coords = { 0.263671875, 0.521484375, 0, 1 }, w = CORNER, h = EDGE, tileV = true },
}
local CORNER_SIZE = { w = CORNER, h = CORNER }

local function NineSlice(frame, style, lift, keepLeft)
    local slice = frame.NineSlice
    if not slice then return false end
    local corners = CORNERS[style] or CORNERS.portrait
    for key, coords in pairs(corners) do
        local tex = slice[key]
        if tex then
            ns.Dress(tex, METAL, CORNER_SIZE, nil, nil, nil, nil, nil, coords)
            -- Plain corner on a portrait layout: 8px out, not the portrait's 13.
            if style == "plain" and key == "TopLeftCorner" and not keepLeft then
                local point, rel, relPoint, x, y = tex:GetPoint(1)
                if point and x and x < -8 then tex:SetPoint(point, rel, relPoint, -8, y) end
            end
            -- Client hangs bottom corners 3px low and the old metal's line sits at the
            -- foot of a taller piece: lift them to the content (the bottom edge follows).
            if key == "BottomLeftCorner" or key == "BottomRightCorner" then
                local point, rel, relPoint, x, y = tex:GetPoint(1)
                if point then
                    if tex.fcuiBaseY == nil then tex.fcuiBaseY = y or 0 end
                    tex:SetPoint(point, rel, relPoint, x or 0, tex.fcuiBaseY + (tonumber(lift) or P.BOTTOM_LIFT))
                end
            end
        end
    end
    for key, edge in pairs(EDGES) do
        local tex = slice[key]
        if tex then
            local primary, fallback = ns.TexPath(edge.key)
            local ok = tex:SetTexture(primary, edge.tileH, edge.tileV)
            if ok == false then tex:SetTexture(fallback, edge.tileH, edge.tileV) end
            ns.BronzeTint(tex)
            tex:SetSize(edge.w, edge.h)
            tex:SetTexCoord(unpack(edge.coords))
        end
    end
    return true
end

-- The portrait corner's ring, for a second portrait (trade window).
function P.PortraitRing(tex)
    ns.Dress(tex, METAL, CORNER_SIZE, nil, nil, nil, nil, nil, CORNERS.portrait.TopLeftCorner)
end

-- Equal within 1e-6 of b (absolute below 1), like Setters' default.
function P.Near(a, b)
    local size = math.abs(b)
    if size < 1 then size = 1 end
    return math.abs(a - b) <= size * 1e-6
end

local CLOSE = { size = { 32, 32 }, coords = FULL, fill = true, add = true }

-- The X's socket is part of the top right corner art: anchor to it, whatever its offset.
function P.PlaceInSocket(button, host)
    local corner = host and host.NineSlice and host.NineSlice.TopRightCorner
    button:ClearAllPoints()
    if corner then
        button:SetPoint("TOPRIGHT", corner, "TOPRIGHT", 0.6, -11)
    else
        button:SetPoint("TOPRIGHT", host, "TOPRIGHT", 4.6, 5)
    end
end

function ns.SkinCloseButton(button, keepPosition)
    if not button then return end
    ns.DressStates(button, "closeUp", "closeDown", "closeDisabled", "closeHighlight", CLOSE)
    if not keepPosition then P.PlaceInSocket(button, button:GetParent()) end
end

local MAX_MIN = {
    { "MaximizeButton", "biggerUp", "biggerDown", "biggerDisabled" },
    { "MinimizeButton", "smallerUp", "smallerDown", "smallerDisabled" },
}
local MAX_MIN_STATES = { coords = FULL, fill = true, hit = { 5, 5, 5, 5 } }

local function SkinMaxMin(button)
    if not button or not button.MaximizeButton then return end
    for i = 1, #MAX_MIN do
        local b = MAX_MIN[i]
        ns.DressStates(button[b[1]], b[2], b[3], b[4], "closeHighlight", MAX_MIN_STATES)
    end
end
P.SkinMaxMin = SkinMaxMin

-- Escape won't close a window an addon wrote on mid-fight: windows met in
-- combat keep the client's art until it ends.
local waiting = {}
local waitWatch

local function SkinLater(frame, opts)
    waiting[frame] = opts or {}
    if waitWatch then return end
    waitWatch = CreateFrame("Frame")
    waitWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
    waitWatch:SetScript("OnEvent", function()
        if InCombatLockdown() then return end
        local held = waiting
        waiting = {}
        for held_frame, held_opts in pairs(held) do
            ns.SafeCall(ns.SkinWindow, held_frame, held_opts)
        end
    end)
end

local ROCK = { coords = FULL }
local STREAKS = { vert = false, coords = { 0, 1, 0.671875, 0.9609375 } }
local MARBLE = { coords = FULL }
local TITLE_STRIP = { vert = false, coords = { 0, 1, 0.2890625, 0.421875 } }

local function SkinSystemTab(tab, lift)
    tab.fcuiLift = lift
    ns.SkinBottomTab(tab)
end

-- Title between the ring (or plain corner) and the X, stone strip under it.
-- plainLeft: strip start beside a plain corner (6 at -8 out, 2 at -12).
local function PlaceTitle(frame, plain, plainLeft)
    local left = plainLeft or 6
    local title = frame.TitleContainer
    if title then
        title:ClearAllPoints()
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", plain and left or 58, 0)
        title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -58, 0)
    end
    local strip = frame.fcui and frame.fcui.titleStrip
    if strip then
        strip:ClearAllPoints()
        strip:SetPoint("TOPLEFT", frame, "TOPLEFT", plain and left or 2, -3)
        strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -25, -3)
    end
end

-- Metal back after the client re-lays its border (sized windows); never mid-fight.
-- Plain top left stays where the client puts it, in line with the bottom left.
function P.Reborder(frame, plain, lift)
    if not P.active or InCombatLockdown() then return false end
    if not NineSlice(frame, plain and "plain" or "portrait", lift, true) then return false end
    PlaceTitle(frame, plain, 2)
    return true
end

-- List marble a shade darker, as in 1.x: a black veil, since a vertex colour on the
-- floor fights its bronze tint (grey at login, unshaded after a toggle).
function P.ShadeFloor(frame)
    local floor = frame.fcui and frame.fcui.insetFloor
    if not floor then return end
    local veil = ns.OwnTexture(frame, "insetVeil", "BACKGROUND", 0)
    veil:SetColorTexture(0, 0, 0, 1 - ns.PANE_SHADE)
    veil:SetAllPoints(floor)
    veil:SetShown(floor:IsShown())
end

-- Border, ring, title strip, close button, tabs. opts (read only): portrait,
-- backing, lift, tabLift, backingRight, backingBottom, topTabs, scrollBars, after.
function ns.SkinWindow(frame, opts)
    if not frame or not P.active then return end
    opts = opts or {}
    local name = frame:GetName()
    if InCombatLockdown() and not (name and name:find("ForeverClassicUI", 1, true)) then
        SkinLater(frame, opts)
        return
    end
    -- A border over its content (the map) passes a smaller lift.
    if not NineSlice(frame, opts.portrait == false and "plain" or "portrait", opts.lift) then return end
    frame.fcui = frame.fcui or {}
    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait or (name and _G[name .. "Portrait"])
    if portrait and opts.portrait ~= false then
        portrait:SetSize(61, 61)
        portrait:ClearAllPoints()
        portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", -6, 8)
        if ns.WatchPortrait then ns.WatchPortrait(portrait) end
    end
    -- Old ButtonFrameTemplate: rock out to the metal (client backing stops at its
    -- thinner border), streaks under the title, marble in the inset. Not on the map.
    if opts.backing ~= false then
        local backing = ns.TileTex(ns.OwnTexture(frame, "backing", "BACKGROUND", -2), "rockBg", ROCK)
        -- Client rock covers ours; parchment stays (registrar/charter gold text needs it).
        local bg = frame.Bg or (frame:GetName() and _G[frame:GetName() .. "Bg"])
        if bg and bg.SetAlpha and bg.IsObjectType and bg:IsObjectType("Texture") then
            local atlas = bg.GetAtlas and bg:GetAtlas()
            local file = bg.GetTexture and bg:GetTexture()
            local parchment = (type(atlas) == "string" and atlas:lower():find("parchment", 1, true) ~= nil)
                or (type(file) == "string" and file:lower():find("parchment", 1, true) ~= nil)
            if parchment then bg:SetAlpha(1) else bg:SetAlpha(0) end
        end
        if frame.TopTileStreaks then frame.TopTileStreaks:SetAlpha(0) end
        backing:ClearAllPoints()
        -- Flush left (a 4px inset showed the world: mail, collections); 4 in on the
        -- right by default, where most windows' metal stands.
        backing:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        backing:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(tonumber(opts.backingRight) or 4), tonumber(opts.backingBottom) or 0)
        backing:Show()
        local streaks = ns.TileTex(ns.OwnTexture(frame, "streaks", "BACKGROUND", -1), "frameSheet", STREAKS)
        streaks:SetHeight(37)
        streaks:ClearAllPoints()
        streaks:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -21)
        streaks:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -21)
        streaks:Show()
        local inset = frame.Inset or (name and _G[name .. "Inset"])
        local floor = ns.OwnTexture(frame, "insetFloor", "BACKGROUND", -1)
        if inset and inset.GetObjectType and inset:GetObjectType() == "Frame" then
            -- The inset's thin border reads as a gap inside the metal.
            if inset.NineSlice then ns.FadeTextures(inset.NineSlice) end
            if inset.Bg and inset.Bg.SetAlpha then inset.Bg:SetAlpha(0) end
            ns.TileTex(floor, "marbleBg", MARBLE)
            floor:ClearAllPoints()
            floor:SetPoint("TOPLEFT", inset, "TOPLEFT", 0, 0)
            floor:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", 0, 0)
            floor:Show()
        else
            floor:Hide()
        end
    elseif frame.fcui and frame.fcui.backing then
        frame.fcui.backing:Hide()
        if frame.fcui.streaks then frame.fcui.streaks:Hide() end
        if frame.fcui.insetFloor then frame.fcui.insetFloor:Hide() end
    end
    local strip = ns.TileTex(ns.OwnTexture(frame, "titleStrip", "BACKGROUND"), "frameSheet", TITLE_STRIP)
    strip:SetHeight(17)
    PlaceTitle(frame, opts.portrait == false)
    strip:Show()
    ns.SkinCloseButton(frame.CloseButton or (name and _G[name .. "CloseButton"]))
    if frame.MaximizeMinimizeButton then
        SkinMaxMin(frame.MaximizeMinimizeButton)
        frame.MaximizeMinimizeButton:SetSize(32, 32)
        local close = frame.CloseButton or (name and _G[name .. "CloseButton"])
        if close then
            frame.MaximizeMinimizeButton:ClearAllPoints()
            frame.MaximizeMinimizeButton:SetPoint("RIGHT", close, "LEFT", 8.5, 0)
        end
    end
    -- Tabs: a tab system, or the classic numbered globals.
    if frame.TabSystem then ns.EachChild(frame.TabSystem, SkinSystemTab, opts.tabLift or opts.lift) end
    if name then
        -- Numbers can skip (social window: 1, 3, 4), so try each.
        for i = 1, 10 do
            local numbered = _G[name .. "Tab" .. i]
            if numbered then
                numbered.fcuiLift = opts.tabLift or opts.lift
                if opts.topTabs then ns.SkinTopTab(numbered) else ns.SkinBottomTab(numbered) end
            end
        end
    end
    -- Old knob and arrows on the thin scroll bars inside; scrollBars = false: the after dresses them.
    if ns.SkinScrollBarsUnder and opts.scrollBars ~= false then ns.SkinScrollBarsUnder(frame, 5) end
    if opts.after then opts.after(frame) end
    P.skinned[frame] = true
end
