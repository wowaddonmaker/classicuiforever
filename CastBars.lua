local _, ns = ...

-- The 1.x cast bars. Blizzard's CastingBarMixin still carries the classic
-- style branch that Classic Era uses (classicStyleCastBar): 195x13 with
-- the old border sheet, UI-StatusBar fills in the old yellow, green, grey
-- and red, a static spark and none of the modern flakes, wisps and glow
-- lines. We turn that branch on for every bar and supply the three
-- textures the branch does not set itself (spark, flash, background).

local FX = { "Flakes01", "Flakes02", "Flakes03", "BaseGlow", "WispGlow", "Sparkles01", "Sparkles02", "Shine",
    "EnergyGlow", "InterruptGlow", "ChargeGlow", "ChargeFlash", "StandardGlow", "CraftGlow", "ChannelShadow", "DropShadow", "TextBorder" }

local active = false
local skinned = {}

-- The classic geometry of SetLook, done here because calling SetLook from
-- addon code makes Blizzard read protected cast values in our context.
local function Shape(bar)
    local look = bar.look or "CLASSIC"
    bar.playCastFX = false
    if look == "UNITFRAME" then
        bar:SetSize(150, 10)
        if bar.Border then
            ns.SetTex(bar.Border, "castBorderSmall")
            bar.Border:SetTexCoord(0, 1, 0, 1)
            bar.Border:ClearAllPoints()
            bar.Border:SetHeight(56)
            bar.Border:SetPoint("TOPLEFT", bar, "TOPLEFT", -23, 23)
            bar.Border:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 23, 23)
        end
        if bar.BorderShield then
            bar.BorderShield:ClearAllPoints()
            bar.BorderShield:SetHeight(56)
            bar.BorderShield:SetPoint("TOPLEFT", bar, "TOPLEFT", -28, 23)
            bar.BorderShield:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 18, 23)
        end
        if bar.Text then
            bar.Text:ClearAllPoints()
            bar.Text:SetHeight(16)
            bar.Text:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 4)
            bar.Text:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 4)
            bar.Text:SetFontObject("SystemFont_Shadow_Small")
        end
    elseif look == "CLASSIC" then
        bar:SetSize(195, 13)
        if bar.Border then
            ns.SetTex(bar.Border, "castBorder")
            bar.Border:SetTexCoord(0, 1, 0, 1)
            bar.Border:ClearAllPoints()
            bar.Border:SetSize(256, 64)
            bar.Border:SetPoint("TOP", bar, "TOP", 0, 28)
        end
        if bar.BorderShield then
            bar.BorderShield:ClearAllPoints()
            bar.BorderShield:SetSize(256, 64)
            bar.BorderShield:SetPoint("TOP", bar, "TOP", 0, 28)
        end
        if bar.Text then
            bar.Text:ClearAllPoints()
            bar.Text:SetSize(185, 16)
            bar.Text:SetPoint("TOP", bar, "TOP", 0, 5)
            bar.Text:SetFontObject("GameFontHighlight")
        end
    end
end

local function Dress(bar)
    if not active then return end
    Shape(bar)
    if bar.Background then
        bar.Background:SetAtlas(nil)
        bar.Background:SetColorTexture(0, 0, 0, 0.5)
        bar.Background:ClearAllPoints()
        bar.Background:SetAllPoints(bar)
    end
    if bar.Spark then
        ns.SetTex(bar.Spark, "castSpark")
        bar.Spark:SetTexCoord(0, 1, 0, 1)
        bar.Spark:SetSize(32, 32)
        bar.Spark:SetBlendMode("ADD")
    end
    if bar.Flash then
        local small = bar.look == "UNITFRAME"
        ns.SetTex(bar.Flash, small and "castFlashSmall" or "castFlash")
        bar.Flash:SetTexCoord(0, 1, 0, 1)
        bar.Flash:SetBlendMode("ADD")
        bar.Flash:ClearAllPoints()
        if small then
            bar.Flash:SetHeight(56)
            bar.Flash:SetPoint("TOPLEFT", bar, "TOPLEFT", -23, 23)
            bar.Flash:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 23, 23)
        else
            bar.Flash:SetSize(256, 64)
            bar.Flash:SetPoint("TOP", bar, "TOP", 0, 28)
        end
    end
    if bar.BorderShield then
        ns.SetTex(bar.BorderShield, bar.look == "UNITFRAME" and "castSmallShield" or "castBorder")
        bar.BorderShield:SetTexCoord(0, 1, 0, 1)
    end
    for _, key in ipairs(FX) do
        local region = bar[key]
        if region then
            if region.SetAtlas then region:SetAtlas(nil) end
            region:SetAlpha(0)
            region:Hide()
        end
    end
end

local function Skin(bar)
    if not bar then return end
    bar.classicStyleCastBar = true
    if not skinned[bar] then
        skinned[bar] = { look = bar.look }
        ns.HookMethod(bar, "SetLook", Dress)
        ns.HookMethod(bar, "UpdateShownState", Dress)
    end
    Dress(bar)
end

local function Apply()
    active = true
    Skin(PlayerCastingBarFrame)
    Skin(PetCastingBarFrame)
    if TargetFrame then Skin(TargetFrame.spellbar) end
    if FocusFrame then Skin(FocusFrame.spellbar) end
    local bosses = BossTargetFrameContainer and BossTargetFrameContainer.BossTargetFrames
    if bosses then
        for _, boss in pairs(bosses) do Skin(boss.spellbar) end
    end
end

local function Restore()
    active = false
    for bar in pairs(skinned) do
        bar.classicStyleCastBar = nil
        if bar.Border then bar.Border:SetAtlas("ui-castingbar-frame") end
        if bar.Spark then bar.Spark:SetAtlas("ui-castingbar-pip") end
        if bar.Flash then bar.Flash:SetAtlas("ui-castingbar-full-glow-standard") end
        if bar.Background then bar.Background:SetAtlas("ui-castingbar-background") end
        for _, key in ipairs(FX) do
            if bar[key] then bar[key]:SetAlpha(1) end
        end
    end
    ns.needsReload = true
end

ns.RegisterModule("castBars", { apply = Apply, restore = Restore })
