local _, ns = ...

local TITLE = "ClassicUI Forever"

-- key, label, tooltip
local TOGGLES = {
    { "classicBar", "Classic main menu bar", "The 1.x bar: stone band and gryphons centered at the bottom, with the action buttons, page arrows, micro buttons, bags and experience bar in their 2004 spots." },
    { "defaultBarSize", "Default interface bar size", "Draws the classic bar at the size of the game's own action bar. The true 1.x bar has 36 pixel buttons where the game's has 45, so at the same interface scale it comes out a fifth smaller; this makes them the same. At that size twelve slots no longer fit most screens, so bars 1 and 2 go to ten icons and the two side bars to eight in the ClassicUI Forever layout, and back to twelve when this is turned off; you can set them yourself in edit mode afterwards. Off is the true classic size.", parent = "classicBar" },
    { "oneBar", "One bar", "The band stops after the twelve main slots, the right gryphon beside them and the experience bar the same width. The bottom right bar, the micro menu and the bags stay where edit mode puts them.", parent = "classicBar" },
    { "bagsBesideBars", "Opened bags beside the right action bars", "Opened bag windows start to the left of the action bars standing down the right edge of the screen, as they used to, and do not cover them. A bar laid down or moved away from that edge is not counted. Off, the bags open in the corner over the bars." },
    { "bagsAboveRow", "Opened bags above the bag buttons", "Opened bag windows stand above the bag buttons, wherever you have put those, and follow them. Off, which is how it starts, they open where the default interface opens them, at the bottom right of the screen. The same tick box is under the bags dialog in edit mode.", parent = "classicBar" },
    { "questMapPane", "Classic map quest pane", "The quest list the map opens on its right, in the quest log's manner: the dark list with plus and minus headers, 1.x difficulty colors and the old check, and a quest's details on parchment." },
    { "gameMenu", "Classic game menu", "The Escape menu as the old dialog box: the header plate and the compact red buttons with yellow labels." },
    { "settingsPanel", "Classic settings window", "The settings window as the old options dialog: the dialog box and header plate, the category list and page in thin-bordered insets, the blue bar under the chosen category, and the old check boxes, sliders, drop downs, arrows, scroll bars, tabs and red buttons." },
    { "buttons", "Classic button style", "Square slot borders, red attack flash and the old pressed and highlight art." },
    { "squareIcons", "Square icons", "Remove the rounded icon mask so icons are square like 1.x. Needs Classic button style on.", parent = "buttons" },
    { "castAnim", "No cast animation on buttons", "1.x played nothing over a button while its spell was casting. The animation the game draws across the icon is taken off and the cooldown swipe under it stays solid." },
    { "hideExtraBars", "Hide bars 6 to 8", "1.x had five action bars. Bars 6, 7 and 8 are faded out and stop taking clicks; their keybinds still work. Turn this off to place them with edit mode." },
    { "emptySlots", "Hide empty side bar slots", "Like 1.x, empty buttons on the extra bars stay hidden until you drag a spell, whatever the Always Show Buttons setting says." },
    { "unitFrames", "Classic unit frames", "Player, target, focus, target of target, pet and party frames with the 1.x art, bars and layout. Turning this off takes full effect after /reload." },
    { "unitFramePlayer", "Classic player frame", "The player frame with the old art, portrait, level circle and bars. Needs Classic unit frames on.", parent = "unitFrames" },
    { "unitFrameTarget", "Classic target frame", "The target frame and its target of target with the old art and bars. Needs Classic unit frames on.", parent = "unitFrames" },
    { "unitFrameFocus", "Classic focus frame", "The focus frame with the old art and bars. Needs Classic unit frames on.", parent = "unitFrames" },
    { "unitFramePet", "Classic pet frame", "The pet frame with the old art and bars. Needs Classic unit frames on.", parent = "unitFrames" },
    { "unitFrameParty", "Classic party frames", "The party frames with the old art, portraits and bars. Needs Classic unit frames on.", parent = "unitFrames" },
    { "trainer", "Classic trainer window", "A trainer's window as the old one: the greeting, the All tab and the filter, the list in green, red and gray under its headers, the chosen service with what it needs and costs below, and your money, Train and Exit along the foot." },
    { "hideBuffArrow", "No arrow beside the buffs", "1.x had no arrow next to the buff icons. The small arrow that folds the buffs away is hidden until the mouse is over it. Turn this off to have it always shown." },
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
    { "oneBag", "One bag", "All your bags open as a single window, in the old bag art, as tall as your slots need. This is the game's own Combine Bags setting; turning it off here gives you the separate bag windows back." },
    { "characterSheet", "Classic character sheet", "The 1.x character window: the old art, slots down the sides with the weapons underneath, the model with its rotate buttons, the attribute and attack stat boxes, the five resistances and the bottom tabs. Turning this off takes full effect after /reload." },
    { "statPanes", "Stat panes with drop downs", "The 2.x stat boxes under the model in place of the 1.x pair: each box has a drop down and can list any section of the game's own character window: General, Primary Attributes, Weapons, Modifiers, Defense or Resistances. The lines, numbers and tooltips are the game's own.", parent = "characterSheet" },
    { "classColorHealth", "Class colored unit frames", "The player and target health bars take the unit's class color instead of the old green. Only players are colored; everything else stays green.", parent = "unitFrames" },
    { "classColorPlates", "Class colored nameplates", "A player's nameplate health bar takes their class color. Everything else keeps the color the game gives it.", parent = "namePlates" },
    { "mapFade", "Fade map while moving", "The map dims itself while you move, which is the game's own mapFade setting. Off, it stays solid." },
    { "hideLastNames", "Hide last names", "The Forever client gives characters a last name and draws it under the first. This turns every surname setting off; the game's own box for it stays in step, so putting surnames back there turns this off." },
    { "whoList", "Classic who list", "The 1.x Who tab on the social window: names, zone, level and class in sortable columns, with Refresh, Add Friend and Group Invite along the foot. A /who answers into it rather than the client's own window, and the tabs read Friends, Who, Guild as they did." },
    { "guildRoster", "Classic guild roster", "The guild tab the 1.x Friends window carried: the member count, the guild message, and the roster in four sortable columns with the old buttons along the foot. The modern guild window stays reachable." },
    { "spellBook", "Classic spellbook", "The 1.x parchment spellbook: twelve spells a page with name and rank beside each icon, school tabs down the right edge, page arrows and a pet tab. Opens from the micro button, the keybind and /spellbook; talents still use the modern window." },
    { "spellBookTopRank", "Highest spell ranks only", "The classic spellbook lists only the highest rank you know of each spell. Off, which is how the old book was, every rank is listed.", parent = "spellBook" },
    { "spellBookSearch", "Spellbook search box", "A search box on the book: type, and every known spell whose name holds the words is listed, across the tabs.", parent = "spellBook" },
    { "gameDamageNumbers", "Show the game's damage numbers", "The game's own floating damage over what you hit. This is the game's setting, shown here because an early version of this addon turned it off for its own damage numbers, which are gone, and the game's settings window no longer offers it. The same as /console floatingCombatTextCombatDamage_v2." },
    { "tradeSkill", "Classic profession windows", "A profession's own window as the old trade skill window: the rank bar under the title, the recipes in the upper half under headers that fold, each in the color of its difficulty, and the chosen recipe below with its reagents, Create All, a count, Create and Exit. The profession tabs down the side stay." },
    { "professionsBook", "Classic professions book", "The professions overview as the old professions book: two parchment pages, each profession with its round emblem, its name, its rank and the small green bar, and its spells on their plates down the right. The crafting pages are left as they are." },
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

-- Nothing of ours writes an edit mode layout while the game is being
-- played. A layout written from an addon's call (a save, a switch, a new
-- layout, a bar's anchor or icon count) leaves every edit mode piece
-- marked as the addon's for the rest of the session: the damage meter,
-- the cooldown viewers, the action bars, the party frames. The client
-- then refuses those pieces their protected values in a fight, and the
-- errors name this addon. A reload was asked for after each write, and
-- "Later" left the session running marked.
--
-- So a write is never made under a game that goes on. What is wanted is
-- put down here as a job, and the jobs are run in the press of a button
-- that reloads the interface, in the same breath and just before it: the
-- session they mark is over, and the next one reads the layouts fresh.
-- "Later" means nothing has been written, and the jobs wait for the next
-- such press.
--
-- Not in the logout itself, which was tried: by then the client's edit
-- mode interface is shut. It named the wrong layout as active and took
-- no notice of a switch, and nothing written there was kept.
function ns.QueueLayoutJob(key, value)
    if not ns.db then return end
    ns.db.layoutJobs = ns.db.layoutJobs or {}
    ns.db.layoutJobs[key] = value
end

StaticPopupDialogs["FCUI_LAYOUT_PENDING"] = {
    text = TITLE .. "\n\n%s\n\nIt is done as the interface reloads.",
    button1 = "Reload now",
    button2 = "Later",
    OnAccept = function() ns.ReloadForLayout() end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

-- The one write that cannot wait for a logout: a piece let go on the
-- classic bar in edit mode snaps into it there and then, by being handed
-- its default place, under the player's eyes. That marks the piece, not
-- the whole layout, and the player's own Save follows it; still, the
-- session is asked to end once edit mode is closed.
StaticPopupDialogs["FCUI_EDIT_WROTE"] = {
    text = TITLE .. "\n\nA change was made for you in edit mode (a piece snapped onto the classic bar, or a size put back to its default). Reload the interface to finish; until you do, the action bars can throw errors in a fight.",
    button1 = "Reload now",
    button2 = "Later",
    OnAccept = function() ns.ReloadForLayout() end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

function ns.WatchEditWrites()
    if ns.editWriteWatched or not ns.OnEditMode then return end
    ns.editWriteWatched = true
    ns.OnEditMode(function()
        local mgr = EditModeManagerFrame
        local editing = mgr and mgr.IsEditModeActive and mgr:IsEditModeActive()
        if editing or not ns.editWrote then return end
        ns.editWrote = nil
        if StaticPopup_Show then StaticPopup_Show("FCUI_EDIT_WROTE") end
    end)
end

-- The way every button of ours reloads the interface: the waiting jobs
-- first, the band's bars pinned (or, with the band off, its pins taken
-- out), and the reload in the same press. A fight forbids the layout
-- work and not the reload, so there the jobs simply wait.
function ns.ReloadForLayout()
    if not (C_UI and C_UI.Reload) then return end
    if ns.db and not InCombatLockdown() then
        ns.sessionEnding = true
        if ns.RunLayoutJobsBeforePin then pcall(ns.RunLayoutJobsBeforePin) end
        if ns.db.classicBar ~= false then
            if ns.PinBandBars then pcall(ns.PinBandBars) end
        elseif not ns.db.bandHandedBack and ns.UnpinBandBars then
            pcall(ns.UnpinBandBars)
        end
        if ns.RunLayoutJobsAfterPin then pcall(ns.RunLayoutJobsAfterPin) end
        if ns.MirrorSave then pcall(ns.MirrorSave) end
    end
    C_UI.Reload()
end

function ns.AskLayoutReload(what)
    if StaticPopup_Show then StaticPopup_Show("FCUI_LAYOUT_PENDING", what) end
end

local function LayoutIndexByName(name, anyType)
    local mgr = EditModeManagerFrame
    if not name or not mgr or not mgr.GetLayouts then return nil end
    for index, layout in ipairs(mgr:GetLayouts()) do
        if layout.layoutName == name and (anyType or layout.layoutType ~= Enum.EditModeLayoutType.Preset) then
            return index, layout
        end
    end
end

-- Back to the layout they were on before the classic one.
function ns.RestorePreviousLayout()
    if InCombatLockdown() then
        ns.Print("cannot change layouts in combat")
        return false
    end
    local wanted = ns.db and ns.db.previousLayout
    if wanted == "" then wanted = nil end
    if not wanted then
        ns.Print("no earlier layout written down; pick one in edit mode")
        return false
    end
    if not EditModeManagerFrame or not EditModeManagerFrame.GetLayouts or not (C_EditMode and C_EditMode.SetActiveLayout) then
        ns.Print("edit mode layouts are not available on this client")
        return false
    end
    if not LayoutIndexByName(wanted, true) then
        ns.Print("the " .. wanted .. " layout is gone; pick one in edit mode")
        return false
    end
    ns.QueueLayoutJob("previous", wanted)
    ns.AskLayoutReload("Switching back to your " .. wanted .. " layout.")
    return true
end

-- At the game's own bar size the classic bar is a quarter again as wide,
-- and twelve slots across with a gryphon at each end no longer fit most
-- screens. So choosing that size also sets how many icons the bars show
-- in the addon's own layout: ten on bars 1 and 2, which share the band's
-- left half, eight on the two side bars, and twelve again when the size
-- is turned back off. Bar 3 keeps its twelve: it stands over the micro
-- menu and the bags, where twelve still fit. The slots
-- past the last shown one keep whatever is on them. It is a change to
-- the layout, made through the client's own entry point for a bar
-- setting, and the interface wants reloading after a layout is written.
local FIT_COUNTS = {
    { "MainActionBar", 10 }, { "MultiBarBottomLeft", 10 },
    { "MultiBarRight", 8 }, { "MultiBarLeft", 8 },
}
local function FitWanted(big)
    local setting = Enum and Enum.EditModeActionBarSetting and Enum.EditModeActionBarSetting.NumIcons
    local wanted = {}
    if setting == nil then return wanted, setting end
    for _, entry in ipairs(FIT_COUNTS) do
        local bar = _G[entry[1]]
        if bar and bar.system and bar.GetSettingValue then
            local want = big and entry[2] or 12
            local ok, now = pcall(bar.GetSettingValue, bar, setting)
            if ok and now ~= want then wanted[#wanted + 1] = { bar, want } end
        end
    end
    return wanted, setting
end

-- As the session ends: the counts go into the layout, and the band is
-- laid once more at the new lengths so the pins that follow are right.
local function FitNow(big)
    if not ns.sessionEnding or not (ns.ClassicLayoutActive and ns.ClassicLayoutActive()) then return false end
    local mgr = EditModeManagerFrame
    if not mgr or not mgr.OnSystemSettingChange or not mgr.SaveLayouts then return false end
    local wanted, setting = FitWanted(big)
    local changed = false
    for _, entry in ipairs(wanted) do
        if pcall(mgr.OnSystemSettingChange, mgr, entry[1], setting, entry[2]) then changed = true end
    end
    if changed then
        pcall(mgr.SaveLayouts, mgr)
        ns.ApplyAll()
    end
    return changed
end

function ns.FitBarsToSize(big)
    if not (ns.ClassicLayoutActive and ns.ClassicLayoutActive()) then return false end
    if #FitWanted(big) == 0 then
        if ns.db and ns.db.layoutJobs then ns.db.layoutJobs.fit = nil end
        return false
    end
    ns.QueueLayoutJob("fit", big and "big" or "normal")
    ns.AskLayoutReload(big and "The bars go to ten and eight icons to fit the larger classic bar." or "The bars go back to twelve icons.")
    return true
end

-- Turning the addon off. Its edit mode layout is the client's own and
-- stays selected with the addon gone, bars pinned where the stone bar
-- had them and frames in their 1.x spots, under the client's modern art:
-- a mess, and the first thing anyone trying the addon out would see on
-- the way out. Nothing of ours runs once it is off, but the reload that
-- turns it off still passes through our logout, where the addon list
-- already says it is unticked. There the layout the player came from is
-- made the active one again, and every client setting we changed goes
-- back to what it was. The classic layout itself is kept, and chosen
-- again if the addon is ever turned back on.
function ns.BeingTurnedOff()
    local state = C_AddOns and C_AddOns.GetAddOnEnableState
    if not state then return false end
    local ok, value = pcall(state, "ClassicUIForever", UnitName("player"))
    return ok and value == 0
end

function ns.HandBack()
    if not ns.db then return end
    ns.handingBack = true
    local mgr = EditModeManagerFrame
    if ns.ClassicLayoutActive and ns.ClassicLayoutActive() and mgr and mgr.GetLayouts and C_EditMode and C_EditMode.SetActiveLayout then
        local wanted, index = ns.db.previousLayout, nil
        if wanted == "" then wanted = nil end
        for i, layout in ipairs(mgr:GetLayouts()) do
            if wanted and layout.layoutName == wanted then index = i break end
        end
        -- No layout written down: the first one the client has, its own
        -- modern preset.
        index = index or 1
        if pcall(C_EditMode.SetActiveLayout, index) then ns.db.layoutSelectPending = true end
    end
    for name, value in pairs(ns.db.cvarWas or {}) do
        if C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar, name, value) end
    end
    ns.db.cvarWas = nil
end

-- The same from a button: untick the addon for this character and reload,
-- which takes the way out above.
function ns.TurnOffCleanly()
    if InCombatLockdown() then
        ns.Print("not during a fight")
        return
    end
    local disable = C_AddOns and C_AddOns.DisableAddOn
    if not disable then return end
    pcall(disable, "ClassicUIForever", UnitName("player"))
    -- The earlier layout is chosen here, in the press itself: the logout
    -- that follows is too late for the client to take it.
    if ns.HandBack then pcall(ns.HandBack) end
    if C_UI and C_UI.Reload then C_UI.Reload() end
end

StaticPopupDialogs["FCUI_TURN_OFF"] = {
    text = TITLE .. "\n\nTurn the addon off for this character? Your earlier edit mode layout is made active again and the game settings the addon changed go back to what they were, so the default interface comes back as you left it. The interface reloads. You can turn the addon back on from the AddOns list at any time.",
    button1 = "Turn off",
    button2 = CANCEL or "Cancel",
    OnAccept = function() ns.TurnOffCleanly() end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

-- Puts the addon's own layout back the way it is made: every bar on the
-- band, the micro menu and the bags back on it at their own size, the
-- band centered, and the player, target and focus frames at their 1.x
-- spots. Only ever the ClassicUI Forever layout; the player's other
-- layouts are not read or written.
local function ResetNow()
    if not ns.sessionEnding or InCombatLockdown() then return false end
    if not (ns.ClassicLayoutActive and ns.ClassicLayoutActive()) then return false end
    ns.db.microPos, ns.db.microScale = nil, nil
    if ns.MirrorSave then ns.MirrorSave() end
    ns.db.barDragged, ns.db.barOffsetX, ns.db.barOffsetY = false, nil, nil
    local names = { "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
        "MultiBarLeft", "StanceBar", "PetActionBar", "PossessActionBar", "MainStatusTrackingBarContainer",
        "SecondaryStatusTrackingBarContainer", "BagsBar", "MicroMenuContainer" }
    for _, name in ipairs(names) do
        local frame = _G[name]
        if frame and frame.system and type(frame.IsInDefaultPosition) == "function" and type(frame.ResetToDefaultPosition) == "function" then
            local ok, isDefault = pcall(frame.IsInDefaultPosition, frame)
            if ok and not isDefault then pcall(frame.ResetToDefaultPosition, frame) end
        end
    end
    if ns.db.barPins then ns.db.barPins[LAYOUT_NAME] = nil end
    -- The band is laid at once, centered, and the frames take their
    -- spots; the pins are written by the logout's own pin step next.
    ns.ApplyAll()
    if ns.ApplyClassicFrameSpots then ns.ApplyClassicFrameSpots() end
    local mgr = EditModeManagerFrame
    if mgr and mgr.SaveLayouts then pcall(mgr.SaveLayouts, mgr) end
    return true
end

function ns.ResetClassicLayout(reloadNow)
    if InCombatLockdown() then
        ns.Print("cannot change layouts in combat")
        return false
    end
    if not (ns.ClassicLayoutActive and ns.ClassicLayoutActive()) then return false end
    ns.QueueLayoutJob("reset", true)
    if reloadNow then
        ns.ReloadForLayout()
        return true
    end
    ns.AskLayoutReload("The " .. LAYOUT_NAME .. " layout goes back to its defaults.")
    return true
end

-- Asked when the layout button is pressed with the classic layout
-- already on: there is nothing to switch to, so the choice is between
-- putting it back to its defaults and, where one is written down, going
-- back to the layout used before.
StaticPopupDialogs["FCUI_LAYOUT_RESET"] = {
    text = TITLE .. "\n\nYou are on the " .. LAYOUT_NAME .. " layout already. Reset it to its defaults? Every bar, the micro menu, the bags and the player, target and focus frames go back to their classic places. Your other layouts are not touched. The interface reloads to do it.",
    button1 = "Reset and reload",
    button2 = CANCEL or "Cancel",
    OnAccept = function() ns.ResetClassicLayout(true) end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

-- How many icons each action bar shows is the player's choice, and it
-- comes along to the classic layout: set up from a layout with twelve on
-- bar 1, the classic layout has twelve; from one with eight, eight. The
-- classic bar draws itself to whatever bar 1 has. Only the bar size
-- toggle changes counts, and says so where it is ticked.
local COUNT_BARS = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
    "MultiBar5", "MultiBar6", "MultiBar7" }

local function ReadIconCounts()
    local counts = {}
    local setting = Enum and Enum.EditModeActionBarSetting and Enum.EditModeActionBarSetting.NumIcons
    if setting == nil then return counts end
    for _, name in ipairs(COUNT_BARS) do
        local bar = _G[name]
        if bar and bar.systemIndex and bar.GetSettingValue then
            local ok, value = pcall(bar.GetSettingValue, bar, setting)
            if ok and type(value) == "number" and value >= 1 and value <= 12 then counts[bar.systemIndex] = value end
        end
    end
    -- With the game's own bar size chosen the fitted counts stand.
    if ns.db and ns.db.defaultBarSize == true then
        for _, entry in ipairs(FIT_COUNTS) do
            local bar = _G[entry[1]]
            if bar and bar.systemIndex then counts[bar.systemIndex] = entry[2] end
        end
    end
    return counts
end

-- The classic layout's own marks on a layout's data: the unit frames'
-- 1.x spots, the icon counts the player came with, and the band's bars
-- held where the band has them. On a layout just made from the preset
-- ("fresh") the chat frame is lifted over the bottom bars and every bar
-- is the band's to pin; on one that already exists only what the layout
-- still holds as the client's own, or as an earlier pin of ours, is.
local function DressLayoutData(layout, counts, pins, fresh)
    local CHAT_X, CHAT_Y = 35, 145
    local pinned = ns.db.barPins and ns.db.barPins[LAYOUT_NAME] or {}
    local record = {}
    for _, system in ipairs(layout.systems or {}) do
        -- The chat frame goes where 1.x kept it, above the bottom bars and
        -- the pet row. The Forever client's own preset already puts it
        -- there; retail's leaves it 50px up, across bars 2 and 3.
        if fresh and system.system == Enum.EditModeSystem.ChatFrame and type(system.anchorInfo) == "table" then
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
        if system.system == Enum.EditModeSystem.ActionBar and type(system.settings) == "table" then
            local count = counts[system.systemIndex] or (fresh and 12) or nil
            for key, entry in pairs(system.settings) do
                if type(entry) == "table" and entry.setting then
                    if count and entry.setting == Enum.EditModeActionBarSetting.NumIcons then entry.value = count end
                    if fresh and entry.setting == Enum.EditModeActionBarSetting.AlwaysShowButtons then entry.value = 0 end
                elseif count and key == Enum.EditModeActionBarSetting.NumIcons then
                    system.settings[key] = count
                elseif fresh and key == Enum.EditModeActionBarSetting.AlwaysShowButtons then
                    system.settings[key] = 0
                end
            end
        end
        -- The band's bars, held against the screen where the band has
        -- them now: a bar the layout leaves to the client is laid out
        -- again by the client whenever it likes, in a fight too.
        for _, pin in ipairs(pins) do
            if system.system == pin.system and system.systemIndex == pin.systemIndex
                and (fresh or system.isInDefaultPosition or pinned[pin.name]) then
                system.anchorInfo = {
                    point = pin.anchorInfo.point, relativeTo = pin.anchorInfo.relativeTo,
                    relativePoint = pin.anchorInfo.relativePoint,
                    offsetX = pin.anchorInfo.offsetX, offsetY = pin.anchorInfo.offsetY,
                }
                system.anchorInfo2 = nil
                system.isInDefaultPosition = false
                record[pin.name] = {
                    point = pin.anchorInfo.point, relativePoint = pin.anchorInfo.relativePoint,
                    offsetX = pin.anchorInfo.offsetX, offsetY = pin.anchorInfo.offsetY,
                }
            end
        end
    end
    if next(record) then
        ns.db.barPins = ns.db.barPins or {}
        ns.db.barPins[LAYOUT_NAME] = ns.db.barPins[LAYOUT_NAME] or {}
        for name, pin in pairs(record) do ns.db.barPins[LAYOUT_NAME][name] = pin end
    end
end

-- As the session ends: the classic layout is made, or the one that is
-- there is brought up to date, and it is made the active one. All of it
-- on the layouts' data, none of it on the frames: the layout that is
-- live stays live to the end, and the next session opens on this one.
local function ClassicNow(job)
    if not ns.sessionEnding then return false end
    local mgr = EditModeManagerFrame
    local layouts = mgr and mgr.layoutInfo and mgr.layoutInfo.layouts
    if not layouts or not (C_EditMode and C_EditMode.SaveLayouts and C_EditMode.SetActiveLayout) or not EditModePresetLayoutManager then return false end
    local counts = type(job) == "table" and job.counts or {}
    local pins = ns.BandPinAnchors and ns.BandPinAnchors() or {}
    local index, layout = LayoutIndexByName(LAYOUT_NAME)
    if layout then
        DressLayoutData(layout, counts, pins, false)
        C_EditMode.SaveLayouts(mgr.layoutInfo)
    else
        if mgr.AreLayoutsFullyMaxed and mgr:AreLayoutsFullyMaxed() then return false end
        local presets = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
        local classicIndex = (Enum.EditModePresetLayouts and Enum.EditModePresetLayouts.Classic) or 2
        local base = presets and (presets[classicIndex] or presets[1])
        if not base then return false end
        DressLayoutData(base, counts, pins, true)
        base.layoutType = Enum.EditModeLayoutType.Account
        base.layoutName = LAYOUT_NAME
        -- After the last of the account's layouts, where the client puts
        -- a new one itself.
        index = nil
        for i, other in ipairs(layouts) do
            if other.layoutType == Enum.EditModeLayoutType.Account then index = i end
        end
        index = (index or (Enum.EditModePresetLayoutsMeta and Enum.EditModePresetLayoutsMeta.NumValues or 2)) + 1
        table.insert(layouts, index, base)
        C_EditMode.SaveLayouts(mgr.layoutInfo)
        if C_EditMode.OnLayoutAdded then C_EditMode.OnLayoutAdded(index, true, false) end
    end
    C_EditMode.SetActiveLayout(index)
    -- The next login looks whether the switch held.
    ns.db.layoutSelectPending = true
    return true
end

local function SelectNow(name)
    if not ns.sessionEnding or not (C_EditMode and C_EditMode.SetActiveLayout) then return false end
    local index = LayoutIndexByName(name, true)
    if not index then return false end
    C_EditMode.SetActiveLayout(index)
    return true
end

-- The jobs, run from the logout: the ones that work on the live layout
-- before the band's bars are pinned, the ones that change which layout
-- is active after, since those leave the live one as it stands.
function ns.RunLayoutJobsBeforePin()
    local jobs = ns.db and ns.db.layoutJobs
    if not jobs or not ns.sessionEnding then return end
    if jobs.reset then
        ResetNow()
        jobs.reset = nil
    end
    if jobs.adopt then
        if ns.AdoptBandBars then ns.AdoptBandBars() end
        jobs.adopt = nil
    end
    if jobs.fit then
        FitNow(jobs.fit == "big")
        jobs.fit = nil
    end
end

function ns.RunLayoutJobsAfterPin()
    local jobs = ns.db and ns.db.layoutJobs
    if not jobs or not ns.sessionEnding then return end
    if jobs.previous then
        if SelectNow(jobs.previous) then ns.db.previousLayout = "" end
        jobs.previous = nil
    end
    if jobs.classic then
        ClassicNow(jobs.classic)
        jobs.classic = nil
    end
    if jobs.select then
        SelectNow(LAYOUT_NAME)
        jobs.select = nil
    end
    ns.db.layoutJobs = nil
end

-- Sets the classic layout up, or switches to the one that is there. With
-- reloadNow the press that asked is the press that reloads.
function ns.CreateClassicLayout(reloadNow)
    if InCombatLockdown() then
        ns.Print("cannot change layouts in combat")
        return
    end
    local mgr = EditModeManagerFrame
    if not mgr or not mgr.GetLayouts or not EditModePresetLayoutManager or not (C_EditMode and C_EditMode.SaveLayouts) then
        ns.Print("edit mode layouts are not available on this client")
        return
    end
    local exists = LayoutIndexByName(LAYOUT_NAME) ~= nil
    if not exists and mgr.AreLayoutsFullyMaxed and mgr:AreLayoutsFullyMaxed() then
        ns.Print("you already have the maximum number of edit mode layouts; delete one in edit mode first")
        return
    end
    -- Read now: these are the layout being left.
    local counts = ReadIconCounts()
    RememberLayout()
    ns.QueueLayoutJob("classic", { counts = counts })
    ns.db.layoutPrompted = true
    if reloadNow then
        ns.ReloadForLayout()
        return
    end
    ns.AskLayoutReload(exists and ("Switching to your " .. LAYOUT_NAME .. " layout.") or ("Setting up the " .. LAYOUT_NAME .. " layout."))
end

StaticPopupDialogs["FCUI_LAYOUT_DONE"] = {
    text = TITLE .. "\n\nThe classic layout is in place. Reload the interface to finish; until you do, the raid and party frames can throw errors.",
    button1 = "Reload now",
    button2 = "Later",
    OnAccept = function() ns.ReloadForLayout() end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

-- First time in with the addon: one question. Set up the classic layout
-- (a new edit mode layout beside the existing ones) or keep what is there.
-- Bars that moved during a fight. A layout that holds the band's bars
-- as "in their default place" leaves them to the client, which lays its
-- bar stack out again whenever it likes, fights included, and an addon
-- may not move a bar back until the fight is over. Pinned into the
-- layout they are no longer the client's to move. That is written as
-- the session ends on any layout of the player's own, so the next login
-- is steady without a word; this asks once, when it has just happened,
-- for whoever would rather not wait.
StaticPopupDialogs["FCUI_BARS_MOVED"] = {
    text = TITLE .. "\n\nYour action bars moved during that fight: this edit mode layout leaves them to the game.\n\nLock them into this layout where the classic bar has them? The interface reloads to do it.",
    button1 = "Lock and reload",
    button2 = "Later",
    -- The lock is the pin every logout writes; the reload is what gets
    -- it written now.
    OnAccept = function() ns.ReloadForLayout() end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

-- The same on one of the client's presets, which cannot hold the bars:
-- a layout of the player's own is what it takes, and the addon's is one.
StaticPopupDialogs["FCUI_BARS_MOVED_PRESET"] = {
    text = TITLE .. "\n\nYour action bars moved during that fight: the game's preset layouts cannot hold the classic bar's places.\n\nSet up the \"" .. LAYOUT_NAME .. "\" layout and switch to it? Your other layouts are untouched. The interface reloads to do it.",
    button1 = "Set up and reload",
    button2 = "Later",
    OnAccept = function() ns.CreateClassicLayout(true) end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

function ns.AskAboutMovedBars()
    if not StaticPopup_Show then return end
    StaticPopup_Show(ns.LayoutWritable() and "FCUI_BARS_MOVED" or "FCUI_BARS_MOVED_PRESET")
end

StaticPopupDialogs["FCUI_FIRST_LOGIN"] = {
    text = TITLE .. "\n\nSet up the classic layout now? This adds an edit mode layout named \"" .. LAYOUT_NAME .. "\" with everything in its 1.x place and switches to it. Your current layout and keybinds are untouched and stay in the edit mode list, where you can switch back at any time. The interface reloads to do it.",
    button1 = "Set up and reload",
    button2 = "Keep my layout",
    OnAccept = function() ns.CreateClassicLayout(true) end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

-- After the reload that made or chose the classic layout: a look at
-- whether the client kept the switch. It is not made from here, that
-- would be a layout written under a running game. If the client did not
-- keep it, it is asked for once more at the next reload; if that does
-- not hold either, the old way is all that is left: switch now and ask
-- for the reload that clears the session.
function ns.SelectClassicLayoutIfPending()
    if ns.db and ns.db.layoutJobs and next(ns.db.layoutJobs) then
        ns.AskLayoutReload("A layout change you asked for is still waiting.")
        return
    end
    if not ns.db or not ns.db.layoutSelectPending then return end
    local mgr = EditModeManagerFrame
    if not mgr or not mgr.GetLayouts or InCombatLockdown() then return end
    local active = mgr.GetActiveLayoutInfo and mgr:GetActiveLayoutInfo()
    local index = LayoutIndexByName(LAYOUT_NAME)
    if (active and active.layoutName == LAYOUT_NAME) or not index then
        ns.db.layoutSelectPending, ns.db.layoutSelectTries = false, 0
        return
    end
    local tries = ns.db.layoutSelectTries or 0
    if tries < 1 then
        ns.db.layoutSelectTries = tries + 1
        ns.QueueLayoutJob("select", true)
        ns.AskLayoutReload("The " .. LAYOUT_NAME .. " layout is made; one more reload switches to it.")
        return
    end
    ns.db.layoutSelectPending, ns.db.layoutSelectTries = false, 0
    if mgr.SelectLayout then
        mgr:SelectLayout(index)
        ns.Print("switched to the " .. LAYOUT_NAME .. " layout")
        ns.QueueApply()
        C_Timer.After(0.5, function() StaticPopup_Show("FCUI_LAYOUT_DONE") end)
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
    if not ns.sessionEnding then return false end
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
-- A layout the client lets anyone write to: the player's own, the
-- addon's among them. The client's presets cannot be changed at all.
function ns.LayoutWritable()
    local mgr = EditModeManagerFrame
    local info = mgr and mgr.GetActiveLayoutInfo and mgr:GetActiveLayoutInfo()
    if not info then return false end
    local preset = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Preset
    return info.layoutType ~= preset
end

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
-- What moves when a target is taken, frame by frame: every frame that
-- matters to the band, its screen rectangle before the change and on
-- each of the six frames after it, with the count of our own band
-- passes beside it so the order is plain.
--
--   /fcui targettrace     toggle; then take two or three targets
local TT_NAMES = { "UIParentBottomManagedFrameContainer", "UIParentRightManagedFrameContainer",
    "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
    "StanceBar", "PetActionBar", "ChatFrame1", "GeneralDockManager", "MainStatusTrackingBarContainer",
    "SecondaryStatusTrackingBarContainer", "ForeverClassicUIBar", "PlayerFrame", "TargetFrame",
    "MicroMenuContainer", "BagsBar", "ObjectiveTrackerFrame" }

local ttWatch

local function TTFrames()
    local list, seen = {}, {}
    local function add(frame, label)
        if frame and not seen[frame] and frame.GetLeft then
            seen[frame] = true
            list[#list + 1] = { frame = frame, label = label }
        end
    end
    for _, name in ipairs(TT_NAMES) do add(_G[name], name) end
    for _, name in ipairs({ "UIParentBottomManagedFrameContainer", "UIParentRightManagedFrameContainer" }) do
        local host = _G[name]
        if host and host.GetChildren then
            for _, child in ipairs({ host:GetChildren() }) do
                add(child, (child.GetName and child:GetName()) or (child.GetDebugName and child:GetDebugName()) or "?")
            end
        end
    end
    return list
end

local function TTRect(frame)
    return frame:GetLeft() or -1, frame:GetBottom() or -1, frame:GetWidth() or 0, frame:GetHeight() or 0,
        frame:IsShown() and true or false
end

local function TargetTrace(on)
    if not ttWatch then
        ttWatch = CreateFrame("Frame")
        ttWatch:SetScript("OnEvent", function(self)
            self.list = TTFrames()
            self.before = {}
            for i, item in ipairs(self.list) do
                local l, b, w, h, shown = TTRect(item.frame)
                self.before[i] = { l, b, w, h, shown }
            end
            self.frameNo = 0
            self.passes = ns.bandPasses or 0
            self.strips = ns.stripPasses or 0
            ns.Persist(string.format("--- target changed at %.3f, band passes so far %d", GetTime(), self.passes))
            self:SetScript("OnUpdate", function(me)
                me.frameNo = me.frameNo + 1
                local passes = ns.bandPasses or 0
                for i, item in ipairs(me.list) do
                    local l, b, w, h, shown = TTRect(item.frame)
                    local was = me.before[i]
                    if math.abs(l - was[1]) > 0.5 or math.abs(b - was[2]) > 0.5 or math.abs(w - was[3]) > 0.5
                        or math.abs(h - was[4]) > 0.5 or shown ~= was[5] then
                        ns.Persist(string.format("  f%d %-40s x %.0f>%.0f y %.0f>%.0f w %.0f>%.0f h %.0f>%.0f shown %s>%s band +%d strip +%d",
                            me.frameNo, item.label, was[1], l, was[2], b, was[3], w, was[4], h,
                            tostring(was[5]), tostring(shown), passes - me.passes, (ns.stripPasses or 0) - me.strips))
                        me.before[i] = { l, b, w, h, shown }
                    end
                end
                if me.frameNo >= 30 then
                    ns.Persist(string.format("  end f30: band +%d strip +%d", (ns.bandPasses or 0) - me.passes,
                        (ns.stripPasses or 0) - me.strips))
                    me:SetScript("OnUpdate", nil)
                end
            end)
        end)
    end
    if on then
        ttWatch:RegisterEvent("PLAYER_TARGET_CHANGED")
    else
        ttWatch:UnregisterEvent("PLAYER_TARGET_CHANGED")
    end
end

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
    elseif cmd == "off" then
        StaticPopup_Show("FCUI_TURN_OFF")
    elseif cmd == "adopt" then
        if ns.ClassicLayoutActive and ns.ClassicLayoutActive() and ns.db.classicBar ~= false then
            ns.QueueLayoutJob("adopt", true)
            ns.AskLayoutReload("Every bar goes back onto the classic bar and is locked there.")
        else
            ns.Print("not now: the classic bar is off, or another layout is active")
        end
    elseif cmd == "targettrace" then
        ns.db.targetTrace = not ns.db.targetTrace
        TargetTrace(ns.db.targetTrace)
        ns.Print("target trace = " .. tostring(ns.db.targetTrace) .. "; take two or three targets, then flush")
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
    elseif cmd == "pin" then
        ns.Print("the bars are locked into the layout whenever the interface reloads or you log out; /reload does it now")
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
        if arg == "reload" then ns.ReloadForLayout() end
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
    else
        -- What was typed is lower case by now and the toggles' names are
        -- not, so the name is found whatever its case.
        local key
        for name, value in pairs(ns.DB_DEFAULTS) do
            if type(value) == "boolean" and name:lower() == cmd then key = name break end
        end
        if key then SetBool(key, arg) else Help() end
    end
end

ns.RegisterModule("options", { init = BuildSettings, apply = function() end, restore = function() end })
