local _, ns = ...

-- The 1.x Who tab. Takes /who results over from the client's own window while on.

local S = ns.social
local IsSecret, Safe = ns.IsSecret, ns.Safe

local active = false
local panel, tab
local results = {}
local sort = { field = "name", reverse = false }
local clientWho -- LFGWhoListFrame from its first sighting: a global frame is never replaced

local COLUMNS = {
    { key = "name", label = NAME or "Name", x = 4, w = 104, justify = "LEFT" },
    { key = "zone", label = ZONE or "Zone", x = 108, w = 104, justify = "LEFT" },
    { key = "level", label = LEVEL_ABBR or "Lvl", x = 212, w = 34, justify = "LEFT" },
    { key = "class", label = CLASS or "Class", x = 246, w = 92, justify = "LEFT" },
}

-- The second column is zone, guild or race, picked from its header's arrow; it shows and sorts by it.
local WHO_FIELDS = {
    { key = "zone", label = ZONE or "Zone" },
    { key = "guild", label = GUILD or "Guild" },
    { key = "race", label = _G.RACE or "Race" },
}
local SCROLL_DOWN = "Interface/ChatFrame/UI-ChatIcon-ScrollDown-"
local FIELD_ARROW = { set = "file", highlightSet = "raw", add = true }
local WHO_EVENTS = { "WHO_LIST_UPDATE", "GLOBAL_MOUSE_UP" }

local function WhoField()
    local want = ns.db and ns.db.whoColumn
    for _, field in ipairs(WHO_FIELDS) do
        if field.key == want then return field end
    end
    return WHO_FIELDS[1]
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
    -- Sorted here: the client's sort re-announces the list and flashes its who window.
    local key = sort.field or "name"
    if key == "zone" then key = WhoField().key end
    local reverse = sort.reverse
    table.sort(results, function(a, b)
        local x, y = a[key], b[key]
        if x == y then x, y = a.name, b.name end
        if type(x) == "string" then x, y = x:lower(), tostring(y):lower() end
        if reverse then return x > y end
        return x < y
    end)
    return Safe(total, shown) or shown
end

---------------------------------------------------------------- the list

local function UpdateRows()
    if not panel then return end
    local offset = ns.ListOffset(panel.bar)
    local shown = S.RowCount(panel)
    local key = WhoField().key
    for i, row in ipairs(panel.rows) do
        local entry = i <= shown and results[offset + i] or nil
        if entry then
            -- Selected by list position, not by name.
            S.ShowRow(row, entry, entry[key] or "", entry.level, entry.class, entry.classFile, panel.selected == offset + i)
        else
            S.HideRow(row)
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

-- The client writes its own title back on its updates, so this runs from there too.
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

-- The old lists' right-click menu: whisper, invite, add friend, ignore.
local rowMenu
local function ShowRowMenu(entry)
    if not rowMenu then
        rowMenu = ns.RowMenu({
            { WHISPER or "Whisper", function(who) ns.Whisper(who.name) end },
            { INVITE or "Invite", function(who) S.Invite(who.name) end },
            { ADD_FRIEND or "Add Friend", function(who) S.AddFriend(who.name) end },
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

local function Header_OnClick(self)
    S.ToggleSort(sort, self.key)
    Refresh()
end

local function HideRowMenu()
    if rowMenu and rowMenu:IsShown() then rowMenu:Hide() end
end

-- The client's who window (in the group finder) opens itself on results; closed while ours is up.
local function CloseClientWhoWindow()
    local who = clientWho or _G["LFGWhoListFrame"]
    clientWho = who
    local parent = _G["LFGParentFrame"]
    -- Only when ours can replace it: in combat only the client opens the social window.
    if not (FriendsFrame and FriendsFrame:IsVisible()) then return end
    -- Never turned from here: that marked the finder's page ours, refusing its opens in a fight.
    if who and who:IsShown() and parent and parent:IsShown() then ns.HidePanel(parent) end
end

-- The client's panels in the window, hidden while the who list is up.
local hidden = { key = "fcuiWhoHidden", swept = "fcuiWhoSwept", pending = false }
S.SettleFrame(hidden)

local function HideBlizzardPanels()
    CloseClientWhoWindow()
    S.HidePanels(hidden, panel)
end

local function ShowBlizzardPanels()
    S.ShowPanels(hidden)
end

local function SelectOurTab(on)
    if not tab then return end
    S.SelectFriendsTab(tab, on)
end

-- Ours back in front after the client's list (WHO_LIST_UPDATE) and each panel swap.
local function FrontAgain()
    if active and panel and panel:IsShown() then
        HideBlizzardPanels()
        SelectOurTab(true)
        DressWindow()
    end
end

---------------------------------------------------------------- the panel

-- The Zone, Guild or Race arrow on the second column's plate.
local function FieldArrow(header, column)
    if column.key ~= "zone" then return end
    if header.Text then header.Text:SetText(WhoField().label) end
    local arrow = CreateFrame("Button", nil, header)
    arrow:SetSize(22, 22)
    arrow:SetPoint("RIGHT", header, "RIGHT", 1, 0)
    ns.DressStates(arrow, SCROLL_DOWN .. "Up", SCROLL_DOWN .. "Down", nil, ns.ART.HILIGHT, FIELD_ARROW)
    local entries = {}
    for _, field in ipairs(WHO_FIELDS) do
        entries[#entries + 1] = { field.label, function()
            ns.db.whoColumn = field.key
            if header.Text then header.Text:SetText(field.label) end
            sort.field, sort.reverse = "zone", false
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

-- The bar runs the pane's full height, down beside the count to the search line.
local function PlaceBar(bar, list)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, -14)
    bar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 6, 4)
end

local function Build()
    local host = FriendsFrame
    if not host then return end
    panel = S.NewPanel(host, "ClassicUIForeverWhoPanel")

    -- The foot in the old order, Refresh, Add Friend, Group Invite: the middle stood first.
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
        if entry then S.AddFriend(entry.name) end
    end)

    panel.invite = ns.PanelButton(panel, GROUP_INVITE or "Group Invite", 123)
    panel.invite:SetPoint("LEFT", panel.add, "RIGHT", -3.5, 0)
    panel.invite:SetScript("OnClick", function()
        local entry = SelectedEntry()
        if entry then S.Invite(entry.name) end
    end)

    -- No stone bar over the buttons (the search line's border is the line);
    -- kept invisible as the list foot's anchor.
    panel.divider = ns.StoneBar(panel)
    panel.divider:SetAlpha(0)
    panel.divider:SetPoint("BOTTOM", panel.refresh, "TOP", 0, 3)
    S.Span(panel.divider, host)

    local headerRow = S.HeaderRow(panel, host, COLUMNS, Header_OnClick, FieldArrow)
    panel.listBox = S.ListBox(panel, host, headerRow, panel.divider)

    panel.found = panel.listBox:CreateFontString(nil, "ARTWORK")
    panel.found:SetFontObject(ns.FONT_GOLD_SMALL or "GameFontNormalSmall")
    panel.found:SetPoint("BOTTOM", panel.listBox, "BOTTOM", 0, 19)

    -- The old query line: a who search without the slash command.
    local query = CreateFrame("EditBox", nil, panel.listBox, "InputBoxTemplate")
    panel.query = query
    query:SetPoint("BOTTOMLEFT", panel.listBox, "BOTTOMLEFT", 6, -7)
    query:SetPoint("RIGHT", panel.listBox, "RIGHT", -2, 0)
    query:SetHeight(18)
    -- The input's thin border is bronze here; drained, it is the old silver.
    ns.DrainInput(query)
    -- The client's lens at the left and its X once something is typed.
    local lens = query:CreateTexture(nil, "OVERLAY")
    lens:SetTexture("Interface/Common/UI-Searchbox-Icon")
    lens:SetSize(14, 14)
    lens:SetPoint("LEFT", query, "LEFT", 1, -2)
    lens:SetVertexColor(0.6, 0.6, 0.6)
    query:SetTextInsets(16, 20, 0, 0)
    local clear = ns.SearchClear(query)
    query:HookScript("OnTextChanged", function(self)
        clear:SetShown((self:GetText() or "") ~= "")
    end)
    -- The old window's lighter metal round the line, out to the window's edges.
    local queryBox = CreateFrame("Frame", nil, panel.listBox, ns.BACKDROP_TEMPLATE)
    queryBox:SetPoint("TOP", query, "TOP", 0, 7)
    queryBox:SetPoint("BOTTOM", query, "BOTTOM", 0, -7)
    queryBox:SetPoint("LEFT", host, "LEFT", -2, 0)
    queryBox:SetPoint("RIGHT", host, "RIGHT", 0, 0)
    queryBox:SetFrameLevel(query:GetFrameLevel())
    ns.Backdrop(queryBox, ns.DialogEdge(20))
    query:SetAutoFocus(false)
    query:SetFontObject("ChatFontNormal")
    query:SetMaxLetters(60)
    query:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    query:SetScript("OnEnterPressed", function(self)
        if C_FriendList and C_FriendList.SendWho then pcall(C_FriendList.SendWho, self:GetText() or "") end
        self:ClearFocus()
    end)

    S.ScrollRows(panel, panel.found, 2, UpdateRows, COLUMNS, Row_OnClick, Row_OnDoubleClick, PlaceBar)

    panel:SetScript("OnShow", function()
        -- Results come to this window, not the chat frame.
        if C_FriendList and C_FriendList.SetWhoToUi then pcall(C_FriendList.SetWhoToUi, true) end
        Refresh()
    end)
    panel:SetScript("OnHide", function()
        if C_FriendList and C_FriendList.SetWhoToUi then pcall(C_FriendList.SetWhoToUi, false) end
    end)

    local clickAt, kept = 0, false
    local driver = ns.EventFrame(WHO_EVENTS, function(_, event)
        if event == "GLOBAL_MOUSE_UP" then
            clickAt = GetTime()
            return
        end
        if not active then return end
        ns.OpenWhoList()
        HideBlizzardPanels()
        DressWindow()
        Refresh()
        -- The client shows its list on this event too; ours goes back in front next frame.
        ns.Sched.NextFrame("who.front", FrontAgain)
    end)
    panel.driver = driver
    -- A bare /who or the Who key opens the client's window before any results: sent away the frame it shows.
    ns.Sched.OnFrame(driver, { name = "who.driver", every = 0, fn = function()
        if not active then return end
        local who = clientWho
        if not who then
            who = _G["LFGWhoListFrame"]
            if not who then return end
            clientWho = who
        end
        if not who:IsVisible() then
            kept = false
            return
        end
        if kept then return end
        -- Opened by a click (micro button, eye, queue button reopen the finder's last page): left in the finder.
        if GetTime() - clickAt < 0.25 then
            kept = true
            return
        end
        -- A fight with the social window shut: the client's list stays.
        if InCombatLockdown() and not (FriendsFrame and FriendsFrame:IsVisible()) then return end
        ns.OpenWhoList()
        HideBlizzardPanels()
    end })
    -- Shown only while the module is on (SetActive); it still hears the event.
    if not active then driver:Hide() end
end

---------------------------------------------------------------- the tabs

local function ShowWho()
    if not panel then return end
    S.BuildWhoFinderTabs(FriendsFrame, panel)
    S.SyncWhoFinderTabs()
    ns.HideGuildRoster()
    HideBlizzardPanels()
    panel:Show()
    SelectOurTab(true)
    DressWindow()
    Refresh()
end

local function HideWho()
    if not panel then return end
    HideRowMenu()
    panel:Hide()
    SelectOurTab(false)
    ShowBlizzardPanels()
    ns.RestoreFriendsTitle()
end
ns.HideWhoList = HideWho

function ns.OpenWhoList()
    if not active or not FriendsFrame then return false end
    if not panel then Build() end
    if not ns.ShowPanel(FriendsFrame) then return false end
    ShowWho()
    return true
end

local function OnClientTab() if active then HideWho() end end
local function OnSocialShow() if active then S.PlaceTabs() end end
local function OnSocialHide() if panel then HideWho() end end
-- The client swaps its own panel in by name; ours goes back over it.
local SOCIAL_HOOKS = { tabClick = OnClientTab, showSubFrame = FrontAgain, update = FrontAgain,
    onShow = OnSocialShow, onHide = OnSocialHide }

local function BuildTab()
    local host = FriendsFrame
    if not host or tab then return end
    tab = S.NewTab(host, "ClassicUIForeverWhoTab", 91, WHO or "Who")
    S.whoTab = tab
    SelectOurTab(false)
    tab:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        ShowWho()
    end)
    S.HookFriendsFrame(host, SOCIAL_HOOKS)
end

-- The first tab says Contacts on this client; 1.x said Friends.
local function RenameFirstTab()
    local first = _G["FriendsFrameTab1"]
    if not first or not first.SetText then return end
    first:SetText(FRIENDS or "Friends")
    ns.FitBottomTab(first)
end

-- The module's switch, its only writer. The watch does nothing while off, so its frame shows only while on.
local function SetActive(on)
    active = on
    local driver = panel and panel.driver
    if driver then driver:SetShown(on) end
end

local function Apply()
    SetActive(true)
    if not FriendsFrame then ns.MissingPiece("FriendsFrame") return end
    -- Never during a fight: see ns.WhenCalm.
    ns.WhenCalm("social", function()
        if not active then return end
        if not panel then Build() end
        BuildTab()
        RenameFirstTab()
        if tab then tab:Show() end
        S.PlaceTabs()
    end)
end

local function Restore()
    SetActive(false)
    HideWho()
    if tab then tab:Hide() end
end

ns.RegisterModule("whoList", { apply = Apply, restore = Restore })
