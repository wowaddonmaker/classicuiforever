local _, ns = ...

-- Custom colour in two layers: a piece shows its copy as drawn (custom/) under a metal layer (custom-metal/, the metal
-- alone in grey, as opaque as it is metal) in the picked colour, so gold, parchment and pictures stay as drawn. A layer
-- follows its piece's shown state, alpha, crop and draw layer each frame while on, so button states carry it too.

local THEMES = ns.bronze.THEMES
local METAL_FROM, METAL_TO = "\\custom\\", "\\custom-metal\\"

local layers = setmetatable({}, { __mode = "k" })   -- piece -> { tex, on, drawLayer, sub }
local job

local function Custom()
    local theme = THEMES[ns.ThemeName() or ""]
    return theme and theme.colorCopies and theme or nil
end

local function Follow(piece, layer)
    local tex = layer.tex
    local shown = piece:IsShown()
    ns.SetShownIf(tex, shown)
    if not shown or not piece:IsVisible() then return end
    local alpha = piece:GetAlpha()
    if not ns.IsSecret(alpha) then ns.SetAlphaIf(tex, alpha) end
    tex:SetTexCoord(piece:GetTexCoord())
    local drawLayer, sub = piece:GetDrawLayer()
    if drawLayer ~= layer.drawLayer or sub ~= layer.sub then
        layer.drawLayer, layer.sub = drawLayer, sub
        tex:SetDrawLayer(drawLayer, math.min(7, (sub or 0) + 1))
    end
end

local function FollowAll()
    local any = false
    for piece, layer in pairs(layers) do
        if layer.on then
            any = true
            Follow(piece, layer)
        end
    end
    if not any then job:Sleep() end
end
job = ns.Sched.Job({ name = "theme.layers", every = 0, awake = false, fn = FollowAll })

local function Tint(layer, theme)
    layer.tex:SetVertexColor(theme.tint[1], theme.tint[2], theme.tint[3])
end

-- copyPath: the custom copy the piece now shows (extra args as its SetTexture had), or nil for none.
function ns.PaintCopy(piece, copyPath, ...)
    if not (piece and piece.GetParent) then return end
    local layer = layers[piece]
    local theme = copyPath and Custom()
    if not theme then
        if layer and layer.on then
            layer.on = false
            layer.tex:Hide()
        end
        return
    end
    if not layer then
        layer = { tex = piece:GetParent():CreateTexture(nil, "ARTWORK") }
        layers[piece] = layer
    end
    local tex = layer.tex
    tex:SetTexture((copyPath:gsub(METAL_FROM, METAL_TO)), ...)
    tex:SetAllPoints(piece)
    tex:SetBlendMode(piece:GetBlendMode())
    if piece.GetHorizTile then
        tex:SetHorizTile(piece:GetHorizTile())
        tex:SetVertTile(piece:GetVertTile())
    end
    layer.drawLayer, layer.on = nil, true
    Tint(layer, theme)
    Follow(piece, layer)
    job:Wake()
end

-- The picked custom colour: saved, then every layer and tinted piece repainted.
function ns.SetThemeColor(r, g, b)
    ns.db.themeColor = string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5))
    ns.ThemeName()
    local theme = Custom()
    if theme then
        for _, layer in pairs(layers) do
            if layer.on then Tint(layer, theme) end
        end
    end
    ns.RepaintBronze()
    if ns.QueueApply then ns.QueueApply() end
end
