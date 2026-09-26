local _, ns = ...

-- 2.x stat panes (a toggle): two boxes under the model, each with a section dropdown; the same
-- sections fill the side panel page (ns.StatList).
-- TBC: the client hides hit and expertise at 0 and lists no mana regen; OWN fills the gaps.

local active = false
local panes
local hostFrame
local Raise

local ROWS = 5
local PANE_W, ROW_H = 115, 13
-- Pane line pitch: five lines end the box above the weapon slots' rivets.
local PANE_ROW = 12
-- Scroll bar: hit width, seconds shown after a scroll, fade in and out.
local BAR_W, BAR_HOLD, FADE_IN, FADE_OUT = 4, 1, 0.1, 0.4
-- Dropdown label frame sits mid-sheet (64 tall): a 24 head with 14 out all round shows ~21, pane wide.
local HEAD_W, HEAD_H, HEAD_OUT = PANE_W, 24, 14
local ROWS_TOP = HEAD_H + 4
-- The 2.x rounded list edge, left silver (a grey tint read dull).
local PANE_BOX = { bg = { 0, 0, 0, 0.55 }, border = { 1, 1, 1, 1 } }
local LIST_BOX = { bg = { 0, 0, 0, 0.55 }, bgFirst = true }
local NA = _G.NOT_APPLICABLE or "N/A"

-- Not a client section (it draws them as a separate block): our page, each line with its school icon.
local RESISTANCES = {
    { stat = "ARCANE_RESIST", school = 6, coords = { 0, 1, 0.2265625, 0.33984375 } },
    { stat = "FIRE_RESIST", school = 2, coords = { 0, 1, 0, 0.11328125 } },
    { stat = "FROST_RESIST", school = 4, coords = { 0, 1, 0.33984375, 0.453125 } },
    { stat = "NATURE_RESIST", school = 3, coords = { 0, 1, 0.11328125, 0.2265625 } },
    { stat = "SHADOW_RESIST", school = 5, coords = { 0, 1, 0.453125, 0.56640625 } },
}

---------------------------------------------------------------- our lines

local function Put(row, label, text, value)
    row.Label:SetText(string.format(STAT_FORMAT or "%s:", label))
    row.Value:SetText(text)
    row.numericValue = value
end

-- Melee, ranged and spell, the way the client's own lines work them out.
local function Hits()
    return _G.GetCombatRatingBonus(_G.CR_HIT_MELEE) + _G.GetHitModifier(),
        _G.GetCombatRatingBonus(_G.CR_HIT_RANGED) + _G.GetRangedHitModifier(),
        _G.GetCombatRatingBonus(_G.CR_HIT_SPELL) + _G.GetSpellHitModifier()
end
local function Crits()
    return _G.GetCritChance(), _G.GetRangedCritChance(), _G.GetSpellCritChance()
end
local function Hastes()
    local ranged, ammo = _G.GetRangedHaste()
    return _G.GetMeleeHaste(), ranged + (ammo or 0), _G.UnitSpellHaste("player")
end

-- The client's tooltips for these name all three schools.
local function HitTip(row)
    _G.CharacterHitFrame_OnEnter(row, row.fcuiMelee, row.fcuiRanged, row.fcuiSpell, _G.STAT_HIT_CHANCE)
end
local function CritTip(row)
    _G.CharacterCritChanceFrame_OnEnter(row, row.fcuiMelee, row.fcuiRanged, row.fcuiSpell)
end
local function HasteTip(row)
    _G.CharacterHasteFrame_OnEnter(row, row.fcuiMelee, row.fcuiRanged, row.fcuiSpell)
end

local function School(read, index, label, format, tip)
    return function(row)
        local melee, ranged, spell = read()
        row.fcuiMelee, row.fcuiRanged, row.fcuiSpell = melee, ranged, spell
        local value = (index == 1 and melee) or (index == 2 and ranged) or spell
        Put(row, label, string.format(format, value), value)
        row.onEnterFunc = tip
    end
end

local function HasRanged()
    return not (_G.IsRangedWeapon and _G.IsRangedWeapon() == false)
end

local function Dps(low, high, speed)
    return (math.max(math.floor(low), 1) + math.max(math.ceil(high), 1)) / (2 * speed)
end

local DPS_LABEL, SPEED_LABEL = _G.STAT_DPS_SHORT or "DPS", _G.WEAPON_SPEED or "Speed"
local HIT_LABEL, CRIT_LABEL = _G.STAT_HIT_CHANCE or "Hit Chance", _G.CRIT_CHANCE or "Crit Chance"
local HASTE_LABEL = _G.STAT_HASTE or "Haste"

-- false: no such line for this character.
local OWN = {
    MELEE_DPS = function(row)
        local speed = _G.UnitAttackSpeed("player")
        local low, high = UnitDamage("player")
        if not speed or speed <= 0 then return false end
        local dps = Dps(low, high, speed)
        Put(row, DPS_LABEL, string.format("%.1f", dps), dps)
    end,
    RANGED_DPS = function(row)
        local speed, low, high = UnitRangedDamage("player")
        if not HasRanged() or not speed or speed <= 0 then return Put(row, DPS_LABEL, NA, 0) end
        local dps = Dps(low, high, speed)
        Put(row, DPS_LABEL, string.format("%.1f", dps), dps)
    end,
    RANGED_SPEED = function(row)
        local speed = UnitRangedDamage("player")
        if not HasRanged() or not speed or speed <= 0 then return Put(row, SPEED_LABEL, NA, 0) end
        Put(row, SPEED_LABEL, string.format("%.2f", speed), speed)
    end,
    MELEE_HIT = School(Hits, 1, HIT_LABEL, "+%.2f%%", HitTip),
    RANGED_HIT = School(Hits, 2, HIT_LABEL, "+%.2f%%", HitTip),
    SPELL_HIT = School(Hits, 3, HIT_LABEL, "+%.2f%%", HitTip),
    MELEE_CRIT = School(Crits, 1, CRIT_LABEL, "%.2f%%", CritTip),
    RANGED_CRIT = School(Crits, 2, CRIT_LABEL, "%.2f%%", CritTip),
    SPELL_CRIT = School(Crits, 3, CRIT_LABEL, "%.2f%%", CritTip),
    MELEE_HASTE = School(Hastes, 1, HASTE_LABEL, "+%.2f%%", HasteTip),
    RANGED_HASTE = School(Hastes, 2, HASTE_LABEL, "+%.2f%%", HasteTip),
    SPELL_HASTE = School(Hastes, 3, HASTE_LABEL, "+%.2f%%", HasteTip),
    -- The client has the function but no line for it.
    RESILIENCE = function(row)
        if type(_G.PaperDollFrame_SetResilience) ~= "function" then return false end
        _G.PaperDollFrame_SetResilience(row, "player")
    end,
    -- Two decimals like hit and crit; the client writes one.
    EXPERTISE = function(row)
        local main, off = _G.GetExpertise()
        local _, offSpeed = _G.UnitAttackSpeed("player")
        local text = offSpeed and string.format("%.2f%% / %.2f%%", main, off) or string.format("%.2f%%", main)
        Put(row, _G.STAT_EXPERTISE or "Expertise", text, main)
        row.onEnterFunc = _G.PaperDollFrame_ExpertiseOnEnter
    end,
    -- The client's line (equipped) and tooltip, then " / overall" as TBC showed.
    ITEMLEVEL = function(row)
        local info = type(PAPERDOLL_STATINFO) == "table" and PAPERDOLL_STATINFO.ITEMLEVEL
        if not info or type(info.updateFunc) ~= "function" then return false end
        info.updateFunc(row, "player")
        local equipped, overall = row.numericValue, _G.GetAverageItemLevel()
        if type(equipped) == "number" and type(overall) == "number" then
            row.Value:SetText(string.format("%d / %d", equipped, math.floor(overall)))
        end
    end,
}

---------------------------------------------------------------- sections

-- key: the old client-built list's id for the nearest section, so saved picks keep meaning.
-- wide: side panel only (panes list TBC's lines). na: N/A where the client writes nothing.
local sections

local function Sections()
    if sections then return sections end
    local damage = DAMAGE or "Damage"
    sections = {
        { key = "section1", label = _G.STAT_CATEGORY_GENERAL or "General", stats = {
            { stat = "HEALTH" }, { stat = "POWER" }, { stat = "ALTERNATEMANA" }, { own = "ITEMLEVEL" },
            { stat = "MOVESPEED" } } },
        { key = "section2", label = _G.STAT_CATEGORY_ATTRIBUTES or "Attributes", stats = {
            { stat = "STRENGTH" }, { stat = "AGILITY" }, { stat = "STAMINA" }, { stat = "INTELLECT" },
            { stat = "SPIRIT" } } },
        { key = "section3", label = _G.STAT_CATEGORY_MELEE or "Melee", stats = {
            { stat = "MAINHAND_DAMAGE", label = damage }, { stat = "OFFHAND_DAMAGE", wide = true },
            { own = "MELEE_DPS", wide = true }, { stat = "ATTACK_AP" }, { stat = "ATTACK_ATTACKSPEED" },
            { own = "MELEE_HASTE", wide = true }, { own = "MELEE_HIT" }, { own = "MELEE_CRIT" },
            { own = "EXPERTISE" } } },
        { key = "section7", label = _G.STAT_CATEGORY_RANGED or "Ranged", stats = {
            { stat = "RANGED_DAMAGE", label = damage, na = true }, { own = "RANGED_DPS", wide = true },
            { stat = "RANGED_ATTACK_AP" }, { own = "RANGED_SPEED" }, { own = "RANGED_HASTE", wide = true },
            { own = "RANGED_HIT" }, { own = "RANGED_CRIT" } } },
        { key = "section4", label = _G.STAT_CATEGORY_SPELL or "Spell", stats = {
            { stat = "SPELLPOWER" }, { stat = "SPELLHEALING" }, { own = "SPELL_HIT" }, { own = "SPELL_CRIT" },
            { own = "SPELL_HASTE" }, { stat = "SPELLPENETRATION", wide = true }, { stat = "MANAREGEN" } } },
        { key = "section5", label = _G.STAT_CATEGORY_DEFENSE or "Defense", stats = {
            { stat = "ARMOR" }, { stat = "DEFENSE" }, { stat = "DODGE" }, { stat = "PARRY" }, { stat = "BLOCK" },
            { own = "RESILIENCE" } } },
        { key = "section6", label = RESISTANCE_LABEL or "Resistances", stats = RESISTANCES, resistances = true },
    }
    return sections
end

local function SectionByKey(key, fallback)
    local list = Sections()
    for _, section in ipairs(list) do
        if section.key == key then return section end
    end
    return list[fallback] or list[1]
end

-- Secret in combat and the client's line functions stop on them; keep the last shown.
local function NumbersWithheld()
    if not UnitStat then return false end
    local _, probe = UnitStat("player", 1)
    return ns.IsSecret(probe)
end

local function LineTip(row)
    if type(row.onEnterFunc) == "function" then
        pcall(row.onEnterFunc, row)
    elseif row.tooltip and type(PaperDollStatTooltip) == "function" then
        pcall(PaperDollStatTooltip, row)
    end
end

-- Shaped for the client's line functions: Label, Value, room for their tooltip fields.
local function Line(parent, height)
    height = height or ROW_H
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(PANE_W - 12, height)
    row.unit = "player"
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(height - 1, height - 1)
    row.Icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.Icon:Hide()
    row.Value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.Value:SetJustifyH("RIGHT")
    row.Value:SetWordWrap(false)
    row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.Label:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.Label:SetPoint("RIGHT", row.Value, "LEFT", -2, 0)
    row.Label:SetJustifyH("LEFT")
    row.Label:SetWordWrap(false)
    row:EnableMouse(true)
    row:SetScript("OnEnter", LineTip)
    row:SetScript("OnLeave", ns.HideTip)
    return row
end

local function ClearLine(row)
    row.tooltip, row.tooltip2, row.tooltip3 = nil, nil, nil
    row.onEnterFunc, row.UpdateTooltip, row.numericValue = nil, nil, nil
    -- Main hand damage never sets it and reads it in its tooltip.
    row.tooltipLabel = nil
end

-- False when the client has no such line or this character has none.
local function FillLine(row, entry, resistances)
    local fill = entry.own and OWN[entry.own]
    if not fill then
        local info = type(PAPERDOLL_STATINFO) == "table" and PAPERDOLL_STATINFO[entry.stat]
        fill = info and info.updateFunc
    end
    if type(fill) ~= "function" then return false end
    ClearLine(row)
    -- Some line functions mean "none" by hiding the row (empty off hand); no value is none too.
    row:Show()
    row.Value:SetText("")
    local ok, result = pcall(fill, row, "player")
    if not ok or result == false or not row:IsShown() then return false end
    local text = row.Value:GetText()
    if text == nil or text == "" then
        if not entry.na then return false end
        row.Value:SetText(NA)
    end
    if entry.label then row.Label:SetText(string.format(STAT_FORMAT or "%s:", entry.label)) end
    row.Label:ClearAllPoints()
    if resistances then
        -- The school alone: "Arcane Resistance:" does not fit the box.
        local school = _G["DAMAGE_SCHOOL" .. (entry.school + 1)]
        if school then row.Label:SetText(string.format(STAT_FORMAT or "%s:", school)) end
        ns.SetTex(row.Icon, "charResistIcons")
        row.Icon:SetTexCoord(unpack(entry.coords))
        row.Icon:Show()
        row.Label:SetPoint("LEFT", row.Icon, "RIGHT", 3, 0)
    else
        row.Icon:Hide()
        row.Label:SetPoint("LEFT", row, "LEFT", 0, 0)
    end
    row.Label:SetPoint("RIGHT", row.Value, "LEFT", -2, 0)
    return true
end

---------------------------------------------------------------- scroll bar

-- Thin bar at the box's right edge, shown while hovered or just scrolled, then faded.
local function BarFade(job, elapsed)
    local pane = job.host:GetParent()
    local bar = pane.bar
    if not bar:IsShown() then
        bar:SetAlpha(0)
        job:Sleep()
        return
    end
    -- The box runs 3 below the pane.
    local want = (pane:IsMouseOver(0, -3, 0, 0) or GetTime() < pane.barHold) and 1 or 0
    local alpha = bar:GetAlpha()
    if alpha < want then
        alpha = math.min(want, alpha + elapsed / FADE_IN)
    elseif alpha > want then
        alpha = math.max(want, alpha - elapsed / FADE_OUT)
    end
    bar:SetAlpha(alpha)
    if want == 0 and alpha == 0 then job:Sleep() end
end

-- One row per line: scrolling only moves rows, so it reads no stat and works in combat.
local function Place(pane)
    local count, offset = pane.lineCount or 0, pane.offset
    for k, row in ipairs(pane.lines) do
        if k <= count and k > offset and k <= offset + ROWS then
            ns.SetPointOnce(row, "TOPLEFT", pane, "TOPLEFT", 6, -ROWS_TOP - (k - offset - 1) * PANE_ROW)
            row:Show()
        else
            row:Hide()
        end
    end
end

local function WakeBar(pane)
    if pane.bar:IsShown() then pane.barFade:Wake() end
end

local function BarChanged(bar, value)
    local pane = bar:GetParent()
    if pane.barSetting then return end
    value = math.floor(value + 0.5)
    if value ~= pane.offset then
        pane.offset = value
        pane.barHold = GetTime() + BAR_HOLD
        Place(pane)
    end
end

local function BarEnter(bar) WakeBar(bar:GetParent()) end

-- Range and thumb for the lines the pane holds; hidden when all fit.
local function SetBar(pane)
    local bar = pane.bar
    local over = math.max(0, (pane.lineCount or 0) - ROWS)
    if over == 0 then
        bar:Hide()
        return
    end
    pane.barSetting = true
    bar.thumb:SetHeight(math.max(6, math.floor(ROWS * PANE_ROW * ROWS / pane.lineCount + 0.5)))
    bar:SetMinMaxValues(0, over)
    bar:SetValue(pane.offset)
    pane.barSetting = false
    bar:Show()
end

local function ScrollBar(pane)
    local bar = CreateFrame("Slider", nil, pane)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(BAR_W)
    bar:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -2, -ROWS_TOP)
    bar:SetPoint("BOTTOMRIGHT", pane, "TOPRIGHT", -2, -(ROWS_TOP + ROWS * PANE_ROW))
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0, 0, 0, 0.5)
    track:SetWidth(2)
    track:SetPoint("TOP", bar, "TOP", 0, 0)
    track:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)
    local thumb = bar:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(0.75, 0.75, 0.75, 1)
    thumb:SetSize(2, ROWS * PANE_ROW)
    bar:SetThumbTexture(thumb)
    bar.thumb = thumb
    bar:SetAlpha(0)
    bar:Hide()
    bar:SetScript("OnValueChanged", BarChanged)
    bar:SetScript("OnEnter", BarEnter)
    pane.bar = bar
    pane.barHold = 0
    pane.barFade = ns.Sched.OnFrame(CreateFrame("Frame", nil, pane), { name = "statPanes.bar", every = 0, fn = BarFade, awake = false })
end

local function PaneRowEnter(row)
    LineTip(row)
    WakeBar(row:GetParent())
end

local function HeadEnter(head) WakeBar(head:GetParent()) end

local function Pane(parent, side, fallback)
    local pane = CreateFrame("Frame", nil, parent)
    pane:SetSize(PANE_W, ROWS_TOP + ROWS * PANE_ROW + 2)
    pane.side, pane.fallback, pane.offset = side, fallback, 0
    pane.shown = {}

    local box = CreateFrame("Frame", nil, pane, ns.BACKDROP_TEMPLATE)
    box:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -(ROWS_TOP - 5))
    box:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, -3)
    box:SetFrameLevel(pane:GetFrameLevel())
    ns.Backdrop(box, ns.BACKDROP.TIP12, PANE_BOX)
    pane.box = box

    -- Dropdown in the settings window's old label frame.
    local head = CreateFrame("Button", nil, pane)
    head:SetSize(HEAD_W, HEAD_H)
    head:SetPoint("TOP", pane, "TOP", 0, -1)
    local arrow = ns.DressDropdown(head, HEAD_OUT)
    head.text = head:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    head.text:SetPoint("LEFT", head, "LEFT", 9, 1)
    head.text:SetPoint("RIGHT", arrow, "LEFT", 3, 1)
    head.text:SetJustifyH("LEFT")
    head.text:SetWordWrap(false)
    head:SetScript("OnEnter", HeadEnter)
    pane.head = head

    -- Made on demand, one per shown line of the section.
    pane.lines = {}

    local function Pick(section)
        ns.db[pane.side] = section.key
        pane.offset = 0
        ns.UpdateStatPanes()
        -- Withheld in combat: the shown section still goes back to its top with the offset.
        Place(pane)
        SetBar(pane)
    end
    head:SetScript("OnClick", function(self)
        -- The old list under the drop down; the client's menu is the modern one.
        if not pane.list then
            local entries = {}
            for _, section in ipairs(Sections()) do
                entries[#entries + 1] = { section.label, function() Pick(section) end, function()
                    return SectionByKey(ns.db[pane.side], pane.fallback) == section
                end }
            end
            pane.list = ns.DropList(entries)
            pane.list:Follow(pane)
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        pane.list:Toggle(self)
    end)

    -- A section with more lines than the box holds is wheeled through.
    pane:EnableMouseWheel(true)
    pane:SetScript("OnMouseWheel", function(self, delta)
        local over = math.max(0, (self.lineCount or 0) - ROWS)
        local offset = math.max(0, math.min(over, self.offset - delta))
        if offset ~= self.offset then
            self.offset = offset
            self.barHold = GetTime() + BAR_HOLD
            WakeBar(self)
            Place(self)
            SetBar(self)
        end
    end)
    ScrollBar(pane)
    -- Hover only: clicks still pass to the doll under the box.
    pane:SetMouseMotionEnabled(true)
    pane:SetScript("OnEnter", WakeBar)
    return pane
end

local function Build()
    if panes then return panes end
    local host = hostFrame or PaperDollFrame
    if not host then return nil end
    panes = {
        left = Pane(host, "statPaneLeft", 2),
        right = Pane(host, "statPaneRight", 3),
    }
    -- Hard left: 5 further right its dropdown covered the ring slot.
    panes.left:SetPoint("TOPLEFT", host, "TOPLEFT", 66, -286)
    panes.right:SetPoint("TOPLEFT", panes.left, "TOPRIGHT", 0, 0)
    return panes
end

local function UpdatePane(pane)
    local section = SectionByKey(ns.db[pane.side], pane.fallback)
    pane.head.text:SetText(section.label)
    local shown, lines = pane.shown, pane.lines
    wipe(shown)
    for _, entry in ipairs(section.stats) do
        if not entry.wide then
            local row = lines[#shown + 1]
            if not row then
                row = Line(pane, PANE_ROW)
                row:SetScript("OnEnter", PaneRowEnter)
                lines[#shown + 1] = row
            end
            -- The row that tested the line keeps it; a failed one is reused for the next.
            if FillLine(row, entry, section.resistances) then shown[#shown + 1] = entry else row:Hide() end
        end
    end
    pane.lineCount = #shown
    pane.offset = math.max(0, math.min(pane.offset, math.max(0, #shown - ROWS)))
    Place(pane)
    SetBar(pane)
end

function ns.UpdateStatPanes()
    if not active or not panes then return end
    Raise()
    if NumbersWithheld() then return end
    UpdatePane(panes.left)
    UpdatePane(panes.right)
end

-- The sheet names the frame its stats live on.
function ns.StatPanesHost(frame)
    hostFrame = frame
end

-- The sheet's pet view puts the pet's numbers in the 1.x boxes instead.
function ns.StatPanesSeen(shown)
    if not active or not panes then return end
    ns.SetShownIf(panes.left, shown)
    ns.SetShownIf(panes.right, shown)
end

-- Above the model, which overlaps the panes' top and took the dropdowns' clicks.
Raise = function()
    local over = CharacterModelScene and CharacterModelScene:GetFrameLevel() or 0
    for _, pane in pairs(panes) do
        local level = math.max(pane:GetParent():GetFrameLevel() + 2, over + 5)
        if pane:GetFrameLevel() < level then
            pane:SetFrameLevel(level)
            pane.head:SetFrameLevel(level + 2)
        end
    end
end

---------------------------------------------------------------- side list

-- Side panel stat page: all sections but resistances (the sheet has a column); heads fold per session.
local LIST_ROW, LIST_HEAD, LIST_GAP = 13, 20, 3
-- The stat boxes' own width from the page's left (SIDE_PANEL_WIDTH widens only the panel); the scroll bar from the
-- page's top right and bottom right corners (x + right, y + up).
local STATS_LIST_WIDTH = 168
local STATS_SCROLL_X = -9
local STATS_SCROLL_TOP = -2
local STATS_SCROLL_BOTTOM = 1
-- Its housing (the column art): left from the bar, ends past the bar's (top up, foot down: the housing's length is the
-- bar's plus both); arrow nudges; the knob beside the arrows' line and its run past the track's ends.
local STATS_SCROLL_HOUSING_X = -10.5
local STATS_SCROLL_HOUSING_TOP = 7
local STATS_SCROLL_HOUSING_BOTTOM = -6
local STATS_SCROLL_UP_ARROW_X = 0
local STATS_SCROLL_UP_ARROW_Y = 2
local STATS_SCROLL_DOWN_ARROW_X = 0
local STATS_SCROLL_DOWN_ARROW_Y = -2
local STATS_SCROLL_KNOB_X = 1
local STATS_SCROLL_KNOB_TRAVEL = 7
local folded = {}
local list

-- The side panel's scroll bar, the stat page's and the equipment page's alike (same spot): on page (either page frame,
-- both laid the same), dressed as the old bar, every number above.
function ns.PlaceSidePanelScroll(bar, page)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", page, "TOPRIGHT", STATS_SCROLL_X, STATS_SCROLL_TOP)
    bar:SetPoint("BOTTOMLEFT", page, "BOTTOMRIGHT", STATS_SCROLL_X, STATS_SCROLL_BOTTOM)
    ns.SkinMinimalScrollBar(bar)
    ns.ScrollTrackArt(bar, {
        houseX = STATS_SCROLL_HOUSING_X,
        houseTop = STATS_SCROLL_HOUSING_TOP,
        houseFoot = STATS_SCROLL_HOUSING_BOTTOM,
        upX = STATS_SCROLL_UP_ARROW_X,
        upY = STATS_SCROLL_UP_ARROW_Y,
        downX = STATS_SCROLL_DOWN_ARROW_X,
        downY = STATS_SCROLL_DOWN_ARROW_Y,
        knobX = STATS_SCROLL_KNOB_X,
        knobReach = STATS_SCROLL_KNOB_TRAVEL,
    })
end

local function LayoutList()
    local width = list.scroll:GetWidth()
    if width and width > 0 then list.child:SetWidth(width) end
    local y = 0
    for _, box in ipairs(list.boxes) do
        local open = not folded[box.section.key]
        ns.SetCollapseIcon(box.head.icon, not open)
        local n = 0
        for _, row in ipairs(box.rows) do
            if open and row.fcuiHas then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -LIST_HEAD - n * LIST_ROW)
                row:SetPoint("RIGHT", box, "RIGHT", -8, 0)
                row:Show()
                n = n + 1
            else
                row:Hide()
            end
        end
        local tall = LIST_HEAD + (n > 0 and n * LIST_ROW + 6 or 4)
        box:SetHeight(tall)
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", list.child, "TOPLEFT", 0, -y)
        box:SetPoint("TOPRIGHT", list.child, "TOPRIGHT", 0, -y)
        y = y + tall + LIST_GAP
    end
    list.child:SetHeight(math.max(1, y))
    -- A fold can leave the view past the new end.
    local over = math.max(0, y - (list.scroll:GetHeight() or 0))
    if list.scroll:GetVerticalScroll() > over then list.scroll:SetVerticalScroll(over) end
    list.laid = true
end

local function ListBox(section)
    local box = CreateFrame("Frame", nil, list.child, ns.BACKDROP_TEMPLATE)
    ns.Backdrop(box, ns.BACKDROP.TIP12, LIST_BOX)
    local head = CreateFrame("Button", nil, box)
    head:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -3)
    head:SetPoint("TOPRIGHT", box, "TOPRIGHT", -4, -3)
    head:SetHeight(LIST_HEAD - 5)
    head.icon = head:CreateTexture(nil, "ARTWORK")
    head.icon:SetSize(14, 14)
    head.icon:SetPoint("LEFT", head, "LEFT", 2, 0)
    local glow = head:CreateTexture(nil, "HIGHLIGHT")
    glow:SetTexture(ns.ART.PLUS_GLOW)
    glow:SetBlendMode("ADD")
    glow:SetAllPoints(head.icon)
    head.text = head:CreateFontString(nil, "ARTWORK")
    head.text:SetFontObject(ns.FONT_GOLD or "GameFontNormal")
    head.text:SetPoint("LEFT", head.icon, "RIGHT", 4, 0)
    head.text:SetText(section.label)
    head:SetScript("OnClick", function()
        folded[section.key] = not folded[section.key] or nil
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        LayoutList()
    end)
    box.head, box.section, box.rows = head, section, {}
    for i = 1, #section.stats do box.rows[i] = Line(box) end
    return box
end

-- Filled while seen, and unseen on sheet open or before first show, so a combat first show has
-- the last numbers; while withheld nothing changes, so lay out once.
function ns.UpdateStatList(opening)
    if not list then return end
    local seen = list.frame:IsVisible()
    if NumbersWithheld() then
        if seen and not list.laid then LayoutList() end
        return
    end
    if not seen and not opening and list.filled then return end
    for _, box in ipairs(list.boxes) do
        for i, entry in ipairs(box.section.stats) do
            box.rows[i].fcuiHas = FillLine(box.rows[i], entry)
        end
    end
    list.filled = true
    if seen then LayoutList() else list.laid = false end
end

-- The stat page, made once on the given parent; the caller anchors it.
function ns.StatList(parent)
    if list then return list.frame end
    local frame = CreateFrame("Frame", nil, parent)
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    scroll:SetWidth(STATS_LIST_WIDTH)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)
    -- The client's thin bar run by its own helper, dressed as the old one (arrows, knob, column art).
    local util = _G.ScrollUtil
    local ok, bar = pcall(CreateFrame, "EventFrame", nil, frame, "MinimalScrollBar")
    if ok and bar and bar.Track and util and util.InitScrollFrameWithScrollBar then
        ns.PlaceSidePanelScroll(bar, frame)
        util.InitScrollFrameWithScrollBar(scroll, bar)
        scroll:SetPanExtent(LIST_ROW * 3)
    else
        if ok and bar then bar:Hide() end
        scroll:SetScript("OnMouseWheel", function(self, delta)
            local over = math.max(0, child:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(math.max(0, math.min(over, self:GetVerticalScroll() - delta * LIST_ROW * 3)))
        end)
    end
    list = { frame = frame, scroll = scroll, child = child, boxes = {} }
    for _, section in ipairs(Sections()) do
        if not section.resistances then list.boxes[#list.boxes + 1] = ListBox(section) end
    end
    scroll:SetScript("OnSizeChanged", LayoutList)
    frame:SetScript("OnShow", function() ns.UpdateStatList() end)
    return frame
end

local function Apply()
    active = true
    if not Build() then return end
    -- Any pass during the sheet's pet view keeps its 1.x boxes: the panes are the player's.
    local sheet = ns.sheet
    local pet = sheet and sheet.active and sheet.PetView and sheet.PetView() or false
    ns.StatPanesSeen(not pet)
    Raise()
    ns.SetClassicStatsShown(pet)
    ns.UpdateStatPanes()
end

local function Restore()
    active = false
    if panes then
        panes.left:Hide()
        panes.right:Hide()
    end
    -- The 1.x boxes come back only on the classic sheet.
    local sheet = ns.sheet
    ns.SetClassicStatsShown(sheet and sheet.active and true or false)
end

ns.RegisterModule("statPanes", { apply = Apply, restore = Restore })
