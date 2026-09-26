local ADDON, ns = ...

ns.PREFIX = "|cffe6c56cClassicUI Forever|r: "

-- { key = db key, apply, restore, init, id }, walked in ns.MODULE_ORDER so bar art lays out
-- after end caps. id defaults to key (pageArrows rides classicBar's toggle).
ns.modules = {}

function ns.RegisterModule(key, mod)
    mod.key = key
    ns.modules[#ns.modules + 1] = mod
end

-- Stable in-place sort; unlisted ids go last in registration order and are logged.
local function OrderModules()
    local order, mods = ns.MODULE_ORDER, ns.modules
    if type(order) ~= "table" then return end
    local rank = {}
    for i, id in ipairs(order) do
        if rank[id] == nil then rank[id] = i end
    end
    local listed, unlisted, report = {}, {}, {}
    for i, mod in ipairs(mods) do
        local id = mod.id or mod.key
        local r = rank[id]
        if r then
            listed[#listed + 1] = { mod = mod, rank = r, at = i }
        else
            unlisted[#unlisted + 1] = mod
            report[#report + 1] = i .. "." .. tostring(id)
        end
    end
    table.sort(listed, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.at < b.at
    end)
    local n = 0
    for _, entry in ipairs(listed) do
        n = n + 1
        mods[n] = entry.mod
    end
    for _, mod in ipairs(unlisted) do
        n = n + 1
        mods[n] = mod
    end
    if #report > 0 then
        ns.Persist("modules: not in MODULE_ORDER, walked last: " .. table.concat(report, ", "))
    end
end

-- Never written to disk; only an attached dev addon receives these lines.
function ns.Persist(line)
    if ns.debugSink then ns.debugSink(line) end
end

-- Forever has a 16xxx toc, retail 120xxx; branch on this, never on whether a function exists.
function ns.OnForever()
    local _, _, _, toc = GetBuildInfo()
    return type(toc) == "number" and toc >= 16000 and toc < 17000
end

function ns.Print(msg)
    if ns.IsSecret(msg) then msg = "<protected value>" end
    DEFAULT_CHAT_FRAME:AddMessage(ns.PREFIX .. tostring(msg))
    ns.Persist(msg)
end

function ns.BeginOutput(title)
    ns.Persist("=== " .. title .. " " .. date("%Y-%m-%d %H:%M:%S") .. " ===")
end

function ns.FlushNotice()
    if ns.debugFlushNotice then ns.debugFlushNotice() end
end

-- Hands ns to the dev addon; nothing else calls it.
function ForeverClassicUI_AttachDevTools(fn)
    fn(ns)
end

-- xpcall handler: the error handler is looked up only when an error happens.
local function Report(err)
    return geterrorhandler()(err)
end
ns.Report = Report

function ns.SafeCall(fn, ...)
    local ok, err = xpcall(fn, Report, ...)
    return ok, err
end

-- Docked addons hear the sheet's layout here: the client's EventRegistry refuses our TriggerEvent (CallbackRegistry.lua:192).
local sheetLaid = {}
function ForeverClassicUI_OnSheetLaid(fn, owner)
    if type(fn) == "function" then sheetLaid[#sheetLaid + 1] = { fn = fn, owner = owner } end
end
function ns.SignalSheetLaid()
    for i = 1, #sheetLaid do ns.SafeCall(sheetLaid[i].fn, sheetLaid[i].owner) end
end

-- Client window writes wait for combat to end: a window written in combat can't close until
-- then and Escape skips it (the social window stuck open that way).
local calmJobs, calmWatch = {}, nil
function ns.WhenCalm(key, fn)
    if not InCombatLockdown() then return ns.SafeCall(fn) end
    calmJobs[key] = fn
    if calmWatch then return end
    calmWatch = CreateFrame("Frame")
    calmWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
    calmWatch:SetScript("OnEvent", function()
        if InCombatLockdown() then return end
        local held = calmJobs
        calmJobs = {}
        for _, job in pairs(held) do ns.SafeCall(job) end
    end)
end

function ns.GetMainBar()
    return MainActionBar or MainMenuBar
end

-- At most one deferred pass per frame; the callback is created once.
local applyQueued = false
local function RunQueuedApply()
    applyQueued = false
    ns.ApplyAll()
end
function ns.QueueApply()
    if applyQueued then return end
    applyQueued = true
    C_Timer.After(0, RunQueuedApply)
end

local toggleParent, toggleOrder

-- Toggle parents and order from ns.TOGGLES; lazy because Options loads later.
local function ToggleTree()
    if toggleParent or type(ns.TOGGLES) ~= "table" then return end
    toggleParent, toggleOrder = {}, {}
    for i, entry in ipairs(ns.TOGGLES) do
        toggleParent[entry[1]] = entry.parent
        toggleOrder[entry[1]] = i
    end
end

-- A module runs while its toggle and every parent toggle are on (a sub-toggle alone never applies).
local function ModuleOn(key)
    if ns.db[key] == false then return false end
    ToggleTree()
    local parent = toggleParent and toggleParent[key]
    if parent and parent ~= key then return ModuleOn(parent) end
    return true
end

-- Modules move and re-level protected frames: a pass asked for in combat runs when it ends. A module that touches
-- nothing protected (inFight = true) runs now as well, so its toggle answers in a fight.
local applyAfterCombat = false
function ns.ApplyAll()
    if not ns.db or not ns.ready then return end
    if InCombatLockdown() then
        applyAfterCombat = true
        for _, mod in ipairs(ns.modules) do
            if mod.inFight then ns.SafeCall(ModuleOn(mod.key) and mod.apply or mod.restore) end
        end
        return
    end
    for _, mod in ipairs(ns.modules) do
        if ModuleOn(mod.key) then
            ns.SafeCall(mod.apply)
        else
            ns.SafeCall(mod.restore)
        end
    end
    -- Restores may still set needsReload; RELOAD_KEYS has the final word.
    if ns.ReloadAfterPass then ns.ReloadAfterPass() end
end

-- Per RELOAD_KEYS toggle: state at session start, last seen, and owed way ("on"/"off").
-- bookWired: spellbook key wired yet; askAfterCombat: a combat change is waiting.
local reload = { start = nil, seen = {}, owed = {}, bookWired = false, askAfterCombat = false }

-- Ticked and its parent in force, unless the rule sets own.
local function InForce(key)
    local rule = ns.RELOAD_KEYS[key]
    if rule and rule.own then return ns.db[key] ~= false end
    return ModuleOn(key)
end

-- Whether a toggle's replacement stands right now (public API): with a change still owed a reload, the session's start.
function ns.ModuleInForce(key)
    ToggleTree()
    if not ns.db or not (toggleOrder and toggleOrder[key]) then return false end
    if reload.owed[key] ~= nil and reload.start then return reload.start[key] == true end
    return ModuleOn(key)
end

-- Session snapshot, taken at login before the first pass.
local function TakeToggleStart()
    if reload.start or not ns.db then return end
    reload.start = {}
    for key in pairs(ns.RELOAD_KEYS) do
        local on = InForce(key)
        reload.start[key] = on
        reload.seen[key] = on
    end
end

-- After every pass, never in combat.
function ns.ReloadAfterPass()
    ns.needsReload = next(reload.owed) ~= nil
end

-- Options list order, then key.
local NO_ORDER = {}
local function ByToggleOrder(a, b)
    local order = toggleOrder or NO_ORDER
    local ra, rb = order[a.key] or 1000, order[b.key] or 1000
    if ra ~= rb then return ra < rb end
    return a.key < b.key
end
local function SortByToggleOrder(list)
    ToggleTree()
    table.sort(list, ByToggleOrder)
    return list
end

-- Toggles changed since the last look that owe a reload. A both-ways toggle back at its start
-- owes nothing (pins and wiring as built); turning an off-only one back on cancels its debt.
local function TakeReloadChanges()
    TakeToggleStart()
    local hits = {}
    if not reload.start then return hits end
    for key, rule in pairs(ns.RELOAD_KEYS) do
        local on = InForce(key)
        if on ~= reload.seen[key] then
            reload.seen[key] = on
            local way = on and "on" or "off"
            if rule.on and rule.off and on == reload.start[key] then
                reload.owed[key] = nil
            elseif rule[way] then
                reload.owed[key] = way
                hits[#hits + 1] = { key = key, text = rule[way] }
            elseif on == reload.start[key] then
                reload.owed[key] = nil
            end
        end
    end
    return SortByToggleOrder(hits)
end

function ns.ReloadOwed()
    return next(reload.owed) ~= nil
end

-- Owed reloads as { key, way }, in options list order.
function ns.ReloadOwedList()
    local list = {}
    for key, way in pairs(reload.owed) do list[#list + 1] = { key = key, way = way } end
    return SortByToggleOrder(list)
end

-- Popup text, capped at RELOAD_LINES; a child whose parent also changed rides the parent's line.
local RELOAD_LINES = 3
local function ReloadText(hits)
    local changed = {}
    for _, hit in ipairs(hits) do changed[hit.key] = true end
    local lines, more = {}, 0
    for _, hit in ipairs(hits) do
        local parent = toggleParent and toggleParent[hit.key]
        if not (parent and changed[parent]) then
            if #lines < RELOAD_LINES then lines[#lines + 1] = hit.text else more = more + 1 end
        end
    end
    if more > 0 then lines[#lines + 1] = string.format("And %d more that a reload finishes.", more) end
    return table.concat(lines, "\n\n")
end

-- Raw entry, not ns.ReloadPopup: this file loads before UI/Dialogs.lua.
StaticPopupDialogs["FOREVERCLASSICUI_RELOAD"] = {
    text = "ClassicUI Forever\n\n%s",
    button1 = RELOADUI or "Reload Now",
    button2 = LATER or "Later",
    OnAccept = function() ns.ReloadForLayout() end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

-- Call after any toggle change; returns whether it asked. Deferred in combat: the pass waits
-- anyway and Reload Now there skips the layout work (ns.ReloadForLayout).
function ns.AskReloadIfNeeded()
    if InCombatLockdown() then
        reload.askAfterCombat = true
        return false
    end
    local hits = TakeReloadChanges()
    ns.needsReload = ns.ReloadOwed()
    if #hits > 0 then
        if StaticPopup_Show then StaticPopup_Show("FOREVERCLASSICUI_RELOAD", ReloadText(hits)) end
        return true
    end
    -- Nothing owed: drop a stale popup.
    if not ns.needsReload and StaticPopup_Hide then StaticPopup_Hide("FOREVERCLASSICUI_RELOAD") end
    return false
end

-- The player changed a toggle: run the pass, then ask for a reload if owed.
-- Told of every toggle, even one whose Apply waits for a fight's end; never polled.
local toggleWatchers = {}
function ns.OnToggle(fn)
    if type(fn) == "function" then toggleWatchers[#toggleWatchers + 1] = fn end
end

-- A radio row turned on turns the rest of its group off; the last one on stays on.
local function PickRadio(key)
    local group = ns.TOGGLE_RADIO and ns.TOGGLE_RADIO[key]
    if not group then return end
    local db = ns.db
    if db[key] ~= true then
        for i = 1, #group do
            if db[group[i]] == true then return end
        end
        db[key] = true
        return
    end
    for i = 1, #group do
        if group[i] ~= key then db[group[i]] = false end
    end
end

local function KeyEffects(key)
    if key == "gameDamageNumbers" then ns.WriteGameDamageNumbers() end
    if key == "defaultBarSize" and ns.FitBarsToSize then ns.FitBarsToSize(ns.db.defaultBarSize == true) end
    if key == "oneBag" then ns.SetCVar("combinedBags", ns.db.oneBag == true and "1" or "0") end
end

-- Keys changed at once (a toggle, a profile switch): their own effects, one pass, the watchers, the save.
function ns.TogglesChanged(changed)
    for i = 1, #changed do KeyEffects(changed[i]) end
    ns.ApplyAll()
    for i = 1, #changed do
        for j = 1, #toggleWatchers do ns.SafeCall(toggleWatchers[j], changed[i]) end
    end
    -- Before the refresh so the window's footer sees the result.
    ns.AskReloadIfNeeded()
    -- The change may come from elsewhere (edit mode's bags dialog).
    if ns.RefreshOptionsWindow then ns.RefreshOptionsWindow() end
end

function ns.ToggleChanged(key)
    PickRadio(key)
    ns.TogglesChanged({ key })
end

-- Our first frame: db loads and the post-combat pass runs before any other frame of ours sees the event.
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("UI_SCALE_CHANGED")
frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_REGEN_ENABLED" then
        if applyAfterCombat then
            applyAfterCombat = false
            ns.ApplyAll()
        end
        -- A toggle changed in combat, weighed now that its pass has run.
        if reload.askAfterCombat then
            reload.askAfterCombat = false
            ns.AskReloadIfNeeded()
            if ns.RefreshOptionsWindow then ns.RefreshOptionsWindow() end
        end
        return
    end
    if event == "PLAYER_LOGOUT" then
        if ns.RepairSurnames then pcall(ns.RepairSurnames) end
        pcall(ns.RepairDamageNumbers)
        pcall(ns.StoreProfile)
        -- Disabled in the addon list: the last chance to hand the UI back.
        if ns.BeingTurnedOff and ns.BeingTurnedOff() and ns.HandBack then pcall(ns.HandBack) end
        return
    end
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        ForeverClassicUIDB = ForeverClassicUIDB or {}
        ns.db = ForeverClassicUIDB
        -- Saved before this version (dbVersion 1): read before the defaults fill the gaps.
        local upgraded = next(ns.db) ~= nil and (ns.db.dbVersion or 1) < 2
        local big = ns.db.defaultBarSize == true
        ns.CopyDefaults(ns.db, ns.DB_DEFAULTS)
        if upgraded then ns.KeepBarSize(big) end
        ns.db.lastOutput = nil   -- stale key from old saves
        ns.LoadProfile()
    elseif event == "PLAYER_LOGIN" then
        ns.ready = true
        ns.ReadGameDamageNumbers()
        OrderModules()
        for _, mod in ipairs(ns.modules) do
            if mod.init then ns.SafeCall(mod.init) end
        end
        TakeToggleStart()
        ns.ApplyAll()
        ns.OnEditMode(function() ns.QueueApply() end)
    else
        ns.QueueApply()
        if event == "PLAYER_ENTERING_WORLD" and not ns.layoutChecked and ns.FirstRun then
            ns.layoutChecked = true
            C_Timer.After(3, function()
                if ns.SelectClassicLayoutIfPending then ns.SelectClassicLayoutIfPending() end
                ns.FirstRun()
                if ns.OfferBarSize then ns.OfferBarSize() end
            end)
        end
    end
end)

-- Edit mode is watched, never hooked or listened to: our code in its callbacks taints the layout pass (party/raid, meter,
-- tracker). Its active flag flips only in the manager's OnShow/OnHide: a pure child hears both, answered the frame after.
local editWatchers = {}
local editWatched, editState
local function EditModeEdge()
    local open = ns.EditMode.Live()
    if open == editState then return end
    editState = open
    ns.EditMode.state = open
    for _, watcher in ipairs(editWatchers) do ns.SafeCall(watcher) end
end
local function QueueEditEdge()
    ns.Sched.NextFrame("core.editMode", EditModeEdge)
end
-- The manager is a load-time client frame; if a client lacks it yet, its addon's load makes the watcher.
local function WatchEditMode()
    if editWatched then return end
    local mgr = EditModeManagerFrame
    if not mgr then
        ns.EventFrame("ADDON_LOADED", function(self)
            if not EditModeManagerFrame then return end
            self:UnregisterAllEvents()
            WatchEditMode()
        end)
        return
    end
    editWatched = true
    -- Under its Border (the client marks it out of layout): the manager is a resize layout frame and counts its children.
    ns.Sched.OnVisible(mgr.Border or mgr, "core.editMode", QueueEditEdge)
    QueueEditEdge()
end
function ns.OnEditMode(fn)
    if type(fn) ~= "function" then return false end
    editWatchers[#editWatchers + 1] = fn
    if editState == nil then
        editState = ns.EditMode.Live()
        ns.EditMode.state = editState
        WatchEditMode()
    end
    return true
end

-- Last few blocked calls, printed by /fcui debug.
ns.blocked = {}
local watchdog = CreateFrame("Frame")
watchdog:RegisterEvent("ADDON_ACTION_BLOCKED")
watchdog:RegisterEvent("ADDON_ACTION_FORBIDDEN")
watchdog:SetScript("OnEvent", function(_, event, addon, func)
    if addon ~= ADDON then return end
    table.insert(ns.blocked, 1, {
        event = event,
        func = tostring(func),
        when = date and date("%H:%M:%S") or "",
        combat = InCombatLockdown() and true or false,
        editMode = ns.EditMode.Live(),
    })
    for i = #ns.blocked, 6, -1 do table.remove(ns.blocked, i) end
    if ns.OfferStatus then ns.OfferStatus() end
end)

function ForeverClassicUI_OnAddonCompartmentClick()
    if ns.OpenOptions then ns.OpenOptions() end
end
