local _, ns = ...

local TITLE = "ClassicUI Forever"

-- key, label, tooltip
local TOGGLES = {
    { "classicBar", "Classic main menu bar", "The 1.x bar: stone band and gryphons centered at the bottom, with the action buttons, page arrows, micro buttons, bags and experience bar in their 2004 spots." },
    { "oneBar", "One bar", "The band stops after the twelve main slots, the right gryphon beside them and the experience bar the same width. The bottom right bar, the micro menu and the bags stay where edit mode puts them.", parent = "classicBar" },
    { "questMapPane", "Classic map quest pane", "The quest list the map opens on its right, in the quest log's manner: the dark list with plus and minus headers, 1.x difficulty colors and the old check, and a quest's details on parchment." },
    { "gameMenu", "Classic game menu", "The Escape menu as the old dialog box: the header plate and the compact red buttons with yellow labels." },
    { "settingsPanel", "Classic settings window", "The settings window as the old options dialog: the dialog box and header plate, the category list and page in thin-bordered insets, the blue bar under the chosen category, and the old check boxes, sliders, drop downs, arrows, scroll bars, tabs and red buttons." },
    { "buttons", "Classic button style", "Square slot borders, red attack flash and the old pressed and highlight art." },
    { "squareIcons", "Square icons", "Remove the rounded icon mask so icons are square like 1.x." },
    { "castAnim", "No cast animation on buttons", "1.x played nothing over a button while its spell was casting. The animation the game draws across the icon is taken off and the cooldown swipe under it stays solid." },
    { "hideExtraBars", "Hide bars 6 to 8", "1.x had five action bars. Bars 6, 7 and 8 are faded out and stop taking clicks; their keybinds still work. Turn this off to place them with edit mode." },
    { "emptySlots", "Hide empty side bar slots", "Like 1.x, empty buttons on the extra bars stay hidden until you drag a spell, whatever the Always Show Buttons setting says." },
    { "unitFrames", "Classic unit frames", "Player, target, focus, target of target, pet and party frames with the 1.x art, bars and layout. Turning this off takes full effect after /reload." },
    { "unitFramePlayer", "Classic player frame", "The player frame with the old art, portrait, level circle and bars. Needs Classic unit frames on.", parent = "unitFrames" },
    { "unitFrameTarget", "Classic target frame", "The target frame and its target of target with the old art and bars. Needs Classic unit frames on.", parent = "unitFrames" },
    { "unitFrameFocus", "Classic focus frame", "The focus frame with the old art and bars. Needs Classic unit frames on.", parent = "unitFrames" },
    { "unitFramePet", "Classic pet frame", "The pet frame with the old art and bars. Needs Classic unit frames on.", parent = "unitFrames" },
    { "unitFrameParty", "Classic party frames", "The party frames with the old art, portraits and bars. Needs Classic unit frames on.", parent = "unitFrames" },
    { "mirrorTimers", "Classic breath and fatigue bars", "The breath, fatigue and feign death timers drawn as 1.x drew them: the old cast bar border around a plain bar, blue for breath and yellow while you are tiring, with the label written on the bar rather than on a plate." },
    { "castBars", "Classic cast bars", "The 1.x cast bar border, spark, flash and colors on the player, pet, target, focus and boss bars." },
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
    { "classColorHealth", "Class colored unit frames", "The player and target health bars take the unit's class color instead of the old green. Only players are colored; everything else stays green.", parent = "unitFrames" },
    { "classColorPlates", "Class colored nameplates", "A player's nameplate health bar takes their class color. Everything else keeps the color the game gives it.", parent = "namePlates" },
    { "mapFade", "Fade map while moving", "The map dims itself while you move, which is the game's own mapFade setting. Off, it stays solid." },
    { "hideLastNames", "Hide last names", "The Forever client gives characters a last name and draws it under the first. This turns every surname setting off; the game's own box for it stays in step, so putting surnames back there turns this off." },
    { "whoList", "Classic who list", "The 1.x Who tab on the social window: names, zone, level and class in sortable columns, with Refresh, Add Friend and Group Invite along the foot. A /who answers into it rather than the client's own window, and the tabs read Friends, Who, Guild as they did." },
    { "guildRoster", "Classic guild roster", "The guild tab the 1.x Friends window carried: the member count, the guild message, and the roster in four sortable columns with the old buttons along the foot. The modern guild window stays reachable." },
    { "spellBook", "Classic spellbook", "The 1.x parchment spellbook: twelve spells a page with name and rank beside each icon, school tabs down the right edge, page arrows and a pet tab. Opens from the micro button, the keybind and /spellbook; talents still use the modern window." },
    { "spellBookSearch", "Spellbook search box", "A search box on the book: type, and every known spell whose name holds the words is listed, across the tabs.", parent = "spellBook" },
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
-- The layout is the client's, not ours: it stays selected when this
-- addon is turned off and after it is removed, and a player who took
-- the offer and then changed their mind has no obvious way back. So the
-- one they were on is written down before the switch.
local function RememberLayout()
    local mgr = EditModeManagerFrame
    local info = mgr and mgr.GetActiveLayoutInfo and mgr:GetActiveLayoutInfo()
    if info and info.layoutName and info.layoutName ~= LAYOUT_NAME then
        ns.db.previousLayout = info.layoutName
    end
end

-- Back to the layout they were on before the classic one.
function ns.RestorePreviousLayout()
    if InCombatLockdown() then
        ns.Print("cannot change layouts in combat")
        return false
    end
    local mgr = EditModeManagerFrame
    local wanted = ns.db and ns.db.previousLayout
    if not wanted then
        ns.Print("no earlier layout written down; pick one in edit mode")
        return false
    end
    if not mgr or not mgr.GetLayouts or not mgr.SelectLayout then
        ns.Print("edit mode layouts are not available on this client")
        return false
    end
    for index, layout in ipairs(mgr:GetLayouts()) do
        if layout.layoutName == wanted then
            mgr:SelectLayout(index)
            ns.Print("switched back to " .. wanted)
            ns.db.previousLayout = nil
            C_Timer.After(0.5, function() StaticPopup_Show("FCUI_LAYOUT_DONE") end)
            return true
        end
    end
    ns.Print("the " .. wanted .. " layout is gone; pick one in edit mode")
    return false
end

function ns.CreateClassicLayout()
    if InCombatLockdown() then
        ns.Print("cannot change layouts in combat")
        return
    end
    RememberLayout()
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
            -- The layout applies on the next frame; then the frames move
            -- and the interface reloads onto the client's own footing.
            C_Timer.After(0.5, function()
                if ns.ApplyClassicFrameSpots then ns.ApplyClassicFrameSpots() end
                StaticPopup_Show("FCUI_LAYOUT_DONE")
            end)
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
        -- centers itself and places the bar inside it. Writing an anchor
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

StaticPopupDialogs["FCUI_LAYOUT_DONE"] = {
    text = TITLE .. "\n\nThe classic layout is in place. Reload the interface to finish; until you do, the raid and party frames can throw errors.",
    button1 = "Reload now",
    button2 = "Later",
    OnAccept = function() if C_UI and C_UI.Reload then C_UI.Reload() end end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

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
    text = TITLE .. "\n\nSet up the classic layout now? This adds an edit mode layout named \"" .. LAYOUT_NAME .. "\" with everything in its 1.x place and switches to it. Your current layout and keybinds are untouched and stay in the edit mode list, and the options window can switch you back to the one you are on now.",
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
            -- Switching a layout lays every frame in it out again, the
            -- party and raid frames with it, and the client holds that
            -- whole pass against an addon for the rest of the session:
            -- those frames then report an error on every health change.
            -- A reload puts them back on the client's own footing, so
            -- the switch ends with one.
            C_Timer.After(0.5, function()
                if ns.ApplyClassicFrameSpots then ns.ApplyClassicFrameSpots() end
                StaticPopup_Show("FCUI_LAYOUT_DONE")
            end)
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
local FRAME_SPOTS = { { "PlayerFrame", 4, -4 }, { "TargetFrame", 250, -4 }, { "FocusFrame", 250, -165 } }
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
    if not Settings or not Settings.RegisterAddOnCategory then return end
    -- The addon's own panel is the page: the toggles in their columns
    -- with the search over them, rather than a list of check boxes.
    if Settings.RegisterCanvasLayoutCategory and ns.OptionsCanvas then
        local canvas = ns.OptionsCanvas()
        if canvas then
            local cat = Settings.RegisterCanvasLayoutCategory(canvas, TITLE)
            Settings.RegisterAddOnCategory(cat)
            category = cat
            return
        end
    end
    if not Settings.RegisterVerticalLayoutCategory or not Settings.RegisterAddOnSetting then return end
    local cat = Settings.RegisterVerticalLayoutCategory(TITLE)

    local function Checkbox(key, label, tooltip)
        local setting = Settings.RegisterAddOnSetting(cat, "FCUI_" .. key, key, ns.db, Settings.VarType.Boolean, label, ns.DB_DEFAULTS[key])
        setting:SetValueChangedCallback(function() ns.ToggleChanged(key) end)
        Settings.CreateCheckbox(cat, setting, tooltip)
    end

    for _, entry in ipairs(TOGGLES) do
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
    if ns.SpellBookBindInfo then ns.Print("spellbook in a fight: " .. ns.SpellBookBindInfo()) end
    -- Which windows this client lets an addon show while a fight is on.
    do
        local names = { "FriendsFrame", "ForeverClassicUISpellBook", "CharacterFrame", "PlayerSpellsFrame", "WorldMapFrame" }
        local parts = {}
        for _, name in ipairs(names) do
            local frame = _G[name]
            if frame then
                local protected = frame.IsProtected and frame:IsProtected()
                parts[#parts + 1] = string.format("%s protected=%s shown=%s", name, tostring(protected), tostring(frame:IsShown()))
            end
        end
        ns.Print("windows: " .. table.concat(parts, "; "))
        ns.Print("secure snippets usable: " .. tostring(loadstring_untainted ~= nil))
    end
    if ns.blocked and #ns.blocked > 0 then
        ns.Print("calls the client refused:")
        for _, hit in ipairs(ns.blocked) do
            ns.Print(string.format("  %s %s %s%s%s", hit.when, hit.event, hit.func,
                hit.combat and " (in combat)" or "", hit.editMode and " (edit mode)" or ""))
        end
    else
        ns.Print("calls the client refused: none")
    end
    if ns.needsReload then ns.Print("a module was turned off; /reload to clear its art fully") end
    if ns.SurnameSettings then
        local names = ns.SurnameSettings()
        if #names == 0 then
            ns.Print("surname settings: none on this client")
        else
            local parts = {}
            for _, name in ipairs(names) do
                local ok, value = pcall(C_CVar.GetCVar, name)
                parts[#parts + 1] = name .. "=" .. (ok and tostring(value) or "?")
            end
            ns.Print("surname settings: " .. table.concat(parts, ", "))
        end
        ns.Print("player name " .. tostring(UnitName("player")) .. " unmodified " ..
            tostring(UnitNameUnmodified and UnitNameUnmodified("player")))
        -- Where a surname is actually drawn: the API's word for the name
        -- beside the string each frame carries.
        local drawn = {
            { "player frame", PlayerName },
            { "target frame", ns.Path(TargetFrame, "TargetFrameContent", "TargetFrameContentMain", "Name") },
            { "target api", nil, "target" },
        }
        for _, entry in ipairs(drawn) do
            if entry[2] then
                ns.Print("  " .. entry[1] .. " draws " .. tostring(entry[2].GetText and entry[2]:GetText()))
            elseif entry[3] and UnitExists(entry[3]) then
                ns.Print("  " .. entry[1] .. " " .. tostring(UnitName(entry[3])) .. " unmodified " ..
                    tostring(UnitNameUnmodified and UnitNameUnmodified(entry[3])))
            end
        end
    end
end

-- Everything drawn on the band's own bars, for a look that does not
-- match the old one: which bars a container shows, what each fill is
-- worth and what color and art it wears, and the rested run over it.
local function Bars()
    local function Num(value)
        if value == nil then return "nil" end
        if issecretvalue and issecretvalue(value) then return "secret" end
        return tostring(value)
    end
    ns.Print(string.format("xp %s of %s exhaustion %s rest state %s", Num(UnitXP and UnitXP("player")),
        Num(UnitXPMax and UnitXPMax("player")), Num(GetXPExhaustion and GetXPExhaustion()), Num(GetRestState and GetRestState())))
    for _, name in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
        local container = _G[name]
        if not container then
            ns.Print(name .. ": missing")
        else
            ns.Print(string.format("%s %s bars %d", name, FrameInfo(container), #(container.bars or {})))
            for index, bar in pairs(container.bars or {}) do
                local status = bar.StatusBar
                local run = bar.ExhaustionLevelFillBar
                ns.Print(string.format("  bar %s shown=%s xp=%s %s", tostring(index), tostring(bar:IsShown()),
                    tostring(bar.ExhaustionTick ~= nil), FrameInfo(bar)))
                if status then
                    local r, g, b = status:GetStatusBarColor()
                    local fill = status:GetStatusBarTexture()
                    local minimum, maximum = status:GetMinMaxValues()
                    ns.Print(string.format("    fill %.2f %.2f %.2f value %s of %s..%s tex %s atlas %s kept %s rested %s %s",
                        r or -1, g or -1, b or -1, Num(status:GetValue()), Num(minimum), Num(maximum),
                        tostring(fill and fill:GetTexture()), tostring(fill and fill.GetAtlas and fill:GetAtlas()),
                        tostring(status.fcuiAtlas), tostring(status.fcuiRested), FrameInfo(status)))
                    for _, key in ipairs({ "Background", "Underlay", "Overlay", "GainFlareAnimationTexture", "LevelUpTexture" }) do
                        local piece = status[key]
                        if piece and piece.IsShown and piece:IsShown() and (piece:GetAlpha() or 0) > 0 then
                            ns.Print(string.format("    %s shown alpha %.2f tex %s", key, piece:GetAlpha(),
                                tostring(piece.GetTexture and piece:GetTexture())))
                        end
                    end
                end
                if run then
                    local r, g, b, a = run:GetVertexColor()
                    local layer, sub = run:GetDrawLayer()
                    ns.Print(string.format("    run shown=%s w=%.0f color %.2f %.2f %.2f a %.2f tex %s layer %s %s parent %s",
                        tostring(run:IsShown()), run:GetWidth() or 0, r or -1, g or -1, b or -1, a or -1,
                        tostring(run:GetTexture()), tostring(layer), tostring(sub),
                        tostring(run:GetParent() and run:GetParent():GetDebugName())))
                end
            end
        end
    end
end

-- What the client's own damage meter will tell an addon: whether our
-- own damage can be told from everyone else's, and whether the numbers
-- come back readable or held back. The old engine drew only your own
-- numbers over a mob, and the event this addon has says what a unit
-- took without saying who dealt it.
local function DamageSources()
    if not (C_DamageMeter and C_DamageMeter.GetCombatSessionFromType and Enum and Enum.DamageMeterSessionType) then
        ns.Print("no damage meter api on this client")
        return
    end
    if C_CombatLog and C_CombatLog.IsCombatLogRestricted then
        local ok, restricted = pcall(C_CombatLog.IsCombatLogRestricted)
        ns.Print("combat log restricted " .. (ok and tostring(restricted) or "?"))
    else
        ns.Print("no combat log api on this client")
    end
    local available, why = true, ""
    if C_DamageMeter.IsDamageMeterAvailable then
        local ok, yes, reason = pcall(C_DamageMeter.IsDamageMeterAvailable)
        if ok then available, why = yes, tostring(reason) end
    end
    ns.Print("damage meter available " .. tostring(available) .. " " .. why)
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType,
        Enum.DamageMeterSessionType.Current, Enum.DamageMeterType.DamageDone)
    if not ok or type(session) ~= "table" then
        ns.Print("no current session: " .. tostring(session))
        return
    end
    local function Show(value)
        if value == nil then return "nil" end
        if issecretvalue and issecretvalue(value) then return "<held back>" end
        return tostring(value)
    end
    ns.Print("session total " .. Show(session.totalAmount) .. " sources " .. tostring(#(session.combatSources or {})))
    for _, source in ipairs(session.combatSources or {}) do
        ns.Print(string.format("  %s mine=%s total=%s class=%s", Show(source.name),
            Show(source.isLocalPlayer), Show(source.totalAmount), Show(source.classFilename)))
        if source.isLocalPlayer == true and C_DamageMeter.GetCombatSessionSourceFromType then
            local fine, mine = pcall(C_DamageMeter.GetCombatSessionSourceFromType,
                Enum.DamageMeterSessionType.Current, Enum.DamageMeterType.DamageDone, source.sourceGUID, source.sourceCreatureID)
            if fine and type(mine) == "table" then
                for _, spell in ipairs(mine.combatSpells or {}) do
                    local detail = spell.combatSpellDetails
                    ns.Print(string.format("    spell %s total %s on %s for %s", Show(spell.spellID),
                        Show(spell.totalAmount), Show(detail and detail.unitName), Show(detail and detail.amount)))
                end
            else
                ns.Print("    no source detail: " .. tostring(mine))
            end
        end
    end
end

-- Every route an addon has for putting a window on screen during a
-- fight, tried one after another on the windows this addon owns or
-- borrows, with whatever the client refused printed beside each. Run it
-- in a fight: one press answers what would otherwise take a dozen.
--
-- The routes:
--   Show        the frame's own method, refused for anything the client
--               protects, and a frame counts as protected when it holds
--               the client's own casting buttons
--   Panel       the client's window manager, which refuses every addon
--               in combat by its own first line
--   securecall  the same through the client's secure caller
--   Driver      a state driver: the client re-reads those on its own
--               timer, in its own context, which is the one pass that is
--               not ours and may therefore be allowed to show the frame
local function TryCombat()
    local blocked = ns.blocked or {}
    local before = #blocked
    ns.Print(string.format("combat %s; snippets usable %s", tostring(InCombatLockdown()),
        tostring(loadstring_untainted ~= nil)))

    local targets = {
        { "FriendsFrame", FriendsFrame },
        { "our spellbook", _G["ForeverClassicUISpellBook"] },
        { "our quest log", _G["ForeverClassicUIQuestLog"] },
    }
    -- A frame of ours holding one of the client's casting buttons: this
    -- says whether a secure child alone is what shuts a window.
    if not ns.probeHost then
        local host = CreateFrame("Frame", "ForeverClassicUIProbeHost", UIParent)
        host:SetSize(120, 40)
        host:SetPoint("CENTER", UIParent, "CENTER", 0, 240)
        local bg = host:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(host)
        bg:SetColorTexture(0, 0, 0, 0.8)
        host:Hide()
        CreateFrame("Button", "ForeverClassicUIProbeChild", host, "SecureActionButtonTemplate")
        ns.probeHost = host
    end
    targets[#targets + 1] = { "plain frame, secure child", ns.probeHost }

    local function State(frame)
        local protected, explicit = false, false
        if frame.IsProtected then protected, explicit = frame:IsProtected() end
        return string.format("protected=%s/%s shown=%s", tostring(protected), tostring(explicit), tostring(frame:IsShown()))
    end

    for _, entry in ipairs(targets) do
        local label, frame = entry[1], entry[2]
        if not frame then
            ns.Print(string.format("%-26s missing", label))
        else
            local was = frame:IsShown()
            ns.Print(string.format("%-26s %s", label, State(frame)))
            if was then
                ns.Print("      already open, routes not tried")
            else
                local ok = pcall(frame.Show, frame)
                ns.Print(string.format("      Show        called=%s shown=%s", tostring(ok), tostring(frame:IsShown())))
                if frame:IsShown() then pcall(frame.Hide, frame) end

                if ShowUIPanel then
                    local fine = pcall(ShowUIPanel, frame)
                    ns.Print(string.format("      Panel       called=%s shown=%s", tostring(fine), tostring(frame:IsShown())))
                    if frame:IsShown() and HideUIPanel then pcall(HideUIPanel, frame) end
                end

                if securecall and ShowUIPanel then
                    local fine = pcall(securecall, ShowUIPanel, frame)
                    ns.Print(string.format("      securecall  called=%s shown=%s", tostring(fine), tostring(frame:IsShown())))
                    if frame:IsShown() and HideUIPanel then pcall(HideUIPanel, frame) end
                end
            end
        end
    end

    -- The driver route is answered on the client's own timer, so it is
    -- asked here and read a moment later.
    local driven = {}
    if RegisterStateDriver then
        for _, entry in ipairs(targets) do
            local frame = entry[2]
            if frame and not frame:IsShown() then
                local ok = pcall(RegisterStateDriver, frame, "visibility", "show")
                driven[#driven + 1] = { entry[1], frame, ok }
            end
        end
    end

    -- The real paths, exactly as the key and the button run them.
    if ns.OpenGuildRoster then
        local opened = ns.OpenGuildRoster()
        ns.Print(string.format("%-26s OpenGuildRoster=%s friends shown=%s", "guild path",
            tostring(opened), tostring(FriendsFrame and FriendsFrame:IsShown())))
    end
    if ns.ToggleSpellBook then
        local opened = ns.ToggleSpellBook()
        local b = _G["ForeverClassicUISpellBook"]
        ns.Print(string.format("%-26s ToggleSpellBook=%s book shown=%s", "spellbook path",
            tostring(opened), tostring(b and b:IsShown())))
    end

    C_Timer.After(0.6, function()
        for _, entry in ipairs(driven) do
            local label, frame, ok = entry[1], entry[2], entry[3]
            ns.Print(string.format("%-26s Driver      called=%s shown=%s", label, tostring(ok), tostring(frame:IsShown())))
            if UnregisterStateDriver then pcall(UnregisterStateDriver, frame, "visibility") end
            if frame:IsShown() then pcall(frame.Hide, frame) end
            frame:SetAttribute("statehidden", nil)
        end
        local now = #(ns.blocked or {})
        if now > before then
            ns.Print("the client refused:")
            for i = 1, now - before do
                local hit = ns.blocked[i]
                ns.Print(string.format("   %s %s%s", hit.event, hit.func, hit.combat and " (in combat)" or ""))
            end
        else
            ns.Print("the client refused nothing during this probe")
        end
        ns.FlushNotice()
    end)
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
        ns.ToggleChanged(key)
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
    elseif cmd == "trycombat" or cmd == "try" then
        ns.BeginOutput("trycombat")
        TryCombat()
    elseif cmd == "dmg" then
        ns.BeginOutput("dmg")
        DamageSources()
        ns.FlushNotice()
    elseif cmd == "sweep" then
        ns.db.sweepTrace = not ns.db.sweepTrace
        if ns.SweepFriendsReport then ns.SweepFriendsReport() end
        ns.Print("friends window trace = " .. tostring(ns.db.sweepTrace) .. "; open the Who list or the roster")
    elseif cmd == "bars" then
        ns.BeginOutput("bars")
        Bars()
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
