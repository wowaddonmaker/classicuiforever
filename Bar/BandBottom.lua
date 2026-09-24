local _, ns = ...
local B = ns.band

-- The client's bottom stack over the band: its container is put back on our spot (KeepBottomContainer).
-- Loot rolls are the client's own, untouched.

-- Client passes that re-stand the container from these events' handlers; ours hears them after, before the frame is drawn.
local RESTAND_EVENTS = { "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_USABLE", "UPDATE_POSSESS_BAR", "ACTIONBAR_PAGE_CHANGED",
    "UPDATE_EXTRA_ACTIONBAR", "PET_BAR_UPDATE_USABLE", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
    "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_FARSIGHT_FOCUS_CHANGED", "UPDATE_INVENTORY_ALERTS", "UNIT_TARGETABLE_CHANGED",
    "INSTANCE_ENCOUNTER_ENGAGE_UNIT" }

local restand = CreateFrame("Frame")
ns.RegisterEvents(restand, RESTAND_EVENTS)
restand:SetScript("OnEvent", function()
    if B.active and B.KeepContainer then B.KeepContainer() end
end)
