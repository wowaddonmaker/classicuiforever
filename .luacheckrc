std = "lua51"
max_line_length = false

ignore = {
    "431",  -- shadowing upvalue
    "432",  -- shadowing upvalue argument
    "122",  -- setting a field on a Blizzard frame (our fcui tables)
}

globals = {
    "ForeverClassicUIDB",
    "ForeverClassicUI_OnAddonCompartmentClick",
    "ForeverClassicUI_AttachDevTools",
    "ForeverClassicUI_CharacterSheetActive",
    "ForeverClassicUI_SkinCharacterCopy",
    "ForeverClassicUI_CharacterSheetSize",
    "SlashCmdList",
    "SLASH_FOREVERCLASSICUI1",
    "SLASH_FOREVERCLASSICUI2",
}

read_globals = {
    "date",
    "CLOSE", "UIParent", "Minimap", "MinimapCluster", "GetCursorPosition", "UnitLevel", "GetCreatureDifficultyColor", "CASTBAR_CLASSIC_YELLOW", "CASTBAR_CLASSIC_GREEN", "CASTBAR_CLASSIC_GRAY", "CASTBAR_CLASSIC_RED", "CreateColor", "GameTooltip",
    "hooksecurefunc", "wipe", "geterrorhandler",
    "CreateFrame", "C_Timer", "GetBuildInfo", "HasAction",
    "DEFAULT_CHAT_FRAME", "UIParent", "EventRegistry", "Settings",
    "MainActionBar", "MainMenuBar", "MicroMenu", "MicroMenuContainer", "BagsBar", "ActionButton1", "ForeverClassicUIBar", "KeyRingButton", "InCombatLockdown", "EditModeManagerFrame", "MultiBarBottomLeft", "MultiBarBottomRight", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer", "MultiBarRight", "MultiBarLeft", "StanceBar", "PetActionBar", "PossessActionBar", "StatusTrackingBarManager", "MicroMenu", "KeyRingButton", "MainMenuBarBackpackButton", "CharacterReagentBag0Slot", "BagBarExpandToggle", "LoadMicroButtonTextures", "UpdateMicroButtons", "GetNetStats", "HelpOpenWebTicketButton", "MainMenuMicroButton", "StaticPopupDialogs", "StaticPopup_Show", "C_EditMode", "C_UI", "UnitFactionGroup", "LibStub", "bit", "C_Texture", "GetTime", "BottomManagedFrameContainer", "RightManagedFrameContainer",
    "WOW_PROJECT_ID",
    "CreateSettingsButtonInitializer", "EditModePresetLayoutManager", "Enum", "SettingsPanel",
    "C_DateAndTime", "GetMouseFoci", "GetMouseFocus",
    "C_QuestLog", "ExpandQuestHeader", "CollapseQuestHeader", "GetQuestLink", "IsModifiedClick", "IsShiftKeyDown", "ChatFrameUtil", "QuestUtil", "QuestDifficultyColors", "GetQuestDifficultyColor", "MAX_QUESTS", "QUESTS", "FAILED", "COMPLETE", "DAILY", "WEEKLY", "GROUP", "ALL", "TRACK_QUEST", "QUEST_LOG", "QUEST_REWARDS", "QUEST_DESCRIPTION", "REWARD_CHOICES", "REWARD_ITEMS", "REWARD_ITEMS_ONLY", "REWARD_XP", "REQUIRED_MONEY", "TIME_REMAINING", "ABANDON_QUEST", "SHARE_QUEST", "EXIT", "QUESTLOG_NO_QUESTS_TEXT", "GetQuestLogQuestText", "GetQuestLogTimeLeft", "GetNumQuestLeaderBoards", "GetQuestLogLeaderBoard", "GetNumQuestLogChoices", "GetNumQuestLogRewards", "GetQuestLogRewardMoney", "GetQuestLogRewardXP", "GetQuestLogChoiceInfo", "GetQuestLogRewardInfo", "GetQuestLogItemLink", "QuestLogPushQuest", "GetMoney", "SecondsToTime", "BreakUpLargeNumbers", "C_CurrencyInfo", "GetCoinTextureString", "ITEM_QUALITY_COLORS", "IsInGroup", "C_Item", "StaticPopup_Hide", "PlaySound", "SOUNDKIT", "GetBindingKey", "ClearOverrideBindings", "SetOverrideBindingClick", "QuestLogMicroButton", "WorldMapFrame", "HideUIPanel", "GameMenuFrame", "QuestObjectiveTracker", "CampaignQuestObjectiveTracker",
    "UIFrameFadeIn", "UIFrameFade", "UIFrameFadeOut", "UnitCanAttack", "ReputationFrame", "PVPRankFrame", "StatisticsFrame", "TokenFrame", "SkillsFrame", "SetItemRef", "FACTION", "STANDING", "ScrollBoxListMixin", "NEXT", "PREV", "ScrollBoxConstants", "LEVEL", "ComboFrame", "ComboFrame_ApplyOverrides", "ComboFrame_UpdateMax", "UnitRace", "UnitClass", "PLAYER_LEVEL_NO_SPEC", "CHARACTER", "REPUTATION_ABBR", "CURRENCY", "PVP", "SKILLS", "STATISTICS", "ToggleCharacter", "PanelTemplates_TabResize", "PanelTemplates_SelectTab", "PanelTemplates_DeselectTab", "UIErrorsFrame", "ERR_QUEST_PUSH_NOT_IN_PARTY_S", "StoreMicroButton", "GetInventoryItemTexture", "PlayerSpellsUtil", "C_SpellBook", "SPELLBOOK", "PET", "PAGE_NUMBER", "PlayerSpellsFrame", "ShowUIPanel", "SPELL_PASSIVE", "PASSIVE_SPELL_FONT_COLOR", "NORMAL_FONT_COLOR", "GameTooltip_Hide", "ChatEdit_InsertLink", "GameFontHighlightSmall", "CharacterFrame", "PaperDollFrame", "CharacterModelScene", "CharacterLevelText", "CharacterRangedSlot", "UnitStat", "UnitArmor", "UnitAttackBothHands", "UnitAttackPower", "UnitDamage", "UnitRangedAttack", "UnitRangedAttackPower", "UnitRangedDamage", "UnitResistance", "GetInventoryItemID", "SetUIPanelAttribute", "ARMOR", "MELEE_ATTACK", "ATTACK_POWER", "DAMAGE", "RANGED_ATTACK", "MELEE_ATTACK_POWER", "RANGED_ATTACK_POWER", "RESISTANCE", "ToggleWorldMap", "WORLDMAP_BUTTON", "QuestMapFrame", "QuestMapFrame_Close", "ComboPointPlayerFrame", "DruidComboPointBarFrame",
    "C_NamePlate", "UnitLevel", "UnitQuestTrivialLevelRange", "GetQuestGreenRange", "BagItemAutoSortButton", "BagItemSearchBox", "ContainerFrameContainer", "GameFontNormalHuge", "NumberFontNormalHuge", "GameFontNormal", "DAMAGE_TEXT_FONT", "SetCVar", "GetCVar", "UnitIsUnit", "UnitGUID", "NamePlateDriverFrame", "OBJECTIVES_TRACKER_LABEL", "STANDARD_TEXT_FONT", "C_QuestLog", "GetQuestDifficultyColor", "OBJECTIVE_TRACKER_COLOR", "ObjectiveTrackerFrame", "QuestScrollFrame",
    "AddonCompartmentFrame", "BossTargetFrameContainer", "C_CVar", "ExpansionLandingPageMinimapButton", "FocusFrame", "GameTimeFrame", "IsResting", "MiniMapMailIcon", "Minimap", "MinimapBackdrop", "MinimapCluster", "MinimapCompassTexture", "MinimapCompassTextureUnderlay", "MinimapZoneText", "PartyFrame", "PetAttackModeTexture", "PetCastingBarFrame", "PetFrame", "PetFrameFlash", "PetFrameHealthBar", "PetFrameHealthBarMask", "PetFrameHealthBarText", "PetFrameHealthBarTextLeft", "PetFrameHealthBarTextRight", "PetFrameManaBar", "PetFrameManaBarMask", "PetFrameManaBarText", "PetFrameManaBarTextLeft", "PetFrameManaBarTextRight", "PetFrameTexture", "PetHitIndicator", "PetName", "PetPortrait", "PlayerCastingBarFrame", "PlayerFrame", "PlayerLevelText", "PlayerName", "PowerBarColor", "QueueStatusButton", "TargetFrame", "TimeManagerClockButton", "TimeManagerClockTicker", "UnitAffectingCombat", "UnitCastingInfo", "UnitChannelInfo", "UnitClassification", "UnitExists", "UnitHealth", "UnitHealthMax", "UnitPower", "UnitPowerMax", "UnitPowerType", "issecretvalue",
}
