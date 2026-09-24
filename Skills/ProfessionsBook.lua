local _, ns = ...

-- The old book on two parchment pages: primary rows (emblem, name, rank, green bar, two plated spells), three short secondary rows.
-- BookPage and its spell buttons are the client's and cast: parents kept, only moved; other card art faded, our rows draw the rest.
-- Fills reset a primary card's spells to fixed offsets from its foot (combat too): the card is cut to their column and moved instead.

local T = {}
ns.prof = T -- shared with the window half (watcher, faces, tabs): ProfessionsWindow.lua
T.built = false

local SHEET = "Interface\\Spellbook\\ProfessionsBook"
local PAGE_LEFT = "Interface\\Spellbook\\Professions-Book-Left"
local PAGE_RIGHT = "Interface\\Spellbook\\Professions-Book-Right"
-- Second primary row sits low on its band (rows 106 apart, art bands 93): raise
-- the whole row; raising only rank, bar and spells left the emblem over the border.
local SECOND_LIFT = { 0, 15 }

-- Rows, from the content frame's top left corner.
local ROW_X, ROW_W = 80, 437
local PRIMARY_H, SECONDARY_H = 100, 52
local PRIMARY_Y = { -62, -168 }
local SECONDARY_Y = { -282, -352, -422 }
-- Bands are 76 apart, rows 70: each band is redrawn centred on its row (First
-- Aid by its emblem, high in the art). { art top, art bottom, drawn top, drawn
-- bottom } in the 512 px page.
local BAND_X = 64 -- the page margin left of here runs straight down and stays put
local BAND_STRIPS = {
    { 286, 302, 236, 252 }, -- plain parchment under the ornament
    { 236, 298, 252, 314 }, -- Cooking
    { 304, 380, 314, 390 }, -- Fishing
    { 380, 432, 390, 442 }, -- First Aid
    { 432, 456, 442, 456 }, -- First Aid foot, squeezed to the book edge
}
-- Spell column x on a row, and the x the client gives a primary card's buttons
-- from its bottom left.
local SPELL_X = 288
local CLIENT_BUTTON_X = 15

-- What the client draws on a card, faded (see FadeCard).
local CARD_ART = { "Background", "ProfessionName", "specialization", "missingHeader", "missingText", "Rank", "icon", "IconBorder" }

local SetShownIf = ns.SetShownIf

local rows = {}

local function Page()
    return ProfessionsFrame and ProfessionsFrame.BookPage
end
T.Page = Page

local function Content()
    local page = Page()
    return page and page.ProfessionsContentFrame
end

local function Font(fontString, name, fallback)
    local object = _G[name] or _G[fallback]
    if object then fontString:SetFontObject(object) end
end

---------------------------------------------------------------------------
-- The rows
---------------------------------------------------------------------------

local function NewBar(parent)
    -- The old bar is still a client template; made from here it is ours.
    local ok, bar = pcall(CreateFrame, "StatusBar", nil, parent, "ProfessionStatusBarTemplate")
    if not ok or not bar then
        bar = CreateFrame("StatusBar", nil, parent)
        bar:SetSize(95, 16)
        bar:SetStatusBarTexture("Interface\\Spellbook\\Professions-Progress-Fill")
        bar.rankText = bar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        bar.rankText:SetPoint("CENTER", 0, 2)
    end
    if bar.capped then bar.capped:Hide() end
    bar:SetStatusBarColor(0, 1, 0)
    return bar
end

local function NewRow(content, primary, y, lift)
    local row = CreateFrame("Frame", nil, content)
    row:SetSize(ROW_W, primary and PRIMARY_H or SECONDARY_H)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", ROW_X, y + (lift or 0))
    row.primary = primary

    row.name = row:CreateFontString(nil, "ARTWORK")
    row.rank = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.rank:SetJustifyH("LEFT")
    row.bar = NewBar(row)
    row.missingHeader = row:CreateFontString(nil, "ARTWORK")
    row.missingText = row:CreateFontString(nil, "ARTWORK")
    Font(row.missingText, "SubSpellFont", "GameFontHighlightSmall")
    row.missingText:SetJustifyH("LEFT")
    row.missingText:SetTextColor(0.1, 0.05, 0.05)

    if primary then
        local ring = row:CreateTexture(nil, "ARTWORK", nil, 1)
        ring:SetTexture(SHEET)
        ring:SetTexCoord(0.43359375, 0.72265625, 0.14843750, 0.72656250)
        ring:SetSize(72, 72)
        ring:SetPoint("TOPLEFT", row, "TOPLEFT", 7, -12)
        row.ring = ring
        local icon = row:CreateTexture(nil, "ARTWORK", nil, 0)
        icon:SetPoint("TOPLEFT", ring, "TOPLEFT", 8, -8)
        icon:SetPoint("BOTTOMRIGHT", ring, "BOTTOMRIGHT", -8, 8)
        row.icon = icon

        Font(row.name, "QuestTitleFontBlackShadow", "GameFontNormalLarge")
        row.name:SetJustifyH("LEFT")
        row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 100, -8)
        row.rank:SetPoint("TOPLEFT", row, "TOPLEFT", 100, -56)
        row.rank:SetWidth(182)
        row.bar:SetPoint("TOPLEFT", row.rank, "BOTTOMLEFT", 14, -5)

        Font(row.missingHeader, "QuestTitleFontBlackShadow", "GameFontNormalLarge")
        row.missingHeader:SetTextColor(0.85, 0.7, 0.6)
        row.missingHeader:SetPoint("TOPLEFT", row, "TOPLEFT", 120, -20)
        row.missingText:SetWidth(305)
        row.missingText:SetPoint("TOPLEFT", row.missingHeader, "BOTTOMLEFT", 0, -1)
    else
        row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 16, 2)
        row.rank:SetPoint("BOTTOMLEFT", row.bar, "TOPLEFT", -14, 4)
        row.rank:SetPoint("BOTTOMRIGHT", row.bar, "TOPRIGHT", 25, 4)
        Font(row.name, "QuestFont_Shadow_Small", "GameFontNormal")
        row.name:SetJustifyH("LEFT")
        row.name:SetTextColor(1, 0.82, 0)
        row.name:SetShadowColor(0, 0, 0)
        row.name:SetPoint("BOTTOMLEFT", row.rank, "TOPLEFT", 0, 2)
        row.name:SetPoint("BOTTOMRIGHT", row.rank, "TOPRIGHT", 0, 2)

        Font(row.missingHeader, "QuestFont_Large", "GameFontNormalLarge")
        row.missingHeader:SetTextColor(0.15, 0.1, 0.1)
        row.missingHeader:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -15)
        row.missingText:SetWidth(250)
        row.missingText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    end
    return row
end

-- Rank title for a skill cap, in the old book's wording.
local function RankTitle(maxRank)
    local ranks = PROFESSION_RANKS
    if type(ranks) ~= "table" or not maxRank then return "" end
    local title = ""
    for _, entry in ipairs(ranks) do
        title = entry[2] or title
        if maxRank <= (entry[1] or 0) then break end
    end
    return title
end

local MISSING = {
    { header = "PROFESSIONS_FIRST_PROFESSION", text = "PROFESSIONS_MISSING_PROFESSION" },
    { header = "PROFESSIONS_SECOND_PROFESSION", text = "PROFESSIONS_MISSING_PROFESSION" },
    { header = "PROFESSIONS_COOKING", text = "PROFESSIONS_COOKING_MISSING" },
    { header = "PROFESSIONS_FISHING", text = "PROFESSIONS_FISHING_MISSING" },
    { header = "PROFESSIONS_FIRST_AID", text = "PROFESSIONS_FIRST_AID_MISSING" },
}

local function FillRow(row, index, slot)
    local name, texture, rank, maxRank, rankModifier, _
    if index and GetProfessionInfo then
        name, texture, rank, maxRank, _, _, _, rankModifier = GetProfessionInfo(index)
    end
    local known = name ~= nil
    row.name:SetShown(known)
    row.rank:SetShown(known)
    row.bar:SetShown(known)
    row.missingHeader:SetShown(not known)
    row.missingText:SetShown(not known)
    if row.icon then
        if known and texture then
            row.icon:SetTexture(texture)
            row.icon:SetDesaturated(false)
        else
            row.icon:SetTexture("Interface\\Icons\\INV_Scroll_04")
        end
        -- Past the icon's own border, cut round to the ring's hole.
        ns.RoundIcon(row.icon, 1)
    end
    if not known then
        local words = MISSING[slot] or MISSING[1]
        row.missingHeader:SetText(_G[words.header] or "")
        row.missingText:SetText(_G[words.text] or "")
        return
    end
    row.name:SetText(name)
    row.rank:SetText(RankTitle(maxRank))
    rank, maxRank = rank or 0, maxRank or 0
    row.bar:SetMinMaxValues(0, math.max(1, maxRank))
    row.bar:SetValue(rank)
    if row.bar.rankText then
        if rankModifier and rankModifier > 0 then
            row.bar.rankText:SetFormattedText(TRADESKILL_RANK_WITH_MODIFIER or "%d (+%d)/%d", rank, rankModifier, maxRank)
        else
            row.bar.rankText:SetFormattedText(TRADESKILL_RANK or "%d/%d", rank, maxRank)
        end
    end
end

---------------------------------------------------------------------------
-- Professions past the five rows (Poisons)
---------------------------------------------------------------------------

-- The client's cards take GetProfessions' first five returns; the rest (Poisons) had only a side tab.
-- Ours: casting plates in a free spell column of a secondary row, armed out of combat.
local EXTRA_MAX = 4
-- Secondary spell columns (content x of SpellButton1, 2 as PlaceCards lays them) and their top below the row.
local COLUMN_X = { ROW_X + ROW_W - 109 - 37, ROW_X + ROW_W - 2 * (109 + 37) }
local COLUMN_DROP = 6
-- A missing row's text, narrowed left of a plate in its first column.
local MISSING_W, MISSING_RIGHT, MISSING_NARROW_W, MISSING_NARROW_RIGHT = 250, -5, 141, -151
local BANK = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
local ITEM_SPELL = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
local IsSecret = ns.IsSecret
local extras = {}

local function Pack(...) return select("#", ...), { ... } end

-- The client's side tab rule for a profession listing no spells: spellOffset + 1 counts if it opens a trade skill.
function T.OpensTrade(info)
    local id = info and info.spellID
    if not id or IsSecret(id) or not (C_TradeSkillUI and C_TradeSkillUI.CanTradeSkillShowCraftingUI) then return false end
    local ok, can = pcall(C_TradeSkillUI.CanTradeSkillShowCraftingUI, id)
    return ok and not IsSecret(can) and can == true
end

local function Extra_OnEnter(self)
    if not self.slot then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetSpellBookItem(self.slot, BANK)
    GameTooltip:Show()
end

-- Pickup is protected in combat; the client's own book has no button for these to lend.
local function Extra_OnDragStart(self)
    if not self.slot or self.isPassive or InCombatLockdown() then return end
    C_SpellBook.PickupSpellBookItem(self.slot, BANK)
end

-- Fires on press and release; links on release.
local function Extra_PostClick(self, _, down)
    if down or not self.slot or not IsModifiedClick("CHATLINK") then return end
    local ok, link = pcall(C_SpellBook.GetSpellBookItemTradeSkillLink, self.slot, BANK)
    if not ok or not link or IsSecret(link) then ok, link = pcall(C_SpellBook.GetSpellBookItemLink, self.slot, BANK) end
    if ok and link and not IsSecret(link) then ChatEdit_InsertLink(link) end
end

-- The old book's plate right of a spell button.
local function SpellPlate(button)
    local plate = button:CreateTexture(nil, "BACKGROUND")
    plate:SetTexture(SHEET)
    plate:SetTexCoord(0.00390625, 0.42578125, 0.14843750, 0.46875000)
    plate:SetSize(108, 41)
    plate:SetPoint("LEFT", button, "RIGHT", 1, 0)
    return plate
end

-- Placed by FillExtras; out of combat (secure).
local function NewExtra(content, i)
    local button = CreateFrame("Button", nil, content, "SecureActionButtonTemplate")
    button:SetSize(37, 37)
    button:SetFrameLevel(content:GetFrameLevel() + 10)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:RegisterForDrag("LeftButton")
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("shift-type1", "")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints(button)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    SpellPlate(button)
    button.name = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    button.name:SetWidth(100)
    button.name:SetMaxLines(2)
    button.name:SetJustifyH("LEFT")
    button.name:SetPoint("LEFT", button, "RIGHT", 5, 7)
    button.sub = button:CreateFontString(nil, "ARTWORK")
    Font(button.sub, "NewSubSpellFont", "GameFontHighlightSmall")
    button.sub:SetSize(95, 14)
    button.sub:SetJustifyH("LEFT")
    button.sub:SetPoint("TOPLEFT", button.name, "BOTTOMLEFT", 0, -1)
    button:SetScript("OnEnter", Extra_OnEnter)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:SetScript("OnDragStart", Extra_OnDragStart)
    button:SetScript("PostClick", Extra_PostClick)
    button:Hide()
    extras[i] = button
    return button
end

-- The extra professions' spells, as the client's side tabs read them (spellOffset + n).
local function ExtraSpells()
    local out = {}
    if not GetProfessions or not GetProfessionInfo then return out end
    local count, profs = Pack(GetProfessions())
    for i = 6, count do
        local prof = profs[i]
        local numSpells, offset
        if prof and not IsSecret(prof) then numSpells, offset = select(5, GetProfessionInfo(prof)) end
        if type(numSpells) == "number" and type(offset) == "number" and not IsSecret(numSpells) and not IsSecret(offset) then
            for slot = offset + 1, offset + math.max(numSpells, 1) do
                local info = C_SpellBook.GetSpellBookItemInfo(slot, BANK)
                if numSpells == 0 and not T.OpensTrade(info) then info = nil end
                local kind, id = info and info.itemType, info and info.actionID
                if id and not IsSecret(id) and not IsSecret(kind) and kind == ITEM_SPELL and #out < EXTRA_MAX then
                    out[#out + 1] = { slot = slot, info = info }
                end
            end
        end
    end
    return out
end

local function NarrowMissing(row, on)
    local text = row and row.missingText
    if not text then return end
    text:SetWidth(on and MISSING_NARROW_W or MISSING_W)
    ns.SetPointOnce(text, "RIGHT", row, "RIGHT", on and MISSING_NARROW_RIGHT or MISSING_RIGHT, 0)
end

-- Free spell columns on parchment: known secondary rows' unused columns, then a missing row's first column; First Aid up.
local function ExtraSpots(cook, fish, faid)
    local spots, known = {}, { cook, fish, faid }
    for i = 3, 1, -1 do
        local index = known[i]
        local numSpells = index and select(5, GetProfessionInfo(index))
        if type(numSpells) == "number" and not IsSecret(numSpells) then
            for column = numSpells + 1, #COLUMN_X do
                spots[#spots + 1] = { x = COLUMN_X[column], y = SECONDARY_Y[i] - COLUMN_DROP }
            end
        end
    end
    for i = 3, 1, -1 do
        if not known[i] then
            spots[#spots + 1] = { x = COLUMN_X[1], y = SECONDARY_Y[i] - COLUMN_DROP, narrow = rows[2 + i] }
        end
    end
    return spots
end

local function FillExtras(cook, fish, faid)
    local content = Content()
    if not content or InCombatLockdown() then return end
    local list = ExtraSpells()
    local spots = #list > 0 and ExtraSpots(cook, fish, faid) or {}
    for i = 3, 5 do NarrowMissing(rows[i], false) end
    for i = 1, math.max(#list, #extras) do
        local entry = spots[i] and list[i]
        local button = extras[i] or (entry and NewExtra(content, i))
        if button then
            if entry then
                ns.SetPointOnce(button, "TOPLEFT", content, "TOPLEFT", spots[i].x, spots[i].y)
                if spots[i].narrow then NarrowMissing(spots[i].narrow, true) end
            end
            local info = entry and entry.info
            local passive = info and not IsSecret(info.isPassive) and info.isPassive or false
            button.slot = entry and entry.slot or nil
            button.isPassive = passive
            button.icon:SetTexture(info and info.iconID or nil)
            button.name:SetText(info and info.name or "")
            button.sub:SetText(info and info.subName or "")
            local id = info and not passive and info.actionID or nil
            button:SetAttribute("type1", id and "spell" or nil)
            button:SetAttribute("spell", id)
            if not button.slot then button:Hide() end
        end
    end
end

function T.FillRows()
    if not T.built or not GetProfessions then return end
    local prof1, prof2, faid, fish, cook = GetProfessions()
    FillRow(rows[1], prof1, 1)
    FillRow(rows[2], prof2, 2)
    FillRow(rows[3], cook, 3)
    FillRow(rows[4], fish, 4)
    FillRow(rows[5], faid, 5)
    FillExtras(cook, fish, faid)
end

---------------------------------------------------------------------------
-- The client's cards
---------------------------------------------------------------------------

-- Faded, never hidden: the client re-shows these on every fill but leaves alpha alone.
local function FadeCard(card)
    ns.FadeKeys(card, CARD_ART)
    local bar = card.StatusBar
    if bar then
        bar:SetAlpha(0)
        if bar.EnableMouse then bar:EnableMouse(false) end
    end
end

local function DressSpellButton(button)
    if not button or not ns.Once(button, "spellPlate") then return end
    SpellPlate(button)
    -- Drop this client's square icon frame and rounded mask.
    if button.IconTextureOverlay then button.IconTextureOverlay:SetAlpha(0) end
    if button.IconTexture and button.OutlineMask and button.IconTexture.RemoveMaskTexture then
        pcall(button.IconTexture.RemoveMaskTexture, button.IconTexture, button.OutlineMask)
    end
end

local function DressUnlearn(card, content, y)
    local button = card.UnlearnButton
    if not button then return end
    -- Just left of the bar's end cap, level with the bar.
    ns.SetPointOnce(button, "CENTER", content, "TOPLEFT", ROW_X + 100 - 15, y - 76)
    if button.Icon then
        button.Icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        button.Icon:SetSize(16, 16)
        button.Icon:SetAlpha(0.75)
    end
    if button.Overlay then button.Overlay:SetAlpha(0) end
    ns.SetPointOnce(card.GamepadUnlearnButton, "RIGHT", button, "LEFT", -2, 0)
end

-- Cards hold casting buttons: placed out of combat only, retried after.
function T.PlaceCards()
    local content = Content()
    if not content or InCombatLockdown() then return false end
    for i = 1, 2 do
        local card = content["PrimaryProfession" .. i]
        if card then
            local y = PRIMARY_Y[i]
            local lift = SECOND_LIFT[i] or 0
            card:SetSize(170, PRIMARY_H)
            ns.SetPointOnce(card, "TOPLEFT", content, "TOPLEFT", ROW_X + SPELL_X - CLIENT_BUTTON_X, y - 5 + lift)
            FadeCard(card)
            DressSpellButton(card.SpellButton1)
            DressSpellButton(card.SpellButton2)
            DressUnlearn(card, content, y + lift)
        end
    end
    for i = 1, 3 do
        local card = content["SecondaryProfession" .. i]
        if card then
            card:SetSize(ROW_W, SECONDARY_H)
            ns.SetPointOnce(card, "TOPLEFT", content, "TOPLEFT", ROW_X, SECONDARY_Y[i])
            FadeCard(card)
            local previous
            for n = 1, 4 do
                local button = card["SpellButton" .. n]
                if button then
                    DressSpellButton(button)
                    button:ClearAllPoints()
                    if previous then
                        button:SetPoint("TOPRIGHT", previous, "TOPLEFT", -109, 0)
                    else
                        button:SetPoint("TOPRIGHT", card, "TOPRIGHT", -109, -6)
                    end
                    previous = button
                end
            end
        end
    end
    return true
end

---------------------------------------------------------------------------
-- The book
---------------------------------------------------------------------------

function T.Build()
    local page, content = Page(), Content()
    if T.built or not page or not content then return T.built end
    -- Our left page has First Aid's emblem where this client's has Archaeology's
    -- (Art/Textures.lua); falls back to the client's page.
    local left = page:CreateTexture(nil, "BACKGROUND", nil, 2)
    if not ns.SetTex(left, "professionsBookLeft") then left:SetTexture(PAGE_LEFT) end
    left:SetSize(512, 512)
    left:SetPoint("TOPLEFT", page, "TOPLEFT", 7, -25)
    local right = page:CreateTexture(nil, "BACKGROUND", nil, 2)
    right:SetTexture(PAGE_RIGHT)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    rows.art = { left, right }
    for _, strip in ipairs(BAND_STRIPS) do
        local band = page:CreateTexture(nil, "BACKGROUND", nil, 3)
        if not ns.SetTex(band, "professionsBookLeft") then band:SetTexture(PAGE_LEFT) end
        band:SetTexCoord(BAND_X / 512, 1, strip[1] / 512, strip[2] / 512)
        -- Both corners on the page texture, so neighbouring strips share an edge exactly.
        band:SetPoint("TOPLEFT", left, "TOPLEFT", BAND_X, -strip[3])
        band:SetPoint("BOTTOMRIGHT", left, "TOPRIGHT", 0, -strip[4])
        rows.art[#rows.art + 1] = band
    end
    for i = 1, 2 do rows[i] = NewRow(content, true, PRIMARY_Y[i], SECOND_LIFT[i]) end
    for i = 1, 3 do rows[2 + i] = NewRow(content, false, SECONDARY_Y[i]) end
    T.built = true
    return true
end

-- Old book's mid-row spells: each fill resets them to 10 and 60 (whole offsets, no tie at 0.5); casting buttons, out of combat.
local SPELL_LOW, SPELL_HIGH = 15, 56
local Near = ns.Near
local function Tighten(button)
    local point, rel, relPoint, x, y = button:GetPoint(1)
    if point == "BOTTOMLEFT" and y then
        local want
        if Near(y, 60, 0.5) then want = SPELL_HIGH elseif Near(y, 10, 0.5) then want = SPELL_LOW end
        if want then button:SetPoint(point, rel, relPoint, x, want) end
    end
end

function T.TightenSpells()
    local content = Content()
    if not content or InCombatLockdown() then return end
    for i = 1, 2 do
        local card = content["PrimaryProfession" .. i]
        local first, second = card and card.SpellButton1, card and card.SpellButton2
        if first and second and first:IsShown() and second:IsShown() then
            Tighten(first)
            Tighten(second)
        end
    end
end

-- Our art only once the cards are placed (impossible in combat): a book first
-- opened in combat showed our rows over the client's cards.
function T.ShowOurs(on)
    if not T.built then return end
    for _, tex in ipairs(rows.art) do SetShownIf(tex, on) end
    for i = 1, 5 do
        if rows[i] then SetShownIf(rows[i], on) end
    end
    -- Secure plates: shown and hidden out of combat only; the page hides them in combat.
    if InCombatLockdown() then return end
    for _, button in ipairs(extras) do SetShownIf(button, on and button.slot ~= nil) end
end
