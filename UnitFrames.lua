local _, ns = ...

-- The 1.x unit frames on Blizzard's 12.x frames. Blizzard's health and
-- power bars are faded out and our own bars, fed by unit events, are
-- drawn in the old spots; Blizzard's text, prediction and absorb regions
-- are moved onto ours so nothing is lost. Portraits, names, levels and
-- the frame art are reskinned in place. Everything secure (clicks, menus,
-- auras) is untouched.

local UI_STATUSBAR = "statusBar"
local FRAME_W, FRAME_H = 232, 100
local BAR_W, BAR_H = 119, 12
-- 1.x anchors, measured from Blizzard's frame, whose top left sits 19px
-- right and 4px below the old art's: the old (106, -41) bars land at
-- (87, -45) here, the target bars at (27, -45).
local PLAYER_BAR_X, TARGET_BAR_X = 87, 27
local HEALTH_Y, POWER_Y = -45, -56
local PLAYER_NAME_Y = -26
local PORTRAIT = 64

local active = false
local driver

local frames = {}   -- key -> { unit, frame, health, power }
local SkinParty

-- Blizzard bars we keep (pet, party) with the unit they show: their own
-- update routines put the modern atlas and a white fill back, so they
-- are recoloured after each one. Weak keys, never a field on the frame.
local keptBars = setmetatable({}, { __mode = "k" })

local function RecolorKept(bar)
    local kind = keptBars[bar]
    if not kind or not active then return end
    bar:SetStatusBarTexture((ns.TexPath(UI_STATUSBAR)))
    if kind == "health" then
        bar:SetStatusBarColor(0, 1, 0)
    else
        local unit = bar.unit or (bar:GetParent() and bar:GetParent().unit)
        if unit then bar:SetStatusBarColor(ns.PowerColor(unit)) end
    end
end

local function KeepBar(bar, kind)
    if not bar then return end
    keptBars[bar] = kind
    RecolorKept(bar)
end

------------------------------------------------------------------ bars

-- 1.x drew the bars behind the frame art, which is what gives them the
-- slot shape; the text goes on a frame above the art so it stays readable.
local function AttachTexts(bar, texts, offsets, textParent)
    for i, fs in ipairs(texts) do
        if fs then
            fs:SetParent(textParent or bar)
            fs:SetDrawLayer("OVERLAY")
            fs:ClearAllPoints()
            local o = offsets[i]
            fs:SetPoint(o[1], bar, o[1], o[2], o[3])
        end
    end
end

-- Blizzard's heal prediction, absorb and animated loss pieces follow our bar.
local function AttachOverlays(source, bar, mask)
    for _, key in ipairs({ "MyHealPredictionBar", "OtherHealPredictionBar", "HealAbsorbBar", "TotalAbsorbBar" }) do
        local piece = source[key]
        if piece then
            piece:SetParent(bar)
            piece:ClearAllPoints()
            piece:SetAllPoints(bar)
            if mask and piece.Fill and piece.Fill.RemoveMaskTexture then pcall(piece.Fill.RemoveMaskTexture, piece.Fill, mask) end
            if piece.Fill then piece.Fill:SetTexture((ns.TexPath(UI_STATUSBAR))) end
        end
    end
    for _, key in ipairs({ "OverAbsorbGlow", "OverHealAbsorbGlow" }) do
        local glow = source[key]
        if glow then
            glow:SetParent(bar)
            if mask and glow.RemoveMaskTexture then pcall(glow.RemoveMaskTexture, glow, mask) end
            glow:ClearAllPoints()
            if key == "OverAbsorbGlow" then
                glow:SetPoint("TOPLEFT", bar, "TOPRIGHT", -7, 0)
                glow:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", -7, 0)
            else
                glow:SetPoint("TOPRIGHT", bar, "TOPLEFT", 7, 0)
                glow:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", 7, 0)
            end
        end
    end
end

-- Retail draws a gold circle with the faction icon in the level spot
-- when PvP flagged; 1.x put the faction icon beside the portrait and
-- kept the level. Nothing in Blizzard's Lua names these two, so they are
-- faded wherever we touch the frame.
local function FadePvpCircle(frame)
    for _, key in ipairs({ "PlayerFrameContentMain", "PlayerFrameContentContextual", "TargetFrameContentMain", "TargetFrameContentContextual" }) do
        local content = frame.PlayerFrameContent or frame.TargetFrameContent
        local part = content and content[key]
        if part then
            ns.Fade(part.PvpBackgroundCircle)
            ns.Fade(part.PvpBackgroundIcon)
        end
    end
end

local function Update(entry, what)
    if not entry or not UnitExists(entry.unit) then return end
    if entry.frame and what == nil then FadePvpCircle(entry.frame) end
    if what ~= "power" and entry.health then ns.SetHealth(entry.health, entry.unit) end
    if what ~= "health" and entry.power then ns.SetPower(entry.power, entry.unit) end
end

local function UpdateAll()
    for _, entry in pairs(frames) do Update(entry) end
end

local function OnEvent(_, event, unit)
    if not active then return end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        for _, entry in pairs(frames) do
            if entry.unit == unit then Update(entry, "health") end
        end
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" or event == "UNIT_POWER_FREQUENT" then
        for _, entry in pairs(frames) do
            if entry.unit == unit then Update(entry, "power") end
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if not InCombatLockdown() then SkinParty() end
        UpdateAll()
    else
        UpdateAll()
    end
end

------------------------------------------------------------------ player

local function SkinPlayer()
    local frame = PlayerFrame
    local container = frame and frame.PlayerFrameContainer
    local main = ns.Path(frame, "PlayerFrameContent", "PlayerFrameContentMain")
    local contextual = ns.Path(frame, "PlayerFrameContent", "PlayerFrameContentContextual")
    if not container or not main or not contextual then ns.MissingPiece("PlayerFrame layout") return end
    local healthContainer, manaArea = main.HealthBarsContainer, main.ManaBarArea
    local blizzHealth = healthContainer and healthContainer.HealthBar
    local blizzMana = manaArea and manaArea.ManaBar

    -- Frame art: the targeting frame sheet mirrored for the left side.
    local art = container.FrameTexture
    if art then
        ns.SetTex(art, "targetingFrame")
        art:SetTexCoord(1, 0.09375, 0, 0.78125)
        art:SetSize(FRAME_W, FRAME_H)
        ns.SetPointOnce(art, "TOPLEFT", frame, "TOPLEFT", -19, -4)
        art:SetDrawLayer("BORDER")
    end
    if container.AlternatePowerFrameTexture then
        local alt = container.AlternatePowerFrameTexture
        ns.SetTex(alt, "targetingFrame")
        alt:SetTexCoord(1, 0.09375, 0, 0.78125)
        alt:SetSize(FRAME_W, FRAME_H)
        ns.SetPointOnce(alt, "TOPLEFT", frame, "TOPLEFT", -19, -4)
    end
    if container.FrameFlash then
        local flash = container.FrameFlash
        ns.SetTex(flash, "targetingFlash")
        flash:SetTexCoord(0.9453125, 0, 0, 0.181640625)
        flash:SetSize(242, 93)
        ns.SetPointOnce(flash, "TOPLEFT", frame, "TOPLEFT", -6, -4)
        flash:SetDrawLayer("BACKGROUND")
    end
    if container.PlayerPortrait then
        container.PlayerPortrait:SetSize(PORTRAIT, PORTRAIT)
        ns.SetPointOnce(container.PlayerPortrait, "TOPLEFT", frame, "TOPLEFT", 23, -16)
    end
    if container.PlayerPortraitMask then
        container.PlayerPortraitMask:SetSize(PORTRAIT, PORTRAIT)
        ns.SetTex(container.PlayerPortraitMask, "portraitMask")
        ns.SetPointOnce(container.PlayerPortraitMask, "TOPLEFT", frame, "TOPLEFT", 23, -16)
    end

    -- Our bars where the 1.x bars were, Blizzard's faded out underneath.
    local host = frame.fcui and frame.fcui.host
    if not host then
        host = CreateFrame("Frame", nil, frame)
        host:EnableMouse(false)
        frame.fcui = frame.fcui or {}
        frame.fcui.host = host
    end
    host:SetAllPoints(frame)
    -- Bars under the art, art under the state icons and text.
    local base = frame:GetFrameLevel()
    -- Protected children: only touched when the level is not already right.
    if host:GetFrameLevel() ~= base + 1 then host:SetFrameLevel(base + 1) end
    if container:GetFrameLevel() ~= base + 3 then container:SetFrameLevel(base + 3) end
    if contextual:GetFrameLevel() ~= base + 4 then contextual:SetFrameLevel(base + 4) end
    local bg = ns.OwnTexture(host, "barBg", "BACKGROUND")
    bg:SetColorTexture(0, 0, 0, 0.5)
    bg:SetSize(BAR_W, 41)
    ns.SetPointOnce(bg, "TOPLEFT", host, "TOPLEFT", PLAYER_BAR_X, PLAYER_NAME_Y)

    local health = ns.CreateBar(host, "health", BAR_W, BAR_H)
    ns.SetPointOnce(health, "TOPLEFT", host, "TOPLEFT", PLAYER_BAR_X, HEALTH_Y)
    health:SetStatusBarColor(0, 1, 0)
    local power = ns.CreateBar(host, "power", BAR_W, BAR_H)
    ns.SetPointOnce(power, "TOPLEFT", host, "TOPLEFT", PLAYER_BAR_X, POWER_Y)
    -- Blizzard's own bars, faded out, keep the mouse: their hover shows
    -- the numbers, so they must cover exactly where ours are drawn.
    if blizzHealth then ns.SetPointOnce(blizzHealth, "TOPLEFT", health, "TOPLEFT", 0, 0); blizzHealth:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0) end
    if blizzMana then ns.SetPointOnce(blizzMana, "TOPLEFT", power, "TOPLEFT", 0, 0); blizzMana:SetPoint("BOTTOMRIGHT", power, "BOTTOMRIGHT", 0, 0) end

    if healthContainer then
        ns.Fade(healthContainer)
        if blizzHealth then
            AttachTexts(health, { blizzHealth.TextString, blizzHealth.LeftText, blizzHealth.RightText },
                { { "CENTER", 0, 0 }, { "LEFT", 6, 0 }, { "RIGHT", -4, 0 } }, contextual)
            AttachOverlays(blizzHealth, health, healthContainer.HealthBarMask)
        end
        local loss = healthContainer.PlayerFrameHealthBarAnimatedLoss
        if loss then
            loss:SetParent(health)
            loss:ClearAllPoints()
            loss:SetAllPoints(health)
            loss:SetStatusBarTexture((ns.TexPath(UI_STATUSBAR)))
            local tex = loss:GetStatusBarTexture()
            if tex and healthContainer.HealthBarMask and tex.RemoveMaskTexture then pcall(tex.RemoveMaskTexture, tex, healthContainer.HealthBarMask) end
        end
    end
    if manaArea then
        ns.Fade(manaArea)
        if blizzMana then
            AttachTexts(power, { blizzMana.TextString, blizzMana.LeftText, blizzMana.RightText },
                { { "CENTER", 0, 0 }, { "LEFT", 6, 0 }, { "RIGHT", -4, 0 } }, contextual)
            -- The power change and full power animations draw the modern
            -- bar atlas; they stay under the faded area, out of sight.
        end
    end

    -- Name and level in the 1.x spots; Forever's level circle goes away.
    if PlayerName then
        PlayerName:SetParent(contextual)
        PlayerName:SetWidth(100)
        PlayerName:SetJustifyH("CENTER")
        ns.SetPointOnce(PlayerName, "TOPLEFT", host, "TOPLEFT", 97, -30)
    end
    if PlayerLevelText then
        PlayerLevelText:SetParent(contextual)
        PlayerLevelText:SetDrawLayer("OVERLAY")
        PlayerLevelText:SetFontObject("GameFontNormalSmall")
        PlayerLevelText:SetJustifyH("CENTER")
        ns.SetPointOnce(PlayerLevelText, "CENTER", host, "TOPLEFT", 36, -71)
        PlayerLevelText:SetTextColor(1, 0.82, 0)
    end
    ns.Fade(main.LevelBackgroundCircle)
    ns.FadeCircles(main)
    ns.FadeCircles(contextual)
    local levelBg = ns.OwnTexture(host, "levelBg", "BORDER")
    ns.SetTex(levelBg, "levelBackground")
    levelBg:SetSize(BAR_W, 19)
    ns.SetPointOnce(levelBg, "TOPLEFT", host, "TOPLEFT", PLAYER_BAR_X, PLAYER_NAME_Y)
    levelBg:SetVertexColor(0, 0, 0)
    levelBg:Hide()

    -- Rest and combat state icons from the old state sheet.
    if main.StatusTexture then
        local status = main.StatusTexture
        status:SetParent(contextual)
        ns.SetTex(status, "playerStatus")
        status:SetTexCoord(0, 0.74609375, 0, 0.53125)
        status:SetSize(190, 66)
        ns.SetPointOnce(status, "TOPLEFT", frame, "TOPLEFT", 16, -12)
        status:SetBlendMode("ADD")
    end
    local rest = ns.OwnTexture(contextual, "rest", "OVERLAY")
    ns.SetTex(rest, "stateIcon")
    rest:SetTexCoord(0, 0.5, 0, 0.421875)
    rest:SetSize(31, 31)
    ns.SetPointOnce(rest, "TOPLEFT", frame, "TOPLEFT", 20, -54)
    local attack = ns.OwnTexture(contextual, "attack", "OVERLAY")
    ns.SetTex(attack, "stateIcon")
    attack:SetTexCoord(0.5, 1, 0, 0.484375)
    attack:SetSize(32, 31)
    ns.SetPointOnce(attack, "TOPLEFT", frame, "TOPLEFT", 21, -53)
    if contextual.PlayerRestLoop then ns.Fade(contextual.PlayerRestLoop) end
    if contextual.AttackIcon then ns.Fade(contextual.AttackIcon) end
    if contextual.PlayerPortraitCornerIcon then ns.Fade(contextual.PlayerPortraitCornerIcon) end
    local function UpdateStatus()
        if not active then return end
        local resting = IsResting()
        local inCombat = frame.inCombat or (UnitAffectingCombat and UnitAffectingCombat("player"))
        rest:SetShown(resting and not inCombat)
        attack:SetShown(not resting and (inCombat or frame.onHateList))
    end
    ns.HookGlobal("PlayerFrame_UpdateStatus", UpdateStatus)
    UpdateStatus()

    -- Retail swaps the level for a role icon inside instances; 1.x always
    -- showed the level there.
    local function LevelNotRole()
        if not active then return end
        if contextual.RoleIcon then contextual.RoleIcon:Hide() end
        if PlayerLevelText then PlayerLevelText:Show() end
    end
    ns.HookGlobal("PlayerFrame_UpdateRolesAssigned", LevelNotRole)
    LevelNotRole()

    if contextual.LeaderIcon then
        ns.SetTex(contextual.LeaderIcon, "leaderIcon")
        contextual.LeaderIcon:SetTexCoord(0, 1, 0, 1)
        contextual.LeaderIcon:SetSize(16, 16)
        ns.SetPointOnce(contextual.LeaderIcon, "TOPLEFT", frame, "TOPLEFT", 21, -16)
    end
    -- PvP: the faction icon beside the portrait as in 1.x; retail's honor
    -- level badge behind it never existed there.
    local function PlayerPvp()
        if not active then return end
        ns.Fade(contextual.PrestigePortrait)
        ns.Fade(contextual.PrestigeBadge)
        FadePvpCircle(frame)
        ns.FadeCircles(main)
        if contextual.PVPIcon then
            local horde = UnitFactionGroup("player") == "Horde"
            ns.SetPointOnce(contextual.PVPIcon, "TOPLEFT", frame, "TOPLEFT", horde and -1 or 8, horde and -22 or -24)
        end
    end
    ns.HookGlobal("PlayerFrame_UpdatePvPStatus", PlayerPvp)
    PlayerPvp()
    if contextual.GroupIndicator then
        ns.SetPointOnce(contextual.GroupIndicator, "BOTTOMLEFT", frame, "TOPLEFT", 97, -20)
    end

    frames.player = { unit = "player", frame = frame, health = health, power = power }
    Update(frames.player)
end

-- Blizzard re-anchors its pieces when the art changes (vehicles, alt power).
local function HookPlayer()
    ns.HookGlobal("PlayerFrame_ToPlayerArt", function() if active then SkinPlayer() end end)
    ns.HookGlobal("PlayerFrame_UpdatePlayerNameTextAnchor", function()
        if active and PlayerName and PlayerFrame.fcui and PlayerFrame.fcui.host then
            ns.SetPointOnce(PlayerName, "TOPLEFT", PlayerFrame.fcui.host, "TOPLEFT", 97, -30)
        end
    end)
    ns.HookGlobal("PlayerFrame_UpdateLevel", function()
        if active and PlayerLevelText and PlayerFrame.fcui and PlayerFrame.fcui.host then
            ns.SetPointOnce(PlayerLevelText, "CENTER", PlayerFrame.fcui.host, "TOPLEFT", 36, -71)
        end
    end)
end

------------------------------------------------------------------ target and focus

local CLASSIFICATION_ART = {
    rareelite = { key = "targetingRareElite", flashCoords = { 0, 0.9453125, 0.181640625, 0.400390625 }, flashSize = { 242, 112 }, flashPoint = { -2, 5 } },
    elite = { key = "targetingElite", flashCoords = { 0, 0.9453125, 0.181640625, 0.400390625 }, flashSize = { 242, 112 }, flashPoint = { -2, 5 } },
    worldboss = { key = "targetingElite", flashCoords = { 0, 0.9453125, 0.181640625, 0.400390625 }, flashSize = { 242, 112 }, flashPoint = { -2, 5 } },
    rare = { key = "targetingRare", flashCoords = { 0, 0.9453125, 0, 0.181640625 }, flashSize = { 242, 93 }, flashPoint = { -4, -4 } },
    minus = { key = "targetingMinus", flashCoords = { 0, 1, 0, 1 }, flashSize = { 256, 128 }, flashPoint = { -4, -4 }, flashKey = "targetingMinusFlash" },
    normal = { key = "targetingFrame", flashCoords = { 0, 0.9453125, 0, 0.181640625 }, flashSize = { 242, 93 }, flashPoint = { -4, -4 } },
}

local function ApplyClassification(frame)
    local entry = frames[frame]
    if not entry or not active then return end
    local container = frame.TargetFrameContainer
    local classification = UnitClassification(entry.unit)
    local art = CLASSIFICATION_ART[classification] or CLASSIFICATION_ART.normal
    if container.FrameTexture then
        ns.SetTex(container.FrameTexture, art.key)
        container.FrameTexture:SetTexCoord(0.09375, 1, 0, 0.78125)
        container.FrameTexture:SetSize(FRAME_W, FRAME_H)
        ns.SetPointOnce(container.FrameTexture, "TOPLEFT", frame, "TOPLEFT", 20, -4)
    end
    if container.Flash then
        ns.SetTex(container.Flash, art.flashKey or "targetingFlash")
        container.Flash:SetTexCoord(unpack(art.flashCoords))
        container.Flash:SetSize(unpack(art.flashSize))
        ns.SetPointOnce(container.Flash, "TOPLEFT", frame, "TOPLEFT", art.flashPoint[1], art.flashPoint[2])
    end
    if container.BossPortraitFrameTexture then ns.Fade(container.BossPortraitFrameTexture) end
    local contextual = ns.Path(frame, "TargetFrameContent", "TargetFrameContentContextual")
    if contextual and contextual.BossIcon then ns.Fade(contextual.BossIcon) end
    local main = ns.Path(frame, "TargetFrameContent", "TargetFrameContentMain")
    local minus = classification == "minus"
    if entry.power then entry.power:SetAlpha(minus and 0 or 1) end
    if entry.bg then
        entry.bg:SetSize(BAR_W, minus and 12 or 25)
    end
    if main and main.ReputationColor then main.ReputationColor:SetShown(not minus) end
    frame.haveElite = (classification == "elite" or classification == "worldboss" or classification == "rare" or classification == "rareelite") or nil
end

local function SkinTarget(frame, unit)
    if not frame then return end
    local container = frame.TargetFrameContainer
    local main = ns.Path(frame, "TargetFrameContent", "TargetFrameContentMain")
    local contextual = ns.Path(frame, "TargetFrameContent", "TargetFrameContentContextual")
    if not container or not main or not contextual then ns.MissingPiece(frame:GetName() .. " layout") return end
    local healthContainer = main.HealthBarsContainer
    local blizzHealth = healthContainer and healthContainer.HealthBar
    local blizzMana = main.ManaBar

    if container.Portrait then
        container.Portrait:SetSize(PORTRAIT, PORTRAIT)
        ns.SetPointOnce(container.Portrait, "TOPRIGHT", frame, "TOPRIGHT", -22, -16)
    end
    if container.PortraitMask then
        container.PortraitMask:SetSize(PORTRAIT, PORTRAIT)
        ns.SetTex(container.PortraitMask, "portraitMask")
        ns.SetPointOnce(container.PortraitMask, "TOPRIGHT", frame, "TOPRIGHT", -22, -16)
    end

    local host = frame.fcui and frame.fcui.host
    if not host then
        host = CreateFrame("Frame", nil, frame)
        host:EnableMouse(false)
        frame.fcui = frame.fcui or {}
        frame.fcui.host = host
    end
    host:SetAllPoints(frame)
    local base = frame:GetFrameLevel()
    -- Protected children: only touched when the level is not already right.
    if host:GetFrameLevel() ~= base + 1 then host:SetFrameLevel(base + 1) end
    if container:GetFrameLevel() ~= base + 3 then container:SetFrameLevel(base + 3) end
    if contextual:GetFrameLevel() ~= base + 4 then contextual:SetFrameLevel(base + 4) end
    local bg = ns.OwnTexture(host, "barBg", "BACKGROUND")
    bg:SetColorTexture(0, 0, 0, 0.5)
    bg:SetSize(BAR_W, 25)
    ns.SetPointOnce(bg, "TOPLEFT", host, "TOPLEFT", TARGET_BAR_X, HEALTH_Y)

    local health = ns.CreateBar(host, "health", BAR_W, BAR_H)
    ns.SetPointOnce(health, "TOPLEFT", host, "TOPLEFT", TARGET_BAR_X, HEALTH_Y)
    health:SetStatusBarColor(0, 1, 0)
    local power = ns.CreateBar(host, "power", BAR_W, BAR_H)
    ns.SetPointOnce(power, "TOPLEFT", host, "TOPLEFT", TARGET_BAR_X, POWER_Y)
    if blizzHealth then ns.SetPointOnce(blizzHealth, "TOPLEFT", health, "TOPLEFT", 0, 0); blizzHealth:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0) end
    if blizzMana then ns.SetPointOnce(blizzMana, "TOPLEFT", power, "TOPLEFT", 0, 0); blizzMana:SetPoint("BOTTOMRIGHT", power, "BOTTOMRIGHT", 0, 0) end

    if blizzHealth then
        ns.Fade(blizzHealth)
        AttachTexts(health, { blizzHealth.TextString, healthContainer.LeftText, healthContainer.RightText, healthContainer.DeadText, healthContainer.UnconsciousText },
            { { "CENTER", 0, 0 }, { "LEFT", 5, 0 }, { "RIGHT", -7, 0 }, { "CENTER", 0, 0 }, { "CENTER", 0, 0 } }, contextual)
        AttachOverlays(blizzHealth, health, healthContainer.HealthBarMask)
    end
    if blizzMana then
        ns.Fade(blizzMana)
        AttachTexts(power, { blizzMana.TextString, blizzMana.LeftText, blizzMana.RightText },
            { { "CENTER", 0, 0 }, { "LEFT", 5, 0 }, { "RIGHT", -7, 0 } }, contextual)
    end

    -- Name over the bars, level in the circle by the portrait, reaction
    -- colour behind the name from the old level background strip.
    if main.Name then
        main.Name:SetParent(contextual)
        main.Name:SetWidth(100)
        main.Name:SetJustifyH("CENTER")
        ns.SetPointOnce(main.Name, "TOPLEFT", host, "TOPLEFT", 36, -30)
    end
    if main.ReputationColor then
        ns.SetTex(main.ReputationColor, "levelBackground")
        main.ReputationColor:SetTexCoord(0, 1, 0, 1)
        main.ReputationColor:SetSize(BAR_W, 19)
        ns.SetPointOnce(main.ReputationColor, "TOPRIGHT", frame, "TOPRIGHT", -86, -26)
    end
    if main.LevelText then
        main.LevelText:SetParent(contextual)
        main.LevelText:SetFontObject("GameFontNormalSmall")
        main.LevelText:SetJustifyH("CENTER")
        ns.SetPointOnce(main.LevelText, "CENTER", host, "TOPLEFT", 198, -71)
    end
    ns.Fade(main.LevelBackgroundCircle)
    ns.FadeCircles(main)
    ns.FadeCircles(contextual)
    if contextual.HighLevelTexture then
        ns.SetTex(contextual.HighLevelTexture, "skull")
        contextual.HighLevelTexture:SetTexCoord(0, 1, 0, 1)
        contextual.HighLevelTexture:SetSize(16, 16)
        ns.SetPointOnce(contextual.HighLevelTexture, "CENTER", host, "TOPLEFT", 197, -71)
    end
    if contextual.LeaderIcon then
        ns.SetTex(contextual.LeaderIcon, "leaderIcon")
        contextual.LeaderIcon:SetTexCoord(0, 1, 0, 1)
        contextual.LeaderIcon:SetSize(16, 16)
        ns.SetPointOnce(contextual.LeaderIcon, "TOPRIGHT", frame, "TOPRIGHT", -24, -14)
    end
    if contextual.RaidTargetIcon and container.Portrait then
        ns.SetPointOnce(contextual.RaidTargetIcon, "CENTER", container.Portrait, "TOP", 2, -2)
    end
    if contextual.QuestIcon then
        ns.SetTex(contextual.QuestIcon, "questBadge")
        contextual.QuestIcon:SetTexCoord(0, 1, 0, 1)
        contextual.QuestIcon:SetSize(32, 32)
        ns.SetPointOnce(contextual.QuestIcon, "TOP", frame, "TOP", 32, -16)
    end
    if contextual.NumericalThreat then
        ns.SetPointOnce(contextual.NumericalThreat, "BOTTOM", frame, "TOP", -30, -26)
    end
    local function TargetPvp(self)
        if not active then return end
        ns.Fade(contextual.PrestigePortrait)
        ns.Fade(contextual.PrestigeBadge)
        FadePvpCircle(frame)
        ns.FadeCircles(contextual)
        ns.FadeCircles(main)
        if contextual.PvpIcon then
            local horde = UnitFactionGroup(self.unit or unit) == "Horde"
            ns.SetPointOnce(contextual.PvpIcon, "TOPRIGHT", frame, "TOPRIGHT", horde and 3 or -4, horde and -22 or -24)
        end
    end
    ns.HookMethod(frame, "CheckFaction", TargetPvp)
    TargetPvp(frame)

    frames[frame] = { unit = unit, frame = frame, health = health, power = power, bg = bg }
    ApplyClassification(frame)
    Update(frames[frame])

    ns.HookMethod(frame, "CheckClassification", ApplyClassification)
    ns.HookMethod(frame, "CheckLevel", function(self)
        if not active then return end
        local m = ns.Path(self, "TargetFrameContent", "TargetFrameContentMain")
        if m and m.LevelText and self.fcui and self.fcui.host then
            ns.SetPointOnce(m.LevelText, "CENTER", self.fcui.host, "TOPLEFT", 198, -71)
        end
    end)
    ns.HookMethod(frame, "AnchorAuraContainer", function(self)
        if not active or not self.GetAuraContainer then return end
        local auras = self:GetAuraContainer()
        if auras and self.TargetFrameContainer.FrameTexture then
            ns.SetPointOnce(auras, "TOPLEFT", self.TargetFrameContainer.FrameTexture, "BOTTOMLEFT", 5, 32)
        end
    end)
    ns.HookScriptOnce(frame, "OnShow", function(self)
        local entry = frames[self]
        if active and entry then Update(entry) end
    end)

    -- Target of target: small frame reskinned in place.
    local tot = frame.totFrame
    if tot then
        if tot.FrameTexture then
            ns.SetTex(tot.FrameTexture, "targetOfTarget")
            tot.FrameTexture:SetTexCoord(0.015625, 0.7265625, 0, 0.703125)
            tot.FrameTexture:SetSize(93, 45)
            ns.SetPointOnce(tot.FrameTexture, "TOPLEFT", tot, "TOPLEFT", 0, 0)
        end
        if tot.Portrait then tot.Portrait:SetSize(35, 35) end
        if tot.Name then
            tot.Name:SetWidth(100)
            ns.SetPointOnce(tot.Name, "BOTTOMLEFT", tot, "BOTTOMLEFT", 42, 7)
        end
        local totBg = ns.OwnTexture(tot, "barBg", "BACKGROUND")
        totBg:SetColorTexture(0, 0, 0, 0.5)
        totBg:SetSize(46, 15)
        ns.SetPointOnce(totBg, "TOPRIGHT", tot, "TOPRIGHT", -29, -15)
        if tot.HealthBar then
            tot.HealthBar:SetStatusBarTexture((ns.TexPath(UI_STATUSBAR)))
            tot.HealthBar:SetSize(46, 7)
            ns.SetPointOnce(tot.HealthBar, "TOPRIGHT", tot, "TOPRIGHT", -29, -15)
            if tot.HealthBarMask then ns.Fade(tot.HealthBarMask) end
        end
        if tot.ManaBar then
            tot.ManaBar:SetStatusBarTexture((ns.TexPath(UI_STATUSBAR)))
            tot.ManaBar:SetSize(46, 7)
            ns.SetPointOnce(tot.ManaBar, "TOPRIGHT", tot, "TOPRIGHT", -29, -23)
            if tot.ManaBarMask then ns.Fade(tot.ManaBarMask) end
        end
        local totName = tot:GetName()
        if totName then
            local spots = { { -23, -8 }, { -10, -8 }, { -23, -21 }, { -10, -21 } }
            for i = 1, 4 do
                local debuff = _G[totName .. "Debuff" .. i]
                if debuff then ns.SetPointOnce(debuff, "TOPLEFT", tot, "TOPRIGHT", spots[i][1], spots[i][2]) end
            end
        end
    end
end

------------------------------------------------------------------ pet

local function SkinPet()
    local frame = PetFrame
    if not frame then return end
    frame:SetSize(128, 53)
    if PetPortrait then ns.SetPointOnce(PetPortrait, "TOPLEFT", frame, "TOPLEFT", 7, -6) end
    if PetName then
        PetName:SetWidth(0)
        ns.SetPointOnce(PetName, "BOTTOMLEFT", frame, "BOTTOMLEFT", 53, 33)
    end
    if PetFrameTexture then
        ns.SetTex(PetFrameTexture, "smallTargetingFrame")
        PetFrameTexture:SetTexCoord(0, 1, 0, 1)
        PetFrameTexture:SetSize(128, 64)
        ns.SetPointOnce(PetFrameTexture, "TOPLEFT", frame, "TOPLEFT", 0, -2)
    end
    if PetFrameFlash then
        ns.SetTex(PetFrameFlash, "partyFlash")
        PetFrameFlash:SetTexCoord(0, 1, 1, 0)
        PetFrameFlash:SetSize(128, 64)
        ns.SetPointOnce(PetFrameFlash, "TOPLEFT", frame, "TOPLEFT", -4, 11)
        PetFrameFlash:SetDrawLayer("BACKGROUND")
    end
    local bars = { { PetFrameHealthBar, -22, PetFrameHealthBarMask, { PetFrameHealthBarText, PetFrameHealthBarTextLeft, PetFrameHealthBarTextRight } },
        { PetFrameManaBar, -29, PetFrameManaBarMask, { PetFrameManaBarText, PetFrameManaBarTextLeft, PetFrameManaBarTextRight } } }
    for _, b in ipairs(bars) do
        local bar, y, mask, texts = b[1], b[2], b[3], b[4]
        if bar then
            bar:SetStatusBarTexture((ns.TexPath(UI_STATUSBAR)))
            bar:SetSize(69, 8)
            ns.SetPointOnce(bar, "TOPLEFT", frame, "TOPLEFT", 47, y)
            if mask then ns.Fade(mask) end
            AttachTexts(bar, texts, { { "CENTER", 0, 0 }, { "LEFT", 0, 0 }, { "RIGHT", -1, 0 } })
        end
    end
    KeepBar(PetFrameHealthBar, "health")
    KeepBar(PetFrameManaBar, "power")
    if PetAttackModeTexture then
        ns.SetTex(PetAttackModeTexture, "petAttackStatus")
        PetAttackModeTexture:SetTexCoord(0.703125, 1, 0, 1)
        PetAttackModeTexture:SetSize(76, 64)
        ns.SetPointOnce(PetAttackModeTexture, "TOPLEFT", frame, "TOPLEFT", 6, -9)
    end
    if PetHitIndicator then ns.SetPointOnce(PetHitIndicator, "CENTER", frame, "TOPLEFT", 28, -27) end
end

------------------------------------------------------------------ party

local function SkinPartyMember(frame)
    if frame.Texture then
        ns.SetTex(frame.Texture, "partyFrame")
        frame.Texture:SetTexCoord(0, 1, 0, 1)
        frame.Texture:SetSize(128, 64)
        ns.SetPointOnce(frame.Texture, "TOPLEFT", frame, "TOPLEFT", 0, -10)
        frame.Texture:SetDrawLayer("ARTWORK", 7)
    end
    if frame.Portrait then ns.SetPointOnce(frame.Portrait, "TOPLEFT", frame, "TOPLEFT", 7, -14) end
    if frame.Name then
        frame.Name:SetWidth(0)
        ns.SetPointOnce(frame.Name, "TOPLEFT", frame, "TOPLEFT", 49, -7)
    end
    local bg = ns.OwnTexture(frame, "barBg", "BACKGROUND", -7)
    bg:SetColorTexture(0, 0, 0, 0.5)
    bg:SetSize(72, 20)
    ns.SetPointOnce(bg, "TOPLEFT", frame, "TOPLEFT", 45, -19)
    -- Our bars where the 1.x bars sat, Blizzard's faded out underneath
    -- and stretched over ours so their hover still shows the numbers,
    -- the same way the player and target frames are done.
    local host = frame.fcui and frame.fcui.host
    if not host then
        host = CreateFrame("Frame", nil, frame)
        host:EnableMouse(false)
        frame.fcui = frame.fcui or {}
        frame.fcui.host = host
    end
    host:SetAllPoints(frame)
    -- The bars go under the frame's own art: the party sheet's borders
    -- overlap the bar edges, which is what keeps them inside the frame.
    -- The text is parented to the frame so it draws over the art.
    local under = math.max(0, frame:GetFrameLevel() - 1)
    if host:GetFrameLevel() ~= under then host:SetFrameLevel(under) end
    local health = ns.CreateBar(host, "health", 70, 10)
    ns.SetPointOnce(health, "TOPLEFT", host, "TOPLEFT", 45, -19)
    health:SetStatusBarColor(0, 1, 0)
    local power = ns.CreateBar(host, "power", 74, 7)
    ns.SetPointOnce(power, "TOPLEFT", host, "TOPLEFT", 41, -30)
    local container = frame.HealthBarContainer
    local blizzHealth = ns.Path(frame, "HealthBarContainer", "HealthBar")
    if container then
        ns.Fade(container)
        if blizzHealth then
            ns.SetPointOnce(blizzHealth, "TOPLEFT", health, "TOPLEFT", 0, 0)
            blizzHealth:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)
            AttachTexts(health, { container.CenterText, container.LeftText, container.RightText },
                { { "CENTER", 0, 0 }, { "LEFT", 0, 0 }, { "RIGHT", -1, 0 } }, frame)
            AttachOverlays(blizzHealth, health, container.HealthBarMask)
        end
    end
    local mana = frame.ManaBar
    if mana then
        ns.Fade(mana)
        ns.SetPointOnce(mana, "TOPLEFT", power, "TOPLEFT", 0, 0)
        mana:SetPoint("BOTTOMRIGHT", power, "BOTTOMRIGHT", 0, 0)
        AttachTexts(power, { mana.CenterText, mana.LeftText, mana.RightText },
            { { "CENTER", 0, 0 }, { "LEFT", 0, 0 }, { "RIGHT", -1, 0 } }, frame)
    end
    frames[frame] = { unit = frame.unit or "party1", frame = frame, health = health, power = power }
    Update(frames[frame])
    local overlay = frame.PartyMemberOverlay
    if overlay then
        if overlay.LeaderIcon then
            ns.SetTex(overlay.LeaderIcon, "leaderIcon")
            overlay.LeaderIcon:SetTexCoord(0, 1, 0, 1)
            overlay.LeaderIcon:SetSize(16, 16)
            ns.SetPointOnce(overlay.LeaderIcon, "TOPLEFT", frame, "TOPLEFT", 0, -8)
        end
        if overlay.RoleIcon then ns.SetPointOnce(overlay.RoleIcon, "TOPLEFT", frame, "TOPLEFT", 7, -41) end
        if overlay.PVPIcon then ns.SetPointOnce(overlay.PVPIcon, "TOPLEFT", frame, "TOPLEFT", -9, -23) end
    end
    if frame.Flash then
        ns.SetTex(frame.Flash, "partyFlash")
        frame.Flash:SetTexCoord(0, 1, 0, 1)
        frame.Flash:SetSize(128, 64)
        ns.SetPointOnce(frame.Flash, "TOPLEFT", frame, "TOPLEFT", -3, -6)
        frame.Flash:SetDrawLayer("BACKGROUND", 0)
    end
    ns.HookMethod(frame, "ToPlayerArt", function(self) if active then SkinPartyMember(self) end end)
    ns.HookMethod(frame, "UpdateNameTextAnchors", function(self)
        if active and self.Name then ns.SetPointOnce(self.Name, "TOPLEFT", self, "TOPLEFT", 49, -7) end
    end)
end

local partyHooked = false
SkinParty = function()
    local pool = PartyFrame and PartyFrame.PartyMemberFramePool
    if not pool then return end
    for frame in pool:EnumerateActive() do SkinPartyMember(frame) end
    -- Members join after we first ran: skin whatever the pool hands out
    -- each time Blizzard lays the party out.
    if not partyHooked then
        partyHooked = true
        ns.HookMethod(PartyFrame, "UpdatePartyFrames", function() if active then SkinParty() end end)
        ns.HookMethod(PartyFrame, "Layout", function() if active then SkinParty() end end)
    end
end

------------------------------------------------------------------ raid manager

-- The raid frame manager parks a tall panel at the screen's left edge
-- whenever you are grouped; 1.x had nothing there. While it is collapsed
-- its backing fades and its arrow sits at the panel's top, below the
-- player frame, so only the arrow shows. Expanding it brings the panel
-- back untouched.
local managerHooked = false
local function LayoutRaidManager()
    local manager = CompactRaidFrameManager
    if not manager then return end
    local arrow = manager.toggleButtonForward
    if active then
        if manager.Background then manager.Background:SetAlpha(manager.collapsed and 0 or 1) end
        if arrow then
            arrow:ClearAllPoints()
            arrow:SetPoint("TOPRIGHT", manager, "TOPRIGHT", -7, 0)
        end
    else
        if manager.Background then manager.Background:SetAlpha(1) end
        if arrow then
            arrow:ClearAllPoints()
            arrow:SetPoint("RIGHT", manager, "RIGHT", -7, 0)
        end
    end
end
local function SkinRaidManager()
    if not CompactRaidFrameManager then return end
    if not managerHooked then
        managerHooked = true
        ns.HookGlobal("CompactRaidFrameManager_Collapse", LayoutRaidManager)
        ns.HookGlobal("CompactRaidFrameManager_Expand", LayoutRaidManager)
    end
    LayoutRaidManager()
end

------------------------------------------------------------------ module

local function Apply()
    active = true
    if not driver then
        driver = CreateFrame("Frame")
        driver:SetScript("OnEvent", OnEvent)
        for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
            "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "PLAYER_ENTERING_WORLD", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "GROUP_ROSTER_UPDATE" }) do
            pcall(driver.RegisterEvent, driver, event)
        end
        HookPlayer()
        -- Blizzard's own refreshes of the bars we keep.
        ns.HookGlobal("UnitFrameManaBar_UpdateType", RecolorKept)
        ns.HookGlobal("UnitFrameHealthBar_Update", RecolorKept)
        ns.HookGlobal("UnitFrameManaBar_Update", RecolorKept)
    end
    SkinPlayer()
    SkinTarget(TargetFrame, "target")
    SkinTarget(FocusFrame, "focus")
    SkinPet()
    SkinParty()
    SkinRaidManager()
end

-- The frames keep our art until a reload; only the live pieces step aside.
local function Restore()
    active = false
    LayoutRaidManager()
    for _, entry in pairs(frames) do
        if entry.health then entry.health:Hide() end
        if entry.power then entry.power:Hide() end
    end
    if PlayerFrame and PlayerFrame.fcui and PlayerFrame.fcui.host then PlayerFrame.fcui.host:Hide() end
    for _, frame in ipairs({ TargetFrame, FocusFrame }) do
        if frame and frame.fcui and frame.fcui.host then frame.fcui.host:Hide() end
        local main = ns.Path(frame, "TargetFrameContent", "TargetFrameContentMain")
        if main then
            ns.Unfade(ns.Path(main, "HealthBarsContainer", "HealthBar"))
            ns.Unfade(main.ManaBar)
        end
    end
    local pmain = ns.Path(PlayerFrame, "PlayerFrameContent", "PlayerFrameContentMain")
    if pmain then
        ns.Unfade(pmain.HealthBarsContainer)
        ns.Unfade(pmain.ManaBarArea)
    end
    ns.needsReload = true
end

ns.RegisterModule("unitFrames", { apply = Apply, restore = Restore })
