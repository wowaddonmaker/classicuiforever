local _, ns = ...

-- Settings category, /fcui help and the slash commands.

local TITLE = ns.options.TITLE
local Debug = ns.options.Debug

local category

local function BuildSettings()
    if not Settings or not Settings.RegisterAddOnCategory then return end
    -- Our own panel as a canvas page.
    if Settings.RegisterCanvasLayoutCategory and ns.OptionsCanvas then
        local canvas = ns.OptionsCanvas()
        if canvas then
            local cat = Settings.RegisterCanvasLayoutCategory(canvas, TITLE)
            Settings.RegisterAddOnCategory(cat)
            category = cat
            return
        end
    end
    -- Fallback: a plain checkbox list.
    if not Settings.RegisterVerticalLayoutCategory or not Settings.RegisterAddOnSetting then return end
    local cat = Settings.RegisterVerticalLayoutCategory(TITLE)

    local function Checkbox(key, label, tooltip)
        local setting = Settings.RegisterAddOnSetting(cat, "FCUI_" .. key, key, ns.db, Settings.VarType.Boolean, label, ns.DB_DEFAULTS[key])
        setting:SetValueChangedCallback(function() ns.ToggleChanged(key) end)
        Settings.CreateCheckbox(cat, setting, tooltip)
    end

    for _, entry in ipairs(ns.TOGGLES) do
        Checkbox(entry[1], entry[2], entry[3])
    end

    Settings.RegisterAddOnCategory(cat)
    category = cat
end

function ns.OpenBlizzardSettings()
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    else
        ns.Print("Use /fcui help for commands.")
    end
end

local function Help()
    ns.Print("commands:")
    ns.Print("  /fcui - open the options window")
    ns.Print("  /fcui settings - the same options in the game's Settings window")
    for _, entry in ipairs(ns.TOGGLES) do
        ns.Print("  /fcui " .. entry[1] .. " on|off - " .. entry[2])
    end
    ns.Print("  /fcui textures builtin|bundled - where the art is read from")
    ns.Print("  /fcui status - a report of your version, game build, changed settings and other addons, for bug reports")
    ns.Print("  /fcui debug - client and frame details for bug reports")
    ns.Print("  /fcui layout - create and select a fresh classic edit mode layout")
    ns.Print("  /fcui prompt - show the first-login layout question again")
    ns.Print("  /fcui welcome - show the welcome note again")
    ns.Print("  /fcui whatsnew - show what changed in this version")
    ns.Print("  /fcui reset - restore defaults")
end

local function Status()
    ns.Print("textures: " .. ns.db.textureSource)
    for _, entry in ipairs(ns.TOGGLES) do
        ns.Print("  " .. entry[1] .. " = " .. tostring(ns.db[entry[1]]))
    end
end

local function SetBool(key, value)
    if value == "on" or value == "true" or value == "1" then
        ns.db[key] = true
    elseif value == "off" or value == "false" or value == "0" then
        ns.db[key] = false
    else
        ns.db[key] = not ns.db[key]
    end
    ns.Print(key .. " = " .. tostring(ns.db[key]))
    ns.ToggleChanged(key)
end

SLASH_FOREVERCLASSICUI1 = "/fcui"
SLASH_FOREVERCLASSICUI2 = "/foreverclassicui"
SlashCmdList.FOREVERCLASSICUI = function(msg)
    msg = (msg or ""):lower()
    local cmd, arg = msg:match("^(%S+)%s*(%S*)$")
    if not cmd then
        ns.OpenOptions()
        return
    end
    if cmd == "settings" then
        ns.OpenBlizzardSettings()
    elseif cmd == "help" then
        Help()
    elseif cmd == "status" or cmd == "report" then
        if ns.ShowStatus then ns.ShowStatus() end
    elseif cmd == "toggles" then
        ns.BeginOutput("status")
        Status()
        ns.FlushNotice()
    elseif cmd == "debug" then
        ns.BeginOutput("debug")
        Debug()
        ns.FlushNotice()
    elseif cmd == "off" then
        StaticPopup_Show("FCUI_TURN_OFF")
    elseif cmd == "adopt" then
        if ns.ClassicLayoutActive() and ns.db.classicBar ~= false then
            ns.QueueLayoutJob("adopt", true)
            ns.AskLayoutReload("Every bar goes back onto the classic bar and is locked there.")
        else
            ns.Print("not now: the classic bar is off, or another layout is active")
        end
    elseif cmd == "pin" then
        ns.Print("the bars are locked into the layout whenever the interface reloads or you log out; /reload does it now")
    elseif cmd == "layout" then
        ns.CreateClassicLayout()
    elseif cmd == "welcome" then
        ns.ShowWelcome()
    elseif cmd == "whatsnew" or cmd == "news" then
        ns.ShowWhatsNew()
    elseif cmd == "dev" then
        -- Unlisted: the next reload runs as a fresh install.
        ns.db.welcomed = false
        ns.db.layoutPrompted = nil
        ns.Print("first-run state cleared; the next reload shows the welcome and the layout question")
        if arg == "reload" then ns.ReloadForLayout() end
    elseif cmd == "prompt" then
        ns.db.layoutPrompted = nil
        StaticPopup_Show("FCUI_FIRST_LOGIN")
    elseif cmd == "reset" then
        -- Wipes all saved data, layout bookkeeping included.
        wipe(ns.db)
        for k, v in pairs(ns.DB_DEFAULTS) do ns.db[k] = v end
        ns.Print("defaults restored")
        -- Same path as one toggle, so a changed piece asks for its reload.
        ns.ToggleChanged()
    elseif cmd == "textures" then
        if arg == "builtin" or arg == "bundled" then
            ns.db.textureSource = arg
            ns.Print("textures = " .. arg)
            ns.ApplyAll()
        else
            ns.Print("usage: /fcui textures builtin|bundled")
        end
    else
        -- cmd is lowercased but keys are camelCase; any boolean key matches.
        local key
        for name, value in pairs(ns.DB_DEFAULTS) do
            if type(value) == "boolean" and name:lower() == cmd then key = name break end
        end
        if key then SetBool(key, arg) else Help() end
    end
end

ns.RegisterModule("options", { init = BuildSettings, apply = function() end, restore = function() end })
