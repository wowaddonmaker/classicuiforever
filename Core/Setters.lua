local _, ns = ...

-- Compare before set: no-op writes cost a call and protected frames refuse them in combat; true when it wrote.
-- Live reads; secret or unreadable values write; numbers within 1e-6 relative, absolute below 1 (32-bit floats).
-- No combat guard; never on client nameplate pieces; cached values only on our regions; SetPointOnce is unconditional.

local IsSecret, AnySecret = ns.IsSecret, ns.AnySecret
local abs = math.abs

local function DefaultTol(want)
    local size = abs(want)
    if size < 1 then size = 1 end
    return size * 1e-6
end

local function Num(v)
    if IsSecret(v) or type(v) ~= "number" then return nil end
    return v
end

-- An unreadable wanted value never matches.
local function Same(current, want, tol)
    if IsSecret(want) or type(want) ~= "number" then return false end
    current = Num(current)
    if current == nil then return false end
    if type(tol) ~= "number" then tol = DefaultTol(want) end
    return abs(current - want) <= tol
end

-- Tolerance compare for callers that check types first.
ns.Near = Same

-- Whether this is the region's only point; nil when unknown (not one point, secret, failed read).
-- rel compares by identity; a name is resolved first.
function ns.IsAt(region, point, rel, relPoint, x, y, tol)
    if AnySecret(point, rel, relPoint, x, y, tol) then return nil end
    if type(region) ~= "table" or not region.GetNumPoints or not region.GetPoint then return nil end
    if type(x) ~= "number" or type(y) ~= "number" then return nil end
    local okCount, count = pcall(region.GetNumPoints, region)
    if not okCount or IsSecret(count) or count ~= 1 then return nil end
    local ok, p, r, rp, px, py = pcall(region.GetPoint, region, 1)
    if not ok or AnySecret(p, r, rp, px, py) then return nil end
    if type(px) ~= "number" or type(py) ~= "number" then return nil end
    if type(rel) == "string" then rel = _G[rel] end
    return p == point and r == rel and rp == relPoint and Same(px, x, tol) and Same(py, y, tol)
end

-- An edit mode system's base widget calls: its wrappers write a snap note the client reads back in our name (tainted drags).
function ns.BaseSetters(frame)
    return frame.SetScaleBase or frame.SetScale, frame.ClearAllPointsBase or frame.ClearAllPoints, frame.SetPointBase or frame.SetPoint
end
local BaseSetters = ns.BaseSetters

-- Five-value form only; skipped when already there.
function ns.SetPointIf(region, point, rel, relPoint, x, y)
    if not AnySecret(point, rel, relPoint, x, y) then
        if point == nil or relPoint == nil or type(x) ~= "number" or type(y) ~= "number" then
            error("ns.SetPointIf takes point, relativeTo, relativePoint, x and y", 2)
        end
        if ns.IsAt(region, point, rel, relPoint, x, y) == true then return false end
    end
    local _, clearPoints, setPoint = BaseSetters(region)
    clearPoints(region)
    setPoint(region, point, rel, relPoint, x, y)
    return true
end

function ns.SetAlphaIf(region, alpha, tol)
    if Same(region:GetAlpha(), alpha, tol) then return false end
    region:SetAlpha(alpha)
    return true
end

-- Compares IsShown (the frame's own flag), not visibility.
function ns.SetShownIf(region, shown)
    if IsSecret(shown) then
        region:SetShown(shown)
        return true
    end
    shown = shown and true or false
    local current = region:IsShown()
    if not IsSecret(current) and current == shown then return false end
    region:SetShown(shown)
    return true
end

-- exact: a custom tolerance; true means the default.
function ns.SetScaleIf(region, scale, exact)
    local old = region:GetScale()
    if Same(old, scale, exact ~= true and exact or nil) then return false end
    local setScale, _, setPoint = BaseSetters(region)
    setScale(region, scale)
    -- A system keeps its place, as the client's wrapper does it.
    old = Num(old)
    if region.SetScaleBase and old and old > 0 and not IsSecret(scale) then
        for i = 1, region:GetNumPoints() do
            local point, rel, relPoint, x, y = region:GetPoint(i)
            if Num(x) and Num(y) then setPoint(region, point, rel, relPoint, x * old / scale, y * old / scale) end
        end
    end
    return true
end

function ns.SetLevelIf(frame, level)
    if Same(frame:GetFrameLevel(), level) then return false end
    frame:SetFrameLevel(level)
    return true
end

-- A missing alpha matches only 1, right whether the client reads nil alpha as 1 or as keep.
local function SameColor(cr, cg, cb, ca, r, g, b, a, tol)
    if AnySecret(r, g, b, a) then return false end
    return Same(cr, r, tol) and Same(cg, g, tol) and Same(cb, b, tol) and Same(ca, a or 1, tol)
end

function ns.SetVertexColorIf(texture, r, g, b, a, tol)
    local cr, cg, cb, ca = texture:GetVertexColor()
    if SameColor(cr, cg, cb, ca, r, g, b, a, tol) then return false end
    if not IsSecret(a) and a == nil then texture:SetVertexColor(r, g, b) else texture:SetVertexColor(r, g, b, a) end
    return true
end

function ns.SetBarColorIf(bar, r, g, b, a, tol)
    local cr, cg, cb, ca = bar:GetStatusBarColor()
    if SameColor(cr, cg, cb, ca, r, g, b, a, tol) then return false end
    if not IsSecret(a) and a == nil then bar:SetStatusBarColor(r, g, b) else bar:SetStatusBarColor(r, g, b, a) end
    return true
end

-- Skips same-value writes only; no combat guard.
function ns.SetAttributeIf(frame, name, value)
    if IsSecret(value) then
        frame:SetAttribute(name, value)
        return true
    end
    local ok, current = pcall(frame.GetAttribute, frame, name)
    if ok and not IsSecret(current) and current == value then return false end
    frame:SetAttribute(name, value)
    return true
end

----------------------------------------------------------- plain setters

-- Alpha 0, not Hide: the client re-Shows its own regions and alpha survives that.
function ns.Fade(region)
    if region and region.SetAlpha then region:SetAlpha(0) end
end

function ns.Unfade(region)
    if region and region.SetAlpha then region:SetAlpha(1) end
end

local EachRegion = ns.EachRegion

local function FadeTexture(region)
    if region:IsObjectType("Texture") then region:SetAlpha(0) end
end

-- Texture regions only.
function ns.FadeRegions(frame)
    EachRegion(frame, FadeTexture)
end

-- 12.x level and PvP circles: any "SmallCircle" atlas texture under any key.
-- ns.FadeAtlas (UI/Dress.lua) loads later, so it is looked up per call.
function ns.FadeCircles(frame)
    ns.FadeAtlas(frame, "smallcircle")
end

-- frame[k1][k2]...; nil if a step is missing.
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
    local _, clearPoints, setPoint = BaseSetters(region)
    clearPoints(region)
    setPoint(region, ...)
end

-- Created once per frame and key, kept in frame.fcui for re-applies.
local function Own(frame, key, create, a, b)
    frame.fcui = frame.fcui or {}
    local region = frame.fcui[key]
    if not region then
        region = create(frame, a, b)
        frame.fcui[key] = region
    end
    return region
end

-- Whether region is one of ours kept in frame.fcui.
function ns.IsOwnRegion(frame, region)
    local own = frame.fcui
    if type(own) ~= "table" then return false end
    for _, value in pairs(own) do
        if value == region then return true end
    end
    return false
end

-- True the first time per frame and key; kept in a weak table, never as a field on the frame.
local onceSeen = setmetatable({}, { __mode = "k" })
function ns.Once(frame, key)
    local keys = onceSeen[frame]
    if not keys then
        keys = {}
        onceSeen[frame] = keys
    end
    if keys[key] then return false end
    keys[key] = true
    return true
end

local function NewTexture(frame, layer, sublevel)
    return frame:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
end

local function NewFontString(frame, layer, font)
    return frame:CreateFontString(nil, layer or "OVERLAY", font or "GameFontHighlightSmall")
end

function ns.OwnTexture(frame, key, layer, sublevel)
    return Own(frame, key, NewTexture, layer, sublevel)
end

function ns.OwnFontString(frame, key, layer, font)
    return Own(frame, key, NewFontString, layer, font)
end
