local _, ns = ...

-- Scalars only: the cvar mirror (Settings.lua) carries nothing else.
ns.DB_DEFAULTS = {
    dbVersion = 1,
    classicBar = true,
    oneBar = false,
    defaultBarSize = false,
    oneBag = false,
    bagsAboveRow = false,
    bagWindowsFollow = false,
    oneBagColumns = 8,
    barOffsetX = 0,
    barOffsetY = 0,
    barDragged = false,
    -- Band snaps are our own record (a snap writes nothing to the layout), plus the snapped bag scale.
    bagsHeld = false,
    bagsSnapScale = 0,
    capHeldLeft = false,
    capHeldRight = false,
    barScale = 1,
    buttons = true,
    squareIcons = true,
    bronzeTheme = false,
    castAnim = true,
    professionsBook = true,
    tradeSkill = true,
    trainer = true,
    tradeSkillSearch = true,
    talents = true,
    professionTabs = false,
    whoTabs = false,
    whoColumn = "zone",
    hideBuffArrow = true,
    spellBookTopRank = false,
    spellDrag = true,
    bagsBesideBars = true,
    gameDamageNumbers = true,
    -- Here so the mirror carries them: Forever can lose saved variables, and the layout to go back to.
    previousLayout = "",
    layoutSelectPending = false,
    layoutSelectTries = 0,
    layoutPrompted = false,
    bandHandedBack = false,
    -- microPos as text: the mirror can't carry tables. bagsFirst is the band order.
    microPosText = "",
    microScale = 1,
    bagsFirst = false,
    hideExtraBars = true,
    unitFrames = true,
    castBars = true,
    mirrorTimers = true,
    comboPoints = true,
    hideLastNames = false,
    classColorHealth = false,
    eliteFrames = false,
    eliteFramePlayer = true,
    eliteFrameTarget = true,
    eliteFrameFocus = true,
    hideStatusMain = false,
    hideStatusSecond = false,
    hoverBothNumbers = true,
    classColorPlates = false,
    mapFade = false,
    welcomeNote = true,
    minimap = true,
    classicTracking = true,
    minimapButton = true,
    minimapButtonAngle = 200,
    namePlates = true,
    fullPlates = true,
    questTracker = true,
    questLog = true,
    questLogDual = false,
    unitFramePlayer = true,
    unitFrameTarget = true,
    unitFrameFocus = true,
    unitFramePet = true,
    unitFrameParty = true,
    questMapPane = true,
    gameMenu = true,
    settingsPanel = true,
    panels = true,
    classicChat = true,
    bags = true,
    characterSheet = true,
    statPanes = true,
    statPaneLeft = "section2",
    statPaneRight = "section3",
    spellBook = true,
    guildRoster = true,
    whoList = true,
    groupFinder = true,
    spellBookSearch = true,
    welcomed = false,
    whatsNewSeen = 0,
    surnamesRepaired = false,
    damageNumbersRepaired = false,
    -- "builtin" = client art, "bundled" = the media/ copies, for files the client drops.
    textureSource = "builtin",
}

-- Module walk order by id, applied at login before any init so .toc moves never reorder modules.
-- Matches the registration order.
ns.MODULE_ORDER = {
    "bronzeTheme", "classicBar", "buttons", "castAnim", "pageArrows", "unitFrames", "hideBuffArrow",
    "castBars", "mirrorTimers", "comboPoints", "minimap", "minimapButton", "namePlates", "classColorPlates",
    "fullPlates", "questTracker", "questLog", "questLogDual", "questMapPane", "panels", "classicChat",
    "guildRoster", "whoList", "groupFinder", "hideLastNames", "mapFade", "oneBag", "bags", "characterSheet", "statPanes",
    "spellBook", "spellBookTopRank", "spellBookSearch", "professionsBook", "tradeSkillSearch", "tradeSkill",
    "trainer", "talents", "options", "gameMenu", "tooltips", "clientMenus", "settingsPanel",
}

-- Reload-only toggles per direction with popup text; unlisted apply live. Owed for art or anchors left on client frames,
-- or client handlers our hand-back leaves tainted (blocked in combat). A child is off while its parent is, unless own = true.
-- Off-only: owed on every turn-off. Both ways: owed while it differs from the session start (pins, spellbook key: once a session).
ns.RELOAD_KEYS = {
    classicBar = {
        -- ns.PinBandBars writes the layout only in ns.ReloadForLayout; unpinned, combat moves the bars.
        on = "The action bars are fixed in the classic bar's places as the interface reloads; until then a fight can move them.",
        -- Pins stay until ns.UnpinBandBars runs in the reload press; Restore only re-anchors.
        off = "The edit mode layout keeps the action bars in the classic bar's places until the interface reloads.",
    },
    spellDrag = {
        own = true,
        -- The spellbook key's click is wired once, at book build (SpellBook LinkLayer).
        on = "Dragging spells to the bars in a fight starts working once the interface reloads.",
        -- Same wiring: the key still opens the client's book behind ours (LinkLayer, TakeButton).
        off = "The spellbook key keeps opening the game's own hidden spellbook until the interface reloads.",
    },
    -- PlayerSpellsUtil entries we write back stay tainted (SpellBook TakeOver).
    spellBook = { off = "The game's own spellbook counts as the addon's until the interface reloads, and misbehaves until then." },
    -- The micro button's click is handed back by our SetScript, so it runs tainted (Talents TakeButton).
    talents = { off = "The talents button opens the game's window in the addon's name until the interface reloads, and a fight can block it." },
    -- Same for QuestLogMicroButton's click (QuestLog Restore).
    questLog = { off = "The quest log button opens the map in the addon's name until the interface reloads, and a fight can block it." },
    -- ToggleGuildFrame stays our wrapper once taken (Guild WrapGuildToggle).
    guildRoster = { off = "The guild key and button go through the addon until the interface reloads, and a fight can block the guild window." },
    -- Restore hides the Who tab only; the first tab keeps its name and the row its cut tabs.
    whoList = { off = "The social window's tabs keep the old names and spacing until the interface reloads." },
    -- Restore hides our host and bars; the client frames keep our anchors and art.
    unitFrames = { off = "The unit frames keep some of the old art and places until the interface reloads." },
    -- Same, for the player frame (RestorePlayer).
    unitFramePlayer = { off = "The player frame keeps some of the old art and places until the interface reloads." },
    -- Target and target of target (RestoreTargetLike).
    unitFrameTarget = { off = "The target frame keeps some of the old art and places until the interface reloads." },
    -- Focus frame (RestoreTargetLike).
    unitFrameFocus = { off = "The focus frame keeps some of the old art and places until the interface reloads." },
    -- No hand-back: nothing removes the pet frame's skin.
    unitFramePet = { off = "The pet frame keeps the old art until the interface reloads." },
    -- Party frames (RestoreParty).
    unitFrameParty = { off = "The party frames keep some of the old art until the interface reloads." },
    -- Restore puts the atlases back only; fill, spark and flash keep our texture and size.
    castBars = { off = "The cast bars keep the old fill and flash until the interface reloads." },
    -- Restore hides the dark ground only; the bars keep our border, texture and size.
    mirrorTimers = { off = "The breath and fatigue bars keep the old border and bar until the interface reloads." },
    -- The client's ComboFrame keeps our anchors (ComboPoints Restore).
    comboPoints = { off = "The game's own combo points keep the old places until the interface reloads." },
    -- Restore hides the ring art only; buttons, zone name and clock keep the old layout.
    minimap = { off = "The minimap's buttons and zone name keep the old places until the interface reloads." },
    -- Restore hides our pieces; the plates keep our anchors, scale and font.
    namePlates = { off = "Nameplates keep the old sizes and places until the interface reloads." },
    -- Only the main header is put back; module headers keep the stone art.
    questTracker = { off = "The objective tracker keeps the old stone headers until the interface reloads." },
    -- Restore hides the floor and parchment; the rows keep the old dress.
    questMapPane = { off = "The map's quest list keeps the old rows until the interface reloads." },
    -- Restore hides the title strips only; dressed windows keep the old frame.
    panels = { off = "Windows already opened keep the old frames until the interface reloads." },
    -- Restore changes nothing; the window keeps our size, buttons and side tabs.
    groupFinder = { off = "The group finder keeps the old size, buttons and side tabs until the interface reloads." },
    -- Restore changes nothing; dressed bag windows keep the old art.
    bags = { off = "Bag windows already opened keep the old art until the interface reloads." },
    -- No characterSheet: its Restore (GiveBack) undoes everything, side pane and setting too.
    -- Restore changes nothing; the window keeps the book's size with its pieces hidden.
    professionsBook = { off = "The professions window keeps the old book's size until the interface reloads." },
    -- The client's crafting page stays parked off screen (ns.ShowTradeSkill).
    tradeSkill = { off = "A profession's own crafting page stays out of sight until the interface reloads." },
    -- Restore changes nothing; the menu keeps the old dialog art.
    gameMenu = { off = "The game menu keeps the old dialog look until the interface reloads." },
    -- Restore changes nothing; the window keeps the old dialog art.
    settingsPanel = { off = "The settings window keeps the old dialog look until the interface reloads." },
}
