local _, ns = ...

-- Every edit mode query goes through here; watched, never hooked or listened to (ns.OnEditMode).

local EditMode = {}
ns.EditMode = EditMode

-- Last edge seen (a frame late, nil until login); per-frame code uses Live().
EditMode.state = nil

function EditMode.Live()
    local mgr = EditModeManagerFrame
    return mgr and mgr.IsEditModeActive and mgr:IsEditModeActive() and true or false
end

-- A box of ours picked takes the pick: the game's piece kept it, and the arrow keys moved that piece. The game's own
-- secure delegate, out of combat.
function EditMode.TakePick()
    local mgr = EditModeManagerFrame
    if InCombatLockdown() or not (EditMode.Live() and mgr.ClearSelectedSystem) then return end
    mgr:ClearSelectedSystem()
end

-- A piece of the game's picked: its settings dialog is up.
function EditMode.GamePicked()
    local dialog = EditModeSystemSettingsDialog
    return dialog ~= nil and dialog:IsShown()
end

-- nil when unknown (no method, uninitialized, secret, failed call); callers decide what nil means.
function ns.InDefaultPosition(frame, requireInitialized)
    if type(frame) ~= "table" or type(frame.IsInDefaultPosition) ~= "function" then return nil end
    if requireInitialized then
        if type(frame.IsInitialized) ~= "function" then return nil end
        local okInit, ready = pcall(frame.IsInitialized, frame)
        if not okInit or ns.IsSecret(ready) or not ready then return nil end
    end
    local ok, isDefault = pcall(frame.IsInDefaultPosition, frame)
    if not ok or ns.IsSecret(isDefault) or type(isDefault) ~= "boolean" then return nil end
    return isDefault
end

function ns.ActiveLayoutInfo()
    local mgr = EditModeManagerFrame
    if not (mgr and mgr.GetActiveLayoutInfo) then return nil end
    return mgr:GetActiveLayoutInfo()
end

-- A change of ours in edit mode lights its Save and Revert All (the widget's own Enable: no client field); each button is
-- hooked once per tag, onClick(revert) running after the client's own click.
local FOOT = { "SaveChangesButton", "RevertAllChangesButton" }
function ns.LightEditFoot(tag, onClick)
    local mgr = EditModeManagerFrame
    if not mgr then return end
    for _, key in ipairs(FOOT) do
        local button = mgr[key]
        if button then
            if not button:IsEnabled() then
                local raw = getmetatable(button)
                raw = raw and raw.__index
                if type(raw) == "table" and raw.Enable then raw.Enable(button) else button:Enable() end
            end
            if ns.Once(button, tag) then
                local revert = key == "RevertAllChangesButton"
                button:HookScript("OnClick", function() onClick(revert) end)
            end
        end
    end
end
