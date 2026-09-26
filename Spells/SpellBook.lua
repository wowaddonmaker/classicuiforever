local _, ns = ...

-- 1.x spellbook: parchment book, 12 spells a page in two columns, school tabs
-- on the right, page arrows and book tabs at the foot. Geometry from Classic
-- Era's SpellBookFrame, data from C_SpellBook; secure buttons cast.
-- Replaces the client book (micro button, key, /spellbook); talents stay the client's.

local SPELLS_PER_PAGE = 12
local MAX_SKILL_TABS = 8
local BOOK_W, BOOK_H = 384, 512
local BUTTON_SIZE, COLUMN_X, ROW_GAP = 37, 157, 14
local FIRST_X, FIRST_Y = 34, -85

local BANK_PLAYER = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
local BANK_PET = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet or 1
local ITEM_FUTURE = Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell
local ITEM_FLYOUT = Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout
local ITEM_SPELL = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
local ITEM_NONE = Enum.SpellBookItemType and Enum.SpellBookItemType.None or 0
local GENERAL_LINE = Enum.SpellBookSkillLineIndex and Enum.SpellBookSkillLineIndex.General or 1

local IsSecret = ns.IsSecret

-- Art specs, built once.
local ADD_HL = { add = true }
local SKILL_TAB = { checked = "checked", add = { Highlight = true, Checked = true }, states = { "Highlight", "Checked" } }
local SB_QUARTERS = {
    { key = "sbTopLeft", layer = "BACKGROUND", w = 256, h = 256, point = "TOPLEFT" },
    { key = "sbTopRight", layer = "BACKGROUND", w = 128, h = 256, point = "TOPRIGHT" },
    { key = "sbBotLeft", layer = "BACKGROUND", w = 256, h = 256, point = "BOTTOMLEFT" },
    { key = "sbBotRight", layer = "BACKGROUND", w = 128, h = 256, point = "BOTTOMRIGHT" },
}
local CHECK = ns.ART.CHECK
local RANKS_BOX = { set = "raw", checked = CHECK .. "Check", add = true, hit = { 0, -110, 0, 0 } }

local active = false
local book
-- The follow beat (StartDragWatch); declared here so Show can wake it.
local dragWatch
local ghost = { at = {}, points = {} }
local RANK_CVAR = "ShowAllSpellRanks"
local clientRanks = { held = false }

local function ClientRanksValue()
    return ns.db and ns.db.spellBookTopRank == true and "0" or "1"
end

local function ClientBookMacro()
    -- Nested (NestLayer): the macro only turns the layer on; it shows and hides
    -- with the client's window. On screen, its click toggles it.
    local layer = ghost.nested and "ForeverClassicUISpellBookLayerOn" or "ForeverClassicUISpellBookClicks"
    -- The professions window first: its close is the client's own, so it goes in a fight too (the book takes its slot).
    return "/click ProfessionsFrameCloseButton\n/console " .. RANK_CVAR .. " " .. ClientRanksValue()
        .. "\n/click " .. layer .. "\n/click SpellbookMicroButton"
end

-- The hidden client book must list our ranks, or a lower rank has no client
-- button to borrow in combat.
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

-- Player item info; an entry listed without it is built from its spell, else it would draw blank.
local function ItemInfo(slot, bank)
    local info = C_SpellBook.GetSpellBookItemInfo(slot, bank)
    if info or bank ~= BANK_PLAYER then return info end
    local ok, kind, id = pcall(C_SpellBook.GetSpellBookItemType, slot, bank)
    if not ok or kind == nil or id == nil or IsSecret(kind) or IsSecret(id) or kind ~= ITEM_SPELL then return nil end
    local spell = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
    if not spell or spell.name == nil then return nil end
    local passive = C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(id)
    return { name = spell.name, subName = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id) or "", iconID = spell.iconID,
        actionID = id, spellID = id, itemType = kind, isPassive = not IsSecret(passive) and passive or false, fromSpell = true }
end

-- True if the item's name or rank holds the query; an entry built from its spell matches by that.
local function SpellMatches(index, bank, query)
    local ok, name, sub = pcall(C_SpellBook.GetSpellBookItemName, index, bank)
    if not ok or type(name) ~= "string" or IsSecret(name) then
        local info = ItemInfo(index, bank)
        if not info then return false end
        name, sub = info.name, info.subName
        if type(name) ~= "string" or IsSecret(name) then return false end
    end
    if name:lower():find(query, 1, true) then return true end
    return type(sub) == "string" and not IsSecret(sub) and sub:lower():find(query, 1, true) ~= nil
end

-- Known player items only: future spells (1.x never listed them), flyouts (their spells are listed on their own), empty entries.
local function Listed(slot)
    local info = ItemInfo(slot, BANK_PLAYER)
    if not info then return false end
    local kind, name = info.itemType, info.name
    if kind ~= nil and not IsSecret(kind) and (kind == ITEM_FUTURE or kind == ITEM_FLYOUT or kind == ITEM_NONE) then return false end
    return IsSecret(name) or (type(name) == "string" and name ~= "")
end

local function Pack(...) return select("#", ...), { ... } end

-- Slots of the last TradeSlots read; the client's book has no button for them.
local tradeSlot = {}

-- Trade and profession spells (Poisons, Mining, Smelting...) sit outside every skill line here; 1.x listed them in General.
local function TradeSlots()
    local out, seen = {}, {}
    wipe(tradeSlot)
    if not GetProfessions or not GetProfessionInfo then return out end
    local count, profs = Pack(GetProfessions())
    for i = 1, count do
        local prof = profs[i]
        local numSpells, offset
        if prof and not IsSecret(prof) then numSpells, offset = select(5, GetProfessionInfo(prof)) end
        if type(numSpells) == "number" and type(offset) == "number" and not IsSecret(numSpells) and not IsSecret(offset) then
            for slot = offset + 1, offset + math.max(numSpells, 1) do
                local info = Listed(slot) and ItemInfo(slot, BANK_PLAYER)
                if numSpells == 0 and not (ns.prof and ns.prof.OpensTrade and ns.prof.OpensTrade(info)) then info = nil end
                local id = info and info.actionID
                if id and not IsSecret(id) and not seen[id] then
                    seen[id] = true
                    tradeSlot[slot] = true
                    out[#out + 1] = { slot = slot, id = id }
                end
            end
        end
    end
    return out
end

local function SortKey(slot)
    local ok, name = pcall(C_SpellBook.GetSpellBookItemName, slot, BANK_PLAYER)
    if not ok or IsSecret(name) or type(name) ~= "string" then
        local info = ItemInfo(slot, BANK_PLAYER)
        name = info and info.name
    end
    if IsSecret(name) or type(name) ~= "string" then return nil end
    return name:lower()
end

-- Trade slots into a list: by name among General's (1.x sorted it), else appended; none twice.
local function MergeTrade(slots, query, sorted)
    local trade = TradeSlots()
    if #trade == 0 then return end
    local have, keys = {}, {}
    for i, slot in ipairs(slots) do
        have["s" .. slot] = true
        local info = ItemInfo(slot, BANK_PLAYER)
        local id = info and info.actionID
        if id and not IsSecret(id) then have[id] = true end
        if sorted then keys[i] = SortKey(slot) end
    end
    for _, entry in ipairs(trade) do
        if not have[entry.id] and not have["s" .. entry.slot] and (not query or SpellMatches(entry.slot, BANK_PLAYER, query)) then
            have[entry.id] = true
            local at = #slots + 1
            local key = sorted and SortKey(entry.slot)
            if key then
                for i = 1, #slots do
                    if keys[i] and keys[i] > key then at = i break end
                end
            end
            table.insert(slots, at, entry.slot)
            if sorted then table.insert(keys, at, key or false) end
        end
    end
end

-- Signature of the trade slots, so a skill-up alone rebuilds nothing.
local function TradeSignature()
    local parts = {}
    for i, entry in ipairs(TradeSlots()) do parts[i] = entry.slot .. ":" .. entry.id end
    return table.concat(parts, ",")
end

-- Known items of the selected tab in order (1.x never listed future spells);
-- with a search, the matching known spells of every tab, in tab order.
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
                    if Listed(i) and SpellMatches(i, BANK_PLAYER, query) then
                        slots[#slots + 1] = i
                    end
                end
            end
        end
        MergeTrade(slots, query, false)
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
        if Listed(i) then slots[#slots + 1] = i end
    end
    if state.line == GENERAL_LINE then MergeTrade(slots, nil, true) end
end

-- Optional top-rank fold: the highest of a ranked name keeps its place.
-- Unranked spells never fold: same-named ones differ (bear vs cat).
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

-- CollectSlots for a tab other than the one on screen.
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

-- Player: actionID (the entry's own spell), not the current override, which
-- changes in combat while a secure button keeps what it got out of combat;
-- the client swaps the override in at cast. Pet: actionID is a pet action.
local function CastID(info, bank)
    if (bank or state.bank) == BANK_PET then return info.spellID or info.actionID end
    return info.actionID or info.spellID
end

-- Arms a casting button; out of combat only.
local function ArmSpell(btn, slot, bank)
    local info = slot and ItemInfo(slot, bank)
    btn.slot = info and slot or nil
    btn.bank = bank
    btn.isPassive = info and info.isPassive or nil
    btn.spellOnly = info and info.fromSpell and info.actionID or nil
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
    -- In combat the numbers are secret; the duration object goes to the swirl
    -- unread. The numeric path below is for clients without it.
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
    -- Secret in combat, and passing them back errors: clear until combat ends.
    if IsSecret(info.startTime) or IsSecret(info.duration) or IsSecret(info.modRate) then
        cd:Clear()
        return
    end
    cd:SetCooldown(info.startTime, info.duration, info.modRate)
end

-- Action-bar tint (grey unusable, blue out of mana), in combat only: 1.x drew
-- spells plain out of combat, else a druid's bear spells sat dimmed all day.
local function UpdateUsable(btn)
    local icon = btn.Icon
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

-- Dims a view with no casting buttons behind it (built or searched in combat).
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
    local info = slot and ItemInfo(slot, state.bank)
    btn.slot = slot
    btn.spellOnly = info and info.fromSpell and info.actionID or nil
    if not info then
        btn.slot = nil
        btn.isPassive = nil
        btn.Icon:Hide()
        btn.SpellName:Hide()
        btn.SpellSubName:Hide()
        btn.cooldown:Clear()
        btn.checkedTex:Hide()
        -- No Enable/Disable here: the client refuses it on casting buttons in combat.
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
    -- A client tab picked in combat moves only the drawn book; an entry with no client button to lay over it clicks the old page.
    local unlent = ghost.clientChoice and InCombatLockdown() and state.bank == BANK_PLAYER and (info.fromSpell or tradeSlot[slot])
    DimButton(btn, (not viewLive or unlent) and not info.isPassive)
    UpdateUsable(btn)
    UpdateCooldown(btn)
end

Button_OnEnter = function(self)
    if not self.slot then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.spellOnly then
        GameTooltip:SetSpellByID(self.spellOnly)
    else
        GameTooltip:SetSpellBookItem(self.slot, state.bank)
    end
    GameTooltip:Show()
end

local function Button_OnDragStart(self)
    -- Pickup is protected in combat and no secure type picks up a spell. The
    -- button's own bank covers pages armed ahead.
    if not self.slot or self.isPassive or InCombatLockdown() then return end
    if self.spellOnly and C_Spell.PickupSpell then
        C_Spell.PickupSpell(self.spellOnly)
    else
        C_SpellBook.PickupSpellBookItem(self.slot, self.bank or state.bank)
    end
end

-- Fires on press and release; links on release.
local function Button_PostClick(self, _, down)
    if down or not self.slot then return end
    if IsModifiedClick("CHATLINK") then
        -- Trade link first, as the client does: a profession links its recipe list.
        local bank = self.bank or state.bank
        local ok, link = pcall(C_SpellBook.GetSpellBookItemTradeSkillLink, self.slot, bank)
        if not ok or not link or IsSecret(link) then
            ok, link = pcall(C_SpellBook.GetSpellBookItemLink, self.slot, bank)
        end
        if (not ok or not link) and self.spellOnly then ok, link = pcall(C_Spell.GetSpellLink, self.spellOnly) end
        if ok and link and not IsSecret(link) then ChatEdit_InsertLink(link) end
    end
end

-- A spell is two frames: the visible slot in the book and a casting button on
-- a clear layer above, so the book holds nothing protected and opens in combat.
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

    -- Click target on the layer above its slot.
    local btn = CreateFrame("CheckButton", "ForeverClassicUISpellButton" .. id, clicks, "SecureActionButtonTemplate")
    btn:SetID(id)
    -- Placed by offsets, never anchored to the slot: that protects the slot, and
    -- a book built before combat then could not show during it.
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    btn:SetPoint("TOPLEFT", clicks, "TOPLEFT", FIRST_X + column * COLUMN_X, FIRST_Y - row * (BUTTON_SIZE + ROW_GAP))
    btn.slotFrame = slot
    btn.Icon = icon
    btn.SpellName = name
    btn.SpellSubName = sub
    btn.cooldown = cooldown
    btn.normal = normal
    btn.checkedTex = checked

    ns.DressStates(btn, nil, "slotPushed", nil, "highlight", ADD_HL)

    return btn
end

-- One page's casting button over a book slot (see the pages).
local function CreatePageButton12(layer, id)
    local btn = CreateFrame("Button", nil, layer, "SecureActionButtonTemplate")
    local column = id > 6 and 1 or 0
    local row = (id - 1) % 6
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    btn:SetPoint("TOPLEFT", layer, "TOPLEFT", FIRST_X + column * COLUMN_X, FIRST_Y - row * (BUTTON_SIZE + ROW_GAP))
    ns.DressStates(btn, nil, "slotPushed", nil, "highlight", ADD_HL)
    -- Secure buttons fire on down or up per the key-down cast setting: register both.
    btn:RegisterForClicks("AnyDown", "AnyUp")
    btn:RegisterForDrag("LeftButton")
    -- Cast on release: a press also starts a drag, and key-down cast fired the
    -- spell being picked up. The client reads this ahead of that setting.
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
    ghost.heldLine = nil
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
    ns.DressStates(tab, nil, nil, nil, "highlight", SKILL_TAB)
    tab:SetID(i)
    tab:SetScript("OnClick", SkillTab_OnClick)
    tab:SetScript("OnEnter", SkillTab_OnEnter)
    tab:SetScript("OnLeave", GameTooltip_Hide)
    tab:Hide()
    return tab
end

local function BookTab_OnClick(self)
    -- Opens the professions window, as 1.x's professions page did.
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
    ns.DressStates(tab, "sbTabUnselected", nil, i == 3 and "sbTab3Selected" or "sbTab1Selected", "sbTabHighlight", ADD_HL)
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
    ns.DressStates(btn, key .. "Up", key .. "Down", key .. "Disabled", "mouseHighlight", ADD_HL)
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
    -- Not a UIPanel: the panel manager refuses addon show/hide in combat (the
    -- book stuck open). Escape and placement are ours: the left window slot,
    -- like the classic quest log.
    f.fcuiSlotWidth = 392
    ns.RegisterClassicWindow(f, true)
    ns.db.spellBookPos = nil
    -- Our Escape out of combat: the client's clears the target first, 1.x closed
    -- windows first. Closes like the X: a bare hide in combat leaves the layer up
    -- and the book reopens.
    if ns.CloseOnEscape then ns.CloseOnEscape(f, function() ns.HideSpellBook() end) end
    if GameMenuFrame then
        -- The menu stays open: in combat Escape cannot be taken, so it must still open.
        GameMenuFrame:HookScript("OnShow", function()
            -- Not in combat: the layer is still up there, so the book reopens and flaps.
            if InCombatLockdown() then return end
            if f:IsShown() then
                f:Hide()
            end
        end)
    end

    ns.DressPieces(f, SB_QUARTERS)

    local icon = f:CreateTexture(nil, "ARTWORK")
    ns.SetTex(icon, "sbIcon")
    icon:SetSize(58, 58)
    icon:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    -- Square icon on this client: cut round inside the ring.
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

    -- Search over the right page, across every tab; the X clears it.
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

    -- 1.x rank box: ticked lists every rank; the inverse of spellBookTopRank.
    local ranks = CreateFrame("CheckButton", nil, f)
    ranks:SetSize(22, 22)
    ranks:SetPoint("TOPLEFT", f, "TOPLEFT", 76, -46)
    ns.DressStates(ranks, CHECK .. "Up", CHECK .. "Down", nil, CHECK .. "Highlight", RANKS_BOX)
    local ranksText = ranks:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    ranksText:SetPoint("LEFT", ranks, "RIGHT", 0, 1)
    ranksText:SetText(_G.SHOW_ALL_SPELL_RANKS or "Show all spell ranks")
    ranks:SetScript("OnClick", function(self)
        ns.db.spellBookTopRank = not self:GetChecked()
        PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        if ns.ToggleChanged then ns.ToggleChanged("spellBookTopRank") else f:Refresh() end
    end)
    f.Ranks = ranks

    -- Casting buttons sit on their own layer so the book shows in combat. There
    -- we may not show or hide the layer and secure snippets do not compile here,
    -- so: RegisterUnitWatch shows it for unit "player" and hides it for "none";
    -- its click is the "attribute" action writing "player", and helpbutton
    -- remaps the click to "close" (writes "none") while the unit is friendly.
    -- One click on, the next off. The key and the micro pad click it; the X and
    -- Professions pads write "none"; the book follows. The watch polls at 5 Hz,
    -- so in combat the layer lags up to 0.2 s.
    local clicks = CreateFrame("Button", "ForeverClassicUISpellBookClicks", UIParent, "SecureActionButtonTemplate")
    clicks:EnableMouse(false)
    -- Anchored to UIParent: anchoring to the book would protect the book.
    clicks:SetSize(BOOK_W, BOOK_H)
    clicks:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
    clicks:SetFrameStrata("HIGH")
    clicks:Hide()
    f.Clicks = clicks
    -- Follows the book's slot (it may sit right of the talent window); moved out
    -- of combat only, re-placed at combat end.
    local function FollowBook()
        if InCombatLockdown() and clicks:IsProtected() then return end
        clicks:ClearAllPoints()
        clicks:SetPoint("TOPLEFT", UIParent, "TOPLEFT", f.fcuiSlotX or 0, -104)
    end
    f.OnClassicPlaced = function() FollowBook() end
    -- The layer cannot move in combat: while up, the book keeps its slot and new
    -- windows lay out around it.
    f.LayerUp = function()
        return clicks:GetAttribute("unit") == "player"
    end
    f.fcuiHoldX = function(self)
        if InCombatLockdown() and self:LayerUp() then return self.fcuiSlotX or 0 end
    end
    -- Out of combat: write the attribute and show the layer now, not at the next poll.
    f.SetLayer = function(_, on)
        if InCombatLockdown() then return end
        on = on and true or false
        if clicks.fcuiLinked then clicks:SetAttribute("unit", on and "player" or "none") end
        clicks:SetShown(on)
    end

    -- Named "none" writer for Escape's macro (ns.SpellBookEscText); writes only our layer.
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

    -- Its "player" twin, pressed by the key's macro while nested in the client book.
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

    -- Secure pad over a closing control: writes "none" (the control cannot in
    -- combat), then runs the control's work. Nested, it presses the key instead (ArmPads).
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
        -- No art: the control under it shows the press and glow.
        pad:SetScript("OnMouseDown", function() over:SetButtonState("PUSHED") end)
        pad:SetScript("OnMouseUp", function() over:SetButtonState("NORMAL") end)
        pad:SetScript("OnEnter", function() over:LockHighlight() end)
        pad:SetScript("OnLeave", function() over:UnlockHighlight() end)
        return pad
    end

    -- Attribute writes, so out of combat: once at build or when combat ends.
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
        -- A macro presses both our layer and the client's micro button, which opens
        -- the client book untainted; only a macro does two presses in one click.
        if ns.db and ns.db.spellDrag ~= false then
            toggle:SetAttribute("type", "macro")
            -- Rank CVar set in the same protected click, so the client book's OnShow
            -- builds a draggable button for every rank we show.
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
        -- Wiring and pages deferred by a load in combat happen here.
        LinkLayer()
        if f.Pages and f.Pages.dirty and f.BuildPages then f.BuildPages() end
        FollowBook()
        if f:IsShown() then f:Refresh() end
    end)

    -- Any hide drops the layer: left up, a click on empty ground would cast.
    f:HookScript("OnShow", function(self) self:SetLayer(true) end)
    f:HookScript("OnHide", function(self)
        if not InCombatLockdown() then
            self:SetLayer(false)
        elseif self:LayerUp() and clicks:IsVisible() then
            -- Hidden in combat with the layer live: reshow rather than leave unseen live
            -- buttons (close via key, micro button or X). A layer already out of sight
            -- (client window closed) is harmless; fixed at combat end.
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

    -- What's Training tab: that addon hangs its tab on the client book we
    -- replace, so open its window through its slash command.
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
            -- Docked beside the book once; the player may move it after.
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
    -- Secure buttons keep their spell through combat, so every page of every tab
    -- gets its own twelve, armed out of combat; a combat page turn only changes
    -- which are shown, again via unit watch and "attribute" clicks, one write each:
    --   each tab container watches the holder's "unit" plus its own suffix; the
    --   holder holds "p", "pl", ... and exactly one suffix completes "player",
    --   so one write shows one tab and hides the rest;
    --   a tab's pages stack upward: pages 1..n shown means page n; next shows
    --   n+1, previous hides n.
    -- The book draws whatever is shown, so view and casts never differ. Combat
    -- turns lag up to 0.2 s.
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

    -- Client category tab for a line: it lends only the buttons it shows, so its
    -- tab turns with ours.
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

    -- A named button that presses one of the client's: a macro knows only names.
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

    -- Secure pad over a book control: the write, then (out of combat) the
    -- control's own click. The write sits on a named twin so the pad's macro can
    -- also press the client's tab (ArmTabs) in the same click.
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
            -- Client tab first: the attribute click hides this pad and the macro would
            -- stop before its second click, splitting the two books in combat.
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

    -- Arms a container's tab pads to reach every other container.
    local function ArmTabs(c, lines)
        local player = c.kind ~= "pet"
        -- Each tab also turns the client book to the same line, so it lends what we show.
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
            -- Proxy clicks on client category tabs are ignored in combat: where the real
            -- tab exists it is parked unseen over ours and takes the hardware click;
            -- FollowClientLine turns our page with it.
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
        f.tradeSig = TradeSignature()
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
        -- Last container is dynamic: a search or a tab past the room, filled on demand.
        local dyn = containers[DYNAMIC] or NewContainer(DYNAMIC)
        dyn.kind, dyn.content = "dyn", nil
        pages.lines = lines
        for _, c in pairs(containers) do
            if c.kind then ArmTabs(c, lines) end
        end
        pages.built = true
        -- Match the frames to the book now, so a first open in combat is already right.
        if f.ApplyPages then f.ApplyPages() end
    end

    -- Container for the current state, plus a content key for the dynamic one.
    local function ContainerFor()
        if not pages.built then return nil end
        if state.search ~= "" then return containers[DYNAMIC], "search:" .. tostring(state.bank) .. ":" .. state.search:lower() end
        if state.bank == BANK_PET then return petContainer end
        if lineContainer[state.line] then return lineContainer[state.line] end
        return containers[DYNAMIC], "line:" .. tostring(state.line)
    end

    -- In combat the shown frames drive the book state.
    local function ReadPages()
        if not pages.built then return end
        local current
        for _, c in pairs(containers) do
            if c.kind and c.frame:IsShown() then current = c end
        end
        if not current then return end
        local page = 1
        for i = 1, current.pages or 1 do
            if current.layers[i] and current.layers[i]:IsShown() then page = i end
        end
        -- A client tab pressed in combat set the line (FollowClientLine) without
        -- moving our frames; reading them back at the next refresh (a druid form
        -- change is one) reverted it. Hold the choice until our own controls move the
        -- frames; drop a choice of the shown tab, which drew page 1 over the live page.
        if ghost.clientChoice and current.kind == "line" and state.bank == BANK_PLAYER
            and state.search == "" and current.line == state.line then
            ghost.clientChoice = nil
        end
        local held = ghost.clientChoice
        if held == true then
            ghost.clientChoice = { from = current, page = page }
            return
        elseif held then
            if held.from == current and held.page == page then return end
            ghost.clientChoice = nil
        end
        if current.kind == "line" then
            state.bank, state.line, state.search = BANK_PLAYER, current.line, ""
        elseif current.kind == "pet" then
            state.bank, state.search = BANK_PET, ""
        end
        SetPage(page)
    end

    -- Out of combat the book state drives the frames.
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

    -- A lent client tab turns only the client book and our page in a fight, never our casting frames, which then cast
    -- the old tab's spells. So from a fight's start (still allowed) our tab pads take the clicks; the lent ones are
    -- deafened again at its end.
    local fightHeard = {}
    local function FightTabs(fight)
        if InCombatLockdown() then return end
        if fight then
            for _, c in pairs(containers) do
                for _, pad in ipairs(c.skillPads) do
                    if pad:IsShown() and not pad:IsMouseEnabled() then
                        pad:EnableMouse(true)
                        fightHeard[pad] = true
                    end
                end
            end
        else
            for pad in pairs(fightHeard) do pad:EnableMouse(false) end
            wipe(fightHeard)
        end
        ghost.fight = fight
        local system = ghost.tabSystem
        if fight and system and system.frame:IsShown() then system.frame:Hide() end
    end
    ns.EventFrame({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }, function(_, event)
        FightTabs(event == "PLAYER_REGEN_DISABLED")
    end)

    f:BuildPages()

    f:SetScript("OnMouseWheel", Book_OnMouseWheel)
    -- HookScript: SetScript would wipe the earlier hooks (layer show/hide, the
    -- one-window rule) and the layer stayed up after the book closed.
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
    for _, event in ipairs({ "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE", "SPELL_UPDATE_COOLDOWN", "PLAYER_REGEN_ENABLED", "PET_BAR_UPDATE", "PLAYER_ENTERING_WORLD", "SKILL_LINES_CHANGED" }) do
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
        -- Skill lines change on every skill-up; rebuild only when the trade spells in General do.
        if event == "SKILL_LINES_CHANGED" then
            local sig = TradeSignature()
            if sig == self.tradeSig then return end
            self.tradeSig = sig
        end
        -- Spells changed or combat ended: rebuild, debounced, even when closed so the
        -- buttons are armed before the next combat open.
        if event ~= "PLAYER_REGEN_ENABLED" then self.Pages.dirty = true end
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
        local selectedVisible, heldBack = false, false
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
                    if ghost.heldLine == i then heldBack = true end
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
        -- A line hidden for a moment (a form or stance change) is held and comes back once shown; never in a fight,
        -- where the casting frames alone say which line is up.
        if state.bank == BANK_PLAYER and not InCombatLockdown() then
            local want
            if heldBack and ghost.heldLine ~= state.line then
                want, ghost.heldLine = ghost.heldLine, nil
            elseif not selectedVisible and firstLine then
                ghost.heldLine = ghost.heldLine or state.line
                want = firstLine
            end
            if want then
                state.line = want
                for i = 1, shown do self.SkillTabs[i]:SetChecked(self.SkillTabs[i].line == want) end
            end
        end
    end

    function f:UpdateBookTabs()
        local petCount, token = PetSpellCount()
        -- Spellbook, Professions, then the optional pet tab, so the fixed two keep
        -- their places, as at the professions window's foot.
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
            -- A client tab may have chosen the line; ReadPages holds it until our controls move the frames.
            self.ReadPages()
        else
            -- Out of combat the frames follow the book, so there is no client choice to hold.
            ghost.clientChoice = nil
            if self.Pages.dirty then self:BuildPages() end
        end
        if self.Search then
            -- A search needs pages of its own, which combat forbids.
            pcall(self.Search.SetEnabled, self.Search, not fight)
            if fight and self.Search:HasFocus() then self.Search:ClearFocus() end
        end
        self:UpdateBookTabs()
        self:UpdateSkillTabs()
        -- Show the list the casting buttons were armed from, where there is one.
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

    -- Clamp the page to the pages the list will have.
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

-- Opens in combat like 1.x: the panel manager refuses addons there, so the
-- book shows without it.
local wanted = false
local closedInFight = false
-- The layer follows the book, out of combat only (it holds casting buttons).
local function ShowClicks(on)
    if not book then return end
    book:SetLayer(on and book:IsShown())
end

local function Show()
    -- May build in combat: its frames are plain; casting-layer writes wait for combat end.
    if not book then book = CreateBook() end
    if dragWatch then dragWatch:Wake() end
    -- Leave the client's talents window open: closed from here its close code runs
    -- tainted (see Init). A book faded in combat is restored rather than reopened.
    closedInFight = false
    book:SetAlpha(1)
    -- Nothing protected inside; should that change, defer the open to combat end
    -- instead of a blocked-action error.
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
    -- A tip one of its pieces owns goes now: a book faded in a fight stays shown, so no watch sees it go.
    local ok, owner = pcall(GameTooltip.GetOwner, GameTooltip)
    while ok and type(owner) == "table" do
        if owner == book then
            GameTooltip:Hide()
            break
        end
        ok, owner = pcall(owner.GetParent, owner)
    end
    -- In combat only a secure click can drop the layer, so the book stays over
    -- live buttons (close by key, Escape or X). A nested layer out of sight with
    -- the client window leaves nothing live, so that book closes.
    if InCombatLockdown() and book:LayerUp() and book:IsShown()
        and book.Clicks and book.Clicks:IsVisible() then return end
    ShowClicks(false)
    -- If protected in combat, fade now and hide at combat end (a Hide would be refused).
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
-- Pickup is protected in combat and secure snippets do not compile here, but
-- the client's own spellbook buttons still start a drag in its name. So the
-- client book stays open unseen with its buttons laid over ours: the player
-- sees this book and starts the client's drag.
-- Never write fields on the client book: an addon-written field is denied
-- secret values from then on, breaking that drag. It opens via the client's
-- micro button (a macro, see LinkLayer); each button is checked secure before use.
local GHOST_X = 4000

-- Dev log line on change only; callers gate on ns.debugSink so nothing is
-- built without the dev addon.
local function Note(line)
    if ghost.said == line then return end
    ghost.said = line
    ns.Persist("spelldrag: " .. line)
end

local function DragOn()
    return active and ns.db and ns.db.spellDrag ~= false
end

local function GhostWindow() return _G["PlayerSpellsFrame"] end

local function GhostBook()
    local window = GhostWindow()
    return window and window.SpellBookFrame
end

-- Mouse off on the client window: the panel manager can put the unseen
-- 809x720 window back on screen (immovable in combat) where it ate world
-- right-clicks. Its spell buttons are left alone.
local function Deafen(window)
    -- EnableMouse on client frames is refused in combat.
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
        -- Spell buttons and category tabs take secure clicks; muting either leaves
        -- only the current category usable in combat.
        if frame == skip or frame == skipTabs then return end
        -- Our casting layer hangs in the client's book (NestLayer).
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

-- Off-screen right, transparent and deaf; ParkGhost lays its buttons over ours.
local function QuietGhost(window)
    if window:GetAlpha() ~= 0 then window:SetAlpha(0) end
    if InCombatLockdown() then return end
    -- Re-hush new frames at most every 0.3 s.
    local now = GetTime()
    if now - (ghost.hushAt or 0) > 0.3 then
        ghost.hushAt = now
        Deafen(window)
    end
    -- 1 px wide to the panel manager; relaid out since the first open used full width.
    if window:GetAttribute("UIPanelLayout-width") ~= 1 then
        pcall(window.SetAttribute, window, "UIPanelLayout-width", 1)
        if window:IsShown() and UpdateUIPanelPositions then pcall(UpdateUIPanelPositions) end
    end
    local point, _, _, x = window:GetPoint(1)
    if window:GetNumPoints() ~= 1 or point ~= "TOPLEFT" or x ~= GHOST_X then
        window:ClearAllPoints()
        window:SetPoint("TOPLEFT", UIParent, "TOPRIGHT", GHOST_X, 0)
    end
end

-- Client spell buttons by slot:bank, only those no addon wrote (issecurevariable).
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
    if not any and ns.debugSink then Note("the client book holds " .. total .. " buttons, " .. marked .. " of them marked by an addon") end
    return any and map or nil, #items > 0 and items or nil
end

-- Proxy clicks on client category tabs are ignored in combat, so the real
-- tabs are parked unseen over ours and take the hardware click.
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
    -- Placed before combat while both books are hidden; the client book's ancestor
    -- keeps the tabs deaf until the hardware click opens both.
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
    -- The hidden PlayerSpellsFrame ancestor wins hit tests over a high-strata
    -- child, so the whole tab system moves to UIParent above the classic book.
    if tabs:GetParent() ~= UIParent then
        tabs:SetParent(UIParent)
        tabs:ClearAllPoints()
        tabs:SetAllPoints(UIParent)
    end
    if tabs.SetClipsChildren then tabs:SetClipsChildren(false) end
    tabs:SetAlpha(0)
    tabs:EnableMouse(false)
    -- Put away in a fight: our tab pads take the clicks then (FightTabs).
    tabs:SetShown(book:IsShown() and not ghost.fight)
    tabs:SetFrameStrata("FULLSCREEN_DIALOG")
    tabs:SetFrameLevel(book:GetFrameLevel() + 90)
    -- Skill lines can load after the book was built: refresh our tabs while legal
    -- (their order may differ from the page list).
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

-- A press on one of the client's tabs laid over ours, this last half second (ns.lastMouseDownAt: UI/Escape.lua).
local function PressedClientTab()
    if GetTime() - (ns.lastMouseDownAt or 0) > 0.5 then return false end
    for tab in pairs(ghost.tabPoints or {}) do
        if tab:IsVisible() and tab:IsMouseOver() then return true end
    end
    return false
end

local function FollowClientLine()
    local client = GhostBook()
    if not client or not client:IsShown() or not client.GetActiveCategoryMixin then return end
    local category = client:GetActiveCategoryMixin()
    local line = category and category.skillLineIndex
    if not line or ghost.clientLine == line then return end
    ghost.clientLine = line
    -- Only the player's press: the client jumps to General on its own when a form change rebuilds its book.
    if not PressedClientTab() then return end
    ghost.heldLine = nil
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
    -- On UIParent so the client scroll frame cannot clip it; the client pool
    -- reparents rows on a category change (combat too), so enforced every pass.
    if item:GetParent() ~= UIParent then
        item:SetParent(UIParent)
        ghost.at[item] = nil
    end
    -- Alpha 0 hides the art and keeps the mouse.
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

-- Lay each client button over ours, scaled to match, above the book so the
-- drag starts on it.
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
            -- Anchor, then correct from measured edges: different parents and scales make
            -- one-shot math on undrawn frames land short.
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
    -- Unborrowed live buttons go off-screen (mouse untouched) so a later tab can
    -- still borrow them.
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
    if ns.debugSink then Note("lent " .. laid .. " of " .. (laid + none) .. " spells, bank " .. tostring(state.bank)) end
end

-- Rearms the X/Professions pads and the key's macro as the layer nests or
-- unnests; out of combat.
local function ArmPads()
    if InCombatLockdown() or not book then return end
    local toggle = _G["ForeverClassicUISpellBookBind"]
    local clicks = book.Clicks
    for _, pad in ipairs(book.LayerPads or {}) do
        if ghost.nested and toggle then
            -- Press the key: the client window closes and takes the nested layer with it.
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

-- While lending, the layer nests in the client book so the client's own
-- Escape hides it, in combat too. It ignores parent scale (the client fits
-- its window to the screen) and alpha (faded window); anchors stay on UIParent.
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
    -- Nested, the layer hit-tests at the window's strata: the book's X took the
    -- click meant for its pad and combat reopened the book. So the window is HIGH
    -- while nested and restored after; no ancestor may clip the layer.
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
    -- Pads are made in LinkLayer, which can run after this.
    local pads = book.LayerPads and #book.LayerPads or 0
    if ghost.nested ~= nested or ghost.armed ~= pads then
        if ghost.nested ~= nested then ghost.sawOpen = false end
        ghost.nested = nested
        ghost.armed = pads
        ArmPads()
    end
end

-- Never opens the client window: keeps it unseen while up, closes it when our book goes.
local function FollowGhost()
    local window = GhostWindow()
    if not window then return end
    local client = GhostBook()
    local live = client ~= nil and client:IsShown()
    NestLayer()
    -- Nested, the client book rules: seen open then gone (its Escape) closes ours.
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
        -- In combat the client book back up with the layer on means live buttons:
        -- reshow ours over them.
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
    -- Repark the tabs every pass out of combat: the client may create categories
    -- a few frames after the book.
    if not InCombatLockdown() then ParkTabs() end
    -- Alpha 0 while shut: the micro button shows it instantly and a late fade
    -- flashed it for a frame.
    if window:GetAlpha() ~= 0 then window:SetAlpha(0) end
    if ns.debugSink and not window:IsShown() then Note("the client never opened its window") end
    if window:IsShown() and not live then
        -- Opened on its talents side, not ours: give back its alpha and mouse.
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
        -- Client tabs appear on its first show, after the pads were armed: rearm a
        -- second apart while any is missing.
        ghost.wired = true
        ghost.wiredAt = now
        ghost.tabsWanted = false
        ns.SafeCall(book.BuildPages)
    end
    if book and book:IsShown() then
        ParkGhost()
    else
        UnparkAll()
        -- The client book holds the bars' empty slots open while up; close it with ours.
        if not InCombatLockdown() and HideUIPanel then
            pcall(HideUIPanel, window)
        end
    end
end

-- 2 Hz on the shared driver; 20 Hz from a watcher under either book while it shows, at once on the frame it appears.
local shownAt = setmetatable({}, { __mode = "k" })
local followAt = 0
local function FollowTick()
    if not active then return end
    followAt = GetTime()
    ns.SafeCall(FollowGhost)
end

-- Both books up (nested) share one 20 Hz beat.
local function FollowBeat()
    if GetTime() - followAt >= 0.04 then FollowTick() end
end

local function MarkShown(watch)
    shownAt[watch] = true
    -- The slow beat sleeps while both books are shut; a book showing wakes it.
    if dragWatch then dragWatch:Wake() end
end

local function FirstFrame(job)
    if not shownAt[job.host] then return false end
    shownAt[job.host] = nil
    return true
end

local function FollowUnder(host)
    if not host then return end
    local job, made = ns.Sched.Attach(host, { name = "spellBook.follow", every = 0.05, pre = FirstFrame, fn = FollowBeat })
    if made then job.host:SetScript("OnShow", MarkShown) end
end

-- Either book may be made after the watch: looked for on each slow beat too.
local function WatchBooks()
    FollowUnder(book)
    FollowUnder(GhostWindow())
end

local function StartDragWatch()
    if dragWatch then return end
    -- The full pass while a book is open and once after; then asleep till a book shows (MarkShown).
    local wasOpen = true
    dragWatch = ns.Sched.Job({ name = "spellBook.follow", every = 0.5, fn = function(job)
        WatchBooks()
        local window = GhostWindow()
        local open = (book and book:IsShown()) or (window and window:IsShown()) or false
        if open or wasOpen then
            FollowTick()
        else
            if active and window and DragOn() then ns.SetAlphaIf(window, 0) end
            job:Sleep()
        end
        wasOpen = open
    end })
    -- The client's book loads on demand: its watcher is made as it loads.
    ns.EventFrame("ADDON_LOADED", WatchBooks)
    WatchBooks()
end

-- Combat edges: drop an orphan layer at the start, apply held-back work at the end.
local waiting = CreateFrame("Frame")
waiting:RegisterEvent("PLAYER_REGEN_ENABLED")
waiting:RegisterEvent("PLAYER_REGEN_DISABLED")
waiting:SetScript("OnEvent", function(_, event)
    if not active then return end
    -- Last chance to drop the layer: left up without a book, its unseen buttons
    -- covered the party frames and clicks there cast. Under an open book it stays
    -- and comes down with the book.
    if event == "PLAYER_REGEN_DISABLED" then
        local open = book and book:IsShown() and book:GetAlpha() > 0
        if book and not open then book:SetLayer(false) end
        return
    end
    -- Held back by combat: a close that could only fade, and an open book's layer.
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
        -- Sync the layer: a book closed in combat left it up, catching clicks where
        -- the vendor window opens.
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

-- Called from the client's pass, where a combat show is refused; a frame
-- later the call is plainly ours, allowed for a window the client does not own.
local function Step(fn)
    if InCombatLockdown() and C_Timer and C_Timer.After then
        C_Timer.After(0, fn)
    else
        fn()
    end
end

-- Swap the PlayerSpellsUtil entries only while on, originals back when off:
-- even a pass-through left in the client's call taints all after it, which
-- combat refuses (the key raised a blocked action).
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

-- Off from the start: write nothing. Restoring the original is still our
-- write, after which the client spellbook ran tainted (spell clicks blocked,
-- no empty slots on bars 2-5 when dragging).
local tookOver = false
local function TakeOver(on)
    if not PlayerSpellsUtil then return end
    if on == tookOver then return end
    tookOver = on
    for key, orig in pairs(originals) do
        PlayerSpellsUtil[key] = on and wrapped[key] or orig
    end
end

-- The micro button calls TogglePlayerSpellsFrame (never wrapped, see Init), so
-- its OnClick is swapped instead. The talents button is untouched.
local microClick
local tookButton = false
local function TakeButton(on)
    local button = _G["SpellbookMicroButton"]
    if not button or not button.GetScript then return end
    if on == tookButton then return end
    tookButton = on
    -- Lending: keep the client's click, the only untainted way into its book; our
    -- pad over it (Apply) presses it through a macro.
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
-- The professions key and micro button: our layer down first (our code cannot in a fight), then the client's opener; the
-- book then goes as a client window replaces ours.
local PROF_BIND_NAME = "ForeverClassicUIProfessionsBind"
local PROF_MACRO = "/click ForeverClassicUISpellBookLayerOff\n/click ProfessionMicroButton"
local profBind

-- Spellbook keys override-bound to our button (the client handler can refuse);
-- set out of combat, they hold in it.
local boundKeys = {}
local function UpdateBinding()
    if not bindButton or InCombatLockdown() then return end
    ClearOverrideBindings(bindButton)
    if profBind then ClearOverrideBindings(profBind) end
    wipe(boundKeys)
    if not active then return end
    if profBind then
        for _, k in ipairs({ GetBindingKey("TOGGLEPROFESSIONBOOK") }) do
            SetOverrideBindingClick(profBind, true, k, PROF_BIND_NAME, "LeftButton")
        end
    end
    -- The spellbook's own keys only; the talents key stays the client's.
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

-- Macro for Escape's secure click (Widgets): drops the layer, which our code
-- cannot in combat; Escape's code then hides the book.
function ns.SpellBookEscText()
    if not book or not book.Clicks or not book.Clicks.fcuiLinked then return nil end
    if not book:LayerUp() then return nil end
    -- Nested, the client window takes the layer and FollowGhost closes ours; a
    -- write would leave the book over a dead layer.
    if ghost.nested then return nil end
    return "/click ForeverClassicUISpellBookLayerOff"
end

-- Escape-all out of combat when nested: this book, then the client window; in
-- combat only the client's Escape can.
function ns.SpellBookEscClose()
    if not book or not book:IsShown() or not ghost.nested or InCombatLockdown() then return end
    Hide()
end

-- For the debug print about opening the book in a fight.
function ns.SpellBookBindInfo()
    return string.format("keys %s; book built %s; book protected %s",
        (#boundKeys > 0 and table.concat(boundKeys, ", ") or "none"),
        tostring(book ~= nil),
        tostring(book and book.IsProtected and book:IsProtected()))
end


-- Build before the first open, out of combat (casting buttons made in combat
-- are refused): at world entry, or when a combat that missed it ends.
local function Prebuild()
    if not active or InCombatLockdown() then return end
    SyncClientRanks()
    -- Load and deafen the client window now: first loaded in combat it could not
    -- be muted and ate world clicks. Loading does not show it.
    if C_AddOns and C_AddOns.LoadAddOn and not GhostWindow() then
        pcall(C_AddOns.LoadAddOn, "Blizzard_PlayerSpells")
    end
    local window = GhostWindow()
    if window then ns.SafeCall(Deafen, window) end
    if not book then book = CreateBook() end
    WatchBooks()
    -- The refresh assigns our skill tabs, so park the client tabs now while legal.
    if book then
        ns.SafeCall(book.Refresh, book)
        ns.SafeCall(ParkTabs)
        ns.SafeCall(NestLayer)
    end
end

local function Init()
    -- Key and micro pad click this; it clicks the layer and PostClick follows the
    -- resulting attribute.
    profBind = CreateFrame("Button", PROF_BIND_NAME, UIParent, "SecureActionButtonTemplate")
    profBind:RegisterForClicks("AnyDown", "AnyUp")
    profBind:SetAttribute("useOnKeyDown", false)
    profBind:SetAttribute("type", "macro")
    profBind:SetAttribute("macrotext", PROF_MACRO)
    bindButton = CreateFrame("Button", BIND_NAME, UIParent, "SecureActionButtonTemplate")
    bindButton:RegisterForClicks("AnyDown", "AnyUp")
    bindButton:SetAttribute("useOnKeyDown", false)
    bindButton:SetScript("PostClick", function(_, _, down)
        -- Fires on press and release; acts on release.
        if not active or down then return end
        -- Fade the just-opened client window this frame; waiting for the watch shows
        -- it for a beat (the first open creates it, so no earlier fade).
        if ns.db and ns.db.spellDrag ~= false then
            local window = _G["PlayerSpellsFrame"]
            if window and window:GetAlpha() ~= 0 then window:SetAlpha(0) end
        end
        local layer = book and book.Clicks
        if layer and layer.fcuiLinked and ghost.nested then
            -- The macro toggled the client window; the layer follows its state.
            local client = GhostBook()
            if client and client:IsVisible() then
                ghost.sawOpen = true
                book.fcuiEscSkip = true
                -- Quieted before our open lays windows out.
                if DragOn() then ns.SafeCall(QuietGhost, GhostWindow()) end
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
    -- Never wrap TogglePlayerSpellsFrame: talents open through it too and ran
    -- tainted (refused in combat; their empty-slot note ignored, so dragged spells
    -- raised no empty slots on bars 2-5). The spellbook has its own entries and key.
end

local function Apply()
    active = true
    -- Resume the drag watch paused by Restore.
    if dragWatch then dragWatch:Wake() end
    SyncClientRanks()
    TakeOver(true)
    TakeButton(true)
    UpdateBinding()
    -- The micro button's click cannot raise the layer in combat; a secure pad
    -- over it presses the bind button.
    if ns.MapPad and bindButton then
        ns.MapPad(_G["SpellbookMicroButton"], nil, nil, bindButton, function() return active end)
        ns.MapPad(_G["ProfessionMicroButton"], nil, nil, profBind, function() return active end)
    end
    StartDragWatch()
    -- Enabled mid-session: world entry has passed.
    if IsLoggedIn and IsLoggedIn() then ns.SafeCall(Prebuild) end
end

local function Restore()
    active = false
    -- Pause the drag watch until Apply.
    if dragWatch then dragWatch:Sleep() end
    SyncClientRanks()
    TakeOver(false)
    TakeButton(false)
    UpdateBinding()
    if book and book:IsShown() then Hide() end
    ns.SafeCall(UnparkAll)
    ns.SafeCall(UnparkTabs)
    ns.SafeCall(Unhush)
    -- Give the client window its alpha back.
    local window = GhostWindow()
    if window then window:SetAlpha(1) end
end

-- For the professions window, which carries the same tabs at its foot.
ns.NewBookTab = CreateBookTab
ns.NewSideTab = CreateSkillTab
function ns.SpellBookActive() return active end
function ns.HideSpellBook() Hide() end
-- Nested, only the key's secure press opens the client window the layer hangs in.
function ns.SpellBookBindButton() return bindButton end
function ns.SpellBookKeyWanted() return active and ghost.nested and not (book and book:IsShown()) or false end
-- After that press: the bank on the book it opened; false if none opened.
function ns.SpellBookTurnTo(pet)
    if not (active and book and book:IsShown()) or InCombatLockdown() then return false end
    state.bank = pet and BANK_PET or BANK_PLAYER
    book:Refresh()
    return true
end
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

-- Public API (Core/API.lua): the shown page's button for a spell; out of combat the book's search brings it up first.
local function PageButtonFor(spellID)
    for _, btn in ipairs(book.Buttons) do
        if btn.slot and btn:IsVisible() then
            local info = ItemInfo(btn.slot, state.bank)
            if info and (info.spellID == spellID or info.actionID == spellID) then return btn end
        end
    end
end

-- Public API: the spell a page button shows now, or nil (another frame, an empty slot, the book shut).
function ns.SpellBookButtonSpell(btn)
    if not (active and book and book:IsShown()) or type(btn) ~= "table" or not btn.slot or not btn:IsVisible() then return nil end
    for _, own in ipairs(book.Buttons) do
        if own == btn then
            local info = ItemInfo(btn.slot, state.bank)
            return info and (info.spellID or info.actionID) or nil
        end
    end
    return nil
end

function ns.SpellBookButtonFor(spellID)
    if not (active and book and book:IsShown()) or type(spellID) ~= "number" then return nil end
    local btn = PageButtonFor(spellID)
    if btn or InCombatLockdown() or not book.Search:IsShown() then return btn end
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    if not name then return nil end
    book.Search:SetText(name)
    return PageButtonFor(spellID)
end

function ns.ToggleSpellBook()
    if not active then return false end
    Toggle()
    return true
end

ns.RegisterModule("spellBook", { init = Init, apply = Apply, restore = Restore })

-- Top-rank toggle: recollect.
local function RelistBook()
    SyncClientRanks()
    if not book then return end
    book.Pages.dirty = true
    if not InCombatLockdown() then book:BuildPages() end
    if book:IsShown() and book.Refresh then book:Refresh() end
end
ns.RegisterModule("spellBookTopRank", { apply = RelistBook, restore = RelistBook })

-- Search toggle; off clears any search.
ns.RegisterModule("spellBookSearch", {
    apply = function() if book and book.Search then book.Search:Show() end end,
    restore = function()
        if book and book.Search then
            book.Search:SetText("")
            book.Search:Hide()
        end
    end,
})
