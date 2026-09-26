local _, ns = ...

-- Public API for other addons (global ClassicUIForeverAPI): whether this addon's version of a window stands in for the
-- client's right now, opening it the way its own key does, and its parts under stable names. version rises only when a
-- call changes in a way that breaks callers.

local API = { version = 1 }
ClassicUIForeverAPI = API

local function Shown(frame) return frame ~= nil and frame:IsShown() end

-- "name:<n>" parts: the n in a number, or nil.
local function Numbered(part, prefix)
    local n = type(part) == "string" and part:match("^" .. prefix .. ":(%d+)$")
    return n and tonumber(n)
end

-- Windows Open and GetFrame support: open(arg) -> shown now; frame() -> the window, nil until built; parts: name -> field;
-- part(frame, part) for numbered parts (patterns lists them for Windows).
local WINDOWS = {
    guildRoster = {
        open = function() return ns.OpenGuildRoster() end,
        frame = function() return ns.guild and ns.guild.panel end,
        parts = { list = "listBox", info = "info", control = "control", addMember = "add", showOffline = "offline",
            motd = "motdBox", status = "status" },
    },
    questLog = {
        -- arg: a quest ID to select.
        open = function(questID)
            ns.ShowQuestLog(questID)
            return Shown(ns.QL.Frame())
        end,
        frame = function() return ns.QL and ns.QL.Frame() end,
        parts = { abandon = "abandon", share = "share", close = "close" },
    },
    spellBook = {
        -- arg: "pet" for the pet's book.
        open = function(which)
            ns.ShowSpellBookBank(which == "pet")
            return Shown(_G.ForeverClassicUISpellBook)
        end,
        frame = function() return _G.ForeverClassicUISpellBook end,
        parts = { search = "Search", prevPage = "PrevPage", nextPage = "NextPage" },
        -- tab:<n> skill line tabs down the side, bookTab:<n> the foot tabs, spell:<id> the button showing that spell.
        patterns = { "tab:<n>", "bookTab:<n>", "spell:<spellID>" },
        part = function(frame, part)
            local n = Numbered(part, "tab")
            if n then return frame.SkillTabs[n] end
            n = Numbered(part, "bookTab")
            if n then return frame.BookTabs[n] end
            n = Numbered(part, "spell")
            if n then return ns.SpellBookButtonFor(n) end
        end,
    },
    talents = {
        -- arg: a tree tab number.
        open = function(tab) return ns.ShowTalents(tab) end,
        frame = function() return _G.ClassicUIForeverTalents end,
        parts = { learn = "learn", reset = "reset" },
        patterns = { "tab:<n>" },
        part = function(frame, part)
            local n = Numbered(part, "tab")
            if n then return frame.tabs[n] end
        end,
    },
    whoList = {
        open = function() return ns.OpenWhoList() end,
        frame = function() return ns.WhoPanel() end,
        parts = { search = "query", list = "listBox", refresh = "refresh", addFriend = "add", invite = "invite" },
    },
}

-- Whether the toggle name's replacement is in force now (a change still owed a reload counts as not made yet).
function API.IsOn(name)
    return type(name) == "string" and ns.ModuleInForce(name)
end

-- Opens this addon's version as its own key does. False when it is not in force, not supported, or can't open now
-- (a window the client keeps shut in combat opens after it).
function API.Open(name, arg)
    local window = WINDOWS[name]
    if not window or not API.IsOn(name) then return false end
    local ok, shown = pcall(window.open, arg)
    return ok and shown == true
end

-- The window (part nil) or one of its parts; nil when unknown or not built yet.
function API.GetFrame(name, part)
    local window = WINDOWS[name]
    local frame = window and window.frame()
    if not frame or part == nil then return frame end
    local field = window.parts[part]
    if field then return frame[field] end
    return window.part and window.part(frame, part) or nil
end

-- The spell a spellbook page button shows right now (nil once its page turned away, or for any other frame): the stable way
-- to tell a button from GetFrame("spellBook", "spell:<id>") still shows that spell.
function API.SpellOnButton(button)
    return ns.SpellBookButtonSpell(button)
end

-- The windows Open and GetFrame support, each with its part names.
function API.Windows()
    local list = {}
    for name, window in pairs(WINDOWS) do
        local parts = {}
        for part in pairs(window.parts) do parts[#parts + 1] = part end
        for _, pattern in ipairs(window.patterns or {}) do parts[#parts + 1] = pattern end
        table.sort(parts)
        list[name] = parts
    end
    return list
end
