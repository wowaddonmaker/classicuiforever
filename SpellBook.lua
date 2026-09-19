local _, ns = ...

-- The 1.x spellbook: the four-piece parchment book, twelve spells a page in
-- two columns with the name and rank beside each icon, school tabs down the
-- right edge, page arrows at the bottom and the Spellbook and pet tabs along
-- the bottom edge. Geometry follows Blizzard's Classic Era SpellBookFrame;
-- the data comes from C_SpellBook and the buttons are secure so clicks cast.
-- The window replaces the modern one whenever the spellbook is asked for
-- (micro button, keybind, /spellbook); talents still open Blizzard's frame.

local SPELLS_PER_PAGE = 12
local MAX_SKILL_TABS = 8
local BOOK_W, BOOK_H = 384, 512
local BUTTON_SIZE, COLUMN_X, ROW_GAP = 37, 157, 14
local FIRST_X, FIRST_Y = 34, -85

local BANK_PLAYER = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
local BANK_PET = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet or 1
local ITEM_FUTURE = Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell
local ITEM_FLYOUT = Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

local active = false
local book
local state = {
    bank = BANK_PLAYER,
    line = 1,           -- selected skill line index (player bank)
    pages = {},         -- current page per skill line, plus pages.pet
    slots = {},         -- spell book slot indices for the selected tab, future spells dropped
    attributesDirty = false,
    search = "",        -- text in the search box; while set, the slots come from every tab
}

local function CurrentPageKey()
    if state.search ~= "" then return "search" end
    return state.bank == BANK_PET and "pet" or state.line
end

local function CurrentPage()
    return state.pages[CurrentPageKey()] or 1
end

local function SetPage(page)
    state.pages[CurrentPageKey()] = page
end

local function PetSpellCount()
    local ok, count, token = pcall(C_SpellBook.HasPetSpells)
    if not ok or not count or IsSecret(count) then return 0 end
    return count, token
end

-- Whether a spell book item's name or rank line holds the search words.
local function SpellMatches(index, bank, query)
    local ok, name, sub = pcall(C_SpellBook.GetSpellBookItemName, index, bank)
    if not ok or type(name) ~= "string" or IsSecret(name) then return false end
    if name:lower():find(query, 1, true) then return true end
    return type(sub) == "string" and not IsSecret(sub) and sub:lower():find(query, 1, true) ~= nil
end

-- The slots shown on the selected tab: every known item of the skill line
-- in order, skipping spells the character has not learned yet (1.x never
-- listed those). With text in the search box, every known spell of every
-- tab whose name holds it, in tab order.
local function CollectSlots()
    local slots = state.slots
    wipe(slots)
    local query = state.search:lower()
    if query ~= "" then
        if state.bank == BANK_PET then
            local count = PetSpellCount()
            for i = 1, count do
                if SpellMatches(i, BANK_PET, query) then slots[#slots + 1] = i end
            end
            return
        end
        local n = C_SpellBook.GetNumSpellBookSkillLines() or 0
        for line = 1, n do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if info and not info.shouldHide and (info.offSpecID or 0) == 0 then
                local first = (info.itemIndexOffset or 0) + 1
                local last = (info.itemIndexOffset or 0) + (info.numSpellBookItems or 0)
                for i = first, last do
                    local kind = C_SpellBook.GetSpellBookItemType(i, BANK_PLAYER)
                    if kind ~= ITEM_FUTURE and kind ~= ITEM_FLYOUT and SpellMatches(i, BANK_PLAYER, query) then
                        slots[#slots + 1] = i
                    end
                end
            end
        end
        return
    end
    if state.bank == BANK_PET then
        local count = PetSpellCount()
        for i = 1, count do slots[#slots + 1] = i end
        return
    end
    local info = C_SpellBook.GetSpellBookSkillLineInfo(state.line)
    if not info then return end
    local first = (info.itemIndexOffset or 0) + 1
    local last = (info.itemIndexOffset or 0) + (info.numSpellBookItems or 0)
    for i = first, last do
        local itemType = C_SpellBook.GetSpellBookItemType(i, BANK_PLAYER)
        -- A flyout is a modern grouping, not a spell: the client's own
        -- book leaves it out and 1.x never had one. Its spells are in
        -- the book on their own.
        if itemType ~= ITEM_FUTURE and itemType ~= ITEM_FLYOUT then slots[#slots + 1] = i end
    end
end

local function PageCount()
    return math.max(1, math.ceil(#state.slots / SPELLS_PER_PAGE))
end

---------------------------------------------------------------------------
-- Spell buttons
---------------------------------------------------------------------------

local SUB_FONT = _G.SubSpellFont and "SubSpellFont" or "GameFontHighlightSmall"

local function ClearAction(btn)
    if InCombatLockdown() then
        state.attributesDirty = true
        return
    end
    btn:SetAttribute("type1", nil)
    btn:SetAttribute("spell", nil)
    btn:SetAttribute("flyoutDirection", nil)
end

local function SetAction(btn, info)
    if InCombatLockdown() then
        state.attributesDirty = true
        return
    end
    if info.itemType == ITEM_FLYOUT then
        ClearAction(btn)
    elseif info.isPassive or not (info.spellID or info.actionID) then
        ClearAction(btn)
    else
        btn:SetAttribute("type1", "spell")
        btn:SetAttribute("spell", info.spellID or info.actionID)
        btn:SetAttribute("flyoutDirection", nil)
    end
end

local function UpdateCooldown(btn)
    local cd = btn.cooldown
    if not btn.slot then cd:Clear(); return end
    local ok, info = pcall(C_SpellBook.GetSpellBookItemCooldown, btn.slot, state.bank)
    if not ok or not info then cd:Clear(); return end
    local enabled = info.isEnabled
    if not IsSecret(enabled) and enabled == false then cd:Clear(); return end
    -- The client hands these numbers out in a fight but will not take
    -- them back from an addon, and offering them anyway is an error on
    -- the player's screen. The swirl waits for the numbers to be plain
    -- again, which is the moment the fight ends.
    if IsSecret(info.startTime) or IsSecret(info.duration) or IsSecret(info.modRate) then
        cd:Clear()
        return
    end
    cd:SetCooldown(info.startTime, info.duration, info.modRate)
end

local function UpdateButton(btn)
    local page = CurrentPage()
    local slot = state.slots[(page - 1) * SPELLS_PER_PAGE + btn:GetID()]
    local info = slot and C_SpellBook.GetSpellBookItemInfo(slot, state.bank)
    btn.slot = slot
    if not info then
        btn.slot = nil
        btn.isPassive = nil
        btn.Icon:Hide()
        btn.SpellName:Hide()
        btn.SpellSubName:Hide()
        btn.cooldown:Clear()
        btn.checkedTex:Hide()
        -- Enabling and disabling a casting button is the client's call
        -- to refuse during a fight; the button keeps the state it had
        -- and takes the new one when the fight ends.
        if not InCombatLockdown() then btn:Disable() end
        btn.normal:SetVertexColor(1, 1, 1)
        ClearAction(btn)
        return
    end
    if not InCombatLockdown() then btn:Enable() end
    btn.isPassive = info.isPassive
    btn.Icon:SetTexture(info.iconID)
    btn.Icon:SetDesaturated(info.isOffSpec and true or false)
    btn.Icon:Show()
    btn.SpellName:SetText(info.name)
    local sub = info.subName or ""
    if sub == "" and info.isPassive then sub = SPELL_PASSIVE end
    btn.SpellSubName:SetText(sub)
    btn.SpellName:ClearAllPoints()
    btn.SpellName:SetPoint("LEFT", btn, "RIGHT", 5, sub == "" and 1 or 3)
    btn.SpellName:Show()
    btn.SpellSubName:Show()
    if info.isPassive then
        btn.normal:SetVertexColor(0, 0, 0)
        btn.SpellName:SetTextColor(PASSIVE_SPELL_FONT_COLOR:GetRGB())
    else
        btn.normal:SetVertexColor(1, 1, 1)
        btn.SpellName:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
    end
    btn.checkedTex:Hide()
    SetAction(btn, info)
    UpdateCooldown(btn)
end

local function Button_OnEnter(self)
    if not self.slot then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetSpellBookItem(self.slot, state.bank)
    GameTooltip:Show()
end

local function Button_OnDragStart(self)
    if not self.slot or self.isPassive or InCombatLockdown() then return end
    C_SpellBook.PickupSpellBookItem(self.slot, state.bank)
end

local function Button_PostClick(self)
    if not self.slot then return end
    if IsModifiedClick("CHATLINK") then
        local ok, link = pcall(C_SpellBook.GetSpellBookItemLink, self.slot, state.bank)
        if ok and link and not IsSecret(link) then ChatEdit_InsertLink(link) end
    end
end

-- A spell is two frames, not one. Everything you see, the slot, the
-- icon, the name and the cooldown, is a plain frame in the book. The
-- thing you click is a casting button on a clear layer above it, which
-- is the client's the moment it holds one. Keeping the two apart is
-- what lets the book itself open during a fight: a book with a casting
-- button inside it is a frame the client will not show there, which is
-- how the old single-frame version came to be refused.
local function CreateSpellButton(parent, id, clicks)
    local slot = CreateFrame("Frame", nil, parent)
    slot:SetID(id)
    slot:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    local column = id > 6 and 1 or 0
    local row = (id - 1) % 6
    slot:SetPoint("TOPLEFT", parent, "TOPLEFT", FIRST_X + column * COLUMN_X, FIRST_Y - row * (BUTTON_SIZE + ROW_GAP))

    local empty = slot:CreateTexture(nil, "BACKGROUND")
    ns.SetTex(empty, "sbEmptySlot")
    empty:SetSize(64, 64)
    empty:SetPoint("TOPLEFT", slot, "TOPLEFT", -3, 3)

    local icon = slot:CreateTexture(nil, "BORDER")
    icon:SetAllPoints(slot)
    icon:Hide()

    local normal = slot:CreateTexture(nil, "ARTWORK")
    ns.SetTex(normal, "slotNormal")
    normal:SetSize(64, 64)
    normal:SetPoint("CENTER", slot, "CENTER", 0, 0)

    local checked = slot:CreateTexture(nil, "OVERLAY")
    ns.SetTex(checked, "checked")
    checked:SetAllPoints(slot)
    checked:SetBlendMode("ADD")
    checked:Hide()

    local name = slot:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    name:SetWidth(103)
    name:SetJustifyH("LEFT")
    name:SetMaxLines(3)
    name:SetPoint("LEFT", slot, "RIGHT", 5, 3)

    local sub = slot:CreateFontString(nil, "ARTWORK", SUB_FONT)
    sub:SetSize(79, 18)
    sub:SetJustifyH("LEFT")
    sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)

    local cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
    cooldown:SetAllPoints(slot)

    -- The click target, on the layer above, over the slot it belongs to.
    local btn = CreateFrame("CheckButton", "ForeverClassicUISpellButton" .. id, clicks, "SecureActionButtonTemplate")
    btn:SetID(id)
    -- Placed against its own layer, by the slot's numbers, and never
    -- against the slot: a frame a casting button is anchored to is held
    -- by the client as if it were one, and the slot is part of the
    -- book. That tie is what kept a book built before a fight from
    -- being shown during it.
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    btn:SetPoint("TOPLEFT", clicks, "TOPLEFT", FIRST_X + column * COLUMN_X, FIRST_Y - row * (BUTTON_SIZE + ROW_GAP))
    btn.slotFrame = slot
    btn.EmptySlot = empty
    btn.Icon = icon
    btn.SpellName = name
    btn.SpellSubName = sub
    btn.cooldown = cooldown
    btn.normal = normal
    btn.checkedTex = checked

    ns.SetButtonTex(btn, "Pushed", "slotPushed")
    ns.SetButtonTex(btn, "Highlight", "highlight")
    btn:GetHighlightTexture():SetBlendMode("ADD")

    -- Secure buttons act on the press when the game key-down setting is
    -- on (the default now), on the release otherwise; both must arrive.
    btn:RegisterForClicks("AnyDown", "AnyUp")
    btn:RegisterForDrag("LeftButton")
    -- A spell in the book casts when the mouse lets go, never on the
    -- press: a press is also how a drag to the bars begins, and with
    -- the game's cast on key down setting the press cast the spell
    -- being picked up. The client reads this before that setting.
    btn:SetAttribute("useOnKeyDown", false)
    btn:SetAttribute("shift-type1", "")
    btn:SetScript("OnEnter", Button_OnEnter)
    btn:SetScript("OnLeave", GameTooltip_Hide)
    btn:SetScript("OnDragStart", Button_OnDragStart)
    btn:SetScript("PostClick", Button_PostClick)

    return btn
end

---------------------------------------------------------------------------
-- Skill line tabs (right edge) and book tabs (bottom edge)
---------------------------------------------------------------------------

local function SkillTab_OnClick(self)
    state.bank = BANK_PLAYER
    state.line = self.line
    PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
    book:Refresh()
end

local function SkillTab_OnEnter(self)
    if not self.tooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tooltip)
    GameTooltip:Show()
end

local function CreateSkillTab(parent, i, prev)
    local tab = CreateFrame("CheckButton", nil, parent)
    tab:SetSize(32, 32)
    if prev then
        tab:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -17)
    else
        tab:SetPoint("TOPLEFT", parent, "TOPRIGHT", -32, -65)
    end
    local plate = tab:CreateTexture(nil, "BACKGROUND")
    ns.SetTex(plate, "sbSkillTab")
    plate:SetSize(64, 64)
    plate:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 11)
    tab:SetNormalTexture("")
    ns.SetButtonTex(tab, "Highlight", "highlight")
    tab:GetHighlightTexture():SetBlendMode("ADD")
    ns.SetButtonTex(tab, "Checked", "checked")
    tab:GetCheckedTexture():SetBlendMode("ADD")
    tab:SetID(i)
    tab:SetScript("OnClick", SkillTab_OnClick)
    tab:SetScript("OnEnter", SkillTab_OnEnter)
    tab:SetScript("OnLeave", GameTooltip_Hide)
    tab:Hide()
    return tab
end

local function BookTab_OnClick(self)
    state.bank = self.bank
    PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
    book:Refresh()
end

local function CreateBookTab(parent, i, prev)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(128, 64)
    if prev then
        tab:SetPoint("LEFT", prev, "RIGHT", -20, 0)
    else
        tab:SetPoint("CENTER", parent, "BOTTOMLEFT", 79, 61)
    end
    tab.Text = tab:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    tab.Text:SetHeight(13)
    tab.Text:SetPoint("CENTER", tab, "CENTER", 0, 3)
    tab:SetFontString(tab.Text)
    tab:SetDisabledFontObject(GameFontHighlightSmall)
    ns.SetButtonTex(tab, "Normal", "sbTabUnselected")
    ns.SetButtonTex(tab, "Disabled", i == 3 and "sbTab3Selected" or "sbTab1Selected")
    ns.SetButtonTex(tab, "Highlight", "sbTabHighlight")
    tab:GetHighlightTexture():SetBlendMode("ADD")
    tab:SetScript("OnClick", BookTab_OnClick)
    tab:Hide()
    return tab
end

---------------------------------------------------------------------------
-- The book
---------------------------------------------------------------------------

local function Page_OnClick(self)
    local page = CurrentPage() + self.step
    if page < 1 or page > PageCount() then return end
    SetPage(page)
    PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
    book:Refresh()
end

local function CreatePageButton(parent, key, step, x)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(32, 32)
    btn:SetPoint("CENTER", parent, "BOTTOMLEFT", x, 105)
    ns.SetButtonTex(btn, "Normal", key .. "Up")
    ns.SetButtonTex(btn, "Pushed", key .. "Down")
    ns.SetButtonTex(btn, "Disabled", key .. "Disabled")
    ns.SetButtonTex(btn, "Highlight", "mouseHighlight")
    btn:GetHighlightTexture():SetBlendMode("ADD")
    btn.step = step
    btn:SetScript("OnClick", Page_OnClick)
    return btn
end

local function Book_OnMouseWheel(_, delta)
    Page_OnClick({ step = delta > 0 and -1 or 1 })
end

local function CreateBook()
    local f = CreateFrame("Frame", "ForeverClassicUISpellBook", UIParent)
    f:SetSize(BOOK_W, BOOK_H)
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:EnableMouseWheel(true)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
    f:Hide()
    -- Deliberately not one of the client's managed panels. A window in
    -- that system is the client's to show and hide, and it turns an addon
    -- away during a fight, which left the book stuck open there: shown
    -- once, then neither closing nor opening again. The classic quest log
    -- has never been in it, opens in a fight, and this book now matches.
    -- Escape and dragging are handled below, which is what the system
    -- was giving us.
    -- The old book did not move: it stood in the window place at the
    -- screen's left, under the player frame, and the classic quest log
    -- stands in the same spot.
    ns.RegisterClassicWindow(f)
    ns.db.spellBookPos = nil
    if GameMenuFrame then
        GameMenuFrame:HookScript("OnShow", function(menu)
            if f:IsShown() then
                f:Hide()
                HideUIPanel(menu)
            end
        end)
    end

    for _, piece in ipairs({
        { "sbTopLeft", 256, 256, "TOPLEFT" },
        { "sbTopRight", 128, 256, "TOPRIGHT" },
        { "sbBotLeft", 256, 256, "BOTTOMLEFT" },
        { "sbBotRight", 128, 256, "BOTTOMRIGHT" },
    }) do
        local tex = f:CreateTexture(nil, "BACKGROUND")
        ns.SetTex(tex, piece[1])
        tex:SetSize(piece[2], piece[3])
        tex:SetPoint(piece[4], f, piece[4], 0, 0)
    end

    local icon = f:CreateTexture(nil, "ARTWORK")
    ns.SetTex(icon, "sbIcon")
    icon:SetSize(58, 58)
    icon:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)

    f.Title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.Title:SetPoint("CENTER", f, "CENTER", 6, 230)
    f.Title:SetText(SPELLBOOK)

    f.PageText = f:CreateFontString(nil, "ARTWORK", "GameFontBlack")
    f.PageText:SetWidth(102)
    f.PageText:SetJustifyH("RIGHT")
    f.PageText:SetPoint("CENTER", f, "BOTTOMLEFT", 182, 105)

    f.PrevPage = CreatePageButton(f, "sbPrev", -1, 50)
    f.NextPage = CreatePageButton(f, "sbNext", 1, 314)

    f.Close = CreateFrame("Button", nil, f)
    f.Close:SetSize(32, 32)
    f.Close:SetPoint("CENTER", f, "TOPRIGHT", -44, -25)
    ns.SkinCloseButton(f.Close, true)
    f.Close:SetScript("OnClick", function() ns.HidePanel(f) end)

    -- A search box over the right page: type, and every known spell whose
    -- name holds the words is listed, across the tabs. The X clears it.
    local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    search:SetSize(130, 20)
    search:SetPoint("TOPRIGHT", f, "TOPRIGHT", -42, -52)
    search:SetAutoFocus(false)
    search:SetMaxLetters(40)
    local hint = search:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    hint:SetPoint("LEFT", search, "LEFT", 2, 0)
    hint:SetText(SEARCH or "Search")
    local clear = CreateFrame("Button", nil, search)
    clear:SetSize(17, 17)
    clear:SetPoint("RIGHT", search, "RIGHT", -3, 0)
    clear:SetNormalTexture("Interface\\FriendsFrame\\ClearBroadcastIcon")
    clear:SetHighlightTexture("Interface\\FriendsFrame\\ClearBroadcastIcon", "ADD")
    clear:GetNormalTexture():SetAlpha(0.6)
    clear:SetScript("OnClick", function() search:SetText("") search:ClearFocus() end)
    clear:Hide()
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        hint:SetShown(text == "")
        clear:SetShown(text ~= "")
        if text ~= state.search then
            state.search = text
            if f:IsShown() then f:Refresh() end
        end
    end)
    search:SetShown(ns.db.spellBookSearch ~= false)
    f.Search = search

    -- The casting buttons sit on their own layer over the book rather
    -- than inside it, so the book holds nothing of the client's and can
    -- be shown during a fight. The layer follows the book everywhere
    -- except into a fight, where showing it is refused; the book still
    -- opens, and its spells simply cannot be clicked until the fight is
    -- over, which is how the old book behaved anyway.
    local clicks = CreateFrame("Frame", "ForeverClassicUISpellBookClicks", UIParent)
    -- The book's own spot and size, said against the screen: tied to
    -- the book it would make the book the client's to show and hide.
    clicks:SetSize(BOOK_W, BOOK_H)
    clicks:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
    clicks:SetFrameStrata("HIGH")
    clicks:Hide()
    f.Clicks = clicks

    -- Whatever hides the book hides the layer with it: the escape key,
    -- the game menu, another window of ours opening. Otherwise the
    -- layer is left on screen with nothing drawn under it, and a click
    -- on empty ground would cast.
    f:HookScript("OnShow", function(self)
        local layer = self.Clicks
        if layer and not (InCombatLockdown() and layer:IsProtected()) then layer:Show() end
    end)
    f:HookScript("OnHide", function(self)
        local layer = self.Clicks
        if layer and not (InCombatLockdown() and layer:IsProtected()) then layer:Hide() end
    end)

    f.Buttons = {}
    for id = 1, SPELLS_PER_PAGE do
        f.Buttons[id] = CreateSpellButton(f, id, clicks)
    end

    f.SkillTabs = {}
    for i = 1, MAX_SKILL_TABS do
        f.SkillTabs[i] = CreateSkillTab(f, i, f.SkillTabs[i - 1])
    end

    f.BookTabs = {}
    for i = 1, 2 do
        f.BookTabs[i] = CreateBookTab(f, i, f.BookTabs[i - 1])
    end

    f:SetScript("OnMouseWheel", Book_OnMouseWheel)
    f:SetScript("OnShow", function(self)
        PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
        self:Refresh()
        ns.RefreshMicroButtons()
    end)
    f:SetScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE)
        ns.RefreshMicroButtons()
    end)
    if ns.MicroButtonFollows then
        for _, name in ipairs({ "SpellbookMicroButton", "PlayerSpellsMicroButton" }) do
            ns.MicroButtonFollows(_G[name], function() return f:IsShown() end)
        end
    end
    -- Event names differ between clients; a missing one is skipped.
    for _, event in ipairs({ "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE", "SPELL_UPDATE_COOLDOWN", "PLAYER_REGEN_ENABLED", "PET_BAR_UPDATE", "PLAYER_ENTERING_WORLD" }) do
        pcall(f.RegisterEvent, f, event)
    end
    pcall(f.RegisterUnitEvent, f, "UNIT_PET", "player")
    f:SetScript("OnEvent", function(self, event)
        -- A closed book still arms its buttons: what a spell button
        -- casts is set on it, and that cannot be set once a fight has
        -- started, so a book opened mid fight would hold dead buttons.
        if not self:IsShown() then
            if not InCombatLockdown() and (event == "PLAYER_REGEN_ENABLED" or event == "SPELLS_CHANGED"
                or event == "LEARNED_SPELL_IN_TAB" or event == "PLAYER_ENTERING_WORLD") then
                CollectSlots()
                for _, btn in ipairs(self.Buttons) do UpdateButton(btn) end
            end
            return
        end
        if event == "SPELL_UPDATE_COOLDOWN" then
            for _, btn in ipairs(self.Buttons) do UpdateCooldown(btn) end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if state.attributesDirty then
                state.attributesDirty = false
                self:Refresh()
            end
        else
            self:Refresh()
        end
    end)

    function f:UpdateSkillTabs()
        local shown = 0
        local selectedVisible = false
        local firstLine
        if state.bank == BANK_PLAYER then
            local n = C_SpellBook.GetNumSpellBookSkillLines() or 0
            for i = 1, n do
                local info = C_SpellBook.GetSpellBookSkillLineInfo(i)
                local offSpec = info and (info.offSpecID or 0) ~= 0
                if info and not info.shouldHide and not offSpec and shown < MAX_SKILL_TABS then
                    shown = shown + 1
                    local tab = self.SkillTabs[shown]
                    tab.line = i
                    tab.tooltip = info.name
                    tab:SetNormalTexture(info.iconID or "")
                    tab:SetChecked(state.line == i)
                    tab:Show()
                    firstLine = firstLine or i
                    if state.line == i then selectedVisible = true end
                end
            end
        end
        for i = shown + 1, MAX_SKILL_TABS do self.SkillTabs[i]:Hide() end
        if state.bank == BANK_PLAYER and not selectedVisible and firstLine then
            state.line = firstLine
            for i = 1, shown do self.SkillTabs[i]:SetChecked(self.SkillTabs[i].line == firstLine) end
        end
    end

    function f:UpdateBookTabs()
        local petCount, token = PetSpellCount()
        local tab1, tab2 = self.BookTabs[1], self.BookTabs[2]
        tab1.bank = BANK_PLAYER
        tab1:SetText(SPELLBOOK)
        tab1:Show()
        local petTitle
        if petCount > 0 then
            petTitle = (token and _G["PET_TYPE_" .. token]) or PET
            tab2.bank = BANK_PET
            tab2:SetText(petTitle)
            tab2:Show()
        else
            tab2:Hide()
            if state.bank == BANK_PET then state.bank = BANK_PLAYER end
        end
        tab1:SetEnabled(state.bank ~= BANK_PLAYER)
        tab2:SetEnabled(state.bank ~= BANK_PET)
        self.Title:SetText(state.bank == BANK_PET and petTitle or SPELLBOOK)
    end

    function f:UpdatePages()
        local pages = PageCount()
        local page = math.min(CurrentPage(), pages)
        SetPage(page)
        self.PageText:SetFormattedText(PAGE_NUMBER, page)
        self.PrevPage:SetEnabled(page > 1)
        self.NextPage:SetEnabled(page < pages)
    end

    function f:Refresh()
        if not active then return end
        self:UpdateBookTabs()
        self:UpdateSkillTabs()
        CollectSlots()
        self:UpdatePages()
        for _, btn in ipairs(self.Buttons) do UpdateButton(btn) end
    end

    return f
end

---------------------------------------------------------------------------
-- Opening: take over the spellbook entry points, leave talents alone
---------------------------------------------------------------------------

-- 1.x opened the book in a fight, and this client will not: the book
-- holds the buttons that cast, which are the client's to show and hide,
-- so the book is its to show and hide too. Asking for it in a fight is
-- refused and the player is told an addon was blocked. So the key that
-- opens the book carries a snippet the client runs itself (see the bind
-- button below), and these two do the ordinary out-of-combat work.
-- 1.x opened the book in a fight and so does this one. The client's
-- window manager refuses an addon there, by its own first line, but a
-- frame still shows itself, casting buttons inside it and all; only
-- that manager is closed to us, so the book goes up without it.
local wanted = false
local closedInFight = false
-- The click layer follows the book, and only out of a fight: it holds
-- casting buttons, so the client refuses to show it during one.
local function ShowClicks(on)
    local clicks = book and book.Clicks
    if not clicks then return end
    if InCombatLockdown() and clicks:IsProtected() then return end
    clicks:SetShown(on and book:IsShown())
end

local function Show()
    -- Building the book during a fight is allowed: its frames are ours
    -- and the spells written onto the casting layer are skipped there,
    -- to be written when the fight ends. So a book never opened before
    -- the fight still opens during it.
    if not book then book = CreateBook() end
    -- The client's talents window is left open if it is up. Closing it
    -- from here runs its closing code as ours, which writes the same
    -- note about the empty slots that is described at the foot of this
    -- file, with the same result.
    -- A book faded out during a fight comes back rather than opening.
    closedInFight = false
    book:SetAlpha(1)
    -- Nothing of the client's is inside the book, so a fight is no
    -- reason it cannot be shown. If this client ever says otherwise the
    -- open waits for the fight to end rather than printing a refusal.
    if InCombatLockdown() and not book:IsShown() and book:IsProtected() then
        wanted = true
        return
    end
    book:Show()
    ShowClicks(true)
    wanted = false
end

local function Hide()
    wanted = false
    if not book then return end
    ShowClicks(false)
    -- Where the client refuses to hide the book during a fight, it is
    -- faded out of the way instead and put away properly the moment the
    -- fight ends. Asking anyway would print a refusal at the player.
    if InCombatLockdown() and book:IsProtected() then
        closedInFight = true
        book:SetAlpha(0)
        return
    end
    closedInFight = false
    book:SetAlpha(1)
    book:Hide()
end

-- What the fight held back opens as soon as it is over.
local waiting = CreateFrame("Frame")
waiting:RegisterEvent("PLAYER_REGEN_ENABLED")
waiting:SetScript("OnEvent", function()
    if not active then return end
    -- What the fight held back: a close that could only fade, and the
    -- casting layer of a book left open.
    if closedInFight and book then
        closedInFight = false
        book:SetAlpha(1)
        book:Hide()
        ShowClicks(false)
        return
    end
    if wanted then
        Show()
    elseif book then
        -- The layer follows the book either way. A book closed during
        -- the fight left its layer up, since hiding that is refused
        -- there, and nothing took it down afterwards: its unseen
        -- buttons sat where the vendor window opens and answered the
        -- mouse with spell tooltips.
        ShowClicks(book:IsShown())
    end
end)

local function Toggle()
    if book and book:IsShown() and not closedInFight then
        Hide()
    else
        Show()
    end
end

local originals = {}

-- The client calls these from its own pass, and a window shown from
-- inside that pass is refused during a fight: the call began as the
-- client's and ours finished it. Stepping out to the next frame makes
-- it plainly ours, which the client allows for a window it does not own.
local function Step(fn)
    if InCombatLockdown() and C_Timer and C_Timer.After then
        C_Timer.After(0, fn)
    else
        fn()
    end
end

-- The client's own way in is taken over while the classic book is on,
-- and handed straight back when it is off. Leaving ours in the middle
-- of the client's call, even as a pass-through, makes everything the
-- client does after it ours, which is refused in a fight: pressing the
-- spellbook key there put a blocked action on screen for a window this
-- addon was no longer drawing.
local wrapped = {}
local function Wrap(key, replacement)
    if not PlayerSpellsUtil or type(PlayerSpellsUtil[key]) ~= "function" or originals[key] then return end
    local orig = PlayerSpellsUtil[key]
    originals[key] = orig
    wrapped[key] = function(...)
        local handled = replacement(...)
        if handled then return end
        return orig(...)
    end
end

-- Ours in the client's place while the book is on, the client's own
-- back in it while the book is off.
local function TakeOver(on)
    if not PlayerSpellsUtil then return end
    for key, orig in pairs(originals) do
        PlayerSpellsUtil[key] = on and wrapped[key] or orig
    end
end

-- The spellbook's micro button goes down TogglePlayerSpellsFrame, the
-- road that is left to the client (see Init). So the button itself is
-- given our click while the book is on, and its own back when it is off.
-- It is the spellbook's button alone; the talents button is not touched.
local microClick
local function TakeButton(on)
    local button = _G["SpellbookMicroButton"]
    if not button or not button.GetScript then return end
    if on then
        if microClick == nil then microClick = button:GetScript("OnClick") or false end
        button:SetScript("OnClick", function()
            if KeybindFrames_InQuickKeybindMode and KeybindFrames_InQuickKeybindMode() then return end
            Step(Toggle)
        end)
    elseif microClick then
        button:SetScript("OnClick", microClick)
    end
end

local BIND_NAME = "ForeverClassicUISpellBookBind"
local bindButton

-- The spellbook key goes to a button of ours. The client's own handler
-- for that key can refuse to open its window, and the old book had no
-- such rule; the binding is set out of combat and holds during a fight.
local boundKeys = {}
local function UpdateBinding()
    if not bindButton or InCombatLockdown() then return end
    ClearOverrideBindings(bindButton)
    wipe(boundKeys)
    if not active then return end
    -- The spellbook's own keys only. Talents are the client's window and
    -- its key stays its own; ours took it and opened the book instead.
    for _, binding in ipairs({ "TOGGLESPELLBOOK", "TOGGLEPLAYERSPELLS" }) do
        local key, second = GetBindingKey(binding)
        for _, k in ipairs({ key, second }) do
            if k then
                SetOverrideBindingClick(bindButton, true, k, BIND_NAME, "LeftButton")
                boundKeys[#boundKeys + 1] = binding .. "=" .. k
            end
        end
    end
end

-- What the debug print reports about opening the book in a fight.
function ns.SpellBookBindInfo()
    return string.format("keys %s; book built %s; book protected %s",
        (#boundKeys > 0 and table.concat(boundKeys, ", ") or "none"),
        tostring(book ~= nil),
        tostring(book and book.IsProtected and book:IsProtected()))
end


-- The book is built ahead of its first opening, out of a fight. Its
-- casting buttons are the client's kind, and ones made during a fight
-- come out refused: a book first asked for in the middle of one did not
-- open, while one opened once beforehand did. So it is made on the way
-- into the world, or as soon as a fight it missed that in has ended.
local function Prebuild()
    if book or not active or InCombatLockdown() then return end
    book = CreateBook()
    CollectSlots()
    for _, btn in ipairs(book.Buttons) do UpdateButton(btn) end
end

local function Init()
    bindButton = CreateFrame("Button", BIND_NAME, UIParent, "SecureActionButtonTemplate")
    bindButton:SetScript("OnClick", function()
        if active then Toggle() end
    end)
    bindButton:RegisterEvent("UPDATE_BINDINGS")
    bindButton:RegisterEvent("PLAYER_REGEN_ENABLED")
    bindButton:RegisterEvent("PLAYER_ENTERING_WORLD")
    bindButton:SetScript("OnEvent", function(_, event)
        UpdateBinding()
        if event ~= "UPDATE_BINDINGS" then ns.SafeCall(Prebuild) end
    end)
    Wrap("ToggleSpellBookFrame", function() Step(Toggle); return true end)
    Wrap("OpenToSpellBookTab", function() Step(Show); return true end)
    Wrap("OpenToSpellBookTabAtSpell", function() Step(Show); return true end)
    Wrap("OpenToSpellBookTabAtCategory", function() Step(Show); return true end)
    -- TogglePlayerSpellsFrame is deliberately not taken over. It is the
    -- one road every tab of the client's window goes down, talents
    -- included, so with ours in its place the talents window was opened
    -- through the addon: the client refused to open it during a fight,
    -- and out of one the window's own code ran as ours. Opening it shows
    -- the empty action bar slots and notes that on each bar, and a note
    -- written by us is one the client will not act on afterwards: from
    -- then until a reload, dragging a spell no longer brought the empty
    -- slots of bars 2 to 5 up to drop it on. The spellbook has its own
    -- entries, above, and the spellbook key is bound to ours directly.
end

local function Apply()
    active = true
    TakeOver(true)
    TakeButton(true)
    UpdateBinding()
    -- Turned on in the middle of a session: the way into the world has
    -- long gone by.
    if IsLoggedIn and IsLoggedIn() then ns.SafeCall(Prebuild) end
end

local function Restore()
    active = false
    TakeOver(false)
    TakeButton(false)
    UpdateBinding()
    if book and book:IsShown() then Hide() end
end

function ns.ToggleSpellBook()
    if not active then return false end
    Toggle()
    return true
end

ns.RegisterModule("spellBook", { init = Init, apply = Apply, restore = Restore })

-- The search box is a toggle of its own under the book; off, it goes
-- and any search with it.
ns.RegisterModule("spellBookSearch", {
    apply = function() if book and book.Search then book.Search:Show() end end,
    restore = function()
        if book and book.Search then
            book.Search:SetText("")
            book.Search:Hide()
        end
    end,
})
