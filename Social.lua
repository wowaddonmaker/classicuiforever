local _, ns = ...

-- The 1.x social window: its tabs in the old order and the old names,
-- and the Who list rebuilt as one of them. The client answers /who with
-- a window of its own; this takes that job while the toggle is on, and
-- hands it back when it is off.

local ROW_H = 16
local active = false
local panel, tab
local SelectOurTab   -- defined with the tabs, used from the panel's events
local results = {}
local sortField = "name"
local sortReverse = false

local COLUMNS = {
    { key = "name", label = NAME or "Name", x = 4, w = 104, justify = "LEFT" },
    { key = "zone", label = ZONE or "Zone", x = 108, w = 104, justify = "LEFT" },
    { key = "level", label = LEVEL_ABBR or "Lvl", x = 212, w = 34, justify = "LEFT" },
    { key = "class", label = CLASS or "Class", x = 246, w = 92, justify = "LEFT" },
}

-- The second column is a choice, as it was on the old who list: the
-- zone, the guild or the race, picked from the little arrow on its
-- header. The column shows it and sorts by it.
local WHO_FIELDS = {
    { key = "zone", label = ZONE or "Zone" },
    { key = "guild", label = GUILD or "Guild" },
    { key = "race", label = _G.RACE or "Race" },
}
local function WhoField()
    local want = ns.db and ns.db.whoColumn
    for _, field in ipairs(WHO_FIELDS) do
        if field.key == want then return field end
    end
    return WHO_FIELDS[1]
end

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

local function Safe(v, fallback)
    if v == nil or IsSecret(v) then return fallback end
    return v
end

local function Collect()
    wipe(results)
    if not (C_FriendList and C_FriendList.GetNumWhoResults and C_FriendList.GetWhoInfo) then return 0 end
    local ok, shown, total = pcall(C_FriendList.GetNumWhoResults)
    if not ok then return 0 end
    shown = Safe(shown, 0) or 0
    for i = 1, shown do
        local fine, info = pcall(C_FriendList.GetWhoInfo, i)
        if fine and type(info) == "table" and info.fullName and not IsSecret(info.fullName) then
            results[#results + 1] = {
                name = info.fullName,
                guild = Safe(info.fullGuildName, ""),
                zone = Safe(info.area, ""),
                level = Safe(info.level, 0),
                class = Safe(info.classStr, ""),
                classFile = Safe(info.filename, nil),
                race = Safe(info.raceStr, ""),
            }
        end
    end
    -- Sorted here, from what was collected. Asking the client to sort
    -- makes it announce the list afresh, and on that announcement it
    -- opens its own who window, which ours then sends away again: a
    -- flash of the client's window on every click of a column.
    local key = sortField or "name"
    if key == "zone" then key = WhoField().key end
    table.sort(results, function(a, b)
        local x, y = a[key], b[key]
        if x == y then x, y = a.name, b.name end
        if type(x) == "string" then x, y = x:lower(), tostring(y):lower() end
        if sortReverse then return x > y end
        return x < y
    end)
    return Safe(total, shown) or shown
end

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------

local function RowCount()
    if not panel then return 0 end
    return math.max(1, math.floor((panel.list:GetHeight() or 0) / ROW_H))
end

local function UpdateRows()
    if not panel then return end
    local offset = math.floor((panel.bar:GetValue() or 0) + 0.5)
    local shown = RowCount()
    for i, row in ipairs(panel.rows) do
        local entry = i <= shown and results[offset + i] or nil
        if entry then
            row.entry = entry
            row.Name:SetText(entry.name)
            row.Zone:SetText(entry[WhoField().key] or "")
            row.Level:SetText(entry.level)
            row.Class:SetText(entry.class)
            row.Name:SetTextColor(1, 0.82, 0)
            row.Zone:SetTextColor(1, 1, 1)
            row.Level:SetTextColor(1, 1, 1)
            local color = entry.classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.classFile]
            if color then row.Class:SetTextColor(color.r, color.g, color.b) else row.Class:SetTextColor(1, 1, 1) end
            row.Selected:SetShown(panel.selected == offset + i)
            row:Show()
        else
            row.entry = nil
            row:Hide()
        end
    end
    panel.bar:SetRange(math.max(0, #results - shown))
end

local function SelectedEntry()
    return panel and panel.selected and results[panel.selected]
end

local function UpdateButtons()
    if not panel then return end
    local entry = SelectedEntry()
    panel.add:SetEnabled(entry and true or false)
    panel.invite:SetEnabled(entry and true or false)
end

-- The window says Who List while the list is up; the client writes its
-- own title back on every update of its own, so this runs from there too.
local function DressWindow()
    if FriendsFrameTitleText then FriendsFrameTitleText:SetText(WHO_LIST or "Who List") end
end

local function Refresh()
    if not panel or not panel:IsShown() then return end
    local total = Collect()
    panel.found:SetText(format(WHO_NUM_RESULTS or "%d People Found", total or #results))
    DressWindow()
    UpdateRows()
    UpdateButtons()
end
ns.RefreshWhoList = Refresh

-- The old who list answered a right click with the same little menu the
-- other lists opened: whisper, invite, add friend and ignore.
local rowMenu
local function ShowRowMenu(entry)
    if not rowMenu then
        rowMenu = ns.RowMenu({
            { WHISPER or "Whisper", function(who) ns.Whisper(who.name) end },
            { INVITE or "Invite", function(who) if C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(who.name) end end },
            { ADD_FRIEND or "Add Friend", function(who) if C_FriendList and C_FriendList.AddFriend then C_FriendList.AddFriend(who.name) end end },
            { IGNORE or "Ignore", function(who) if C_FriendList and C_FriendList.AddIgnore then C_FriendList.AddIgnore(who.name) end end },
        })
    end
    rowMenu:Follow(panel)
    rowMenu:Open(entry, entry.name)
end

local function Row_OnClick(self, button)
    if not self.entry then return end
    for i, entry in ipairs(results) do
        if entry == self.entry then panel.selected = i end
    end
    UpdateRows()
    UpdateButtons()
    if button == "RightButton" and self.entry.name ~= UnitName("player") then
        ShowRowMenu(self.entry)
    end
end

local function Row_OnDoubleClick(self)
    if self.entry then ns.Whisper(self.entry.name) end
end

local function CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(index - 1) * ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- The old list highlight, as on the guild roster: a bright gold bar
    -- that fades out over its last stretch, on the chosen row and the
    -- same under the mouse.
    local sel = row:CreateTexture(nil, "BACKGROUND")
    sel:SetAllPoints(row)
    sel:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
    sel:SetBlendMode("ADD")
    sel:SetVertexColor(1, 0.82, 0, 1)
    sel:SetTexCoord(0, 0.97, 0, 1)
    sel:Hide()
    row.Selected = sel

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
    highlight:SetBlendMode("ADD")
    highlight:SetVertexColor(1, 0.82, 0, 1)
    highlight:SetTexCoord(0, 0.97, 0, 1)

    for _, column in ipairs(COLUMNS) do
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        text:SetPoint("LEFT", row, "LEFT", column.x, 0)
        text:SetWidth(column.w)
        text:SetJustifyH(column.justify)
        text:SetWordWrap(false)
        row[column.key:gsub("^%l", string.upper)] = text
    end
    row:SetScript("OnClick", Row_OnClick)
    row:SetScript("OnDoubleClick", Row_OnDoubleClick)
    return row
end

local function Header_OnClick(self)
    -- A second click on the same column turns the order round.
    if sortField == self.key then
        sortReverse = not sortReverse
    else
        sortField, sortReverse = self.key, false
    end
    Refresh()
end

local BLIZZARD_PANELS = { "FriendsListFrame", "IgnoreListFrame", "WhoFrame", "RaidFrame", "QuickJoinFrame", "FriendsFrameBroadcastInput" }

-- The client keeps a who window of its own in the group finder, which
-- opens itself when results arrive; it goes while ours is up.
local function HideRowMenu()
    if rowMenu and rowMenu:IsShown() then rowMenu:Hide() end
end

local function CloseClientWhoWindow()
    local who = _G["LFGWhoListFrame"]
    local parent = _G["LFGParentFrame"]
    -- Only when ours is there to take its place. During a fight the
    -- social window is the client's to open, not ours, and a /who there
    -- had the client's list sent away with nothing put up instead.
    if not (FriendsFrame and FriendsFrame:IsVisible()) then return end
    if who and who:IsShown() and parent and parent:IsShown() then
        -- The group finder remembers the page it was shut on. Shut on its
        -- who page it came back on that page at every opening, was sent
        -- away again from here, and so could not be opened at all: its
        -- key did nothing, and a side tab of ours took many clicks. It is
        -- turned to its first page before it goes.
        local first = _G["LFGParentFrameTab1_OnClick"]
        if type(first) == "function" then pcall(first) end
        ns.HidePanel(parent)
    end
end

-- What a fight refused, alpha aside, is set the moment it ends.
local mousePending = false
local settle = CreateFrame("Frame")
settle:RegisterEvent("PLAYER_REGEN_ENABLED")
settle:SetScript("OnEvent", function()
    if not mousePending then return end
    mousePending = false
    for _, name in ipairs(BLIZZARD_PANELS) do
        local frame = _G[name]
        if frame and frame.EnableMouse then
            -- The roster and the Who list both dress these, so a
            -- panel either of them is holding down stays down.
            frame:EnableMouse(not (frame.fcuiGuildHidden or frame.fcuiWhoHidden))
        end
    end
end)

local function HideBlizzardPanels()
    CloseClientWhoWindow()
    for _, name in ipairs(BLIZZARD_PANELS) do
        local frame = _G[name]
        if frame and frame:IsShown() then
            frame:SetAlpha(0)
            -- Taking the mouse from one of the client's own frames is
            -- its call to refuse during a fight; the alpha alone hides
            -- it there, and the mouse is taken once the fight ends.
            if frame.EnableMouse and not InCombatLockdown() then
                frame:EnableMouse(false)
            else
                mousePending = true
            end
            frame.fcuiWhoHidden = true
        end
    end
    local header = FriendsFrame and FriendsFrame.FriendsTabHeader
    if header then header:SetAlpha(0) end
    ns.SweepFriendsFrame("fcuiWhoSwept", true)
    ns.KeepFriendsSwept(panel, "fcuiWhoSwept")
end

local function ShowBlizzardPanels()
    for _, name in ipairs(BLIZZARD_PANELS) do
        local frame = _G[name]
        if frame and frame.fcuiWhoHidden then
            frame:SetAlpha(1)
            -- Giving the mouse back is as much the client's call to
            -- refuse as taking it was, so it waits for the fight to end
            -- the same way.
            if frame.EnableMouse and not InCombatLockdown() then
                frame:EnableMouse(true)
            else
                mousePending = true
            end
            frame.fcuiWhoHidden = nil
        end
    end
    local header = FriendsFrame and FriendsFrame.FriendsTabHeader
    if header then header:SetAlpha(1) end
    ns.SweepFriendsFrame("fcuiWhoSwept", false)
end

local function Build()
    local host = FriendsFrame
    if not host then return end
    panel = CreateFrame("Frame", "ClassicUIForeverWhoPanel", host)
    panel:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -64)
    panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -8, 12)
    panel:SetFrameLevel(host:GetFrameLevel() + 6)
    panel:Hide()

    -- The foot: the three old buttons in the old order, Refresh, Add
    -- Friend, Group Invite. The middle one is stood first and the other
    -- two hung from it, over the same run of the foot as before.
    panel.add = ns.PanelButton(panel, ADD_FRIEND or "Add Friend", 127)
    panel.add:SetPoint("BOTTOM", panel, "BOTTOM", -6, -7)
    panel.refresh = ns.PanelButton(panel, REFRESH or "Refresh", 112)
    panel.refresh:SetPoint("RIGHT", panel.add, "LEFT", 1.5, 0)
    panel.refresh:SetScript("OnClick", function()
        if C_FriendList and C_FriendList.SendWho then
            pcall(C_FriendList.SendWho, panel.query and panel.query:GetText() or "")
        end
    end)

    panel.add:SetScript("OnClick", function()
        local entry = SelectedEntry()
        if entry and C_FriendList and C_FriendList.AddFriend then C_FriendList.AddFriend(entry.name) end
    end)

    panel.invite = ns.PanelButton(panel, GROUP_INVITE or "Group Invite", 123)
    panel.invite:SetPoint("LEFT", panel.add, "RIGHT", -3.5, 0)
    panel.invite:SetScript("OnClick", function()
        local entry = SelectedEntry()
        if entry and C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(entry.name) end
    end)

    -- No bar of stone between the list and the buttons: the search
    -- line's border is the only line there. The bar is kept, unseen, as
    -- the thing the list's foot is measured from.
    panel.divider = ns.StoneBar(panel)
    panel.divider:SetAlpha(0)
    panel.divider:SetPoint("BOTTOM", panel.refresh, "TOP", 0, 3)
    panel.divider:SetPoint("LEFT", host, "LEFT", 5, 0)
    panel.divider:SetPoint("RIGHT", host, "RIGHT", -5, 0)

    -- The column plates on their band of the window's stone.
    local headerBand = CreateFrame("Frame", nil, panel)
    headerBand:SetHeight(22)
    headerBand:SetPoint("TOP", panel, "TOP", 0, 1)
    headerBand:SetPoint("LEFT", host, "LEFT", 5, 0)
    headerBand:SetPoint("RIGHT", host, "RIGHT", -5, 0)
    local stone = ns.StoneFill(headerBand, "BACKGROUND")
    stone:SetAllPoints(headerBand)

    local headerRow = CreateFrame("Frame", nil, panel)
    headerRow:SetHeight(20)
    headerRow:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    headerRow:SetPoint("RIGHT", panel, "RIGHT", -22, 0)
    local lastHeader
    for _, column in ipairs(COLUMNS) do
        lastHeader = ns.ColumnHeader(headerRow, column, lastHeader, Header_OnClick)
        if column.key == "zone" then
            -- The old header's arrow: Zone, Guild or Race for this column.
            local header = lastHeader
            if header.Text then header.Text:SetText(WhoField().label) end
            local arrow = CreateFrame("Button", nil, header)
            arrow:SetSize(22, 22)
            arrow:SetPoint("RIGHT", header, "RIGHT", 1, 0)
            arrow:SetNormalTexture("Interface/ChatFrame/UI-ChatIcon-ScrollDown-Up")
            arrow:SetPushedTexture("Interface/ChatFrame/UI-ChatIcon-ScrollDown-Down")
            arrow:SetHighlightTexture("Interface/Buttons/UI-Common-MouseHilight", "ADD")
            local entries = {}
            for _, field in ipairs(WHO_FIELDS) do
                entries[#entries + 1] = { field.label, function()
                    ns.db.whoColumn = field.key
                    if header.Text then header.Text:SetText(field.label) end
                    sortField, sortReverse = "zone", false
                    Refresh()
                end }
            end
            local menu
            arrow:SetScript("OnClick", function()
                if not menu then
                    menu = ns.RowMenu(entries)
                    menu:Follow(panel)
                end
                menu:Open(WHO_FIELDS, "")
            end)
        end
    end

    panel.listBox = ns.SectionBox(panel)
    panel.listBox:SetPoint("TOP", headerRow, "BOTTOM", 0, -5)
    panel.listBox:SetPoint("LEFT", host, "LEFT", 5, 0)
    panel.listBox:SetPoint("RIGHT", host, "RIGHT", -5, 0)
    panel.listBox:SetPoint("BOTTOM", panel.divider, "TOP", 0, 1)

    panel.found = panel.listBox:CreateFontString(nil, "ARTWORK")
    panel.found:SetFontObject(ns.FONT_GOLD_SMALL or "GameFontNormalSmall")
    panel.found:SetPoint("BOTTOM", panel.listBox, "BOTTOM", 0, 19)

    -- The old query line: the words of a who search without the slash
    -- command in front of them.
    panel.query = CreateFrame("EditBox", nil, panel.listBox, "InputBoxTemplate")
    panel.query:SetPoint("BOTTOMLEFT", panel.listBox, "BOTTOMLEFT", 6, -7)
    panel.query:SetPoint("RIGHT", panel.listBox, "RIGHT", -2, 0)
    panel.query:SetHeight(18)
    -- The line's border is the one the old window had round it, the
    -- lighter metal the profession window's foot wears, and not the
    -- client's bronze input box, whose pieces go.
    -- The input's own thin border is bronze on this client; drained of
    -- its color it is the silver the rest of the old window wears.
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        ns.DrainBronze(panel.query[key], 0.85)
    end
    -- The client's search line has a lens at its left and an X at its
    -- right once something is typed, inside the input's own thin border.
    local lens = panel.query:CreateTexture(nil, "OVERLAY")
    lens:SetTexture("Interface/Common/UI-Searchbox-Icon")
    lens:SetSize(14, 14)
    lens:SetPoint("LEFT", panel.query, "LEFT", 1, -2)
    lens:SetVertexColor(0.6, 0.6, 0.6)
    panel.query:SetTextInsets(16, 20, 0, 0)
    local clear = CreateFrame("Button", nil, panel.query)
    clear:SetSize(17, 17)
    clear:SetPoint("RIGHT", panel.query, "RIGHT", -3, 0)
    clear:SetNormalTexture("Interface/FriendsFrame/ClearBroadcastIcon")
    clear:SetHighlightTexture("Interface/FriendsFrame/ClearBroadcastIcon", "ADD")
    clear:GetNormalTexture():SetAlpha(0.6)
    clear:SetScript("OnClick", function()
        panel.query:SetText("")
        panel.query:ClearFocus()
    end)
    clear:Hide()
    panel.query:HookScript("OnTextChanged", function(self)
        clear:SetShown((self:GetText() or "") ~= "")
    end)
    local queryBox = CreateFrame("Frame", nil, panel.listBox, BackdropTemplateMixin and "BackdropTemplate" or nil)
    -- Out to the window's own edges on both sides, as the profession
    -- window's foot is; only its height follows the line.
    queryBox:SetPoint("TOP", panel.query, "TOP", 0, 7)
    queryBox:SetPoint("BOTTOM", panel.query, "BOTTOM", 0, -7)
    queryBox:SetPoint("LEFT", host, "LEFT", -2, 0)
    queryBox:SetPoint("RIGHT", host, "RIGHT", 0, 0)
    queryBox:SetFrameLevel(panel.query:GetFrameLevel())
    if queryBox.SetBackdrop then
        queryBox:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 20,
            insets = { left = 5, right = 5, top = 5, bottom = 5 },
        })
    end
    panel.queryBox = queryBox
    panel.query:SetAutoFocus(false)
    panel.query:SetFontObject("ChatFontNormal")
    panel.query:SetMaxLetters(60)
    panel.query:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    panel.query:SetScript("OnEnterPressed", function(self)
        if C_FriendList and C_FriendList.SendWho then pcall(C_FriendList.SendWho, self:GetText() or "") end
        self:ClearFocus()
    end)

    local list = CreateFrame("Frame", nil, panel.listBox)
    list:SetPoint("TOPLEFT", panel.listBox, "TOPLEFT", 8, -4)
    list:SetPoint("BOTTOMRIGHT", panel.found, "TOPRIGHT", 0, 2)
    list:SetPoint("RIGHT", panel.listBox, "RIGHT", -26, 0)
    list:EnableMouseWheel(true)
    panel.list = list

    panel.bar = ns.ClassicScrollBar(panel, list, function() UpdateRows() end)
    -- The column runs the pane's full height here, past the foot of the
    -- rows and down beside the count to the search line's border, and a
    -- little higher at its head: it stopped short at both ends.
    panel.bar:ClearAllPoints()
    panel.bar:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, -14)
    panel.bar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 6, 4)
    -- No bar until the list runs past the box, and the bar in its
    -- bordered column when it does, as on the guild roster.
    panel.bar.hideWhenIdle = true
    if ns.ScrollColumnOn then ns.ScrollColumnOn(panel.bar) end
    list:SetScript("OnMouseWheel", function(_, delta)
        panel.bar:SetValue((panel.bar:GetValue() or 0) - delta)
    end)

    panel.rows = {}
    for i = 1, 30 do panel.rows[i] = CreateRow(list, i) end

    panel:SetScript("OnShow", function()
        -- Results come to this window rather than the chat frame.
        if C_FriendList and C_FriendList.SetWhoToUi then pcall(C_FriendList.SetWhoToUi, true) end
        Refresh()
    end)
    panel:SetScript("OnHide", function()
        if C_FriendList and C_FriendList.SetWhoToUi then pcall(C_FriendList.SetWhoToUi, false) end
    end)

    local driver = CreateFrame("Frame")
    driver:RegisterEvent("WHO_LIST_UPDATE")
    driver:SetScript("OnEvent", function()
        if not active then return end
        ns.OpenWhoList()
        HideBlizzardPanels()
        DressWindow()
        Refresh()
        -- The client shows its own list on the same event; whichever of
        -- us runs first, this puts ours back in front on the next frame.
        C_Timer.After(0, function()
            if active and panel and panel:IsShown() then
                HideBlizzardPanels()
                SelectOurTab(true)
                DressWindow()
            end
        end)
    end)
    panel.driver = driver
    -- A bare /who opens the client's own who window on the spot, from
    -- the command itself, and the results come a moment later: until
    -- they did, the client's window stood beside ours. It is looked for
    -- on every frame, and one that has come up is sent away and ours
    -- opened in the same frame, before anything of it is drawn.
    driver:SetScript("OnUpdate", function()
        if not active then return end
        local who = _G["LFGWhoListFrame"]
        if not who or not who:IsVisible() then return end
        -- A fight with the social window shut: the client's list stays.
        if InCombatLockdown() and not (FriendsFrame and FriendsFrame:IsVisible()) then return end
        ns.OpenWhoList()
        HideBlizzardPanels()
    end)
end

---------------------------------------------------------------------------
-- The tabs
---------------------------------------------------------------------------

local function BlizzardTabs()
    local tabs = {}
    for i = 1, 8 do
        local frame = _G["FriendsFrameTab" .. i]
        if frame then tabs[#tabs + 1] = frame end
    end
    return tabs
end

function SelectOurTab(on)
    if not tab then return end
    if on then
        if PanelTemplates_SelectTab then PanelTemplates_SelectTab(tab) end
        for _, other in ipairs(BlizzardTabs()) do
            if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(other) end
        end
    else
        if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab) end
    end
    if ns.FitBottomTab then ns.FitBottomTab(tab) end
end

-- This client keeps its who list in the group finder's window, as the
-- third of three side tabs: Create Listing, Group Browser, Who. The old
-- Who tab gets the same three down its right edge, put away behind a
-- small arrow as the professions book's are. The third is this list; the
-- other two open the client's group finder on their page.
local finderTabs, finderToggle = {}, nil
local function FinderOpen() return ns.db and ns.db.whoTabs and true or false end

local function SyncFinderTabs()
    local open = FinderOpen()
    -- The group finder's code is fetched while the tabs come out, not
    -- at the click that needs it.
    if open and ns.WarmGroupFinder then ns.WarmGroupFinder() end
    for _, side in ipairs(finderTabs) do
        side:SetShown(open)
        side:SetChecked(side.who and true or false)
    end
    if finderToggle and finderToggle.open ~= open then
        finderToggle.open = open
        local name = open and "PrevPage" or "NextPage"
        finderToggle:SetNormalTexture("Interface/Buttons/UI-SpellbookIcon-" .. name .. "-Up")
        finderToggle:SetPushedTexture("Interface/Buttons/UI-SpellbookIcon-" .. name .. "-Down")
    end
end

-- The group finder's page, turned to once its window is up.
local function TurnFinderTo(index)
    local frame = _G["LFGParentFrame"]
    local turn = _G["LFGParentFrameTab" .. index .. "_OnClick"]
    if frame and frame:IsShown() and type(turn) == "function" and frame.selectedTab ~= index then turn() end
end

local function BuildFinderTabs(host)
    if finderToggle or not ns.NewSideTab then return end
    local FINDER = {
        { index = 1, icon = "Interface/Icons/INV_Helmet_08", text = _G.LFG_LIST_TAB_1 or "Create Listing" },
        { index = 2, icon = "Interface/Icons/Achievement_General_StayClassy", text = _G.LFG_LIST_TAB_2 or "Group Browser" },
        { who = true, icon = "Interface/Icons/INV_OwlDragonMount", text = _G.LFG_LIST_TAB_3 or WHO or "Who" },
    }
    for i, entry in ipairs(FINDER) do
        local side = ns.NewSideTab(panel, i, finderTabs[i - 1])
        if i == 1 then
            side:ClearAllPoints()
            side:SetPoint("TOPLEFT", host, "TOPRIGHT", -3, -58)
        end
        side:SetNormalTexture(entry.icon)
        side.tooltip = entry.text
        side.who = entry.who
        side:SetScript("OnClick", function(self)
            self:SetChecked(self.who and true or false)
            if self.who then return end
            -- Reached only where the pad below is not up: in a fight, or
            -- with the group finder open already.
            if InCombatLockdown() then
                if UIErrorsFrame and ERR_NOT_IN_COMBAT then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1) end
                return
            end
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            local frame = _G["LFGParentFrame"]
            if frame and frame:IsShown() then
                TurnFinderTo(entry.index)
            else
                local show = _G["LFGVanilla_ShowFrame"]
                if type(show) == "function" then show(entry.index) end
            end
            -- In the social window's place, whichever way it came up.
            if FriendsFrame and FriendsFrame:IsShown() then ns.HidePanel(FriendsFrame) end
        end)
        finderTabs[i] = side
        -- The window is opened by the client, not by us: a secure pad over
        -- the tab presses the group finder's own micro button, and the
        -- page is turned once it is up.
        if not entry.who and ns.MapPad and _G["LFDMicroButton"] then
            -- A strata over the social window, which is raised over its
            -- own when clicked: a pad level with it lay under the tab, the
            -- tab took the click, and the window came up beside this one
            -- with this one still standing.
            ns.MapPad(side, "HIGH", function()
                PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
                -- The group finder takes the social window's place, as if
                -- the page had turned in the one window: left up, the two
                -- stood one over the other.
                -- The page is turned at once, before the who list's own
                -- watch can see the group finder up on its who page and
                -- send it away; and once more a frame on, for a window
                -- whose code was only just fetched.
                TurnFinderTo(entry.index)
                if FriendsFrame and FriendsFrame:IsShown() then ns.HidePanel(FriendsFrame) end
                C_Timer.After(0, function() TurnFinderTo(entry.index) end)
            end, _G["LFDMicroButton"], function()
                local frame = _G["LFGParentFrame"]
                return not (frame and frame:IsShown())
            end)
        end
    end
    finderToggle = CreateFrame("Button", "ClassicUIForeverWhoTabsToggle", panel)
    finderToggle:SetSize(24, 24)
    finderToggle:SetPoint("TOPRIGHT", host, "TOPRIGHT", -8, -28)
    finderToggle:SetFrameLevel(panel:GetFrameLevel() + 20)
    finderToggle:SetHighlightTexture("Interface/Buttons/UI-Common-MouseHilight", "ADD")
    finderToggle:SetScript("OnClick", function()
        ns.db.whoTabs = not FinderOpen()
        if ns.MirrorSave then ns.MirrorSave() end
        SyncFinderTabs()
    end)
    finderToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(_G.LOOKING_FOR_GROUP or _G.GROUP_FINDER or "Group Finder")
        GameTooltip:Show()
    end)
    finderToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    SyncFinderTabs()
end

local function ShowWho()
    if not panel then return end
    BuildFinderTabs(FriendsFrame)
    SyncFinderTabs()
    if ns.HideGuildRoster then ns.HideGuildRoster() end
    HideBlizzardPanels()
    panel:Show()
    SelectOurTab(true)
    DressWindow()
    Refresh()
end
ns.ShowWhoList = ShowWho

local function HideWho()
    if not panel then return end
    HideRowMenu()
    panel:Hide()
    SelectOurTab(false)
    ShowBlizzardPanels()
    if ns.RestoreFriendsTitle then ns.RestoreFriendsTitle() end
end
ns.HideWhoList = HideWho

function ns.OpenWhoList()
    if not active or not FriendsFrame then return false end
    if not panel then Build() end
    if not ns.ShowPanel(FriendsFrame) then return false end
    ShowWho()
    return true
end

-- The row the old window carried: Friends, Who, Guild, then whatever
-- else the client keeps. The gap is the one the client leaves between
-- two of its own tabs, measured before anything is moved.
local tabGap
local SOCIAL_TAB_PAD = 38
local function PlaceRow()
    local blizzard = BlizzardTabs()
    if not tabGap then
        local first, second
        for _, other in ipairs(blizzard) do
            if other:IsShown() then
                if not first then first = other elseif not second then second = other end
            end
        end
        if first and second and first:GetRight() and second:GetLeft() then
            tabGap = second:GetLeft() - first:GetRight()
        else
            tabGap = -14
        end
    end
    local order = {}
    if blizzard[1] then order[#order + 1] = blizzard[1] end
    if tab then order[#order + 1] = tab end
    local guildTab = _G["ClassicUIForeverGuildTab"]
    if guildTab then order[#order + 1] = guildTab end
    local communitiesTab = _G["ClassicUIForeverCommunitiesTab"]
    if communitiesTab then order[#order + 1] = communitiesTab end
    for i = 2, #blizzard do
        if blizzard[i] then order[#order + 1] = blizzard[i] end
    end
    -- Five tabs where the old window had four: each is cut to 19 either
    -- side of its label, from 25, which is what makes room for the fifth.
    for _, entry in ipairs(order) do
        if entry.fcuiPad ~= SOCIAL_TAB_PAD then
            entry.fcuiPad = SOCIAL_TAB_PAD
            if ns.FitBottomTab then ns.FitBottomTab(entry) end
        end
    end
    local previous
    for _, entry in ipairs(order) do
        if entry:IsShown() then
            entry:ClearAllPoints()
            if previous then
                entry:SetPoint("LEFT", previous, "RIGHT", tabGap, 0)
                entry:SetPoint("BOTTOM", previous, "BOTTOM", 0, 0)
            else
                entry:SetPoint("TOPLEFT", FriendsFrame, "BOTTOMLEFT", 5, 2)
            end
            previous = entry
        end
    end
end
ns.PlaceSocialTabs = PlaceRow

local function BuildTab()
    local host = FriendsFrame
    if not host or tab then return end
    tab = CreateFrame("Button", "ClassicUIForeverWhoTab", host, "PanelTabButtonTemplate")
    tab:SetID(91)
    tab:SetText(WHO or "Who")
    if ns.SkinBottomTab then ns.SkinBottomTab(tab) end
    SelectOurTab(false)
    tab:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        ShowWho()
    end)
    for _, other in ipairs(BlizzardTabs()) do
        other:HookScript("OnClick", function() if active then HideWho() end end)
    end
    -- The client swaps its own panel in by name; ours goes back over it.
    if type(FriendsFrame_ShowSubFrame) == "function" then
        hooksecurefunc("FriendsFrame_ShowSubFrame", function()
            if active and panel and panel:IsShown() then
                HideBlizzardPanels()
                SelectOurTab(true)
                DressWindow()
            end
        end)
    end
    if type(FriendsFrame_Update) == "function" then
        hooksecurefunc("FriendsFrame_Update", function()
            if active and panel and panel:IsShown() then
                HideBlizzardPanels()
                SelectOurTab(true)
                DressWindow()
            end
        end)
    end
    host:HookScript("OnShow", function() if active then PlaceRow() end end)
    host:HookScript("OnHide", function() if panel then HideWho() end end)
end

-- The first tab was called Contacts on this client; 1.x called it Friends.
local function RenameFirstTab()
    local first = _G["FriendsFrameTab1"]
    if not first or not first.SetText then return end
    first:SetText(FRIENDS or "Friends")
    if ns.FitBottomTab then ns.FitBottomTab(first) end
end

local function Apply()
    active = true
    if not FriendsFrame then ns.MissingPiece("FriendsFrame") return end
    -- Never during a fight: see ns.WhenCalm.
    ns.WhenCalm("social", function()
        if not active then return end
        if not panel then Build() end
        BuildTab()
        RenameFirstTab()
        if tab then tab:Show() end
        PlaceRow()
    end)
end

local function Restore()
    active = false
    HideWho()
    if tab then tab:Hide() end
end

ns.RegisterModule("whoList", { apply = Apply, restore = Restore })
