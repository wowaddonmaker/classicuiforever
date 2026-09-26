local _, ns = ...

-- Private table the Options files share.
local O = {}
ns.options = O
O.TITLE = "ClassicUI Forever"

-- key, label, tooltip; parent makes it an indented sub-toggle, grayed while the parent is off; group starts a headed section;
-- radio groups rows where exactly one is on; search adds words the search finds but the row never shows.
-- Order drives the options list, /fcui help and the reload prompt (Core ToggleTree); Status reads it. Kids follow their parent.
ns.TOGGLES = {
    { "bronzeTheme", "Custom theme", "Recolors the classic look's metal (gryphons, borders, minimap rings, tooltips and item slots) in the color picked below.", group = "Look", search = "custom skin color dark mode" },
    { "themeBronze", "Bronze", "Forever's bronze instead of the old silver. Tooltips and menus show Forever's own art.", parent = "bronzeTheme", radio = "theme" },
    { "themeDark", "Dark", "Charcoal metal for a darker interface. Tooltips and menus keep the 1.x shapes, darkened.", parent = "bronzeTheme", radio = "theme" },
    { "panels", "Window frames", "The old metal border, round portrait, small X and stone title strip on the game's windows." },
    { "buttons", "Button style", "Square slot borders, the red attack flash and the old pressed and highlight art." },
    { "squareIcons", "Square icons", "Icons without the rounded mask, as in 1.x.", parent = "buttons" },
    { "hideKeyText", "Hide key text", "No key names on the action buttons.", parent = "buttons" },
    { "castAnim", "Hide cast animation", "Nothing plays over a button while its spell casts, as in 1.x. The cooldown swipe stays." },

    { "classicBar", "Classic bar", "The stone band with gryphons at the bottom: action buttons, page arrows, micro buttons, bags and the experience bar in their 1.x spots.", group = "Action bars" },
    { "defaultBarSize", "Game-sized bar", "The classic bar at the size of the game's own bar (45 px buttons, not 1.x's 36).", parent = "classicBar" },
    { "oneBar", "One bar", "The band ends after the twelve main slots. Bar 3, the micro menu and the bags stay where edit mode puts them.", parent = "classicBar" },
    { "reagentBagSlot", "Reagent bag: full slot", "The reagent bag in a full slot beside the bags, as on WoW Forever's own bar, with the key ring past it.", parent = "classicBar", radio = "reagentBag" },
    { "reagentBagRound", "Reagent bag: round button", "A small round reagent bag between the key ring and the last bag; the bag row keeps its 1.x length.", parent = "classicBar", radio = "reagentBag" },
    { "reagentBagHover", "Reagent bag: round on hover", "The round reagent bag shows only while the mouse is over the bags or the key ring, so the row reads as 1.x.", parent = "classicBar", radio = "reagentBag" },
    { "hideProfessionsButton", "Hide professions button", "Takes the professions button off the micro menu and closes the gap. Professions open from the spellbook, as in 1.x: its professions tab and the books on its General tab.", parent = "classicBar" },
    { "hideLatencyBar", "Hide latency bar", "Takes the old latency bar (green, yellow or red by your connection) off the band. The key ring closes up.", parent = "classicBar" },
    { "hideKeyRing", "Hide key ring", "Takes the key ring off the band. The latency bar closes up.", parent = "classicBar" },
    { "hideBagsArt", "Hide bags bar art", "The bags' own run of band art goes, on the bar or moved off it. The bag buttons stay. Separate from Action Bar 1's Hide Bar Art.", parent = "classicBar" },
    { "hideMicroArt", "Hide micro menu bar art", "The micro menu's own run of band art goes, on the bar or moved off it. The buttons stay. Separate from Action Bar 1's Hide Bar Art.", parent = "classicBar" },
    { "bagsAboveRow", "Bags above bag buttons", "Opened bags stand above the bag buttons and follow them. Off, they open at the bottom right.", parent = "classicBar" },
    { "hideExtraBars", "Hide bars 6 to 8", "1.x had five bars. Bars 6 to 8 fade out and ignore clicks; their keybinds still work." },

    { "unitFrames", "Unit frames", "Player, target, focus, target of target, pet and party frames in the 1.x art. Off takes full effect after a reload.", group = "Unit frames" },
    { "unitFramePlayer", "Player", "The player frame in the old art.", parent = "unitFrames" },
    { "unitFrameTarget", "Target", "The target and target of target frames in the old art.", parent = "unitFrames" },
    { "unitFrameFocus", "Focus", "The focus frame in the old art.", parent = "unitFrames" },
    { "unitFramePet", "Pet", "The pet frame in the old art.", parent = "unitFrames" },
    { "unitFrameParty", "Party", "The party frames in the old art.", parent = "unitFrames" },
    { "classColorHealth", "Class colored health", "Players' health bars take their class color instead of green.", parent = "unitFrames" },
    { "hoverBothNumbers", "Both numbers on hover", "With status text on Numeric or Percentage, hovering a bar shows the percentage and the value together.", parent = "unitFrames" },
    { "eliteFrames", "Elite frames", "The gold dragon of an elite on the frames picked below.", parent = "unitFrames" },
    { "eliteFramePlayer", "Player", "Around your own portrait.", parent = "eliteFrames" },
    { "eliteFrameTarget", "Target", "On every target, not only elites; rares get the rare elite dragon.", parent = "eliteFrames" },
    { "eliteFrameFocus", "Focus", "On every focus, not only elites; rares get the rare elite dragon.", parent = "eliteFrames" },
    { "castBars", "Cast bars", "The 1.x cast bar border, spark and colors on player, pet, target, focus and boss bars." },
    { "comboPoints", "Combo points", "Five orbs down the target portrait's right side, as rogues and cat druids saw them in 1.x." },
    { "mirrorTimers", "Breath and fatigue bars", "The breath, fatigue and feign death timers in the old cast bar style." },
    { "hideBuffArrow", "Hide buff arrow", "The arrow that folds the buffs away shows only under the mouse." },

    { "namePlates", "Nameplates", "The 1.x plate: rounded border with the level, the name above, the cast bar below. Off takes full effect after a reload.", group = "Nameplates" },
    { "classColorPlates", "Class colors", "Players' plates take their class color.", parent = "namePlates" },
    { "fullPlates", "Always full plates", "Friendly players, NPCs and minor mobs get the full plate, not the game's simplified one." },
    { "hideLastNames", "Hide last names", "Turns off every surname setting, so only first names show. The game's own box stays in step." },

    { "gameMenu", "Game menu and dialogs", "The Escape menu, pop-up boxes, edit mode, quick keybind, chat settings, color picker and report box in the old dialog look.", group = "Dialogs" },
    { "settingsPanel", "Settings window", "The game's settings window as the old options dialog." },
    { "lootWindow", "Loot window", "The 1.x loot window: the loot icon in its ring, old name boxes per row and a pager at the foot. Off takes full effect after a reload.", search = "loot frame" },
    { "lootRoll", "Loot rolls", "Need and greed boxes as in 1.x: dice for need, coin for greed, a red X to pass." },

    { "characterSheet", "Character sheet", "The 1.x character window. The arrow at its bottom right opens the TBC side panel with stats and the equipment manager.", group = "Character and spells" },
    { "statPanes", "Stat drop downs", "Two TBC stat boxes under the model, each with a drop down: General, Attributes, Melee, Ranged, Spell, Defense or Resistances.", parent = "characterSheet" },
    { "equipmentQuickButton", "Equipment manager button", "A small button above the gloves slot that opens the equipment manager. The side panel's arrow reaches it too.", parent = "characterSheet" },
    { "weaponSkillDetail", "Weapon skill detail", "Under a weapon skill on the Skills tab, WoW Forever's breakdown: hit and crit against an equal-level enemy and a raid boss, and glancing blows.", parent = "characterSheet" },
    { "spellBook", "Spellbook", "The 1.x parchment spellbook: twelve spells a page, school tabs down the right, page arrows and a pet tab." },
    { "spellBookTopRank", "Top ranks only", "Lists only the highest rank of each spell. Off, every rank shows, as in 1.x.", parent = "spellBook" },
    { "spellBookSearch", "Search box", "A search box on the spellbook that lists every known spell matching the words.", parent = "spellBook" },
    { "talents", "Talent window", "The old talent window: one tree at a time, tree tabs along the foot, rank plates and arrows. Click to stage a point, Learn to commit." },

    { "professionsBook", "Professions book", "The professions overview as the old two-page book, each profession with its emblem, rank bar and spells.", group = "Professions" },
    { "tradeSkill", "Profession windows", "A profession's window as the old trade skill window: recipes by difficulty color above, the chosen recipe and its reagents below." },
    { "tradeSkillSearch", "Recipe search", "A search box on a profession's window that lists only the matching recipes.", parent = "tradeSkill" },
    { "trainer", "Trainer window", "A trainer's window as the old one: services in green, red and gray, what they need and cost, and Train." },

    { "questLog", "Quest log", "The 1.x quest log in its own window. The quest button, key and tracker clicks open it instead of the map.", group = "Quests" },
    { "questLogDual", "Double pane", "The wider 3.x quest log: the list on the left, the quest on parchment beside it. Off is the 1.x single pane.", parent = "questLog" },
    { "questTracker", "Quest tracker", "Old stone headers and small collapse buttons on the objective tracker." },
    { "hideObjectiveTracker", "Hide objective tracker", "Hides the game's objective tracker, for a quest tracker from another addon. Its quest item buttons go with it. Changes wait for the end of a fight.", search = "quest watch objectives" },
    { "worldMap", "World map", "The old metal border, title strip and corner close button on the world map. Off takes full effect after a reload.", group = "Map" },
    { "questMapPane", "Map quest list", "The map's quest list in the quest log's style: dark list, plus and minus headers, 1.x colors, details on parchment." },
    { "mapFade", "Fade map while moving", "The map dims while you move. This is the game's own setting." },
    { "mapUnlocked", "Unlock map", "Drag the world map anywhere by its title bar, no edit mode needed. The lock at the map's top right switches this too.", search = "move map lock" },

    { "whoList", "Who list", "The 1.x Who tab on the social window, in sortable columns. /who answers into it.", group = "Social" },
    { "guildRoster", "Guild roster", "The 1.x guild tab: member count, guild message and the roster in sortable columns." },
    { "groupFinder", "Group finder", "The group finder at the social window's size, with the Who tab's side tabs. Needs Window frames on." },

    { "bags", "Bag windows", "The 1.x bag windows: bag art with the portrait ring, the money strip and the old slots. Off takes full effect after a reload.", group = "Bags" },
    { "oneBag", "One bag", "All bags open as one window in the old art. This is the game's Combine Bags setting." },
    { "bagsBesideBars", "Bags clear side bars", "Opened bags start left of the side action bars instead of covering them." },

    { "minimap", "Minimap", "The round 1.x minimap with the zone name on top and the old tracking, zoom, mail and clock spots.", group = "Minimap and chat" },
    { "classicTracking", "Tracking icon", "Your tracking spell's icon in a ring on the minimap, as in classic. Right-click it to stop tracking.", parent = "minimap" },
    { "minimapButton", "Options button", "A button on the minimap ring that opens these options. Drag it around the ring." },
    { "minimapCollector", "Collect addon buttons", "The other addons' minimap buttons gathered behind one button on the ring; click it for a grid of them. Drag it around the ring.", search = "minimap icons bag" },
    { "classicChat", "Chat buttons", "The chat buttons in one column down the chat's left, as in 1.x. The scroll bar goes; arrows and the wheel scroll." },

    { "gameDamageNumbers", "Damage numbers", "The game's floating damage over your targets. This is the game's own setting.", group = "Other" },
    { "welcomeNote", "Welcome note", "The welcome note on a character's first login with the addon." },
}

-- Radio rows: key -> its group's keys (Core ToggleChanged keeps exactly one on).
ns.TOGGLE_RADIO = {}
do
    local groups = {}
    for _, entry in ipairs(ns.TOGGLES) do
        local name = entry.radio
        if name then
            local group = groups[name] or {}
            groups[name] = group
            group[#group + 1] = entry[1]
            ns.TOGGLE_RADIO[entry[1]] = group
        end
    end
end
