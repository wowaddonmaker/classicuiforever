local _, ns = ...

-- Art table, bronze copies and metal keys. ns.bronze is state private to the Art files.
local B = {}
ns.bronze = B

local BUNDLED = "Interface\\AddOns\\ClassicUIForever\\media\\"

-- Classic art by key: "Dir\\File" (the client's Interface\\Dir\\File, our copy media\\File), "!File" (ours only),
-- "=Dir\\File" (the client's only), "Dir\\File|Copy" (our copy under another name). Paths: ns.TexPaths (Textures.lua).
B.BUNDLED = BUNDLED
ns.TEX = {
    endCap = "MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf",
    barBody = "MainMenuBar\\UI-MainMenuBar-Dwarf",
    barKeyring = "MainMenuBar\\UI-MainMenuBar-KeyRing",
    statusBar = "TargetingFrame\\UI-StatusBar",
    -- Vertical shading only: the XP fill tiles, so a horizontal gradient shows as blocks. Ours only.
    statusBarFlat = "!UI-StatusBar-Flat.tga",
    repBar = "PaperDollInfoFrame\\UI-ReputationWatchBar",
    maxLevel = "MainMenuBar\\UI-MainMenuBar-MaxLevel",
    slotEmpty = "Buttons\\UI-Quickslot",
    slotNormal = "Buttons\\UI-Quickslot2",
    slotPushed = "Buttons\\UI-Quickslot-Depress",
    slotFlash = "Buttons\\UI-QuickslotRed",
    highlight = "Buttons\\ButtonHilight-Square",
    checked = "Buttons\\CheckButtonHilight",
    -- Round glow for the reagent slot (round_hilight.py). Ours only.
    checkedRound = "!CheckButtonHilight-Round.tga",
    equippedBorder = "Buttons\\UI-ActionButton-Border",
    backpackIcon = "Buttons\\Button-Backpack-Up",
    microHighlight = "Buttons\\UI-MicroButton-Hilight",
    iconFrame = "Common\\WhiteIconFrame",
    keyRingUp = "Buttons\\UI-Button-KeyRing",
    keyRingDown = "Buttons\\UI-Button-KeyRing-Down",
    keyRingHighlight = "Buttons\\UI-Button-KeyRing-Highlight",
    -- unit frames
    targetingFrame = "TargetingFrame\\UI-TargetingFrame",
    targetingElite = "TargetingFrame\\UI-TargetingFrame-Elite",
    targetingRare = "TargetingFrame\\UI-TargetingFrame-Rare",
    targetingRareElite = "TargetingFrame\\UI-TargetingFrame-Rare-Elite",
    targetingMinus = "TargetingFrame\\UI-TargetingFrame-Minus",
    targetingFlash = "TargetingFrame\\UI-TargetingFrame-Flash",
    targetingMinusFlash = "TargetingFrame\\UI-TargetingFrame-Minus-Flash",
    levelBackground = "TargetingFrame\\UI-TargetingFrame-LevelBackground",
    skull = "TargetingFrame\\UI-TargetingFrame-Skull",
    targetOfTarget = "TargetingFrame\\UI-TargetofTargetFrame",
    smallTargetingFrame = "TargetingFrame\\UI-SmallTargetingFrame",
    partyFrame = "TargetingFrame\\UI-PartyFrame",
    partyFlash = "TargetingFrame\\UI-PartyFrame-Flash",
    petAttackStatus = "TargetingFrame\\UI-Player-AttackStatus",
    questBadge = "TargetingFrame\\PortraitQuestBadge",
    portraitMask = "CharacterFrame\\TempPortraitAlphaMask",
    stateIcon = "CharacterFrame\\UI-StateIcon",
    playerStatus = "CharacterFrame\\UI-Player-Status",
    leaderIcon = "GroupFrame\\UI-Group-LeaderIcon",
    groupIndicator = "CharacterFrame\\UI-CharacterFrame-GroupIndicator",
    -- cast bars
    castBorder = "CastingBar\\UI-CastingBar-Border",
    castBorderSmall = "CastingBar\\UI-CastingBar-Border-Small",
    castSmallShield = "CastingBar\\UI-CastingBar-Small-Shield",
    castSpark = "CastingBar\\UI-CastingBar-Spark",
    castFlash = "CastingBar\\UI-CastingBar-Flash",
    castFlashSmall = "CastingBar\\UI-CastingBar-Flash-Small",
    -- minimap
    minimapBorder = "Minimap\\UI-Minimap-Border",
    minimapBackground = "Minimap\\UI-Minimap-Background",
    compassNorth = "Minimap\\CompassNorthTag",
    compassRing = "Minimap\\CompassRing",
    zoomInUp = "Minimap\\UI-Minimap-ZoomInButton-Up",
    zoomInDown = "Minimap\\UI-Minimap-ZoomInButton-Down",
    zoomInDisabled = "Minimap\\UI-Minimap-ZoomInButton-Disabled",
    zoomOutUp = "Minimap\\UI-Minimap-ZoomOutButton-Up",
    zoomOutDown = "Minimap\\UI-Minimap-ZoomOutButton-Down",
    zoomOutDisabled = "Minimap\\UI-Minimap-ZoomOutButton-Disabled",
    zoomHighlight = "Minimap\\UI-Minimap-ZoomButton-Highlight",
    trackingBorder = "Minimap\\MiniMap-TrackingBorder",
    -- The client's copy is a wider redraw; ours is the 128x32 original.
    nameplateBorder = "!Nameplate-Border",
    questTrackerButtons = "Buttons\\QuestTrackerButtons",
    barFill = "TargetingFrame\\UI-TargetingFrame-BarFill",
    -- The client's copies are near-black stand-ins; ours are the Era originals.
    questLogTopLeft = "!UI-QuestLog-TopLeft",
    questLogTopRight = "!UI-QuestLog-TopRight",
    questLogBotLeft = "!UI-QuestLog-BotLeft",
    questLogBotRight = "!UI-QuestLog-BotRight",
    -- 3.x dual-pane sheets and the window's map button.
    questLogDualLeft = "!UI-QuestLogDualPane-Left",
    questLogDualRight = "!UI-QuestLogDualPane-Right",
    questMapButton = "=QuestFrame\\UI-QuestMap_Button",
    -- Minimap button face: the end cap's gryphon on a black disc.
    gryphonIcon = "!Gryphon-Icon",
    questLogBook = "QuestFrame\\UI-QuestLog-BookIcon",
    questLogEmptyTopLeft = "!UI-QuestLog-Empty-TopLeft",
    questLogEmptyTopRight = "!UI-QuestLog-Empty-TopRight",
    questLogEmptyBotLeft = "!UI-QuestLog-Empty-BotLeft",
    questLogEmptyBotRight = "!UI-QuestLog-Empty-BotRight",
    questLogTabLeft = "QuestFrame\\UI-QuestLogSortTab-Left",
    questLogTabMiddle = "QuestFrame\\UI-QuestLogSortTab-Middle",
    questLogTabRight = "QuestFrame\\UI-QuestLogSortTab-Right",
    charGeneralTopLeft = "PaperDollInfoFrame\\UI-Character-General-TopLeft",
    charGeneralTopRight = "PaperDollInfoFrame\\UI-Character-General-TopRight",
    charGeneralBotLeft = "PaperDollInfoFrame\\UI-Character-General-BottomLeft",
    charGeneralBotRight = "PaperDollInfoFrame\\UI-Character-General-BottomRight",
    charTabTopLeft = "PaperDollInfoFrame\\UI-Character-CharacterTab-L1",
    charTabTopRight = "PaperDollInfoFrame\\UI-Character-CharacterTab-R1",
    charTabBotLeft = "PaperDollInfoFrame\\UI-Character-CharacterTab-BottomLeft",
    charTabBotRight = "PaperDollInfoFrame\\UI-Character-CharacterTab-BottomRight",
    charStatBox = "PaperDollInfoFrame\\UI-Character-StatBackground",
    -- 1.x's pet tab lower half: the XP bar socket and the training points and Close footer.
    petBotLeft = "PetPaperDollFrame\\UI-PetPaperDollFrame-BotLeft",
    petBotRight = "PetPaperDollFrame\\UI-PetPaperDollFrame-BotRight",
    charResistIcons = "PaperDollInfoFrame\\UI-Character-ResistanceIcons",
    rotateLeftUp = "Buttons\\UI-RotationLeft-Button-Up",
    rotateLeftDown = "Buttons\\UI-RotationLeft-Button-Down",
    rotateRightUp = "Buttons\\UI-RotationRight-Button-Up",
    rotateRightDown = "Buttons\\UI-RotationRight-Button-Down",
    roundHighlight = "Buttons\\ButtonHilight-Round",
    -- The client ships modern stand-ins under these names; ours are the Era originals.
    scrollKnob = "!UI-ScrollBar-Knob",
    scrollUpButtonUp = "!UI-ScrollBar-ScrollUpButton-Up",
    scrollUpButtonDown = "!UI-ScrollBar-ScrollUpButton-Down",
    scrollUpButtonDisabled = "!UI-ScrollBar-ScrollUpButton-Disabled",
    scrollUpButtonHighlight = "!UI-ScrollBar-ScrollUpButton-Highlight",
    scrollDownButtonUp = "!UI-ScrollBar-ScrollDownButton-Up",
    scrollDownButtonDown = "!UI-ScrollBar-ScrollDownButton-Down",
    scrollDownButtonDisabled = "!UI-ScrollBar-ScrollDownButton-Disabled",
    scrollDownButtonHighlight = "!UI-ScrollBar-ScrollDownButton-Highlight",
    -- The client's rep plate is a redraw; ours is the Era sheet (name plate and bar frame).
    repPlate = "!UI-Character-ReputationBar",
    -- Old thin yellow selection line, two pieces on black (drawn ADD).
    repHighlight = "!UI-Character-ReputationBar-Highlight",
    -- Era skill bar: grey gradient fill (blue for skills, standing colour for reputation) and border.
    skillsBar = "!UI-Character-Skills-Bar",
    -- Era loot window: item name box, loot icon, dead-target skull.
    lootNameFrame = "!UI-QuestItemNameFrame",
    lootIcon = "!LootPanel-Icon",
    lootPanel = "!UI-LootPanel",
    -- Era scroll track beside the character sheet's lists.
    charScrollBar = "!UI-Character-ScrollBar",
    -- Era art (the client's are stand-ins): inset marble, rock to the border, frame sheet (title
    -- strip, streaks), merchant bottom strip (repair slots) and item name slots.
    marbleBg = "!UI-Background-Marble",
    rockBg = "!UI-Background-Rock",
    frameSheet = "!_UI-Frame",
    merchantBottom = "!UI-Merchant-BottomBorder",
    merchantLabelSlots = "!UI-Merchant-LabelSlots",
    -- Old bag sheets: the shared bag pieces and the backpack's own.
    bagComponents = "!UI-Bag-Components",
    backpackBg = "!UI-BackpackBackground",
    lootSkull = "TargetingFrame\\TargetDead",
    skillsBarBorder = "!UI-Character-Skills-BarBorder",
    comboPoint = "ComboFrame\\ComboPoint",
    -- Old bank gravel floor, a tile cut from the 1.x window sheet.
    bankFloor = "!UI-BankFrame-Floor",
    -- Empty bag slot icon; the old bank tinted it red for unbought slots.
    bagSlotIcon = "PaperDoll\\UI-PaperDoll-Slot-Bag",
    -- Old options dialog top tabs: active open at the bottom, inactive closed.
    optionsTabActive = "!UI-OptionsFrame-ActiveTab",
    optionsTabInactive = "!UI-OptionsFrame-InActiveTab",
    exhaustionTick = "=MainMenuBar\\UI-ExhaustionTickNormal",
    exhaustionTickHighlight = "=MainMenuBar\\UI-ExhaustionTickHighlight",
    questParchment = "!QuestBG",
    questLogHighlight = "QuestFrame\\UI-QuestLogTitleHighlight",
    calendarButton = "Calendar\\UI-Calendar-Button",
    trackingNone = "Minimap\\Tracking\\None|Tracking-None",
    latencyBar = "!UI-MainMenuBar-LatencyBar.tga",
    -- Era's 1.x key ring sheet (latency window, key slot); every client here has the later one.
    barKeyringClassic = "!UI-MainMenuBar-KeyRing-Classic.blp",
    -- The client's left page with Archaeology's fossil swapped for the old First Aid drop. Ours only.
    professionsBookLeft = "!Professions-Book-Left-FirstAid.tga",
    -- window chrome
    frameMetal = "FrameGeneral\\UIFrameMetal",
    frameMetalH = "FrameGeneral\\UIFrameMetalHorizontal",
    frameMetalV = "FrameGeneral\\UIFrameMetalVertical",
    closeUp = "Buttons\\UI-Panel-MinimizeButton-Up",
    closeDown = "Buttons\\UI-Panel-MinimizeButton-Down",
    closeDisabled = "Buttons\\UI-Panel-MinimizeButton-Disabled",
    closeHighlight = "Buttons\\UI-Panel-MinimizeButton-Highlight",
    tabActive = "PaperDollInfoFrame\\UI-Character-ActiveTab",
    tabInactive = "PaperDollInfoFrame\\UI-Character-InActiveTab",
    tabHighlight = "PaperDollInfoFrame\\UI-Character-Tab-RealHighlight",
    biggerUp = "Buttons\\UI-Panel-BiggerButton-Up",
    biggerDown = "Buttons\\UI-Panel-BiggerButton-Down",
    biggerDisabled = "Buttons\\UI-Panel-BiggerButton-Disabled",
    smallerUp = "Buttons\\UI-Panel-SmallerButton-Up",
    smallerDown = "Buttons\\UI-Panel-SmallerButton-Down",
    smallerDisabled = "Buttons\\UI-Panel-SmallerButton-Disabled",
    clockBackground = "TimeManager\\ClockBackground",
    arrowUpUp = "MainMenuBar\\UI-MainMenu-ScrollUpButton-Up",
    arrowUpDown = "MainMenuBar\\UI-MainMenu-ScrollUpButton-Down",
    arrowUpDisabled = "MainMenuBar\\UI-MainMenu-ScrollUpButton-Disabled",
    arrowUpHighlight = "MainMenuBar\\UI-MainMenu-ScrollUpButton-Highlight",
    arrowDownUp = "MainMenuBar\\UI-MainMenu-ScrollDownButton-Up",
    arrowDownDown = "MainMenuBar\\UI-MainMenu-ScrollDownButton-Down",
    arrowDownDisabled = "MainMenuBar\\UI-MainMenu-ScrollDownButton-Disabled",
    arrowDownHighlight = "MainMenuBar\\UI-MainMenu-ScrollDownButton-Highlight",
}

-- The 1.x micro button sheets: microSpellbookUp, microQuestDown, ...
for _, name in ipairs({ "CharacterNightElf", "Spellbook", "Talents", "Achievement", "Quest", "Socials", "LFG", "Mounts", "EJ", "Help", "BStore", "MainMenu", "World" }) do
    for _, state in ipairs({ "Up", "Down", "Disabled" }) do
        ns.TEX["micro" .. name .. state] = "Buttons\\UI-MicroButton-" .. name .. "-" .. state
    end
end

-- Redrawn by the client under the old names: Socials (a guild banner), Quest ("!" for the goblet), the game menu,
-- the "no tracking" minimap icon, the targeting sheets (oval level ring) and the tabs (a gold rim on the picked one).
B.PREFER = {}
for _, key in ipairs({ "microSocialsUp", "microSocialsDown", "microSocialsDisabled", "microQuestUp", "microQuestDown",
    "microQuestDisabled", "microMainMenuUp", "microMainMenuDown", "microMainMenuDisabled", "trackingNone",
    "targetingFrame", "targetingElite", "targetingRare", "targetingRareElite", "targetingMinus",
    "targetingFlash", "targetingMinusFlash", "tabActive", "tabInactive" }) do
    B.PREFER[key] = true
end

-- 1.x had no Professions button: Forever's picture shrunk into the old frame (dev/tools/professions_micro.py). Ours only.
for _, state in ipairs({ "Up", "Down", "Disabled" }) do
    ns.TEX["microProfessions" .. state] = "!UI-MicroButton-Professions-" .. state .. ".tga"
end

-- The character button is the portrait frame sheet; no disabled version exists.
ns.TEX.microCharacterUp = "Buttons\\UI-MicroButtonCharacter-Up"
ns.TEX.microCharacterDown = "Buttons\\UI-MicroButtonCharacter-Down"
ns.TEX.microCharacterDisabled = ns.TEX.microCharacterUp

-- 1.x spellbook: parchment quarters, school tab plate, page arrows, bottom tabs, empty slot.
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
    ns.TEX[key] = file
end

-- Custom themes ("bronze" in names is the theme on): the colour METAL keys tint to and the folder of copies recoloured
-- on the grey metal only (bronze_variants.py; ThemeArt.lua lists them, loads first). client: tooltips and menus keep
-- Forever's own art. Keys with a copy swap to it with the theme.
local THEMES = {
    bronze = { tint = { 0.9, 0.62, 0.32 }, dir = BUNDLED .. "bronze\\", client = true, copies = {} },
    dark = { tint = { 0.38, 0.38, 0.40 }, dir = BUNDLED .. "dark\\", copies = {} },
}
B.THEMES = THEMES
-- Toggles that change the theme.
B.THEME_KEYS = { bronzeTheme = true, themeBronze = true, themeDark = true }

-- nil while the custom theme is off, else the pick under it.
function ns.ThemeName()
    local db = ns.db
    if not db or db.bronzeTheme ~= true then return nil end
    return db.themeDark == true and "dark" or "bronze"
end

local ART = "\n" .. (ns.THEME_ART or "")
local ART_LOWER = ART:lower()
local function Lookup(path, dir)
    local base = path:match("([^\\/]+)$")
    if not base then return false end
    local key = "\n" .. base:gsub("%.[%a]+$", ""):lower() .. "\n"
    local at = ART_LOWER:find(key, 1, true)
    return at and (dir .. ART:sub(at + 1, at + #key - 2) .. ".tga") or false
end

-- A file's copy in the theme on (bronze while off, for callers asking whether one exists), memoized per theme.
local function BronzeCopy(path)
    if type(path) ~= "string" then return nil end
    local theme = THEMES[ns.ThemeName() or "bronze"]
    local memo = theme.copies
    local copy = memo[path]
    if copy == nil then
        copy = Lookup(path, theme.dir)
        memo[path] = copy
    end
    return copy or nil
end
ns.BronzeCopy = BronzeCopy

-- Metal art tinted bronze with the theme (borders, portrait and minimap rings, window frames).
-- Stone backings are tinted where drawn; parchment and icons are left alone.
local METAL = {
    endCap = true,
    targetingFrame = true, targetingElite = true, targetingRare = true, targetingRareElite = true,
    targetingMinus = true, targetOfTarget = true, smallTargetingFrame = true, partyFrame = true,
    castBorder = true, castBorderSmall = true, castSmallShield = true,
    minimapBorder = true, trackingBorder = true,
    frameMetal = true, frameMetalH = true, frameMetalV = true,
    tabActive = true, tabInactive = true,
    slotNormal = true,
    maxLevel = true, repBar = true, groupIndicator = true,
}
B.METAL = METAL
