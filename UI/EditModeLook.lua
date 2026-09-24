local _, ns = ...

-- Edit mode's windows and the quick keybind window in the old dialog box on the game menu toggle, bronze with the theme.
-- Textures, alpha and our own overlays only: no hooks, no fields on client frames, no layout writes.

local B = ns.bronze
local KEYS = ns.KEYS
local weak = { __mode = "k" }

local borders = setmetatable({}, weak)   -- client dialog border -> true
local pieces = setmetatable({}, weak)    -- client bronze trim -> drain grey or false
local files = setmetatable({}, weak)     -- state texture -> { path, atlas, button }
local held = setmetatable({}, weak)      -- trim the client re-colours on enable -> its button
local reds = setmetatable({}, weak)      -- red panel button piece -> true
local rowsSeen = setmetatable({}, weak)
local plates = setmetatable({}, weak)    -- client dialog header -> its host
local active, staticDone, watchJob = false, false, nil
local qkDone = false
local rowCount, buttonCount = -1, -1

-- No import link dialog: the client never builds it (commented out in EditModeDialogs.xml).
local DIALOGS = { "EditModeLayoutDialog", "EditModeImportLayoutDialog", "EditModeUnsavedChangesDialog" }
local DIALOG_BUTTONS = { "AcceptButton", "CancelButton", "SaveAndProceedButton", "ProceedButton" }
local RED_PIECES = { "Left", "Middle", "Right" }
local QK_BUTTONS = { "DefaultsButton", "CancelButton", "OkayButton" }
local INPUT_EDGES = { "TopLeftTex", "TopRightTex", "TopTex", "BottomLeftTex", "BottomRightTex", "BottomTex",
    "LeftTex", "RightTex" }
-- The client's X atlases (UIPanelCloseButtonNoScripts), put back on restore; GetAtlas may be secret.
local CLOSE = {
    { "Normal", "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", "RedButton-Exit" },
    { "Pushed", "Interface\\Buttons\\UI-Panel-MinimizeButton-Down", "RedButton-exit-pressed" },
    { "Disabled", "Interface\\Buttons\\UI-Panel-MinimizeButton-Disabled", "RedButton-Exit-Disabled" },
    { "Highlight", "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "RedButton-Highlight" },
}
local CHECK = {
    { "Normal", "Interface\\Buttons\\UI-CheckBox-Up" },
    { "Pushed", "Interface\\Buttons\\UI-CheckBox-Down" },
}
-- The 24 px X drawn at the old 32 px size.
local CLOSE_OUT = 4

------------------------------------------------------------------ borders

local function Border(border)
    if not border or borders[border] then return end
    borders[border] = true
    if active then ns.OldDialogBorder(border, true) end
end

-- DialogHeaderTemplate: its diamond pieces fade under our old plate, the client's title stays.
local function Header(header, host)
    if not header or plates[header] then return end
    plates[header] = host
    if active then ns.OldDialogHeader(header, host, true) end
end

------------------------------------------------------------------- trim

-- button: the client desaturates this piece by that button's enable state.
local function Piece(region, grey, button)
    if not region or not region.SetDesaturated or pieces[region] ~= nil then return end
    pieces[region] = grey or false
    if button then held[region] = button end
    if active then ns.DrainBronze(region, grey) end
end

local function EachTex(frame, button)
    if frame then ns.EachTexture(frame, Piece, nil, button) end
end

local function Dropdown(dropdown)
    if not dropdown then return end
    Piece(dropdown.Background, nil, dropdown)
    Piece(dropdown.Arrow, nil, dropdown)
end

-- MinimalSliderWithSteppersTemplate.
local function Slider(steppers)
    if not steppers then return end
    local slider = steppers.Slider
    if slider then
        ns.EachKey(slider, KEYS.LRM, Piece)
        if slider.GetThumbTexture then Piece(slider:GetThumbTexture()) end
    end
    EachTex(steppers.Back, steppers.Back)
    EachTex(steppers.Forward, steppers.Forward)
end

-- MinimalScrollBar.
local function ScrollBar(bar)
    if not bar then return end
    local track = bar.Track
    if track then
        ns.EachKey(track, KEYS.THUMB, Piece)
        ns.EachKey(track.Thumb, KEYS.THUMB, Piece, nil, track.Thumb)
    end
    EachTex(bar.Back, bar.Back)
    EachTex(bar.Forward, bar.Forward)
end

-- UIPanelButtonTemplate: the client's red file, its bronze copy with the theme.
local function Red(button)
    if not button or not (button.Left and button.Middle and button.Right) then return end
    for i = 1, #RED_PIECES do
        local tex = button[RED_PIECES[i]]
        if not reds[tex] then
            reds[tex] = true
            if active then ns.BronzeClientTexture(tex) end
        end
    end
end

------------------------------------------------------------ state files

local function ApplyFile(tex, info)
    ns.SetFile(tex, info.path)
    local button = info.button
    if button then
        tex:SetTexCoord(0, 1, 0, 1)
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", button, "TOPLEFT", -CLOSE_OUT, CLOSE_OUT)
        tex:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", CLOSE_OUT, -CLOSE_OUT)
    end
end

local function Unfile(tex, info)
    B.swapped[tex] = nil
    if info.atlas then
        tex:SetAtlas(info.atlas)
        tex:ClearAllPoints()
        tex:SetAllPoints(info.button)
    else
        tex:SetTexture(info.path)
    end
end

local function StateFiles(button, states, placed)
    if not button then return end
    for i = 1, #states do
        local state = states[i]
        local getter = button["Get" .. state[1] .. "Texture"]
        local tex = getter and getter(button)
        if tex and not files[tex] then
            local info = { path = state[2], atlas = placed and state[3] or nil, button = placed and button or nil }
            files[tex] = info
            if active then ApplyFile(tex, info) end
        end
    end
end

local function CloseX(button)
    StateFiles(button, CLOSE, true)
end

-- Already the 1.x files; with the theme they take the bronze copies.
local function Check(button)
    StateFiles(button, CHECK, false)
end

local function WalkChecks(frame, depth)
    if not frame or depth > 8 then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsObjectType("CheckButton") then
            Check(child)
        else
            WalkChecks(child, depth + 1)
        end
    end
end

----------------------------------------------------------------- frames

-- Everything made at load; the settings dialog's rows come later from pools.
local function DressStatic()
    local manager = EditModeManagerFrame
    if not manager then return false end
    Border(manager.Border)
    CloseX(manager.CloseButton)
    Red(manager.SaveChangesButton)
    Red(manager.RevertAllChangesButton)
    Dropdown(manager.LayoutDropdown)
    Slider(manager.GridSpacingSlider and manager.GridSpacingSlider.Slider)
    local container = manager.AccountSettings and manager.AccountSettings.SettingsContainer
    if container then
        ScrollBar(container.ScrollBar)
        EachTex(container.BorderArt)
    end
    WalkChecks(manager, 0)
    local dialog = EditModeSystemSettingsDialog
    if dialog then
        Border(dialog.Border)
        CloseX(dialog.CloseButton)
    end
    for i = 1, #DIALOGS do
        local frame = _G[DIALOGS[i]]
        if frame then
            Border(frame.Border)
            ns.EachKey(frame.LayoutNameEditBox, KEYS.LMR, Piece, 0.85)
            local box = frame.ImportBox
            if box then
                ns.EachKey(box, INPUT_EDGES, Piece)
                ScrollBar(box.ScrollBar)
            end
            ns.EachKey(frame, DIALOG_BUTTONS, Red)
            WalkChecks(frame, 0)
        else
            ns.MissingPiece(DIALOGS[i])
        end
    end
    return true
end

-- The settings pools only grow: dress rows not met before.
local function Rows(settings)
    local count = settings:GetNumChildren()
    if count == rowCount then return end
    rowCount = count
    for _, row in ipairs({ settings:GetChildren() }) do
        if not rowsSeen[row] then
            rowsSeen[row] = true
            Dropdown(row.Dropdown)
            Slider(row.Slider)
            local button = row.Button
            if button and button.IsObjectType and button:IsObjectType("CheckButton") then Check(button) end
        end
    end
end

-- Revert Changes and the pooled extra buttons.
local function DialogButtons(buttons)
    local count = buttons:GetNumChildren()
    if count == buttonCount then return end
    buttonCount = count
    for _, button in ipairs({ buttons:GetChildren() }) do Red(button) end
end

-- A disabled piece keeps the client's grey; the theme's repaint and our restore clear it.
local function Disabled(region)
    local button = held[region]
    return button ~= nil and button.IsEnabled ~= nil and not button:IsEnabled()
end

-- Steppers, scroll arrows and dropdowns reset their desaturation on each state change, and
-- red buttons their file on show, press and enable: put ours back before the frame draws.
local function Hold()
    local bronze = ns.BronzeOn()
    for region in pairs(held) do
        if not region:IsDesaturated() then
            if not bronze then
                ns.DrainBronze(region, pieces[region] or nil)
            elseif Disabled(region) then
                region:SetDesaturated(true)
            end
        end
    end
    for tex in pairs(reds) do ns.BronzeClientTexture(tex) end
end

-- Every frame while edit mode is open.
local function EachFrame()
    if not active then return end
    local dialog = EditModeSystemSettingsDialog
    if dialog and dialog:IsShown() then
        if dialog.Settings then Rows(dialog.Settings) end
        if dialog.Buttons then DialogButtons(dialog.Buttons) end
    end
    Hold()
end

local function Pass()
    if active and not staticDone and not InCombatLockdown() then staticDone = DressStatic() end
end

local function Noop() end

-- Every frame while the quick keybind window is open: edit mode is hidden then.
local function QKFrame()
    if active then Hold() end
end

-- QuickKeybindFrame is protected: new children out of combat only.
local function DressQuickKeybind()
    if qkDone or not active or InCombatLockdown() then return end
    qkDone = true
    local frame = _G.QuickKeybindFrame
    if not frame then
        ns.MissingPiece("QuickKeybindFrame")
        return
    end
    Border(frame.BG)
    Header(frame.Header, frame)
    Check(frame.UseCharacterBindingsButton)
    ns.EachKey(frame, QK_BUTTONS, Red)
    -- A pure watcher under BG: runs only while the window is shown.
    local host = frame.BG or frame
    ns.Sched.OnFrame(CreateFrame("Frame", nil, host), { name = "quickKeybind.look", every = 1, fn = Noop, pre = QKFrame })
end

-- A pure watcher under the manager's Border (ignoreInLayout): runs only while edit mode is open.
local function StartWatch()
    if watchJob then
        watchJob:Kick()
        return
    end
    local host = EditModeManagerFrame and EditModeManagerFrame.Border
    if not host then return end
    local watch = CreateFrame("Frame", nil, host)
    watchJob = ns.Sched.OnFrame(watch, { name = "editMode.look", every = 0.1, fn = Pass, pre = EachFrame })
end

local function Apply()
    if active then return end
    active = true
    for border in pairs(borders) do ns.OldDialogBorder(border, true) end
    for region, grey in pairs(pieces) do ns.DrainBronze(region, grey or nil) end
    for tex, info in pairs(files) do ApplyFile(tex, info) end
    for tex in pairs(reds) do ns.BronzeClientTexture(tex) end
    for header, host in pairs(plates) do ns.OldDialogHeader(header, host, true) end
    if not staticDone then staticDone = DressStatic() end
    if not qkDone then ns.WhenCalm("quickKeybind.look", DressQuickKeybind) end
    StartWatch()
end

local function Restore()
    if not active then return end
    active = false
    for border in pairs(borders) do ns.OldDialogBorder(border, false) end
    for region in pairs(pieces) do
        ns.UndrainBronze(region)
        if Disabled(region) then region:SetDesaturated(true) end
    end
    for tex, info in pairs(files) do Unfile(tex, info) end
    for tex in pairs(reds) do ns.BronzeClientTexture(tex, true) end
    for header, host in pairs(plates) do ns.OldDialogHeader(header, host, false) end
end

ns.RegisterModule("gameMenu", { apply = Apply, restore = Restore })

-- Our own panels beside edit mode's dialogs follow them.
ns.EditModeBorder = Border
ns.EditModeClose = CloseX
ns.EditModeSlider = Slider
ns.EditModeCheck = Check
ns.EditModeRed = Red
