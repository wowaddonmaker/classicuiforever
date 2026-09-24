local _, ns = ...

-- Sheet model: camera fit, rotate buttons, dev camera line.
-- Loads first: creates ns.sheet, and the spinner is the sheet's first load-time frame.

local T = {}
ns.sheet = T

-- The camera is framed for the wide pane, too close in 233x224; zoom out by the scene's
-- own steps, once per camera.
local MODEL_ZOOM_STEPS = 3
local function FitModelCamera()
    local scene = CharacterModelScene
    local camera = scene and scene.GetActiveCamera and scene:GetActiveCamera()
    if not camera or camera.fcuiFitted then return end
    camera.fcuiFitted = true
    T.camera = camera
    if type(scene.OnMouseWheel) == "function" then
        for _ = 1, MODEL_ZOOM_STEPS do pcall(scene.OnMouseWheel, scene, -1) end
    end
end
T.FitModelCamera = FitModelCamera

-- Zooms back in by the same steps when the sheet turns off.
function T.UnfitModelCamera()
    local scene, camera = CharacterModelScene, T.camera
    T.camera = nil
    if not scene or not camera or not camera.fcuiFitted then return end
    camera.fcuiFitted = nil
    local current = scene.GetActiveCamera and scene:GetActiveCamera()
    if current ~= camera or type(scene.OnMouseWheel) ~= "function" then return end
    for _ = 1, MODEL_ZOOM_STEPS do pcall(scene.OnMouseWheel, scene, 1) end
end

-- Fallback without camera yaw calls: half a turn per second while held.
-- Yaw goes through the actor, never a scene field the client reads back.
local spinner = CreateFrame("Frame")
spinner:Hide()
local function SheetActor(scene)
    local actor
    if scene.GetPlayerActor then actor = scene:GetPlayerActor() end
    if not actor and scene.GetActorByTag then actor = scene:GetActorByTag("player") end
    if not actor and type(scene.tagToActor) == "table" then
        actor = select(2, next(scene.tagToActor))
    end
    if actor and actor.GetYaw and actor.SetYaw then return actor end
end

spinner:SetScript("OnUpdate", function(self, elapsed)
    local scene = CharacterModelScene
    if not scene or not scene:IsVisible() then self:Hide() return end
    local step = self.turn * math.pi * elapsed
    local actor = self.actor or SheetActor(scene)
    if actor then
        actor:SetYaw((actor:GetYaw() or 0) + step)
        return
    end
    -- No figure: the camera goes round it instead.
    local camera = scene.GetActiveCamera and scene:GetActiveCamera()
    if camera and camera.GetYaw and camera.SetYaw then
        camera:SetYaw((camera:GetYaw() or 0) - step)
        if camera.SnapToTargetInterpolationYaw then camera:SnapToTargetInterpolationYaw() end
    else
        self:Hide()
    end
end)

-- Actor SetYaw shows nothing here; turn the camera like the client (DEFAULT_ROTATE_INCREMENT).
local ROTATE_STEP = 0.05
local function RotateStart(direction)
    local scene = CharacterModelScene
    if scene and scene.AdjustCameraYaw then
        scene:AdjustCameraYaw(direction, ROTATE_STEP)
        return
    end
    spinner.turn = direction == "left" and -1 or 1
    spinner.actor = scene and SheetActor(scene)
    spinner:Show()
end

local function RotateStop()
    local scene = CharacterModelScene
    if scene and scene.StopCameraYaw then scene:StopCameraYaw() end
    spinner:Hide()
    spinner.actor = nil
end

local function RotateButton(parent, artKey, direction, anchor, relPoint)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(35, 35)
    button:SetPoint("TOPLEFT", anchor, relPoint, 0, 0)
    button:SetNormalTexture((ns.TexPath(artKey .. "Up")))
    button:SetPushedTexture((ns.TexPath(artKey .. "Down")))
    button:SetHighlightTexture((ns.TexPath("roundHighlight")))
    button:GetHighlightTexture():SetBlendMode("ADD")
    button:RegisterForClicks("AnyDown", "AnyUp")
    -- Above the model, which takes the mouse over this corner.
    if CharacterModelScene then button:SetFrameLevel(CharacterModelScene:GetFrameLevel() + 10) end
    button:SetScript("OnMouseDown", function()
        RotateStart(direction)
        PlaySound(SOUNDKIT.IG_INVENTORY_ROTATE_CHARACTER)
    end)
    button:SetScript("OnMouseUp", RotateStop)
    button:SetScript("OnHide", RotateStop)
    return button
end

-- At the model's top left corner.
function T.BuildRotate(doll)
    if not CharacterModelScene then return end
    T.rotateRight = RotateButton(doll, "rotateLeft", "left", CharacterModelScene, "TOPLEFT")
    T.rotateLeft = RotateButton(doll, "rotateRight", "right", T.rotateRight, "TOPRIGHT")
end

-- Every scene transition brings a new camera; fit it too.
function T.HookModel()
    local scene = CharacterModelScene
    if not scene then return end
    if scene.TransitionToModelSceneID then
        ns.HookMethod(scene, "TransitionToModelSceneID", function()
            if T.active then C_Timer.After(0, FitModelCamera) end
        end)
    end
    scene:HookScript("OnShow", function()
        if T.active then C_Timer.After(0.1, FitModelCamera) end
    end)
end

-- For the dev probe; published as ns.CharacterCameraInfo on the first Apply.
function T.CameraInfo()
    local scene = CharacterModelScene
    local camera = scene and scene.GetActiveCamera and scene:GetActiveCamera()
    if not camera then return "no camera" end
    local ok, distance = pcall(function() return camera:GetZoomDistance() end)
    local okMax, max = pcall(function() return camera:GetMaxZoomDistance() end)
    return string.format("camera %s fitted %s zoom %s max %s", tostring(camera.GetDebugName and camera:GetDebugName() or "?"), tostring(camera.fcuiFitted), ok and tostring(distance) or "n/a", okMax and tostring(max) or "n/a")
end
