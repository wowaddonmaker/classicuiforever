local _, ns = ...

-- The 1.x quest log window on the modern quest API; also takes the 3.x double pane shape.

local QL = ns.QL
local CollectEntries, SetAllCollapsed, ToggleHeader = QL.CollectEntries, QL.SetAllCollapsed, QL.ToggleHeader
local QuestInLog, FirstQuest, TagFor, LevelColor = QL.QuestInLog, QL.FirstQuest, QL.TagFor, QL.LevelColor
local IsWatched, SetWatched, PartyOnQuest = QL.IsWatched, QL.SetWatched, QL.PartyOnQuest
local ART = ns.ART

local WIDTH, HEIGHT = 384, 512
local ROWS, ROW_H, ROW_GAP = 6, 15, 0.6   -- six rows fill the 93px track exactly
local LIST_X, LIST_Y, LIST_W = 19, -75, 300
local LIST_H = 93   -- the art's list track; rows clip to it
local DETAIL_GAP, DETAIL_H = 7, 260
local TITLE_TAG_ROOM = 275
-- 3.x double pane, measured from its two sheets; the frame is their opaque extent.
local DUAL = { WIDTH = 680, HEIGHT = 440, LIST_X = 20, LIST_Y = -76, LIST_W = 296, LIST_H = 332, ROWS = 21,
    DETAIL_X = 352, DETAIL_Y = -80, DETAIL_W = 292, DETAIL_H = 328 }
local MAX_ROWS = DUAL.ROWS

local FRAME_NAME = "ForeverClassicUIQuestLog"   -- named by string in BarSkins' MICRO_WINDOWS

local frame
local countdown   -- 1s redraw for a timed quest
local rows = {}
local selectedID

local function Rows() return (frame and frame.dual) and DUAL.ROWS or ROWS end
local function DetailHeight() return (frame and frame.dual) and DUAL.DETAIL_H or DETAIL_H end

local CHECK_MARK = ART.CHECK .. "Check"
local RADIO = "Interface\\Buttons\\UI-RadioButton"
local INPUT = "Interface\\Common\\Common-Input-Border"

local SINGLE_ART = {
    { key = "questLogTopLeft", layer = "BACKGROUND", w = 256, h = 256, point = "TOPLEFT" },
    { key = "questLogTopRight", layer = "BACKGROUND", w = 128, h = 256, point = "TOPRIGHT" },
    { key = "questLogBotLeft", layer = "BACKGROUND", w = 256, h = 256, point = "BOTTOMLEFT" },
    { key = "questLogBotRight", layer = "BACKGROUND", w = 128, h = 256, point = "BOTTOMRIGHT" },
}
local DUAL_ART = {
    { key = "questLogDualLeft", layer = "BACKGROUND", w = 512, h = 512, point = "TOPLEFT" },
    { key = "questLogDualRight", layer = "BACKGROUND", w = 256, h = 512, point = "TOPLEFT", x = 512 },
}
local EMPTY_ART = {
    { key = "questLogEmptyTopLeft", layer = "BACKGROUND", w = 256, h = 256, point = "TOPLEFT" },
    { key = "questLogEmptyTopRight", layer = "BACKGROUND", w = 64, h = 256, point = "TOPRIGHT", x = -64 },
    { key = "questLogEmptyBotLeft", layer = "BACKGROUND", w = 256, h = 128, point = "BOTTOMLEFT", y = 128 },
    { key = "questLogEmptyBotRight", layer = "BACKGROUND", w = 64, h = 128, point = "BOTTOMRIGHT", x = -64, y = 128 },
}
local BOOK = { layer = "ARTWORK", w = 64, h = 64, point = "TOPLEFT", x = 4, y = -4 }
-- Built right to left; the middle is sized to the text in UpdateList.
local COUNT_BOX = {
    { key = INPUT, set = "raw", layer = "ARTWORK", coords = { 0.9375, 1, 0, 0.625 }, w = 8, h = 20,
        point = "TOPRIGHT", x = -47, y = -41 },
    { key = INPUT, set = "raw", layer = "ARTWORK", coords = { 0.0625, 0.9375, 0, 0.625 }, w = 100, h = 20,
        point = "RIGHT", relPoint = "LEFT", chain = true },
    { key = INPUT, set = "raw", layer = "ARTWORK", coords = { 0, 0.0625, 0, 0.625 }, w = 8, h = 20,
        point = "RIGHT", relPoint = "LEFT", chain = true },
}
-- All three under the ARTWORK minus icon.
local ALL_TAB = {
    { key = "questLogTabLeft", layer = "BACKGROUND", w = 8, h = 32, point = "TOPLEFT", x = -6, y = 8 },
    { key = "questLogTabMiddle", layer = "BACKGROUND", w = 38, h = 32, point = "LEFT", relPoint = "RIGHT", chain = true },
    { key = "questLogTabRight", layer = "BACKGROUND", w = 8, h = 32, point = "LEFT", relPoint = "RIGHT", chain = true },
}

-- Log, watch, roster and money changes refill the window.
local LOG_EVENTS = { "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "UNIT_QUEST_LOG_CHANGED", "GROUP_ROSTER_UPDATE",
    "PLAYER_MONEY" }
-- Party changes refill the rows; a quest giver's window closes the log.
local PARTY_EVENTS = { "PARTY_MEMBER_ENABLE", "PARTY_MEMBER_DISABLE" }
local GIVER_EVENTS = { "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "GOSSIP_SHOW" }
local PARTY, GIVER = {}, {}
for i = 1, #PARTY_EVENTS do PARTY[PARTY_EVENTS[i]] = true end
for i = 1, #GIVER_EVENTS do GIVER[GIVER_EVENTS[i]] = true end

local UpdateAll, Layout, FillRow

local function CloseLog() ns.HideQuestLog() end

local function CheckSound(button)
    PlaySound(button:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
end

local function HideTipIfOwned(owner)
    if GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
end

------------------------------------------------------------------ list rows

local function RowClick(row)
    local info = row.info
    if not info then return end
    if info.isHeader then
        PlaySound(ToggleHeader(info) and SOUNDKIT.IG_QUEST_LIST_CLOSE or SOUNDKIT.IG_QUEST_LIST_OPEN)
        UpdateAll()
        return
    end
    if IsModifiedClick("CHATLINK") and ChatFrameUtil and ChatFrameUtil.InsertLink then
        local link = GetQuestLink(info.questID)
        if link and ChatFrameUtil.InsertLink(link) then return end
    end
    if IsShiftKeyDown() then
        SetWatched(info.questID, not IsWatched(info.questID))
    end
    selectedID = info.questID
    C_QuestLog.SetSelectedQuest(info.questID)
    PlaySound(SOUNDKIT.IG_QUEST_LIST_SELECT)
    UpdateAll()
end

-- Refill first so party names are fresh; UpdateList re-runs this for the tooltip's row.
local function RowEnter(self)
    local info = self.info
    if not info then
        HideTipIfOwned(self)
        return
    end
    if not info.isHeader then FillRow(self, info) end
    self.text:SetTextColor(1, 1, 1)
    if info.isHeader then
        -- A header scrolled under the pointer drops the quest tooltip.
        HideTipIfOwned(self)
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(info.title, 1, 1, 1)
    if self.tagText then GameTooltip:AddLine(self.tagText, 0.8, 0.8, 0.8) end
    if self.party and #self.party > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(PARTY_QUEST_STATUS_ON or "Party members that are on this quest:", 1, 0.82, 0)
        for _, name in ipairs(self.party) do GameTooltip:AddLine(name, 1, 1, 1) end
    end
    GameTooltip:Show()
end

local function RowLeave(self)
    if self.info then self.text:SetTextColor(LevelColor(self.info)) end
    GameTooltip:Hide()
end

local function MakeRow(index)
    local row = CreateFrame("Button", nil, frame.listArea)
    row:SetSize(LIST_W, ROW_H)
    if index == 1 then
        row:SetPoint("TOPLEFT", frame.listArea, "TOPLEFT", 0, 0)
    else
        row:SetPoint("TOPLEFT", rows[index - 1], "BOTTOMLEFT", 0, -ROW_GAP)
    end
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", row, "LEFT", 3, 0)
    row.text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row.text:SetPoint("LEFT", row, "LEFT", 20, 0)
    row.tag = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.tag:SetJustifyH("RIGHT")
    row.tag:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.check = row:CreateTexture(nil, "OVERLAY")
    row.check:SetTexture(CHECK_MARK)
    row.check:SetSize(16, 16)
    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetBlendMode("ADD")
    row:SetScript("OnClick", RowClick)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    return row
end

-- Header: collapse icon and name. Quest: "[n]" party count, title, tag, check if tracked.
function FillRow(row, info)
    row.info = info
    if not info then
        row:Hide()
        return
    end
    row:Show()
    local r, g, b = LevelColor(info)
    row.text:SetTextColor(r, g, b)
    row.tag:SetTextColor(r, g, b)
    row.highlight:ClearAllPoints()
    if info.isHeader then
        row.icon:Show()
        ns.SetCollapseIcon(row.icon, info.isCollapsed)
        row.text:SetText(info.title or "")
        row.text:SetWidth(0)
        row.tag:SetText("")
        row.tagText = nil
        row.check:Hide()
        row.highlight:SetTexture(ART.PLUS_GLOW)
        row.highlight:SetSize(16, 16)
        row.highlight:SetPoint("LEFT", row, "LEFT", 3, 0)
        row:UnlockHighlight()
        return
    end
    row.icon:Hide()
    local party = PartyOnQuest(info.questID)
    row.party = party
    row.text:SetText("  " .. (#party > 0 and ("[" .. #party .. "] ") or "") .. (info.title or ""))
    local tag = TagFor(info)
    row.tagText = tag
    row.tag:SetText(tag and ("(" .. tag .. ")") or "")
    -- The title yields to the tag; the check follows the title.
    row.text:SetWidth(0)
    local natural = row.text:GetStringWidth()
    local room = TITLE_TAG_ROOM - (tag and (row.tag:GetStringWidth() + 15) or 0)
    local width = math.min(natural, room)
    row.text:SetWidth(width)
    ns.SetPointOnce(row.check, "LEFT", row, "LEFT", 20 + width + 4, 0)
    row.check:SetShown(IsWatched(info.questID))
    ns.SetTex(row.highlight, "questLogHighlight")
    row.highlight:SetAllPoints(row)
    if info.questID == selectedID then
        row.highlight:SetVertexColor(r, g, b)
        row.tag:SetTextColor(1, 1, 1)
        row:LockHighlight()
    else
        row.highlight:SetVertexColor(1, 1, 1)
        row:UnlockHighlight()
    end
end

-- fresh: entries UpdateAll just collected; other callers collect their own.
local function UpdateList(fresh)
    local entries = fresh or CollectEntries()
    local n = Rows()
    local offset = math.floor(frame.listBar:GetValue() + 0.5)
    frame.listBar:SetRange(#entries - n)
    offset = math.min(offset, math.max(0, #entries - n))
    for i = 1, MAX_ROWS do
        FillRow(rows[i], i <= n and entries[i + offset] or nil)
    end
    for i = 1, MAX_ROWS do
        if GameTooltip:IsOwned(rows[i]) then RowEnter(rows[i]) end
    end
    -- All tab: minus while any header is open, plus once every one is shut.
    local headers, closed = 0, 0
    for _, info in ipairs(entries) do
        if info.isHeader then
            headers = headers + 1
            if info.isCollapsed then closed = closed + 1 end
        end
    end
    frame.allCollapsed = headers > 0 and closed == headers
    ns.SetCollapseIcon(frame.allIcon, frame.allCollapsed)
    local _, numQuests = C_QuestLog.GetNumQuestLogEntries()
    local max = (C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept()) or MAX_QUESTS or 20
    frame.count:SetText(string.format("%s: %d/%d", QUESTS or "Quests", numQuests or 0, max))
    frame.countMiddle:SetWidth(math.max(20, frame.count:GetStringWidth()))
end

----------------------------------------------------------------- detail pane

-- Sole writer of hasTimer; the countdown runs only while it is set.
local function SetHasTimer(on)
    frame.hasTimer = on
    if countdown then
        if on then countdown:Wake() else countdown:Sleep() end
    end
end

-- The foot buttons follow the selection; QuestLogDetail.lua writes the page.
local function UpdateDetail()
    QL.ResetDetail()
    local child = frame.detailChild
    local info = selectedID and QuestInLog(selectedID)
    frame.abandon:SetEnabled(info ~= nil)
    -- Share enables only for a pushable quest while grouped, as in 1.x.
    local pushable = false
    if info and IsInGroup and IsInGroup() and C_QuestLog.IsPushableQuest then
        local ok, can = pcall(C_QuestLog.IsPushableQuest, info.questID)
        pushable = ok and can == true
    end
    frame.share:SetEnabled(pushable)
    frame.trackButton:SetEnabled(info ~= nil)
    frame.track:SetChecked(info ~= nil and IsWatched(selectedID))
    frame.track:SetEnabled(info ~= nil)
    if not info then
        SetHasTimer(false)
        child:SetHeight(1)
        frame.detailBar:SetRange(0)
        return
    end
    QL.FillDetail(frame, info, DetailHeight(), SetHasTimer)
end

-- Collects once and hands the entries to UpdateList.
function UpdateAll()
    if not frame or not frame:IsShown() then return end
    local entries = CollectEntries()
    local current = C_QuestLog.GetSelectedQuest()
    if selectedID and not QuestInLog(selectedID) then selectedID = nil end
    if not selectedID and current and current > 0 and QuestInLog(current) then selectedID = current end
    if not selectedID then selectedID = FirstQuest() end
    local empty = #entries == 0
    frame.empty:SetShown(empty)
    -- SetRange re-shows both bars (no hideWhenIdle), so an empty log still shows them; intended.
    frame.detail:SetShown(not empty)
    frame.detailBar:SetShown(not empty)
    frame.listBar:SetShown(not empty)
    frame.allTab:SetShown(not empty and not frame.dual)
    UpdateList(entries)
    UpdateDetail()
end

------------------------------------------------------------------- controls

local function CountBox(parent)
    local pieces = ns.DressPieces(parent, COUNT_BOX, nil, true)
    local right, middle = pieces[1], pieces[2]
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetTextColor(ns.QuestYellow())
    text:SetPoint("RIGHT", right, "RIGHT", -6, 0)
    return text, middle, right
end

-- Fallback when the secure pad can't act (combat, or no client map button).
local function ShowMapClick()
    if InCombatLockdown() then
        ns.SayNotInCombat()
        return
    end
    ns.HideQuestLog()
    if ToggleWorldMap then ToggleWorldMap() elseif WorldMapFrame then ShowUIPanel(WorldMapFrame) end
end

-- 3.x Show Map button: map icon, label to its left.
local function ShowMapButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(110, 24)
    local icon = button:CreateTexture(nil, "ARTWORK")
    ns.SetTex(icon, "questMapButton")
    icon:SetTexCoord(0.125, 0.875, 0, 0.5)
    icon:SetSize(36, 24)
    icon:SetPoint("RIGHT", button, "RIGHT", 0, 0)
    local label = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("RIGHT", icon, "LEFT", -2, 0)
    label:SetText(SHOW_MAP or "Show Map")
    label:SetTextColor(ns.QuestYellow())
    local glow = button:CreateTexture(nil, "HIGHLIGHT")
    glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    glow:SetBlendMode("ADD")
    glow:SetAllPoints(icon)
    button:SetScript("OnClick", ShowMapClick)
    -- A secure pad clicks the client's map button: opening it ourselves taints its pins
    -- and breaks the map key in combat. DIALOG to sit over the HIGH log.
    ns.MapPad(button, "DIALOG", CloseLog)
    return button
end

local function AllClick()
    if frame.allCollapsed then
        SetAllCollapsed(false)
        PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN)
    else
        SetAllCollapsed(true)
        PlaySound(SOUNDKIT.IG_QUEST_LIST_CLOSE)
    end
    UpdateAll()
end

local function AllTab(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(54, 32)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", 70, -48)
    local button = CreateFrame("Button", nil, holder)
    button:SetSize(40, 22)
    button:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -2)
    ns.DressPieces(button, ALL_TAB)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", button, "LEFT", 3, 0)
    icon:SetTexture(ART.MINUS)
    local glow = button:CreateTexture(nil, "HIGHLIGHT")
    glow:SetTexture(ART.PLUS_GLOW)
    glow:SetBlendMode("ADD")
    glow:SetAllPoints(icon)
    local text = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("LEFT", button, "LEFT", 20, 0)
    text:SetText(ALL or "All")
    text:SetTextColor(ns.QuestYellow())
    button:SetScript("OnClick", AllClick)
    holder.icon = icon
    return holder
end

-- Radio-style check beside the All tab (Track Quest, double pane switch).
local function RadioCheck(parent, anchor, y, text)
    local button = CreateFrame("CheckButton", nil, parent)
    button:SetSize(20, 20)
    button:SetPoint("LEFT", anchor, "RIGHT", 5, y)
    button:SetNormalTexture(RADIO)
    button:GetNormalTexture():SetTexCoord(0, 0.25, 0, 1)
    button:SetHighlightTexture(RADIO)
    button:GetHighlightTexture():SetTexCoord(0.5, 0.75, 0, 1)
    button:GetHighlightTexture():SetBlendMode("ADD")
    button:SetCheckedTexture(RADIO)
    button:GetCheckedTexture():SetTexCoord(0.25, 0.5, 0, 1)
    local label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("LEFT", button, "RIGHT", 0, 0)
    label:SetText(text)
    return button
end

local function TrackClick(self)
    if not selectedID then self:SetChecked(false) return end
    SetWatched(selectedID, self:GetChecked())
    CheckSound(self)
    UpdateAll()
end

-- Same setting as the options' Double pane toggle.
local function DualClick(self)
    CheckSound(self)
    ns.db.questLogDual = self:GetChecked() and true or false
    ns.ApplyAll()
    if ns.RefreshOptionsWindow then ns.RefreshOptionsWindow() end
end

local function EmptyPane(parent)
    local empty = CreateFrame("Frame", nil, parent)
    empty:SetSize(WIDTH, HEIGHT)
    empty:SetPoint("TOPLEFT", parent, "TOPLEFT", LIST_X, -73)
    empty.pieces = ns.DressPieces(empty, EMPTY_ART, nil, true)
    local text = empty:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetWidth(200)
    text:SetPoint("TOP", parent, "TOP", -20, -105)
    empty.text = text
    text:SetText(QUESTLOG_NO_QUESTS_TEXT or "You have no quests. Look for exclamation marks over the heads of characters to find quests.")
    empty:Hide()
    return empty
end

local function AbandonClick()
    if not selectedID then return end
    C_QuestLog.SetSelectedQuest(selectedID)
    C_QuestLog.SetAbandonQuest()
    local name = C_QuestLog.GetAbandonQuestName and C_QuestLog.GetAbandonQuestName() or QuestInLog(selectedID) and QuestInLog(selectedID).title or ""
    local items = C_QuestLog.GetAbandonQuestItems and C_QuestLog.GetAbandonQuestItems() or {}
    if #items > 0 then
        local names = {}
        for _, item in ipairs(items) do
            local itemName = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(item)
            names[#names + 1] = itemName or tostring(item)
        end
        StaticPopup_Hide("ABANDON_QUEST")
        StaticPopup_Show("ABANDON_QUEST_WITH_ITEMS", name, table.concat(names, ", "))
    else
        StaticPopup_Hide("ABANDON_QUEST_WITH_ITEMS")
        StaticPopup_Show("ABANDON_QUEST", name)
    end
    PlaySound(SOUNDKIT.IG_QUEST_LOG_ABANDON_QUEST)
end

local function TrackButtonClick()
    if not selectedID then return end
    SetWatched(selectedID, not IsWatched(selectedID))
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    UpdateAll()
end

local function ShareClick()
    local info = selectedID and QuestInLog(selectedID)
    if not info or not QuestLogPushQuest then return end
    if not IsInGroup() then
        UIErrorsFrame:AddMessage("You are not in a party.", 1, 0.1, 0.1)
        return
    end
    if C_QuestLog.IsPushableQuest(info.questID) then QuestLogPushQuest(info.questLogIndex) end
end

-------------------------------------------------------------------- layout

-- Single pane (list over detail) or double (side by side); rows, bars and detail pool are shared.
function Layout()
    local dual = frame.dual
    for _, tex in ipairs(frame.singleArt) do tex:SetShown(not dual) end
    for _, tex in ipairs(frame.dualArt) do tex:SetShown(dual) end
    frame:SetSize(dual and DUAL.WIDTH or WIDTH, dual and DUAL.HEIGHT or HEIGHT)
    local listW = dual and DUAL.LIST_W or LIST_W
    frame.listArea:ClearAllPoints()
    if dual then
        frame.listArea:SetPoint("TOPLEFT", frame, "TOPLEFT", DUAL.LIST_X, DUAL.LIST_Y)
        frame.listArea:SetSize(DUAL.LIST_W, DUAL.LIST_H)
    else
        frame.listArea:SetPoint("TOPLEFT", frame, "TOPLEFT", LIST_X, LIST_Y)
        frame.listArea:SetSize(LIST_W, LIST_H)
    end
    for i = 1, MAX_ROWS do rows[i]:SetWidth(listW) end
    frame.detail:ClearAllPoints()
    if dual then
        frame.detail:SetPoint("TOPLEFT", frame, "TOPLEFT", DUAL.DETAIL_X, DUAL.DETAIL_Y)
        frame.detail:SetSize(DUAL.DETAIL_W, DUAL.DETAIL_H)
        frame.detailChild:SetWidth(DUAL.DETAIL_W)
    else
        frame.detail:SetPoint("TOPLEFT", frame.listArea, "BOTTOMLEFT", 0, -DETAIL_GAP)
        frame.detail:SetSize(LIST_W, DETAIL_H)
        frame.detailChild:SetWidth(LIST_W)
    end
    -- Bars sit on the tracks drawn in the art.
    frame.detailBar:ClearAllPoints()
    frame.listBar:ClearAllPoints()
    if dual then
        frame.detailBar:SetPoint("TOPLEFT", frame.detail, "TOPRIGHT", 12, -10)
        frame.detailBar:SetPoint("BOTTOMLEFT", frame.detail, "BOTTOMRIGHT", 12, 14)
        frame.listBar:SetPoint("TOPLEFT", frame.listArea, "TOPRIGHT", 10, -14)
        frame.listBar:SetPoint("BOTTOMLEFT", frame.listArea, "BOTTOMRIGHT", 10, 14)
    else
        frame.detailBar:SetPoint("TOPLEFT", frame.detail, "TOPRIGHT", 7, -16)
        frame.detailBar:SetPoint("BOTTOMLEFT", frame.detail, "BOTTOMRIGHT", 7, 16)
        frame.listBar:SetPoint("TOPLEFT", frame.listArea, "TOPRIGHT", 7, -16)
        frame.listBar:SetPoint("BOTTOMLEFT", frame.listArea, "BOTTOMRIGHT", 7, 16)
    end
    ns.SetPointOnce(frame.book, "TOPLEFT", frame, "TOPLEFT", dual and 6 or 4, dual and -6 or -4)
    ns.SetPointOnce(frame.title, "TOP", frame, "TOP", 0, dual and -19 or -17)
    frame.close:ClearAllPoints()
    if dual then
        frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 3, -8)
    else
        frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -8)
    end
    frame.countRight:ClearAllPoints()
    if dual then
        frame.countRight:SetPoint("TOPLEFT", frame, "TOPLEFT", 190, -40)
    else
        frame.countRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -47, -41)
    end
    frame.allTab:SetShown(not dual)
    frame.track:SetShown(not dual)
    -- Switch under Track Quest in the single pane, beside the count in the double.
    frame.dualToggle:SetChecked(dual)
    frame.dualToggle:ClearAllPoints()
    if dual then
        frame.dualToggle:SetPoint("LEFT", frame.countRight, "RIGHT", 8, 0)
    else
        frame.dualToggle:SetPoint("LEFT", frame.allTab, "RIGHT", 5, 0)
    end
    frame.showMap:SetShown(dual)
    frame.trackButton:SetShown(dual)
    frame.abandon:ClearAllPoints()
    frame.exit:ClearAllPoints()
    frame.share:ClearAllPoints()
    if dual then
        -- Three equal buttons across the foot's left box, 4px apart.
        local bw = 104
        frame.abandon:SetWidth(bw)
        frame.abandon:SetText(ABANDON_QUEST_ABBREV or "Abandon")
        frame.abandon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 8)
        frame.share:SetWidth(bw)
        frame.share:SetText(SHARE_QUEST_ABBREV or "Share")
        frame.share:SetPoint("LEFT", frame.abandon, "RIGHT", -4, 0)
        frame.trackButton:SetWidth(bw)
        ns.SetPointOnce(frame.trackButton, "LEFT", frame.share, "RIGHT", 2, 0)
        frame.exit:SetWidth(80)
        frame.exit:SetText(CLOSE or "Close")
        frame.exit:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    else
        frame.abandon:SetWidth(125)
        frame.abandon:SetText(ABANDON_QUEST or "Abandon Quest")
        frame.abandon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 17, 54)
        frame.exit:SetWidth(77)
        frame.exit:SetText(EXIT or "Exit")
        frame.exit:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -43, 54)
        frame.share:SetWidth(123)
        frame.share:SetText(SHARE_QUEST or "Share Quest")
        frame.share:SetPoint("RIGHT", frame.exit, "LEFT", 0, 0)
    end
    -- Empty log: 1.x empty parchment in single; just the text in the double pane's well.
    for _, tex in ipairs(frame.empty.pieces) do tex:SetShown(not dual) end
    frame.empty.text:ClearAllPoints()
    if dual then
        frame.empty.text:SetPoint("TOP", frame.listArea, "TOP", 0, -30)
    else
        frame.empty.text:SetPoint("TOP", frame, "TOP", -20, -105)
    end
end

-- Runs on every ApplyAll: Layout only on a shape change, but always refill (ApplyAll can swap row art).
function ns.QuestLogSetDual(on)
    if not frame then return end
    on = on and true or false
    if frame.dual ~= on then
        frame.dual = on
        Layout()
    end
    if frame:IsShown() then UpdateAll() end
end

--------------------------------------------------------------------- build

local function SavePos(self)
    local point, _, relPoint, x, y = self:GetPoint(1)
    ns.db.questLogPos = { point, relPoint, x, y }
end

-- Coalesces a burst of party log changes into one refill next frame.
local function FlushParty()
    if not frame.partyDirty then return end
    frame.partyDirty = nil
    if frame:IsShown() then UpdateList() end
end

local function OnLogEvent(self, event, unit)
    if GIVER[event] then
        if self:IsShown() then self:Hide() end
        return
    end
    -- Party logs affect only the rows' party counts and names.
    if (event == "UNIT_QUEST_LOG_CHANGED" and unit ~= "player") or PARTY[event] then
        if self:IsShown() then
            self.partyDirty = true
            ns.Sched.NextFrame("questlog.party", FlushParty)
        end
        return
    end
    -- One rebuild per frame, however many events arrive.
    if self:IsShown() then ns.Sched.Soon("questlog.update", UpdateAll) end
end

local function LogShown()
    PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN)
    UpdateAll()
    ns.RefreshMicroButtons()
end

local function LogHidden()
    PlaySound(SOUNDKIT.IG_QUEST_LOG_CLOSE)
    GameTooltip:Hide()
    ns.RefreshMicroButtons()
end

local function Build()
    frame = CreateFrame("Frame", FRAME_NAME, UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
    frame:SetToplevel(true)
    frame:SetFrameStrata("HIGH")
    ns.MakeDraggable(frame, SavePos)
    -- OnShow order matters: RegisterClassicWindow, CloseOnEscape, then ours.
    ns.RegisterClassicWindow(frame)
    -- Escape closes the log before clearing the target.
    ns.CloseOnEscape(frame, CloseLog)
    frame:Hide()
    local pos = ns.db.questLogPos
    if pos then ns.SetPointOnce(frame, pos[1], UIParent, pos[2], pos[3], pos[4]) end

    frame.singleArt = ns.DressPieces(frame, SINGLE_ART, nil, true)
    frame.dualArt = ns.DressPieces(frame, DUAL_ART, nil, true)
    frame.book = ns.DressNew(frame, "questLogBook", BOOK)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", frame, "TOP", 0, -17)
    title:SetText(QUEST_LOG or "Quest Log")
    frame.title = title

    frame.close = ns.DialogClose(frame, CloseLog, -30, -8)

    frame.count, frame.countMiddle, frame.countRight = CountBox(frame)
    frame.allTab = AllTab(frame)
    frame.allIcon = frame.allTab.icon
    frame.track = RadioCheck(frame, frame.allTab, 17, TRACK_QUEST or "Track Quest")
    frame.track:SetScript("OnClick", TrackClick)
    frame.dualToggle = RadioCheck(frame, frame.allTab, 0, "Double pane")
    frame.dualToggle:SetScript("OnClick", DualClick)
    frame.showMap = ShowMapButton(frame)
    frame.showMap:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -36, -40)

    local listArea = CreateFrame("Frame", nil, frame)
    listArea:SetPoint("TOPLEFT", frame, "TOPLEFT", LIST_X, LIST_Y)
    listArea:SetSize(LIST_W, LIST_H)
    listArea:SetClipsChildren(true)
    frame.listArea = listArea
    for i = 1, MAX_ROWS do rows[i] = MakeRow(i) end
    listArea:EnableMouseWheel(true)
    listArea:SetScript("OnMouseWheel", function(_, delta) frame.listBar:SetValue(frame.listBar:GetValue() - delta) end)
    frame.listBar = ns.ClassicScrollBar(frame, listArea, function() UpdateList() end)

    local detail = CreateFrame("ScrollFrame", nil, frame)
    detail:SetPoint("TOPLEFT", listArea, "BOTTOMLEFT", 0, -DETAIL_GAP)
    detail:SetSize(LIST_W, DETAIL_H)
    detail:SetClipsChildren(true)
    local child = CreateFrame("Frame", nil, detail)
    child:SetSize(LIST_W, DETAIL_H)
    detail:SetScrollChild(child)
    detail:EnableMouseWheel(true)
    detail:SetScript("OnMouseWheel", function(_, delta) frame.detailBar:SetValue(frame.detailBar:GetValue() - delta * 20) end)
    frame.detail, frame.detailChild = detail, child
    frame.detailBar = ns.ClassicScrollBar(frame, detail, function(value) detail:SetVerticalScroll(value) end)

    frame.empty = EmptyPane(frame)

    frame.abandon = ns.PanelButton(frame, ABANDON_QUEST or "Abandon Quest", 125)
    frame.abandon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 17, 54)
    frame.abandon:SetScript("OnClick", AbandonClick)
    frame.exit = ns.PanelButton(frame, EXIT or "Exit", 77)
    frame.exit:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -43, 54)
    frame.exit:SetScript("OnClick", CloseLog)
    frame.share = ns.PanelButton(frame, SHARE_QUEST or "Share Quest", 123)
    frame.share:SetPoint("RIGHT", frame.exit, "LEFT", 0, 0)
    -- The double pane's Track foot button, as in 3.x.
    frame.trackButton = ns.PanelButton(frame, TRACK_QUEST_ABBREV or "Track", 76)
    frame.trackButton:SetScript("OnClick", TrackButtonClick)
    frame.share:SetScript("OnClick", ShareClick)

    ns.RegisterEvents(frame, LOG_EVENTS)
    -- Party members going on or offline change who counts as on a quest.
    ns.RegisterEvents(frame, PARTY_EVENTS)
    -- A quest giver's window closes the log, as in 1.x.
    ns.RegisterEvents(frame, GIVER_EVENTS)
    frame:SetScript("OnEvent", OnLogEvent)
    -- Runs only while hasTimer is set and the log is shown.
    countdown = ns.Sched.OnFrame(CreateFrame("Frame", nil, frame), {
        name = "questlog.countdown", every = 1, awake = frame.hasTimer == true, fn = UpdateDetail,
    })
    frame:HookScript("OnShow", LogShown)
    frame:HookScript("OnHide", LogHidden)
    ns.MicroButtonFollows(QuestLogMicroButton, function() return QL.active and frame:IsShown() end)
    frame.dual = ns.db.questLogDual == true
    Layout()
end

function ns.ShowQuestLog(questID)
    if not QL.active then return end
    if not frame then Build() end
    if questID then
        selectedID = questID
        C_QuestLog.SetSelectedQuest(questID)
    end
    if frame:IsShown() then UpdateAll() else frame:Show() end
end

function ns.HideQuestLog()
    if frame then frame:Hide() end
end

function ns.ToggleQuestLog()
    if frame and frame:IsShown() then ns.HideQuestLog() else ns.ShowQuestLog() end
end

-- nil until the first show builds it.
function QL.Frame() return frame end
-- The quest the detail pane shows; its reward buttons read it live.
function QL.SelectedID() return selectedID end
