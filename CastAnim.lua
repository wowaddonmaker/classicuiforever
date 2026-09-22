local _, ns = ...

-- The 12.x client plays an animation across an action button's icon
-- while its spell is casting, and lightens the cooldown swipe under it
-- so the animation shows through. 1.x had neither: a button did nothing
-- but sit there while the cast bar filled.
--
-- The animation frame is taken to nothing and the swipe put back to
-- the shade the client rests it at. Both are done from the events that
-- start a cast rather than from a hook on the client's own play of it,
-- since a hook there puts our code inside the client's pass over the
-- button.

-- The client's own shade for a swipe, out of its cooldown template. It
-- lightens the swipe to nothing while the animation plays and sets it
-- solid when the animation ends, so a button that had ever cast wore a
-- far darker clock than the old UI ever drew.
local SWIPE_ALPHA = 0.64

local active = false
local driver

local function Strip(button)
    if not button then return end
    local anim = button.SpellCastAnimFrame
    if anim then anim:SetAlpha(active and 0 or 1) end
    local cooldown = active and button.cooldown
    if cooldown and cooldown.SetSwipeColor then cooldown:SetSwipeColor(0, 0, 0, SWIPE_ALPHA) end
end

local function StripAll()
    if ns.ForEachActionButton then ns.ForEachActionButton(Strip) end
end

local EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED" }

local function Apply()
    active = true
    if not driver then
        driver = CreateFrame("Frame")
        driver:SetScript("OnEvent", function()
            if not active then return end
            StripAll()
            -- The client sets the swipe on the same event; ours lands
            -- after it either way.
            C_Timer.After(0, StripAll)
        end)
        for _, event in ipairs(EVENTS) do
            pcall(driver.RegisterUnitEvent, driver, event, "player")
        end
        driver:RegisterEvent("PLAYER_ENTERING_WORLD")
        driver:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    end
    StripAll()
end

local function Restore()
    active = false
    StripAll()
end

ns.RegisterModule("castAnim", { apply = Apply, restore = Restore })
