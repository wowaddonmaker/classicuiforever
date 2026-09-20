local ADDON, ns = ...

ns.ADDON = ADDON
ns.PREFIX = "|cffe6c56cClassicUI Forever|r: "

ns.DB_DEFAULTS = {
    dbVersion = 1,
    classicBar = true,
    oneBar = false,
    defaultBarSize = false,
    oneBag = false,
    bagsAboveRow = false,
    oneBagColumns = 4,
    barOffsetX = 0,
    barOffsetY = 0,
    barDragged = false,
    barScale = 1,
    buttons = true,
    squareIcons = true,
    castAnim = true,
    emptySlots = true,
    hideExtraBars = true,
    unitFrames = true,
    castBars = true,
    mirrorTimers = true,
    comboPoints = true,
    hideLastNames = false,
    classColorHealth = false,
    classColorPlates = false,
    mapFade = false,
    welcomeNote = true,
    minimap = true,
    minimapButton = true,
    minimapButtonAngle = 200,
    namePlates = true,
    fullPlates = true,
    questTracker = true,
    questLog = true,
    questLogDual = false,
    unitFramePlayer = true,
    unitFrameTarget = true,
    unitFrameFocus = true,
    unitFramePet = true,
    unitFrameParty = true,
    questMapPane = true,
    gameMenu = true,
    settingsPanel = true,
    panels = true,
    bags = true,
    characterSheet = true,
    statPanes = true,
    statPaneLeft = "section2",
    statPaneRight = "section3",
    spellBook = true,
    guildRoster = true,
    whoList = true,
    spellBookSearch = true,
    welcomed = false,
    -- "builtin" reads the art that still ships inside the game client;
    -- "bundled" reads the copies in media/ (fallback if the client drops them)
    textureSource = "builtin",
}

-- Module registry: each module is { key = db key, apply = fn, restore = fn }
-- applied in registration order so bar art lays out after end caps.
ns.modules = {}

function ns.RegisterModule(key, mod)
    mod.key = key
    ns.modules[#ns.modules + 1] = mod
end

-- Nothing is written to disk by the addon itself. A developer addon can
-- attach through ForeverClassicUI_AttachDevTools and take every line
-- that goes through here.
function ns.Persist(line)
    if ns.debugSink then ns.debugSink(line) end
end

-- Which client this is. WoW Forever reports a 1.60 build with a toc
-- in the 16000s; retail 12.x is in the 120000s. Every place the two
-- clients differ branches on this, never on whether a function exists.
function ns.OnForever()
    local _, _, _, toc = GetBuildInfo()
    return type(toc) == "number" and toc >= 16000 and toc < 17000
end

function ns.Print(msg)
    if issecretvalue and issecretvalue(msg) then msg = "<protected value>" end
    DEFAULT_CHAT_FRAME:AddMessage(ns.PREFIX .. tostring(msg))
    ns.Persist(msg)
end

function ns.BeginOutput(title)
    ns.Persist("=== " .. title .. " " .. date("%Y-%m-%d %H:%M:%S") .. " ===")
end

function ns.FlushNotice()
    if ns.debugFlushNotice then ns.debugFlushNotice() end
end

-- Hands the namespace to a developer addon. Nothing else calls this.
function ForeverClassicUI_AttachDevTools(fn)
    fn(ns)
end

function ns.SafeCall(fn, ...)
    local ok, err = xpcall(fn, geterrorhandler(), ...)
    return ok, err
end

function ns.GetMainBar()
    return MainActionBar or MainMenuBar
end

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = v
        end
    end
end

-- The classic damage numbers are gone: they could not tell your own
-- damage from anyone else's, which the client no longer says. While
-- they were drawn, the game's own numbers over the mob were turned off
-- so the two would not double up, and that is put back once here for
-- anyone upgrading, or they would be left with no numbers at all.
local function RetireDamageNumbers()
    if not ns.db or ns.db.damageNumbersRetired then return end
    ns.db.damageNumbersRetired = true
    if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return end
    for _, name in ipairs({ "floatingCombatTextCombatDamage", "floatingCombatTextCombatDamage_v2" }) do
        local ok, value = pcall(C_CVar.GetCVar, name)
        if ok and value == "0" then pcall(C_CVar.SetCVar, name, "1") end
    end
end

-- The Forever client writes an addon's saved variables at logout but
-- does not bring them back at the next login, so every toggle came back
-- as its default. CVars do come back. Every setting that differs from
-- its default is mirrored into one cvar of ours on each change, and read
-- back over the saved table at load; on retail the file itself is used.
local MIRROR_CVAR = "ClassicUIForeverSettings"
local function MirrorReady()
    return ns.OnForever() and C_CVar and C_CVar.RegisterCVar and C_CVar.SetCVar and C_CVar.GetCVar
end

function ns.MirrorSave()
    if not ns.db or not MirrorReady() then return end
    local parts = {}
    -- Read by key rather than walking the table: a probe may shadow
    -- the table's keys behind a metatable, and a walk then finds none.
    for k in pairs(ns.DB_DEFAULTS) do
        local v = ns.db[k]
        local t = type(v)
        if (t == "boolean" or t == "number" or t == "string") and ns.DB_DEFAULTS[k] ~= v and not tostring(v):find("[;=]") then
            parts[#parts + 1] = k .. "=" .. (t == "boolean" and (v and "b1" or "b0") or t == "number" and ("n" .. v) or ("s" .. v))
        end
    end
    table.sort(parts)
    pcall(C_CVar.SetCVar, MIRROR_CVAR, table.concat(parts, ";"))
end

local function MirrorLoad()
    if not ns.db or not MirrorReady() then return end
    -- Read before registering: a value the client kept from the last
    -- session is not to be reset by the registration.
    local ok, text = pcall(C_CVar.GetCVar, MIRROR_CVAR)
    if not ok or text == nil then
        pcall(C_CVar.RegisterCVar, MIRROR_CVAR, "")
        ok, text = pcall(C_CVar.GetCVar, MIRROR_CVAR)
    end
    ns.mirrorLoaded = ok and text or nil
    if not ok or not text or text == "" then return end
    for pair in text:gmatch("[^;]+") do
        local k, kind, raw = pair:match("^([%w_]+)=([bns])(.*)$")
        if k then
            if kind == "b" then ns.db[k] = raw == "1"
            elseif kind == "n" then ns.db[k] = tonumber(raw)
            else ns.db[k] = raw end
        end
    end
end

-- One deferred pass per frame no matter how many hooks fire.
local applyQueued = false
function ns.QueueApply()
    if applyQueued then return end
    applyQueued = true
    C_Timer.After(0, function()
        applyQueued = false
        ns.ApplyAll()
    end)
end

-- Modules move and re-level protected frames (unit frames, action bars),
-- which the client blocks in combat; a pass asked for in combat runs as
-- soon as combat ends.
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
    ns.MirrorSave()
end

-- Turning one of these off leaves art on screen that only a reload
-- clears, so the player is asked plainly rather than told in a line of
-- text at the foot of a window, which nobody reads.
ns.RELOAD_KEYS = {
    bags = true, castBars = true, characterSheet = true, classicBar = true, comboPoints = true,
    gameMenu = true, minimap = true, namePlates = true, panels = true,
    questMapPane = true, questTracker = true, settingsPanel = true, unitFrames = true,
}

StaticPopupDialogs["FOREVERCLASSICUI_RELOAD"] = {
    text = "Some of the old art stays on screen until the interface reloads.",
    button1 = RELOADUI or "Reload Now",
    button2 = LATER or "Later",
    OnAccept = function() if C_UI and C_UI.Reload then C_UI.Reload() end end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

-- A toggle the player just changed: the pass runs, and a piece switched
-- back to the modern look says so where it cannot be missed.
function ns.ToggleChanged(key)
    if key == "defaultBarSize" and ns.FitBarsToSize then ns.FitBarsToSize(ns.db.defaultBarSize == true) end
    if key == "oneBag" then ns.SetCVar("combinedBags", ns.db.oneBag == true and "1" or "0") end
    ns.ApplyAll()
    -- A toggle changed somewhere other than the settings window, the
    -- bags dialog in edit mode for one, shows there too if it is open.
    if ns.RefreshOptionsWindow then ns.RefreshOptionsWindow() end
    if key and ns.RELOAD_KEYS[key] and ns.db and ns.db[key] == false and StaticPopup_Show then
        StaticPopup_Show("FOREVERCLASSICUI_RELOAD")
    end
end

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
        return
    end
    if event == "PLAYER_LOGOUT" then
        ns.MirrorSave()
        -- Unticked in the addon list and reloading: this is the last code
        -- of ours that runs, and the one chance to leave the client's UI
        -- as it was found.
        if ns.BeingTurnedOff and ns.BeingTurnedOff() and ns.HandBack then pcall(ns.HandBack) end
        return
    end
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        ForeverClassicUIDB = ForeverClassicUIDB or {}
        ns.db = ForeverClassicUIDB
        CopyDefaults(ns.db, ns.DB_DEFAULTS)
        ns.db.lastOutput = nil   -- earlier builds logged here; nothing does now
        MirrorLoad()
        RetireDamageNumbers()
    elseif event == "PLAYER_LOGIN" then
        ns.ready = true
        for _, mod in ipairs(ns.modules) do
            if mod.init then ns.SafeCall(mod.init) end
        end
        ns.ApplyAll()
        ns.OnEditMode(function() ns.QueueApply() end)
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

-- One way in for every setting this addon writes. A console setting the
-- client guards (the nameplate family among them) refuses a write from
-- an addon while the player is in combat, and the refusal puts the
-- blocked-action box on their screen; a write of the value it already
-- holds is refused the same way for nothing gained.
function ns.SetCVar(name, value)
    if not name or value == nil then return false end
    if InCombatLockdown() then return false end
    if not (C_CVar and C_CVar.SetCVar and C_CVar.GetCVar) then return false end
    local ok, current = pcall(C_CVar.GetCVar, name)
    if ok and current ~= nil and tostring(current) == tostring(value) then return true end
    -- What the setting was before this addon first changed it, kept so it
    -- can be handed back if the addon is turned off.
    if ok and current ~= nil and ns.db and not ns.handingBack then
        ns.db.cvarWas = ns.db.cvarWas or {}
        if ns.db.cvarWas[name] == nil then ns.db.cvarWas[name] = tostring(current) end
    end
    local wrote = pcall(C_CVar.SetCVar, name, value)
    return wrote
end

-- Edit mode opening and closing, watched rather than hooked or listened
-- for. A callback of ours in the client's own list, or a hook on the
-- manager's own methods, runs inside the client's pass over every frame
-- in the layout: whatever it does in that pass after us it holds
-- against us, and the party and raid frames are laid out in it, which
-- is how the damage meter and the objective tracker came to fail on the
-- client's own values. Asking the manager what it is doing says the
-- same thing and leaves its passes alone.
local editWatchers = {}
local editWatch, editState
function ns.OnEditMode(fn)
    if type(fn) ~= "function" then return false end
    editWatchers[#editWatchers + 1] = fn
    if not editWatch then
        local mgr = EditModeManagerFrame
        editState = mgr and mgr.IsEditModeActive and mgr:IsEditModeActive() and true or false
        editWatch = CreateFrame("Frame")
        editWatch:SetScript("OnUpdate", function(self, elapsed)
            self.since = (self.since or 0) + elapsed
            if self.since < 0.1 then return end
            self.since = 0
            local mgr = EditModeManagerFrame
            local now = mgr and mgr.IsEditModeActive and mgr:IsEditModeActive() and true or false
            if now == editState then return end
            editState = now
            for _, watcher in ipairs(editWatchers) do ns.SafeCall(watcher) end
        end)
    end
    return true
end

-- The client tells an addon when one of its calls was refused. The last
-- few are kept and printed by the debug command, so a report of the
-- blocked-action box comes back with the call that caused it rather
-- than a guess.
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
        editMode = EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive
            and EditModeManagerFrame:IsEditModeActive() and true or false,
    })
    for i = #ns.blocked, 6, -1 do table.remove(ns.blocked, i) end
end)

function ForeverClassicUI_OnAddonCompartmentClick()
    if ns.OpenOptions then ns.OpenOptions() end
end
