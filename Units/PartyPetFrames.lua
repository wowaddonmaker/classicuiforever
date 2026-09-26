local _, ns = ...

-- Pet and party frames on 1.x art.

local UF = ns.UF
local On, Busy, Update = UF.On, UF.Busy, UF.Update
local Host, BarBg, Cover, BarTexts, AttachOverlays, KeepBar, HideHost = UF.Host, UF.BarBg, UF.Cover, UF.BarTexts, UF.AttachOverlays, UF.KeepBar, UF.HideHost
local Dress, FadeKeys, Near = ns.Dress, ns.FadeKeys, ns.Near

local FULL = { 0, 1, 0, 1 }
local PET_ART = { coords = FULL, w = 128, h = 64, point = "TOPLEFT", y = -2 }
local PET_FLASH = { coords = { 0, 1, 1, 0 }, w = 128, h = 64, point = "TOPLEFT", x = -4, y = 11, layer = "BACKGROUND" }
local PET_ATTACK = { coords = { 0.703125, 1, 0, 1 }, w = 76, h = 64, point = "TOPLEFT", x = 6, y = -9 }
local PARTY_ART = { coords = FULL, w = 128, h = 64, point = "TOPLEFT", y = -10 }
local PARTY_ART_LAYERED = { coords = FULL, w = 128, h = 64, point = "TOPLEFT", y = -10, layer = "ARTWORK", sublevel = 7 }
local PARTY_FLASH = { coords = FULL, w = 128, h = 64, point = "TOPLEFT", x = -3, y = -6 }
local PARTY_FLASH_LAYERED = { coords = FULL, w = 128, h = 64, point = "TOPLEFT", x = -3, y = -6, layer = "BACKGROUND", sublevel = 0 }
local PARTY_LEADER = { coords = FULL, w = 16, h = 16, point = "TOPLEFT", y = -8 }
local SMALL_TEXTS = { { "CENTER", 0, 0 }, { "LEFT", 3, 0 }, { "RIGHT", -3, 0 } }
-- Power slot starts 4 left of health (portrait curve): its text sits 4 further in to align the columns.
local PARTY_POWER_TEXTS = { { "CENTER", 2, 0 }, { "LEFT", 7, 0 }, { "RIGHT", -3, 0 } }
local PARTY_CLIENT_BARS = { "HealthBarContainer", "ManaBar" }
-- Pet bars: from the frame's top left, under its border (the rims cap their ends, as on the player frame).
local PET_HEALTH_X = 47
local PET_HEALTH_Y = -22
local PET_HEALTH_W = 69
local PET_HEALTH_H = 8
-- The resource bar fills its inset 1 further left and down than the health bar's numbers.
local PET_MANA_X = 46
local PET_MANA_Y = -29
local PET_MANA_W = 70
local PET_MANA_H = 9

------------------------------------------------------------------ pet

local function SkinPet()
    if Busy() then return end
    local frame = PetFrame
    if not frame then return end
    frame:SetSize(128, 53)
    if PetPortrait then ns.SetPointOnce(PetPortrait, "TOPLEFT", frame, "TOPLEFT", 7, -6) end
    if PetName then
        PetName:SetWidth(0)
        ns.SetPointOnce(PetName, "BOTTOMLEFT", frame, "BOTTOMLEFT", 53, 33)
    end
    -- The border rides a frame above the bars (the client's bars are the frame's children, over its own art), with the
    -- name, hit text and attack glow over it.
    local base = frame:GetFrameLevel()
    local art = ns.OwnFrame(frame, "petArt", base + 2)
    art:SetAllPoints(frame)
    for _, region in ipairs({ PetFrameTexture, PetName, PetHitIndicator, PetAttackModeTexture }) do
        if region and region:GetParent() ~= art then region:SetParent(art) end
    end
    if PetName then PetName:SetDrawLayer("OVERLAY") end
    if PetHitIndicator then PetHitIndicator:SetDrawLayer("OVERLAY") end
    Dress(PetFrameTexture, "smallTargetingFrame", PET_ART, frame)
    Dress(PetFrameFlash, "partyFlash", PET_FLASH, frame)
    local bars = { { PetFrameHealthBar, PET_HEALTH_X, PET_HEALTH_Y, PET_HEALTH_W, PET_HEALTH_H, PetFrameHealthBarMask,
            { PetFrameHealthBarText, PetFrameHealthBarTextLeft, PetFrameHealthBarTextRight }, false },
        { PetFrameManaBar, PET_MANA_X, PET_MANA_Y, PET_MANA_W, PET_MANA_H, PetFrameManaBarMask,
            { PetFrameManaBarText, PetFrameManaBarTextLeft, PetFrameManaBarTextRight }, true } }
    for _, b in ipairs(bars) do
        local bar, x, y, w, h, mask, texts = b[1], b[2], b[3], b[4], b[5], b[6], b[7]
        if bar then
            ns.SetBarFill(bar)
            ns.SetLevelIf(bar, base + 1)
            bar:SetSize(w, h)
            ns.SetPointOnce(bar, "TOPLEFT", frame, "TOPLEFT", x, y)
            if mask then ns.Fade(mask) end
            BarTexts(frame, nil, bar, texts, SMALL_TEXTS, bar, nil, "pet", b[8])
        end
    end
    KeepBar(PetFrameHealthBar, "health")
    KeepBar(PetFrameManaBar, "power")
    Dress(PetAttackModeTexture, "petAttackStatus", PET_ATTACK, frame)
    if PetHitIndicator then ns.SetPointOnce(PetHitIndicator, "CENTER", frame, "TOPLEFT", 28, -27) end
end

------------------------------------------------------------------ party

-- Forever's bronze pet ring and vehicle frame: silver without the theme.
local function DrainPartyTrim(frame, undo)
    local paint = undo and ns.UndrainBronze or ns.DrainBronze
    paint(ns.Path(frame, "PetFrame", "Texture"))
    paint(frame.VehicleTexture)
end

local function SkinPartyMember(frame)
    if Busy() then return end
    DrainPartyTrim(frame)
    Dress(frame.Texture, "partyFrame", PARTY_ART_LAYERED, frame)
    if frame.Portrait then ns.SetPointOnce(frame.Portrait, "TOPLEFT", frame, "TOPLEFT", 7, -14) end
    if frame.Name then
        frame.Name:SetWidth(0)
        ns.SetPointOnce(frame.Name, "TOPLEFT", frame, "TOPLEFT", 49, -7)
    end
    BarBg(frame, -7, 72, 20, frame, 45, -19)
    -- Bars under the art (its borders cap their ends); texts ride a frame above.
    local host = Host(frame, math.max(0, frame:GetFrameLevel() - 1))
    local health = ns.CreateBar(host, "health", 70, 10)
    ns.SetPointOnce(health, "TOPLEFT", host, "TOPLEFT", 45, -19)
    health:SetStatusBarColor(0, 1, 0)
    local power = ns.CreateBar(host, "power", 74, 7)
    ns.SetPointOnce(power, "TOPLEFT", host, "TOPLEFT", 41, -30)
    local unit = frame.unit or "party1"
    local container = frame.HealthBarContainer
    local blizzHealth = ns.Path(frame, "HealthBarContainer", "HealthBar")
    if container then
        ns.Fade(container)
        if blizzHealth then
            Cover(blizzHealth, health)
            BarTexts(frame, nil, health, { container.CenterText, container.LeftText, container.RightText },
                SMALL_TEXTS, blizzHealth, frame, unit, false)
            AttachOverlays(blizzHealth, health, container.HealthBarMask)
        end
    end
    local mana = frame.ManaBar
    if mana then
        ns.Fade(mana)
        Cover(mana, power)
        BarTexts(frame, nil, power, { mana.CenterText, mana.LeftText, mana.RightText },
            PARTY_POWER_TEXTS, mana, frame, unit, true)
    end
    UF.frames[frame] = { unit = unit, frame = frame, health = health, power = power }
    Update(UF.frames[frame])
    local overlay = frame.PartyMemberOverlay
    if overlay then
        Dress(overlay.LeaderIcon, "leaderIcon", PARTY_LEADER, frame)
        if overlay.RoleIcon then ns.SetPointOnce(overlay.RoleIcon, "TOPLEFT", frame, "TOPLEFT", 7, -41) end
        if overlay.PVPIcon then ns.SetPointOnce(overlay.PVPIcon, "TOPLEFT", frame, "TOPLEFT", -9, -23) end
    end
    Dress(frame.Flash, "partyFlash", PARTY_FLASH_LAYERED, frame)
end

-- From our passes, never a hook: one on the party layout runs inside it, and the raid frames set up next are refused health.
local function SkinParty()
    local pool = PartyFrame and PartyFrame.PartyMemberFramePool
    if not pool then return end
    if Busy() then return end
    for frame in pool:EnumerateActive() do SkinPartyMember(frame) end
end

-- The client re-lays party frames on its own (group level-up): art returns on its events (textures are fine
-- in combat), the full skin now or after combat.
local function PartyArtUndone(frame)
    local tex = frame.Texture
    if not tex then return false end
    -- The client may restore its atlas without touching size or place (a join mid fight); ours is a file, never an atlas.
    local atlas = tex.GetAtlas and tex:GetAtlas()
    if atlas and not ns.IsSecret(atlas) then return true end
    local w, h = tex:GetSize()
    local point, relativeTo, _, x, y = tex:GetPoint(1)
    -- Secret in combat: unknown.
    if ns.AnySecret(w, h, point, x, y) then return nil end
    if not Near(w or 0, 128, 0.5) or not Near(h or 0, 64, 0.5) then return true end
    return point ~= "TOPLEFT" or relativeTo ~= frame or not Near(x or 0, 0, 0.5) or not Near(y or 0, -10, 0.5)
end

local function KeepParty()
    if not UF.active or not On("party") then return end
    local pool = PartyFrame and PartyFrame.PartyMemberFramePool
    if not pool then return end
    -- Empty until the party frame first shows; skips the pool's iterator.
    local active = pool.GetNumActive and pool:GetNumActive()
    if not ns.IsSecret(active) and active == 0 then return end
    local frames = UF.frames
    for frame in pool:EnumerateActive() do
        local undone = frames[frame] and PartyArtUndone(frame)
        -- Unknown counts as undone for the cheap art, not the full skin.
        if undone or undone == nil and frames[frame] then
            Dress(frame.Texture, "partyFrame", PARTY_ART, frame)
            if frame.Portrait then ns.SetPointOnce(frame.Portrait, "TOPLEFT", frame, "TOPLEFT", 7, -14) end
            if frame.Name then ns.SetPointOnce(frame.Name, "TOPLEFT", frame, "TOPLEFT", 49, -7) end
            Dress(frame.Flash, "partyFlash", PARTY_FLASH, frame)
            DrainPartyTrim(frame)
            if undone and not Busy() then SkinPartyMember(frame) end
        end
    end
end

-- Roster events land before the client lays the party out: redo on later frames; same-frame timers share one.
local function SkinPartySoon()
    if not UF.active or not On("party") then return end
    SkinParty()
    ns.Sched.AfterPerFrame("unitFrames.party", 0, SkinParty)
    ns.Sched.AfterPerFrame("unitFrames.party", 0.3, SkinParty)
end

local function RestoreParty()
    local pool = PartyFrame and PartyFrame.PartyMemberFramePool
    if not pool then return end
    for frame in pool:EnumerateActive() do
        UF.frames[frame] = nil
        DrainPartyTrim(frame, true)
        HideHost(frame)
        FadeKeys(frame, PARTY_CLIENT_BARS, 1)
    end
    ns.needsReload = true
end

UF.SkinPet, UF.SkinParty, UF.SkinPartySoon, UF.KeepParty, UF.RestoreParty = SkinPet, SkinParty, SkinPartySoon, KeepParty, RestoreParty
