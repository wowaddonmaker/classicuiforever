local _, ns = ...

-- Hook installers, once per frame and method, global or script; the hooks live in their modules.

local IsSecret = ns.IsSecret

local hooked = setmetatable({}, { __mode = "k" })

-- Per-frame install marks: method names and "script:" keys.
local function Marks(frame)
    local marks = hooked[frame]
    if not marks then
        marks = {}
        hooked[frame] = marks
    end
    return marks
end

-- Trampolines let the dev addon swap entry.fn for a timed wrapper; ns.hookFns keeps install order.
-- HookScriptOnce hooks directly.
ns.hookFns = ns.hookFns or {}

local function Trampoline(label, fn)
    local entry = { label = label, fn = fn }
    local list = ns.hookFns
    list[#list + 1] = entry
    return function(...) return entry.fn(...) end
end

-- A missing method is listed for /fcui debug, not an error.
function ns.HookMethod(frame, method, fn)
    if not frame then return false end
    if type(frame[method]) ~= "function" then
        ns.MissingPiece((frame.GetName and frame:GetName() or "?") .. ":" .. method)
        return false
    end
    local marks = Marks(frame)
    if marks[method] then return true end
    marks[method] = true
    -- Dev addon label only; nameless frames with a parentKey use their debug name, the rest "?".
    local name = frame.GetName and frame:GetName()
    if IsSecret(name) then name = nil end
    if not name and frame.GetParentKey and frame.GetDebugName then
        local key = frame:GetParentKey()
        if key and key ~= "" then name = frame:GetDebugName() end
    end
    if IsSecret(name) then name = nil end
    hooksecurefunc(frame, method, Trampoline((name or "?") .. ":" .. method, fn))
    return true
end

local hookedGlobals = {}
function ns.HookGlobal(name, fn)
    if type(_G[name]) ~= "function" then
        ns.MissingPiece(name)
        return false
    end
    if hookedGlobals[name] then return true end
    hookedGlobals[name] = true
    hooksecurefunc(name, Trampoline(name, fn))
    return true
end

function ns.HookScriptOnce(frame, script, fn)
    if not frame or not frame.HookScript then return end
    local marks, key = Marks(frame), "script:" .. script
    if marks[key] then return end
    marks[key] = true
    frame:HookScript(script, fn)
end

-- Client pieces missing on this build, for /fcui debug.
ns.missing = {}
function ns.MissingPiece(name)
    ns.missing[name] = true
end
