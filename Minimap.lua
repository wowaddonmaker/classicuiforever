local _, ns = ...

-- The 1.x minimap cluster: a 192px stone ring with the zone name across
-- the top, the round map inside, tracking and mail on the left, zoom and
-- day/night on the right. Blizzard's frames are re-anchored inside the
-- cluster and its Layout hook keeps the size from drifting.

local CLUSTER = 192
local MAP = 140

local active = false
local hooked = false

local function BuildRing()
    local cluster = MinimapCluster
    local backdrop = MinimapBackdrop
    if not cluster or not backdrop then return end
    local top = ns.OwnTexture(cluster, "borderTop", "ARTWORK")
    ns.SetTex(top, "minimapBorder")
    top:SetTexCoord(0.25, 1, 0, 0.125)
    top:SetSize(CLUSTER, 32)
    ns.SetPointOnce(top, "TOPRIGHT", cluster, "TOPRIGHT", 0, 0)
    local ring = ns.OwnTexture(backdrop, "ring", "ARTWORK")
    ns.SetTex(ring, "minimapBorder")
    ring:SetTexCoord(0.25, 1, 0.125, 0.875)
    ring:ClearAllPoints()
    ring:SetAllPoints(backdrop)
    local north = ns.OwnTexture(backdrop, "north", "OVERLAY")
    ns.SetTex(north, "compassNorth")
    north:SetSize(16, 16)
    ns.SetPointOnce(north, "CENTER", Minimap, "CENTER", 0, 67)
    cluster.fcuiNorth = north
end

local function Layout()
    local cluster = MinimapCluster
    local backdrop = MinimapBackdrop
    local map = Minimap
    if not cluster or not backdrop or not map then ns.MissingPiece("MinimapCluster") return end
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
    if MinimapCompassTexture then
        ns.SetTex(MinimapCompassTexture, "compassRing")
        MinimapCompassTexture:SetTexCoord(0, 1, 0, 1)
        MinimapCompassTexture:SetSize(256, 256)
        ns.SetPointOnce(MinimapCompassTexture, "CENTER", map, "CENTER", -2, 0)
        MinimapCompassTexture:SetDrawLayer("OVERLAY")
    end
    if MinimapCompassTextureUnderlay then ns.Fade(MinimapCompassTextureUnderlay) end
    local rotate = C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("rotateMinimap")
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

    -- Zoom buttons on the lower right of the ring.
    for _, entry in ipairs({ { map.ZoomIn, "zoomIn", 72, -25 }, { map.ZoomOut, "zoomOut", 50, -43 } }) do
        local button, key, x, y = entry[1], entry[2], entry[3], entry[4]
        if button then
            button:SetParent(backdrop)
            button:SetSize(32, 32)
            ns.SetButtonTex(button, "Normal", key .. "Up")
            ns.SetButtonTex(button, "Pushed", key .. "Down")
            ns.SetButtonTex(button, "Disabled", key .. "Disabled")
            ns.SetButtonTex(button, "Highlight", "zoomHighlight")
            for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
                local tex = button["Get" .. state .. "Texture"](button)
                if tex then
                    tex:SetTexCoord(0, 1, 0, 1)
                    tex:ClearAllPoints()
                    tex:SetAllPoints(button)
                end
            end
            button:GetHighlightTexture():SetBlendMode("ADD")
            button:SetHitRectInsets(4, 4, 2, 6)
            ns.SetPointOnce(button, "CENTER", backdrop, "CENTER", x, y)
            button:Show()
        end
    end

    -- Tracking on the upper left.
    local tracking = cluster.Tracking
    if tracking then
        tracking:SetParent(backdrop)
        tracking:SetSize(32, 32)
        ns.SetPointOnce(tracking, "TOPLEFT", backdrop, "TOPLEFT", 9, -45)
        if tracking.Background then
            ns.SetTex(tracking.Background, "minimapBackground")
            tracking.Background:SetTexCoord(0, 1, 0, 1)
            tracking.Background:SetSize(25, 25)
            ns.SetPointOnce(tracking.Background, "TOPLEFT", tracking, "TOPLEFT", 2, -4)
            tracking.Background:SetAlpha(0.6)
        end
        local border = ns.OwnTexture(tracking, "border", "BORDER")
        ns.SetTex(border, "trackingBorder")
        border:SetSize(54, 54)
        ns.SetPointOnce(border, "TOPLEFT", tracking, "TOPLEFT", 0, 0)
        if tracking.Button then
            tracking.Button:SetSize(32, 32)
            ns.SetPointOnce(tracking.Button, "TOPLEFT", tracking, "TOPLEFT", 0, 0)
            ns.Fade(tracking.Button:GetNormalTexture())
            ns.Fade(tracking.Button:GetPushedTexture())
            ns.SetButtonTex(tracking.Button, "Highlight", "zoomHighlight")
            local hl = tracking.Button:GetHighlightTexture()
            if hl then hl:SetTexCoord(0, 1, 0, 1); hl:SetAllPoints(tracking.Button); hl:SetBlendMode("ADD") end
        end
    end

    -- Mail on the upper right of the map.
    local indicator = cluster.IndicatorFrame
    if indicator then
        indicator:SetParent(cluster)
        indicator:SetSize(33, 33)
        ns.SetPointOnce(indicator, "TOPRIGHT", map, "TOPRIGHT", 24, -37)
        if indicator.MailFrame then
            indicator.MailFrame:SetSize(33, 33)
            ns.SetPointOnce(indicator.MailFrame, "TOPRIGHT", map, "TOPRIGHT", 24, -37)
            local border = ns.OwnTexture(indicator.MailFrame, "border", "OVERLAY")
            ns.SetTex(border, "trackingBorder")
            border:SetSize(52, 52)
            ns.SetPointOnce(border, "TOPLEFT", indicator.MailFrame, "TOPLEFT", 0, 0)
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
        GameTimeFrame:SetSize(40, 40)
        ns.SetPointOnce(GameTimeFrame, "TOPRIGHT", map, "TOPRIGHT", 20, -2)
        GameTimeFrame:SetHitRectInsets(6, 0, 5, 10)
    end

    -- Clock at the bottom of the map.
    if TimeManagerClockButton then
        TimeManagerClockButton:SetParent(map)
        TimeManagerClockButton:SetSize(60, 28)
        ns.SetPointOnce(TimeManagerClockButton, "CENTER", map, "CENTER", 0, -75)
        local bg = ns.OwnTexture(TimeManagerClockButton, "bg", "BORDER")
        ns.SetTex(bg, "clockBackground")
        bg:SetTexCoord(0.015625, 0.8125, 0.015625, 0.390625)
        bg:SetAllPoints(TimeManagerClockButton)
        if TimeManagerClockTicker then ns.SetPointOnce(TimeManagerClockTicker, "CENTER", TimeManagerClockButton, "CENTER", 3, 1) end
    end

    -- Queue eye on the lower left, instance flag on the upper left.
    if QueueStatusButton then
        QueueStatusButton:SetParent(backdrop)
        QueueStatusButton:SetScale(1)
        QueueStatusButton:SetSize(33, 33)
        ns.SetPointOnce(QueueStatusButton, "TOPLEFT", backdrop, "TOPLEFT", 22, -100)
        local border = ns.OwnTexture(QueueStatusButton, "border", "OVERLAY")
        ns.SetTex(border, "trackingBorder")
        border:SetSize(52, 52)
        ns.SetPointOnce(border, "TOPLEFT", QueueStatusButton, "TOPLEFT", 1, -1)
    end
    if cluster.InstanceDifficulty then
        ns.SetPointOnce(cluster.InstanceDifficulty, "TOPLEFT", cluster, "TOPLEFT", 22, -17)
    end
    if ExpansionLandingPageMinimapButton then
        ns.SetPointOnce(ExpansionLandingPageMinimapButton, "TOPLEFT", cluster, "TOPLEFT", 32, -118)
    end
    if AddonCompartmentFrame then AddonCompartmentFrame:Hide() end
end

local function Apply()
    active = true
    if not MinimapCluster then ns.MissingPiece("MinimapCluster") return end
    BuildRing()
    Layout()
    if not hooked then
        hooked = true
        ns.HookMethod(MinimapCluster, "Layout", function() if active then Layout() end end)
        ns.HookMethod(MinimapCluster, "SetRotateMinimap", function() if active then Layout() end end)
        if MinimapCluster.IndicatorFrame then
            ns.HookMethod(MinimapCluster.IndicatorFrame, "Layout", function() if active then Layout() end end)
        end
        if QueueStatusButton then
            ns.HookMethod(QueueStatusButton, "UpdatePosition", function() if active then Layout() end end)
        end
        if AddonCompartmentFrame then
            ns.HookMethod(AddonCompartmentFrame, "UpdateDisplay", function(self) if active then self:Hide() end end)
        end
        if Minimap then
            ns.HookScriptOnce(Minimap, "OnLeave", function(self)
                if active then
                    if self.ZoomIn then self.ZoomIn:Show() end
                    if self.ZoomOut then self.ZoomOut:Show() end
                end
            end)
        end
    end
end

local function Restore()
    active = false
    if MinimapCluster and MinimapCluster.fcui then
        for _, tex in pairs(MinimapCluster.fcui) do tex:Hide() end
    end
    if MinimapBackdrop and MinimapBackdrop.fcui then
        for _, tex in pairs(MinimapBackdrop.fcui) do tex:Hide() end
    end
    if MinimapCluster and MinimapCluster.BorderTop then ns.Unfade(MinimapCluster.BorderTop) end
    ns.needsReload = true
end

ns.RegisterModule("minimap", { apply = Apply, restore = Restore })
