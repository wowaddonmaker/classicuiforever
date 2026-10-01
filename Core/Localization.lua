local _, ns = ...

-- Localization: Locales/enUS.lua fills L first, then the client's language file overrides what it translates.
-- Keys are stable ids (OPT_<toggle key>, GROUP_<title>): wording edits never desync the translations.
-- A key no file sets returns itself, so a missing string shows in development instead of breaking.

local L = setmetatable({}, { __index = function(_, key)
    if type(key) == "string" then return key end
    return ""
end })
ns.L = L
