local _, ns = ...

-- Shared texture dressing: specs are call-site constants, nothing allocates per call.
-- Art/Textures helpers are looked up at call time.

local EMPTY = ns.EMPTY
local IsSecret = ns.IsSecret
local SetAlphaIf, SetLevelIf = ns.SetAlphaIf, ns.SetLevelIf
local OwnTexture = ns.OwnTexture
local select, type, pairs = select, type, pairs

-- Art paths shared by several files.
local ART = {
    DIALOG_BG = "Interface\\DialogFrame\\UI-DialogBox-Background",
    DIALOG_BG_DARK = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    DIALOG_BORDER = "Interface\\DialogFrame\\UI-DialogBox-Border",
    DIALOG_HEADER = "Interface\\DialogFrame\\UI-DialogBox-Header",
    TIP_BG = "Interface\\Tooltips\\UI-Tooltip-Background",
    TIP_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border",
    WHITE = "Interface\\Buttons\\WHITE8X8",
    PANEL_BUTTON = "Interface\\Buttons\\UI-Panel-Button-",
    CHECK = "Interface\\Buttons\\UI-CheckBox-",
    PAGE_PREV = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-",
    PAGE_NEXT = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-",
    HILIGHT = "Interface\\Buttons\\UI-Common-MouseHilight",
    PLUS = "Interface\\Buttons\\UI-PlusButton-Up",
    PLUS_DOWN = "Interface\\Buttons\\UI-PlusButton-Down",
    MINUS = "Interface\\Buttons\\UI-MinusButton-Up",
    PLUS_GLOW = "Interface\\Buttons\\UI-PlusButton-Hilight",
    QUICKSLOT = "Interface\\Buttons\\UI-Quickslot2",
    GOLD_BAR = "Interface\\QuestFrame\\UI-QuestLogTitleHighlight",
}
ns.ART = ART

-- Key lists the fades walk; read only.
ns.KEYS = {
    LMR = { "Left", "Middle", "Right" },
    LRM = { "Left", "Right", "Middle" },
    LRC = { "Left", "Right", "Center" },
    THUMB = { "Begin", "Middle", "End" },
    TAB_GLOW = { "LeftHighlight", "MiddleHighlight", "RightHighlight" },
    PANEL = { "Left", "Right", "Center", "Middle", "TopLeft", "TopRight", "BottomLeft", "BottomRight", "TopMiddle",
        "MiddleLeft", "MiddleRight", "BottomMiddle", "MiddleMiddle" },
    STATES = { "Normal", "Pushed", "Disabled", "Highlight" },
}
local STATES = ns.KEYS.STATES

---------------------------------------------------------------- one region

-- set: "key" (default, ns.SetTex), "file" (ns.SetFile, bronze copy) or "raw".
local function SetArt(tex, art, set)
    if set == "file" then return ns.SetFile(tex, art) ~= false end
    if set == "raw" then return tex:SetTexture(art) ~= false end
    return ns.SetTex(tex, art)
end

local function SetCoords(tex, c)
    if c[5] ~= nil then
        tex:SetTexCoord(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8])
    else
        tex:SetTexCoord(c[1], c[2], c[3], c[4])
    end
end

-- A three-value colour passes no alpha argument.
local function ApplyColor(region, method, c)
    if c[4] ~= nil then region[method](region, c[1], c[2], c[3], c[4]) else region[method](region, c[1], c[2], c[3]) end
end
ns.ApplyColor = ApplyColor

-- Vertex goes after the tint, but a theme repaint resets it on tinted pieces:
-- never pair spec.vertex with tint or a metal key.
local function DressTex(tex, key, spec, rel, x, y, w, h, coords, skipLayer)
    local ok = true
    if key ~= nil then ok = SetArt(tex, key, spec.set) end
    local tint = spec.tint
    if tint then ns.BronzeTint(tex, tint ~= true and tint or nil) end
    local c = coords or spec.coords
    if c then SetCoords(tex, c) end
    if w == nil then w = spec.w end
    if h == nil then h = spec.h end
    if w ~= nil and h ~= nil then
        tex:SetSize(w, h)
    elseif w ~= nil then
        tex:SetWidth(w)
    elseif h ~= nil then
        tex:SetHeight(h)
    end
    if spec.horizTile ~= nil and tex.SetHorizTile then tex:SetHorizTile(spec.horizTile) end
    local point = spec.point
    if spec.fill or point then
        rel = rel or tex:GetParent()
        if not spec.keep then tex:ClearAllPoints() end
        if spec.fill then
            tex:SetAllPoints(rel)
        else
            if x == nil then x = spec.x or 0 end
            if y == nil then y = spec.y or 0 end
            tex:SetPoint(point, rel, spec.relPoint or point, x, y)
            local point2 = spec.point2
            if point2 then tex:SetPoint(point2, rel, spec.relPoint2 or point2, spec.x2 or 0, spec.y2 or 0) end
        end
    end
    local layer = spec.layer
    if layer and not skipLayer then
        if spec.sublevel ~= nil then tex:SetDrawLayer(layer, spec.sublevel) else tex:SetDrawLayer(layer) end
    end
    if spec.blend then tex:SetBlendMode(spec.blend) end
    if spec.vertex then ApplyColor(tex, "SetVertexColor", spec.vertex) end
    if spec.alpha ~= nil then tex:SetAlpha(spec.alpha) end
    if spec.show == true then tex:Show() elseif spec.show == false then tex:Hide() end
    return tex, ok
end

-- nil key keeps the art; non-nil x, y, w, h, coords override the spec's; rel defaults to the parent.
-- Coords computed at run time go in a reused table.
function ns.Dress(tex, key, spec, rel, x, y, w, h, coords)
    if not tex then return nil end
    return DressTex(tex, key, spec or EMPTY, rel, x, y, w, h, coords, false)
end

-- spec.own reuses an OwnTexture; the layer is set at creation only.
local function NewTex(parent, spec)
    local own = spec.own
    if own then return OwnTexture(parent, own, spec.layer, spec.sublevel) end
    return parent:CreateTexture(nil, spec.layer or "ARTWORK", nil, spec.sublevel or 0)
end

function ns.DressNew(parent, key, spec, rel, x, y, w, h, coords)
    spec = spec or EMPTY
    return DressTex(NewTex(parent, spec), key, spec, rel or parent, x, y, w, h, coords, true)
end

-- Each piece is a spec with its own key: spec.field dresses owner[field] (client pieces), else a new one.
-- spec.chain anchors to the previous piece; out is a table to fill, or true for a new one.
function ns.DressPieces(owner, pieces, rel, out)
    if out == true then out = {} end
    rel = rel or owner
    local prev
    for i = 1, #pieces do
        local spec = pieces[i]
        local field = spec.field
        local tex
        if field then tex = owner[field] else tex = NewTex(owner, spec) end
        if tex then
            DressTex(tex, spec.key, spec, (spec.chain and prev) or rel, nil, nil, nil, nil, nil, not field)
            prev = tex
        end
        if out then out[i] = tex end
    end
    return out
end

------------------------------------------------------ cap, middle, cap

local EDGE_POINT = {
    TOP = { LEFT = "TOPLEFT", RIGHT = "TOPRIGHT" },
    BOTTOM = { LEFT = "BOTTOMLEFT", RIGHT = "BOTTOMRIGHT" },
}

local sliceNames = {}
local function SliceNames(prefix)
    local names = sliceNames[prefix]
    if not names then
        names = { prefix .. "Left", prefix .. "Middle", prefix .. "Right" }
        sliceNames[prefix] = names
    end
    return names
end

local function SlicePiece(tex, key, spec, c)
    if key ~= nil then SetArt(tex, key, spec.set) end
    local tint = spec.tint
    if tint then ns.BronzeTint(tex, tint ~= true and tint or nil) end
    if c then SetCoords(tex, c) end
    if spec.horizTile ~= nil and tex.SetHorizTile then tex:SetHorizTile(spec.horizTile) end
end

local function SliceCap(tex, key, spec, c, cap, rel, side, ox, oy)
    SlicePiece(tex, key, spec, c)
    local h = spec.height
    if h then tex:SetSize(cap, h) else tex:SetWidth(cap) end
    tex:ClearAllPoints()
    local dx = side == "LEFT" and -ox or ox
    if h then
        local point = EDGE_POINT[spec.edge or "TOP"][side]
        tex:SetPoint(point, rel, point, dx, oy)
    else
        tex:SetPoint(EDGE_POINT.TOP[side], rel, EDGE_POINT.TOP[side], dx, oy)
        tex:SetPoint(EDGE_POINT.BOTTOM[side], rel, EDGE_POINT.BOTTOM[side], dx, -oy)
    end
    if spec.show then tex:Show() end
end

local function SliceMiddle(tex, key, spec, c, left, right)
    SlicePiece(tex, key, spec, c)
    local h = spec.height
    local edgeWise = spec.middle == "edge"
    if spec.midW and h then
        tex:SetSize(spec.midW, h)
    elseif edgeWise and h then
        tex:SetHeight(h)
    end
    if left and right then
        tex:ClearAllPoints()
        if edgeWise then
            local points = EDGE_POINT[spec.edge or "TOP"]
            tex:SetPoint(points.LEFT, left, points.RIGHT, 0, 0)
            tex:SetPoint(points.RIGHT, right, points.LEFT, 0, 0)
        else
            tex:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
            tex:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
        end
    end
    if spec.show then tex:Show() end
end

-- nil key means spec.key. Pieces: spec.fields (owner's regions), spec.own (OwnTexture
-- prefix, safe to re-run) or three new textures, made left, right, middle.
-- With spec.height the caps sit on spec.edge at x -ox/+ox, y oy; else they span rel's height.
-- The middle runs between the caps (along the edge with spec.middle = "edge"), only when both exist.
function ns.ThreeSlice(owner, key, spec, rel, ox, oy)
    if not owner or not spec then return nil end
    local left, middle, right
    local fields, own = spec.fields, spec.own
    if fields then
        left, middle, right = owner[fields[1]], owner[fields[2]], owner[fields[3]]
    elseif own then
        local names = SliceNames(own)
        left = OwnTexture(owner, names[1], spec.layer, spec.sublevel)
        right = OwnTexture(owner, names[3], spec.layer, spec.sublevel)
        middle = OwnTexture(owner, names[2], spec.layer, spec.sublevel)
    else
        local layer, sublevel = spec.layer or "ARTWORK", spec.sublevel or 0
        left = owner:CreateTexture(nil, layer, nil, sublevel)
        right = owner:CreateTexture(nil, layer, nil, sublevel)
        middle = owner:CreateTexture(nil, layer, nil, sublevel)
    end
    rel = rel or owner
    if key == nil then key = spec.key end
    if ox == nil then ox = spec.ox or 0 end
    if oy == nil then oy = spec.oy or 0 end
    local c = spec.coords or EMPTY
    if left then SliceCap(left, key, spec, c[1], spec.capL or spec.cap, rel, "LEFT", ox, oy) end
    if right then SliceCap(right, key, spec, c[3], spec.capR or spec.cap, rel, "RIGHT", ox, oy) end
    if middle then SliceMiddle(middle, key, spec, c[2], left, right) end
    return left, middle, right
end

-------------------------------------------------------------- tiled floors

-- how: vert = false tiles across only, tint = false skips bronze, coords, shade (number or {r, g, b}).
-- The shade goes on after the tint, so a theme repaint resets it.
function ns.TileTex(tex, key, how, shade)
    if not tex then return nil end
    how = how or EMPTY
    local vert = how.vert ~= false
    tex:SetTexture((ns.TexPath(key)), "REPEAT", vert and "REPEAT" or "CLAMP")
    if how.tint ~= false then ns.BronzeTint(tex) end
    tex:SetHorizTile(true)
    if vert then tex:SetVertTile(true) end
    if how.coords then SetCoords(tex, how.coords) end
    if shade == nil then shade = how.shade end
    if type(shade) == "number" then
        tex:SetVertexColor(shade, shade, shade)
    elseif shade then
        ApplyColor(tex, "SetVertexColor", shade)
    end
    return tex
end

------------------------------------------------------------ button states

local STATE_SET = {
    Normal = "SetNormalTexture", Pushed = "SetPushedTexture", Disabled = "SetDisabledTexture",
    Highlight = "SetHighlightTexture", Checked = "SetCheckedTexture", DisabledChecked = "SetDisabledCheckedTexture",
}
local STATE_GET = {
    Normal = "GetNormalTexture", Pushed = "GetPushedTexture", Disabled = "GetDisabledTexture",
    Highlight = "GetHighlightTexture", Checked = "GetCheckedTexture", DisabledChecked = "GetDisabledCheckedTexture",
}

local function StateTexture(button, state)
    local getter = button[STATE_GET[state]]
    return getter and getter(button)
end
ns.StateTexture = StateTexture

-- set: "key" (default), "file", "raw" (plain setter) or "tex" (SetTex on the existing texture).
local function SetState(button, state, art, set)
    if art == nil then return end
    if set == "file" then
        ns.SetButtonFile(button, state, art)
    elseif set == "raw" then
        local setter = button[STATE_SET[state]]
        if setter then setter(button, art) end
    elseif set == "tex" then
        local tex = StateTexture(button, state)
        if tex then ns.SetTex(tex, art) end
    else
        ns.SetButtonTex(button, state, art)
    end
end

-- One value for every state, or a table by state.
local function ByState(value, state, isList)
    if type(value) ~= "table" then return value end
    if isList and value[1] ~= nil then return value end
    return value[state]
end

-- nil art leaves that state. how: set, highlightSet (Highlight, Checked, DisabledChecked),
-- checked, disabledChecked, size = {w, h}, states (default the four), hit = {l, r, t, b};
-- per state texture: coords, fill, center = {w, h} or inset = {x1, y1, x2, y2}, layer, alpha
-- (value or table by state), add (true: ADD on Highlight; table: the states it names).
function ns.DressStates(button, normal, pushed, disabled, highlight, how)
    if not button then return end
    how = how or EMPTY
    local size = how.size
    if size then button:SetSize(size[1], size[2]) end
    local set = how.set
    SetState(button, "Normal", normal, set)
    SetState(button, "Pushed", pushed, set)
    SetState(button, "Disabled", disabled, set)
    local highlightSet = how.highlightSet or set
    SetState(button, "Highlight", highlight, highlightSet)
    SetState(button, "Checked", how.checked, highlightSet)
    SetState(button, "DisabledChecked", how.disabledChecked, highlightSet)
    local coords, fill, center, layer, alpha, add = how.coords, how.fill, how.center, how.layer, how.alpha, how.add
    local inset = how.inset
    if coords or fill or center or inset or layer or alpha ~= nil or add then
        local states = how.states or STATES
        for i = 1, #states do
            local state = states[i]
            local tex = StateTexture(button, state)
            if tex then
                local c = ByState(coords, state, true)
                if c then SetCoords(tex, c) end
                if fill then
                    tex:ClearAllPoints()
                    tex:SetAllPoints(button)
                elseif center then
                    tex:ClearAllPoints()
                    tex:SetPoint("CENTER", button, "CENTER", 0, 0)
                    tex:SetSize(center[1], center[2])
                elseif inset then
                    tex:ClearAllPoints()
                    tex:SetPoint("TOPLEFT", button, "TOPLEFT", inset[1], inset[2])
                    tex:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", inset[3], inset[4])
                end
                local l = ByState(layer, state)
                if l then tex:SetDrawLayer(l) end
                local a = ByState(alpha, state)
                if a ~= nil then tex:SetAlpha(a) end
                if (add == true and state == "Highlight") or (type(add) == "table" and add[state]) then tex:SetBlendMode("ADD") end
            end
        end
    end
    local hit = how.hit
    if hit then button:SetHitRectInsets(hit[1], hit[2], hit[3], hit[4]) end
end

-- fn(texture, state, a1, a2) per listed state the button has.
function ns.EachState(button, states, fn, a1, a2)
    if not button then return end
    for i = 1, #states do
        local state = states[i]
        local tex = StateTexture(button, state)
        if tex then fn(tex, state, a1, a2) end
    end
end

-------------------------------------------------------------------- fades

-- fn(region, a1, a2) per listed key the owner holds.
function ns.EachKey(owner, keys, fn, a1, a2)
    if not owner then return end
    for i = 1, #keys do
        local region = owner[keys[i]]
        if region then fn(region, a1, a2) end
    end
end

local function FadeKey(region, alpha, how)
    if not region.SetAlpha then return end
    if how.texture and not (region.IsObjectType and region:IsObjectType("Texture")) then return end
    if how.clearAtlas and region.SetAtlas then region:SetAtlas(nil) end
    if how.changed then SetAlphaIf(region, alpha) else region:SetAlpha(alpha) end
    if how.mouseOff and region.IsMouseEnabled and region:IsMouseEnabled() then region:EnableMouse(false) end
    if how.hide then region:Hide() end
end

-- alpha defaults to 0. how: texture (textures only), changed (via SetAlphaIf),
-- clearAtlas (SetAtlas(nil) first), mouseOff, hide.
function ns.FadeKeys(owner, keys, alpha, how)
    ns.EachKey(owner, keys, FadeKey, alpha or 0, how or EMPTY)
end

-- Copy of Util's local Askable: a forbidden frame may not be queried.
local function Askable(frame, method)
    if type(frame) ~= "table" or type(frame[method]) ~= "function" then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    return true
end

local function TexVisit(region, fn, a1, a2, a3)
    if region:IsObjectType("Texture") then fn(region, a1, a2, a3) end
end

-- fn(texture, a1, a2, a3) for each Texture region, no table made.
function ns.EachTexture(frame, fn, a1, a2, a3)
    ns.EachRegion(frame, TexVisit, fn, a1, a2, a3)
end

local function IsOwn(frame, region)
    local own = frame.fcui
    if type(own) ~= "table" then return false end
    for _, value in pairs(own) do
        if value == region then return true end
    end
    return false
end

local function FadeRegion(frame, region, alpha, how, s1, s2, s3)
    if region == s1 or region == s2 or region == s3 then return end
    if not region:IsObjectType("Texture") then return end
    if how.own and IsOwn(frame, region) then return end
    if how.changed then SetAlphaIf(region, alpha) else region:SetAlpha(alpha) end
end

local function FadeList(frame, alpha, how, s1, s2, s3, ...)
    for i = 1, select("#", ...) do
        FadeRegion(frame, (select(i, ...)), alpha, how, s1, s2, s3)
    end
end

local function FadeFrame(frame, alpha, how, s1, s2, s3)
    if Askable(frame, "GetRegions") then FadeList(frame, alpha, how, s1, s2, s3, frame:GetRegions()) end
end

local function FadeChildren(alpha, how, s1, s2, s3, ...)
    local skip = how.skipChild
    for i = 1, select("#", ...) do
        local child = select(i, ...)
        if not (skip and skip(child)) then FadeFrame(child, alpha, how, s1, s2, s3) end
    end
end

-- Skips s1..s3. how: own (skip frame.fcui members), changed (via SetAlphaIf),
-- children (direct children too, filtered by how.skipChild).
function ns.FadeTextures(frame, alpha, how, s1, s2, s3)
    if not frame then return end
    alpha = alpha or 0
    how = how or EMPTY
    FadeFrame(frame, alpha, how, s1, s2, s3)
    if how.children and Askable(frame, "GetChildren") then FadeChildren(alpha, how, s1, s2, s3, frame:GetChildren()) end
end

local function AtlasVisit(region, needle, exact, fn)
    if not region:IsObjectType("Texture") or not region.GetAtlas then return end
    local atlas = region:GetAtlas()
    if IsSecret(atlas) or atlas == nil then return end
    if exact then
        if atlas ~= needle then return end
    elseif not atlas:lower():find(needle, 1, true) then
        return
    end
    if fn then fn(region) else region:SetAlpha(0) end
end

-- Atlas contains needle (lower-case plain find), or equals it when exact: fade or call fn.
function ns.FadeAtlas(frame, needle, exact, fn)
    ns.EachRegion(frame, AtlasVisit, needle, exact, fn)
end

-- Child kept in parent.fcui[key]. how: kind, template, mouse (keep it), fill ("once" or true), show.
-- Level via SetLevelIf: the parent may be protected.
function ns.OwnFrame(parent, key, level, how)
    how = how or EMPTY
    local own = parent.fcui
    if not own then
        own = {}
        parent.fcui = own
    end
    local frame = own[key]
    local isNew = frame == nil
    if isNew then
        frame = CreateFrame(how.kind or "Frame", nil, parent, how.template)
        if not how.mouse then frame:EnableMouse(false) end
        if how.fill == "once" then frame:SetAllPoints(parent) end
        own[key] = frame
    end
    if how.fill == true then frame:SetAllPoints(parent) end
    if IsSecret(level) or level ~= nil then SetLevelIf(frame, level) end
    if how.show ~= false then frame:Show() end
    return frame, isNew
end

function ns.SetBarFill(bar, key)
    bar:SetStatusBarTexture((ns.TexPath(key or "statusBar")))
end

function ns.SetCollapseIcon(tex, collapsed)
    tex:SetTexture(collapsed and ART.PLUS or ART.MINUS)
end
