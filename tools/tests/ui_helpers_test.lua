-- Offline tests for UI/Dress.lua, UI/Dialogs.lua and the art themes under Lua 5.4.
-- Run from the addon root: lua tools/tests/ui_helpers_test.lua (CI runs every tools/tests/*_test.lua).
-- Loads the real Core/Util.lua, Core/Scheduler.lua, Core/Setters.lua, Art/ThemeArt.lua, Art/TextureData.lua,
-- Art/Textures.lua and Art/Bronze.lua over a stubbed client, then the two helper files.
-- luacheck: std lua54
-- luacheck: ignore 111 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

unpack = table.unpack

------------------------------------------------------------------ the stub client

local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
function issecretvalue(v) return v == SECRET end

local clock = 100
function GetTime() return clock end
local timers = {}
C_Timer = { After = function(s, fn) timers[#timers + 1] = { s, fn } end }
function geterrorhandler() return function(msg) error(msg, 0) end end
function InCombatLockdown() return false end
BackdropTemplateMixin = {}
StaticPopupDialogs = {}
ERR_NOT_IN_COMBAT = "You can't do that while in combat"

local Region = {}
local RegionMT = { __index = Region }

local function Log(self, name, ...)
    local entry = table.pack(...)
    entry.name = name
    self._log[#self._log + 1] = entry
end

local function NewRegion(kind, parent, layer, sublevel)
    local r = setmetatable({
        _kind = kind, _parent = parent, _log = {}, _alpha = 1, _points = {}, _shown = true,
        _level = parent and (parent._level or 0) + 1 or 1, _regions = {}, _children = {}, _scripts = {},
        _layer = layer, _sub = sublevel, _mouse = true, _states = {},
    }, RegionMT)
    if parent then
        local list = (kind == "Texture" or kind == "FontString") and parent._regions or parent._children
        list[#list + 1] = r
    end
    return r
end

function Region:IsObjectType(t)
    if t == "Frame" then return self._kind ~= "Texture" and self._kind ~= "FontString" end
    return self._kind == t
end
function Region:GetObjectType() return self._kind end
function Region:IsForbidden() return self._forbidden == true end
function Region:GetParent() return self._parent end
function Region:SetTexture(path, wh, wv)
    Log(self, "SetTexture", path, wh, wv)
    self._tex = path
    return self._texOk ~= false
end
function Region:GetTexture() return self._tex end
function Region:SetTexCoord(...) Log(self, "SetTexCoord", ...) self._coords = { ... } end
function Region:SetSize(w, h) Log(self, "SetSize", w, h) self._w, self._h = w, h end
function Region:SetWidth(w) Log(self, "SetWidth", w) self._w = w end
function Region:SetHeight(h) Log(self, "SetHeight", h) self._h = h end
function Region:GetWidth() return self._w or 0 end
function Region:GetHeight() return self._h or 0 end
function Region:ClearAllPoints() Log(self, "ClearAllPoints") self._points = {} end
function Region:SetPoint(point, rel, relPoint, x, y)
    Log(self, "SetPoint", point, rel, relPoint, x, y)
    self._points[#self._points + 1] = { point, rel, relPoint, x, y }
end
function Region:SetAllPoints(rel)
    Log(self, "SetAllPoints", rel)
    self._points = { { "ALL", rel } }
end
function Region:GetNumPoints() return #self._points end
function Region:GetPoint(i) local p = self._points[i] if p then return p[1], p[2], p[3], p[4], p[5] end end
function Region:SetDrawLayer(...) Log(self, "SetDrawLayer", ...) self._layer, self._sub = ... end
function Region:GetDrawLayer() return self._layer, self._sub end
function Region:SetBlendMode(mode) Log(self, "SetBlendMode", mode) self._blend = mode end
function Region:SetVertexColor(...) Log(self, "SetVertexColor", ...) self._vertex = { ... } end
function Region:GetVertexColor() local v = self._vertex or { 1, 1, 1, 1 } return v[1], v[2], v[3], v[4] end
function Region:SetDesaturated(on) Log(self, "SetDesaturated", on) self._desat = on end
function Region:SetAlpha(a) Log(self, "SetAlpha", a) self._alpha = a end
function Region:GetAlpha() return self._alpha end
function Region:Show() Log(self, "Show") self._shown = true end
function Region:Hide() Log(self, "Hide") self._shown = false end
function Region:IsShown() return self._shown end
function Region:SetShown(on) if on then self:Show() else self:Hide() end end
function Region:SetAtlas(atlas) Log(self, "SetAtlas", atlas) self._atlas = atlas end
function Region:GetAtlas() return self._atlas end
function Region:SetHorizTile(on) Log(self, "SetHorizTile", on) end
function Region:SetVertTile(on) Log(self, "SetVertTile", on) end
function Region:SetText(t) Log(self, "SetText", t) self._text = t end
function Region:GetText() return self._text end
function Region:SetFontObject(f) Log(self, "SetFontObject", f) self._font = f end
function Region:CreateTexture(_, layer, _, sublevel)
    local tex = NewRegion("Texture", self, layer, sublevel)
    Log(self, "CreateTexture", layer, sublevel)
    return tex
end
function Region:CreateFontString(_, layer, font)
    local fs = NewRegion("FontString", self, layer)
    fs._font = font
    Log(self, "CreateFontString", layer, font)
    return fs
end
function Region:GetRegions() return table.unpack(self._regions) end
function Region:GetChildren() return table.unpack(self._children) end
function Region:EnableMouse(on) Log(self, "EnableMouse", on) self._mouse = on end
function Region:IsMouseEnabled() return self._mouse end
function Region:SetFrameLevel(l) Log(self, "SetFrameLevel", l) self._level = l end
function Region:GetFrameLevel() return self._level end
function Region:SetScript(name, fn) Log(self, "SetScript", name, fn) self._scripts[name] = fn end
function Region:GetScript(name) return self._scripts[name] end
function Region:SetHitRectInsets(...) Log(self, "SetHitRectInsets", ...) end
function Region:SetMovable(on) Log(self, "SetMovable", on) end
function Region:RegisterForDrag(b) Log(self, "RegisterForDrag", b) end
function Region:SetClampedToScreen(on) Log(self, "SetClampedToScreen", on) end
function Region:StartMoving() end
-- _dropAnchors: the client leaving a frame others hang on with no anchor after a drag.
function Region:StopMovingOrSizing()
    Log(self, "StopMovingOrSizing")
    if self._dropAnchors then self._points = {} end
end
function Region:GetNumPoints() return #self._points end
function Region:GetLeft() return self._left end
function Region:GetTop() return self._top end
function Region:SetStatusBarTexture(path) Log(self, "SetStatusBarTexture", path) end
function Region:RegisterEvent(e) Log(self, "RegisterEvent", e) end
function Region:RegisterUnitEvent(e) Log(self, "RegisterUnitEvent", e) end

-- Button state textures, made on first set as the client does.
for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight", "Checked", "DisabledChecked" }) do
    Region["Set" .. state .. "Texture"] = function(self, path)
        Log(self, "Set" .. state .. "Texture", path)
        local tex = self._states[state]
        if not tex then
            tex = NewRegion("Texture", self)
            self._states[state] = tex
        end
        tex:SetTexture(path)
    end
    Region["Get" .. state .. "Texture"] = function(self) return self._states[state] end
end

local Backdrop = {}
function Backdrop:SetBackdrop(info) Log(self, "SetBackdrop", info) self.backdropInfo = info end
function Backdrop:SetBackdropColor(...) Log(self, "SetBackdropColor", ...) self._bg = { ... } end
function Backdrop:GetBackdropColor() local c = self._bg or { 1, 1, 1, 1 } return c[1], c[2], c[3], c[4] end
function Backdrop:SetBackdropBorderColor(...) Log(self, "SetBackdropBorderColor", ...) end

function CreateFrame(kind, _, parent, template)
    local frame = NewRegion(kind or "Frame", parent)
    frame._template = template
    if type(template) == "string" and template:find("BackdropTemplate", 1, true) then
        for k, v in pairs(Backdrop) do frame[k] = v end
    end
    return frame
end

UIParent = CreateFrame("Frame")

local tipCalls = {}
GameTooltip = {}
function GameTooltip:SetOwner(owner, anchor) tipCalls[#tipCalls + 1] = { "SetOwner", owner, anchor } end
function GameTooltip:SetText(...) tipCalls[#tipCalls + 1] = table.pack("SetText", ...) end
function GameTooltip:AddLine(...) tipCalls[#tipCalls + 1] = table.pack("AddLine", ...) end
function GameTooltip:Show() tipCalls[#tipCalls + 1] = { "Show" } end
function GameTooltip:Hide() tipCalls[#tipCalls + 1] = { "Hide" } end

local errorLines = {}
UIErrorsFrame = { AddMessage = function(_, ...) errorLines[#errorLines + 1] = table.pack(...) end }

------------------------------------------------------------------ the addon

local ns = { db = { bronzeTheme = false } }
function ns.RegisterModule() end

local function Load(path)
    local chunk, err = loadfile(ROOT .. "/" .. path)
    if not chunk then error(err) end
    chunk("ClassicUIForever", ns)
end

Load("Core/Util.lua")
Load("Core/Scheduler.lua")
Load("Core/Setters.lua")
Load("Art/ThemeArt.lua")
Load("Art/TextureData.lua")
Load("Art/Textures.lua")
Load("Art/Bronze.lua")
-- The helpers load before Skin.lua, so nothing of Skin's may be needed at load.
Load("UI/Dress.lua")
Load("UI/Dialogs.lua")

-- Skin.lua's OwnTexture, as it is.
function ns.OwnTexture(frame, key, layer, sublevel)
    frame.fcui = frame.fcui or {}
    local tex = frame.fcui[key]
    if not tex then
        tex = frame:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
        frame.fcui[key] = tex
    end
    return tex
end
local skinnedClose = {}
function ns.SkinCloseButton(button, keep) skinnedClose[#skinnedClose + 1] = { button, keep } end

------------------------------------------------------------------ the harness

local passed, failed = 0, 0
local function Check(cond, msg)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. msg .. "  (" .. debug.traceback("", 2):match("\n[^\n]*\n%s*([^\n]*)") .. ")")
    end
end

local function Names(r)
    local out = {}
    for i, e in ipairs(r._log) do out[i] = e.name end
    return table.concat(out, ",")
end

local function Calls(r, name)
    local out = {}
    for _, e in ipairs(r._log) do if e.name == name then out[#out + 1] = e end end
    return out
end

local function Same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

local function Near(a, b) return math.abs(a - b) < 1e-9 end

local function Test(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        failed = failed + 1
        print("ERROR in " .. name .. ": " .. tostring(err))
    end
end

------------------------------------------------------------------ ns.Dress

Test("Dress basic order", function()
    local frame = CreateFrame("Frame")
    local tex = frame:CreateTexture(nil, "ARTWORK")
    local SPEC = { coords = { 1, 0.09375, 0, 0.78125 }, w = 232, h = 100, point = "TOPLEFT", x = -19, y = -4, layer = "BORDER" }
    local got, ok = ns.Dress(tex, "targetingFrame", SPEC, frame)
    Check(got == tex and ok == true, "returns tex, ok")
    -- METAL key: SetTex tints it (theme off: desaturated false, white).
    Check(Names(tex) == "SetTexture,SetDesaturated,SetVertexColor,SetTexCoord,SetSize,ClearAllPoints,SetPoint,SetDrawLayer",
        "order was " .. Names(tex))
    Check(tex._tex == ns.TexPath("targetingFrame"), "key path")
    Check(Same(tex._coords, { 1, 0.09375, 0, 0.78125 }), "coords")
    local p = tex._points[1]
    Check(p[1] == "TOPLEFT" and p[2] == frame and p[3] == "TOPLEFT" and p[4] == -19 and p[5] == -4, "point")
    local layer = Calls(tex, "SetDrawLayer")[1]
    Check(layer[1] == "BORDER" and layer.n == 1, "layer without sublevel passes one argument")
end)

Test("Dress overrides and partial size", function()
    local frame = CreateFrame("Frame")
    local tex = frame:CreateTexture()
    local coords = {}
    coords[1], coords[2], coords[3], coords[4] = 0.25, 0.5, 0.1, 0.2
    ns.Dress(tex, "barBody", { point = "BOTTOMLEFT", show = true, coords = { 0, 1, 0, 1 } }, frame, 12, 3, 40, 43, coords)
    Check(Same(tex._coords, { 0.25, 0.5, 0.1, 0.2 }), "coords override")
    Check(tex._w == 40 and tex._h == 43, "size override")
    local p = tex._points[1]
    Check(p[4] == 12 and p[5] == 3 and p[3] == "BOTTOMLEFT", "x, y override, relPoint defaults to point")
    Check(tex._shown and Calls(tex, "Show")[1] ~= nil, "shown")
    local t2 = frame:CreateTexture()
    ns.Dress(t2, nil, { h = 56 })
    Check(Names(t2) == "SetHeight", "height only, no art: " .. Names(t2))
    local t3 = frame:CreateTexture()
    ns.Dress(t3, nil, { w = 31 })
    Check(Names(t3) == "SetWidth", "width only")
    Check(ns.Dress(nil, "barBody", {}) == nil, "nil texture is a no-op")
end)

Test("Dress tint share, vertex after tint, hide, alpha", function()
    ns.db.bronzeTheme = true
    local frame = CreateFrame("Frame")
    local tex = frame:CreateTexture()
    ns.Dress(tex, "barBody", { tint = 0.9, show = false, alpha = 0.6 })
    local v = tex._vertex
    Check(Near(v[1], 1 + (0.9 - 1) * 0.9) and Near(v[3], 1 + (0.32 - 1) * 0.9), "soft bronze share")
    Check(tex._desat == true, "desaturated under the theme")
    Check(tex._shown == false and tex._alpha == 0.6, "hidden, alpha")
    local bg = frame:CreateTexture()
    ns.Dress(bg, "levelBackground", { w = 100, h = 19, vertex = { 0, 0, 0 }, show = false })
    Check(Same(bg._vertex, { 0, 0, 0 }), "vertex colour wins over any tint")
    local vc = Calls(bg, "SetVertexColor")
    Check(vc[#vc].n == 3, "three-value vertex passes three arguments")
    local full = frame:CreateTexture()
    ns.Dress(full, "barBody", { tint = true })
    Check(Near(full._vertex[1], 0.9), "tint = true is the full share")
    ns.db.bronzeTheme = false
end)

Test("Themes: dark tint, a copy folder per theme, the look rule", function()
    ns.db.bronzeTheme, ns.db.themeDark = true, true
    local frame = CreateFrame("Frame")
    local tex = frame:CreateTexture()
    ns.Dress(tex, "barBody", { tint = true })
    Check(Near(tex._vertex[1], 0.38) and Near(tex._vertex[3], 0.40), "dark tint")
    local BORDER = "Interface/DialogFrame/UI-DialogBox-Border"
    local copy = ns.BronzeCopy(BORDER)
    Check(copy ~= nil and copy:find("dark", 1, true) ~= nil, "dark copy: " .. tostring(copy))
    Check(ns.ThemeLook(true) == "themed" and ns.ThemeLook() == "themed", "dark keeps the 1.x shapes everywhere")
    ns.db.themeDark = false
    copy = ns.BronzeCopy(BORDER)
    Check(copy ~= nil and copy:find("bronze", 1, true) ~= nil, "bronze copy: " .. tostring(copy))
    Check(ns.ThemeLook(true) == "client", "bronze tooltips and menus are the client's")
    ns.db.bronzeTheme = false
    Check(ns.ThemeLook(true) == "classic" and ns.ThemeName() == nil, "off")
    Check(ns.BronzeCopy(BORDER) ~= nil, "off still answers whether a copy exists")
end)

Test("Dress fill, keep, second point, file and raw", function()
    local frame = CreateFrame("Frame")
    local other = CreateFrame("Frame")
    local tex = frame:CreateTexture()
    ns.Dress(tex, "clockBackground", { fill = true, keep = true, coords = { 0.015625, 0.8125, 0.015625, 0.390625 } }, other)
    Check(#Calls(tex, "ClearAllPoints") == 0 and tex._points[1][2] == other, "fill kept, on rel")
    local ring = frame:CreateTexture()
    ns.Dress(ring, "minimapBorder", { fill = true })
    Check(Calls(ring, "ClearAllPoints")[1] and ring._points[1][2] == frame, "fill defaults to the parent")
    local border = frame:CreateTexture()
    ns.Dress(border, "castBorderSmall", { h = 56, point = "TOPLEFT", x = -23, y = 23, point2 = "TOPRIGHT", x2 = 23, y2 = 23 }, frame)
    Check(#border._points == 2 and border._points[2][1] == "TOPRIGHT" and border._points[2][4] == 23, "second point")
    local f = frame:CreateTexture()
    ns.Dress(f, "Interface\\DialogFrame\\UI-DialogBox-Header", { set = "file" })
    Check(f._tex == "Interface\\DialogFrame\\UI-DialogBox-Header", "file path set")
    local r = frame:CreateTexture()
    ns.Dress(r, "Interface\\Common\\Common-Input-Border", { set = "raw" })
    Check(Names(r) == "SetTexture", "raw path: one plain SetTexture")
    local eight = frame:CreateTexture()
    ns.Dress(eight, nil, { coords = { 0.2578125, 0.9375, 0.3671875, 0.9375, 0.2578125, 0.0625, 0.3671875, 0.0625 } })
    Check(#eight._coords == 8, "eight coordinates")
    local missing = frame:CreateTexture()
    missing._texOk = false
    local _, ok = ns.Dress(missing, "Interface\\Nope", { set = "raw" })
    Check(ok == false, "a failed raw set reports false")
end)

Test("DressNew own and fresh", function()
    local frame = CreateFrame("Frame")
    local SPEC = { own = "border", layer = "OVERLAY", sublevel = 2, w = 52, h = 52, point = "TOPLEFT", x = 1, y = -1 }
    local a = ns.DressNew(frame, "trackingBorder", SPEC)
    local b = ns.DressNew(frame, "trackingBorder", SPEC)
    Check(a == b and frame.fcui.border == a, "own texture reused")
    Check(#Calls(a, "SetDrawLayer") == 0, "own texture keeps its creation layer")
    Check(a._layer == "OVERLAY" and a._sub == 2, "made on the spec's layer")
    Check(a._points[1][2] == frame, "rel defaults to the parent")
    local c = ns.DressNew(frame, "gryphonIcon", { layer = "ARTWORK", w = 24, h = 24, point = "TOPLEFT", x = 5, y = -5 })
    Check(c ~= a and c._layer == "ARTWORK" and c._sub == 0, "fresh texture, sublevel 0")
end)

------------------------------------------------------------------ ns.DressPieces

Test("DressPieces made, chained and fields", function()
    local frame = CreateFrame("Frame")
    local QUARTERS = {
        { key = "charGeneralTopLeft", layer = "BACKGROUND", sublevel = -2, w = 256, h = 256, point = "TOPLEFT" },
        { key = "charGeneralTopRight", layer = "BACKGROUND", sublevel = -2, w = 128, h = 256, point = "TOPLEFT", x = 256 },
    }
    local list = ns.DressPieces(frame, QUARTERS, nil, true)
    Check(#list == 2 and list[2]._points[1][4] == 256 and list[1]._sub == -2, "made on owner, out list")
    local PILL = {
        { key = "Interface\\X", set = "raw", layer = "BACKGROUND", w = 12, h = 28, coords = { 0.90625, 1, 0, 1 }, point = "TOPRIGHT", y = 3 },
        { key = "Interface\\X", set = "raw", layer = "BACKGROUND", w = 186, h = 28, coords = { 0.09375, 0.90625, 0, 1 }, point = "RIGHT", relPoint = "LEFT", chain = true },
        { key = "Interface\\X", set = "raw", layer = "BACKGROUND", w = 12, h = 28, coords = { 0, 0.09375, 0, 1 }, point = "RIGHT", relPoint = "LEFT", chain = true },
    }
    local pill = ns.DressPieces(frame, PILL, nil, {})
    Check(pill[2]._points[1][2] == pill[1] and pill[3]._points[1][2] == pill[2], "chained right to left")
    Check(pill[1]._points[1][2] == frame and pill[1]._points[1][5] == 3, "first on rel")
    local tab = CreateFrame("Button")
    tab.Left = tab:CreateTexture()
    tab.Middle = tab:CreateTexture()
    tab.Middle:SetPoint("LEFT", tab, "LEFT", 5, 0)
    tab.Middle._log = {}
    local TAB = {
        { field = "Left", key = "tabInactive", coords = { 0, 0.15625, 0, 1 }, w = 20, h = 32, horizTile = false, point = "TOPLEFT", y = -4 },
        { field = "Middle", key = "tabInactive", coords = { 0.15625, 0.84375, 0, 1 }, w = 88, h = 32, horizTile = false },
        { field = "Right", key = "tabInactive", w = 20, h = 32, point = "TOPRIGHT", y = -4 },
    }
    Check(ns.DressPieces(tab, TAB) == nil, "no out, nothing returned")
    Check(tab.Left._points[1][5] == -4 and tab.Left._points[1][2] == tab, "field piece anchored on the owner")
    Check(#Calls(tab.Middle, "ClearAllPoints") == 0 and #tab.Middle._points == 1, "middle keeps the client's anchors")
    Check(Calls(tab.Middle, "SetHorizTile")[1][1] == false, "tiling off")
end)

------------------------------------------------------------------ ns.ThreeSlice

Test("ThreeSlice spanning caps (drop down)", function()
    local dd = CreateFrame("Frame")
    local DD = { own = "dd", layer = "BACKGROUND", sublevel = 0, set = "file", key = "Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame",
        coords = { { 0, 0.1953125, 0, 1 }, { 0.1953125, 0.8046875, 0, 1 }, { 0.8046875, 1, 0, 1 } }, cap = 25, show = true }
    local l, m, r = ns.ThreeSlice(dd, nil, DD, dd, 17, 17)
    Check(dd.fcui.ddLeft == l and dd.fcui.ddMiddle == m and dd.fcui.ddRight == r, "own keys match the old ones")
    Check(Calls(dd, "CreateTexture")[2] and dd._regions[2] == r and dd._regions[3] == m, "made left, right, middle")
    Check(l._w == 25 and l._points[1][1] == "TOPLEFT" and l._points[1][4] == -17 and l._points[1][5] == 17, "left top")
    Check(l._points[2][1] == "BOTTOMLEFT" and l._points[2][4] == -17 and l._points[2][5] == -17, "left bottom")
    Check(r._points[1][1] == "TOPRIGHT" and r._points[1][4] == 17 and r._points[2][5] == -17, "right")
    Check(m._points[1][2] == l and m._points[1][3] == "TOPRIGHT" and m._points[2][2] == r and m._points[2][3] == "BOTTOMLEFT", "middle corner to corner")
    Check(Same(m._coords, { 0.1953125, 0.8046875, 0, 1 }), "middle coords")
    Check(l._shown and #Calls(m, "Show") == 1, "shown")
    local l2 = ns.ThreeSlice(dd, nil, DD, dd, 17, 17)
    Check(l2 == l, "re-run reuses")
end)

Test("ThreeSlice edge caps (minimal tab, foot tab)", function()
    local tab = CreateFrame("Button")
    local MT = { own = "mt", layer = "BACKGROUND", cap = 20, height = 32, edge = "BOTTOM", middle = "edge", show = true,
        coords = { { 0, 0.15625, 0, 1 }, { 0.15625, 0.84375, 0, 1 }, { 0.84375, 1, 0, 1 } } }
    local l, m, r = ns.ThreeSlice(tab, "optionsTabActive", MT, tab)
    Check(l._tex == ns.TexPath("optionsTabActive"), "key argument")
    Check(l._w == 20 and l._h == 32 and l._points[1][1] == "BOTTOMLEFT" and l._points[1][5] == 0, "cap on the edge")
    Check(r._points[1][1] == "BOTTOMRIGHT", "right cap")
    Check(m._h == 32 and m._points[1][1] == "BOTTOMLEFT" and m._points[1][3] == "BOTTOMRIGHT" and m._points[2][3] == "BOTTOMLEFT", "middle along the edge")
    local foot = CreateFrame("Button")
    local OFF = { layer = "BACKGROUND", key = "tabInactive", cap = 20, height = 32, middle = "edge",
        coords = { { 0, 0.15625, 0, 1 }, { 0.15625, 0.84375, 0, 1 }, { 0.84375, 1, 0, 1 } } }
    local fl, fm = ns.ThreeSlice(foot, nil, OFF, foot, 0, -4)
    Check(fl._points[1][1] == "TOPLEFT" and fl._points[1][5] == -4, "edge defaults to TOP, y from oy")
    Check(fm._points[1][1] == "TOPLEFT" and fm._points[2][1] == "TOPRIGHT" and fm._points[2][3] == "TOPLEFT", "foot tab middle")
    local header = CreateFrame("Button")
    local COL = { layer = "BACKGROUND", set = "raw", key = "Interface\\FriendsFrame\\WhoFrame-ColumnTabs", capL = 5, capR = 4, height = 20,
        coords = { { 0, 0.078125, 0, 0.625 }, { 0.078125, 0.90625, 0, 0.625 }, { 0.90625, 0.96875, 0, 0.625 } } }
    local cl, cm, cr = ns.ThreeSlice(header, nil, COL)
    Check(cl._w == 5 and cr._w == 4 and cm._points[2][1] == "BOTTOMRIGHT", "own cap widths, spanning middle by default")
end)

Test("ThreeSlice fields with a piece missing", function()
    local tab = CreateFrame("Button")
    tab.LeftActive = tab:CreateTexture()
    tab.MiddleActive = tab:CreateTexture()
    local TOP = { fields = { "LeftActive", "MiddleActive", "RightActive" }, key = "tabActive", cap = 20, height = 35, edge = "BOTTOM",
        middle = "edge", midW = 88, horizTile = false,
        coords = { { 0, 0.15625, 0.546875, 0 }, { 0.15625, 0.84375, 0.546875, 0 }, { 0.84375, 1, 0.546875, 0 } } }
    local l, m, r = ns.ThreeSlice(tab, nil, TOP)
    Check(r == nil and l._points[1][1] == "BOTTOMLEFT", "left dressed")
    Check(m._w == 88 and m._h == 35 and #m._points == 0 and #Calls(m, "ClearAllPoints") == 0, "middle sized, not re-anchored")
end)

------------------------------------------------------------------ ns.TileTex

Test("TileTex", function()
    local frame = CreateFrame("Frame")
    local stone = ns.TileTex(frame:CreateTexture(), "rockBg", { coords = { 0, 1, 0, 1 }, shade = { 1.25, 1.2, 1.1 } })
    Check(Names(stone) == "SetTexture,SetDesaturated,SetVertexColor,SetHorizTile,SetVertTile,SetTexCoord,SetVertexColor", "order " .. Names(stone))
    local st = Calls(stone, "SetTexture")[1]
    Check(st[1] == ns.TexPath("rockBg") and st[2] == "REPEAT" and st[3] == "REPEAT", "tiled both ways")
    Check(Same(stone._vertex, { 1.25, 1.2, 1.1 }), "shade after the tint")
    local streaks = ns.TileTex(frame:CreateTexture(), "frameSheet", { vert = false, coords = { 0, 1, 0.671875, 0.9609375 } })
    Check(Calls(streaks, "SetTexture")[1][3] == "CLAMP" and #Calls(streaks, "SetVertTile") == 0, "along only")
    local floor = ns.TileTex(frame:CreateTexture(), "bankFloor", { tint = false })
    Check(#Calls(floor, "SetDesaturated") == 0, "no tint")
    local marble = ns.TileTex(frame:CreateTexture(), "marbleBg", nil, 0.9)
    Check(Same(marble._vertex, { 0.9, 0.9, 0.9 }), "number shade argument")
end)

------------------------------------------------------------------ ns.DressStates

Test("DressStates keys, coords, fill, add", function()
    local b = CreateFrame("Button")
    local CLOSE = { size = { 32, 32 }, coords = { 0, 1, 0, 1 }, fill = true, add = true }
    ns.DressStates(b, "closeUp", "closeDown", "closeDisabled", "closeHighlight", CLOSE)
    Check(b._w == 32 and b:GetNormalTexture()._tex == ns.TexPath("closeUp"), "size, normal")
    Check(b:GetHighlightTexture()._blend == "ADD" and b:GetNormalTexture()._blend == nil, "ADD on the highlight only")
    Check(b:GetDisabledTexture()._points[1][1] == "ALL", "filled")
    local arrow = CreateFrame("Button")
    ns.DressStates(arrow, "scrollUpButtonUp", "scrollUpButtonDown", "scrollUpButtonDisabled", "scrollUpButtonHighlight",
        { coords = { 0.25, 0.75, 0.25, 0.75 }, add = true })
    Check(#arrow:GetPushedTexture()._points == 0 and Same(arrow:GetPushedTexture()._coords, { 0.25, 0.75, 0.25, 0.75 }), "coords, not anchored")
    local only = CreateFrame("Button")
    ns.DressStates(only, nil, "slotPushed", nil, "highlight", { add = true })
    Check(only:GetNormalTexture() == nil and only:GetPushedTexture() ~= nil, "nil state left")
    local skill = CreateFrame("CheckButton")
    ns.DressStates(skill, nil, nil, nil, "highlight", { checked = "checked", add = { Highlight = true, Checked = true },
        states = { "Highlight", "Checked" } })
    Check(skill:GetCheckedTexture()._blend == "ADD" and skill:GetHighlightTexture()._blend == "ADD", "ADD by state table")
end)

Test("DressStates per state, file, raw, tex, center, hit", function()
    local cal = CreateFrame("Button")
    ns.DressStates(cal, "calendarButton", "calendarButton", nil, "zoomHighlight", {
        states = { "Normal", "Pushed", "Highlight" }, fill = true, add = true,
        coords = { Normal = { 0, 0.390625, 0, 0.78125 }, Pushed = { 0.5, 0.890625, 0, 0.78125 }, Highlight = { 0, 1, 0, 1 } },
        layer = { Normal = "BACKGROUND", Pushed = "BACKGROUND" } })
    Check(cal:GetPushedTexture()._coords[1] == 0.5 and cal:GetPushedTexture()._layer == "BACKGROUND", "per-state coords and layer")
    Check(#Calls(cal:GetHighlightTexture(), "SetDrawLayer") == 0, "no layer where none given")
    local check = CreateFrame("CheckButton")
    local C = "Interface\\Buttons\\UI-CheckBox-"
    ns.DressStates(check, C .. "Up", C .. "Down", nil, C .. "Highlight", { set = "file", highlightSet = "raw",
        checked = C .. "Check", disabledChecked = C .. "Check-Disabled", coords = { 0, 1, 0, 1 }, fill = true, add = true,
        states = { "Normal", "Pushed", "Highlight", "Checked", "DisabledChecked" } })
    Check(check:GetCheckedTexture()._tex == C .. "Check" and check:GetDisabledCheckedTexture()._points[1][1] == "ALL", "checked states")
    Check(#Calls(check, "SetNormalTexture") == 1 and #Calls(check, "SetHighlightTexture") == 1, "one set each")
    local ring = CreateFrame("Button")
    ring:SetNormalTexture("x")
    ring:SetHighlightTexture("y")
    ns.DressStates(ring, "keyRingUp", "keyRingDown", nil, "keyRingHighlight", { set = "tex", coords = { 0, 0.5625, 0, 0.609375 },
        fill = true, alpha = 1, add = true, states = { "Normal", "Pushed", "Highlight" } })
    Check(ring:GetPushedTexture() == nil, "tex: a state the button lacks is not made")
    Check(ring:GetNormalTexture()._tex == ns.TexPath("keyRingUp") and ring:GetHighlightTexture()._alpha == 1, "tex set, alpha")
    local step = CreateFrame("Button")
    ns.DressStates(step, "Interface\\P-Up", nil, nil, "Interface\\H", { set = "file", highlightSet = "raw", center = { 26, 26 },
        add = true, hit = { 5, 5, 5, 5 } })
    local n = step:GetNormalTexture()
    Check(n._points[1][1] == "CENTER" and n._w == 26 and step:GetHighlightTexture()._blend == "ADD", "centered")
    Check(Calls(step, "SetHitRectInsets")[1][1] == 5, "hit insets")
    local menu = CreateFrame("Button")
    local P = "Interface\\Buttons\\UI-Panel-Button-"
    ns.DressStates(menu, P .. "Up", P .. "Down", P .. "Disabled", P .. "Highlight", { set = "file", highlightSet = "raw",
        coords = { 0, 0.625, 0, 0.6875 }, inset = { 0, -1, 0, 1 }, add = true })
    local mp = menu:GetPushedTexture()._points
    Check(mp[1][1] == "TOPLEFT" and mp[1][5] == -1 and mp[2][1] == "BOTTOMRIGHT" and mp[2][5] == 1, "inset anchors")
    local micro = CreateFrame("Button")
    micro:SetHighlightTexture("old")
    ns.DressStates(micro, "microSpellbookUp", "microSpellbookDown", "microSpellbookDisabled", "microHighlight",
        { highlightSet = "tex", add = true, alpha = { Highlight = 1 }, coords = { 0, 1, 22 / 64, 1 }, fill = true })
    Check(micro:GetHighlightTexture()._tex == ns.TexPath("microHighlight") and #Calls(micro:GetNormalTexture(), "SetAlpha") == 0,
        "micro highlight by tex, alpha on it alone")
end)

Test("DressStates raw rows: panel button, options box, gold bar", function()
    local P = ns.ART.PANEL_BUTTON
    local button = CreateFrame("Button")
    button:SetNormalTexture(P .. "Up")
    local PANEL_RAW = { set = "raw", coords = { 0, 0.625, 0, 0.6875 }, add = true }
    ns.DressStates(button, nil, P .. "Down", P .. "Disabled", P .. "Highlight", PANEL_RAW)
    Check(#Calls(button, "SetNormalTexture") == 1 and button:GetPushedTexture()._tex == P .. "Down", "raw sets, probe kept")
    Check(Names(button:GetDisabledTexture()) == "SetTexture,SetTexCoord", "raw: no bronze bookkeeping " .. Names(button:GetDisabledTexture()))
    Check(Same(button:GetNormalTexture()._coords, { 0, 0.625, 0, 0.6875 }) and button:GetHighlightTexture()._blend == "ADD", "coords on all, ADD")
    local C = ns.ART.CHECK
    local box = CreateFrame("CheckButton")
    ns.DressStates(box, C .. "Up", C .. "Down", nil, C .. "Highlight",
        { set = "raw", checked = C .. "Check", disabledChecked = C .. "Check-Disabled", add = true, hit = { 0, -110, 0, 0 } })
    Check(box:GetDisabledCheckedTexture()._tex == C .. "Check-Disabled" and box:GetCheckedTexture()._blend == nil, "checked states raw, no ADD")
    Check(#box:GetNormalTexture()._points == 0 and Calls(box, "SetHitRectInsets")[1][2] == -110, "client anchors, hit")
    local row = CreateFrame("Button")
    local GOLD_SEL = { set = "raw", layer = "BACKGROUND", fill = true, blend = "ADD", vertex = { 1, 0.82, 0, 1 },
        coords = { 0, 0.97, 0, 1 }, show = false }
    local sel = ns.DressNew(row, ns.ART.GOLD_BAR, GOLD_SEL)
    Check(sel._layer == "BACKGROUND" and sel._points[1][2] == row and sel._blend == "ADD" and sel._shown == false, "gold bar")
    Check(sel._vertex[2] == 0.82 and sel._vertex[4] == 1 and sel._tex == ns.ART.GOLD_BAR, "gold, raw path")
end)

Test("EachState", function()
    local b = CreateFrame("Button")
    b:SetNormalTexture("a")
    b:SetHighlightTexture("b")
    local seen = {}
    ns.EachState(b, ns.KEYS.STATES, function(tex, state, a1) seen[#seen + 1] = state .. a1 end, "!")
    Check(Same(seen, { "Normal!", "Highlight!" }), "existing states in list order")
end)

------------------------------------------------------------------ fades

Test("FadeKeys and EachKey", function()
    local owner = CreateFrame("Frame")
    owner.Left = owner:CreateTexture()
    owner.Middle = owner:CreateFontString()
    ns.FadeKeys(owner, ns.KEYS.LMR)
    Check(owner.Left._alpha == 0 and owner.Middle._alpha == 0, "fade, default 0, any region")
    ns.FadeKeys(owner, ns.KEYS.LMR, 1, { texture = true })
    Check(owner.Left._alpha == 1 and owner.Middle._alpha == 0, "textures only")
    owner.Left._log = {}
    ns.FadeKeys(owner, ns.KEYS.LMR, 1, { changed = true, texture = true })
    Check(#Calls(owner.Left, "SetAlpha") == 0, "unchanged alpha not written")
    owner.Left._alpha = SECRET
    ns.FadeKeys(owner, ns.KEYS.LMR, 1, { changed = true, texture = true })
    Check(owner.Left._alpha == 1, "a secret alpha is written over")
    owner.Left._alpha = 0.3499999940395355
    owner.Left._log = {}
    ns.FadeKeys(owner, ns.KEYS.LMR, 0.35, { changed = true, texture = true })
    Check(#Calls(owner.Left, "SetAlpha") == 0, "a float read back of the same alpha is not written")
    local bar = CreateFrame("StatusBar")
    bar.Spark = bar:CreateTexture()
    bar.Spark._atlas = "pip"
    ns.FadeKeys(bar, { "Spark", "Flash" }, 0, { clearAtlas = true, hide = true })
    Check(Names(bar.Spark) == "SetAtlas,SetAlpha,Hide" and bar.Spark._atlas == nil, "HideFx order")
    local lfg = CreateFrame("Frame")
    lfg.ListingTab = CreateFrame("Button", nil, lfg)
    ns.FadeKeys(lfg, { "ListingTab" }, 0, { changed = true, mouseOff = true })
    Check(lfg.ListingTab._alpha == 0 and lfg.ListingTab._mouse == false, "quiet tab")
    lfg.ListingTab._log = {}
    ns.FadeKeys(lfg, { "ListingTab" }, 0, { changed = true, mouseOff = true })
    Check(#lfg.ListingTab._log == 0, "second pass writes nothing")
    local got = {}
    ns.EachKey(owner, ns.KEYS.LMR, function(r, a) got[#got + 1] = a end, 7)
    Check(#got == 2 and got[1] == 7, "EachKey passes arguments")
    ns.FadeKeys(nil, ns.KEYS.LMR)
end)

Test("FadeTextures", function()
    local frame = CreateFrame("Frame")
    local a, b, c = frame:CreateTexture(), frame:CreateTexture(), frame:CreateTexture()
    local fs = frame:CreateFontString()
    ns.FadeTextures(frame, nil, nil, b)
    Check(a._alpha == 0 and b._alpha == 1 and c._alpha == 0 and fs._alpha == 1, "textures faded, skip kept, font left")
    ns.FadeTextures(frame, 1)
    Check(a._alpha == 1 and c._alpha == 1 and #Calls(fs, "SetAlpha") == 0, "unfade, fonts never touched")
    frame.fcui = { bg = c }
    ns.FadeTextures(frame, 0, { own = true })
    Check(a._alpha == 0 and c._alpha == 1, "own textures skipped")
    a._log = {}
    ns.FadeTextures(frame, 0, { changed = true, own = true })
    Check(#Calls(a, "SetAlpha") == 0, "changed skips equal")
    a._alpha = SECRET
    ns.FadeTextures(frame, 0, { changed = true, own = true })
    Check(a._alpha == 0, "changed writes over a secret alpha")
    a._alpha = 0.6000000238418579
    a._log = {}
    ns.FadeTextures(frame, 0.6, { changed = true, own = true })
    Check(#Calls(a, "SetAlpha") == 0, "changed takes the float read back as the same")
    local border = CreateFrame("Frame")
    local child = CreateFrame("Frame", nil, border)
    local slot = CreateFrame("Button", nil, border)
    slot.GetBagID = function() return 1 end
    local ct, st = child:CreateTexture(), slot:CreateTexture()
    ns.FadeTextures(border, 0, { children = true, skipChild = function(k) return k.GetBagID end })
    Check(ct._alpha == 0 and st._alpha == 1, "children, skip predicate")
    local forbidden = CreateFrame("Frame")
    local ft = forbidden:CreateTexture()
    forbidden._forbidden = true
    ns.FadeTextures(forbidden)
    Check(ft._alpha == 1, "a forbidden frame is not asked")
    ns.FadeTextures(nil)
end)

Test("FadeAtlas and EachTexture", function()
    local frame = CreateFrame("Frame")
    local circle, other, exact, secret = frame:CreateTexture(), frame:CreateTexture(), frame:CreateTexture(), frame:CreateTexture()
    circle._atlas = "UI-HUD-UnitFrame-SmallCircle"
    other._atlas = "portrait"
    exact._atlas = "bank-divider"
    secret._atlas = SECRET
    frame:CreateFontString()
    ns.FadeAtlas(frame, "smallcircle")
    Check(circle._alpha == 0 and other._alpha == 1 and secret._alpha == 1, "substring, case-insensitive")
    ns.FadeAtlas(frame, "bank-divider", true)
    Check(exact._alpha == 0, "exact")
    local hit
    ns.FadeAtlas(frame, "portrait", false, function(r) hit = r end)
    Check(hit == other and other._alpha == 1, "handed to fn")
    local n = 0
    ns.EachTexture(frame, function(_, x, y, z) if x == 1 and y == 2 and z == 3 then n = n + 1 end end, 1, 2, 3)
    Check(n == 4, "EachTexture visits textures with three arguments")
end)

------------------------------------------------------------------ small pieces

Test("OwnFrame", function()
    local parent = CreateFrame("Frame")
    parent._level = 5
    local holder, isNew = ns.OwnFrame(parent, "texts", 8, { fill = "once" })
    Check(isNew and parent.fcui.texts == holder and holder._mouse == false and holder._points[1][1] == "ALL", "made, deaf, filled once")
    holder._log = {}
    local again, isNew2 = ns.OwnFrame(parent, "texts", 8, { fill = "once" })
    Check(again == holder and not isNew2 and #Calls(holder, "SetAllPoints") == 0 and #Calls(holder, "SetFrameLevel") == 0, "level unchanged not written")
    Check(#Calls(holder, "Show") == 1, "shown every call")
    local host = ns.OwnFrame(parent, "host", nil, { fill = true })
    host._log = {}
    ns.OwnFrame(parent, "host", 6, { fill = true, show = false })
    Check(#Calls(host, "SetAllPoints") == 1 and host._level == 6 and #Calls(host, "Show") == 0, "fill every call, show false")
    host._level = SECRET
    host._log = {}
    ns.OwnFrame(parent, "host", 6, { show = false })
    Check(#Calls(host, "SetFrameLevel") == 1 and host._level == 6, "a secret level read back is written over")
    host._log = {}
    ns.OwnFrame(parent, "host", SECRET, { show = false })
    Check(#Calls(host, "SetFrameLevel") == 1, "a secret level asked for is written")
end)

Test("ApplyColor and StateTexture", function()
    local frame = CreateFrame("Frame")
    local tex = frame:CreateTexture()
    ns.ApplyColor(tex, "SetVertexColor", { 1, 0.82, 0 })
    ns.ApplyColor(tex, "SetVertexColor", { 1, 0.82, 0, 0.5 })
    local vc = Calls(tex, "SetVertexColor")
    Check(vc[1].n == 3 and vc[2].n == 4 and vc[2][4] == 0.5, "three or four arguments")
    local b = CreateFrame("CheckButton")
    b:SetCheckedTexture("x")
    Check(ns.StateTexture(b, "Checked") == b._states.Checked and ns.StateTexture(b, "Normal") == nil, "state texture or nil")
    Check(ns.StateTexture(frame, "Normal") == nil, "no getter, nil")
end)

Test("SetBarFill and SetCollapseIcon", function()
    local bar = CreateFrame("StatusBar")
    ns.SetBarFill(bar)
    Check(Calls(bar, "SetStatusBarTexture")[1][1] == ns.TexPath("statusBar"), "default fill")
    ns.SetBarFill(bar, "skillsBar")
    Check(Calls(bar, "SetStatusBarTexture")[2][1] == ns.TexPath("skillsBar"), "keyed fill")
    local icon = bar:CreateTexture()
    ns.SetCollapseIcon(icon, true)
    Check(icon._tex == ns.ART.PLUS, "plus when collapsed")
    ns.SetCollapseIcon(icon, nil)
    Check(icon._tex == ns.ART.MINUS, "minus when open")
end)

------------------------------------------------------------------ dialogs

Test("Backdrop", function()
    Check(ns.BACKDROP.DIALOG.insets.right == 12 and ns.BACKDROP.TIP16.insets.left == 4, "shared infos")
    local e = ns.DialogEdge(20)
    Check(e == ns.DialogEdge(20) and e.insets.top == 5 and e.bgFile == nil, "edge memo, quarter inset")
    Check(ns.Backdrop(CreateFrame("Frame"), ns.BACKDROP.DIALOG) == false, "no backdrop method")
    local f = CreateFrame("Frame", nil, nil, "BackdropTemplate")
    Check(ns.Backdrop(f, ns.BACKDROP.DIALOG), "takes it")
    Check(Names(f) == "SetBackdrop,SetBackdropBorderColor", "bronze border after the set: " .. Names(f))
    local s = CreateFrame("Frame", nil, nil, "BackdropTemplate")
    ns.Backdrop(s, ns.BACKDROP.TIP14, { bronze = false, bg = { 0, 0, 0, 0.7 }, border = { 0.6, 0.6, 0.6 } })
    Check(Names(s) == "SetBackdrop,SetBackdropColor,SetBackdropBorderColor", "silver: " .. Names(s))
    Check(Calls(s, "SetBackdropBorderColor")[1].n == 3, "three-value colour")
    local i = CreateFrame("Frame", nil, nil, "BackdropTemplate")
    ns.Backdrop(i, ns.BACKDROP.TIP16, { bg = { 0.34, 0.32, 0.30, 0.55 }, bgFirst = true, base = { 0.6, 0.6, 0.6, 1 } })
    Check(Names(i) == "SetBackdrop,SetBackdropColor,SetBackdropBorderColor", "fill first: " .. Names(i))
    Check(Calls(i, "SetBackdropBorderColor")[1][1] == 0.6, "border base")
    local d = CreateFrame("Frame", nil, nil, "BackdropTemplate")
    ns.Backdrop(d, ns.BACKDROP.DIALOG_DARK, { bg = { 1, 1, 1, 1 }, border = { 1, 1, 1, 1 } })
    Check(Names(d) == "SetBackdrop,SetBackdropBorderColor,SetBackdropColor,SetBackdropBorderColor", "drop list: " .. Names(d))
end)

Test("DialogBacking and DialogHeader", function()
    local menu = CreateFrame("Frame")
    menu._level = 9
    local backing = ns.DialogBacking(menu, nil, { bg = { 1, 1, 1, 1 } })
    Check(backing._parent == menu and backing._points[1][2] == menu and backing._level == 9, "backing over host at its level")
    Check(backing.backdropInfo == ns.BACKDROP.DIALOG, "default info")
    local pane = CreateFrame("Frame")
    local plate, title = ns.DialogHeader(pane, "Equipment Manager", { width = 300 })
    Check(plate._tex == ns.ART.DIALOG_HEADER and plate._w == 300 and plate._h == 64, "plate")
    Check(plate._points[1][1] == "TOP" and plate._points[1][2] == pane and plate._points[1][5] == 12, "plate on top")
    Check(title._parent == pane and title._font == "GameFontNormal" and title._points[1][5] == -14 and title._text == "Equipment Manager", "title")
    local header = CreateFrame("Frame")
    header.Text = header:CreateFontString()
    header.Text:SetPoint("CENTER", header, "CENTER", 0, 0)
    local HOW = { own = "plate", layer = "BACKGROUND", restyle = true, fontObject = "GoldFont", keepTitle = true }
    local p1, t1 = ns.DialogHeader(menu, nil, HOW, header, header.Text)
    local p2 = ns.DialogHeader(menu, "Main Menu", HOW, header, header.Text)
    Check(p1 == p2 and header.fcui.plate == p1 and p1._w == 256 and p1._points[1][2] == menu, "own plate on owner, on host")
    Check(t1 == header.Text and header.Text._font == "GoldFont" and header.Text._points[1][1] == "CENTER", "restyled, anchor kept")
    Check(header.Text._text == "Main Menu" and #Calls(header.Text, "SetText") == 1, "nil text not written")
    local panel = CreateFrame("Frame")
    local before = #panel._regions
    local p3, t3 = ns.DialogHeader(panel, nil, { own = "plate", restyle = true }, nil, nil)
    Check(p3 and t3 == nil and #panel._regions == before + 1, "restyle with no font makes none")
end)

Test("MakeDraggable, DialogClose, SayNotInCombat", function()
    local f = CreateFrame("Frame")
    ns.MakeDraggable(f)
    Check(f._scripts.OnDragStart == f.StartMoving and f._scripts.OnDragStop ~= nil, "drag scripts")
    Check(#Calls(f, "SetClampedToScreen") == 1 and f._mouse == true, "clamped, mouse")
    f._scripts.OnDragStop(f)
    Check(#Calls(f, "StopMovingOrSizing") == 1, "plain stop")
    local g = CreateFrame("Frame")
    local stoppedFirst
    local function SavePos(self) stoppedFirst = self == g and #Calls(g, "StopMovingOrSizing") == 1 end
    ns.MakeDraggable(g, SavePos)
    Check(g._scripts.OnDragStop == f._scripts.OnDragStop and #Calls(g, "SetClampedToScreen") == 1, "one shared stop, clamped")
    g._scripts.OnDragStop(g)
    Check(stoppedFirst == true, "onStop runs after the move has stopped")
    local h = CreateFrame("Frame")
    ns.MakeDraggable(h)
    h:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    h._left, h._top, h._dropAnchors = 120, 540, true
    h._scripts.OnDragStop(h)
    local p = h._points[1]
    Check(#h._points == 1 and p[1] == "TOPLEFT" and p[3] == "BOTTOMLEFT" and p[4] == 120 and p[5] == 540,
        "a drag that left no anchor is pinned where it was drawn")
    local onClick = function() end
    local close = ns.DialogClose(f, onClick)
    Check(close._template == "UIPanelCloseButton" and close._points[1][4] == -6 and close._scripts.OnClick == onClick, "close")
    Check(skinnedClose[#skinnedClose][1] == close and skinnedClose[#skinnedClose][2] == true, "skinned in place")
    ns.SayNotInCombat()
    local line = errorLines[#errorLines]
    Check(line[1] == ERR_NOT_IN_COMBAT and line[2] == 1 and line[3] == 0.1 and line[4] == 0.1, "red line")
end)

Test("Popup and ReloadPopup", function()
    local def = ns.Popup("FCUI_TEST", { text = "x", button1 = "OK", showAlert = 1, preferredIndex = false, timeout = 5 })
    Check(StaticPopupDialogs.FCUI_TEST == def and def.whileDead == 1 and def.hideOnEscape == 1, "defaults")
    Check(def.preferredIndex == nil and def.timeout == 5 and def.showAlert == 1, "false removes, set kept")
    local reload = ns.ReloadPopup("FCUI_TEST_RELOAD", "text %s")
    Check(reload.button1 == "Reload now" and reload.button2 == "Later" and reload.preferredIndex == 3, "reload labels")
    local core = ns.ReloadPopup("FCUI_TEST_CORE", "t", "Reload Now", "Later!")
    Check(core.button1 == "Reload Now" and core.button2 == "Later!", "given labels")
    local called = 0
    ns.ReloadForLayout = function(...) called = called + 1 Check(select("#", ...) == 0, "no arguments") end
    reload.OnAccept({}, "data")
    Check(called == 1, "looked up on the click")
end)

Test("AttachTip", function()
    local b = CreateFrame("Button")
    ns.AttachTip(b, { text = "Professions" })
    Check(b._scripts.OnLeave == ns.HideTip and b._scripts.OnEnter == ns.ShowTip, "scripts")
    tipCalls = {}
    b._scripts.OnEnter(b)
    Check(tipCalls[1][1] == "SetOwner" and tipCalls[1][3] == "ANCHOR_RIGHT" and tipCalls[2].n == 2 and tipCalls[3][1] == "Show", "plain text")
    ns.AttachTip(b, { text = function(self) return self.tip end, r = 1, g = 1, b = 1,
        lines = { { function(self) return self.tip2 end, nil, nil, nil, true } } })
    tipCalls = {}
    b._scripts.OnEnter(b)
    Check(#tipCalls == 0, "nil text shows nothing")
    b.tip, b.tip2 = "Armor", "Reduces damage"
    b._scripts.OnEnter(b)
    Check(tipCalls[2][3] == 1 and tipCalls[3][1] == "AddLine" and tipCalls[3][2] == "Reduces damage" and tipCalls[3][6] == true, "colour and wrapped line")
    tipCalls = {}
    b.tip2 = nil
    b._scripts.OnEnter(b)
    Check(#tipCalls == 3, "nil line left out")
    ns.AttachTip(b, { anchor = "ANCHOR_LEFT", text = "ClassicUI Forever", r = 1, g = 1, b = 1, when = function(self) return self.on end,
        lines = { { "Left-click: options", 0.8, 0.8, 0.8 } } })
    tipCalls = {}
    b._scripts.OnEnter(b)
    Check(#tipCalls == 0, "when false")
    b.on = true
    b._scripts.OnEnter(b)
    Check(tipCalls[1][3] == "ANCHOR_LEFT" and tipCalls[3][3] == 0.8, "anchor, grey line")
    tipCalls = {}
    b._scripts.OnLeave(b)
    Check(tipCalls[1][1] == "Hide", "hide")
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
