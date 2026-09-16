local _, ns = ...

-- Shared helpers for the reskin modules. Every Blizzard frame stays alive
-- and keeps its logic; we only change textures, anchors and alpha, and we
-- hook the update methods that would undo that.

-- Alpha 0 instead of Hide: Blizzard's own code calls Show() on its regions
-- all the time and alpha survives that.
function ns.Fade(region)
    if region and region.SetAlpha then region:SetAlpha(0) end
end

function ns.Unfade(region)
    if region and region.SetAlpha then region:SetAlpha(1) end
end

local hooked = setmetatable({}, { __mode = "k" })

-- Hook a method on a frame once. Missing methods are skipped and reported
-- through the debug flush instead of erroring the module out.
function ns.HookMethod(frame, method, fn)
    if not frame then return false end
    if type(frame[method]) ~= "function" then
        ns.MissingPiece((frame.GetName and frame:GetName() or "?") .. ":" .. method)
        return false
    end
    hooked[frame] = hooked[frame] or {}
    if hooked[frame][method] then return true end
    hooked[frame][method] = true
    hooksecurefunc(frame, method, fn)
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
    hooksecurefunc(name, fn)
    return true
end

function ns.HookScriptOnce(frame, script, fn)
    if not frame or not frame.HookScript then return end
    hooked[frame] = hooked[frame] or {}
    if hooked[frame]["script:" .. script] then return end
    hooked[frame]["script:" .. script] = true
    frame:HookScript(script, fn)
end

-- Pieces the running client does not have are listed for /fcui debug.
ns.missing = {}
function ns.MissingPiece(name)
    if not ns.missing[name] then
        ns.missing[name] = true
        ns.missingCount = (ns.missingCount or 0) + 1
    end
end

-- Walk a dotted path of keys from a frame, nil if any step is missing.
function ns.Path(frame, ...)
    local node = frame
    for i = 1, select("#", ...) do
        if type(node) ~= "table" then return nil end
        node = node[(select(i, ...))]
    end
    return node
end

function ns.SetPointOnce(region, ...)
    if not region then return end
    region:ClearAllPoints()
    region:SetPoint(...)
end

-- A texture created once on a frame, keyed so re-applies reuse it.
function ns.OwnTexture(frame, key, layer, sublevel)
    frame.fcui = frame.fcui or {}
    local tex = frame.fcui[key]
    if not tex then
        tex = frame:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
        frame.fcui[key] = tex
    end
    return tex
end

function ns.OwnFontString(frame, key, layer, font)
    frame.fcui = frame.fcui or {}
    local fs = frame.fcui[key]
    if not fs then
        fs = frame:CreateFontString(nil, layer or "OVERLAY", font or "GameFontHighlightSmall")
        frame.fcui[key] = fs
    end
    return fs
end

-- 1.x power colours. Blizzard's PowerBarColor still exists on both
-- clients and is used for anything not listed here.
ns.POWER_COLORS = {
    MANA = { 0, 0, 1 }, RAGE = { 1, 0, 0 }, FOCUS = { 1, 0.5, 0.25 }, ENERGY = { 1, 1, 0 },
    RUNIC_POWER = { 0, 0.82, 1 }, LUNAR_POWER = { 0.3, 0.52, 0.9 }, MAELSTROM = { 0, 0.5, 1 },
    INSANITY = { 0.4, 0, 0.8 }, FURY = { 0.788, 0.259, 0.992 }, PAIN = { 1, 0.61, 0 },
    AMMOSLOT = { 0.8, 0.6, 0 }, FUEL = { 0, 0.55, 0.5 },
}

function ns.PowerColor(unit)
    local powerType, token, altR, altG, altB = UnitPowerType(unit)
    local c = token and ns.POWER_COLORS[token]
    if c then return c[1], c[2], c[3] end
    if altR then return altR, altG, altB end
    local info = PowerBarColor and (PowerBarColor[token] or PowerBarColor[powerType])
    if info then return info.r, info.g, info.b end
    return 0, 0, 1
end

-- Secret values (12.x combat data) never reach a StatusBar.
function ns.SafeNumber(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- A StatusBar we own with the 1.x fill, under no mouse.
function ns.CreateBar(parent, key, width, height)
    parent.fcui = parent.fcui or {}
    local bar = parent.fcui[key]
    if not bar then
        bar = CreateFrame("StatusBar", nil, parent)
        bar:EnableMouse(false)
        parent.fcui[key] = bar
    end
    bar:SetSize(width, height)
    bar:SetStatusBarTexture((ns.TexPath("statusBar")))
    bar:GetStatusBarTexture():SetTexCoord(0, 1, 0, 1)
    return bar
end

function ns.SetHealth(bar, unit)
    local hp, max = ns.SafeNumber(UnitHealth(unit)), ns.SafeNumber(UnitHealthMax(unit))
    if not hp or not max then return end
    bar:SetMinMaxValues(0, max > 0 and max or 1)
    bar:SetValue(hp)
end

function ns.SetPower(bar, unit)
    local p, max = ns.SafeNumber(UnitPower(unit)), ns.SafeNumber(UnitPowerMax(unit))
    if not p or not max then return end
    bar:SetMinMaxValues(0, max > 0 and max or 1)
    bar:SetValue(p)
    bar:SetStatusBarColor(ns.PowerColor(unit))
end
