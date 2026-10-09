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

-- Still exactly where our record put it: a bar the player moved since is theirs.
local function AtRecord(info, spot)
    return type(info) == "table" and type(spot) == "table" and info.relativeTo == "UIParent" and info.point == spot.point
        and info.relativePoint == spot.relativePoint and math.abs((info.offsetX or 0) - (spot.offsetX or 0)) < 0.5
        and math.abs((info.offsetY or 0) - (spot.offsetY or 0)) < 0.5
end

-- A player's layout data: band bars at a pin of ours (its shape, or our record's spot) back to the game's default.
local function HandBackLayout(layout, record)
    local presets = EditModePresetLayoutManager
    local changed = false
    for _, bar in ipairs(ns.band.PIN_NAMES or {}) do
        local frame = _G[bar]
        for _, system in ipairs(frame and frame.system and layout.systems or {}) do
            if system.system == frame.system and system.systemIndex == frame.systemIndex and not system.isInDefaultPosition
                and (OurShape(system.anchorInfo) or AtRecord(system.anchorInfo, record and record[bar])) then
                local ok, home = pcall(presets.GetDefaultSystemAnchorInfo, presets, frame.system, frame.systemIndex)
                if ok and type(home) == "table" then
                    system.anchorInfo, system.anchorInfo2, system.isInDefaultPosition = home, nil, true
                    changed = true
                end
            end
        end
    end
    return changed
end

-- Pins older versions wrote into the player's own layouts, handed back in their data, as a reload or our Turn off
-- starts: with the addon off the game drew its bars at those spots. Never with edit mode open (its unsaved changes
-- would be saved too) or in a fight; never a preset or a layout of ours.
function ns.HandBackPlayerPins()
    if not ns.sessionEnding or InCombatLockdown() or ns.EditMode.Live() then return false end
    local mgr = EditModeManagerFrame
    local layouts = mgr and mgr.layoutInfo and mgr.layoutInfo.layouts
    if not (layouts and EditModePresetLayoutManager and C_EditMode and C_EditMode.SaveLayouts) then return false end
    local changed = false
    for _, layout in ipairs(layouts) do
        local name = layout.layoutName
        if layout.layoutType ~= Enum.EditModeLayoutType.Preset and name ~= ns.LAYOUT_NAME then
            local record = ns.db.barPins and ns.db.barPins[name]
            if HandBackLayout(layout, record) then changed = true end
            if record then ns.db.barPins[name] = nil end
        end
    end
    if changed then C_EditMode.SaveLayouts(mgr.layoutInfo) end
    return changed
end

-- The reload press's band step, between the layout jobs before and after the pins (ns.ReloadForLayout): pins kept up
-- on a layout of ours, handed back as the band is turned off; a player's own layout only loses old pins of ours.
function ns.BandLayoutStep()
    if not ns.sessionEnding then return end
    ns.SafeCall(ns.HandBackPlayerPins)
    if ns.db.classicBar == false then
        if not ns.db.bandHandedBack then ns.SafeCall(ns.UnpinBandBars) end
        return
    end
    -- Leaving for the classic layout: it gets its pins as it is built (Options/Layout.lua ClassicNow).
    local jobs = ns.db.layoutJobs
    if jobs and (jobs.classic or jobs.select) then return end
    if ns.OurLayoutActive() then ns.SafeCall(ns.PinBandBars) end
end
