local _, ns = ...

-- Colours, gold fonts and unit bar fills.

local IsSecret = ns.IsSecret

-- 1.x quest difficulty colours; the client's gold yellow reads orange on the old art.
local QUEST_COLOURS = {
    impossible = { 1, 0.1, 0.1 }, verydifficult = { 1, 0.5, 0.25 }, difficult = { 1, 0.92, 0 },
    standard = { 0.25, 0.75, 0.25 }, trivial = { 0.5, 0.5, 0.5 },
}
-- Quest log labels (All, the count) use the same yellow.
function ns.QuestYellow()
    local c = QUEST_COLOURS.difficult
    return c[1], c[2], c[3]
end

function ns.QuestLevelColor(level)
    level = tonumber(level) or 0
    local player = UnitLevel("player") or 1
    local diff = level - player
    local key
    if level <= 0 then
        key = "difficult"
    elseif diff >= 5 then
        key = "impossible"
    elseif diff >= 3 then
        key = "verydifficult"
    elseif diff >= -2 then
        key = "difficult"
    else
        local range = 5
        if UnitQuestTrivialLevelRange then
            local ok, r = pcall(UnitQuestTrivialLevelRange, "player")
            if ok and tonumber(r) then range = r end
        elseif GetQuestGreenRange then
            local ok, r = pcall(GetQuestGreenRange)
            if ok and tonumber(r) then range = r end
        end
        key = (-diff <= range) and "standard" or "trivial"
    end
    local c = QUEST_COLOURS[key]
    return c[1], c[2], c[3]
end

-- Game fonts in the old gold, whatever colour the client gives them.
local function GoldFont(name, base)
    local font = CreateFont(name)
    font:SetFontObject(base)
    font:SetTextColor(1, 0.82, 0)
    return font
end
ns.FONT_GOLD = GoldFont("ClassicUIForeverGold", "GameFontNormal")
ns.FONT_GOLD_SMALL = GoldFont("ClassicUIForeverGoldSmall", "GameFontNormalSmall")
-- A global font name others may use; nothing here reads it.
GoldFont("ClassicUIForeverGoldLarge", "GameFontNormalLarge")

-- 1.x skull: over ten levels above, or -1 (bosses), attackable units only.
-- UnitCanAttack is secret in a fight; the skull stands then.
function ns.SkullLevel(level, unit)
    if level == nil then return false end
    if IsSecret(level) then return false end
    if level < 0 then return true end
    if unit and UnitCanAttack then
        local foe = UnitCanAttack("player", unit)
        if not IsSecret(foe) and not foe then return false end
    end
    local mine = UnitLevel("player")
    if mine == nil or IsSecret(mine) then return false end
    return (level - mine) > 10
end

-- 1.x power colours; PowerBarColor covers anything not listed.
ns.POWER_COLORS = {
    MANA = { 0, 0, 1 }, RAGE = { 1, 0, 0 }, FOCUS = { 1, 0.5, 0.25 }, ENERGY = { 1, 1, 0 },
    RUNIC_POWER = { 0, 0.82, 1 }, LUNAR_POWER = { 0.3, 0.52, 0.9 }, MAELSTROM = { 0, 0.5, 1 },
    INSANITY = { 0.4, 0, 0.8 }, FURY = { 0.788, 0.259, 0.992 }, PAIN = { 1, 0.61, 0 },
    AMMOSLOT = { 0.8, 0.6, 0 }, FUEL = { 0, 0.55, 0.5 },
}

function ns.PowerColor(unit)
    local powerType, token, altR, altG, altB = UnitPowerType(unit)
    if IsSecret(token) or IsSecret(powerType) then return 0, 0, 1 end
    local c = token and ns.POWER_COLORS[token]
    if c then return c[1], c[2], c[3] end
    if altR and not IsSecret(altR) then return altR, altG, altB end
    local info = PowerBarColor and (PowerBarColor[token] or PowerBarColor[powerType])
    if info then return info.r, info.g, info.b end
    return 0, 0, 1
end

-- Our StatusBar with the 1.x fill; takes no mouse.
local BAR = { kind = "StatusBar", show = false }
function ns.CreateBar(parent, key, width, height)
    local bar = ns.OwnFrame(parent, key, nil, BAR)
    bar:SetSize(width, height)
    ns.SetBarFill(bar)
    bar:GetStatusBarTexture():SetTexCoord(0, 1, 0, 1)
    -- A restore hides the bar; the next apply reuses it.
    bar:Show()
    return bar
end

-- 12.x unit values are secret, even the player's: StatusBar takes them, arithmetic does not.
local function FillBar(bar, value, max)
    if value == nil or max == nil then return end
    if not IsSecret(max) and max <= 0 then
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        return
    end
    bar:SetMinMaxValues(0, max)
    bar:SetValue(value)
end

-- A class file's colour; nothing for a missing, secret or unknown class.
function ns.ClassRGB(classFile)
    if IsSecret(classFile) or not classFile then return end
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if color then return color.r, color.g, color.b end
end

-- In a dungeon UnitIsPlayer and UnitClass are secret: such a unit stays green.
function ns.HealthColor(unit)
    if ns.db and ns.db.classColorHealth and unit and UnitIsPlayer then
        local isPlayer = UnitIsPlayer(unit)
        if not IsSecret(isPlayer) and isPlayer then
            local _, class = UnitClass(unit)
            local r, g, b = ns.ClassRGB(class)
            if r then return r, g, b end
        end
    end
    return 0, 1, 0
end

function ns.SetHealth(bar, unit)
    FillBar(bar, UnitHealth(unit), UnitHealthMax(unit))
    bar:SetStatusBarColor(ns.HealthColor(unit))
end

function ns.SetPower(bar, unit)
    FillBar(bar, UnitPower(unit), UnitPowerMax(unit))
    bar:SetStatusBarColor(ns.PowerColor(unit))
end
