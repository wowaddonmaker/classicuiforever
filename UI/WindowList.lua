local _, ns = ...
local L = ns.L

-- Every piece ClassicUI Forever Windows moves and sizes (UI/WindowHandles.lua), one entry each.

-- w, h: box before made; cut: old 384 x 512 frame's bare edges; stripRight, stripH: strip inset, height; toggle: unlock option;
-- quests: the map; section: heading; piece: laid by ns.LayPiece; ringKey: minimap angle (while ringIf); fixedIf: no drag then;
-- choice: radio list; client: game window; follows: place, unlock (while followIf, or always), followSize: size; gameEdit.
ns.WINDOW_LIST = {
    { key = "character", label = L["UI_CHARACTER"], name = "CharacterFrame", w = 354, h = 467, cut = { 30, 45 }, client = true },
    -- The classic professions book wears the spellbook's frame, its corner on the book's art (homes 0, -104 and 12, -118).
    { key = "professions", label = L["UI_PROFESSIONS"], name = "ProfessionsFrame", w = 550, h = 525, client = true,
        follows = "spellBook", followIf = "professionsBook", followX = 12, followY = -14 },
    { key = "talents", label = L["UI_TALENTS"], name = "ClassicUIForeverTalents", w = 354, h = 467, cut = { 30, 45 },
        padHost = true },
    { key = "questLog", label = L["UI_QUEST_LOG"], name = "ForeverClassicUIQuestLog", w = 349, h = 437, cut = { 35, 75 } },
    { key = "map", label = L["UI_WORLD_MAP"], name = "WorldMapFrame", w = 1035, h = 534, stripH = 24, toggle = "mapUnlocked",
        quests = true },
    { key = "calendar", label = L["UI_CALENDAR"], name = "ForeverClassicUICalendarHome", w = 28, h = 28, section = L["UI_MINIMAP"],
        piece = true, ringKey = "calendarAngle", ringIf = "calendarRing", fixedIf = "calendarBehind", choice = "calendarSpot",
        choiceLabel = L["UI_MODE"] },
    { key = "spellBook", label = L["UI_SPELLBOOK"], name = "ForeverClassicUISpellBook", w = 384, h = 512,
        calm = true, padHost = true },
    { key = "minimapZone", label = L["UI_ZONE_NAME"], name = "ForeverClassicUIMinimapZoneHome", w = 140, h = 12,
        section = L["UI_MINIMAP"], piece = true, choice = "minimapZoneShow", choiceLabel = L["UI_SHOW"] },
    { key = "minimapTracking", label = L["UI_TRACKING"], name = "ForeverClassicUIMinimapTrackingHome", w = 32, h = 32,
        section = L["UI_MINIMAP"], piece = true, choice = "minimapTrackingShow", choiceLabel = L["UI_SHOW"] },
    { key = "minimapMail", label = L["UI_MAIL"], name = "ForeverClassicUIMinimapMailHome", w = 33, h = 33,
        section = L["UI_MINIMAP"], piece = true, choice = "minimapMailShow", choiceLabel = L["UI_SHOW"] },
    { key = "minimapZoomIn", label = L["UI_ZOOM_IN"], name = "ForeverClassicUIMinimapZoomInHome", w = 32, h = 32,
        section = L["UI_MINIMAP"], piece = true, ringKey = "zoomInAngle", choice = "minimapZoomInShow", choiceLabel = L["UI_SHOW"] },
    { key = "minimapZoomOut", label = L["UI_ZOOM_OUT"], name = "ForeverClassicUIMinimapZoomOutHome", w = 32, h = 32,
        section = L["UI_MINIMAP"], piece = true, ringKey = "zoomOutAngle", choice = "minimapZoomOutShow", choiceLabel = L["UI_SHOW"] },
    { key = "minimapClock", label = L["UI_CLOCK"], name = "ForeverClassicUIMinimapClockHome", w = 60, h = 28,
        section = L["UI_MINIMAP"], piece = true, choice = "minimapClockShow", choiceLabel = L["UI_SHOW"] },
    { key = "minimapDiel", label = L["UI_DAY_AND_NIGHT"], name = "ForeverClassicUIMinimapDielHome", w = 40, h = 40,
        section = L["UI_MINIMAP"], piece = true, choice = "minimapDielShow", choiceLabel = L["UI_SHOW"] },
    { key = "minimapCoords", label = L["UI_COORDINATES"], name = "ForeverClassicUIMinimapCoordsHome", w = 90, h = 10,
        section = L["UI_MINIMAP"], piece = true, choice = "minimapCoordsShow", choiceLabel = L["UI_SHOW"] },
    -- Our buttons on the ring (Map/MinimapButton.lua); the options button is fixed while the addon bag holds it.
    { key = "minimapOptionsButton", label = L["OPT_minimapButton"], name = "ForeverClassicUIMinimapButton", w = 32, h = 32,
        section = L["UI_MINIMAP"], piece = true, ringKey = "minimapButtonAngle", fixedIf = "minimapCollector",
        choice = "optionsButtonShow", choiceLabel = L["UI_SHOW"] },
    { key = "minimapAddonBag", label = L["MAP_ADDON_BUTTONS"], name = "ForeverClassicUIMinimapCollector", w = 32, h = 32,
        section = L["UI_MINIMAP"], piece = true, ringKey = "minimapCollectorAngle", choice = "addonBagShow", choiceLabel = L["UI_SHOW"] },
    { key = "minimapGroupFinder", label = L["OPT_groupFinder"], name = "ForeverClassicUIGroupFinderButton", w = 32, h = 32,
        section = L["UI_MINIMAP"], piece = true, ringKey = "lfgButtonAngle", choice = "groupFinderButtonShow",
        choiceLabel = L["UI_SHOW"] },
    -- The classic bar's gryphons (Bar/BandArt.lua), on the band ends until placed.
    { key = "gryphonLeft", label = L["UI_GRYPHON_LEFT"], name = "ForeverClassicUIGryphonLeft", w = 128, h = 128,
        piece = true, gameEdit = true, choice = "gryphonLeftShow", choiceLabel = L["UI_SHOW"] },
    { key = "gryphonRight", label = L["UI_GRYPHON_RIGHT"], name = "ForeverClassicUIGryphonRight", w = 128, h = 128,
        piece = true, gameEdit = true, choice = "gryphonRightShow", choiceLabel = L["UI_SHOW"] },
    { key = "social", label = L["UI_SOCIAL"], name = "FriendsFrame", w = 338, h = 424, client = true },
    -- Dressed as the social window, the group finder stands in its place at its size.
    { key = "groupFinder", label = L["OPT_groupFinder"], name = "LFGParentFrame", w = 338, h = 424, client = true,
        follows = "social", followIf = "groupFinder", followX = 0, followY = 0 },
    -- The NPC's quest and gossip windows open on one spot: one place, lock and size.
    { key = "questGiver", label = L["UI_QUEST_GIVER"], name = "QuestFrame", w = 338, h = 427, client = true },
    { key = "gossip", label = L["UI_GOSSIP"], name = "GossipFrame", w = 338, h = 427, client = true,
        follows = "questGiver", followX = 0, followY = 0, followSize = true },
}

-- An entry's window; none for a padHost one inside the game's spell window (gamepad on at login), which places it.
function ns.WindowFrame(entry)
    if entry.padHost and ns.padSession then return nil end
    return _G[entry.name]
end
