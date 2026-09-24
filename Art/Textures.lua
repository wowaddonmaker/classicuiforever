local _, ns = ...

-- Art setters by TEX key or file, with client/bundled fallback and bronze bookkeeping.

local B = ns.bronze
local BronzeCopy = ns.BronzeCopy

-- Last SetTexture result per key, for /fcui debug.
ns.texStatus = {}

function ns.TexPath(key)
    local entry = ns.TEX[key]
    if entry.bronze and ns.BronzeOn() then
        return entry.bronze, entry.bundled
    end
    -- The client redrew some files under the old names: ours first.
    if entry.preferBundled or (ns.db and ns.db.textureSource == "bundled") then
        return entry.bundled, entry.builtin
    end
    return entry.builtin, entry.bundled
end

-- SetTexture returns false for a missing file; then try the fallback.
local function SetWithFallback(texture, primary, fallback, ...)
    local ok = texture:SetTexture(primary, ...)
    if ok == false and fallback then ok = texture:SetTexture(fallback, ...) end
    return ok
end
B.SetWithFallback = SetWithFallback

-- Metal with the softer share: the action slot ring.
local SOFT_KEYS = { slotNormal = true }

-- Falls back to the other copy so a missing file never leaves a blank region; extra args go to SetTexture.
function ns.SetTex(texture, key, ...)
    local primary, fallback = ns.TexPath(key)
    local ok = texture:SetTexture(primary, ...)
    if ok == false then
        ok = texture:SetTexture(fallback, ...)
        ns.texStatus[key] = ok and "fallback" or "missing"
    else
        ns.texStatus[key] = "ok"
    end
    -- Sheets with a bronze copy swap with the theme.
    local swapped = B.swapped
    if ns.TEX[key] and ns.TEX[key].bronze then
        swapped[texture] = key
    elseif swapped[texture] then
        swapped[texture] = nil
    end
    if B.METAL[key] then
        ns.BronzeTint(texture, SOFT_KEYS[key] and ns.BRONZE_SOFT or nil)
    elseif B.tinted[texture] then
        -- Texture reused for non-metal art: clear the tint.
        ns.UntintBronze(texture)
    end
    return ok ~= false
end

-- By file; swaps to its bronze copy with the theme.
function ns.SetFile(texture, path, ...)
    if not texture or not path then return end
    local copy = BronzeCopy(path)
    B.swapped[texture] = copy and { path = path, copy = copy, args = { ... } } or nil
    local ok = SetWithFallback(texture, (copy and ns.ThemeLook() == "bronze") and copy or path, copy and path, ...)
    return ok ~= false
end

-- Out of the theme's file swap, before the texture takes other art again.
function ns.UnswapBronze(texture)
    if texture then B.swapped[texture] = nil end
end

-- Same, for a button state texture.
function ns.SetButtonFile(button, which, path, ...)
    local setter = button and button["Set" .. which .. "Texture"]
    local getter = button and button["Get" .. which .. "Texture"]
    if not setter or not getter then return end
    setter(button, path, ...)
    local tex = getter(button)
    if tex then ns.SetFile(tex, path) end
    return tex
end

function ns.SetButtonTex(button, which, key)
    local setter = button["Set" .. which .. "Texture"]
    local getter = button["Get" .. which .. "Texture"]
    if not setter or not getter then return end
    local tex = getter(button)
    if not tex then
        setter(button, (ns.TexPath(key)))
        tex = getter(button)
    end
    if not tex then return end
    ns.SetTex(tex, key)
    return tex
end
