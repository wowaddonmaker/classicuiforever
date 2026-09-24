local _, ns = ...

-- 1.x stat boxes under the model (attributes left, melee/ranged right), resistances up the right.

local T = ns.sheet
local Safe = ns.Safe

local STAT_NAMES = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }
-- Top to bottom: arcane, fire, nature, frost, shadow.
local RESISTANCES = {
    { id = 6, coords = { 0, 1, 0.2265625, 0.33984375 } },
    { id = 2, coords = { 0, 1, 0, 0.11328125 } },
    { id = 3, coords = { 0, 1, 0.11328125, 0.2265625 } },
    { id = 4, coords = { 0, 1, 0.33984375, 0.453125 } },
    { id = 5, coords = { 0, 1, 0.453125, 0.56640625 } },
}
local GREEN, RED, WHITE = "|cff20ff20", "|cffff2020", "|cffffffff"
local ARMOR_NAME = ARMOR or "Armor"

-- Old three-piece box: caps and a stretched middle.
local BOX_TOP = { layer = "BACKGROUND", sublevel = 1, w = 115, h = 16, coords = { 0, 0.8984375, 0, 0.125 }, point = "TOPLEFT" }
local BOX_MID = { layer = "BACKGROUND", sublevel = 1, w = 115, coords = { 0, 0.8984375, 0.125, 0.1953125 }, point = "TOPLEFT", relPoint = "BOTTOMLEFT" }
local BOX_BOT = { layer = "BACKGROUND", sublevel = 1, w = 115, h = 16, coords = { 0, 0.8984375, 0.484375, 0.609375 }, point = "TOPLEFT", relPoint = "BOTTOMLEFT" }
local RESIST_ICON = { layer = "BACKGROUND", fill = true }

local function StatBox(parent, x, y, middleHeight)
    local top = ns.DressNew(parent, "charStatBox", BOX_TOP, parent, x, y)
    local middle = ns.DressNew(parent, "charStatBox", BOX_MID, top, nil, nil, nil, middleHeight)
    return (ns.DressNew(parent, "charStatBox", BOX_BOT, middle))
end

local function TipTitle(row) return row.tip end
local function TipDetail(row) return row.tip2 end
local STAT_TIP = { text = TipTitle, r = 1, g = 1, b = 1, lines = { { TipDetail, nil, nil, nil, true } } }

local function StatRow(parent, label, anchor, relPoint, x, y)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(104, 13)
    row:SetPoint("TOPLEFT", anchor, relPoint, x, y)
    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.label:SetText(label)
    row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.value:SetJustifyH("RIGHT")
    row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row:EnableMouse(true)
    ns.AttachTip(row, STAT_TIP)
    return row
end

local function ResistTip(row)
    local name = _G["DAMAGE_SCHOOL" .. (row.id + 1)] or _G["RESISTANCE" .. row.id .. "_NAME"] or ("Resistance " .. row.id)
    return name .. " " .. (RESISTANCE or "Resistance")
end
local RESIST_TIP = { text = ResistTip, r = 1, g = 1, b = 1 }

local function Number(value) return Safe(value, 0) end

-- Base in white, buffed total green or red, as 1.x showed it.
local function Buffed(base, pos, neg)
    base, pos, neg = Number(base), Number(pos), Number(neg)
    local total = base + pos + neg
    if pos == 0 and neg == 0 then return WHITE .. total .. "|r", nil end
    local color = (pos > 0 and neg == 0) and GREEN or ((neg < 0 and pos == 0) and RED or WHITE)
    local detail = string.format("%d (%d base", total, base)
    if pos > 0 then detail = detail .. string.format(" %s+%d|r", GREEN, pos) end
    if neg < 0 then detail = detail .. string.format(" %s%d|r", RED, neg) end
    return color .. total .. "|r", detail .. ")"
end

-- The 2.x stat panes take this area when their toggle is on.
function ns.SetClassicStatsShown(shown)
    if not T.attrs then return end
    T.attrs:SetShown(shown and true or false)
end

local statLabels = {}
local forever
local filledFor

-- A withheld switch to or from the pet: dashes, never the other unit's numbers.
local function Dashes()
    for i, row in ipairs(T.attributes) do
        row.value:SetText("--")
        row.tip, row.tip2 = statLabels[i], nil
    end
    for _, row in ipairs({ T.armor, T.attack, T.attackPower, T.damage, T.rangedAttack, T.rangedPower, T.rangedDamage }) do
        row.value:SetText("--")
    end
    T.armor.tip, T.armor.tip2 = ARMOR_NAME, nil
    for _, res in ipairs(T.resistances) do res.value:SetText("--") end
end

-- IsShown, not IsVisible: the doll stays shown while shut, so a combat open has pre-combat numbers.
-- Returns true when the stat panes were updated.
local function UpdateStats(opening)
    if not T.built or not T.active or not PaperDollFrame or not PaperDollFrame:IsShown() then return false end
    if ns.UpdateStatPanes then ns.UpdateStatPanes() end
    if ns.UpdateStatList then ns.UpdateStatList(opening) end
    -- The client's pet view shows the pet's numbers.
    local unit = T.PetView and T.PetView() and "pet" or "player"
    -- Secret in combat: keep the last numbers rather than zeros.
    local _, probe = UnitStat(unit, 1)
    if ns.IsSecret(probe) then
        if filledFor ~= unit then Dashes() end
        filledFor = unit
        return true
    end
    filledFor = unit
    for i, row in ipairs(T.attributes) do
        local _, effective, pos, neg = UnitStat(unit, i)
        local text, detail = Buffed(Number(effective) - Number(pos) - Number(neg), pos, neg)
        row.value:SetText(text)
        row.tip = statLabels[i] .. " " .. Number(effective)
        row.tip2 = detail
    end
    do
        local _, effective, _, pos, neg = UnitArmor(unit)
        local text, detail = Buffed(Number(effective) - Number(pos) - Number(neg), pos, neg)
        T.armor.value:SetText(text)
        T.armor.tip = ARMOR_NAME .. " " .. Number(effective)
        T.armor.tip2 = detail
    end
    -- Melee: weapon skill where the client has it, then power and damage.
    if UnitAttackBothHands then
        local base, mod = UnitAttackBothHands(unit)
        T.attack.value:SetText(Buffed(base, mod, 0))
    else
        T.attack.value:SetText("--")
    end
    do
        local base, pos, neg = UnitAttackPower(unit)
        T.attackPower.value:SetText(Buffed(base, pos, neg))
    end
    do
        local minDamage, maxDamage = UnitDamage(unit)
        minDamage, maxDamage = Number(minDamage), Number(maxDamage)
        T.damage.value:SetText(string.format("%d - %d", math.max(math.floor(minDamage), 1), math.max(math.ceil(maxDamage), 1)))
    end
    -- Ranged: only with a ranged weapon or wand in hand; the pet has none.
    local hasRanged = unit == "player" and CharacterRangedSlot and CharacterRangedSlot:IsShown()
        and GetInventoryItemID("player", CharacterRangedSlot:GetID()) ~= nil
    if not hasRanged then
        T.rangedAttack.value:SetText("--")
        T.rangedPower.value:SetText("--")
        T.rangedDamage.value:SetText("--")
    else
        if UnitRangedAttack then
            local base, mod = UnitRangedAttack("player")
            T.rangedAttack.value:SetText(Buffed(base, mod, 0))
        else
            T.rangedAttack.value:SetText("--")
        end
        local base, pos, neg = UnitRangedAttackPower("player")
        T.rangedPower.value:SetText(Buffed(base, pos, neg))
        local _, minDamage, maxDamage = UnitRangedDamage("player")
        minDamage, maxDamage = Number(minDamage), Number(maxDamage)
        if maxDamage > 0 then
            T.rangedDamage.value:SetText(string.format("%d - %d", math.max(math.floor(minDamage), 1), math.max(math.ceil(maxDamage), 1)))
        else
            T.rangedDamage.value:SetText("--")
        end
    end
    -- Resistances are Forever only (retail dropped the API); 0 if the call is missing.
    if forever then
        for _, res in ipairs(T.resistances) do
            if UnitResistance then
                local _, total = UnitResistance(unit, res.id)
                res.value:SetText(Number(total))
            else
                res.value:SetText("0")
            end
        end
    end
    return true
end
T.UpdateStats = UpdateStats

-- Boxes at (67, -291) and the resistance column, 32x29 a row.
function T.BuildStats(doll)
    forever = ns.OnForever()
    local attrs = CreateFrame("Frame", nil, doll)
    attrs:SetSize(230, 78)
    attrs:SetPoint("TOPLEFT", doll, "TOPLEFT", 67, -291)
    StatBox(attrs, 0, 0, 53)
    local meleeBottom = StatBox(attrs, 115, 0, 12)
    StatBox(attrs, 115, -46, 11)
    T.attrs = attrs
    T.attributes = {}
    local prev
    for i = 1, 5 do
        local label = _G["SPELL_STAT" .. i .. "_NAME"] or STAT_NAMES[i]
        statLabels[i] = label
        local row = StatRow(attrs, label, prev or attrs, prev and "BOTTOMLEFT" or "TOPLEFT", prev and 0 or 6, prev and 0 or -3)
        T.attributes[i] = row
        prev = row
    end
    T.armor = StatRow(attrs, ARMOR_NAME, prev, "BOTTOMLEFT", 0, 0)
    T.attack = StatRow(attrs, MELEE_ATTACK or "Melee Attack", attrs, "TOPLEFT", 122, -2)
    T.attackPower = StatRow(attrs, ATTACK_POWER or "Power", T.attack, "BOTTOMLEFT", 5, 1)
    T.damage = StatRow(attrs, DAMAGE or "Damage", T.attackPower, "BOTTOMLEFT", 0, 1)
    T.rangedAttack = StatRow(attrs, RANGED_ATTACK or "Ranged Attack", T.damage, "BOTTOMLEFT", -5, -6)
    T.rangedPower = StatRow(attrs, ATTACK_POWER or "Power", T.rangedAttack, "BOTTOMLEFT", 5, 1)
    T.rangedDamage = StatRow(attrs, DAMAGE or "Damage", T.rangedPower, "BOTTOMLEFT", 0, 1)
    T.attack.tip = MELEE_ATTACK or "Melee Attack"
    T.attackPower.tip = MELEE_ATTACK_POWER or "Attack Power"
    T.damage.tip = DAMAGE or "Damage"
    T.rangedAttack.tip = RANGED_ATTACK or "Ranged Attack"
    T.rangedPower.tip = RANGED_ATTACK_POWER or "Ranged Attack Power"
    T.rangedDamage.tip = DAMAGE or "Damage"
    meleeBottom:SetPoint("TOPLEFT", attrs, "TOPLEFT", 115, -28)

    local resFrame = CreateFrame("Frame", nil, doll)
    resFrame:SetSize(32, 160)
    resFrame:SetPoint("TOPRIGHT", doll, "TOPLEFT", 297, -77)
    resFrame:SetShown(forever)
    T.resistances = {}
    prev = nil
    for i, res in ipairs(RESISTANCES) do
        local row = CreateFrame("Frame", nil, resFrame)
        row:SetSize(32, 29)
        row:SetPoint("TOP", prev or resFrame, prev and "BOTTOM" or "TOP", 0, 0)
        ns.DressNew(row, "charResistIcons", RESIST_ICON, row, nil, nil, nil, nil, res.coords)
        row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.value:SetPoint("BOTTOM", row, "BOTTOM", 0, 3)
        row.id = res.id
        row:EnableMouse(true)
        ns.AttachTip(row, RESIST_TIP)
        T.resistances[i] = row
        prev = row
    end
end

-- Player and pet unit events, one pass a frame; the side panel lines need the extras.
local UNIT_EVENTS = { "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_DAMAGE",
    "UNIT_ATTACK_SPEED", "UNIT_RANGEDDAMAGE", "UNIT_ATTACK", "UNIT_RESISTANCES", "UNIT_INVENTORY_CHANGED",
    "UNIT_LEVEL", "UNIT_AURA", "UNIT_MAXHEALTH", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_SPELL_HASTE" }
local EVENTS = { "COMBAT_RATING_UPDATE", "SPELL_POWER_CHANGED", "PLAYER_EQUIPMENT_CHANGED",
    "PLAYER_AVG_ITEM_LEVEL_UPDATE", "SKILL_LINES_CHANGED", "PLAYER_REGEN_ENABLED", "PET_STATS_UPDATE" }
local function QueueStats(_, event, unit)
    -- The pet's changes count only while its view is up.
    if (unit == "pet" or event == "PET_STATS_UPDATE") and not (T.PetView and T.PetView()) then return end
    ns.Sched.Soon("character.stats", UpdateStats)
end
local function DollShown() if T.active then UpdateStats(true) end end

function T.WatchStats(doll)
    local watcher = CreateFrame("Frame")
    ns.RegisterEvents(watcher, UNIT_EVENTS, "player", "pet")
    ns.RegisterEvents(watcher, EVENTS)
    watcher:SetScript("OnEvent", QueueStats)
    doll:HookScript("OnShow", DollShown)
end
