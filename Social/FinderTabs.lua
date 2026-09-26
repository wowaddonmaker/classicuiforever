local _, ns = ...

-- The finder's three side tabs (Create Listing, Group Browser, Who), on both the Who tab and the dressed finder.
-- Pages turn only by the client's own side tabs, lent over ours: our turns taint selectedTab.

local S = ns.social

-- Plain setters: the arrows never swap to bronze copies.
local RAW = { set = "raw" }
local TOGGLE_TIP = { text = function() return _G.LOOKING_FOR_GROUP or _G.GROUP_FINDER or "Group Finder" end }
-- The client's side tab per page, by our tab's index.
local CATCH_KEYS = { "ListingTab", "BrowsingTab" }
-- The client's own who page, which a click on its micro button can reopen.
local WHO_PAGE = 3

-- Built per call: the tab strings are read at build time, not at file load.
local function Entries()
    return {
        { index = 1, icon = "Interface/Icons/INV_Helmet_08", text = _G.LFG_LIST_TAB_1 or "Create Listing" },
        { index = 2, icon = "Interface/Icons/Achievement_General_StayClassy", text = _G.LFG_LIST_TAB_2 or "Group Browser" },
        { who = true, icon = "Interface/Icons/INV_OwlDragonMount", text = _G.LFG_LIST_TAB_3 or WHO or "Who" },
    }
end

-- ns.NewSideTab lives in SpellBook.lua, which loads later: looked up per call. The first tab hangs off anchor.
local function NewFinderTab(parent, i, prev, entry, anchor)
    local side = ns.NewSideTab(parent, i, prev)
    if i == 1 then
        ns.SetPointOnce(side, "TOPLEFT", anchor, "TOPRIGHT", -3, -58)
    end
    side:SetNormalTexture(entry.icon)
    side.tooltip = entry.text
    return side
end

local whoTabs, whoToggle = {}, nil
local finderTabs = {}

---------------------------------------------------------------- the client's tabs over ours

-- index -> our tab the client's lies over, and whether ours is lit for it.
local lent, lit = {}, {}

local function Catcher(index)
    local finder = _G["LFGParentFrame"]
    return finder and finder[CATCH_KEYS[index]]
end

-- Widget calls only: the client's tab keeps its own click, which turns the page in its name.
local function Lend(index, host)
    local catcher = Catcher(index)
    if not catcher or lent[index] == host then return end
    if lent[index] and lit[index] then lent[index]:UnlockHighlight() end
    lent[index], lit[index] = host, false
    catcher:SetParent(host)
    catcher:ClearAllPoints()
    catcher:SetAllPoints(host)
    catcher:SetFrameLevel(host:GetFrameLevel() + 2)
    catcher:SetAlpha(0)
    if not catcher:IsMouseEnabled() then catcher:EnableMouse(true) end
end

-- No finder tabs of ours (groupFinder off): the client's tab goes back to its own place.
local function GiveBack(index, finder)
    local catcher, mine = Catcher(index), lent[index]
    if not catcher or not mine then return end
    if lit[index] then mine:UnlockHighlight() end
    lent[index], lit[index] = nil, false
    catcher:SetParent(finder)
    catcher:ClearAllPoints()
    -- Off the finder's edge, not the first tab, which may still be lent out.
    local below = index == 1 and 0 or (Catcher(1):GetHeight() + 2) * (index - 1)
    catcher:SetPoint("TOPLEFT", finder, "TOPRIGHT", 0, -60 - below)
    catcher:SetFrameLevel(finder:GetFrameLevel() + 1)
    catcher:SetAlpha(1)
end

local RunCatchers
local onFinder = false

-- Over the Who tab's while those show and the finder is shut or hovered there, else the finder's.
local function SyncCatchers()
    local finder = _G["LFGParentFrame"]
    if not finder then return end
    -- Also run while the finder shows: with no finder tabs of ours its tabs must still come home.
    if not onFinder then
        onFinder = true
        RunCatchers(finder, "finder.catchers")
    end
    local up = finder:IsShown()
    for index = 1, #CATCH_KEYS do
        local who = whoTabs[index]
        local onWho = who and who:IsVisible() and (not up or who:IsMouseOver())
        local host = onWho and who or finderTabs[index]
        if host then Lend(index, host) else GiveBack(index, finder) end
        local catcher, mine = Catcher(index), lent[index]
        if catcher and mine then
            local over = catcher:IsVisible() and catcher:IsMouseOver() and true or false
            if over ~= lit[index] then
                lit[index] = over
                if over then mine:LockHighlight() else mine:UnlockHighlight() end
            end
        end
    end
end

-- Runs every frame while parent shows.
function RunCatchers(parent, name)
    ns.Sched.OnFrame(CreateFrame("Frame", nil, parent), { name = name, every = 0, fn = SyncCatchers })
end

---------------------------------------------------------------- opening on a page

-- The client turned its finder under our Who tab's tab: shown on that page in the social window's place.
local pending
local function OpenOnPage()
    local index = pending
    pending = nil
    local finder = _G["LFGParentFrame"]
    if not finder or not index or finder.selectedTab ~= index then return end
    -- In a fight too: shown raw (our Escape closes it); only a locked finder stays shut.
    if not finder:IsShown() and not ns.ShowPanel(finder) then
        ns.SayNotInCombat()
        return
    end
    if FriendsFrame and FriendsFrame:IsShown() then ns.HidePanel(FriendsFrame) end
end

local clickWatch
local function WatchClicks()
    if clickWatch then return end
    clickWatch = ns.EventFrame({ "GLOBAL_MOUSE_UP", "PLAYER_REGEN_ENABLED" }, function(_, event, button)
        -- The finder's code refused to load in a fight: fetched after it, so the client's tab is lent before a click.
        if event == "PLAYER_REGEN_ENABLED" then
            if whoTabs[1] and whoTabs[1]:IsVisible() then S.SyncWhoFinderTabs() end
            return
        end
        if button ~= "LeftButton" then return end
        for index = 1, #CATCH_KEYS do
            local host, catcher = lent[index], Catcher(index)
            if host and host.onWho and catcher and catcher:IsVisible() and catcher:IsMouseOver() then
                -- Next frame: the client's own mouse-up turns the page first.
                pending = index
                ns.Sched.NextFrame("finder.openOnPage", OpenOnPage)
            end
        end
    end)
end

---------------------------------------------------------------- on the Who tab

-- Put away behind a small arrow, as the professions book's are.
local function FinderOpen() return ns.db and ns.db.whoTabs and true or false end

function S.SyncWhoFinderTabs()
    local open = FinderOpen()
    -- The finder's code is fetched as the tabs come out, not at the click.
    if open and ns.WarmGroupFinder then ns.WarmGroupFinder() end
    for _, side in ipairs(whoTabs) do
        side:SetShown(open)
        side:SetChecked(side.who and true or false)
    end
    ns.PanelToggleFace(whoToggle, open, RAW)
    SyncCatchers()
end

-- The third tab is the who list itself; the other two open the client's
-- finder on their page. Parented to the who panel, anchored to host.
function S.BuildWhoFinderTabs(host, panel)
    if whoToggle or not ns.NewSideTab then return end
    for i, entry in ipairs(Entries()) do
        local side = NewFinderTab(panel, i, whoTabs[i - 1], entry, host)
        side.who, side.onWho = entry.who, true
        side:SetScript("OnClick", function(self)
            self:SetChecked(self.who and true or false)
            if self.who then return end
            -- Reached only without the client's tab over ours: in a fight, or before its code loaded.
            if InCombatLockdown() then
                ns.SayNotInCombat()
                return
            end
            if ns.WarmGroupFinder then ns.WarmGroupFinder() end
            local finder = _G["LFGParentFrame"]
            if finder and not finder:IsShown() then
                PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
                ns.ShowPanel(finder)
                if FriendsFrame and FriendsFrame:IsShown() then ns.HidePanel(FriendsFrame) end
            end
        end)
        whoTabs[i] = side
    end
    RunCatchers(panel, "who.catchers")
    WatchClicks()
    whoToggle = ns.PanelToggle(panel, "ClassicUIForeverWhoTabsToggle", 24, "TOPRIGHT", host, "TOPRIGHT", -8, -28,
        panel:GetFrameLevel() + 20, function()
            ns.db.whoTabs = not FinderOpen()
            S.SyncWhoFinderTabs()
        end, TOGGLE_TIP)
    S.SyncWhoFinderTabs()
end

---------------------------------------------------------------- on the finder

function S.BuildFinderSideTabs(parent)
    if #finderTabs > 0 or not ns.NewSideTab then return end
    for i, entry in ipairs(Entries()) do
        local side = NewFinderTab(parent, i, finderTabs[i - 1], entry, parent)
        side.index = entry.index
        side:SetScript("OnClick", function(self)
            if entry.who then
                PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
                self:SetChecked(parent.selectedTab == WHO_PAGE)
                -- Back to the Who tab in this window's place: this one goes first (in a fight too, unless it is locked).
                if ns.HidePanel(parent) then ns.OpenWhoList() end
                return
            end
            -- Under the client's tab, which turns the page; only its mark is kept here.
            self:SetChecked(parent.selectedTab == entry.index)
        end)
        side:Show()
        finderTabs[i] = side
    end
    SyncCatchers()
end

-- Runs at 10 Hz while the finder is up: written only on change.
function S.SyncFinderSideTabs(parent)
    for _, side in ipairs(finderTabs) do
        local want = (side.index or WHO_PAGE) == parent.selectedTab
        if (side:GetChecked() and true or false) ~= want then side:SetChecked(want) end
    end
end
