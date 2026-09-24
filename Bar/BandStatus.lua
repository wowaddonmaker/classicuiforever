local _, ns = ...
local B = ns.band

-- XP and reputation bars in the band's top strip: the client's two holders re-hung, re-drawn in 1.x art, and watched.

local PIECES = B.PIECES
local STRIP_H = 10
-- How far the XP strip is held in from each band end.
local STATUS_INSET = 2
-- Reputation bar art when two bars show (rows of UI-ReputationWatchBar).
local REP_ROWS = { { 0, 0.171875 }, { 0.1875, 0.359375 }, { 0.375, 0.546875 }, { 0.5625, 0.734375 } }
local Remember, BandNow, Record, Differs, StatusPair = B.Remember, B.BandNow, B.Record, B.Differs, B.StatusPair
local ArtWidth, Anchor = B.ArtWidth, B.Anchor
local Dress, SetAlphaIf = ns.Dress, ns.SetAlphaIf

local FULL = { 0, 1, 0, 1 }
local TICK = { coords = FULL, fill = true, tint = true }
local TICK_HL = { coords = FULL, fill = true }
local REP_TOP = { point = "TOPLEFT", show = true }
local REP_RAIL = { tint = true, point = "TOPLEFT", show = true }
local RUN = {}   -- a strip's coords, refilled per piece

-- Art strips over a status bar so it reads as part of the band.
local function EnsureStrips(statusBar)
    if statusBar.fcuiStrips then return statusBar.fcuiStrips end
    local strips = {}
    for i = 1, 5 do
        strips[i] = statusBar:CreateTexture(nil, "ARTWORK", nil, 1)
    end
    statusBar.fcuiStrips = strips
    return strips
end

-- The client's fills are coloured atlases; the 1.x fill takes its colour from the atlas the client asked for.
local BAR_COLORS = {
    { "Rested", 0, 0.39, 0.88 }, { "Experience", 0.58, 0, 0.55 },
    { "Faction-Red", 0.8, 0.13, 0.13 }, { "Faction-Orange", 1, 0.5, 0 }, { "Faction-Yellow", 1, 1, 0 },
    { "Faction-Green", 0, 0.6, 0.1 }, { "Faction-Blue", 0, 0.6, 1 },
    { "Honor", 1, 0.24, 0 }, { "Artifact", 0.9, 0.8, 0.6 }, { "Azerite", 1, 0.8, 0.2 },
}

local function RecolorStatus(status, atlas)
    if not B.active then return end
    if atlas then
        status.fcuiAtlas = atlas
    else
        local tex = status:GetStatusBarTexture()
        status.fcuiAtlas = status.fcuiAtlas or (tex and tex.GetAtlas and tex:GetAtlas())
        atlas = status.fcuiAtlas
    end
    -- Shaded down its height only: the bar re-cuts its fill coords as the value changes, so a sheet column came out as blocks.
    ns.SetBarFill(status, "statusBarFlat")
    local r, g, b = 0.58, 0, 0.55
    if status.fcuiXP then
        -- Known by its tick. Rested (blue) = rested XP banked; checked in order: the run to the tick showing, the amount,
        -- the client's own flag (UpdateStatusBarTextures), the fill atlas, and last the rest state (reads Normal here with XP banked).
        local rested = false
        local run = status.fcuiRun
        if run and run:IsShown() and (run:GetWidth() or 0) > 0 then rested = true end
        if not rested and GetXPExhaustion then
            local amount = GetXPExhaustion()
            if amount and not (issecretvalue and issecretvalue(amount)) and amount > 0 then rested = true end
        end
        if not rested and status.fcuiRested then rested = true end
        if not rested and atlas and atlas:find("Rested", 1, true) then rested = true end
        if not rested and GetRestState then
            local state = GetRestState()
            if not (issecretvalue and issecretvalue(state)) and state == 1 then rested = true end
        end
        if rested then r, g, b = 0, 0.39, 0.88 end
        -- The run to the tick stays the faint 1.x wash; the client restores its own texture and strength on update
        -- (a shadow over the fill's end), so it is reset with every fill.
        if run then
            run:SetColorTexture(0, 0.39, 0.88, 0.15)
            run:SetVertexColor(1, 1, 1, 1)
            run:SetAlpha(1)
            run:SetDrawLayer("BACKGROUND", 0)
        end
    elseif status.fcuiBar and status.fcuiBar.factionID and C_Reputation and C_Reputation.GetWatchedFactionData then
        -- Watched faction in the old standing colours, from the standing (the art name gave purple): red to hostile,
        -- orange unfriendly, yellow neutral, green from friendly.
        local ok, data = pcall(C_Reputation.GetWatchedFactionData)
        local reaction = ok and data and data.reaction
        if type(reaction) == "number" and not (issecretvalue and issecretvalue(reaction)) then
            if reaction <= 2 then r, g, b = 0.8, 0.3, 0.22
            elseif reaction == 3 then r, g, b = 0.75, 0.27, 0
            elseif reaction == 4 then r, g, b = 0.9, 0.7, 0
            else r, g, b = 0, 0.6, 0.1 end
        else
            r, g, b = 0, 0.6, 0.1
        end
    elseif atlas then
        for _, entry in ipairs(BAR_COLORS) do
            if atlas:find(entry[1], 1, true) then r, g, b = entry[2], entry[3], entry[4] break end
        end
    end
    status:SetStatusBarColor(r, g, b)
end

-- The client picks the XP fill by rest state through this method; keep its answer and recolour, blue exactly when its own is.
local function HookRestedState(bar, status)
    if not bar.UpdateStatusBarTextures then return end
    ns.HookMethod(bar, "UpdateStatusBarTextures", function(self, isRested)
        local sb = self.StatusBar or status
        if not sb then return end
        sb.fcuiRested = isRested and true or false
        RecolorStatus(sb)
    end)
end

-- The client's segment posts on a holder (from its pool); the strip draws the 1.x ones.
local function SetDividers(container, alpha, changed)
    local pool = container and container.HorizontalDividersPool
    if not (pool and pool.EnumerateActive) then return end
    for divider in pool:EnumerateActive() do
        if changed then SetAlphaIf(divider, alpha) else divider:SetAlpha(alpha) end
    end
end
B.SetDividers = SetDividers

-- The client rebuilds its posts on each layout: fade them as it does.
local function OnDividers(self)
    if B.active then SetDividers(self, 0) end
end

-- XP bar in the band's top 10 px; a second bar (reputation, honor) over it in the old reputation watch bar art.
local function LayoutStatusBar(container, isTop)
    if not container then return end
    -- A holder the player moved in edit mode is theirs: it stays at the layout's spot, drawn as the plain strip, and Reset
    -- To Default Position brings it back. In a fight one snapped to a client bar is locked with it, so left as is.
    local own = B.SystemMoved(container)
    if own and InCombatLockdown() and container.IsProtected and container:IsProtected() then return end
    if own then isTop = false end
    -- In the player's hand it follows the mouse.
    if not container.isDragging and own then
        -- Band size at the layout's spot/scale, only when not there already. Base widget calls only: the client's
        -- wrappers write a snap note that marks its next drag or hide as ours.
        local info = container.systemInfo and container.systemInfo.anchorInfo
        local scale = BandNow()
        if info and info.point then
            local setScale = container.SetScaleBase or container.SetScale
            local clearPoints = container.ClearAllPointsBase or container.ClearAllPoints
            local setPoint = container.SetPointBase or container.SetPoint
            Remember(container)
            if math.abs((container:GetScale() or 1) - scale) > 0.001 then setScale(container, scale) end
            local rel = type(info.relativeTo) == "string" and _G[info.relativeTo] or info.relativeTo
            if type(rel) ~= "table" then rel = UIParent end
            local relPoint = info.relativePoint or info.point
            local x, y = (info.offsetX or 0) / scale, (info.offsetY or 0) / scale
            local point, at, atPoint, px, py = container:GetPoint(1)
            if point ~= info.point or at ~= rel or atPoint ~= relPoint
                or math.abs((px or 0) - x) > 0.05 or math.abs((py or 0) - y) > 0.05 then
                clearPoints(container)
                setPoint(container, info.point, rel, relPoint, x, y)
                local second = container.systemInfo.anchorInfo2
                if second and second.point then
                    local rel2 = type(second.relativeTo) == "string" and _G[second.relativeTo] or second.relativeTo
                    if type(rel2) ~= "table" then rel2 = UIParent end
                    setPoint(container, second.point, rel2, second.relativePoint or second.point,
                        (second.offsetX or 0) / scale, (second.offsetY or 0) / scale)
                end
            end
        end
    elseif not container.isDragging then
        -- The upper bar stands 2 clear of the band (its art runs 2 under its fill). In a fight the band frame keeps its old
        -- width while the art is drawn to the new one from the left: centre on the art.
        local dx = 0
        if InCombatLockdown() and B.art:GetWidth() then dx = (ArtWidth() - B.art:GetWidth()) / 2 end
        Anchor(container, isTop and "BOTTOM" or "TOP", "TOP", dx, isTop and 2 or -1, BandNow())
    end
    local h = isTop and 7 or STRIP_H
    -- Inside the band frame, not across it: its ends showed past a hidden gryphon.
    local w = ArtWidth() - STATUS_INSET * 2
    -- Off the band, edit mode's Size applies too (100% = band length).
    if own then
        local setting = Enum and Enum.EditModeStatusTrackingBarSetting and Enum.EditModeStatusTrackingBarSetting.Size
        if setting ~= nil and container.GetSettingValue then
            local ok, size = pcall(container.GetSettingValue, container, setting)
            if ok and type(size) == "number" and size > 0 then w = w * size / 100 end
        end
    end
    container:SetSize(w, h)
    if container.BarFrameTexture then container.BarFrameTexture:SetAlpha(0) end
    -- The client fades one bar out and the next in (both out first on a swap), reading a holder's alpha at each fade's end
    -- to pick the direction. Fades kept but cut to 0.02 s: a zero-length fade never ran and the swap hung on it.
    if not container.fcuiNoFade then
        container.fcuiNoFade = true
        for _, key in ipairs({ "FadeInAnimation", "FadeOutAnimation" }) do
            local group = container[key]
            if group and group.GetAnimations then
                for _, anim in ipairs({ group:GetAnimations() }) do
                    if anim.SetDuration then anim:SetDuration(0.02) end
                    if anim.SetStartDelay then anim:SetStartDelay(0) end
                end
            end
        end
    end
    OnDividers(container)
    ns.HookMethod(container, "UpdateDividers", OnDividers)
    for _, bar in pairs(container.bars or {}) do
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        bar:SetSize(w, h)
        local status = bar.StatusBar
        if status then
            status:ClearAllPoints()
            status:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
            status:SetSize(w, h)
            status.fcuiXP = bar.ExhaustionTick ~= nil
            status.fcuiBar = bar
            ns.HookMethod(status, "SetBarTexture", RecolorStatus)
            HookRestedState(bar, status)
            RecolorStatus(status)
            if status.Background then status.Background:SetAlpha(0) end
            -- Rested: the paler run to the tick moves from the bar frame onto the status bar, under the strips and fill;
            -- the tick wears the old marker.
            local run = bar.ExhaustionLevelFillBar
            status.fcuiRun = run
            local tick = bar.ExhaustionTick
            if tick and tick.UpdateTickPosition then
                ns.HookMethod(tick, "UpdateTickPosition", function() RecolorStatus(status) end)
            end
            if run then
                if run.SetParent then run:SetParent(status) end
                run:SetDrawLayer("BACKGROUND", 0)
                run:SetVertexColor(1, 1, 1, 1)
                -- Flat 15% blue: the client re-cuts the run's coords by its width, which on a sheet sampled other columns.
                run:SetColorTexture(0, 0.39, 0.88, 0.15)
                run:ClearAllPoints()
                run:SetPoint("BOTTOMLEFT", status, "BOTTOMLEFT", 0, 0)
                run:SetHeight(h)
            end
            if tick and not tick.fcuiSkinned then
                tick.fcuiSkinned = true
                tick:SetSize(32, 32)
                Dress(tick.Normal, "exhaustionTick", TICK, tick)
                Dress(tick.Highlight, "exhaustionTickHighlight", TICK_HL, tick)
            end
            -- The old bar's full art stretched to band width, never cut: as many segments as keep a post nearest every 51.2
            -- of 1024, stretched at most a tenth either way to fill end to end.
            local strips = EnsureStrips(status)
            local segment = 1024 / 20
            local count = math.max(1, math.floor(w / segment + 0.5))
            local stretch = (w / count) / segment
            local sheetTo = math.min(1024, w / stretch)
            for i, tex in ipairs(strips) do
                local piece = PIECES[i]
                local from = (i - 1) * 256
                local to = math.min(sheetTo, i * 256)
                if piece and to > from then
                    local u1 = (to - from) / 256
                    if isTop then
                        -- 11 rows with the channel in 2-8: start at 2 over the 7-tall fill so it lies in the channel.
                        RUN[1], RUN[2], RUN[3], RUN[4] = 0, u1, REP_ROWS[i][1], REP_ROWS[i][2]
                        Dress(tex, "repBar", REP_TOP, status, from * stretch, 2, (to - from) * stretch, 11, RUN)
                    else
                        -- Cut from the band's sheets, which stay stone; only the rail tints bronze.
                        RUN[1], RUN[2], RUN[3], RUN[4] = 0, u1, piece.strip[1], piece.strip[2]
                        Dress(tex, piece.stripKey or piece.key, REP_RAIL, status, from * stretch, 0, (to - from) * stretch, STRIP_H, RUN)
                    end
                else
                    tex:Hide()
                end
            end
        end
    end
end

local function HasVisibleBar(container)
    if not container then return false end
    for _, bar in pairs(container.bars or {}) do
        if bar:IsShown() then return true end
    end
    return false
end
B.HasVisibleBar = HasVisibleBar

-- Recheck the XP fill against rest state: on rest events and on entering the world (when the state is known).
function B.RecolorExpBars()
    if not B.active then return end
    for _, container in ipairs(StatusPair()) do
        for _, bar in pairs(container and container.bars or {}) do
            if bar.ExhaustionTick and bar.StatusBar then
                bar.StatusBar.fcuiRested = nil
                RecolorStatus(bar.StatusBar)
            end
        end
    end
end

-- Whether a holder is showing the XP bar.
local function ShowsExperience(container)
    for _, bar in pairs(container and container.bars or {}) do
        if bar:IsShown() and bar.ExhaustionTick then return true end
    end
    return false
end

local function LayoutStatusBars()
    local main, second = MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer
    -- With two bars up XP keeps the band strip and the faction stands over it; the client gives its first holder to the faction.
    local swap = HasVisibleBar(main) and HasVisibleBar(second) and ShowsExperience(second) and not ShowsExperience(main)
    -- A holder moved off the band leaves the strip to the other, with nothing over it.
    local mainOn = main and not B.SystemMoved(main)
    local secondOn = second and not B.SystemMoved(second)
    LayoutStatusBar(main, (swap and secondOn) and true or false)
    LayoutStatusBar(second, ((not swap) and mainOn) and true or false)
    -- Holder alpha is left to the client's fades and the watch: set here mid-swap, a quick watch toggle left both at 0.
    -- The thin top bar stands in for a missing strip (moved off included).
    local anyShown = (mainOn and main:IsShown()) or (secondOn and second:IsShown())
    local art = B.art
    for _, tex in ipairs(art.maxLevel) do tex:SetShown(not anyShown and tex.fcuiInBand == true and not art.artHidden) end
end
B.LayoutStatusBars = LayoutStatusBars

-- What is up and which way round, as one number.
local function BarsState()
    local main, second = MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer
    local mainUp, secondUp = HasVisibleBar(main), HasVisibleBar(second)
    local swap = mainUp and secondUp and ShowsExperience(second) and not ShowsExperience(main)
    return (mainUp and 1 or 0) + (secondUp and 2 or 0) + (swap and 4 or 0), mainUp and secondUp
end

-- Polled, not event-driven: the client swaps bars over stacking fades. A settled state is laid once; a holder
-- left at alpha 0 with a bar up and no fade running is restored. No client calls.
local FADES = { "FadeInAnimation", "FadeOutAnimation", "MaxLevelFadeOutAnimation" }
local function Playing(container)
    for i = 1, #FADES do
        local group = container[FADES[i]]
        if group and group.IsPlaying and group:IsPlaying() then return true end
    end
    return false
end

-- Watching or dropping a faction changes which bars are up and which stands over which: re-laid once the client
-- is done. 20 Hz, in the band's lane (BandWatch).
local barsWatch = { since = 0 }
function B.BarsTick(elapsed)
    local watch = barsWatch
    watch.since = watch.since + elapsed
    if watch.since < 0.05 then return end
    watch.since = 0
    if not (B.active and B.art) then return end
    local busy = false
    for _, container in ipairs(StatusPair()) do
        if container then
            if Playing(container) then
                busy = true
            elseif HasVisibleBar(container) and (container:GetAlpha() or 1) < 1 then
                container:SetAlpha(1)
            end
        end
    end
    -- Only once the client has finished moving, and out of combat.
    if busy or InCombatLockdown() then return end
    local state, two = BarsState()
    if state ~= watch.state then
        watch.state = state
        pcall(LayoutStatusBars)
        -- The rows over the band rise and fall with the second bar.
        if two ~= watch.two then
            watch.two = two
            ns.QueueApply()
        end
    end
end

-- Whether the bars are still heading to the last request (a fade running, or a settled state not yet laid);
-- what changes them (reputation's Show as Experience Bar) waits on this.
function ns.StatusBarsBusy()
    if not (B.active and B.art) then return false end
    for _, container in ipairs(StatusPair()) do
        if container and Playing(container) then return true end
    end
    return (BarsState()) ~= barsWatch.state
end

-- Whether a watched faction's bar is up now.
function ns.StatusBarsShowFaction()
    for _, container in ipairs(StatusPair()) do
        for _, bar in pairs(container and container.bars or {}) do
            if bar:IsShown() and not bar.ExhaustionTick and bar.factionID then return true end
        end
    end
    return false
end

-- The holders are not protected: they go back into the band even in a fight, when the client moves them most
-- (e.g. a target with combo points).
local statusList
local function StatusFrames()
    if statusList then return statusList end
    statusList = {}
    for _, frame in ipairs(StatusPair()) do
        if frame and frame.GetPoint then statusList[#statusList + 1] = frame end
    end
    return statusList
end

-- The client hands a holder its bars after login and resizes them without the holder moving; our strips and colours
-- live on them, so the sample counts them and sums their sizes (order-free).
local statusMark = {}
local function BarSums(container)
    local count, width, height = 0, 0, 0
    for _, bar in pairs(container.bars or {}) do
        count = count + 1
        width = width + (bar:GetWidth() or 0)
        height = height + (bar:GetHeight() or 0)
        local status = bar.StatusBar
        if status then
            width = width + (status:GetWidth() or 0)
            height = height + (status:GetHeight() or 0)
        end
    end
    return count, width, height
end

function B.MarkStatus()
    for _, frame in ipairs(StatusFrames()) do
        local mark = Record(frame, statusMark[frame])
        mark.count, mark.width, mark.height = BarSums(frame)
        local bar = frame.bars and frame.bars[1]
        mark.bar1 = bar and bar:GetWidth() or 0
        statusMark[frame] = mark
    end
    -- Every band pass ends here: the cast bar re-measures its stand.
    B.castWatch.want = nil
end

-- Per-frame tripwire: the client re-anchors and resizes the holders when a fade ends (UpdateShownState from OnFinished), no event.
function B.hot.StatusTrip()
    local list = statusList
    if not list then return false end
    for i = 1, #list do
        local frame = list[i]
        local mark = statusMark[frame]
        if mark then
            local point, rel, _, x, y = frame:GetPoint(1)
            if point ~= mark.point or rel ~= mark.rel or math.abs((x or 0) - mark.x) > 0.05 or math.abs((y or 0) - mark.y) > 0.05
                or math.abs((frame:GetWidth() or 0) - mark.w) > 0.05 then
                return true
            end
            local bar = frame.bars and frame.bars[1]
            if bar and math.abs((bar:GetWidth() or 0) - mark.bar1) > 0.05 then return true end
        end
    end
    return false
end

function B.StatusMoved()
    for _, frame in ipairs(StatusFrames()) do
        local mark = statusMark[frame]
        if Differs(frame, mark) then return true end
        local count, width, height = BarSums(frame)
        if count ~= mark.count or math.abs(width - mark.width) > 0.05 or math.abs(height - mark.height) > 0.05 then
            return true
        end
    end
    return false
end

function B.StatusBack()
    if not B.active or B.applying then return end
    -- A dragged holder moves every frame; the drop's pass lays it.
    for _, frame in ipairs(StatusFrames()) do
        if frame.isDragging then return end
    end
    ns.stripPasses = (ns.stripPasses or 0) + 1
    B.applying = true
    pcall(LayoutStatusBars)
    B.applying = false
    B.MarkStatus()
end
