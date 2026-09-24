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

function ns.SafeCall(fn, ...)
    local ok, err = xpcall(fn, geterrorhandler(), ...)
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

-- Modules move and re-level protected frames: a pass asked for in combat runs when it ends.
local applyAfterCombat = false
function ns.ApplyAll()
    if not ns.db or not ns.ready then return end
    if InCombatLockdown() then
        applyAfterCombat = true
        return
    end
    for _, mod in ipairs(ns.modules) do
        if ns.db[mod.key] ~= false then
            ns.SafeCall(mod.apply)
        else
            ns.SafeCall(mod.restore)
        end
    end
    -- Restores may still set needsReload; RELOAD_KEYS has the final word.
    if ns.ReloadAfterPass then ns.ReloadAfterPass() end
    ns.MirrorSave()
end

-- Per RELOAD_KEYS toggle: state at session start, last seen, and owed way ("on"/"off").
-- bookWired: spellbook key wired yet; askAfterCombat: a combat change is waiting.
local reload = { start = nil, seen = {}, owed = {}, bookWired = false, askAfterCombat = false }
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

-- Ticked and its parent in force, unless the rule sets own.
local function InForce(key)
    if ns.db[key] == false then return false end
    local rule = ns.RELOAD_KEYS[key]
    if rule and rule.own then return true end
    ToggleTree()
    local parent = toggleParent and toggleParent[key]
    if parent and parent ~= key then return InForce(parent) end
    return true
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

-- After every pass, never in combat. The spellbook key is wired once, when the book is first
-- built while on; until then each pass retakes spellDrag's start.
function ns.ReloadAfterPass()
    if reload.start and not reload.bookWired then
        reload.bookWired = InForce("spellBook")
        local on = InForce("spellDrag")
        reload.start.spellDrag, reload.seen.spellDrag, reload.owed.spellDrag = on, on, nil
    end
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
function ns.ToggleChanged(key)
    if key == "gameDamageNumbers" then ns.WriteGameDamageNumbers() end
    if key == "defaultBarSize" and ns.FitBarsToSize then ns.FitBarsToSize(ns.db.defaultBarSize == true) end
    if key == "oneBag" then ns.SetCVar("combinedBags", ns.db.oneBag == true and "1" or "0") end
    ns.ApplyAll()
    -- Before the refresh so the window's footer sees the result.
    ns.AskReloadIfNeeded()
    -- The change may come from elsewhere (edit mode's bags dialog).
    if ns.RefreshOptionsWindow then ns.RefreshOptionsWindow() end
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
        ns.MirrorSave()
        -- Disabled in the addon list: the last chance to hand the UI back.
        if ns.BeingTurnedOff and ns.BeingTurnedOff() and ns.HandBack then pcall(ns.HandBack) end
        return
    end
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        ForeverClassicUIDB = ForeverClassicUIDB or {}
        ns.db = ForeverClassicUIDB
        ns.CopyDefaults(ns.db, ns.DB_DEFAULTS)
        ns.db.lastOutput = nil   -- stale key from old saves
        ns.MirrorLoad()
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
        if ns.WatchEditWrites then ns.WatchEditWrites() end
    else
        ns.QueueApply()
        if event == "PLAYER_ENTERING_WORLD" and not ns.layoutChecked and ns.FirstRun then
            ns.layoutChecked = true
            C_Timer.After(3, function()
                if ns.SelectClassicLayoutIfPending then ns.SelectClassicLayoutIfPending() end
                ns.FirstRun()
            end)
        end
    end
end)

-- Edit mode is polled, never hooked or listened to: our code in the manager's callbacks runs
-- inside its layout pass and taints the rest (party/raid frames, damage meter, tracker broke).
-- The 0.1 s poll gets its own frame, not the driver, made on first call (classic bar Init, after
-- its edit watch frame), so on the closing frame that watch sees the release before the drag clears.
local editWatchers = {}
local editJob, editState
local function EditModePoll()
    local open = ns.EditMode.Live()
    if open == editState then return end
    editState = open
    ns.EditMode.state = open
    for _, watcher in ipairs(editWatchers) do ns.SafeCall(watcher) end
end
function ns.OnEditMode(fn)
    if type(fn) ~= "function" then return false end
    editWatchers[#editWatchers + 1] = fn
    if not editJob then
        editState = ns.EditMode.Live()
        ns.EditMode.state = editState
        editJob = ns.Sched.OnFrame(CreateFrame("Frame"), { name = "core.editMode", every = 0.1, fn = EditModePoll })
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
