local ADDON, ns = ...

ns.ADDON = ADDON
ns.PREFIX = "|cffe6c56cForever Classic UI|r: "

ns.DB_DEFAULTS = {
    dbVersion = 1,
    enabled = true,
    classicBar = true,
    barOffsetX = 0,
    barOffsetY = 0,
    barScale = 1,
    buttons = true,
    squareIcons = true,
    pageArrows = true,
    emptySlots = true,
    hideExtraBars = true,
    unitFrames = true,
    castBars = true,
    minimap = true,
    minimapButton = true,
    minimapButtonAngle = 200,
    namePlates = true,
    questTracker = true,
    panels = true,
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

-- Every chat line also lands in ForeverClassicUIDB.lastOutput (colors
-- stripped) so a /reload puts it on disk for reading outside the game.
local OUTPUT_MAX = 2000
local outputDirty = false

local function StripColors(s)
    if issecretvalue and issecretvalue(s) then return "<protected value>" end
    s = tostring(s)
    if issecretvalue and issecretvalue(s) then return "<protected value>" end
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

function ns.Persist(line)
    if not ns.db then return end
    local out = ns.db.lastOutput
    if not out then
        out = {}
        ns.db.lastOutput = out
    end
    out[#out + 1] = StripColors(line)
    if #out > OUTPUT_MAX then table.remove(out, 1) end
    outputDirty = true
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
    if not outputDirty then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cff888888[FCUI] Output saved. /reload to flush to disk.|r")
    outputDirty = false
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
        if ns.db.enabled and ns.db[mod.key] ~= false then
            ns.SafeCall(mod.apply)
        else
            ns.SafeCall(mod.restore)
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
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
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        ForeverClassicUIDB = ForeverClassicUIDB or {}
        ns.db = ForeverClassicUIDB
        CopyDefaults(ns.db, ns.DB_DEFAULTS)
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
            C_Timer.After(3, ns.FirstRun)
        end
    end
end)

function ForeverClassicUI_OnAddonCompartmentClick()
    if ns.OpenOptions then ns.OpenOptions() end
end
