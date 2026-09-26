local _, ns = ...

-- Custom theme (bronze or dark; "bronze" in names means the theme on). On: our silver art takes the theme's tint or
-- copies, and the client bronze we hide or drain is left as drawn (bronze) or darkened (dark); off (default) is the old
-- silver. Painted pieces are kept in weak tables so a toggle repaints what is on screen.

local B = ns.bronze
local SetWithFallback, BronzeCopy, THEMES, ThemeName = B.SetWithFallback, ns.BronzeCopy, B.THEMES, ns.ThemeName

-- The theme on, or nil.
local function Theme()
    local name = ThemeName()
    return name and THEMES[name]
end

local weak = { __mode = "k" }
local tinted = setmetatable({}, weak)    -- texture -> share, or true for full
local silvered = setmetatable({}, weak)  -- tinted gold art, drained grey when off
local kept = setmetatable({}, weak)      -- client bronze shown only with the theme
local drained = setmetatable({}, weak)   -- client bronze drained when off -> {r,g,b} or false
local bordered = setmetatable({}, weak)  -- backdrop -> base colour and backdrop pair
local swapped = setmetatable({}, weak)   -- texture -> TEX key, or a file path (it holds a separator)
local swapArgs = setmetatable({}, weak)  -- file-swapped texture -> its extra SetTexture args, when it had any
B.tinted, B.silvered, B.swapped, B.swapArgs = tinted, silvered, swapped, swapArgs

function ns.BronzeOn()
    return ThemeName() ~= nil
end

-- The theme rule in one place. Off: "classic" (1.x art). On: "themed" (1.x shapes in the theme's copies or tints),
-- or "client" for pieces a theme shows in Forever's own art (bronze: tooltips, menus).
function ns.ThemeLook(clientArt)
    local theme = Theme()
    if not theme then return "classic" end
    return (clientArt and theme.client) and "client" or "themed"
end

-- Pull latch in a module's own pass: true once per theme change; state.on is the theme name last painted (false: off),
-- state.was the one before.
function ns.ThemeTurned(state)
    local on = ThemeName() or false
    if state.on == on then return false end
    state.was, state.on = state.on, on
    return true
end

-- Softer share for the slots and the band; full bronze read too strong.
ns.BRONZE_SOFT = 0.9
local function PaintTint(texture)
    if not texture.SetDesaturated then return end
    local theme = Theme()
    if theme then
        local tint, share = theme.tint, tinted[texture]
        share = type(share) == "number" and share or 1
        texture:SetDesaturated(true)
        texture:SetVertexColor(1 + (tint[1] - 1) * share, 1 + (tint[2] - 1) * share, 1 + (tint[3] - 1) * share)
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

-- Out of the repaint, back to as drawn.
function ns.UntintBronze(texture)
    if not texture then return end
    tinted[texture] = nil
    silvered[texture] = nil
    if not texture.SetDesaturated then return end
    texture:SetDesaturated(false)
    texture:SetVertexColor(1, 1, 1)
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

-- The backdrop with its edge file swapped for the theme's copy, made once per frame and theme.
local function ThemedInfo(info, name)
    local themed = info[name]
    if themed then return themed end
    themed = {}
    for k, v in pairs(info.plain) do themed[k] = v end
    themed.edgeFile = BronzeCopy(info.plain.edgeFile)
    info[name] = themed
    return themed
end

-- Border tinted to the theme; a window that greys its own border passes that grey to keep the depth.
-- Edge sheets with a theme copy (dialog border, slider track) swap instead, keeping the fill colour.
function ns.BronzeBackdrop(frame, r, g, b, a)
    if not frame or not frame.SetBackdropBorderColor then return end
    local base = bordered[frame]
    if r or type(base) ~= "table" then
        base = { r or 1, g or r or 1, b or r or 1, a or 1, info = type(base) == "table" and base.info or nil }
    end
    local plain = frame.backdropInfo
    if not base.info and plain and plain.edgeFile and BronzeCopy(plain.edgeFile) then base.info = { plain = plain } end
    bordered[frame] = base
    local name = ThemeName()
    if base.info and frame.SetBackdrop then
        local want = name and ThemedInfo(base.info, name) or base.info.plain
        if frame.backdropInfo ~= want then
            local fr, fg, fb, fa = frame:GetBackdropColor()
            frame:SetBackdrop(want)
            if fr then frame:SetBackdropColor(fr, fg, fb, fa) end
        end
        frame:SetBackdropBorderColor(base[1], base[2], base[3], base[4])
    elseif name then
        local tint = THEMES[name].tint
        frame:SetBackdropBorderColor(tint[1] * base[1], tint[2] * base[2], tint[3] * base[3], base[4])
    else
        frame:SetBackdropBorderColor(base[1], base[2], base[3], base[4])
    end
end

-- Client trim bronze where 1.x was silver (input boxes, macro text, slider arrows, guild detail border): drained to
-- the old metal (tint: its grey) when off, as drawn with a theme showing client art, drained and tinted with another.
local function PaintDrain(region, tint)
    local theme = Theme()
    if theme and theme.client then
        region:SetDesaturated(false)
        if region.SetVertexColor then region:SetVertexColor(1, 1, 1) end
        return
    end
    region:SetDesaturated(true)
    if not region.SetVertexColor then return end
    local r, g, b = 1, 1, 1
    if tint then r, g, b = tint[1], tint[2], tint[3] end
    if theme then
        local t = theme.tint
        r, g, b = r * t[1], g * t[2], b * t[3]
    end
    region:SetVertexColor(r, g, b)
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

-- Drained once; drained again when the client resets its desaturation (an unreadable state counts as right).
function ns.KeepDrained(region, r, g, b)
    if not region or not region.SetDesaturated then return end
    local grey = ns.ThemeLook(true) ~= "client"
    if drained[region] == nil or (region.IsDesaturated and ns.Safe(region:IsDesaturated(), grey) ~= grey) then
        ns.DrainBronze(region, r, g, b)
    end
end

-- Input box trim: the client's bronze edges drained to the old lighter silver.
ns.INPUT_GREY = 0.85
function ns.DrainInput(box, drain)
    ns.EachKey(box, ns.KEYS.LMR, drain or ns.DrainBronze, ns.INPUT_GREY)
end

local function SliceDrain(region, center, grey, drain)
    if region ~= center then drain(region, grey) end
end

local function SliceTint(region, center)
    if region ~= center and region.IsObjectType and region:IsObjectType("Texture") then ns.BronzeTint(region) end
end

-- NineSlice edges; the Center stays as drawn.
function ns.DrainSlice(slice, grey, drain)
    if slice then ns.EachRegion(slice, SliceDrain, slice.Center, grey, drain or ns.DrainBronze) end
end

function ns.TintSlice(slice)
    if slice then ns.EachRegion(slice, SliceTint, slice.Center) end
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
        if what:find("[\\/]") then
            local args = swapArgs[texture]
            local want = ns.BronzeOn() and ns.BronzeCopy(what) or what
            if args then SetWithFallback(texture, want, what, unpack(args)) else SetWithFallback(texture, want, what) end
        else
            SetWithFallback(texture, ns.TexPath(what))
        end
    end
end

-- First module, so the repaint runs before every other apply.
ns.RegisterModule("bronzeTheme", { apply = function() ns.RepaintBronze() end, restore = function() ns.RepaintBronze() end })
