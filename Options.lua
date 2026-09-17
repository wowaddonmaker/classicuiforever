local _, ns = ...

local TITLE = "Forever Classic UI"

-- key, label, tooltip
local TOGGLES = {
    { "classicBar", "Classic main menu bar", "The 1.x bar: stone band and gryphons centered at the bottom, with the action buttons, page arrows, micro buttons, bags and experience bar in their 2004 spots." },
    { "buttons", "Classic button style", "Square slot borders, red attack flash and the old pressed and highlight art." },
    { "squareIcons", "Square icons", "Remove the rounded icon mask so icons are square like 1.x." },
    { "pageArrows", "Classic page arrows", "Use the original stone scroll arrows for action bar paging." },
    { "emptySlots", "Hide empty side bar slots", "Like 1.x, empty buttons on the extra bars stay hidden until you drag a spell, whatever the Always Show Buttons setting says." },
    { "unitFrames", "Classic unit frames", "Player, target, focus, target of target, pet and party frames with the 1.x art, bars and layout. Turning this off takes full effect after /reload." },
    { "castBars", "Classic cast bars", "The 1.x cast bar border, spark, flash and colours on the player, pet, target, focus and boss bars." },
    { "minimap", "Classic minimap", "The round 1.x minimap ring with the zone name across the top and the old tracking, zoom, mail and clock spots." },
    { "namePlates", "Classic nameplates", "Flat health bars with a thin dark edge and an outlined white name, the way 1.x drew them." },
    { "questTracker", "Classic quest tracker", "The old stone module headers and small collapse buttons on the objective tracker, and the parchment quest log background." },
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
    ns.Print("main bar: " .. (bar and bar:GetName() or "none") .. ", classic bar: " .. ns.ClassicBarInfo())
    ns.Print("bar " .. FrameInfo(bar))
    ns.Print("micro " .. FrameInfo(MicroMenuContainer or MicroMenu))
    ns.Print("bags " .. FrameInfo(BagsBar))
    local ab1 = bar and bar.actionButtons and bar.actionButtons[1] or ActionButton1
    ns.Print("button1 " .. FrameInfo(ab1))
    if bar then
        local parent = bar:GetParent()
        ns.Print(string.format("bar strata %s level %d alpha %.2f visible %s parent %s hideBarArt %s",
            bar:GetFrameStrata(), bar:GetFrameLevel(), bar:GetAlpha(), tostring(bar:IsVisible()), parent and parent:GetName() or "?", tostring(bar.hideBarArt)))
    end
    if ab1 then
        local normal = ab1:GetNormalTexture()
        ns.Print(string.format("button1 normal tex %s %s alpha %.2f layer %s; slotArt alpha %s; icon masks %s",
            tostring(normal and normal:GetTexture()), normal and FrameInfo(normal) or "none", normal and normal:GetAlpha() or 0,
            tostring(normal and normal:GetDrawLayer()), tostring(ab1.SlotArt and ab1.SlotArt:GetAlpha()),
            tostring(ab1.icon and ab1.icon.GetNumMaskTextures and ab1.icon:GetNumMaskTextures())))
    end
    local keys = {}
    for key in pairs(ns.TEX) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local status = ns.texStatus[key]
        if status and status ~= "ok" then ns.Print("  tex " .. key .. ": " .. status) end
    end
    local missing = {}
    for name in pairs(ns.missing or {}) do missing[#missing + 1] = name end
    table.sort(missing)
    ns.Print("missing pieces: " .. (#missing > 0 and table.concat(missing, ", ") or "none"))
    local function Level(frame)
        if not frame then return "missing" end
        return string.format("%s L%d %s", frame:GetFrameStrata(), frame:GetFrameLevel(), FrameInfo(frame))
    end
    for _, name in ipairs({ "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "MinimapCluster", "Minimap", "MinimapBackdrop", "PlayerCastingBarFrame",
        "CharacterMicroButton", "MainMenuMicroButton", "MainMenuBarBackpackButton", "CharacterBag0Slot", "QueueStatusButton", "GameTimeFrame", "TimeManagerClockButton" }) do
        ns.Print(name .. " " .. Level(_G[name]))
    end
    ns.Print("tracking " .. Level(MinimapCluster and MinimapCluster.Tracking) .. " button " .. Level(MinimapCluster and MinimapCluster.Tracking and MinimapCluster.Tracking.Button))
    ns.Print("zoomIn " .. Level(Minimap and Minimap.ZoomIn) .. " mail " .. Level(MinimapCluster and MinimapCluster.IndicatorFrame))
    local art = ForeverClassicUIBar
    ns.Print("art " .. Level(art) .. " pn " .. Level(bar and bar.ActionBarPageNumber) .. " up " .. Level(bar and bar.ActionBarPageNumber and bar.ActionBarPageNumber.UpButton))
    local host = PlayerFrame and PlayerFrame.fcui and PlayerFrame.fcui.host
    local power = host and host.fcui and host.fcui.power
    if power then
        local r, g, b = power:GetStatusBarColor()
        local tex = power:GetStatusBarTexture()
        ns.Print(string.format("our power bar color %.2f %.2f %.2f value %s of %s tex %s shown %s %s", r or -1, g or -1, b or -1,
            tostring(power:GetValue()), tostring(select(2, power:GetMinMaxValues())), tostring(tex and tex:GetTexture()), tostring(power:IsShown()), FrameInfo(power)))
        local ptype, token = UnitPowerType("player")
        ns.Print("player power type " .. tostring(ptype) .. " token " .. tostring(token) .. " secret " .. tostring(issecretvalue and issecretvalue(token)))
        local main = PlayerFrame.PlayerFrameContent and PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
        ns.Print("blizz mana area alpha " .. tostring(main and main.ManaBarArea and main.ManaBarArea:GetAlpha()) .. " alt power shown " .. tostring(main and main.AlternatePowerBarArea and main.AlternatePowerBarArea:IsShown()))
    end
    local ftex = PlayerFrame and PlayerFrame.PlayerFrameContainer and PlayerFrame.PlayerFrameContainer.FrameTexture
    ns.Print("player frame texture " .. tostring(ftex and ftex:GetTexture()) .. " atlas " .. tostring(ftex and ftex:GetAtlas()) .. " " .. (ftex and FrameInfo(ftex) or ""))
    if ns.needsReload then ns.Print("a module was turned off; /reload to clear its art fully") end
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
    elseif cmd == "hit" then
        -- What is under the cursor right now: hover a dead button, then run this.
        ns.BeginOutput("hit")
        local foci = GetMouseFoci and GetMouseFoci() or { GetMouseFocus and GetMouseFocus() }
        if #foci == 0 then ns.Print("nothing under the cursor") end
        for _, frame in ipairs(foci) do
            local parent = frame.GetParent and frame:GetParent()
            ns.Print(string.format("%s strata %s level %d mouse %s parent %s %s", frame:GetName() or frame:GetDebugName() or "?",
                frame:GetFrameStrata(), frame:GetFrameLevel(), tostring(frame:IsMouseEnabled()),
                parent and (parent:GetName() or parent:GetDebugName()) or "none", FrameInfo(frame)))
        end
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
