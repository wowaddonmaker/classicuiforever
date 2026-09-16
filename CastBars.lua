local _, ns = ...

-- The 1.x cast bars on Blizzard's CastingBarMixin frames: the standalone
-- player bar with the wide border sheet, and the small bordered bar for
-- anything attached to a unit frame (target, focus, boss, pet, the player
-- bar when locked to its frame). Blizzard keeps every timer, event and
-- animation; we swap the art after each of its own updates.

local BIG_W, BIG_H = 195, 13
local COLORS = {
    cast = { 1, 0.7, 0 },
    channel = { 0, 1, 0 },
    locked = { 0.7, 0.7, 0.7 },
    failed = { 1, 0, 0 },
}

local active = false
local skinned = {}

local function IsStandalone(bar)
    return bar == PlayerCastingBarFrame and not bar.attachedToPlayerFrame and bar.look ~= "UNITFRAME"
end

local function SetFill(bar, color)
    bar:SetStatusBarTexture((ns.TexPath("statusBar")))
    local tex = bar:GetStatusBarTexture()
    if tex then
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetVertexColor(color[1], color[2], color[3])
    end
end

local function CurrentColor(bar)
    local unit = bar.unit or "player"
    local notInterruptible
    if bar.channeling then
        notInterruptible = select(7, UnitChannelInfo(unit))
        if notInterruptible and not (issecretvalue and issecretvalue(notInterruptible)) and notInterruptible then return COLORS.locked end
        return COLORS.channel
    end
    notInterruptible = select(8, UnitCastingInfo(unit))
    if notInterruptible and not (issecretvalue and issecretvalue(notInterruptible)) and notInterruptible then return COLORS.locked end
    return COLORS.cast
end

local function Layout(bar)
    if not active then return end
    local w, h = bar:GetSize()
    if not w or w == 0 then w, h = BIG_W, BIG_H end
    if bar.Background then
        bar.Background:SetAtlas(nil)
        bar.Background:SetColorTexture(0, 0, 0, 0.5)
        bar.Background:ClearAllPoints()
        bar.Background:SetAllPoints(bar)
    end
    if IsStandalone(bar) then
        local s = w / BIG_W
        if bar.Border then
            ns.SetTex(bar.Border, "castBorder")
            bar.Border:SetTexCoord(0, 1, 0, 1)
            bar.Border:SetSize(256 * s, 64 * s)
            ns.SetPointOnce(bar.Border, "TOP", bar, "TOP", 0, 28 * s)
        end
        if bar.BorderShield then
            ns.SetTex(bar.BorderShield, "castBorder")
            bar.BorderShield:SetTexCoord(0, 1, 0, 1)
            bar.BorderShield:SetSize(256 * s, 64 * s)
            ns.SetPointOnce(bar.BorderShield, "TOP", bar, "TOP", 0, 28 * s)
        end
        if bar.Flash then
            ns.SetTex(bar.Flash, "castFlash")
            bar.Flash:SetTexCoord(0, 1, 0, 1)
            bar.Flash:SetSize(256 * s, 64 * s)
            ns.SetPointOnce(bar.Flash, "TOP", bar, "TOP", 0, 28 * s)
            bar.Flash:SetBlendMode("ADD")
        end
        if bar.Text then
            bar.Text:SetFontObject("GameFontHighlight")
            ns.SetPointOnce(bar.Text, "CENTER", bar, "CENTER", 0, 1)
            bar.Text:SetWidth(w - 10)
        end
        if bar.Icon then ns.Fade(bar.Icon) end
    else
        if bar.Border then
            ns.SetTex(bar.Border, "castBorderSmall")
            bar.Border:SetTexCoord(0, 1, 0, 1)
            bar.Border:ClearAllPoints()
            bar.Border:SetHeight(49)
            bar.Border:SetPoint("TOPLEFT", bar, "TOPLEFT", -23, 20)
            bar.Border:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 23, 20)
        end
        if bar.BorderShield then
            ns.SetTex(bar.BorderShield, "castSmallShield")
            bar.BorderShield:SetTexCoord(0, 1, 0, 1)
            bar.BorderShield:ClearAllPoints()
            bar.BorderShield:SetHeight(49)
            bar.BorderShield:SetPoint("TOPLEFT", bar, "TOPLEFT", -28, 20)
            bar.BorderShield:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 18, 20)
        end
        if bar.Flash then
            ns.SetTex(bar.Flash, "castFlashSmall")
            bar.Flash:SetTexCoord(0, 1, 0, 1)
            bar.Flash:ClearAllPoints()
            bar.Flash:SetHeight(49)
            bar.Flash:SetPoint("TOPLEFT", bar, "TOPLEFT", -23, 20)
            bar.Flash:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 23, 20)
            bar.Flash:SetBlendMode("ADD")
        end
        if bar.Text then
            bar.Text:SetFontObject("GameFontHighlightSmall")
            bar.Text:ClearAllPoints()
            bar.Text:SetHeight(16)
            bar.Text:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 4)
            bar.Text:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 4)
        end
        if bar.Icon then
            ns.Unfade(bar.Icon)
            bar.Icon:SetSize(16, 16)
            ns.SetPointOnce(bar.Icon, "RIGHT", bar, "LEFT", -5, 0)
        end
    end
    if bar.TextBorder then ns.Fade(bar.TextBorder) end
    if bar.Spark then
        ns.SetTex(bar.Spark, "castSpark")
        bar.Spark:SetTexCoord(0, 1, 0, 1)
        bar.Spark:SetSize(32, 32)
        bar.Spark:SetBlendMode("ADD")
    end
    SetFill(bar, CurrentColor(bar))
end

local function Skin(bar)
    if not bar or skinned[bar] then
        if bar then Layout(bar) end
        return
    end
    skinned[bar] = true
    ns.HookMethod(bar, "SetLook", Layout)
    ns.HookMethod(bar, "UpdateShownState", Layout)
    ns.HookMethod(bar, "UpdateBarFillTexture", function(self, isFull)
        if not active then return end
        SetFill(self, isFull and COLORS.channel or CurrentColor(self))
    end)
    ns.HookMethod(bar, "PlayInterruptAnims", function(self)
        if not active then return end
        SetFill(self, COLORS.failed)
        if self.maxValue then self:SetValue(self.maxValue) end
        if self.Spark then self.Spark:Hide() end
    end)
    ns.HookMethod(bar, "PlayFinishAnim", function(self)
        if not active or not self.Flash then return end
        local r, g, b = self:GetStatusBarColor()
        self.Flash:SetVertexColor(r or 1, g or 1, b or 1)
    end)
    ns.HookScriptOnce(bar, "OnSizeChanged", function(self) if active then Layout(self) end end)
    Layout(bar)
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
        if bar.SetLook and bar.look then pcall(bar.SetLook, bar, bar.look) end
    end
    ns.needsReload = true
end

ns.RegisterModule("castBars", { apply = Apply, restore = Restore })
