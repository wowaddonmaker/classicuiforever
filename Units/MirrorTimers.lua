local _, ns = ...

-- 1.x breath/fatigue/feign death bars: old cast border round a plain status bar, label on it, old colours.
-- Dressed a frame after the start event: the client's setup is done and we stay out of its pass.

local BAR_W, BAR_H = 195, 13
local FRAME_W, FRAME_H = 206, 26

-- Blue breath, yellow fatigue, orange death.
local COLORS = {
    BREATH = { 0, 0.5, 1 },
    EXHAUSTION = { 1, 0.9, 0 },
    DEATH = { 1, 0.7, 0 },
    FEIGNDEATH = { 1, 0.7, 0 },
}
local BORDER = { coords = { 0, 1, 0, 1 }, w = 256, h = 64, point = "TOP", y = 25 }
local EVENTS = { "MIRROR_TIMER_START", "MIRROR_TIMER_STOP", "PLAYER_ENTERING_WORLD" }

local active = false
local driver

local function Kind(bar)
    return bar.timer or bar.type or (bar.GetAttribute and bar:GetAttribute("timer")) or "BREATH"
end

local function Dress(bar)
    if not bar or not bar.StatusBar then return end
    bar:SetSize(FRAME_W, FRAME_H)

    -- Dark backdrop under everything, as the old bar had.
    local fill = ns.OwnTexture(bar, "ground", "BACKGROUND", 0)
    fill:SetColorTexture(0, 0, 0, 0.5)
    fill:ClearAllPoints()
    fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 5, -2)
    fill:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -5, 11)
    fill:Show()

    local status = bar.StatusBar
    status:SetSize(BAR_W, BAR_H)
    ns.SetPointOnce(status, "TOP", bar, "TOP", 0, -2)
    ns.SetBarFill(status)
    local color = COLORS[Kind(bar)] or COLORS.BREATH
    status:SetStatusBarColor(color[1], color[2], color[3])

    ns.Dress(bar.Border, "castBorder", BORDER, bar)
    -- 1.x drew the label straight on the bar, no plate.
    if bar.TextBorder then bar.TextBorder:SetAlpha(0) end
    if bar.Text then
        bar.Text:SetFontObject("GameFontHighlight")
        ns.SetPointOnce(bar.Text, "TOP", bar, "TOP", 0, -2)
    end
end

local function DressChild(child)
    if child.StatusBar then ns.SafeCall(Dress, child) end
end

local function DressAll()
    local container = MirrorTimerContainer
    if not active or not container or not container.GetChildren then return end
    ns.EachChild(container, DressChild)
end

local function RestoreChild(child)
    if child.fcui and child.fcui.ground then child.fcui.ground:Hide() end
    if child.TextBorder then child.TextBorder:SetAlpha(1) end
end

local function Apply()
    active = true
    if not driver then
        driver = CreateFrame("Frame")
        ns.RegisterEvents(driver, EVENTS)
        driver:SetScript("OnEvent", function()
            if not active then return end
            -- One pass next frame dresses every timer.
            ns.Sched.NextFrame("mirror.dress", DressAll)
        end)
    end
    DressAll()
end

local function Restore()
    active = false
    local container = MirrorTimerContainer
    if not container or not container.GetChildren then return end
    ns.EachChild(container, RestoreChild)
    ns.needsReload = true
end

ns.RegisterModule("mirrorTimers", { apply = Apply, restore = Restore })
