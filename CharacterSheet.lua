local _, ns = ...

-- The 1.x character sheet on Blizzard's character frame: the 384x512
-- window in the old art, the portrait and name up top, sixteen slots
-- down the sides with the weapons underneath, the model in the middle
-- with the two rotate buttons, the two stat boxes (attributes and armour
-- on the left, melee and ranged attack on the right), the five
-- resistances up the right edge, and the tabs along the bottom. The
-- retail chrome, side panel and stat list are faded; Blizzard's slot
-- buttons and model keep all their logic. The Forever client builds its
-- character frame differently (a stats pane on the right with a toggle,
-- mode tabs in a column on the right edge, the level line in that pane),
-- so there the pane is kept shut, the column is hidden and the sheet
-- draws its own level line and bottom tabs.

local WIDTH, HEIGHT = 384, 512
local SLOT_GAP = 4
local LEFT_SLOTS = { "CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot", "CharacterBackSlot",
    "CharacterChestSlot", "CharacterShirtSlot", "CharacterTabardSlot", "CharacterWristSlot" }
local RIGHT_SLOTS = { "CharacterHandsSlot", "CharacterWaistSlot", "CharacterLegsSlot", "CharacterFeetSlot",
    "CharacterFinger0Slot", "CharacterFinger1Slot", "CharacterTrinket0Slot", "CharacterTrinket1Slot" }
local WEAPON_SLOTS = { "CharacterMainHandSlot", "CharacterSecondaryHandSlot", "CharacterRangedSlot" }
local STAT_NAMES = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }
-- Resistance rows top to bottom: arcane, fire, nature, frost, shadow.
local RESISTANCES = {
    { id = 6, coords = { 0, 1, 0.2265625, 0.33984375 } },
    { id = 2, coords = { 0, 1, 0, 0.11328125 } },
    { id = 3, coords = { 0, 1, 0.11328125, 0.2265625 } },
    { id = 4, coords = { 0, 1, 0.33984375, 0.453125 } },
    { id = 5, coords = { 0, 1, 0.453125, 0.56640625 } },
}
local BOX_TOP = { 0, 0.8984375, 0, 0.125 }
local BOX_MID = { 0, 0.8984375, 0.125, 0.1953125 }
local BOX_BOT = { 0, 0.8984375, 0.484375, 0.609375 }
local GREEN, RED, WHITE = "|cff20ff20", "|cffff2020", "|cffffffff"

local active = false
local HideSidePane
local built = false
local sheet = {}

-- Short labels so six tabs fit the 384px window.
local TAB_LABELS = {
    PaperDollFrame = "Char", ReputationFrame = REPUTATION_ABBR or "Reputation",
    TokenFrame = CURRENCY or "Currency", PVPRankFrame = "PvP", SkillsFrame = SKILLS or "Skills",
    StatisticsFrame = "Stats",
}

-- "Level 20 Gnome Mage", gold, the way 1.x wrote it under the name.
local function LevelLine()
    local level = UnitLevel("player")
    if issecretvalue and issecretvalue(level) then level = "" end
    local race = UnitRace("player") or ""
    local class = UnitClass("player") or ""
    return string.format("%s %s %s %s", LEVEL or "Level", tostring(level), race, class)
end

local function Number(value)
    if value == nil or (issecretvalue and issecretvalue(value)) then return 0 end
    return value
end

local function Piece(parent, key, w, h, x, y, layer, sub)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    ns.SetTex(tex, key)
    tex:SetSize(w, h)
    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return tex
end

-- A stat box: the old three-piece background, top and bottom caps.
local function StatBox(parent, x, y, middleHeight)
    local top = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
    ns.SetTex(top, "charStatBox")
    top:SetSize(115, 16)
    top:SetTexCoord(unpack(BOX_TOP))
    top:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local middle = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
    ns.SetTex(middle, "charStatBox")
    middle:SetSize(115, middleHeight)
    middle:SetTexCoord(unpack(BOX_MID))
    middle:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    local bottom = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
    ns.SetTex(bottom, "charStatBox")
    bottom:SetSize(115, 16)
    bottom:SetTexCoord(unpack(BOX_BOT))
    bottom:SetPoint("TOPLEFT", middle, "BOTTOMLEFT", 0, 0)
    return bottom
end

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
    row:SetScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tip, 1, 1, 1)
        if self.tip2 then GameTooltip:AddLine(self.tip2, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

-- "base" in white, the buffed total in green or red the way 1.x showed it.
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

local function UpdateStats()
    if not built or not active or not PaperDollFrame or not PaperDollFrame:IsShown() then return end
    for i, row in ipairs(sheet.attributes) do
        local _, effective, pos, neg = UnitStat("player", i)
        local text, detail = Buffed(Number(effective) - Number(pos) - Number(neg), pos, neg)
        row.value:SetText(text)
        row.tip = (_G["SPELL_STAT" .. i .. "_NAME"] or STAT_NAMES[i]) .. " " .. Number(effective)
        row.tip2 = detail
    end
    do
        local _, effective, _, pos, neg = UnitArmor("player")
        local text, detail = Buffed(Number(effective) - Number(pos) - Number(neg), pos, neg)
        sheet.armor.value:SetText(text)
        sheet.armor.tip = (ARMOR or "Armor") .. " " .. Number(effective)
        sheet.armor.tip2 = detail
    end
    -- Melee: weapon skill where the client has it, then power and damage.
    if UnitAttackBothHands then
        local base, mod = UnitAttackBothHands("player")
        sheet.attack.value:SetText(Buffed(base, mod, 0))
    else
        sheet.attack.value:SetText("--")
    end
    do
        local base, pos, neg = UnitAttackPower("player")
        sheet.attackPower.value:SetText(Buffed(base, pos, neg))
    end
    do
        local minDamage, maxDamage = UnitDamage("player")
        minDamage, maxDamage = Number(minDamage), Number(maxDamage)
        sheet.damage.value:SetText(string.format("%d - %d", math.max(math.floor(minDamage), 1), math.max(math.ceil(maxDamage), 1)))
    end
    -- Ranged: only with a ranged weapon or wand in hand.
    local hasRanged = CharacterRangedSlot and CharacterRangedSlot:IsShown() and GetInventoryItemID("player", CharacterRangedSlot:GetID()) ~= nil
    if not hasRanged then
        sheet.rangedAttack.value:SetText("--")
        sheet.rangedPower.value:SetText("--")
        sheet.rangedDamage.value:SetText("--")
    else
        if UnitRangedAttack then
            local base, mod = UnitRangedAttack("player")
            sheet.rangedAttack.value:SetText(Buffed(base, mod, 0))
        else
            sheet.rangedAttack.value:SetText("--")
        end
        local base, pos, neg = UnitRangedAttackPower("player")
        sheet.rangedPower.value:SetText(Buffed(base, pos, neg))
        local _, minDamage, maxDamage = UnitRangedDamage("player")
        minDamage, maxDamage = Number(minDamage), Number(maxDamage)
        if maxDamage > 0 then
            sheet.rangedDamage.value:SetText(string.format("%d - %d", math.max(math.floor(minDamage), 1), math.max(math.ceil(maxDamage), 1)))
        else
            sheet.rangedDamage.value:SetText("--")
        end
    end
    -- Resistances are a Forever thing; retail dropped them and their
    -- API, so its sheet has no column. Forever reads them where the
    -- client still offers the call and shows 0 where it does not.
    if ns.OnForever() then
        for _, res in ipairs(sheet.resistances) do
            if UnitResistance then
                local _, total = UnitResistance("player", res.id)
                res.value:SetText(Number(total))
            else
                res.value:SetText("0")
            end
        end
    end
end

-- The client frames its camera for the wide modern pane; in the old
-- 233x224 window the same camera draws the character too large. The
-- camera backs off by a step once per camera the client hands out.
local MODEL_ZOOM = 1.25
local function FitModelCamera()
    local scene = CharacterModelScene
    local camera = scene and scene.GetActiveCamera and scene:GetActiveCamera()
    if not camera or camera.fcuiFitted or not camera.GetZoomDistance or not camera.SetZoomDistance then return end
    camera.fcuiFitted = true
    local distance = camera:GetZoomDistance()
    if distance and distance > 0 then
        if camera.SetMaxZoomDistance and camera.GetMaxZoomDistance then
            local max = camera:GetMaxZoomDistance()
            if max and max < distance * MODEL_ZOOM then camera:SetMaxZoomDistance(distance * MODEL_ZOOM) end
        end
        camera:SetZoomDistance(distance * MODEL_ZOOM)
    end
end

local function Rotate(delta)
    local scene = CharacterModelScene
    local camera = scene and scene.GetActiveCamera and scene:GetActiveCamera()
    if camera and camera.SetYaw and camera.GetYaw then
        camera:SetYaw(camera:GetYaw() + delta)
    end
end

local function RotateButton(parent, artKey, delta, anchor, relPoint)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(35, 35)
    button:SetPoint("TOPLEFT", anchor, relPoint, 0, 0)
    button:SetNormalTexture((ns.TexPath(artKey .. "Up")))
    button:SetPushedTexture((ns.TexPath(artKey .. "Down")))
    button:SetHighlightTexture((ns.TexPath("roundHighlight")))
    button:GetHighlightTexture():SetBlendMode("ADD")
    button:SetScript("OnClick", function() Rotate(delta) PlaySound(SOUNDKIT.IG_INVENTORY_ROTATE_CHARACTER) end)
    return button
end

local function Build()
    built = true
    local frame, doll = CharacterFrame, PaperDollFrame

    -- The old art: the general frame under everything, the paper doll
    -- overlay on the character tab only.
    sheet.general = {
        Piece(frame, "charGeneralTopLeft", 256, 256, 0, 0, "BACKGROUND", -2),
        Piece(frame, "charGeneralTopRight", 128, 256, 256, 0, "BACKGROUND", -2),
        Piece(frame, "charGeneralBotLeft", 256, 256, 0, -256, "BACKGROUND", -2),
        Piece(frame, "charGeneralBotRight", 128, 256, 256, -256, "BACKGROUND", -2),
    }
    sheet.doll = {
        Piece(doll, "charTabTopLeft", 256, 256, 0, 0, "BACKGROUND", -1),
        Piece(doll, "charTabTopRight", 128, 256, 256, 0, "BACKGROUND", -1),
        Piece(doll, "charTabBotLeft", 256, 256, 0, -256, "BACKGROUND", -1),
        Piece(doll, "charTabBotRight", 128, 256, 256, -256, "BACKGROUND", -1),
    }

    -- Stat boxes at (67, -291): attributes and armour left, attacks right.
    local attrs = CreateFrame("Frame", nil, doll)
    attrs:SetSize(230, 78)
    attrs:SetPoint("TOPLEFT", doll, "TOPLEFT", 67, -291)
    StatBox(attrs, 0, 0, 53)
    local meleeBottom = StatBox(attrs, 115, 0, 12)
    StatBox(attrs, 115, -46, 11)
    sheet.attrs = attrs
    sheet.attributes = {}
    local prev
    for i = 1, 5 do
        local label = _G["SPELL_STAT" .. i .. "_NAME"] or STAT_NAMES[i]
        local row = StatRow(attrs, label, prev or attrs, prev and "BOTTOMLEFT" or "TOPLEFT", prev and 0 or 6, prev and 0 or -3)
        sheet.attributes[i] = row
        prev = row
    end
    sheet.armor = StatRow(attrs, ARMOR or "Armor", prev, "BOTTOMLEFT", 0, 0)
    sheet.attack = StatRow(attrs, MELEE_ATTACK or "Melee Attack", attrs, "TOPLEFT", 122, -2)
    sheet.attackPower = StatRow(attrs, ATTACK_POWER or "Power", sheet.attack, "BOTTOMLEFT", 5, 1)
    sheet.damage = StatRow(attrs, DAMAGE or "Damage", sheet.attackPower, "BOTTOMLEFT", 0, 1)
    sheet.rangedAttack = StatRow(attrs, RANGED_ATTACK or "Ranged Attack", sheet.damage, "BOTTOMLEFT", -5, -6)
    sheet.rangedPower = StatRow(attrs, ATTACK_POWER or "Power", sheet.rangedAttack, "BOTTOMLEFT", 5, 1)
    sheet.rangedDamage = StatRow(attrs, DAMAGE or "Damage", sheet.rangedPower, "BOTTOMLEFT", 0, 1)
    sheet.attack.tip = MELEE_ATTACK or "Melee Attack"
    sheet.attackPower.tip = MELEE_ATTACK_POWER or "Attack Power"
    sheet.damage.tip = DAMAGE or "Damage"
    sheet.rangedAttack.tip = RANGED_ATTACK or "Ranged Attack"
    sheet.rangedPower.tip = RANGED_ATTACK_POWER or "Ranged Attack Power"
    sheet.rangedDamage.tip = DAMAGE or "Damage"
    meleeBottom:SetPoint("TOPLEFT", attrs, "TOPLEFT", 115, -28)

    -- Resistances up the right edge, 32x29 each.
    local resFrame = CreateFrame("Frame", nil, doll)
    resFrame:SetSize(32, 160)
    resFrame:SetPoint("TOPRIGHT", doll, "TOPLEFT", 297, -77)
    resFrame:SetShown(ns.OnForever())
    sheet.resistances = {}
    prev = nil
    for i, res in ipairs(RESISTANCES) do
        local row = CreateFrame("Frame", nil, resFrame)
        row:SetSize(32, 29)
        row:SetPoint("TOP", prev or resFrame, prev and "BOTTOM" or "TOP", 0, 0)
        local icon = row:CreateTexture(nil, "BACKGROUND")
        ns.SetTex(icon, "charResistIcons")
        icon:SetAllPoints(row)
        icon:SetTexCoord(unpack(res.coords))
        row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.value:SetPoint("BOTTOM", row, "BOTTOM", 0, 3)
        row.id = res.id
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local name = _G["DAMAGE_SCHOOL" .. (self.id + 1)] or _G["RESISTANCE" .. self.id .. "_NAME"] or ("Resistance " .. self.id)
            GameTooltip:SetText(name .. " " .. (RESISTANCE or "Resistance"), 1, 1, 1)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        sheet.resistances[i] = row
        prev = row
    end

    -- Rotate buttons at the model's top left corner.
    if CharacterModelScene then
        sheet.rotateRight = RotateButton(doll, "rotateLeft", -0.6, CharacterModelScene, "TOPLEFT")
        sheet.rotateLeft = RotateButton(doll, "rotateRight", 0.6, sheet.rotateRight, "TOPRIGHT")
    end

    local watcher = CreateFrame("Frame")
    for _, event in ipairs({ "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_DAMAGE", "UNIT_ATTACK_SPEED",
        "UNIT_RESISTANCES", "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "UNIT_LEVEL", "COMBAT_RATING_UPDATE", "UNIT_AURA" }) do
        pcall(watcher.RegisterEvent, watcher, event)
    end
    watcher:SetScript("OnEvent", function(_, _, unit)
        if unit == nil or unit == "player" then UpdateStats() end
    end)
    doll:HookScript("OnShow", function() if active then UpdateStats() end end)
end

local function Fade(region)
    if region then ns.Fade(region) end
end

-- A 1.x character tab: left cap, stretched middle and right cap from the
-- old tab sheets (inactive 32px tall, active 35px), the label centred.
local TAB_MAX_WIDTH = 74
local function TabPieces(tab, active)
    local key = active and "tabActive" or "tabInactive"
    local h = active and 35 or 32
    local bottom = active and 0.546875 or 1
    -- The glow is the same three pieces again on the mouse-over layer,
    -- added at low alpha, so it lights the tab's own shape and nothing
    -- beside it.
    for _, pair in ipairs({ { tab.left, tab.glowLeft, 0, 0.15625 }, { tab.middle, tab.glowMiddle, 0.15625, 0.84375 }, { tab.right, tab.glowRight, 0.84375, 1 } }) do
        local tex, glow, l, r = pair[1], pair[2], pair[3], pair[4]
        ns.SetTex(tex, key)
        tex:SetTexCoord(l, r, 0, bottom)
        if glow then
            ns.SetTex(glow, key)
            glow:SetTexCoord(l, r, 0, bottom)
        end
    end
    tab.left:SetSize(20, h)
    tab.right:SetSize(20, h)
end

local function ClassicTab(parent, index)
    local tab = CreateFrame("Button", "ForeverClassicUICharacterTab" .. index, parent)
    tab:SetHeight(32)
    tab.left = tab:CreateTexture(nil, "BACKGROUND")
    tab.left:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    tab.right = tab:CreateTexture(nil, "BACKGROUND")
    tab.right:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 0, 0)
    tab.middle = tab:CreateTexture(nil, "BACKGROUND")
    tab.middle:SetPoint("TOPLEFT", tab.left, "TOPRIGHT", 0, 0)
    tab.middle:SetPoint("BOTTOMRIGHT", tab.right, "BOTTOMLEFT", 0, 0)
    tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.text:SetPoint("CENTER", tab, "CENTER", 0, -3)
    tab.text:SetWordWrap(false)
    tab.text:SetJustifyH("CENTER")
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        local base = tab[key:lower()]
        local glow = tab:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints(base)
        glow:SetBlendMode("ADD")
        glow:SetAlpha(0.35)
        tab["glow" .. key] = glow
    end
    function tab:SetLabel(text)
        self.text:SetWidth(0)
        self.text:SetText(text)
        local width = math.min(TAB_MAX_WIDTH, math.ceil(self.text:GetStringWidth()) + 30)
        self:SetWidth(width)
        self.text:SetWidth(width - 24)
    end
    function tab:SetSelected(selected)
        TabPieces(self, selected)
        self.text:SetFontObject(selected and "GameFontHighlightSmall" or "GameFontNormalSmall")
    end
    TabPieces(tab, false)
    return tab
end

-- Another addon's copy of the character window (Transmog Inspector's
-- side panel) can wear the same art. Paints the general frame and the
-- paper doll overlay onto the given frame once; later calls only show
-- them again. Returns true when the sheet is on and the art was drawn.
local dressed = setmetatable({}, { __mode = "k" })

-- The size of the old window art, whatever width the client's frame
-- is holding at the moment, then where its border actually ends on the
-- right (the sheet is transparent past that) and begins on the left; a
-- docked copy sits against those edges.
local ART_RIGHT_EDGE, ART_LEFT_EDGE = 349, 3
function ns.SheetArtEdges() return ART_RIGHT_EDGE, ART_LEFT_EDGE end
-- The right edge moves out past the equipment dialog while it is open,
-- so a copy docking beside the sheet goes past the dialog.
function ForeverClassicUI_CharacterSheetSize()
    local extra = ns.EquipmentPaneExtent and ns.EquipmentPaneExtent() or 0
    return WIDTH, HEIGHT, ART_RIGHT_EDGE + extra, ART_LEFT_EDGE
end

function ForeverClassicUI_SkinCharacterCopy(frame)
    if not frame then return false end
    if not dressed[frame] then
        dressed[frame] = {
            Piece(frame, "charGeneralTopLeft", 256, 256, 0, 0, "BACKGROUND", -2),
            Piece(frame, "charGeneralTopRight", 128, 256, 256, 0, "BACKGROUND", -2),
            Piece(frame, "charGeneralBotLeft", 256, 256, 0, -256, "BACKGROUND", -2),
            Piece(frame, "charGeneralBotRight", 128, 256, 256, -256, "BACKGROUND", -2),
            Piece(frame, "charTabTopLeft", 256, 256, 0, 0, "BACKGROUND", -1),
            Piece(frame, "charTabTopRight", 128, 256, 256, 0, "BACKGROUND", -1),
            Piece(frame, "charTabBotLeft", 256, 256, 0, -256, "BACKGROUND", -1),
            Piece(frame, "charTabBotRight", 128, 256, 256, -256, "BACKGROUND", -1),
        }
    end
    for _, tex in ipairs(dressed[frame]) do tex:SetShown(active) end
    return active
end

-- Runs after Blizzard sizes or retabs the character frame.
local function Layout()
    if not active or not built or InCombatLockdown() then return end
    local frame, doll = CharacterFrame, PaperDollFrame
    frame:SetSize(WIDTH, HEIGHT)
    if SetUIPanelAttribute then
        SetUIPanelAttribute(frame, "width", WIDTH)
        SetUIPanelAttribute(frame, "height", HEIGHT)
    end
    Fade(frame.NineSlice)
    Fade(frame.Bg)
    Fade(frame.TopTileStreaks)
    Fade(frame.Inset)
    Fade(frame.InsetRight)
    for _, key in ipairs({ "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft", "BackgroundBotRight", "BackgroundOverlay" }) do
        Fade(doll[key])
        if CharacterModelScene then Fade(CharacterModelScene[key]) end
    end
    if CharacterModelScene and CharacterModelScene.ControlFrame then Fade(CharacterModelScene.ControlFrame) end
    -- Forever: every tab's content hangs off the left pane, which is
    -- wider than the old window and wears its own dark backing. It is
    -- squeezed inside the art, under the name and above the tabs, and
    -- its backing goes; the doll's own pieces are anchored elsewhere.
    local pane = frame.LeftPaneHost
    if pane then
        pane:ClearAllPoints()
        pane:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -60)
        pane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 82)
        for _, region in ipairs({ pane:GetRegions() }) do
            if region:IsObjectType("Texture") then region:SetAlpha(0) end
        end
    end
    -- Forever: the stats pane, its toggle and the mode tab column.
    Fade(frame.RightPaneHost)
    if frame.RightPaneToggleButton then
        Fade(frame.RightPaneToggleButton)
        frame.RightPaneToggleButton:EnableMouse(false)
    end
    if frame.ModeTabs then
        Fade(frame.ModeTabs)
        frame.ModeTabs:EnableMouse(false)
        for _, tab in ipairs(frame.ModeTabs.Tabs or {}) do tab:EnableMouse(false) end
    end

    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    if portrait then
        portrait:SetSize(62, 62)
        portrait:ClearAllPoints()
        portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 9, -6)
    end
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    if title then
        title:ClearAllPoints()
        title:SetPoint("CENTER", frame, "TOP", 6, -24)
        title:SetFontObject("GameFontNormal")
    end
    if title then
        if not sheet.level then
            sheet.level = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        end
        sheet.level:ClearAllPoints()
        sheet.level:SetPoint("TOP", title, "BOTTOM", 0, -6)
        sheet.level:SetText(LevelLine())
        sheet.level:Show()
        if CharacterLevelText then Fade(CharacterLevelText) end
    end
    local close = frame.CloseButton
    if close then
        close:ClearAllPoints()
        close:SetPoint("CENTER", frame, "TOPRIGHT", -44, -25)
        if ns.SkinCloseButton then ns.SkinCloseButton(close, true) end
    end

    -- Slots down each side, weapons underneath.
    local function Column(names, x)
        local prev
        for _, name in ipairs(names) do
            local slot = _G[name]
            if slot then
                slot:ClearAllPoints()
                if prev then
                    slot:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -SLOT_GAP)
                else
                    slot:SetPoint("TOPLEFT", doll, "TOPLEFT", x, -74)
                end
                Fade(_G[name .. "Frame"])
                Fade(slot.BorderFrame)
                prev = slot
            end
        end
    end
    Column(LEFT_SLOTS, 21)
    Column(RIGHT_SLOTS, 306)
    local prev
    for _, name in ipairs(WEAPON_SLOTS) do
        local slot = _G[name]
        if slot then
            slot:ClearAllPoints()
            if prev then
                slot:SetPoint("TOPLEFT", prev, "TOPRIGHT", 5, 0)
            else
                slot:SetPoint("TOPLEFT", doll, "BOTTOMLEFT", 122, 127)
            end
            Fade(_G[name .. "Frame"])
            Fade(slot.BorderFrame)
            prev = slot
        end
    end
    local ammo = _G["CharacterAmmoSlot"]
    if ammo then
        Fade(_G["CharacterAmmoSlotFrame"])
        Fade(ammo.BorderFrame)
        local function FadeGearArt(frame)
            for _, region in ipairs({ frame:GetRegions() }) do
                if region:IsObjectType("Texture") then
                    local atlas = region.GetAtlas and region:GetAtlas()
                    if atlas and atlas:lower():find("gearslot", 1, true) then region:SetAlpha(0) end
                end
            end
        end
        FadeGearArt(ammo)
        for _, child in ipairs({ ammo:GetChildren() }) do FadeGearArt(child) end
    end

    if CharacterModelScene then
        CharacterModelScene:ClearAllPoints()
        CharacterModelScene:SetPoint("TOPLEFT", doll, "TOPLEFT", 65, -78)
        CharacterModelScene:SetSize(233, 224)
        FitModelCamera()
    end

    -- Tabs along the art's bottom strip, built from the old tab sheet:
    -- each takes its label's width (capped, the label cut with "..."),
    -- overlapping the last by 16px, the first 14px in from the left.
    local strip = sheet.general[3]   -- the bottom-left art piece
    local tabPrev
    local function PlaceTab(tab)
        tab:ClearAllPoints()
        if tabPrev then
            tab:SetPoint("LEFT", tabPrev, "RIGHT", -16, 0)
        else
            tab:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 14, 46)
        end
        tabPrev = tab
    end
    if frame.ModeTabs and frame.ModeTabs.Tabs then
        sheet.tabs = sheet.tabs or {}
        for i, mode in ipairs(frame.ModeTabs.Tabs) do
            local tab = sheet.tabs[i]
            if not tab then
                tab = ClassicTab(frame, i)
                tab:SetScript("OnClick", function(self)
                    if self.frameName and ToggleCharacter then ToggleCharacter(self.frameName, true) end
                end)
                sheet.tabs[i] = tab
            end
            tab.frameName = mode.frameName
            tab:SetLabel(TAB_LABELS[mode.frameName or ""] or mode.frameName or "")
            tab:SetSelected(mode.frameName == frame.activeSubframe)
            tab:SetShown(mode:IsShown())
            if mode:IsShown() then PlaceTab(tab) end
        end
    else
        for i = 1, 6 do
            local tab = _G["CharacterFrameTab" .. i]
            if tab and tab:IsShown() then
                if ns.SkinBottomTab then ns.SkinBottomTab(tab) end
                PlaceTab(tab)
            end
        end
    end
    UpdateStats()
    -- Anything docked to the frame (Transmog Inspector) re-lays after us.
    if frame:IsShown() and EventRegistry and EventRegistry.TriggerEvent then EventRegistry:TriggerEvent("ClassicUIForever.CharacterSheetLaid") end
end

---------------------------------------------------------------- reputation

-- The 1.x reputation tab: Faction and Standing over the list, each row
-- the old plate (name at the left, the 137x13 bar frame at the right)
-- with a plain fill, plus and minus on the headers, and the list kept
-- inside the art with the scroll bar on the track beside it. The
-- Forever client draws these rows through a ScrollBox on its wide pane,
-- so the box is re-anchored and each row skinned as it is acquired.

local PLATE_L = { 0, 1, 0, 0.34375 }
local PLATE_R = { 0, 0.0625, 0.34375, 0.671875 }
local BAR_W, BAR_H = 137, 13

local function FadeAtlas(frame, needle)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then
            local atlas = region.GetAtlas and region:GetAtlas()
            if atlas and atlas:lower():find(needle, 1, true) then region:SetAlpha(0) end
        end
    end
end

-- One list row with a bar. Reputation: the old plate (name at the
-- left, the 137x13 bar frame at the right) drawn on the bar itself over
-- a gradient fill in the standing's colour, so the frame's rounded
-- corners shape the fill. Skills: the bar spans the row, the name inside
-- it at the left with the rank after it, the fill blue, the old rounded
-- border around it. Blizzard's own name sits faded; ours mirrors it on
-- the bar, where it draws above the art.
local SKILL_BLUE = { 0, 0, 0.5 }
local SKILL_COORDS, REP_COORDS = { 0, 1, 0, 0.5 }, { 0, 1, 0, 1 }
local function SkinListEntry(row, barKey)
    local content = row.Content
    local bar = content and barKey and content[barKey]
    if not bar then return end
    local skills = barKey == "SkillsBar"
    FadeAtlas(bar, "stat-bar-bg")
    if content.BackgroundHighlight then
        for _, region in ipairs({ content.BackgroundHighlight:GetRegions() }) do region:SetAlpha(0) end
    end
    if content.AccountWideIcon then content.AccountWideIcon:SetAlpha(0) end
    bar:ClearAllPoints()
    if skills then
        bar:SetPoint("LEFT", row, "LEFT", 20, 0)
        bar:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        bar:SetHeight(15)
    else
        bar:SetSize(BAR_W, BAR_H)
        bar:SetPoint("LEFT", row, "LEFT", 130, 0)
    end
    -- The fill: the old gradient under the art, tinted by Blizzard's
    -- colour (the standing's), or the skill blue.
    local fill = bar.Fill
    if fill then
        if bar.Mask and fill.RemoveMaskTexture then pcall(fill.RemoveMaskTexture, fill, bar.Mask) end
        ns.SetTex(fill, "skillsBar")
        fill:SetDrawLayer("BACKGROUND", 0)
        fill:ClearAllPoints()
        if skills then
            fill:SetHeight(15)
            fill:SetPoint("LEFT", bar, "LEFT", 0, 0)
        else
            fill:SetHeight(BAR_H - 2)
            fill:SetPoint("LEFT", bar, "LEFT", 1, 0)
        end
        bar.fcuiInset = skills and 0 or 2
        bar.fcuiCoords = skills and SKILL_COORDS or REP_COORDS
        if not bar.fcuiFill then
            bar.fcuiFill = true
            hooksecurefunc(bar, "SetFillWidth", function(self, width)
                self.Fill:SetWidth(math.max(0, math.min(width, self:GetWidth() - (self.fcuiInset or 0))))
            end)
            hooksecurefunc(bar, "SetFillTextureByColorType", function(self)
                ns.SetTex(self.Fill, "skillsBar")
                self.Fill:SetTexCoord(unpack(self.fcuiCoords))
            end)
            if bar.SetFillPercent then
                hooksecurefunc(bar, "SetFillPercent", function(self) self.Fill:SetTexCoord(unpack(self.fcuiCoords)) end)
            end
            if skills and bar.UpdateBarColor then
                hooksecurefunc(bar, "UpdateBarColor", function(self) self.Fill:SetVertexColor(SKILL_BLUE[1], SKILL_BLUE[2], SKILL_BLUE[3]) end)
            end
            -- 1.x wrote the rank as 250/300, no spaces.
            if skills and bar.SetText then
                hooksecurefunc(bar, "SetText", function(self, text)
                    if type(text) == "string" and text:find(" / ", 1, true) then self.Text:SetText((text:gsub(" / ", "/"))) end
                end)
            end
        end
        fill:SetTexCoord(unpack(bar.fcuiCoords))
        if skills then fill:SetVertexColor(SKILL_BLUE[1], SKILL_BLUE[2], SKILL_BLUE[3]) end
        fill:SetWidth(math.max(0, math.min(fill:GetWidth(), bar:GetWidth() - bar.fcuiInset)))
    end
    -- Our copy of the name, on the bar so it draws over the art.
    local name = ns.OwnFontString(bar, "name", "OVERLAY", skills and "GameFontNormalSmall" or "GameFontHighlightSmall")
    name:SetFontObject(skills and "GameFontNormalSmall" or "GameFontHighlightSmall")
    name:SetText(content.Name and content.Name:GetText() or "")
    name:SetWordWrap(false)
    name:SetJustifyH("LEFT")
    name:ClearAllPoints()
    if content.Name then content.Name:SetAlpha(0) end
    if skills then
        name:SetPoint("LEFT", bar, "LEFT", 6, 1)
        name:SetWidth(0)
        local border = ns.OwnTexture(bar, "border", "BORDER", 0)
        ns.SetTex(border, "skillsBarBorder")
        border:SetTexCoord(0, 1, 0, 1)
        border:ClearAllPoints()
        border:SetPoint("LEFT", bar, "LEFT", -5, 0)
        border:SetPoint("RIGHT", bar, "RIGHT", 5, 0)
        border:SetHeight(32)
        border:Show()
        if bar.Text then
            bar.Text:SetFontObject("GameFontHighlightSmall")
            bar.Text:ClearAllPoints()
            bar.Text:SetPoint("LEFT", name, "RIGHT", 10, -1)
            bar.Text:SetWidth(128)
            bar.Text:SetJustifyH("LEFT")
            local text = bar.Text:GetText()
            if type(text) == "string" and text:find(" / ", 1, true) then bar.Text:SetText((text:gsub(" / ", "/"))) end
        end
    else
        name:SetPoint("LEFT", bar, "LEFT", -119, 0)
        name:SetWidth(104)
        if bar.Text then bar.Text:SetFontObject("GameFontHighlightSmall") end
        -- The plate: the sheet's top strip is the name plate and the bar
        -- frame in one, 126px left of the bar; its right cap follows,
        -- cut above the stray mark the sheet carries under it.
        local left = ns.OwnTexture(bar, "plateLeft", "BORDER", 0)
        ns.SetTex(left, "repPlate")
        left:SetTexCoord(unpack(PLATE_L))
        left:SetSize(256, 22)
        left:ClearAllPoints()
        left:SetPoint("TOPLEFT", bar, "TOPLEFT", -126, 4)
        local right = ns.OwnTexture(bar, "plateRight", "BORDER", 0)
        ns.SetTex(right, "repPlate")
        right:SetTexCoord(unpack(PLATE_R))
        right:SetSize(16, 22)
        right:ClearAllPoints()
        right:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
        left:Show()
        right:Show()
        -- Earlier builds drew the plate on the row's content; those go.
        if content.fcui then
            if content.fcui.plateLeft then content.fcui.plateLeft:Hide() end
            if content.fcui.plateRight then content.fcui.plateRight:Hide() end
        end
    end
    -- A sub-header's own collapse button becomes the old plus and minus.
    local toggle = row.ToggleCollapseButton
    if toggle then
        toggle:SetSize(16, 16)
        toggle:ClearAllPoints()
        if skills then
            toggle:SetPoint("RIGHT", bar, "LEFT", -2, 0)
        else
            toggle:SetPoint("RIGHT", bar, "LEFT", -122, 0)
        end
        toggle:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
        toggle:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
        for _, tex in ipairs({ toggle:GetNormalTexture(), toggle:GetPushedTexture() }) do
            if tex then tex:SetTexCoord(0, 1, 0, 1) tex:SetAllPoints(toggle) end
        end
    end
end

local function SkinRepHeader(row, barKey)
    FadeAtlas(row, "collapseexpand")
    if row.Name then
        row.Name:SetFontObject(barKey == "SkillsBar" and "GameFontHighlight" or "GameFontNormal")
        row.Name:ClearAllPoints()
        row.Name:SetPoint("LEFT", row, "LEFT", 26, 0)
    end
    if row.StateIcon then row.StateIcon:SetAlpha(0) end
    local icon = ns.OwnTexture(row, "collapseIcon", "ARTWORK")
    local collapsed = row.IsCollapsed and row:IsCollapsed()
    icon:SetTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
    icon:SetSize(16, 16)
    icon:ClearAllPoints()
    icon:SetPoint("LEFT", row, "LEFT", 7, 0)
    icon:Show()
end

local function SkinListRow(row, barKey)
    if not active then return end
    -- A row just acquired has no data yet; Blizzard's header methods
    -- index it, so the row is skinned once its data arrives.
    if row.GetElementData and row:GetElementData() == nil then return end
    if row.Content then SkinListEntry(row, barKey) else SkinRepHeader(row, barKey) end
end

-- The client's thin scroll bar wears the old knob and arrows.
local function SkinRepScrollBar(bar)
    if not bar or bar.fcuiSkinned then return end
    bar.fcuiSkinned = true
    local top = ns.OwnTexture(bar, "trackTop", "BACKGROUND", 0)
    ns.SetTex(top, "charScrollBar")
    top:SetTexCoord(0, 0.484375, 0, 1)
    top:SetSize(31, 256)
    top:ClearAllPoints()
    top:SetPoint("TOPLEFT", bar, "TOPLEFT", -8, 9)
    top:Show()
    local bottom = ns.OwnTexture(bar, "trackBottom", "BACKGROUND", 1)
    ns.SetTex(bottom, "charScrollBar")
    bottom:SetTexCoord(0.515625, 1, 0, 0.421875)
    bottom:SetSize(31, 108)
    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -8, -8)
    bottom:Show()
    local track = bar.Track
    if track then
        for _, key in ipairs({ "Begin", "Middle", "End" }) do
            if track[key] then track[key]:SetAlpha(0) end
        end
        local thumb = track.Thumb
        if thumb then
            for _, key in ipairs({ "Begin", "Middle", "End" }) do
                if thumb[key] then thumb[key]:SetAlpha(0) end
            end
            thumb:SetWidth(16)
            local knob = ns.OwnTexture(thumb, "knob", "ARTWORK")
            ns.SetTex(knob, "scrollKnob")
            knob:SetSize(18, 24)
            knob:SetTexCoord(0.2, 0.8, 0.125, 0.875)
            knob:ClearAllPoints()
            knob:SetPoint("CENTER", thumb, "CENTER", 0, 0)
            knob:Show()
        end
    end
    local function Arrow(button, kind)
        if not button then return end
        if button.Texture then button.Texture:SetAlpha(0) end
        button:SetSize(16, 16)
        local tex = ns.OwnTexture(button, "arrow", "ARTWORK")
        ns.SetTex(tex, "scroll" .. kind .. "ButtonUp")
        tex:SetTexCoord(0.25, 0.75, 0.25, 0.75)
        tex:SetAllPoints(button)
        tex:Show()
    end
    Arrow(bar.Back, "Up")
    Arrow(bar.Forward, "Down")
    -- The arrows sit on the track art: 3px right of the thin bar, the
    -- top one 4px above it and the bottom one 4px below.
    if bar.Back then
        bar.Back:ClearAllPoints()
        bar.Back:SetPoint("TOP", bar, "TOP", 3, 4)
    end
    if bar.Forward then
        bar.Forward:ClearAllPoints()
        bar.Forward:SetPoint("BOTTOM", bar, "BOTTOM", 3, -4)
    end
end

-- The list tabs all draw through a ScrollBox on the client's wide
-- pane with the thin scroll bar beside it; each is put inside the art
-- where 1.x drew its list, with the old knob and arrows. Rows with a
-- bar (reputation, skills) get the plate; the rest keep their text.
local listHooked = setmetatable({}, { __mode = "k" })
local function SkinListFrame(frame, barKey)
    local box = frame and frame.ScrollBox
    if not box then return end
    if not listHooked[frame] then
        listHooked[frame] = true
        if box.RegisterCallback and ScrollBoxListMixin and ScrollBoxListMixin.Event then
            -- Initialized, not acquired: a row is acquired before its
            -- data is set, and the header skin reads that data.
            box:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, function(_, row) SkinListRow(row, barKey) end, frame)
        end
        -- Blizzard re-initialises a row on every data change; follow it.
        if box.ForEachFrame and type(frame.Update) == "function" then
            ns.HookMethod(frame, "Update", function()
                if active and box.ForEachFrame then box:ForEachFrame(function(row) SkinListRow(row, barKey) end) end
            end)
        end
    end
    if not active then return end
    local view = box.GetView and box:GetView()
    if view and not view.fcuiExtents then
        view.fcuiExtents = true
        if barKey and view.SetElementExtentCalculator then
            local entry = (barKey == "SkillsBar") and 19 or 23
            local header = (barKey == "SkillsBar") and 18 or 22
            view:SetElementExtentCalculator(function(_, data)
                return (data.isHeader and not data.isChild) and header or entry
            end)
        end
        if view.SetPadding then view:SetPadding(6, 6, 6, 6, 1) end
        if box.FullUpdate then box:FullUpdate(ScrollBoxConstants and ScrollBoxConstants.UpdateImmediately) end
    end
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 12, -76)
    box:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -66, 86)
    for _, child in ipairs({ box:GetChildren() }) do
        if child ~= box.ScrollTarget then FadeAtlas(child, "scrollline") end
    end
    if frame.ScrollBar then
        SkinRepScrollBar(frame.ScrollBar)
        frame.ScrollBar:ClearAllPoints()
        frame.ScrollBar:SetPoint("TOPLEFT", box, "TOPRIGHT", 6, -4)
        frame.ScrollBar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 6, 4)
    end
    if box.ForEachFrame then box:ForEachFrame(function(row) SkinListRow(row, barKey) end) end
    if frame.filterDropdown then
        frame.filterDropdown:ClearAllPoints()
        frame.filterDropdown:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -40, -62)
    end
end

local function SkinReputation()
    local rep = ReputationFrame
    SkinListFrame(rep, "ReputationBar")
    if rep and active then
        local faction = ns.OwnFontString(rep, "factionLabel", "ARTWORK", "GameFontHighlight")
        faction:SetText(FACTION or "Faction")
        faction:ClearAllPoints()
        faction:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 70, -57)
        faction:Show()
        local standing = ns.OwnFontString(rep, "standingLabel", "ARTWORK", "GameFontHighlight")
        standing:SetText(STANDING or "Standing")
        standing:ClearAllPoints()
        standing:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 215, -59)
        standing:Show()
    end
end

local function SkinPvP()
    local pvp = PVPRankFrame
    local main = pvp and pvp.MainInfoFrame
    if not main or not active then return end
    main:ClearAllPoints()
    main:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 6, -70)
    main:SetPoint("BOTTOMRIGHT", CharacterFrame, "TOPRIGHT", -6, -205)
end

local LIST_TABS = { { "SkillsFrame", "SkillsBar" }, { "TokenFrame" }, { "StatisticsFrame" } }
local function SkinListTabs()
    SkinReputation()
    SkinPvP()
    for _, entry in ipairs(LIST_TABS) do
        SkinListFrame(_G[entry[1]], entry[2])
    end
end

-- The side pane's frames go away; Blizzard's flag for it is left alone.
-- Everything Blizzard's Expand shows for the pane: its host, the stats
-- list, the sidebar tabs and level line, each sidebar, and the column
-- of mode tabs and the toggle beside the window.
HideSidePane = function(frame)
    if frame.RightPaneHost then frame.RightPaneHost:Hide() end
    for _, pane in ipairs(frame.SidePanes or {}) do pane:Hide() end
    for _, name in ipairs({ "CharacterStatsPane", "CharacterStatsPaneScrollBox", "PaperDollSidebarTabs", "PaperDollLevelInfo" }) do
        local f = _G[name]
        if f and f.Hide then f:Hide() end
    end
    if type(GetPaperDollSideBarFrame) == "function" and type(PAPERDOLL_SIDEBARS) == "table" then
        for i = 1, #PAPERDOLL_SIDEBARS do
            local bar = GetPaperDollSideBarFrame(i)
            -- The equipment manager stays while our dialog holds it.
            local keep = bar == (PaperDollFrame and PaperDollFrame.EquipmentManagerPane) and ns.EquipmentPaneOpen and ns.EquipmentPaneOpen()
            if bar and bar.Hide and not keep then bar:Hide() end
        end
    end
    if frame.ModeTabs then frame.ModeTabs:Hide() end
    if frame.RightPaneToggleButton then frame.RightPaneToggleButton:Hide() end
end

local hooked = false
local function Apply()
    active = true
    if not CharacterFrame or not PaperDollFrame then ns.MissingPiece("CharacterFrame") return end
    if not built then Build() end
    if not hooked then
        hooked = true
        ns.HookMethod(CharacterFrame, "UpdateSize", Layout)
        ns.HookMethod(CharacterFrame, "UpdateTabBounds", Layout)
        -- The side panel never shows; the sheet is the old single pane.
        -- Its frames are hidden, never its state: Blizzard's collapsed
        -- flag is a Lua field its own show path reads, and a write from
        -- here would taint that path (the status bar text compares a
        -- secret value right after it and errors).
        ns.HookMethod(CharacterFrame, "Expand", function(self)
            if active then HideSidePane(self) end
        end)
        if ReputationFrame then ReputationFrame:HookScript("OnShow", SkinReputation) end
        if PVPRankFrame then PVPRankFrame:HookScript("OnShow", SkinPvP) end
        for _, entry in ipairs(LIST_TABS) do
            local frame = _G[entry[1]]
            if frame then
                local key = entry[2]
                frame:HookScript("OnShow", function(self) SkinListFrame(self, key) end)
            end
        end
        if CharacterFrame.RefreshRightPane then
            ns.HookMethod(CharacterFrame, "RefreshRightPane", function(self)
                if active then HideSidePane(self) end
            end)
            ns.HookMethod(CharacterFrame, "ShowSubFrame", function() if active then C_Timer.After(0, Layout) end end)
        end
        if type(PaperDollFrame_UpdateSidebarTabs) == "function" then
            ns.HookGlobal("PaperDollFrame_UpdateSidebarTabs", function() if active then HideSidePane(CharacterFrame) end end)
        end
        CharacterFrame:HookScript("OnShow", function() if active then Layout() end end)
        -- A new camera comes with every model scene transition; fit it too.
        if CharacterModelScene then
            if CharacterModelScene.TransitionToModelSceneID then
                ns.HookMethod(CharacterModelScene, "TransitionToModelSceneID", function()
                    if active then C_Timer.After(0, FitModelCamera) end
                end)
            end
            CharacterModelScene:HookScript("OnShow", function()
                if active then C_Timer.After(0.1, FitModelCamera) end
            end)
        end
        -- What the sheet knows about the camera, for the dev probe.
        function ns.CharacterCameraInfo()
            local scene = CharacterModelScene
            local camera = scene and scene.GetActiveCamera and scene:GetActiveCamera()
            if not camera then return "no camera" end
            local ok, distance = pcall(function() return camera:GetZoomDistance() end)
            local okMax, max = pcall(function() return camera:GetMaxZoomDistance() end)
            return string.format("camera %s fitted %s zoom %s max %s", tostring(camera.GetDebugName and camera:GetDebugName() or "?"), tostring(camera.fcuiFitted), ok and tostring(distance) or "n/a", okMax and tostring(max) or "n/a")
        end
    end
    HideSidePane(CharacterFrame)
    if ns.EquipmentPaneApply then ns.EquipmentPaneApply() end
    -- Next login Blizzard loads the pane collapsed itself, from its cvar.
    if C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar, "characterFrameCollapsed", "1") end
    SkinListTabs()
    -- Other addons that dock onto the character frame can read this.
    ForeverClassicUI_CharacterSheetActive = true
    for _, tex in ipairs(sheet.general) do tex:Show() end
    for _, tex in ipairs(sheet.doll) do tex:Show() end
    sheet.attrs:Show()
    Layout()
end

local function Restore()
    active = false
    ForeverClassicUI_CharacterSheetActive = false
    if not built then return end
    if sheet.level then sheet.level:Hide() end
    for _, tab in ipairs(sheet.tabs or {}) do tab:Hide() end
    for _, tex in ipairs(sheet.general) do tex:Hide() end
    for _, tex in ipairs(sheet.doll) do tex:Hide() end
    sheet.attrs:Hide()
    for _, row in ipairs(sheet.resistances) do row:Hide() end
    if sheet.rotateLeft then sheet.rotateLeft:Hide() end
    if sheet.rotateRight then sheet.rotateRight:Hide() end
    if ns.EquipmentPaneRestore then ns.EquipmentPaneRestore() end
    ns.needsReload = true
end

ns.RegisterModule("characterSheet", { apply = Apply, restore = Restore })
