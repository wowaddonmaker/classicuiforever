local _, ns = ...
local L = ns.L

-- The game's personal resource display as 1.x nameplates: the plates' flat fill (the game still colours it by health
-- and power type) in the plate's border without its level slot. The power bar hangs our gap under health (0: flush,
-- the two borders one shared rail); each border reaches half the gap, so apart they meet without overlapping.

local BACK_ATLAS = "UI-HUD-CoolDownManager-Bar-BG"
local BAR_ATLAS = "UI-HUD-CoolDownManager-Bar"
-- The plate sheet's lower half: 16 rows, a round end 5 past the bar's end.
local PLATE_V0, PLATE_V1, PLATE_H, PLATE_END = 0.5, 1, 16, 5
local CAP_U, RAIL_U1 = 8 / 128, 48 / 128   -- round end with the rail's start; a plain run of rail
local FIT_EVERY = 0.5

local active = false
local own = setmetatable({}, { __mode = "k" })    -- status bar -> { left, mid, right, back }
local fitGap

local function Display() return _G.PersonalResourceDisplayFrame end

local function Bars()
    local prd = Display()
    if not prd then return nil end
    local container = prd.HealthBarsContainer
    return container and container.healthBar, prd.PowerBar, prd.AlternatePowerBar
end

-- Our gap between health and power (option), in place of the client's padding (4 at least).
ns.PRD_GAP_MIN, ns.PRD_GAP_MAX = 0, 20
local function BarGap()
    local gap = tonumber(ns.db and ns.db.prdGap) or 0
    return math.max(ns.PRD_GAP_MIN, math.min(ns.PRD_GAP_MAX, gap))
end

-- The power bar our gap under health; the client re-lays it on its setting changes, so this runs with the watch.
local function HangPower()
    local prd = Display()
    local power, health = prd and prd.PowerBar, prd and prd.HealthBarsContainer
    if not (power and health) or prd.hideHealth then return end
    ns.SetPointOnce(power, "TOP", health, "BOTTOM", 0, -BarGap())
end

local function FindBack(region, parts)
    if region.GetAtlas and region:GetAtlas() == BACK_ATLAS then parts.back = region end
end

-- Left end, rail stretched along, the left end mirrored; as tall as the bar plus half the gap each side, at most the
-- plate's own reach (half the bar).
local function Fit(bar)
    local parts = own[bar]
    if not parts then return end
    local h = bar:GetHeight() or 0
    local reach = math.max(1, math.min(h / 2, BarGap() / 2))
    local s = (h + 2 * reach) / PLATE_H
    local out, cap = PLATE_END * s, CAP_U * 128 * s
    local left, mid, right = parts.left, parts.mid, parts.right
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", bar, "TOPLEFT", -out, reach)
    left:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", cap - out, -reach)
    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", bar, "TOPRIGHT", out, reach)
    right:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", out - cap, -reach)
    mid:ClearAllPoints()
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT")
    mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
end

local function FitAll()
    for bar in pairs(own) do Fit(bar) end
end

-- Gap changes move no bar's size: looked at while the display shows.
local function WatchGap()
    if not active then return end
    HangPower()
    local gap = BarGap()
    if gap ~= fitGap then
        fitGap = gap
        FitAll()
    end
end

local function Piece(bar, u0, u1)
    local tex = bar:CreateTexture(nil, "OVERLAY", nil, 2)
    ns.SetTex(tex, "nameplateBorder")
    tex:SetTexCoord(u0, u1, PLATE_V0, PLATE_V1)
    return tex
end

local function ShowFrame(parts, shown)
    parts.left:SetShown(shown)
    parts.mid:SetShown(shown)
    parts.right:SetShown(shown)
end

local function Resized(bar)
    if active then Fit(bar) end
end

local function Dress(bar)
    if not bar then return end
    local parts = own[bar]
    if not parts then
        parts = {}
        parts.left = Piece(bar, 0, CAP_U)
        parts.mid = Piece(bar, CAP_U, RAIL_U1)
        parts.right = Piece(bar, CAP_U, 0)
        ns.EachRegion(bar, FindBack, parts)
        own[bar] = parts
        ns.HookScriptOnce(bar, "OnSizeChanged", Resized)
    end
    bar:SetStatusBarTexture((ns.TexPath("barFill")))
    -- The client's back reaches well past the bar; the plates have none.
    if parts.back then ns.SetAlphaIf(parts.back, 0) end
    ShowFrame(parts, true)
    Fit(bar)
end

local function Undress(bar)
    local parts = bar and own[bar]
    if not parts then return end
    bar:SetStatusBarTexture(BAR_ATLAS)
    if parts.back then ns.SetAlphaIf(parts.back, 1) end
    ShowFrame(parts, false)
end

local watching = false
local function Apply()
    active = true
    local health, power, alternate = Bars()
    ns.SafeCall(Dress, health)
    ns.SafeCall(Dress, power)
    ns.SafeCall(Dress, alternate)
    ns.SafeCall(HangPower)
    fitGap = BarGap()
    local prd = Display()
    if prd and not watching then
        watching = true
        ns.Sched.Attach(prd, { name = "resourceDisplay.gap", every = FIT_EVERY, fn = WatchGap })
    end
end

local function Restore()
    if not active then return end
    active = false
    local health, power, alternate = Bars()
    ns.SafeCall(Undress, health)
    ns.SafeCall(Undress, power)
    ns.SafeCall(Undress, alternate)
    -- The client's own spot back: its padding under health.
    local prd = Display()
    if prd and prd.PowerBar and prd.HealthBarsContainer and not prd.hideHealth and prd.GetBarPadding then
        ns.SetPointOnce(prd.PowerBar, "TOP", prd.HealthBarsContainer, "BOTTOM", 0, -prd:GetBarPadding())
    end
end

-- The gap picked in the options.
function ns.SetPrdGap(value)
    ns.db.prdGap = math.max(ns.PRD_GAP_MIN, math.min(ns.PRD_GAP_MAX, math.floor(tonumber(value) or 0)))
    if not active then return end
    HangPower()
    fitGap = BarGap()
    FitAll()
end

-- Under the client's dialog: our bar gap, its reset, and the client's own defaults to set back by hand.
local function GapValues()
    return BarGap(), ns.PRD_GAP_MIN, ns.PRD_GAP_MAX, ns.PRD_GAP_MAX - ns.PRD_GAP_MIN
end
ns.DialogExtra({
    title = L["MAP_CLASSICUI_FOREVER"],
    match = function(system) return active and system == Display() end,
    build = function(panel)
        panel.gap = ns.DialogExtraSlider(panel, L["OPTWIN_BAR_GAP"], GapValues, ns.SetPrdGap)
        local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        reset:SetHeight(28)
        reset:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 26, 16)
        reset:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 16)
        reset:SetText(L["UNIT_RESET_TO_DEFAULT_SETTINGS"])
        reset:SetScript("OnClick", function()
            ns.SetPrdGap(0)
            panel.gap()
        end)
        ns.EditModeRed(reset)
        local note = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        note:SetPoint("BOTTOMLEFT", reset, "TOPLEFT", 0, 8)
        note:SetPoint("BOTTOMRIGHT", reset, "TOPRIGHT", 0, 8)
        note:SetJustifyH("LEFT")
        panel.note = note
        panel.extraH = 90
    end,
    fill = function(panel)
        panel.gap()
        local defaults = ns.ClientDefaults(Display())
        panel.note:SetText(defaults and string.format(L["UNIT_GAME_DEFAULTS"], defaults) or "")
    end,
})

ns.RegisterModule("resourceDisplay", { apply = Apply, restore = Restore })
