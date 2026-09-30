-- Offline tests for Core/Gamepad.lua under Lua 5.4: the gamepad check, the window lookups and ns.NewFrame.
-- Run from the addon root: lua tools/tests/gamepad_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

------------------------------------------------------------------ the stub client

local made = {}   -- every CreateFrame call: { kind, name, parent, template }
local Frame = {}
Frame.__index = Frame
function Frame:SetParent(p) self._parent = p end
function Frame:GetParent() return self._parent end
function Frame:GetName() return self._name end
function Frame:SetFrameLevel(l) self._level = l end
function Frame:GetFrameLevel() return self._level end
function Frame:SetScript(name, fn) self._scripts[name] = fn end
function Frame:RegisterEvent(e) self._events[#self._events + 1] = e end

function CreateFrame(kind, name, parent, template)
    made[#made + 1] = { kind, name, parent, template }
    local level = parent and (parent._level or 0) + 1 or 0
    return setmetatable({ _kind = kind, _name = name, _parent = parent, _level = level, _scripts = {}, _events = {} }, Frame)
end

UIParent = CreateFrame("Frame", "UIParent")
UIParent._level = 0

local combat = false
function InCombatLockdown() return combat end

-- The client's lookups, as SmartNavigation.lua has them.
local nav = { activePanels = {} }
function nav:GetPanelInfo(frame, dontCreate)
    assert(dontCreate == true, "a lookup must never create panel info")
    for _, info in ipairs(self.activePanels) do
        if info.frame == frame then return info end
    end
end
function nav:GetParentPanelInfo(frame)
    local curr = frame
    while curr and curr ~= UIParent do
        local info = self:GetPanelInfo(curr, true)
        if info then return info end
        curr = curr:GetParent()
    end
end

local GAMEPAD, MKB = 1, 0
local style = MKB

------------------------------------------------------------------ the addon

local ns = {}
function ns.SetLevelIf(frame, level) if frame:GetFrameLevel() ~= level then frame:SetFrameLevel(level) end end

local function Load(path)
    local chunk, err = loadfile(ROOT .. "/" .. path)
    if not chunk then error(err) end
    chunk("ClassicUIForever", ns)
end

------------------------------------------------------------------ the checks

local passed, failed = 0, 0
local function Check(ok, label)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. label)
    end
end

local function Test(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        failed = failed + 1
        print("ERROR in " .. name .. ": " .. tostring(err))
    end
end

-- Loaded on a client without the gamepad API first: nothing may break.
Load("Core/Util.lua")
Load("Core/Gamepad.lua")

Test("no gamepad API", function()
    Check(ns.GamepadUI() == false, "no C_InputInterfaceStyle: off")
    local parent = CreateFrame("Frame", nil, UIParent)
    local frame = ns.NewFrame("Button", nil, parent)
    Check(made[#made][3] == parent and frame:GetParent() == parent, "made on its parent")
    Check(ns.GamepadHolds(parent) == false, "holds nothing")
end)

-- A client with the gamepad interface: the enum is read as the file loads.
Enum = { InputDeviceInterfaceType = { Gamepad = GAMEPAD, Mkb = MKB } }
C_InputInterfaceStyle = { GetCurrentStyle = function() return style end }
SmartNavigation = nav
GamepadMode = { FrameControlsManager = { shownFrames = {} } }
Load("Core/Gamepad.lua")

Test("transition event", function()
    local watcher = made[#made]
    Check(watcher[3] == nil, "a plain event frame")
end)

Test("style", function()
    style = MKB
    Check(ns.GamepadUI() == false, "mouse and keyboard: off")
    style = GAMEPAD
    Check(ns.GamepadUI() == true, "gamepad: on")
end)

local window = CreateFrame("Frame", "CharacterFrame", UIParent)
window._level = 5
local inner = CreateFrame("Frame", nil, window)
local elsewhere = CreateFrame("Frame", nil, UIParent)

Test("NewFrame, no window open", function()
    style = GAMEPAD
    nav.activePanels = {}
    local frame = ns.NewFrame("Frame", nil, inner)
    Check(made[#made][3] == inner and frame:GetParent() == inner, "made on its parent")
end)

Test("NewFrame, window open", function()
    style = GAMEPAD
    nav.activePanels = { { frame = window, buttonGroups = {} } }
    local frame = ns.NewFrame("Button", nil, inner, "UIPanelButtonTemplate")
    local call = made[#made]
    Check(call[3] == UIParent and call[4] == "UIPanelButtonTemplate", "made on UIParent, template kept")
    Check(frame:GetParent() == inner, "moved to its parent")
    Check(frame:GetFrameLevel() == inner:GetFrameLevel() + 1, "level over its parent, as CreateFrame gives")
    local named = ns.NewFrame("Frame", "$parentTab", window)
    Check(made[#made][2] == "CharacterFrameTab" and named:GetName() == "CharacterFrameTab", "$parent names the real parent")
    local other = ns.NewFrame("Frame", nil, elsewhere)
    Check(made[#made][3] == elsewhere and other:GetParent() == elsewhere, "outside the window: made on its parent")
    local top = ns.NewFrame("Frame", nil, UIParent)
    Check(made[#made][3] == UIParent and top:GetParent() == UIParent, "UIParent itself")
end)

Test("NewFrame, secure in a fight", function()
    style = GAMEPAD
    nav.activePanels = { { frame = window, buttonGroups = {} } }
    combat = true
    ns.NewFrame("Button", nil, inner, "SecureActionButtonTemplate")
    Check(made[#made][3] == inner, "a secure frame cannot move in a fight: made on its parent")
    ns.NewFrame("Frame", nil, inner)
    Check(made[#made][3] == UIParent, "a plain frame still goes round")
    combat = false
end)

Test("NewFrame, mouse and keyboard", function()
    style = MKB
    nav.activePanels = { { frame = window, buttonGroups = {} } }
    ns.NewFrame("Frame", nil, inner)
    Check(made[#made][3] == inner, "gamepad off: made on its parent")
    style = GAMEPAD
end)

Test("GamepadHolds", function()
    style = GAMEPAD
    nav.activePanels = { { frame = window, buttonGroups = {} } }
    GamepadMode.FrameControlsManager.shownFrames = {}
    Check(ns.GamepadHolds(window) == true, "navigated window")
    Check(ns.GamepadHolds(inner) == false, "a child is not a window")
    nav.activePanels = {}
    GamepadMode.FrameControlsManager.shownFrames = { elsewhere }
    Check(ns.GamepadHolds(elsewhere) == true, "shown by the focus manager")
    Check(ns.GamepadHolds(window) == false, "neither")
    style = MKB
    Check(ns.GamepadHolds(elsewhere) == false, "gamepad off: holds nothing")
    style = GAMEPAD
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
