local _, ns = ...

-- Edit mode handles for the windows (Windows in our box under edit mode): drag a placeholder to give a window its own place,
-- click it for Unlock (allow free movement, a drag strip on the window), Size and resets. Places (db.windowPos, UIParent
-- units) and sizes (db.windowScale) are put back the frame after anyone moves the window, never inside the client's pass.

-- w, h: placeholder size before the window is first made; stripRight: title strip inset from the right; toggle: the option
-- that holds its unlock (the map's lock button and settings box).
local WINDOWS = {
    { key = "character", label = "Character", name = "CharacterFrame", w = 352, h = 424 },
    { key = "professions", label = "Professions", name = "ProfessionsFrame", w = 550, h = 525 },
    { key = "talents", label = "Talents", name = "ClassicUIForeverTalents", w = 352, h = 512 },
    { key = "questLog", label = "Quest log", name = "ForeverClassicUIQuestLog", w = 384, h = 512 },
    { key = "map", label = "World map", name = "WorldMapFrame", w = 1002, h = 668, stripRight = 90, toggle = "mapUnlocked" },
}
local SLOT_LEFT, SLOT_TOP = 0, 104
local STRIP_H, STRIP_LEFT, STRIP_RIGHT = 24, 60, 30
local HANDLE_BG, HANDLE_EDGE = { 0.1, 0.35, 0.85, 0.35 }, { 0.35, 0.65, 1, 1 }
local Plain = ns.Safe

local weak = { __mode = "k" }
local entryOf = setmetatable({}, weak)   -- window frame -> its entry, once watched
local strips = setmetatable({}, weak)    -- window frame -> its drag strip
local moving = setmetatable({}, weak)    -- window frame -> true mid free drag
local dragged = setmetatable({}, weak)   -- placeholder -> true once this press dragged it

-- Our saved tables, a broken entry dropped as read (settings outlive sessions; one bad value errored every pass).
local function Clean(key, valid)
    local list = ns.DbTable(key)
    for name, value in pairs(list) do
        if not valid(value) then list[name] = nil end
    end
    return list
end

local function ValidSpot(pos) return type(pos) == "table" and type(pos[1]) == "number" and type(pos[2]) == "number" end
local function ValidScale(scale) return type(scale) == "number" and scale >= 0.5 and scale <= 1.5 end
local function ValidFlag(flag) return flag == true end

local function Places() return Clean("windowPos", ValidSpot) end

local function Freed() return Clean("windowFree", ValidFlag) end
local function Scales() return Clean("windowScale", ValidScale) end

local function IsFree(entry)
    if entry.toggle then return ns.db[entry.toggle] == true end
    return Freed()[entry.key] == true
end

local function Ratio(frame)
    local scale, screen = Plain(frame:GetEffectiveScale()), UIParent:GetEffectiveScale()
    if not scale or not screen or screen <= 0 then return nil end
    return scale / screen
end

local PlaceAll

local function Apply(entry)
    local frame, pos, scale = _G[entry.name], Places()[entry.key], Scales()[entry.key]
    if not frame or moving[frame] or not (pos or scale) then return end
    if InCombatLockdown() and ns.WindowLocked(frame) then
        ns.WhenCalm("windowPlaces", PlaceAll)
        return
    end
    if scale then ns.SetScaleIf(frame, scale) end
    if not pos then return end
    local k = Ratio(frame)
    if not k then return end
    local x, y = pos[1] / k, pos[2] / k
    if not ns.IsAt(frame, "TOPLEFT", UIParent, "BOTTOMLEFT", x, y) then
        ns.SetPointOnce(frame, "TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    end
end

-- From the frame's drawn top left.
local function SaveFrom(entry, frame)
    local k = Ratio(frame)
    local left, top = Plain(frame:GetLeft()), Plain(frame:GetTop())
    if k and left and top then Places()[entry.key] = { left * k, top * k } end
end

local function StripDragStart(self)
    local frame = self:GetParent()
    if InCombatLockdown() and ns.WindowLocked(frame) then return end
    moving[frame] = true
    frame:SetMovable(true)
    frame:StartMoving()
end

-- StopMovingOrSizing drops the anchors of a frame others hang on: read where it was drawn first, then set it there.
local function StripDragStop(self)
    local frame = self:GetParent()
    if not moving[frame] then return end
    local entry = entryOf[frame]
    SaveFrom(entry, frame)
    frame:StopMovingOrSizing()
    if frame.SetUserPlaced then pcall(frame.SetUserPlaced, frame, false) end
    moving[frame] = nil
    Apply(entry)
end

-- The title strip that drags an unlocked window; nothing on a locked one.
local function Strip(entry)
    local frame = _G[entry.name]
    if not frame then return end
    local strip = strips[frame]
    if not IsFree(entry) then
        if strip then strip:Hide() end
        return
    end
    if not strip then
        strip = CreateFrame("Frame", nil, frame)
        strip:SetPoint("TOPLEFT", frame, "TOPLEFT", STRIP_LEFT, 0)
        strip:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -(entry.stripRight or STRIP_RIGHT), -STRIP_H)
        strip:EnableMouse(true)
        strip:RegisterForDrag("LeftButton")
        strip:SetScript("OnDragStart", StripDragStart)
        strip:SetScript("OnDragStop", StripDragStop)
        strips[frame] = strip
    end
    ns.SetLevelIf(strip, frame:GetFrameLevel() + 20)
    if not strip:IsShown() then strip:Show() end
end

-- Watched from the first place or unlock: shown or moved by anyone, put back the frame after.
local function Watch(entry)
    local frame = _G[entry.name]
    if not frame or entryOf[frame] then return end
    entryOf[frame] = entry
    local job = "windowPlace." .. entry.key
    local function Put() Apply(entry) end
    local function Soon() ns.Sched.NextFrame(job, Put) end
    ns.Sched.OnVisible(frame, "windowPlace", function(shown) if shown then Soon() end end)
    ns.Sched.OnMove(frame, Soon)
end

local MapLock
PlaceAll = function()
    if not ns.db then return end
    if MapLock then MapLock() end
    local places, scales = Places(), Scales()
    for _, entry in ipairs(WINDOWS) do
        if places[entry.key] or scales[entry.key] or IsFree(entry) then
            Watch(entry)
            Apply(entry)
        end
        -- Also off again: a strip made earlier goes.
        local frame = _G[entry.name]
        if frame and (IsFree(entry) or strips[frame]) then Strip(entry) end
    end
end
-- The map's lock, beside its maximize and close buttons: the same switch as its option and its edit mode box.
local LOCK = "Interface\\Buttons\\LockButton-"
local MAP_ENTRY = WINDOWS[5]
local LOCK_TIP = { text = "Map lock", r = 1, g = 1, b = 1, lines = { { function()
    return ns.db.mapUnlocked and "Unlocked: drag the map by its title bar. Click to lock it."
        or "Locked. Click to drag the map anywhere by its title bar."
end, nil, nil, nil, true } } }
local lock
local function SyncLock()
    if not lock then return end
    local state = ns.db.mapUnlocked and "Unlocked-" or "Locked-"
    lock:SetNormalTexture(LOCK .. state .. "Up")
    lock:SetPushedTexture(LOCK .. state .. "Down")
end

MapLock = function()
    local map = WorldMapFrame
    if lock or not map then return end
    local border = map.BorderFrame or map
    local beside = border.MaximizeMinimizeFrame or border.CloseButton
    lock = CreateFrame("Button", nil, border)
    lock:SetSize(28, 28)
    lock:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    if beside then
        lock:SetPoint("RIGHT", beside, "LEFT", 2, 0)
    else
        lock:SetPoint("TOPRIGHT", map, "TOPRIGHT", -56, -2)
    end
    lock:SetScript("OnClick", function()
        ns.db.mapUnlocked = not ns.db.mapUnlocked
        ns.ToggleChanged("mapUnlocked")
    end)
    ns.AttachTip(lock, LOCK_TIP)
    SyncLock()
end

ns.OnToggle(function(key)
    if key ~= MAP_ENTRY.toggle then return end
    PlaceAll()
    SyncLock()
end)

-- Our windows are made on first open; client ones as their addon loads.
ns.PlaceSavedWindows = PlaceAll
ns.EventFrame({ "ADDON_LOADED", "PLAYER_LOGIN" }, function() if ns.db then PlaceAll() end end)

-- Back where the client or our slots put it: ours go back on the slots now, the client's on their next opening.
local function Reset(entry)
    Places()[entry.key] = nil
    local frame = _G[entry.name]
    if frame then ns.ReturnClassicWindow(frame) end
end

------------------------------------------------------------------ edit mode

local box, dialog, selected
local handles = {}

-- A placeholder's rect in UIParent units: its place, else where the window is drawn now, else the first slot.
local function HandleRect(entry)
    local frame, pos = _G[entry.name], Places()[entry.key]
    local k = frame and Ratio(frame)
    local w, h = entry.w, entry.h
    if frame and k then
        w, h = (Plain(frame:GetWidth()) or w / k) * k, (Plain(frame:GetHeight()) or h / k) * k
    end
    if pos then return pos[1], pos[2], w, h end
    if frame and k and frame:IsShown() then
        local left, top = Plain(frame:GetLeft()), Plain(frame:GetTop())
        if left and top then return left * k, top * k, w, h end
    end
    return SLOT_LEFT, UIParent:GetHeight() - SLOT_TOP, w, h
end

local function LayHandle(entry)
    local handle = handles[entry.key]
    if not handle then return end
    local x, y, w, h = HandleRect(entry)
    handle:SetSize(w, h)
    if not ns.IsAt(handle, "TOPLEFT", UIParent, "BOTTOMLEFT", x, y) then
        ns.SetPointOnce(handle, "TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    end
end

local function Refresh()
    if not (dialog and selected and dialog:IsShown()) then return end
    dialog.title:SetText(selected.label)
    dialog.check:SetChecked(IsFree(selected))
    dialog.reset:SetEnabled(Places()[selected.key] ~= nil)
    dialog.resize:SetEnabled(Scales()[selected.key] ~= nil)
    if dialog.InitSlider then dialog.InitSlider() end
end

-- Unlock: the map's goes through its option (lock button and settings box follow); the rest are kept here.
local function SetFree(entry, on)
    if entry.toggle then
        ns.db[entry.toggle] = on
        ns.ToggleChanged(entry.toggle)
    else
        Freed()[entry.key] = on or nil
    end
    PlaceAll()
end

local function Percent(value) return string.format("%d%%", value) end
local function SizeValues()
    local scale = selected and Scales()[selected.key] or 1
    return math.floor(scale * 100 + 0.5), 50, 150, 20
end

-- No dialog refresh here: that would re-fill the slider under the player's hand.
local function OnSize(value)
    if not selected then return end
    local scale = math.max(0.5, math.min(1.5, value / 100))
    Scales()[selected.key] = math.abs(scale - 1) > 0.001 and scale or nil
    local frame = _G[selected.name]
    if frame and not Scales()[selected.key] and not (InCombatLockdown() and ns.WindowLocked(frame)) then
        ns.SetScaleIf(frame, 1)
    end
    PlaceAll()
    LayHandle(selected)
end

-- Shaped like edit mode's own dialog, as the band's pieces are.
local function Dialog()
    if dialog then return dialog end
    local B = ns.band
    dialog = B.EditDialog("ForeverClassicUIWindowDialog", 383, 214)
    dialog:SetClampedToScreen(true)
    local check = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
    check:SetSize(30, 30)
    check:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -44)
    ns.EditModeCheck(check)
    local label = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    label:SetText("Unlock (allow free movement)")
    check:SetScript("OnClick", function(self) SetFree(selected, self:GetChecked() and true or false) end)
    dialog.check = check
    local size = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    size:SetSize(100, 32)
    size:SetJustifyH("LEFT")
    size:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 0, -4)
    size:SetText(HUD_EDIT_MODE_SETTING_MICRO_MENU_SIZE or "Size")
    local slider, formatters = B.StepperSlider(dialog, 200, size, 5, Percent)
    if slider then
        dialog.InitSlider = B.GuardedSlider(slider, SizeValues, OnSize, { formatters = formatters, owner = dialog })
    end
    dialog.reset = B.EditDialogReset(dialog, function()
        Reset(selected)
        LayHandle(selected)
        Refresh()
    end)
    local resize = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    resize:SetSize(330, 28)
    resize:SetPoint("BOTTOM", dialog.reset, "TOP", 0, 6)
    resize:SetText("Reset To Default Size")
    resize:SetScript("OnClick", function()
        OnSize(100)
        Refresh()
    end)
    ns.EditModeRed(resize)
    dialog.resize = resize
    return dialog
end

local function Select(entry)
    selected = entry
    local d = Dialog()
    ns.SetPointOnce(d, "LEFT", handles[entry.key], "RIGHT", 8, 0)
    d:Show()
    Refresh()
end

local function HandleDown(self) dragged[self] = nil end

local function HandleDragStart(self)
    dragged[self] = true
    self:StartMoving()
end

local function HandleUp(self, button)
    if button == "LeftButton" and not dragged[self] then Select(self.entry) end
end

-- A drop gives the window its place at once.
local function HandleDropped(self)
    local entry = self.entry
    local left, top = Plain(self:GetLeft()), Plain(self:GetTop())
    if not (left and top) then return end
    Places()[entry.key] = { left, top }
    LayHandle(entry)
    PlaceAll()
    if selected == entry then Refresh() end
end

local function Handle(entry)
    local handle = handles[entry.key]
    if handle then return handle end
    handle = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    handle.entry = entry
    -- Under edit mode's own selections and dialogs.
    handle:SetFrameStrata("LOW")
    ns.Backdrop(handle, ns.BACKDROP.TIP16, { bronze = false, bg = HANDLE_BG, border = HANDLE_EDGE })
    local text = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    text:SetPoint("CENTER")
    text:SetText(entry.label)
    ns.MakeDraggable(handle, HandleDropped)
    handle:SetScript("OnDragStart", HandleDragStart)
    handle:SetScript("OnMouseDown", HandleDown)
    handle:SetScript("OnMouseUp", HandleUp)
    handles[entry.key] = handle
    return handle
end

local function ShowHandles(on)
    for _, entry in ipairs(WINDOWS) do
        if on then
            Handle(entry)
            LayHandle(entry)
            handles[entry.key]:Show()
        elseif handles[entry.key] then
            handles[entry.key]:Hide()
        end
    end
    if not on and dialog then dialog:Hide() end
end

-- Our box under edit mode's window, never inside its layout: Windows shows the placeholders.
local function WindowsClick(self)
    ns.db.editWindows = self:GetChecked() and true or false
    ShowHandles(ns.db.editWindows)
end

local function Box()
    if box then return box end
    box = ns.CheckPanel(250, "Windows (ClassicUI Forever)", WindowsClick)
    local check = box.check
    check.label = "Windows"
    check.tooltip = "Shows the character, professions, talents, quest log and map windows here. Drag one to give it a place of its own; click it to unlock it, size it or reset it."
    ns.AttachTip(check, { text = function(self) return self.label end, r = 1, g = 1, b = 1,
        lines = { { function(self) return self.tooltip end, nil, nil, nil, true } } })
    return box
end

local function OnEditMode()
    local live = ns.EditMode.Live()
    local manager = EditModeManagerFrame
    if live and manager and ns.db then
        local b = Box()
        -- Kept on screen: under a window standing low it fell off the bottom.
        b:SetClampedToScreen(true)
        ns.SetPointOnce(b, "TOPLEFT", manager, "BOTTOMLEFT", 0, 2)
        b.check:SetChecked(ns.db.editWindows == true)
        b:Show()
        ShowHandles(ns.db.editWindows == true)
    else
        if box then box:Hide() end
        ShowHandles(false)
    end
end
ns.OnEditMode(OnEditMode)
