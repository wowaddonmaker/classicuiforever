local _, ns = ...

-- The 1.x cast bars: 195x13 with the old border sheet, UI-StatusBar fills
-- in the old yellow, green, grey and red, a static spark and none of the
-- modern flakes, wisps and glow lines.
--
-- Nothing here writes a field on a cast bar. Blizzard's own classic
-- branch (classicStyleCastBar) would do most of this, but a field set
-- from addon code taints every later read of it, and the bar's update
-- loop then trips on the secret cast values other units carry. So the
-- bars keep running Blizzard's modern branch untouched and secure hooks
-- put the classic art back after each change.

local FX = { "Flakes01", "Flakes02", "Flakes03", "BaseGlow", "WispGlow", "Sparkles01", "Sparkles02", "Shine",
    "EnergyGlow", "InterruptGlow", "ChargeGlow", "ChargeFlash", "StandardGlow", "CraftGlow", "ChannelShadow", "DropShadow", "TextBorder" }
local FINISH_ANIMS = { "StandardFinish", "ChannelFinish", "CraftingFinish" }

local FILL_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local COLORS = {
    yellow = CASTBAR_CLASSIC_YELLOW or CreateColor(1, 0.7, 0),
    green = CASTBAR_CLASSIC_GREEN or CreateColor(0, 1, 0),
    gray = CASTBAR_CLASSIC_GRAY or CreateColor(0.5, 0.5, 0.5),
    red = CASTBAR_CLASSIC_RED or CreateColor(1, 0, 0),
}

local active = false
local skinned = {}

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

-- 12.x never calls SetLook on the target, focus and boss spell bars, so
-- their look is unset; those are the small bars (they are the ones with
-- AdjustPosition), everything else is the full-size bar.
local function LookOf(bar)
    if bar.look then return bar.look end
    return bar.AdjustPosition and "UNITFRAME" or "CLASSIC"
end

-- The classic geometry of SetLook, done here because calling SetLook from
-- addon code makes Blizzard read protected cast values in our context.
local function Shape(bar)
    local look = LookOf(bar)
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
        -- The spell icon hangs off the left end of the bar, 18px, as 1.x drew it.
        if bar.Icon then
            bar.Icon:SetSize(18, 18)
            bar.Icon:ClearAllPoints()
            bar.Icon:SetPoint("RIGHT", bar, "LEFT", -3.5, 1)
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

local function HideFx(bar)
    for _, key in ipairs(FX) do
        local region = bar[key]
        if region then
            if region.SetAtlas then region:SetAtlas(nil) end
            region:SetAlpha(0)
            region:Hide()
        end
    end
end

local function DressSpark(bar)
    if not bar.Spark then return end
    ns.SetTex(bar.Spark, "castSpark")
    bar.Spark:SetTexCoord(0, 1, 0, 1)
    bar.Spark:SetSize(32, 32)
    bar.Spark:SetBlendMode("ADD")
end

local function DressFlash(bar)
    if not bar.Flash then return end
    local small = LookOf(bar) == "UNITFRAME"
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

-- The classic fill colour for the modern atlas Blizzard just chose: the
-- atlas name carries the bar type, so the type itself (a secret value for
-- other units) is never read here.
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

-- What the last placement saw, for the saved output.
local lastPlacement = {}
local function NotePlacement(bar, text)
    if lastPlacement[bar] == text then return end
    lastPlacement[bar] = text
    if ns.Persist then ns.Persist("spellbar " .. (bar:GetName() or "?") .. " " .. text) end
end

-- Where 1.x put the target and focus spell bar: under the frame at
-- (43, 3), lower with a target-of-target frame, or under the buff rows
-- when they sit below the frame. The aura container is a private frame
-- on 12.x: its buttons and its size come from aura data that addon code
-- cannot read or compare. Blizzard decides in secure code whether the
-- bar goes under the auras, and anchors it to the container or to the
-- frame; the choice is read back from the bar's own anchor and the 1.x
-- offsets are applied against the same frame.
local Position
Position = function(bar)
    if not active or bar.boss then return end
    if InCombatLockdown() and bar.IsProtected and bar:IsProtected() then return end
    local parent = bar:GetParent()
    if not parent or not parent.GetAuraContainer then return end
    -- The small focus frame is scaled down and Blizzard scales its spell
    -- bar back up to full size; ours stays with the frame.
    if parent.smallSize then
        if bar:GetScale() ~= 1 then bar:SetScale(1) end
    end
    local container = parent:GetAuraContainer()
    local ok, _, relativeTo = pcall(bar.GetPoint, bar, 1)
    local underAuras = ok and container ~= nil and relativeTo == container
    NotePlacement(bar, string.format("under auras %s tot %s top %s", tostring(underAuras), tostring(parent.haveToT), tostring(parent.buffsOnTop)))
    bar:ClearAllPoints()
    if underAuras then
        -- Retail hangs it 10 below the container; the old bar's border
        -- art reaches 23 above the bar, so a little more keeps it clear
        -- of the last row.
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

local function Dress(bar)
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
        ns.SetTex(bar.BorderShield, LookOf(bar) == "UNITFRAME" and "castSmallShield" or "castBorder")
        bar.BorderShield:SetTexCoord(0, 1, 0, 1)
    end
    HideFx(bar)
    Fill(bar)
    if bar.AdjustPosition then Position(bar) end
end

local function Skin(bar)
    if not bar then return end
    if not skinned[bar] then
        skinned[bar] = true
        ns.HookMethod(bar, "SetLook", Dress)
        ns.HookMethod(bar, "UpdateShownState", Dress)
        if bar.AdjustPosition then
            ns.HookMethod(bar, "AdjustPosition", Position)
            local parent = bar:GetParent()
            if parent and parent.SetSmallSize then
                ns.HookMethod(parent, "SetSmallSize", function() Position(bar) end)
            end
        end
        -- Blizzard re-sets the fill atlas on every start, stop and finish.
        ns.HookMethod(bar, "UpdateBarFillTexture", Fill)
        -- The spark atlas and the per-type glow come back on every cast.
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
