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
local function CollectAllSlots()
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

-- Highest ranks only, for whoever asks for it: of the spells that carry
-- a rank number and share a name, the one with the highest number stays,
-- in its own place in the book. A spell with no number in its second
-- line is never folded into another: two of a name there are two
-- different spells (a bear's and a cat's), not two ranks of one.
local function CollectSlots()
    CollectAllSlots()
    if not (ns.db and ns.db.spellBookTopRank == true) or state.bank == BANK_PET then return end
    local slots = state.slots
    local best, rankOf = {}, {}
    for _, index in ipairs(slots) do
        local ok, name, sub = pcall(C_SpellBook.GetSpellBookItemName, index, BANK_PLAYER)
        if ok and type(name) == "string" and not IsSecret(name) and type(sub) == "string" and not IsSecret(sub) then
            local rank = tonumber(sub:match("%d+"))
            if rank then
                rankOf[index] = rank
                local held = best[name]
                if not held or rank >= rankOf[held] then best[name] = index end
            end
        end
    end
    local kept = {}
    for _, index in ipairs(slots) do
        local ok, name = pcall(C_SpellBook.GetSpellBookItemName, index, BANK_PLAYER)
        if not rankOf[index] or not ok or best[name] == index then kept[#kept + 1] = index end
    end
    wipe(slots)
    for i, index in ipairs(kept) do slots[i] = index end
end

local function PageCount()
    return math.max(1, math.ceil(#state.slots / SPELLS_PER_PAGE))
end

-- The same list for a tab that is not the one on screen.
local function SlotsFor(bank, line, search)
    local keepBank, keepLine, keepSearch = state.bank, state.line, state.search
    state.bank, state.line, state.search = bank, line, search
    CollectSlots()
    local out = {}
    for i, index in ipairs(state.slots) do out[i] = index end
    state.bank, state.line, state.search = keepBank, keepLine, keepSearch
    return out
end

---------------------------------------------------------------------------
-- Spell buttons
---------------------------------------------------------------------------

local SUB_FONT = _G.SubSpellFont and "SubSpellFont" or "GameFontHighlightSmall"

-- The spell a book entry casts, as one number. An entry carries two: the
-- spell it is, and the spell that spell is standing in as right now (a
-- druid's form, a talent's replacement). The second changes under the
-- player, in a fight as anywhere, while a casting button keeps what it
-- was given out of one: a button given the stand-in cast that, whatever
-- the book showed by then, and every entry whose stand-in had changed
-- since looked like a button carrying the wrong spell. So the button is
-- given the entry's own spell, which does not change, and the client
-- turns it into the stand-in at the cast, as it does for an action bar.
-- A pet's entry is the other way about: its own number is a pet action,
-- not a spell.
local function CastID(info, bank)
    if (bank or state.bank) == BANK_PET then return info.spellID or info.actionID end
    return info.actionID or info.spellID
end

-- What a casting button casts, written out of a fight only (see the
-- pages, in the book).
local function ArmSpell(btn, slot, bank)
    local info = slot and C_SpellBook.GetSpellBookItemInfo(slot, bank)
    btn.slot = info and slot or nil
    btn.isPassive = info and info.isPassive or nil
    local id = info and not info.isPassive and info.itemType ~= ITEM_FLYOUT and CastID(info, bank) or nil
    if id and not IsSecret(id) then
        btn:SetAttribute("type1", "spell")
        btn:SetAttribute("spell", id)
    else
        btn:SetAttribute("type1", nil)
        btn:SetAttribute("spell", nil)
    end
end

local function UpdateCooldown(btn)
    local cd = btn.cooldown
    if not btn.slot then cd:Clear(); return end
    -- In a fight the cooldown's numbers are kept from an addon, but the
    -- client hands out the whole cooldown as one sealed object that a
    -- swirl will take as it is: nothing is read, so nothing is refused.
    -- That is the road the global cooldown and every spell's own take
    -- during a fight; the numbers below are for a client without it.
    if C_SpellBook.GetSpellBookItemCooldownDuration and cd.SetCooldownFromDurationObject then
        local ok, duration = pcall(C_SpellBook.GetSpellBookItemCooldownDuration, btn.slot, state.bank)
        if ok and duration ~= nil then
            if pcall(cd.SetCooldownFromDurationObject, cd, duration, true) then return end
        end
    end
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

-- A spell that cannot be cast right now is drawn as the action bars draw
-- it: grey when it is simply not usable (a teleport in a fight, a form's
-- spell out of the form), blue when only the mana is missing.
local function UpdateUsable(btn)
    local icon = btn.Icon
    -- In a fight only. Out of one the old book drew every spell plainly,
    -- and a druid's bear spells stood dimmed all day for want of the form.
    if not btn.slot or btn.isPassive or not C_SpellBook.IsSpellBookItemUsable or not InCombatLockdown() then
        icon:SetVertexColor(1, 1, 1)
        return
    end
    local ok, usable, noPower = pcall(C_SpellBook.IsSpellBookItemUsable, btn.slot, state.bank)
    if not ok or IsSecret(usable) or IsSecret(noPower) or usable then
        icon:SetVertexColor(1, 1, 1)
    elseif noPower then
        icon:SetVertexColor(0.5, 0.5, 1)
    else
        icon:SetVertexColor(0.4, 0.4, 0.4)
    end
end

-- A view the casting buttons could not be made for (a book first built
-- during a fight, a search typed during one) is drawn dimmed until the
-- fight ends: nothing on it casts, and it should not look as if it did.
local function DimButton(btn, on)
    local shade = btn.shade
    if not on then
        if shade then shade:Hide() end
        return
    end
    if not shade then
        shade = btn.slotFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        shade:SetAllPoints(btn.slotFrame)
        shade:SetColorTexture(0, 0, 0, 0.55)
        btn.shade = shade
    end
    shade:Show()
end

local viewLive = true
local Button_OnEnter

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
        btn.normal:SetVertexColor(1, 1, 1)
        DimButton(btn, false)
        return
    end
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
    DimButton(btn, not viewLive and not info.isPassive)
    UpdateUsable(btn)
    UpdateCooldown(btn)
end

Button_OnEnter = function(self)
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

    return btn
end

-- A casting button of one page (see the pages, in the book): over a slot
-- of the book, with the press and glow art, carrying one spell.
local function CreatePageButton12(layer, id)
    local btn = CreateFrame("Button", nil, layer, "SecureActionButtonTemplate")
    local column = id > 6 and 1 or 0
    local row = (id - 1) % 6
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    btn:SetPoint("TOPLEFT", layer, "TOPLEFT", FIRST_X + column * COLUMN_X, FIRST_Y - row * (BUTTON_SIZE + ROW_GAP))
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
    if InCombatLockdown() then
        self:SetChecked(state.line == self.line)
        return
    end
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
    -- The professions tab turns to the other window, as the old book
    -- turned to its professions page.
    if self.professions then
        if ns.OpenProfessionsBook and ns.OpenProfessionsBook() then
            PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
            if ns.HideSpellBook then ns.HideSpellBook() end
        end
        return
    end
    if InCombatLockdown() then return end
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
    if InCombatLockdown() then return end
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
    f.fcuiSlotWidth = 392
    ns.RegisterClassicWindow(f, true)
    ns.db.spellBookPos = nil
    if GameMenuFrame then
        GameMenuFrame:HookScript("OnShow", function(menu)
            if f:IsShown() then
                -- Escape cannot take the casting layer down in a fight,
                -- so there it is the game's own key again and the book
                -- stays for its key, its micro button or its X to close.
                if InCombatLockdown() and f.LayerUp and f:LayerUp() then return end
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
    -- On this client the book's portrait is a square icon, which stood
    -- out past the ring at its corners: cut round, just inside the ring.
    if ns.RoundIcon then ns.RoundIcon(icon, 2) end

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
    search:SetPoint("TOPRIGHT", f, "TOPRIGHT", -42, -47)
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

    -- The old book's own check box, over the left page: ticked, every
    -- rank is listed, as the old book did it; unticked, only the highest
    -- rank known of each spell. The same setting as the one in the
    -- options, the other way up.
    local ranks = CreateFrame("CheckButton", nil, f)
    ranks:SetSize(22, 22)
    ranks:SetPoint("TOPLEFT", f, "TOPLEFT", 76, -46)
    ranks:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    ranks:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    ranks:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    ranks:GetHighlightTexture():SetBlendMode("ADD")
    ranks:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    ranks:SetHitRectInsets(0, -110, 0, 0)
    local ranksText = ranks:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    ranksText:SetPoint("LEFT", ranks, "RIGHT", 0, 1)
    ranksText:SetText(_G.SHOW_ALL_SPELL_RANKS or "Show all spell ranks")
    ranks:SetScript("OnClick", function(self)
        ns.db.spellBookTopRank = not self:GetChecked()
        PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        if ns.ToggleChanged then ns.ToggleChanged("spellBookTopRank") else f:Refresh() end
    end)
    f.Ranks = ranks

    -- The casting buttons sit on their own layer over the book rather
    -- than inside it, so the book holds nothing of the client's and can
    -- be shown during a fight. Out of a fight the layer follows the book.
    -- During one an addon may not show or hide it, and on this client the
    -- usual way round that, a secure handler's own few lines of code, is
    -- shut: the client cannot compile them at all (its loader is missing,
    -- an error out of its own files at the first click). What is left
    -- needs no code of ours to run securely:
    --   the layer is watched for a unit, which the client's own state
    --   driver does by showing it while the unit in its "unit" attribute
    --   exists and hiding it otherwise: "player" is up, "none" is down;
    --   the layer is also a secure button whose click writes that
    --   attribute, the client's own "attribute" action. Written plainly it
    --   says "player"; while the unit is the player, a friend, the click
    --   is first renamed by the help-button rule to "close", under which
    --   it says "none". So one click turns it on and the next turns it off.
    -- The spellbook key and a pad over the micro button click it, pads
    -- over the book's X and Professions tab write "none", and the book
    -- follows the attribute. The driver looks five times a second, so the
    -- layer itself is up to a fifth of a second behind in a fight.
    local clicks = CreateFrame("Button", "ForeverClassicUISpellBookClicks", UIParent, "SecureActionButtonTemplate")
    clicks:EnableMouse(false)
    -- The book's own spot and size, said against the screen: tied to
    -- the book it would make the book the client's to show and hide.
    clicks:SetSize(BOOK_W, BOOK_H)
    clicks:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
    clicks:SetFrameStrata("HIGH")
    clicks:Hide()
    f.Clicks = clicks
    -- The casting layer goes where the book goes (the book may stand to
    -- the talent window's right). It holds casting buttons, so it is
    -- moved out of a fight only; during one it is put away in any case,
    -- and it is stood in the book's place again as the fight ends.
    local function FollowBook()
        if InCombatLockdown() and clicks:IsProtected() then return end
        clicks:ClearAllPoints()
        clicks:SetPoint("TOPLEFT", UIParent, "TOPLEFT", f.fcuiSlotX or 0, -104)
    end
    f.OnClassicPlaced = function() FollowBook() end
    -- The layer cannot be moved in a fight, so while it is up in one the
    -- book stays where it stands, under its buttons; a window opening
    -- beside it is stood around it.
    f.LayerUp = function()
        return clicks:GetAttribute("unit") == "player"
    end
    f.fcuiHoldX = function(self)
        if InCombatLockdown() and self:LayerUp() then return self.fcuiSlotX or 0 end
    end
    -- Ours to set out of a fight only: the attribute, and the layer with
    -- it at once rather than at the driver's next look.
    f.SetLayer = function(_, on)
        if InCombatLockdown() then return end
        on = on and true or false
        if clicks.fcuiLinked then clicks:SetAttribute("unit", on and "player" or "none") end
        clicks:SetShown(on)
    end

    -- A pad on the layer, over a control of the book that closes it. Its
    -- click writes "none" to the layer, which the control's own click
    -- could not do in a fight, and the control's work follows.
    local function LayerPad(over, width, height, point, x, y, after)
        local pad = CreateFrame("Button", nil, clicks, "SecureActionButtonTemplate")
        pad:SetSize(width, height)
        pad:SetPoint("CENTER", clicks, point, x, y)
        pad:RegisterForClicks("AnyUp", "AnyDown")
        pad:SetAttribute("useOnKeyDown", false)
        pad:SetAttribute("type", "attribute")
        pad:SetAttribute("attribute-frame", clicks)
        pad:SetAttribute("attribute-name", "unit")
        pad:SetAttribute("attribute-value", "none")
        pad:SetScript("PostClick", function(_, _, down)
            if not down then after() end
        end)
        -- The pad has no art: the control under it shows the press and glow.
        pad:SetScript("OnMouseDown", function() over:SetButtonState("PUSHED") end)
        pad:SetScript("OnMouseUp", function() over:SetButtonState("NORMAL") end)
        pad:SetScript("OnEnter", function() over:LockHighlight() end)
        pad:SetScript("OnLeave", function() over:UnlockHighlight() end)
        return pad
    end

    -- All of it is attribute writing, which is for out of a fight: done
    -- once, as the book is built or as the fight it was built in ends.
    local function LinkLayer()
        if clicks.fcuiLinked or InCombatLockdown() then return end
        local toggle = _G["ForeverClassicUISpellBookBind"]
        if not toggle then return end
        clicks.fcuiLinked = true
        for _, btn in ipairs(f.Buttons or {}) do btn:EnableMouse(false) end
        clicks:RegisterForClicks("AnyUp", "AnyDown")
        clicks:SetAttribute("useOnKeyDown", false)
        clicks:SetAttribute("type", "attribute")
        clicks:SetAttribute("attribute-name", "unit")
        clicks:SetAttribute("attribute-value", "player")
        clicks:SetAttribute("helpbutton", "close")
        clicks:SetAttribute("attribute-value-close", "none")
        clicks:SetAttribute("unit", f:IsShown() and "player" or "none")
        RegisterUnitWatch(clicks)
        toggle:SetAttribute("type", "click")
        toggle:SetAttribute("clickbutton", clicks)
        LayerPad(f.Close, 24, 24, "TOPRIGHT", -44, -25, function()
            if ns.HideSpellBook then ns.HideSpellBook() end
        end)
        local profTab = f.BookTabs and f.BookTabs[2]
        if profTab then
            LayerPad(profTab, 100, 30, "BOTTOMLEFT", 187, 64, function()
                local click = profTab:GetScript("OnClick")
                if click then click(profTab) end
            end)
        end
    end
    f.LinkLayer = LinkLayer

    local follow = CreateFrame("Frame")
    follow:RegisterEvent("PLAYER_REGEN_ENABLED")
    follow:SetScript("OnEvent", function()
        LinkLayer()
        FollowBook()
    end)

    -- Whatever hides the book hides the layer with it: the game menu,
    -- another window of ours opening. Otherwise the layer is left on
    -- screen with nothing drawn under it, and a click on empty ground
    -- would cast.
    f:HookScript("OnShow", function(self) self:SetLayer(true) end)
    f:HookScript("OnHide", function(self)
        if not InCombatLockdown() then
            self:SetLayer(false)
        elseif self:LayerUp() then
            -- Hidden in a fight by something that could not take the
            -- layer down with it. Live buttons nobody can see are worse
            -- than a book that stays: it comes back, and closes by its
            -- key, its micro button or its X, which can.
            C_Timer.After(0, function()
                if InCombatLockdown() and self:LayerUp() and not self:IsShown() then self:Show() end
            end)
        end
    end)

    f.Buttons = {}
    for id = 1, SPELLS_PER_PAGE do
        f.Buttons[id] = CreateSpellButton(f, id, clicks)
    end

    f.SkillTabs = {}
    for i = 1, MAX_SKILL_TABS do
        f.SkillTabs[i] = CreateSkillTab(f, i, f.SkillTabs[i - 1])
    end

    -- One more tab under the skill tabs, for a trainer list from another
    -- addon where one is installed (What's Training). On this client that
    -- addon hangs its tab on the game's own spellbook, which this book
    -- stands in for, so its tab could not be reached; it also has a
    -- window of its own, the old book's size, behind its slash command.
    -- The tab opens that window beside the book.
    f.TrainTab = CreateSkillTab(f, MAX_SKILL_TABS + 1, nil)
    f.TrainTab:SetNormalTexture("Interface\\Icons\\INV_Misc_Book_09")
    f.TrainTab.tooltip = "What can I train?"
    f.TrainTab:SetScript("OnClick", function(self)
        self:SetChecked(false)
        local open = SlashCmdList and SlashCmdList.WHATSTRAINING
        if type(open) ~= "function" then return end
        PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
        pcall(open, "")
        local window = _G["WhatsTrainingFloatingFrame"]
        if window and window:IsShown() and not window.fcuiDocked then
            -- Beside the book the first time, and the player's to drag after.
            window.fcuiDocked = true
            window:ClearAllPoints()
            window:SetPoint("TOPLEFT", f, "TOPRIGHT", -28, -12)
        end
    end)

    f.BookTabs = {}
    for i = 1, 3 do
        f.BookTabs[i] = CreateBookTab(f, i, f.BookTabs[i - 1])
    end
    LinkLayer()

    ------------------------------------------------------------ the pages
    -- A casting button is given its spell out of a fight and keeps it
    -- through one, so twelve buttons re-armed at every page turn held the
    -- last page seen before the fight, whatever the book showed during
    -- it. Instead every page of every tab has its own twelve, armed out
    -- of a fight, and turning a page or a tab during one only changes
    -- which of them are up. That is a show and a hide of casting buttons,
    -- which in a fight only the client may do, and this client cannot run
    -- a secure handler's code (see the layer, above); so, as with the
    -- layer, it is done with the client's unit watch and its "attribute"
    -- click, one write to a click:
    --   a tab's pages hang from a frame of their own, watched for a unit
    --   it does not carry itself: it takes the holder's "unit" and adds
    --   its own suffix. The holder says "p", "pl", "pla"... and each
    --   tab's suffix finishes exactly one of those into "player", so one
    --   write to the holder brings one tab up and sends the rest away;
    --   within a tab the pages lie one over the other, a later page
    --   higher, each covering the whole of the one under it. Pages 1 to n
    --   are up while page n is read: next shows n+1, previous hides n.
    -- The book then draws whatever tab and page are up, so what it shows
    -- and what casts cannot differ. The watch looks five times a second,
    -- so a turn during a fight lands up to a fifth of a second late.
    local SELECTORS = { { "p", "layer" }, { "pl", "ayer" }, { "pla", "yer" }, { "play", "er" }, { "playe", "r" }, { "player" } }
    local DYNAMIC = #SELECTORS
    local holder = CreateFrame("Frame", nil, clicks)
    holder:SetAllPoints(clicks)
    local containers, lineContainer = {}, {}
    local petContainer
    local pages = { dirty = true, built = false }
    f.Pages = pages

    local refreshQueued = false
    local function QueueRefresh()
        if refreshQueued then return end
        refreshQueued = true
        C_Timer.After(0, function()
            refreshQueued = false
            if f:IsShown() then f:Refresh() end
        end)
    end

    -- A pad over one of the book's own controls. Its click is the secure
    -- write; out of a fight the control's own click then runs as it
    -- always did, and sets everything plainly.
    local function NewPad(parent, over, width, height, enter)
        local pad = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
        pad:SetSize(width, height)
        pad:RegisterForClicks("AnyUp", "AnyDown")
        pad:SetAttribute("useOnKeyDown", false)
        pad:SetAttribute("attribute-name", "unit")
        pad:SetScript("OnMouseDown", function() if over:IsEnabled() then over:SetButtonState("PUSHED") end end)
        pad:SetScript("OnMouseUp", function() if over:IsEnabled() then over:SetButtonState("NORMAL") end end)
        pad:SetScript("OnEnter", function()
            over:LockHighlight()
            if enter then enter(over) end
        end)
        pad:SetScript("OnLeave", function()
            over:UnlockHighlight()
            GameTooltip:Hide()
        end)
        pad:SetScript("PostClick", function(self, _, down)
            if down then return end
            if InCombatLockdown() then
                if self.live then PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN) end
                return
            end
            local click = over:GetScript("OnClick")
            if click and over:IsEnabled() then click(over) end
        end)
        return pad
    end
    local function ArmPad(pad, frame, value)
        pad.live = frame ~= nil
        pad:SetAttribute("type", frame and "attribute" or nil)
        pad:SetAttribute("attribute-frame", frame)
        pad:SetAttribute("attribute-value", value)
    end

    local function NewLayer(c, page)
        local layer = CreateFrame("Frame", nil, c.frame)
        layer:SetAllPoints(clicks)
        layer:SetFrameLevel(clicks:GetFrameLevel() + 10 + page * 12)
        layer.buttons = {}
        for id = 1, SPELLS_PER_PAGE do layer.buttons[id] = CreatePageButton12(layer, id) end
        layer.prev = NewPad(layer, f.PrevPage, 32, 32)
        layer.prev:SetPoint("CENTER", layer, "BOTTOMLEFT", 50, 105)
        layer.next = NewPad(layer, f.NextPage, 32, 32)
        layer.next:SetPoint("CENTER", layer, "BOTTOMLEFT", 314, 105)
        layer:SetAttribute("unit", page == 1 and "player" or "none")
        RegisterUnitWatch(layer)
        layer:HookScript("OnShow", QueueRefresh)
        layer:HookScript("OnHide", QueueRefresh)
        c.layers[page] = layer
        return layer
    end

    local function NewContainer(index)
        local c = { index = index, selector = SELECTORS[index][1], layers = {}, skillPads = {} }
        c.frame = CreateFrame("Frame", nil, holder)
        c.frame:SetAllPoints(clicks)
        c.frame:SetAttribute("useparent-unit", true)
        if SELECTORS[index][2] then c.frame:SetAttribute("unitsuffix", SELECTORS[index][2]) end
        RegisterUnitWatch(c.frame)
        c.frame:HookScript("OnShow", QueueRefresh)
        c.frame:HookScript("OnHide", QueueRefresh)
        -- The skill tabs down the right edge, and the two tabs at the foot.
        for i = 1, MAX_SKILL_TABS do
            local pad = NewPad(c.frame, f.SkillTabs[i], 32, 32, SkillTab_OnEnter)
            pad:SetPoint("TOPLEFT", c.frame, "TOPRIGHT", -32, -65 - (i - 1) * 49)
            c.skillPads[i] = pad
        end
        c.bookPad = NewPad(c.frame, f.BookTabs[1], 100, 30)
        c.bookPad:SetPoint("CENTER", c.frame, "BOTTOMLEFT", 79, 64)
        c.petPad = NewPad(c.frame, f.BookTabs[3], 100, 30)
        c.petPad:SetPoint("CENTER", c.frame, "BOTTOMLEFT", 295, 64)
        containers[index] = c
        return c
    end

    local function Fill(c, slots, bank)
        c.slots, c.bank = slots, bank
        c.pages = math.max(1, math.ceil(#slots / SPELLS_PER_PAGE))
        for page = 1, c.pages do
            local layer = c.layers[page] or NewLayer(c, page)
            for id = 1, SPELLS_PER_PAGE do
                ArmSpell(layer.buttons[id], slots[(page - 1) * SPELLS_PER_PAGE + id], bank)
            end
        end
        for page, layer in ipairs(c.layers) do
            ArmPad(layer.prev, page > 1 and page <= c.pages and layer or nil, "none")
            ArmPad(layer.next, page < c.pages and c.layers[page + 1] or nil, "player")
            if page > c.pages then
                layer:SetAttribute("unit", "none")
                layer:Hide()
            end
        end
    end

    -- The pads of one tab's frame: the way to every other tab that has
    -- casting buttons of its own.
    local function ArmTabs(c, lines)
        local player = c.kind ~= "pet"
        for i = 1, MAX_SKILL_TABS do
            local target = player and lines[i] and lineContainer[lines[i]]
            local pad = c.skillPads[i]
            ArmPad(pad, target and holder or nil, target and target.selector or nil)
            pad:SetShown(target and true or false)
        end
        local first = lines[1] and lineContainer[lines[1]]
        ArmPad(c.bookPad, not player and first and holder or nil, first and first.selector or nil)
        c.bookPad:SetShown(not player and first ~= nil)
        ArmPad(c.petPad, player and petContainer and holder or nil, petContainer and petContainer.selector or nil)
        c.petPad:SetShown(player and petContainer ~= nil)
    end

    function f.BuildPages()
        if InCombatLockdown() or not clicks.fcuiLinked then
            pages.dirty = true
            return
        end
        pages.dirty = false
        local lines = {}
        local n = C_SpellBook.GetNumSpellBookSkillLines() or 0
        for i = 1, n do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(i)
            if info and not info.shouldHide and (info.offSpecID or 0) == 0 and #lines < MAX_SKILL_TABS then lines[#lines + 1] = i end
        end
        local hasPet = PetSpellCount() > 0
        local room = DYNAMIC - 1 - (hasPet and 1 or 0)
        wipe(lineContainer)
        petContainer = nil
        local index = 0
        for i, line in ipairs(lines) do
            if i <= room then
                index = index + 1
                local c = containers[index] or NewContainer(index)
                c.kind, c.line, c.content = "line", line, nil
                Fill(c, SlotsFor(BANK_PLAYER, line, ""), BANK_PLAYER)
                lineContainer[line] = c
            end
        end
        if hasPet then
            index = index + 1
            local c = containers[index] or NewContainer(index)
            c.kind, c.line, c.content = "pet", nil, nil
            Fill(c, SlotsFor(BANK_PET, state.line, ""), BANK_PET)
            petContainer = c
        end
        for i = index + 1, DYNAMIC - 1 do
            if containers[i] then containers[i].kind = nil end
        end
        -- The last one is for whatever has no frame of its own: a search,
        -- or a tab past the ones there was room for. Filled when wanted.
        local dyn = containers[DYNAMIC] or NewContainer(DYNAMIC)
        dyn.kind, dyn.content = "dyn", nil
        pages.lines = lines
        for _, c in pairs(containers) do
            if c.kind then ArmTabs(c, lines) end
        end
        pages.built = true
        -- The frames stand as the book stands from the start: a book first
        -- opened in a fight has its tab and page up already.
        if f.ApplyPages then f.ApplyPages() end
    end

    -- The frame that carries what the book's state asks for.
    local function ContainerFor()
        if not pages.built then return nil end
        if state.search ~= "" then return containers[DYNAMIC], "search:" .. tostring(state.bank) .. ":" .. state.search:lower() end
        if state.bank == BANK_PET then return petContainer end
        if lineContainer[state.line] then return lineContainer[state.line] end
        return containers[DYNAMIC], "line:" .. tostring(state.line)
    end

    -- In a fight the book is told by the frames what is up.
    local function ReadPages()
        if not pages.built then return end
        local current
        for _, c in pairs(containers) do
            if c.kind and c.frame:IsShown() then current = c end
        end
        if not current then return end
        if current.kind == "line" then
            state.bank, state.line, state.search = BANK_PLAYER, current.line, ""
        elseif current.kind == "pet" then
            state.bank, state.search = BANK_PET, ""
        end
        local page = 1
        for i = 1, current.pages or 1 do
            if current.layers[i] and current.layers[i]:IsShown() then page = i end
        end
        SetPage(page)
    end

    -- Out of a fight the frames are told by the book.
    local function ApplyPages()
        local c, content = ContainerFor()
        if not c then return nil end
        if c.kind == "dyn" and c.content ~= content then
            c.content = content
            c.line = state.line
            Fill(c, SlotsFor(state.bank, state.line, state.search), state.bank)
            ArmTabs(c, pages.lines or {})
        end
        holder:SetAttribute("unit", c.selector)
        for _, other in pairs(containers) do other.frame:SetShown(other == c) end
        local page = math.min(CurrentPage(), c.pages)
        for i, layer in ipairs(c.layers) do
            local up = i <= page
            layer:SetAttribute("unit", up and "player" or "none")
            layer:SetShown(up)
        end
        return c
    end
    f.ReadPages, f.ApplyPages, f.ContainerFor = ReadPages, ApplyPages, ContainerFor

    f:BuildPages()

    f:SetScript("OnMouseWheel", Book_OnMouseWheel)
    -- Added to, not set: setting a script throws away whatever was hooked
    -- onto it before, and that was the click layer's own show and hide
    -- above and the one window at a time rule. With those gone the
    -- casting layer stayed on screen after the book had closed, its
    -- icons over whatever had opened, until something else put it away.
    f:HookScript("OnShow", function(self)
        PlaySound(SOUNDKIT.IG_SPELLBOOK_OPEN)
        self:Refresh()
        ns.RefreshMicroButtons()
    end)
    f:HookScript("OnHide", function()
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
    pcall(f.RegisterEvent, f, "PLAYER_REGEN_DISABLED")
    pcall(f.RegisterEvent, f, "SPELL_UPDATE_USABLE")
    local rebuildQueued = false
    f:SetScript("OnEvent", function(self, event)
        if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_USABLE" then
            if self:IsShown() then
                for _, btn in ipairs(self.Buttons) do
                    UpdateCooldown(btn)
                    UpdateUsable(btn)
                end
            end
            return
        end
        if event == "PLAYER_REGEN_DISABLED" then
            if self:IsShown() then self:Refresh() end
            return
        end
        -- The spells have changed, or a fight that held a change back is
        -- over. A closed book is rebuilt as well: its buttons have to be
        -- armed before the fight it is next opened in. Once, however many
        -- of these come together.
        if event ~= "PLAYER_REGEN_ENABLED" or self.Pages.dirty then self.Pages.dirty = true end
        if rebuildQueued then return end
        rebuildQueued = true
        C_Timer.After(0.1, function()
            rebuildQueued = false
            if self.Pages.dirty and not InCombatLockdown() then self:BuildPages() end
            if self:IsShown() then self:Refresh() end
        end)
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
        -- The trainer list's tab, under the last skill tab that is up.
        local train = self.TrainTab
        if train then
            local there = state.bank == BANK_PLAYER and SlashCmdList and type(SlashCmdList.WHATSTRAINING) == "function"
            train:SetShown(there and true or false)
            if there then
                train:ClearAllPoints()
                if shown > 0 then
                    train:SetPoint("TOPLEFT", self.SkillTabs[shown], "BOTTOMLEFT", 0, -17)
                else
                    train:SetPoint("TOPLEFT", self, "TOPRIGHT", -32, -65)
                end
            end
        end
        if state.bank == BANK_PLAYER and not selectedVisible and firstLine then
            state.line = firstLine
            for i = 1, shown do self.SkillTabs[i]:SetChecked(self.SkillTabs[i].line == firstLine) end
        end
    end

    function f:UpdateBookTabs()
        local petCount, token = PetSpellCount()
        -- Spellbook, Professions, and the pet last: the pet comes and
        -- goes, and the two that stay keep their places, the same places
        -- they have at the foot of the professions window.
        local tab1, profTab, tab2 = self.BookTabs[1], self.BookTabs[2], self.BookTabs[3]
        tab1.bank = BANK_PLAYER
        tab1:SetText(SPELLBOOK)
        tab1:Show()
        profTab.professions = true
        profTab:SetText(TRADE_SKILLS or "Professions")
        profTab:Show()
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
        if self.Ranks then
            self.Ranks:SetChecked(not (ns.db and ns.db.spellBookTopRank == true))
            -- The pet's spells have no ranks to fold.
            self.Ranks:SetShown(state.bank ~= BANK_PET)
        end
        local fight = InCombatLockdown()
        if fight then
            self.ReadPages()
        elseif self.Pages.dirty then
            self:BuildPages()
        end
        if self.Search then
            -- A search makes a page of its own, which cannot be made in a fight.
            pcall(self.Search.SetEnabled, self.Search, not fight)
            if fight and self.Search:HasFocus() then self.Search:ClearFocus() end
        end
        self:UpdateBookTabs()
        self:UpdateSkillTabs()
        -- The list on screen is the list the casting buttons were made
        -- from, where there is one.
        local c, content = self.ContainerFor()
        local usable = c and (not fight or (c.slots and (c.kind ~= "dyn" or c.content == content)))
        if usable then
            if not fight then
                self:UpdatePagesFor(c, content)
                c = self.ApplyPages() or c
            end
            wipe(state.slots)
            for i, index in ipairs(c.slots) do state.slots[i] = index end
            viewLive = true
        else
            CollectSlots()
            viewLive = not fight
        end
        self:UpdatePages()
        for _, btn in ipairs(self.Buttons) do UpdateButton(btn) end
    end

    -- The page asked for, held to the pages the list will have.
    function f.UpdatePagesFor(_, c, content)
        local slots = c.slots
        if c.kind == "dyn" and c.content ~= content then slots = SlotsFor(state.bank, state.line, state.search) end
        local most = math.max(1, math.ceil(#slots / SPELLS_PER_PAGE))
        if CurrentPage() > most then SetPage(most) end
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
    if not book then return end
    book:SetLayer(on and book:IsShown())
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
    -- A close that did not come through a secure button cannot take the
    -- casting layer down during a fight, and the book does not leave its
    -- live buttons behind: it stays, to be closed by its key, Escape or
    -- its X.
    if InCombatLockdown() and book:LayerUp() and book:IsShown() then return end
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
waiting:RegisterEvent("PLAYER_REGEN_DISABLED")
waiting:SetScript("OnEvent", function(_, event)
    if not active then return end
    -- A fight is starting, and this is the last moment the casting layer
    -- is ours to put away. Left up, it cannot be hidden once the fight
    -- is on: a book closed during the fight then left its buttons on the
    -- screen unseen, over the party frames, where a click meant for a
    -- party member cast a spell instead, until the fight was over. So
    -- the layer goes down as the fight begins, book open or not. The
    -- book itself stays; its spells cannot be clicked until the fight
    -- ends, the same as a book opened during one.
    -- That holds for a layer with no book under it. Under an open book
    -- the layer stays, so the spells go on casting into the fight, and it
    -- comes down with the book (see Hide and the book's OnHide).
    if event == "PLAYER_REGEN_DISABLED" then
        local open = book and book:IsShown() and book:GetAlpha() > 0
        if book and not open then book:SetLayer(false) end
        return
    end
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
-- With the book off from the start nothing is written at all. Putting
-- the client's own function back into its table is still a write of
-- ours, and the client treats what it then reads there as the addon's:
-- its own spellbook, opened through those entries, ran in the addon's
-- name, so a click on a spell was a blocked action and a dragged spell
-- brought up no empty slots on bars 2 to 5.
local tookOver = false
local function TakeOver(on)
    if not PlayerSpellsUtil then return end
    if on == tookOver then return end
    tookOver = on
    for key, orig in pairs(originals) do
        PlayerSpellsUtil[key] = on and wrapped[key] or orig
    end
end

-- The spellbook's micro button goes down TogglePlayerSpellsFrame, the
-- road that is left to the client (see Init). So the button itself is
-- given our click while the book is on, and its own back when it is off.
-- It is the spellbook's button alone; the talents button is not touched.
local microClick
local tookButton = false
local function TakeButton(on)
    local button = _G["SpellbookMicroButton"]
    if not button or not button.GetScript then return end
    if on == tookButton then return end
    tookButton = on
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
end

local function Init()
    -- The spellbook key and the pad over the micro button come here, and
    -- this button clicks the casting layer (see the layer, in the book),
    -- which turns itself on or off. The book then follows the layer: by
    -- the time this click is done the layer's attribute says which.
    bindButton = CreateFrame("Button", BIND_NAME, UIParent, "SecureActionButtonTemplate")
    bindButton:RegisterForClicks("AnyDown", "AnyUp")
    bindButton:SetAttribute("useOnKeyDown", false)
    bindButton:SetScript("PostClick", function(_, _, down)
        -- Heard on the press and on the release; the click is done on
        -- the release, whatever the cast on key down setting says.
        if not active or down then return end
        local layer = book and book.Clicks
        if layer and layer.fcuiLinked then
            if book:LayerUp() then
                Show()
            elseif book:IsShown() then
                Hide()
            end
        else
            Toggle()
        end
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
    -- The micro button's own click is ours and cannot raise the casting
    -- layer in a fight; a secure pad over it presses the button above.
    if ns.MapPad and bindButton then
        ns.MapPad(_G["SpellbookMicroButton"], nil, nil, bindButton, function() return active end)
    end
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

-- For the professions window, which carries the same tabs at its foot.
ns.NewBookTab = CreateBookTab
ns.NewSideTab = CreateSkillTab
function ns.SpellBookActive() return active end
function ns.SpellBookBank() return state.bank end
function ns.HideSpellBook() Hide() end
function ns.SpellBookPetTitle()
    local petCount, token = PetSpellCount()
    if petCount > 0 then return (token and _G["PET_TYPE_" .. token]) or PET end
end
function ns.ShowSpellBookBank(pet)
    if not active then return false end
    state.bank = pet and BANK_PET or BANK_PLAYER
    Show()
    if book and book:IsShown() then book:Refresh() end
    return true
end

function ns.ToggleSpellBook()
    if not active then return false end
    Toggle()
    return true
end

ns.RegisterModule("spellBook", { init = Init, apply = Apply, restore = Restore })

-- Highest ranks only: the list is simply collected again.
local function RelistBook()
    if not book then return end
    book.Pages.dirty = true
    if not InCombatLockdown() then book:BuildPages() end
    if book:IsShown() and book.Refresh then book:Refresh() end
end
ns.RegisterModule("spellBookTopRank", { apply = RelistBook, restore = RelistBook })

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
