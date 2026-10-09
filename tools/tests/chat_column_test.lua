-- Offline tests for Windows/Chat.lua under Lua 5.4: the menu, voice and friends buttons stand on the docked tab showing,
-- and a hidden scroll-to-bottom button stays unseen through the game's own fade in (#142).
-- Run from the addon root: lua tools/tests/chat_column_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

------------------------------------------------------------------ the stub client

local Frame = {}
Frame.__index = Frame
function Frame:SetParent(p) self._parent = p end
function Frame:GetParent() return self._parent end
function Frame:GetName() return self._name end
function Frame:Show() self._shown = true end
function Frame:Hide() self._shown = false end
function Frame:SetShown(on) self._shown = on and true or false end
function Frame:IsShown() return self._shown end
function Frame:IsVisible()
    local f = self
    while f do
        if not f._shown then return false end
        f = f._parent
    end
    return true
end
function Frame:SetFrameStrata(s) self._strata = s end
function Frame:GetFrameStrata() return self._strata end
function Frame:SetFrameLevel(l) self._level = l end
function Frame:GetFrameLevel() return self._level end
function Frame:ClearAllPoints() self._points = {} end
function Frame:SetPoint(point, rel, relPoint, x, y)
    for _, p in ipairs(self._points) do
        if p[1] == point then
            p[2], p[3], p[4], p[5] = rel, relPoint, x, y
            return
        end
    end
    self._points[#self._points + 1] = { point, rel, relPoint, x, y }
end
function Frame:SetAllPoints(rel) self._points = { { "TOPLEFT", rel, "TOPLEFT", 0, 0 } } end
function Frame:GetNumPoints() return #self._points end
function Frame:GetPoint(i) return table.unpack(self._points[i] or {}) end
function Frame:SetSize(w, h) self._w, self._h = w, h end
function Frame:SetWidth(w) self._w = w end
function Frame:SetHeight(h) self._h = h end
function Frame:GetWidth() return self._w or 0 end
function Frame:GetHeight() return self._h or 0 end
function Frame:GetBottom() return nil end
function Frame:GetEffectiveScale() return 1 end
function Frame:SetScript(name, fn) self._scripts[name] = fn end
function Frame:GetScript(name) return self._scripts[name] end
function Frame:IsObjectType(kind) return kind == "Frame" or kind == self._kind end
function Frame:SetAlpha(a) self._alpha = a end
function Frame:EnableMouse(on) self._mouse = on end
function Frame:IsMouseEnabled() return self._mouse ~= false end
function Frame:GetNormalTexture() return nil end
function Frame:GetPushedTexture() return nil end
function Frame:GetDisabledTexture() return nil end
function Frame:GetHighlightTexture() return nil end
function Frame:SetNormalAtlas() end
function Frame:SetPushedAtlas() end
function Frame:SetHighlightAtlas() end
function Frame:ClearDisabledTexture() end

function CreateFrame(kind, name, parent)
    local level = parent and (parent._level or 0) + 1 or 0
    local frame = setmetatable({ _kind = kind, _name = name, _parent = parent, _level = level, _strata = "MEDIUM",
        _shown = true, _points = {}, _scripts = {} }, Frame)
    if name then _G[name] = frame end
    return frame
end

UIParent = CreateFrame("Frame", "UIParent")
function InCombatLockdown() return false end
function GetTime() return 100 end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end

-- Two docked windows on one dock, General selected; the client hangs menu and voice on ChatFrame1's button frame.
local function ChatWindow(name)
    local chat = CreateFrame("Frame", name, UIParent)
    chat.buttonFrame = CreateFrame("Frame", name .. "ButtonFrame", chat)
    chat.isDocked = 1
    return chat
end
local general, combatLog = ChatWindow("ChatFrame1"), ChatWindow("ChatFrame2")
combatLog:Hide()
CHAT_FRAMES = { "ChatFrame1", "ChatFrame2" }
local menu = CreateFrame("Button", "ChatFrameMenuButton", general.buttonFrame)
local channel = CreateFrame("Button", "ChatFrameChannelButton", general.buttonFrame)
local alerts = CreateFrame("Frame", "ChatAlertFrame", UIParent)
menu:SetPoint("BOTTOM", general.buttonFrame, "BOTTOM", 0, 0)
local toBottom = CreateFrame("Button", nil, general)
general.ScrollToBottomButton = toBottom

------------------------------------------------------------------ the addon

local ns = { db = {}, EMPTY = {}, ART = { HILIGHT = "hilight" } }
local noop = function() end
local module, shownHooks = nil, {}
local function NewJob(spec) return { Wake = noop, Sleep = noop, Kick = function(job) spec.fn(job, 0) end } end
ns.Sched = {
    OnFrame = function(_, spec) return NewJob(spec) end,
    Job = NewJob,
    NextFrame = noop,
    Soon = noop,
    OnVisible = function(host, _, fn) shownHooks[host] = fn end,
}
ns.NewFrame = CreateFrame
ns.SetPointOnce = function(frame, ...) frame:ClearAllPoints() frame:SetPoint(...) end
ns.SetShownIf = function(frame, on) frame:SetShown(on) end
ns.SetAlphaIf = function(frame, a) frame:SetAlpha(a) end
ns.BaseSetters = function() return nil, Frame.ClearAllPoints, Frame.SetPoint end
ns.Near = function(a, b, d) return math.abs((a or 0) - (b or 0)) <= d end
ns.AnySecret = function() return false end
ns.IsSecret = function() return false end
ns.ThemeTurned = function() return false end
ns.ThemeLook = function() return "classic" end
ns.EventFrame, ns.StateTexture, ns.BronzeCopy, ns.DressStates, ns.PaintCopy, ns.EachState, ns.Dress = noop, noop, noop,
    noop, noop, noop, noop
ns.SkinMinimalScrollBar = noop
ns.RegisterModule = function(_, mod) module = mod end
ns.OnToggle = noop

local chunk = assert(loadfile(ROOT .. "/Windows/Chat.lua"))
chunk("ClassicUIForever", ns)

------------------------------------------------------------------ checks

local failures = 0
local function Check(ok, what)
    if not ok then
        failures = failures + 1
        print("FAIL: " .. what)
    end
end

-- The frame a button's first point hangs on.
local function Under(frame)
    local _, rel = frame:GetPoint(1)
    return rel
end

-- Shows chat, hides the other, and fires the bottom slot's show as the client's tab pass would.
local function Pick(chat, other)
    other:Hide()
    chat:Show()
    for host, fn in pairs(shownHooks) do
        if host:GetParent() == chat.buttonFrame then fn(true) end
    end
end

local function Stacked(chat, label)
    Check(menu:GetParent() == chat.buttonFrame, label .. ": menu on the shown window's button frame")
    Check(channel:GetParent() == chat.buttonFrame, label .. ": voice on the shown window's button frame")
    Check(menu:IsVisible() and channel:IsVisible(), label .. ": menu and voice visible")
    local slot = Under(menu)
    Check(slot ~= nil and slot:GetParent() == chat.buttonFrame, label .. ": menu stands on the shown window's column")
    Check(Under(channel) == menu, label .. ": voice above the menu")
    Check(Under(alerts) == channel, label .. ": friends above the voice button")
end

assert(module and module.apply, "Windows/Chat.lua registered no module")
local ok, err = pcall(module.apply)
Check(ok, "apply raised: " .. tostring(err))
if ok then
    Stacked(general, "General")
    Pick(combatLog, general)
    Stacked(combatLog, "Combat Log tab")
    Pick(general, combatLog)
    Stacked(general, "back on General")
    ok, err = pcall(module.restore)
    Check(ok, "restore raised: " .. tostring(err))
    Check(menu:GetParent() == general.buttonFrame and Under(menu) == general.buttonFrame,
        "restore: menu back on ChatFrame1's button frame at its own point")
end

-- Hide chat buttons with the scroll-to-bottom button picked: the game fades that button's own alpha in as the chat
-- scrolls up, which flashed past a hold on its alpha.
ns.db = { hideChatButtons = true }
ok, err = pcall(module.apply)
Check(ok, "apply with hidden buttons raised: " .. tostring(err))
local heldLevel = toBottom:GetFrameLevel()
toBottom:SetAlpha(1)
toBottom:Show()
Check(not toBottom:IsVisible(), "hidden: the game's fade in leaves the scroll-to-bottom button unseen")
Check(toBottom:GetParent() ~= general and not toBottom:GetParent():IsShown(), "hidden: held under a hidden frame of ours")
ns.db.hideChatButtons = false
ok, err = pcall(module.apply)
Check(ok, "apply with buttons shown raised: " .. tostring(err))
Check(toBottom:GetParent() == general and toBottom:IsVisible(), "shown again: back on its chat and seen")
Check(toBottom:GetFrameLevel() == heldLevel, "shown again: at the level it had as it was held")
ns.db.hideChatButtons = true
Check(pcall(module.apply) and toBottom:GetParent() ~= general, "hidden again before the restore")
Check(pcall(module.restore) and toBottom:GetParent() == general, "restore: the scroll-to-bottom button back on its chat")

if failures > 0 then
    print(string.format("chat column: %d failed", failures))
    os.exit(1)
end
print("chat column: ok")
