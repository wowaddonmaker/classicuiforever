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
local Drifted, ArtWidth, Anchor = B.Drifted, B.ArtWidth, B.Anchor
local Dress, SetAlphaIf = ns.Dress, ns.SetAlphaIf
local EditModeLive = ns.EditMode.Live

local FULL = { 0, 1, 0, 1 }
local TICK = { coords = FULL, fill = true, tint = true }
local TICK_HL = { coords = FULL, fill = true }
local REP_TOP = { point = "TOPLEFT", show = true }
local REP_RAIL = { tint = true, point = "TOPLEFT", show = true }
local RUN = {}   -- a strip's coords, refilled per piece

-- Art strips over a status bar so it reads as part of the band; at least n of them.
local function EnsureStrips(statusBar, n)
    local strips = statusBar.fcuiStrips
    if not strips then
        strips = {}
        statusBar.fcuiStrips = strips
    end
    for i = #strips + 1, n do
        strips[i] = statusBar:CreateTexture(nil, "ARTWORK", nil, 1)
    end
    return strips
end

-- The strip's posts sit every 51 texels at 3.5 + 51k; 1 to 19 are Y posts, 0 and 20 the end brackets.
-- The window sits 1 texel left of the post centres: seen in game, a whole left half post, a trimmed right one.
local POST_PITCH, POST_AT, POST_RUNS, POST_SHIFT = 51, 3.5, 18, 1

-- On the band: the old bar's full art stretched to band width, never cut: as many segments as keep a post nearest every
-- 51.2 of 1024, stretched at most a tenth either way to fill end to end.
local function DrawBandStrips(status, w, isTop)
    local strips = EnsureStrips(status, 4)
    local count = math.max(1, math.floor(w / (1024 / 20) + 0.5))
    local stretch = w / (count * 1024 / 20)
    local sheetTo = math.min(1024, count * 1024 / 20)
    for i = 1, 4 do
        local piece, tex = PIECES[i], strips[i]
        local from = (i - 1) * 256
        local to = math.min(sheetTo, i * 256)
        if to - from > 0.01 then
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
    return 4
end

-- Moved off the band: whole segments post to post (half Y posts at both ends), repeating the sheet's 18 past its end,
-- with the top rail flipped under the channel for the lower border the band's rim gives it there.
local function DrawOwnStrips(status, w)
    local count = math.max(1, math.floor(w / POST_PITCH + 0.5))
    local stretch = w / (count * POST_PITCH)
    local used, done = 0, 0
    local a = POST_AT + POST_PITCH - POST_SHIFT
    while done < count do
        local run = math.min(count - done, POST_RUNS)
        local b = a + run * POST_PITCH
        local x0 = done * POST_PITCH - a
        for i = math.floor(a / 256) + 1, math.ceil(b / 256) do
            local piece = PIECES[i]
            local base = (i - 1) * 256
            local lo, hi = math.max(a, base), math.min(b, i * 256)
            if hi - lo > 0.01 then
                local strips = EnsureStrips(status, used + 2)
                local key, v0 = piece.stripKey or piece.key, piece.strip[1]
                local x, width = (x0 + lo) * stretch, (hi - lo) * stretch
                -- Seen in game: the bar's left end wants two more texels of its post, drawn past the holder's edge.
                if used == 0 then lo, x, width = lo - 2, x - 2 * stretch, width + 2 * stretch end
                RUN[1], RUN[2], RUN[3], RUN[4] = (lo - base) / 256, (hi - base) / 256, v0, piece.strip[2]
                Dress(strips[used + 1], key, REP_RAIL, status, x, 0, width, STRIP_H, RUN)
                RUN[3], RUN[4] = v0 + 2 / 256, v0
                Dress(strips[used + 2], key, REP_RAIL, status, x, -STRIP_H, width, 2, RUN)
                used = used + 2
            end
        end
        done = done + run
    end
    return used
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
            if amount and not ns.IsSecret(amount) and amount > 0 then rested = true end
        end
        if not rested and status.fcuiRested then rested = true end
        if not rested and atlas and atlas:find("Rested", 1, true) then rested = true end
        if not rested and GetRestState then
            local state = GetRestState()
            if not ns.IsSecret(state) and state == 1 then rested = true end
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
        if type(reaction) == "number" and not ns.IsSecret(reaction) then
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
local function SetDividers(container, alpha)
    local pool = container and container.HorizontalDividersPool
    if not (pool and pool.EnumerateActive) then return end
    for divider in pool:EnumerateActive() do divider:SetAlpha(alpha) end
end
B.SetDividers = SetDividers

-- Posts faded per holder (weak): a released post keeps alpha 0 (the pool's reset only hides), so only a grown pool is walked.
local fadedCount = setmetatable({}, { __mode = "k" })
function B.FadeNewDividers(container)
    local pool = container and container.HorizontalDividersPool
    if not (pool and pool.GetNumActive and pool.EnumerateActive) then return end
    local count = pool:GetNumActive()
    if count <= (fadedCount[container] or 0) then return end
    for divider in pool:EnumerateActive() do SetAlphaIf(divider, 0) end
    fadedCount[container] = count
end

-- The client rebuilds its posts on each layout: fade them as it does.
local function OnDividers(self)
    if B.active then SetDividers(self, 0) end
end

-- Base widget calls only: the client's wrappers write a snap note that marks its next drag or hide as ours.
local function BaseSetters(container)
    return container.SetScaleBase or container.SetScale, container.ClearAllPointsBase or container.ClearAllPoints,
        container.SetPointBase or container.SetPoint
end
B.BaseSetters = BaseSetters

local function AnchorOf(info)
    local rel = type(info.relativeTo) == "string" and _G[info.relativeTo] or info.relativeTo
    if type(rel) ~= "table" then rel = UIParent end
    return rel, info.relativePoint or info.point
end

-- A moved holder at the layout's spot and band scale, only when not there already.
local function PlaceOwn(container)
    local info = container.systemInfo and container.systemInfo.anchorInfo
    if not (info and info.point) then return end
    local scale = BandNow()
    local setScale, clearPoints, setPoint = BaseSetters(container)
    Remember(container)
    if math.abs((container:GetScale() or 1) - scale) > 0.001 then setScale(container, scale) end
    local rel, relPoint = AnchorOf(info)
    local x, y = (info.offsetX or 0) / scale, (info.offsetY or 0) / scale
    local point, at, atPoint, px, py = container:GetPoint(1)
    if point ~= info.point or at ~= rel or atPoint ~= relPoint
        or math.abs((px or 0) - x) > 0.05 or math.abs((py or 0) - y) > 0.05 then
        clearPoints(container)
        setPoint(container, info.point, rel, relPoint, x, y)
        local second = container.systemInfo.anchorInfo2
        if second and second.point then
            local rel2, relPoint2 = AnchorOf(second)
            setPoint(container, second.point, rel2, relPoint2, (second.offsetX or 0) / scale, (second.offsetY or 0) / scale)
        end
    end
end

local function SizeSetting()
    return Enum and Enum.EditModeStatusTrackingBarSetting and Enum.EditModeStatusTrackingBarSetting.Size
end

-- Edit mode's Width for a holder as a fraction (100% = band length).
local function HolderPct(container)
    local setting = SizeSetting()
    if setting == nil or not container.GetSettingValue then return 1 end
    local ok, size = pcall(container.GetSettingValue, container, setting)
    if ok and type(size) == "number" and size > 0 then return size / 100 end
    return 1
end

local function Protected(frame)
    return frame.IsProtected and frame:IsProtected() and true or false
end

local function RelayStatus()
    if B.StatusBack then B.StatusBack() end
end

-- A holder at its spot and size: a moved one is the player's (layout spot, plain strip), else on the band.
-- Nil while a client bar snapped to it locks it in a fight: the client alone moves it then, ours waits for the end.
local function PlaceHolder(container, isTop, own)
    if InCombatLockdown() and Protected(container) then
        ns.WhenCalm("statusRelay", RelayStatus)
        return nil
    end
    if own then isTop = false end
    -- In the player's hand it follows the mouse.
    if not container.isDragging and own then
        PlaceOwn(container)
    elseif not container.isDragging then
        -- The upper bar stands 2 clear of the band (its art runs 2 under its fill). In a fight the band frame keeps its old
        -- width while the art is drawn to the new one from the left: centre on the art.
        local dx = 0
        if InCombatLockdown() and B.art:GetWidth() then dx = (ArtWidth() - B.art:GetWidth()) / 2 end
        Anchor(container, isTop and "BOTTOM" or "TOP", "TOP", dx, isTop and 2 or -1, BandNow())
    end
    -- Off the band it carries its own 2-row lower rail.
    local h = isTop and 7 or own and STRIP_H + 2 or STRIP_H
    -- Inside the band frame, not across it: its ends showed past a hidden gryphon.
    local w = ArtWidth() - STATUS_INSET * 2
    if own then w = w * HolderPct(container) end
    container:SetSize(w, h)
    return isTop, w, h
end

-- The client places the tick and sizes the run only on XP events, so a Width change moved neither.
local function FitRested(bar, tick, run, w)
    if not (UnitXP and UnitXPMax and GetXPExhaustion) then return end
    local xp, most, rest = UnitXP("player"), UnitXPMax("player"), GetXPExhaustion()
    if ns.AnySecret(xp, most, rest) then return end
    if type(xp) ~= "number" or type(most) ~= "number" or type(rest) ~= "number" or most <= 0 or rest <= 0 then return end
    local at = math.max((xp + rest) / most * w, 0)
    -- Past the end the client either clamps to the edge (run shown) or drops the tick's anchor (run hidden).
    local over = at > w
    at = math.min(at, w)
    if tick:IsShown() and not (over and not (run and run:IsShown())) then
        ns.SetPointOnce(tick, "CENTER", bar, "LEFT", at, _G.EXHAUSTION_TICK_OFFSET_Y or 0)
    end
    if run and run:IsShown() then run:SetWidth(at) end
end

-- A holder's bars drawn in 1.x art at w x h.
local function DressBars(container, w, h, own, isTop)
    if container.BarFrameTexture then container.BarFrameTexture:SetAlpha(0) end
    -- The client fades one bar out and the next in (both out first on a swap), reading a holder's alpha at each fade's end
    -- to pick the direction. Fades kept but cut to 0.02 s: a zero-length fade never ran and the swap hung on it.
    if ns.Once(container, "noFade") then
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
        -- Kept for the hand-back: the holder goes back to its own size, so its bars must too.
        Remember(bar)
        ns.SetPointOnce(bar, "TOPLEFT", container, "TOPLEFT", 0, 0)
        bar:SetSize(w, h)
        local status = bar.StatusBar
        if status then
            Remember(status)
            ns.SetPointOnce(status, "TOPLEFT", bar, "TOPLEFT", 0, 0)
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
                ns.SetPointOnce(run, "BOTTOMLEFT", status, "BOTTOMLEFT", 0, 0)
                run:SetHeight(h)
            end
            if tick and ns.Once(tick, "tickSkinned") then
                tick:SetSize(32, 32)
                Dress(tick.Normal, "exhaustionTick", TICK, tick)
                Dress(tick.Highlight, "exhaustionTickHighlight", TICK_HL, tick)
            end
            local used = own and DrawOwnStrips(status, w) or DrawBandStrips(status, w, isTop)
            local strips = status.fcuiStrips
            for k = used + 1, #strips do strips[k]:Hide() end
            if tick then FitRested(bar, tick, run, w) end
        end
    end
end

-- XP bar in the band's top 10 px; a second bar (reputation, honor) over it in the old reputation watch bar art.
local function LayoutStatusBar(container, isTop)
    if not container then return end
    -- A moved holder stays at the layout's spot and Reset To Default Position brings it back.
    local own = B.SystemMoved(container)
    local top, w, h = PlaceHolder(container, isTop, own)
    if not w then
        -- Locked: its own bars (not protected) re-dressed where it stands.
        top, w, h = isTop and not own, container:GetWidth(), container:GetHeight()
        if not (w and w > 0 and h and h > 0) then return end
    end
    DressBars(container, w, h, own, top)
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

-- The one holder moved in edit mode is the bars' home: XP (else the lone bar) there, a second bar on it at its width and scale,
-- not in edit mode. Returns home, low, high (high nil: a lone bar moves home); mainUp/secondUp: read this tick, or nil.
local function StackPlan(main, second, mainUp, secondUp)
    if not (main and second) or ns.sessionEnding or EditModeLive() then return nil end
    if main.isDragging or second.isDragging then return nil end
    local home, other = main, second
    local homeUp, otherUp = mainUp, secondUp
    if B.SystemMoved(second) then home, other, homeUp, otherUp = second, main, secondUp, mainUp end
    if not B.SystemMoved(home) or B.SystemMoved(other) then return nil end
    if otherUp == nil then otherUp = HasVisibleBar(other) end
    if not otherUp then return nil end
    if homeUp == nil then homeUp = HasVisibleBar(home) end
    if not homeUp then return home, other, nil end
    if ShowsExperience(other) and not ShowsExperience(home) then return home, other, home end
    return home, home, other
end

local stacked = setmetatable({}, { __mode = "k" })

-- Whether a frame stands on the band: not moved in edit mode and not in the stack.
function B.OnBand(frame)
    return not stacked[frame] and not B.SystemMoved(frame)
end

local function IsHolder(frame)
    return frame ~= nil and (frame == MainStatusTrackingBarContainer or frame == SecondaryStatusTrackingBarContainer)
end

-- A stacked holder hung on the other is set loose at its screen spot first, or re-laying that other would loop.
local function Unstack()
    for holder in pairs(stacked) do
        local _, at = holder:GetPoint(1)
        if IsHolder(at) then
            local left, bottom = holder:GetLeft(), holder:GetBottom()
            local _, clearPoints, setPoint = BaseSetters(holder)
            clearPoints(holder)
            if left and bottom then setPoint(holder, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom) end
        end
    end
    wipe(stacked)
end

local function LayoutLocked(info)
    if not (info and info.point) then return false end
    local rel = AnchorOf(info)
    return rel ~= UIParent and not IsHolder(rel) and Protected(rel)
end

-- In a fight the stack moves only while nothing it hangs on is locked: a frame anchored to a protected one is locked too.
local function StackLocked(main, second)
    if not InCombatLockdown() then return false end
    if Protected(main) or Protected(second) or (B.art and Protected(B.art)) then return true end
    for i = 1, 2 do
        local holder = i == 1 and main or second
        local system = holder.systemInfo
        if system and B.SystemMoved(holder) and (LayoutLocked(system.anchorInfo) or LayoutLocked(system.anchorInfo2)) then
            return true
        end
    end
    return false
end

-- Unstacked spots first, the band one before the moved one (either may be snapped to the other), then the stack stands
-- on the home spot read off the moved holder.
local function LayoutStack(home, other, low, high)
    PlaceHolder(other, false, false)
    local _, w, h = PlaceHolder(home, false, true)
    local left, bottom = home:GetLeft(), home:GetBottom()
    if not (w and left and bottom) then return false end
    local scale = BandNow()
    for i = 1, 2 do
        local holder = i == 1 and low or high
        if holder then
            local setScale, clearPoints, setPoint = BaseSetters(holder)
            Remember(holder)
            if math.abs((holder:GetScale() or 1) - scale) > 0.001 then setScale(holder, scale) end
            clearPoints(holder)
            -- The low one by screen spot: an anchor to home could loop through home's own snap to the other holder.
            if i == 1 then
                setPoint(holder, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
            else
                setPoint(holder, "BOTTOMLEFT", low, "TOPLEFT", 0, 0)
            end
            holder:SetSize(w, h)
            DressBars(holder, w, h, true, false)
            stacked[holder] = true
        end
    end
    return true
end

local function LayoutStatusBars()
    local main, second = MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer
    local home, low, high = StackPlan(main, second)
    if (home or next(stacked)) and StackLocked(main, second) then
        ns.WhenCalm("statusRelay", RelayStatus)
        return
    end
    Unstack()
    if not (home and LayoutStack(home, home == main and second or main, low, high)) then
        -- With two bars up XP keeps the band strip and the faction stands over it; the client gives its first holder to the faction.
        local swap = HasVisibleBar(main) and HasVisibleBar(second) and ShowsExperience(second) and not ShowsExperience(main)
        -- A holder moved off the band leaves the strip to the other, with nothing over it.
        local mainOn = main and not B.SystemMoved(main)
        local secondOn = second and not B.SystemMoved(second)
        LayoutStatusBar(main, (swap and secondOn) and true or false)
        LayoutStatusBar(second, ((not swap) and mainOn) and true or false)
    end
    -- Holder alpha is left to the client's fades and the watch: set here mid-swap, a quick watch toggle left both at 0.
    -- The thin top bar stands in for a missing strip (moved off or stacked included).
    local anyShown = (main and B.OnBand(main) and main:IsShown()) or (second and B.OnBand(second) and second:IsShown())
    local art = B.art
    for _, tex in ipairs(art.maxLevel) do tex:SetShown(not anyShown and tex.fcuiInBand == true and not art.artHidden) end
end
B.LayoutStatusBars = LayoutStatusBars

-- What is up, which way round and whether stacked, as one number; the second value moves the rows over the band.
local function BarsState(mainUp, secondUp)
    local main, second = MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer
    if mainUp == nil then mainUp = HasVisibleBar(main) end
    if secondUp == nil then secondUp = HasVisibleBar(second) end
    local swap = mainUp and secondUp and ShowsExperience(second) and not ShowsExperience(main)
    local stack = StackPlan(main, second, mainUp, secondUp) ~= nil
    local state = (mainUp and 1 or 0) + (secondUp and 2 or 0) + (swap and 4 or 0) + (stack and 8 or 0)
    return state, stack and 2 or (mainUp and secondUp) and 1 or 0
end

-- Polled: the client swaps bars over stacking fades. A settled state is laid once; a holder at alpha 0, a bar up, no fade: restored.
local FADES = { "FadeInAnimation", "FadeOutAnimation", "MaxLevelFadeOutAnimation" }
local function Playing(container)
    for i = 1, #FADES do
        local group = container[FADES[i]]
        if group and group.IsPlaying and group:IsPlaying() then return true end
    end
    return false
end

-- The manager holds a swap until a holder's animation ends, then swaps with no event; IsAnimating only reads (fail = animating).
local function Animating()
    for _, container in ipairs(StatusPair()) do
        if container.IsAnimating then
            local ok, animating = pcall(container.IsAnimating, container)
            if not ok or ns.IsSecret(animating) or animating then return true end
        end
    end
    return false
end

-- Watching or dropping a faction changes which bars are up and which stands over which: re-laid once the client
-- is done. 20 Hz while awake: the band's lane (BandWatch) runs this when barsWatch.since is due.
local barsWatch = B.barsWatch
function B.BarsTick()
    local watch = barsWatch
    if not (B.active and B.art) then return end
    local busy, restored = false, false
    -- Each holder's HasVisibleBar read once, for BarsState too (slot 1 main, 2 second).
    local mainUp, secondUp
    for i, container in ipairs(StatusPair()) do
        if Playing(container) then
            busy = true
        else
            local up = HasVisibleBar(container)
            if i == 1 then mainUp = up else secondUp = up end
            if up and (container:GetAlpha() or 1) < 1 then
                container:SetAlpha(1)
                restored = true
            end
        end
    end
    -- Only once the client has finished moving, and out of combat.
    if busy or InCombatLockdown() then return end
    local state, two = BarsState(mainUp, secondUp)
    if state ~= watch.state then
        watch.state = state
        pcall(LayoutStatusBars)
        -- The rows over the band rise and fall with the second bar.
        if two ~= watch.two then
            watch.two = two
            ns.QueueApply()
        end
        return
    end
    -- Settled a second after the last wake: asleep until a status event, a band pass, a hot moment or edit mode.
    if restored or EditModeLive() or GetTime() - watch.wokeAt < 1 or Animating() then return end
    B.WakeBars(true)
end
B.BarsState = BarsState

-- Still heading to the last request (a fade, or a state not yet laid): Show as Experience Bar waits on it; a mismatch wakes.
function ns.StatusBarsBusy()
    if not (B.active and B.art) then return false end
    for _, container in ipairs(StatusPair()) do
        if container and Playing(container) then return true end
    end
    if (BarsState()) ~= barsWatch.state then
        B.WakeBars()
        return true
    end
    return false
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

-- The holders go back into the band even in a fight, when the client moves them most (e.g. a target with combo
-- points); one a client bar is snapped to is locked then and waits for the fight's end (PlaceHolder).
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
        local w, h = bar:GetSize()
        width = width + (w or 0)
        height = height + (h or 0)
        local status = bar.StatusBar
        if status then
            w, h = status:GetSize()
            width = width + (w or 0)
            height = height + (h or 0)
        end
    end
    return count, width, height
end

function B.MarkStatus()
    local list = StatusFrames()
    for i = 1, #list do
        local frame = list[i]
        local mark = Record(frame, statusMark[frame])
        mark.count, mark.width, mark.height = BarSums(frame)
        local bar = frame.bars and frame.bars[1]
        mark.bar1 = bar and bar:GetWidth() or 0
        statusMark[frame] = mark
    end
    -- Every band pass ends here: the cast bar re-measures its stand, the status watch looks again.
    B.castWatch.want = nil
    B.WakeBars()
end

-- Per-frame tripwire: the client re-anchors and resizes the holders when a fade ends (UpdateShownState from OnFinished), no event.
function B.hot.StatusTrip()
    local list = statusList
    if not list then return false end
    for i = 1, #list do
        local frame = list[i]
        local mark = statusMark[frame]
        if mark then
            if Drifted(frame, mark) then return true end
            local d = (frame:GetWidth() or 0) - mark.w
            if d > 0.05 or d < -0.05 then return true end
            local bar = frame.bars and frame.bars[1]
            if bar then
                d = (bar:GetWidth() or 0) - mark.bar1
                if d > 0.05 or d < -0.05 then return true end
            end
        end
    end
    return false
end

function B.StatusMoved()
    local list = StatusFrames()
    for i = 1, #list do
        local frame = list[i]
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
    B.WakeBars()
    if not B.active or B.applying then return end
    -- A dragged holder moves every frame; the drop's pass lays it.
    local list = StatusFrames()
    for i = 1, #list do
        if list[i].isDragging then return end
    end
    ns.stripPasses = (ns.stripPasses or 0) + 1
    B.WhileApplying(LayoutStatusBars)
    B.MarkStatus()
end

-- On the band a holder is drawn at band length whatever its Width: that slider is dimmed under a note while it is.
-- Display only: alpha on the client's row and our own veil over it, never its value.
local DIM = 0.3
local dimmed = setmetatable({}, { __mode = "k" })
local veil

local function Undim()
    for frame in pairs(dimmed) do frame:SetAlpha(1) end
    wipe(dimmed)
end

local function Veil()
    if veil then return veil end
    veil = CreateFrame("Frame")
    veil:EnableMouse(true)
    veil:EnableMouseWheel(true)
    veil:SetScript("OnMouseWheel", function() end)
    -- Hung on the slider row it goes with the dialog at once, and stays down so a reused row comes back bare.
    veil:SetScript("OnHide", function(self)
        self:Hide()
        Undim()
    end)
    local note = veil:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    note:SetText("Follows the classic bar")
    veil.note = note
    veil:Hide()
    return veil
end

local function WidthRow(dialog, setting)
    local pools = dialog.pools
    if not (pools and pools.EnumerateActiveByTemplate) then return nil end
    for row in pools:EnumerateActiveByTemplate("EditModeSettingSliderTemplate") do
        if row.setting == setting and row:IsShown() then return row end
    end
    return nil
end

-- On the edit beat (BandWatch) and on restore (editing false).
function B.FollowStatusDialog(editing)
    local dialog = EditModeSystemSettingsDialog
    local holder = editing and B.active and dialog and dialog:IsShown() and dialog.attachedToSystem
    local setting = SizeSetting()
    local row
    if holder and setting ~= nil and (holder == MainStatusTrackingBarContainer or holder == SecondaryStatusTrackingBarContainer)
        and B.OnBand(holder) then
        row = WidthRow(dialog, setting)
    end
    local slider = row and (row.Slider or row)
    for frame in pairs(dimmed) do
        if frame ~= slider then
            frame:SetAlpha(1)
            dimmed[frame] = nil
        end
    end
    if not slider then
        if veil and veil:IsShown() then veil:Hide() end
        return
    end
    local v = Veil()
    if v.row ~= row then
        v.row = row
        v:SetParent(row)
        v:ClearAllPoints()
        v:SetAllPoints(row)
        ns.SetPointOnce(v.note, "CENTER", slider, "CENTER", 0, 0)
    end
    if v:GetFrameStrata() ~= dialog:GetFrameStrata() then v:SetFrameStrata(dialog:GetFrameStrata()) end
    ns.SetLevelIf(v, math.min(row:GetFrameLevel() + 20, 9000))
    -- After the veil moves: its hide un-dims.
    SetAlphaIf(slider, DIM)
    dimmed[slider] = true
    if not v:IsShown() then v:Show() end
end

-- Band off: nothing stacked (loose before the hand-back re-anchors), no dimmed slider; posts walked afresh next time.
function B.StatusRestore()
    Unstack()
    wipe(fadedCount)
    B.FollowStatusDialog(false)
end
