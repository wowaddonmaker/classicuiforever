local _, ns = ...
local L = ns.L

-- The spellbook's foot tabs on the professions book page, with their secure pads (ProfessionsWindow.lua calls these).

local T = ns.prof
local Page = T.Page
local SetShownIf = ns.SetShownIf

-- The spellbook's foot tabs in the same spot, so the two windows turn into each
-- other like the old book's pages. On the book page (a crafting page has none);
-- both windows are the client's to show in combat, so no turn there.
local bookTabs
-- Secure pads over the Spellbook and pet tabs, under the client's window so they show and hide with it, in a fight
-- too (a pad on UIParent is placed out of combat only). Anchored to the window, never the tabs: the window turns
-- protected by them, and every write on it here already waits for a fight's end; the tabs stay free.
local bookPads
-- The small book's tabs on the spellbook's own spots: 61 over its frame's foot is 12 under this window's.
local function TabY() return T.Big() and -7 or -12 end
-- The spellbook's first tab centres (79 wide, 66 narrow) less its border's 12 in from its frame; Collections third.
local WIDE = { x = 67, step = 108, drawn = 100, overlap = -20, hit = 14, slot = { 0, 1, 2 } }
local NARROW = { x = 54, step = 80, drawn = 74, overlap = -48, hit = 27, slot = { 0, 1, 3, 2 } }
local BORDER_W = 338   -- the spellbook's border, 12 to 350
local firstX   -- the first tab's centre as last laid (the row centred when it would stand off to the right)
local function Spec()
    return ns.CollectionsMicroHidden and ns.CollectionsMicroHidden() and NARROW or WIDE
end

-- Shown with its tab inside the window, never by the window: placed while it was shut, a pad went hidden for the fight.
local function PadShown(i)
    local page = Page()
    return bookTabs[i]:IsShown() and page ~= nil and page:IsShown()
end

-- From the tabs' fixed layout, so a shut window places them too. From the window's top: the tabs hang from the shape's
-- foot, a book's height down, and in a fight the shape stands past the window's foot.
local function PlaceBookPads()
    local frame = ProfessionsFrame
    if not bookPads or not frame or InCombatLockdown() then return end
    local k = frame:GetEffectiveScale()
    if not (k and k > 0) then return end
    local hit, spec = ns.BOOK_TAB_HIT, Spec()
    for i, pad in pairs(bookPads) do
        local tab, slot = bookTabs[i], spec.slot[i]
        -- The wide row has no Collections tab
        if not slot then
            pad:Hide()
        else
            local r = tab:GetEffectiveScale() / k
            local w, h = tab:GetWidth(), tab:GetHeight()
            -- The drawn tab only; the sheet's blank margin reached over the window's buttons.
            ns.SetPointOnce(pad, "BOTTOMLEFT", frame, "TOPLEFT", ((firstX or spec.x) + slot * spec.step - w / 2 + spec.hit) * r,
                (TabY() - h / 2 + hit.bottom) * r - T.BookH())
            pad:SetSize((w - 2 * spec.hit) * r, (h - hit.top - hit.bottom) * r)
            pad:SetFrameLevel(tab:GetFrameLevel() + 5)
            pad:SetShown(PadShown(i))
        end
    end
end

T.PlaceBookPads = PlaceBookPads
function T.FirstBookTab() return bookTabs and bookTabs[1] end

-- A crafting page hides the tabs' page under them; the pads, on the window, must follow, out of combat.
function T.SyncBookPads()
    if not bookPads or InCombatLockdown() then return end
    for i, pad in pairs(bookPads) do
        if bookTabs[i] and pad:IsShown() ~= PadShown(i) then
            PlaceBookPads()
            return
        end
    end
end

function T.BookTabs()
    local frame, page = ProfessionsFrame, Page()
    if not frame or not page or not ns.NewBookTab then return end
    local on = ns.SpellBookActive and ns.SpellBookActive() and true or false
    if not bookTabs then
        if not on then return end
        bookTabs = {}
        for i = 1, 4 do bookTabs[i] = ns.NewBookTab(page, i, bookTabs[i - 1]) end
        bookTabs[1]:SetText(SPELLBOOK or "Spellbook")
        bookTabs[4]:SetText(L["SKILL_COLLECTIONS"])
        bookTabs[2]:SetText(TRADE_SKILLS or "Professions")
        bookTabs[2]:SetEnabled(false)
        for i, tab in ipairs(bookTabs) do
            tab:SetScript("OnClick", function()
                if i == 2 then return end
                if i == 4 then
                    if _G.CollectionsMicroButton then _G.CollectionsMicroButton:Click() end
                    return
                end
                if InCombatLockdown() then ns.SayNotInCombat() return end
                PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
                ns.HidePanel(frame)
                ns.ShowSpellBookBank(i == 3)
            end)
        end
        -- Each pad turns the book to its tab (SpellBook's wrap), then presses the spellbook key (its macro closes this
        -- window first): the book opens on that tab in a fight too.
        -- HIGH: the toplevel window raises itself over a same-strata pad on every click.
        local key = ns.SpellBookBindButton and ns.SpellBookBindButton()
        if key then
            bookPads = {}
            for _, i in ipairs({ 1, 3 }) do
                local tab = bookTabs[i]
                local pad = ns.NewFrame("Button", nil, frame, "SecureActionButtonTemplate")
                pad:SetFrameStrata("HIGH")
                pad:RegisterForClicks("AnyUp", "AnyDown")
                pad:SetAttribute("useOnKeyDown", false)
                pad:SetAttribute("type", "click")
                pad:SetAttribute("clickbutton", key)
                if ns.SpellBookTurnPad then ns.SpellBookTurnPad(pad, i == 3) end
                pad:SetScript("PostClick", function(_, _, down)
                    if down or not ns.SpellBookTurnTo(i == 3) then return end
                    PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
                    ns.HidePanel(frame)
                end)
                -- No art: the tab under it shows the press and glow.
                pad:SetScript("OnMouseDown", function() if tab:IsEnabled() then tab:SetButtonState("PUSHED") end end)
                pad:SetScript("OnMouseUp", function() if tab:IsEnabled() then tab:SetButtonState("NORMAL") end end)
                pad:SetScript("OnEnter", function() tab:LockHighlight() end)
                pad:SetScript("OnLeave", function() tab:UnlockHighlight() end)
                -- Shut under the cursor by its own click: no OnLeave comes, so the glow goes here.
                pad:SetScript("OnHide", function()
                    tab:UnlockHighlight()
                    if tab:IsEnabled() then tab:SetButtonState("NORMAL") end
                end)
                pad:Hide()
                bookPads[i] = pad
            end
            -- Collections: the hidden micro button's own click, in a fight too.
            local coll = _G.CollectionsMicroButton
            if coll then
                local tab = bookTabs[4]
                local pad = ns.NewFrame("Button", nil, frame, "SecureActionButtonTemplate")
                pad:SetFrameStrata("HIGH")
                pad:RegisterForClicks("AnyUp", "AnyDown")
                pad:SetAttribute("useOnKeyDown", false)
                pad:SetAttribute("type", "click")
                pad:SetAttribute("clickbutton", coll)
                pad:SetScript("OnMouseDown", function() tab:SetButtonState("PUSHED") end)
                pad:SetScript("OnMouseUp", function() tab:SetButtonState("NORMAL") end)
                pad:SetScript("OnEnter", function() tab:LockHighlight() end)
                pad:SetScript("OnLeave", function() tab:UnlockHighlight() end)
                pad:SetScript("OnHide", function()
                    tab:UnlockHighlight()
                    tab:SetButtonState("NORMAL")
                end)
                pad:Hide()
                bookPads[4] = pad
            end
        end
    end
    -- Tucked under the bottom border like the old foot tabs; at -13 they floated clear of it.
    local spec = Spec()
    local narrow = spec == NARROW
    local order = narrow and { 1, 2, 4, 3 } or { 1, 2, 3 }
    local petUp = on and ns.SpellBookPetTitle and ns.SpellBookPetTitle() ~= nil
    local count = (narrow and 3 or 2) + (petUp and 1 or 0)
    firstX = ns.BalancedTabX(spec.x, spec.drawn, spec.step, count, 0, T.Big() and frame:GetWidth() or BORDER_W)
    for n, i in ipairs(order) do
        local tab = bookTabs[i]
        if n == 1 then
            ns.SetPointOnce(tab, "CENTER", frame, "BOTTOMLEFT", firstX, TabY())
        else
            ns.SetPointOnce(tab, "LEFT", bookTabs[order[n - 1]], "RIGHT", spec.overlap, 0)
        end
        if ns.DressBookTab then ns.DressBookTab(tab, narrow) end
    end
    -- As the spellbook's foot: unpicked tabs under the window's border, the picked one (disabled) over it.
    local slice = frame.NineSlice
    if slice then
        local level = slice:GetFrameLevel()
        for _, tab in ipairs(bookTabs) do ns.SetLevelIf(tab, tab:IsEnabled() and math.max(1, level - 1) or level + 1) end
    end
    local pet = on and ns.SpellBookPetTitle and ns.SpellBookPetTitle() or nil
    if pet and narrow then pet = PET or "Pet" end
    if pet and bookTabs[3]:GetText() ~= pet then bookTabs[3]:SetText(pet) end
    SetShownIf(bookTabs[1], on)
    SetShownIf(bookTabs[2], on)
    SetShownIf(bookTabs[3], on and pet ~= nil)
    SetShownIf(bookTabs[4], on and narrow)
    PlaceBookPads()
end
