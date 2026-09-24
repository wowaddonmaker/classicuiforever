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
-- Forbidden frames (the bank has one) are never asked. Protected forms pcall; on error, visit none.
local function Visit(fn, a1, a2, a3, a4, ...)
    local n = select("#", ...)
    for i = 1, n do
        fn((select(i, ...)), a1, a2, a3, a4)
    end
    return n
end

local function VisitChecked(fn, a1, a2, a3, a4, ok, ...)
    if not ok then return 0 end
    return Visit(fn, a1, a2, a3, a4, ...)
end

-- Whether frame has method and may be asked (not forbidden).
local function Askable(frame, method)
    if type(frame) ~= "table" or type(frame[method]) ~= "function" then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    return true
end
ns.Askable = Askable

function ns.EachChild(frame, fn, a1, a2, a3, a4)
    if not Askable(frame, "GetChildren") then return 0 end
    return Visit(fn, a1, a2, a3, a4, frame:GetChildren())
end

function ns.EachRegion(frame, fn, a1, a2, a3, a4)
    if not Askable(frame, "GetRegions") then return 0 end
    return Visit(fn, a1, a2, a3, a4, frame:GetRegions())
end

function ns.EachChildProtected(frame, fn, a1, a2, a3, a4)
    if not Askable(frame, "GetChildren") then return 0 end
    return VisitChecked(fn, a1, a2, a3, a4, pcall(frame.GetChildren, frame))
end

function ns.EachRegionProtected(frame, fn, a1, a2, a3, a4)
    if not Askable(frame, "GetRegions") then return 0 end
    return VisitChecked(fn, a1, a2, a3, a4, pcall(frame.GetRegions, frame))
end
