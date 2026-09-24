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

-- One pcall per event so one this client lacks fails alone; unit1/unit2 make unit events.
-- Returns how many registered.
function ns.RegisterEvents(frame, list, unit1, unit2)
    if not frame or type(list) ~= "table" then return 0 end
    local count = 0
    for i = 1, #list do
        local event = list[i]
        local ok
        if unit2 ~= nil then
            ok = pcall(frame.RegisterUnitEvent, frame, event, unit1, unit2)
        elseif unit1 ~= nil then
            ok = pcall(frame.RegisterUnitEvent, frame, event, unit1)
        else
            ok = pcall(frame.RegisterEvent, frame, event)
        end
        if ok then count = count + 1 end
    end
    return count
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

local function Askable(frame, method)
    if type(frame) ~= "table" or type(frame[method]) ~= "function" then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    return true
end

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
