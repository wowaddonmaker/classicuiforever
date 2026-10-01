local _, ns = ...

-- Classic Era's small world map: its 610 x 438 art, the quest pane in a second hole the art widens across.
-- Nav bar row, filter, pin and coordinates show only with "Map navigation bar".
-- Size and anchors change inside a snippet, out of combat: from our code the map's refit would run as ours.

local P = ns.panels

-- Classic Era's numbers (Blizzard_WorldMap Vanilla): frame, art pieces, the map's hole, title, close button.
local ERA_W, ERA_H = 610, 438
local ART_LEFT_FILE, ART_RIGHT_FILE = 334393, 334394     -- UI-WorldMapSmall-Left / -Right
local ART_X, ART_LEFT_W, ART_RIGHT_W, ART_H = 12, 512, 128, 512
local CANVAS_LEFT, CANVAS_TOP, CANVAS_RIGHT, CANVAS_BOTTOM = 20, 22, 600, 410
local TITLE_Y = -12
local CLOSE_X, CLOSE_Y = -44, 5                          -- from the right art piece's top right
local MAXIMIZE_GAP = 10
-- Under the picture as Era's (LowerFrameLevel); only the footer's top line, art rows 405 to 412, drawn over it.
local ART_UNDER_MAP = 1
local FOOT_LINE_OVER_MAP = 2
local FOOT_LINE_TOP, FOOT_LINE_BOTTOM = 405, 412
-- Quest pane: its own hole right of the map's; the art widens across it. Rect from the frame's top left.
local QUEST_PANE_X = 611        -- pane's left (+ right)
local QUEST_PANE_Y = 22         -- pane's top, down from the frame's top (+ lower)
local QUEST_PANE_W = 330        -- pane's width (+ wider; the window widens with it)
local QUEST_PANE_H = 383        -- pane's height (+ taller)
local DIVIDER_X = 590           -- divider between map and pane: its left, under the map's right end (+ right)
local DIVIDER_GAP = -2          -- divider: the pane's edge from the map's edge (- overlaps)
-- Era art columns and rows: the right piece's column a picture ends at (the map's at 600) and its art's end; a hole's
-- right edge (right piece), left edge (left piece) and their rows; the left piece's first clear column.
local PICTURE_RIGHT_COL, ART_RIGHT_COL = 76, 86
local EDGE_RIGHT_L, EDGE_RIGHT_R, EDGE_LEFT_L, EDGE_LEFT_R = 66, 81, 0, 18
local EDGE_TOP, EDGE_BOTTOM = 20, 412
local FILL_MIN_COL = 17
-- Forever's own small map and its picture's place (its XML: 2 in, under the 67 tall title row, 3 in from the right
-- past the quest pane, 2 up), restored when its layout is wanted.
local FOREVER_W, FOREVER_H = 702, 534
local FOREVER_LEFT, FOREVER_TOP, FOREVER_RIGHT, FOREVER_BOTTOM = 2, 67, 3, 2
-- Its quest pane (its AttachQuestLog): width, then 3 in from the right, 25 down, 3 up.
local FOREVER_PANE_W, FOREVER_PANE_RIGHT, FOREVER_PANE_TOP, FOREVER_PANE_BOTTOM = 333, 3, 25, 3
-- Its quest details: a fixed 502 tall under the pane's top (1 down), fitted to Era's shorter pane; the text in it
-- 5 in, 43 down, 430 tall.
local FOREVER_DETAILS_H, DETAILS_TOP = 502, 1
local FOREVER_DETAILS_TEXT_X, FOREVER_DETAILS_TEXT_Y, FOREVER_DETAILS_TEXT_H = 5, -43, 430
-- Era layout: the details text, its scroll bar, Back and the parchment up into the header band's room (+ up).
local DETAILS_LIFT = 14

local EXTRAS = { "NavBar", "WorldMapTrackingOptionsButton", "WorldMapTrackingPinButton" }

local layout, art, title
local hidden = {}          -- client piece -> true while we hold it hidden
local eraDressed
local titleFor             -- the map id the title was written for

-- The map picture anchors from its parent, the map frame: a snippet's anchor target must be "$parent" or protected.
local LAY = [[
    local map, canvas = self:GetFrameRef("map"), self:GetFrameRef("canvas")
    local w = self:GetAttribute("w")
    if w then
        map:SetWidth(w)
        map:SetHeight(self:GetAttribute("h"))
    end
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", "$parent", "TOPLEFT", self:GetAttribute("l"), self:GetAttribute("t"))
    canvas:SetPoint("BOTTOMRIGHT", "$parent", self:GetAttribute("rp"), self:GetAttribute("r"), self:GetAttribute("b"))
    local pane = self:GetFrameRef("pane")
    if pane then
        pane:ClearAllPoints()
        pane:SetPoint(self:GetAttribute("qp"), "$parent", self:GetAttribute("qp"), self:GetAttribute("qx1"),
            self:GetAttribute("qy1"))
        pane:SetPoint("BOTTOMRIGHT", "$parent", self:GetAttribute("qr"), self:GetAttribute("qx2"), self:GetAttribute("qy2"))
    end
    local details = self:GetFrameRef("details")
    if details then details:SetHeight(self:GetAttribute("dh")) end
    local text = self:GetFrameRef("detailsText")
    if text then
        text:ClearAllPoints()
        text:SetPoint("TOPLEFT", "$parent", "TOPLEFT", self:GetAttribute("dtx"), self:GetAttribute("dty"))
        text:SetHeight(self:GetAttribute("dth"))
    end
]]

-- The client fits the picture to its box only as it opens: hidden and shown here, its own open refits it.
local REFIT = [[
    local map = self:GetFrameRef("map")
    if map:IsShown() then
        map:Hide(true)
        map:Show(true)
    end
]]

local function Map() return WorldMapFrame end

local function WantEra()
    local map = Map()
    return map and P.active and ns.db.worldMap ~= false and ns.db.mapNavBar ~= true and not map:IsMaximized()
end

local function PaneShown()
    local pane = Map().QuestLog
    return pane and pane:IsShown() and true or false
end

local function Layout()
    if layout then return layout end
    local map = Map()
    layout = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    layout:SetFrameRef("map", map)
    layout:SetFrameRef("canvas", map.ScrollContainer)
    if map.QuestLog then layout:SetFrameRef("pane", map.QuestLog) end
    local details = map.QuestLog and map.QuestLog.DetailsFrame
    if details then layout:SetFrameRef("details", details) end
    if details and details.ScrollFrame then layout:SetFrameRef("detailsText", details.ScrollFrame) end
    return layout
end

-- The right art piece's left and the window's width with the pane open: its hole ends at the pane's right.
local function PaneArtX() return QUEST_PANE_X + QUEST_PANE_W - PICTURE_RIGHT_COL end
local function PaneWindowW() return PaneArtX() + ART_RIGHT_COL end

-- The map picture's two anchors (from the map frame's top left, then its given corner), the quest pane's (its first
-- corner from the same corner of the frame, its bottom right from qr) and the frame's size.
local function Target(era)
    local map = Map()
    if era then
        return { l = CANVAS_LEFT, t = -CANVAS_TOP, rp = "TOPLEFT", r = CANVAS_RIGHT, b = -CANVAS_BOTTOM,
            qp = "TOPLEFT", qx1 = QUEST_PANE_X, qy1 = -QUEST_PANE_Y,
            qr = "TOPLEFT", qx2 = QUEST_PANE_X + QUEST_PANE_W, qy2 = -(QUEST_PANE_Y + QUEST_PANE_H),
            dh = QUEST_PANE_H - DETAILS_TOP, dtx = FOREVER_DETAILS_TEXT_X, dty = FOREVER_DETAILS_TEXT_Y + DETAILS_LIFT,
            dth = FOREVER_DETAILS_TEXT_H - (FOREVER_DETAILS_H - (QUEST_PANE_H - DETAILS_TOP)) + DETAILS_LIFT,
            w = PaneShown() and PaneWindowW() or ERA_W, h = ERA_H }
    end
    local pane = PaneShown() and (map.questLogWidth or FOREVER_PANE_W) or 0
    local t = { l = FOREVER_LEFT, t = -FOREVER_TOP, rp = "BOTTOMRIGHT", r = -(FOREVER_RIGHT + pane), b = FOREVER_BOTTOM,
        qp = "TOPRIGHT", qx1 = -FOREVER_PANE_RIGHT, qy1 = -FOREVER_PANE_TOP,
        qr = "BOTTOMRIGHT", qx2 = -FOREVER_PANE_RIGHT, qy2 = FOREVER_PANE_BOTTOM, dh = FOREVER_DETAILS_H,
        dtx = FOREVER_DETAILS_TEXT_X, dty = FOREVER_DETAILS_TEXT_Y, dth = FOREVER_DETAILS_TEXT_H }
    if not map:IsMaximized() then
        t.w, t.h = (map.minimizedWidth or FOREVER_W) + pane, map.minimizedHeight or FOREVER_H
    end
    return t
end

local function Near(a, b) return a and math.abs(a - b) < 0.5 end

local function PointIs(region, i, point, rel, relPoint, x, y)
    local p, r, rp, px, py = region:GetPoint(i)
    return p == point and r == rel and rp == relPoint and Near(px, x) and Near(py, y)
end

local function Laid(t)
    local map = Map()
    local canvas = map.ScrollContainer
    if t.w and not (Near(map:GetWidth(), t.w) and Near(map:GetHeight(), t.h)) then return false end
    local pane = map.QuestLog
    local details = pane and pane.DetailsFrame
    if details and not Near(details:GetHeight(), t.dh) then return false end
    local text = details and details.ScrollFrame
    if text and not (Near(text:GetHeight(), t.dth) and text:GetNumPoints() == 1
        and PointIs(text, 1, "TOPLEFT", details, "TOPLEFT", t.dtx, t.dty)) then
        return false
    end
    if pane and not (pane:GetNumPoints() == 2 and PointIs(pane, 1, t.qp, map, t.qp, t.qx1, t.qy1)
        and PointIs(pane, 2, "BOTTOMRIGHT", map, t.qr, t.qx2, t.qy2)) then
        return false
    end
    return canvas:GetNumPoints() == 2 and PointIs(canvas, 1, "TOPLEFT", map, "TOPLEFT", t.l, t.t)
        and PointIs(canvas, 2, "BOTTOMRIGHT", map, t.rp, t.r, t.b)
end

local PANE_KEYS = { "qp", "qx1", "qy1", "qr", "qx2", "qy2", "dh", "dtx", "dty", "dth" }
local layFailed   -- a refused snippet stops the layout for the session, reported once
local laidAt      -- when a lay last moved the picture's box; its fit is checked a frame later
local function Lay(t)
    if layFailed or InCombatLockdown() or Laid(t) then return end
    laidAt = GetTime()
    local lay = Layout()
    lay:SetAttribute("w", t.w)
    lay:SetAttribute("h", t.h)
    lay:SetAttribute("l", t.l)
    lay:SetAttribute("t", t.t)
    lay:SetAttribute("rp", t.rp)
    lay:SetAttribute("r", t.r)
    lay:SetAttribute("b", t.b)
    for _, key in ipairs(PANE_KEYS) do lay:SetAttribute(key, t[key]) end
    local ok, err = pcall(lay.Execute, lay, LAY)
    if not ok then
        layFailed = true
        geterrorhandler()("world map layout: " .. tostring(err))
    end
end

-- The client's fit (its base scale) against the box the picture has now.
local function Fitted()
    local map = Map()
    local canvas = map.ScrollContainer
    local id = map:GetMapID()
    local layers = id and C_Map.GetMapArtLayers(id)
    local layer = layers and layers[1]
    if not (layer and canvas.baseScale) then return true end
    local want = math.min(canvas:GetWidth() / layer.layerWidth, canvas:GetHeight() / layer.layerHeight)
    return math.abs(canvas.baseScale - want) < 0.001
end

-- Once per lay, out of combat. Never with the gamepad on: the hide drops the map from its focus, and the show from a
-- snippet never gives it back (nothing selected until Start). The box is laid while the map is shut instead.
local function Refit()
    if not laidAt or laidAt == GetTime() or layFailed or InCombatLockdown() then return end
    laidAt = nil
    if ns.GamepadUI() or not Map():IsShown() or Fitted() then return end
    local ok, err = pcall(Layout().Execute, Layout(), REFIT)
    if not ok then geterrorhandler()("world map refit: " .. tostring(err)) end
end

local function Art()
    if art then return art end
    local map = Map()
    art = ns.NewFrame("Frame", nil, map)
    art:SetSize(ERA_W, ERA_H)
    art:SetPoint("TOPLEFT", map, "TOPLEFT", 0, 0)
    art:SetFrameLevel(math.max(0, map.ScrollContainer:GetFrameLevel() - ART_UNDER_MAP))
    -- The footer's top line over the picture (the client's tiled backing fills its box), under its pins (2000 up).
    local foot = ns.NewFrame("Frame", nil, art)
    foot:SetAllPoints(art)
    foot:SetFrameLevel(map.ScrollContainer:GetFrameLevel() + FOOT_LINE_OVER_MAP)
    local footRows = FOOT_LINE_BOTTOM - FOOT_LINE_TOP
    local footRun = ART_X + ART_LEFT_W - CANVAS_LEFT
    for i, run in ipairs({ { CANVAS_LEFT, footRun }, { CANVAS_LEFT + footRun, CANVAS_RIGHT - CANVAS_LEFT - footRun } }) do
        local line = foot:CreateTexture(nil, "ARTWORK")
        line:SetTexture(ART_LEFT_FILE)
        line:SetSize(run[2], footRows)
        line:SetTexCoord((ART_LEFT_W - run[2]) / ART_LEFT_W, 1, FOOT_LINE_TOP / ART_H, FOOT_LINE_BOTTOM / ART_H)
        line:SetPoint("TOPLEFT", art, "TOPLEFT", run[1], -FOOT_LINE_TOP)
        foot[i] = line
    end
    local left = art:CreateTexture(nil, "ARTWORK")
    left:SetTexture(ART_LEFT_FILE)
    left:SetSize(ART_LEFT_W, ART_H)
    left:SetPoint("TOPLEFT", art, "TOPLEFT", ART_X, 0)
    local right = art:CreateTexture(nil, "ARTWORK")
    right:SetTexture(ART_RIGHT_FILE)
    right:SetSize(ART_RIGHT_W, ART_H)
    art.right = right
    -- Pane open: the left piece's end repeated up to the right piece, the two hole edges as a divider, dark behind.
    art.fill = art:CreateTexture(nil, "ARTWORK")
    art.fill:SetTexture(ART_LEFT_FILE)
    art.edgeRight = art:CreateTexture(nil, "ARTWORK", nil, 1)
    art.edgeRight:SetTexture(ART_RIGHT_FILE)
    art.edgeRight:SetSize(EDGE_RIGHT_R - EDGE_RIGHT_L, EDGE_BOTTOM - EDGE_TOP)
    art.edgeRight:SetTexCoord(EDGE_RIGHT_L / ART_RIGHT_W, EDGE_RIGHT_R / ART_RIGHT_W, EDGE_TOP / ART_H, EDGE_BOTTOM / ART_H)
    art.edgeRight:SetPoint("TOPLEFT", art, "TOPLEFT", DIVIDER_X, -EDGE_TOP)
    art.edgeLeft = art:CreateTexture(nil, "ARTWORK", nil, 1)
    art.edgeLeft:SetTexture(ART_LEFT_FILE)
    art.edgeLeft:SetSize(EDGE_LEFT_R - EDGE_LEFT_L, EDGE_BOTTOM - EDGE_TOP)
    art.edgeLeft:SetTexCoord(EDGE_LEFT_L / ART_LEFT_W, EDGE_LEFT_R / ART_LEFT_W, EDGE_TOP / ART_H, EDGE_BOTTOM / ART_H)
    art.edgeLeft:SetPoint("TOPLEFT", art.edgeRight, "TOPRIGHT", DIVIDER_GAP, 0)
    art.paneBack = art:CreateTexture(nil, "BACKGROUND")
    art.paneBack:SetColorTexture(0, 0, 0, 1)
    art.paneBack:SetPoint("TOPLEFT", art.edgeRight, "TOPLEFT", 0, 0)
    art.paneBack:SetPoint("BOTTOMRIGHT", right, "TOPLEFT", PICTURE_RIGHT_COL, -EDGE_BOTTOM)
    -- Over the map's border frame, which holds the client's own title; centred over the map.
    local titleHost = ns.NewFrame("Frame", nil, map.BorderFrame)
    titleHost:SetAllPoints(art)
    title = titleHost:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER", art, "TOPLEFT", ERA_W / 2, TITLE_Y)
    art.titleHost = titleHost
    art:Hide()
    return art
end

-- Era's pieces for the window without the pane, or widened across it.
local artPane
local function LayArt(a, pane)
    if artPane == pane then return end
    artPane = pane
    local rightX = pane and PaneArtX() or ART_X + ART_LEFT_W
    a:SetSize(pane and PaneWindowW() or ERA_W, ERA_H)
    ns.SetPointOnce(a.right, "TOPLEFT", a, "TOPLEFT", rightX, 0)
    local fillW = math.min(rightX - (ART_X + ART_LEFT_W), ART_LEFT_W - FILL_MIN_COL)
    if pane and fillW > 0 then
        a.fill:SetSize(fillW, ART_H)
        a.fill:SetTexCoord((ART_LEFT_W - fillW) / ART_LEFT_W, 1, 0, 1)
        ns.SetPointOnce(a.fill, "TOPRIGHT", a.right, "TOPLEFT", 0, 0)
    end
    a.fill:SetShown(pane and fillW > 0)
    a.edgeRight:SetShown(pane)
    a.edgeLeft:SetShown(pane)
    a.paneBack:SetShown(pane)
end

-- Era's title: the continent's name inside one, else World Map.
local function MapTitle()
    local id = Map():GetMapID()
    local info = id and C_Map.GetMapInfo(id)
    while info and info.mapType and info.mapType > Enum.UIMapType.Continent and info.parentMapID do
        info = C_Map.GetMapInfo(info.parentMapID)
    end
    if info and info.mapType == Enum.UIMapType.Continent then return info.name end
    return WORLD_MAP or "World Map"
end

-- The client's coordinates line: the map's child holding PlayerCoords, found once.
local coords
local function NoteCoords(child)
    if child.PlayerCoords then coords = child end
end

local function Coords(map)
    if not coords then ns.EachChild(map, NoteCoords) end
    return coords
end

local function HoldHidden(piece)
    if not piece then return end
    if piece:IsShown() then
        hidden[piece] = true
        piece:Hide()
    end
end

local function DressEra()
    local map = Map()
    local border = map.BorderFrame
    local a = Art()
    LayArt(a, PaneShown())
    ns.SetShownIf(a, true)
    ns.SetShownIf(a.titleHost, true)
    ns.SetAlphaIf(border.NineSlice, 0)
    ns.SetAlphaIf(border.TitleContainer, 0)
    ns.SetAlphaIf(border.InsetBorderTop, 0)
    if border.fcui and border.fcui.titleStrip then ns.SetShownIf(border.fcui.titleStrip, false) end
    ns.SetAlphaIf(_G["WorldMapFrameBg"], 0)
    for _, key in ipairs(EXTRAS) do HoldHidden(map[key]) end
    -- The quest pane toggle sits on the footer's border: over its line.
    if map.SidePanelToggle then
        ns.SetLevelIf(map.SidePanelToggle, map.ScrollContainer:GetFrameLevel() + FOOT_LINE_OVER_MAP + 1)
    end
    HoldHidden(Coords(map))
    local id = map:GetMapID()
    if id ~= titleFor then
        titleFor = id
        title:SetText(MapTitle())
    end
    local close, sizer = border.CloseButton, border.MaximizeMinimizeFrame
    if close then ns.SetPointIf(close, "TOPRIGHT", a.right, "TOPRIGHT", CLOSE_X, CLOSE_Y) end
    if sizer and close then ns.SetPointIf(sizer, "RIGHT", close, "LEFT", MAXIMIZE_GAP, 0) end
    eraDressed = true
end

local function DressForever()
    if not eraDressed then return end
    eraDressed = false
    local map = Map()
    local border = map.BorderFrame
    if art then
        art:Hide()
        art.titleHost:Hide()
    end
    border.NineSlice:SetAlpha(1)
    if border.TitleContainer then border.TitleContainer:SetAlpha(1) end
    if border.InsetBorderTop then border.InsetBorderTop:SetAlpha(1) end
    if border.fcui and border.fcui.titleStrip then border.fcui.titleStrip:Show() end
    if _G["WorldMapFrameBg"] then _G["WorldMapFrameBg"]:SetAlpha(1) end
    for piece in pairs(hidden) do piece:Show() end
    wipe(hidden)
    local close = border.CloseButton
    if close then P.PlaceInSocket(close, border) end
    if border.MaximizeMinimizeFrame and close then P.MaxMinBeside(border.MaximizeMinimizeFrame, close, 8) end
end

local touched   -- the map picture's anchors are ours from the first Era lay on

-- Hide map quest button: faded and deaf, as the client shows it again on every open.
local QUEST_BUTTON_PARTS = { "OpenButton", "CloseButton" }
local questButtonHidden = false
local function QuestButton(map)
    local toggle = map.SidePanelToggle
    local hide = ns.db.hideMapQuestButton == true
    if not toggle or hide == questButtonHidden then return end
    questButtonHidden = hide
    toggle:SetAlpha(hide and 0 or 1)
    for _, key in ipairs(QUEST_BUTTON_PARTS) do
        if toggle[key] then toggle[key]:EnableMouse(not hide) end
    end
end

local function Pass()
    local map = Map()
    if not map then return end
    QuestButton(map)
    if WantEra() then
        touched = true
        local t = Target(true)
        Lay(t)
        if Laid(t) then DressEra() else DressForever() end
    elseif touched then
        DressForever()
        Lay(Target(false))
    end
    Refit()
end

-- How far the Era layout lifts the quest details' text (its Back button follows, Quest/QuestMapPane.lua).
function ns.MapDetailsLift() return eraDressed and DETAILS_LIFT or 0 end

-- The edit mode box: Era's size while its layout is on, the client's otherwise.
function ns.ClassicMapSize()
    if P.active and ns.db.worldMap ~= false and ns.db.mapNavBar ~= true then return ERA_W, ERA_H, PaneWindowW() - ERA_W end
    return FOREVER_W, FOREVER_H, FOREVER_PANE_W
end

-- The map shut: its box laid now, so its own next open fits the picture to it with no refit.
local function LayShut()
    local map = Map()
    if not ns.ready or not map or map:IsShown() then return end
    Pass()
end

local function Attach()
    local map = Map()
    if not map or not map.ScrollContainer or not map.TitleCanvasSpacerFrame then return false end
    ns.Sched.Attach(map, { name = "map.classic", every = 0, fn = Pass })
    ns.Sched.OnVisible(map, "map.classicShut", function(shown)
        if not shown then ns.Sched.NextFrame("map.classicShut", LayShut) end
    end)
    ns.Sched.NextFrame("map.classicShut", LayShut)
    return true
end

-- At login, and after a fight that held off a lay.
ns.EventFrame({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }, function() LayShut() end)

if not Attach() then
    local wait
    wait = ns.EventFrame("ADDON_LOADED", function()
        if Attach() then wait:UnregisterAllEvents() end
    end)
end

ns.OnToggle(function(key)
    if key == "mapNavBar" or key == "worldMap" or key == "hideMapQuestButton" then
        if Map() and Map():IsShown() then Pass() else LayShut() end
    end
end)
