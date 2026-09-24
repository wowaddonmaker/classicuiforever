local _, ns = ...

-- Shared by the guild roster and who list. Helpers only: each module owns its
-- frames, hooks and settle frame, and calls these at its own build points.

local S = {}
ns.social = S

local ROW_H = 16

-- The client's panels inside the social window, faded under our lists.
local CLIENT_PANELS = { "FriendsListFrame", "IgnoreListFrame", "WhoFrame", "RaidFrame", "QuickJoinFrame", "FriendsFrameBroadcastInput" }

-- The old gold list bar: raw path (the bundled key would swap to bronze), sheet tail cut off.
local GOLD_SEL = { set = "raw", layer = "BACKGROUND", fill = true, blend = "ADD", vertex = { 1, 0.82, 0, 1 },
    coords = { 0, 0.97, 0, 1 }, show = false }
local GOLD_HL = { set = "raw", layer = "HIGHLIGHT", fill = true, blend = "ADD", vertex = { 1, 0.82, 0, 1 },
    coords = { 0, 0.97, 0, 1 } }

---------------------------------------------------------------- tabs

-- The client's own tabs along the window's foot, a new list each call.
function S.FriendsFrameTabs()
    local tabs = {}
    for i = 1, 8 do
        local frame = _G["FriendsFrameTab" .. i]
        if frame then tabs[#tabs + 1] = frame end
    end
    return tabs
end

-- Our tab up (every client tab down) or down.
function S.SelectFriendsTab(tab, on)
    if on then
        if PanelTemplates_SelectTab then PanelTemplates_SelectTab(tab) end
        for _, other in ipairs(S.FriendsFrameTabs()) do
            if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(other) end
        end
    else
        if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab) end
    end
    if ns.FitBottomTab then ns.FitBottomTab(tab) end
end

function S.NewTab(host, name, id, text)
    local tab = CreateFrame("Button", name, host, "PanelTabButtonTemplate")
    tab:SetID(id)
    tab:SetText(text)
    if ns.SkinBottomTab then ns.SkinBottomTab(tab) end
    return tab
end

-- A module's hooks on the social window, in chain order: client tab
-- clicks, ShowSubFrame (who only), Update, OnShow, OnHide.
function S.HookFriendsFrame(host, h)
    for _, other in ipairs(S.FriendsFrameTabs()) do
        other:HookScript("OnClick", h.tabClick)
    end
    if h.showSubFrame and type(FriendsFrame_ShowSubFrame) == "function" then
        hooksecurefunc("FriendsFrame_ShowSubFrame", h.showSubFrame)
    end
    if type(FriendsFrame_Update) == "function" then
        hooksecurefunc("FriendsFrame_Update", h.update)
    end
    host:HookScript("OnShow", h.onShow)
    host:HookScript("OnHide", h.onHide)
end

-- 1.x tab order: Friends, Who, Guild, Communities, then the client's others.
-- The client's gap is measured once, before anything moves.
local tabGap
local SOCIAL_TAB_PAD = 38
function S.PlaceTabs()
    local blizzard = S.FriendsFrameTabs()
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
    local whoTab = S.whoTab
    if whoTab then order[#order + 1] = whoTab end
    local guildTab = _G["ClassicUIForeverGuildTab"]
    if guildTab then order[#order + 1] = guildTab end
    local communitiesTab = _G["ClassicUIForeverCommunitiesTab"]
    if communitiesTab then order[#order + 1] = communitiesTab end
    for i = 2, #blizzard do
        if blizzard[i] then order[#order + 1] = blizzard[i] end
    end
    -- Five tabs where 1.x had four: 19 either side of the label, not 25.
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
ns.PlaceSocialTabs = S.PlaceTabs

-------------------------------------------------------- client panels

-- state = { key = hidden mark, swept = sweep mark, pending = false }, one per
-- module. Its settle frame calls this on REGEN_ENABLED to set the mouse combat refused.
function S.Settle(state)
    if not state.pending then return end
    state.pending = false
    for _, name in ipairs(CLIENT_PANELS) do
        local frame = _G[name]
        if frame and frame.EnableMouse then
            -- A panel either list holds down stays down.
            frame:EnableMouse(not (frame.fcuiGuildHidden or frame.fcuiWhoHidden))
        end
    end
end

function S.HidePanels(state, panel)
    local key = state.key
    for _, name in ipairs(CLIENT_PANELS) do
        local frame = _G[name]
        if frame and frame:IsShown() then
            frame:SetAlpha(0)
            -- The client refuses mouse changes on its frames in a fight; alpha alone hides it until then.
            if frame.EnableMouse and not InCombatLockdown() then
                frame:EnableMouse(false)
            else
                state.pending = true
            end
            frame[key] = true
        end
    end
    local header = FriendsFrame and FriendsFrame.FriendsTabHeader
    if header then header:SetAlpha(0) end
    ns.SweepFriendsFrame(state.swept, true)
    ns.KeepFriendsSwept(panel, state.swept)
end

function S.ShowPanels(state)
    local key = state.key
    for _, name in ipairs(CLIENT_PANELS) do
        local frame = _G[name]
        if frame and frame[key] then
            frame:SetAlpha(1)
            if frame.EnableMouse and not InCombatLockdown() then
                frame:EnableMouse(true)
            else
                state.pending = true
            end
            frame[key] = nil
        end
    end
    local header = FriendsFrame and FriendsFrame.FriendsTabHeader
    if header then header:SetAlpha(1) end
    ns.SweepFriendsFrame(state.swept, false)
end

---------------------------------------------------------------- lists

-- Across the window, 5 in from either side.
local function Span(frame, host)
    frame:SetPoint("LEFT", host, "LEFT", 5, 0)
    frame:SetPoint("RIGHT", host, "RIGHT", -5, 0)
end
S.Span = Span

-- A module's hidden panel over the window's body, above the client's.
function S.NewPanel(host, name)
    local panel = CreateFrame("Frame", name, host)
    panel:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -64)
    panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -8, 12)
    panel:SetFrameLevel(host:GetFrameLevel() + 6)
    panel:Hide()
    return panel
end

function S.RowCount(panel)
    if not panel then return 0 end
    return math.max(1, math.floor((panel.list:GetHeight() or 0) / ROW_H))
end

-- A list row: gold bar on the chosen row and under the mouse, one text per column (row.Name, row.Zone, ...).
local function ListRow(parent, index, columns, onClick, onDoubleClick)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(index - 1) * ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.Selected = ns.DressNew(row, ns.ART.GOLD_BAR, GOLD_SEL)
    ns.DressNew(row, ns.ART.GOLD_BAR, GOLD_HL)
    for _, column in ipairs(columns) do
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        text:SetPoint("LEFT", row, "LEFT", column.x, 0)
        text:SetWidth(column.w)
        text:SetJustifyH(column.justify)
        text:SetWordWrap(false)
        row[column.key:gsub("^%l", string.upper)] = text
    end
    row:SetScript("OnClick", onClick)
    row:SetScript("OnDoubleClick", onDoubleClick)
    return row
end

-- The column plates on a band of the window's stone; each(header, column)
-- runs as each plate is made. Returns the header row and the plates.
function S.HeaderRow(panel, host, columns, onClick, each)
    local headerBand = CreateFrame("Frame", nil, panel)
    headerBand:SetHeight(22)
    headerBand:SetPoint("TOP", panel, "TOP", 0, 1)
    Span(headerBand, host)
    local stone = ns.StoneFill(headerBand, "BACKGROUND")
    stone:SetAllPoints(headerBand)

    local headerRow = CreateFrame("Frame", nil, panel)
    headerRow:SetHeight(20)
    headerRow:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    headerRow:SetPoint("RIGHT", panel, "RIGHT", -22, 0)
    local headers, last = {}, nil
    for _, column in ipairs(columns) do
        last = ns.ColumnHeader(headerRow, column, last, onClick)
        headers[#headers + 1] = last
        if each then each(last, column) end
    end
    return headerRow, headers
end

-- The box the list sits in, from under the plates down to bottom.
function S.ListBox(panel, host, headerRow, bottom)
    local box = ns.SectionBox(panel)
    box:SetPoint("TOP", headerRow, "BOTTOM", 0, -5)
    Span(box, host)
    box:SetPoint("BOTTOM", bottom, "TOP", 0, 1)
    return box
end

-- The list over foot (gap above it), its bar and 30 rows. placeBar(bar,
-- list) re-anchors the bar before its column is put on.
function S.ScrollRows(panel, foot, gap, onValue, columns, onClick, onDoubleClick, placeBar)
    local list = CreateFrame("Frame", nil, panel.listBox)
    list:SetPoint("TOPLEFT", panel.listBox, "TOPLEFT", 8, -4)
    list:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT", 0, gap)
    list:SetPoint("RIGHT", panel.listBox, "RIGHT", -26, 0)
    list:EnableMouseWheel(true)
    panel.list = list

    local bar = ns.ClassicScrollBar(panel, list, onValue)
    panel.bar = bar
    if placeBar then placeBar(bar, list) end
    -- No bar until the list outgrows its box, then the old scroll column round it.
    bar.hideWhenIdle = true
    if ns.ScrollColumnOn then ns.ScrollColumnOn(bar) end
    list:SetScript("OnMouseWheel", function(_, delta)
        bar:SetValue((bar:GetValue() or 0) - delta)
    end)

    panel.rows = {}
    for i = 1, 30 do panel.rows[i] = ListRow(list, i, columns, onClick, onDoubleClick) end
    return list
end

-- A second click on the same column turns the order round.
function S.ToggleSort(sort, key)
    if sort.field == key then
        sort.reverse = not sort.reverse
    else
        sort.field, sort.reverse = key, false
    end
end

---------------------------------------------------------------- names

function S.Invite(name)
    if C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(name) end
end

function S.AddFriend(name)
    if C_FriendList and C_FriendList.AddFriend then C_FriendList.AddFriend(name) end
end

---------------------------------------------------------------- recent allies

-- Invite button pulled in off the scroll column; the pin and clock icons move with it.
local INVITE_X = -4
local alliesWatch, alliesCount

local function PlaceAllyRow(row)
    if row.fcuiPlaced then return end
    row.fcuiPlaced = true
    local button, icons = row.PartyButton, row.StateIconContainer
    if button then
        button:ClearAllPoints()
        button:SetPoint("RIGHT", row, "RIGHT", INVITE_X, 0)
    end
    if icons then
        icons:ClearAllPoints()
        icons:SetPoint("TOPRIGHT", row, "TOPRIGHT", INVITE_X - 24, 0)
    end
end

-- Pooled rows keep our anchors, so only a new row needs placing.
local function AlliesChanged(job)
    local n = job.target:GetNumChildren()
    if n ~= alliesCount then
        alliesCount = n
        return true
    end
end

local function PlaceAllies(job)
    ns.EachChild(job.target, PlaceAllyRow)
end

-- The watch hangs under the list, so it only runs while the tab shows.
function ns.PlaceRecentAllyRows()
    local host = _G["RecentAlliesFrame"]
    local list = host and host.List
    local target = list and list.ScrollBox and list.ScrollBox.ScrollTarget
    if alliesWatch or not target then return end
    alliesWatch = CreateFrame("Frame", nil, list)
    local job = ns.Sched.OnFrame(alliesWatch, { name = "friends.recentAllies", every = 0.25, pre = AlliesChanged, fn = PlaceAllies })
    job.target = target
end
