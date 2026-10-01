local _, ns = ...
local B = ns.band

-- Band art: the stone runs, the gryphons and the thin top bar.

local ART_W, BAND_H, CAP_SIZE = B.ART_W, B.BAND_H, B.CAP_SIZE
local PAGE_ROOM, PAGE_POST, PAGE_BOX_Y, PAGE_BOX_H = B.PAGE_ROOM, B.PAGE_POST, B.PAGE_BOX_Y, B.PAGE_BOX_H
local PIECES, CAP_KEYS, BAND_RUN = B.PIECES, B.CAP_KEYS, B.BAND_RUN
local ART_H = 53
local Segments, ArtWidth = B.Segments, B.ArtWidth
local Dress, InDefaultPosition = ns.Dress, ns.InDefaultPosition

local FULL = { 0, 1, 0, 1 }
local CAP_LEFT, CAP_RIGHT = { coords = FULL }, { coords = { 1, 0, 0, 1 } }
local RUN = {}   -- a run's coords, refilled per piece
local ARTLESS = {}   -- segment owner -> its art hidden, refilled per paint
local RIM_H = 2      -- the band's top rows: the lower border of the strip over it
local CAP_TEX = { LeftEndCap = "leftCap", RightEndCap = "rightCap" }
local GRYPHON_NAMES = { LeftEndCap = "ForeverClassicUIGryphonLeft", RightEndCap = "ForeverClassicUIGryphonRight" }
local GRYPHON_KEYS = { LeftEndCap = "gryphonLeft", RightEndCap = "gryphonRight" }
local GRYPHON_SHOW = { LeftEndCap = "showGryphonLeft", RightEndCap = "showGryphonRight" }
local GRYPHON_HIDE = { LeftEndCap = "hideGryphonLeft", RightEndCap = "hideGryphonRight" }
local MAGNET = 8   -- edit mode's own snap reach, UIParent units
local MAGNET_TARGETS = { "ForeverClassicUIBar", "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
    "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar", "MainStatusTrackingBarContainer",
    "SecondaryStatusTrackingBarContainer", "ForeverClassicUIGryphonLeft", "ForeverClassicUIGryphonRight" }
local CAP_LEVEL = 3   -- over the band's own art, under the buttons (B.ButtonLevel), as 1.x drew the end caps

function B.BuildArt()
    local art = CreateFrame("Frame", "ForeverClassicUIBar", UIParent)
    B.art = art
    art:SetSize(ART_W, ART_H)
    art:SetFrameStrata("MEDIUM")
    art:SetFrameLevel(1)
    art.pieces = {}
    -- The most runs B.Segments makes: two body sheets, micro region of two, page room, the latency and key ring section,
    -- three bag runs, a second micro region of two, the post.
    for i = 1, 12 do
        art.pieces[i] = art:CreateTexture(nil, "BACKGROUND")
    end
    art.pageEdge = art:CreateTexture(nil, "BACKGROUND", nil, 1)
    -- Gryphons on their own layer under the buttons, as 1.x drew the end caps.
    local capLayer = CreateFrame("Frame", nil, art)
    capLayer:SetAllPoints(art)
    capLayer:SetFrameLevel(CAP_LEVEL)
    art.capLayer = capLayer
    -- Each picture fills its named home, which our Windows edit mode moves and sizes (UI/WindowHandles.lua); an unplaced
    -- home stands on its foot, a point at the band end, so a size step keeps it there.
    art.capHomes, art.capFeet = {}, {}
    for key, texKey in pairs(CAP_TEX) do
        local foot = CreateFrame("Frame", nil, art)
        foot:SetSize(1, 1)
        foot:SetPoint("BOTTOM", art, "BOTTOM", key == "LeftEndCap" and -544 or 544, 0)
        art.capFeet[key] = foot
        local home = CreateFrame("Frame", GRYPHON_NAMES[key], art)
        home:SetSize(CAP_SIZE, CAP_SIZE)
        home:SetPoint("BOTTOM", foot, "BOTTOM", 0, 0)
        art.capHomes[key] = home
        art[texKey] = capLayer:CreateTexture(nil, "OVERLAY", nil, 5)
        art[texKey]:SetAllPoints(home)
    end
    -- Their saved places and sizes, now that the named frames exist.
    ns.PlaceSavedWindows()
    -- The thin bar along the top when no experience bar is shown.
    art.maxLevel = {}
    for i = 1, 4 do
        local tex = art:CreateTexture(nil, "BACKGROUND")
        tex:SetSize(256, 7)
        tex:SetPoint("BOTTOM", art, "TOP", -384 + (i - 1) * 256, -11)
        art.maxLevel[i] = tex
    end
    -- Scaled row frames, so button offsets are written in 1.x pixels.
    art.rows = {}
    -- Right columns hang from the screen corner, not the band or their bars, so edit mode can't shift their 1.x spot.
    art.sideAnchor = CreateFrame("Frame", nil, UIParent)
    art.sideAnchor:SetSize(1, 1)
    art.sideAnchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    for _, index in ipairs({ 7, 8 }) do
        local row = CreateFrame("Frame", nil, art.sideAnchor)
        row:SetSize(1, 1)
        art.rows[index] = row
    end
end

function B.PaintArt()
    local art = B.art
    -- Gryphons over bars: their layer above every button slot (pet and stance slots stand near 73).
    ns.SetLevelIf(art.capLayer, ns.db.gryphonsOverBars and B.ButtonLevel() + 40 or CAP_LEVEL)
    local segments = Segments()
    -- Hide Bar Art on Action Bar 1 drops its runs and the gryphons like the client's art; the micro menu's and the bags'
    -- runs go by their own Hide Bar Art. Buttons and the xp bar stay.
    local main = ns.GetMainBar()
    local bare = main and main.hideBarArt == true
    ARTLESS.bar, ARTLESS.micro, ARTLESS.bags = bare, ns.db.hideMicroArt == true, ns.db.hideBagsArt == true
    for i, tex in ipairs(art.pieces) do
        local seg = segments[i]
        -- A hidden run keeps its top rim, the bottom border of the XP strip (or thin bar) over it; bar 1's takes all.
        local rim = seg and ARTLESS[seg[6]] and not bare
        if seg and ARTLESS[seg[6]] and not rim then seg = nil end
        if seg then
            -- The band art carries the slot frames, page number surround and sockets, so it tints bronze whole.
            local piece = PIECES[seg[3]]
            local v0, v1 = piece.band[1], piece.band[2]
            if rim then v1 = v0 + (v1 - v0) * RIM_H / BAND_H end
            RUN[1], RUN[2], RUN[3], RUN[4] = seg[4], seg[5], v0, v1
            Dress(tex, piece.key, BAND_RUN, art, seg[1], rim and BAND_H - RIM_H or 0, seg[2], rim and RIM_H or BAND_H, RUN)
        else
            tex:Hide()
        end
    end
    -- The number box's edge jutting past its post, over the piece that starts there.
    local edgeX = B.CurrentPlan().pageEdge
    if edgeX and not bare then
        local band = PIECES[3].band
        local row = (band[2] - band[1]) / BAND_H
        RUN[1], RUN[2] = PAGE_POST / 256, PAGE_ROOM / 256
        RUN[3], RUN[4] = band[2] - (PAGE_BOX_Y + PAGE_BOX_H) * row, band[2] - PAGE_BOX_Y * row
        Dress(art.pageEdge, PIECES[3].key, BAND_RUN, art, edgeX, PAGE_BOX_Y, PAGE_ROOM - PAGE_POST, PAGE_BOX_H, RUN)
    else
        art.pageEdge:Hide()
    end
    B.LayLatency(bare)
    Dress(art.leftCap, "endCap", CAP_LEFT)
    Dress(art.rightCap, "endCap", CAP_RIGHT)
    for i, tex in ipairs(art.maxLevel) do
        local v = (i - 1) * 0.25
        RUN[1], RUN[2], RUN[3], RUN[4] = 0, 1, v, v + 0.21875
        Dress(tex, "maxLevel", nil, nil, nil, nil, nil, nil, RUN)
    end
end

-- Gryphons: our pictures on homes of ours, placed and sized in our Windows edit mode. The client's caps hide in a frame
-- of ours: faded, they stayed edit mode pieces others snapped to, and the layout saves a snap to them (no name) at the
-- screen's top. Forever's caps are edit mode frames; retail's are the bar's own textures, which CapFrame leaves out.
local function CapFrame(bar, key)
    local caps = bar and bar.EndCaps
    local cap = caps and caps[key]
    return cap and cap.IsObjectType and cap:IsObjectType("Frame") and cap or nil
end
B.CapFrame = CapFrame

-- Retail's cap texture (nil on Forever): faded under ours while the band is on.
local function ClientCapTexture(bar, key)
    local caps = bar and bar.EndCaps
    local cap = caps and caps[key]
    return cap and cap.IsObjectType and cap:IsObjectType("Texture") and cap or nil
end
B.ClientCapTexture = ClientCapTexture

local function CapHidden(cap)
    local setting = Enum and Enum.EditModeMainActionBarEndCapSetting and Enum.EditModeMainActionBarEndCapSetting.Hidden
    if not cap or setting == nil or not cap.GetSettingValueBool then return false end
    local ok, hidden = pcall(cap.GetSettingValueBool, cap, setting)
    return ok and hidden and true or false
end

-- The game's own Hidden on a cap (its dialog, gone with the handle) becomes our choice once the layout is applied.
local function CarryHiddenCaps(bar)
    for _, key in ipairs(CAP_KEYS) do
        local cap = CapFrame(bar, key)
        if cap and not cap.systemInfo then return end
    end
    for _, key in ipairs(CAP_KEYS) do
        if CapHidden(CapFrame(bar, key)) then ns.db[GRYPHON_SHOW[key]], ns.db[GRYPHON_HIDE[key]] = false, true end
    end
    ns.db.gryphonHiddenCarried = true
end

local function GryphonShown(bar, key)
    return not (bar and bar.hideBarArt == true) and not ns.db[GRYPHON_HIDE[key]]
end

-- A cap's bottom-centre offset from the band's, the same on both ends.
local function CapSlot(key, w)
    return key == "LeftEndCap" and -(w / 2 + 32) or w / 2 + 32
end
B.CapSlot = CapSlot

-- A gryphon on its band end unless placed (anyway: a drag's preview of home) or in hand. The foot from the art's left
-- edge, as the art keeps its old length in a fight.
local function LayCapHome(key, w, anyway)
    local art = B.art
    local foot = art.capFeet[key]
    ns.SetPointOnce(foot, "BOTTOM", art, "BOTTOMLEFT", w / 2 + CapSlot(key, w), 0)
    local home = art.capHomes[key]
    if ns.WindowMoving(home) and not anyway then return end
    if ns.WindowPlaced(GRYPHON_KEYS[key]) and not anyway then return end
    if not ns.IsAt(home, "BOTTOM", foot, "BOTTOM", 0, 0) then ns.SetPointOnce(home, "BOTTOM", foot, "BOTTOM", 0, 0) end
end
B.LayCapHome = LayCapHome

-- Edit mode's reset and size steps (ns.LayPiece); anyway: home while dragged near it, whatever the saved place.
function ns.LayGryphon(key, anyway)
    for capKey, gryphonKey in pairs(GRYPHON_KEYS) do
        if gryphonKey == key and B.art then LayCapHome(capKey, ArtWidth(), anyway) end
    end
end

-- A frame's sides in UIParent units, or nil.
local function Sides(frame)
    local l, r, t, b = ns.Safe(frame:GetLeft()), ns.Safe(frame:GetRight()), ns.Safe(frame:GetTop()), ns.Safe(frame:GetBottom())
    if not (l and r and t and b) then return nil end
    local k = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return l * k, r * k, t * k, b * k
end

-- The shortest move within edit mode's own snap reach, kept against the best so far.
local function Pull(best, move)
    if math.abs(move) <= MAGNET and (not best or math.abs(move) < math.abs(best)) then return move end
    return best
end

-- Snap to Elements for a dropped box: edges beside, over or level with a shown bar's. Its new top left, UIParent units.
local function Magnet(box, own)
    local l, r, t, b = Sides(box)
    if not l then return nil end
    local dx, dy
    for _, name in ipairs(MAGNET_TARGETS) do
        local target = _G[name]
        local tl, tr, tt, tb
        if target and target ~= own and target:IsVisible() and target:GetEffectiveAlpha() > 0 then tl, tr, tt, tb = Sides(target) end
        if tl then
            if b < tt and t > tb then
                dx = Pull(Pull(Pull(Pull(dx, tl - r), tr - l), tl - l), tr - r)
            end
            if l < tr and r > tl then
                dy = Pull(Pull(Pull(Pull(dy, tb - t), tt - b), tb - b), tt - t)
            end
        end
    end
    return l + (dx or 0), t + (dy or 0)
end

-- Where a gryphon's box would land if let go now (UI/WindowHandles.lua), while edit mode's Snap to Elements is on:
-- "home" near its band end, else its top left pulled to the bars; nil where it is.
function ns.SnapPieceDrop(key, box)
    local mgr = EditModeManagerFrame
    if not (mgr and mgr.IsSnapEnabled and mgr:IsSnapEnabled()) then return nil end
    for capKey, gryphonKey in pairs(GRYPHON_KEYS) do
        if gryphonKey == key and B.art then
            local fl, fr, _, fb = Sides(B.art.capFeet[capKey])
            local bl, br, _, bb = Sides(box)
            if fl and bl and math.abs((bl + br - fl - fr) / 2) < B.SNAP_PX and math.abs(bb - fb) < B.SNAP_PX then
                return "home"
            end
            return Magnet(box, B.art.capHomes[capKey])
        end
    end
end

-- A gryphon dragged by its old handle (the client's cap) keeps that spot as our place, once the layout has put it there.
local function CarryMovedCap(cap, key)
    local moved = ns.db.capMoved
    if not (moved and moved[key]) or not cap.systemInfo then return end
    moved[key] = nil
    if next(moved) == nil then ns.db.capMoved = nil end
    if InDefaultPosition(cap) or ns.WindowPlaced(GRYPHON_KEYS[key]) then return end
    local home = B.art.capHomes[key]
    ns.SetPointOnce(home, "BOTTOM", cap, "BOTTOM", 0, 0)
    local left, top = home:GetLeft(), home:GetTop()
    if not (left and top) then return end
    local k = home:GetEffectiveScale() / UIParent:GetEffectiveScale()
    ns.SetWindowPlace(GRYPHON_KEYS[key], left * k, top * k)
    ns.PlaceSavedWindows()
end

-- Hidden, not faded: edit mode snaps to what is visible. Caps are no layout-managed frames, so the client never re-parents them.
local stash
local function StashCap(cap)
    if cap:GetParent() == stash or (InCombatLockdown() and cap:IsProtected()) then return end
    if not stash then
        stash = CreateFrame("Frame")
        stash:Hide()
    end
    cap:SetParent(stash)
end

-- Band off: the client's caps back on its bar.
function B.UnstashCaps(bar)
    for _, key in ipairs(CAP_KEYS) do
        local cap = CapFrame(bar, key)
        if cap and stash and cap:GetParent() == stash then cap:SetParent(bar.EndCaps) end
    end
end

local function PlaceCaps(bar, w)
    local art = B.art
    if not ns.db.gryphonHiddenCarried then CarryHiddenCaps(bar) end
    for _, key in ipairs(CAP_KEYS) do
        local tex = art[CAP_TEX[key]]
        local cap = CapFrame(bar, key)
        -- Ours tint bronze with the theme; the client's pair, shown for it, flashed, jumped and came back silver.
        ns.BronzeTint(tex)
        if cap then
            if ns.db.capMoved then CarryMovedCap(cap, key) end
            StashCap(cap)
        else
            local client = ClientCapTexture(bar, key)
            if client then ns.SetAlphaIf(client, 0) end
        end
        LayCapHome(key, w)
        tex:SetShown(GryphonShown(bar, key))
    end
end

-- Band width, and gryphons hidden with Hide Bar Art (as the client's end caps go).
local function ApplyArtShape(bar)
    local art = B.art
    local hide = bar and bar.hideBarArt == true
    local w = ArtWidth()
    art:SetSize(w, ART_H)
    art.artHidden = hide
    PlaceCaps(bar, w)
    for i, tex in ipairs(art.maxLevel) do
        -- Cut to the band's length, not a whole number of sheets.
        local seen = math.max(0, math.min(256, w - (i - 1) * 256))
        ns.SetPointOnce(tex, "BOTTOMLEFT", art, "TOPLEFT", (i - 1) * 256, -11)
        tex:SetWidth(math.max(seen, 1))
        tex:SetTexCoord(0, seen / 256, (i - 1) * 0.25, (i - 1) * 0.25 + 0.21875)
        tex.fcuiInBand = seen > 0
    end
end
B.ApplyArtShape = ApplyArtShape

-- The micro menu's selection box stays hidden: it moves by our handle (MicroHome). Bags and tracking bars
-- keep theirs, as pieces the player can take off the band.
local HIDDEN_BOXES = { "MicroMenuContainer" }
function B.HideSelections()
    for _, name in ipairs(HIDDEN_BOXES) do
        local system = _G[name]
        local selection = system and system.Selection
        if selection and selection:IsShown() then selection:Hide() end
    end
    -- Status Tracking Bar 2's tick shows the second holder even empty (as the upper strip) and its box covered
    -- bars 2/3's, which rise only for a shown bar: hidden while empty and nothing is off the band, else restored if still lit.
    local second = SecondaryStatusTrackingBarContainer
    local selection = second and second.Selection
    if selection then
        local empty = not B.HasVisibleBar(second) and not B.SystemMoved(second)
            and not B.SystemMoved(MainStatusTrackingBarContainer)
        if empty and selection:IsShown() then
            selection:Hide()
        elseif not empty and not selection:IsShown() and (second.isHighlighted or second.isSelected) then
            selection:Show()
        end
    end
end

-- Hide Bar Art follows on every art refresh, without a full layout pass (that stuttered while toggling).
function B.KeepBarShape()
    local bar = ns.GetMainBar()
    if not bar then return end
    local art = B.art
    for _, key in ipairs(CAP_KEYS) do
        local tex = art and art[CAP_TEX[key]]
        if tex then ns.SetShownIf(tex, GryphonShown(bar, key)) end
    end
    if art and (bar.hideBarArt == true) ~= (art.artHidden == true) then ApplyArtShape(bar) end
end
