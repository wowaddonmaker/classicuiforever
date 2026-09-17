local _, ns = ...

local BUNDLED = "Interface\\AddOns\\ForeverClassicUI\\media\\"

-- Classic art paths as the client shipped them. Every entry also names the
-- copy in media/ so the addon keeps working if a client build drops the file.
ns.TEX = {
    endCap = { builtin = "Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf", bundled = BUNDLED .. "UI-MainMenuBar-EndCap-Dwarf" },
    barBody = { builtin = "Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf", bundled = BUNDLED .. "UI-MainMenuBar-Dwarf" },
    barKeyring = { builtin = "Interface\\MainMenuBar\\UI-MainMenuBar-KeyRing", bundled = BUNDLED .. "UI-MainMenuBar-KeyRing" },
    statusBar = { builtin = "Interface\\TargetingFrame\\UI-StatusBar", bundled = BUNDLED .. "UI-StatusBar" },
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
    questTrackerButtons = { builtin = "Interface\\Buttons\\QuestTrackerButtons", bundled = BUNDLED .. "QuestTrackerButtons" },
    barFill = { builtin = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill", bundled = BUNDLED .. "UI-TargetingFrame-BarFill" },
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

-- Result of the last SetTexture per key, for /fcui debug.
ns.texStatus = {}

function ns.TexPath(key)
    local entry = ns.TEX[key]
    if ns.db and ns.db.textureSource == "bundled" then
        return entry.bundled, entry.builtin
    end
    return entry.builtin, entry.bundled
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
    return ok ~= false
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
