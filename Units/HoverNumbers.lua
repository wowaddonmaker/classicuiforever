local _, ns = ...

-- Numeric/Percentage status text shows both numbers on hover, like Both: we watch the faded
-- client bar's lockShow and stand in for its text. Values may be secret: format, never compare.

local UF = ns.UF
local IsSecret = ns.IsSecret

local hoverList, hoverCount, hoverShown, hoverOn, hoverDirty = {}, 0, 0, false, false
local hoverByBar = {}
local hoverEvents, ceilCurve, HoverShow
local HOVER_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER",
    "UNIT_DISPLAYPOWER", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "GROUP_ROSTER_UPDATE" }
-- The client re-points its bars on these (powerToken, party slot); refill on the next pass.
local HOVER_DEFER = { UNIT_DISPLAYPOWER = true, PLAYER_TARGET_CHANGED = true,
    PLAYER_FOCUS_CHANGED = true, GROUP_ROSTER_UPDATE = true }

-- The client rounds its percent up; %d floors, so the curve adds 0.999.
local function CeilCurve()
    if ceilCurve == nil then
        ceilCurve = false
        local util = _G.C_CurveUtil
        if util and util.CreateCurve then
            local curve = util.CreateCurve()
            if Enum.LuaCurveType then curve:SetType(Enum.LuaCurveType.Linear) end
            curve:AddPoint(0, 0.999)
            curve:AddPoint(1, 100.999)
            ceilCurve = curve
        end
    end
    return ceilCurve or (_G.CurveConstants and _G.CurveConstants.ScaleTo100)
end

-- Both-mode strings: percent left (health and mana only), value right, in the client's formats.
local function HoverFill(e)
    local cb = e.bar
    local unit = cb.unit or e.unit
    local curve = CeilCurve()
    if not unit or not curve then return false end
    local value, pct, showPct
    if e.power then
        local token = cb.powerToken
        showPct = not IsSecret(token) and (token == nil or token == "MANA")
        value = UnitPower(unit)
        if showPct then pct = _G.UnitPowerPercent(unit, nil, false, curve) end
    else
        showPct = true
        value = UnitHealth(unit)
        pct = _G.UnitHealthPercent(unit, true, curve)
    end
    local short = cb.capNumericDisplay and _G.AbbreviateLargeNumbers or BreakUpLargeNumbers
    e.right:SetText(short(value))
    e.right:Show()
    if showPct then
        e.left:SetFormattedText("%d%%", pct)
        e.left:Show()
    else
        e.left:Hide()
    end
    return true
end

local function CopyFont(fs, src)
    if not src then return end
    local font = src:GetFontObject()
    if font then fs:SetFontObject(font) end
    fs:SetTextColor(src:GetTextColor())
end

local function HoverRefresh(_, event, unit)
    if event and HOVER_DEFER[event] then
        hoverDirty = true
        return
    end
    for i = 1, hoverCount do
        local e = hoverList[i]
        if e.shown and (unit == nil or unit == (e.bar.unit or e.unit)) then
            local ok, done = pcall(HoverFill, e)
            if not (ok and done) then
                e.mode = false
                HoverShow(e, false)
            end
        end
    end
end

HoverShow = function(e, on)
    local ts = e.bar.TextString
    if on then
        CopyFont(e.left, e.bar.LeftText)
        CopyFont(e.right, e.bar.RightText)
        local ok, done = pcall(HoverFill, e)
        if not (ok and done) then
            -- Unfillable this hover: the client's text stays.
            e.mode = false
            e.left:Hide()
            e.right:Hide()
            return
        end
        ts:SetAlpha(0)
        e.shown = true
        hoverShown = hoverShown + 1
        -- Refresh on events, only while something is shown.
        if hoverShown == 1 then
            if not hoverEvents then
                hoverEvents = CreateFrame("Frame")
                hoverEvents:SetScript("OnEvent", HoverRefresh)
            end
            ns.RegisterEvents(hoverEvents, HOVER_EVENTS)
        end
    elseif e.shown then
        e.left:Hide()
        e.right:Hide()
        if ts then ts:SetAlpha(1) end
        e.shown = false
        hoverShown = math.max(0, hoverShown - 1)
        if hoverShown == 0 and hoverEvents then
            hoverEvents:UnregisterAllEvents()
            hoverDirty = false
        end
    end
end

function UF.HoverReset()
    for i = 1, hoverCount do
        local e = hoverList[i]
        e.hovered, e.mode = false, false
        if e.shown then HoverShow(e, false) end
    end
end

-- The client's text stands when it says something else: zero, paused, forced mode, disconnected, pending cast cost.
local function HoverAllowed(e)
    local cb = e.bar
    local ts = cb.TextString
    if not ts or not cb.LeftText or not cb.RightText or not ts:IsShown() then return false end
    if cb.isZero or cb.pauseUpdates or cb.showNumeric or cb.showPercentage or cb.disablePercentages then return false end
    local dc = cb.disconnected
    if IsSecret(dc) then return false end
    if dc then return false end
    if e.power then
        local uf = cb.unitFrame
        local cost = uf and uf.predictedPowerCost
        if cost ~= nil and (IsSecret(cost) or cost ~= 0) then return false end
    end
    return true
end

local function BothWanted()
    local mode = GetCVar("statusTextDisplay")
    return mode == "NUMERIC" or mode == "PERCENT"
end

-- Per frame: on a beat the client's one-number text would flash first.
function UF.HoverPass()
    if hoverCount == 0 then return end
    if not (ns.db == nil or ns.db.hoverBothNumbers ~= false) then
        if hoverOn then
            hoverOn = false
            UF.HoverReset()
        end
        return
    end
    hoverOn = true
    local frames = UF.frames
    for i = 1, hoverCount do
        local e = hoverList[i]
        local cb = e.bar
        local lock = cb.lockShow
        local hovered = lock ~= nil and lock > 0 and (e.owner == nil or frames[e.owner] ~= nil)
        if hovered ~= e.hovered then
            e.hovered = hovered
            e.mode = hovered and BothWanted()
        end
        local want = (e.mode and HoverAllowed(e)) and true or false
        if want ~= e.shown then HoverShow(e, want) end
    end
    if hoverDirty then
        hoverDirty = false
        HoverRefresh()
    end
end

-- Both strings for one client bar, at its left/right text spots.
-- owner: UF.frames key that must still be dressed (nil: pet).
function UF.HoverBoth(clientBar, bar, holder, offsets, owner, unit, power)
    if not clientBar or not holder then return end
    local e = hoverByBar[clientBar]
    if not e then
        e = { bar = clientBar, hovered = false, mode = false, shown = false }
        hoverByBar[clientBar] = e
        hoverCount = hoverCount + 1
        hoverList[hoverCount] = e
    end
    e.owner, e.unit, e.power = owner, unit, power
    local key = power and "hoverPower" or "hoverHealth"
    e.left = ns.OwnFontString(holder, key .. "L", "OVERLAY", "TextStatusBarText")
    e.right = ns.OwnFontString(holder, key .. "R", "OVERLAY", "TextStatusBarText")
    local l, r = offsets[2], offsets[3]
    ns.SetPointOnce(e.left, l[1], bar, l[1], l[2], l[3])
    ns.SetPointOnce(e.right, r[1], bar, r[1], r[2], r[3])
    if not e.shown then
        e.left:Hide()
        e.right:Hide()
    end
end
