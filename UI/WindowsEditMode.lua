local _, ns = ...
local L = ns.L

-- ClassicUI Forever Windows: our edit mode window around the window placeholders (UI/WindowHandles.lua), and its toggle
-- on the client's HUD Edit Mode window.

local W = ns.windowEdit
local WINDOWS, Clean, ValidFlag, Places, Scales, Freed = W.WINDOWS, W.Clean, W.ValidFlag, W.Places, W.Scales, W.Freed
local Set, DialogKeys = W.Set, W.DialogKeys
local Ratio, PlaceAll, LayHandle, Refresh = W.Ratio, W.PlaceAll, W.LayHandle, W.Refresh
local ShowHandle, Return = W.ShowHandle, W.Return
local Plain = ns.Safe

-- Shaped like the client's HUD Edit Mode (510 wide, 225 x 32 check rows in two columns, Revert All Changes and Save).
-- The client's is shut by its own close button and opened by /editmode, both pressed by secure pads in its name: from
-- our code they would taint its layouts.
local MODE_W, MODE_PAD, ROW_W, ROW_H = 510, 20, 225, 32
local MODE_TOP = 110
local SECTION_GAP = 40
local FOOT_W, FOOT_H, FOOT_X, FOOT_Y, FOOT_GAP = 220, 28, 15, 16, 14
-- The toggle's top right from the client's window's, beside its layout dropdown; Back from our window's top left.
local TOGGLE_X, TOGGLE_Y, TOGGLE_H = -20, -50, 26
local BACK_X, BACK_Y, BACK_W, BACK_H, ARROW = 14, -12, 44, 24, 16
local EDIT_MODE_SLASH = SLASH_EDITMODE1 or "/editmode"
local MODE_TITLE = L["UI_CLASSICUI_FOREVER_WINDOWS"]
local MODE_HELP = L["UI_CHECK_THE_WINDOWS_TO_MOVE"]
local UNSAVED = "FCUI_WINDOWS_UNSAVED"
local mode, modeToggle
-- The toggle pressed edit mode's close: our mode opens once it is shut (its unsaved changes prompt may hold it).
local closing = false
-- Where the client's window stood (UIParent units, top centre), for ours to open there.
local spotX, spotY
-- Places, sizes and unlocks as the mode opened or last saved; any other way out goes back to them, as edit mode does.
local saved

local function Picked() return Clean("editWindowsShown", ValidFlag) end

local function ShowPicked(on)
    local picked = Picked()
    for _, entry in ipairs(WINDOWS) do
        if not entry.gameEdit then ShowHandle(entry, on and picked[entry.key] == true) end
    end
    if not on then W.HideDialog() end
end

local function EachKey(fn)
    for _, entry in ipairs(WINDOWS) do fn(entry, entry.key) end
end

local function Snapshot()
    local snap = { pos = {}, scale = {}, free = {}, map = ns.db.mapUnlocked == true }
    for key, pos in pairs(Places()) do snap.pos[key] = { pos[1], pos[2] } end
    for key, scale in pairs(Scales()) do snap.scale[key] = scale end
    for key in pairs(Freed()) do snap.free[key] = true end
    snap.ring = {}
    for _, entry in ipairs(WINDOWS) do
        if entry.ringKey then snap.ring[entry.key] = ns.db[entry.ringKey] or false end
    end
    snap.set = {}
    for _, key in ipairs(DialogKeys()) do snap.set[key] = ns.db[key] or false end
    return snap
end

local function SamePlace(a, b)
    if not (a and b) then return a == b end
    return math.abs(a[1] - b[1]) < 0.5 and math.abs(a[2] - b[2]) < 0.5
end

-- Against snap, else ours as last saved.
local function Dirty(snap)
    snap = snap or saved
    if not snap then return false end
    if (ns.db.mapUnlocked == true) ~= snap.map then return true end
    for _, key in ipairs(DialogKeys()) do
        if (ns.db[key] or false) ~= snap.set[key] then return true end
    end
    for _, entry in ipairs(WINDOWS) do
        if entry.ringKey and (ns.db[entry.ringKey] or false) ~= snap.ring[entry.key] then return true end
    end
    local places, scales, freed = Places(), Scales(), Freed()
    local dirty = false
    EachKey(function(_, key)
        if dirty then return end
        dirty = not SamePlace(places[key], snap.pos[key])
            or math.abs((scales[key] or 1) - (snap.scale[key] or 1)) > 0.001
            or (freed[key] == true) ~= (snap.free[key] == true)
    end)
    return dirty
end

-- Back to the snapshot; apply = false (logout) writes the saved tables only.
local function Restore(snap, apply)
    local places, scales, freed = Places(), Scales(), Freed()
    for _, entry in ipairs(WINDOWS) do
        if entry.ringKey then
            Set(entry.ringKey, snap.ring[entry.key] or nil)
            if apply then Return(entry) end
        end
    end
    EachKey(function(entry, key)
        local frame = _G[entry.name]
        local placed = places[key] ~= nil
        local pos = snap.pos[key]
        places[key] = pos and { pos[1], pos[2] } or nil
        scales[key] = snap.scale[key]
        freed[key] = snap.free[key]
        if apply and frame and placed and not places[key] then Return(entry) end
    end)
    if (ns.db.mapUnlocked == true) ~= snap.map then
        Set("mapUnlocked", snap.map)
        if apply then ns.ToggleChanged("mapUnlocked") end
    end
    local changed = {}
    for _, key in ipairs(DialogKeys()) do
        if (ns.db[key] or false) ~= snap.set[key] then
            Set(key, snap.set[key] or nil)
            changed[#changed + 1] = key
        end
    end
    if apply and #changed > 0 then ns.TogglesChanged(changed) end
    if not apply then return end
    PlaceAll()
    for _, entry in ipairs(WINDOWS) do LayHandle(entry) end
    Refresh()
end

local function Save() saved = Snapshot() end
local function RevertAll() if saved then Restore(saved, true) end end

-- gameEdit pieces (the gryphons) move in the game's own edit mode: their boxes up while it is, and its Save and Revert
-- All settle them too. Left without either, a change is kept (as the micro menu's).
local gameSaved

-- A classic layout reset settles both snapshots: else the mode left open put the old places back at logout.
function ns.SettleWindowEdits()
    if saved then saved = Snapshot() end
    if gameSaved then gameSaved = Snapshot() end
end

-- Only with the classic bar on: its gryphons exist then.
local function GameBoxes(on)
    on = on and ns.ClassicBarActive and ns.ClassicBarActive()
    for _, entry in ipairs(WINDOWS) do
        if entry.gameEdit then ShowHandle(entry, on) end
    end
end

local function GameFootClick(revert)
    if not gameSaved then return end
    if revert and Dirty(gameSaved) then Restore(gameSaved, true) end
    gameSaved = Snapshot()
end

local function SyncGameFoot()
    if gameSaved and Dirty(gameSaved) then ns.LightEditFoot("windowsHooked", GameFootClick) end
end

-- data: "close" when the close button asked; Back stays up (the choice made, it goes back on the next press).
-- The client's own exit prompt, in its words and order: Save and Exit, Exit (drops the changes), Cancel.
ns.Popup(UNSAVED, {
    text = _G.HUD_EDIT_MODE_UNSAVED_CHANGES_EXIT_DIALOG_TITLE
        or L["UI_IF_YOU_EXIT_NOW_YOU"],
    button1 = _G.HUD_EDIT_MODE_SAVE_AND_EXIT or "Save and Exit",
    button2 = _G.HUD_EDIT_MODE_EXIT or "Exit",
    button3 = CANCEL,
    OnAccept = function(_, data)
        Save()
        if data == "close" and mode then mode:Hide() end
    end,
    OnCancel = function(_, data, reason)
        if reason ~= "clicked" then return end
        RevertAll()
        if data == "close" and mode then mode:Hide() end
    end,
    OnAlt = function() end,
    -- Escape is Cancel, as on the client's.
    OnEscape = function() end,
})

local function TryClose()
    if Dirty() then
        StaticPopup_Show(UNSAVED, nil, nil, "close")
    else
        mode:Hide()
    end
end

local TOGGLE_TIP = { text = MODE_TITLE, r = 1, g = 1, b = 1, lines = { {
    L["UI_SWITCH_TO_MOVING_THE_CLASSICUI"], nil, nil, nil, true } } }
local BACK_TIP = { text = L["UI_BACK_TO_REGULAR_EDIT_MODE"], r = 1, g = 1, b = 1, lines = { {
    L["UI_THE_HUD_EDIT_MODE_SAVE"], nil, nil, nil, true } } }

-- On the client's window: the check and its label under one button, which its pad covers whole.
local function Toggle()
    local hit = CreateFrame("Button", nil, UIParent)
    hit:SetHeight(TOGGLE_H)
    local check = ns.NewFrame("CheckButton", nil, hit, "UICheckButtonTemplate")
    check:SetSize(TOGGLE_H, TOGGLE_H)
    check:SetPoint("LEFT", hit, "LEFT", 0, 0)
    check:EnableMouse(false)
    ns.EditModeCheck(check)
    local label = check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", check, "RIGHT", 2, 0)
    label:SetText(MODE_TITLE)
    hit:SetWidth(TOGGLE_H + 4 + math.ceil(label:GetStringWidth()))
    ns.AttachTip(hit, TOGGLE_TIP)
    hit:HookScript("OnEnter", function() check:LockHighlight() end)
    hit:HookScript("OnLeave", function() check:UnlockHighlight() end)
    -- Reached only without its pad (a fight, or a moment after a drag): edit mode never shuts from our code.
    hit:SetScript("OnClick", function() if InCombatLockdown() then ns.SayNotInCombat() end end)
    return hit
end

local function PromptUp()
    local prompt = _G["EditModeUnsavedChangesDialog"]
    return prompt ~= nil and prompt:IsShown()
end

-- Each frame while edit mode shows: the toggle on the client's window by measure (a frame hung on it would lose the
-- window its anchor on a drag), and a press the prompt cancelled forgotten.
local function Follow()
    local mgr = EditModeManagerFrame
    if closing and ns.EditMode.Live() and not PromptUp() then closing = false end
    local k = mgr and Ratio(mgr)
    local left, right, top = mgr and Plain(mgr:GetLeft()), mgr and Plain(mgr:GetRight()), mgr and Plain(mgr:GetTop())
    if not (k and left and right and top) then return end
    spotX, spotY = (left + right) / 2 * k, top * k
    local x, y = right * k + TOGGLE_X, top * k + TOGGLE_Y
    if not ns.IsAt(modeToggle, "TOPRIGHT", UIParent, "BOTTOMLEFT", x, y) then
        ns.SetPointOnce(modeToggle, "TOPRIGHT", UIParent, "BOTTOMLEFT", x, y)
    end
    ns.SetLevelIf(modeToggle, mgr:GetFrameLevel() + 20)
end

local function PressedClose() closing = true end

local function ModeToggle()
    if modeToggle then return modeToggle end
    modeToggle = Toggle()
    modeToggle:SetFrameStrata("DIALOG")
    modeToggle:Hide()
    ns.Sched.Attach(modeToggle, { name = "windows.follow", every = 0, fn = Follow })
    ns.Sched.Attach(modeToggle, { name = "windows.gameDirty", every = 0.2, fn = SyncGameFoot })
    local close = EditModeManagerFrame and EditModeManagerFrame.CloseButton
    if close then ns.MapPad(modeToggle, "DIALOG", PressedClose, close, nil, true) end
    return modeToggle
end

local function SyncToggle()
    local mgr = EditModeManagerFrame
    if mgr and ns.db and mgr:IsVisible() and ns.EditMode.Live() then
        local toggle = ModeToggle()
        Follow()
        if not toggle:IsShown() then toggle:Show() end
    elseif modeToggle and modeToggle:IsShown() then
        modeToggle:Hide()
    end
end

local function ModeCheck(entry, index, top)
    local col, row = (index - 1) % 2, math.floor((index - 1) / 2)
    local check = ns.NewFrame("CheckButton", nil, mode, "UICheckButtonTemplate")
    check:SetSize(ROW_H, ROW_H)
    check:SetPoint("TOPLEFT", mode, "TOPLEFT", MODE_PAD + col * ROW_W, -(top + row * ROW_H))
    check:SetHitRectInsets(0, -(ROW_W - ROW_H), 0, 0)
    ns.EditModeCheck(check)
    local label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    label:SetPoint("LEFT", check, "RIGHT", 5, 0)
    label:SetText(entry.label)
    check.entry = entry
    check:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        Picked()[self.entry.key] = on or nil
        ShowHandle(self.entry, on)
    end)
    return check
end

local function FootButton(text, point, x, onClick)
    local button = ns.NewFrame("Button", nil, mode, "UIPanelButtonTemplate")
    button:SetSize(FOOT_W, FOOT_H)
    button:SetPoint(point, mode, point, x, FOOT_Y)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    ns.EditModeRed(button)
    return button
end

-- Back runs /editmode through its pad; with changes unsaved the pad stands down and Back asks first.
local function BackMacro()
    if Dirty() then return nil end
    return EDIT_MODE_SLASH
end

local function BackClick()
    if InCombatLockdown() then
        ns.SayNotInCombat()
    elseif Dirty() then
        StaticPopup_Show(UNSAVED, nil, nil, "back")
    end
end

local function NoOp() end

local function SyncFoot()
    local dirty = Dirty()
    mode.save:SetEnabled(dirty)
    mode.revert:SetEnabled(dirty)
end

local function Mode()
    if mode then return mode end
    -- The windows first, then each piece section (the minimap's) under its own heading; gameEdit pieces have no row.
    local windows, sections, byTitle = {}, {}, {}
    for _, entry in ipairs(WINDOWS) do
        local title = entry.section
        if title and not entry.gameEdit then
            local list = byTitle[title]
            if not list then
                list = { title = title }
                byTitle[title] = list
                sections[#sections + 1] = list
            end
            list[#list + 1] = entry
        elseif not entry.gameEdit then
            windows[#windows + 1] = entry
        end
    end
    local tall = MODE_TOP + math.ceil(#windows / 2) * ROW_H
    for _, list in ipairs(sections) do
        list.top = tall + SECTION_GAP
        tall = list.top + math.ceil(#list / 2) * ROW_H
    end
    -- Under a window's own dialog (200), children and all: lowered after they were made, its close stood over it.
    mode = ns.band.EditDialog("ForeverClassicUIWindowsEditMode", MODE_W, tall + FOOT_GAP + FOOT_H + FOOT_Y, MODE_TITLE, 150)
    mode.close:SetScript("OnClick", TryClose)
    local back = ns.NewFrame("Button", nil, mode, "UIPanelButtonTemplate")
    back:SetSize(BACK_W, BACK_H)
    back:SetPoint("TOPLEFT", mode, "TOPLEFT", BACK_X, BACK_Y)
    ns.EditModeRed(back)
    local arrow = back:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(ARROW, ARROW)
    arrow:SetPoint("CENTER", back, "CENTER", 0, 0)
    arrow:SetAtlas("common-icon-backarrow")
    back:SetScript("OnClick", BackClick)
    ns.AttachTip(back, BACK_TIP)
    ns.MapPad(back, "DIALOG", NoOp, BackMacro)
    local help = mode:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    help:SetPoint("TOPLEFT", mode, "TOPLEFT", MODE_PAD + 5, -46)
    help:SetWidth(MODE_W - 2 * MODE_PAD - 10)
    help:SetJustifyH("LEFT")
    help:SetText(MODE_HELP)
    local head = mode:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    head:SetPoint("BOTTOMLEFT", mode, "TOPLEFT", MODE_PAD + 5, -(MODE_TOP - 6))
    head:SetText(L["UI_WINDOWS"])
    mode.checks = {}
    for i, entry in ipairs(windows) do mode.checks[#mode.checks + 1] = ModeCheck(entry, i, MODE_TOP) end
    for _, list in ipairs(sections) do
        local sub = mode:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        sub:SetPoint("BOTTOMLEFT", mode, "TOPLEFT", MODE_PAD + 5, -(list.top - 6))
        sub:SetText(list.title)
        for i, entry in ipairs(list) do mode.checks[#mode.checks + 1] = ModeCheck(entry, i, list.top) end
    end
    mode.revert = FootButton(HUD_EDIT_MODE_REVERT_ALL_CHANGES or "Revert All Changes", "BOTTOMLEFT", FOOT_X, RevertAll)
    mode.save = FootButton(HUD_EDIT_MODE_SAVE_LAYOUT or "Save", "BOTTOMRIGHT", -FOOT_X, Save)
    ns.Sched.Attach(mode, { name = "windows.dirty", every = 0.2, fn = SyncFoot })
    mode:SetScript("OnShow", function(self)
        Save()
        local picked = Picked()
        for _, check in ipairs(self.checks) do check:SetChecked(picked[check.entry.key] == true) end
        ShowPicked(true)
        SyncFoot()
    end)
    mode:SetScript("OnHide", function()
        if Dirty() then RevertAll() end
        saved = nil
        ShowPicked(false)
    end)
    return mode
end

local function OpenMode()
    local m = Mode()
    if spotX then
        ns.SetPointOnce(m, "TOP", UIParent, "BOTTOMLEFT", spotX, spotY)
    elseif m:GetNumPoints() == 0 then
        m:SetPoint("TOP", UIParent, "TOP", 0, -100)
    end
    m:Show()
end

local watched = false
local function QueueSync() ns.Sched.NextFrame("windows.toggle", SyncToggle) end

-- The client's edit mode opening shuts ours; shut after the toggle's press, ours opens.
local function OnEditMode()
    local mgr = EditModeManagerFrame
    if not (mgr and ns.db) then return end
    if not watched then
        watched = true
        -- Under its Border: the manager is a resize layout frame and counts its children.
        ns.Sched.OnVisible(mgr.Border or mgr, "windowsToggle", QueueSync)
    end
    SyncToggle()
    if ns.EditMode.Live() then
        closing = false
        if mode and mode:IsShown() then mode:Hide() end
        gameSaved = gameSaved or Snapshot()
        GameBoxes(true)
        return
    end
    GameBoxes(false)
    gameSaved = nil
    if closing then
        closing = false
        OpenMode()
    end
end
ns.OnEditMode(OnEditMode)

-- Logging out with the mode up leaves nothing unsaved behind.
ns.EventFrame("PLAYER_LOGOUT", function()
    if mode and mode:IsShown() and saved and Dirty() then Restore(saved, false) end
end)
