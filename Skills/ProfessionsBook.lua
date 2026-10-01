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
-- Rows, from the content frame's top left corner (rowY: two primaries, three secondaries): the full book (its second
-- primary raised 15 onto its band), or the 1.x window's size (option), each row on its own band of the page cut
-- off on the right, stacked with no spare parchment.
local BIG = { rowX = 80, rowW = 437, ring = 72, ringX = 7, ringY = -12, textX = 100, nameY = -8, rankW = 182,
    spellX = 288, plates = true, rowY = { -62, -153, -282, -352, -422 } }
local SMALL = { rowX = 17, rowW = 305, ring = 48, ringX = 4, ringY = -23, textX = 58, nameY = -11, rankW = 97,
    spellX = 159, barW = 64, plates = false, iconsX = 159, descX = 129, descSize = 9, rowY = { -37, -131, -230, -294, -358 } }
-- The small page's art: { texture top, bottom, drawn top } on the left page from its spine margin, 322 wide.
-- Every band drawn PULL further into the art, so the secondaries' emblems (at x 150-186) stand near their names; a cut
-- inside a band showed a seam, so the whole band moves and its soft left rim goes under the window's metal.
local PULL = 24
local SMALL_ART_X, SMALL_ART_U, SMALL_ART_W = 8, 64, 322
local SMALL_BANDS = {
    { 26, 38, 24 },    -- the page's top edge
    { 38, 132, 36 },   -- first primary band
    { 38, 132, 130 },  -- second primary, on the first's band
    { 236, 300, 224 }, -- Cooking
    { 314, 378, 288 }, -- Fishing
    { 392, 456, 352 }, -- First Aid
    { 458, 466, 416 }, -- the page's foot
}
local PRIMARY_H, SECONDARY_H = 100, 52

function T.Big() return ns.db == nil or ns.db.profBookBig == true end
local function Spec() return T.Big() and BIG or SMALL end
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
-- The x the client gives a primary card's buttons from its bottom left.
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
    local ok, bar = pcall(ns.NewFrame, "StatusBar", nil, parent, "ProfessionStatusBarTemplate")
    if not ok or not bar then
        bar = ns.NewFrame("StatusBar", nil, parent)
        bar:SetSize(95, 16)
        bar:SetStatusBarTexture("Interface\\Spellbook\\Professions-Progress-Fill")
        bar.rankText = bar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        bar.rankText:SetPoint("CENTER", 0, 2)
    end
    if bar.capped then bar.capped:Hide() end
    bar:SetStatusBarColor(0, 1, 0)
    return bar
end

local function NewRow(content, primary, index)
    local row = ns.NewFrame("Frame", nil, content)
    row.index = index
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
        row.ring = ring
        local icon = row:CreateTexture(nil, "ARTWORK", nil, 0)
        row.icon = icon

        Font(row.name, "QuestTitleFontBlackShadow", "GameFontNormalLarge")
        row.name:SetJustifyH("LEFT")
        row.bar:SetPoint("TOPLEFT", row.rank, "BOTTOMLEFT", 14, -5)

        Font(row.missingHeader, "QuestTitleFontBlackShadow", "GameFontNormalLarge")
        row.missingHeader:SetTextColor(0.85, 0.7, 0.6)
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
        row.missingText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    end
    return row
end

-- A row's size and inner spots for the page size.
local function LayRow(row, content, spec)
    row:SetSize(spec.rowW, row.primary and PRIMARY_H or SECONDARY_H)
    row.bar.fullW = row.bar.fullW or row.bar:GetWidth()
    row.bar:SetWidth(spec.barW or row.bar.fullW)
    ns.SetPointOnce(row, "TOPLEFT", content, "TOPLEFT", spec.rowX, spec.rowY[row.index])
    if row.primary then
        row.ring:SetSize(spec.ring, spec.ring)
        ns.SetPointOnce(row.ring, "TOPLEFT", row, "TOPLEFT", spec.ringX, spec.ringY)
        local inset = spec.ring / 9
        ns.SetPointOnce(row.icon, "TOPLEFT", row.ring, "TOPLEFT", inset, -inset)
        row.icon:SetPoint("BOTTOMRIGHT", row.ring, "BOTTOMRIGHT", -inset, inset)
        ns.SetPointOnce(row.name, "TOPLEFT", row, "TOPLEFT", spec.textX, spec.nameY)
        row.name:SetWidth(spec.spellX - spec.textX - 4)
        ns.SetPointOnce(row.rank, "TOPLEFT", row, "TOPLEFT", spec.textX, -56)
        row.rank:SetWidth(spec.rankW)
        ns.SetPointOnce(row.missingHeader, "TOPLEFT", row, "TOPLEFT", spec.textX + 20, -20)
        row.missingText:SetWidth(spec.rowW - spec.textX - 32)
    else
        -- Untrained: the description after the emblem on the small page, at the row's right on the full one.
        row.missingText:ClearAllPoints()
        if spec.descX then
            row.missingText:SetPoint("LEFT", row, "LEFT", spec.descX, 0)
            row.missingText:SetWidth(spec.rowW - spec.descX - 5)
        else
            row.missingText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
            row.missingText:SetWidth(spec.rowW - 187)
        end
    end
    -- The small page's descriptions a point smaller, to fit their band.
    local font, size, flags = row.missingText:GetFont()
    row.descSize = row.descSize or size
    if font then row.missingText:SetFont(font, spec.descSize or row.descSize, flags) end
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
-- Professions past the five rows (Poisons): the client's side tab and our General tab reach them, not this page
---------------------------------------------------------------------------

local IsSecret = ns.IsSecret

-- The client's side tab rule for a profession listing no spells: spellOffset + 1 counts if it opens a trade skill.
function T.OpensTrade(info)
    local id = info and info.spellID
    if not id or IsSecret(id) or not (C_TradeSkillUI and C_TradeSkillUI.CanTradeSkillShowCraftingUI) then return false end
    local ok, can = pcall(C_TradeSkillUI.CanTradeSkillShowCraftingUI, id)
    return ok and not IsSecret(can) and can == true
end

-- The old book's plate right of a spell button.
local plates = {}   -- spell button -> its plate
local function SpellPlate(button)
    local plate = button:CreateTexture(nil, "BACKGROUND")
    plates[button] = plate
    plate:SetTexture(SHEET)
    plate:SetTexCoord(0.00390625, 0.42578125, 0.14843750, 0.46875000)
    plate:SetSize(108, 41)
    plate:SetPoint("LEFT", button, "RIGHT", 1, 0)
    return plate
end

function T.FillRows()
    if not T.built or not GetProfessions then return end
    local prof1, prof2, faid, fish, cook = GetProfessions()
    FillRow(rows[1], prof1, 1)
    FillRow(rows[2], prof2, 2)
    FillRow(rows[3], cook, 3)
    FillRow(rows[4], fish, 4)
    FillRow(rows[5], faid, 5)
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

local function DressUnlearn(card, content, y, spec)
    local button = card.UnlearnButton
    if not button then return end
    -- Just left of the bar's end cap, level with the bar.
    ns.SetPointOnce(button, "CENTER", content, "TOPLEFT", spec.rowX + spec.textX - 15, y - 76)
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
    local spec = Spec()
    for i = 1, 2 do
        local card = content["PrimaryProfession" .. i]
        if card then
            local y = spec.rowY[i]
            card:SetSize(170, PRIMARY_H)
            ns.SetPointOnce(card, "TOPLEFT", content, "TOPLEFT", spec.rowX + spec.spellX - CLIENT_BUTTON_X, y - 5)
            FadeCard(card)
            DressSpellButton(card.SpellButton1)
            DressSpellButton(card.SpellButton2)
            DressUnlearn(card, content, y, spec)
        end
    end
    for i = 1, 3 do
        local card = content["SecondaryProfession" .. i]
        if card then
            card:SetSize(spec.rowW, SECONDARY_H)
            ns.SetPointOnce(card, "TOPLEFT", content, "TOPLEFT", spec.rowX, spec.rowY[2 + i])
            FadeCard(card)
            -- Small page: the first spell with its name plate after the bar, any more as icons to its left.
            local previous
            for n = 1, 4 do
                local button = card["SpellButton" .. n]
                if button then
                    DressSpellButton(button)
                    local named = spec.plates or n == 1
                    if plates[button] then plates[button]:SetShown(named) end
                    ns.SetAlphaIf(button.spellString, named and 1 or 0)
                    ns.SetAlphaIf(button.subSpellString, named and 1 or 0)
                    button:ClearAllPoints()
                    if not spec.plates then
                        if previous then
                            button:SetPoint("TOPRIGHT", previous, "TOPLEFT", -4, 0)
                        else
                            button:SetPoint("TOPLEFT", card, "TOPLEFT", spec.iconsX, -6)
                        end
                    elseif previous then
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
    rows.small = {}
    -- Clipped to the window's inside: the page stands lower than the window, and the art ran past its foot.
    local clip = ns.NewFrame("Frame", nil, page)
    clip:SetPoint("TOPLEFT", ProfessionsFrame, "TOPLEFT", 4, -20)
    clip:SetPoint("BOTTOMRIGHT", ProfessionsFrame, "BOTTOMRIGHT", -4, 4)
    clip:SetClipsChildren(true)
    clip:SetFrameLevel(page:GetFrameLevel())
    rows.clip = clip
    local function Piece(band, u0, u1, x)
        local tex = clip:CreateTexture(nil, "BACKGROUND", nil, 2)
        if not ns.SetTex(tex, "professionsBookLeft") then tex:SetTexture(PAGE_LEFT) end
        tex:SetTexCoord(u0 / 512, u1 / 512, band[1] / 512, band[2] / 512)
        tex:SetPoint("TOPLEFT", page, "TOPLEFT", x, -band[3])
        tex:SetSize(u1 - u0, band[2] - band[1])
        rows.small[#rows.small + 1] = tex
    end
    local artEnd = SMALL_ART_U + SMALL_ART_W
    for _, band in ipairs(SMALL_BANDS) do
        Piece(band, SMALL_ART_U + PULL, artEnd + PULL, SMALL_ART_X)
    end
    for i = 1, 2 do rows[i] = NewRow(content, true, i) end
    for i = 1, 3 do rows[2 + i] = NewRow(content, false, 2 + i) end
    T.built = true
    T.Lay()
    return true
end

-- Rows and art for the page size; the cards (casting buttons) follow in PlaceCards, out of combat.
function T.Lay()
    local content = Content()
    if not T.built or not content then return end
    local spec = Spec()
    for i = 1, 5 do LayRow(rows[i], content, spec) end
    if T.shown ~= nil then T.ShowOurs(T.shown) end
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
    T.shown = on
    local big = T.Big()
    -- The small page's art inside the window's metal: the chrome's backing marks where the rails start.
    local fcui = ProfessionsFrame and ProfessionsFrame.fcui
    local backing = fcui and fcui.backing
    if backing and rows.clipOn ~= backing then
        rows.clipOn = backing
        rows.clip:ClearAllPoints()
        rows.clip:SetAllPoints(backing)
    end
    for _, tex in ipairs(rows.art) do SetShownIf(tex, on and big) end
    for _, tex in ipairs(rows.small) do SetShownIf(tex, on and not big) end
    for i = 1, 5 do
        if rows[i] then SetShownIf(rows[i], on) end
    end
end
