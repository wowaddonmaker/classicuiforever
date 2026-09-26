local _, ns = ...

-- ClassicUI Forever Windows: our edit mode for the windows. A placeholder drag places a window; its dialog holds Movable
-- anytime, Size and resets. Places (db.windowPos, UIParent units) and sizes (db.windowScale) are put back the frame after
-- anyone moves the window, never inside the client's pass.

-- w, h: placeholder size before the window is first made; cut: right and bottom of a 384 x 512 frame its old art leaves
-- bare (the 1.x frame's hit rect); stripRight: title strip inset from the right; toggle: the option that holds its unlock
-- (the map's lock button and settings box); quests: the map, which its quest log pane widens.
local WINDOWS = {
    { key = "character", label = "Character", name = "CharacterFrame", w = 354, h = 467, cut = { 30, 45 } },
    { key = "professions", label = "Professions", name = "ProfessionsFrame", w = 550, h = 525 },
    { key = "talents", label = "Talents", name = "ClassicUIForeverTalents", w = 354, h = 467, cut = { 30, 45 } },
    { key = "questLog", label = "Quest log", name = "ForeverClassicUIQuestLog", w = 349, h = 437, cut = { 35, 75 } },
    { key = "map", label = "World map", name = "WorldMapFrame", w = 1035, h = 534, stripRight = 90, toggle = "mapUnlocked",
        quests = true },
}
local SLOT_LEFT, SLOT_TOP = 0, 104
local STRIP_H, STRIP_LEFT, STRIP_RIGHT = 24, 60, 30
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

-- Maximized, the map fills the screen as the client lays it: none of our place or size.
local function Full(entry, frame)
    return entry.quests and frame and frame.IsMaximized and frame:IsMaximized() and true or false
end

-- The part of the window its art fills, in its own units.
local function DrawnSize(entry, frame)
    local w, h = Plain(frame:GetWidth()), Plain(frame:GetHeight())
    if not (w and h) then return nil end
    local cut = entry.cut
    if cut and math.abs(w - 384) < 1 and math.abs(h - 512) < 1 then return w - cut[1], h - cut[2] end
    return w, h
end

local scaled = setmetatable({}, weak)   -- window frame -> true while it wears a size of ours
local clampWas = setmetatable({}, weak) -- window frame -> its clamp before a drag of ours

-- A top left (UIParent units) that keeps the window's drawn part on the screen.
local function OnScreen(entry, frame, k, left, top)
    local w, h = DrawnSize(entry, frame)
    if not w then return left, top end
    local screenW, screenH = UIParent:GetSize()
    left = math.max(0, math.min(left, screenW - w * k))
    top = math.min(screenH, math.max(top, h * k))
    return left, top
end

local PlaceAll

local function Apply(entry)
    local frame = _G[entry.name]
    if not frame or moving[frame] then return end
    local pos, scale = Places()[entry.key], Scales()[entry.key]
    if Full(entry, frame) then pos, scale = nil, nil end
    if not (pos or scale or scaled[frame]) then return end
    if InCombatLockdown() and ns.WindowLocked(frame) then
        ns.WhenCalm("windowPlaces", PlaceAll)
        return
    end
    -- No size of ours (or the map maximized): its own.
    if scale then
        ns.SetScaleIf(frame, scale)
        scaled[frame] = true
    elseif scaled[frame] then
        ns.SetScaleIf(frame, 1)
        scaled[frame] = nil
    end
    if not pos then return end
    local k = Ratio(frame)
    if not k then return end
    local x, y = OnScreen(entry, frame, k, pos[1], pos[2])
    x, y = x / k, y / k
    if not ns.IsAt(frame, "TOPLEFT", UIParent, "BOTTOMLEFT", x, y) then
        ns.SetPointOnce(frame, "TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    end
end

-- From the frame's drawn top left.
local function SaveFrom(entry, frame)
    local k = Ratio(frame)
    local left, top = Plain(frame:GetLeft()), Plain(frame:GetTop())
    if not (k and left and top) then return end
    local x, y = OnScreen(entry, frame, k, left * k, top * k)
    Places()[entry.key] = { x, y }
end

local function StripDragStart(self)
    local frame = self:GetParent()
    if (InCombatLockdown() and ns.WindowLocked(frame)) or Full(entryOf[frame], frame) then return end
    moving[frame] = true
    ns.Sched.LetGo(frame, true)
    -- Held on the screen while dragged.
    clampWas[frame] = frame:IsClampedToScreen() and true or false
    frame:SetClampedToScreen(true)
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
    frame:SetClampedToScreen(clampWas[frame] == true)
    Apply(entry)
    ns.Sched.LetGo(frame, false)
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

-- Watched from the first place or unlock: placed as it shows, and put back the frame after anyone moves it.
local function Watch(entry)
    local frame = _G[entry.name]
    if not frame or entryOf[frame] then return end
    entryOf[frame] = entry
    local function Put() Apply(entry) end
    -- Before it draws, shown or moved (the map's quest toggle re-lays it through the panel manager): later, it flashed there.
    ns.Sched.OnMove(frame, ns.Sched.AfterShow(frame, "windowPlace", Put))
end

local MapLock
PlaceAll = function()
    if not ns.db then return end
    if MapLock then MapLock() end
    for _, entry in ipairs(WINDOWS) do
        local frame = _G[entry.name]
        if Places()[entry.key] or Scales()[entry.key] or IsFree(entry) or (frame and scaled[frame]) then
            Watch(entry)
            Apply(entry)
        end
        -- Also off again: a strip made earlier goes.
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
    -- Under the mouse, its tooltip says the new state at once.
    if GameTooltip:IsOwned(lock) then lock:GetScript("OnEnter")(lock) end
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
    -- Maximized, the map is the client's full screen and nothing of ours moves it: no lock then.
    local function LockShown() ns.SetShownIf(lock, not (map.IsMaximized and map:IsMaximized())) end
    ns.Sched.OnMove(map, function() ns.Sched.NextFrame("windows.mapLock", LockShown) end)
    ns.Sched.AfterShow(map, "windows.mapLock", LockShown)
    LockShown()
end

ns.OnToggle(function(key)
    if key ~= MAP_ENTRY.toggle then return end
    PlaceAll()
    SyncLock()
end)

-- Our windows are made on first open; client ones as their addon loads.
ns.PlaceSavedWindows = PlaceAll
ns.EventFrame({ "ADDON_LOADED", "PLAYER_LOGIN" }, function() if ns.db then PlaceAll() end end)

------------------------------------------------------------------ edit mode

local dialog, selected
local handles = {}
-- The map's placeholder: with its quest log pane (as it opens) or the map alone; one place and size for both.
local mapOnly = false

-- Back where the client or our slots put it: ours go back on the slots now, the client's on their next opening.
local function Reset(entry)
    Places()[entry.key] = nil
    local frame = _G[entry.name]
    if frame then ns.ReturnClassicWindow(frame) end
end

-- The client's map: 702 x 534, plus 333 for its quest log pane.
local MAP_W, MAP_H, MAP_QUESTS = 702, 534, 333

-- The placeholder's size in the window's own units: as drawn, the map in the width picked.
local function PreviewSize(entry, frame)
    if entry.quests then return MAP_W + (mapOnly and 0 or MAP_QUESTS), MAP_H end
    if frame then
        local w, h = DrawnSize(entry, frame)
        if w then return w, h end
    end
    return entry.w, entry.h
end

-- A placeholder's rect in UIParent units: its place, else where the window is drawn now, else its spot (the map's
-- centred, the rest on the first slot).
local function HandleRect(entry)
    local frame, pos = _G[entry.name], Places()[entry.key]
    local full = Full(entry, frame)
    local k = (frame and not full and Ratio(frame)) or Scales()[entry.key] or 1
    local w, h = PreviewSize(entry, frame)
    w, h = w * k, h * k
    if pos then return pos[1], pos[2], w, h end
    if frame and not full and frame:IsShown() then
        local left, top = Plain(frame:GetLeft()), Plain(frame:GetTop())
        if left and top then return left * k, top * k, w, h end
    end
    if entry.quests then
        local screenW, screenH = UIParent:GetSize()
        return (screenW - w) / 2, screenH - (screenH - h) / 2, w, h
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

-- Edit mode's own look: blue, and yellow while its dialog is open.
local function DressHandles()
    local open = dialog and dialog:IsShown() and selected
    for key, handle in pairs(handles) do
        handle.sel.Dress(open and open.key == key and "editmode-actionbar-selected" or "editmode-actionbar-highlight")
    end
end

local DIALOG_H, VIEW_H, FREE_Y = 214, 34, -44
-- The map's extra rows: its view switch over Movable anytime, Fade while moving under it.
local MAP_ROWS = 2

local function Refresh()
    if not (dialog and selected and dialog:IsShown()) then return end
    local key, views = selected.key, selected.quests == true
    dialog.title:SetText(selected.label)
    dialog:SetHeight(views and DIALOG_H + VIEW_H * MAP_ROWS or DIALOG_H)
    dialog.views:SetShown(views)
    dialog.wide:SetChecked(not mapOnly)
    dialog.narrow:SetChecked(mapOnly)
    ns.SetPointOnce(dialog.check, "TOPLEFT", dialog, "TOPLEFT", 20, views and FREE_Y - VIEW_H or FREE_Y)
    dialog.check:SetChecked(IsFree(selected))
    -- The map's fade is the addon's own setting (the game's mapFade), the same as in the options.
    dialog.fade:SetShown(views)
    dialog.fade:SetChecked(ns.db.mapFade == true)
    ns.SetPointOnce(dialog.sizeLabel, "TOPLEFT", views and dialog.fade or dialog.check, "BOTTOMLEFT", 0, -4)
    dialog.reset:SetEnabled(Places()[key] ~= nil)
    dialog.resize:SetEnabled(Scales()[key] ~= nil)
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
    PlaceAll()
    LayHandle(selected)
end

-- The map's placeholder width.
local function PickView(only)
    if not (selected and selected.quests) then return end
    mapOnly = only
    LayHandle(selected)
    Refresh()
end

local function ViewCheck(parent, text, x, only)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(30, 30)
    check:SetPoint("LEFT", parent, "LEFT", x, 0)
    ns.EditModeCheck(check)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    label:SetText(text)
    check:SetScript("OnClick", function() PickView(only) end)
    return check
end

local FADE_TIP = { text = "Fade while moving", r = 1, g = 1, b = 1, lines = { {
    "The map dims while you move. The same setting as in the options (the game's own).", nil, nil, nil, true } } }

local FREE_TIP = { text = "Movable anytime", r = 1, g = 1, b = 1, lines = { {
    "Drag the window by its title bar whenever it is open, not only here. Off, it stays where it is placed.",
    nil, nil, nil, true } } }

-- Shaped like edit mode's own dialog, as the band's pieces are.
local function Dialog()
    if dialog then return dialog end
    local B = ns.band
    dialog = B.EditDialog("ForeverClassicUIWindowDialog", 383, DIALOG_H)
    dialog:SetClampedToScreen(true)
    -- The map only: its placeholder with or without the quest log pane.
    local views = CreateFrame("Frame", nil, dialog)
    views:SetSize(343, 30)
    views:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, FREE_Y)
    dialog.views = views
    dialog.wide = ViewCheck(views, "With quest log", 0, false)
    dialog.narrow = ViewCheck(views, "Map only", 180, true)
    local check = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
    check:SetSize(30, 30)
    check:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, FREE_Y)
    ns.EditModeCheck(check)
    local label = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    label:SetText("Movable anytime, by its title bar")
    check:SetScript("OnClick", function(self) SetFree(selected, self:GetChecked() and true or false) end)
    ns.AttachTip(check, FREE_TIP)
    dialog.check = check
    local fade = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
    fade:SetSize(30, 30)
    fade:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 0, -4)
    ns.EditModeCheck(fade)
    local fadeLabel = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    fadeLabel:SetPoint("LEFT", fade, "RIGHT", 4, 0)
    fadeLabel:SetText("Fade while moving")
    fade:SetScript("OnClick", function(self)
        ns.db.mapFade = self:GetChecked() and true or false
        ns.ToggleChanged("mapFade")
    end)
    ns.AttachTip(fade, FADE_TIP)
    dialog.fade = fade
    local size = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    dialog.sizeLabel = size
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
    dialog:HookScript("OnHide", DressHandles)
    return dialog
end

local function Select(entry)
    selected = entry
    local d = Dialog()
    local handle = handles[entry.key]
    local right, top, bottom = Plain(handle:GetRight()), Plain(handle:GetTop()), Plain(handle:GetBottom())
    -- Placed once: hung on the placeholder, it moved with each size step under the slider's hand.
    if right and top and bottom then
        ns.SetPointOnce(d, "LEFT", UIParent, "BOTTOMLEFT", right + 8, (top + bottom) / 2)
    end
    d:Show()
    DressHandles()
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
    handle = CreateFrame("Frame", nil, UIParent)
    handle.entry = entry
    -- Over the windows it stands for, under our mode window and dialogs.
    handle:SetFrameStrata("DIALOG")
    handle:SetFrameLevel(50)
    ns.MakeDraggable(handle, HandleDropped)
    handle:SetScript("OnDragStart", HandleDragStart)
    handle:SetScript("OnMouseDown", HandleDown)
    handle:SetScript("OnMouseUp", HandleUp)
    -- Edit mode's selection box over it; the mouse stays the placeholder's.
    local sel = ns.band.SelectionHandle(handle, entry.label)
    sel:SetFrameStrata("DIALOG")
    sel:SetFrameLevel(51)
    sel:EnableMouse(false)
    sel:Show()
    handle.sel = sel
    handles[entry.key] = handle
    return handle
end

-- One window's placeholder up or down; its dialog goes with it.
local function ShowHandle(entry, on)
    if on then
        Handle(entry)
        LayHandle(entry)
        handles[entry.key]:Show()
        DressHandles()
    elseif handles[entry.key] then
        handles[entry.key]:Hide()
        if selected == entry and dialog then dialog:Hide() end
    end
end

-- Shared with UI/WindowsEditMode.lua, the mode window around these placeholders.
ns.windowEdit = {
    WINDOWS = WINDOWS, Clean = Clean, ValidFlag = ValidFlag, Places = Places, Scales = Scales, Freed = Freed,
    Ratio = Ratio, PlaceAll = PlaceAll, LayHandle = LayHandle, Refresh = Refresh,
    ShowHandle = ShowHandle,
    HideDialog = function() if dialog then dialog:Hide() end end,
}

-- The map's lock and option switch its Movable anytime too.
ns.OnToggle(function(key) if key == MAP_ENTRY.toggle or key == "mapFade" then Refresh() end end)
