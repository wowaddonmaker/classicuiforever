local _, ns = ...
local L = ns.L

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
    button1 = L["OPTWIN_RELOAD_NOW"],
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

-- The game refuses an addon's reload in a fight: the change stays saved and the reload is offered as the fight ends.
ns.ReloadPopup("FCUI_RELOAD_AFTER_FIGHT", string.format(L["CORE_RELOAD_AFTER_FIGHT"], TITLE))
-- The options button asks here: a press from our own button that saved the layout first had its next call refused.
ns.ReloadPopup("FCUI_RELOAD_CONFIRM", string.format(L["OPTWIN_RELOAD_CONFIRM"], TITLE))
local function OfferReloadAfterFight()
    if StaticPopup_Show then StaticPopup_Show("FCUI_RELOAD_AFTER_FIGHT") end
end

-- Every addon reload: pre-pin jobs, band pins (unpins with the band off), post-pin jobs, all in the press, in that order.
function ns.ReloadForLayout()
    if not (C_UI and C_UI.Reload) then return end
    if InCombatLockdown() then
        ns.Print(L["CORE_RELOAD_WAITS_FOR_FIGHT"])
        ns.WhenCalm("reloadAfterFight", OfferReloadAfterFight)
        return
    end
    if ns.db then
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

-- The game-sized bar became the default: an install from before keeps its 1.x size, written as its choice into the
-- account and every profile (profiles keep only what differs from the defaults), and is offered the new size once.
function ns.KeepBarSize(big)
    local db = ns.db
    if not big then db.classicBarSize = true end
    for _, shot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
        if type(shot) == "table" and shot.defaultBarSize == nil and shot.classicBarSize == nil then shot.classicBarSize = true end
    end
    db.barSizeOffer = not big or nil
end

-- Game-sized bar (on by default) became Classic-sized bars (off by default): a box unticked before is ticked now,
-- in the account and every profile.
function ns.BarSizeKey()
    local db = ns.db
    local function Turn(t)
        if t.defaultBarSize == nil then return end
        if t.defaultBarSize == false then t.classicBarSize = true end
        t.defaultBarSize = nil
    end
    Turn(db)
    for _, shot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
        if type(shot) == "table" then Turn(shot) end
    end
end

ns.Popup("FCUI_BAR_SIZE_OFFER", {
    text = TITLE .. "\n\nThe classic bar now comes at the game's own size (45 px buttons) for new installs. Yours keeps the 1.x size (36 px).\n\nSwitch to the game's size? The Classic-sized bars option changes it any time.",
    button1 = L["OPTWIN_GAME_SIZE"],
    button2 = L["OPTWIN_KEEP_MINE"],
    OnAccept = function()
        ns.db.classicBarSize = false
        ns.TogglesChanged({ "classicBarSize" })
    end,
})

-- 0.14.0's bar changes, each key's value before them: an install from before keeps these (written into the account and
-- every profile, which keep only what differs from the defaults) and is offered the new look once. Runs before the defaults fill.
local OLD_LOOK = { hideMicroGroupFinder = false, hideMicroCollections = false, hideMicroLegacy = false, eraBagSize = false,
    hideMicroHelp = true, hideMicroKeepSize = true }
function ns.KeepOldLook()
    local db = ns.db
    for k, old in pairs(OLD_LOOK) do
        if db[k] == nil then db[k] = old end
        for _, shot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
            if type(shot) == "table" and shot[k] == nil then shot[k] = old end
        end
    end
    db.classicLookOffer = true
    db.dbVersion = 4
end

-- 0.14.0's What's New list: a player it was announced to, coming from an older one, met its bar changes unasked (the Help
-- button, micro buttons grown to fill): told at each login until they choose (ns.AnnounceBarsLook).
local LIST_0140 = 12
function ns.NoteBarsLook()
    local db = ns.db
    local from, seen = tonumber(db.whatsNewFrom) or 0, tonumber(db.whatsNewSeen) or 0
    if from >= 1 and from < LIST_0140 and seen >= LIST_0140 then db.barsLookNote = true end
    db.dbVersion = 4
end

-- The text's homes for the hidden buttons: the minimap eye, and the spellbook's Collections tab (none with our
-- spellbook off, so Collections stays). t: the account's full values or a profile's differences.
local function TakeClassicLook(t, full)
    for k, old in pairs(OLD_LOOK) do
        local keep = k == "hideMicroCollections" and t.spellBook == false
        if full then
            if not keep then t[k] = ns.DB_DEFAULTS[k] end
        elseif t[k] == old and not keep then
            t[k] = nil
        end
    end
    t.lfgMinimapButton = full or nil
end

local function TakeOldLook(t)
    for k, old in pairs(OLD_LOOK) do t[k] = old end
end

-- Accepted, every profile follows the new defaults. Written, then reloaded, so the bar and bags build once in the new look.
ns.Popup("FCUI_CLASSIC_LOOK_OFFER", {
    text = string.format(L["OPTWIN_CLASSIC_LOOK_OFFER"], TITLE),
    button1 = L["OPTWIN_USE_CLASSIC_LOOK"],
    button2 = L["OPTWIN_KEEP_MINE"],
    OnAccept = function() ns.ChooseBarsLook("classic") end,
})

ns.Popup("FCUI_OLD_LOOK_CONFIRM", {
    text = string.format(L["OPTWIN_OLD_LOOK_CONFIRM"], TITLE),
    button1 = L["OPTWIN_USE_CLASSIC_LOOK"],
    button2 = CANCEL or "Cancel",
    OnAccept = function() ns.ChooseBarsLook("old") end,
})

-- The bars note's choice ("old", "classic", or nil to keep the bars): the account and every profile, then a reload.
function ns.ChooseBarsLook(which)
    local db = ns.db
    db.barsLookNote = nil
    if not which then return end
    for _, shot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
        if type(shot) == "table" then
            if which == "old" then TakeOldLook(shot) else TakeClassicLook(shot, false) end
        end
    end
    if which == "old" then TakeOldLook(db) else TakeClassicLook(db, true) end
    ns.ReloadForLayout()
end

function ns.OfferClassicLook()
    if not ns.db or not ns.db.classicLookOffer then return end
    ns.db.classicLookOffer = nil
    if StaticPopup_Show then StaticPopup_Show("FCUI_CLASSIC_LOOK_OFFER") end
end

-- Once, at the first world entry after the upgrade.
function ns.OfferBarSize()
    if not ns.db or not ns.db.barSizeOffer then return end
    ns.db.barSizeOffer = nil
    if StaticPopup_Show then StaticPopup_Show("FCUI_BAR_SIZE_OFFER") end
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
    text = TITLE .. "\n\nTurn the addon off for this character? Your earlier layout and game settings come back. The interface reloads.",
    button1 = L["OPTWIN_TURN_OFF"],
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
-- Forever holds it by RIGHT, retail by TOPRIGHT; a spot further in than ours is the player's and stays. Held off its
-- default too: a default tracker is laid by the client's right-side container, flush with the edge whatever its offset.
local TRACKER_X, TRACKER_GAP = -110, 10
local TRACKER_EDGE_POINTS = { RIGHT = true, TOPRIGHT = true }
local function PlaceTracker(system)
    local info = system.anchorInfo
    if type(info) ~= "table" or not TRACKER_EDGE_POINTS[info.point] or info.relativePoint ~= info.point then return false end
    if info.relativeTo ~= nil and info.relativeTo ~= "UIParent" then return false end
    local side = ns.band and ns.band.SideColumnsWidth and ns.band.SideColumnsWidth() or 0
    local x = math.min(TRACKER_X, -(side + TRACKER_GAP))
    if (info.offsetX or 0) < x - 0.5 then return false end
    if info.offsetX == x and system.isInDefaultPosition == false then return false end
    info.offsetX = x
    system.isInDefaultPosition = false
    return true
end

-- The classic layout's tracker placed beside the side bars as they stand now, in the session's end write.
function ns.PlaceClassicTracker()
    if not ns.sessionEnding or not ns.ClassicLayoutActive() then return false end
    local active = ns.ActiveLayoutInfo()
    for _, system in ipairs(active and active.systems or {}) do
        if system.system == Enum.EditModeSystem.ObjectiveTracker then return PlaceTracker(system) end
    end
    return false
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
    local defaults = ns.DB_DEFAULTS
    ns.db.reagentBagSlot, ns.db.reagentBagRound, ns.db.reagentBagHover =
        defaults.reagentBagSlot, defaults.reagentBagRound, defaults.reagentBagHover
    ns.db.hideMicroButtons, ns.db.hideProfessionsButton = defaults.hideMicroButtons, defaults.hideProfessionsButton
    -- The classic look's micro buttons and bag slots too (Legacy, group finder and collections off, Era's bag slots).
    TakeClassicLook(ns.db, true)
    -- Windows and gryphons placed or sized in the windows edit mode (the map included) back to their own; Movable
    -- anytime is kept.
    ns.db.windowPos, ns.db.windowScale = nil, nil
    if ns.SettleWindowEdits then ns.SettleWindowEdits() end
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
    -- Settings too (Hide Bar Art, slot counts and the rest).
    ns.ResetLayoutSettingsNow()
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
    text = string.format(L["OPTWIN_RESET_CLASSIC_UI"], TITLE),
    button1 = L["OPTWIN_RESET_AND_RELOAD"],
    button2 = CANCEL or "Cancel",
    OnAccept = function() ns.ResetClassicLayout(true) end,
})

-- Icon counts carry over from the layout being left. The band follows bar 1's count.
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
    return counts
end

-- The chat's foot over the band's pet and stance row at either bar size (the game's 145 sat on the form bar); the damage
-- meter under four party frames (their foot at -391), from the corner where it covered the player frame.
local CHAT_X, CHAT_GAP, CHAT_Y = 35, 6, 145
local METER_X, METER_Y = 22, -399
local function ChatY()
    local top = ns.band and ns.band.PetRowTop and ns.band.PetRowTop()
    return top and math.floor(top + CHAT_GAP + 0.5) or CHAT_Y
end

-- Writes the classic setup into layout data: unit frame spots, icon counts, band pins.
-- A fresh layout also lifts chat and pins every bar; an existing one pins only bars
-- still at default or pinned by us before.
local function DressLayoutData(layout, counts, pins, fresh)
    local chatY = ChatY()
    local pinned = ns.db.barPins and ns.db.barPins[LAYOUT_NAME] or {}
    local record = {}
    for _, system in ipairs(layout.systems or {}) do
        if fresh and system.system == Enum.EditModeSystem.ObjectiveTracker then
            FitTracker(system)
            PlaceTracker(system)
        end
        -- Chat above the bars and pet row as in 1.x.
        if fresh and system.system == Enum.EditModeSystem.ChatFrame and type(system.anchorInfo) == "table" then
            local info = system.anchorInfo
            if info.point == "BOTTOMLEFT" and (info.offsetY or 0) < chatY then
                info.relativeTo = "UIParent"
                info.relativePoint = "BOTTOMLEFT"
                info.offsetX = CHAT_X
                info.offsetY = chatY
                system.isInDefaultPosition = false
            end
        end
        if fresh and system.system == Enum.EditModeSystem.DamageMeter and type(system.anchorInfo) == "table" then
            local info = system.anchorInfo
            info.point, info.relativeTo, info.relativePoint = "TOPLEFT", "UIParent", "TOPLEFT"
            info.offsetX, info.offsetY = METER_X, METER_Y
            system.isInDefaultPosition = false
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
    -- A slot-count job queued before 0.11.0 (the bar size no longer trims the bars).
    jobs.fit = nil
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
    text = string.format(L["OPTWIN_LAYOUTS_FULL"], TITLE, LAYOUT_NAME),
    button1 = OKAY or "Okay",
})

-- Creates or selects the classic layout; reloadNow reloads in this press.
function ns.CreateClassicLayout(reloadNow)
    if RefuseInCombat("cannot change layouts in combat") then return end
    local mgr = EditModeManagerFrame
    if not mgr or not mgr.GetLayouts or not EditModePresetLayoutManager or not (C_EditMode and C_EditMode.SaveLayouts) then
        ns.Print(L["CHAT_15"])
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
    ns.AskLayoutReload(string.format(exists and L["OPTWIN_SWITCHING_TO_LAYOUT"] or L["OPTWIN_SETTING_UP_LAYOUT"], LAYOUT_NAME))
end

ns.Popup("FCUI_LAYOUT_PICK", {
    text = TITLE .. "\n\nThe " .. LAYOUT_NAME .. " layout is made, but the game did not switch to it. Open edit mode and "
        .. "pick " .. LAYOUT_NAME .. " in its Layout list.",
    button1 = OKAY,
})

-- First login: set up the classic layout or keep the current one.
ns.Popup("FCUI_FIRST_LOGIN", {
    text = TITLE .. "\n\nSet up the classic layout now? This adds an edit mode layout named \"" .. LAYOUT_NAME .. "\" and switches to it. Your current layout stays in the list. The interface reloads.",
    button1 = L["OPTWIN_SET_UP_AND_RELOAD"],
    button2 = L["OPTWIN_KEEP_MY_LAYOUT"],
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

-- Player top left, target beside, focus under it (1.x had none), the meter under the party frames, the chat over the
-- band, written as edit mode records a drag. Reset job only, so a frame moved on purpose stays.
-- Target y is -4 here, -2 in the layout data; both kept on purpose.
local function FrameSpots()
    return { { "PlayerFrame", "TOPLEFT", 4, -4 }, { "TargetFrame", "TOPLEFT", 250, -4 }, { "FocusFrame", "TOPLEFT", 250, -165 },
        { "DamageMeter", "TOPLEFT", METER_X, METER_Y }, { "ChatFrame1", "BOTTOMLEFT", CHAT_X, ChatY() } }
end
function ns.ApplyClassicFrameSpots()
    if not ns.sessionEnding then return false end
    if InCombatLockdown() or not ns.ClassicLayoutActive() then return false end
    local mgr = EditModeManagerFrame
    if not mgr or not mgr.UpdateSystemAnchorInfo or not mgr.SaveLayouts then return false end
    local changed = false
    for _, spot in ipairs(FrameSpots()) do
        local frame, corner = _G[spot[1]], spot[2]
        if frame and frame.system then
            -- Spots are screen units; offsets are in frame scale (the focus frame is smaller).
            local scale = frame:GetScale()
            if not scale or scale <= 0 then scale = 1 end
            local wantX, wantY = spot[3] / scale, spot[4] / scale
            local point, rel, relPoint, x, y = frame:GetPoint(1)
            local there = point == corner and rel == UIParent and relPoint == corner
                and math.abs((x or 0) - wantX) < 0.5 and math.abs((y or 0) - wantY) < 0.5
            if not there then
                ns.SetPointOnce(frame, corner, UIParent, corner, wantX, wantY)
                if mgr:UpdateSystemAnchorInfo(frame) then changed = true end
            end
        end
    end
    if changed then
        mgr:SaveLayouts()
        ns.Print(L["CHAT_16"])
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
