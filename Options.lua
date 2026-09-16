local _, ns = ...

local TITLE = "Forever Classic UI"

-- key, label, tooltip
local TOGGLES = {
    { "endCaps", "Classic gryphons", "Replace the end cap art with the original gryphons." },
    { "barArt", "Stone bar background", "Draw the original stone band behind the main bar, micro menu and bags." },
    { "hideModernBorders", "Hide modern bar borders", "Fade the modern frame art around the main bar, micro menu and bags." },
    { "buttons", "Classic button style", "Square slot borders, red attack flash and the old pressed and highlight art." },
    { "squareIcons", "Square icons", "Remove the rounded icon mask so icons are square like 1.x." },
    { "pageArrows", "Classic page arrows", "Use the original stone scroll arrows for action bar paging." },
}

local category

local function BuildSettings()
    if not Settings or not Settings.RegisterVerticalLayoutCategory or not Settings.RegisterAddOnSetting then return end
    local cat = Settings.RegisterVerticalLayoutCategory(TITLE)

    local function Checkbox(key, label, tooltip)
        local setting = Settings.RegisterAddOnSetting(cat, "FCUI_" .. key, key, ns.db, Settings.VarType.Boolean, label, ns.DB_DEFAULTS[key])
        setting:SetValueChangedCallback(ns.QueueApply)
        Settings.CreateCheckbox(cat, setting, tooltip)
    end

    Checkbox("enabled", "Enable " .. TITLE, "Master switch. Disabling restores the modern art without a reload where possible.")
    for _, entry in ipairs(TOGGLES) do
        Checkbox(entry[1], entry[2], entry[3])
    end

    local function TextureOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("builtin", "Game client files")
        container:Add("bundled", "Bundled copies")
        return container:GetData()
    end
    local source = Settings.RegisterAddOnSetting(cat, "FCUI_textureSource", "textureSource", ns.db, Settings.VarType.String, "Texture source", ns.DB_DEFAULTS.textureSource)
    source:SetValueChangedCallback(ns.QueueApply)
    Settings.CreateDropdown(cat, source, TextureOptions, "Where the classic art is read from. Switch to bundled copies if the client no longer ships the originals.")

    Settings.RegisterAddOnCategory(cat)
    category = cat
end

function ns.OpenOptions()
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    else
        ns.Print("Use /fcui help for commands.")
    end
end

local function Help()
    ns.Print("commands:")
    ns.Print("  /fcui - open options")
    ns.Print("  /fcui on|off - master switch")
    for _, entry in ipairs(TOGGLES) do
        ns.Print("  /fcui " .. entry[1] .. " on|off - " .. entry[2])
    end
    ns.Print("  /fcui textures builtin|bundled - where the art is read from")
    ns.Print("  /fcui status - current settings")
    ns.Print("  /fcui debug - client and frame details for bug reports")
    ns.Print("  /fcui reset - restore defaults")
end

local function Status()
    ns.Print("enabled: " .. tostring(ns.db.enabled) .. ", textures: " .. ns.db.textureSource)
    for _, entry in ipairs(TOGGLES) do
        ns.Print("  " .. entry[1] .. " = " .. tostring(ns.db[entry[1]]))
    end
end

local function FrameInfo(frame)
    if not frame then return "missing" end
    if not frame:GetLeft() then return "shown=" .. tostring(frame:IsShown()) .. " (no rect yet)" end
    return string.format("shown=%s w=%.0f h=%.0f left=%.0f bottom=%.0f scale=%.2f",
        tostring(frame:IsShown()), frame:GetWidth(), frame:GetHeight(), frame:GetLeft(), frame:GetBottom(), frame:GetEffectiveScale())
end

local function Debug()
    local version, build, _, toc = GetBuildInfo()
    ns.Print(string.format("client %s (%s) toc %s project %s", version, build, tostring(toc), tostring(WOW_PROJECT_ID)))
    local bar = ns.GetMainBar()
    ns.Print("main bar: " .. (bar and bar:GetName() or "none") .. ", end caps: " .. ns.EndCapShape())
    ns.Print("bar " .. FrameInfo(bar))
    ns.Print("micro " .. FrameInfo(MicroMenuContainer or MicroMenu))
    ns.Print("bags " .. FrameInfo(BagsBar))
    local ab1 = bar and bar.actionButtons and bar.actionButtons[1] or ActionButton1
    ns.Print("button1 " .. FrameInfo(ab1))
    local keys = {}
    for key in pairs(ns.TEX) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        ns.Print("  tex " .. key .. ": " .. (ns.texStatus[key] or "unused"))
    end
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
    local function SetBool(key, value)
        if value == "on" or value == "true" or value == "1" then
            ns.db[key] = true
        elseif value == "off" or value == "false" or value == "0" then
            ns.db[key] = false
        else
            ns.db[key] = not ns.db[key]
        end
        ns.Print(key .. " = " .. tostring(ns.db[key]))
        ns.ApplyAll()
    end
    if cmd == "on" or cmd == "off" then
        SetBool("enabled", cmd)
    elseif cmd == "help" then
        Help()
    elseif cmd == "status" then
        ns.BeginOutput("status")
        Status()
        ns.FlushNotice()
    elseif cmd == "debug" then
        ns.BeginOutput("debug")
        Debug()
        ns.FlushNotice()
    elseif cmd == "reset" then
        wipe(ns.db)
        for k, v in pairs(ns.DB_DEFAULTS) do ns.db[k] = v end
        ns.Print("defaults restored")
        ns.ApplyAll()
    elseif cmd == "textures" then
        if arg == "builtin" or arg == "bundled" then
            ns.db.textureSource = arg
            ns.Print("textures = " .. arg)
            ns.ApplyAll()
        else
            ns.Print("usage: /fcui textures builtin|bundled")
        end
    elseif type(ns.DB_DEFAULTS[cmd]) == "boolean" then
        SetBool(cmd, arg)
    else
        Help()
    end
end

ns.RegisterModule("options", { init = BuildSettings, apply = function() end, restore = function() end })
