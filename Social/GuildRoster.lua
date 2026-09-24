local _, ns = ...

-- The 1.x guild tab, rebuilt rather than re-anchored: this client keeps the
-- guild in the Communities window, which is left alone.

local G, S = ns.guild, ns.social
local EntryKey, LastOnline, GuildMOTD, GuildTitle = G.EntryKey, G.LastOnline, G.GuildMOTD, G.GuildTitle

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
local STATUS_ARROW = { add = true }
local STATUS_TIP = { text = function()
    return statusView and (GUILD_STATUS or "Guild Status") or (PLAYER_STATUS or "Player Status")
end, r = 1, g = 1, b = 1 }

---------------------------------------------------------------- the list

local function UpdateRows()
    local panel = G.panel
    if not panel then return end
    local roster, selected = G.roster, G.selected
    local offset = ns.ListOffset(panel.bar)
    local shown = S.RowCount(panel)
    for i, row in ipairs(panel.rows) do
        local entry = i <= shown and roster[offset + i] or nil
        if not entry then
            S.HideRow(row)
        elseif statusView then
            -- Rank, note and last online in the zone, level and class slots, uncoloured.
            S.ShowRow(row, entry, entry.rank, entry.note, LastOnline(entry), nil, EntryKey(entry) == selected, not entry.online)
        else
            S.ShowRow(row, entry, entry.zone, entry.level, entry.class, entry.classFile, EntryKey(entry) == selected, not entry.online)
        end
    end
    panel.bar:SetRange(math.max(0, #roster - shown))
    -- The arrow beside the scroll column when shown, else by the box's edge.
    ns.SetPointOnce(panel.status, "BOTTOMRIGHT", panel.listBox, "BOTTOMRIGHT", panel.bar:IsShown() and -32 or -8, 2)
    -- The row pads follow what the rows now hold.
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
            ns.SetPointOnce(text, "LEFT", row, "LEFT", column.x, 0)
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

-- The member's status is the client's own frame, opened by the row pad's click on its row.
local function Row_OnClick(self, button)
    if not self.entry then return end
    G.selected = EntryKey(self.entry)
    if button == "RightButton" then
        UpdateRows()
        ShowRowMenu(self.entry)
        return
    end
    if SetGuildRosterSelection then pcall(SetGuildRosterSelection, self.entry.index) end
    UpdateRows()
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
S.SettleFrame(hidden)

function G.HideBlizzardPanels() S.HidePanels(hidden, G.panel) end
function G.ShowBlizzardPanels() S.ShowPanels(hidden) end

---------------------------------------------------------------- the panel

-- The bar runs the box's full height: from its top edge down beside the counts, its column's foot on the box's foot.
local function PlaceBar(bar, list)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, -13)
    bar:SetPoint("BOTTOMLEFT", G.panel.listBox, "BOTTOMRIGHT", -20, 20)
end

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
            ns.Sched.NextFrame("guild.controlPlace", function()
                if GuildControlUI and GuildControlUI:IsShown() and host:IsShown() and not InCombatLockdown() then
                    ns.SetPointOnce(GuildControlUI, "TOPLEFT", host, "TOPRIGHT", 6, 0)
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

    S.ScrollRows(panel, panel.totals, 4, UpdateRows, COLUMNS, Row_OnClick, Row_OnDoubleClick, PlaceBar)
    -- After the rows: the bridge hears the mouse on them.
    G.WatchBridge(panel)

    panel:SetScript("OnShow", function()
        if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
        Refresh()
    end)
    -- The client's member frame closes with the ghost: no pick stays lit for reopening.
    panel:SetScript("OnHide", function() G.selected = nil end)

    -- Roster events burst: a refresh at most every 0.33 s. Idle, the frame
    -- hides (events still arrive) until one wakes it.
    local driver = ns.EventFrame(ROSTER_EVENTS, function(self)
        self.dirty = true
        G.bridge.stale = true
        if not self:IsShown() then self:Show() end
    end)
    ns.Sched.OnFrame(driver, { name = "guild.rosterDriver", every = 0, fn = function(_, elapsed)
        driver.wait = (driver.wait or 0) - elapsed
        if not driver.dirty then
            if driver.wait <= 0 then driver:Hide() end
            return
        end
        if driver.wait > 0 then return end
        driver.dirty, driver.wait = false, 0.33
        if G.active then Refresh() end
    end })
    panel.driver = driver
end
