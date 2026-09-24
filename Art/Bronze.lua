local _, ns = ...

-- Forever draws bronze where 1.x drew silver. Theme on: our silver art is tinted bronze and the
-- client bronze we hide or drain is left as drawn; off (default) is the old silver. Painted
-- pieces are kept in weak tables so a toggle repaints what is on screen.

local B = ns.bronze
local SetWithFallback, BronzeCopy = B.SetWithFallback, ns.BronzeCopy

local BRONZE = { 0.9, 0.62, 0.32 }

local weak = { __mode = "k" }
local tinted = setmetatable({}, weak)    -- texture -> share, or true for full
local silvered = setmetatable({}, weak)  -- tinted gold art, drained grey when off
local kept = setmetatable({}, weak)      -- client bronze shown only with the theme
local drained = setmetatable({}, weak)   -- client bronze drained when off -> {r,g,b} or false
local bordered = setmetatable({}, weak)  -- backdrop -> base colour and backdrop pair
local swapped = setmetatable({}, weak)   -- texture -> TEX key or { path, copy, args }
B.tinted, B.silvered, B.swapped = tinted, silvered, swapped

function ns.BronzeOn()
    return ns.db ~= nil and ns.db.bronzeTheme == true
end

-- Softer share for the slots and the band; full bronze read too strong.
ns.BRONZE_SOFT = 0.9
local function PaintTint(texture)
    if not texture.SetDesaturated then return end
    if ns.BronzeOn() then
        local share = tinted[texture]
        share = type(share) == "number" and share or 1
        texture:SetDesaturated(true)
        texture:SetVertexColor(1 + (BRONZE[1] - 1) * share, 1 + (BRONZE[2] - 1) * share, 1 + (BRONZE[3] - 1) * share)
    else
        texture:SetDesaturated(silvered[texture] == true)
        texture:SetVertexColor(1, 1, 1)
    end
end

-- silver: the art is gold, drained grey when the theme is off.
function ns.BronzeTint(texture, share, silver)
    if not texture then return end
    tinted[texture] = share or true
    silvered[texture] = silver and true or nil
    PaintTint(texture)
end

-- Client bronze hidden for the old look, shown only with the theme.
local function PaintKeep(region)
    region:SetAlpha(ns.BronzeOn() and 1 or 0)
end

function ns.BronzeKeep(region)
    if not region or not region.SetAlpha then return end
    kept[region] = true
    PaintKeep(region)
end

-- Forever's thin bronze rim over an icon's grey bevel, theme only.
-- outset puts it just past the quality border so both show.
function ns.BronzeRim(button, icon, outset)
    if not button then return end
    outset = outset or 0
    icon = icon or button.icon or button.Icon
        or (button.GetName and button:GetName() and _G[button:GetName() .. "IconTexture"])
    if not icon then return end
    local rim = button.fcuiBronzeRim
    if not rim then
        rim = button:CreateTexture(nil, "ARTWORK", nil, 7)
        rim:SetTexture(ns.TexPath("iconFrame"))
        button.fcuiBronzeRim = rim
    end
    rim:ClearAllPoints()
    rim:SetPoint("TOPLEFT", icon, "TOPLEFT", -outset, outset)
    rim:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", outset, -outset)
    ns.BronzeTint(rim)
    ns.BronzeKeep(rim)
end

-- Border tinted bronze; a window that greys its own border passes that grey to keep the depth.
-- Edge sheets with a bronze copy (dialog border, slider track) swap instead, keeping the fill colour.
function ns.BronzeBackdrop(frame, r, g, b, a)
    if not frame or not frame.SetBackdropBorderColor then return end
    local base = bordered[frame]
    if r or type(base) ~= "table" then
        base = { r or 1, g or r or 1, b or r or 1, a or 1, info = type(base) == "table" and base.info or nil }
    end
    if not base.info and frame.backdropInfo and frame.backdropInfo.edgeFile then
        local copy = BronzeCopy(frame.backdropInfo.edgeFile)
        if copy then
            local bronzeInfo = {}
            for k, v in pairs(frame.backdropInfo) do bronzeInfo[k] = v end
            bronzeInfo.edgeFile = copy
            base.info = { plain = frame.backdropInfo, bronze = bronzeInfo }
        end
    end
    bordered[frame] = base
    local on = ns.BronzeOn()
    if base.info and frame.SetBackdrop then
        local want = on and base.info.bronze or base.info.plain
        if frame.backdropInfo ~= want then
            local fr, fg, fb, fa = frame:GetBackdropColor()
            frame:SetBackdrop(want)
            if fr then frame:SetBackdropColor(fr, fg, fb, fa) end
        end
        frame:SetBackdropBorderColor(base[1], base[2], base[3], base[4])
    elseif on then
        frame:SetBackdropBorderColor(BRONZE[1] * base[1], BRONZE[2] * base[2], BRONZE[3] * base[3], base[4])
    else
        frame:SetBackdropBorderColor(base[1], base[2], base[3], base[4])
    end
end

-- Client trim bronze where 1.x was silver (input boxes, macro text, slider arrows, guild detail
-- border): drained to the old metal when off, as drawn when on.
local function PaintDrain(region, tint)
    if ns.BronzeOn() then
        region:SetDesaturated(false)
        if region.SetVertexColor then region:SetVertexColor(1, 1, 1) end
        return
    end
    region:SetDesaturated(true)
    if tint and region.SetVertexColor then region:SetVertexColor(tint[1], tint[2], tint[3]) end
end

function ns.DrainBronze(region, r, g, b)
    if not region or not region.SetDesaturated then return end
    local tint = r and { r, g or r, b or r } or false
    drained[region] = tint
    PaintDrain(region, tint)
end

-- Back to as drawn, out of the repaint.
function ns.UndrainBronze(region)
    if not region or not region.SetDesaturated then return end
    drained[region] = nil
    region:SetDesaturated(false)
    if region.SetVertexColor then region:SetVertexColor(1, 1, 1) end
end

-- Repaint every remembered piece for the current theme.
function ns.RepaintBronze()
    for texture in pairs(tinted) do PaintTint(texture) end
    for region in pairs(kept) do PaintKeep(region) end
    for region, tint in pairs(drained) do
        if region.SetDesaturated then PaintDrain(region, tint or nil) end
    end
    for frame in pairs(bordered) do ns.BronzeBackdrop(frame) end
    for texture, what in pairs(swapped) do
        if type(what) == "table" then
            SetWithFallback(texture, ns.BronzeOn() and what.copy or what.path, what.path, unpack(what.args))
        else
            SetWithFallback(texture, ns.TexPath(what))
        end
    end
end

-- First module, so the repaint runs before every other apply.
ns.RegisterModule("bronzeTheme", { apply = function() ns.RepaintBronze() end, restore = function() ns.RepaintBronze() end })
