local _, ns = ...

-- The addon's edit mode layout: create, reset, select, hand back.
-- An addon layout write taints every edit mode system for the session (refused in combat), so writes
-- queue as jobs for the reload press (ns.sessionEnding); not at logout, edit mode is shut by then.

local TITLE = ns.options.TITLE
-- Saved as the client's layout name and the barPins key: never rename.
local LAYOUT_NAME = "ClassicUI Forever"

local function RefuseInCombat(msg)
    if not InCombatLockdown() then return false end
    ns.Print(msg)
    return true
end

-- The layout being left, for HandBack when the addon is turned off.
local function RememberLayout()
    local info = ns.ActiveLayoutInfo()
    if info and info.layoutName and info.layoutName ~= LAYOUT_NAME then
        ns.db.previousLayout = info.layoutName
    end
end

-- Kept until the next reload press; "Later" writes nothing.
function ns.QueueLayoutJob(key, value)
    if not ns.db then return end
    ns.DbTable("layoutJobs")
    ns.db.layoutJobs[key] = value
end

ns.ReloadPopup("FCUI_LAYOUT_PENDING", TITLE .. "\n\n%s\n\nIt is done as the interface reloads.")

-- Our Default Size buttons: the size is written as the interface reloads; written mid-game, edit mode's pieces
-- (damage meter, action bars) were refused secret values in fights for the session.
ns.Popup("FCUI_SIZE_RESET", {
    text = TITLE .. "\n\nPut the %s back to the default size? The interface reloads to do it.",
    button1 = "Reload now",
    button2 = CANCEL,
    OnAccept = function(_, job)
        ns.QueueLayoutJob(job, true)
        ns.ReloadForLayout()
    end,
})

-- job: the layout job key (bagsSize, eyeSize); what: the piece, as the popup names it.
function ns.AskSizeReset(job, what)
    if RefuseInCombat("not during a fight") then return end
    if StaticPopup_Show then StaticPopup_Show("FCUI_SIZE_RESET", what, nil, job) end
end

-- Every addon reload: pre-pin jobs, band pins (unpins with the band off), post-pin jobs,
-- all in the press, in that order. In combat only the reload runs; jobs wait.
function ns.ReloadForLayout()
    if not (C_UI and C_UI.Reload) then return end
    if ns.db and not InCombatLockdown() then
        ns.sessionEnding = true
        pcall(ns.RunLayoutJobsBeforePin)
        if ns.db.classicBar ~= false then
            pcall(ns.PinBandBars)
        elseif not ns.db.bandHandedBack then
            pcall(ns.UnpinBandBars)
        end
        pcall(ns.RunLayoutJobsAfterPin)
    end
    C_UI.Reload()
end

function ns.AskLayoutReload(what)
    if StaticPopup_Show then StaticPopup_Show("FCUI_LAYOUT_PENDING", what) end
end

local function LayoutIndexByName(name, anyType)
    local mgr = EditModeManagerFrame
    if not name or not mgr or not mgr.GetLayouts then return nil end
    for index, layout in ipairs(mgr:GetLayouts()) do
        if layout.layoutName == name and (anyType or layout.layoutType ~= Enum.EditModeLayoutType.Preset) then
            return index, layout
        end
    end
end

-- At the game's bar size 12 slots plus gryphons do not fit: 10 on bars 1-2, 8 on the
-- side bars, 12 again at classic size. Bar 3 keeps 12; hidden slots keep their spells.
local FIT_COUNTS = {
    { "MainActionBar", 10 }, { "MultiBarBottomLeft", 10 },
    { "MultiBarRight", 8 }, { "MultiBarLeft", 8 },
}
local function FitWanted(big)
    local setting = Enum and Enum.EditModeActionBarSetting and Enum.EditModeActionBarSetting.NumIcons
    local wanted = {}
    if setting == nil then return wanted, setting end
    for _, entry in ipairs(FIT_COUNTS) do
        local bar = _G[entry[1]]
        if bar and bar.system and bar.GetSettingValue then
            local want = big and entry[2] or 12
            local ok, now = pcall(bar.GetSettingValue, bar, setting)
            if ok and now ~= want then wanted[#wanted + 1] = { bar, want } end
        end
    end
    return wanted, setting
end

-- Session end only: writes the counts, then re-lays the band so the pins match.
local function FitNow(big)
    if not ns.sessionEnding or not ns.ClassicLayoutActive() then return false end
    local mgr = EditModeManagerFrame
    if not mgr or not mgr.OnSystemSettingChange or not mgr.SaveLayouts then return false end
    local wanted, setting = FitWanted(big)
    local changed = false
    for _, entry in ipairs(wanted) do
        if pcall(mgr.OnSystemSettingChange, mgr, entry[1], setting, entry[2]) then changed = true end
    end
    if changed then
        pcall(mgr.SaveLayouts, mgr)
        ns.ApplyAll()
    end
    return changed
end

-- The game-sized bar became the default: an install from before keeps its 1.x size, written as its choice into the
-- account and every profile (profiles keep only what differs from the defaults), and is offered the new size once.
function ns.KeepBarSize(big)
    local db = ns.db
    if not big then db.defaultBarSize = false end
    for _, shot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
        if type(shot) == "table" and shot.defaultBarSize == nil then shot.defaultBarSize = false end
    end
    db.barSizeOffer = not big or nil
    db.dbVersion = 2
end

ns.Popup("FCUI_BAR_SIZE_OFFER", {
    text = TITLE .. "\n\nThe classic bar now comes at the game's own size (45 px buttons) for new installs. Yours keeps the 1.x size (36 px).\n\nSwitch to the game's size? Bars 1 and 2 go to ten slots and the side bars to eight so it fits, done as the interface reloads. The Game-sized bar option changes it any time.",
    button1 = "Game size",
    button2 = "Keep mine",
    OnAccept = function()
        ns.db.defaultBarSize = true
        ns.TogglesChanged({ "defaultBarSize" })
    end,
})

-- Once, at the first world entry after the upgrade.
function ns.OfferBarSize()
    if not ns.db or not ns.db.barSizeOffer then return end
    ns.db.barSizeOffer = nil
    if StaticPopup_Show then StaticPopup_Show("FCUI_BAR_SIZE_OFFER") end
end

function ns.FitBarsToSize(big)
    if not ns.ClassicLayoutActive() then return false end
    if #FitWanted(big) == 0 then
        if ns.db and ns.db.layoutJobs then ns.db.layoutJobs.fit = nil end
        return false
    end
    ns.QueueLayoutJob("fit", big and "big" or "normal")
    ns.AskLayoutReload(big and "The bars go to ten and eight icons to fit the larger classic bar." or "The bars go back to twelve icons.")
    return true
end

-- Our logout still runs on the reload that turns us off, already unticked: HandBack then
-- restores the previous layout and every changed cvar. The classic layout is kept.
function ns.BeingTurnedOff()
    local state = C_AddOns and C_AddOns.GetAddOnEnableState
    if not state then return false end
    local ok, value = pcall(state, "ClassicUIForever", UnitName("player"))
    return ok and value == 0
end

function ns.HandBack()
    if not ns.db then return end
    -- Stops ns.SetCVar recording cvarWas during the hand back.
    ns.handingBack = true
    local mgr = EditModeManagerFrame
    if ns.ClassicLayoutActive() and mgr and mgr.GetLayouts and C_EditMode and C_EditMode.SetActiveLayout then
        local wanted = ns.db.previousLayout
        -- "" is the default (none recorded).
        if wanted == "" then wanted = nil end
        -- None recorded: index 1, the client's modern preset.
        local index = LayoutIndexByName(wanted, true) or 1
        if pcall(C_EditMode.SetActiveLayout, index) then ns.db.layoutSelectPending = true end
    end
    for name, value in pairs(ns.db.cvarWas or {}) do ns.WriteCVar(name, value) end
    ns.db.cvarWas = nil
end

-- Button path: untick for this character and reload.
function ns.TurnOffCleanly()
    if RefuseInCombat("not during a fight") then return end
    local disable = C_AddOns and C_AddOns.DisableAddOn
    if not disable then return end
    pcall(disable, "ClassicUIForever", UnitName("player"))
    -- In the press: at logout the client no longer takes a layout change.
    pcall(ns.HandBack)
    if C_UI and C_UI.Reload then C_UI.Reload() end
end

ns.Popup("FCUI_TURN_OFF", {
    text = TITLE .. "\n\nTurn the addon off for this character? Your earlier edit mode layout is made active again and the game settings the addon changed go back to what they were, so the default interface comes back as you left it. The interface reloads. You can turn the addon back on from the AddOns list at any time.",
    button1 = "Turn off",
    button2 = CANCEL or "Cancel",
    OnAccept = function() ns.TurnOffCleanly() end,
})

-- The tracker's Height (slider 400-1000 in 10s, raw = steps above 400) fitted between its default top, 275 down, and
-- the bars along the bottom: the preset's 800 overflowed and edit mode pushed it up to the screen's top.
local TRACKER_TOP, TRACKER_FOOT, TRACKER_MIN, TRACKER_MAX, TRACKER_STEP = 275, 160, 400, 800, 10
function ns.ClassicTrackerHeightRaw()
    local room = (UIParent:GetHeight() or 768) - TRACKER_TOP - TRACKER_FOOT
    local height = math.max(TRACKER_MIN, math.min(TRACKER_MAX, math.floor(room / TRACKER_STEP) * TRACKER_STEP))
    return (height - TRACKER_MIN) / TRACKER_STEP
end

-- Its right edge clear of the side bars at the screen's right, as the bags open beside them; the default 110 in at least.
local TRACKER_X, TRACKER_GAP = -110, 10
local function PlaceTracker(system)
    local info = system.anchorInfo
    if type(info) ~= "table" or info.point ~= "TOPRIGHT" then return end
    local side = ns.band and ns.band.SideColumnsWidth and ns.band.SideColumnsWidth() or 0
    local x = math.min(TRACKER_X, -(side + TRACKER_GAP))
    if info.offsetX ~= x then
        info.offsetX = x
        system.isInDefaultPosition = false
    end
end

local function FitTracker(system)
    local height = Enum.EditModeObjectiveTrackerSetting and Enum.EditModeObjectiveTrackerSetting.Height
    if height == nil or type(system.settings) ~= "table" then return end
    for key, entry in pairs(system.settings) do
        if type(entry) == "table" and entry.setting == height then
            entry.value = ns.ClassicTrackerHeightRaw()
        elseif key == height and type(entry) ~= "table" then
            system.settings[key] = ns.ClassicTrackerHeightRaw()
        end
    end
end

-- Resets the addon layout: bars, micro menu and bags on the centered band, unit frames
-- at their 1.x spots. Never touches the player's other layouts.
local function ResetNow()
    if not ns.sessionEnding or InCombatLockdown() then return false end
    if not ns.ClassicLayoutActive() then return false end
    ns.db.microPos, ns.db.microScale = nil, nil
    ns.db.hideMicroArt, ns.db.hideBagsArt = false, false
    -- The band's own pieces back on it at their defaults: latency bar, key ring, the reagent bag in its full slot.
    ns.db.hideLatencyBar, ns.db.hideKeyRing = false, false
    ns.db.latencyPos, ns.db.keyRingPos = nil, nil
    ns.db.reagentBagSlot, ns.db.reagentBagRound, ns.db.reagentBagHover = true, false, false
    -- Gryphons back on the band (the pin step then resets their edit mode spots).
    ns.db.capMoved, ns.db.capHeldLeft, ns.db.capHeldRight = nil, false, false
    -- Windows placed or sized in the windows edit mode (the map included) back to their own; Movable anytime is kept.
    ns.db.windowPos, ns.db.windowScale = nil, nil
    ns.db.barDragged, ns.db.barOffsetX, ns.db.barOffsetY = false, nil, nil
    local names = { "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
        "MultiBarLeft", "StanceBar", "PetActionBar", "PossessActionBar", "MainStatusTrackingBarContainer",
        "SecondaryStatusTrackingBarContainer", "BagsBar", "MicroMenuContainer", "ObjectiveTrackerFrame" }
    for _, name in ipairs(names) do
        local frame = _G[name]
        if frame and frame.system and type(frame.IsInDefaultPosition) == "function" and type(frame.ResetToDefaultPosition) == "function" then
            local ok, isDefault = pcall(frame.IsInDefaultPosition, frame)
            if ok and not isDefault then pcall(frame.ResetToDefaultPosition, frame) end
        end
    end
    if ns.db.barPins then ns.db.barPins[LAYOUT_NAME] = nil end
    local active = ns.ActiveLayoutInfo()
    for _, system in ipairs(active and active.systems or {}) do
        if system.system == Enum.EditModeSystem.ObjectiveTracker then PlaceTracker(system) end
    end
    -- Settings too (Hide Bar Art and the rest), counts by the bar size option.
    ns.ResetLayoutSettingsNow()
    FitNow(ns.db.defaultBarSize == true)
    -- ReloadForLayout's pin step writes the pins after this.
    ns.ApplyAll()
    ns.ApplyClassicFrameSpots()
    local mgr = EditModeManagerFrame
    if mgr and mgr.SaveLayouts then pcall(mgr.SaveLayouts, mgr) end
    return true
end

function ns.ResetClassicLayout(reloadNow)
    if RefuseInCombat("cannot change layouts in combat") then return false end
    if not ns.ClassicLayoutActive() then return false end
    ns.QueueLayoutJob("reset", true)
    if reloadNow then
        ns.ReloadForLayout()
        return true
    end
    ns.AskLayoutReload("The " .. LAYOUT_NAME .. " layout goes back to its defaults.")
    return true
end

-- Layout button pressed while already on the classic layout.
ns.Popup("FCUI_LAYOUT_RESET", {
    text = TITLE .. "\n\nYou are on the " .. LAYOUT_NAME .. " layout already. Reset it to its defaults? Every bar, the micro menu, the bags, the key ring, latency bar and reagent bag slot, the player, target and focus frames and the windows (map included) go back to their classic places and settings, bar art shown. Your other layouts are not touched. The interface reloads to do it.",
    button1 = "Reset and reload",
    button2 = CANCEL or "Cancel",
    OnAccept = function() ns.ResetClassicLayout(true) end,
})

-- Icon counts carry over from the layout being left; only the bar size toggle changes
-- them. The band follows bar 1's count.
local COUNT_BARS = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
    "MultiBar5", "MultiBar6", "MultiBar7" }

local function ReadIconCounts()
    local counts = {}
    local setting = Enum and Enum.EditModeActionBarSetting and Enum.EditModeActionBarSetting.NumIcons
    if setting == nil then return counts end
    for _, name in ipairs(COUNT_BARS) do
        local bar = _G[name]
        if bar and bar.systemIndex and bar.GetSettingValue then
            local ok, value = pcall(bar.GetSettingValue, bar, setting)
            if ok and type(value) == "number" and value >= 1 and value <= 12 then counts[bar.systemIndex] = value end
        end
    end
    -- At the game's bar size the fitted counts stand.
    if ns.db and ns.db.defaultBarSize == true then
        for _, entry in ipairs(FIT_COUNTS) do
            local bar = _G[entry[1]]
            if bar and bar.systemIndex then counts[bar.systemIndex] = entry[2] end
        end
    end
    return counts
end

-- Writes the classic setup into layout data: unit frame spots, icon counts, band pins.
-- A fresh layout also lifts chat and pins every bar; an existing one pins only bars
-- still at default or pinned by us before.
local function DressLayoutData(layout, counts, pins, fresh)
    local CHAT_X, CHAT_Y = 35, 145
    local pinned = ns.db.barPins and ns.db.barPins[LAYOUT_NAME] or {}
    local record = {}
    for _, system in ipairs(layout.systems or {}) do
        if fresh and system.system == Enum.EditModeSystem.ObjectiveTracker then
            FitTracker(system)
            PlaceTracker(system)
        end
        -- Chat above the bars and pet row as in 1.x; the preset's 50px overlaps bars 2 and 3.
        if fresh and system.system == Enum.EditModeSystem.ChatFrame and type(system.anchorInfo) == "table" then
            local info = system.anchorInfo
            if info.point == "BOTTOMLEFT" and (info.offsetY or 0) < CHAT_Y then
                info.relativeTo = "UIParent"
                info.relativePoint = "BOTTOMLEFT"
                info.offsetX = CHAT_X
                info.offsetY = CHAT_Y
                system.isInDefaultPosition = false
            end
        end
        -- Player top left, target beside it; Forever's presets put both in the bottom corners.
        if system.system == Enum.EditModeSystem.UnitFrame and type(system.anchorInfo) == "table" and Enum.EditModeUnitFrameSystemIndices then
            local spots = {
                [Enum.EditModeUnitFrameSystemIndices.Player] = { 4, -4 },
                [Enum.EditModeUnitFrameSystemIndices.Target] = { 250, -2 },
                [Enum.EditModeUnitFrameSystemIndices.Focus] = { 250, -165 },
            }
            local spot = spots[system.systemIndex]
            if spot then
                local info = system.anchorInfo
                info.point, info.relativeTo, info.relativePoint = "TOPLEFT", "UIParent", "TOPLEFT"
                info.offsetX, info.offsetY = spot[1], spot[2]
                system.isInDefaultPosition = false
            end
        end
        if system.system == Enum.EditModeSystem.ActionBar and type(system.settings) == "table" then
            local count = counts[system.systemIndex] or (fresh and 12) or nil
            -- A new layout shows the bar art (band and gryphons) whatever the preset had.
            local artKey = fresh and Enum.EditModeActionBarSystemIndices
                and system.systemIndex == Enum.EditModeActionBarSystemIndices.MainBar
                and Enum.EditModeActionBarSetting.HideBarArt or nil
            for key, entry in pairs(system.settings) do
                if type(entry) == "table" and entry.setting then
                    if count and entry.setting == Enum.EditModeActionBarSetting.NumIcons then entry.value = count end
                    if artKey ~= nil and entry.setting == artKey then entry.value = 0 end
                elseif count and key == Enum.EditModeActionBarSetting.NumIcons then
                    system.settings[key] = count
                elseif artKey ~= nil and key == artKey then
                    system.settings[key] = 0
                end
            end
        end
        -- Pin to the band: an unpinned bar is re-laid by the client at will, in combat too.
        for _, pin in ipairs(pins) do
            if system.system == pin.system and system.systemIndex == pin.systemIndex
                and (fresh or system.isInDefaultPosition or pinned[pin.name]) then
                system.anchorInfo = {
                    point = pin.anchorInfo.point, relativeTo = pin.anchorInfo.relativeTo,
                    relativePoint = pin.anchorInfo.relativePoint,
                    offsetX = pin.anchorInfo.offsetX, offsetY = pin.anchorInfo.offsetY,
                }
                system.anchorInfo2 = nil
                system.isInDefaultPosition = false
                record[pin.name] = {
                    point = pin.anchorInfo.point, relativePoint = pin.anchorInfo.relativePoint,
                    offsetX = pin.anchorInfo.offsetX, offsetY = pin.anchorInfo.offsetY,
                }
            end
        end
    end
    if next(record) then
        ns.DbTable("barPins")
        ns.db.barPins[LAYOUT_NAME] = ns.db.barPins[LAYOUT_NAME] or {}
        for name, pin in pairs(record) do ns.db.barPins[LAYOUT_NAME][name] = pin end
    end
end

-- Session end: create or update the classic layout and activate it, on data only, never live frames.
local function ClassicNow(job)
    if not ns.sessionEnding then return false end
    local mgr = EditModeManagerFrame
    local layouts = mgr and mgr.layoutInfo and mgr.layoutInfo.layouts
    if not layouts or not (C_EditMode and C_EditMode.SaveLayouts and C_EditMode.SetActiveLayout) or not EditModePresetLayoutManager then return false end
    local counts = type(job) == "table" and job.counts or {}
    local pins = ns.BandPinAnchors()
    local index, layout = LayoutIndexByName(LAYOUT_NAME)
    if layout then
        DressLayoutData(layout, counts, pins, false)
        C_EditMode.SaveLayouts(mgr.layoutInfo)
    else
        if mgr.AreLayoutsFullyMaxed and mgr:AreLayoutsFullyMaxed() then return false end
        local presets = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
        local classicIndex = (Enum.EditModePresetLayouts and Enum.EditModePresetLayouts.Classic) or 2
        local base = presets and (presets[classicIndex] or presets[1])
        if not base then return false end
        DressLayoutData(base, counts, pins, true)
        base.layoutType = Enum.EditModeLayoutType.Account
        base.layoutName = LAYOUT_NAME
        -- After the account's last layout, where the client puts a new one.
        index = nil
        for i, other in ipairs(layouts) do
            if other.layoutType == Enum.EditModeLayoutType.Account then index = i end
        end
        index = (index or (Enum.EditModePresetLayoutsMeta and Enum.EditModePresetLayoutsMeta.NumValues or 2)) + 1
        table.insert(layouts, index, base)
        C_EditMode.SaveLayouts(mgr.layoutInfo)
        if C_EditMode.OnLayoutAdded then C_EditMode.OnLayoutAdded(index, true, false) end
    end
    C_EditMode.SetActiveLayout(index)
    -- Next login checks the switch held.
    ns.db.layoutSelectPending = true
    return true
end

local function SelectNow(name)
    if not ns.sessionEnding or not (C_EditMode and C_EditMode.SetActiveLayout) then return false end
    local index = LayoutIndexByName(name, true)
    if not index then return false end
    C_EditMode.SetActiveLayout(index)
    return true
end

-- Jobs on the live layout run before the pins; layout switches after.
function ns.RunLayoutJobsBeforePin()
    local jobs = ns.db and ns.db.layoutJobs
    if type(jobs) ~= "table" or not ns.sessionEnding then return end
    -- Each job is taken off before it runs: settings outlive sessions, so one that errored re-ran at every logout.
    if jobs.reset then
        jobs.reset = nil
        ResetNow()
    end
    if jobs.adopt then
        jobs.adopt = nil
        ns.AdoptBandBars()
    end
    if jobs.fit then
        local big = jobs.fit == "big"
        jobs.fit = nil
        FitNow(big)
    end
    ns.ResetSizesNow(jobs)
end

function ns.RunLayoutJobsAfterPin()
    local jobs = ns.db and ns.db.layoutJobs
    if type(jobs) ~= "table" or not ns.sessionEnding then return end
    -- Taken off before any runs, as above.
    ns.db.layoutJobs = nil
    -- Legacy: only old saved data still holds "previous".
    if jobs.previous and SelectNow(jobs.previous) then ns.db.previousLayout = "" end
    if jobs.classic then ClassicNow(jobs.classic) end
    if jobs.select then SelectNow(LAYOUT_NAME) end
end

-- No room for another layout. Steps, not a button: edit mode opened from our code would run its setup in our name.
ns.Popup("FCUI_LAYOUTS_FULL", {
    text = TITLE .. "\n\nEdit mode is at its layout limit, so there is no room for the " .. LAYOUT_NAME .. " layout.\n\n"
        .. "Delete one you no longer use: press Escape, choose Edit Mode, pick it in the layout list and delete it. "
        .. "Then set up the classic layout again from the options.",
    button1 = OKAY or "Okay",
})

-- Creates or selects the classic layout; reloadNow reloads in this press.
function ns.CreateClassicLayout(reloadNow)
    if RefuseInCombat("cannot change layouts in combat") then return end
    local mgr = EditModeManagerFrame
    if not mgr or not mgr.GetLayouts or not EditModePresetLayoutManager or not (C_EditMode and C_EditMode.SaveLayouts) then
        ns.Print("edit mode layouts are not available on this client")
        return
    end
    local exists = LayoutIndexByName(LAYOUT_NAME) ~= nil
    if not exists and mgr.AreLayoutsFullyMaxed and mgr:AreLayoutsFullyMaxed() then
        StaticPopup_Show("FCUI_LAYOUTS_FULL")
        return
    end
    -- Read now, before this layout is left.
    local counts = ReadIconCounts()
    RememberLayout()
    ns.QueueLayoutJob("classic", { counts = counts })
    ns.db.layoutPrompted = true
    if reloadNow then
        ns.ReloadForLayout()
        return
    end
    ns.AskLayoutReload(exists and ("Switching to your " .. LAYOUT_NAME .. " layout.") or ("Setting up the " .. LAYOUT_NAME .. " layout."))
end

ns.Popup("FCUI_LAYOUT_PICK", {
    text = TITLE .. "\n\nThe " .. LAYOUT_NAME .. " layout is made, but the game did not switch to it. Open edit mode and "
        .. "pick " .. LAYOUT_NAME .. " in its Layout list.",
    button1 = OKAY,
})

-- First login: set up the classic layout or keep the current one.
ns.Popup("FCUI_FIRST_LOGIN", {
    text = TITLE .. "\n\nSet up the classic layout now? This adds an edit mode layout named \"" .. LAYOUT_NAME .. "\" with everything in its 1.x place and switches to it. Your current layout and keybinds are untouched and stay in the edit mode list, where you can switch back at any time. The interface reloads to do it.",
    button1 = "Set up and reload",
    button2 = "Keep my layout",
    OnAccept = function() ns.CreateClassicLayout(true) end,
})

-- After the layout reload: did the switch hold? No write here (live session). Not held:
-- one more queued select; still not: the player picks it in edit mode (a live switch tainted every piece).
function ns.SelectClassicLayoutIfPending()
    if ns.db and ns.db.layoutJobs and next(ns.db.layoutJobs) then
        ns.AskLayoutReload("A layout change you asked for is still waiting.")
        return
    end
    if not ns.db or not ns.db.layoutSelectPending then return end
    local mgr = EditModeManagerFrame
    if not mgr or not mgr.GetLayouts or InCombatLockdown() then return end
    local active = ns.ActiveLayoutInfo()
    local index = LayoutIndexByName(LAYOUT_NAME)
    if (active and active.layoutName == LAYOUT_NAME) or not index then
        ns.db.layoutSelectPending, ns.db.layoutSelectTries = false, 0
        return
    end
    local tries = ns.db.layoutSelectTries or 0
    if tries < 1 then
        ns.db.layoutSelectTries = tries + 1
        ns.QueueLayoutJob("select", true)
        ns.AskLayoutReload("The " .. LAYOUT_NAME .. " layout is made; one more reload switches to it.")
        return
    end
    ns.db.layoutSelectPending, ns.db.layoutSelectTries = false, 0
    StaticPopup_Show("FCUI_LAYOUT_PICK")
end

-- Player top left, target beside, focus under it (1.x had none), written as edit mode
-- records a drag. Reset job only, so a frame moved on purpose stays.
-- Target y is -4 here, -2 in the layout data; both kept on purpose.
local FRAME_SPOTS = { { "PlayerFrame", 4, -4 }, { "TargetFrame", 250, -4 }, { "FocusFrame", 250, -165 } }
function ns.ApplyClassicFrameSpots()
    if not ns.sessionEnding then return false end
    if InCombatLockdown() or not ns.ClassicLayoutActive() then return false end
    local mgr = EditModeManagerFrame
    if not mgr or not mgr.UpdateSystemAnchorInfo or not mgr.SaveLayouts then return false end
    local changed = false
    for _, spot in ipairs(FRAME_SPOTS) do
        local frame = _G[spot[1]]
        if frame and frame.system then
            -- Spots are screen units; offsets are in frame scale (the focus frame is smaller).
            local scale = frame:GetScale()
            if not scale or scale <= 0 then scale = 1 end
            local wantX, wantY = spot[2] / scale, spot[3] / scale
            local point, rel, relPoint, x, y = frame:GetPoint(1)
            local there = point == "TOPLEFT" and rel == UIParent and relPoint == "TOPLEFT"
                and math.abs((x or 0) - wantX) < 0.5 and math.abs((y or 0) - wantY) < 0.5
            if not there then
                ns.SetPointOnce(frame, "TOPLEFT", UIParent, "TOPLEFT", wantX, wantY)
                if mgr:UpdateSystemAnchorInfo(frame) then changed = true end
            end
        end
    end
    if changed then
        mgr:SaveLayouts()
        ns.Print("player, target and focus frames moved to their 1.x spots")
    end
    return true
end

-- Any active layout but a client preset may be written.
function ns.LayoutWritable()
    local info = ns.ActiveLayoutInfo()
    if not info then return false end
    local preset = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Preset
    return info.layoutType ~= preset
end

function ns.ClassicLayoutActive()
    local info = ns.ActiveLayoutInfo()
    return info ~= nil and info.layoutName == LAYOUT_NAME
end

function ns.CheckLayoutPosition()
    if not ns.db or not ns.db.classicBar then return end
    -- Legacy key, cleared from old saved data.
    ns.db.layoutWarned = nil
    if ns.db.layoutPrompted then return end
    ns.db.layoutPrompted = true
    if ns.ClassicLayoutActive() then return end
    StaticPopup_Show("FCUI_FIRST_LOGIN")
end
