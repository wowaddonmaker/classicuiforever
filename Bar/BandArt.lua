local _, ns = ...
local B = ns.band

-- Band art: the stone runs, the gryphons and the thin top bar.

local ART_W, BAND_H, CAP_SIZE = B.ART_W, B.BAND_H, B.CAP_SIZE
local PIECES, CAP_KEYS, BAND_RUN = B.PIECES, B.CAP_KEYS, B.BAND_RUN
local ART_H = 53
local Segments, ArtWidth = B.Segments, B.ArtWidth
local Dress, FadeTextures, InDefaultPosition = ns.Dress, ns.FadeTextures, ns.InDefaultPosition

local FULL = { 0, 1, 0, 1 }
local CAP_LEFT, CAP_RIGHT = { coords = FULL }, { coords = { 1, 0, 0, 1 } }
local CHANGED = { changed = true }
local RUN = {}   -- a run's coords, refilled per piece
local ARTLESS = {}   -- segment owner -> its art hidden, refilled per paint
local RIM_H = 2      -- the band's top rows: the lower border of the strip over it
local CAP_TEX = { LeftEndCap = "leftCap", RightEndCap = "rightCap" }
local CAP_LEVEL = 100   -- the client's own end caps level: over every action bar, under hotkey text

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
    -- Gryphons on their own layer over the action bars, as the client's end caps draw.
    local capLayer = CreateFrame("Frame", nil, art)
    capLayer:SetAllPoints(art)
    capLayer:SetFrameLevel(CAP_LEVEL)
    art.leftCap = capLayer:CreateTexture(nil, "OVERLAY", nil, 5)
    art.leftCap:SetSize(CAP_SIZE, CAP_SIZE)
    art.leftCap:SetPoint("BOTTOM", art, "BOTTOM", -544, 0)
    art.rightCap = capLayer:CreateTexture(nil, "OVERLAY", nil, 5)
    art.rightCap:SetSize(CAP_SIZE, CAP_SIZE)
    art.rightCap:SetPoint("BOTTOM", art, "BOTTOM", 544, 0)
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
    B.LayLatency(bare)
    Dress(art.leftCap, "endCap", CAP_LEFT)
    Dress(art.rightCap, "endCap", CAP_RIGHT)
    for i, tex in ipairs(art.maxLevel) do
        local v = (i - 1) * 0.25
        RUN[1], RUN[2], RUN[3], RUN[4] = 0, 1, v, v + 0.21875
        Dress(tex, "maxLevel", nil, nil, nil, nil, nil, nil, RUN)
    end
end

-- Gryphons: our textures on the client's end caps (still edit mode handles, art faded). A cap sits on its band
-- end until dragged and snaps back when dropped near it; "moved" means only a drag we saw.
-- Forever's caps are edit mode frames; retail's are the bar's own textures, which CapFrame leaves out.
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

local function CapHeldKey(key) return key == "LeftEndCap" and "capHeldLeft" or "capHeldRight" end
B.CapHeldKey = CapHeldKey

-- Whether the player dragged a cap off the band, by our record of the drop alone: the client turns a cap's snap into a
-- fixed spot itself whenever bar 1 moves or hides, so its layout says moved when nobody moved it (the cap popped out).
local function CapMoved(key)
    if ns.db and ns.db[CapHeldKey(key)] == true then return false end
    return ns.db ~= nil and ns.db.capMoved ~= nil and ns.db.capMoved[key] == true
end
B.CapMoved = CapMoved

local function CapHidden(cap)
    local setting = Enum and Enum.EditModeMainActionBarEndCapSetting and Enum.EditModeMainActionBarEndCapSetting.Hidden
    if not cap or setting == nil or not cap.GetSettingValueBool then return false end
    local ok, hidden = pcall(cap.GetSettingValueBool, cap, setting)
    return ok and hidden and true or false
end

-- A cap's bottom-centre offset from the band's, the same on both ends.
local function CapSlot(key, w)
    return key == "LeftEndCap" and -(w / 2 + 32) or w / 2 + 32
end
B.CapSlot = CapSlot

-- Our cap picture for a key.
function B.CapTexture(key) return B.art[CAP_TEX[key]] end

local function PlaceCaps(bar, w, hideArt)
    local art = B.art
    local container = bar and bar.EndCaps
    if container and not container:IsShown() then container:Show() end
    for _, key in ipairs(CAP_KEYS) do
        local tex = art[CAP_TEX[key]]
        local cap = CapFrame(bar, key)
        tex:ClearAllPoints()
        -- Ours tint bronze with the theme; the client's pair, shown for it, flashed, jumped and came back silver.
        ns.BronzeTint(tex)
        if cap and cap.GetPoint then
            FadeTextures(cap, 0, CHANGED)
            -- Reset To Default Position in the cap's dialog: back on the band.
            if (CapMoved(key) or ns.db[CapHeldKey(key)]) and InDefaultPosition(cap) then
                if ns.db.capMoved then ns.db.capMoved[key] = nil end
                ns.db[CapHeldKey(key)] = false
            end
            if not CapMoved(key) and not cap.isDragging then
                ns.OverlayOnBand(cap, "BOTTOM", "BOTTOM", CapSlot(key, w), 0, CAP_SIZE, CAP_SIZE)
                -- On the band itself: the client re-anchors its cap frames (layout applies); they only carry the handle.
                tex:SetPoint("BOTTOM", art, "BOTTOM", CapSlot(key, w), 0)
            else
                -- Moved or in hand: the picture rides the frame at the band's size, whatever the frame's.
                tex:SetPoint("BOTTOM", cap, "BOTTOM", 0, 0)
            end
            tex:SetShown(not hideArt and not CapHidden(cap))
        else
            local client = ClientCapTexture(bar, key)
            if client then ns.SetAlphaIf(client, 0) end
            tex:SetPoint("BOTTOM", art, "BOTTOM", CapSlot(key, w), 0)
            tex:SetShown(not hideArt)
        end
    end
end

-- Band width, and gryphons hidden with Hide Bar Art (as the client's end caps go).
local function ApplyArtShape(bar)
    local art = B.art
    local hide = bar and bar.hideBarArt == true
    local w = ArtWidth()
    art:SetSize(w, ART_H)
    art.artHidden = hide
    PlaceCaps(bar, w, hide)
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

-- The client repaints its gryphons on every art refresh; ours stay the ones shown. Hide Bar Art is handled
-- here too, without a full layout pass (that stuttered while toggling).
function B.KeepBarShape()
    local bar = ns.GetMainBar()
    if not bar then return end
    local art = B.art
    for _, key in ipairs(CAP_KEYS) do
        local cap = CapFrame(bar, key)
        if cap then
            FadeTextures(cap, 0, CHANGED)
            local tex = art and art[CAP_TEX[key]]
            if tex then ns.SetShownIf(tex, bar.hideBarArt ~= true and not CapHidden(cap)) end
        end
    end
    if art and (bar.hideBarArt == true) ~= (art.artHidden == true) then ApplyArtShape(bar) end
end
