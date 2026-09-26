local _, ns = ...

-- Queue eye (its own edit mode system), placed from Minimap.lua's Layout: on the rim until
-- the player moves it. Stays UIParent's child: under the minimap a saved place restored wrong.

local MM = ns.MM

-- The client eye is 43px with its own gold rim: scale it under our border, drawn from a frame above.
local EYE_SCALE = 0.64
local EYE_RING = { own = "border", layer = "OVERLAY", w = 52, h = 52, point = "TOPLEFT", x = 1, y = -1 }
-- Outside edit mode only these move or resize the eye (probe P2); the spec change can switch the active layout.
local EYE_EVENTS = { "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "PLAYER_ENTERING_WORLD",
    "PLAYER_SPECIALIZATION_CHANGED" }
local EYE_LOOK = 0.3   -- polling after each wake, for a client move that lands a few frames late

local eyeWatch
local sizeReset
local lookUntil = 0

local function EyeMoved(eye)
    return ns.InDefaultPosition(eye) == false
end

-- Written as the interface reloads, never mid-game.
local function DefaultSizeClick() ns.AskSizeReset("eyeSize", "group finder eye") end

-- Default Size beside Revert Changes for the eye.
local function SizeResetButton()
    local dialog, eye = EditModeSystemSettingsDialog, QueueStatusButton
    local revert = dialog and dialog.Buttons and dialog.Buttons.RevertChangesButton
    if not revert or not eye then return end
    local show = MM.active and dialog:IsShown() and dialog.attachedToSystem == eye and revert:IsVisible()
    if not sizeReset then
        if not show then return end
        sizeReset = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
        sizeReset:SetFrameStrata("DIALOG")
        sizeReset:SetText("Default Size")
        sizeReset:SetScript("OnClick", DefaultSizeClick)
    end
    if show then
        local scale = dialog:GetEffectiveScale() / UIParent:GetEffectiveScale()
        sizeReset:SetScale(scale > 0 and scale or 1)
        sizeReset:SetFrameLevel(dialog:GetFrameLevel() + 20)
        ns.SetPointOnce(sizeReset, "LEFT", revert, "RIGHT", 6, 0)
        sizeReset:SetSize(144, 28)
        sizeReset:SetEnabled(not ns.Near(eye:GetScale(), 1, 0.001))
    end
    sizeReset:SetShown(show)
end

local function PlaceEye()
    local eye, backdrop = QueueStatusButton, MinimapBackdrop
    if not eye or not backdrop then return end
    eye:SetSize(33, 33)
    -- Centred on the border's hole (measured): 0.5px right; the art sits 1px above its frame.
    if eye.Eye and eye.Eye.SetScale then
        eye.Eye:SetScale(EYE_SCALE)
        ns.SetPointOnce(eye.Eye, "CENTER", eye, "CENTER", 0.5 / EYE_SCALE, (0.5 - EYE_SCALE) / EYE_SCALE)
    end
    -- Border and eye are the button's children, so edit mode's size scales both.
    local over = eye.fcuiOver
    if not over then
        over = CreateFrame("Frame", nil, eye)
        over:SetAllPoints(eye)
        eye.fcuiOver = over
    end
    over:SetFrameLevel((eye.Eye and eye.Eye:GetFrameLevel() or eye:GetFrameLevel()) + 5)
    ns.DressNew(over, "trackingBorder", EYE_RING, eye)
    -- On the rim the minimap's edit mode box covers the eye's: lift it to HIGH.
    if eye.Selection and eye.Selection.SetFrameStrata and eye.Selection:GetFrameStrata() ~= "HIGH" then
        eye.Selection:SetFrameStrata("HIGH")
    end
    local dragging = eye.IsDragging and eye:IsDragging()
    if EyeMoved(eye) or dragging or InCombatLockdown() then return end
    if eye:GetParent() ~= UIParent then eye:SetParent(UIParent) end
    -- Scale is edit mode's; anchor the centre in its own units so it grows in place.
    local own = eye:GetEffectiveScale()
    local k = (own and own > 0) and (backdrop:GetEffectiveScale() / own) or 1
    ns.SetPointOnce(eye, "CENTER", backdrop, "TOPLEFT", 38.5 * k, -116.5 * k)
end
MM.PlaceEye = PlaceEye

-- Sole writer of the eye watch's sleep (R8): awake through edit mode, else a short look after each wake.
local function SetEyeWatch(awake)
    if awake then
        lookUntil = GetTime() + EYE_LOOK
        eyeWatch:Wake()
        eyeWatch:Kick()
    else
        eyeWatch:Sleep()
    end
end

-- No events for moves, resets or size changes in edit mode: poll there. The settings dialog shows only in edit mode.
local function EyeTick(job, now)
    local editing = ns.EditMode.state
    if editing then SizeResetButton() end
    if MM.active and QueueStatusButton then
        local moved = EyeMoved(QueueStatusButton)
        local scale = QueueStatusButton:GetEffectiveScale()
        if moved ~= job.moved or scale ~= job.scale then
            job.moved, job.scale = moved, scale
            PlaceEye()
        end
    end
    if not editing and now >= lookUntil then SetEyeWatch(false) end
end

-- Entry wakes the poll; exit takes one look (the client reverts or saves the layout), and the dialog, ours with it.
local function EditEdge()
    if not ns.EditMode.state and sizeReset then sizeReset:Hide() end
    SetEyeWatch(true)
end

local function EyeEvent()
    SetEyeWatch(true)
end

-- Created at the first Layout with an eye (after the bar's Init made the edit poll); runs with the module on or off.
function MM.WatchEye()
    if eyeWatch then return end
    eyeWatch = ns.Sched.Job({ name = "minimap.eye", every = 0.1, fn = EyeTick, awake = false })
    local events = CreateFrame("Frame")
    events:SetScript("OnEvent", EyeEvent)
    ns.RegisterEvents(events, EYE_EVENTS)
    ns.OnEditMode(EditEdge)
    SetEyeWatch(true)
end
