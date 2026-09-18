local ADDON, ns = ...

ns.ADDON = ADDON
ns.PREFIX = "|cffe6c56cClassicUI Forever|r: "

ns.DB_DEFAULTS = {
    dbVersion = 1,
    classicBar = true,
    oneBar = false,
    barOffsetX = 0,
    barOffsetY = 0,
    barDragged = false,
    barScale = 1,
    buttons = true,
    squareIcons = true,
    emptySlots = true,
    hideExtraBars = true,
    unitFrames = true,
    castBars = true,
    comboPoints = true,
    combatNumbers = true,
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
    spellBook = true,
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
        return
    end
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        ForeverClassicUIDB = ForeverClassicUIDB or {}
        ns.db = ForeverClassicUIDB
        CopyDefaults(ns.db, ns.DB_DEFAULTS)
        ns.db.lastOutput = nil   -- earlier builds logged here; nothing does now
        MirrorLoad()
    elseif event == "PLAYER_LOGIN" then
        ns.ready = true
        for _, mod in ipairs(ns.modules) do
            if mod.init then ns.SafeCall(mod.init) end
        end
        ns.ApplyAll()
        if EventRegistry and EventRegistry.RegisterCallback then
            EventRegistry:RegisterCallback("EditMode.Exit", ns.QueueApply, ns)
            EventRegistry:RegisterCallback("EditMode.Enter", ns.QueueApply, ns)
        end
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

function ForeverClassicUI_OnAddonCompartmentClick()
    if ns.OpenOptions then ns.OpenOptions() end
end
