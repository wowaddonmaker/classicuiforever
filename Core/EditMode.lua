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
