local _, ns = ...

-- 12.x plays a cast animation over the icon and lightens the swipe; 1.x had neither.
-- Driven by cast events: hooking the client's play would run us inside its button pass.

-- Client's resting swipe shade (cooldown template); after a cast it goes solid, far darker than 1.x.
local SWIPE_ALPHA = 0.64

local active = false
local driver
-- Buttons whose cast anim was showing: the anim's OnHide darkens the swipe a moment after
-- the events, so these are polled per frame until it hides.
local playing = {}
local stripSlot

local function Strip(button)
    if not button then return end
    local anim = button.SpellCastAnimFrame
    if anim then anim:SetAlpha(active and 0 or 1) end
    local cooldown = active and button.cooldown
    if cooldown and cooldown.SetSwipeColor then cooldown:SetSwipeColor(0, 0, 0, SWIPE_ALPHA) end
end

-- Sole show/hide of the driver: awake only while playing is non-empty (only StripVisit adds).
local function SetWatching(on)
    if not driver then return end
    if on then
        if not driver:IsShown() then driver:Show() end
    elseif driver:IsShown() then
        driver:Hide()
    end
end

local function StripVisit(button)
    Strip(button)
    local anim = button and button.SpellCastAnimFrame
    if active and anim and anim:IsShown() and not playing[button] then
        playing[button] = true
        SetWatching(true)
    end
end

local function StripAll()
    ns.ForEachActionButton(StripVisit)
end

local function StripSlotVisit(button)
    local action = button and button.action
    if action ~= nil and not ns.IsSecret(action) and tonumber(action) == stripSlot then StripVisit(button) end
end

local EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED" }
local SLOT_EVENTS = { "PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED" }

local function OnCastEvent(_, event, slot)
    if not active then return end
    -- A slot change repaints only its buttons, as ActionButton.lua does; slot 0 and the rest walk all.
    if event == "ACTIONBAR_SLOT_CHANGED" and not ns.IsSecret(slot) and type(slot) == "number" and slot > 0 then
        stripSlot = slot
        ns.ForEachActionButton(StripSlotVisit)
    else
        StripAll()
    end
    -- Client sets the swipe on the same event in no fixed order: one walk next frame covers them all.
    ns.Sched.AfterPerFrame("castAnim.strip", 0, StripAll)
end

local function FollowPlaying()
    if not active or next(playing) == nil then
        SetWatching(false)
        return
    end
    for button in pairs(playing) do
        local anim = button.SpellCastAnimFrame
        if not (anim and anim:IsShown()) then
            playing[button] = nil
            Strip(button)
        end
    end
    if next(playing) == nil then SetWatching(false) end
end

local function Apply()
    active = true
    if not driver then
        driver = ns.EventFrame(EVENTS, OnCastEvent, "player")
        ns.Sched.OnFrame(driver, { name = "castAnim.follow", every = 0, fn = FollowPlaying })
        ns.RegisterEvents(driver, SLOT_EVENTS)
    end
    StripAll()
end

local function Restore()
    active = false
    wipe(playing)
    StripAll()
end

ns.RegisterModule("castAnim", { apply = Apply, restore = Restore })
