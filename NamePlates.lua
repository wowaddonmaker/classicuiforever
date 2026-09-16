local _, ns = ...

-- 1.x nameplates were a plain health bar with a thin dark edge and the
-- name in white above it. Blizzard's nameplate unit frames keep all
-- their logic; each one gets the flat fill, a black backing and edge,
-- and loses the modern deselected overlay. Forbidden plates (instanced
-- content on 12.x) are left alone.

local active = false
local skinned = setmetatable({}, { __mode = "k" })

local function SkinPlate(unitFrame)
    if not active or not unitFrame or (unitFrame.IsForbidden and unitFrame:IsForbidden()) then return end
    local health = ns.Path(unitFrame, "HealthBarsContainer", "healthBar")
    if health then
        if health.barTexture then
            health.barTexture:SetAtlas(nil)
            ns.SetTex(health.barTexture, "statusBar")
            health.barTexture:SetTexCoord(0, 1, 0, 1)
        end
        if health.bgTexture then
            health.bgTexture:SetAtlas(nil)
            health.bgTexture:SetColorTexture(0, 0, 0, 0.6)
        end
        if health.deselectedOverlay then ns.Fade(health.deselectedOverlay) end
        local edge = ns.OwnTexture(health, "edge", "BACKGROUND", -2)
        edge:SetColorTexture(0, 0, 0, 0.8)
        edge:ClearAllPoints()
        edge:SetPoint("TOPLEFT", health, "TOPLEFT", -1, 1)
        edge:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 1, -1)
        edge:Show()
    end
    local cast = ns.Path(unitFrame, "CastBarsContainer", "castBar")
    if cast and cast.SetStatusBarTexture then
        cast:SetStatusBarTexture((ns.TexPath("statusBar")))
        local tex = cast:GetStatusBarTexture()
        if tex then tex:SetTexCoord(0, 1, 0, 1) end
        if cast.Background then
            cast.Background:SetAtlas(nil)
            cast.Background:SetColorTexture(0, 0, 0, 0.6)
        end
    end
    if unitFrame.name then
        unitFrame.name:SetFontObject("SystemFont_Outline_Small")
    end
    if not skinned[unitFrame] then
        skinned[unitFrame] = true
        ns.HookMethod(unitFrame, "ApplyFrameOptions", SkinPlate)
        ns.HookMethod(unitFrame, "UpdateIsTarget", SkinPlate)
    end
end

local function OnPlateAdded(_, unitToken)
    if not active then return end
    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit(unitToken)
    if plate and plate.UnitFrame then SkinPlate(plate.UnitFrame) end
end

local hooked = false

local function Apply()
    active = true
    if not NamePlateDriverFrame then ns.MissingPiece("NamePlateDriverFrame") return end
    if not hooked then
        hooked = true
        ns.HookMethod(NamePlateDriverFrame, "OnNamePlateAdded", OnPlateAdded)
    end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            if plate.UnitFrame then SkinPlate(plate.UnitFrame) end
        end
    end
end

local function Restore()
    active = false
    for unitFrame in pairs(skinned) do
        if unitFrame.fcui then
            for _, tex in pairs(unitFrame.fcui) do tex:Hide() end
        end
        local health = ns.Path(unitFrame, "HealthBarsContainer", "healthBar")
        if health and health.fcui then
            for _, tex in pairs(health.fcui) do tex:Hide() end
        end
    end
    ns.needsReload = true
end

ns.RegisterModule("namePlates", { apply = Apply, restore = Restore })
