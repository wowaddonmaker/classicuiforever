local _, ns = ...

-- Queue eye (its own edit mode system), placed from Minimap.lua's Layout: on the rim until
-- the player moves it. Stays UIParent's child: under the minimap a saved place restored wrong.

local MM = ns.MM

-- The client eye is 43px with its own gold rim: scale it under our border, drawn from a frame above.
local EYE_SCALE = 0.64
local EYE_RING = { own = "border", layer = "OVERLAY", w = 52, h = 52, point = "TOPLEFT", x = 1, y = -1 }

local eyeWatch
local sizeReset

local function EyeMoved(eye)
    return ns.InDefaultPosition(eye) == false
end

local function DefaultSizeClick()
    local dialog = EditModeSystemSettingsDialog
    local setting = Enum.EditModeGroupFinderSetting and Enum.EditModeGroupFinderSetting.Size
    if not setting or InCombatLockdown() then return end
    -- Our layout write: a reload is asked for once edit mode closes.
    if pcall(dialog.OnSettingValueChanged, dialog, setting, 100) then ns.editWrote = true end
end

-- Default Size beside Revert Changes for the eye; uses the dialog's own change path
-- so the slider, unsaved mark and Revert follow.
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
        sizeReset:ClearAllPoints()
        sizeReset:SetPoint("LEFT", revert, "RIGHT", 6, 0)
        sizeReset:SetSize(144, 28)
        sizeReset:SetEnabled(math.abs((eye:GetScale() or 1) - 1) > 0.001)
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
        eye.Eye:ClearAllPoints()
        eye.Eye:SetPoint("CENTER", eye, "CENTER", 0.5 / EYE_SCALE, (0.5 - EYE_SCALE) / EYE_SCALE)
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

-- No events for moves, resets or size changes: poll.
local function EyeTick(job)
    SizeResetButton()
    if not MM.active or not QueueStatusButton then return end
    local moved = EyeMoved(QueueStatusButton)
    local scale = QueueStatusButton:GetEffectiveScale()
    if moved ~= job.moved or scale ~= job.scale then
        job.moved, job.scale = moved, scale
        PlaceEye()
    end
end

-- Created at the first Layout with an eye; runs with the module on or off.
function MM.WatchEye()
    if eyeWatch then return end
    eyeWatch = ns.Sched.Job({ name = "minimap.eye", every = 0.1, fn = EyeTick })
end
