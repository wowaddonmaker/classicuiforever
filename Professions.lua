local _, ns = ...

-- The professions overview as the old professions book: two parchment
-- pages, each primary profession with its round emblem, its name in the
-- book's title face, its rank and the small green bar, its two spells on
-- their plates down the right; the secondary professions as three short
-- rows under them.
--
-- The page is the client's (ProfessionsFrame.BookPage) and so are the
-- spell buttons on it, which cast and so are the client's alone to make.
-- They stay where they are in the frame tree and are only stood in new
-- places. Everything else the client draws on its cards is faded out,
-- and the book's own lines are drawn by us from the same profession
-- data, on rows of our own that hold nothing of the client's.
--
-- The client puts a primary card's two spell buttons back at fixed
-- offsets from the card's bottom left corner every time it fills the
-- card, in a fight too, where nothing of ours may move them again. So
-- the buttons are never moved: the card itself is cut down to the
-- buttons' column and stood where the book wants that column, and the
-- client's offsets land where they should by themselves.

local active = false
local built = false

local SHEET = "Interface\\Spellbook\\ProfessionsBook"
local PAGE_LEFT = "Interface\\Spellbook\\Professions-Book-Left"
local PAGE_RIGHT = "Interface\\Spellbook\\Professions-Book-Right"
local BOOK_W, BOOK_H = 550, 525
-- The second profession's rank line, bar, unlearn button and spells sat
-- low on its band of the page's art: they are raised, the first's are not.
local SECOND_LIFT = { 0, 15 }

-- Rows, from the content frame's top left corner.
local ROW_X, ROW_W = 80, 437
local PRIMARY_H, SECONDARY_H = 100, 52
local PRIMARY_Y = { -62, -168 }
local SECONDARY_Y = { -282, -352, -422 }
-- Where the spell column starts on a row, and the offsets the client
-- gives a primary card's buttons from the card's bottom left.
local SPELL_X = 288
local CLIENT_BUTTON_X = 15

local rows = {}
local sizeWas

local function Page()
    return ProfessionsFrame and ProfessionsFrame.BookPage
end

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
    -- The old bar is still one of the client's templates; made from
    -- here it is a frame of ours.
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
    row:SetPoint("TOPLEFT", content, "TOPLEFT", ROW_X, y)
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
        row.rank:SetPoint("TOPLEFT", row, "TOPLEFT", 100, -56 + (lift or 0))
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

-- The title that goes with a skill's cap, as the old book worded it.
local function RankTitle(maxRank)
    local ranks = PROFESSION_RANKS
    if type(ranks) ~= "table" or not maxRank then return "" end
    local title = ""
    for _, entry in ipairs(ranks) do
        title = entry[2] or title
        if maxRank <= (entry[1] or 0) then break end
    end
    return title or ""
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
        -- Past the icon's own border, and cut round to the ring's hole.
        if ns.RoundIcon then ns.RoundIcon(row.icon, 1) end
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

local function FillRows()
    if not built or not GetProfessions then return end
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

-- What the client draws on a card is faded, never hidden: it shows and
-- hides those pieces itself whenever it fills the card, and leaves
-- their fade alone.
local function FadeCard(card)
    for _, key in ipairs({ "Background", "ProfessionName", "specialization", "missingHeader", "missingText", "Rank", "icon", "IconBorder" }) do
        local region = card[key]
        if region and region.SetAlpha then region:SetAlpha(0) end
    end
    local bar = card.StatusBar
    if bar then
        bar:SetAlpha(0)
        if bar.EnableMouse then bar:EnableMouse(false) end
    end
end

local function DressSpellButton(button)
    if not button or button.fcuiPlate then return end
    local plate = button:CreateTexture(nil, "BACKGROUND")
    plate:SetTexture(SHEET)
    plate:SetTexCoord(0.00390625, 0.42578125, 0.14843750, 0.46875000)
    plate:SetSize(108, 41)
    plate:SetPoint("LEFT", button, "RIGHT", 1, 0)
    button.fcuiPlate = plate
    -- The square frame the client lays over the icon, and the rounding
    -- of the icon's corners, are this client's own look.
    if button.IconTextureOverlay then button.IconTextureOverlay:SetAlpha(0) end
    if button.IconTexture and button.OutlineMask and button.IconTexture.RemoveMaskTexture then
        pcall(button.IconTexture.RemoveMaskTexture, button.IconTexture, button.OutlineMask)
    end
end

local function DressUnlearn(card, content, y)
    local button = card.UnlearnButton
    if not button then return end
    button:ClearAllPoints()
    -- Just left of the bar's own end cap, level with the bar: it stood
    -- on the cap and a few pixels under the bar's line.
    button:SetPoint("CENTER", content, "TOPLEFT", ROW_X + 100 - 15, y - 76)
    if button.Icon then
        button.Icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        button.Icon:SetSize(16, 16)
        button.Icon:SetAlpha(0.75)
    end
    if button.Overlay then button.Overlay:SetAlpha(0) end
    local pad = card.GamepadUnlearnButton
    if pad then
        pad:ClearAllPoints()
        pad:SetPoint("RIGHT", button, "LEFT", -2, 0)
    end
end

-- The cards hold casting buttons, so they are the client's to move once
-- a fight is on: this is done out of one, and again after one if it
-- could not be.
local function PlaceCards()
    local content = Content()
    if not content or InCombatLockdown() then return false end
    for i = 1, 2 do
        local card = content["PrimaryProfession" .. i]
        if card then
            local y = PRIMARY_Y[i]
            card:ClearAllPoints()
            card:SetSize(170, PRIMARY_H)
            local lift = SECOND_LIFT[i] or 0
            card:SetPoint("TOPLEFT", content, "TOPLEFT", ROW_X + SPELL_X - CLIENT_BUTTON_X, y - 5 + lift)
            FadeCard(card)
            DressSpellButton(card.SpellButton1)
            DressSpellButton(card.SpellButton2)
            DressUnlearn(card, content, y + lift)
        end
    end
    for i = 1, 3 do
        local card = content["SecondaryProfession" .. i]
        if card then
            card:ClearAllPoints()
            card:SetSize(ROW_W, SECONDARY_H)
            card:SetPoint("TOPLEFT", content, "TOPLEFT", ROW_X, SECONDARY_Y[i])
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

local function Build()
    local page, content = Page(), Content()
    if built or not page or not content then return built end
    local left = page:CreateTexture(nil, "BACKGROUND", nil, 2)
    left:SetTexture(PAGE_LEFT)
    left:SetPoint("TOPLEFT", page, "TOPLEFT", 7, -25)
    local right = page:CreateTexture(nil, "BACKGROUND", nil, 2)
    right:SetTexture(PAGE_RIGHT)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    rows.art = { left, right }
    for i = 1, 2 do rows[i] = NewRow(content, true, PRIMARY_Y[i], SECOND_LIFT[i]) end
    for i = 1, 3 do rows[2 + i] = NewRow(content, false, SECONDARY_Y[i]) end
    built = true
    return true
end

-- A primary profession's two spells stand close, one on the other, as the
-- old book had them: 44 from one to the next, the pair in the middle of
-- its row. The client stands them 50 apart (at 10 and 60 from the card's
-- foot) and does so again every time it fills a card, so its two places
-- are looked for on the watcher's beat and changed for ours. They are
-- casting buttons: not during a fight.
local SPELL_LOW, SPELL_HIGH = 15, 56
local function TightenSpells()
    local content = Content()
    if not content or InCombatLockdown() then return end
    for i = 1, 2 do
        local card = content["PrimaryProfession" .. i]
        local first, second = card and card.SpellButton1, card and card.SpellButton2
        if first and second and first:IsShown() and second:IsShown() then
            for _, button in ipairs({ first, second }) do
                local point, rel, relPoint, x, y = button:GetPoint(1)
                if point == "BOTTOMLEFT" and y then
                    local want
                    if math.abs(y - 60) < 0.5 then want = SPELL_HIGH elseif math.abs(y - 10) < 0.5 then want = SPELL_LOW end
                    if want then button:SetPoint(point, rel, relPoint, x, want) end
                end
            end
        end
    end
end

-- The book is ours to show only once the client's cards have been stood
-- in the book's places, and that cannot be done during a fight. A book
-- first opened in one used to come up as both at once, our rows laid
-- over the client's cards. Until the cards are placed the book is left
-- entirely the client's.
local function ShowOurs(on)
    if not built then return end
    for _, tex in ipairs(rows.art or {}) do tex:SetShown(on) end
    for i = 1, 5 do
        if rows[i] then rows[i]:SetShown(on) end
    end
end

-- The window is the book's size while the book is up, and the client's
-- own again for a profession's crafting page. The window holds casting
-- buttons, so this too waits out a fight.
-- The client's panel manager places this window, and scales it to fit
-- the screen, from a width and a height it keeps for it: the client's own
-- 750 wide, and whatever height the window had when it last looked. It
-- looks again every time a profession tab is pressed. Resized from here
-- behind its back, the window was placed for one size on opening and for
-- another after a tab, and stood in a different spot each time. So the
-- manager is told the size we gave, and asked to place the window anew.
local fitted
local function TellManager(frame, width, height)
    local key = tostring(width) .. "x" .. tostring(height)
    if fitted == key then return end
    fitted = key
    if not sizeWas.attrs then
        sizeWas.attrs = { frame:GetAttribute("UIPanelLayout-width"), frame:GetAttribute("UIPanelLayout-height") }
    end
    frame:SetAttribute("UIPanelLayout-width", width or sizeWas.attrs[1])
    frame:SetAttribute("UIPanelLayout-height", height or sizeWas.attrs[2])
    if frame:IsShown() and UpdateUIPanelPositions then pcall(UpdateUIPanelPositions, frame) end
end

local function FitWindow(width, height)
    local frame = ProfessionsFrame
    if not frame or InCombatLockdown() then return false end
    if width then
        if not sizeWas then sizeWas = { frame:GetWidth(), frame:GetHeight() } end
        if math.abs(frame:GetWidth() - width) > 0.5 or math.abs(frame:GetHeight() - height) > 0.5 then
            frame:SetSize(width, height)
        end
        TellManager(frame, width, height)
    elseif sizeWas then
        if math.abs(frame:GetHeight() - sizeWas[2]) > 0.5 then frame:SetHeight(sizeWas[2]) end
        if frame:GetWidth() < sizeWas[1] - 0.5 then frame:SetWidth(sizeWas[1]) end
        TellManager(frame, nil, nil)
    end
    return true
end

-- The side tabs' icons fill their tabs. The client sees to that each
-- time it marks a tab as picked, and a window turned to the book from
-- here, by the pieces alone, is never marked by the client at all: the
-- icons stayed the small size the tabs are made with. The same numbers
-- as the client's own, put on the textures directly.
local function FillTabIcons()
    local frame = ProfessionsFrame
    if not frame then return end
    local function Fill(tab)
        local icon = tab and tab.Icon
        if not icon then return end
        local extent = tab.interiorExtent or 50
        if math.abs((icon:GetWidth() or 0) - extent) > 0.5 then
            icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
            icon:SetSize(extent, extent)
        end
    end
    Fill(frame.ProfessionsOverviewTab)
    for _, tab in ipairs(frame.rightProfessionTabs or {}) do Fill(tab) end
end

-- The side tabs are put away until asked for, as the equipment manager
-- is on the character sheet: an arrow under the close button brings them
-- out and puts them back, and which it was is kept. They are the
-- client's, so they are not hidden (the client shows and hides them
-- itself each time the window opens) but made unseen and deaf.
local tabToggle
local function TabsOpen() return ns.db and ns.db.professionTabs and true or false end

local function SyncTabs()
    local frame = ProfessionsFrame
    if not frame then return end
    local open = TabsOpen()
    local function Set(tab)
        if not tab then return end
        local alpha = open and 1 or 0
        if math.abs((tab:GetAlpha() or 1) - alpha) > 0.01 then tab:SetAlpha(alpha) end
        if tab:IsMouseEnabled() ~= open then tab:EnableMouse(open) end
    end
    Set(frame.ProfessionsOverviewTab)
    for _, tab in ipairs(frame.rightProfessionTabs or {}) do Set(tab) end
    -- Level with the close button, which stands over everything in the
    -- window: the window's border alone is some hundreds of levels up,
    -- and the pages with it, and a button a few levels over the window
    -- itself lay under all of them, unseen.
    if tabToggle then
        local close = frame.CloseButton
        local level = math.min(10000, (close and close:GetFrameLevel() or (frame:GetFrameLevel() + 600)) + 1)
        if tabToggle:GetFrameLevel() ~= level then tabToggle:SetFrameLevel(level) end
    end
    if tabToggle and tabToggle.open ~= open then
        tabToggle.open = open
        local name = open and "PrevPage" or "NextPage"
        tabToggle:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. name .. "-Up")
        tabToggle:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. name .. "-Down")
    end
end

local function TabToggle()
    local frame = ProfessionsFrame
    if tabToggle or not frame then return end
    tabToggle = CreateFrame("Button", "ClassicUIForeverProfessionTabsToggle", frame)
    tabToggle:SetSize(24, 24)
    -- Right of the rank bar in a profession, the top of the right page in
    -- the book: under the close button and a little in from it.
    tabToggle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -15, -28)
    tabToggle:SetFrameLevel(frame:GetFrameLevel() + 40)
    tabToggle:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    tabToggle:SetScript("OnClick", function()
        ns.db.professionTabs = not TabsOpen()
        if ns.MirrorSave then ns.MirrorSave() end
        SyncTabs()
    end)
    tabToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(TRADE_SKILLS or "Professions")
        GameTooltip:Show()
    end)
    tabToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- The book put back, by the pieces alone: nothing of the window's own is
-- called, so nothing of it is left marked as ours.
local function BackToBook()
    local frame, page = ProfessionsFrame, Page()
    if not frame or not page or InCombatLockdown() then return false end
    page:Show()
    if frame.CraftingPage then frame.CraftingPage:Hide() end
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    if title and TRADE_SKILLS then title:SetText(TRADE_SKILLS) end
    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    if portrait then portrait:SetTexture("Interface/ICONS/INV_SideTab_Professions_c60") end
    for _, tab in ipairs(frame.rightProfessionTabs or {}) do
        if tab.SelectedTexture then tab.SelectedTexture:Hide() end
    end
    local overview = frame.ProfessionsOverviewTab
    if overview and overview.SelectedTexture then overview.SelectedTexture:Show() end
    return true
end

local function NotInAFight()
    if UIErrorsFrame and ERR_NOT_IN_COMBAT then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1) end
end

-- The spellbook's tabs at the foot of the book, in the same places they
-- have on the spellbook, so the two turn into each other as the old
-- book's pages did. They belong to the book's page and go with it: a
-- profession's own window has none. Both windows are the client's to
-- show and hide during a fight, so the turn waits for the fight's end.
local bookTabs
local function BookTabs()
    local frame, page = ProfessionsFrame, Page()
    if not frame or not page or not ns.NewBookTab then return end
    local on = ns.SpellBookActive and ns.SpellBookActive() and true or false
    if not bookTabs then
        if not on then return end
        bookTabs = {}
        for i = 1, 3 do bookTabs[i] = ns.NewBookTab(page, i, bookTabs[i - 1]) end
        bookTabs[1]:ClearAllPoints()
        bookTabs[1]:SetPoint("CENTER", frame, "BOTTOMLEFT", 70, -13)
        bookTabs[1]:SetText(SPELLBOOK or "Spellbook")
        bookTabs[2]:SetText(TRADE_SKILLS or "Professions")
        bookTabs[2]:SetEnabled(false)
        for i, tab in ipairs(bookTabs) do
            tab:SetScript("OnClick", function()
                if i == 2 then return end
                if InCombatLockdown() then NotInAFight() return end
                PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
                HideUIPanel(frame)
                ns.ShowSpellBookBank(i == 3)
            end)
        end
    end
    local pet = on and ns.SpellBookPetTitle and ns.SpellBookPetTitle() or nil
    if pet and bookTabs[3]:GetText() ~= pet then bookTabs[3]:SetText(pet) end
    bookTabs[1]:SetShown(on)
    bookTabs[2]:SetShown(on)
    bookTabs[3]:SetShown(on and pet ~= nil)
end

-- The other way: the book turned to a profession's page, by the pieces
-- alone. The client does this itself only when the profession opened is
-- a different one from the last. Open First Aid, shut the window (which
-- is then turned back to the book, above), open First Aid again: to the
-- client nothing has changed, it turns no page, and the book came up
-- where the profession was asked for.
local function ToCraft()
    local frame, page = ProfessionsFrame, Page()
    local crafting = frame and frame.CraftingPage
    if not frame or not page or not crafting or InCombatLockdown() then return false end
    if not page:IsShown() and crafting:IsShown() then return true end
    page:Hide()
    crafting:Show()
    local info = C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    local id = info and info.professionID
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    if title and info and info.professionName and info.professionName ~= "" then title:SetText(info.professionName) end
    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    if portrait and id and C_TradeSkillUI.GetTradeSkillTexture then
        local icon = C_TradeSkillUI.GetTradeSkillTexture(id)
        if icon then portrait:SetTexture(icon) end
    end
    local overview = frame.ProfessionsOverviewTab
    if overview and overview.SelectedTexture then overview.SelectedTexture:Hide() end
    for _, tab in ipairs(frame.rightProfessionTabs or {}) do
        if tab.SelectedTexture then tab.SelectedTexture:SetShown(id ~= nil and tab.skillLine == id) end
    end
    return true
end

-- The client's profession tabs each ask to be told when the window
-- shows, and each then casts its profession: two professions, two casts,
-- two trade skills opened in the instant the book comes up, and the book
-- turned to a crafting page by the last of them. Out of a fight the book
-- can be put back; during one it cannot, and the window came up on a
-- profession, the book's size, with every tab lit. The tabs are taken
-- off that list. What the casts were for, bringing a profession's page
-- back to life when the window reopens on it, is not needed here: a shut
-- window is turned back to the book (below), and a profession opened
-- from its spell or its tab opens its own trade skill as it always did.
local tabsQuieted = false
local function QuietTabs()
    local frame = ProfessionsFrame
    if tabsQuieted or not frame or not (EventRegistry and EventRegistry.UnregisterCallback) then return end
    local tabs = {}
    for _, tab in ipairs(frame.rightProfessionTabs or {}) do tabs[#tabs + 1] = tab end
    if frame.ProfessionsOverviewTab then tabs[#tabs + 1] = frame.ProfessionsOverviewTab end
    if #tabs == 0 then return end
    tabsQuieted = true
    for _, tab in ipairs(tabs) do
        pcall(EventRegistry.UnregisterCallback, EventRegistry, "ProfessionsFrame.Show", tab)
    end
    ns.Persist("professions: " .. #tabs .. " tabs taken off the show list")
end

-- The book opened from a button of ours (the spellbook's tab). Through
-- the client's own panel call, which shows the window in the client's
-- name and not the addon's; that call turns an addon away in a fight.
function ns.OpenProfessionsBook()
    if InCombatLockdown() then NotInAFight() return false end
    if not ProfessionsFrame and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_ProfessionsBook")
        pcall(C_AddOns.LoadAddOn, "Blizzard_Professions")
    end
    local frame = ProfessionsFrame
    if not frame then return false end
    if active then QuietTabs() end
    BackToBook()
    if not frame:IsShown() then ShowUIPanel(frame) end
    return true
end

-- Watched from a frame of our own, never hooked into the client's page.
local watch
local function StartWatch()
    if watch then return end
    watch = CreateFrame("Frame")
    watch:RegisterEvent("SKILL_LINES_CHANGED")
    watch:RegisterEvent("SPELLS_CHANGED")
    watch:RegisterEvent("PLAYER_REGEN_ENABLED")
    watch:RegisterEvent("TRADE_SKILL_SHOW")
    -- The window's own piece, loaded by the client because the window was
    -- asked for before anything here could load it (a session begun in a
    -- fight): the tabs are taken off the show list in the instant the
    -- piece is in, which is before the client goes on to show the window.
    -- Nothing in that needs the fight to be over.
    watch:RegisterEvent("ADDON_LOADED")
    -- Opened from its micro button or its key, the window comes up on the
    -- book and then, in the same instant, turns to a profession by
    -- itself: every profession tab of the client's casts its profession
    -- as the window shows, each cast opens that trade skill, and an
    -- opened trade skill turns the book to its crafting page. (Until the
    -- sessions were kept clean of our layout writes the client refused
    -- those casts, and the book stayed.) A trade skill that opens while
    -- the window is only just up, from the book, with no tab pressed, is
    -- that, and the book is put back. One opened while the window was
    -- still shut is the player's own cast, and is left to show.
    watch:SetScript("OnEvent", function(self, event)
        if event == "ADDON_LOADED" then
            if active and ProfessionsFrame then QuietTabs() end
            return
        end
        if event == "TRADE_SKILL_SHOW" then
            local frame = ProfessionsFrame
            local now = GetTime()
            -- With the tabs off the show list every trade skill that
            -- opens is one the player asked for: a profession on an
            -- action bar, a plate in the book, a tab. Its page is wanted.
            -- (Only a window the client showed before the tabs could be
            -- quieted still casts by itself, and is put back on the book.)
            if not tabsQuieted and frame and frame:IsShown() and active and self.bookWhenShut
                and now - (self.shutAt or 0) < 0.5 then
                self.restoreBook = true
            else
                self.ownCastAt = now
                self.wantCraft = now
                -- Turned, sized and dressed here and now, inside the
                -- event, not at the watcher's next beat: the window is
                -- shown in this same instant, and for the tenth of a
                -- second until that beat it stood there as the book.
                if active and frame and ToCraft() then
                    local tick = self:GetScript("OnUpdate")
                    if tick then
                        self.since = 1
                        tick(self, 0)
                    end
                end
            end
        end
        self.dirty = true
    end)
    local placed = false
    watch:SetScript("OnUpdate", function(self, elapsed)
        -- Every frame: whether the window is shut, and on which face.
        local shut = ProfessionsFrame and not ProfessionsFrame:IsShown()
        if shut then
            local book = Page()
            self.shutAt = GetTime()
            -- A window never yet opened opens on the book, whatever its
            -- pages say before then (the book's page starts out hidden).
            local castNow = (GetTime() - (self.ownCastAt or 0)) < 3
            self.bookWhenShut = (book and book:IsShown() or (not self.everShown and not castNow)) and true or false
            -- Shut on a profession's page, it is turned back to the book,
            -- so the micro button and the key always open the book. A
            -- profession is opened from its spell or its tab.
            -- Before its first opening as well. The window's pages start
            -- out with the crafting page up and the book hidden, and the
            -- client only turns to the book when its button finds no
            -- window yet and has to load one. Loaded ahead of time from
            -- here, the window was simply shown as it stood: a crafting
            -- page with no trade skill open, in the book's size.
            -- Not in the moments after a trade skill has opened with the
            -- window still shut: that is the player's own cast (a
            -- profession on an action bar, a spell in the book), the
            -- client has just turned the window to that profession, and
            -- it shows the window a beat later. Turned back to the book
            -- in that beat, the window opened on the book and the cast
            -- profession never showed.
            local ownCast = (GetTime() - (self.ownCastAt or 0)) < 3
            if active and book and not book:IsShown() and not InCombatLockdown() and not ownCast then
                if BackToBook() then
                    self.bookWhenShut = true
                    ns.Persist("professions: shut window turned to the book")
                end
            end
        elseif ProfessionsFrame then
            if not self.everShown or self.wasShut then
                ns.Persist(string.format("professions: shown, book %s, %dx%d, placed %s, combat %s", tostring(Page() and Page():IsShown()),
                    ProfessionsFrame:GetWidth() or 0, ProfessionsFrame:GetHeight() or 0, tostring(self.placedNow), tostring(InCombatLockdown())))
            end
            self.everShown = true
            self.ownCastAt = nil
        end
        -- The frame the window comes up in gets the full pass, not the
        -- next tenth of a second's: ours is laid over it before it is drawn.
        if self.wasShut and not shut then self.since = 1 end
        self.wasShut = shut and true or false
        if self.restoreBook and BackToBook() then self.restoreBook = false end
        -- The page of a profession just asked for, turned to if the
        -- client has not turned to it.
        if self.wantCraft then
            if GetTime() - self.wantCraft > 3 then
                self.wantCraft = nil
            elseif active and ProfessionsFrame and not self.restoreBook and ToCraft() then
                if ProfessionsFrame:IsShown() then self.wantCraft = nil end
            end
        end
        self.since = (self.since or 0) + elapsed
        if self.since < 0.1 then return end
        self.since = 0
        -- The professions window is a piece the client loads the first
        -- time it is opened. Opened for the first time during a fight,
        -- none of the placing below could be done and it came up as the
        -- client's own. So the piece is loaded from here, once, a few
        -- seconds into the session and out of a fight, and everything is
        -- in place before any fight can find it otherwise.
        if not ProfessionsFrame and not self.loadTried and not InCombatLockdown()
            and (active or (ns.TradeSkillActive and ns.TradeSkillActive())) then
            -- At the first chance there is, with no wait: a session that
            -- begins in a fight has only its first moments, before the
            -- fight is counted, in which any of this can be done.
            if C_AddOns and C_AddOns.LoadAddOn then
                self.loadTried = true
                local okBook, book = pcall(C_AddOns.LoadAddOn, "Blizzard_ProfessionsBook")
                local okMain, main = pcall(C_AddOns.LoadAddOn, "Blizzard_Professions")
                ns.Persist(string.format("professions: early load book %s/%s main %s/%s frame %s", tostring(okBook),
                    tostring(book), tostring(okMain), tostring(main), tostring(ProfessionsFrame ~= nil)))
            end
        end
        local frame = ProfessionsFrame
        local page = Page()
        if not frame or not page then return end
        if active then
            QuietTabs()
            FillTabIcons()
        end
        TabToggle()
        SyncTabs()
        BookTabs()
        -- Which of the window's two faces is up, and the size that face
        -- has in the old interface: the book's, a trade skill window's,
        -- or, with neither of ours on, the client's own.
        local bookUp = active and page:IsVisible() and true or false
        local crafting = frame.CraftingPage
        local tradeOn = ns.TradeSkillActive and ns.TradeSkillActive()
        local craftUp = not bookUp and tradeOn and crafting and crafting:IsVisible() and true or false
        if bookUp then
            FitWindow(BOOK_W, BOOK_H)
        elseif craftUp then
            FitWindow(ns.TradeSkillWindowSize())
        elseif frame:IsVisible() then
            FitWindow(nil)
        elseif self.bookWhenShut then
            -- Shut, and the face it will open on is known. It is given
            -- that face's size now: opened during a fight it cannot be
            -- resized, and the book came up spilling out of a window
            -- still the size of a trade skill's.
            if active then FitWindow(BOOK_W, BOOK_H) end
        elseif tradeOn then
            FitWindow(ns.TradeSkillWindowSize())
        end
        if ns.ShowTradeSkill then ns.ShowTradeSkill(craftUp) end
        -- The book is built and its cards placed as soon as the window
        -- exists, open or not, for the same reason: none of it can be
        -- done once a fight is on.
        if active then
            if not built then Build() end
            if built and (self.dirty or not placed) then
                local was = placed
                placed = PlaceCards() or placed
                if placed ~= was then ns.Persist("professions: cards placed, combat " .. tostring(InCombatLockdown())) end
                FillRows()
                self.dirty = false
            end
            self.placedNow = placed
            ShowOurs(placed)
            if placed then TightenSpells() end
        end
    end)
end
ns.StartProfessionsWatch = StartWatch

local function Apply()
    active = true
    StartWatch()
    -- One pass now, not a tenth of a second on.
    -- Three, back to back: the first loads the window, the second turns
    -- it to the book and sizes it, the third sees it settled.
    local tick = watch and watch:GetScript("OnUpdate")
    if tick then
        for _ = 1, 3 do
            watch.since = 1
            tick(watch, 0)
        end
        watch.since = 1
        ns.Persist(string.format("professions: first pass, fight %s, window %s", tostring(InCombatLockdown()), tostring(ProfessionsFrame ~= nil)))
    end
end

local function Restore()
    if not active then return end
    active = false
    ns.needsReload = true
end

ns.RegisterModule("professionsBook", { apply = Apply, restore = Restore })
