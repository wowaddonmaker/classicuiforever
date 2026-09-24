local _, ns = ...

-- Professions window around the book (ProfessionsBook.lua): size per face (in a
-- fight, the book drawn past a trade skill sized window), side tabs tucked behind
-- an arrow, the spellbook's foot tabs, book/crafting turns, and the one watcher
-- driving both the book and trade skill modules.

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

-- Book size while the book is up, the client's own for a crafting page; holds
-- casting buttons, so out of combat only. The panel manager places the window
-- from its stored width/height (750 and the last height seen), rechecked on
-- every profession tab; resized behind its back the window jumped. So tell it
-- our size and re-place, checking each time: the client writes 750 back, and
-- then the next window (the sheet) landed 200 past the book's edge.
-- Read through the client's registration: until the manager first copies it onto
-- the frame, that copy would overwrite anything written before.
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

local function FillTabIcons()
    local frame = ProfessionsFrame
    if not frame then return end
    FillTabIcon(frame.ProfessionsOverviewTab)
    for _, tab in ipairs(frame.rightProfessionTabs or EMPTY) do FillTabIcon(tab) end
end

-- Side tabs tucked away like the sheet's equipment manager: an arrow under the
-- close button toggles them, saved. The client re-shows them on every open, so
-- they are made transparent and deaf, not hidden.
local tabToggle
local function TabsOpen() return ns.db and ns.db.professionTabs and true or false end

local function SetTabOpen(tab, open)
    if not tab then return end
    local alpha = open and 1 or 0
    if math.abs((tab:GetAlpha() or 1) - alpha) > 0.01 then tab:SetAlpha(alpha) end
    if tab:IsMouseEnabled() ~= open then tab:EnableMouse(open) end
end

-- Forever's tab plate and hover rim are bronze: drained to silver off the theme; the gold selected mark stays.
local TAB_METAL = { "Background", "HighlightTexture" }
local tabMetal = setmetatable({}, { __mode = "k" })
local function DrainTab(tab)
    if not tab then return end
    local grey = not ns.BronzeOn()
    for i = 1, #TAB_METAL do
        local tex = tab[TAB_METAL[i]]
        -- Rechecked each pass: art the client resets comes back bronze.
        if tex and tex.SetDesaturated and (not tabMetal[tex]
            or (tex.IsDesaturated and ns.Safe(tex:IsDesaturated(), grey) ~= grey)) then
            tabMetal[tex] = true
            ns.DrainBronze(tex)
        end
    end
end

local function DrainTabs()
    local frame = ProfessionsFrame
    if not frame then return false end
    DrainTab(frame.ProfessionsOverviewTab)
    for _, tab in ipairs(frame.rightProfessionTabs or EMPTY) do DrainTab(tab) end
    return true
end

local function SyncTabs()
    local frame = ProfessionsFrame
    if not frame then return end
    local open = TabsOpen()
    DrainTabs()
    SetTabOpen(frame.ProfessionsOverviewTab, open)
    for _, tab in ipairs(frame.rightProfessionTabs or EMPTY) do SetTabOpen(tab, open) end
    -- Level with the close button: border and pages sit hundreds of levels up and
    -- hid a button just above the window.
    if tabToggle then
        local close = frame.CloseButton
        local level = math.min(10000, (close and close:GetFrameLevel() or (frame:GetFrameLevel() + 600)) + 1)
        if tabToggle:GetFrameLevel() ~= level then tabToggle:SetFrameLevel(level) end
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
        if ns.MirrorSave then ns.MirrorSave() end
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
local function BookTabs()
    local frame, page = ProfessionsFrame, Page()
    if not frame or not page or not ns.NewBookTab then return end
    local on = ns.SpellBookActive and ns.SpellBookActive() and true or false
    if not bookTabs then
        if not on then return end
        bookTabs = {}
        for i = 1, 3 do bookTabs[i] = ns.NewBookTab(page, i, bookTabs[i - 1]) end
        bookTabs[1]:ClearAllPoints()
        -- Tucked under the bottom border like the old foot tabs; at -13 they floated clear of it.
        bookTabs[1]:SetPoint("CENTER", frame, "BOTTOMLEFT", 70, -7)
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
    end
    local pet = on and ns.SpellBookPetTitle and ns.SpellBookPetTitle() or nil
    if pet and bookTabs[3]:GetText() ~= pet then bookTabs[3]:SetText(pet) end
    SetShownIf(bookTabs[1], on)
    SetShownIf(bookTabs[2], on)
    SetShownIf(bookTabs[3], on and pet ~= nil)
end

-- In a fight the window can't be resized (the book's spell buttons are secure)
-- and a window written on then can't be closed till it ends. So a shut window
-- waits at trade skill size, and a book opened in a fight is drawn past it:
-- border, title and tabs hang from this frame of ours, which alone is resized,
-- and the chrome's stone is copied under the part it adds.
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

-- Every pass: chrome dressed late (a window first met in a fight) hangs from the window again.
local function Home(frame)
    if not shape or InCombatLockdown() then return end
    Rehome(frame.NineSlice, frame)
    Rehome(frame.TitleContainer, frame)
    Rehome(frame.ProfessionsOverviewTab, frame)
    Rehome(tabToggle, frame)
    Rehome(bookTabs and bookTabs[1], frame)
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
    shape:ClearAllPoints()
    shape:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
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

-- Each client profession tab casts its profession on ProfessionsFrame.Show, so
-- the window opened on the last one; in combat it came up at book size with
-- every tab lit. Unregister them: reopening a profession's page is not needed
-- (a shut window returns to the book; spells and tabs still open trade skills).
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

-- Watched from a frame of our own, never hooked into the client's page.
local watch
local function StartWatch()
    if watch then return end
    watch = CreateFrame("Frame")
    watch:RegisterEvent("SKILL_LINES_CHANGED")
    watch:RegisterEvent("SPELLS_CHANGED")
    watch:RegisterEvent("PLAYER_REGEN_ENABLED")
    watch:RegisterEvent("TRADE_SKILL_SHOW")
    -- When the client loads the window itself (asked for early, or a session begun
    -- in combat), unregister the tabs before it shows; fine in combat.
    watch:RegisterEvent("ADDON_LOADED")
    -- Opened by micro button or key, the window may turn itself to a profession
    -- (the tabs' show casts); the client refused those casts until our layout
    -- writes stopped tainting sessions. A trade skill opening just after the book
    -- showed, no tab pressed, is that: put the book back. One opened while shut is
    -- the player's cast and stays.
    watch:SetScript("OnEvent", function(self, event)
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
        -- GetTime is constant within a frame; read once.
        local now = GetTime()
        -- Every frame: whether the window is shut, and on which face.
        local shut = ProfessionsFrame and not ProfessionsFrame:IsShown()
        local book = Page()
        -- A face turned (a cast, a tab): full pass now, so size and chrome follow.
        local bookShown = book and book:IsShown() or false
        if bookShown ~= self.bookShown then
            self.bookShown = bookShown
            self.since = 1
        end
        if shut then
            self.shutAt = now
            -- A never-opened window opens on the book, though its page starts hidden.
            local castNow = (now - (self.ownCastAt or 0)) < 3
            self.bookWhenShut = (book and book:IsShown() or (not self.everShown and not castNow)) and true or false
            -- Shut on a crafting page: turn back to the book so micro button and key always
            -- open it. Also before the first open: preloaded by us, it came up as a blank
            -- crafting page at book size. Not within 3 s of a trade skill opening while shut
            -- (castNow): the player's cast shows a beat later and would be lost.
            if active and book and not book:IsShown() and not InCombatLockdown() and not castNow then
                if BackToBook() then
                    self.bookWhenShut = true
                    ns.Persist("professions: shut window turned to the book")
                end
            end
        elseif ProfessionsFrame then
            if ns.debugSink and (not self.everShown or self.wasShut) then
                ns.Persist(string.format("professions: shown, book %s, %dx%d, placed %s, combat %s, grown %s", tostring(bookShown),
                    ProfessionsFrame:GetWidth() or 0, ProfessionsFrame:GetHeight() or 0, tostring(self.placedNow), tostring(InCombatLockdown()),
                    tostring(shape and shape.grown)))
            end
            self.everShown = true
            self.ownCastAt = nil
        end
        -- Full pass on the frame the window appears, so ours is laid before it draws,
        -- and the frame it shuts, so it has its fight size before one can start.
        if self.wasShut ~= (shut and true or false) then self.since = 1 end
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
        -- Shut and idle: only tabs and the opening face to keep, 2 Hz.
        self.since = (self.since or 0) + elapsed
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
        if not frame or not page then return end
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
    end)
end
ns.StartProfessionsWatch = StartWatch

-- No watcher with both professions modules off, yet the panels chrome still silvers the window: drain its tabs once.
local tabDrain = CreateFrame("Frame")
tabDrain:RegisterEvent("ADDON_LOADED")
tabDrain:RegisterEvent("PLAYER_ENTERING_WORLD")
-- Modules applied in a login fight come up when it ends.
tabDrain:RegisterEvent("PLAYER_REGEN_ENABLED")
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
            tick(watch, 0)
        end
        watch.since = 1
        if ns.debugSink then
            ns.Persist(string.format("professions: first pass, fight %s, window %s", tostring(InCombatLockdown()), tostring(ProfessionsFrame ~= nil)))
        end
    end
end

local function Restore()
    if not active then return end
    active = false
    ns.needsReload = true
end

ns.RegisterModule("professionsBook", { apply = Apply, restore = Restore })
