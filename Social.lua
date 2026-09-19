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

local COLUMNS = {
    { key = "name", label = NAME or "Name", x = 4, w = 104, justify = "LEFT" },
    { key = "zone", label = ZONE or "Zone", x = 108, w = 104, justify = "LEFT" },
    { key = "level", label = LEVEL_ABBR or "Lvl", x = 212, w = 34, justify = "LEFT" },
    { key = "class", label = CLASS or "Class", x = 246, w = 92, justify = "LEFT" },
}

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
            row.Zone:SetText(entry.zone)
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

    local sel = row:CreateTexture(nil, "BACKGROUND")
    sel:SetAllPoints(row)
    sel:SetColorTexture(0.35, 0.3, 0.12, 0.7)
    sel:Hide()
    row.Selected = sel

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    highlight:SetColorTexture(1, 0.82, 0, 0.12)

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
    sortField = self.key
    if C_FriendList and C_FriendList.SortWho then pcall(C_FriendList.SortWho, sortField) end
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
    if who and who:IsShown() and parent and parent:IsShown() then
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

    -- The foot: the three old buttons, Refresh in the middle.
    panel.refresh = ns.PanelButton(panel, REFRESH or "Refresh", 112)
    panel.refresh:SetPoint("BOTTOM", panel, "BOTTOM", 4, -9)
    panel.refresh:SetScript("OnClick", function()
        if C_FriendList and C_FriendList.SendWho then
            pcall(C_FriendList.SendWho, panel.query and panel.query:GetText() or "")
        end
    end)

    panel.add = ns.PanelButton(panel, ADD_FRIEND or "Add Friend", 118)
    panel.add:SetPoint("RIGHT", panel.refresh, "LEFT", 1, 0)
    panel.add:SetScript("OnClick", function()
        local entry = SelectedEntry()
        if entry and C_FriendList and C_FriendList.AddFriend then C_FriendList.AddFriend(entry.name) end
    end)

    panel.invite = ns.PanelButton(panel, GROUP_INVITE or "Group Invite", 118)
    panel.invite:SetPoint("LEFT", panel.refresh, "RIGHT", 2, 0)
    panel.invite:SetScript("OnClick", function()
        local entry = SelectedEntry()
        if entry and C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(entry.name) end
    end)

    panel.divider = ns.StoneBar(panel)
    panel.divider:SetPoint("BOTTOM", panel.refresh, "TOP", 0, 5)
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
    end

    panel.listBox = ns.SectionBox(panel)
    panel.listBox:SetPoint("TOP", headerRow, "BOTTOM", 0, -5)
    panel.listBox:SetPoint("LEFT", host, "LEFT", 5, 0)
    panel.listBox:SetPoint("RIGHT", host, "RIGHT", -5, 0)
    panel.listBox:SetPoint("BOTTOM", panel.divider, "TOP", 0, 1)

    panel.found = panel.listBox:CreateFontString(nil, "ARTWORK")
    panel.found:SetFontObject(ns.FONT_GOLD_SMALL or "GameFontNormalSmall")
    panel.found:SetPoint("BOTTOM", panel.listBox, "BOTTOM", 0, 26)

    -- The old query line: the words of a who search without the slash
    -- command in front of them.
    panel.query = CreateFrame("EditBox", nil, panel.listBox, "InputBoxTemplate")
    panel.query:SetPoint("BOTTOMLEFT", panel.listBox, "BOTTOMLEFT", 12, 4)
    panel.query:SetPoint("RIGHT", panel.listBox, "RIGHT", -10, 0)
    panel.query:SetHeight(18)
    panel.query:SetAutoFocus(false)
    panel.query:SetFontObject("ChatFontNormal")
    panel.query:SetMaxLetters(60)
    local hint = panel.query:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    hint:SetPoint("LEFT", panel.query, "LEFT", 2, 0)
    hint:SetText(WHO_FRAME_SEARCH_HINT or "Search, as in 5 mage")
    panel.query:SetScript("OnTextChanged", function(self) hint:SetShown((self:GetText() or "") == "") end)
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

local function ShowWho()
    if not panel then return end
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
    for i = 2, #blizzard do
        if blizzard[i] then order[#order + 1] = blizzard[i] end
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
    if not panel then Build() end
    BuildTab()
    RenameFirstTab()
    if tab then tab:Show() end
    PlaceRow()
end

local function Restore()
    active = false
    HideWho()
    if tab then tab:Hide() end
end

ns.RegisterModule("whoList", { apply = Apply, restore = Restore })
