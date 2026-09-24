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
local RING = { own = "ring", layer = "ARTWORK", coords = { 0.25, 1, 0.125, 0.875 }, fill = true }
local NORTH = { own = "north", layer = "OVERLAY", w = 16, h = 16, point = "CENTER", y = 67 }
local COMPASS = { coords = FULL, w = 256, h = 256, point = "CENTER", x = -2, layer = "OVERLAY" }
local ZOOM_STATES = { coords = FULL, fill = true }
local ZOOM = {
    { field = "ZoomIn", up = "zoomInUp", down = "zoomInDown", disabled = "zoomInDisabled", x = 72, y = -25 },
    { field = "ZoomOut", up = "zoomOutUp", down = "zoomOutDown", disabled = "zoomOutDisabled", x = 50, y = -43 },
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

-- Era's rim spot, in our backdrop's coordinates.
local function TrackingFrame(backdrop, level)
    local frame = trackFrame
    if not frame then
        frame = CreateFrame("Frame", nil, backdrop)
        trackFrame = frame
        frame:Hide()
        frame:SetSize(32, 32)
        frame:EnableMouse(true)
        local border = ns.DressNew(frame, "trackingBorder", TRACK_BORDER)
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
    ns.SetPointOnce(frame, "TOPLEFT", backdrop, "TOPLEFT", 11, -26)
end

----------------------------------------------------- the tracking glass

-- The glass button's Normal and Pushed textures, re-read each Layout.
local glass = {}
local glassJob

-- Swap the client's atlas art for the 1.x glass; polled since the client puts its own back.
local function OldGlass()
    for i = 1, 2 do
        local tex = glass[i]
        if tex and tex.GetAtlas and tex:GetAtlas() then ns.Dress(tex, "trackingNone", NO_TRACKING) end
    end
end

-- Only while the glass shows, as the child watcher this replaced.
local function GlassTick()
    local tracking = MinimapCluster.Tracking
    if tracking and tracking:IsVisible() then OldGlass() end
end

-- Made at the first Layout with a glass button; Layout runs only while on.
local function WatchGlass()
    if glassJob then return end
    glassJob = ns.Sched.Job({ name = "minimap.glass", every = 0.2, fn = GlassTick, awake = MM.active })
end

-- The button's own art at the 1.x icon size.
local function PlaceGlass(tex, tracking, offset)
    if not tex then return end
    tex:SetSize(20, 20)
    ns.SetPointOnce(tex, "TOPLEFT", tracking, "TOPLEFT", offset, -offset)
end

-- Sole writer of MM.active; the glass watch is awake only while on.
local function SetActive(on)
    MM.active = on
    if glassJob then
        if on then glassJob:Wake() else glassJob:Sleep() end
    end
    UpdateTracking()
end

------------------------------------------------------------------- layout

local function BuildRing()
    local cluster = MinimapCluster
    local backdrop = MinimapBackdrop
    if not cluster or not backdrop then return end
    ns.DressNew(cluster, "minimapBorder", RING_TOP)
    ns.DressNew(backdrop, "minimapBorder", RING)
    cluster.fcuiNorth = ns.DressNew(backdrop, "compassNorth", NORTH, Minimap)
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

    -- Zone name across the top of the ring.
    if MinimapZoneText then
        MinimapZoneText:SetSize(MAP, 12)
        MinimapZoneText:SetJustifyH("CENTER")
        ns.SetPointOnce(MinimapZoneText, "CENTER", cluster, "TOP", 0, -12)
    end
    if cluster.ZoneTextButton then
        cluster.ZoneTextButton:SetSize(MAP, 12)
        ns.SetPointOnce(cluster.ZoneTextButton, "CENTER", cluster, "TOP", 0, -12)
    end

    -- Buttons over the map's edge must stand above it to take clicks.
    local above = map:GetFrameLevel() + 5

    -- Zoom on the lower right of the ring.
    for i = 1, #ZOOM do
        local zoom = ZOOM[i]
        local button = map[zoom.field]
        if button then
            button:SetParent(backdrop)
            button:SetFrameLevel(above)
            button:SetSize(32, 32)
            ns.DressStates(button, zoom.up, zoom.down, zoom.disabled, "zoomHighlight", ZOOM_STATES)
            -- Ours is already grey; the client's desaturate turned bronze silver.
            local disabled = button:GetDisabledTexture()
            if disabled and disabled.SetDesaturated then disabled:SetDesaturated(false) end
            button:GetHighlightTexture():SetBlendMode("ADD")
            button:SetHitRectInsets(4, 4, 2, 6)
            ns.SetPointOnce(button, "CENTER", backdrop, "CENTER", zoom.x, zoom.y)
            button:Show()
        end
    end

    -- Tracking upper left: the spell at Era's spot, the glass (client menu) below, clear of the eye.
    TrackingFrame(backdrop, above)
    local tracking = cluster.Tracking
    if tracking then
        tracking:SetParent(backdrop)
        tracking:SetFrameLevel(above)
        tracking:SetSize(32, 32)
        -- With the spell icon off the glass keeps its old spot.
        ns.SetPointOnce(tracking, "TOPLEFT", backdrop, "TOPLEFT", 9, TrackingOn() and -64 or -45)
        ns.Dress(tracking.Background, "minimapBackground", GLASS_BG, tracking)
        ns.DressNew(tracking, "trackingBorder", GLASS_RING)
        local button = tracking.Button
        if button then
            button:SetSize(32, 32)
            button:SetFrameLevel(above + 1)
            ns.SetPointOnce(button, "TOPLEFT", tracking, "TOPLEFT", 0, 0)
            glass[1], glass[2] = button:GetNormalTexture(), button:GetPushedTexture()
            PlaceGlass(glass[1], tracking, 6)
            PlaceGlass(glass[2], tracking, 8)
            OldGlass()
            WatchGlass()
            ns.DressStates(button, nil, nil, nil, "zoomHighlight", HL_RING)
        end
    end

    -- Mail on the upper right of the map.
    local indicator = cluster.IndicatorFrame
    if indicator then
        indicator:SetParent(cluster)
        indicator:SetFrameLevel(above)
        indicator:SetSize(33, 33)
        ns.SetPointOnce(indicator, "TOPRIGHT", map, "TOPRIGHT", 24, -37)
        if indicator.MailFrame then
            indicator.MailFrame:SetSize(33, 33)
            ns.SetPointOnce(indicator.MailFrame, "TOPRIGHT", map, "TOPRIGHT", 24, -37)
            ns.DressNew(indicator.MailFrame, "trackingBorder", MAIL_RING)
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

    -- Day/night: Forever's cycle frame or the calendar button, top right.
    if cluster.DielFrame then
        ns.SetPointOnce(cluster.DielFrame, "TOPRIGHT", map, "TOPRIGHT", 20, -2)
    end
    if GameTimeFrame then
        GameTimeFrame:SetParent(map)
        GameTimeFrame:SetFrameLevel(above)
        GameTimeFrame:SetSize(40, 40)
        ns.SetPointOnce(GameTimeFrame, "TOPRIGHT", map, "TOPRIGHT", 20, -2)
        GameTimeFrame:SetHitRectInsets(6, 0, 5, 10)
        ns.SkinCalendar()
    end

    -- Clock at the map's bottom: the client's plate faded, our stone plate kept.
    if TimeManagerClockButton then
        local clock = TimeManagerClockButton
        clock:SetParent(map)
        clock:SetFrameLevel(above)
        clock:SetSize(60, 28)
        ns.SetPointOnce(clock, "CENTER", map, "CENTER", 0, -75)
        ns.FadeTextures(clock, 0, nil, clock.fcui and clock.fcui.bg)
        ns.DressNew(clock, "clockBackground", CLOCK_PLATE, TimeManagerClockButton)
        if TimeManagerClockTicker then ns.SetPointOnce(TimeManagerClockTicker, "CENTER", TimeManagerClockButton, "CENTER", 3, 1) end
    end

    -- Queue eye on the lower left (MinimapEye.lua), instance flag on the upper left.
    if QueueStatusButton then
        MM.PlaceEye()
        MM.WatchEye()
    end
    if cluster.InstanceDifficulty then
        ns.SetPointOnce(cluster.InstanceDifficulty, "TOPLEFT", cluster, "TOPLEFT", 22, -17)
    end
    -- No landing page in 1.x; faded rather than moved, still reachable from the micro menu.
    if ExpansionLandingPageMinimapButton then
        ExpansionLandingPageMinimapButton:SetAlpha(0)
        ExpansionLandingPageMinimapButton:EnableMouse(false)
    end
    if AddonCompartmentFrame then AddonCompartmentFrame:Hide() end

    -- LibDBIcon places buttons by map width (onto the ring); refresh each pass to follow our smaller map.
    local ldbi = LibStub and LibStub.GetLibrary and LibStub:GetLibrary("LibDBIcon-1.0", true)
    if ldbi and ldbi.GetButtonList and ldbi.Refresh then
        for _, name in ipairs(ldbi:GetButtonList()) do pcall(ldbi.Refresh, ldbi, name) end
    end
    if ns.OnMinimapLaid then ns.OnMinimapLaid(ldbi) end
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
end

--------------------------------------------------------------------- module

local function LayoutIfActive()
    if MM.active then Layout() end
end

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
        if QueueStatusButton then
            ns.HookMethod(QueueStatusButton, "UpdatePosition", LayoutIfActive)
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

-- Runs on every ApplyAll while off; OwnTexture never re-shows, so the ring needs a reload.
local function Restore()
    SetActive(false)
    HideOwn(MinimapCluster)
    HideOwn(MinimapBackdrop)
    if MinimapCluster and MinimapCluster.BorderTop then ns.Unfade(MinimapCluster.BorderTop) end
    ns.needsReload = true
end

ns.RegisterModule("minimap", { apply = Apply, restore = Restore })
