local _, ns = ...

-- The 1.x guild tab: the roster the Friends window carried, with the
-- four sortable columns, the member count and the guild message under
-- them, and Guild Information, Add Member and Guild Control along the
-- foot. The Forever client keeps its guild in the Communities window,
-- so this is rebuilt rather than re-anchored; that window is left alone.

local ROW_H = 16
local PILL_BORDER = "Interface\\ClassTrainerFrame\\UI-ClassTrainer-FilterBorder"
local GUILD_ICON = "Interface\\FriendsFrame\\FriendsFrameScrollIcon"
local active = false
local panel, tab
local clientToggleGuild   -- the client's own guild toggle, kept when ours takes over
local togglingAt          -- the moment a toggle ran, so one click never acts twice
local selected            -- guild roster index the player clicked
local sortField, sortReverse = "name", false

-- The 1.x proportions: a quarter for the name, a third for the zone, a
-- narrow level and a wide class.
local COLUMNS = {
    { key = "name", label = NAME or "Name", x = 4, w = 96, justify = "LEFT" },
    { key = "zone", label = ZONE or "Zone", x = 100, w = 112, justify = "LEFT" },
    { key = "level", label = LEVEL_ABBR or "Lvl", x = 212, w = 34, justify = "LEFT" },
    { key = "class", label = CLASS or "Class", x = 246, w = 92, justify = "LEFT" },
}
-- The other face of the roster, behind the arrow at its foot: each
-- member's rank, note and when they were last on, in the same three
-- places on the row.
local STATUS_COLUMNS = {
    { key = "name", label = NAME or "Name", x = 4, w = 96, justify = "LEFT" },
    { key = "rank", label = RANK or "Rank", x = 100, w = 80, justify = "LEFT" },
    { key = "note", label = LABEL_NOTE or "Note", x = 180, w = 84, justify = "LEFT" },
    { key = "lastOnline", label = LASTONLINE or "Last Online", x = 264, w = 74, justify = "LEFT" },
}
local statusView = false
local LastOnline
local DockNotes, SyncBridge   -- the note bridge, further down
local ROW_TEXTS = { "Name", "Zone", "Level", "Class" }

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

local function Safe(v, fallback)
    if v == nil or IsSecret(v) then return fallback end
    return v
end

-- The roster as the client hands it over, one entry a member.
local roster = {}

local function ShowOffline()
    if GetGuildRosterShowOffline then
        local ok, value = pcall(GetGuildRosterShowOffline)
        if ok then return value and true or false end
    end
    return false
end

local function CollectRoster()
    wipe(roster)
    if not IsInGuild or not IsInGuild() then return 0, 0 end
    local total, online = 0, 0
    if GetNumGuildMembers then
        local ok, a, b = pcall(GetNumGuildMembers)
        if ok then total, online = Safe(a, 0), Safe(b, 0) end
    end
    local showOffline = ShowOffline()
    for i = 1, total do
        local ok, name, rank, rankIndex, level, class, zone, note, officerNote, isOnline, status, classFile, _, _, _, _, _, guid = pcall(GetGuildRosterInfo, i)
        if ok and name and not IsSecret(name) then
            isOnline = Safe(isOnline, false) and true or false
            if showOffline or isOnline then
                roster[#roster + 1] = {
                    index = i,
                    name = Ambiguate and Ambiguate(name, "guild") or name,
                    rank = Safe(rank, ""),
                    rankIndex = Safe(rankIndex, 0),
                    level = Safe(level, 0),
                    class = Safe(class, ""),
                    classFile = Safe(classFile, nil),
                    zone = Safe(zone, ""),
                    note = Safe(note, ""),
                    officerNote = Safe(officerNote, ""),
                    online = isOnline,
                    status = Safe(status, 0),
                    guid = Safe(guid, nil),
                }
            end
        end
    end
    return total, online
end

-- The client sorts its own roster where it takes our field, so repeat
-- clicks turn the order the way 1.x did; the list is sorted here as well
-- so the rows are right whatever order the client keeps.
local function SortRoster()
    local key = sortField
    table.sort(roster, function(a, b)
        local x, y = a[key], b[key]
        if key == "rank" then
            x, y = tonumber(a.rankIndex) or 0, tonumber(b.rankIndex) or 0
        elseif key == "lastOnline" then
            x, y = a.online and 0 or 1, b.online and 0 or 1
        elseif key == "level" then
            x, y = tonumber(x) or 0, tonumber(y) or 0
        else
            x, y = tostring(x):lower(), tostring(y):lower()
        end
        if x == y then return tostring(a.name):lower() < tostring(b.name):lower() end
        if sortReverse then return x > y end
        return x < y
    end)
end

local function SelectedEntry()
    for _, entry in ipairs(roster) do
        if entry.index == selected then return entry end
    end
end
ns.GuildSelectedMember = SelectedEntry

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------

-- A section of the panel: no paint of its own, so the window's own dark
-- floor shows through the way the old sections read, with the iron bars
-- telling them apart.
local function RowCount()
    if not panel then return 0 end
    return math.max(1, math.floor((panel.list:GetHeight() or 0) / ROW_H))
end

local function UpdateRows()
    if not panel then return end
    local offset = math.floor((panel.bar:GetValue() or 0) + 0.5)
    local shown = RowCount()
    for i, row in ipairs(panel.rows) do
        local entry = i <= shown and roster[offset + i] or nil
        if entry then
            row.entry = entry
            row.Name:SetText(entry.name)
            if statusView then
                row.Zone:SetText(entry.rank)
                row.Level:SetText(entry.note)
                row.Class:SetText(LastOnline(entry))
            else
                row.Zone:SetText(entry.zone)
                row.Level:SetText(entry.level)
                row.Class:SetText(entry.class)
            end
            local color = not statusView and entry.classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.classFile]
            if not entry.online then
                row.Name:SetTextColor(0.5, 0.5, 0.5)
                row.Zone:SetTextColor(0.5, 0.5, 0.5)
                row.Level:SetTextColor(0.5, 0.5, 0.5)
                row.Class:SetTextColor(0.5, 0.5, 0.5)
            else
                row.Name:SetTextColor(1, 0.82, 0)
                row.Zone:SetTextColor(1, 1, 1)
                row.Level:SetTextColor(1, 1, 1)
                if color then
                    row.Class:SetTextColor(color.r, color.g, color.b)
                else
                    row.Class:SetTextColor(1, 1, 1)
                end
            end
            row.Selected:SetShown(entry.index == selected)
            row:Show()
        else
            row.entry = nil
            row:Hide()
        end
    end
    panel.bar:SetRange(math.max(0, #roster - shown))
    -- The arrow stands beside the scroll column when there is one, and
    -- out by the box's edge when there is not.
    if panel.status then
        panel.status:ClearAllPoints()
        panel.status:SetPoint("BOTTOMRIGHT", panel.listBox, "BOTTOMRIGHT", panel.bar:IsShown() and -32 or -8, 2)
    end
    -- The pads over the rows follow what the rows now hold.
    if SyncBridge then SyncBridge() end
end

-- One face of the roster or the other: the headers and the three places
-- on each row take the columns of the face that is up.
local function ApplyView()
    if not panel then return end
    local columns = statusView and STATUS_COLUMNS or COLUMNS
    for i, header in ipairs(panel.headers or {}) do
        local column = columns[i]
        header.key = column.key
        header:SetWidth(column.w)
        if header.Text then header.Text:SetText(column.label) end
    end
    for _, row in ipairs(panel.rows or {}) do
        for i, key in ipairs(ROW_TEXTS) do
            local text, column = row[key], columns[i]
            text:ClearAllPoints()
            text:SetPoint("LEFT", row, "LEFT", column.x, 0)
            text:SetWidth(column.w)
        end
    end
end

local function UpdateButtons()
    if not panel then return end
    panel.control:SetEnabled(IsGuildLeader and IsGuildLeader() and true or false)
    panel.add:SetEnabled(CanGuildInvite and CanGuildInvite() and true or false)
end

-- The guild message and the window's title are read from calls the
-- client refuses while the player is in combat, and a refusal puts the
-- blocked-action box on their screen. What was read last stands in for
-- them there; a guild message does not change mid fight, and the roster
-- reads itself again the moment combat ends.
local lastMOTD, lastTitle = "", nil

local function GuildMOTD()
    if InCombatLockdown() then return lastMOTD end
    if C_GuildInfo and C_GuildInfo.GetMOTD then
        local ok, text = pcall(C_GuildInfo.GetMOTD)
        if ok and type(text) == "string" then lastMOTD = text return text end
    end
    if GetGuildRosterMOTD then
        local ok, text = pcall(GetGuildRosterMOTD)
        if ok and type(text) == "string" then lastMOTD = text return text end
    end
    return lastMOTD
end

-- The window's title while the roster is up: the player's own rank and
-- the guild's name, as 1.x wrote it.
local function GuildTitle()
    if InCombatLockdown() then return lastTitle or GUILD or "Guild" end
    if not GetGuildInfo then return GUILD or "Guild" end
    local ok, guildName, rankName = pcall(GetGuildInfo, "player")
    if not ok or not guildName or IsSecret(guildName) then return lastTitle or GUILD or "Guild" end
    if rankName and not IsSecret(rankName) then
        lastTitle = format(GUILD_TITLE_TEMPLATE or "%s of %s", rankName, guildName)
    else
        lastTitle = guildName
    end
    return lastTitle
end

local function Refresh()
    if not panel or not panel:IsShown() then return end
    local total, online = CollectRoster()
    SortRoster()
    panel.totals:SetText(format(GUILD_TOTAL or "%d Guild Members", total))
    panel.online:SetText(format(GUILD_TOTALONLINE or "(%d Online)", online))
    panel.motd:SetText(GuildMOTD())
    panel.offline:SetChecked(ShowOffline())
    if FriendsFrameTitleText then FriendsFrameTitleText:SetText(GuildTitle()) end
    UpdateRows()
    UpdateButtons()
    if ns.UpdateGuildPopout then ns.UpdateGuildPopout() end
end
ns.RefreshGuildRoster = Refresh

-- Whatever the fight held back is read again the moment it ends.
local regen = CreateFrame("Frame")
regen:RegisterEvent("PLAYER_REGEN_ENABLED")
regen:SetScript("OnEvent", function()
    if panel and panel:IsShown() then Refresh() end
end)

-- The little menu a right click on a member opens, in the old shape:
-- the name across the top and the few things you could do from a row.
-- It is the shared row menu, which closes on a press anywhere else and
-- goes away with the roster; the one built here before did neither, and
-- stayed on screen until one of its rows was picked.
local rowMenu

local function NotMe(entry) return entry.name ~= UnitName("player") end

local function ShowRowMenu(entry)
    if not rowMenu then
        rowMenu = ns.RowMenu({
            { WHISPER or "Whisper", function(e) ns.Whisper(e.name) end,
              function(e) return NotMe(e) and e.online end },
            { INVITE or "Invite", function(e) if C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(e.name) end end,
              function(e) return NotMe(e) and e.online end },
            { ADD_FRIEND or "Add Friend", function(e) if C_FriendList and C_FriendList.AddFriend then C_FriendList.AddFriend(e.name) end end,
              NotMe },
            { GUILD_PROMOTE or "Promote", function(e) if C_GuildInfo and C_GuildInfo.Promote then C_GuildInfo.Promote(e.name) end end,
              function(e) return NotMe(e) and CanGuildPromote and CanGuildPromote() end },
            { GUILD_DEMOTE or "Demote", function(e) if C_GuildInfo and C_GuildInfo.Demote then C_GuildInfo.Demote(e.name) end end,
              function(e) return NotMe(e) and CanGuildDemote and CanGuildDemote() end },
            { REMOVE or "Remove", function(e) if C_GuildInfo and C_GuildInfo.Uninvite then C_GuildInfo.Uninvite(e.name) end end,
              function(e) return NotMe(e) and CanGuildRemove and CanGuildRemove() end },
        })
        rowMenu:Follow(panel)
    end
    rowMenu:Open(entry, entry.name)
end

local function Row_OnClick(self, button)
    if not self.entry then return end
    if button == "RightButton" then
        selected = self.entry.index
        UpdateRows()
        ShowRowMenu(self.entry)
        if ns.UpdateGuildPopout then ns.UpdateGuildPopout() end
        return
    end
    selected = self.entry.index
    if SetGuildRosterSelection then pcall(SetGuildRosterSelection, self.entry.index) end
    UpdateRows()
    -- Picking a member opens their status, as the old roster did.
    if panel and panel.popout then panel.popout:Show() end
    if ns.UpdateGuildPopout then ns.UpdateGuildPopout() end
end

local function Row_OnDoubleClick(self)
    if not self.entry or not self.entry.online then return end
    ns.Whisper(self.entry.name)
end

local function CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(index - 1) * ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- The old list highlight: a bright bar that fades out over its last
    -- stretch, gold on the chosen row and the same, fainter, under the
    -- mouse. A flat tint read as a dull orange block.
    local sel = row:CreateTexture(nil, "BACKGROUND")
    sel:SetAllPoints(row)
    sel:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
    sel:SetBlendMode("ADD")
    sel:SetVertexColor(1, 0.82, 0, 1)
    sel:Hide()
    row.Selected = sel

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
    highlight:SetBlendMode("ADD")
    highlight:SetVertexColor(1, 0.82, 0, 1)
    -- The bar's fade starts seven eighths along the sheet; with the
    -- sheet's last few hundredths cut off it starts nine tenths along.
    highlight:SetTexCoord(0, 0.97, 0, 1)
    sel:SetTexCoord(0, 0.97, 0, 1)

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
    if sortField == self.key then
        sortReverse = not sortReverse
    else
        sortField, sortReverse = self.key, false
    end
    if SortGuildRoster then pcall(SortGuildRoster, self.key) end
    Refresh()
end

-- Blizzard's own panels inside the social window, hidden while the guild
-- roster is up and shown again when a Blizzard tab is picked.
local BLIZZARD_PANELS = { "FriendsListFrame", "IgnoreListFrame", "WhoFrame", "RaidFrame", "QuickJoinFrame", "FriendsFrameBroadcastInput" }

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
            frame.fcuiGuildHidden = true
        end
    end
    local header = FriendsFrame and FriendsFrame.FriendsTabHeader
    if header then header:SetAlpha(0) end
    ns.SweepFriendsFrame("fcuiGuildSwept", true)
    ns.KeepFriendsSwept(panel, "fcuiGuildSwept")
end

local function ShowBlizzardPanels()
    for _, name in ipairs(BLIZZARD_PANELS) do
        local frame = _G[name]
        if frame and frame.fcuiGuildHidden then
            frame:SetAlpha(1)
            -- Giving the mouse back is as much the client's call to
            -- refuse as taking it was, so it waits for the fight to end
            -- the same way.
            if frame.EnableMouse and not InCombatLockdown() then
                frame:EnableMouse(true)
            else
                mousePending = true
            end
            frame.fcuiGuildHidden = nil
        end
    end
    local header = FriendsFrame and FriendsFrame.FriendsTabHeader
    if header then header:SetAlpha(1) end
    ns.SweepFriendsFrame("fcuiGuildSwept", false)
end

-- The side popout the Player Status arrow opens: what 1.x showed about
-- the member picked, and the buttons that act on them.
local function PopoutLine(out, previous, label)
    local row = CreateFrame("Frame", nil, out)
    row:SetHeight(14)
    row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -4)
    row:SetPoint("RIGHT", out, "RIGHT", -10, 0)
    row.Label = row:CreateFontString(nil, "ARTWORK")
    row.Label:SetFontObject(ns.FONT_GOLD_SMALL or "GameFontNormalSmall")
    row.Label:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.Label:SetText(label)
    row.Value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Value:SetPoint("LEFT", row.Label, "RIGHT", 4, 0)
    row.Value:SetJustifyH("LEFT")
    return row
end

local function RankArrow(parent, key, anchor, offset, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(16, 16)
    button:SetPoint("LEFT", anchor, "RIGHT", offset, 0)
    ns.SetButtonTex(button, "Normal", key .. "ButtonUp")
    ns.SetButtonTex(button, "Pushed", key .. "ButtonDown")
    ns.SetButtonTex(button, "Disabled", key .. "ButtonDisabled")
    ns.SetButtonTex(button, "Highlight", key .. "ButtonHighlight")
    for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
        local tex = button["Get" .. state .. "Texture"](button)
        if tex then tex:SetTexCoord(0.25, 0.75, 0.25, 0.75) end
    end
    button:GetHighlightTexture():SetBlendMode("ADD")
    button:SetScript("OnClick", onClick)
    return button
end

local function BuildPopout(host)
    -- Named as ours: the sweep that keeps the client's controls off this
    -- window while the roster is up takes every child of the window that
    -- is not, and the member pane hangs from the window. Unnamed it was
    -- swept with the rest the moment it opened.
    local out = CreateFrame("Frame", "ClassicUIForeverGuildMember", host, BackdropTemplateMixin and "BackdropTemplate" or nil)
    if out.SetBackdrop then
        out:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        ns.BronzeBackdrop(out)
    end
    out:SetSize(206, 250)
    out:SetPoint("TOPLEFT", host, "TOPRIGHT", -6, -70)
    out:SetFrameLevel(host:GetFrameLevel() + 10)
    out:EnableMouse(true)
    out:Hide()

    -- The name sits on the same black as everything else, with the old
    -- close button beside it.
    out.title = out:CreateFontString(nil, "ARTWORK")
    out.title:SetFontObject(ns.FONT_GOLD or "GameFontNormal")
    out.title:SetPoint("LEFT", out, "TOPLEFT", 14, -20)
    out.title:SetPoint("RIGHT", out, "TOPRIGHT", -32, -20)
    out.title:SetJustifyH("LEFT")

    out.close = CreateFrame("Button", nil, out, "UIPanelCloseButton")
    out.close:SetPoint("TOPRIGHT", out, "TOPRIGHT", 2, 2)
    if ns.SkinCloseButton then ns.SkinCloseButton(out.close, true) end
    out.close:SetScript("OnClick", function() out:Hide() end)

    out.level = out:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    out.level:SetPoint("TOPLEFT", out, "TOPLEFT", 14, -40)

    out.zone = PopoutLine(out, out.level, (ZONE or "Zone") .. ":")
    out.rank = PopoutLine(out, out.zone, (RANK or "Rank") .. ":")
    out.lastOnline = PopoutLine(out, out.rank, (LASTONLINE or "Last Online") .. ":")

    -- Promote and demote are the arrows beside the rank, as 1.x had them.
    out.promote = RankArrow(out.rank, "scrollUp", out.rank.Value, 6, function()
        local entry = SelectedEntry()
        if entry and C_GuildInfo and C_GuildInfo.Promote then C_GuildInfo.Promote(entry.name) end
    end)
    out.demote = RankArrow(out.rank, "scrollDown", out.promote, 2, function()
        local entry = SelectedEntry()
        if entry and C_GuildInfo and C_GuildInfo.Demote then C_GuildInfo.Demote(entry.name) end
    end)

    -- Only the guild master may hand the guild over.
    out.guildmaster = ns.PanelButton(out, GUILD_PROMOTE_TO_GM or "Promote to Guild Master", 186)
    out.guildmaster:SetPoint("BOTTOMLEFT", out, "BOTTOMLEFT", 14, 42)
    out.guildmaster:SetScript("OnClick", function()
        local entry = SelectedEntry()
        if entry and C_GuildInfo and C_GuildInfo.SetLeader then C_GuildInfo.SetLeader(entry.name) end
    end)

    out.remove = ns.PanelButton(out, REMOVE or "Remove", 90)
    out.remove:SetPoint("BOTTOMLEFT", out, "BOTTOMLEFT", 14, 16)
    out.remove:SetScript("OnClick", function()
        local entry = SelectedEntry()
        if entry and C_GuildInfo and C_GuildInfo.Uninvite then C_GuildInfo.Uninvite(entry.name) end
    end)

    out.invite = ns.PanelButton(out, GROUP_INVITE or "Group Invite", 90)
    out.invite:SetPoint("LEFT", out.remove, "RIGHT", 4, 0)
    out.invite:SetScript("OnClick", function()
        local entry = SelectedEntry()
        if entry and C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(entry.name) end
    end)

    -- The public note and, for those who may see it, the officer's note:
    -- a label and a pale bordered box each, as the old pane had them.
    -- They are not written here: saving a note is the client's alone.
    -- While the note bridge (further down) has the client's own note box
    -- lying over one of these, a click on it opens the client's dialog.
    -- When it has not, whoever may write notes is told how on the box.
    local function NoteHint(self)
        if not self.mayEdit then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.Label:GetText() or "", 1, 1, 1)
        GameTooltip:AddLine("Out of combat, click the member in the list, then click here to write the note.", nil, nil, nil, true)
        GameTooltip:Show()
    end

    local function NoteBox(labelText, anchor, gap)
        local label = out:CreateFontString(nil, "ARTWORK")
        label:SetFontObject(ns.FONT_GOLD_SMALL or "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gap)
        label:SetText(labelText)
        local box = CreateFrame("Button", nil, out, BackdropTemplateMixin and "BackdropTemplate" or nil)
        box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
        box:SetPoint("RIGHT", out, "RIGHT", -14, 0)
        box:SetHeight(40)
        if box.SetBackdrop then
            box:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = false, edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            box:SetBackdropColor(0, 0, 0, 0.85)
            box:SetBackdropBorderColor(0.78, 0.78, 0.78)
        end
        box.Text = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        box.Text:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -6)
        box.Text:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 6)
        box.Text:SetJustifyH("LEFT")
        box.Text:SetJustifyV("TOP")
        box.Label = label
        box:SetScript("OnEnter", NoteHint)
        box:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return box
    end
    out.noteBox = NoteBox((LABEL_NOTE or "Note") .. ":", out.lastOnline, -6)
    out.officerBox = NoteBox(GUILD_OFFICERNOTE_LABEL or OFFICER_NOTE_COLON or "Officer's Note", out.noteBox, -5)
    return out
end

-- How long ago the member was last seen, in the words 1.x used.
LastOnline = function(entry)
    if entry.online then return GUILD_ONLINE_LABEL or "Online" end
    if not GetGuildRosterLastOnline then return "" end
    local ok, years, months, days, hours = pcall(GetGuildRosterLastOnline, entry.index)
    if not ok then return "" end
    years, months, days, hours = Safe(years, 0), Safe(months, 0), Safe(days, 0), Safe(hours, 0)
    if years and years > 0 then return format(LASTONLINE_YEARS or "%d years", years) end
    if months and months > 0 then return format(LASTONLINE_MONTHS or "%d months", months) end
    if days and days > 0 then return format(LASTONLINE_DAYS or "%d days", days) end
    if hours and hours > 0 then return format(LASTONLINE_HOURS or "%d hours", hours) end
    return LASTONLINE_MINS or "moments ago"
end

function ns.UpdateGuildPopout(fromBridge)
    if not panel or not panel.popout or not panel.popout:IsShown() then return end
    local out = panel.popout
    local entry = SelectedEntry()
    local me = UnitName("player")
    -- Whether the client's note boxes lie over ours for this member.
    if not fromBridge and DockNotes then DockNotes() end
    local live = ns.GuildNotesLive and ns.GuildNotesLive(entry)
    out.title:SetText(entry and entry.name or (PLAYER_STATUS or "Player Status"))
    out.level:SetText(entry and format("%s %s %s", LEVEL or "Level", tostring(entry.level), tostring(entry.class)) or "")
    out.zone.Value:SetText(entry and entry.zone or "")
    out.rank.Value:SetText(entry and entry.rank or "")
    out.lastOnline.Value:SetText(entry and LastOnline(entry) or "")
    local mayNote = ((CanEditPublicNote and CanEditPublicNote()) or (entry and entry.name == me)) and true or false
    local note = entry and entry.note or ""
    if note == "" and mayNote and live then note = GUILD_NOTE_EDITLABEL or "Click here to set a Public Note." end
    out.noteBox.Text:SetText(note)
    out.noteBox.mayEdit = mayNote
    -- The officer's note is there only for those the guild lets see it.
    local seeOfficer = (C_GuildInfo and C_GuildInfo.CanViewOfficerNote and C_GuildInfo.CanViewOfficerNote())
        or (CanViewOfficerNote and CanViewOfficerNote()) or false
    local mayOfficer = (C_GuildInfo and C_GuildInfo.CanEditOfficerNote and C_GuildInfo.CanEditOfficerNote())
        or (CanEditOfficerNote and CanEditOfficerNote()) or false
    out.officerBox:SetShown(seeOfficer and true or false)
    out.officerBox.Label:SetShown(seeOfficer and true or false)
    if seeOfficer then
        local officer = entry and entry.officerNote or ""
        if officer == "" and mayOfficer and live then officer = GUILD_OFFICERNOTE_EDITLABEL or "Click here to set an Officer's Note." end
        out.officerBox.Text:SetText(officer)
        out.officerBox.mayEdit = mayOfficer and true or false
    end
    local leader = IsGuildLeader and IsGuildLeader() and true or false
    out:SetHeight(216 + (seeOfficer and 60 or 0) + (leader and 26 or 0))

    local other = entry and entry.name ~= me
    out.promote:SetEnabled(other and CanGuildPromote and CanGuildPromote() and true or false)
    out.demote:SetEnabled(other and CanGuildDemote and CanGuildDemote() and true or false)
    out.remove:SetEnabled(other and CanGuildRemove and CanGuildRemove() and true or false)
    out.invite:SetEnabled(other and entry.online and true or false)
    out.guildmaster:SetShown(IsGuildLeader and IsGuildLeader() and true or false)
    out.guildmaster:SetEnabled(other and entry.online and true or false)
end

---------------------------------------------------------------------------
-- The note bridge
---------------------------------------------------------------------------

-- Saving a guild note is a call the client keeps for itself: by guid it
-- is refused an addon outright, and its own note dialog opened from here
-- is refused at Accept. What the client will do is save a note when the
-- whole road to it is its own: its roster row clicked, its member frame
-- shown by that click, its note box clicked, its dialog accepted.
--
-- So that road is laid under this roster. While the roster is up, out of
-- a fight, the client's guild window stands open unseen: faded out, off
-- the screen, and tall enough that every member has a row. Over each row
-- of ours lies a secure pad, and a click on it is a press of the
-- client's row for the same member, which shows the client's member
-- frame for them. That frame is the one thing of the window that is
-- seen: it is taken off the unseen window, hung from the screen and
-- stood beside the roster where our own member pane stands, which steps
-- aside for it. Its note boxes are clicked where they are, by the mouse
-- itself, and the dialog that opens and the save behind it are the
-- client's from end to end. Our own pane is what shows when the client's
-- cannot: during a fight, or for a member the window holds no row for.
--
-- The pads hang from the screen by measure, never from this panel: a
-- secure child would make the roster the client's to show and hide
-- during a fight.
local bridge = { pads = {}, rows = {} }
local GHOST_ROWS_MAX = 500     -- rows the unseen window is grown to hold
local CLIENT_ROW_H = 20        -- a row of the client's member list

local function ClientDetail()
    return CommunitiesFrame and CommunitiesFrame.GuildMemberDetailFrame
end

local function HidePads()
    if InCombatLockdown() then return end
    for _, pad in ipairs(bridge.pads) do
        if pad:IsShown() then pad:Hide() end
    end
    if bridge.NotePad then bridge.NotePad:Hide() end
    if bridge.OfficerPad then bridge.OfficerPad:Hide() end
end

-- The client's member frame in the old window's metal: its border's
-- pieces lose their bronze, its buttons and its close button take the
-- old sheets. Art only, by calls on the pieces; nothing of the frame's
-- own is read or written.
local function DressDetail(detail)
    if bridge.dressed then return end
    bridge.dressed = true
    local border = detail.Border
    if border and border.GetRegions then
        for _, region in ipairs({ border:GetRegions() }) do
            if region ~= border.Bg then ns.DrainBronze(region) end
        end
    end
    -- The two note boxes: the border pieces go white, piece by piece.
    -- Not through the boxes' own backdrop calls, which would write on
    -- the very frames a note is saved from.
    for _, box in ipairs({ detail.NoteBackground, detail.OfficerNoteBackground }) do
        for _, holder in ipairs({ box, box and box.NineSlice }) do
            if holder and holder.GetRegions then
                local center = holder.Center
                for _, region in ipairs({ holder:GetRegions() }) do
                    if region ~= center then ns.DrainBronze(region, 1, 1, 1) end
                end
            end
        end
    end
    if ns.SkinCloseButton then pcall(ns.SkinCloseButton, detail.CloseButton, true) end
    if ns.SkinRedButton then
        pcall(ns.SkinRedButton, detail.RemoveButton)
        pcall(ns.SkinRedButton, detail.GroupInviteButton)
    end
end

-- The client's member frame back on its own window, as it was made.
local function ParkDetail()
    local detail = ClientDetail()
    if not detail or not bridge.docked then return end
    bridge.docked = nil
    detail:Hide()
    detail:SetParent(CommunitiesFrame)
    detail:SetFrameStrata(CommunitiesFrame:GetFrameStrata())
    detail:SetFrameLevel(1000)
    detail:ClearAllPoints()
    detail:SetPoint("TOPLEFT", CommunitiesFrame, "TOPRIGHT", -8, -76)
end

-- Whatever of ours touches the client's guild window must leave no mark
-- on it. A window shown, or a club picked, by a plain call from here has
-- its fields written in our name, and everything the client later does
-- with them is refused its protected calls: its community list raised
-- blocked-action errors, and a note would be refused the same way. The
-- client's panel manager is the one door that leaves no mark: it shows
-- and hides a panel from its own secure delegate, whoever asked. So the
-- window is only ever shown and hidden through it, the guild is picked
-- by the setting the window reads for itself as it opens, and nothing on
-- the window is called from here.
local GHOST_X = 4000           -- how far off the screen's right edge it stands
local GHOST_LIST_OVERHEAD = 91 -- the window above and below its member list

local function GhostHeight()
    -- As many rows as the client's list will hold: everyone with Show
    -- Offline Members ticked, and otherwise only who is on. It was grown
    -- for the whole guild either way, and every one of those rows is a
    -- live row of the client's, drawn again at each change of the roster.
    local members, online = 0, 0
    if GetNumGuildMembers then members, online = GetNumGuildMembers() end
    members, online = Safe(members, 0), Safe(online, 0)
    if not ShowOffline() then members = online end
    return GHOST_LIST_OVERHEAD + (math.min(members, GHOST_ROWS_MAX) + 12) * CLIENT_ROW_H
end

local function PlaceGhost(frame)
    local _, _, _, x = frame:GetPoint(1)
    if frame:GetNumPoints() ~= 1 or x ~= GHOST_X then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPRIGHT", GHOST_X, 0)
    end
end

-- The client's window given back as it was found.
local function DropGhost()
    HidePads()
    if not bridge.ghost then return end
    local frame, keep = CommunitiesFrame, bridge.keep
    bridge.ghost, bridge.keep, bridge.live = nil, nil, nil
    wipe(bridge.rows)
    if frame and keep then
        ParkDetail()
        local detail = ClientDetail()
        if detail then detail:Hide() end
        if frame:IsShown() and HideUIPanel then pcall(HideUIPanel, frame) end
        frame:SetAttribute("UIPanelLayout-width", keep.widthAttr)
        frame:SetSize(keep.width, keep.height)
        frame:SetAlpha(keep.alpha)
    end
    ns.guildGhost = nil
end
ns.DropGuildGhost = DropGhost

-- The client's window up and unseen, on the guild, with its member list
-- out. False when it cannot be (the player has that window open, or the
-- client will not open panels just now).
local function RaiseGhost()
    -- Never during a fight: this asks the client to open one of its own
    -- windows, which it refuses to do for an addon there and tells the
    -- player an action was blocked. The notes wait for the fight to end.
    if InCombatLockdown() then return false end
    if not CommunitiesFrame and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_Communities")
    end
    local frame = CommunitiesFrame
    if not frame or not frame.MemberList or not ClientDetail() or not ShowUIPanel then return false end
    if bridge.ghost then
        if not frame:IsShown() then
            -- Something else closed it: what was changed is put back.
            DropGhost()
            return false
        end
        PlaceGhost(frame)
        local height = GhostHeight()
        if height > frame:GetHeight() + 1 then frame:SetHeight(height) end
        return true
    end
    if frame:IsShown() then return false end
    local now = GetTime()
    if bridge.retryAt and now < bridge.retryAt then return false end
    local clubId = C_Club and C_Club.GetGuildClubId and C_Club.GetGuildClubId()
    if not clubId then return false end
    bridge.keep = {
        alpha = frame:GetAlpha(), width = frame:GetWidth(), height = frame:GetHeight(),
        strata = frame:GetFrameStrata(), widthAttr = frame:GetAttribute("UIPanelLayout-width"),
    }
    bridge.ghost = true
    ns.guildGhost = true
    frame:SetAlpha(0)
    -- Tall before it opens, so that every member's row is made by the
    -- window's own opening and not by a change of ours afterwards.
    frame:SetHeight(GhostHeight())
    -- The manager is told it is a sliver, so it stands it beside the
    -- social window instead of closing that to make room.
    frame:SetAttribute("UIPanelLayout-width", 1)
    -- The window opens on the club this setting names.
    if SetCVar then pcall(SetCVar, "lastSelectedClubId", clubId) end
    pcall(ShowUIPanel, frame)
    if not frame:IsShown() then
        DropGhost()
        bridge.retryAt = now + 2
        return false
    end
    PlaceGhost(frame)
    return true
end

-- The client's rows read by the guid of the member each holds.
local function ReadClientRows()
    wipe(bridge.rows)
    local frame = CommunitiesFrame
    local box = frame.MemberList.ScrollBox
    if not box or not box.ForEachFrame then return end
    if C_Club and frame.GetSelectedClubId and frame:GetSelectedClubId() ~= C_Club.GetGuildClubId() then return end
    box:ForEachFrame(function(row)
        if row.isInvitation or not row.GetMemberInfo then return end
        local info = row:GetMemberInfo()
        local guid = info and info.guid
        if guid and not IsSecret(guid) then bridge.rows[guid] = row end
    end)
end

local lastPadClick = {}
local function Pad(index)
    local pad = bridge.pads[index]
    if pad then return pad end
    pad = CreateFrame("Button", "ClassicUIForeverGuildRowPad" .. index, UIParent, "SecureActionButtonTemplate")
    pad:SetAttribute("type1", "click")
    pad:SetAttribute("useOnKeyDown", false)
    pad:RegisterForClicks("AnyUp", "AnyDown")
    pad:Hide()
    local highlight = pad:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(pad)
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
    highlight:SetBlendMode("ADD")
    highlight:SetVertexColor(1, 0.82, 0, 1)
    highlight:SetTexCoord(0, 0.97, 0, 1)
    -- The client's row has been pressed by now; the roster does with the
    -- click what it does with any click on the row under the pad.
    pad:SetScript("PostClick", function(_, button, down)
        if down then return end
        local row = panel and panel.rows[index]
        if not row or not row.entry then return end
        local now = GetTime()
        if button == "LeftButton" and lastPadClick.entry == row.entry and now - (lastPadClick.at or 0) < 0.4 then
            lastPadClick.entry = nil
            Row_OnDoubleClick(row)
            return
        end
        lastPadClick.entry, lastPadClick.at = row.entry, now
        Row_OnClick(row, button)
    end)
    bridge.pads[index] = pad
    return pad
end

-- The member may have been picked before the client's rows had come (they
-- arrive a moment after the window opens), or during a fight, and then
-- the client's member frame is not showing them and its note boxes are
-- our own pane is up instead. For that case a pad lies over each of our
-- note boxes: a click on it is a press of the client's row for the
-- member, and the client's frame takes our pane's place at once.
local function NotePad(key)
    local pad = bridge[key]
    if pad then return pad end
    pad = CreateFrame("Button", "ClassicUIForeverGuild" .. key, UIParent, "SecureActionButtonTemplate")
    pad:SetAttribute("type1", "click")
    pad:SetAttribute("useOnKeyDown", false)
    pad:RegisterForClicks("AnyUp", "AnyDown")
    pad:Hide()
    pad:SetScript("PostClick", function(_, _, down)
        if down then return end
        SyncBridge()
    end)
    bridge[key] = pad
    return pad
end

local function PlaceNotePads()
    local out = panel and panel.popout
    local entry = SelectedEntry()
    local theirs = out and out:IsVisible() and entry and entry.guid and not bridge.live and bridge.rows[entry.guid]
    local scale = UIParent:GetEffectiveScale()
    for key, box in pairs({ NotePad = out and out.noteBox, OfficerPad = out and out.officerBox }) do
        local left, bottom = box and box:GetLeft(), box and box:GetBottom()
        if theirs and box:IsVisible() and box.mayEdit and left and bottom then
            local pad = NotePad(key)
            if pad.target ~= theirs then
                pad:SetAttribute("clickbutton", theirs)
                pad.target = theirs
            end
            local ratio = box:GetEffectiveScale() / scale
            pad:SetFrameStrata("HIGH")
            pad:ClearAllPoints()
            pad:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * ratio, bottom * ratio)
            pad:SetSize(box:GetWidth() * ratio, box:GetHeight() * ratio)
            if not pad:IsShown() then pad:Show() end
        elseif bridge[key] and bridge[key]:IsShown() then
            bridge[key]:Hide()
        end
    end
end

local function PlacePads()
    if InCombatLockdown() or not panel then return end
    local scale = UIParent:GetEffectiveScale()
    for index, row in ipairs(panel.rows) do
        local entry = row:IsVisible() and row.entry
        local theirs = entry and entry.guid and bridge.rows[entry.guid]
        local left, bottom = row:GetLeft(), row:GetBottom()
        if theirs and left and bottom then
            local pad = Pad(index)
            if pad.target ~= theirs then
                pad:SetAttribute("clickbutton", theirs)
                pad.target = theirs
            end
            local ratio = row:GetEffectiveScale() / scale
            -- A layer above the social window, not a level above the row
            -- in the same one: that window comes to the front of its
            -- layer on every press of the mouse, over a pad that hangs
            -- from the screen, and the press went to the row under it.
            -- The first click on a member never reached the client.
            pad:SetFrameStrata("HIGH")
            pad:ClearAllPoints()
            pad:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * ratio, bottom * ratio)
            pad:SetSize(row:GetWidth() * ratio, row:GetHeight() * ratio)
            if not pad:IsShown() then pad:Show() end
        else
            -- A member in view with no row of the client's: read again
            -- at the next beat, they may only not have come yet.
            if entry and entry.guid then bridge.stale = true end
            local pad = bridge.pads[index]
            if pad and pad:IsShown() then pad:Hide() end
        end
    end
end

-- The client's member frame beside the roster while it is showing the
-- member ours is, our own pane out of its way; parked on its window
-- again, and our pane left to itself, when it is not. True when that
-- changed.
DockNotes = function()
    local detail = ClientDetail()
    local out = panel and panel.popout
    local host = out and out:GetParent()
    local entry = SelectedEntry()
    local live
    if bridge.ghost and detail and host and detail:IsShown() and panel:IsVisible() and entry and entry.guid then
        local ok, info = pcall(detail.GetMemberInfo, detail)
        local guid = ok and info and info.guid
        if guid and not IsSecret(guid) and guid == entry.guid then live = guid end
    end
    local was = bridge.live
    if live then
        if not bridge.docked then
            bridge.docked = true
            -- Off the unseen window, which would keep it unseen and, on
            -- this client, out of the mouse's reach with it.
            detail:SetParent(UIParent)
            detail:SetFrameStrata("HIGH")
            detail:ClearAllPoints()
            detail:SetPoint("TOPLEFT", host, "TOPRIGHT", -6, -70)
            detail:SetAlpha(1)
            DressDetail(detail)
        end
        if out:IsShown() then out:Hide() end
    elseif bridge.docked then
        ParkDetail()
    end
    bridge.live = live
    return was ~= live
end

-- Whether a click on a note box leads anywhere for this member: the
-- client's box lies over ours, or a pad that will bring it does.
function ns.GuildNotesLive(entry)
    if bridge.live ~= nil then return true end
    return bridge.ghost and entry and entry.guid and bridge.rows[entry.guid] and not InCombatLockdown() and true or false
end

-- Whether the player may write any note at all: someone else's by their
-- rank, or their own once they are the member picked. The unseen window
-- is there for saving notes and for nothing else, and it is the costly
-- part of this roster, so without a note to save it is never raised.
local function MayWriteNotes()
    if CanEditPublicNote and CanEditPublicNote() then return true end
    if C_GuildInfo and C_GuildInfo.CanEditOfficerNote and C_GuildInfo.CanEditOfficerNote() then return true end
    if CanEditOfficerNote and CanEditOfficerNote() then return true end
    local entry = SelectedEntry()
    return entry ~= nil and entry.name == UnitName("player")
end

SyncBridge = function()
    local want = active and panel and panel:IsVisible() and IsInGuild and IsInGuild() and MayWriteNotes()
    if not want then
        if bridge.ghost then DropGhost() end
        return
    end
    if not InCombatLockdown() then
        if RaiseGhost() then
            -- The client's rows are read when there is reason to: the
            -- roster changed, a row of ours found none of theirs, or two
            -- seconds went by. It was every quarter second and at every
            -- turn of the wheel, over every row the window holds.
            local now = GetTime()
            if bridge.stale or now - (bridge.readAt or 0) > 2 then
                bridge.stale, bridge.readAt = nil, now
                ReadClientRows()
            end
            PlacePads()
        else
            HidePads()
        end
    end
    if DockNotes() and ns.UpdateGuildPopout then ns.UpdateGuildPopout(true) end
    if not InCombatLockdown() and bridge.ghost then PlaceNotePads() end
end

local bridgeWatch = CreateFrame("Frame")
bridgeWatch:RegisterEvent("PLAYER_REGEN_DISABLED")
-- The pads are the client's to hide once a fight is on; this comes just
-- before it, while they are still ours.
bridgeWatch:SetScript("OnEvent", HidePads)
bridgeWatch:SetScript("OnUpdate", function(self, elapsed)
    -- The panel manager stands the window back on the screen whenever it
    -- lays its panels out again; it goes straight back off.
    if bridge.ghost and CommunitiesFrame and CommunitiesFrame:IsShown() then PlaceGhost(CommunitiesFrame) end
    self.since = (self.since or 0) + elapsed
    if self.since < 0.25 then return end
    self.since = 0
    if bridge.ghost or (active and panel and panel:IsVisible()) then SyncBridge() end
end)

local function Build()
    local host = FriendsFrame
    if not host then return end
    panel = CreateFrame("Frame", "ClassicUIForeverGuildPanel", host)
    panel:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -64)
    panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -8, 12)
    panel:SetFrameLevel(host:GetFrameLevel() + 6)
    panel:Hide()

    -- Show offline members, the old pill under the title bar: the class
    -- trainer's filter border cut in three, as the 1.x guild tab used it.
    panel.offline = CreateFrame("CheckButton", nil, panel)
    panel.offline:SetSize(210, 23)
    panel.offline:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 30)
    local pieces = {
        { 12, 28, "TOPRIGHT", 0.90625, 1 },
        { 186, 28, nil, 0.09375, 0.90625 },
        { 12, 28, nil, 0, 0.09375 },
    }
    local previous
    for _, piece in ipairs(pieces) do
        local tex = panel.offline:CreateTexture(nil, "BACKGROUND")
        tex:SetTexture(PILL_BORDER)
        tex:SetSize(piece[1], piece[2])
        tex:SetTexCoord(piece[4], piece[5], 0, 1)
        if piece[3] then
            tex:SetPoint("TOPRIGHT", panel.offline, "TOPRIGHT", 0, 3)
        else
            tex:SetPoint("RIGHT", previous, "LEFT", 0, 0)
        end
        previous = tex
    end
    -- The empty box is drawn whether or not it is ticked, so it reads as
    -- something that can be turned on.
    local box = panel.offline:CreateTexture(nil, "ARTWORK")
    box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    box:SetSize(22, 22)
    box:SetPoint("RIGHT", panel.offline, "RIGHT", -6, 2)
    local check = panel.offline:CreateTexture(nil, "OVERLAY")
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetSize(22, 22)
    check:SetPoint("CENTER", box, "CENTER", 0, 0)
    panel.offline:SetCheckedTexture(check)
    local hover = panel.offline:CreateTexture(nil, "HIGHLIGHT")
    hover:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    hover:SetBlendMode("ADD")
    hover:SetSize(22, 22)
    hover:SetPoint("CENTER", box, "CENTER", 0, 0)
    local offlineText = panel.offline:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    offlineText:SetPoint("CENTER", panel.offline, "CENTER", -3, 2)
    offlineText:SetText(SHOW_OFFLINE_MEMBERS or "Show Offline Members")
    panel.offline:SetScript("OnClick", function(self)
        if SetGuildRosterShowOffline then pcall(SetGuildRosterShowOffline, self:GetChecked() and true or false) end
        if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
        Refresh()
    end)

    -- The foot: the three old buttons.
    panel.add = ns.PanelButton(panel, ADDMEMBER or "Add Member", 118)
    panel.add:SetPoint("BOTTOM", panel, "BOTTOM", 4, -8)
    panel.add:SetScript("OnClick", function()
        -- The client's dialog asks the guild's club how full it is and
        -- stopped on an error when it was not told which club.
        if StaticPopup_Show then
            local clubId = C_Club and C_Club.GetGuildClubId and C_Club.GetGuildClubId()
            StaticPopup_Show("ADD_GUILDMEMBER", nil, nil, { clubId = clubId })
        end
    end)

    panel.control = ns.PanelButton(panel, GUILDCONTROL or "Guild Control", 110)
    panel.control:SetPoint("LEFT", panel.add, "RIGHT", 2, 0)
    panel.control:SetScript("OnClick", function()
        -- The client's guild control comes with a piece that is only
        -- loaded when asked for; its own opener loads it and shows it.
        if GuildControlUI and GuildControlUI:IsShown() then
            ns.HidePanel(GuildControlUI)
        elseif type(GuildControlUI_Show) == "function" then
            GuildControlUI_Show()
            -- The client stands it off by the width it has on record for
            -- the social window, which is wider than the old one: it is
            -- brought in beside the roster with a small gap.
            C_Timer.After(0, function()
                if GuildControlUI and GuildControlUI:IsShown() and host:IsShown() and not InCombatLockdown() then
                    GuildControlUI:ClearAllPoints()
                    GuildControlUI:SetPoint("TOPLEFT", host, "TOPRIGHT", 6, 0)
                end
            end)
        elseif ToggleGuildControlUI then
            ToggleGuildControlUI()
        end
    end)

    panel.info = ns.PanelButton(panel, GUILD_INFORMATION or "Guild Information", 126)
    panel.info:SetPoint("RIGHT", panel.add, "LEFT", 1, 0)
    panel.info:SetScript("OnClick", function()
        -- The client's own guild window, not ours: the call we kept. It
        -- is given back as it was first if the note bridge has it.
        DropGhost()
        if clientToggleGuild then clientToggleGuild() elseif ToggleGuildFrame then ToggleGuildFrame() end
    end)

    -- The guild message over the buttons, an iron bar between them.
    panel.lowerBar = ns.StoneBar(panel)
    panel.lowerBar:SetPoint("BOTTOM", panel.info, "TOP", 0, 1)
    panel.lowerBar:SetPoint("LEFT", host, "LEFT", 5, 0)
    panel.lowerBar:SetPoint("RIGHT", host, "RIGHT", -5, 0)

    panel.motdBox = ns.SectionBox(panel)
    panel.motdBox:SetPoint("BOTTOM", panel.lowerBar, "TOP", 0, 1)
    panel.motdBox:SetPoint("LEFT", host, "LEFT", 5, 0)
    panel.motdBox:SetPoint("RIGHT", host, "RIGHT", -5, 0)
    panel.motdBox:SetHeight(74)

    panel.upperBar = ns.StoneBar(panel)
    panel.upperBar:SetPoint("BOTTOM", panel.motdBox, "TOP", 0, 1)
    panel.upperBar:SetPoint("LEFT", host, "LEFT", 5, 0)
    panel.upperBar:SetPoint("RIGHT", host, "RIGHT", -5, 0)

    local motdLabel = panel.motdBox:CreateFontString(nil, "ARTWORK")
    motdLabel:SetFontObject(ns.FONT_GOLD_SMALL or "GameFontNormalSmall")
    motdLabel:SetPoint("TOPLEFT", panel.motdBox, "TOPLEFT", 8, -8)
    -- The old heading. The client's own string for it has lost the word
    -- Guild and the colon; in English the old words are used outright.
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "enUS" or locale == "enGB" then
        motdLabel:SetText("Guild Message Of The Day:")
    else
        motdLabel:SetText((GUILD_MOTD_LABEL or "Message of the Day") .. ":")
    end

    panel.motd = panel.motdBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    panel.motd:SetPoint("TOPLEFT", motdLabel, "BOTTOMLEFT", 0, -3)
    panel.motd:SetPoint("BOTTOMRIGHT", panel.motdBox, "BOTTOMRIGHT", -8, 6)
    panel.motd:SetJustifyH("LEFT")
    panel.motd:SetJustifyV("TOP")

    -- Setting the message is a call no addon may make: the client refuses
    -- it outright. The client's own editor may, when its own Edit button
    -- is pressed, and a secure button may press another button for the
    -- player. So a secure pad lies over the message, and a click on it is
    -- a press of the client's Edit button: its editor opens, and what is
    -- accepted there is set by the client itself.
    --
    -- The pad hangs from the screen by measure, not from this panel: a
    -- secure child would make the whole roster the client's to show and
    -- hide during a fight. It is up only while the roster is, out of a
    -- fight, for someone who may set the message.
    local pad
    local function EditButton()
        local frame = CommunitiesFrame
        local info = frame and frame.GuildDetailsFrame and frame.GuildDetailsFrame.Info
        return info and info.EditMOTDButton
    end
    local function MayEdit()
        if CanEditMOTD then return CanEditMOTD() and true or false end
        return C_GuildInfo and C_GuildInfo.CanEditMOTD and C_GuildInfo.CanEditMOTD() and true or false
    end
    local padWatch = CreateFrame("Frame")
    padWatch:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 0.2 then return end
        self.since = 0
        if InCombatLockdown() then return end
        local want = active and panel:IsVisible() and MayEdit()
        if want and not pad then
            -- The client's editor comes with a piece loaded on demand.
            if not EditButton() and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_Communities") end
            local button = EditButton()
            if not button then return end
            pad = CreateFrame("Button", "ClassicUIForeverMotdPad", UIParent, "SecureActionButtonTemplate")
            pad:SetAttribute("type", "click")
            pad:SetAttribute("clickbutton", button)
            pad:SetAttribute("useOnKeyDown", false)
            pad:RegisterForClicks("AnyUp", "AnyDown")
            pad:SetFrameStrata("HIGH")
            pad:Hide()
        end
        if not pad then return end
        if not want then
            if pad:IsShown() then pad:Hide() end
            return
        end
        local box = panel.motdBox
        local left, bottom = box:GetLeft(), box:GetBottom()
        if not left or not bottom then return end
        local ratio = box:GetEffectiveScale() / UIParent:GetEffectiveScale()
        pad:ClearAllPoints()
        pad:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * ratio, bottom * ratio)
        pad:SetSize(box:GetWidth() * ratio, box:GetHeight() * ratio)
        if not pad:IsShown() then pad:Show() end
    end)

    -- The counts are not a section of their own: they are the last line
    -- inside the black the roster sits on, with the arrow to the member
    -- at its right, so they are laid in once the list box exists.

    -- The headers above the list, and the list itself in its own box.
    local headerBand = CreateFrame("Frame", nil, panel)
    headerBand:SetHeight(22)
    headerBand:SetPoint("TOP", panel, "TOP", 0, 1)
    headerBand:SetPoint("LEFT", host, "LEFT", 5, 0)
    headerBand:SetPoint("RIGHT", host, "RIGHT", -5, 0)
    local headerStone = ns.StoneFill(headerBand, "BACKGROUND")
    headerStone:SetAllPoints(headerBand)
    panel.headerBand = headerBand

    local headerRow = CreateFrame("Frame", nil, panel)
    headerRow:SetHeight(20)
    headerRow:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    headerRow:SetPoint("RIGHT", panel, "RIGHT", -22, 0)
    panel.headers = {}
    local lastHeader
    for _, column in ipairs(COLUMNS) do
        lastHeader = ns.ColumnHeader(headerRow, column, lastHeader, Header_OnClick)
        panel.headers[#panel.headers + 1] = lastHeader
    end

    panel.listBox = ns.SectionBox(panel)
    panel.listBox:SetPoint("TOP", headerRow, "BOTTOM", 0, -5)
    panel.listBox:SetPoint("LEFT", host, "LEFT", 5, 0)
    panel.listBox:SetPoint("RIGHT", host, "RIGHT", -5, 0)
    panel.listBox:SetPoint("BOTTOM", panel.upperBar, "TOP", 0, 1)

    panel.totals = panel.listBox:CreateFontString(nil, "ARTWORK")
    panel.totals:SetFontObject(ns.FONT_GOLD_SMALL or "GameFontNormalSmall")
    panel.totals:SetPoint("BOTTOMLEFT", panel.listBox, "BOTTOMLEFT", 8, 6)

    panel.online = panel.listBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    panel.online:SetPoint("LEFT", panel.totals, "RIGHT", 4, 0)
    panel.online:SetTextColor(0.1, 1, 0.1)

    -- The arrow at the roster's foot turns it over: zone, level and
    -- class on one face, rank, note and last online on the other. No
    -- label beside it; the old one said what it did in its tooltip.
    panel.status = CreateFrame("Button", nil, panel.listBox)
    panel.status:SetSize(28, 28)
    panel.status:SetPoint("BOTTOMRIGHT", panel.listBox, "BOTTOMRIGHT", -8, 2)
    ns.SetButtonTex(panel.status, "Normal", "sbNextUp")
    ns.SetButtonTex(panel.status, "Pushed", "sbNextDown")
    ns.SetButtonTex(panel.status, "Highlight", "mouseHighlight")
    panel.status:GetHighlightTexture():SetBlendMode("ADD")
    panel.status:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(statusView and (GUILD_STATUS or "Guild Status") or (PLAYER_STATUS or "Player Status"), 1, 1, 1)
        GameTooltip:Show()
    end)
    panel.status:SetScript("OnLeave", function() GameTooltip:Hide() end)

    panel.popout = BuildPopout(host)
    panel.status:SetScript("OnClick", function(self)
        statusView = not statusView
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        ApplyView()
        -- A sort by a column the new face does not have falls back.
        local columns = statusView and STATUS_COLUMNS or COLUMNS
        local known = false
        for _, column in ipairs(columns) do if column.key == sortField then known = true end end
        if not known then sortField, sortReverse = "name", false end
        Refresh()
        if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
    end)

    local list = CreateFrame("Frame", nil, panel.listBox)
    list:SetPoint("TOPLEFT", panel.listBox, "TOPLEFT", 8, -4)
    list:SetPoint("BOTTOMRIGHT", panel.totals, "TOPRIGHT", 0, 4)
    list:SetPoint("RIGHT", panel.listBox, "RIGHT", -26, 0)
    list:EnableMouseWheel(true)
    panel.list = list

    panel.bar = ns.ClassicScrollBar(panel, list, function() UpdateRows() end)
    -- No bar until the roster is longer than its box, and the old scroll
    -- column round it when it is.
    panel.bar.hideWhenIdle = true
    if ns.ScrollColumnOn then ns.ScrollColumnOn(panel.bar) end
    list:SetScript("OnMouseWheel", function(_, delta)
        panel.bar:SetValue((panel.bar:GetValue() or 0) - delta)
    end)

    panel.rows = {}
    for i = 1, 30 do panel.rows[i] = CreateRow(list, i) end

    panel:SetScript("OnShow", function()
        if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
        Refresh()
    end)
    panel:SetScript("OnHide", function() if panel.popout then panel.popout:Hide() end end)

    local driver = CreateFrame("Frame")
    for _, event in ipairs({ "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "GUILD_MOTD" }) do
        pcall(driver.RegisterEvent, driver, event)
    end
    -- A busy guild sends these in bursts, and each one had the whole
    -- roster read, sorted and drawn again. They are gathered: one pass,
    -- and the next no sooner than a third of a second on.
    driver:SetScript("OnEvent", function(self)
        self.dirty = true
        bridge.stale = true
    end)
    driver:SetScript("OnUpdate", function(self, elapsed)
        self.wait = (self.wait or 0) - elapsed
        if not self.dirty or self.wait > 0 then return end
        self.dirty, self.wait = false, 0.33
        if active then Refresh() end
    end)
    panel.driver = driver
end

---------------------------------------------------------------------------
-- The tab
---------------------------------------------------------------------------

local function BlizzardTabs()
    local tabs = {}
    for i = 1, 8 do
        local frame = _G["FriendsFrameTab" .. i]
        if frame then tabs[#tabs + 1] = frame end
    end
    return tabs
end

local function SelectOurTab(on)
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
    -- White while it is the tab that is up, as the old tabs were; gold
    -- otherwise, and gray where there is no guild (KeepTabState).
    -- Not by whether the tab is enabled: a selected tab is a disabled
    -- one, that is how the client's tabs mark the one that is up, so the
    -- white was never put on and the label stayed gold on its own pane.
    local text = tab.GetFontString and tab:GetFontString()
    if text and not tab.fcuiNoGuild then
        if on then text:SetTextColor(1, 1, 1) else text:SetTextColor(1, 0.82, 0) end
    end
end

-- The window wears the guild scroll and the player's rank while the
-- roster is up, and takes its own icon and title back afterwards.
local function DressWindow(on)
    local icon = FriendsFrameIcon
    if icon then
        if on then
            if not icon.fcuiTexture then icon.fcuiTexture = icon:GetTexture() end
            icon:SetTexture(GUILD_ICON)
            icon:SetTexCoord(0, 1, 0, 1)
        elseif icon.fcuiTexture then
            icon:SetTexture(icon.fcuiTexture)
        end
    end
    if on and FriendsFrameTitleText then
        FriendsFrameTitleText:SetText(GuildTitle())
    elseif not on and ns.RestoreFriendsTitle then
        ns.RestoreFriendsTitle()
    end
end

local function InGuild() return IsInGuild and IsInGuild() and true or false end

local function ShowGuild()
    if not panel then return end
    -- Without a guild there is no roster to show: the tab is grayed out
    -- as it was, and nothing else opens this either.
    if not InGuild() then return end
    if ns.HideWhoList then ns.HideWhoList() end
    HideBlizzardPanels()
    panel:Show()
    SelectOurTab(true)
    DressWindow(true)
    Refresh()
    if ns.RefreshMicroButtons then ns.RefreshMicroButtons() end
end

local function HideGuild()
    if not panel then return end
    panel:Hide()
    DropGhost()
    SelectOurTab(false)
    DressWindow(false)
    ShowBlizzardPanels()
    if ns.RefreshMicroButtons then ns.RefreshMicroButtons() end
end
ns.HideGuildRoster = HideGuild

-- Our tab takes the gap Blizzard leaves between two of its own, so the
-- row reads as one set rather than a tab pushed against another.
local function TabGap(tabs)
    local first, second
    for _, other in ipairs(tabs) do
        if other:IsShown() then
            if not first then first = other elseif not second then second = other end
        end
    end
    if first and second and first:GetRight() and second:GetLeft() then
        return second:GetLeft() - first:GetRight()
    end
    return -14
end

local function PlaceTab()
    if not tab then return end
    -- The who list owns the row's order when it is on.
    if ns.PlaceSocialTabs then ns.PlaceSocialTabs() return end
    local tabs = BlizzardTabs()
    local last
    for _, other in ipairs(tabs) do
        if other:IsShown() then last = other end
    end
    -- Narrower tabs, as the who list's row has them, to fit one more.
    local row = { tab, unpack(tabs) }
    row[#row + 1] = _G["ClassicUIForeverCommunitiesTab"]
    for _, entry in ipairs(row) do
        if entry.fcuiPad ~= 38 then
            entry.fcuiPad = 38
            if ns.FitBottomTab then ns.FitBottomTab(entry) end
        end
    end
    tab:ClearAllPoints()
    if last then
        -- The same height as its neighbours, or its own art hangs below
        -- the row and leaves a gap under the window's border.
        if last:GetHeight() and last:GetHeight() > 0 then tab:SetHeight(last:GetHeight()) end
        tab:SetPoint("LEFT", last, "RIGHT", TabGap(tabs), 0)
        tab:SetPoint("BOTTOM", last, "BOTTOM", 0, 0)
    else
        tab:SetPoint("BOTTOMLEFT", FriendsFrame, "BOTTOMLEFT", 16, 2)
    end
    local communities = _G["ClassicUIForeverCommunitiesTab"]
    if communities then
        communities:ClearAllPoints()
        communities:SetHeight(tab:GetHeight())
        communities:SetPoint("LEFT", tab, "RIGHT", TabGap(tabs), 0)
        communities:SetPoint("BOTTOM", tab, "BOTTOM", 0, 0)
    end
end

-- The Guild tab as the old window had it: there, and grayed out, for a
-- character in no guild.
local function KeepTabState()
    if not tab then return end
    local text = tab.GetFontString and tab:GetFontString()
    if InGuild() then
        -- Only a tab put out for want of a guild is brought back. The
        -- test used to be "is it disabled", and a selected tab is
        -- disabled too: every pass of this, and there are several in the
        -- first seconds of a session, took the Guild tab that had just
        -- been pressed for a guildless one, enabled it and unpicked it,
        -- with the roster still up behind it.
        if tab.fcuiNoGuild then
            tab.fcuiNoGuild = false
            tab:Enable()
            if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab) end
            if ns.FitBottomTab then ns.FitBottomTab(tab) end
        end
        -- The gray was put on the label itself and outlives the enabling.
        local up = panel and panel:IsShown()
        if text then
            if up then text:SetTextColor(1, 1, 1) else text:SetTextColor(1, 0.82, 0) end
        end
    else
        -- Through the roster's own closing, which gives the window's
        -- panels back; hidden bare, the friends list stayed unseen.
        if panel and panel:IsShown() then HideGuild() end
        tab.fcuiNoGuild = true
        tab:Disable()
        if text then text:SetTextColor(0.5, 0.5, 0.5) end
    end
end

-- The old window had no communities, and this roster takes the key and
-- the button that used to open them along with the guild. So they get a
-- tab of their own beside Guild, which opens the client's communities
-- window as it is; that window takes the social window's place, as the
-- client's manager has it.
local communitiesTab
local function BuildCommunitiesTab(host)
    if communitiesTab or not C_Club then return end
    communitiesTab = CreateFrame("Button", "ClassicUIForeverCommunitiesTab", host, "PanelTabButtonTemplate")
    communitiesTab:SetID(92)
    communitiesTab:SetText(COMMUNITIES or "Communities")
    if ns.SkinBottomTab then ns.SkinBottomTab(communitiesTab) end
    if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(communitiesTab) end
    communitiesTab:SetScript("OnClick", function()
        -- The client opens no window for an addon during a fight.
        if InCombatLockdown() then
            if UIErrorsFrame and ERR_NOT_IN_COMBAT then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1) end
            return
        end
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        -- The client's window given back first if the note bridge has
        -- it up unseen, or the toggle below would only put it away.
        DropGhost()
        if panel and panel:IsShown() then HideGuild() end
        local frame = _G["CommunitiesFrame"]
        if frame and frame:IsShown() then return end
        -- The communities window is a window of its own, not a page of
        -- this one: the social window shuts as it opens, and it takes
        -- the social window's place.
        if FriendsFrame and FriendsFrame:IsShown() then ns.HidePanel(FriendsFrame) end
        local open = clientToggleGuild or ToggleGuildFrame
        if type(open) == "function" then open() end
    end)
end

local function BuildTab()
    local host = FriendsFrame
    if not host or tab then return end
    BuildCommunitiesTab(host)
    tab = CreateFrame("Button", "ClassicUIForeverGuildTab", host, "PanelTabButtonTemplate")
    tab:SetID(90)
    tab:SetText(GUILD or "Guild")
    if ns.SkinBottomTab then ns.SkinBottomTab(tab) end
    SelectOurTab(false)
    PlaceTab()
    tab:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        ShowGuild()
    end)
    for _, other in ipairs(BlizzardTabs()) do
        other:HookScript("OnClick", function() if active then HideGuild() end end)
    end
    if type(FriendsFrame_Update) == "function" then
        hooksecurefunc("FriendsFrame_Update", function()
            if active and panel and panel:IsShown() then
                HideBlizzardPanels()
                SelectOurTab(true)
                DressWindow(true)
            end
        end)
    end
    host:HookScript("OnShow", function() if active then PlaceTab() KeepTabState() end end)
    host:HookScript("OnHide", function() if panel then HideGuild() end end)
    local guildWatch = CreateFrame("Frame")
    -- Joining a guild is told before the client itself says the character
    -- is in one, so the tab stayed gray until the interface next loaded.
    -- It is asked again on the roster's own update and a moment later.
    guildWatch:RegisterEvent("PLAYER_GUILD_UPDATE")
    guildWatch:RegisterEvent("GUILD_ROSTER_UPDATE")
    guildWatch:SetScript("OnEvent", function()
        if not active then return end
        KeepTabState()
        C_Timer.After(1, KeepTabState)
        C_Timer.After(4, KeepTabState)
    end)
    KeepTabState()
end

-- The guild micro button opens this roster instead of the Communities
-- window while the classic roster is on.
-- A window the client will not open during a fight is remembered and
-- opened the moment the fight ends. The friends window holds pieces the
-- client protects, so an addon may not show it there; where it is
-- already open, the roster takes its tab as usual.
local wanted = false

function ns.OpenGuildRoster()
    if not active or not FriendsFrame then return false end
    if not panel then Build() end
    BuildTab()
    if not ns.ShowPanel(FriendsFrame) then
        wanted = true
        return false
    end
    wanted = false
    ShowGuild()
    return true
end

local afterFight = CreateFrame("Frame")
afterFight:RegisterEvent("PLAYER_REGEN_ENABLED")
afterFight:SetScript("OnEvent", function()
    if active and wanted then
        wanted = false
        ns.OpenGuildRoster()
    end
end)

-- 1.x had no guild button in the micro menu: it had Social, which opened
-- the friends window, with the guild as one of its tabs. The client's
-- guild button wears the old Social art and does the old Social job.
local function SocialShown() return FriendsFrame and FriendsFrame:IsShown() and true or false end

local function ToggleSocial()
    if not FriendsFrame then return end
    if SocialShown() then
        if panel and panel:IsShown() then panel:Hide() end
        ns.HidePanel(FriendsFrame)
    else
        ns.ShowPanel(FriendsFrame)
    end
    if ns.RefreshMicroButtons then ns.RefreshMicroButtons() end
end

local function CloseClientGuildWindows()
    DropGhost()
    for _, name in ipairs({ "CommunitiesFrame", "GuildFrame" }) do
        local frame = _G[name]
        if frame and frame:IsShown() then ns.HidePanel(frame) end
    end
end

-- The guild key (and anything else that calls the client's own toggle)
-- opens this roster while it is on; the Guild Information button still
-- reaches the client's window through the call we kept.
local function WrapGuildToggle()
    if clientToggleGuild or type(ToggleGuildFrame) ~= "function" then return end
    clientToggleGuild = ToggleGuildFrame
    -- The client calls this from its own pass (the guild key, the micro
    -- button). A window put on screen from inside that pass is refused
    -- during a fight, so the work steps out to the next frame there,
    -- where it is plainly ours and allowed.
    local function Run()
        togglingAt = GetTime()
        CloseClientGuildWindows()
        -- What is on screen decides, not the roster's own flag. A window
        -- the client refused to open during a fight left that flag set
        -- with nothing shown, and every press after it read as "close",
        -- so the button did nothing until the next reload.
        ToggleSocial()
    end

    ToggleGuildFrame = function(...)
        if not active then return clientToggleGuild(...) end
        if InCombatLockdown() and C_Timer and C_Timer.After then
            -- The press is marked as taken now, not when the work runs a
            -- frame on. The button's own click comes through here and
            -- then through the hook below in the same frame: the hook saw
            -- no mark, toggled the window itself, and the work put off to
            -- the next frame toggled it straight back. During a fight the
            -- button did nothing, or shut a window in the blink it opened.
            togglingAt = GetTime()
            C_Timer.After(0, Run)
        else
            Run()
        end
    end
end

-- The guild key answers to a button of ours, so the roster opens from
-- the key the way it does from the button. Opening a window during a
-- fight is the client's to do and it refuses any addon that asks; this
-- client cannot compile a secure snippet either, its restricted loader
-- is missing, so a window the client will not show simply stays shut
-- rather than raising the blocked-action box.
local GUILD_BIND = "ForeverClassicUIGuildBind"
local guildBind

local function UpdateGuildBinding()
    if not guildBind or InCombatLockdown() then return end
    ClearOverrideBindings(guildBind)
    if not active then return end
    for _, binding in ipairs({ "TOGGLEGUILDTAB", "TOGGLEGUILDFRAME", "TOGGLEGUILD" }) do
        local key, second = GetBindingKey(binding)
        for _, k in ipairs({ key, second }) do
            if k then SetOverrideBindingClick(guildBind, true, k, GUILD_BIND, "LeftButton") end
        end
    end
end
ns.UpdateGuildBinding = UpdateGuildBinding

-- Opening the social window so that the client counts it as one of its
-- own panels, which is what lets the client's own Escape close it.
--
-- Shown from our Lua it stands on screen uncounted: the client's Escape
-- walks straight past it to the target and then to the game menu, and
-- nothing closes it for the rest of a fight. The client will not open a
-- panel for an addon during a fight either, so the press has to reach
-- one of the client's own openers. This client has no friends button in
-- its micro menu and its /friends command is not a secure one (with a
-- player targeted it adds that player as a friend), which leaves the
-- quick join toast beside the chat: its click, with no toast waiting,
-- is the client's own ToggleFriendsFrame.
local socialOpen

-- What a press leaves behind. The guild key opens the roster inside
-- the window; the social button only opens the window and leaves the
-- tab where the player last had it. The client's own tab is not
-- touched: set from here it lit beside ours, two tabs engaged at once.
local function AfterSocialPress(toRoster)
    if not active then return end
    if SocialShown() then
        if toRoster then
            CloseClientGuildWindows()
            ShowGuild()
        end
    else
        HideGuild()
    end
    if ns.RefreshMicroButtons then ns.RefreshMicroButtons() end
end

-- A press that left the window as it found it did not do what it was
-- for: the client's opener turns its own page where the window is
-- already up, and does nothing at all where it has a toast waiting.
-- The window is moved from here instead, so a press is never lost.
local function SettleSocialPress(was)
    local now = SocialShown()
    if was == now then ToggleSocial() end
end

local function BuildSocialOpener()
    if socialOpen or InCombatLockdown() then return end
    if not _G["QuickJoinToastButton"] then return end
    socialOpen = CreateFrame("Button", "ForeverClassicUISocialOpen", UIParent, "SecureActionButtonTemplate")
    -- A real target off the edge of the screen: a button with no size
    -- and nowhere to stand is never clicked at all.
    socialOpen:SetSize(1, 1)
    socialOpen:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
    socialOpen:EnableMouse(false)
    socialOpen:RegisterForClicks("AnyUp", "AnyDown")
    socialOpen:SetAttribute("useOnKeyDown", false)
    socialOpen:SetAttribute("type", "macro")
    socialOpen:SetAttribute("macrotext", "/click QuickJoinToastButton")
    socialOpen:SetScript("PreClick", function(self, _, down)
        if down then return end
        self.was = SocialShown()
    end)
    socialOpen:HookScript("OnClick", function(self, _, down)
        if down or not active then return end
        SettleSocialPress(self.was)
        self.was = nil
        AfterSocialPress(false)
    end)
    return socialOpen
end

local function BuildSecureOpener()
    if guildBind or InCombatLockdown() then return end
    if not panel then Build() end
    guildBind = CreateFrame("Button", GUILD_BIND, UIParent, "SecureActionButtonTemplate")
    -- The key runs a macro, not our Lua. A macro is the client's own
    -- text, run in the client's own pass, so the window it opens is
    -- opened by the client and its window manager raises no objection
    -- during a fight. Ours then picks the roster's tab inside it, which
    -- is an ordinary frame and always allowed.
    guildBind:RegisterForClicks("AnyUp", "AnyDown")
    -- Once to a press. Both halves of a key press reach this button, and
    -- the press it carries is done on the release: without this the
    -- window opened as the key went down and closed as it came up.
    guildBind:SetAttribute("useOnKeyDown", false)
    guildBind:SetAttribute("type", "macro")
    -- The quick join toast, not /friends: that command is not a secure
    -- one on this client, and with a player targeted it adds that
    -- player as a friend instead of opening anything.
    guildBind:SetAttribute("macrotext", "/click QuickJoinToastButton")
    guildBind:SetScript("PreClick", function(self, _, down)
        if down then return end
        self.was = SocialShown()
    end)
    guildBind:HookScript("OnClick", function(self, _, down)
        if down or not active then return end
        SettleSocialPress(self.was)
        self.was = nil
        AfterSocialPress(true)
    end)
    guildBind:RegisterEvent("UPDATE_BINDINGS")
    guildBind:RegisterEvent("PLAYER_REGEN_ENABLED")
    -- Bindings are not always loaded when this first runs, and the key
    -- only reaches us once the override is in place: without this the
    -- roster waited for whatever fired the next binding update.
    guildBind:RegisterEvent("PLAYER_ENTERING_WORLD")
    guildBind:SetScript("OnEvent", UpdateGuildBinding)
    -- However the roster came up, it is dressed from here.
    panel:HookScript("OnShow", function()
        if not active then return end
        HideBlizzardPanels()
        SelectOurTab(true)
        DressWindow(true)
        Refresh()
        if ns.RefreshMicroButtons then ns.RefreshMicroButtons() end
    end)
    UpdateGuildBinding()
end

local function HookGuildOpeners()
    local button = GuildMicroButton
    if not button or button.fcuiGuildHooked then return end
    button.fcuiGuildHooked = true
    button:HookScript("OnClick", function()
        if not active then return end
        -- The button's own click already went through the toggle we
        -- wrapped; acting again here would undo it on the same press.
        if togglingAt == GetTime() then return end
        togglingAt = GetTime()
        CloseClientGuildWindows()
        -- A second press closes the roster, as the button's own window does.
        -- What is on screen decides, not the roster's own flag. A window
        -- the client refused to open during a fight left that flag set
        -- with nothing shown, and every press after it read as "close",
        -- so the button did nothing until the next reload.
        ToggleSocial()
    end)
    -- The button stays pressed while the roster is up.
    if ns.MicroButtonFollows then
        ns.MicroButtonFollows(button, SocialShown)
    end
    -- And it says so: the client's own text for this button is about
    -- guilds and communities.
    button:HookScript("OnEnter", function(self)
        if not active or not GameTooltip:IsOwned(self) then return end
        local title = SOCIAL_BUTTON or "Social"
        if type(MicroButtonTooltipText) == "function" then title = MicroButtonTooltipText(title, "TOGGLESOCIAL") end
        GameTooltip:SetText(title, 1, 1, 1)
        if NEWBIE_TOOLTIP_SOCIAL then GameTooltip:AddLine(NEWBIE_TOOLTIP_SOCIAL, 1, 0.82, 0, true) end
        GameTooltip:Show()
    end)
end

local function Apply()
    active = true
    if not FriendsFrame then ns.MissingPiece("FriendsFrame") return end
    -- Never during a fight: see ns.WhenCalm.
    ns.WhenCalm("guild", function()
        if not active then return end
        if not panel then Build() end
        BuildTab()
        HookGuildOpeners()
        WrapGuildToggle()
        BuildSecureOpener()
        -- The button presses the client's own opener, as the key does.
        if BuildSocialOpener() and GuildMicroButton and ns.MapPad then
            ns.MapPad(GuildMicroButton, nil, nil, socialOpen, function() return active end)
        end
        if communitiesTab then communitiesTab:Show() end
        if tab then tab:Show() PlaceTab() end
    end)
end

local function Restore()
    active = false
    if ns.UpdateGuildBinding then ns.UpdateGuildBinding() end
    HideGuild()
    if tab then tab:Hide() end
    if communitiesTab then communitiesTab:Hide() end
    if ns.PlaceSocialTabs then ns.PlaceSocialTabs() end
end

ns.RegisterModule("guildRoster", { apply = Apply, restore = Restore })
