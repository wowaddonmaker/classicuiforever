local _, ns = ...

-- Window around the book (ProfessionsBook.lua): size per face (in a fight the book is drawn past a trade skill sized window),
-- side tabs behind an arrow, the spellbook's foot tabs, book/crafting turns, and the one watcher for book and trade skill.

local T = ns.prof
local Page = T.Page
local Build, PlaceCards, FillRows = T.Build, T.PlaceCards, T.FillRows
local ShowOurs, TightenSpells = T.ShowOurs, T.TightenSpells
local SetShownIf = ns.SetShownIf
local EMPTY = ns.EMPTY

local active = false
local BOOK_W, BOOK_H = 550, 525
local sizeWas

local RAW = { set = "raw" }
local PREV_UP, PREV_DOWN = ns.ART.PAGE_PREV .. "Up", ns.ART.PAGE_PREV .. "Down"
local NEXT_UP, NEXT_DOWN = ns.ART.PAGE_NEXT .. "Up", ns.ART.PAGE_NEXT .. "Down"
local TOGGLE_TIP = { text = function() return TRADE_SKILLS or "Professions" end }
-- Forever's side tabs drawn at the size of our Who and group finder tabs (its 50 px icon to their 32); the column keeps
-- its chain, so it tightens with them.
local PROF_TAB_SCALE = 0.64

-- Book size on the book, the client's on a crafting page; out of combat only (casting buttons).
-- The manager places from its stored size, rechecked per tab, and the client writes 750 back: tell it ours and re-place each time.
-- Read via the registration: the manager's first copy onto the frame overwrites earlier writes.
local function PanelAttr(frame, name)
    local value = frame:GetAttribute("UIPanelLayout-" .. name)
    if value == nil and not frame:GetAttribute("UIPanelLayout-defined") then
        local registered = UIPanelWindows and UIPanelWindows[frame:GetName()]
        value = registered and registered[name]
    end
    return value
end
local function SetPanelAttr(frame, name, value)
    if SetUIPanelAttribute then SetUIPanelAttribute(frame, name, value) else frame:SetAttribute("UIPanelLayout-" .. name, value) end
end

-- The client registers the window 35 in from the left for its own side tabs; ours stand at the usual left edge.
local function TellManager(frame, width, height)
    if not sizeWas.attrs then
        sizeWas.attrs = { PanelAttr(frame, "width"), PanelAttr(frame, "height"), PanelAttr(frame, "xoffset") }
    end
    local wantWidth, wantHeight = width or sizeWas.attrs[1], height or sizeWas.attrs[2]
    local wantX = width and 0 or sizeWas.attrs[3]
    if PanelAttr(frame, "width") == wantWidth and PanelAttr(frame, "height") == wantHeight
        and PanelAttr(frame, "xoffset") == wantX then return end
    SetPanelAttr(frame, "width", wantWidth)
    SetPanelAttr(frame, "height", wantHeight)
    SetPanelAttr(frame, "xoffset", wantX)
    if frame:IsShown() and UpdateUIPanelPositions then pcall(UpdateUIPanelPositions, frame) end
end

-- tellWidth/tellHeight: what the manager is told, when not the size.
local function FitWindow(width, height, tellWidth, tellHeight)
    local frame = ProfessionsFrame
    if not frame or InCombatLockdown() then return false end
    if width then
        if not sizeWas then sizeWas = { frame:GetWidth(), frame:GetHeight() } end
        if math.abs(frame:GetWidth() - width) > 0.5 or math.abs(frame:GetHeight() - height) > 0.5 then
            frame:SetSize(width, height)
        end
        TellManager(frame, tellWidth or width, tellHeight or height)
    elseif sizeWas then
        if math.abs(frame:GetHeight() - sizeWas[2]) > 0.5 then frame:SetHeight(sizeWas[2]) end
        if frame:GetWidth() < sizeWas[1] - 0.5 then frame:SetWidth(sizeWas[1]) end
        TellManager(frame, nil, nil)
    end
    return true
end

-- Enlarge a side tab's icon with the client's numbers: the client does it when
-- marking a tab picked, which our piecewise turn to the book never does.
local function FillTabIcon(tab)
    local icon = tab and tab.Icon
    if not icon then return end
    local extent = tab.interiorExtent or 50
    if math.abs((icon:GetWidth() or 0) - extent) > 0.5 then
        icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
        icon:SetSize(extent, extent)
    end
end

-- fn(tab, a) on the overview tab, then each profession tab; false without the window.
local function EachTab(fn, a)
    local frame = ProfessionsFrame
    if not frame then return false end
    fn(frame.ProfessionsOverviewTab, a)
    for _, tab in ipairs(frame.rightProfessionTabs or EMPTY) do fn(tab, a) end
    return true
end

local function FillTabIcons()
    EachTab(FillTabIcon)
end

-- Side tabs tucked away like the sheet's equipment manager: an arrow under the
-- close button toggles them, saved. The client re-shows them on every open, so
-- they are made transparent and deaf, not hidden.
local tabToggle
local function TabsOpen() return ns.db and ns.db.professionTabs and true or false end

local function SetTabOpen(tab, open)
    if not tab then return end
    -- They cast in the client's name: sized out of combat only.
    if not InCombatLockdown() then ns.SetScaleIf(tab, PROF_TAB_SCALE) end
    ns.SetAlphaIf(tab, open and 1 or 0, 0.01)
    if tab:IsMouseEnabled() ~= open then tab:EnableMouse(open) end
end

-- Forever's tab plate and hover rim are bronze: drained to silver off the theme; the gold selected mark stays.
local TAB_METAL = { "Background", "HighlightTexture" }
local function DrainTab(tab)
    if not tab then return end
    -- Rechecked each pass: art the client resets comes back bronze.
    for i = 1, #TAB_METAL do ns.KeepDrained(tab[TAB_METAL[i]]) end
end

local function DrainTabs()
    return EachTab(DrainTab)
end

local function SyncTabs()
    local frame = ProfessionsFrame
    if not frame then return end
    local open = TabsOpen()
    DrainTabs()
    EachTab(SetTabOpen, open)
    -- Level with the close button: border and pages sit hundreds of levels up and hid a button just above the window.
    if tabToggle then
        local close = frame.CloseButton
        local level = math.min(10000, (close and close:GetFrameLevel() or (frame:GetFrameLevel() + 600)) + 1)
        ns.SetLevelIf(tabToggle, level)
    end
    if tabToggle and tabToggle.open ~= open then
        tabToggle.open = open
        ns.DressStates(tabToggle, open and PREV_UP or NEXT_UP, open and PREV_DOWN or NEXT_DOWN, nil, nil, RAW)
    end
end

local function TabToggle()
    local frame = ProfessionsFrame
    if tabToggle or not frame then return end
    tabToggle = CreateFrame("Button", "ClassicUIForeverProfessionTabsToggle", frame)
    tabToggle:SetSize(24, 24)
    -- Top of the book's right page, under and just inside the close button.
    tabToggle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -15, -28)
    tabToggle:SetFrameLevel(frame:GetFrameLevel() + 40)
    tabToggle:SetHighlightTexture(ns.ART.HILIGHT, "ADD")
    tabToggle:SetScript("OnClick", function()
        ns.db.professionTabs = not TabsOpen()
        SyncTabs()
    end)
    ns.AttachTip(tabToggle, TOGGLE_TIP)
end

-- Turn back to the book piece by piece: calling the window's own code would taint it.
local function BackToBook()
    local frame, page = ProfessionsFrame, Page()
    if not frame or not page or InCombatLockdown() then return false end
    page:Show()
    if frame.CraftingPage then frame.CraftingPage:Hide() end
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    if title and TRADE_SKILLS then title:SetText(TRADE_SKILLS) end
    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    if portrait then portrait:SetTexture("Interface/ICONS/INV_SideTab_Professions_c60") end
    for _, tab in ipairs(frame.rightProfessionTabs or EMPTY) do
        if tab.SelectedTexture then tab.SelectedTexture:Hide() end
    end
    local overview = frame.ProfessionsOverviewTab
    if overview and overview.SelectedTexture then overview.SelectedTexture:Show() end
    return true
end

-- The spellbook's foot tabs in the same spot, so the two windows turn into each
-- other like the old book's pages. On the book page (a crafting page has none);
-- both windows are the client's to show in combat, so no turn there.
local bookTabs
-- Secure pads over the Spellbook and pet tabs, under the client's window so they show and hide with it, in a fight
-- too (a pad on UIParent is placed out of combat only). Anchored to the window, never the tabs: the window turns
-- protected by them, and every write on it here already waits for a fight's end; the tabs stay free.
local bookPads
local function PlaceBookPads()
    local frame = ProfessionsFrame
    if not bookPads or not frame or InCombatLockdown() then return end
    local k, left, bottom = frame:GetEffectiveScale(), frame:GetLeft(), frame:GetBottom()
    if not (k and k > 0 and left and bottom) then return end
    for i, pad in pairs(bookPads) do
        local tab = bookTabs[i]
        local s, tl, tb = tab:GetEffectiveScale(), tab:GetLeft(), tab:GetBottom()
        local shown = tab:IsShown() and s and s > 0 and tl and tb and true or false
        if shown then
            ns.SetPointOnce(pad, "BOTTOMLEFT", frame, "BOTTOMLEFT", (tl * s - left * k) / k, (tb * s - bottom * k) / k)
            pad:SetSize(tab:GetWidth() * s / k, tab:GetHeight() * s / k)
            pad:SetFrameLevel(tab:GetFrameLevel() + 5)
        end
        pad:SetShown(shown)
    end
end

local function BookTabs()
    local frame, page = ProfessionsFrame, Page()
    if not frame or not page or not ns.NewBookTab then return end
    local on = ns.SpellBookActive and ns.SpellBookActive() and true or false
    if not bookTabs then
        if not on then return end
        bookTabs = {}
        for i = 1, 3 do bookTabs[i] = ns.NewBookTab(page, i, bookTabs[i - 1]) end
        -- Tucked under the bottom border like the old foot tabs; at -13 they floated clear of it.
        ns.SetPointOnce(bookTabs[1], "CENTER", frame, "BOTTOMLEFT", 70, -7)
        bookTabs[1]:SetText(SPELLBOOK or "Spellbook")
        bookTabs[2]:SetText(TRADE_SKILLS or "Professions")
        bookTabs[2]:SetEnabled(false)
        for i, tab in ipairs(bookTabs) do
            tab:SetScript("OnClick", function()
                if i == 2 then return end
                if InCombatLockdown() then ns.SayNotInCombat() return end
                PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
                HideUIPanel(frame)
                ns.ShowSpellBookBank(i == 3)
            end)
        end
        -- Each pad presses the spellbook key (its macro closes this window first): the book opens in a fight too.
        -- HIGH: the toplevel window raises itself over a same-strata pad on every click.
        local key = ns.SpellBookBindButton and ns.SpellBookBindButton()
        if key then
            bookPads = {}
            for _, i in ipairs({ 1, 3 }) do
                local tab = bookTabs[i]
                local pad = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate")
                pad:SetFrameStrata("HIGH")
                pad:RegisterForClicks("AnyUp", "AnyDown")
                pad:SetAttribute("useOnKeyDown", false)
                pad:SetAttribute("type", "click")
                pad:SetAttribute("clickbutton", key)
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
                pad:Hide()
                bookPads[i] = pad
            end
        end
    end
    local pet = on and ns.SpellBookPetTitle and ns.SpellBookPetTitle() or nil
    if pet and bookTabs[3]:GetText() ~= pet then bookTabs[3]:SetText(pet) end
    SetShownIf(bookTabs[1], on)
    SetShownIf(bookTabs[2], on)
    SetShownIf(bookTabs[3], on and pet ~= nil)
    PlaceBookPads()
end

-- In a fight the window can't be resized (secure spell buttons), and one written on then can't close till it ends. So a shut
-- window waits at trade skill size and a book opened in a fight is drawn past it: border, title and tabs hang from our shape,
-- which alone is resized, with the chrome's stone copied under the part it adds.
local shape
-- Windows/WindowChrome.lua's cuts for its backing, streaks and title strip.
local GROW_CUTS = {
    backing = { "rockBg", { coords = { 0, 1, 0, 1 } } },
    streaks = { "frameSheet", { vert = false, coords = { 0, 1, 0.671875, 0.9609375 } } },
    titleStrip = { "frameSheet", { vert = false, coords = { 0, 1, 0.2890625, 0.421875 } } },
}

-- Nothing protected may hang from the shape, or it locks in a fight too.
local function GrowReady()
    return shape ~= nil and ns.Safe(shape:IsProtected(), true) == false
end

local function Smaller(frame, width, height)
    return ns.Safe(frame:GetWidth(), width) < width - 0.5 or ns.Safe(frame:GetHeight(), height) < height - 0.5
end

-- Once the window wears our chrome; the shape follows the window until grown.
local function EnsureShape(frame)
    local fcui = frame.fcui
    if shape or not (fcui and fcui.backing) or InCombatLockdown() then return end
    shape = CreateFrame("Frame", nil, frame)
    shape:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    shape:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    shape.grown, shape.art = false, {}
    for key, cut in pairs(GROW_CUTS) do
        local from = fcui[key]
        if from then
            local layer, sublevel = from:GetDrawLayer()
            local tex = ns.TileTex(shape:CreateTexture(nil, layer, nil, sublevel), cut[1], cut[2])
            tex.from = from
            tex:Hide()
            shape.art[#shape.art + 1] = tex
        end
    end
    T.shape = shape
end

-- Anchors on the window moved to the shape; out of combat only, sizes equal then.
local function Rehome(object, frame)
    if not object or ns.Safe(object:IsProtected(), true) then return end
    for i = 1, object:GetNumPoints() do
        local point, rel, relPoint, x, y = object:GetPoint(i)
        if not ns.AnySecret(point, rel, relPoint, x, y) and rel == frame then
            object:SetPoint(point, shape, relPoint, x, y)
        end
    end
end

-- The client's panel manager scales the window to 1 as it shows it (UpdateScaleForFit). Out of combat our windows edit
-- mode puts the size back the frame after; the window is protected (the book tab pads) and a fight refuses that, so
-- the secure openers put it back in their own click, after the client's show.
local sizeWrap
local function RefreshSize()
    local frame = ProfessionsFrame
    if not frame or not sizeWrap or InCombatLockdown() then return end
    sizeWrap:SetFrameRef("prof", frame)
    sizeWrap:SetAttribute("scale", ns.WindowScale and ns.WindowScale("professions") or 1)
end
function ns.ProfessionsSizeWrap(button)
    if not button then return end
    sizeWrap = sizeWrap or CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    SecureHandlerWrapScript(button, "OnClick", sizeWrap, [[ if not down then return nil, "size" end ]], [[
        local f = control:GetFrameRef("prof")
        local s = control:GetAttribute("scale")
        if f and s and f:IsShown() then f:SetScale(s) end
    ]])
    RefreshSize()
end

-- Every pass: chrome dressed late (a window first met in a fight) hangs from the window again.
local function Home(frame)
    if not shape or InCombatLockdown() then return end
    Rehome(frame.NineSlice, frame)
    Rehome(frame.TitleContainer, frame)
    Rehome(frame.ProfessionsOverviewTab, frame)
    Rehome(tabToggle, frame)
    Rehome(bookTabs and bookTabs[1], frame)
    PlaceBookPads()
    RefreshSize()
end

-- A copy takes its stone's points, moved from the window to the shape.
local function Mirror(tex, frame)
    local from = tex.from
    tex:ClearAllPoints()
    for i = 1, from:GetNumPoints() do
        local point, rel, relPoint, x, y = from:GetPoint(i)
        if not ns.AnySecret(point, rel, relPoint, x, y) then
            tex:SetPoint(point, rel == frame and shape or rel, relPoint, x, y)
        end
    end
    tex:SetHeight(ns.Safe(from:GetHeight(), 0))
end

-- Book size on the shape (ours, so free in a fight), solid where it passes the window.
local function Grow(on)
    if not shape then return end
    on = on and active and GrowReady() or false
    if InCombatLockdown() and not GrowReady() then return end
    local frame = ProfessionsFrame
    if on then ns.SetLevelIf(shape, math.max(0, frame:GetFrameLevel() - 1)) end
    if shape.grown == on then return end
    shape.grown = on
    ns.SetPointOnce(shape, "TOPLEFT", frame, "TOPLEFT", 0, 0)
    if on then
        shape:SetSize(BOOK_W, BOOK_H)
    else
        shape:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    end
    shape:EnableMouse(on)
    for _, tex in ipairs(shape.art) do
        if on then Mirror(tex, frame) end
        tex:SetShown(on and tex.from:IsShown())
    end
end

-- Shut: sized for how it may open in a fight, where it can't be resized.
local function SizeShut(watcher, tradeOn)
    if active and tradeOn and GrowReady() then
        -- The manager keeps the book's size: in a fight others stand past a grown book,
        -- and a book's extra width off a trade skill till it ends (a gap, never a cover).
        local width, height = ns.TradeSkillWindowSize()
        FitWindow(width, height, BOOK_W, BOOK_H)
    elseif watcher.bookWhenShut then
        if active then FitWindow(BOOK_W, BOOK_H) end
    elseif tradeOn then
        FitWindow(ns.TradeSkillWindowSize())
    end
end

-- Turn to the crafting page piece by piece: the client turns only when the
-- profession changes, so First Aid, shut, First Aid again left the book up.
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
    for _, tab in ipairs(frame.rightProfessionTabs or EMPTY) do
        if tab.SelectedTexture then tab.SelectedTexture:SetShown(id ~= nil and tab.skillLine == id) end
    end
    return true
end

-- Each client profession tab casts its profession on ProfessionsFrame.Show: the window opened on the last one (in combat at book size,
-- every tab lit). Unregistered: reopening a page isn't needed, as a shut window returns to the book and spells and tabs open trade skills.
local tabsQuieted = false
local function QuietTabs()
    local frame = ProfessionsFrame
    if tabsQuieted or not frame or not (EventRegistry and EventRegistry.UnregisterCallback) then return end
    local tabs = {}
    for _, tab in ipairs(frame.rightProfessionTabs or EMPTY) do tabs[#tabs + 1] = tab end
    if frame.ProfessionsOverviewTab then tabs[#tabs + 1] = frame.ProfessionsOverviewTab end
    if #tabs == 0 then return end
    tabsQuieted = true
    for _, tab in ipairs(tabs) do
        pcall(EventRegistry.UnregisterCallback, EventRegistry, "ProfessionsFrame.Show", tab)
    end
    ns.Persist("professions: " .. #tabs .. " tabs taken off the show list")
end

-- Opened from the spellbook's tab via ShowUIPanel so it shows in the client's
-- name; refused to addons in combat.
function ns.OpenProfessionsBook()
    if InCombatLockdown() then ns.SayNotInCombat() return false end
    if not ProfessionsFrame and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_ProfessionsBook")
        pcall(C_AddOns.LoadAddOn, "Blizzard_Professions")
    end
    local frame = ProfessionsFrame
    if not frame then return false end
    if active then
        QuietTabs()
        -- Book size before it shows: a shut window waits at trade skill size.
        FitWindow(BOOK_W, BOOK_H)
    end
    BackToBook()
    if not frame:IsShown() then ns.ShowPanel(frame) end
    return true
end

-- ADDON_LOADED: the client loaded the window itself (asked early, or a session begun in combat); tabs quieted before it shows.
local WATCH_EVENTS = { "SKILL_LINES_CHANGED", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED", "TRADE_SKILL_SHOW", "ADDON_LOADED" }

-- Watched from a frame of our own, never hooked into the client's page.
local watch

-- The shut gate's one writer (R8): pending asks for full passes while shut until one completes.
local function SetPending(on)
    if not watch then return end
    watch.pending = on
    if on then watch:Show() end
end

-- Our child under the window runs only while it is visible: wakes the sleeping watch on the frame it shows.
local function EnsureOpenHost(frame)
    if watch.openHost or not frame then return end
    watch.openHost = ns.Sched.Attach(frame, { name = "professions.open", every = 0, fn = function()
        if watch:IsShown() then return end
        watch:Show()
        local tick = watch:GetScript("OnUpdate")
        if tick then tick(watch, 0) end
    end })
end

local function NoteShown(w, bookShown)
    local frame = ProfessionsFrame
    ns.Persist(string.format("professions: shown, book %s, %dx%d, placed %s, combat %s, grown %s", tostring(bookShown),
        frame:GetWidth() or 0, frame:GetHeight() or 0, tostring(w.placedNow), tostring(InCombatLockdown()),
        tostring(shape and shape.grown)))
end

-- Lockdown is not yet set while this dispatches: the last out-of-combat chance to size the shut window.
local function FightStart()
    local frame = ProfessionsFrame
    if not frame or frame:IsShown() then return end
    SetPending(true)
    local tick = watch:GetScript("OnUpdate")
    if tick then
        watch.since = 1
        tick(watch, 0)
    end
end

-- Every frame the watch is awake: whether the window is shut, on which face, and the turns that follow.
local function FaceTick(self, now)
    -- Every frame: whether the window is shut, and on which face.
    local shut = ProfessionsFrame and not ProfessionsFrame:IsShown()
    local book = Page()
    -- A face turned (a cast, a tab): full pass now, so size and chrome follow.
    local bookShown = book and book:IsShown() or false
    if bookShown ~= self.bookShown then
        self.bookShown = bookShown
        self.since = 1
        SetPending(true)
    end
    if shut then
        self.shutAt = now
        -- A never-opened window opens on the book, though its page starts hidden.
        local castNow = (now - (self.ownCastAt or 0)) < 3
        local wasBook = self.bookWhenShut
        self.bookWhenShut = (book and book:IsShown() or (not self.everShown and not castNow)) and true or false
        -- Shut on a crafting page, or never opened (preloaded, it came up blank at book size): back to the book for micro button and key.
        -- Not within 3 s of a trade skill opening while shut (castNow): the player's cast shows a beat later and would be lost.
        if active and book and not book:IsShown() and not InCombatLockdown() and not castNow then
            if BackToBook() then
                self.bookWhenShut = true
                ns.Persist("professions: shut window turned to the book")
            end
        end
        -- The shut size follows the opening face.
        if self.bookWhenShut ~= wasBook then SetPending(true) end
    elseif ProfessionsFrame then
        if ns.debugSink and (not self.everShown or self.wasShut) then NoteShown(self, bookShown) end
        self.everShown = true
        self.ownCastAt = nil
    end
    -- Full pass on the frame the window appears, so ours is laid before it draws,
    -- and the frame it shuts, so it has its fight size before one can start.
    if self.wasShut ~= (shut and true or false) then
        self.since = 1
        SetPending(true)
    end
    self.wasShut = shut and true or false
    if self.restoreBook and BackToBook() then self.restoreBook = false end
    -- A profession just asked for, turned to if the client has not.
    if self.wantCraft then
        if now - self.wantCraft > 3 then
            self.wantCraft = nil
        elseif active and ProfessionsFrame and not self.restoreBook and ToCraft() then
            if ProfessionsFrame:IsShown() then self.wantCraft = nil end
        end
    end
    return shut
end

-- The watch itself: the face read every frame awake, the full pass on its gates; asleep while shut and settled.
local placed = false
local function WatchTick(self, elapsed)
    -- GetTime is constant within a frame; read once.
    local now = GetTime()
    local shut = FaceTick(self, now)
    self.since = (self.since or 0) + elapsed
    -- Shut and settled: asleep till an event, the window showing (open host) or a pending pass wakes it.
    if shut and not self.dirty and not self.pending then
        if not self.wantCraft and not self.restoreBook and now - (self.ownCastAt or 0) >= 3 then self:Hide() end
        return
    end
    -- Shut and pending: 2 Hz.
    if self.since < ((shut and not self.dirty) and 0.5 or 0.1) then return end
    self.since = 0
    -- Load the window ourselves, once, out of combat at the first chance: first
    -- loaded in combat it came up as the client's (a session begun in combat has
    -- only its first moments).
    if not ProfessionsFrame and not self.loadTried and not InCombatLockdown()
        and (active or (ns.TradeSkillActive and ns.TradeSkillActive())) then
        if C_AddOns and C_AddOns.LoadAddOn then
            self.loadTried = true
            local okBook, bookLoaded = pcall(C_AddOns.LoadAddOn, "Blizzard_ProfessionsBook")
            local okMain, main = pcall(C_AddOns.LoadAddOn, "Blizzard_Professions")
            if ns.debugSink then
                ns.Persist(string.format("professions: early load book %s/%s main %s/%s frame %s", tostring(okBook),
                    tostring(bookLoaded), tostring(okMain), tostring(main), tostring(ProfessionsFrame ~= nil)))
            end
        end
    end
    local frame = ProfessionsFrame
    local page = Page()
    -- Not loaded yet: asleep till its ADDON_LOADED.
    if not frame or not page then
        if self.loadTried or not active then self:Hide() end
        return
    end
    EnsureOpenHost(frame)
    if active then
        QuietTabs()
        FillTabIcons()
    end
    TabToggle()
    SyncTabs()
    BookTabs()
    -- Size by face: book, trade skill, or the client's own when neither module is on.
    local bookUp = active and page:IsVisible() and true or false
    local crafting = frame.CraftingPage
    local tradeOn = ns.TradeSkillActive and ns.TradeSkillActive()
    local craftUp = not bookUp and tradeOn and crafting and crafting:IsVisible() and true or false
    if active then EnsureShape(frame) end
    Home(frame)
    if bookUp then
        -- Refused in a fight: grown past the window instead.
        FitWindow(BOOK_W, BOOK_H)
        Grow(Smaller(frame, BOOK_W, BOOK_H))
    else
        Grow(false)
        if craftUp then
            FitWindow(ns.TradeSkillWindowSize())
        elseif frame:IsVisible() then
            FitWindow(nil)
        else
            SizeShut(self, tradeOn)
        end
    end
    if ns.ShowTradeSkill then ns.ShowTradeSkill(craftUp) end
    -- Build and place as soon as the window exists, open or not: impossible once combat starts.
    if active then
        if not T.built then Build() end
        if T.built and (self.dirty or not placed) then
            local was = placed
            placed = PlaceCards() or placed
            if placed ~= was and ns.debugSink then ns.Persist("professions: cards placed, combat " .. tostring(InCombatLockdown())) end
            FillRows()
            self.dirty = false
        end
        self.placedNow = placed
        ShowOurs(placed)
        if placed then TightenSpells() end
    end
    SetPending(false)
end

-- Starts the watch; a running one takes a full pass for the module that turned on.
local function StartWatch()
    if watch then
        SetPending(true)
        return
    end
    watch = CreateFrame("Frame")
    T.watch = watch
    ns.RegisterEvents(watch, WATCH_EVENTS)
    -- Opened by micro button or key, the window may turn itself to a profession (the tabs' show casts): a trade skill opening
    -- just after the book showed, no tab pressed, gets the book back. One opened while shut is the player's cast and stays.
    watch:SetScript("OnEvent", function(self, event)
        self:Show()
        if event == "ADDON_LOADED" then
            if active and ProfessionsFrame then QuietTabs() end
            return
        end
        if event == "TRADE_SKILL_SHOW" then
            local frame = ProfessionsFrame
            local now = GetTime()
            -- With the tabs unregistered every trade skill that opens is the player's; only
            -- a window shown before QuietTabs still self-casts, and goes back to the book.
            if not tabsQuieted and frame and frame:IsShown() and active and self.bookWhenShut
                and now - (self.shutAt or 0) < 0.5 then
                self.restoreBook = true
            else
                self.ownCastAt = now
                self.wantCraft = now
                -- Turn, size and dress now, not next tick: the window shows this instant and
                -- stood as the book for that tick.
                if active and frame and ToCraft() then
                    -- The window may not count as shown yet: past the shut gate.
                    SetPending(true)
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
    ns.Sched.OnFrame(watch, { name = "professions.watch", every = 0, fn = function(_, since) WatchTick(watch, since) end })
    local fightStart = CreateFrame("Frame")
    fightStart:RegisterEvent("PLAYER_REGEN_DISABLED")
    fightStart:SetScript("OnEvent", FightStart)
end
ns.StartProfessionsWatch = StartWatch

-- No watcher with both professions modules off, yet the panels chrome still silvers the window: drain its tabs once.
-- PLAYER_REGEN_ENABLED: modules applied in a login fight come up when it ends.
local TAB_DRAIN_EVENTS = { "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }
local tabDrain = CreateFrame("Frame")
ns.RegisterEvents(tabDrain, TAB_DRAIN_EVENTS)
tabDrain:SetScript("OnEvent", function(self)
    if watch or (ns.panels and ns.panels.active and DrainTabs()) then self:UnregisterAllEvents() end
end)

local function Apply()
    active = true
    StartWatch()
    -- Three passes now: load, turn to the book and size, settle.
    local tick = watch and watch:GetScript("OnUpdate")
    if tick then
        for _ = 1, 3 do
            watch.since = 1
            SetPending(true)
            tick(watch, 0)
        end
        watch.since = 1
        SetPending(true)
        if ns.debugSink then
            ns.Persist(string.format("professions: first pass, fight %s, window %s", tostring(InCombatLockdown()), tostring(ProfessionsFrame ~= nil)))
        end
    end
end

local function Restore()
    if not active then return end
    active = false
    ns.needsReload = true
    SetPending(true)
end

ns.RegisterModule("professionsBook", { apply = Apply, restore = Restore })
