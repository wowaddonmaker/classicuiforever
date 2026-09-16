std = "lua51"
max_line_length = false

ignore = {
    "431",  -- shadowing upvalue
    "432",  -- shadowing upvalue argument
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
    "MainActionBar", "MainMenuBar", "MicroMenu", "MicroMenuContainer", "BagsBar", "ActionButton1", "ForeverClassicUIBar", "KeyRingButton", "InCombatLockdown", "EditModeManagerFrame", "MultiBarBottomLeft", "MultiBarBottomRight", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer", "MultiBarRight", "MultiBarLeft", "StanceBar", "PetActionBar", "PossessActionBar", "StatusTrackingBarManager", "BottomManagedFrameContainer", "RightManagedFrameContainer",
    "WOW_PROJECT_ID",
}
