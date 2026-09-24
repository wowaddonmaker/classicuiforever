local _, ns = ...

-- Shared unit frame state: our bars over the faded client ones; clicks, menus and auras stay the client's.

local FadeKeys, EachKey = ns.FadeKeys, ns.EachKey

local UF = {
    active = false,
    -- Set when combat refused a pass; PLAYER_REGEN_ENABLED re-applies.
    combatPending = false,
    frames = {},    -- key -> { unit, frame, health, power[, bg] }
    keepers = {},   -- name -> fn(beat)
    FRAME_W = 232, FRAME_H = 100,
    BAR_W = 119, BAR_H = 12,
    -- Client frame is offset (19, -4) from the 1.x art: 1.x bars at (106, -41) land at (87, -45).
    HEALTH_Y = -45, POWER_Y = -56,
    -- Name and level text, off the host's top left.
    NAME_TEXT_Y = -30, LEVEL_TEXT_Y = -71,
    PORTRAIT = 64,
}
ns.UF = UF

-- Per-frame toggles under the module switch.
local KEYS = { player = "unitFramePlayer", target = "unitFrameTarget", focus = "unitFrameFocus", pet = "unitFramePet", party = "unitFrameParty" }
function UF.On(kind) return ns.db == nil or ns.db[KEYS[kind]] ~= false end

-- In combat unit frames and their children refuse points (blocked-addon warning): flag for after.
function UF.Busy()
    if not InCombatLockdown() then return false end
    UF.combatPending = true
    return true
end

------------------------------------------------------------------ keepers

-- Client rewrites are undone from our beat and events, never a hook: a pass our code joins is refused unit health.
function UF.Keeper(key, fn)
    UF.keepers[key] = fn
    fn()
end

-- Player keepers skip the beat: every client write they undo runs from a driver event (Mainline/PlayerFrame.lua OnEvent).
local EVENT_KEEPERS = { ["player.art"] = true, ["player.anchors"] = true, ["player.level"] = true,
    ["player.status"] = true, ["player.role"] = true, ["player.pvp"] = true }
UF.EVENT_KEEPERS = EVENT_KEEPERS

-- beat: true on the driver's 0.25 s beat, nil from an event.
function UF.KeepFrames(beat)
    if not UF.active then return end
    for key, fn in pairs(UF.keepers) do
        if not (beat and EVENT_KEEPERS[key]) then ns.SafeCall(fn, beat) end
    end
end

-- Kept client bars (pet) -> kind, re-dressed after the client's refresh; weak keys, never a field on its bar.
local keptBars = setmetatable({}, { __mode = "k" })

local function RecolorKept(bar)
    local kind = keptBars[bar]
    if not kind or not UF.active then return end
    ns.SetBarFill(bar)
    if kind == "health" then
        bar:SetStatusBarColor(0, 1, 0)
    else
        local unit = bar.unit or (bar:GetParent() and bar:GetParent().unit)
        if unit then bar:SetStatusBarColor(ns.PowerColor(unit)) end
    end
end

function UF.KeepBar(bar, kind)
    if not bar then return end
    keptBars[bar] = kind
    RecolorKept(bar)
end

-- The client repaints the pet bars white on its refresh events.
function UF.RepaintKept(unit)
    if unit ~= "pet" then return end
    RecolorKept(PetFrameHealthBar)
    RecolorKept(PetFrameManaBar)
end

------------------------------------------------------------------ bars

local ONCE, EVERY = { fill = "once" }, { fill = true }

-- Our child frame at parent.fcui[key], mouse off, filling the parent.
local function Child(parent, key, level)
    return ns.OwnFrame(parent, key, level, ONCE)
end
UF.Child = Child

-- Host for our bars, re-filled and re-levelled every pass.
function UF.Host(frame, level)
    return ns.OwnFrame(frame, "host", level, EVERY)
end

-- Texts get their own frame above the art; parented lower, the border covers them.
local function TextHolder(frame, above)
    return Child(frame, "texts", (above or frame):GetFrameLevel() + 3)
end

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

-- Client texts onto our bar, plus our both-numbers hover strings.
function UF.BarTexts(frame, above, bar, texts, offsets, clientBar, owner, unit, power)
    local holder = TextHolder(frame, above)
    AttachTexts(bar, texts, offsets, holder)
    UF.HoverBoth(clientBar, bar, holder, offsets, owner, unit, power)
end

local OVERLAY_BARS = { "MyHealPredictionBar", "OtherHealPredictionBar", "HealAbsorbBar", "TotalAbsorbBar" }
local OVERLAY_GLOWS = { "OverAbsorbGlow", "OverHealAbsorbGlow" }

-- Client heal prediction and absorb pieces follow our bar.
function UF.AttachOverlays(source, bar, mask)
    for _, key in ipairs(OVERLAY_BARS) do
        local piece = source[key]
        if piece then
            piece:SetParent(bar)
            piece:ClearAllPoints()
            piece:SetAllPoints(bar)
            if mask and piece.Fill and piece.Fill.RemoveMaskTexture then pcall(piece.Fill.RemoveMaskTexture, piece.Fill, mask) end
            if piece.Fill then piece.Fill:SetTexture((ns.TexPath("statusBar"))) end
        end
    end
    for _, key in ipairs(OVERLAY_GLOWS) do
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

-- Dark backdrop under a bar pair.
function UF.BarBg(owner, sublevel, w, h, rel, x, y)
    local bg = ns.OwnTexture(owner, "barBg", "BACKGROUND", sublevel)
    bg:SetColorTexture(0, 0, 0, 0.5)
    bg:SetSize(w, h)
    ns.SetPointOnce(bg, "TOPLEFT", rel, "TOPLEFT", x, y)
    return bg
end

-- The faded client bar keeps the mouse (its hover shows the numbers), so it covers ours exactly.
function UF.Cover(clientBar, bar)
    ns.SetPointOnce(clientBar, "TOPLEFT", bar, "TOPLEFT", 0, 0)
    clientBar:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
end

-- Bars under the art, art under icons and text; protected children are re-levelled only when different.
function UF.BuildBars(frame, container, contextual, x, bgH, bgY, unit, clientHealth, clientMana)
    local base = frame:GetFrameLevel()
    local host = UF.Host(frame, base + 1)
    ns.SetLevelIf(container, base + 3)
    ns.SetLevelIf(contextual, base + 4)
    local bg = UF.BarBg(host, nil, UF.BAR_W, bgH, host, x, bgY)
    local health = ns.CreateBar(host, "health", UF.BAR_W, UF.BAR_H)
    ns.SetPointOnce(health, "TOPLEFT", host, "TOPLEFT", x, UF.HEALTH_Y)
    health:SetStatusBarColor(ns.HealthColor(unit))
    local power = ns.CreateBar(host, "power", UF.BAR_W, UF.BAR_H)
    ns.SetPointOnce(power, "TOPLEFT", host, "TOPLEFT", x, UF.POWER_Y)
    if clientHealth then UF.Cover(clientHealth, health) end
    if clientMana then UF.Cover(clientMana, power) end
    return host, health, power, bg
end

-- Client name text over our bars, above the art.
function UF.PlaceName(name, contextual, host, x)
    if not name then return end
    name:SetParent(contextual)
    name:SetWidth(100)
    name:SetJustifyH("CENTER")
    ns.SetPointOnce(name, "TOPLEFT", host, "TOPLEFT", x, UF.NAME_TEXT_Y)
end

-- Client level text in the circle by the portrait, above the art.
function UF.PlaceLevel(level, contextual, host, x, layer)
    if not level then return end
    level:SetParent(contextual)
    if layer then level:SetDrawLayer(layer) end
    level:SetFontObject("GameFontNormalSmall")
    level:SetJustifyH("CENTER")
    ns.SetPointOnce(level, "CENTER", host, "TOPLEFT", x, UF.LEVEL_TEXT_Y)
end

-- Back to the modern look: hide our bar host.
function UF.HideHost(frame)
    if frame and frame.fcui and frame.fcui.host then frame.fcui.host:Hide() end
end

------------------------------------------------------------------ PvP

-- Retail's gold faction circle covers the level spot (1.x kept the level); unnamed in client Lua, so faded on every pass.
local PVP_PARTS = { "PlayerFrameContentMain", "PlayerFrameContentContextual", "TargetFrameContentMain", "TargetFrameContentContextual" }
local PVP_CIRCLE = { "PvpBackgroundCircle", "PvpBackgroundIcon" }
local PVP_BADGES = { "PrestigePortrait", "PrestigeBadge" }

local function EachPvpCircle(frame, fn)
    local content = frame.PlayerFrameContent or frame.TargetFrameContent
    if not content then return end
    for i = 1, #PVP_PARTS do
        local part = content[PVP_PARTS[i]]
        if part then EachKey(part, PVP_CIRCLE, fn) end
    end
end

local function FadePvpCircle(frame)
    EachPvpCircle(frame, ns.Fade)
end
UF.FadePvpCircle = FadePvpCircle

-- Honor badge over the portrait; 1.x had none.
function UF.FadePvpBadges(contextual)
    FadeKeys(contextual, PVP_BADGES)
end

-- frame -> pieces its last walk faded. Only fixed keyed regions ever carry a SmallCircle atlas, so the beat replays them.
local pvpPieces = setmetatable({}, { __mode = "k" })
local collected

local function Collect(region)
    if not region.SetAlpha then return end
    region:SetAlpha(0)
    collected[#collected + 1] = region
end

-- Badges, PvP circles and SmallCircle art of circles1/circles2: walked and kept off the beat, replayed on it.
function UF.FadePvpPieces(frame, contextual, beat, circles1, circles2)
    local list = pvpPieces[frame]
    if beat and list then
        for i = 1, #list do list[i]:SetAlpha(0) end
        return
    end
    if list then
        wipe(list)
    else
        list = {}
        pvpPieces[frame] = list
    end
    collected = list
    EachKey(contextual, PVP_BADGES, Collect)
    EachPvpCircle(frame, Collect)
    if circles1 then ns.FadeAtlas(circles1, "smallcircle", false, Collect) end
    if circles2 then ns.FadeAtlas(circles2, "smallcircle", false, Collect) end
    collected = nil
end

-- Our 1.x faction emblem above the art: with an honor level the client swaps its icon for the badge we fade.
local PVP_ART = {
    Horde = "Interface\\TargetingFrame\\UI-PVP-Horde",
    Alliance = "Interface\\TargetingFrame\\UI-PVP-Alliance",
    FFA = "Interface\\TargetingFrame\\UI-PVP-FFA",
}

local function PvpArtOf(unit)
    if UnitIsPVPFreeForAll and UnitIsPVPFreeForAll(unit) then return PVP_ART.FFA end
    if UnitIsPVP(unit) then return PVP_ART[UnitFactionGroup(unit) or ""] end
    return nil
end

-- Emblem for the unit's flag: nil for none, false when the lookup errors (secret) and the client's icon stays.
local function PvpArt(unit)
    local ok, art = pcall(PvpArtOf, unit)
    if not ok then return false end
    return art
end

-- Our emblem's last art and anchor frame: only OwnPvpIcon writes them.
local emblemArt = setmetatable({}, { __mode = "k" })
local emblemAt = setmetatable({}, { __mode = "k" })

function UF.OwnPvpIcon(frame, holder, unit, clientIcon, point, x, y)
    if not holder then return nil end
    local icon = ns.OwnTexture(holder, "pvpIcon", "OVERLAY")
    local art = PvpArt(unit)
    if art == false then
        icon:Hide()
        ns.Unfade(clientIcon)
        return nil
    end
    ns.Fade(clientIcon)
    if not art then
        icon:Hide()
        return nil
    end
    if emblemArt[icon] ~= art then
        icon:SetTexture(art)
        -- Never mirrored (the Alliance crest would show it); caller offsets allow for the emblem's top-left spot in its sheet.
        icon:SetTexCoord(0, 1, 0, 1)
        icon:SetSize(64, 64)
        emblemArt[icon] = art
    end
    if emblemAt[icon] ~= frame then
        ns.SetPointIf(icon, point, frame, point, x, y)
        emblemAt[icon] = frame
    end
    icon:Show()
    return icon
end

function UF.HideOwnPvp(frame)
    local holder = frame and frame.fcui and frame.fcui.texts
    local icon = holder and holder.fcui and holder.fcui.pvpIcon
    if icon then icon:Hide() end
end

------------------------------------------------------------------ fills

local function Update(entry, what)
    if not entry or not UnitExists(entry.unit) then return end
    if entry.frame and what == nil then FadePvpCircle(entry.frame) end
    if what ~= "power" and entry.health then ns.SetHealth(entry.health, entry.unit) end
    if what ~= "health" and entry.power then ns.SetPower(entry.power, entry.unit) end
end
UF.Update = Update

function UF.UpdateAll()
    for _, entry in pairs(UF.frames) do Update(entry) end
end
