local _, ns = ...
local L = ns.L

-- Swing timers in the 1.x player cast bar's look: its border, the old fill, its finish flash as a swing lands.
-- Blizzard's own frame art is blanked (range dimming resets its alpha); ours hangs on the bar and dims with it.

local FILL_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
-- 1.x bar colours to pick from per hand, in menu order.
ns.SWING_COLORS = {
    { key = "cast", label = L["UI_CAST_GOLD"], rgb = { 1, 0.7, 0 } },
    { key = "darkGold", label = L["UI_DARK_GOLD"], rgb = { 0.85, 0.55, 0 } },
    { key = "focus", label = L["UI_FOCUS_ORANGE"], rgb = { 1, 0.5, 0.25 } },
    { key = "energy", label = L["UI_ENERGY_YELLOW"], rgb = { 1, 1, 0 } },
    { key = "channel", label = L["UNIT_CHANNEL_GREEN"], rgb = { 0, 1, 0 } },
    { key = "mana", label = L["UI_MANA_BLUE"], rgb = { 0, 0, 1 } },
    { key = "failed", label = L["UI_FAILED_RED"], rgb = { 1, 0, 0 } },
}
local COLOR_BY_KEY = {}
for _, color in ipairs(ns.SWING_COLORS) do COLOR_BY_KEY[color.key] = color.rgb end
-- Border thickness steps, a quarter of the 1.x border each; 0 is half, 2 the 1.x border.
ns.SWING_BORDER_MIN, ns.SWING_BORDER_MAX = -1, 5
local BORDER_STEP = 0.25
local LABEL_X = 10
-- The border's opening sits 2.5 rows above the bar's middle.
local OPENING_UP = 2.5
-- The player cast bar's border (256 x 64) round its 195 x 13 bar, 30.5 past each end, scaled with the swing bar's
-- height (edit mode). The rails are one nine; the opening (rows 28-37, columns 34-222) another, its soft shade 4 deep
-- at each edge, so the shade keeps its shape at any thickness (stretched whole it swelled, cut off it left a seam).
local BAR_H, OUT_X = 13, 30.5
local CUT_LEFT, CUT_RIGHT, CUT_TOP, CUT_FOOT, SHADE = 34, 222, 28, 37, 4
local COLS = { 0, CUT_LEFT / 256, CUT_RIGHT / 256, 1 }
local ROWS = { 0, CUT_TOP / 64, CUT_FOOT / 64, 1 }
local SHADE_COLS = { CUT_LEFT / 256, (CUT_LEFT + SHADE) / 256, (CUT_RIGHT - SHADE) / 256, CUT_RIGHT / 256 }
local SHADE_ROWS = { CUT_TOP / 64, (CUT_TOP + SHADE) / 64, (CUT_FOOT - SHADE) / 64, CUT_FOOT / 64 }
local IN_X, IN_H = CUT_LEFT - OUT_X, CUT_FOOT - CUT_TOP
local FLASH_TIME = 0.3
local RESET_DROP = 0.5   -- a fall of this much of the bar is a new swing
local FRAMES = {
    { name = "SwingTimerMainHandFrame", key = "swingColorMain", default = "cast" },
    { name = "SwingTimerOffHandFrame", key = "swingColorOff", default = "darkGold" },
    { name = "SwingTimerRangedFrame", key = "swingColorRanged", default = "channel" },
}

local function Color(entry)
    return COLOR_BY_KEY[ns.db and ns.db[entry.key]] or COLOR_BY_KEY[entry.default]
end

local function Thickness()
    local step = tonumber(ns.db and ns.db.swingBorder) or 0
    return 0.5 + BORDER_STEP * math.max(ns.SWING_BORDER_MIN, math.min(ns.SWING_BORDER_MAX, step))
end

local active = false
local own = setmetatable({}, { __mode = "k" })   -- status bar -> our border and flash

-- Nine pieces of a border sheet cut at cols and rows, row by row from the top left.
local function Slices(bar, key, layer, cols, rows)
    local list = {}
    for row = 1, 3 do
        for col = 1, 3 do
            local tex = bar:CreateTexture(nil, layer, nil, 2)
            ns.SetTex(tex, key)
            tex:SetTexCoord(cols[col], cols[col + 1], rows[row], rows[row + 1])
            list[#list + 1] = tex
        end
    end
    return list
end

-- The opening inset from the bar's ends and depth under its top; ends l wide, top t and foot b tall round it.
local function LaySlices(list, bar, inset, depth, l, t, b)
    local tl, top, tr, left, mid, right, bl, bottom, br = unpack(list)
    for i = 1, #list do list[i]:ClearAllPoints() end
    mid:SetPoint("TOPLEFT", bar, "TOPLEFT", inset, 0)
    mid:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", -inset, -depth)
    tl:SetPoint("BOTTOMRIGHT", mid, "TOPLEFT")
    tl:SetSize(l, t)
    top:SetPoint("BOTTOMLEFT", mid, "TOPLEFT")
    top:SetPoint("BOTTOMRIGHT", mid, "TOPRIGHT")
    top:SetHeight(t)
    tr:SetPoint("BOTTOMLEFT", mid, "TOPRIGHT")
    tr:SetSize(l, t)
    left:SetPoint("TOPRIGHT", mid, "TOPLEFT")
    left:SetPoint("BOTTOMRIGHT", mid, "BOTTOMLEFT")
    left:SetWidth(l)
    right:SetPoint("TOPLEFT", mid, "TOPRIGHT")
    right:SetPoint("BOTTOMLEFT", mid, "BOTTOMRIGHT")
    right:SetWidth(l)
    bl:SetPoint("TOPRIGHT", mid, "BOTTOMLEFT")
    bl:SetSize(l, b)
    bottom:SetPoint("TOPLEFT", mid, "BOTTOMLEFT")
    bottom:SetPoint("TOPRIGHT", mid, "BOTTOMRIGHT")
    bottom:SetHeight(b)
    br:SetPoint("TOPLEFT", mid, "BOTTOMRIGHT")
    br:SetSize(l, b)
end

-- The opening's shade on the rails' middle piece (only an anchor now): corners s square, edges between, centre.
local function LayShade(list, mid, s)
    local tl, top, tr, left, centre, right, bl, bottom, br = unpack(list)
    for i = 1, #list do list[i]:ClearAllPoints() end
    tl:SetPoint("TOPLEFT", mid, "TOPLEFT")
    tr:SetPoint("TOPRIGHT", mid, "TOPRIGHT")
    bl:SetPoint("BOTTOMLEFT", mid, "BOTTOMLEFT")
    br:SetPoint("BOTTOMRIGHT", mid, "BOTTOMRIGHT")
    for _, corner in ipairs({ tl, tr, bl, br }) do corner:SetSize(s, s) end
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT")
    top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT")
    bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT")
    left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT")
    right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    centre:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT")
    centre:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")
end

local function ShowSlices(list, shown)
    for i = 1, #list do list[i]:SetShown(shown) end
end

local function Dress(entry)
    local timer = _G[entry.name]
    local bar = timer and timer.StatusBar
    if not bar then return end
    if timer.Background then timer.Background:SetTexture(nil) end
    if timer.Border then timer.Border:SetTexture(nil) end
    if bar.Pip then bar.Pip:SetAlpha(0) end
    if bar.TypeLabelShadow then bar.TypeLabelShadow:SetAlpha(0) end
    bar:SetStatusBarTexture(FILL_TEXTURE)
    local rgb = Color(entry)
    bar:SetStatusBarColor(rgb[1], rgb[2], rgb[3])
    local parts = own[bar]
    if not parts then
        parts = {}
        parts.border = Slices(bar, "castBorder", "ARTWORK", COLS, ROWS)
        parts.shade = Slices(bar, "castBorder", "ARTWORK", SHADE_COLS, SHADE_ROWS)
        -- The 1.x cast bar's dark backing, the bar's own size.
        parts.back = bar:CreateTexture(nil, "BACKGROUND")
        parts.back:SetColorTexture(0, 0, 0, 0.5)
        parts.back:SetAllPoints(bar)
        parts.flash = Slices(bar, "castFlash", "OVERLAY", COLS, ROWS)
        parts.flashShade = Slices(bar, "castFlash", "OVERLAY", SHADE_COLS, SHADE_ROWS)
        local anim = bar:CreateAnimationGroup()
        local glows = {}
        for _, list in ipairs({ parts.flash, parts.flashShade }) do
            for _, tex in ipairs(list) do glows[#glows + 1] = tex end
        end
        for _, tex in ipairs(glows) do
            tex:SetBlendMode("ADD")
            tex:SetAlpha(0)
            local fade = anim:CreateAnimation("Alpha")
            fade:SetTarget(tex)
            fade:SetFromAlpha(1)
            fade:SetToAlpha(0)
            fade:SetDuration(FLASH_TIME)
        end
        anim:SetToFinalAlpha(true)
        parts.anim = anim
        own[bar] = parts
    end
    local h = bar:GetHeight() or 0
    local k = Thickness()
    -- One scale on every side (the bar's height), so the ends keep their shape and thickness steps match the rails.
    local sy = h / BAR_H
    -- Scaled round the bar's own edges: the rails hug the bar, thinner or thicker.
    local sk = sy * k
    local inset, depth = IN_X * sk, (BAR_H - (BAR_H - IN_H) * k) * sy
    local l, t, b = CUT_LEFT * sk, CUT_TOP * sk, (64 - CUT_FOOT) * sk
    LaySlices(parts.border, bar, inset, depth, l, t, b)
    LaySlices(parts.flash, bar, inset, depth, l, t, b)
    -- The shade as deep as the rails are thick, never more than the opening holds.
    local s = SHADE * math.min(sk, depth / IN_H)
    LayShade(parts.shade, parts.border[5], s)
    LayShade(parts.flashShade, parts.flash[5], s)
    local up = OPENING_UP * sk
    if bar.TypeLabel then ns.SetPointOnce(bar.TypeLabel, "LEFT", bar, "LEFT", LABEL_X, up) end
    if bar.TimeLabel then ns.SetPointOnce(bar.TimeLabel, "RIGHT", bar, "RIGHT", -LABEL_X, up) end
    for _, list in ipairs({ parts.border, parts.shade, parts.flash, parts.flashShade }) do ShowSlices(list, true) end
    parts.border[5]:Hide()
    parts.flash[5]:Hide()
    parts.back:Show()
end

local function Undress(entry)
    local timer = _G[entry.name]
    local bar = timer and timer.StatusBar
    if not bar then return end
    if timer.Background then timer.Background:SetAtlas("ui-swingtimerbar-background") end
    if timer.Border then timer.Border:SetAtlas("ui-swingtimerbar-frame") end
    if bar.Pip then bar.Pip:SetAlpha(1) end
    if bar.TypeLabelShadow then bar.TypeLabelShadow:SetAlpha(1) end
    if bar.TypeLabel then ns.SetPointOnce(bar.TypeLabel, "LEFT", bar, "LEFT", LABEL_X, 0) end
    if bar.TimeLabel then ns.SetPointOnce(bar.TimeLabel, "RIGHT", bar, "RIGHT", -LABEL_X, 0) end
    if timer.barTexture then bar:SetStatusBarTexture(timer.barTexture) end
    bar:SetStatusBarColor(1, 1, 1)
    local parts = own[bar]
    if parts then
        for _, list in ipairs({ parts.border, parts.shade, parts.flash, parts.flashShade }) do ShowSlices(list, false) end
        parts.back:Hide()
    end
end

-- A resized bar (edit mode) fits its border again.
local function Resized(bar)
    if not active then return end
    for _, entry in ipairs(FRAMES) do
        local timer = _G[entry.name]
        if timer and timer.StatusBar == bar then Dress(entry) end
    end
end

-- While a timer shows: the bar falling back is a swing landing, which flashes as a cast finishing.
local lastValue = setmetatable({}, { __mode = "k" })
local function WatchSwing(job)
    local bar = job.bar
    local value = active and bar:GetValue() or nil
    local last = lastValue[bar]
    lastValue[bar] = value
    local parts = own[bar]
    if value and last and parts and last - value >= RESET_DROP then
        parts.anim:Stop()
        parts.anim:Play()
    end
end

local function Apply()
    active = true
    for _, entry in ipairs(FRAMES) do
        local timer = _G[entry.name]
        if timer and timer.StatusBar then
            ns.HookScriptOnce(timer.StatusBar, "OnSizeChanged", Resized)
            local job = ns.Sched.Attach(timer, { name = "swing.flash", every = 0, fn = WatchSwing })
            if job then job.bar = timer.StatusBar end
            ns.SafeCall(Dress, entry)
        end
    end
end

local function Restore()
    if not active then return end
    active = false
    for _, entry in ipairs(FRAMES) do ns.SafeCall(Undress, entry) end
end

-- A colour or thickness picked in the options.
function ns.SetSwingLook(key, value)
    if key then ns.db[key] = value end
    if not active then return end
    for _, entry in ipairs(FRAMES) do ns.SafeCall(Dress, entry) end
end

function ns.SetSwingBorder(step)
    ns.SetSwingLook("swingBorder", step)
end

-- The border thickness under the client's swing timer dialog too; the same setting as the options.
local HANDS = { SwingTimerMainHandFrame = true, SwingTimerOffHandFrame = true, SwingTimerRangedFrame = true }
local function BorderValues()
    local low, high = ns.SWING_BORDER_MIN, ns.SWING_BORDER_MAX
    return tonumber(ns.db and ns.db.swingBorder) or 0, low, high, high - low
end
ns.DialogExtra({
    title = L["MAP_CLASSICUI_FOREVER"],
    match = function(system) return active and HANDS[system:GetName() or ""] == true end,
    build = function(panel) panel.border = ns.DialogExtraSlider(panel, L["OPTWIN_BORDER_THICKNESS"], BorderValues, ns.SetSwingBorder) end,
    fill = function(panel) panel.border() end,
})

ns.RegisterModule("swingTimers", { apply = Apply, restore = Restore })
