local _, ns = ...

-- Sheet core: take/give-back of client regions, the old window art, the docking API.

local T = ns.sheet
local EMPTY = ns.EMPTY

T.WIDTH, T.HEIGHT = 384, 512
-- Drawn border edges (transparent past the right one); docked copies sit against them.
T.ART_RIGHT_EDGE, T.ART_LEFT_EDGE = 349, 3

---------------------------------------------------------------- give back

-- First-found state of every client region we change, so turning off needs no relog.
-- The pane's collapsed flag is read, never written.
local taken = {}
local READ = {
    alpha = function(r) return r:GetAlpha() end,
    mouse = function(r) return r:IsMouseEnabled() and true or false end,
    points = function(r)
        local points = {}
        for i = 1, r:GetNumPoints() do
            local point, rel, relPoint, x, y = r:GetPoint(i)
            points[i] = { point = point, rel = rel, relPoint = relPoint, x = x, y = y }
        end
        return points
    end,
    size = function(r) return { r:GetWidth(), r:GetHeight() } end,
    width = function(r) return r:GetWidth() end,
    scale = function(r) return r:GetScale() end,
    parent = function(r) return r:GetParent() end,
    level = function(r) return r:GetFrameLevel() end,
    layer = function(r) return { r:GetDrawLayer() } end,
    font = function(r) return r:GetFontObject() end,
    justify = function(r) return r:GetJustifyH() end,
    hit = function(r) return { r:GetHitRectInsets() } end,
    clips = function(r) return r:DoesClipChildren() and true or false end,
    shown = function(r) return r:IsShown() and true or false end,
    masks = function(r)
        local masks = {}
        for i = 1, r:GetNumMaskTextures() do masks[i] = r:GetMaskTexture(i) end
        return masks
    end,
    art = function(r)
        return { atlas = r:GetAtlas(), file = r:GetTexture(), coords = { r:GetTexCoord() },
            color = { r:GetVertexColor() }, blend = r:GetBlendMode() }
    end,
}
local function Take(region, ...)
    if not region then return end
    local kept = taken[region]
    if not kept then
        kept = {}
        taken[region] = kept
    end
    for i = 1, select("#", ...) do
        local aspect = select(i, ...)
        if kept[aspect] == nil then
            local ok, value = pcall(READ[aspect], region)
            if ok and value ~= nil then kept[aspect] = value end
        end
    end
end
T.Take = Take
function T.TakeAlpha(region) Take(region, "alpha") end

-- The gamepad's focus glow round the old art, not the frame's whole 384 x 512 (the art starts in from its top left,
-- stops short of its right and sits its tabs in the bottom 76). Re-placed while shown: the client may lay it again.
local GLOW_LEFT, GLOW_TOP, GLOW_BOTTOM = 11, -13, 76
function T.PlaceGlow(frame, extra)
    local glow = frame.FrameGlow
    if not glow then return end
    Take(glow, "points")
    ns.SetTwoPointsIf(glow, "TOPLEFT", frame, "TOPLEFT", GLOW_LEFT, GLOW_TOP,
        "BOTTOMRIGHT", frame, "BOTTOMLEFT", T.ART_RIGHT_EDGE + extra, GLOW_BOTTOM)
end

-- Records which faces existed: the old close art adds faces the client button may lack.
local FACES = ns.KEYS.STATES
function T.TakeFaces(button)
    if not button then return end
    Take(button, "size", "points")
    local kept = taken[button]
    if kept.faces then return end
    kept.faces = {}
    for _, face in ipairs(FACES) do
        local tex = ns.StateTexture(button, face)
        kept.faces[face] = tex or false
        if tex then Take(tex, "art", "points") end
    end
end

local function PutBack(region, kept)
    if kept.parent then region:SetParent(kept.parent) end
    if kept.scale then region:SetScale(kept.scale) end
    if kept.size then region:SetSize(kept.size[1], kept.size[2]) end
    if kept.width then region:SetWidth(kept.width) end
    if kept.points then
        -- Own pcall: a refused point must not skip the rest.
        pcall(function()
            region:ClearAllPoints()
            for _, p in ipairs(kept.points) do region:SetPoint(p.point, p.rel, p.relPoint, p.x, p.y) end
        end)
    end
    if kept.level then region:SetFrameLevel(kept.level) end
    if kept.layer then region:SetDrawLayer(kept.layer[1], kept.layer[2]) end
    if kept.font then region:SetFontObject(kept.font) end
    if kept.justify then region:SetJustifyH(kept.justify) end
    if kept.art then
        local art = kept.art
        if art.atlas then
            region:SetAtlas(art.atlas)
        elseif art.file then
            region:SetTexture(art.file)
            region:SetTexCoord(unpack(art.coords))
        end
        region:SetVertexColor(unpack(art.color))
        if art.blend then region:SetBlendMode(art.blend) end
    end
    if kept.masks then
        for i = region:GetNumMaskTextures(), 1, -1 do region:RemoveMaskTexture(region:GetMaskTexture(i)) end
        for _, mask in ipairs(kept.masks) do region:AddMaskTexture(mask) end
    end
    if kept.faces then
        for face, had in pairs(kept.faces) do
            local clear = region["Clear" .. face .. "Texture"]
            if not had and ns.StateTexture(region, face) and clear then clear(region) end
        end
    end
    if kept.alpha then region:SetAlpha(kept.alpha) end
    if kept.mouse ~= nil then region:EnableMouse(kept.mouse) end
    if kept.hit then region:SetHitRectInsets(unpack(kept.hit)) end
    if kept.clips ~= nil then region:SetClipsChildren(kept.clips) end
end

-- Shown state goes back last. A piece that lays out on show (skill hit table) waits
-- until its parent is hidden, else that layout pass runs tainted.
local showLater = {}
local showWatch
local function ShowBack(region, shown)
    if shown and not region:IsShown() then
        local parent = region:GetParent()
        if parent and parent:IsVisible() then
            showLater[region] = true
            if not showWatch then
                showWatch = CreateFrame("Frame")
                ns.Sched.OnFrame(showWatch, { name = "sheet.showBack", every = 0, fn = function()
                    for piece in pairs(showLater) do
                        local over = piece:GetParent()
                        if not (over and over:IsVisible()) then
                            showLater[piece] = nil
                            pcall(piece.Show, piece)
                        end
                    end
                    if not next(showLater) then showWatch:Hide() end
                end })
            end
            showWatch:Show()
            return
        end
    end
    region:SetShown(shown)
end

-- Pending shows count as client-shown, so the next give-back shows them too.
function T.KeepShownLater()
    for region in pairs(showLater) do
        taken[region] = taken[region] or {}
        taken[region].shown = true
    end
    wipe(showLater)
end

-- Our pieces on client frames (plates, arrows, rims); hidden with the sheet.
local own = setmetatable({}, { __mode = "k" })
local function Own(region)
    if region then own[region] = true end
    return region
end
T.Own = Own

-- Fade, recording alpha for give-back.
function T.Fade(region)
    Take(region, "alpha")
    ns.Fade(region)
end

-- Close faces leave the bronze list before their own art goes back; shown state last.
function T.PutAllBack(close)
    for piece in pairs(own) do piece:Hide() end
    local faces = close and taken[close] and taken[close].faces
    for _, tex in pairs(faces or EMPTY) do
        if tex then pcall(ns.SetTex, tex, "closeHighlight") end
    end
    for region, kept in pairs(taken) do pcall(PutBack, region, kept) end
    for region, kept in pairs(taken) do
        if kept.shown ~= nil then pcall(ShowBack, region, kept.shown) end
    end
    wipe(taken)
end

------------------------------------------------------------------ the art

-- General frame under everything; the paper doll sheet on the character tab only.
local GENERAL = {
    { key = "charGeneralTopLeft", layer = "BACKGROUND", sublevel = -2, w = 256, h = 256, point = "TOPLEFT", x = 0, y = 0 },
    { key = "charGeneralTopRight", layer = "BACKGROUND", sublevel = -2, w = 128, h = 256, point = "TOPLEFT", x = 256, y = 0 },
    { key = "charGeneralBotLeft", layer = "BACKGROUND", sublevel = -2, w = 256, h = 256, point = "TOPLEFT", x = 0, y = -256 },
    { key = "charGeneralBotRight", layer = "BACKGROUND", sublevel = -2, w = 128, h = 256, point = "TOPLEFT", x = 256, y = -256 },
}
local DOLL = {
    { key = "charTabTopLeft", layer = "BACKGROUND", sublevel = -1, w = 256, h = 256, point = "TOPLEFT", x = 0, y = 0 },
    { key = "charTabTopRight", layer = "BACKGROUND", sublevel = -1, w = 128, h = 256, point = "TOPLEFT", x = 256, y = 0 },
    { key = "charTabBotLeft", layer = "BACKGROUND", sublevel = -1, w = 256, h = 256, point = "TOPLEFT", x = 0, y = -256 },
    { key = "charTabBotRight", layer = "BACKGROUND", sublevel = -1, w = 128, h = 256, point = "TOPLEFT", x = 256, y = -256 },
}
local ALL_EIGHT = {}
for i = 1, 4 do ALL_EIGHT[i], ALL_EIGHT[i + 4] = GENERAL[i], DOLL[i] end
-- Retail has no ranged slot: Era's three weapon wells (sheet x 114-248, y 120-170) are laid as two, centered where the
-- three were (the first 92 px moved WELLS_SHIFT right, the plain frame line either side); the slots move with them.
local WELLS_SHIFT = 21
T.WEAPON_SLOTS_X = 122 + (ns.OnForever() and 0 or WELLS_SHIFT)
local function BotLeftPiece(x, y, w, h, sx, sy)
    return { key = "charTabBotLeft", layer = "BACKGROUND", sublevel = -1, w = w, h = h, point = "TOPLEFT", x = x,
        y = -256 - y, coords = { sx / 256, (sx + w) / 256, sy / 256, (sy + h) / 256 } }
end
local RETAIL_DOLL = { DOLL[1], DOLL[2], DOLL[4],
    BotLeftPiece(0, 0, 114, 256, 0, 0), BotLeftPiece(249, 0, 7, 256, 249, 0), BotLeftPiece(114, 0, 135, 120, 114, 0),
    BotLeftPiece(114, 171, 135, 85, 114, 171), BotLeftPiece(114, 120, WELLS_SHIFT, 51, 70, 120),
    BotLeftPiece(114 + WELLS_SHIFT, 120, 92, 51, 114, 120), BotLeftPiece(227, 120, 22, 51, 70, 120) }

-- The portrait frame covers the ring's inner edge: redraw that corner above it from
-- the sheet that is up (the doll's has the head socket), down to the ring's foot.
local RING_W, RING_H = 80, 73
local RING = { layer = "ARTWORK", fill = true, coords = { 0, RING_W / 256, 0, RING_H / 256 } }
local function RingPiece(parent, frame, key, lift)
    local holder = frame.PortraitContainer
    local over = ns.NewFrame("Frame", nil, parent)
    over:SetSize(RING_W, RING_H)
    -- On its sheet's page (the doll page stands off the window, CharacterSheet.lua DOLL_X).
    over:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    over:SetFrameLevel((holder and holder:GetFrameLevel() or frame:GetFrameLevel()) + lift)
    ns.DressNew(over, key, RING)
    return over
end
-- The doll page stands 2 left and 1 up of the window: while its ring shows, the window's own is put away, or it shows
-- along the doll ring's right and bottom edges as a seam.
local function RingOver(frame, doll, only)
    local over = RingPiece(frame, frame, only or "charGeneralTopLeft", 1)
    if doll and not only then
        local ring = RingPiece(doll, frame, "charTabTopLeft", 2)
        over.doll = ring
        ring:SetScript("OnShow", function() over:SetAlpha(0) end)
        ring:SetScript("OnHide", function() over:SetAlpha(1) end)
        over:SetAlpha(ring:IsVisible() and 0 or 1)
    end
    return over
end

-- Era's portrait: the player's face on every tab. Forever shows the spec icon on the doll page (the pet view's too), and
-- the swap jumped as it was fitted: ours lies over the game's, which is faded while the ring overlay shows.
local FACE_SIZE, FACE_X, FACE_Y = 62, 9, -6
local FACE_EVENTS = { "PORTRAITS_UPDATED", "PLAYER_ENTERING_WORLD" }
local function Face(frame, over)
    local holder = frame.PortraitContainer
    local face = ns.NewFrame("Frame", nil, frame)
    face:SetAllPoints(frame)
    face:SetFrameLevel(holder and holder:GetFrameLevel() or frame:GetFrameLevel())
    local tex = face:CreateTexture(nil, "ARTWORK")
    tex:SetSize(FACE_SIZE, FACE_SIZE)
    tex:SetPoint("TOPLEFT", frame, "TOPLEFT", FACE_X, FACE_Y)
    local function Refresh() if face:IsVisible() then SetPortraitTexture(tex, "player") end end
    local events = ns.EventFrame(FACE_EVENTS, Refresh)
    ns.RegisterEvents(events, { "UNIT_PORTRAIT_UPDATE" }, "player")
    local function Shown(on)
        face:SetShown(on)
        local game = holder and holder.portrait
        if game then ns.SetAlphaIf(game, on and 0 or 1) end
        Refresh()
    end
    over:HookScript("OnShow", function() Shown(true) end)
    over:HookScript("OnHide", function() Shown(false) end)
    Shown(over:IsShown())
    return face
end

function T.BuildArt(frame, doll)
    T.general = ns.DressPieces(frame, GENERAL, nil, true)
    T.doll = ns.DressPieces(doll, ns.OnForever() and DOLL or RETAIL_DOLL, nil, true)
    T.ringOver = RingOver(frame, doll)
    T.face = Face(frame, T.ringOver)
end

----------------------------------------------------------- docking API

-- Another addon's character window copy wears the same art: painted once, then toggled.
local dressed = setmetatable({}, { __mode = "k" })

-- Width, height, art right edge (past the side panel while open), art left edge.
function ForeverClassicUI_CharacterSheetSize()
    local extra = ns.EquipmentPaneExtent and ns.EquipmentPaneExtent() or 0
    return T.WIDTH, T.HEIGHT, T.ART_RIGHT_EDGE + extra, T.ART_LEFT_EDGE
end

-- True when the sheet is on and the art was drawn.
function ForeverClassicUI_SkinCharacterCopy(frame)
    if not frame then return false end
    if not dressed[frame] then
        dressed[frame] = ns.DressPieces(frame, ALL_EIGHT, nil, {})
        dressed[frame].ringOver = RingOver(frame, nil, "charTabTopLeft")
    end
    local active = T.active and true or false
    for _, tex in ipairs(dressed[frame]) do tex:SetShown(active) end
    dressed[frame].ringOver:SetShown(active)
    return active
end
