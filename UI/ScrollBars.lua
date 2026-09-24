local _, ns = ...

-- Old scroll bars: our slider, the old knob and arrows on client thin bars, the column behind.

local FadeKeys, KEYS = ns.FadeKeys, ns.KEYS

local KNOB_H = 24
local KNOB_COORDS = { 0.2, 0.8, 0.125, 0.875 }
local KNOB = { layer = "ARTWORK", w = 18, h = KNOB_H, coords = KNOB_COORDS }
local OWN_KNOB = { own = "knob", layer = "ARTWORK", w = 18, h = KNOB_H, coords = KNOB_COORDS }
-- The arrow sheets are 32x32 with the 16x16 arrow in the middle.
local ARROW_COORDS = { 0.25, 0.75, 0.25, 0.75 }
local ARROW = { coords = ARROW_COORDS, add = true }
-- One pixel right: the old track sits that far over.
local ARROW_OVER = { own = "arrow", layer = "ARTWORK", coords = ARROW_COORDS,
    point = "TOPLEFT", x = 1, point2 = "BOTTOMRIGHT", x2 = 1, show = true }

function ns.ClassicScrollBar(parent, anchorTo, onValue)
    local bar = CreateFrame("Slider", nil, parent)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(16)
    bar:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 6, -16)
    bar:SetPoint("BOTTOMLEFT", anchorTo, "BOTTOMRIGHT", 6, 16)
    bar:SetThumbTexture((ns.DressNew(bar, "scrollKnob", KNOB)))
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)

    local function Arrow(kind, point, relPoint)
        local button = CreateFrame("Button", nil, bar)
        button:SetSize(16, 16)
        button:SetPoint(point, bar, relPoint, 0, 0)
        local key = "scroll" .. kind .. "Button"
        ns.DressStates(button, key .. "Up", key .. "Down", key .. "Disabled", key .. "Highlight", ARROW)
        return button
    end
    bar.up = Arrow("Up", "BOTTOM", "TOP")
    bar.down = Arrow("Down", "TOP", "BOTTOM")
    bar.up:SetScript("OnClick", function() bar:SetValue(bar:GetValue() - bar.step) PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON) end)
    bar.down:SetScript("OnClick", function() bar:SetValue(bar:GetValue() + bar.step) PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON) end)
    bar.step = 1

    function bar:SetRange(max, step)
        self.step = step or 1
        max = math.max(0, max)
        local value = self:GetValue()
        self:SetMinMaxValues(0, max)
        self:SetValue(math.min(value, max))
        -- Nothing to scroll: only the knob goes (arrows grey out), unless hideWhenIdle.
        self:SetShown(not self.hideWhenIdle or max > 0)
        local thumb = self:GetThumbTexture()
        if thumb then thumb:SetShown(max > 0) end
        self:Refresh()
    end
    function bar:Refresh()
        local _, max = self:GetMinMaxValues()
        local value = self:GetValue()
        self.up:SetEnabled(value > 0)
        self.down:SetEnabled(value < max)
    end
    bar:SetScript("OnValueChanged", function(self, value)
        self:Refresh()
        onValue(value)
    end)
    return bar
end

-- The client's thumb stretches with the content, so the knob is placed by scroll fraction.
function ns.ClassicKnob(bar)
    local track = bar.Track
    local thumb = track and track.Thumb
    if not thumb then return end
    FadeKeys(thumb, KEYS.THUMB)
    local knob = ns.DressNew(track, "scrollKnob", OWN_KNOB)
    local function Place()
        -- Nothing to scroll: no knob, as the client hides its thumb (the wheel still moves pct).
        if bar.HasScrollableExtent then
            local ok, can = pcall(bar.HasScrollableExtent, bar)
            if ok and not can then
                knob:Hide()
                return
            end
        end
        local pct = bar.fcuiPct or 0
        -- The client's track stops 3 px short of its arrows; the old knob ran up to them.
        local reach = bar.fcuiKnobReach or 3
        local room = math.max(0, (track:GetHeight() or 0) - KNOB_H)
        -- On the arrows' line: the track may sit off to one side.
        local dx = 0
        local arrow = bar.Back or bar.Forward
        local refX = arrow and arrow.GetCenter and arrow:GetCenter()
        if not refX and bar.GetCenter then refX = bar:GetCenter() end
        local trackX = track.GetCenter and track:GetCenter()
        if refX and trackX then dx = refX - trackX end
        dx = dx + (bar.fcuiArrowOffset or 0)
        knob:ClearAllPoints()
        knob:SetPoint("TOP", track, "TOP", dx, reach - pct * (room + reach * 2))
        knob:Show()
    end
    if not bar.fcuiKnobHooked then
        bar.fcuiKnobHooked = true
        if bar.SetScrollPercentageInternal then
            hooksecurefunc(bar, "SetScrollPercentageInternal", function(self, pct) self.fcuiPct = pct or 0 Place() end)
        end
        if bar.Update then hooksecurefunc(bar, "Update", Place) end
        track:HookScript("OnSizeChanged", Place)
    end
    Place()
end

function ns.SkinMinimalScrollBar(bar)
    if not bar or bar.fcuiSkinned then return end
    bar.fcuiSkinned = true
    local track = bar.Track
    if track then
        FadeKeys(track, KEYS.THUMB)
        if track.Thumb then track.Thumb:SetWidth(16) end
        -- The arrow art is a pixel right of its button; the knob follows.
        bar.fcuiArrowOffset = 1
        ns.ClassicKnob(bar)
    end
    local function Arrow(button, kind)
        if not button then return end
        if button.Texture then button.Texture:SetAlpha(0) end
        button:SetSize(16, 16)
        ns.DressNew(button, "scroll" .. kind .. "ButtonUp", ARROW_OVER)
    end
    Arrow(bar.Back, "Up")
    Arrow(bar.Forward, "Down")
end

-- Scroll column: a head up to 256 tall, a 108 foot, the head's plain run stretched between.
local TRACK_FOOT = 108

local function ColumnPiece(tex)
    ns.SetTex(tex, "charScrollBar")
    tex:SetWidth(31)
    tex:ClearAllPoints()
end

local function ColumnPieces(top, middle, foot)
    ColumnPiece(top)
    ColumnPiece(middle)
    ColumnPiece(foot)
end

local function JoinColumn(top, middle, foot)
    foot:SetHeight(TRACK_FOOT)
    foot:SetTexCoord(0.515625, 1, 0, TRACK_FOOT / 256)
    middle:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    middle:SetPoint("BOTTOMLEFT", foot, "TOPLEFT", 0, 0)
    middle:SetTexCoord(0, 0.484375, 0.3, 0.7)
end

-- Too short for foot plus socket: no column rather than overlapping pieces.
local function FitColumn(top, middle, foot, total)
    if total < TRACK_FOOT + 24 then
        top:Hide() middle:Hide() foot:Hide()
        return
    end
    local head = math.min(256, total - TRACK_FOOT)
    top:SetHeight(head)
    top:SetTexCoord(0, 0.484375, 0, head / 256)
    top:Show()
    foot:Show()
    middle:SetShown(total - TRACK_FOOT - head > 0.5)
end

-- Moves a client arrow by dy, once.
local function Nudge(button, flag, dy)
    if not button or button[flag] then return end
    local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
    if point then
        button[flag] = true
        button:ClearAllPoints()
        button:SetPoint(point, relativeTo, relativePoint, x or 0, (y or 0) + dy)
    end
end

function ns.ScrollTrackArt(bar)
    if not bar or bar.fcuiTrackArt or not bar.GetHeight then return end
    bar.fcuiTrackArt = true
    -- A bar with its own track (the sheet's lists) keeps it.
    if bar.fcui and bar.fcui.trackTop then return end
    local top = ns.OwnTexture(bar, "trackTop", "BACKGROUND", 0)
    local middle = ns.OwnTexture(bar, "trackMiddle", "BACKGROUND", 0)
    local foot = ns.OwnTexture(bar, "trackBottom", "BACKGROUND", 1)
    ColumnPieces(top, middle, foot)
    -- Head and up arrow 2 higher, foot and down arrow 2 lower: spans the text area to the button row.
    top:SetPoint("TOPLEFT", bar, "TOPLEFT", -10.5, 7)
    Nudge(bar.Back, "fcuiRaised", 2)
    foot:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -10.5, -6)
    Nudge(bar.Forward, "fcuiLowered", -2)
    JoinColumn(top, middle, foot)
    local function Fit()
        FitColumn(top, middle, foot, (bar:GetHeight() or 0) + 13)
    end
    -- Sized via our own frame: the client resets the bar's size script, dropping any hook on it.
    local ear = CreateFrame("Frame", nil, bar)
    ear:SetAllPoints(bar)
    ear:SetScript("OnSizeChanged", Fit)
    ear:SetScript("OnShow", Fit)
    Fit()
    -- Arrows moved 2 out at each end, so the knob reaches further.
    bar.fcuiKnobReach = 7
    if bar.Track then ns.ClassicKnob(bar) end
end

-- Same column behind our own bar, whose arrows sit outside it; shown and hidden with the bar.
function ns.ScrollColumnOn(bar)
    if not bar or bar.fcuiColumn or not bar.up or not bar.down then return end
    bar.fcuiColumn = true
    local top = bar:CreateTexture(nil, "BACKGROUND", nil, 0)
    local middle = bar:CreateTexture(nil, "BACKGROUND", nil, 0)
    local foot = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    ColumnPieces(top, middle, foot)
    top:SetPoint("TOPLEFT", bar.up, "TOPLEFT", -7.5, 5)
    foot:SetPoint("BOTTOMLEFT", bar.down, "BOTTOMLEFT", -7.5, -4)
    JoinColumn(top, middle, foot)
    local function Fit()
        FitColumn(top, middle, foot, (bar:GetHeight() or 0) + 32 + 9)
    end
    bar:HookScript("OnSizeChanged", Fit)
    Fit()
end

-- Thin scroll bars a few levels under a window; a forbidden frame (the bank has one) is never queried.
local function SkinUnder(child, depth)
    ns.SkinScrollBarsUnder(child, depth)
end
function ns.SkinScrollBarsUnder(frame, depth)
    if not frame or (depth or 0) <= 0 or type(frame) ~= "table" or not frame.GetChildren then return end
    if frame.IsForbidden and frame:IsForbidden() then return end
    local bar = rawget(frame, "ScrollBar")
    if type(bar) == "table" and not (bar.IsForbidden and bar:IsForbidden()) and bar.Track and bar.Back and bar.Forward then
        ns.SkinMinimalScrollBar(bar)
        ns.ScrollTrackArt(bar)
    end
    ns.EachChildProtected(frame, SkinUnder, depth - 1)
end

-- Bars that move inside the client's own passes: no client hook, the knob follows a watch that runs while the bar shows.
-- column: the track column behind it too.
function ns.QuietScrollBar(bar, name, column)
    if not bar or bar.fcuiSkinned or not (bar.Track and bar.Back and bar.Forward) then return end
    if not (bar.GetScrollPercentage and bar.GetVisibleExtentPercentage) then return end
    bar.fcuiKnobHooked = true
    ns.SkinMinimalScrollBar(bar)
    if column then ns.ScrollTrackArt(bar) end
    local track = bar.Track
    local pct, ext, height
    ns.Sched.OnFrame(CreateFrame("Frame", nil, bar), { name = name, every = 0, fn = function()
        local p, e, h = bar:GetScrollPercentage(), bar:GetVisibleExtentPercentage(), track:GetHeight()
        if p == pct and e == ext and h == height then return end
        pct, ext, height = p, e, h
        bar.fcuiPct = p
        ns.ClassicKnob(bar)
    end })
end
