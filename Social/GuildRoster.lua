local _, ns = ...

-- The 1.x guild tab, rebuilt rather than re-anchored: this client keeps the
-- guild in the Communities window, which is left alone.

local G, S = ns.guild, ns.social
local SelectedEntry, LastOnline, GuildMOTD, GuildTitle = G.SelectedEntry, G.LastOnline, G.GuildMOTD, G.GuildTitle

local PILL_BORDER = "Interface\\ClassTrainerFrame\\UI-ClassTrainer-FilterBorder"
local CHECK_UP = ns.ART.CHECK .. "Up"
local CHECK_MARK = ns.ART.CHECK .. "Check"
local CHECK_HOVER = ns.ART.CHECK .. "Highlight"

-- 1.x column proportions.
local COLUMNS = {
    { key = "name", label = NAME or "Name", x = 4, w = 96, justify = "LEFT" },
    { key = "zone", label = ZONE or "Zone", x = 100, w = 112, justify = "LEFT" },
    { key = "level", label = LEVEL_ABBR or "Lvl", x = 212, w = 34, justify = "LEFT" },
    { key = "class", label = CLASS or "Class", x = 246, w = 92, justify = "LEFT" },
}
-- The status view (foot arrow): rank, note, last online in the same slots.
local STATUS_COLUMNS = {
    { key = "name", label = NAME or "Name", x = 4, w = 96 },
    { key = "rank", label = RANK or "Rank", x = 100, w = 80 },
    { key = "note", label = LABEL_NOTE or "Note", x = 180, w = 84 },
    { key = "lastOnline", label = LASTONLINE or "Last Online", x = 264, w = 74 },
}
local ROW_TEXTS = { "Name", "Zone", "Level", "Class" }
local ROSTER_EVENTS = { "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "GUILD_MOTD" }
local statusView = false

-- The offline pill: the trainer's filter border cut in three.
local OFFLINE_PILL = {
    { key = PILL_BORDER, set = "raw", layer = "BACKGROUND", w = 12, h = 28, coords = { 0.90625, 1, 0, 1 }, point = "TOPRIGHT", y = 3 },
    { key = PILL_BORDER, set = "raw", layer = "BACKGROUND", w = 186, h = 28, coords = { 0.09375, 0.90625, 0, 1 }, point = "RIGHT", relPoint = "LEFT", chain = true },
    { key = PILL_BORDER, set = "raw", layer = "BACKGROUND", w = 12, h = 28, coords = { 0, 0.09375, 0, 1 }, point = "RIGHT", relPoint = "LEFT", chain = true },
}
local OFFLINE_BOX = { set = "raw", layer = "ARTWORK", w = 22, h = 22, point = "RIGHT", x = -6, y = 2 }
local OFFLINE_CHECK = { set = "raw", layer = "OVERLAY", w = 22, h = 22, point = "CENTER" }
local OFFLINE_HOVER = { set = "raw", layer = "HIGHLIGHT", blend = "ADD", w = 22, h = 22, point = "CENTER" }
local RANK_ARROW = { coords = { 0.25, 0.75, 0.25, 0.75 }, add = true }
local STATUS_ARROW = { add = true }
local NOTE_BOX = { bronze = false, bg = { 0, 0, 0, 0.85 }, border = { 0.78, 0.78, 0.78 } }
local STATUS_TIP = { text = function()
    return statusView and (GUILD_STATUS or "Guild Status") or (PLAYER_STATUS or "Player Status")
end, r = 1, g = 1, b = 1 }

---------------------------------------------------------------- the list

local function UpdateRows()
    local panel = G.panel
    if not panel then return end
    local roster, selected = G.roster, G.selected
    local offset = math.floor((panel.bar:GetValue() or 0) + 0.5)
    local shown = S.RowCount(panel)
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
    -- The arrow beside the scroll column when shown, else by the box's edge.
    if panel.status then
        panel.status:ClearAllPoints()
        panel.status:SetPoint("BOTTOMRIGHT", panel.listBox, "BOTTOMRIGHT", panel.bar:IsShown() and -32 or -8, 2)
    end
    -- The note pads follow what the rows now hold.
    G.SyncBridge()
end

-- The current view's columns onto the headers and row texts.
local function ApplyView()
    local panel = G.panel
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
    local panel = G.panel
    if not panel then return end
    panel.control:SetEnabled(IsGuildLeader and IsGuildLeader() and true or false)
    panel.add:SetEnabled(CanGuildInvite and CanGuildInvite() and true or false)
end

local function Refresh()
    local panel = G.panel
    if not panel or not panel:IsShown() then return end
    local total, online = G.CollectRoster()
    G.SortRoster()
    panel.totals:SetText(format(GUILD_TOTAL or "%d Guild Members", total))
    panel.online:SetText(format(GUILD_TOTALONLINE or "(%d Online)", online))
    panel.motd:SetText(GuildMOTD())
    panel.offline:SetChecked(G.ShowOffline())
    if FriendsFrameTitleText then FriendsFrameTitleText:SetText(GuildTitle()) end
    UpdateRows()
    UpdateButtons()
    ns.UpdateGuildPopout()
end
G.Refresh = Refresh

-- Reread after combat what the fight held back.
local regen = CreateFrame("Frame")
regen:RegisterEvent("PLAYER_REGEN_ENABLED")
regen:SetScript("OnEvent", function()
    if G.panel and G.panel:IsShown() then Refresh() end
end)

-- A C_GuildInfo call by name, where this client has it.
local function GuildCall(method, name)
    local call = C_GuildInfo and C_GuildInfo[method]
    if call then call(name) end
end

-- A popout button's handler: the call on the selected member.
local function OnSelected(method)
    return function()
        local entry = SelectedEntry()
        if entry then GuildCall(method, entry.name) end
    end
end

-- Right-click menu; closes on a click elsewhere or with the roster.
local rowMenu

local function NotMe(entry) return entry.name ~= UnitName("player") end

local function ShowRowMenu(entry)
    if not rowMenu then
        rowMenu = ns.RowMenu({
            { WHISPER or "Whisper", function(e) ns.Whisper(e.name) end,
              function(e) return NotMe(e) and e.online end },
            { INVITE or "Invite", function(e) S.Invite(e.name) end,
              function(e) return NotMe(e) and e.online end },
            { ADD_FRIEND or "Add Friend", function(e) S.AddFriend(e.name) end,
              NotMe },
            { GUILD_PROMOTE or "Promote", function(e) GuildCall("Promote", e.name) end,
              function(e) return NotMe(e) and CanGuildPromote and CanGuildPromote() end },
            { GUILD_DEMOTE or "Demote", function(e) GuildCall("Demote", e.name) end,
              function(e) return NotMe(e) and CanGuildDemote and CanGuildDemote() end },
            { REMOVE or "Remove", function(e) GuildCall("Uninvite", e.name) end,
              function(e) return NotMe(e) and CanGuildRemove and CanGuildRemove() end },
        })
        rowMenu:Follow(G.panel)
    end
    rowMenu:Open(entry, entry.name)
end

local function Row_OnClick(self, button)
    if not self.entry then return end
    if button == "RightButton" then
        G.selected = self.entry.index
        UpdateRows()
        ShowRowMenu(self.entry)
        ns.UpdateGuildPopout()
        return
    end
    G.selected = self.entry.index
    if SetGuildRosterSelection then pcall(SetGuildRosterSelection, self.entry.index) end
    UpdateRows()
    -- Picking a member opens their status, as the old roster did.
    local panel = G.panel
    if panel and panel.popout then panel.popout:Show() end
    ns.UpdateGuildPopout()
end
G.Row_OnClick = Row_OnClick

local function Row_OnDoubleClick(self)
    if not self.entry or not self.entry.online then return end
    ns.Whisper(self.entry.name)
end
G.Row_OnDoubleClick = Row_OnDoubleClick

-- The client sorts its roster by our field too, so repeat clicks turn it as 1.x did.
local function Header_OnClick(self)
    S.ToggleSort(G.sort, self.key)
    if SortGuildRoster then pcall(SortGuildRoster, self.key) end
    Refresh()
end

-- The client's panels in the window, hidden while the roster is up.
local hidden = { key = "fcuiGuildHidden", swept = "fcuiGuildSwept", pending = false }
local settle = CreateFrame("Frame")
settle:RegisterEvent("PLAYER_REGEN_ENABLED")
settle:SetScript("OnEvent", function() S.Settle(hidden) end)

function G.HideBlizzardPanels() S.HidePanels(hidden, G.panel) end
function G.ShowBlizzardPanels() S.ShowPanels(hidden) end

---------------------------------------------------------------- the popout

-- The 1.x member details and the buttons that act on them.
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
    ns.DressStates(button, key .. "ButtonUp", key .. "ButtonDown", key .. "ButtonDisabled", key .. "ButtonHighlight", RANK_ARROW)
    button:SetScript("OnClick", onClick)
    return button
end

-- A note box's hint for whoever may write notes, when the client's box is not over ours.
local function NoteHint(self)
    if not self.mayEdit then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.Label:GetText() or "", 1, 1, 1)
    GameTooltip:AddLine("Out of combat, click the member in the list, then click here to write the note.", nil, nil, nil, true)
    GameTooltip:Show()
end

-- A read-only note box: saving is the client's alone, via the note bridge pads.
local function NoteBox(out, labelText, anchor, gap)
    local label = out:CreateFontString(nil, "ARTWORK")
    label:SetFontObject(ns.FONT_GOLD_SMALL or "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gap)
    label:SetText(labelText)
    local box = CreateFrame("Button", nil, out, ns.BACKDROP_TEMPLATE)
    box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
    box:SetPoint("RIGHT", out, "RIGHT", -14, 0)
    box:SetHeight(40)
    ns.Backdrop(box, ns.BACKDROP.FLAT12, NOTE_BOX)
    box.Text = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    box.Text:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -6)
    box.Text:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 6)
    box.Text:SetJustifyH("LEFT")
    box.Text:SetJustifyV("TOP")
    box.Label = label
    box:SetScript("OnEnter", NoteHint)
    box:SetScript("OnLeave", ns.HideTip)
    return box
end

local function BuildPopout(host)
    -- Named: the friends-window sweep hides every unnamed child.
    local out = CreateFrame("Frame", "ClassicUIForeverGuildMember", host, ns.BACKDROP_TEMPLATE)
    ns.Backdrop(out, ns.BACKDROP.DIALOG)
    out:SetSize(206, 250)
    out:SetPoint("TOPLEFT", host, "TOPRIGHT", -6, -70)
    out:SetFrameLevel(host:GetFrameLevel() + 10)
    out:EnableMouse(true)
    out:Hide()

    out.title = out:CreateFontString(nil, "ARTWORK")
    out.title:SetFontObject(ns.FONT_GOLD or "GameFontNormal")
    out.title:SetPoint("LEFT", out, "TOPLEFT", 14, -20)
    out.title:SetPoint("RIGHT", out, "TOPRIGHT", -32, -20)
    out.title:SetJustifyH("LEFT")
    out.close = ns.DialogClose(out, function() out:Hide() end, 2, 2)

    out.level = out:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    out.level:SetPoint("TOPLEFT", out, "TOPLEFT", 14, -40)

    out.zone = PopoutLine(out, out.level, (ZONE or "Zone") .. ":")
    out.rank = PopoutLine(out, out.zone, (RANK or "Rank") .. ":")
    out.lastOnline = PopoutLine(out, out.rank, (LASTONLINE or "Last Online") .. ":")

    -- Promote and demote are the arrows beside the rank, as in 1.x.
    out.promote = RankArrow(out.rank, "scrollUp", out.rank.Value, 6, OnSelected("Promote"))
    out.demote = RankArrow(out.rank, "scrollDown", out.promote, 2, OnSelected("Demote"))

    -- Only the guild master may hand the guild over.
    out.guildmaster = ns.PanelButton(out, GUILD_PROMOTE_TO_GM or "Promote to Guild Master", 186)
    out.guildmaster:SetPoint("BOTTOMLEFT", out, "BOTTOMLEFT", 14, 42)
    out.guildmaster:SetScript("OnClick", OnSelected("SetLeader"))

    out.remove = ns.PanelButton(out, REMOVE or "Remove", 90)
    out.remove:SetPoint("BOTTOMLEFT", out, "BOTTOMLEFT", 14, 16)
    out.remove:SetScript("OnClick", OnSelected("Uninvite"))

    out.invite = ns.PanelButton(out, GROUP_INVITE or "Group Invite", 90)
    out.invite:SetPoint("LEFT", out.remove, "RIGHT", 4, 0)
    out.invite:SetScript("OnClick", function()
        local entry = SelectedEntry()
        if entry then S.Invite(entry.name) end
    end)

    out.noteBox = NoteBox(out, (LABEL_NOTE or "Note") .. ":", out.lastOnline, -6)
    out.officerBox = NoteBox(out, GUILD_OFFICERNOTE_LABEL or OFFICER_NOTE_COLON or "Officer's Note", out.noteBox, -5)
    return out
end

function ns.UpdateGuildPopout(fromBridge)
    local panel = G.panel
    if not panel or not panel.popout or not panel.popout:IsShown() then return end
    local out = panel.popout
    local entry = SelectedEntry()
    local me = UnitName("player")
    -- Whether the client's note boxes lie over ours for this member.
    if not fromBridge then G.DockNotes() end
    local live = ns.GuildNotesLive(entry)
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
    -- The officer's note only for those the guild lets see it.
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

---------------------------------------------------------------- the panel

function G.Build()
    local host = FriendsFrame
    if not host then return end
    local panel = S.NewPanel(host, "ClassicUIForeverGuildPanel")
    G.panel = panel

    -- Show Offline Members, the old pill under the title bar; the empty box shows either way.
    local offline = CreateFrame("CheckButton", nil, panel)
    panel.offline = offline
    offline:SetSize(210, 23)
    offline:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 30)
    ns.DressPieces(offline, OFFLINE_PILL)
    local box = ns.DressNew(offline, CHECK_UP, OFFLINE_BOX)
    local check = ns.DressNew(offline, CHECK_MARK, OFFLINE_CHECK, box)
    offline:SetCheckedTexture(check)
    ns.DressNew(offline, CHECK_HOVER, OFFLINE_HOVER, box)
    local offlineText = offline:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    offlineText:SetPoint("CENTER", offline, "CENTER", -3, 2)
    offlineText:SetText(SHOW_OFFLINE_MEMBERS or "Show Offline Members")
    offline:SetScript("OnClick", function(self)
        if SetGuildRosterShowOffline then pcall(SetGuildRosterShowOffline, self:GetChecked() and true or false) end
        if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
        Refresh()
    end)

    -- The foot: the three old buttons.
    panel.add = ns.PanelButton(panel, ADDMEMBER or "Add Member", 118)
    panel.add:SetPoint("BOTTOM", panel, "BOTTOM", 4, -8)
    panel.add:SetScript("OnClick", function()
        -- The client's dialog errors unless told the guild's club.
        if StaticPopup_Show then
            local clubId = C_Club and C_Club.GetGuildClubId and C_Club.GetGuildClubId()
            StaticPopup_Show("ADD_GUILDMEMBER", nil, nil, { clubId = clubId })
        end
    end)

    panel.control = ns.PanelButton(panel, GUILDCONTROL or "Guild Control", 110)
    panel.control:SetPoint("LEFT", panel.add, "RIGHT", 2, 0)
    panel.control:SetScript("OnClick", function()
        -- Loaded on demand; the client's own opener loads and shows it.
        if GuildControlUI and GuildControlUI:IsShown() then
            ns.HidePanel(GuildControlUI)
        elseif type(GuildControlUI_Show) == "function" then
            GuildControlUI_Show()
            -- The client places it for the wider modern window: moved beside the roster next frame.
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
        -- The client's guild window via the kept toggle; the ghost is dropped first.
        G.DropGhost()
        if G.clientToggleGuild then G.clientToggleGuild() elseif ToggleGuildFrame then ToggleGuildFrame() end
    end)

    -- The guild message over the buttons, iron bars either side.
    panel.lowerBar = ns.StoneBar(panel)
    panel.lowerBar:SetPoint("BOTTOM", panel.info, "TOP", 0, 1)
    S.Span(panel.lowerBar, host)

    panel.motdBox = ns.SectionBox(panel)
    panel.motdBox:SetPoint("BOTTOM", panel.lowerBar, "TOP", 0, 1)
    S.Span(panel.motdBox, host)
    panel.motdBox:SetHeight(74)

    panel.upperBar = ns.StoneBar(panel)
    panel.upperBar:SetPoint("BOTTOM", panel.motdBox, "TOP", 0, 1)
    S.Span(panel.upperBar, host)

    local motdLabel = panel.motdBox:CreateFontString(nil, "ARTWORK")
    motdLabel:SetFontObject(ns.FONT_GOLD_SMALL or "GameFontNormalSmall")
    motdLabel:SetPoint("TOPLEFT", panel.motdBox, "TOPLEFT", 8, -8)
    -- The client's string lost "Guild" and the colon; English gets the old words outright.
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

    G.BuildMotdPad(panel)

    -- The column plates, then the list in its box; the counts are its last line.
    local headerRow
    headerRow, panel.headers = S.HeaderRow(panel, host, COLUMNS, Header_OnClick)
    panel.listBox = S.ListBox(panel, host, headerRow, panel.upperBar)

    panel.totals = panel.listBox:CreateFontString(nil, "ARTWORK")
    panel.totals:SetFontObject(ns.FONT_GOLD_SMALL or "GameFontNormalSmall")
    panel.totals:SetPoint("BOTTOMLEFT", panel.listBox, "BOTTOMLEFT", 8, 6)

    panel.online = panel.listBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    panel.online:SetPoint("LEFT", panel.totals, "RIGHT", 4, 0)
    panel.online:SetTextColor(0.1, 1, 0.1)

    -- The arrow at the foot turns the roster over; its tooltip says to which face.
    panel.status = CreateFrame("Button", nil, panel.listBox)
    panel.status:SetSize(28, 28)
    panel.status:SetPoint("BOTTOMRIGHT", panel.listBox, "BOTTOMRIGHT", -8, 2)
    ns.DressStates(panel.status, "sbNextUp", "sbNextDown", nil, "mouseHighlight", STATUS_ARROW)
    ns.AttachTip(panel.status, STATUS_TIP)

    panel.popout = BuildPopout(host)
    panel.status:SetScript("OnClick", function(self)
        statusView = not statusView
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        ApplyView()
        -- A sort by a column the new face lacks falls back to the name.
        local columns = statusView and STATUS_COLUMNS or COLUMNS
        local known = false
        for _, column in ipairs(columns) do if column.key == G.sort.field then known = true end end
        if not known then G.sort.field, G.sort.reverse = "name", false end
        Refresh()
        if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
    end)

    S.ScrollRows(panel, panel.totals, 4, UpdateRows, COLUMNS, Row_OnClick, Row_OnDoubleClick)

    panel:SetScript("OnShow", function()
        if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
        Refresh()
    end)
    panel:SetScript("OnHide", function() if panel.popout then panel.popout:Hide() end end)

    -- Roster events burst: a refresh at most every 0.33 s. Idle, the frame
    -- hides (events still arrive) until one wakes it.
    local driver = CreateFrame("Frame")
    ns.RegisterEvents(driver, ROSTER_EVENTS)
    driver:SetScript("OnEvent", function(self)
        self.dirty = true
        G.bridge.stale = true
        if not self:IsShown() then self:Show() end
    end)
    driver:SetScript("OnUpdate", function(self, elapsed)
        self.wait = (self.wait or 0) - elapsed
        if not self.dirty then
            if self.wait <= 0 then self:Hide() end
            return
        end
        if self.wait > 0 then return end
        self.dirty, self.wait = false, 0.33
        if G.active then Refresh() end
    end)
    panel.driver = driver
end
