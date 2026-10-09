local _, ns = ...

-- Band pins live only in the classic layout of ours: a player's own is never written, as an addon turned off cannot
-- take pins back (the game drew its bars at our spots, overlapping).

-- The classic layout is up: the only layout the band pins.
function ns.OurLayoutActive()
    return ns.ActiveLayoutInfo() ~= nil and ns.ClassicLayoutActive()
end

-- No edit mode drop, snap or nudge makes these: a band pin's anchor.
local function OurShape(info)
    if type(info) ~= "table" or info.relativeTo ~= "UIParent" then return false end
    return (info.point == "BOTTOMLEFT" and info.relativePoint == "BOTTOM")
        or (info.point == "TOPRIGHT" and info.relativePoint == "BOTTOMRIGHT")
end

-- Pins into layout data: each band bar the layout holds at default (any, fresh) or at a pin of ours.
function ns.PinLayoutData(layout, pins, name, fresh)
    local pinned = ns.db.barPins and ns.db.barPins[name] or {}
    local record = {}
    for _, system in ipairs(layout.systems or {}) do
        for _, pin in ipairs(pins) do
            if system.system == pin.system and system.systemIndex == pin.systemIndex
                and (fresh or system.isInDefaultPosition or pinned[pin.name] or OurShape(system.anchorInfo)) then
                local spot = pin.anchorInfo
                system.anchorInfo = { point = spot.point, relativeTo = spot.relativeTo, relativePoint = spot.relativePoint,
                    offsetX = spot.offsetX, offsetY = spot.offsetY }
                system.anchorInfo2 = nil
                system.isInDefaultPosition = false
                record[pin.name] = { point = spot.point, relativePoint = spot.relativePoint, offsetX = spot.offsetX,
                    offsetY = spot.offsetY }
            end
        end
    end
    if next(record) then
        local saved = ns.DbTable("barPins")
        saved[name] = saved[name] or {}
        for bar, spot in pairs(record) do saved[name][bar] = spot end
    end
end

-- The reload press's band step, between the layout jobs before and after the pins (ns.ReloadForLayout): pins kept up
-- on a layout of ours, handed back as the band is turned off; a player's layout is left as it is.
function ns.BandLayoutStep()
    if not ns.sessionEnding then return end
    if ns.db.classicBar == false then
        if not ns.db.bandHandedBack then ns.SafeCall(ns.UnpinBandBars) end
        return
    end
    -- Leaving for the classic layout: it gets its pins as it is built (Options/Layout.lua ClassicNow).
    local jobs = ns.db.layoutJobs
    if jobs and (jobs.classic or jobs.select) then return end
    if ns.OurLayoutActive() then ns.SafeCall(ns.PinBandBars) end
end
