local _, ns = ...
local B = ns.band

-- Default-placed cast bar: the client stacks it for its flat bar, which lands it among the band's
-- rows once bars 2/3 move; only its anchor is set, over the band. Placed or dragged, it is the player's.

local CAST_STAND = B.CAST_STAND
local CAST_GAP = 26
local InDefaultPosition = ns.InDefaultPosition

-- want = last computed stand; ticks every frame in the band lane (BandWatch).
local castWatch = { since = 0 }
B.castWatch = castWatch
local castBar

function castWatch.Stand(bar, want)
    local bottom = bar:GetBottom()
    if bottom and math.abs(bottom - want) > 1 then
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, want)
    end
end

function B.CastTick(elapsed, isHot)
    local watch = castWatch
    local bar = castBar
    if not bar then
        bar = _G["PlayerCastingBarFrame"]
        castBar = bar
    end
    local art = B.art
    if not (B.active and art and bar and bar:IsShown()) then
        watch.want = nil
        return
    end
    -- Edit mode too (the client restacks it as pieces move); never while dragged.
    if bar.isDragging then return end
    -- Recomputed on show and on the beat (bars may be moving); held in between.
    watch.since = watch.since + elapsed
    if watch.want and watch.since < B.hot.BEAT and not isHot then
        castWatch.Stand(bar, watch.want)
        return
    end
    watch.since = 0
    watch.want = nil
    if InDefaultPosition(bar) == false then return end
    local screen = UIParent:GetEffectiveScale()
    local centre = UIParent:GetWidth() / 2
    local top = 0
    -- Floor: the highest of the band and its bars under the screen centre.
    for i = 0, #CAST_STAND do
        local frame
        if i == 0 then frame = art else frame = _G[CAST_STAND[i]] end
        if not frame then break end
        -- Only bars on the band: a placed or dragged one is no floor (the cast bar followed a dragged bar 2).
        local onBand = frame == art or (not frame.isDragging and B.OnBand(frame))
        if onBand and frame:IsShown() and (frame:GetAlpha() or 1) > 0 and frame:GetTop() and frame:GetLeft() then
            -- Read from its buttons, which hang on the band: the client may carry the bar frame off in combat.
            local from, to = frame, frame
            local buttons = frame.actionButtons
            if buttons and buttons[1] and buttons[1]:GetLeft() then
                from, to = buttons[1], buttons[1]
                for j = #buttons, 2, -1 do
                    if buttons[j]:IsShown() and buttons[j]:GetRight() then to = buttons[j] break end
                end
            end
            local k = from:GetEffectiveScale() / screen
            local left, right = math.min(from:GetLeft(), to:GetLeft()) * k, math.max(from:GetRight(), to:GetRight()) * k
            local up = math.max(from:GetTop(), to:GetTop()) * k
            -- Only what reaches up from the band, not a bar dragged mid-screen.
            if left < centre + 110 and right > centre - 110 and up < 260 and up > top then top = up end
        end
    end
    if top <= 0 then return end
    local mine = bar:GetEffectiveScale() / screen
    local want = (top + CAST_GAP) / mine
    watch.want = want
    castWatch.Stand(bar, want)
end
