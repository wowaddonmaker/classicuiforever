local _, ns = ...

local TITLE = "ClassicUI Forever"

-- key, label, tooltip
local TOGGLES = {
    { "classicBar", "Classic main menu bar", "The 1.x bar: stone band and gryphons centered at the bottom, with the action buttons, page arrows, micro buttons, bags and experience bar in their 2004 spots." },
    { "questMapPane", "Classic map quest pane", "The quest list the map opens on its right, in the quest log's manner: the dark list with plus and minus headers, 1.x difficulty colours and the old check, and a quest's details on parchment." },
    { "gameMenu", "Classic game menu", "The Escape menu as the old dialog box: the header plate and the compact red buttons with yellow labels." },
    { "settingsPanel", "Classic settings window", "The settings window as the old options dialog: the dialog box and header plate, the category list and page in thin-bordered insets, the blue bar under the chosen category, and the old check boxes, sliders, drop downs, arrows, scroll bars, tabs and red buttons." },
    { "buttons", "Classic button style", "Square slot borders, red attack flash and the old pressed and highlight art." },
    { "squareIcons", "Square icons", "Remove the rounded icon mask so icons are square like 1.x." },
    { "hideExtraBars", "Hide bars 6 to 8", "1.x had five action bars. Bars 6, 7 and 8 are faded out and stop taking clicks; their keybinds still work. Turn this off to place them with edit mode." },
    { "emptySlots", "Hide empty side bar slots", "Like 1.x, empty buttons on the extra bars stay hidden until you drag a spell, whatever the Always Show Buttons setting says." },
    { "unitFrames", "Classic unit frames", "Player, target, focus, target of target, pet and party frames with the 1.x art, bars and layout. Turning this off takes full effect after /reload." },
    { "unitFramePlayer", "Classic player frame", "The player frame with the old art, portrait, level circle and bars. Needs Classic unit frames on.", parent = "unitFrames" },
    { "unitFrameTarget", "Classic target frame", "The target frame and its target of target with the old art and bars. Needs Classic unit frames on.", parent = "unitFrames" },
    { "unitFrameFocus", "Classic focus frame", "The focus frame with the old art and bars. Needs Classic unit frames on.", parent = "unitFrames" },
    { "unitFramePet", "Classic pet frame", "The pet frame with the old art and bars. Needs Classic unit frames on.", parent = "unitFrames" },
    { "unitFrameParty", "Classic party frames", "The party frames with the old art, portraits and bars. Needs Classic unit frames on.", parent = "unitFrames" },
    { "castBars", "Classic cast bars", "The 1.x cast bar border, spark, flash and colours on the player, pet, target, focus and boss bars." },
    { "combatNumbers", "Classic damage numbers", "The old damage numbers over the mob you hit: melee white, spells yellow, crits bigger with the pop, floating up and fading. Turns enemy nameplates on (V), the only way an addon can find a mob on screen; press V to hide them again and the game's own numbers take over until they are back. Anything hitting the mob shows, not only you; the client no longer tells addons who hit." },
    { "welcomeNote", "Welcome note", "Shows the welcome note the first time a character logs in with the addon (on Forever, as a chat link). Turn off to never see it." },
    { "comboPoints", "Classic combo points", "Five orbs curving down the right side of the target portrait, lit as combo points are earned, the way rogues and cat druids saw them in 1.x. Retail's display under the player frame is hidden." },
    { "minimapButton", "Minimap button", "A small button on the minimap ring that opens this options window. Drag it around the ring." },
    { "minimap", "Classic minimap", "The round 1.x minimap ring with the zone name across the top and the old tracking, zoom, mail and clock spots." },
    { "namePlates", "Classic nameplates", "The 1.x plate drawn from the old sheet at its old size: the rounded border with the level in its slot, the shaded bar inside it, the name above, and the cast bar underneath. Turning this off takes full effect after /reload." },
    { "fullPlates", "No simplified nameplates", "1.x had no cut-down plates. Friendly players and NPCs, minions and minor mobs get the full plate instead of the game's reduced one that only grows when targeted. Turning this off puts your simplified nameplate setting back." },
    { "questLog", "Classic quest log", "The 1.x quest log in its own window: the book, the quest count, the All tab, Track Quest, the list over the parchment detail, and Abandon, Share and Exit. The quest button, the quest log key and quest clicks in the tracker open it instead of the map's quest panel." },
    { "questLogDual", "Double-pane quest log", "The classic quest log as the wider 3.x window: the list on the left, the quest on the parchment beside it, Show Map at the top and Abandon, Share, Track and Close along the foot. Off is the 1.x single pane.", parent = "questLog" },
    { "questTracker", "Classic quest tracker", "The old stone module headers and small collapse buttons on the objective tracker, and the parchment quest log background." },
    { "bags", "Classic bags", "The 1.x bag windows: the old bag sheet with the portrait ring, name strip and slot cells, the backpack's money strip, slots on the old grid with the old slot border. The combined bag window keeps the modern look; 1.x had no such window. Turning this off takes full effect after /reload." },
    { "characterSheet", "Classic character sheet", "The 1.x character window: the old art, slots down the sides with the weapons underneath, the model with its rotate buttons, the attribute and attack stat boxes, the five resistances and the bottom tabs. Turning this off takes full effect after /reload." },
    { "spellBook", "Classic spellbook", "The 1.x parchment spellbook: twelve spells a page with name and rank beside each icon, school tabs down the right edge, page arrows and a pet tab. Opens from the micro button, the keybind and /spellbook; talents still use the modern window." },
    { "panels", "Classic window frames", "The old metal border with the round portrait, the small X close button, the stone title strip and character-sheet tabs on the character, inspect, merchant, mail, friends, quest, trade, bank and other windows." },
}

ns.TOGGLES = TOGGLES

local category

local LAYOUT_NAME = "ClassicUI Forever"

-- A fresh edit mode layout for the classic look, built from Blizzard's own
-- "Classic" preset with twelve icons on every bar and the empty slot grid
-- off. It is added beside the user's existing layouts and selected, so
-- nothing of theirs is overwritten: keybinds live outside edit mode, and
-- their old layout stays in the edit mode dropdown to switch back to.
function ns.CreateClassicLayout()
    if InCombatLockdown() then
        ns.Print("cannot change layouts in combat")
        return
    end
    local mgr = EditModeManagerFrame
    if not mgr or not mgr.MakeNewLayout or not mgr.GetLayouts or not EditModePresetLayoutManager then
        ns.Print("edit mode layouts are not available on this client")
        return
    end
    for index, layout in ipairs(mgr:GetLayouts()) do
        if layout.layoutName == LAYOUT_NAME and layout.layoutType ~= Enum.EditModeLayoutType.Preset then
            mgr:SelectLayout(index)
            ns.Print("switched to your existing " .. LAYOUT_NAME .. " layout")
            ns.QueueApply()
            -- The layout applies on the next frame; then the frames move.
            C_Timer.After(0.5, function() if ns.ApplyClassicFrameSpots then ns.ApplyClassicFrameSpots() end end)
            return
        end
    end
    if mgr.AreLayoutsFullyMaxed and mgr:AreLayoutsFullyMaxed() then
        ns.Print("you already have the maximum number of edit mode layouts; delete one in edit mode first")
        return
    end
    local presets = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
    local classicIndex = (Enum.EditModePresetLayouts and Enum.EditModePresetLayouts.Classic) or 2
    local base = presets and (presets[classicIndex] or presets[1])
    if not base then
        ns.Print("no preset layout to copy")
        return
    end
    local CHAT_X, CHAT_Y = 35, 145
    for _, system in ipairs(base.systems or {}) do
        -- The chat frame goes where 1.x kept it, above the bottom bars and
        -- the pet row. The Forever client's own preset already puts it
        -- there; retail's leaves it 50px up, across bars 2 and 3.
        if system.system == Enum.EditModeSystem.ChatFrame and type(system.anchorInfo) == "table" then
            local info = system.anchorInfo
            if info.point == "BOTTOMLEFT" and (info.offsetY or 0) < CHAT_Y then
                info.relativeTo = "UIParent"
                info.relativePoint = "BOTTOMLEFT"
                info.offsetX = CHAT_X
                info.offsetY = CHAT_Y
                system.isInDefaultPosition = false
            end
        end
        -- Player frame in the top left corner, target just right of it,
        -- where 1.x put them. The Forever client's own layouts drop both
        -- to the bottom corners, so the anchors are written as placed.
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
        -- Bar 1 stays in its default (managed) position: the band then
        -- centres itself and places the bar inside it. Writing an anchor
        -- here does not survive the save, Blizzard rewrites it from the
        -- frame's live position, which left the band shifted right.
        if system.system == Enum.EditModeSystem.ActionBar and type(system.settings) == "table" then
            for key, entry in pairs(system.settings) do
                if type(entry) == "table" and entry.setting then
                    if entry.setting == Enum.EditModeActionBarSetting.NumIcons then entry.value = 12 end
                    if entry.setting == Enum.EditModeActionBarSetting.AlwaysShowButtons then entry.value = 0 end
                elseif key == Enum.EditModeActionBarSetting.NumIcons then
                    system.settings[key] = 12
                elseif key == Enum.EditModeActionBarSetting.AlwaysShowButtons then
                    system.settings[key] = 0
                end
            end
        end
    end
    -- MakeNewLayout relies on bookkeeping that only exists once the edit
    -- mode dropdown has been built; build it, or insert the layout ourselves.
    if not mgr.highestLayoutIndexByType and mgr.UpdateDropdownOptions then pcall(mgr.UpdateDropdownOptions, mgr) end
    if mgr.highestLayoutIndexByType then
        mgr:MakeNewLayout(base, Enum.EditModeLayoutType.Account, LAYOUT_NAME, false)
    else
        local layouts = mgr:GetLayouts()
        local index
        for i, layout in ipairs(layouts) do
            if layout.layoutType == Enum.EditModeLayoutType.Account then index = i end
        end
        index = (index or (Enum.EditModePresetLayoutsMeta and Enum.EditModePresetLayoutsMeta.NumValues or 2)) + 1
        base.layoutType = Enum.EditModeLayoutType.Account
        base.layoutName = LAYOUT_NAME
        table.insert(layouts, index, base)
        mgr:SaveLayouts()
        if C_EditMode and C_EditMode.OnLayoutAdded then C_EditMode.OnLayoutAdded(index, true, false) end
    end
    -- The layout table was built by addon code, so the game treats every
    -- read of it as tainted until the layouts are loaded fresh; a reload
    -- does that (Blizzard's own dialog builds its table in secure code).
    ns.Print("created the " .. LAYOUT_NAME .. " edit mode layout")
    ns.db.layoutPrompted = true
    -- The game does not always switch to a layout an addon added (the
    -- dev log showed the previous layout still active after the reload),
    -- so the next login selects it by name.
    ns.db.layoutSelectPending = true
    -- Reload needs a click behind it; a timer is not allowed to do it.
    StaticPopup_Show("FCUI_RELOAD")
end

StaticPopupDialogs["FCUI_RELOAD"] = {
    text = TITLE .. "\n\nThe classic layout is saved. Reload the interface to finish switching to it.",
    button1 = "Reload now",
    button2 = "Later",
    OnAccept = function() if C_UI and C_UI.Reload then C_UI.Reload() end end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

-- First time in with the addon: one question. Set up the classic layout
-- (a new edit mode layout beside the existing ones) or keep what is there.
StaticPopupDialogs["FCUI_FIRST_LOGIN"] = {
    text = TITLE .. "\n\nSet up the classic layout now? This adds an edit mode layout named \"" .. LAYOUT_NAME .. "\" with everything in its 1.x place and switches to it. Your current layout and keybinds are untouched, and it stays in the edit mode list.",
    button1 = "Set up classic layout",
    button2 = "Keep my layout",
    OnAccept = function() ns.CreateClassicLayout() end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

-- After the reload that follows creating the layout: make it the active
-- one if the game left the old layout selected.
function ns.SelectClassicLayoutIfPending()
    if not ns.db or not ns.db.layoutSelectPending then return end
    local mgr = EditModeManagerFrame
    if not mgr or not mgr.GetLayouts or not mgr.SelectLayout or InCombatLockdown() then return end
    ns.db.layoutSelectPending = nil
    local active = mgr.GetActiveLayoutInfo and mgr:GetActiveLayoutInfo()
    if active and active.layoutName == LAYOUT_NAME then return end
    for index, layout in ipairs(mgr:GetLayouts()) do
        if layout.layoutName == LAYOUT_NAME and layout.layoutType ~= Enum.EditModeLayoutType.Preset then
            mgr:SelectLayout(index)
            ns.Print("switched to the " .. LAYOUT_NAME .. " layout")
            ns.QueueApply()
            C_Timer.After(0.5, function() if ns.ApplyClassicFrameSpots then ns.ApplyClassicFrameSpots() end end)
            return
        end
    end
end

-- Player frame in the top left corner, target just right of it, written
-- into the active layout the way edit mode records a drag: anchor the
-- frame, let the manager read the anchor into the layout, save. Only
-- on the addon's own layout, and only from the layout button, so a
-- frame the player moved on purpose stays put between logins.
-- The focus frame goes under the target with a gap, where the old
-- addons of the day put it (1.x had no focus frame).
local FRAME_SPOTS = { { "PlayerFrame", 4, -4 }, { "TargetFrame", 250, -2 }, { "FocusFrame", 250, -165 } }
function ns.ApplyClassicFrameSpots()
    if InCombatLockdown() or not ns.ClassicLayoutActive() then return false end
    local mgr = EditModeManagerFrame
    if not mgr or not mgr.UpdateSystemAnchorInfo or not mgr.SaveLayouts then return false end
    local changed = false
    for _, spot in ipairs(FRAME_SPOTS) do
        local frame = _G[spot[1]]
        if frame and frame.system then
            -- Anchor offsets are in the frame's own scale; the focus frame
            -- is drawn smaller than the others, so the 1.x spots, which
            -- are screen numbers, are divided by it.
            local scale = frame:GetScale()
            if not scale or scale <= 0 then scale = 1 end
            local wantX, wantY = spot[2] / scale, spot[3] / scale
            local point, rel, relPoint, x, y = frame:GetPoint(1)
            local there = point == "TOPLEFT" and rel == UIParent and relPoint == "TOPLEFT"
                and math.abs((x or 0) - wantX) < 0.5 and math.abs((y or 0) - wantY) < 0.5
            if not there then
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", wantX, wantY)
                if mgr:UpdateSystemAnchorInfo(frame) then changed = true end
            end
        end
    end
    if changed then
        mgr:SaveLayouts()
        ns.Print("player, target and focus frames moved to their 1.x spots")
    end
    return true
end

-- Whether the active edit mode layout is the addon's own.
function ns.ClassicLayoutActive()
    local mgr = EditModeManagerFrame
    local info = mgr and mgr.GetActiveLayoutInfo and mgr:GetActiveLayoutInfo()
    return info ~= nil and info.layoutName == LAYOUT_NAME
end

function ns.CheckLayoutPosition()
    if not ns.db or not ns.db.classicBar then return end
    ns.db.layoutWarned = nil
    if ns.db.layoutPrompted then return end
    local mgr = EditModeManagerFrame
    local info = mgr and mgr.GetActiveLayoutInfo and mgr:GetActiveLayoutInfo()
    -- Layouts made under the addon's earlier display name still count.
    if info and info.layoutName == LAYOUT_NAME then
        ns.db.layoutPrompted = true
        return
    end
    ns.db.layoutPrompted = true
    StaticPopup_Show("FCUI_FIRST_LOGIN")
end

local function BuildSettings()
    if not Settings or not Settings.RegisterVerticalLayoutCategory or not Settings.RegisterAddOnSetting then return end
    local cat = Settings.RegisterVerticalLayoutCategory(TITLE)

    local function Checkbox(key, label, tooltip)
        local setting = Settings.RegisterAddOnSetting(cat, "FCUI_" .. key, key, ns.db, Settings.VarType.Boolean, label, ns.DB_DEFAULTS[key])
        setting:SetValueChangedCallback(ns.QueueApply)
        Settings.CreateCheckbox(cat, setting, tooltip)
    end

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

    if CreateSettingsButtonInitializer and SettingsPanel and SettingsPanel.GetLayout then
        local layout = SettingsPanel:GetLayout(cat)
        if layout and layout.AddInitializer then
            layout:AddInitializer(CreateSettingsButtonInitializer("Classic edit mode layout", "Create and select", ns.CreateClassicLayout,
                "Adds a new edit mode layout named " .. LAYOUT_NAME .. " built from the game's Classic preset (twelve icons on every bar, no empty slot grid, chat above the bars, player and target frames in the top left) and switches to it. Your current layout and keybinds are left untouched; switch back any time from the edit mode dropdown.", true))
        end
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
    for _, entry in ipairs(TOGGLES) do
        ns.Print("  /fcui " .. entry[1] .. " on|off - " .. entry[2])
    end
    ns.Print("  /fcui textures builtin|bundled - where the art is read from")
    ns.Print("  /fcui status - current settings")
    ns.Print("  /fcui debug - client and frame details for bug reports")
    ns.Print("  /fcui layout - create and select a fresh classic edit mode layout")
    ns.Print("  /fcui prompt - show the first-login layout question again")
    ns.Print("  /fcui welcome - show the welcome note again")
    ns.Print("  /fcui reset - restore defaults")
end

local function Status()
    ns.Print("textures: " .. ns.db.textureSource)
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
    if cmd == "settings" then
        ns.OpenBlizzardSettings()
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
    elseif cmd == "layout" then
        ns.CreateClassicLayout()
    elseif cmd == "welcome" then
        ns.ShowWelcome()
    elseif cmd == "dev" then
        -- Not listed in help: forget the first-run state so the next
        -- reload runs as a fresh install (welcome, then the layout question).
        ns.db.welcomed = false
        ns.db.layoutPrompted = nil
        ns.Print("first-run state cleared; the next reload shows the welcome and the layout question")
        if arg == "reload" and C_UI and C_UI.Reload then C_UI.Reload() end
    elseif cmd == "prompt" then
        -- Show the first-login question again (testing, or a second look).
        ns.db.layoutPrompted = nil
        StaticPopup_Show("FCUI_FIRST_LOGIN")
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
