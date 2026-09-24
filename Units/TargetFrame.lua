local _, ns = ...

-- Target and focus frames on 1.x art, their aura rows, and the ToT under the portrait.

local UF = ns.UF
local Busy, Keeper, Update = UF.Busy, UF.Keeper, UF.Update
local Child, BarBg, BarTexts, AttachOverlays = UF.Child, UF.BarBg, UF.BarTexts, UF.AttachOverlays
local BuildBars, PlaceName, PlaceLevel = UF.BuildBars, UF.PlaceName, UF.PlaceLevel
local FadePvpPieces, OwnPvpIcon, HideOwnPvp, HideHost = UF.FadePvpPieces, UF.OwnPvpIcon, UF.HideOwnPvp, UF.HideHost
local Dress, DressNew, FadeKeys = ns.Dress, ns.DressNew, ns.FadeKeys
local SetPointIf, SetShownIf, IsSecret = ns.SetPointIf, ns.SetShownIf, ns.IsSecret

local FRAME_W, FRAME_H, BAR_W = UF.FRAME_W, UF.FRAME_H, UF.BAR_W
local HEALTH_Y, PORTRAIT, LEVEL_TEXT_Y = UF.HEALTH_Y, UF.PORTRAIT, UF.LEVEL_TEXT_Y
local BAR_X, NAME_X, LEVEL_X = 27, 36, 199

local FULL = { 0, 1, 0, 1 }
local ELITE_FLASH, PLAIN_FLASH = { 0, 0.9453125, 0.181640625, 0.400390625 }, { 0, 0.9453125, 0, 0.181640625 }
local CLASSIFICATION_ART = {
    rareelite = { key = "targetingRareElite", flashCoords = ELITE_FLASH, flashSize = { 242, 112 }, flashPoint = { -2, 5 } },
    elite = { key = "targetingElite", flashCoords = ELITE_FLASH, flashSize = { 242, 112 }, flashPoint = { -2, 5 } },
    worldboss = { key = "targetingElite", flashCoords = ELITE_FLASH, flashSize = { 242, 112 }, flashPoint = { -2, 5 } },
    rare = { key = "targetingRare", flashCoords = PLAIN_FLASH, flashSize = { 242, 93 }, flashPoint = { -4, -4 } },
    minus = { key = "targetingMinus", flashCoords = FULL, flashSize = { 256, 128 }, flashPoint = { -4, -4 }, flashKey = "targetingMinusFlash" },
    normal = { key = "targetingFrame", flashCoords = PLAIN_FLASH, flashSize = { 242, 93 }, flashPoint = { -4, -4 } },
}
local ART = { coords = { 0.09375, 1, 0, 0.78125 }, w = FRAME_W, h = FRAME_H, point = "TOPLEFT", x = 20, y = -4 }
local FLASH = { point = "TOPLEFT" }
local MASK = { w = PORTRAIT, h = PORTRAIT, point = "TOPRIGHT", x = -22, y = -16 }
local REPUTATION = { coords = FULL, w = BAR_W, h = 19, point = "TOPRIGHT", x = -86, y = -26 }
local SKULL = { coords = FULL, w = 16, h = 16, point = "CENTER", relPoint = "TOPLEFT", x = 199, y = -70 }
local LEADER = { coords = FULL, w = 16, h = 16, point = "TOPRIGHT", x = -24, y = -14 }
local QUEST = { coords = FULL, w = 32, h = 32, point = "TOP", x = 32, y = -16 }
local TOT_ART = { own = "art", layer = "ARTWORK", coords = { 0.015625, 0.7265625, 0, 0.703125 }, w = 93, h = 45, point = "TOPLEFT", show = true }
local TEXTS = { { "CENTER", 0, 0 }, { "LEFT", 5, 0 }, { "RIGHT", -7, 0 }, { "CENTER", 0, 0 }, { "CENTER", 0, 0 } }
local TOT_PIECES = { "FrameTexture", "HealthBar", "ManaBar" }
local TOT_BARS = { "HealthBar", "ManaBar" }
local TOT_DEBUFFS = { { -23, -8 }, { -10, -8 }, { -23, -21 }, { -10, -21 } }
local TARGET_EVENTS = { "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED" }
local UNIT_TARGET = { "UNIT_TARGET" }

-- The client drops the aura row 23 below the 1.x spot on layout changes: put back on each re-lay trigger (UnitFrames.lua).
local AURA_X, AURA_Y = 5, 32
local function KeepAuraRow(frame, force)
    local auras = frame.GetAuraContainer and frame:GetAuraContainer()
    local art = frame.TargetFrameContainer and frame.TargetFrameContainer.FrameTexture
    if not auras or not art then return end
    local point, relativeTo, relativePoint, x, y = auras:GetPoint(1)
    -- Secret in combat, never compared; a blind put re-lays the whole row, so only when forced.
    local hidden = IsSecret(point) or IsSecret(x) or IsSecret(y) or IsSecret(relativePoint)
    if hidden and not force then return end
    if not hidden and point == "TOPLEFT" and relativeTo == art and relativePoint == "BOTTOMLEFT"
        and math.abs((x or 0) - AURA_X) < 0.5 and math.abs((y or 0) - AURA_Y) < 0.5 then
        return
    end
    ns.SetPointOnce(auras, "TOPLEFT", art, "BOTTOMLEFT", AURA_X, AURA_Y)
end

local function ApplyClassification(frame)
    local entry = UF.frames[frame]
    if not entry or not UF.active then return end
    local container = frame.TargetFrameContainer
    local classification = UnitClassification(entry.unit)
    -- Secret in dungeons: never a table key.
    if IsSecret(classification) or classification == nil then classification = "normal" end
    local art = CLASSIFICATION_ART[classification] or CLASSIFICATION_ART.normal
    Dress(container.FrameTexture, art.key, ART, frame)
    Dress(container.Flash, art.flashKey or "targetingFlash", FLASH, frame, art.flashPoint[1], art.flashPoint[2],
        art.flashSize[1], art.flashSize[2], art.flashCoords)
    ns.Fade(container.BossPortraitFrameTexture)
    local contextual = ns.Path(frame, "TargetFrameContent", "TargetFrameContentContextual")
    if contextual then ns.Fade(contextual.BossIcon) end
    local main = ns.Path(frame, "TargetFrameContent", "TargetFrameContentMain")
    local minus = classification == "minus"
    if entry.power then entry.power:SetAlpha(minus and 0 or 1) end
    if entry.bg then entry.bg:SetSize(BAR_W, minus and 12 or 25) end
    if main and main.ReputationColor then SetShownIf(main.ReputationColor, not minus) end
    -- CastBars reads this to drop the spell bar.
    frame.haveElite = (classification == "elite" or classification == "worldboss" or classification == "rare" or classification == "rareelite") or nil
end

-- 1.x ToT: bottom right 35 in, 10 below the target art's; the art spot (20, -4, 232x100) is folded in
-- because a protected frame cannot anchor to a texture. Out of combat, only when moved.
local TOT_X, TOT_Y = 20 + 232 - 35 - 93, -4 - 100 - 10 + 45
local function PlaceTot(frame)
    local tot = frame and frame.totFrame
    if not tot or InCombatLockdown() then return end
    -- The small focus frame scales its ToT up over the cast bar: keep 1. Offsets are in the ToT's scale.
    if frame.smallSize then ns.SetScaleIf(tot, 1, 0.01) end
    local scale = tot:GetScale()
    if not scale or scale <= 0 then scale = 1 end
    local wantX, wantY = TOT_X / scale, TOT_Y / scale
    if ns.IsAt(tot, "TOPLEFT", frame, "TOPLEFT", wantX, wantY, 0.5) then return end
    ns.SetPointOnce(tot, "TOPLEFT", frame, "TOPLEFT", wantX, wantY)
end

-- The client refills its ToT bars every frame: they stay faded and ours fill from the unit.
local function FillTot(tot, fallbackUnit)
    local own = tot.fcui
    if not own or not own.totHealth then return end
    local unit = tot.unit or fallbackUnit
    if not unit or not UnitExists(unit) then return end
    ns.SetHealth(own.totHealth, unit)
    ns.SetPower(own.totPower, unit)
end

-- No ToT health event: 0.1 s beat while shown (the holder's visibility edges), at once on show or unit change
-- (ours are white until filled).
local function WatchTot(holder, tot, fallbackUnit, unit)
    local job = ns.Sched.Job({ name = "unitFrames.tot." .. unit, every = 0.1, awake = holder:IsVisible(), fn = function()
        if UF.active then FillTot(tot, fallbackUnit) end
    end })
    local function Now() job:RunNow() end
    -- Its show and hide re-configure the target's aura row (TargetOfTargetMixin OnShow/OnHide).
    local function Relaid()
        if UF.AuraHot then UF.AuraHot() end
    end
    holder:SetScript("OnShow", function()
        job:Wake()
        Now()
        Relaid()
    end)
    holder:SetScript("OnHide", function()
        job:Sleep()
        Relaid()
    end)
    ns.RegisterEvents(holder, TARGET_EVENTS)
    ns.RegisterEvents(holder, UNIT_TARGET, unit)
    holder:SetScript("OnEvent", Now)
end

-- Corpse or untold level (-1, "Level ??"): the client shows its skull and leaves the last unit's number in the text.
-- true then, false for a number it wrote, nil when secret.
local function ClientHidesLevel(unit)
    local isCorpse = _G.UnitIsCorpse
    local corpse = isCorpse and isCorpse(unit)
    if IsSecret(corpse) then return nil end
    if corpse then return true end
    local level = UnitEffectiveLevel(unit)
    if IsSecret(level) then return nil end
    if type(level) ~= "number" then return nil end
    return level <= 0
end

local function SkinTarget(frame, unit)
    if Busy() then return end
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
    Dress(container.PortraitMask, "portraitMask", MASK, frame)

    local host, health, power, bg = BuildBars(frame, container, contextual, BAR_X, 25, HEALTH_Y, unit, blizzHealth, blizzMana)

    if blizzHealth then
        ns.Fade(blizzHealth)
        BarTexts(frame, contextual, health, { blizzHealth.TextString, healthContainer.LeftText, healthContainer.RightText,
            healthContainer.DeadText, healthContainer.UnconsciousText }, TEXTS, blizzHealth, frame, unit, false)
        AttachOverlays(blizzHealth, health, healthContainer.HealthBarMask)
    end
    if blizzMana then
        ns.Fade(blizzMana)
        BarTexts(frame, contextual, power, { blizzMana.TextString, blizzMana.LeftText, blizzMana.RightText },
            TEXTS, blizzMana, frame, unit, true)
    end

    -- The reaction colour behind the name uses the old level strip.
    PlaceName(main.Name, contextual, host, NAME_X)
    Dress(main.ReputationColor, "levelBackground", REPUTATION, frame)
    PlaceLevel(main.LevelText, contextual, host, LEVEL_X)
    ns.Fade(main.LevelBackgroundCircle)
    ns.FadeCircles(main)
    ns.FadeCircles(contextual)
    Dress(contextual.HighLevelTexture, "skull", SKULL, host)
    Dress(contextual.LeaderIcon, "leaderIcon", LEADER, frame)
    if contextual.RaidTargetIcon and container.Portrait then
        ns.SetPointOnce(contextual.RaidTargetIcon, "CENTER", container.Portrait, "TOP", 2, -2)
    end
    Dress(contextual.QuestIcon, "questBadge", QUEST, frame)
    if contextual.NumericalThreat then
        ns.SetPointOnce(contextual.NumericalThreat, "BOTTOM", frame, "TOP", -30, -26)
    end
    local function TargetPvp(beat)
        if not UF.active then return end
        FadePvpPieces(frame, contextual, beat, contextual, main)
        OwnPvpIcon(frame, frame.fcui and frame.fcui.texts, frame.unit or unit, contextual.PvpIcon, "TOPRIGHT", 25, -22)
    end
    UF.frames[frame] = { unit = unit, frame = frame, health = health, power = power, bg = bg }
    Update(UF.frames[frame])

    -- The client rewrites these on its own passes; re-applied here.
    Keeper(unit .. ".frame", function(beat)
        if not UF.active or not UF.frames[frame] then return end
        -- The client shows these frames in its target/focus handlers, before our event: a hidden one waits.
        if beat and not frame:IsShown() then return end
        TargetPvp(beat)
        ApplyClassification(frame)
        if main.LevelText then
            SetPointIf(main.LevelText, "CENTER", host, "TOPLEFT", LEVEL_X, LEVEL_TEXT_Y)
            -- 1.x drew a skull far above you. The hidden text keeps the last unit's level: show only one the client wrote.
            local who = frame.unit or unit
            local clientSkull = ClientHidesLevel(who)
            local skull = clientSkull or ns.SkullLevel(UnitLevel(who), who)
            if skull or clientSkull ~= nil then
                SetShownIf(main.LevelText, not skull)
                if contextual.HighLevelTexture then SetShownIf(contextual.HighLevelTexture, skull) end
            end
        end
        -- On the beat the aura job puts the row back.
        if not beat then KeepAuraRow(frame, true) end
        -- The client refills the ToT bars gray, in its own place, on a unit change.
        local tot = frame.totFrame
        if tot and tot:IsShown() then FadeKeys(tot, TOT_PIECES) end
        PlaceTot(frame)
    end)

    -- ToT art on our frame above the bars (its slots cap the bar ends); pieces placed off the art's top left.
    local tot = frame.totFrame
    PlaceTot(frame)
    if tot then
        local top = math.max(tot.HealthBar and tot.HealthBar:GetFrameLevel() or 0,
            tot.ManaBar and tot.ManaBar:GetFrameLevel() or 0, tot:GetFrameLevel()) + 1
        local holder, isNew = Child(tot, "artHolder", top)
        local totArt = DressNew(holder, "targetOfTarget", TOT_ART, tot)
        ns.Fade(tot.FrameTexture)
        if tot.Portrait then
            tot.Portrait:SetSize(35, 35)
            ns.SetPointOnce(tot.Portrait, "TOPLEFT", tot, "TOPLEFT", 5, -5)
        end
        if tot.Name then
            tot.Name:SetParent(holder)
            tot.Name:SetWidth(100)
            ns.SetPointOnce(tot.Name, "BOTTOMLEFT", totArt, "BOTTOMLEFT", 42, 3)
        end
        BarBg(tot, nil, 46, 15, tot, 45, -15)
        FadeKeys(tot, TOT_BARS)
        local barHost = Child(tot, "barHost")
        local totHealth = ns.CreateBar(barHost, "health", 46, 7)
        ns.SetPointOnce(totHealth, "TOPLEFT", tot, "TOPLEFT", 45, -15)
        local totPower = ns.CreateBar(barHost, "power", 46, 7)
        ns.SetPointOnce(totPower, "TOPLEFT", tot, "TOPLEFT", 45, -23)
        tot.fcui.totHealth, tot.fcui.totPower = totHealth, totPower
        -- Above the bars: each sits a level over its host, and at equal level it drew over the art (square ends).
        ns.SetLevelIf(holder, math.max(totHealth:GetFrameLevel(), totPower:GetFrameLevel(), holder:GetFrameLevel() - 2) + 2)
        local fallbackUnit = (frame.unit or unit) .. "target"
        if isNew then WatchTot(holder, tot, fallbackUnit, frame.unit or unit) end
        -- Never white, even before a unit exists.
        totHealth:SetStatusBarColor(0, 1, 0)
        totPower:SetStatusBarColor(0, 0, 1)
        FillTot(tot, fallbackUnit)
        local totName = tot:GetName()
        if totName then
            for i = 1, 4 do
                local debuff = _G[totName .. "Debuff" .. i]
                if debuff then ns.SetPointOnce(debuff, "TOPLEFT", tot, "TOPRIGHT", TOT_DEBUFFS[i][1], TOT_DEBUFFS[i][2]) end
            end
        end
    end
end

local function RestoreTargetLike(frame)
    if not frame then return end
    UF.frames[frame] = nil
    HideOwnPvp(frame)
    ns.Unfade(ns.Path(frame, "TargetFrameContent", "TargetFrameContentContextual", "PvpIcon"))
    HideHost(frame)
    local main = ns.Path(frame, "TargetFrameContent", "TargetFrameContentMain")
    if main then
        ns.Unfade(ns.Path(main, "HealthBarsContainer", "HealthBar"))
        ns.Unfade(main.ManaBar)
    end
    local tot = frame.totFrame
    if tot and tot.fcui then
        if tot.fcui.artHolder then tot.fcui.artHolder:Hide() end
        if tot.fcui.barHost then tot.fcui.barHost:Hide() end
        FadeKeys(tot, TOT_PIECES, 1)
    end
    ns.needsReload = true
end

UF.KeepAuraRow, UF.SkinTarget, UF.RestoreTargetLike = KeepAuraRow, SkinTarget, RestoreTargetLike
