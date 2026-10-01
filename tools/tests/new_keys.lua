-- What a player updating sees, one line per settings key added after the defaults lock (tools/tests/defaults_test.lua
-- refuses a new key without one). Kept as before: name where (Options/Layout.lua OLD_LOOK, a dbVersion migration).
-- The same for everyone: why that is fine (opt-in and off by default, or nothing on screen).
-- luacheck: std lua54
return {
    hideThreatGlow = "same for everyone: opt-in, off by default",
    plainQuestItems = "same for everyone: opt-in, off by default",
    plainNumbers = "same for everyone: mirrors the game's own setting, which only the player changes",
}
