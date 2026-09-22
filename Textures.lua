local _, ns = ...

local BUNDLED = "Interface\\AddOns\\ClassicUIForever\\media\\"

-- Classic art paths as the client shipped them. Every entry also names the
-- copy in media/ so the addon keeps working if a client build drops the file.
ns.TEX = {
    endCap = { builtin = "Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf", bundled = BUNDLED .. "UI-MainMenuBar-EndCap-Dwarf" },
    barBody = { builtin = "Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf", bundled = BUNDLED .. "UI-MainMenuBar-Dwarf" },
    barKeyring = { builtin = "Interface\\MainMenuBar\\UI-MainMenuBar-KeyRing", bundled = BUNDLED .. "UI-MainMenuBar-KeyRing" },
    statusBar = { builtin = "Interface\\TargetingFrame\\UI-StatusBar", bundled = BUNDLED .. "UI-StatusBar" },
    -- The same shading down its height and none along its length. The
    -- old sheet runs dark to light across its width, which is right for a
    -- bar the sheet is stretched over once. The experience bar's fill is
    -- not stretched, it is tiled, so the sheet came out as a row of dark
    -- to light blocks along the bar. No client file is shaded this way,
    -- so both names point at the copy in media/.
    statusBarFlat = { builtin = BUNDLED .. "UI-StatusBar-Flat.tga", bundled = BUNDLED .. "UI-StatusBar-Flat.tga" },
    repBar = { builtin = "Interface\\PaperDollInfoFrame\\UI-ReputationWatchBar", bundled = BUNDLED .. "UI-ReputationWatchBar" },
    maxLevel = { builtin = "Interface\\MainMenuBar\\UI-MainMenuBar-MaxLevel", bundled = BUNDLED .. "UI-MainMenuBar-MaxLevel" },
    slotEmpty = { builtin = "Interface\\Buttons\\UI-Quickslot", bundled = BUNDLED .. "UI-Quickslot" },
    slotNormal = { builtin = "Interface\\Buttons\\UI-Quickslot2", bundled = BUNDLED .. "UI-Quickslot2" },
    slotPushed = { builtin = "Interface\\Buttons\\UI-Quickslot-Depress", bundled = BUNDLED .. "UI-Quickslot-Depress" },
    slotFlash = { builtin = "Interface\\Buttons\\UI-QuickslotRed", bundled = BUNDLED .. "UI-QuickslotRed" },
    highlight = { builtin = "Interface\\Buttons\\ButtonHilight-Square", bundled = BUNDLED .. "ButtonHilight-Square" },
    checked = { builtin = "Interface\\Buttons\\CheckButtonHilight", bundled = BUNDLED .. "CheckButtonHilight" },
    equippedBorder = { builtin = "Interface\\Buttons\\UI-ActionButton-Border", bundled = BUNDLED .. "UI-ActionButton-Border" },
    backpackIcon = { builtin = "Interface\\Buttons\\Button-Backpack-Up", bundled = BUNDLED .. "Button-Backpack-Up" },
    microHighlight = { builtin = "Interface\\Buttons\\UI-MicroButton-Hilight", bundled = BUNDLED .. "UI-MicroButton-Hilight" },
    iconFrame = { builtin = "Interface\\Common\\WhiteIconFrame", bundled = BUNDLED .. "WhiteIconFrame" },
    keyRingUp = { builtin = "Interface\\Buttons\\UI-Button-KeyRing", bundled = BUNDLED .. "UI-Button-KeyRing" },
    keyRingDown = { builtin = "Interface\\Buttons\\UI-Button-KeyRing-Down", bundled = BUNDLED .. "UI-Button-KeyRing-Down" },
    keyRingHighlight = { builtin = "Interface\\Buttons\\UI-Button-KeyRing-Highlight", bundled = BUNDLED .. "UI-Button-KeyRing-Highlight" },
    -- unit frames
    targetingFrame = { builtin = "Interface\\TargetingFrame\\UI-TargetingFrame", bundled = BUNDLED .. "UI-TargetingFrame" },
    targetingElite = { builtin = "Interface\\TargetingFrame\\UI-TargetingFrame-Elite", bundled = BUNDLED .. "UI-TargetingFrame-Elite" },
    targetingRare = { builtin = "Interface\\TargetingFrame\\UI-TargetingFrame-Rare", bundled = BUNDLED .. "UI-TargetingFrame-Rare" },
    targetingRareElite = { builtin = "Interface\\TargetingFrame\\UI-TargetingFrame-Rare-Elite", bundled = BUNDLED .. "UI-TargetingFrame-Rare-Elite" },
    targetingMinus = { builtin = "Interface\\TargetingFrame\\UI-TargetingFrame-Minus", bundled = BUNDLED .. "UI-TargetingFrame-Minus" },
    targetingFlash = { builtin = "Interface\\TargetingFrame\\UI-TargetingFrame-Flash", bundled = BUNDLED .. "UI-TargetingFrame-Flash" },
    targetingMinusFlash = { builtin = "Interface\\TargetingFrame\\UI-TargetingFrame-Minus-Flash", bundled = BUNDLED .. "UI-TargetingFrame-Minus-Flash" },
    levelBackground = { builtin = "Interface\\TargetingFrame\\UI-TargetingFrame-LevelBackground", bundled = BUNDLED .. "UI-TargetingFrame-LevelBackground" },
    skull = { builtin = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull", bundled = BUNDLED .. "UI-TargetingFrame-Skull" },
    targetOfTarget = { builtin = "Interface\\TargetingFrame\\UI-TargetofTargetFrame", bundled = BUNDLED .. "UI-TargetofTargetFrame" },
    smallTargetingFrame = { builtin = "Interface\\TargetingFrame\\UI-SmallTargetingFrame", bundled = BUNDLED .. "UI-SmallTargetingFrame" },
    partyFrame = { builtin = "Interface\\TargetingFrame\\UI-PartyFrame", bundled = BUNDLED .. "UI-PartyFrame" },
    partyFlash = { builtin = "Interface\\TargetingFrame\\UI-PartyFrame-Flash", bundled = BUNDLED .. "UI-PartyFrame-Flash" },
    petAttackStatus = { builtin = "Interface\\TargetingFrame\\UI-Player-AttackStatus", bundled = BUNDLED .. "UI-Player-AttackStatus" },
    questBadge = { builtin = "Interface\\TargetingFrame\\PortraitQuestBadge", bundled = BUNDLED .. "PortraitQuestBadge" },
    portraitMask = { builtin = "Interface\\CharacterFrame\\TempPortraitAlphaMask", bundled = BUNDLED .. "TempPortraitAlphaMask" },
    stateIcon = { builtin = "Interface\\CharacterFrame\\UI-StateIcon", bundled = BUNDLED .. "UI-StateIcon" },
    playerStatus = { builtin = "Interface\\CharacterFrame\\UI-Player-Status", bundled = BUNDLED .. "UI-Player-Status" },
    leaderIcon = { builtin = "Interface\\GroupFrame\\UI-Group-LeaderIcon", bundled = BUNDLED .. "UI-Group-LeaderIcon" },
    -- cast bars
    castBorder = { builtin = "Interface\\CastingBar\\UI-CastingBar-Border", bundled = BUNDLED .. "UI-CastingBar-Border" },
    castBorderSmall = { builtin = "Interface\\CastingBar\\UI-CastingBar-Border-Small", bundled = BUNDLED .. "UI-CastingBar-Border-Small" },
    castSmallShield = { builtin = "Interface\\CastingBar\\UI-CastingBar-Small-Shield", bundled = BUNDLED .. "UI-CastingBar-Small-Shield" },
    castSpark = { builtin = "Interface\\CastingBar\\UI-CastingBar-Spark", bundled = BUNDLED .. "UI-CastingBar-Spark" },
    castFlash = { builtin = "Interface\\CastingBar\\UI-CastingBar-Flash", bundled = BUNDLED .. "UI-CastingBar-Flash" },
    castFlashSmall = { builtin = "Interface\\CastingBar\\UI-CastingBar-Flash-Small", bundled = BUNDLED .. "UI-CastingBar-Flash-Small" },
    -- minimap
    minimapBorder = { builtin = "Interface\\Minimap\\UI-Minimap-Border", bundled = BUNDLED .. "UI-Minimap-Border" },
    minimapBackground = { builtin = "Interface\\Minimap\\UI-Minimap-Background", bundled = BUNDLED .. "UI-Minimap-Background" },
    compassNorth = { builtin = "Interface\\Minimap\\CompassNorthTag", bundled = BUNDLED .. "CompassNorthTag" },
    compassRing = { builtin = "Interface\\Minimap\\CompassRing", bundled = BUNDLED .. "CompassRing" },
    zoomInUp = { builtin = "Interface\\Minimap\\UI-Minimap-ZoomInButton-Up", bundled = BUNDLED .. "UI-Minimap-ZoomInButton-Up" },
    zoomInDown = { builtin = "Interface\\Minimap\\UI-Minimap-ZoomInButton-Down", bundled = BUNDLED .. "UI-Minimap-ZoomInButton-Down" },
    zoomInDisabled = { builtin = "Interface\\Minimap\\UI-Minimap-ZoomInButton-Disabled", bundled = BUNDLED .. "UI-Minimap-ZoomInButton-Disabled" },
    zoomOutUp = { builtin = "Interface\\Minimap\\UI-Minimap-ZoomOutButton-Up", bundled = BUNDLED .. "UI-Minimap-ZoomOutButton-Up" },
    zoomOutDown = { builtin = "Interface\\Minimap\\UI-Minimap-ZoomOutButton-Down", bundled = BUNDLED .. "UI-Minimap-ZoomOutButton-Down" },
    zoomOutDisabled = { builtin = "Interface\\Minimap\\UI-Minimap-ZoomOutButton-Disabled", bundled = BUNDLED .. "UI-Minimap-ZoomOutButton-Disabled" },
    zoomHighlight = { builtin = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", bundled = BUNDLED .. "UI-Minimap-ZoomButton-Highlight" },
    trackingBorder = { builtin = "Interface\\Minimap\\MiniMap-TrackingBorder", bundled = BUNDLED .. "MiniMap-TrackingBorder" },
    -- The client's copy of this sheet is a wider redraw with a broader
    -- level slot; the bundled one is the 128x32 original, used on purpose.
    nameplateBorder = { builtin = BUNDLED .. "Nameplate-Border", bundled = BUNDLED .. "Nameplate-Border" },
    questTrackerButtons = { builtin = "Interface\\Buttons\\QuestTrackerButtons", bundled = BUNDLED .. "QuestTrackerButtons" },
    barFill = { builtin = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill", bundled = BUNDLED .. "UI-TargetingFrame-BarFill" },
    -- The client still ships these eight files, but as near-black stand-ins;
    -- the bundled copies are the Classic Era originals and are used on purpose.
    questLogTopLeft = { builtin = BUNDLED .. "UI-QuestLog-TopLeft", bundled = BUNDLED .. "UI-QuestLog-TopLeft" },
    questLogTopRight = { builtin = BUNDLED .. "UI-QuestLog-TopRight", bundled = BUNDLED .. "UI-QuestLog-TopRight" },
    questLogBotLeft = { builtin = BUNDLED .. "UI-QuestLog-BotLeft", bundled = BUNDLED .. "UI-QuestLog-BotLeft" },
    questLogBotRight = { builtin = BUNDLED .. "UI-QuestLog-BotRight", bundled = BUNDLED .. "UI-QuestLog-BotRight" },
    -- The 3.x double pane sheets and the map button of its window.
    questLogDualLeft = { builtin = BUNDLED .. "UI-QuestLogDualPane-Left", bundled = BUNDLED .. "UI-QuestLogDualPane-Left" },
    questLogDualRight = { builtin = BUNDLED .. "UI-QuestLogDualPane-Right", bundled = BUNDLED .. "UI-QuestLogDualPane-Right" },
    questMapButton = { builtin = "Interface\\QuestFrame\\UI-QuestMap_Button", bundled = "Interface\\QuestFrame\\UI-QuestMap_Button" },
    -- The minimap button's face: the gryphon on a black disc, cut from the end cap.
    gryphonIcon = { builtin = BUNDLED .. "Gryphon-Icon", bundled = BUNDLED .. "Gryphon-Icon" },
    questLogBook = { builtin = "Interface\\QuestFrame\\UI-QuestLog-BookIcon", bundled = BUNDLED .. "UI-QuestLog-BookIcon" },
    questLogEmptyTopLeft = { builtin = BUNDLED .. "UI-QuestLog-Empty-TopLeft", bundled = BUNDLED .. "UI-QuestLog-Empty-TopLeft" },
    questLogEmptyTopRight = { builtin = BUNDLED .. "UI-QuestLog-Empty-TopRight", bundled = BUNDLED .. "UI-QuestLog-Empty-TopRight" },
    questLogEmptyBotLeft = { builtin = BUNDLED .. "UI-QuestLog-Empty-BotLeft", bundled = BUNDLED .. "UI-QuestLog-Empty-BotLeft" },
    questLogEmptyBotRight = { builtin = BUNDLED .. "UI-QuestLog-Empty-BotRight", bundled = BUNDLED .. "UI-QuestLog-Empty-BotRight" },
    questLogTabLeft = { builtin = "Interface\\QuestFrame\\UI-QuestLogSortTab-Left", bundled = BUNDLED .. "UI-QuestLogSortTab-Left" },
    questLogTabMiddle = { builtin = "Interface\\QuestFrame\\UI-QuestLogSortTab-Middle", bundled = BUNDLED .. "UI-QuestLogSortTab-Middle" },
    questLogTabRight = { builtin = "Interface\\QuestFrame\\UI-QuestLogSortTab-Right", bundled = BUNDLED .. "UI-QuestLogSortTab-Right" },
    charGeneralTopLeft = { builtin = "Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft", bundled = BUNDLED .. "UI-Character-General-TopLeft" },
    charGeneralTopRight = { builtin = "Interface\\PaperDollInfoFrame\\UI-Character-General-TopRight", bundled = BUNDLED .. "UI-Character-General-TopRight" },
    charGeneralBotLeft = { builtin = "Interface\\PaperDollInfoFrame\\UI-Character-General-BottomLeft", bundled = BUNDLED .. "UI-Character-General-BottomLeft" },
    charGeneralBotRight = { builtin = "Interface\\PaperDollInfoFrame\\UI-Character-General-BottomRight", bundled = BUNDLED .. "UI-Character-General-BottomRight" },
    charTabTopLeft = { builtin = "Interface\\PaperDollInfoFrame\\UI-Character-CharacterTab-L1", bundled = BUNDLED .. "UI-Character-CharacterTab-L1" },
    charTabTopRight = { builtin = "Interface\\PaperDollInfoFrame\\UI-Character-CharacterTab-R1", bundled = BUNDLED .. "UI-Character-CharacterTab-R1" },
    charTabBotLeft = { builtin = "Interface\\PaperDollInfoFrame\\UI-Character-CharacterTab-BottomLeft", bundled = BUNDLED .. "UI-Character-CharacterTab-BottomLeft" },
    charTabBotRight = { builtin = "Interface\\PaperDollInfoFrame\\UI-Character-CharacterTab-BottomRight", bundled = BUNDLED .. "UI-Character-CharacterTab-BottomRight" },
    charStatBox = { builtin = "Interface\\PaperDollInfoFrame\\UI-Character-StatBackground", bundled = BUNDLED .. "UI-Character-StatBackground" },
    charResistIcons = { builtin = "Interface\\PaperDollInfoFrame\\UI-Character-ResistanceIcons", bundled = BUNDLED .. "UI-Character-ResistanceIcons" },
    rotateLeftUp = { builtin = "Interface\\Buttons\\UI-RotationLeft-Button-Up", bundled = BUNDLED .. "UI-RotationLeft-Button-Up" },
    rotateLeftDown = { builtin = "Interface\\Buttons\\UI-RotationLeft-Button-Down", bundled = BUNDLED .. "UI-RotationLeft-Button-Down" },
    rotateRightUp = { builtin = "Interface\\Buttons\\UI-RotationRight-Button-Up", bundled = BUNDLED .. "UI-RotationRight-Button-Up" },
    rotateRightDown = { builtin = "Interface\\Buttons\\UI-RotationRight-Button-Down", bundled = BUNDLED .. "UI-RotationRight-Button-Down" },
    roundHighlight = { builtin = "Interface\\Buttons\\ButtonHilight-Round", bundled = BUNDLED .. "ButtonHilight-Round" },
    -- The client ships modern stand-ins under these names; the bundled
    -- copies are the Classic Era originals and are used on purpose.
    scrollKnob = { builtin = BUNDLED .. "UI-ScrollBar-Knob", bundled = BUNDLED .. "UI-ScrollBar-Knob" },
    scrollUpButtonUp = { builtin = BUNDLED .. "UI-ScrollBar-ScrollUpButton-Up", bundled = BUNDLED .. "UI-ScrollBar-ScrollUpButton-Up" },
    scrollUpButtonDown = { builtin = BUNDLED .. "UI-ScrollBar-ScrollUpButton-Down", bundled = BUNDLED .. "UI-ScrollBar-ScrollUpButton-Down" },
    scrollUpButtonDisabled = { builtin = BUNDLED .. "UI-ScrollBar-ScrollUpButton-Disabled", bundled = BUNDLED .. "UI-ScrollBar-ScrollUpButton-Disabled" },
    scrollUpButtonHighlight = { builtin = BUNDLED .. "UI-ScrollBar-ScrollUpButton-Highlight", bundled = BUNDLED .. "UI-ScrollBar-ScrollUpButton-Highlight" },
    scrollDownButtonUp = { builtin = BUNDLED .. "UI-ScrollBar-ScrollDownButton-Up", bundled = BUNDLED .. "UI-ScrollBar-ScrollDownButton-Up" },
    scrollDownButtonDown = { builtin = BUNDLED .. "UI-ScrollBar-ScrollDownButton-Down", bundled = BUNDLED .. "UI-ScrollBar-ScrollDownButton-Down" },
    scrollDownButtonDisabled = { builtin = BUNDLED .. "UI-ScrollBar-ScrollDownButton-Disabled", bundled = BUNDLED .. "UI-ScrollBar-ScrollDownButton-Disabled" },
    scrollDownButtonHighlight = { builtin = BUNDLED .. "UI-ScrollBar-ScrollDownButton-Highlight", bundled = BUNDLED .. "UI-ScrollBar-ScrollDownButton-Highlight" },
    -- The client's copy of the reputation plate is a redraw; the bundled
    -- one is the Classic Era sheet (name plate and bar frame), used on purpose.
    repPlate = { builtin = BUNDLED .. "UI-Character-ReputationBar", bundled = BUNDLED .. "UI-Character-ReputationBar" },
    -- The thin yellow line the old sheet drew round the chosen faction:
    -- the same sheet's shape, in two pieces, on black (drawn added).
    repHighlight = { builtin = BUNDLED .. "UI-Character-ReputationBar-Highlight", bundled = BUNDLED .. "UI-Character-ReputationBar-Highlight" },
    -- The old skill bar: a gray gradient fill (tinted blue for skills, by
    -- standing for reputation) and the rounded border around it. Both
    -- are the Classic Era files, bundled on purpose.
    skillsBar = { builtin = BUNDLED .. "UI-Character-Skills-Bar", bundled = BUNDLED .. "UI-Character-Skills-Bar" },
    -- The loot window: the name box behind each item, the loot icon and
    -- the dead-target skull in the portrait ring; Classic Era files.
    lootNameFrame = { builtin = BUNDLED .. "UI-QuestItemNameFrame", bundled = BUNDLED .. "UI-QuestItemNameFrame" },
    lootIcon = { builtin = BUNDLED .. "LootPanel-Icon", bundled = BUNDLED .. "LootPanel-Icon" },
    lootPanel = { builtin = BUNDLED .. "UI-LootPanel", bundled = BUNDLED .. "UI-LootPanel" },
    -- The scroll track beside the character sheet's lists; Classic Era file.
    charScrollBar = { builtin = BUNDLED .. "UI-Character-ScrollBar", bundled = BUNDLED .. "UI-Character-ScrollBar" },
    -- The marble the old windows were floored with, and the merchant's
    -- item name slots; the client's copies are stand-ins, these are Era's.
    marbleBg = { builtin = BUNDLED .. "UI-Background-Marble", bundled = BUNDLED .. "UI-Background-Marble" },
    -- An old window is rock out to its border with streaks under the
    -- title; the marble is the floor of its inset only. The frame sheet
    -- carries the title strip and the streaks; the merchant's bottom
    -- strip holds the repair slots.
    rockBg = { builtin = BUNDLED .. "UI-Background-Rock", bundled = BUNDLED .. "UI-Background-Rock" },
    frameSheet = { builtin = BUNDLED .. "_UI-Frame", bundled = BUNDLED .. "_UI-Frame" },
    merchantBottom = { builtin = BUNDLED .. "UI-Merchant-BottomBorder", bundled = BUNDLED .. "UI-Merchant-BottomBorder" },
    merchantLabelSlots = { builtin = BUNDLED .. "UI-Merchant-LabelSlots", bundled = BUNDLED .. "UI-Merchant-LabelSlots" },
    -- The old bag sheets: the pieces every bag is cut from, and the backpack's own.
    bagComponents = { builtin = BUNDLED .. "UI-Bag-Components", bundled = BUNDLED .. "UI-Bag-Components" },
    backpackBg = { builtin = BUNDLED .. "UI-BackpackBackground", bundled = BUNDLED .. "UI-BackpackBackground" },
    lootSkull = { builtin = "Interface\\TargetingFrame\\TargetDead", bundled = BUNDLED .. "TargetDead" },
    skillsBarBorder = { builtin = BUNDLED .. "UI-Character-Skills-BarBorder", bundled = BUNDLED .. "UI-Character-Skills-BarBorder" },
    comboPoint = { builtin = "Interface\\ComboFrame\\ComboPoint", bundled = BUNDLED .. "ComboPoint" },
    -- The old bank's gravel floor, cut from the 1.x window sheet as a tile.
    bankFloor = { builtin = BUNDLED .. "UI-BankFrame-Floor", bundled = BUNDLED .. "UI-BankFrame-Floor" },
    -- The empty bag slot's bag, which the old bank tinted red for a slot
    -- not yet bought.
    bagSlotIcon = { builtin = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag", bundled = BUNDLED .. "UI-PaperDoll-Slot-Bag" },
    -- The old options dialog's top tabs: the active one open at its foot
    -- onto the box below, the inactive one closed.
    optionsTabActive = { builtin = BUNDLED .. "UI-OptionsFrame-ActiveTab", bundled = BUNDLED .. "UI-OptionsFrame-ActiveTab" },
    optionsTabInactive = { builtin = BUNDLED .. "UI-OptionsFrame-InActiveTab", bundled = BUNDLED .. "UI-OptionsFrame-InActiveTab" },
    exhaustionTick = { builtin = "Interface\\MainMenuBar\\UI-ExhaustionTickNormal", bundled = "Interface\\MainMenuBar\\UI-ExhaustionTickNormal" },
    exhaustionTickHighlight = { builtin = "Interface\\MainMenuBar\\UI-ExhaustionTickHighlight", bundled = "Interface\\MainMenuBar\\UI-ExhaustionTickHighlight" },
    questParchment = { builtin = BUNDLED .. "QuestBG", bundled = BUNDLED .. "QuestBG" },
    questLogHighlight = { builtin = "Interface\\QuestFrame\\UI-QuestLogTitleHighlight", bundled = BUNDLED .. "UI-QuestLogTitleHighlight" },
    calendarButton = { builtin = "Interface\\Calendar\\UI-Calendar-Button", bundled = BUNDLED .. "UI-Calendar-Button" },
    trackingNone = { builtin = "Interface\\Minimap\\Tracking\\None", bundled = BUNDLED .. "Tracking-None" },
    performanceBar = { builtin = "Interface\\MainMenuBar\\UI-MainMenuBar-PerformanceBar", bundled = BUNDLED .. "UI-MainMenuBar-PerformanceBar" },
    -- window chrome
    frameMetal = { builtin = "Interface\\FrameGeneral\\UIFrameMetal", bundled = BUNDLED .. "UIFrameMetal" },
    frameMetalH = { builtin = "Interface\\FrameGeneral\\UIFrameMetalHorizontal", bundled = BUNDLED .. "UIFrameMetalHorizontal" },
    frameMetalV = { builtin = "Interface\\FrameGeneral\\UIFrameMetalVertical", bundled = BUNDLED .. "UIFrameMetalVertical" },
    closeUp = { builtin = "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", bundled = BUNDLED .. "UI-Panel-MinimizeButton-Up" },
    closeDown = { builtin = "Interface\\Buttons\\UI-Panel-MinimizeButton-Down", bundled = BUNDLED .. "UI-Panel-MinimizeButton-Down" },
    closeDisabled = { builtin = "Interface\\Buttons\\UI-Panel-MinimizeButton-Disabled", bundled = BUNDLED .. "UI-Panel-MinimizeButton-Disabled" },
    closeHighlight = { builtin = "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", bundled = BUNDLED .. "UI-Panel-MinimizeButton-Highlight" },
    tabActive = { builtin = "Interface\\PaperDollInfoFrame\\UI-Character-ActiveTab", bundled = BUNDLED .. "UI-Character-ActiveTab" },
    tabInactive = { builtin = "Interface\\PaperDollInfoFrame\\UI-Character-InActiveTab", bundled = BUNDLED .. "UI-Character-InActiveTab" },
    tabHighlight = { builtin = "Interface\\PaperDollInfoFrame\\UI-Character-Tab-RealHighlight", bundled = BUNDLED .. "UI-Character-Tab-RealHighlight" },
    biggerUp = { builtin = "Interface\\Buttons\\UI-Panel-BiggerButton-Up", bundled = BUNDLED .. "UI-Panel-BiggerButton-Up" },
    biggerDown = { builtin = "Interface\\Buttons\\UI-Panel-BiggerButton-Down", bundled = BUNDLED .. "UI-Panel-BiggerButton-Down" },
    biggerDisabled = { builtin = "Interface\\Buttons\\UI-Panel-BiggerButton-Disabled", bundled = BUNDLED .. "UI-Panel-BiggerButton-Disabled" },
    smallerUp = { builtin = "Interface\\Buttons\\UI-Panel-SmallerButton-Up", bundled = BUNDLED .. "UI-Panel-SmallerButton-Up" },
    smallerDown = { builtin = "Interface\\Buttons\\UI-Panel-SmallerButton-Down", bundled = BUNDLED .. "UI-Panel-SmallerButton-Down" },
    smallerDisabled = { builtin = "Interface\\Buttons\\UI-Panel-SmallerButton-Disabled", bundled = BUNDLED .. "UI-Panel-SmallerButton-Disabled" },
    clockBackground = { builtin = "Interface\\TimeManager\\ClockBackground", bundled = BUNDLED .. "ClockBackground" },
    arrowUpUp = { builtin = "Interface\\MainMenuBar\\UI-MainMenu-ScrollUpButton-Up", bundled = BUNDLED .. "UI-MainMenu-ScrollUpButton-Up" },
    arrowUpDown = { builtin = "Interface\\MainMenuBar\\UI-MainMenu-ScrollUpButton-Down", bundled = BUNDLED .. "UI-MainMenu-ScrollUpButton-Down" },
    arrowUpDisabled = { builtin = "Interface\\MainMenuBar\\UI-MainMenu-ScrollUpButton-Disabled", bundled = BUNDLED .. "UI-MainMenu-ScrollUpButton-Disabled" },
    arrowUpHighlight = { builtin = "Interface\\MainMenuBar\\UI-MainMenu-ScrollUpButton-Highlight", bundled = BUNDLED .. "UI-MainMenu-ScrollUpButton-Highlight" },
    arrowDownUp = { builtin = "Interface\\MainMenuBar\\UI-MainMenu-ScrollDownButton-Up", bundled = BUNDLED .. "UI-MainMenu-ScrollDownButton-Up" },
    arrowDownDown = { builtin = "Interface\\MainMenuBar\\UI-MainMenu-ScrollDownButton-Down", bundled = BUNDLED .. "UI-MainMenu-ScrollDownButton-Down" },
    arrowDownDisabled = { builtin = "Interface\\MainMenuBar\\UI-MainMenu-ScrollDownButton-Disabled", bundled = BUNDLED .. "UI-MainMenu-ScrollDownButton-Disabled" },
    arrowDownHighlight = { builtin = "Interface\\MainMenuBar\\UI-MainMenu-ScrollDownButton-Highlight", bundled = BUNDLED .. "UI-MainMenu-ScrollDownButton-Highlight" },
}

-- The 1.x micro button sheets: microSpellbookUp, microQuestDown, ...
for _, name in ipairs({ "CharacterNightElf", "Abilities", "Spellbook", "Talents", "Achievement", "Quest", "Socials", "LFG", "Mounts", "EJ", "Help", "BStore", "MainMenu", "World" }) do
    for _, state in ipairs({ "Up", "Down", "Disabled" }) do
        ns.TEX["micro" .. name .. state] = {
            builtin = "Interface\\Buttons\\UI-MicroButton-" .. name .. "-" .. state,
            bundled = BUNDLED .. "UI-MicroButton-" .. name .. "-" .. state,
        }
    end
end

-- Two the client has redrawn under their old names. Its Socials micro
-- button is a guild banner now, where the old one was the speech bubble,
-- and its "no tracking" minimap icon is not the old magnifying glass.
for _, key in ipairs({ "microSocialsUp", "microSocialsDown", "microSocialsDisabled", "trackingNone" }) do
    if ns.TEX[key] then ns.TEX[key].preferBundled = true end
end

-- The character button is the portrait frame sheet (no disabled version exists).
ns.TEX.microCharacterUp = { builtin = "Interface\\Buttons\\UI-MicroButtonCharacter-Up", bundled = BUNDLED .. "UI-MicroButtonCharacter-Up" }
ns.TEX.microCharacterDown = { builtin = "Interface\\Buttons\\UI-MicroButtonCharacter-Down", bundled = BUNDLED .. "UI-MicroButtonCharacter-Down" }
ns.TEX.microCharacterDisabled = ns.TEX.microCharacterUp

-- The 1.x spellbook: parchment quarters, school tab plate, page arrows,
-- bottom tabs and the empty slot socket.
for key, file in pairs({
    sbTopLeft = "Spellbook\\UI-SpellbookPanel-TopLeft",
    sbTopRight = "Spellbook\\UI-SpellbookPanel-TopRight",
    sbBotLeft = "Spellbook\\UI-SpellbookPanel-BotLeft",
    sbBotRight = "Spellbook\\UI-SpellbookPanel-BotRight",
    sbIcon = "Spellbook\\Spellbook-Icon",
    sbSkillTab = "Spellbook\\SpellBook-SkillLineTab",
    sbEmptySlot = "Spellbook\\UI-Spellbook-SpellBackground",
    sbTabUnselected = "Spellbook\\UI-SpellBook-Tab-Unselected",
    sbTab1Selected = "Spellbook\\UI-SpellBook-Tab1-Selected",
    sbTab3Selected = "Spellbook\\UI-SpellBook-Tab3-Selected",
    sbTabHighlight = "Spellbook\\UI-SpellbookPanel-Tab-Highlight",
    sbPrevUp = "Buttons\\UI-SpellbookIcon-PrevPage-Up",
    sbPrevDown = "Buttons\\UI-SpellbookIcon-PrevPage-Down",
    sbPrevDisabled = "Buttons\\UI-SpellbookIcon-PrevPage-Disabled",
    sbNextUp = "Buttons\\UI-SpellbookIcon-NextPage-Up",
    sbNextDown = "Buttons\\UI-SpellbookIcon-NextPage-Down",
    sbNextDisabled = "Buttons\\UI-SpellbookIcon-NextPage-Disabled",
    mouseHighlight = "Buttons\\UI-Common-MouseHilight",
}) do
    local file_ = file:match("[^\\]+$")
    ns.TEX[key] = { builtin = "Interface\\" .. file, bundled = BUNDLED .. file_ }
end

-- Bronze copies, for the bronze theme, of the art whose metal and face
-- share one sheet: only the grey metal was recoloured (made by
-- dev/tools/bronze_variants.py, listed in BronzeArt.lua), so parchment,
-- pictures and icons keep their colour. Any key whose art has a copy
-- swaps to it with the theme; a tinted key keeps its tint instead.
local BRONZE_DIR = BUNDLED .. "bronze\\"
local function BronzeCopy(path)
    local base = type(path) == "string" and path:match("([^\\/]+)$")
    if not base then return nil end
    base = base:gsub("%.[%a]+$", "")
    local file = ns.BRONZE_ART and ns.BRONZE_ART[base:lower()]
    return file and (BRONZE_DIR .. file .. ".tga") or nil
end
do
    for _, entry in pairs(ns.TEX) do
        entry.bronze = BronzeCopy(entry.bundled)
    end
end

-- Result of the last SetTexture per key, for /fcui debug.
ns.texStatus = {}

function ns.TexPath(key)
    local entry = ns.TEX[key]
    if entry.bronze and ns.db and ns.db.bronzeTheme == true then
        return entry.bronze, entry.bundled
    end
    -- A file this client still has under the old name but has redrawn:
    -- the client's copy is the wrong picture, so ours is the one used.
    if entry.preferBundled or (ns.db and ns.db.textureSource == "bundled") then
        return entry.bundled, entry.builtin
    end
    return entry.builtin, entry.bundled
end

---------------------------------------------------------------------------
-- The bronze theme
---------------------------------------------------------------------------
-- Forever draws its frames in bronze where 1.x drew silver. With the theme
-- on, everything else stays classic and the metal goes bronze: the old
-- silver art of ours is tinted to Forever's bronze, and the client's own
-- bronze pieces this addon otherwise hides or drains are left as the game
-- drew them. Off, the default, is the old silver.
--
-- Every piece that goes through here is remembered, weakly, so turning the
-- theme repaints what is already on screen rather than waiting for each
-- window to be dressed again.
local BRONZE = { 0.9, 0.62, 0.32 }

-- Our art that is metal: frame borders, portrait rings, the minimap's
-- rings, the window frames. The stone backings are tinted where they are
-- drawn (ns.BronzeTint); parchment and icons are left alone.
local METAL = {
    endCap = true,
    targetingFrame = true, targetingElite = true, targetingRare = true, targetingRareElite = true,
    targetingMinus = true, targetOfTarget = true, smallTargetingFrame = true, partyFrame = true,
    castBorder = true, castBorderSmall = true, castSmallShield = true,
    minimapBorder = true, trackingBorder = true,
    frameMetal = true, frameMetalH = true, frameMetalV = true,
    tabActive = true, tabInactive = true,
    slotNormal = true,
    maxLevel = true, repBar = true,
}

-- A key tinted as metal keeps its tint and never swaps to a copy, even
-- where the client's own use of the same sheet has one.
for key in pairs(METAL) do
    if ns.TEX[key] then ns.TEX[key].bronze = nil end
end

local tinted = setmetatable({}, { __mode = "k" })
-- Metal that takes the softer share: the ring round every action slot.
local SOFT_KEYS = { slotNormal = true }
local kept = setmetatable({}, { __mode = "k" })
local drained = setmetatable({}, { __mode = "k" })
local bordered = setmetatable({}, { __mode = "k" })
local swapped = setmetatable({}, { __mode = "k" })

function ns.BronzeOn()
    return ns.db ~= nil and ns.db.bronzeTheme == true
end

-- How much of the bronze a piece takes: all of it, or a softer share for
-- the slots, where the full colour read too strong.
ns.BRONZE_SOFT = 0.9
local function PaintTint(texture)
    if not texture.SetDesaturated then return end
    if ns.BronzeOn() then
        local share = tinted[texture]
        share = type(share) == "number" and share or 1
        texture:SetDesaturated(true)
        texture:SetVertexColor(1 + (BRONZE[1] - 1) * share, 1 + (BRONZE[2] - 1) * share, 1 + (BRONZE[3] - 1) * share)
    else
        texture:SetDesaturated(false)
        texture:SetVertexColor(1, 1, 1)
    end
end

-- A piece of our own silver art that turns bronze with the theme.
function ns.BronzeTint(texture, share)
    if not texture then return end
    tinted[texture] = share or true
    PaintTint(texture)
end

-- A piece of the client's own bronze that this addon hides for the old
-- look: seen with the theme, hidden without it.
function ns.BronzeKeep(region)
    if not region or not region.SetAlpha then return end
    kept[region] = true
    region:SetAlpha(ns.BronzeOn() and 1 or 0)
end

-- Forever's thin bronze frame over an item button's picture, at the
-- picture's own size: every icon carries a grey bevel at its edge, and
-- this lies over it. Shown with the theme, gone without it.
-- An item slot's rim stands this far outside its picture, just beyond the
-- quality colour's own border, so both show.
function ns.BronzeRim(button, icon, outset)
    if not button then return end
    outset = outset or 0
    icon = icon or button.icon or button.Icon
        or (button.GetName and button:GetName() and _G[button:GetName() .. "IconTexture"])
    if not icon then return end
    local rim = button.fcuiBronzeRim
    if not rim then
        rim = button:CreateTexture(nil, "ARTWORK", nil, 7)
        rim:SetTexture(ns.TexPath("iconFrame"))
        button.fcuiBronzeRim = rim
    end
    rim:ClearAllPoints()
    rim:SetPoint("TOPLEFT", icon, "TOPLEFT", -outset, outset)
    rim:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", outset, -outset)
    ns.BronzeTint(rim)
    ns.BronzeKeep(rim)
end

-- A backdrop's silver border, turned bronze with the theme. A border
-- the window greys on its own passes that grey, and keeps its depth in
-- bronze.
-- Where the border's own sheet has a bronze copy (the dialog border, the
-- slider track) the copy is laid on instead of a tint, keeping the
-- frame's fill as it was.
function ns.BronzeBackdrop(frame, r, g, b, a)
    if not frame or not frame.SetBackdropBorderColor then return end
    local base = bordered[frame]
    if r or type(base) ~= "table" then
        base = { r or 1, g or r or 1, b or r or 1, a or 1, info = type(base) == "table" and base.info or nil }
    end
    if not base.info and frame.backdropInfo and frame.backdropInfo.edgeFile then
        local copy = BronzeCopy(frame.backdropInfo.edgeFile)
        if copy then
            local bronzeInfo = {}
            for k, v in pairs(frame.backdropInfo) do bronzeInfo[k] = v end
            bronzeInfo.edgeFile = copy
            base.info = { plain = frame.backdropInfo, bronze = bronzeInfo }
        end
    end
    bordered[frame] = base
    local on = ns.BronzeOn()
    if base.info and frame.SetBackdrop then
        local want = on and base.info.bronze or base.info.plain
        if frame.backdropInfo ~= want then
            local fr, fg, fb, fa = frame:GetBackdropColor()
            frame:SetBackdrop(want)
            if fr then frame:SetBackdropColor(fr, fg, fb, fa) end
        end
        frame:SetBackdropBorderColor(base[1], base[2], base[3], base[4])
    elseif on then
        frame:SetBackdropBorderColor(BRONZE[1] * base[1], BRONZE[2] * base[2], BRONZE[3] * base[3], base[4])
    else
        frame:SetBackdropBorderColor(base[1], base[2], base[3], base[4])
    end
end

-- Art whose metal and colour share one sheet and that has no bronze copy
-- (the client's red buttons): warmed toward bronze, never drained, so the
-- red stays red and the grey border goes warm.
local WARM = { 1, 0.8, 0.58 }
local warmed = setmetatable({}, { __mode = "k" })
local function PaintWarm(texture)
    if ns.BronzeOn() then
        texture:SetVertexColor(WARM[1], WARM[2], WARM[3])
    else
        texture:SetVertexColor(1, 1, 1)
    end
end
function ns.BronzeWarm(texture)
    if not texture or not texture.SetVertexColor then return end
    warmed[texture] = true
    PaintWarm(texture)
end

-- Some of the trim in this client's own windows is bronze where 1.x
-- wore silver: the input boxes, the macro text box, the slider arrows,
-- the guild detail's border. Without the theme those pieces are drained
-- of their color and lit to the old metal; with it they stay as drawn.
local function PaintDrain(region, tint)
    if ns.BronzeOn() then
        region:SetDesaturated(false)
        if region.SetVertexColor then region:SetVertexColor(1, 1, 1) end
        return
    end
    region:SetDesaturated(true)
    if tint and region.SetVertexColor then region:SetVertexColor(tint[1], tint[2], tint[3]) end
end

function ns.DrainBronze(region, r, g, b)
    if not region or not region.SetDesaturated then return end
    local tint = r and { r, g or r, b or r } or false
    drained[region] = tint
    PaintDrain(region, tint)
end

-- Everything remembered, painted for the theme as it now stands.
function ns.RepaintBronze()
    for texture in pairs(tinted) do PaintTint(texture) end
    for region in pairs(kept) do region:SetAlpha(ns.BronzeOn() and 1 or 0) end
    for region, tint in pairs(drained) do
        if region.SetDesaturated then PaintDrain(region, tint or nil) end
    end
    for frame in pairs(bordered) do ns.BronzeBackdrop(frame) end
    for texture in pairs(warmed) do PaintWarm(texture) end
    for texture, what in pairs(swapped) do
        if type(what) == "table" then
            local want = ns.BronzeOn() and what.copy or what.path
            if texture:SetTexture(want, unpack(what.args)) == false then texture:SetTexture(what.path, unpack(what.args)) end
        else
            local primary, fallback = ns.TexPath(what)
            if texture:SetTexture(primary) == false then texture:SetTexture(fallback) end
        end
    end
end

-- SetTexture returns false when the file does not exist; fall back to the
-- other copy so a missing client file never leaves a blank region.
function ns.SetTex(texture, key)
    local primary, fallback = ns.TexPath(key)
    local ok = texture:SetTexture(primary)
    if ok == false then
        ok = texture:SetTexture(fallback)
        ns.texStatus[key] = ok and "fallback" or "missing"
    else
        ns.texStatus[key] = "ok"
    end
    -- A sheet with a bronze copy is swapped for it, and back, as the
    -- theme turns.
    if ns.TEX[key] and ns.TEX[key].bronze then
        swapped[texture] = key
    elseif swapped[texture] then
        swapped[texture] = nil
    end
    if METAL[key] then
        ns.BronzeTint(texture, SOFT_KEYS[key] and ns.BRONZE_SOFT or nil)
    elseif tinted[texture] then
        -- The same texture given a piece that is not metal.
        tinted[texture] = nil
        texture:SetDesaturated(false)
        texture:SetVertexColor(1, 1, 1)
    end
    return ok ~= false
end

-- A texture set by its file rather than by a key, swapped for its bronze
-- copy, and back, as the theme turns.
function ns.SetFile(texture, path, ...)
    if not texture or not path then return end
    local copy = BronzeCopy(path)
    swapped[texture] = copy and { path = path, copy = copy, args = { ... } } or nil
    local ok = texture:SetTexture((copy and ns.BronzeOn()) and copy or path, ...)
    if ok == false and copy then ok = texture:SetTexture(path, ...) end
    return ok ~= false
end

-- The same for one of a button's state textures, set by its file.
function ns.SetButtonFile(button, which, path, ...)
    local setter = button and button["Set" .. which .. "Texture"]
    local getter = button and button["Get" .. which .. "Texture"]
    if not setter or not getter then return end
    setter(button, path, ...)
    local tex = getter(button)
    if tex then ns.SetFile(tex, path) end
    return tex
end

function ns.SetButtonTex(button, which, key)
    local setter = button["Set" .. which .. "Texture"]
    local getter = button["Get" .. which .. "Texture"]
    if not setter or not getter then return end
    local tex = getter(button)
    if not tex then
        setter(button, (ns.TexPath(key)))
        tex = getter(button)
    end
    if not tex then return end
    ns.SetTex(tex, key)
    return tex
end

-- The theme turned from anywhere (the options window, the slash command,
-- the chat line) repaints what is on screen; every module then dresses
-- its own pieces for it as the settings are applied.
ns.RegisterModule("bronzeTheme", { apply = function() ns.RepaintBronze() end, restore = function() ns.RepaintBronze() end })

-- The client's own chat buttons: the friends button, the voice and text to
-- speech buttons and the chat menu. Their frames sit on sheets of the
-- client's (atlas sheets, or plain files) that have bronze copies here, so
-- with the theme each is laid on the copy at the same place on the sheet,
-- and given its own art back without it. The client sets its atlas again
-- as a button is pressed or changes state, which a light watch catches.
local SHEETS = {
    [1537274] = BRONZE_DIR .. "QuickJoin-Atlas.tga",
    [1706035] = BRONZE_DIR .. "ChatFrame-Atlas.tga",
    -- The frame pieces the client builds its insets and inner borders from:
    -- corners, and the strips it tiles along and down.
    [1723831] = BRONZE_DIR .. "UIFrame-Inner-Atlas.tga",
    [1723832] = BRONZE_DIR .. "UIFrame-VTile-Atlas.tga",
    [1723833] = BRONZE_DIR .. "UIFrame-HTile-Atlas.tga",
}
local FILES = {
    [130949] = BRONZE_DIR .. "UI-ChatIcon-Chat-Up.tga",
    [130948] = BRONZE_DIR .. "UI-ChatIcon-Chat-Down.tga",
    [130947] = BRONZE_DIR .. "UI-ChatIcon-Chat-Disabled.tga",
    -- The mail window's own: item slot frames, the bars across it, the
    -- money boxes, the slot backs and the invoice line.
    [136383] = BRONZE_DIR .. "MailItemBorder.tga",
    [130968] = BRONZE_DIR .. "UI-ClassTrainer-HorizontalBar.tga",
    [130975] = BRONZE_DIR .. "Common-Input-Border.tga",
    [130862] = BRONZE_DIR .. "UI-Slot-Background.tga",
    [136387] = BRONZE_DIR .. "UI-MailFrame-InvoiceLine.tga",
    -- The page arrows the client's own windows use (the inbox's pages).
    [130864] = BRONZE_DIR .. "UI-SpellbookIcon-NextPage-Disabled.tga",
    [130865] = BRONZE_DIR .. "UI-SpellbookIcon-NextPage-Down.tga",
    [130866] = BRONZE_DIR .. "UI-SpellbookIcon-NextPage-Up.tga",
    [130867] = BRONZE_DIR .. "UI-SpellbookIcon-PrevPage-Disabled.tga",
    [130868] = BRONZE_DIR .. "UI-SpellbookIcon-PrevPage-Down.tga",
    [130869] = BRONZE_DIR .. "UI-SpellbookIcon-PrevPage-Up.tga",
    -- Item slots in the client's windows (trade, merchant, bank): the ring,
    -- the empty slot and the name plate beside it.
    [130841] = BRONZE_DIR .. "UI-Quickslot2.tga",
    [130766] = BRONZE_DIR .. "UI-EmptySlot.tga",
    [136796] = BRONZE_DIR .. "UI-QuestItemNameFrame.tga",
    -- The client's red buttons, built from slices of the old sheet.
    [130828] = BRONZE_DIR .. "UI-Panel-Button-Up.tga",
    [130825] = BRONZE_DIR .. "UI-Panel-Button-Down.tga",
    [130824] = BRONZE_DIR .. "UI-Panel-Button-Disabled.tga",
    -- The trade window's empty "will not be traded" picture.
    [137072] = BRONZE_DIR .. "UI-TradeFrame-EnchantIcon.tga",
}
local clientWas = setmetatable({}, { __mode = "k" })

local function BronzeClient(texture)
    if not texture or not texture.GetAtlas then return end
    -- Our own pieces the theme already turns (tinted or swapped) are left
    -- to that, or they would be bronzed twice.
    if tinted[texture] or swapped[texture] then return end
    local was = clientWas[texture]
    if not ns.BronzeOn() then
        if was then
            clientWas[texture] = nil
            -- Cleared first: an atlas set again over a texture that still
            -- names it was taken as already there, and the button was left
            -- with nothing drawn at all.
            texture:SetTexture(nil)
            texture:SetTexCoord(0, 1, 0, 1)
            if was.atlas then texture:SetAtlas(was.atlas) else texture:SetTexture(was.file) end
        end
        return
    end
    -- Already on its copy: the client has not set its own art again.
    if was and texture:GetTexture() == was.copyID then return end
    local atlas = texture:GetAtlas()
    if atlas and C_Texture and C_Texture.GetAtlasInfo then
        local info = C_Texture.GetAtlasInfo(atlas)
        local copy = info and SHEETS[info.file]
        -- Laid on only where the copy loads; a failed load drew nothing. A
        -- strip the client tiles along an edge is tiled the same way.
        local across, down = info and info.tilesHorizontally, info and info.tilesVertically
        if copy and texture:SetTexture(copy, across and "REPEAT" or "CLAMP", down and "REPEAT" or "CLAMP") ~= false then
            texture:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)
            if texture.SetHorizTile then texture:SetHorizTile(across and true or false) end
            if texture.SetVertTile then texture:SetVertTile(down and true or false) end
            clientWas[texture] = { atlas = atlas, copyID = texture:GetTexture() }
        elseif copy then
            texture:SetAtlas(atlas)
        end
        return
    end
    local file = texture:GetTexture()
    local copy = type(file) == "number" and FILES[file]
    if copy then
        if texture:SetTexture(copy) ~= false then
            clientWas[texture] = { file = file, copyID = texture:GetTexture() }
        else
            texture:SetTexture(file)
        end
    end
end

local function ChatTextures()
    local list = {}
    local quick = _G["QuickJoinToastButton"]
    if quick and quick.FriendsButton then list[#list + 1] = quick.FriendsButton end
    for _, name in ipairs({ "ChatFrameChannelButton", "TextToSpeechButton", "ChatFrameMenuButton" }) do
        local button = _G[name]
        if button and button.GetNormalTexture then
            for _, state in ipairs({ "Normal", "Pushed", "Disabled" }) do
                local tex = button["Get" .. state .. "Texture"](button)
                if tex then list[#list + 1] = tex end
            end
        end
    end
    return list
end

local CLIENT_WINDOWS = { "MailFrame", "TradeFrame", "MerchantFrame", "BankFrame", "GossipFrame", "QuestFrame",
    "ClassTrainerFrame", "LootFrame" }

-- The trade window's money boxes are locked to addons whole: even asking
-- whether they are shown is refused, so their pieces keep the client's art.

-- Every texture of a client window, down a few levels of its children.
-- Pieces the client keeps from addons (the trade window's money boxes)
-- are passed over: asking a forbidden frame for its regions is an error.
local function Forbidden(object)
    return not object or (object.IsForbidden and object:IsForbidden())
end

local function WalkClient(frame, depth)
    if Forbidden(frame) or depth > 5 or not frame.GetRegions then return end
    local okRegions, regions = pcall(function() return { frame:GetRegions() } end)
    if okRegions then
        for _, region in ipairs(regions) do
            if not Forbidden(region) and region.IsObjectType and region:IsObjectType("Texture") then
                pcall(BronzeClient, region)
            end
        end
    end
    local okChildren, children = pcall(function() return { frame:GetChildren() } end)
    if okChildren then
        for _, child in ipairs(children) do WalkClient(child, depth + 1) end
    end
end

local chatWatch = CreateFrame("Frame")
-- A client window coming up is dressed on the next frame, not at the next
-- half second of the watch: the trade window stood silver for a moment.
for _, event in ipairs({ "TRADE_SHOW", "MAIL_SHOW", "MERCHANT_SHOW", "BANKFRAME_OPENED", "GOSSIP_SHOW",
    "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "TRAINER_SHOW", "LOOT_OPENED" }) do
    pcall(chatWatch.RegisterEvent, chatWatch, event)
end
-- For a second after one opens, every frame: the client fills its slots
-- and redraws their art just after showing the window.
chatWatch:SetScript("OnEvent", function(self) self.since = 1 self.burst = 1 end)
chatWatch:SetScript("OnUpdate", function(self, elapsed)
    self.since = (self.since or 0) + elapsed
    self.burst = (self.burst or 0) - elapsed
    if self.since < 0.5 and self.burst <= 0 then return end
    self.since = 0
    if not ns.db then return end
    if not ns.BronzeOn() then
        -- Everything laid on its copy gets its own art back, whether its
        -- window is open or not.
        for tex in pairs(clientWas) do BronzeClient(tex) end
        return
    end
    for _, tex in ipairs(ChatTextures()) do BronzeClient(tex) end
    -- The client's own windows that carry its plain art: looked over while
    -- they are open.
    for _, name in ipairs(CLIENT_WINDOWS) do
        local window = _G[name]
        if window and window:IsShown() then WalkClient(window, 0) end
    end
end)

-- Buffs and debuffs: the client draws no frame round a buff, only the icon
-- with the grey bevel every icon carries, and the bronze theme lays its
-- thin frame over that bevel, as on the action buttons. A debuff's own
-- border, coloured by its kind, is left as it is. The aura buttons are
-- the client's and come and go from its pools, so they are looked at a
-- few times a second while the theme is on.
local function AuraRims(container)
    if not container or not container.GetChildren then return end
    for _, button in ipairs({ container:GetChildren() }) do
        local icon = button.Icon or button.icon
        if icon and icon.IsObjectType and icon:IsObjectType("Texture") and not button.fcuiBronzeRim then
            ns.BronzeRim(button, icon)
        end
    end
end

local auraWatch = CreateFrame("Frame")
auraWatch:SetScript("OnUpdate", function(self, elapsed)
    self.since = (self.since or 0) + elapsed
    if self.since < 0.5 then return end
    self.since = 0
    if not ns.BronzeOn() then return end
    for _, frame in ipairs({ _G["BuffFrame"], _G["DebuffFrame"] }) do
        if frame then AuraRims(frame.AuraContainer or frame) end
    end
    for _, unitFrame in ipairs({ _G["TargetFrame"], _G["FocusFrame"] }) do
        local auras = unitFrame and unitFrame.GetAuraContainer and unitFrame:GetAuraContainer()
        if auras then AuraRims(auras) end
    end
end)
