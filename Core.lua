local ADDON, ns = ...

ns.ADDON = ADDON
ns.PREFIX = "|cffe6c56cForever Classic UI|r: "

ns.DB_DEFAULTS = {
    dbVersion = 1,
    enabled = true,
    endCaps = true,
    barArt = true,
    hideModernBorders = true,
    buttons = true,
    squareIcons = true,
    pageArrows = true,
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

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(ns.PREFIX .. tostring(msg))
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

function ns.ApplyAll()
    if not ns.db or not ns.ready then return end
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
frame:SetScript("OnEvent", function(_, event, arg1)
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
    end
end)

function ForeverClassicUI_OnAddonCompartmentClick()
    if ns.OpenOptions then ns.OpenOptions() end
end
