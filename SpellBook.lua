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
local ghost = { at = {}, points = {} }
local RANK_CVAR = "ShowAllSpellRanks"
local clientRanks = { held = false }

local function ClientRanksValue()
    return ns.db and ns.db.spellBookTopRank == true and "0" or "1"
end

local function ClientBookMacro()
    -- Hung inside the client's book (see NestLayer), the casting layer is
    -- only ever put on here: it shows while the client's window shows, so
    -- the micro button's own toggle of that window opens and closes both.
    -- Standing on the screen, the layer's click turns it on or off.
    local layer = ghost.nested and "ForeverClassicUISpellBookLayerOn" or "ForeverClassicUISpellBookClicks"
    return "/console " .. RANK_CVAR .. " " .. ClientRanksValue()
        .. "\n/click " .. layer .. "\n/click SpellbookMicroButton"
end

-- The hidden client book must list the same ranks as this one or there is
-- no client-owned button to borrow for a lower rank during combat.
local function SyncClientRanks()
    if not GetCVar or not SetCVar then return end
    local lending = active and ns.db and ns.db.spellDrag ~= false
    if lending then
        if not clientRanks.held then
            local ok, value = pcall(GetCVar, RANK_CVAR)
            if not ok then return end
            clientRanks.held = true
            clientRanks.value = value
        end
        pcall(SetCVar, RANK_CVAR, ClientRanksValue())
    elseif clientRanks.held then
        if clientRanks.value ~= nil then pcall(SetCVar, RANK_CVAR, clientRanks.value) end
        clientRanks.held = false
        clientRanks.value = nil
    end
    if not InCombatLockdown() then
        local toggle = _G["ForeverClassicUISpellBookBind"]
        if toggle and toggle:GetAttribute("type") == "macro" then
            toggle:SetAttribute("macrotext", ClientBookMacro())
        end
    end
end

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
    btn.bank = bank
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
    -- Not in a fight: taking a spell onto the cursor is a call the
    -- client keeps for itself there (tried, and refused with the blocked
    -- action notice), and none of the secure button types picks a spell
    -- up. The button carries its own bank for the pages laid out ahead.
    if not self.slot or self.isPassive or InCombatLockdown() then return end
    C_SpellBook.PickupSpellBookItem(self.slot, self.bank or state.bank)
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
    -- Escape is taken while the book is up, out of a fight: left to the
    -- client, the key drops the target first and only reaches the game
    -- menu, where the book was shut from (below), with no target held.
    -- The old client shut its windows before it let the target go. The
    -- menu's way stays for a fight, where no key can be taken.
    -- Escape shuts the book the same way its X does, not by hiding the
    -- frame outright: the casting layer has to come down with it. A bare
    -- hide during a fight left the layer up, and the book put itself
    -- straight back rather than leave live buttons on the screen unseen,
    -- which read as Escape closing it and it opening again at once.
    if ns.CloseOnEscape then ns.CloseOnEscape(f, function() ns.HideSpellBook() end) end
    if GameMenuFrame then
        -- The menu is left open. It used to be shut again in the same
        -- breath, which read as it flashing, and in a fight it is the
        -- only way the menu opens at all: the key cannot be taken while
        -- a fight is on, so Escape goes to the client there.
        GameMenuFrame:HookScript("OnShow", function()
            -- Not during a fight: Escape is the client's own there, and
            -- a book shut from here came straight back (its layer is
            -- still up), which read as the menu flapping open and shut.
            if InCombatLockdown() then return end
            if f:IsShown() then
                -- Escape cannot take the casting layer down in a fight,
                -- so there it is the game's own key again and the book
                -- stays for its key, its micro button or its X to close.
                if InCombatLockdown() and f.LayerUp and f:LayerUp() then return end
                f:Hide()
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

    -- The write the pads below carry, on a button with a name of its
    -- own, for Escape to press through a macro (ns.SpellBookEscText).
    -- It writes to the casting layer, which is ours, and touches
    -- nothing of the client's.
    local layerOff = CreateFrame("Button", "ForeverClassicUISpellBookLayerOff", UIParent, "SecureActionButtonTemplate")
    layerOff:SetSize(1, 1)
    layerOff:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
    layerOff:EnableMouse(false)
    layerOff:RegisterForClicks("AnyUp", "AnyDown")
    layerOff:SetAttribute("useOnKeyDown", false)
    layerOff:SetAttribute("type", "attribute")
    layerOff:SetAttribute("attribute-frame", clicks)
    layerOff:SetAttribute("attribute-name", "unit")
    layerOff:SetAttribute("attribute-value", "none")

    -- Its twin, which only ever puts the layer on: the spellbook key's
    -- macro presses it while the layer hangs in the client's book.
    local layerOn = CreateFrame("Button", "ForeverClassicUISpellBookLayerOn", UIParent, "SecureActionButtonTemplate")
    layerOn:SetSize(1, 1)
    layerOn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
    layerOn:EnableMouse(false)
    layerOn:RegisterForClicks("AnyUp", "AnyDown")
    layerOn:SetAttribute("useOnKeyDown", false)
    layerOn:SetAttribute("type", "attribute")
    layerOn:SetAttribute("attribute-frame", clicks)
    layerOn:SetAttribute("attribute-name", "unit")
    layerOn:SetAttribute("attribute-value", "player")

    -- A pad on the layer, over a control of the book that closes it. Its
    -- click writes "none" to the layer, which the control's own click
    -- could not do in a fight, and the control's work follows. Where the
    -- layer hangs in the client's book the pad presses the spellbook key
    -- instead (see ArmPads), so the client's window closes with it.
    f.LayerPads = {}
    local function LayerPad(over, width, height, point, x, y, after)
        local pad = CreateFrame("Button", nil, clicks, "SecureActionButtonTemplate")
        f.LayerPads[#f.LayerPads + 1] = pad
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
        -- One click, two presses: the layer of ours that the spells
        -- cast from, and the client's own micro button, whose handler
        -- opens the client's book with no code of ours in the way. A
        -- macro is the one thing that will do both from one click.
        if ns.db and ns.db.spellDrag ~= false then
            toggle:SetAttribute("type", "macro")
            -- Set the rank filter in the same protected click that opens
            -- the client book. Its OnShow rebuild then creates a real,
            -- draggable client button for every rank this book displays.
            toggle:SetAttribute("macrotext", ClientBookMacro())
        else
            toggle:SetAttribute("type", "click")
            toggle:SetAttribute("clickbutton", clicks)
        end
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
        -- A reload in the middle of a fight leaves all of this undone:
        -- the layer cannot be wired and the pages cannot be built while
        -- the fight is on. Both are done the moment it ends.
        LinkLayer()
        if f.Pages and f.Pages.dirty and f.BuildPages then f.BuildPages() end
        FollowBook()
        if f:IsShown() then f:Refresh() end
    end)

    -- Whatever hides the book hides the layer with it: the game menu,
    -- another window of ours opening. Otherwise the layer is left on
    -- screen with nothing drawn under it, and a click on empty ground
    -- would cast.
    f:HookScript("OnShow", function(self) self:SetLayer(true) end)
    f:HookScript("OnHide", function(self)
        if not InCombatLockdown() then
            self:SetLayer(false)
        elseif self:LayerUp() and clicks:IsVisible() then
            -- Hidden in a fight by something that could not take the
            -- layer down with it. Live buttons nobody can see are worse
            -- than a book that stays: it comes back, and closes by its
            -- key, its micro button or its X, which can. A layer that is
            -- already out of sight, because the client's window it hangs
            -- in was closed, leaves nothing live behind, so the book stays
            -- shut and the layer's attribute is put right as the fight ends.
            C_Timer.After(0, function()
                if InCombatLockdown() and self:LayerUp() and clicks:IsVisible() and not self:IsShown() then self:Show() end
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

    -- The client's own category tab for a skill line, asked of the
    -- client's own categories. Its book lends this one its buttons, and
    -- it can only lend the ones it is showing, so its tab has to turn
    -- with ours.
    local function ClientCategoryTab(line, bank)
        local window = _G["PlayerSpellsFrame"]
        local client = window and window.SpellBookFrame
        local tabs = client and client.CategoryTabSystem
        if not tabs or not client.categoryMixins then return nil end
        for _, category in ipairs(client.categoryMixins) do
            local okBank, holdsBank = pcall(category.GetSpellBank, category)
            if okBank and holdsBank == bank then
                local okID, id = pcall(category.GetTabID, category)
                local match = bank ~= Enum.SpellBookSpellBank.Player
                if not match and line then
                    local okLine, holds = pcall(category.ContainsSkillLine, category, line)
                    match = (okLine and holds) or category.skillLineIndex == line
                end
                if okID and id and match then
                    local okTab, tab = pcall(tabs.GetTabButton, tabs, id)
                    if okTab and tab then return tab end
                end
            end
        end
        return nil
    end

    -- A button with a name that presses one of the client's, since a
    -- macro knows nothing but names.
    local linePads = {}
    local function LinePad(key, tab)
        local name = "ForeverClassicUIBookLine" .. key
        local pad = linePads[key]
        if not pad then
            pad = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
            pad:SetSize(1, 1)
            pad:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
            pad:EnableMouse(false)
            pad:RegisterForClicks("AnyUp", "AnyDown")
            pad:SetAttribute("useOnKeyDown", false)
            pad:SetAttribute("type", "click")
            linePads[key] = pad
        end
        if pad.tab ~= tab then
            pad:SetAttribute("clickbutton", tab)
            pad.tab = tab
        end
        return name
    end

    -- A pad over one of the book's own controls. Its click is the secure
    -- write; out of a fight the control's own click then runs as it
    -- always did, and sets everything plainly.
    -- The write itself is on a twin with a name of its own, and the pad
    -- runs a macro that presses the twin: a macro is the one thing that
    -- will do two secure things from one click, and the second is the
    -- press of the client's own tab (see ArmTabs).
    local padCount = 0
    local function NewPad(parent, over, width, height, enter)
        local pad = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
        padCount = padCount + 1
        pad.twinName = "ForeverClassicUIBookAct" .. padCount
        pad.twin = CreateFrame("Button", pad.twinName, UIParent, "SecureActionButtonTemplate")
        pad.twin:SetSize(1, 1)
        pad.twin:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
        pad.twin:EnableMouse(false)
        pad.twin:RegisterForClicks("AnyUp", "AnyDown")
        pad.twin:SetAttribute("useOnKeyDown", false)
        pad.twin:SetAttribute("attribute-name", "unit")
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
    local function ArmPad(pad, frame, value, alsoName)
        pad.live = frame ~= nil
        pad.twin:SetAttribute("type", frame and "attribute" or nil)
        pad.twin:SetAttribute("attribute-frame", frame)
        pad.twin:SetAttribute("attribute-value", value)
        if frame then
            -- The current container (and this pad with it) is hidden by the
            -- attribute click. Press the client's category tab first; when
            -- the old order hid this pad first, the macro never reached its
            -- second click and the two spellbooks diverged in combat.
            local text
            if alsoName then
                text = "/click " .. alsoName .. "\n/click " .. pad.twinName
            else
                text = "/click " .. pad.twinName
            end
            pad:SetAttribute("type", "macro")
            pad:SetAttribute("macrotext", text)
        else
            pad:SetAttribute("type", nil)
            pad:SetAttribute("macrotext", nil)
        end
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
        -- Each tab of ours turns the client's book to the same skill
        -- line in the same click, so the buttons it lends are the ones
        -- this book is showing.
        local lend = ns.db and ns.db.spellDrag ~= false
        local function TabName(line, bank, key)
            if not lend then return nil end
            local tab = ClientCategoryTab(line, bank)
            if not tab then ghost.tabsWanted = true end
            return tab and LinePad(key, tab) or nil
        end
        for i = 1, MAX_SKILL_TABS do
            local target = player and lines[i] and lineContainer[lines[i]]
            local pad = c.skillPads[i]
            local also = target and lines[i] and TabName(lines[i], Enum.SpellBookSpellBank.Player, "L" .. lines[i]) or nil
            ArmPad(pad, target and holder or nil, target and target.selector or nil, also)
            -- A secure proxy cannot activate this client's category tabs in
            -- combat. When the real tab is available it is already parked
            -- invisibly over the Classic tab, so let the hardware click land
            -- on Blizzard's button itself. FollowClientLine makes the visible
            -- Classic page follow the category Blizzard actually selected.
            pad:EnableMouse(also == nil)
            if f.SkillTabs[i] then f.SkillTabs[i]:EnableMouse(also == nil) end
            pad:SetShown(target and true or false)
        end
        local first = lines[1] and lineContainer[lines[1]]
        ArmPad(c.bookPad, not player and first and holder or nil, first and first.selector or nil,
            (not player and first and lines[1]) and TabName(lines[1], Enum.SpellBookSpellBank.Player, "L" .. lines[1]) or nil)
        c.bookPad:SetShown(not player and first ~= nil)
        ArmPad(c.petPad, player and petContainer and holder or nil, petContainer and petContainer.selector or nil,
            (player and petContainer) and TabName(nil, Enum.SpellBookSpellBank.Pet, "Pet") or nil)
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
            -- A real client category tab may have selected the line. Its
            -- click is the protected one; do not immediately overwrite
            -- that choice with the old secure-container state.
            if ghost.clientChoice then
                ghost.clientChoice = nil
            else
                self.ReadPages()
            end
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
    -- its X. A layer out of sight with the client's window it hangs in
    -- has nothing live to leave, so that book closes.
    if InCombatLockdown() and book:LayerUp() and book:IsShown()
        and book.Clicks and book.Clicks:IsVisible() then return end
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


---------------------------------------------------------------------------
-- Dragging a spell onto the bars during a fight
---------------------------------------------------------------------------
-- Taking a spell onto the cursor is a call the client keeps for itself
-- once a fight is on: ours is refused outright, and the one way round it
-- that other UIs use (a secure drag snippet) cannot be built on this
-- client at all. What the client will do is pick a spell up from its own
-- spellbook button, on a plain drag, in its own name.
--
-- So the client's book is kept open where it cannot be seen, and its
-- spell buttons are laid, unseen, over the buttons of ours that hold the
-- same spells. The book the player looks at is still this one; the drag
-- they begin is the client's own.
--
-- Nothing of the client's book is ever set from here. A field of its own
-- written by an addon is refused the fight's secret values ever after,
-- which would block the very call this is for, so the book is opened by
-- the client's own micro button (the key and the button both go through
-- a macro that presses it, see LinkLayer) and every button is asked
-- whether it is still the client's before it is used.
local GHOST_X = 4000

-- One line in the development log for each turn this takes, and only
-- when it turns.
local function Note(line)
    if ghost.said == line then return end
    ghost.said = line
    ns.Persist("spelldrag: " .. line)
end

local function DragOn()
    return active and ns.db and ns.db.spellDrag ~= false
end
ns.SpellBookLendsButtons = DragOn

local function GhostWindow() return _G["PlayerSpellsFrame"] end

local function GhostBook()
    local window = GhostWindow()
    return window and window.SpellBookFrame
end

-- Everything of the client's window that answers the mouse, hushed. It
-- stands 809 by 720, and the client's own window manager puts it back on
-- the screen whenever it lays its panels out, where it cannot be moved
-- again during a fight: unseen but listening, it swallowed a right click
-- meant for the ground. Its spell buttons are left alone; they are the
-- whole point, and they hang on the screen of their own anyway.
local function Deafen(window)
    -- Never during a fight: the window is the client's own, and turning
    -- the mouse off on one of its frames there is refused outright.
    if InCombatLockdown() then return end
    local client = window.SpellBookFrame
    local skip = client and client.PagedSpellsFrame
    local skipTabs = client and client.CategoryTabSystem
    local hushed = ghost.hushed
    if not hushed then
        hushed = {}
        ghost.hushed = hushed
    end
    local function Walk(frame)
        -- The spell buttons and category tabs are both pressed through
        -- secure click actions. Muting either makes only the category the
        -- client already had selected usable during combat.
        if frame == skip or frame == skipTabs then return end
        -- Our casting layer hangs in the client's book (see NestLayer).
        if book and frame == book.Clicks then return end
        if frame.IsMouseEnabled and frame:IsMouseEnabled() then
            hushed[#hushed + 1] = frame
            frame:EnableMouse(false)
        end
        if frame.GetChildren then
            for _, child in ipairs({ frame:GetChildren() }) do Walk(child) end
        end
    end
    Walk(window)
end

local function Unhush()
    if InCombatLockdown() then return end
    for _, frame in ipairs(ghost.hushed or {}) do
        if frame.EnableMouse then pcall(frame.EnableMouse, frame, true) end
    end
    ghost.hushed = nil
end

-- Off the screen's right edge, unseen and deaf. Only its spell buttons
-- are wanted, and those are laid over this book by hand below.
local function QuietGhost(window)
    if window:GetAlpha() ~= 0 then window:SetAlpha(0) end
    if InCombatLockdown() then return end
    -- Its new pieces are hushed as they appear, a few times a second.
    local now = GetTime()
    if now - (ghost.hushAt or 0) > 0.3 then
        ghost.hushAt = now
        Deafen(window)
    end
    pcall(window.SetAttribute, window, "UIPanelLayout-width", 1)
    local point, _, _, x = window:GetPoint(1)
    if window:GetNumPoints() ~= 1 or point ~= "TOPLEFT" or x ~= GHOST_X then
        window:ClearAllPoints()
        window:SetPoint("TOPLEFT", UIParent, "TOPRIGHT", GHOST_X, 0)
    end
end

-- The client's spell buttons by slot, and only the ones whose own fields
-- no addon has written.
local function GhostItems()
    local client = GhostBook()
    local paged = client and client:IsShown() and client.PagedSpellsFrame
    if not paged or not paged.EnumerateFrames then return nil end
    local map, items, any, total, marked = {}, {}, false, 0, 0
    for _, item in paged:EnumerateFrames() do
        if item.HasValidData and item:HasValidData() and item.Button and item.slotIndex then
            total = total + 1
            items[#items + 1] = item
            if issecurevariable(item, "slotIndex") and issecurevariable(item, "spellBank") then
                map[item.slotIndex .. ":" .. tostring(item.spellBank)] = item
                any = true
            else
                marked = marked + 1
            end
        end
    end
    if not any then Note("the client book holds " .. total .. " buttons, " .. marked .. " of them marked by an addon") end
    return any and map or nil, #items > 0 and items or nil
end

-- The proxy clicks used for the client's category tabs are not honored by
-- this client during combat. Put the real, invisible client tab buttons on
-- the Classic book's tabs instead. The user still sees and uses only the
-- Classic book, but the hardware click now reaches Blizzard's own button.
local function UnparkTabs()
    if InCombatLockdown() then return end
    local system = ghost.tabSystem
    if system then
        system.frame:SetShown(system.shown)
        system.frame:SetAlpha(system.alpha)
        system.frame:EnableMouse(system.mouse)
        if system.clips ~= nil and system.frame.SetClipsChildren then
            system.frame:SetClipsChildren(system.clips)
        end
        system.frame:SetParent(system.parent)
        system.frame:ClearAllPoints()
        for _, point in ipairs(system.points) do
            system.frame:SetPoint(point[1], point[2], point[3], point[4], point[5])
        end
        if #system.points == 0 then system.frame:SetSize(system.width, system.height) end
        system.frame:SetFrameStrata(system.strata)
        system.frame:SetFrameLevel(system.level)
        ghost.tabSystem = nil
    end
    for tab, kept in pairs(ghost.tabPoints or {}) do
        tab:SetAlpha(kept.alpha or 1)
        tab:SetFrameStrata(kept.strata)
        tab:SetFrameLevel(kept.level)
        tab:EnableMouse(kept.mouse)
        tab:ClearAllPoints()
        if kept.point then tab:SetPoint(kept.point, kept.rel, kept.relPoint, kept.x, kept.y) end
        ghost.tabPoints[tab] = nil
    end
end

local function ParkTabs()
    -- Prepared while both books are still hidden, before combat. The client
    -- spellbook ancestor keeps these tabs non-interactive until the hardware
    -- click opens both books; by then their protected positions already exist.
    if not book or not DragOn() then return UnparkTabs() end
    local client = GhostBook()
    local tabs = client and client.CategoryTabSystem
    if not tabs or not client.categoryMixins then return end
    if not ghost.tabSystem or ghost.tabSystem.frame ~= tabs then
        local points = {}
        for index = 1, tabs:GetNumPoints() do
            points[index] = { tabs:GetPoint(index) }
        end
        ghost.tabSystem = {
            frame = tabs,
            parent = tabs:GetParent(),
            points = points,
            width = tabs:GetWidth(),
            height = tabs:GetHeight(),
            shown = tabs:IsShown(),
            alpha = tabs:GetAlpha(),
            mouse = tabs:IsMouseEnabled(),
            clips = tabs.DoesClipChildren and tabs:DoesClipChildren() or nil,
            strata = tabs:GetFrameStrata(),
            level = tabs:GetFrameLevel(),
        }
    end
    -- The hidden PlayerSpellsFrame ancestor still wins the hit-test ordering
    -- even when this child reports a high strata. Keep the real tabs parented
    -- to their real tab system, but move that whole system to UIParent so the
    -- complete button can sit above the Classic book.
    if tabs:GetParent() ~= UIParent then
        tabs:SetParent(UIParent)
        tabs:ClearAllPoints()
        tabs:SetAllPoints(UIParent)
    end
    if tabs.SetClipsChildren then tabs:SetClipsChildren(false) end
    tabs:SetAlpha(0)
    tabs:EnableMouse(false)
    tabs:SetShown(book:IsShown())
    tabs:SetFrameStrata("FULLSCREEN_DIALOG")
    tabs:SetFrameLevel(book:GetFrameLevel() + 90)
    -- Skill-line data can finish loading after the hidden book was built.
    -- Refresh the actual visible-tab identities while changes are still
    -- legal; their order is not guaranteed to match the page-build list.
    if not InCombatLockdown() and book.UpdateSkillTabs then book:UpdateSkillTabs() end
    ghost.tabPoints = ghost.tabPoints or {}
    local present = {}
    for _, category in ipairs(client.categoryMixins) do
        local line = category.skillLineIndex
        local tabID = category.GetTabID and category:GetTabID()
        local tab = tabID and tabs:GetTabButton(tabID)
        local target
        if line then
            for _, drawn in ipairs(book.SkillTabs or {}) do
                if drawn.line == line then target = drawn break end
            end
        end
        if tab and target then
            present[tab] = true
            if not ghost.tabPoints[tab] then
                local point, rel, relPoint, x, y = tab:GetPoint(1)
                ghost.tabPoints[tab] = { point = point, rel = rel, relPoint = relPoint, x = x, y = y,
                    alpha = tab:GetAlpha(), strata = tab:GetFrameStrata(), level = tab:GetFrameLevel(),
                    mouse = tab:IsMouseEnabled() }
            end
            tab:SetAlpha(0)
            tab:SetFrameStrata("FULLSCREEN_DIALOG")
            tab:SetFrameLevel(book:GetFrameLevel() + 100)
            tab:EnableMouse(true)
            tab:ClearAllPoints()
            tab:SetPoint("CENTER", target, "CENTER", 0, 0)
        end
    end
    if not InCombatLockdown() then
        for tab in pairs(ghost.tabPoints) do
            if not present[tab] then
                local kept = ghost.tabPoints[tab]
                tab:SetAlpha(kept.alpha or 1)
                tab:SetFrameStrata(kept.strata)
                tab:SetFrameLevel(kept.level)
                tab:EnableMouse(kept.mouse)
                tab:ClearAllPoints()
                if kept.point then tab:SetPoint(kept.point, kept.rel, kept.relPoint, kept.x, kept.y) end
                ghost.tabPoints[tab] = nil
            end
        end
    end
end

local function FollowClientLine()
    local client = GhostBook()
    if not client or not client:IsShown() or not client.GetActiveCategoryMixin then return end
    local category = client:GetActiveCategoryMixin()
    local line = category and category.skillLineIndex
    if not line or ghost.clientLine == line then return end
    ghost.clientLine = line
    if state.bank == BANK_PLAYER and state.line ~= line then
        state.line = line
        state.search = ""
        SetPage(1)
        ghost.clientChoice = true
        if book and book:IsShown() then book:Refresh() end
    end
end

local function RememberItem(item)
    if not ghost.points[item] then
        local point, rel, relPoint, x, y = item:GetPoint(1)
        ghost.points[item] = { point = point, rel = rel, relPoint = relPoint, x = x, y = y,
            parent = item:GetParent(), alpha = item:GetAlpha(),
            scale = item:GetScale() or 1, strata = item:GetFrameStrata() }
    end
    -- Kept on UIParent so the hidden client's scroll frame cannot clip a
    -- borrowed button. The client's pool reparents some rows when a category
    -- changes, including during combat, so this is deliberately enforced on
    -- every pass rather than only the first time the row is seen.
    if item:GetParent() ~= UIParent then
        item:SetParent(UIParent)
        ghost.at[item] = nil
    end
    -- Alpha hides its art without disabling its mouse.
    if item:GetAlpha() ~= 0 then item:SetAlpha(0) end
    if item:GetFrameStrata() ~= "FULLSCREEN_DIALOG" then item:SetFrameStrata("FULLSCREEN_DIALOG") end
end

local function Unpark(item)
    local kept = ghost.points[item]
    if not kept then return end
    ghost.points[item] = nil
    ghost.at[item] = nil
    if kept.parent then item:SetParent(kept.parent) end
    item:SetAlpha(kept.alpha or 1)
    item:SetFrameStrata(kept.strata)
    item:SetScale(kept.scale)
    item:ClearAllPoints()
    if kept.point then item:SetPoint(kept.point, kept.rel, kept.relPoint, kept.x, kept.y) end
end

local function UnparkAll()
    for item in pairs(ghost.points) do Unpark(item) end
end

-- Each of the client's buttons over ours: its own size, in the same
-- place, above the book so the drag begins on it. It keeps its parent,
-- which is the unseen window, so it is drawn at that window's nothing.
local function ParkGhost()
    if not book or not book:IsShown() or not DragOn() then return UnparkAll() end
    local map, items = GhostItems()
    if not items then return UnparkAll() end
    map = map or {}
    local taken, present, laid, none = {}, {}, 0, 0
    for _, item in ipairs(items) do
        present[item] = true
        RememberItem(item)
    end
    for _, btn in ipairs(book.Buttons or {}) do
        local item = btn.slot and btn:IsVisible() and map[btn.slot .. ":" .. tostring(state.bank)]
        if btn.slot and btn:IsVisible() then
            if item then laid = laid + 1 else none = none + 1 end
        end
        if item then
            taken[item] = true
            local face = item.Button
            local want = (btn:GetWidth() or 0) * btn:GetEffectiveScale()
            local have = (face:GetWidth() or 0) * face:GetEffectiveScale()
            if want > 0 and have > 0 and math.abs(want - have) > 0.5 then
                item:SetScale((item:GetScale() or 1) * want / have)
            end
            -- Stood on ours, then read back and nudged: the two hang from
            -- different frames at different sizes, and one pass of
            -- arithmetic on numbers that are not drawn yet lands short.
            local at = ghost.at[item]
            if not at or at.btn ~= btn then
                ghost.at[item] = { btn = btn, x = 0, y = 0 }
                item:ClearAllPoints()
                item:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
            else
                local scale = item:GetEffectiveScale()
                if scale and scale > 0 and face:GetLeft() and btn:GetLeft() then
                    local dx = (btn:GetLeft() * btn:GetEffectiveScale() - face:GetLeft() * face:GetEffectiveScale()) / scale
                    local dy = (btn:GetTop() * btn:GetEffectiveScale() - face:GetTop() * face:GetEffectiveScale()) / scale
                    if math.abs(dx) > 0.2 or math.abs(dy) > 0.2 then
                        at.x, at.y = at.x + dx, at.y + dy
                        item:ClearAllPoints()
                        item:SetPoint("TOPLEFT", btn, "TOPLEFT", at.x, at.y)
                    end
                end
            end
        end
    end
    -- Active client buttons that this page does not borrow must not remain
    -- invisibly over the middle of the screen. Park them off-screen while
    -- leaving their mouse state alone, so a later tab can still borrow them.
    for _, item in ipairs(items) do
        if not taken[item] then
            local kept = ghost.points[item]
            item:SetScale(kept.scale)
            ghost.at[item] = nil
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", UIParent, "TOPRIGHT", GHOST_X, 0)
        end
    end
    for item in pairs(ghost.points) do
        if not present[item] then Unpark(item) end
    end
    Note("lent " .. laid .. " of " .. (laid + none) .. " spells, bank " .. tostring(state.bank))
end

-- What the pads over the book's X and Professions tab press, and what the
-- spellbook key's macro says. Set out of a fight, as the layer moves.
local function ArmPads()
    if InCombatLockdown() or not book then return end
    local toggle = _G["ForeverClassicUISpellBookBind"]
    local clicks = book.Clicks
    for _, pad in ipairs(book.LayerPads or {}) do
        if ghost.nested and toggle then
            -- The same press as the spellbook key: the layer stays on and
            -- the client's window is toggled shut, taking the layer with it.
            pad:SetAttribute("type", "click")
            pad:SetAttribute("clickbutton", toggle)
        else
            pad:SetAttribute("type", "attribute")
            pad:SetAttribute("attribute-frame", clicks)
            pad:SetAttribute("attribute-name", "unit")
            pad:SetAttribute("attribute-value", "none")
        end
    end
    if toggle and toggle:GetAttribute("type") == "macro" then
        toggle:SetAttribute("macrotext", ClientBookMacro())
    end
end

-- The casting layer hangs in the client's own spellbook while that book
-- is lent, so the client's own Escape, closing its window in its own
-- name, puts the layer out of sight with it, in a fight as well: no key
-- of ours, no list of the client's. The layer keeps the screen's scale
-- whatever the client does to its window's, which it fits to the screen
-- as it opens it, and it keeps its own alpha under the faded window. Its
-- place is still said against the screen (see FollowBook).
local function NestLayer()
    if InCombatLockdown() or not book or not book.Clicks then return end
    local clicks = book.Clicks
    if not clicks.SetIgnoreParentScale or not clicks.SetIgnoreParentAlpha then return end
    local host = DragOn() and GhostBook() or nil
    local parent = host or UIParent
    if clicks:GetParent() ~= parent then
        clicks:SetIgnoreParentScale(host ~= nil)
        clicks:SetIgnoreParentAlpha(host ~= nil)
        clicks:SetParent(parent)
        clicks:SetFrameStrata("HIGH")
    end
    -- Inside the client's window the layer answers the mouse at that
    -- window's height, not its own: the book's X, a plain button of the
    -- book standing higher, took the click meant for the pad over it, and
    -- a fight then brought the book straight back. So the unseen window is
    -- stood above the book while the layer hangs in it, and given back its
    -- own height when it no longer does. Nothing in its chain may cut the
    -- layer to its box either.
    local window = GhostWindow()
    if window then
        if host then
            if not ghost.windowStrata then ghost.windowStrata = window:GetFrameStrata() end
            if window:GetFrameStrata() ~= "HIGH" then window:SetFrameStrata("HIGH") end
            for _, box in ipairs({ host, window }) do
                if box.DoesClipChildren and box:DoesClipChildren() then box:SetClipsChildren(false) end
            end
        elseif ghost.windowStrata then
            window:SetFrameStrata(ghost.windowStrata)
            ghost.windowStrata = nil
        end
    end
    local scale = host and UIParent:GetEffectiveScale() or 1
    if math.abs(clicks:GetScale() - scale) > 0.0001 then clicks:SetScale(scale) end
    local nested = host ~= nil
    -- The pads are made as the layer is wired, which can come after this.
    local pads = book.LayerPads and #book.LayerPads or 0
    if ghost.nested ~= nested or ghost.armed ~= pads then
        if ghost.nested ~= nested then ghost.sawOpen = false end
        ghost.nested = nested
        ghost.armed = pads
        ArmPads()
    end
end

-- The client's window is never opened from here, only kept out of sight
-- while it is up and put away when this book goes.
local function FollowGhost()
    local window = GhostWindow()
    if not window then return end
    local client = GhostBook()
    local live = client ~= nil and client:IsShown()
    NestLayer()
    -- Where the layer hangs in the client's book, that book is the truth:
    -- once it has been up under this book and goes, this book goes too.
    -- That is how the client's own Escape closes it.
    local shown = book and book:IsShown() and not closedInFight
    if ghost.nested and shown then
        if client and client:IsVisible() then
            ghost.sawOpen = true
        elseif ghost.sawOpen then
            ghost.sawOpen = false
            Hide()
        end
    elseif not shown then
        ghost.sawOpen = false
        -- The other way round in a fight: the client's book back up with
        -- the layer still on shows live buttons, so this book comes back
        -- over them.
        if ghost.nested and InCombatLockdown() and book and book:LayerUp()
            and client and client:IsVisible() then
            Show()
        end
    end
    -- Escape is the client's while its window stands behind this book.
    if book then book.fcuiEscSkip = (ghost.nested and ghost.sawOpen) or nil end
    if not DragOn() then
        UnparkAll()
        return
    end
    -- The window need not be open for its category buttons to be prepared.
    -- Repeat out of combat because the client can finish creating categories
    -- a few frames after the module and the Classic book were first built.
    if not InCombatLockdown() then ParkTabs() end
    -- Held at nothing while it is still shut: the client shows it the
    -- moment the micro button is pressed, and a window first faded a
    -- beat later showed itself for that beat.
    if window:GetAlpha() ~= 0 then window:SetAlpha(0) end
    if not window:IsShown() then Note("the client never opened its window") end
    if window:IsShown() and not live then
        -- Standing open on its talents side: somebody else's, left as it
        -- is and given its colour back and its ears back if ours took them.
        UnparkAll()
        Unhush()
        if window:GetAlpha() == 0 then window:SetAlpha(1) end
        return
    end
    if not live then
        UnparkAll()
        return
    end
    QuietGhost(window)
    ParkTabs()
    FollowClientLine()
    local now = GetTime()
    if (not ghost.wired or ghost.tabsWanted) and book and book.BuildPages
        and not InCombatLockdown() and now - (ghost.wiredAt or 0) > 1 then
        -- The client's tabs can only be found once its book is up, and
        -- the pads were armed before that. Armed again while any of
        -- them is still missing, a second apart, since the client makes
        -- them as its book is first shown.
        ghost.wired = true
        ghost.wiredAt = now
        ghost.tabsWanted = false
        ns.SafeCall(book.BuildPages)
    end
    if book and book:IsShown() then
        ParkGhost()
    else
        UnparkAll()
        -- The client's book holds the action bars' empty slots open while
        -- it is up, so it does not stay open behind a closed book.
        if not InCombatLockdown() and HideUIPanel then
            pcall(HideUIPanel, window)
        end
    end
end

local dragWatch
local function StartDragWatch()
    if dragWatch then return end
    dragWatch = CreateFrame("Frame")
    dragWatch:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 0.05 then return end
        self.since = 0
        if not active then return end
        ns.SafeCall(FollowGhost)
    end)
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
    -- With the client's book lending its buttons, this button keeps its
    -- own click: it is the one way into the client's book that leaves no
    -- mark of ours on it. The pad over it (see Apply) is what the player
    -- presses, and the macro behind that pad presses this button again.
    if on and ns.db and ns.db.spellDrag ~= false then
        if microClick then button:SetScript("OnClick", microClick) end
    elseif on then
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

-- What Escape's click carries while the book is up: the write that
-- takes the casting layer down, which no code of ours may do during a
-- fight. Escape (in Widgets) asks for this and sets it out of one; its
-- own code then closes the book, which is an ordinary frame.
function ns.SpellBookEscText()
    if not book or not book.Clicks or not book.Clicks.fcuiLinked then return nil end
    if not book:LayerUp() then return nil end
    -- Hung in the client's book, the layer goes with the client's window
    -- and this book with it (see FollowGhost); a write here would only
    -- leave the book open over a dead layer.
    if ghost.nested then return nil end
    return "/click ForeverClassicUISpellBookLayerOff"
end

-- Escape closing every window of ours at once, as the client's own closes
-- all of its panels on the one press. Out of a fight this book goes too,
-- the client's window after it; in one, only the client's Escape can.
function ns.SpellBookEscClose()
    if not book or not book:IsShown() or not ghost.nested or InCombatLockdown() then return end
    Hide()
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
    if not active or InCombatLockdown() then return end
    SyncClientRanks()
    -- The client fetches its spells window the first time it is wanted,
    -- and a window first wanted during a fight cannot have its mouse
    -- turned off until that fight ends: unseen, it stood in the middle
    -- of the screen taking clicks meant for the ground. It is asked for
    -- and quietened here instead, where there is no fight to stop us.
    -- Loading it does not show it, and this never touches the buttons
    -- the book borrows.
    if C_AddOns and C_AddOns.LoadAddOn and not GhostWindow() then
        pcall(C_AddOns.LoadAddOn, "Blizzard_PlayerSpells")
    end
    local window = GhostWindow()
    if window then ns.SafeCall(Deafen, window) end
    if not book then book = CreateBook() end
    -- Refreshing a hidden Classic book assigns its skill-line tabs. Anchor
    -- the client's corresponding real tabs now, while changing their points
    -- is still legal, rather than discovering them after combat has begun.
    if book then
        ns.SafeCall(book.Refresh, book)
        ns.SafeCall(ParkTabs)
        ns.SafeCall(NestLayer)
    end
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
        -- The macro above has just opened the client's book. It is put
        -- out here, in the same frame, rather than on the next beat of
        -- the watch: a beat is long enough to be seen, and the first
        -- opening of a session makes the window itself, so there is
        -- nothing to have put out beforehand.
        if ns.db and ns.db.spellDrag ~= false then
            local window = _G["PlayerSpellsFrame"]
            if window and window:GetAlpha() ~= 0 then window:SetAlpha(0) end
        end
        local layer = book and book.Clicks
        if layer and layer.fcuiLinked and ghost.nested then
            -- The macro put the layer on and toggled the client's window;
            -- the window says which way, and the layer follows it.
            local client = GhostBook()
            if client and client:IsVisible() then
                ghost.sawOpen = true
                book.fcuiEscSkip = true
                Show()
            else
                ghost.sawOpen = false
                Hide()
            end
        elseif layer and layer.fcuiLinked then
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
    SyncClientRanks()
    TakeOver(true)
    TakeButton(true)
    UpdateBinding()
    -- The micro button's own click is ours and cannot raise the casting
    -- layer in a fight; a secure pad over it presses the button above.
    if ns.MapPad and bindButton then
        ns.MapPad(_G["SpellbookMicroButton"], nil, nil, bindButton, function() return active end)
    end
    StartDragWatch()
    -- Turned on in the middle of a session: the way into the world has
    -- long gone by.
    if IsLoggedIn and IsLoggedIn() then ns.SafeCall(Prebuild) end
end

local function Restore()
    active = false
    SyncClientRanks()
    TakeOver(false)
    TakeButton(false)
    UpdateBinding()
    if book and book:IsShown() then Hide() end
    ns.SafeCall(UnparkAll)
    ns.SafeCall(UnparkTabs)
    ns.SafeCall(Unhush)
    -- The client's own window is its own again.
    local window = GhostWindow()
    if window then window:SetAlpha(1) end
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
    SyncClientRanks()
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
