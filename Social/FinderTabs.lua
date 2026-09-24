local _, ns = ...

-- The finder's three side tabs (Create Listing, Group Browser, Who), on both the Who tab and the dressed finder.
-- Pages turn only by the client's own side tabs, lent over ours: our turns taint selectedTab.
-- The finder opens and shuts only by secure pads pressing the client's own buttons: our first open marks it ours.

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

-- Over a hovered Who tab's while the finder is up beside it on another page (this page's has the pad), else the finder's.
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
        local onWho = up and finder.selectedTab ~= index and who and who:IsVisible() and who:IsMouseOver()
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

---------------------------------------------------------------- the pads

-- One /click line per button (a frame, or a name for one made later): /click finds it by name as it runs.
local function ClickMacro(...)
    local lines = {}
    for i = 1, select("#", ...) do
        local frame = select(i, ...)
        local name = type(frame) == "string" and frame or (frame and frame.GetName and frame:GetName())
        if name then lines[#lines + 1] = "/click " .. name end
    end
    if #lines == 0 then return nil end
    return table.concat(lines, "\n")
end

local function CanOpenFinder()
    local finder, micro = _G["LFGParentFrame"], _G["LFDMicroButton"]
    if not finder or finder:IsShown() or not micro or not micro:IsEnabled() then return false end
    -- Else the client's toggle shuts instead, and the pad would only close the social window.
    local info = _G.C_LFGInfo
    return not (info and info.CanPlayerUsePremadeGroup) or info.CanPlayerUsePremadeGroup()
end

-- No client button picks the page (its page buttons call a missing global): shut, the finder opens on its last page
-- and the social window shuts by its X; up beside, this page's tab swaps by that X and the other's is the client's.
local function WhoPadMacro(index)
    local finder = _G["LFGParentFrame"]
    if not finder then return nil end
    if finder:IsShown() then
        if finder.selectedTab == index then return ClickMacro(FriendsFrame and FriendsFrame.CloseButton) end
        return nil
    end
    if CanOpenFinder() then return ClickMacro(_G["LFDMicroButton"], FriendsFrame and FriendsFrame.CloseButton) end
    return nil
end

local function WhoPad(side, index)
    if not _G["LFDMicroButton"] then return end
    ns.MapPad(side, side:GetFrameStrata(), SyncCatchers, function() return WhoPadMacro(index) end)
end

-- The finder shuts by its X; a shut social window opens by the client's toast button, as the guild pads open it.
local function FinderWhoPad(side, parent)
    local close, toast = _G["LFGParentFrameCloseButton"], _G["QuickJoinToastButton"]
    if not (close and toast) then return end
    ns.MapPad(side, side:GetFrameStrata(), function()
        ns.OpenWhoList()
    end, function()
        if not parent:IsShown() then return nil end
        if FriendsFrame and FriendsFrame:IsShown() then return ClickMacro(close) end
        return ClickMacro(close, toast)
    end)
end

-- The finder's code refused to load in a fight: fetched after it, so the pads have their finder.
ns.EventFrame("PLAYER_REGEN_ENABLED", function()
    if whoTabs[1] and whoTabs[1]:IsVisible() then S.SyncWhoFinderTabs() end
end)

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
        side.who = entry.who
        -- Reached only without the pad over ours: in a fight, or before the finder's code loaded.
        side:SetScript("OnClick", function(self)
            self:SetChecked(self.who and true or false)
            if self.who then return end
            if InCombatLockdown() then
                ns.SayNotInCombat()
            elseif ns.WarmGroupFinder then
                ns.WarmGroupFinder()
            end
        end)
        if entry.index then WhoPad(side, entry.index) end
        whoTabs[i] = side
    end
    RunCatchers(panel, "who.catchers")
    whoToggle = ns.PanelToggle(panel, "ClassicUIForeverWhoTabsToggle", 24, "TOPRIGHT", host, "TOPRIGHT", -8, -28,
        panel:GetFrameLevel() + 20, function()
            ns.db.whoTabs = not FinderOpen()
            ns.MirrorSave()
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
                -- Without the pad (a fight): the finder stays, never shut from here.
                if not InCombatLockdown() then ns.OpenWhoList() end
                return
            end
            -- Under the client's tab, which turns the page; only its mark is kept here.
            self:SetChecked(parent.selectedTab == entry.index)
        end)
        side:Show()
        if entry.who then FinderWhoPad(side, parent) end
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
