local _, ns = ...

-- Shared helpers; each answers its question and leaves unreadable values to the caller.

-- A client without issecretvalue has no secrets.
local secretTest = type(issecretvalue) == "function" and issecretvalue or nil

local function IsSecret(v)
    if secretTest and secretTest(v) then return true end
    return false
end
ns.IsSecret = IsSecret

-- Secret test first, so a secret is never compared.
function ns.Safe(v, fallback)
    if IsSecret(v) or v == nil then return fallback end
    return v
end

-- Classic Era's wording where Forever rewrote a global string (Era 1.15.9 GlobalStrings); other languages keep the client's.
local ERA_TEXT = {
    NEWBIE_TOOLTIP_CHARACTER = "Information about your character, including equipment, statistics, skills, and reputation.",
    NEWBIE_TOOLTIP_SPELLBOOK = "All of your spells and abilities. To move a spell or ability to your Action Bar, open the "
        .. "Spellbook & Abilities window, left-click that spell or ability, and drag it down to your Action Bar.",
    -- Era's sentence said 20: the cap is this client's.
    NEWBIE_TOOLTIP_QUESTLOG = function()
        local max = C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept()
        if type(max) ~= "number" or IsSecret(max) then return nil end
        return ("A list of all the active quests you currently have. You can have up to %d active quests at one time.")
            :format(max)
    end,
    NEWBIE_TOOLTIP_LFGPARENT = "Find other players to group with to tackle challenging content.",
    NEWBIE_TOOLTIP_MAINMENU = "Here you can modify your video, sound, and interface settings, or create custom hotkeys. "
        .. "You can also choose to log out or exit the program altogether.",
    NEWBIE_TOOLTIP_LATENCY = "The average time it takes to talk with the game server. A low latency will display as a green "
        .. "bar, higher latencies will be yellow or even red. Consistently high latencies may indicate a problem with your "
        .. "Internet connection.",
}
local english = GetLocale and (GetLocale() == "enUS" or GetLocale() == "enGB")
function ns.EraText(key)
    local text = english and ERA_TEXT[key] or nil
    if type(text) == "function" then text = text() end
    text = text or _G[key]
    if type(text) == "string" and text ~= "" then return text end
end

function ns.AnySecret(...)
    if not secretTest then return false end
    for i = 1, select("#", ...) do
        if secretTest((select(i, ...))) then return true end
    end
    return false
end

-- Shared empty table; writes error.
ns.EMPTY = setmetatable({}, {
    __newindex = function() error("ns.EMPTY is shared and stays empty", 2) end,
    __metatable = false,
})

-- nil when missing or the call fails.
-- The value the client ships with; nil when unknown.
function ns.GetCVarDefault(name)
    local get = C_CVar and C_CVar.GetCVarDefault
    if name == nil or type(get) ~= "function" then return nil end
    local ok, value = pcall(get, name)
    return ok and value or nil
end

function ns.GetCVar(name)
    if name == nil then return nil end
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    if type(get) ~= "function" then return nil end
    local ok, value = pcall(get, name)
    if ok then return value end
    return nil
end

-- nil when missing or the call fails.
function ns.GetCVarBool(name)
    if name == nil or not (C_CVar and C_CVar.GetCVarBool) then return nil end
    local ok, value = pcall(C_CVar.GetCVarBool, name)
    if ok then return value end
    return nil
end

-- Missing or forbidden: may not be asked anything.
function ns.IsForbidden(object)
    return not object or (object.IsForbidden and object:IsForbidden())
end

-- One pcall per event so one this client lacks fails alone; unit1/unit2 make unit events.
local function RegisterOne(frame, event, unit1, unit2)
    if unit2 ~= nil then return pcall(frame.RegisterUnitEvent, frame, event, unit1, unit2) end
    if unit1 ~= nil then return pcall(frame.RegisterUnitEvent, frame, event, unit1) end
    return pcall(frame.RegisterEvent, frame, event)
end

-- The button a key binds to: acts on press (the game's key down setting, as its own windows) and clicks target, whose
-- release action and chained /clicks stay as they are. Out of combat, once per target; returns its name.
local keyProxies = {}
function ns.KeyProxy(targetName)
    local name = targetName .. "Key"
    if keyProxies[name] then return name end
    local target = _G[targetName]
    if not target or InCombatLockdown() then return targetName end
    local proxy = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    proxy:SetSize(1, 1)
    proxy:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
    proxy:EnableMouse(false)
    proxy:RegisterForClicks("AnyDown", "AnyUp")
    proxy:SetAttribute("type", "click")
    proxy:SetAttribute("clickbutton", target)
    keyProxies[name] = proxy
    return name
end

-- Returns how many registered.
function ns.RegisterEvents(frame, list, unit1, unit2)
    if not frame or type(list) ~= "table" then return 0 end
    local count = 0
    for i = 1, #list do
        if RegisterOne(frame, list[i], unit1, unit2) then count = count + 1 end
    end
    return count
end

-- A plain event frame, made at the caller's own CreateFrame site; events is one name or a list.
function ns.EventFrame(events, onEvent, unit1, unit2)
    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", onEvent)
    if type(events) == "string" then
        RegisterOne(frame, events, unit1, unit2)
    else
        ns.RegisterEvents(frame, events, unit1, unit2)
    end
    return frame
end

-- fn(child, a1..a4) per child or region without building a table; returns the count.
-- Forbidden frames (the bank has one) are never asked. Protected forms pcall the whole walk, never the getter:
-- a pcall returning 22 or more values aborts the beta client (Lua's api check, lapi.c 577).
local function Visit(fn, a1, a2, a3, a4, ...)
    local n = select("#", ...)
    for i = 1, n do
        fn((select(i, ...)), a1, a2, a3, a4)
    end
    return n
end

local function VisitChildren(frame, fn, a1, a2, a3, a4) return Visit(fn, a1, a2, a3, a4, frame:GetChildren()) end
local function VisitRegions(frame, fn, a1, a2, a3, a4) return Visit(fn, a1, a2, a3, a4, frame:GetRegions()) end

-- Whether frame has method and may be asked (not forbidden).
local function Askable(frame, method)
    if type(frame) ~= "table" or type(frame[method]) ~= "function" then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    return true
end
ns.Askable = Askable

-- Some frames say they are not forbidden yet refuse addon code (a nameplate's piece, 0.16.0): asked once in a pcall
-- that returns only the count, then walked outside it, so a walker's own error still shows.
local function CountChildren(frame) return select("#", frame:GetChildren()) end
local function CountRegions(frame) return select("#", frame:GetRegions()) end

-- With the dev tools attached (ns.noteWalks): each walk's fn and first arguments, for the release check's secret walk.
local walkFns = setmetatable({}, { __mode = "k" })
ns.walkFns = walkFns
local function NoteWalk(fn, kind, a1, a2, a3, a4)
    if ns.noteWalks and not walkFns[fn] then walkFns[fn] = { kind = kind, a1 = a1, a2 = a2, a3 = a3, a4 = a4 } end
end

function ns.EachChild(frame, fn, a1, a2, a3, a4)
    NoteWalk(fn, "child", a1, a2, a3, a4)
    if not Askable(frame, "GetChildren") or not pcall(CountChildren, frame) then return 0 end
    return Visit(fn, a1, a2, a3, a4, frame:GetChildren())
end

function ns.EachRegion(frame, fn, a1, a2, a3, a4)
    NoteWalk(fn, "region", a1, a2, a3, a4)
    if not Askable(frame, "GetRegions") or not pcall(CountRegions, frame) then return 0 end
    return Visit(fn, a1, a2, a3, a4, frame:GetRegions())
end

function ns.EachChildProtected(frame, fn, a1, a2, a3, a4)
    NoteWalk(fn, "child", a1, a2, a3, a4)
    if not Askable(frame, "GetChildren") then return 0 end
    local ok, n = pcall(VisitChildren, frame, fn, a1, a2, a3, a4)
    return ok and n or 0
end

function ns.EachRegionProtected(frame, fn, a1, a2, a3, a4)
    NoteWalk(fn, "region", a1, a2, a3, a4)
    if not Askable(frame, "GetRegions") then return 0 end
    local ok, n = pcall(VisitRegions, frame, fn, a1, a2, a3, a4)
    return ok and n or 0
end
