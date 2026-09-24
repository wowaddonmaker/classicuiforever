local _, ns = ...

-- 1.x cast bars: 195x13 in the old border, UI-StatusBar fill in the old colours, static spark, no modern FX.
-- Never write a field on a cast bar or call SetLook: an addon-set field taints later reads and the
-- bar's update trips on other units' secret cast values. Secure hooks re-dress after each change.

local Dress, FadeKeys, IsSecret = ns.Dress, ns.FadeKeys, ns.IsSecret

local FX = { "Flakes01", "Flakes02", "Flakes03", "BaseGlow", "WispGlow", "Sparkles01", "Sparkles02", "Shine",
    "EnergyGlow", "InterruptGlow", "ChargeGlow", "ChargeFlash", "StandardGlow", "CraftGlow", "ChannelShadow", "DropShadow", "TextBorder" }
local FINISH_ANIMS = { "StandardFinish", "ChannelFinish", "CraftingFinish" }
local HIDE_FX = { clearAtlas = true, hide = true }

local FULL = { 0, 1, 0, 1 }
local BORDER_SMALL = { coords = FULL, h = 56, point = "TOPLEFT", x = -23, y = 23, point2 = "TOPRIGHT", x2 = 23, y2 = 23 }
local BORDER = { coords = FULL, w = 256, h = 64, point = "TOP", y = 28 }
local SPARK = { coords = FULL, w = 32, h = 32, blend = "ADD" }
local FLASH_SMALL = { coords = FULL, blend = "ADD", h = 56, point = "TOPLEFT", x = -23, y = 23, point2 = "TOPRIGHT", x2 = 23, y2 = 23 }
local FLASH_BIG = { coords = FULL, blend = "ADD", w = 256, h = 64, point = "TOP", y = 28 }
local PLAIN = { coords = FULL }

local FILL_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local COLORS = {
    yellow = CASTBAR_CLASSIC_YELLOW or CreateColor(1, 0.7, 0),
    green = CASTBAR_CLASSIC_GREEN or CreateColor(0, 1, 0),
    gray = CASTBAR_CLASSIC_GRAY or CreateColor(0.5, 0.5, 0.5),
    red = CASTBAR_CLASSIC_RED or CreateColor(1, 0, 0),
}

local active = false
local skinned = {}

-- 12.x never calls SetLook on target/focus/boss spell bars: those (with AdjustPosition) are small, the rest full size.
local function LookOf(bar)
    if bar.look then return bar.look end
    return bar.AdjustPosition and "UNITFRAME" or "CLASSIC"
end

-- SetLook's classic geometry by hand: SetLook from addon code reads protected cast values in our context.
local function Shape(bar)
    local look = LookOf(bar)
    if look == "UNITFRAME" then
        bar:SetSize(150, 10)
        Dress(bar.Border, "castBorderSmall", BORDER_SMALL, bar)
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
        -- 1.x: 18px spell icon off the bar's left end.
        if bar.Icon then
            bar.Icon:SetSize(18, 18)
            ns.SetPointOnce(bar.Icon, "RIGHT", bar, "LEFT", -3.5, 1)
        end
    elseif look == "CLASSIC" then
        bar:SetSize(195, 13)
        Dress(bar.Border, "castBorder", BORDER, bar)
        if bar.BorderShield then
            bar.BorderShield:SetSize(256, 64)
            ns.SetPointOnce(bar.BorderShield, "TOP", bar, "TOP", 0, 28)
        end
        if bar.Text then
            bar.Text:SetSize(185, 16)
            ns.SetPointOnce(bar.Text, "TOP", bar, "TOP", 0, 5)
            bar.Text:SetFontObject("GameFontHighlight")
        end
    end
end

local function HideFx(bar)
    FadeKeys(bar, FX, 0, HIDE_FX)
end

local function DressSpark(bar)
    Dress(bar.Spark, "castSpark", SPARK)
end

local function DressFlash(bar)
    if not bar.Flash then return end
    local small = LookOf(bar) == "UNITFRAME"
    Dress(bar.Flash, small and "castFlashSmall" or "castFlash", small and FLASH_SMALL or FLASH_BIG, bar)
end

-- Colour from the client's chosen atlas name: the bar type itself is secret for other units.
local function FillColor(atlas)
    atlas = (type(atlas) == "string" and not IsSecret(atlas)) and atlas:lower() or ""
    if atlas:find("interrupted", 1, true) then return COLORS.red end
    if atlas:find("full", 1, true) then return COLORS.green end
    if atlas:find("channel", 1, true) then return COLORS.green end
    if atlas:find("uninterrupt", 1, true) then return COLORS.gray end
    return COLORS.yellow
end

local function Fill(bar)
    if not active then return end
    local tex = bar:GetStatusBarTexture()
    local atlas = tex and tex.GetAtlas and tex:GetAtlas()
    local color = FillColor(atlas)
    bar:SetStatusBarTexture(FILL_TEXTURE)
    bar:SetStatusBarColor(color:GetRGB())
end

-- 1.x spell bar spot: (43, 3) under the frame, lower with a ToT or elite, or under the auras.
-- The aura container is private: the client's choice is read back from the bar's anchor.
local function Position(bar)
    if not active or bar.boss then return end
    if InCombatLockdown() and bar.IsProtected and bar:IsProtected() then return end
    local parent = bar:GetParent()
    if not parent or not parent.GetAuraContainer then return end
    -- The client scales the small focus frame's bar back up: keep it at 1.
    if parent.smallSize then
        if bar:GetScale() ~= 1 then bar:SetScale(1) end
    end
    local container = parent:GetAuraContainer()
    local ok, _, relativeTo = pcall(bar.GetPoint, bar, 1)
    local underAuras = ok and container ~= nil and relativeTo == container
    if ns.OnSpellBarPlaced then ns.OnSpellBarPlaced(bar, underAuras, parent) end
    bar:ClearAllPoints()
    if underAuras then
        -- The old border reaches 23 above the bar: 16 down (the client uses 10) clears the last row.
        bar:SetPoint("TOPLEFT", container, "BOTTOMLEFT", 22, -16)
        return
    end
    local y = 3
    if parent.haveToT then
        y = -25
    elseif parent.haveElite then
        y = -9
    end
    bar:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 43, y)
end

local function StopFinishAnims(bar)
    for _, key in ipairs(FINISH_ANIMS) do
        local anim = bar[key]
        if anim and anim.Stop then anim:Stop() end
    end
    HideFx(bar)
end

local function DressBar(bar)
    if not active then return end
    Shape(bar)
    if bar.Background then
        bar.Background:SetAtlas(nil)
        bar.Background:SetColorTexture(0, 0, 0, 0.5)
        bar.Background:ClearAllPoints()
        bar.Background:SetAllPoints(bar)
    end
    DressSpark(bar)
    DressFlash(bar)
    if bar.BorderShield then
        Dress(bar.BorderShield, LookOf(bar) == "UNITFRAME" and "castSmallShield" or "castBorder", PLAIN)
    end
    HideFx(bar)
    Fill(bar)
    if bar.AdjustPosition then Position(bar) end
end

local function Skin(bar)
    if not bar then return end
    if not skinned[bar] then
        skinned[bar] = true
        ns.HookMethod(bar, "SetLook", DressBar)
        ns.HookMethod(bar, "UpdateShownState", DressBar)
        if bar.AdjustPosition then
            ns.HookMethod(bar, "AdjustPosition", Position)
            local parent = bar:GetParent()
            if parent and parent.SetSmallSize then
                ns.HookMethod(parent, "SetSmallSize", function() Position(bar) end)
            end
        end
        -- The client re-sets the fill atlas on every start, stop and finish.
        ns.HookMethod(bar, "UpdateBarFillTexture", Fill)
        -- Spark atlas and per-type glow return on every cast.
        ns.HookMethod(bar, "ShowSpark", function(b)
            if not active then return end
            DressSpark(b)
            HideFx(b)
        end)
        -- The finish glow atlas is set just before the fade plays.
        ns.HookMethod(bar, "PlayFadeAnim", function(b)
            if active then DressFlash(b) end
        end)
        ns.HookMethod(bar, "PlayFinishAnim", function(b)
            if active then StopFinishAnims(b) end
        end)
        ns.HookMethod(bar, "PlayInterruptAnims", function(b)
            if active then HideFx(b) end
        end)
    end
    DressBar(bar)
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
        if bar.Border then bar.Border:SetAtlas("ui-castingbar-frame") end
        if bar.Spark then bar.Spark:SetAtlas("ui-castingbar-pip") end
        if bar.Flash then bar.Flash:SetAtlas("ui-castingbar-full-glow-standard") end
        if bar.Background then bar.Background:SetAtlas("ui-castingbar-background") end
        FadeKeys(bar, FX, 1)
    end
    ns.needsReload = true
end

ns.RegisterModule("castBars", { apply = Apply, restore = Restore })
