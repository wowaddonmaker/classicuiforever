local _, ns = ...

-- The 1.x minimap cluster: client frames re-anchored inside it; the Layout hook
-- stops size drift. Queue eye in MinimapEye.lua; ns.MM is the minimap's private table.

local MM = {}
ns.MM = MM
MM.active = false

local CLUSTER = 192
local MAP = 140
local FULL = { 0, 1, 0, 1 }

local hooked = false

-- Art specs. Re-anchors in Layout stay unconditional, like SetPointOnce itself.
local RING_TOP = { own = "borderTop", layer = "ARTWORK", coords = { 0.25, 1, 0, 0.125 }, w = CLUSTER, h = 32, point = "TOPRIGHT" }
-- The zone bar runs 20 to 188 of that 192 cut: its middle stands 8 right of the cluster's, where the zone name goes.
local ZONE_X = 8
local RING = { own = "ring", layer = "ARTWORK", coords = { 0.25, 1, 0.125, 0.875 }, fill = true }
local NORTH = { own = "north", layer = "OVERLAY", w = 16, h = 16, point = "CENTER", y = 67 }
local COMPASS = { coords = FULL, w = 256, h = 256, point = "CENTER", x = -2, layer = "OVERLAY" }
local ZOOM_STATES = { coords = FULL, fill = true }
local ZOOM = {
    { field = "ZoomIn", key = "minimapZoomIn", up = "zoomInUp", down = "zoomInDown", disabled = "zoomInDisabled" },
    { field = "ZoomOut", key = "minimapZoomOut", up = "zoomOutUp", down = "zoomOutDown", disabled = "zoomOutDisabled" },
}
local GLASS_BG = { coords = FULL, w = 25, h = 25, point = "TOPLEFT", x = 2, y = -4, alpha = 0.6 }
local GLASS_RING = { own = "border", layer = "BORDER", w = 52, h = 52, point = "TOPLEFT" }
local NO_TRACKING = { coords = FULL, w = 20, h = 20 }
local HL_RING = { coords = FULL, fill = true, add = true, states = { "Highlight" } }
local MAIL_RING = { own = "border", layer = "OVERLAY", w = 52, h = 52, point = "TOPLEFT" }
local CLOCK_PLATE = { own = "bg", layer = "BORDER", alpha = 1, coords = { 0.015625, 0.8125, 0.015625, 0.390625 },
    fill = true, keep = true }
local CALENDAR = { states = { "Normal", "Pushed", "Highlight" }, fill = true, add = true,
    coords = { Normal = { 0, 0.390625, 0, 0.78125 }, Pushed = { 0.5, 0.890625, 0, 0.78125 }, Highlight = FULL },
    layer = { Normal = "BACKGROUND", Pushed = "BACKGROUND" } }

-------------------------------------------------------- pieces

-- Pieces the player can move and size in ClassicUI Forever Windows (UI/WindowHandles.lua) or hide in the options:
-- each in a named home the edit mode places by name; ns.LayPiece lays one at its default spot again.
-- show: the piece's Shown / On hover / Hidden keys (show<id>, hover<id>, hide<id>); ring: its angle key on the ring.
local PIECES = {
    minimapZone = { home = "ForeverClassicUIMinimapZoneHome", show = "MinimapZone" },
    minimapTracking = { home = "ForeverClassicUIMinimapTrackingHome", show = "MinimapTracking" },
    minimapMail = { home = "ForeverClassicUIMinimapMailHome", show = "MinimapMail" },
    minimapZoomIn = { home = "ForeverClassicUIMinimapZoomInHome", show = "MinimapZoomIn", ring = "zoomInAngle", angle = 322 },
    minimapZoomOut = { home = "ForeverClassicUIMinimapZoomOutHome", show = "MinimapZoomOut", ring = "zoomOutAngle", angle = 302 },
    minimapClock = { home = "ForeverClassicUIMinimapClockHome", show = "MinimapClock" },
    minimapDiel = { home = "ForeverClassicUIMinimapDielHome", show = "MinimapDiel" },
    minimapCoords = { home = "ForeverClassicUIMinimapCoordsHome", show = "MinimapCoords" },
}
MM.PIECE_KEYS = PIECES
local SHOW_IDS = { "MinimapZone", "MinimapTracking", "MinimapMail", "MinimapZoomIn", "MinimapZoomOut", "MinimapClock",
    "MinimapDiel", "MinimapCalendar", "MinimapCoords", "MinimapDifficulty" }
local ZOOM_R = 79
local DIEL_RING = "UI-HUD-Minimap-Frame-Cycle"
-- Other addons' minimap buttons wear the old gold tracking ring (MiniMap-TrackingBorder): tinted as ours.
local TRACKING_RING = 136430
local RING_SHARE = { dark = 1.28 }
local function TintRing(region)
    if not (region.GetTexture and region.IsObjectType and region:IsObjectType("Texture")) then return end
    local file = ns.Safe(region:GetTexture())
    if file == TRACKING_RING or (type(file) == "string" and file:lower():find("minimap%-trackingborder")) then
        if ns.Once(region, "themeRing") then ns.BronzeTint(region, RING_SHARE) end
        -- Hide button borders is our minimap's: the game's map keeps its rings.
        if MM.active then ns.MinimapButtonBorder(region) end
    end
end
function ns.ThemeAddonRing(button)
    local name = button and button.GetName and button:GetName()
    if not button or (name and name:find("^ForeverClassicUI")) then return end
    ns.EachRegion(button, TintRing)
end
local function RingOfChild(child)
    if child.IsObjectType and child:IsObjectType("Button") then ns.ThemeAddonRing(child) end
end

-- Our minimap off: other addons' rings on the game's map take the theme too, a LibDBIcon button made later as it comes.
local ringListener
local function ThemeRingsOnGameMap()
    local ldbi = LibStub and LibStub.GetLibrary and LibStub:GetLibrary("LibDBIcon-1.0", true)
    if ldbi and ldbi.GetButtonList then
        for _, name in ipairs(ldbi:GetButtonList()) do
            ns.ThemeAddonRing(ldbi.GetMinimapButton and ldbi:GetMinimapButton(name))
        end
        if not ringListener and ldbi.RegisterCallback then
            ringListener = {}
            ldbi.RegisterCallback(ringListener, "LibDBIcon_IconCreated", function(_, button) ns.ThemeAddonRing(button) end)
        end
    end
    if Minimap then ns.EachChild(Minimap, RingOfChild) end
end
-- Hide button borders: every ring round a minimap button (ours, the client's, other addons'), kept here to apply at once.
local buttonBorders = setmetatable({}, { __mode = "k" })
function ns.MinimapButtonBorder(tex)
    if not tex then return end
    buttonBorders[tex] = true
    ns.SetAlphaIf(tex, ns.db.hideButtonBorders and 0 or 1)
end
local function ButtonBordersApply()
    for tex in pairs(buttonBorders) do ns.SetAlphaIf(tex, ns.db.hideButtonBorders and 0 or 1) end
end

-- The game's coordinates line and the map container it hangs in (Blizzard_Minimap Minimap.xml).
local function PlayerCoords()
    local box = MinimapCluster and MinimapCluster.MinimapContainer
    return box and box.PlayerCoords, box
end

-- The comma under the map's middle: the game writes the line as one string, its numbers of any width, so the line
-- slides by the difference, measured on a scratch string in its font, while it shows.
local commaScratch, commaOn
local measured = { shift = 0 }
local function CommaShift(coords)
    local text = coords.CoordText
    local line = commaOn and text and text:GetText()
    if not line or ns.IsSecret(line) then return end
    local file, size, flags = text:GetFont()
    -- Measured only for a new line or font; the anchors are held each beat all the same.
    if line ~= measured.line or file ~= measured.file or size ~= measured.size then
        local cut = line:find(",", 1, true)
        local shift = 0
        if cut then
            commaScratch = commaScratch or UIParent:CreateFontString(nil, "OVERLAY")
            commaScratch:SetFont(file, size, flags)
            commaScratch:SetText(line:sub(1, cut - 1))
            local before = commaScratch:GetStringWidth()
            commaScratch:SetText(",")
            shift = text:GetStringWidth() / 2 - before - commaScratch:GetStringWidth() / 2
        end
        measured.line, measured.file, measured.size, measured.shift = line, file, size, shift
    end
    local shift = measured.shift
    ns.SetTwoPointsIf(text, "TOPLEFT", coords, "TOPLEFT", shift, 0, "BOTTOMRIGHT", coords, "BOTTOMRIGHT", shift, 0)
end

local function DrainDielRing(region)
    if region.GetAtlas and ns.Safe(region:GetAtlas()) == DIEL_RING then
        ns.DrainBronze(region)
        ns.MinimapButtonBorder(region)
    end
end
local homes = {}

---------------------------------------------------------------- shown, on hover, hidden

-- "hide", "hover" or nil (shown).
function MM.ShowState(id)
    local db = ns.db
    if not id or not db then return nil end
    if db["hide" .. id] then return "hide" end
    if db["hover" .. id] then return "hover" end
end

-- Frames shown only while the mouse is over the minimap or over them.
local hovering = {}
local hoverJob

local function HoverTick(job)
    if not next(hovering) then job:Sleep() return end
    local over = MinimapCluster and MinimapCluster:IsMouseOver()
    if not over then
        for frame in pairs(hovering) do
            if frame:IsVisible() and frame:IsMouseOver() then over = true break end
        end
    end
    -- Our ring button inside the addon bag stays lit there.
    for frame in pairs(hovering) do
        if not (ns.MinimapCollected and ns.MinimapCollected(frame)) then ns.SetAlphaIf(frame, over and 1 or 0) end
    end
end

-- A client frame hidden under a hidden frame of ours: by alpha alone it still took the mouse and showed its tooltip, and
-- the client's own shows cannot reach it here. Its parent, strata and level back for any other choice.
local stash
local stashedFrom = setmetatable({}, { __mode = "k" })
local function Stash(frame, hide)
    local was = stashedFrom[frame]
    if hide and not was then
        if not stash then
            stash = CreateFrame("Frame")
            stash:Hide()
        end
        stashedFrom[frame] = { frame:GetParent(), frame:GetFrameStrata(), frame:GetFrameLevel() }
        frame:SetParent(stash)
    elseif not hide and was then
        stashedFrom[frame] = nil
        frame:SetParent(was[1])
        frame:SetFrameStrata(was[2])
        frame:SetFrameLevel(was[3])
    end
end

-- client: a frame the client shows and hides itself (never shown from here).
function ns.MinimapShow(frame, id, client)
    if not frame then return end
    local state = MM.ShowState(id)
    if client then
        Stash(frame, state == "hide")
    else
        ns.SetShownIf(frame, state ~= "hide")
    end
    hovering[frame] = state == "hover" or nil
    if state == nil then ns.SetAlphaIf(frame, 1) end
    if not next(hovering) or not MinimapCluster then return end
    hoverJob = hoverJob or ns.Sched.Job({ name = "minimap.hover", every = 0.1, awake = false, fn = HoverTick })
    hoverJob:Wake()
    HoverTick(hoverJob)
end

-- Old saves: one hide key for both zoom buttons, the calendar on or off.
function ns.MigrateMinimapShow(db)
    if db.hideMinimapZoom ~= nil then
        if db.hideMinimapZoom then db.hideMinimapZoomIn, db.hideMinimapZoomOut = true, true end
        db.hideMinimapZoom = nil
    end
    if db.minimapCalendar ~= nil then
        if db.minimapCalendar == false then db.hideMinimapCalendar = true end
        db.minimapCalendar = nil
    end
    for _, list in ipairs({ db.windowPos, db.windowScale }) do
        if type(list) == "table" then list.minimapZoom = nil end
    end
    for _, id in ipairs(SHOW_IDS) do
        if db["hide" .. id] or db["hover" .. id] then db["show" .. id] = false end
        if db["hide" .. id] then db["hover" .. id] = false end
    end
end

---------------------------------------------------------------- homes

local function Home(key, parent, level, w, h)
    local home = homes[key]
    if not home then
        home = CreateFrame("Frame", PIECES[key].home, parent)
        homes[key] = home
        if ns.PlaceSavedWindows then ns.PlaceSavedWindows() end
    end
    home:SetSize(w, h)
    ns.SetLevelIf(home, level)
    return home
end

-- The home's size and level; its middle at the default spot unless placed in edit mode (offsets in its own scale).
local function LayHome(key, parent, level, w, h, rel, relPoint, x, y)
    local home = Home(key, parent, level, w, h)
    if not (ns.WindowPlaced and ns.WindowPlaced(key)) then
        local k = home:GetScale()
        ns.SetPointOnce(home, "CENTER", rel, relPoint, x / k, y / k)
    end
    ns.MinimapShow(home, PIECES[key].show)
    return home
end

-- A ring piece: its middle at its angle, dragged round the ring in edit mode.
local function LayRingHome(key, parent, level, w, h)
    local piece = PIECES[key]
    local home = Home(key, parent, level, w, h)
    ns.RingPoint(home, tonumber(ns.db[piece.ring]) or piece.angle, ZOOM_R, home:GetEffectiveScale() / Minimap:GetEffectiveScale())
    ns.MinimapShow(home, piece.show)
    return home
end

-------------------------------------------------------- classic tracking

-- 1.x MiniMapTracking: the active tracking spell on the rim; right-click cancels it.
-- Its buff leaves the buff bar meanwhile (TrackingBuff.lua).
local C_Minimap = _G.C_Minimap
local trackFrame
-- 52 like the mail and eye rings; ring centre is at (20, 19) on the 64px sheet.
local TRACK_RING = 52
local TRACK_CX, TRACK_CY = TRACK_RING * 20 / 64, TRACK_RING * 19 / 64
local TRACK_BORDER = { layer = "ARTWORK", w = TRACK_RING, h = TRACK_RING, point = "TOPLEFT" }
local TRACK_EVENTS = { "MINIMAP_UPDATE_TRACKING", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD" }

local function TrackingOn() return MM.active and ns.db and ns.db.classicTracking ~= false end

local function ActiveTrackingSpell()
    if not (C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return nil end
    local count = C_Minimap.GetNumTrackingTypes()
    if ns.IsSecret(count) or type(count) ~= "number" then return nil end
    for i = 1, count do
        local info = C_Minimap.GetTrackingInfo(i)
        if info and not ns.AnySecret(info.active, info.type) and info.active and info.type == "spell" then
            return i, info
        end
    end
    return nil
end

local function UpdateTracking()
    local frame = trackFrame
    local index, info
    if frame and TrackingOn() then index, info = ActiveTrackingSpell() end
    if MM.TrackingBuff then MM.TrackingBuff(info) end
    if not frame then return end
    frame.index = index
    frame.spellID = info and not ns.IsSecret(info.spellID) and info.spellID or nil
    frame.name = info and info.name
    if info then
        frame.icon:SetTexture(info.texture)
        ns.RoundIcon(frame.icon)
    end
    frame:SetShown(index ~= nil)
end

local function QueueTracking() ns.Sched.Soon("minimap.tracking", UpdateTracking) end

local function TrackingMouseUp(self, button)
    if button == "RightButton" and self.index and C_Minimap.SetTracking then
        C_Minimap.SetTracking(self.index, false)
    end
end

local function TrackingEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    if self.spellID and GameTooltip.SetSpellByID then
        GameTooltip:SetSpellByID(self.spellID)
    else
        GameTooltip:SetText(self.name or "", 1, 1, 1)
    end
    GameTooltip:Show()
end

-- Era's rim spot, in our backdrop's coordinates, until it is dragged round the ring (shift-drag, or edit mode): then at
-- its angle, as far from the map's middle as Era's spot is.
local TRACK_KEY, TRACK_ANGLE, TRACK_R = "minimapTrackingIcon", "trackingIconAngle", 83.6
local function PlaceTracking()
    local frame = trackFrame
    if not frame then return end
    local degrees = ns.db and ns.db[TRACK_ANGLE]
    if degrees then
        ns.RingPoint(frame, degrees, TRACK_R, frame:GetEffectiveScale() / Minimap:GetEffectiveScale())
    else
        ns.SetPointOnce(frame, "TOPLEFT", frame:GetParent(), "TOPLEFT", 11, -26)
    end
end
function ns.LayTrackingIcon(key)
    if key == TRACK_KEY then PlaceTracking() end
end

local function TrackingFrame(backdrop, level)
    local frame = trackFrame
    if not frame then
        frame = CreateFrame("Frame", "ForeverClassicUIMinimapTrackingIcon", backdrop)
        trackFrame = frame
        frame:Hide()
        frame:SetSize(32, 32)
        frame:EnableMouse(true)
        -- Shift-drag round the ring, as our ring buttons move.
        frame:RegisterForDrag("LeftButton")
        local drag = ns.Sched.OnFrame(CreateFrame("Frame", nil, frame), { name = "minimap.trackingDrag", every = 0,
            awake = false, fn = function()
                ns.db[TRACK_ANGLE] = ns.MinimapCursorAngle()
                PlaceTracking()
            end })
        frame:SetScript("OnDragStart", function() if IsShiftKeyDown() then drag:Wake() end end)
        frame:SetScript("OnDragStop", function() drag:Sleep() end)
        if ns.PlaceSavedWindows then ns.PlaceSavedWindows() end
        local border = ns.DressNew(frame, "trackingBorder", TRACK_BORDER)
        ns.MinimapButtonBorder(border)
        -- Round, slightly wider than the hole so its edge hides under the ring.
        local icon = frame:CreateTexture(nil, "BORDER")
        icon:SetSize(22, 22)
        icon:SetPoint("CENTER", border, "TOPLEFT", TRACK_CX, -TRACK_CY)
        frame.icon = icon
        ns.RoundIcon(icon)
        frame:SetScript("OnMouseUp", TrackingMouseUp)
        frame:SetScript("OnEnter", TrackingEnter)
        frame:SetScript("OnLeave", GameTooltip_Hide)
        frame:SetScript("OnEvent", QueueTracking)
        ns.RegisterEvents(frame, TRACK_EVENTS)
        UpdateTracking()
    end
    frame:SetFrameLevel(level)
    PlaceTracking()
end

----------------------------------------------------- the tracking glass

-- The glass button's Normal and Pushed textures, re-read each Layout.
local glass = {}
local glassWatched = false

-- Swap the client's atlas art for the 1.x glass, which the client puts back.
local function OldGlass()
    for i = 1, 2 do
        local tex = glass[i]
        if tex and tex.GetAtlas and tex:GetAtlas() then ns.Dress(tex, "trackingNone", NO_TRACKING) end
    end
end

local function GlassTick()
    local tracking = MinimapCluster.Tracking
    if MM.active and tracking and tracking:IsVisible() then OldGlass() end
end

-- After what the client's button answers (tracking, spells, its cvar, presses, scale): this frame's pass, and the next.
local GLASS_EVENTS = { "MINIMAP_UPDATE_TRACKING", "SPELLS_CHANGED", "CVAR_UPDATE", "GLOBAL_MOUSE_DOWN", "GLOBAL_MOUSE_UP",
    "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "PLAYER_ENTERING_WORLD" }
local function GlassSoon()
    if not MM.active then return end
    ns.Sched.Soon("minimap.glass", GlassTick)
    ns.Sched.NextFrame("minimap.glass", GlassTick)
end

-- Its show is heard inside the client's pass: the frame after.
local function GlassShown(shown)
    if shown and MM.active then ns.Sched.NextFrame("minimap.glass", GlassTick) end
end

-- Made at the first Layout with a glass button; Layout runs only while on.
local function WatchGlass(tracking)
    if glassWatched then return end
    glassWatched = true
    ns.EventFrame(GLASS_EVENTS, GlassSoon)
    ns.Sched.OnVisible(tracking, "minimap.glass", GlassShown)
end

-- The button's own art at the 1.x icon size.
local function PlaceGlass(tex, tracking, offset)
    if not tex then return end
    tex:SetSize(20, 20)
    ns.SetPointOnce(tex, "TOPLEFT", tracking, "TOPLEFT", offset, -offset)
end

-- Sole writer of MM.active.
local function SetActive(on)
    MM.active = on
    UpdateTracking()
end

------------------------------------------------------------------- layout

local ringBorder, ringHeader
local function BuildRing()
    local cluster = MinimapCluster
    local backdrop = MinimapBackdrop
    if not cluster or not backdrop then return end
    ringHeader = ns.DressNew(cluster, "minimapBorder", RING_TOP)
    ringBorder = ns.DressNew(backdrop, "minimapBorder", RING)
    cluster.fcuiNorth = ns.DressNew(backdrop, "compassNorth", NORTH, Minimap)
end

-- Hide minimap border and header: the ring and the zone bar over the map.
local function RingShown()
    if ringBorder then ns.SetAlphaIf(ringBorder, ns.db.hideMinimapBorder and 0 or 1) end
    if ringHeader then ns.SetAlphaIf(ringHeader, ns.db.hideMinimapHeader and 0 or 1) end
end

local function Layout()
    local cluster = MinimapCluster
    local backdrop = MinimapBackdrop
    local map = Minimap
    if not cluster or not backdrop or not map then ns.MissingPiece("MinimapCluster") return end
    -- Edit mode's size scales only the map container, pulling the map off its ring:
    -- scale the whole cluster instead so every spot below stays in 1.x pixels.
    local size = 1
    if cluster.GetSettingValue and Enum and Enum.EditModeMinimapSetting and Enum.EditModeMinimapSetting.Size then
        local ok, value = pcall(cluster.GetSettingValue, cluster, Enum.EditModeMinimapSetting.Size)
        if ok and type(value) == "number" and value > 0 then size = value / 100 end
    end
    if cluster.MinimapContainer then ns.SetScaleIf(cluster.MinimapContainer, 1, 0) end
    ns.SetScaleIf(cluster, size, 0.001)
    -- The client scales the header again as the map grows.
    if cluster.BorderTop then cluster.BorderTop:SetScale(1) end
    if cluster.ZoneTextButton then cluster.ZoneTextButton:SetScale(1) end
    cluster:SetSize(CLUSTER, CLUSTER)
    if cluster.BorderTop then ns.Fade(cluster.BorderTop) end
    if cluster.MinimapContainer then
        cluster.MinimapContainer:SetSize(MAP, MAP)
        ns.SetPointOnce(cluster.MinimapContainer, "CENTER", cluster, "TOP", 9, -92)
    end
    map:SetSize(MAP, MAP)
    map:ClearAllPoints()
    if cluster.MinimapContainer then
        map:SetPoint("CENTER", cluster.MinimapContainer, "CENTER", 0, 0)
    else
        map:SetPoint("CENTER", cluster, "TOP", 9, -92)
    end
    if map.SetMaskTexture then map:SetMaskTexture((ns.TexPath("portraitMask"))) end
    backdrop:SetSize(CLUSTER, CLUSTER)
    ns.SetPointOnce(backdrop, "CENTER", cluster, "CENTER", 0, -20)
    if backdrop.StaticOverlayTexture then ns.Fade(backdrop.StaticOverlayTexture) end
    ns.Dress(MinimapCompassTexture, "compassRing", COMPASS, map)
    if MinimapCompassTextureUnderlay then ns.Fade(MinimapCompassTextureUnderlay) end
    local rotate = ns.GetCVarBool("rotateMinimap")
    if MinimapCompassTexture then MinimapCompassTexture:SetShown(rotate and true or false) end
    if cluster.fcuiNorth then cluster.fcuiNorth:SetShown(not rotate) end

    -- Buttons over the map's edge must stand above it to take clicks.
    local above = map:GetFrameLevel() + 5

    -- Zone name centred on the zone bar, whatever the calendar's spot.
    local zone = LayHome("minimapZone", cluster, cluster:GetFrameLevel() + 2, MAP, 12, cluster, "TOP", ZONE_X, -12)
    if cluster.ZoneTextButton then
        cluster.ZoneTextButton:SetParent(zone)
        cluster.ZoneTextButton:SetSize(MAP, 12)
        ns.SetPointOnce(cluster.ZoneTextButton, "CENTER", zone, "CENTER", 0, 0)
    end
    if MinimapZoneText then
        if MinimapZoneText:GetParent() ~= cluster.ZoneTextButton then MinimapZoneText:SetParent(zone) end
        MinimapZoneText:SetSize(MAP, 12)
        MinimapZoneText:SetJustifyH("CENTER")
        ns.SetPointOnce(MinimapZoneText, "CENTER", zone, "CENTER", 0, 0)
    end

    -- Zoom in and out, each on the ring at its own angle.
    for i = 1, #ZOOM do
        local zoom = ZOOM[i]
        local button = map[zoom.field]
        if button then
            local zoomHome = LayRingHome(zoom.key, backdrop, above, 32, 32)
            button:SetParent(zoomHome)
            button:SetFrameLevel(above + 1)
            button:SetSize(32, 32)
            ns.DressStates(button, zoom.up, zoom.down, zoom.disabled, "zoomHighlight", ZOOM_STATES)
            -- Ours is already grey; the client's desaturate turned bronze silver.
            local disabled = button:GetDisabledTexture()
            if disabled and disabled.SetDesaturated then disabled:SetDesaturated(false) end
            button:GetHighlightTexture():SetBlendMode("ADD")
            button:SetHitRectInsets(4, 4, 2, 6)
            ns.SetPointOnce(button, "CENTER", zoomHome, "CENTER", 0, 0)
            button:Show()
        end
    end

    -- Tracking upper left: the spell at Era's spot, the glass (client menu) below, clear of the eye.
    TrackingFrame(backdrop, above)
    local tracking = cluster.Tracking
    if tracking then
        -- With the spell icon off the glass keeps its old spot.
        local glassHome = LayHome("minimapTracking", backdrop, above, 32, 32, backdrop, "TOPLEFT", 9 + 16,
            (TrackingOn() and -64 or -45) - 16)
        tracking:SetParent(glassHome)
        tracking:SetFrameLevel(above + 1)
        tracking:SetSize(32, 32)
        ns.SetPointOnce(tracking, "TOPLEFT", glassHome, "TOPLEFT", 0, 0)
        ns.Dress(tracking.Background, "minimapBackground", GLASS_BG, tracking)
        ns.MinimapButtonBorder(ns.DressNew(tracking, "trackingBorder", GLASS_RING))
        local button = tracking.Button
        if button then
            button:SetSize(32, 32)
            button:SetFrameLevel(above + 1)
            ns.SetPointOnce(button, "TOPLEFT", tracking, "TOPLEFT", 0, 0)
            glass[1], glass[2] = button:GetNormalTexture(), button:GetPushedTexture()
            PlaceGlass(glass[1], tracking, 6)
            PlaceGlass(glass[2], tracking, 8)
            OldGlass()
            WatchGlass(tracking)
            ns.DressStates(button, nil, nil, nil, "zoomHighlight", HL_RING)
        end
    end

    -- Mail on the upper right of the map, a spot lower while the calendar stands under the day/night.
    local indicator = cluster.IndicatorFrame
    local mailY = MM.CalendarUnderDiel() and -70 or -37
    if indicator then
        local mailHome = LayHome("minimapMail", cluster, above, 33, 33, map, "TOPRIGHT", 24 - 16.5, mailY - 16.5)
        indicator:SetParent(mailHome)
        indicator:SetFrameLevel(above + 1)
        indicator:SetSize(33, 33)
        ns.SetPointOnce(indicator, "TOPLEFT", mailHome, "TOPLEFT", 0, 0)
        if indicator.MailFrame then
            indicator.MailFrame:SetSize(33, 33)
            ns.SetPointOnce(indicator.MailFrame, "TOPLEFT", mailHome, "TOPLEFT", 0, 0)
            ns.MinimapButtonBorder(ns.DressNew(indicator.MailFrame, "trackingBorder", MAIL_RING))
            if MiniMapMailIcon then
                MiniMapMailIcon:SetTexture("Interface\\Icons\\INV_Letter_15")
                MiniMapMailIcon:SetSize(18, 18)
                ns.SetPointOnce(MiniMapMailIcon, "TOPLEFT", indicator.MailFrame, "TOPLEFT", 7, -6)
            end
        end
        if indicator.CraftingOrderFrame then
            indicator.CraftingOrderFrame:SetSize(33, 33)
            ns.SetPointOnce(indicator.CraftingOrderFrame, "TOPLEFT", indicator, "TOPLEFT", 0, 0)
        end
    end

    -- Day/night top right, in a home edit mode moves; the calendar at its picked spot (MinimapCalendar.lua).
    local diel = cluster.DielFrame
    if diel then
        local w, h = diel:GetSize()
        local dielHome = LayHome("minimapDiel", cluster, above, w, h, map, "TOPRIGHT", 20 - w / 2, -2 - h / 2)
        if diel:GetParent() ~= dielHome then diel:SetParent(dielHome) end
        ns.SetPointOnce(diel, "CENTER", dielHome, "CENTER", 0, 0)
        -- Its bronze ring follows the theme (silver off, darkened with Dark).
        if ns.Once(diel, "themeRing") then ns.EachRegion(diel, DrainDielRing) end
    end
    -- The game's coordinates under the map, in a home edit mode moves.
    local coords = PlayerCoords()
    if coords then
        local coordsHome = LayHome("minimapCoords", backdrop, above, 90, 10, map, "BOTTOM", 0, -23)
        if coords:GetParent() ~= coordsHome then coords:SetParent(coordsHome) end
        ns.SetPointOnce(coords, "CENTER", coordsHome, "CENTER", 0, 0)
        commaOn = true
        ns.Sched.Attach(coords, { name = "minimap.coordsComma", every = 0.1, fn = function() CommaShift(coords) end })
    end
    RingShown()
    if GameTimeFrame then
        MM.PlaceCalendar(cluster, map, above)
        ns.SkinCalendar()
    end

    -- Clock at the map's bottom: the client's plate faded, our stone plate kept.
    if TimeManagerClockButton then
        local clock = TimeManagerClockButton
        local clockHome = LayHome("minimapClock", map, above, 60, 28, map, "CENTER", 0, -75)
        clock:SetParent(clockHome)
        clock:SetFrameLevel(above + 1)
        clock:SetSize(60, 28)
        ns.SetPointOnce(clock, "CENTER", clockHome, "CENTER", 0, 0)
        ns.FadeTextures(clock, 0, nil, clock.fcui and clock.fcui.bg)
        ns.MinimapButtonBorder(ns.DressNew(clock, "clockBackground", CLOCK_PLATE, TimeManagerClockButton))
        if TimeManagerClockTicker then ns.SetPointOnce(TimeManagerClockTicker, "CENTER", TimeManagerClockButton, "CENTER", 3, 1) end
    end

    -- Queue eye on the lower left (MinimapEye.lua), instance flag on the upper left.
    if QueueStatusButton then
        MM.PlaceEye()
        MM.WatchEye()
    end
    -- 1.x had no difficulty flag: hidden by default (the game shows it per instance).
    if cluster.InstanceDifficulty then
        ns.SetPointOnce(cluster.InstanceDifficulty, "TOPLEFT", cluster, "TOPLEFT", 22, -17)
        ns.MinimapShow(cluster.InstanceDifficulty, "MinimapDifficulty", true)
    end
    -- No landing page in 1.x; faded rather than moved, still reachable from the micro menu.
    if ExpansionLandingPageMinimapButton then
        ExpansionLandingPageMinimapButton:SetAlpha(0)
        ExpansionLandingPageMinimapButton:EnableMouse(false)
    end
    if AddonCompartmentFrame then AddonCompartmentFrame:Hide() end

    -- LibDBIcon places buttons by map width (onto the ring); refresh each pass to follow our smaller map. Not the ones in
    -- the addon button bag: a refresh puts them back on the map, drag and hover fade included.
    local ldbi = LibStub and LibStub.GetLibrary and LibStub:GetLibrary("LibDBIcon-1.0", true)
    if ldbi and ldbi.GetButtonList and ldbi.Refresh then
        for _, name in ipairs(ldbi:GetButtonList()) do
            local button = ldbi.GetMinimapButton and ldbi:GetMinimapButton(name)
            if not (ns.MinimapCollected and ns.MinimapCollected(button)) then pcall(ldbi.Refresh, ldbi, name) end
            if button then ns.ThemeAddonRing(button) end
        end
    end
    ns.EachChild(map, RingOfChild)
    if ns.OnMinimapLaid then ns.OnMinimapLaid(ldbi) end
end

-- Ring maths for pieces dragged round the minimap: the cursor's angle about its middle (degrees, 0 = right, counter-
-- clockwise), and a frame's middle at an angle and radius (map units; k: the frame's scale over the map's).
function ns.MinimapCursorAngle()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
    if angle < 0 then angle = angle + 360 end
    return angle
end

function ns.RingPoint(frame, degrees, radius, k)
    local a, f = math.rad(degrees), 1 / (k or 1)
    ns.SetPointOnce(frame, "CENTER", Minimap, "CENTER", math.cos(a) * radius * f, math.sin(a) * radius * f)
end

-- The 1.x calendar button: the day number on the stone calendar art.
function ns.SkinCalendar()
    local button = GameTimeFrame
    if not button or not MM.active then return end
    ns.DressStates(button, "calendarButton", "calendarButton", nil, "zoomHighlight", CALENDAR)
    ns.FadeTextures(button, 0, nil, button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture())
    local day = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime().monthDay
    local fs = button:GetFontString()
    if not fs then
        button:SetNormalFontObject("GameFontBlack")
        fs = button:CreateFontString(nil, "OVERLAY", "GameFontBlack")
        button:SetFontString(fs)
    end
    fs:SetFontObject("GameFontBlack")
    ns.SetPointOnce(fs, "CENTER", button, "CENTER", -1, -1)
    fs:SetDrawLayer("OVERLAY")
    if day then button:SetText(day) end
    MM.SquareDay()
end

--------------------------------------------------------------------- module

local function LayoutIfActive()
    if MM.active then Layout() end
end
MM.Relayout = LayoutIfActive

local function HideLanding(self)
    if MM.active then self:SetAlpha(0); self:EnableMouse(false) end
end

local function HideCompartment(self)
    if MM.active then self:Hide() end
end

-- The client hides the zoom buttons as the mouse leaves the map.
local function ShowZoom(self)
    if MM.active then
        if self.ZoomIn then self.ZoomIn:Show() end
        if self.ZoomOut then self.ZoomOut:Show() end
    end
end

local function HideOwn(frame)
    if frame and frame.fcui then
        for _, tex in pairs(frame.fcui) do tex:Hide() end
    end
end

-- These hooks run inside the client's edit mode layout passes: add no work to them.
local function Apply()
    SetActive(true)
    MM.taken = true
    if not MinimapCluster then ns.MissingPiece("MinimapCluster") return end
    BuildRing()
    Layout()
    if not hooked then
        hooked = true
        ns.HookMethod(MinimapCluster, "Layout", LayoutIfActive)
        ns.HookMethod(MinimapCluster, "SetRotateMinimap", LayoutIfActive)
        if MinimapCluster.IndicatorFrame then
            ns.HookMethod(MinimapCluster.IndicatorFrame, "Layout", LayoutIfActive)
        end
        if AddonCompartmentFrame then
            ns.HookMethod(AddonCompartmentFrame, "UpdateDisplay", HideCompartment)
        end
        ns.HookGlobal("GameTimeFrame_SetDate", ns.SkinCalendar)
        if ExpansionLandingPageMinimapButton then
            ns.HookMethod(ExpansionLandingPageMinimapButton, "UpdateIcon", HideLanding)
        end
        if Minimap then ns.HookScriptOnce(Minimap, "OnLeave", ShowZoom) end
    end
end

-- Runs on every ApplyAll while off: only what Apply took this session goes back, the game's pieces are not ours to
-- place otherwise. OwnTexture never re-shows, so the ring needs a reload.
local function Restore()
    SetActive(false)
    ThemeRingsOnGameMap()
    if not MM.taken then return end
    MM.taken = false
    HideOwn(MinimapCluster)
    HideOwn(MinimapBackdrop)
    MM.HideCalendar()
    for _, home in pairs(homes) do ns.MinimapShow(home, nil) end
    if MinimapCluster and MinimapCluster.InstanceDifficulty then ns.MinimapShow(MinimapCluster.InstanceDifficulty, nil, true) end
    for tex in pairs(buttonBorders) do ns.SetAlphaIf(tex, 1) end
    -- Day/night and coordinates back in the client's frames at its spots.
    local diel = MinimapCluster and MinimapCluster.DielFrame
    if diel then
        diel:SetParent(MinimapCluster)
        ns.SetPointOnce(diel, "CENTER", MinimapCluster, "CENTER", 63, 72)
    end
    local coords, box = PlayerCoords()
    if coords and Minimap then
        coords:SetParent(box)
        ns.SetPointOnce(coords, "BOTTOM", Minimap, "BOTTOM", 0, -18)
        commaOn = false
        if coords.CoordText then
            coords.CoordText:ClearAllPoints()
            coords.CoordText:SetAllPoints(coords)
        end
    end
    if MinimapCluster and MinimapCluster.BorderTop then ns.Unfade(MinimapCluster.BorderTop) end
    ns.needsReload = true
end

ns.RegisterModule("minimap", { apply = Apply, restore = Restore })

-- A piece's Shown / On hover / Hidden picked: laid again at once.
ns.OnToggle(function(key)
    if key == "hideMinimapBorder" or key == "hideMinimapHeader" then LayoutIfActive() return end
    if key == "hideButtonBorders" then ButtonBordersApply() return end
    for _, id in ipairs(SHOW_IDS) do
        if key == "show" .. id or key == "hover" .. id or key == "hide" .. id then LayoutIfActive() return end
    end
end)
