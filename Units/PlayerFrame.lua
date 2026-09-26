local _, ns = ...

-- Player frame on 1.x art: bars, name/level spots, rest/combat icons, faction emblem.

local UF = ns.UF
local On, Busy, Keeper, Update = UF.On, UF.Busy, UF.Keeper, UF.Update
local BuildBars, PlaceName, PlaceLevel, BarTexts, AttachOverlays = UF.BuildBars, UF.PlaceName, UF.PlaceLevel, UF.BarTexts, UF.AttachOverlays
local FadePvpCircle, FadePvpBadges, FadePvpPieces = UF.FadePvpCircle, UF.FadePvpBadges, UF.FadePvpPieces
local OwnPvpIcon, HideOwnPvp, HideHost = UF.OwnPvpIcon, UF.HideOwnPvp, UF.HideHost
local Dress, DressNew, FadeKeys = ns.Dress, ns.DressNew, ns.FadeKeys
local SetPointIf, SetShownIf, SetVertexColorIf, IsSecret = ns.SetPointIf, ns.SetShownIf, ns.SetVertexColorIf, ns.IsSecret

local FRAME_W, FRAME_H, BAR_W, PORTRAIT = UF.FRAME_W, UF.FRAME_H, UF.BAR_W, UF.PORTRAIT
local NAME_TEXT_Y, LEVEL_TEXT_Y = UF.NAME_TEXT_Y, UF.LEVEL_TEXT_Y
local BAR_X, NAME_Y = 87, -26
local NAME_X, LEVEL_X = 97, 34

local FULL = { 0, 1, 0, 1 }
-- Targeting sheet mirrored for the left side.
local ART = { coords = { 1, 0.09375, 0, 0.78125 }, w = FRAME_W, h = FRAME_H, point = "TOPLEFT", x = -19, y = -4, layer = "BORDER" }
local ALT_ART = { coords = ART.coords, w = FRAME_W, h = FRAME_H, point = "TOPLEFT", x = -19, y = -4 }
local FLASH = { coords = { 0.9453125, 0, 0, 0.181640625 }, w = 242, h = 93, point = "TOPLEFT", x = -6, y = -4, layer = "BACKGROUND" }
-- The elite glow, mirrored from the target's (2 in and 9 up from its plain glow, so 2 out on the flipped side).
local ELITE_FLASH = { coords = { 0.9453125, 0, 0.181640625, 0.400390625 }, w = 242, h = 112, point = "TOPLEFT", x = -8, y = 5,
    layer = "BACKGROUND" }
local STATUS = { coords = { 0, 0.74609375, 0, 0.53125 }, w = 190, h = 66, point = "TOPLEFT", x = 16, y = -12, blend = "ADD" }
local MASK = { w = PORTRAIT, h = PORTRAIT, point = "TOPLEFT", x = 23, y = -16 }
local LEVEL_BG = { own = "levelBg", layer = "BORDER", w = BAR_W, h = 19, point = "TOPLEFT", x = BAR_X, y = NAME_Y, vertex = { 0, 0, 0 }, show = false }
-- Era's spots and sizes on the round ring (Era x - 1.5, y - 0.5 on our frame).
local REST = { own = "rest", layer = "OVERLAY", coords = { 0, 0.5, 0, 0.421875 }, w = 31, h = 33, point = "TOPLEFT", x = 18, y = -52.5 }
local ATTACK = { own = "attack", layer = "OVERLAY", coords = { 0.5, 1, 0, 0.484375 }, w = 32, h = 32, point = "TOPLEFT", x = 19, y = -52.5 }
local LEADER = { coords = FULL, w = 16, h = 16, point = "TOPLEFT", x = 21, y = -16 }
-- 1.x group tab: bottom left (97, -20) on the 1.12 frame is (78, -24) on ours; the right cap follows the text.
local GROUP_TEXT_X, GROUP_TEXT_Y = 98, -18
local GROUP_L = { own = "tabLeft", layer = "BACKGROUND", sublevel = -1, coords = { 0, 0.1875, 0, 1 }, w = 24, h = 16, point = "TOPLEFT", x = 78, y = -8, alpha = 0.3 }
local GROUP_R = { own = "tabRight", layer = "BACKGROUND", sublevel = -1, coords = { 0.53125, 0.71875, 0, 1 }, w = 24, h = 16, point = "TOPRIGHT", relPoint = "RIGHT", x = 20, y = 10, alpha = 0.3 }
local GROUP_M = { own = "tabMid", layer = "BACKGROUND", sublevel = -1, coords = { 0.1875, 0.53125, 0, 1 }, h = 16, alpha = 0.3 }
local TEXTS = { { "CENTER", 0, 0 }, { "LEFT", 6, 0 }, { "RIGHT", -4, 0 } }
local ART_PIECES = { "FrameTexture", "AlternatePowerFrameTexture", "FrameFlash" }
local STATE_ICONS = { "PlayerRestLoop", "AttackIcon", "PlayerPortraitCornerIcon" }
local CLIENT_BARS = { "HealthBarsContainer", "ManaBarArea" }
-- A class colour strip another addon lays on the client's player frame (the modern name band, placed for the default
-- frame): faded, its colour shown in our name box as the target's reaction colour is.
-- Known by its atlas (compared lower case) or by its spot on the content frame.
local CLASS_BAND_ATLAS = "ui-hud-unitframe-target-portraiton-type"
local CLASS_BAND_X, CLASS_BAND_Y = 75, -25
-- Our name box; the other addon's strip; the content frame's region count and last region when last looked (our
-- skin moves a region off it, so the count alone reads the same once the strip is added).
local nameBg, classBand, bandLookedAt, bandLastSeen

-- The client re-sets its atlas on art changes (combat, low health); textures are unprotected, so ours returns mid fight.
local function PlayerArt()
    local frame = PlayerFrame
    local container = frame and frame.PlayerFrameContainer
    if not container then return end
    -- The elite dragon is a toggle (Elite frames, Player): the elite target sheet, flipped like the plain one.
    local elite = ns.db and ns.db.eliteFrames == true and ns.db.eliteFramePlayer ~= false
    local sheet = elite and "targetingElite" or "targetingFrame"
    Dress(container.FrameTexture, sheet, ART, frame)
    Dress(container.AlternatePowerFrameTexture, sheet, ALT_ART, frame)
    Dress(container.FrameFlash, "targetingFlash", elite and ELITE_FLASH or FLASH, frame)
    local main = ns.Path(frame, "PlayerFrameContent", "PlayerFrameContentMain")
    Dress(main and main.StatusTexture, "playerStatus", STATUS, frame)
    -- Modern circles return with the art; 1.x had none.
    local contextual = ns.Path(frame, "PlayerFrameContent", "PlayerFrameContentContextual")
    if contextual then
        FadePvpBadges(contextual)
        ns.FadeCircles(contextual)
    end
    if main then ns.FadeCircles(main) end
    FadePvpCircle(frame)
end

-- An atlas here means the client took the art back: ours are files.
local function PlayerArtTaken()
    local container = PlayerFrame and PlayerFrame.PlayerFrameContainer
    if not container then return false end
    for i = 1, #ART_PIECES do
        local region = container[ART_PIECES[i]]
        if region and region.GetAtlas and region:GetAtlas() then return true end
    end
    local main = ns.Path(PlayerFrame, "PlayerFrameContent", "PlayerFrameContentMain")
    local status = main and main.StatusTexture
    if status and status.GetAtlas and status:GetAtlas() then return true end
    return false
end

local function KeepPlayerArt()
    if not UF.active or not On("player") then return end
    if PlayerArtTaken() then PlayerArt() end
end

-- The client re-anchors name and level on art changes (vehicle, alt power).
local function KeepPlayerAnchors()
    if not UF.active or not On("player") then return end
    local host = PlayerFrame and PlayerFrame.fcui and PlayerFrame.fcui.host
    if not host then return end
    if PlayerName then SetPointIf(PlayerName, "TOPLEFT", host, "TOPLEFT", NAME_X, NAME_TEXT_Y) end
    if PlayerLevelText then SetPointIf(PlayerLevelText, "CENTER", host, "TOPLEFT", LEVEL_X, LEVEL_TEXT_Y) end
    if PlayerFrameGroupIndicatorText then SetPointIf(PlayerFrameGroupIndicatorText, "LEFT", host, "TOPLEFT", GROUP_TEXT_X, GROUP_TEXT_Y) end
end

local function BandVisit(region, main)
    if classBand or not region:IsObjectType("Texture") then return end
    local atlas = region:GetAtlas()
    local named = type(atlas) == "string" and not IsSecret(atlas) and atlas:lower() == CLASS_BAND_ATLAS
    if named or ns.IsAt(region, "TOPLEFT", main, "TOPLEFT", CLASS_BAND_X, CLASS_BAND_Y) == true then classBand = region end
end

local function KeepClassBand()
    if not UF.active or not nameBg or not On("player") then return end
    if not classBand then
        local main = ns.Path(PlayerFrame, "PlayerFrameContent", "PlayerFrameContentMain")
        local count = main and main:GetNumRegions()
        if not count or count == 0 then return end
        local last = select(count, main:GetRegions())
        if count == bandLookedAt and last == bandLastSeen then return end
        bandLookedAt, bandLastSeen = count, last
        ns.EachRegion(main, BandVisit, main)
        if not classBand then return end
    end
    ns.SetAlphaIf(classBand, 0)
    local shown = classBand:IsShown()
    SetShownIf(nameBg, shown)
    if shown then
        -- Its colour without its alpha: a texture's alpha is its vertex alpha, and the strip's is ours at 0.
        local r, g, b = classBand:GetVertexColor()
        SetVertexColorIf(nameBg, r, g, b, 1)
    end
end

-- Read by the dev addon's band probe.
function ns.ClassBandState()
    return classBand, nameBg, bandLookedAt, UF.keepers["player.classBand"] ~= nil
end

-- 1.x gold level: the client whitens it on every update. A scaled level keeps its green; a secret one goes gold.
local function KeepLevelColor()
    if not UF.active then return end
    local unit = PlayerFrame and PlayerFrame.unit or "player"
    local level, effective = UnitLevel(unit), UnitEffectiveLevel(unit)
    local hidden = IsSecret(level) or IsSecret(effective)
    if not hidden and level ~= effective then return end
    SetVertexColorIf(PlayerLevelText, 1, 0.82, 0)
end

local function SkinPlayer()
    if Busy() then return end
    local frame = PlayerFrame
    local container = frame and frame.PlayerFrameContainer
    local main = ns.Path(frame, "PlayerFrameContent", "PlayerFrameContentMain")
    local contextual = ns.Path(frame, "PlayerFrameContent", "PlayerFrameContentContextual")
    if not container or not main or not contextual then ns.MissingPiece("PlayerFrame layout") return end
    local healthContainer, manaArea = main.HealthBarsContainer, main.ManaBarArea
    local blizzHealth = healthContainer and healthContainer.HealthBar
    local blizzMana = manaArea and manaArea.ManaBar

    PlayerArt()
    if container.PlayerPortrait then
        container.PlayerPortrait:SetSize(PORTRAIT, PORTRAIT)
        ns.SetPointOnce(container.PlayerPortrait, "TOPLEFT", frame, "TOPLEFT", 23, -16)
    end
    Dress(container.PlayerPortraitMask, "portraitMask", MASK, frame)

    -- The backdrop spans the name strip too.
    local host, health, power = BuildBars(frame, container, contextual, BAR_X, 41, NAME_Y, "player", blizzHealth, blizzMana)

    if healthContainer then
        ns.Fade(healthContainer)
        if blizzHealth then
            BarTexts(frame, contextual, health, { blizzHealth.TextString, blizzHealth.LeftText, blizzHealth.RightText },
                TEXTS, blizzHealth, "player", "player", false)
            AttachOverlays(blizzHealth, health, healthContainer.HealthBarMask)
        end
        local loss = healthContainer.PlayerFrameHealthBarAnimatedLoss
        if loss then
            loss:SetParent(health)
            loss:ClearAllPoints()
            loss:SetAllPoints(health)
            ns.SetBarFill(loss)
            local tex = loss:GetStatusBarTexture()
            if tex and healthContainer.HealthBarMask and tex.RemoveMaskTexture then pcall(tex.RemoveMaskTexture, tex, healthContainer.HealthBarMask) end
        end
    end
    if manaArea then
        ns.Fade(manaArea)
        -- Its power animations draw the modern atlas, hidden by the fade.
        if blizzMana then
            BarTexts(frame, contextual, power, { blizzMana.TextString, blizzMana.LeftText, blizzMana.RightText },
                TEXTS, blizzMana, "player", "player", true)
        end
    end

    PlaceName(PlayerName, contextual, host, NAME_X)
    PlaceLevel(PlayerLevelText, contextual, host, LEVEL_X, "OVERLAY")
    if PlayerLevelText then Keeper("player.level", KeepLevelColor) end
    ns.Fade(main.LevelBackgroundCircle)
    ns.FadeCircles(main)
    ns.FadeCircles(contextual)
    nameBg = DressNew(host, "levelBackground", LEVEL_BG)
    Keeper("player.classBand", KeepClassBand)

    -- Rest and combat icons from the old state sheet.
    if main.StatusTexture then
        main.StatusTexture:SetParent(contextual)
        Dress(main.StatusTexture, "playerStatus", STATUS, frame)
    end
    local rest = DressNew(contextual, "stateIcon", REST, frame)
    local attack = DressNew(contextual, "stateIcon", ATTACK, frame)
    FadeKeys(contextual, STATE_ICONS)
    local function UpdateStatus()
        if not UF.active then return end
        local resting = IsResting()
        local inCombat = frame.inCombat or (UnitAffectingCombat and UnitAffectingCombat("player"))
        local showRest = resting and not inCombat
        local showAttack = (not resting and (inCombat or frame.onHateList)) and true or false
        SetShownIf(rest, showRest)
        SetShownIf(attack, showAttack)
        -- The zzz and swords sit on the level circle: hide the number, as 1.x did.
        if PlayerLevelText then SetShownIf(PlayerLevelText, not showRest and not showAttack) end
    end
    Keeper("player.status", UpdateStatus)

    -- Retail swaps the level for a role icon in instances; 1.x kept the level.
    local function LevelNotRole()
        if not UF.active then return end
        if contextual.RoleIcon then SetShownIf(contextual.RoleIcon, false) end
        if PlayerLevelText then SetShownIf(PlayerLevelText, not rest:IsShown() and not attack:IsShown()) end
    end
    Keeper("player.role", LevelNotRole)

    Dress(contextual.LeaderIcon, "leaderIcon", LEADER, frame)
    local function PlayerPvp(beat)
        if not UF.active then return end
        FadePvpPieces(frame, contextual, beat, main)
        local holder = frame.fcui and frame.fcui.texts
        local icon = OwnPvpIcon(frame, holder, "player", contextual.PVPIcon, "TOPLEFT", -1, -22)
        -- PvP timer over our emblem (18 in, 23 down its sheet); the client hangs it on its hidden icon or badge.
        if icon and PlayerPVPTimerText then
            if holder and PlayerPVPTimerText:GetParent() ~= holder then PlayerPVPTimerText:SetParent(holder) end
            SetPointIf(PlayerPVPTimerText, "CENTER", icon, "TOPLEFT", 21, 2)
        end
    end
    Keeper("player.pvp", PlayerPvp)
    -- Our tab rides the client's Show/Hide; its own frame keeps the client's anchors.
    local group, groupText = contextual.GroupIndicator, PlayerFrameGroupIndicatorText
    if group and groupText then
        ns.FadeAtlas(group, "groupindicator")
        SetPointIf(groupText, "LEFT", host, "TOPLEFT", GROUP_TEXT_X, GROUP_TEXT_Y)
        local left = DressNew(group, "groupIndicator", GROUP_L, host)
        local right = DressNew(group, "groupIndicator", GROUP_R, groupText)
        local mid = DressNew(group, "groupIndicator", GROUP_M)
        mid:ClearAllPoints()
        mid:SetPoint("LEFT", left, "RIGHT")
        mid:SetPoint("RIGHT", right, "LEFT")
    end

    UF.frames.player = { unit = "player", frame = frame, health = health, power = power }
    Keeper("player.anchors", KeepPlayerAnchors)
    Update(UF.frames.player)
end

local function RestorePlayer()
    if not PlayerFrame then return end
    UF.frames.player = nil
    HideOwnPvp(PlayerFrame)
    if classBand then classBand:SetAlpha(1) end
    ns.Unfade(ns.Path(PlayerFrame, "PlayerFrameContent", "PlayerFrameContentContextual", "PVPIcon"))
    HideHost(PlayerFrame)
    FadeKeys(ns.Path(PlayerFrame, "PlayerFrameContent", "PlayerFrameContentMain"), CLIENT_BARS, 1)
    ns.needsReload = true
end

UF.SkinPlayer, UF.RestorePlayer, UF.KeepPlayerArt = SkinPlayer, RestorePlayer, KeepPlayerArt
