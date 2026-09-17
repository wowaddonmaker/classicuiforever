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
}

local function CurrentPageKey()
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

-- The slots shown on the selected tab: every known item of the skill line
-- in order, skipping spells the character has not learned yet (1.x never
-- listed those).
local function CollectSlots()
    local slots = state.slots
    wipe(slots)
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
        if itemType ~= ITEM_FUTURE then slots[#slots + 1] = i end
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
        btn:SetAttribute("type1", "flyout")
        btn:SetAttribute("spell", info.actionID)
        btn:SetAttribute("flyoutDirection", "RIGHT")
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
        btn:SetChecked(false)
        btn:Disable()
        btn:GetNormalTexture():SetVertexColor(1, 1, 1)
        ClearAction(btn)
        return
    end
    btn:Enable()
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
        btn:GetNormalTexture():SetVertexColor(0, 0, 0)
        btn.SpellName:SetTextColor(PASSIVE_SPELL_FONT_COLOR:GetRGB())
    else
        btn:GetNormalTexture():SetVertexColor(1, 1, 1)
        btn.SpellName:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
    end
    btn:SetChecked(false)
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

local function CreateSpellButton(parent, id)
    local btn = CreateFrame("CheckButton", "ForeverClassicUISpellButton" .. id, parent, "SecureActionButtonTemplate")
    btn:SetID(id)
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    local column = id > 6 and 1 or 0
    local row = (id - 1) % 6
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", FIRST_X + column * COLUMN_X, FIRST_Y - row * (BUTTON_SIZE + ROW_GAP))

    local empty = btn:CreateTexture(nil, "BACKGROUND")
    ns.SetTex(empty, "sbEmptySlot")
    empty:SetSize(64, 64)
    empty:SetPoint("TOPLEFT", btn, "TOPLEFT", -3, 3)
    btn.EmptySlot = empty

    btn.Icon = btn:CreateTexture(nil, "BORDER")
    btn.Icon:SetAllPoints(btn)
    btn.Icon:Hide()

    btn.SpellName = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    btn.SpellName:SetWidth(103)
    btn.SpellName:SetJustifyH("LEFT")
    btn.SpellName:SetMaxLines(3)
    btn.SpellName:SetPoint("LEFT", btn, "RIGHT", 5, 3)

    btn.SpellSubName = btn:CreateFontString(nil, "ARTWORK", SUB_FONT)
    btn.SpellSubName:SetSize(79, 18)
    btn.SpellSubName:SetJustifyH("LEFT")
    btn.SpellSubName:SetPoint("TOPLEFT", btn.SpellName, "BOTTOMLEFT", 0, -2)

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(btn)

    ns.SetButtonTex(btn, "Normal", "slotNormal")
    local normal = btn:GetNormalTexture()
    normal:SetSize(64, 64)
    normal:ClearAllPoints()
    normal:SetPoint("CENTER", btn, "CENTER", 0, 0)
    ns.SetButtonTex(btn, "Pushed", "slotPushed")
    ns.SetButtonTex(btn, "Highlight", "highlight")
    btn:GetHighlightTexture():SetBlendMode("ADD")
    ns.SetButtonTex(btn, "Checked", "checked")
    btn:GetCheckedTexture():SetBlendMode("ADD")

    btn:RegisterForClicks("AnyUp")
    btn:RegisterForDrag("LeftButton")
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
    -- Registered as a left-side UI panel the way the 1.x book was, so it
    -- stacks beside the character sheet and closes on Escape like any panel.
    f:SetAttribute("UIPanelLayout-defined", true)
    f:SetAttribute("UIPanelLayout-enabled", true)
    f:SetAttribute("UIPanelLayout-area", "left")
    f:SetAttribute("UIPanelLayout-pushable", 1)
    f:SetAttribute("UIPanelLayout-whileDead", true)

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
    f.PageText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -110, 38)

    f.PrevPage = CreatePageButton(f, "sbPrev", -1, 50)
    f.NextPage = CreatePageButton(f, "sbNext", 1, 314)

    f.Close = CreateFrame("Button", nil, f)
    f.Close:SetSize(32, 32)
    f.Close:SetPoint("CENTER", f, "TOPRIGHT", -44, -25)
    ns.SkinCloseButton(f.Close, true)
    f.Close:SetScript("OnClick", function() HideUIPanel(f) end)

    f.Buttons = {}
    for id = 1, SPELLS_PER_PAGE do
        f.Buttons[id] = CreateSpellButton(f, id)
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
    end)
    f:SetScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE)
    end)
    -- Event names differ between clients; a missing one is skipped.
    for _, event in ipairs({ "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE", "SPELL_UPDATE_COOLDOWN", "PLAYER_REGEN_ENABLED", "PET_BAR_UPDATE" }) do
        pcall(f.RegisterEvent, f, event)
    end
    pcall(f.RegisterUnitEvent, f, "UNIT_PET", "player")
    f:SetScript("OnEvent", function(self, event)
        if not self:IsShown() then return end
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

local function Show()
    if not book then book = CreateBook() end
    if PlayerSpellsFrame and PlayerSpellsFrame:IsShown() then HideUIPanel(PlayerSpellsFrame) end
    ShowUIPanel(book)
end

local function Toggle()
    if book and book:IsShown() then
        HideUIPanel(book)
    else
        Show()
    end
end

local originals = {}

local function Wrap(key, replacement)
    if not PlayerSpellsUtil or type(PlayerSpellsUtil[key]) ~= "function" or originals[key] then return end
    local orig = PlayerSpellsUtil[key]
    originals[key] = orig
    PlayerSpellsUtil[key] = function(...)
        if active then
            local handled = replacement(...)
            if handled then return end
        end
        return orig(...)
    end
end

local function Init()
    Wrap("ToggleSpellBookFrame", function() Toggle(); return true end)
    Wrap("OpenToSpellBookTab", function() Show(); return true end)
    Wrap("OpenToSpellBookTabAtSpell", function() Show(); return true end)
    Wrap("OpenToSpellBookTabAtCategory", function() Show(); return true end)
    Wrap("TogglePlayerSpellsFrame", function(suggestedTab, inspectUnit)
        local tabs = PlayerSpellsUtil.FrameTabs
        if inspectUnit or not tabs or suggestedTab ~= tabs.SpellBook then return false end
        Toggle()
        return true
    end)
end

local function Apply()
    active = true
end

local function Restore()
    active = false
    if book and book:IsShown() then HideUIPanel(book) end
end

function ns.ToggleSpellBook()
    if not active then return false end
    Toggle()
    return true
end

ns.RegisterModule("spellBook", { init = Init, apply = Apply, restore = Restore })
