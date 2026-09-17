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
    "SlashCmdList",
    "SLASH_FOREVERCLASSICUI1",
    "SLASH_FOREVERCLASSICUI2",
}

read_globals = {
    "date",
    "hooksecurefunc", "wipe", "geterrorhandler",
    "CreateFrame", "C_Timer", "GetBuildInfo", "HasAction",
    "DEFAULT_CHAT_FRAME", "UIParent", "EventRegistry", "Settings",
    "MainActionBar", "MainMenuBar", "MicroMenu", "MicroMenuContainer", "BagsBar", "ActionButton1", "ForeverClassicUIBar", "KeyRingButton", "InCombatLockdown", "EditModeManagerFrame", "MultiBarBottomLeft", "MultiBarBottomRight", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer", "MultiBarRight", "MultiBarLeft", "StanceBar", "PetActionBar", "PossessActionBar", "StatusTrackingBarManager", "MicroMenu", "KeyRingButton", "MainMenuBarBackpackButton", "CharacterReagentBag0Slot", "BagBarExpandToggle", "LoadMicroButtonTextures", "UpdateMicroButtons", "GetNetStats", "HelpOpenWebTicketButton", "MainMenuMicroButton", "C_Texture", "GetTime", "BottomManagedFrameContainer", "RightManagedFrameContainer",
    "WOW_PROJECT_ID",
    "C_DateAndTime", "GetMouseFoci", "GetMouseFocus",
    "C_NamePlate", "NamePlateDriverFrame", "OBJECTIVES_TRACKER_LABEL", "ObjectiveTrackerFrame", "QuestScrollFrame",
    "AddonCompartmentFrame", "BossTargetFrameContainer", "C_CVar", "ExpansionLandingPageMinimapButton", "FocusFrame", "GameTimeFrame", "IsResting", "MiniMapMailIcon", "Minimap", "MinimapBackdrop", "MinimapCluster", "MinimapCompassTexture", "MinimapCompassTextureUnderlay", "MinimapZoneText", "PartyFrame", "PetAttackModeTexture", "PetCastingBarFrame", "PetFrame", "PetFrameFlash", "PetFrameHealthBar", "PetFrameHealthBarMask", "PetFrameHealthBarText", "PetFrameHealthBarTextLeft", "PetFrameHealthBarTextRight", "PetFrameManaBar", "PetFrameManaBarMask", "PetFrameManaBarText", "PetFrameManaBarTextLeft", "PetFrameManaBarTextRight", "PetFrameTexture", "PetHitIndicator", "PetName", "PetPortrait", "PlayerCastingBarFrame", "PlayerFrame", "PlayerLevelText", "PlayerName", "PowerBarColor", "QueueStatusButton", "TargetFrame", "TimeManagerClockButton", "TimeManagerClockTicker", "UnitAffectingCombat", "UnitCastingInfo", "UnitChannelInfo", "UnitClassification", "UnitExists", "UnitHealth", "UnitHealthMax", "UnitPower", "UnitPowerMax", "UnitPowerType", "issecretvalue",
}
