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

-- The group finder's eye. On this client it is a piece of edit mode in
-- its own right, the player's to drag anywhere. Left where the client
-- puts it, it is stood in its old place on the minimap's rim; once the
-- player has moved it, it is theirs and nothing here touches its place.
-- It stays the screen's child, as the client has it (it was made the
-- minimap's, and a piece dragged out of there and saved by the client
-- came back somewhere else). Its edit mode box is lifted a layer: on the
-- rim it lies inside the minimap's own box, which covered it, so it
-- could not be picked up at all.
local eyeWatch
local function EyeMoved(eye)
    if not eye.IsInDefaultPosition then return false end
    local ok, inDefault = pcall(eye.IsInDefaultPosition, eye)
    return ok and inDefault == false
end
-- The client's settings window for the eye has a size slider and no way
-- back to the plain size but to find 100% on it by hand. A button of ours
-- stands in the empty place beside Revert Changes while that window is
-- up for the eye. It goes through the window's own path for a changed
-- setting, so the slider, the unsaved mark and Revert all follow; being
-- a change to the layout made from here, it asks for the interface to be
-- reloaded once edit mode is shut, as a piece snapped onto the bar does.
local sizeReset
local function SizeResetButton()
    local dialog, eye = EditModeSystemSettingsDialog, QueueStatusButton
    local revert = dialog and dialog.Buttons and dialog.Buttons.RevertChangesButton
    if not revert or not eye then return end
    local show = active and dialog:IsShown() and dialog.attachedToSystem == eye and revert:IsVisible()
    if not sizeReset then
        if not show then return end
        sizeReset = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
        sizeReset:SetFrameStrata("DIALOG")
        sizeReset:SetText("Default Size")
        sizeReset:SetScript("OnClick", function()
            local setting = Enum.EditModeGroupFinderSetting and Enum.EditModeGroupFinderSetting.Size
            if not setting or InCombatLockdown() then return end
            if pcall(dialog.OnSettingValueChanged, dialog, setting, 100) then ns.editWrote = true end
        end)
    end
    if show then
        local scale = dialog:GetEffectiveScale() / UIParent:GetEffectiveScale()
        sizeReset:SetScale(scale > 0 and scale or 1)
        sizeReset:SetFrameLevel(dialog:GetFrameLevel() + 20)
        sizeReset:ClearAllPoints()
        sizeReset:SetPoint("LEFT", revert, "RIGHT", 6, 0)
        sizeReset:SetSize(144, 28)
        sizeReset:SetEnabled(math.abs((eye:GetScale() or 1) - 1) > 0.001)
    end
    sizeReset:SetShown(show)
end

local function PlaceEye()
    local eye, backdrop = QueueStatusButton, MinimapBackdrop
    if not eye or not backdrop then return end
    eye:SetSize(33, 33)
    -- The client's eye comes with a gold rim of its own and is drawn at
    -- 43, well over the hole in a minimap button's border, and in a frame
    -- of its own that stands over anything drawn on the button. So the
    -- eye is brought down until its rim lies under our border, and the
    -- border is drawn from a frame over the eye's. Both are the button's
    -- children: the size set in edit mode scales the button, and the
    -- border and the eye go with it.
    -- Stood on the middle of the border's hole, which is not the middle
    -- of the button: the hole lies half a pixel right of it, and the
    -- eye's art a pixel above its own frame's middle. Out by that little
    -- at the plain size, it was out by half as much again at 150%.
    local EYE_SCALE = 0.64
    if eye.Eye and eye.Eye.SetScale then
        eye.Eye:SetScale(EYE_SCALE)
        eye.Eye:ClearAllPoints()
        eye.Eye:SetPoint("CENTER", eye, "CENTER", 0.5 / EYE_SCALE, (0.5 - EYE_SCALE) / EYE_SCALE)
    end
    local over = eye.fcuiOver
    if not over then
        over = CreateFrame("Frame", nil, eye)
        over:SetAllPoints(eye)
        eye.fcuiOver = over
    end
    over:SetFrameLevel((eye.Eye and eye.Eye:GetFrameLevel() or eye:GetFrameLevel()) + 5)
    local border = ns.OwnTexture(over, "border", "OVERLAY")
    ns.SetTex(border, "trackingBorder")
    border:SetSize(52, 52)
    ns.SetPointOnce(border, "TOPLEFT", eye, "TOPLEFT", 1, -1)
    if eye.Selection and eye.Selection.SetFrameStrata and eye.Selection:GetFrameStrata() ~= "HIGH" then
        eye.Selection:SetFrameStrata("HIGH")
    end
    local dragging = eye.IsDragging and eye:IsDragging()
    if EyeMoved(eye) or dragging or InCombatLockdown() then return end
    if eye:GetParent() ~= UIParent then eye:SetParent(UIParent) end
    -- Its scale is the client's, from the size set in edit mode, and is
    -- left alone. It is stood by its centre, with the distances turned
    -- into its own units, so it grows and shrinks about its place on the
    -- rim whatever that size is.
    local own = eye:GetEffectiveScale()
    local k = (own and own > 0) and (backdrop:GetEffectiveScale() / own) or 1
    ns.SetPointOnce(eye, "CENTER", backdrop, "TOPLEFT", 38.5 * k, -116.5 * k)
end

local function Layout()
    local cluster = MinimapCluster
    local backdrop = MinimapBackdrop
    local map = Minimap
    if not cluster or not backdrop or not map then ns.MissingPiece("MinimapCluster") return end
    -- Edit mode's size setting scales the map container alone, which drew
    -- the map out of its ring and left the zone name inside it. The whole
    -- cluster takes the size instead, so the classic minimap grows as one
    -- and every spot below stays written in 1.x pixels.
    local size = 1
    if cluster.GetSettingValue and Enum and Enum.EditModeMinimapSetting and Enum.EditModeMinimapSetting.Size then
        local ok, value = pcall(cluster.GetSettingValue, cluster, Enum.EditModeMinimapSetting.Size)
        if ok and type(value) == "number" and value > 0 then size = value / 100 end
    end
    if cluster.MinimapContainer and cluster.MinimapContainer:GetScale() ~= 1 then
        cluster.MinimapContainer:SetScale(1)
    end
    if math.abs((cluster:GetScale() or 1) - size) > 0.001 then cluster:SetScale(size) end
    -- Blizzard scales the header a second time when the map grows.
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

    -- Buttons that sit over the map edge must be above the map to take clicks.
    local above = map:GetFrameLevel() + 5

    -- Zoom buttons on the lower right of the ring.
    for _, entry in ipairs({ { map.ZoomIn, "zoomIn", 72, -25 }, { map.ZoomOut, "zoomOut", 50, -43 } }) do
        local button, key, x, y = entry[1], entry[2], entry[3], entry[4]
        if button then
            button:SetParent(backdrop)
            button:SetFrameLevel(above)
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
            -- The client's zoom buttons grey their disabled picture on top of
            -- whatever it is: the old disabled art is grey of its own, and the
            -- bronze theme's copy came out silver under it, the minus at full
            -- zoom out.
            local disabled = button:GetDisabledTexture()
            if disabled and disabled.SetDesaturated then disabled:SetDesaturated(false) end
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
        tracking:SetFrameLevel(above)
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
            local button = tracking.Button
            button:SetSize(32, 32)
            button:SetFrameLevel(above + 1)
            ns.SetPointOnce(button, "TOPLEFT", tracking, "TOPLEFT", 0, 0)
            -- Blizzard draws the current tracking icon as the button's
            -- normal texture; keep it, at the 1.x icon size.
            for _, state in ipairs({ "Normal", "Pushed" }) do
                local tex = button["Get" .. state .. "Texture"](button)
                if tex then
                    tex:SetSize(20, 20)
                    tex:ClearAllPoints()
                    tex:SetPoint("TOPLEFT", tracking, "TOPLEFT", state == "Pushed" and 8 or 6, state == "Pushed" and -8 or -6)
                end
            end
            -- With nothing tracked the client shows a picture of its own
            -- drawing, from its atlas; the old button showed the
            -- magnifying glass. An icon the client puts there for a
            -- tracking that is on is a file, not an atlas piece, and is
            -- left alone. The client puts its own back whenever it likes,
            -- so it is looked at on a slow beat.
            local function OldGlass()
                for _, state in ipairs({ "Normal", "Pushed" }) do
                    local tex = button["Get" .. state .. "Texture"](button)
                    if tex and tex.GetAtlas and tex:GetAtlas() then
                        ns.SetTex(tex, "trackingNone")
                        tex:SetTexCoord(0, 1, 0, 1)
                        tex:SetSize(20, 20)
                    end
                end
            end
            OldGlass()
            if not tracking.fcuiGlassWatch then
                local watch = CreateFrame("Frame", nil, tracking)
                tracking.fcuiGlassWatch = watch
                watch:SetScript("OnUpdate", function(self, elapsed)
                    self.since = (self.since or 0) + elapsed
                    if self.since < 0.2 then return end
                    self.since = 0
                    if active then OldGlass() end
                end)
            end
            ns.SetButtonTex(button, "Highlight", "zoomHighlight")
            local hl = button:GetHighlightTexture()
            if hl then hl:SetTexCoord(0, 1, 0, 1); hl:ClearAllPoints(); hl:SetAllPoints(button); hl:SetBlendMode("ADD") end
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
        GameTimeFrame:SetFrameLevel(above)
        GameTimeFrame:SetSize(40, 40)
        ns.SetPointOnce(GameTimeFrame, "TOPRIGHT", map, "TOPRIGHT", 20, -2)
        GameTimeFrame:SetHitRectInsets(6, 0, 5, 10)
        ns.SkinCalendar()
    end

    -- Clock at the bottom of the map.
    if TimeManagerClockButton then
        local clock = TimeManagerClockButton
        clock:SetParent(map)
        clock:SetFrameLevel(above)
        clock:SetSize(60, 28)
        ns.SetPointOnce(clock, "CENTER", map, "CENTER", 0, -75)
        -- Retail's rounded clock plate goes; only our stone plate and the time stay.
        for _, region in ipairs({ clock:GetRegions() }) do
            if region:IsObjectType("Texture") and not (clock.fcui and clock.fcui.bg == region) then region:SetAlpha(0) end
        end
        local bg = ns.OwnTexture(clock, "bg", "BORDER")
        bg:SetAlpha(1)
        ns.SetTex(bg, "clockBackground")
        bg:SetTexCoord(0.015625, 0.8125, 0.015625, 0.390625)
        bg:SetAllPoints(TimeManagerClockButton)
        if TimeManagerClockTicker then ns.SetPointOnce(TimeManagerClockTicker, "CENTER", TimeManagerClockButton, "CENTER", 3, 1) end
    end

    -- Queue eye on the lower left, instance flag on the upper left.
    if QueueStatusButton then
        PlaceEye()
        -- Moved, put back to its default, moved again: each is heard of
        -- here only by looking.
        if not eyeWatch then
            eyeWatch = CreateFrame("Frame")
            eyeWatch:SetScript("OnUpdate", function(self, elapsed)
                self.since = (self.since or 0) + elapsed
                if self.since < 0.1 then return end
                self.since = 0
                SizeResetButton()
                if not active or not QueueStatusButton then return end
                local moved = EyeMoved(QueueStatusButton)
                local scale = QueueStatusButton:GetEffectiveScale()
                if moved ~= self.moved or scale ~= self.scale then
                    self.moved, self.scale = moved, scale
                    PlaceEye()
                end
            end)
        end
    end
    if cluster.InstanceDifficulty then
        ns.SetPointOnce(cluster.InstanceDifficulty, "TOPLEFT", cluster, "TOPLEFT", 22, -17)
    end
    -- No expansion landing page in 1.x; the button stays reachable from
    -- the micro menu, so it is faded out here rather than moved.
    if ExpansionLandingPageMinimapButton then
        ExpansionLandingPageMinimapButton:SetAlpha(0)
        ExpansionLandingPageMinimapButton:EnableMouse(false)
    end
    if AddonCompartmentFrame then AddonCompartmentFrame:Hide() end

    -- Addon minimap buttons: the library places them from the map's own
    -- width, which puts them on the stone ring the way 1.x buttons sat;
    -- re-laid here so they follow the smaller map.
    local ldbi = LibStub and LibStub.GetLibrary and LibStub:GetLibrary("LibDBIcon-1.0", true)
    if ldbi and ldbi.GetButtonList and ldbi.Refresh then
        for _, name in ipairs(ldbi:GetButtonList()) do pcall(ldbi.Refresh, ldbi, name) end
    end
    if ns.OnMinimapLaid then ns.OnMinimapLaid(ldbi) end
end

-- The 1.x calendar button: the day number on the stone calendar art.
function ns.SkinCalendar()
    local button = GameTimeFrame
    if not button or not active then return end
    ns.SetButtonTex(button, "Normal", "calendarButton")
    ns.SetButtonTex(button, "Pushed", "calendarButton")
    ns.SetButtonTex(button, "Highlight", "zoomHighlight")
    local normal, pushed, hl = button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture()
    if normal then normal:SetTexCoord(0, 0.390625, 0, 0.78125); normal:ClearAllPoints(); normal:SetAllPoints(button); normal:SetDrawLayer("BACKGROUND") end
    if pushed then pushed:SetTexCoord(0.5, 0.890625, 0, 0.78125); pushed:ClearAllPoints(); pushed:SetAllPoints(button); pushed:SetDrawLayer("BACKGROUND") end
    if hl then hl:SetTexCoord(0, 1, 0, 1); hl:ClearAllPoints(); hl:SetAllPoints(button); hl:SetBlendMode("ADD") end
    for _, region in ipairs({ button:GetRegions() }) do
        if region:IsObjectType("Texture") and region ~= normal and region ~= pushed and region ~= hl then region:SetAlpha(0) end
    end
    local day = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime().monthDay
    local fs = button:GetFontString()
    if not fs then
        button:SetNormalFontObject("GameFontBlack")
        fs = button:CreateFontString(nil, "OVERLAY", "GameFontBlack")
        button:SetFontString(fs)
    end
    fs:SetFontObject("GameFontBlack")
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", button, "CENTER", -1, -1)
    fs:SetDrawLayer("OVERLAY")
    if day then button:SetText(day) end
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
        ns.HookGlobal("GameTimeFrame_SetDate", ns.SkinCalendar)
        if ExpansionLandingPageMinimapButton then
            ns.HookMethod(ExpansionLandingPageMinimapButton, "UpdateIcon", function(self)
                if active then self:SetAlpha(0); self:EnableMouse(false) end
            end)
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
