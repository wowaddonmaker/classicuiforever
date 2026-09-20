local _, ns = ...

-- The 1.x quest log: its own window, nothing to do with the map. The old
-- four-piece art with the book in the portrait ring, the quest count box,
-- the All tab, Track Quest, six list rows over a parchment detail pane,
-- and Abandon, Share and Exit along the bottom. The quest micro button,
-- the quest log key and quest clicks in the tracker open it in place of
-- the map's quest panel. Built on the modern quest API, so it works on
-- both the Forever client and retail.

local WIDTH, HEIGHT = 384, 512
local ROWS, ROW_H, ROW_GAP = 6, 15, 0.6   -- six rows fill the 93px track exactly
local LIST_X, LIST_Y, LIST_W = 19, -75, 300
local LIST_H = 93   -- the art's list track; the rows live in a clipped area of this size
local DETAIL_GAP, DETAIL_H = 7, 260
local TEXT_W = 285
local TITLE_TAG_ROOM = 275
-- The double pane of the 3.x log, measured from its two sheets: the list
-- well on the left, the parchment on the right, the buttons along the
-- foot. The frame is the sheets' opaque extent.
local DUAL = { WIDTH = 680, HEIGHT = 440, LIST_X = 20, LIST_Y = -76, LIST_W = 296, LIST_H = 332, ROWS = 21,
    DETAIL_X = 352, DETAIL_Y = -80, DETAIL_W = 292, DETAIL_H = 328 }
local MAX_ROWS = DUAL.ROWS

local FRAME_NAME = "ForeverClassicUIQuestLog"
local BIND_NAME = "ForeverClassicUIQuestLogBind"

local active = false
local frame, bindButton
local function Rows() return (frame and frame.dual) and DUAL.ROWS or ROWS end
local function DetailHeight() return (frame and frame.dual) and DUAL.DETAIL_H or DETAIL_H end
local rows = {}
local entries = {}
local selectedID
local originalMicroClick

local function FirstFont(...)
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        if _G[name] then return name end
    end
    return "GameFontNormal"
end

local FONT_TITLE = FirstFont("QuestTitleFont", "QuestFont_Large", "GameFontNormalLarge")
local FONT_BODY = FirstFont("QuestFont", "QuestFontNormalSmall", "GameFontNormal")
local FONT_SMALL = FirstFont("QuestFontNormalSmall", "GameFontNormalSmall")
local PARCHMENT = { 0.18, 0.12, 0.06 }
local DONE = { 0.2, 0.2, 0.2 }

local ScrollBar = function(parent, anchorTo, onValue) return ns.ClassicScrollBar(parent, anchorTo, onValue) end

-- Visible log entries: headers and real quests, in log order.
local collapsed = {}   -- header key -> true while our list keeps it shut
local function HeaderKey(info)
    return info.headerSortKey or info.title or info.questLogIndex
end

local function CollectEntries()
    wipe(entries)
    local skipping = false
    local i = 1
    while i <= (C_QuestLog.GetNumQuestLogEntries() or 0) do
        local info = C_QuestLog.GetInfo(i)
        if info and info.isHeader then
            -- The game's own collapsed headers hide their quests from
            -- the enumeration; open them so every quest is listed, and
            -- keep the collapsing in our own hands.
            if info.isCollapsed and ExpandQuestHeader then ExpandQuestHeader(info.questLogIndex) end
            skipping = collapsed[HeaderKey(info)] == true
            info.isCollapsed = skipping
            entries[#entries + 1] = info
        elseif info and not skipping and not info.isHidden and not info.isTask and not info.isBounty then
            entries[#entries + 1] = info
        end
        i = i + 1
    end
    return entries
end

function ns.QuestLogSetAllCollapsed(shut)
    wipe(collapsed)
    if shut then
        for _, info in ipairs(entries) do
            if info.isHeader then collapsed[HeaderKey(info)] = true end
        end
    end
end

local function QuestInLog(questID)
    for _, info in ipairs(entries) do
        if not info.isHeader and info.questID == questID then return info end
    end
end

local function FirstQuest()
    for _, info in ipairs(entries) do
        if not info.isHeader then return info.questID end
    end
end

local function TagFor(info)
    if C_QuestLog.IsFailed and C_QuestLog.IsFailed(info.questID) then return FAILED or "Failed" end
    if C_QuestLog.IsComplete(info.questID) then return COMPLETE or "Complete" end
    if info.frequency == Enum.QuestFrequency.Daily then return DAILY or "Daily" end
    if info.frequency == Enum.QuestFrequency.Weekly then return WEEKLY or "Weekly" end
    local tag = C_QuestLog.GetQuestTagInfo and C_QuestLog.GetQuestTagInfo(info.questID)
    if tag and tag.tagName and tag.tagName ~= "" then return tag.tagName end
    if info.suggestedGroup and info.suggestedGroup > 0 then return (GROUP or "Group") end
    return nil
end

local function LevelColor(info)
    if info.isHeader then
        local header = QuestDifficultyColors and QuestDifficultyColors["header"]
        if header then return header.r, header.g, header.b end
        return 0.7, 0.7, 0.7
    end
    local level = info.difficultyLevel or info.level or 0
    return ns.QuestLevelColor(level)
end

local function IsWatched(questID)
    return C_QuestLog.GetQuestWatchType(questID) ~= nil
end

local function SetWatched(questID, watched)
    if watched then
        C_QuestLog.AddQuestWatch(questID, Enum.QuestWatchType and Enum.QuestWatchType.Manual)
    elseif not QuestUtil or not QuestUtil.CanRemoveQuestWatch or QuestUtil.CanRemoveQuestWatch() then
        C_QuestLog.RemoveQuestWatch(questID)
    end
end

local UpdateAll, Layout

-- One list row: the plus or minus for headers, the title, the tag on the
-- right, the check when the quest is tracked.
local function RowClick(row)
    local info = row.info
    if not info then return end
    if info.isHeader then
        local key = HeaderKey(info)
        if collapsed[key] then
            collapsed[key] = nil
            PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN)
        else
            collapsed[key] = true
            PlaySound(SOUNDKIT.IG_QUEST_LIST_CLOSE)
        end
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
    row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    row.check:SetSize(16, 16)
    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetBlendMode("ADD")
    row:SetScript("OnClick", RowClick)
    row:SetScript("OnEnter", function(self)
        self.text:SetTextColor(1, 1, 1)
        if self.info and not self.info.isHeader then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.info.title, 1, 1, 1)
            if self.tagText then GameTooltip:AddLine(self.tagText, 0.8, 0.8, 0.8) end
            if self.party and #self.party > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(PARTY_QUEST_STATUS_ON or "Party members that are on this quest:", 1, 0.82, 0)
                for _, name in ipairs(self.party) do GameTooltip:AddLine(name, 1, 1, 1) end
            end
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        if self.info then self.text:SetTextColor(LevelColor(self.info)) end
        GameTooltip:Hide()
    end)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    return row
end

-- Who else in the party has this quest: the old log put their number in
-- front of the title, "[2]", and named them when the row was pointed at.
local function PartyOnQuest(questID)
    local names = {}
    if not questID or not IsInGroup or not IsInGroup() then return names end
    if not (C_QuestLog and C_QuestLog.IsUnitOnQuest) then return names end
    for i = 1, (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0) do
        local unit = "party" .. i
        local ok, on = pcall(C_QuestLog.IsUnitOnQuest, unit, questID)
        if ok and on == true then names[#names + 1] = UnitName(unit) or unit end
    end
    return names
end

local function FillRow(row, info)
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
        row.icon:SetTexture(info.isCollapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
        row.text:SetText(info.title or "")
        row.text:SetWidth(0)
        row.tag:SetText("")
        row.tagText = nil
        row.check:Hide()
        row.highlight:SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
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
    -- The title yields to the tag, then the check follows the title.
    row.text:SetWidth(0)
    local natural = row.text:GetStringWidth()
    local room = TITLE_TAG_ROOM - (tag and (row.tag:GetStringWidth() + 15) or 0)
    local width = math.min(natural, room)
    row.text:SetWidth(width)
    row.check:ClearAllPoints()
    row.check:SetPoint("LEFT", row, "LEFT", 20 + width + 4, 0)
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

local function UpdateList()
    CollectEntries()
    local n = Rows()
    local offset = math.floor(frame.listBar:GetValue() + 0.5)
    frame.listBar:SetRange(#entries - n)
    offset = math.min(offset, math.max(0, #entries - n))
    for i = 1, MAX_ROWS do
        FillRow(rows[i], i <= n and entries[i + offset] or nil)
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
    frame.allIcon:SetTexture(frame.allCollapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
    local _, numQuests = C_QuestLog.GetNumQuestLogEntries()
    local max = (C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept()) or MAX_QUESTS or 20
    frame.count:SetText(string.format("%s: %d/%d", QUESTS or "Quests", numQuests or 0, max))
    frame.countMiddle:SetWidth(math.max(20, frame.count:GetStringWidth()))
end

-- Detail pane: a pool of font strings stacked down the parchment.
local detailStrings, detailUsed = {}, 0
local rewardButtons, rewardsUsed = {}, 0

local function DetailString(font, width, x, y, anchor, relPoint)
    detailUsed = detailUsed + 1
    local fs = detailStrings[detailUsed]
    if not fs then
        fs = frame.detailChild:CreateFontString(nil, "ARTWORK")
        detailStrings[detailUsed] = fs
    end
    fs:SetFontObject(font)
    fs:SetJustifyH("LEFT")
    fs:SetWidth(width)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", anchor or frame.detailChild, relPoint or "TOPLEFT", x or 0, y or 0)
    fs:SetTextColor(unpack(PARCHMENT))
    fs:Show()
    return fs
end

local function RewardButton()
    rewardsUsed = rewardsUsed + 1
    local button = rewardButtons[rewardsUsed]
    if not button then
        button = CreateFrame("Button", nil, frame.detailChild)
        button:SetSize(140, 36)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(34, 34)
        button.icon:SetPoint("LEFT", button, "LEFT", 1, 0)
        button.border = button:CreateTexture(nil, "OVERLAY")
        ns.SetTex(button.border, "slotNormal")
        button.border:SetSize(56, 56)
        button.border:SetPoint("CENTER", button.icon, "CENTER", 0, -1)
        -- The old name box behind the reward's words.
        button.nameBox = button:CreateTexture(nil, "BACKGROUND", nil, 1)
        ns.SetTex(button.nameBox, "lootNameFrame")
        button.nameBox:SetTexCoord(0, 1, 0, 1)
        ns.FitNamePlate(button.nameBox, button, 40, 98, 34)
        button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        button.count:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", -2, 2)
        button.name = button:CreateFontString(nil, "ARTWORK", FONT_SMALL)
        button.name:SetPoint("LEFT", button.icon, "RIGHT", 6, 0)
        button.name:SetPoint("RIGHT", button, "RIGHT", -2, 0)
        button.name:SetJustifyH("LEFT")
        button.name:SetWordWrap(true)
        button.name:SetMaxLines(2)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetQuestLogItem, GameTooltip, self.rewardType, self.index, selectedID)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button:SetScript("OnClick", function(self)
            if IsModifiedClick("CHATLINK") and ChatFrameUtil and ChatFrameUtil.InsertLink then
                local ok, link = pcall(GetQuestLogItemLink, self.rewardType, self.index, selectedID)
                if ok and link then ChatFrameUtil.InsertLink(link) end
            end
        end)
        rewardButtons[rewardsUsed] = button
    end
    button:Show()
    return button
end

local function ResetDetail()
    for i = 1, detailUsed do detailStrings[i]:Hide() end
    for i = 1, rewardsUsed do rewardButtons[i]:Hide() end
    detailUsed, rewardsUsed = 0, 0
end

local function Coins(copper)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then return C_CurrencyInfo.GetCoinTextureString(copper) end
    return GetCoinTextureString and GetCoinTextureString(copper) or tostring(copper)
end

-- Lays the rewards after `last`: choices first, then the fixed items,
-- money and experience. Returns the new last region.
local function LayoutRewards(last)
    local questID = selectedID
    local numChoices = GetNumQuestLogChoices(questID, true) or 0
    local numRewards = GetNumQuestLogRewards(questID) or 0
    local money = GetQuestLogRewardMoney(questID) or 0
    local xp = GetQuestLogRewardXP and GetQuestLogRewardXP(questID) or 0
    if numChoices + numRewards + money + xp <= 0 then return last end

    local title = DetailString(FONT_TITLE, TEXT_W, 0, -10, last, "BOTTOMLEFT")
    title:SetText(QUEST_REWARDS or "Rewards")
    last = title

    local function Grid(kind, count, header)
        if count <= 0 then return end
        local label = DetailString(FONT_SMALL, TEXT_W, 0, -5, last, "BOTTOMLEFT")
        label:SetText(header)
        last = label
        local rowAnchor = last
        for i = 1, count do
            local button = RewardButton()
            button.rewardType, button.index = kind, i
            local name, texture, count2, quality, _, itemID
            if kind == "choice" then
                name, texture, count2, quality, _, itemID = GetQuestLogChoiceInfo(i, questID)
            else
                name, texture, count2, quality, _, itemID = GetQuestLogRewardInfo(i, questID)
            end
            button.icon:SetTexture(texture)
            button.count:SetText((count2 or 0) > 1 and count2 or "")
            local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
            button.name:SetText(name or (itemID and ("item " .. itemID)) or "")
            if color then button.name:SetTextColor(color.r, color.g, color.b) else button.name:SetTextColor(unpack(PARCHMENT)) end
            button:ClearAllPoints()
            if i % 2 == 1 then
                button:SetPoint("TOPLEFT", rowAnchor, "BOTTOMLEFT", i == 1 and 0 or 0, -4)
                rowAnchor = button
                last = button
            else
                button:SetPoint("TOPLEFT", rowAnchor, "TOPRIGHT", 5, 0)
            end
        end
    end
    Grid("choice", numChoices, REWARD_CHOICES or "Choose one of the following rewards:")
    Grid("reward", numRewards, numChoices > 0 and (REWARD_ITEMS or "You will also receive:") or (REWARD_ITEMS_ONLY or "You will receive:"))
    if money > 0 then
        local line = DetailString(FONT_SMALL, TEXT_W, 0, -6, last, "BOTTOMLEFT")
        line:SetText(Coins(money))
        last = line
    end
    if xp > 0 then
        local line = DetailString(FONT_SMALL, TEXT_W, 0, -4, last, "BOTTOMLEFT")
        line:SetText(string.format("%s: %s", REWARD_XP or "Experience", BreakUpLargeNumbers and BreakUpLargeNumbers(xp) or xp))
        last = line
    end
    return last
end

local function UpdateDetail()
    ResetDetail()
    local child = frame.detailChild
    local info = selectedID and QuestInLog(selectedID)
    -- Nothing to abandon, share or track without a quest under the cursor.
    frame.abandon:SetEnabled(info ~= nil)
    -- Share is lit only for a quest that can be shared, with a party to
    -- share it with, as the old button was.
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
        child:SetHeight(1)
        frame.detailBar:SetRange(0)
        return
    end
    local detailH = DetailHeight()
    C_QuestLog.SetSelectedQuest(selectedID)
    local questIndex = info.questLogIndex

    local titleText = info.title or ""
    if C_QuestLog.IsFailed and C_QuestLog.IsFailed(selectedID) then
        titleText = titleText .. " - (" .. (FAILED or "Failed") .. ")"
    end
    local title = DetailString(FONT_TITLE, TEXT_W, 5, -5)
    title:SetText(titleText)
    local last = title

    local description, objectivesText = GetQuestLogQuestText(questIndex)
    if objectivesText and objectivesText ~= "" then
        local objectives = DetailString(FONT_BODY, TEXT_W - 10, 0, -5, last, "BOTTOMLEFT")
        objectives:SetText(objectivesText)
        last = objectives
    end

    local timeLeft = GetQuestLogTimeLeft and GetQuestLogTimeLeft()
    frame.hasTimer = timeLeft ~= nil
    if timeLeft then
        local timer = DetailString(FONT_SMALL, TEXT_W, 0, -10, last, "BOTTOMLEFT")
        timer:SetText((TIME_REMAINING or "Time Remaining:") .. " " .. SecondsToTime(timeLeft))
        last = timer
    end

    local numObjectives = GetNumQuestLeaderBoards(questIndex) or 0
    for i = 1, numObjectives do
        local text, kind, finished = GetQuestLogLeaderBoard(i, questIndex)
        if not text or text == "" then text = kind end
        local line = DetailString(FONT_SMALL, TEXT_W, 0, i == 1 and -10 or -2, last, "BOTTOMLEFT")
        if finished then
            line:SetTextColor(unpack(DONE))
            text = text .. " (" .. (COMPLETE or "Complete") .. ")"
        end
        line:SetText(text)
        last = line
    end

    local required = C_QuestLog.GetRequiredMoney and C_QuestLog.GetRequiredMoney(selectedID) or 0
    if required > 0 then
        local line = DetailString(FONT_SMALL, TEXT_W, 0, numObjectives > 0 and -4 or -10, last, "BOTTOMLEFT")
        line:SetText((REQUIRED_MONEY or "Required Money:") .. " " .. Coins(required))
        if required > GetMoney() then line:SetTextColor(1, 0.1, 0.1) else line:SetTextColor(unpack(DONE)) end
        last = line
    end

    if description and description ~= "" then
        local header = DetailString(FONT_TITLE, TEXT_W, 0, -10, last, "BOTTOMLEFT")
        header:SetText(QUEST_DESCRIPTION or "Description")
        local body = DetailString(FONT_BODY, TEXT_W - 10, 0, -5, header, "BOTTOMLEFT")
        body:SetText(description)
        last = body
    end

    last = LayoutRewards(last)

    -- Child height from the top of the pane to the last piece.
    local top, bottom = child:GetTop(), last:GetBottom()
    local height = (top and bottom) and (top - bottom + 12) or detailH
    child:SetHeight(math.max(height, detailH))
    frame.detailBar:SetRange(math.max(0, height - detailH), 20)
end

function UpdateAll()
    if not frame or not frame:IsShown() then return end
    CollectEntries()
    local current = C_QuestLog.GetSelectedQuest()
    if selectedID and not QuestInLog(selectedID) then selectedID = nil end
    if not selectedID and current and current > 0 and QuestInLog(current) then selectedID = current end
    if not selectedID then selectedID = FirstQuest() end
    local empty = #entries == 0
    frame.empty:SetShown(empty)
    frame.detail:SetShown(not empty)
    frame.detailBar:SetShown(not empty)
    frame.listBar:SetShown(not empty)
    frame.allTab:SetShown(not empty and not frame.dual)
    UpdateList()
    UpdateDetail()
end

local function Piece(parent, key, w, h, point, x, y)
    local tex = parent:CreateTexture(nil, "BACKGROUND")
    ns.SetTex(tex, key)
    tex:SetSize(w, h)
    tex:SetPoint(point, parent, point, x, y)
    return tex
end

local function CountBox(parent)
    local right = parent:CreateTexture(nil, "ARTWORK")
    right:SetTexture("Interface\\Common\\Common-Input-Border")
    right:SetTexCoord(0.9375, 1, 0, 0.625)
    right:SetSize(8, 20)
    right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -47, -41)
    local middle = parent:CreateTexture(nil, "ARTWORK")
    middle:SetTexture("Interface\\Common\\Common-Input-Border")
    middle:SetTexCoord(0.0625, 0.9375, 0, 0.625)
    middle:SetSize(100, 20)
    middle:SetPoint("RIGHT", right, "LEFT", 0, 0)
    local left = parent:CreateTexture(nil, "ARTWORK")
    left:SetTexture("Interface\\Common\\Common-Input-Border")
    left:SetTexCoord(0, 0.0625, 0, 0.625)
    left:SetSize(8, 20)
    left:SetPoint("RIGHT", middle, "LEFT", 0, 0)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetTextColor(ns.QuestYellow())
    text:SetPoint("RIGHT", right, "RIGHT", -6, 0)
    return text, middle, right
end

-- The 3.x window's Show Map button: the map icon with its label to
-- the left, opening the world map.
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
    -- The click goes to a secure pad laid over the button (the same one
    -- the map micro button has), which presses the client's own map
    -- button: a map opened from a click of ours has its pins made in the
    -- addon's name, and the map key is then blocked on them in a fight.
    -- What is left here is for a window opened during a fight, when the
    -- pad cannot be laid, and for a client without that button.
    button:SetScript("OnClick", function()
        if InCombatLockdown() then
            if UIErrorsFrame and ERR_NOT_IN_COMBAT then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1) end
            return
        end
        ns.HideQuestLog()
        if ToggleWorldMap then ToggleWorldMap() elseif WorldMapFrame then ShowUIPanel(WorldMapFrame) end
    end)
    -- The window stands in the HIGH layer and raises itself when pressed.
    if ns.MapPad then ns.MapPad(button, "DIALOG", function() ns.HideQuestLog() end) end
    return button
end

local function AllTab(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(54, 32)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", 70, -48)
    local button = CreateFrame("Button", nil, holder)
    button:SetSize(40, 22)
    button:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -2)
    local left = button:CreateTexture(nil, "BACKGROUND")
    ns.SetTex(left, "questLogTabLeft")
    left:SetSize(8, 32)
    left:SetPoint("TOPLEFT", button, "TOPLEFT", -6, 8)
    local middle = button:CreateTexture(nil, "BACKGROUND")
    ns.SetTex(middle, "questLogTabMiddle")
    middle:SetSize(38, 32)
    middle:SetPoint("LEFT", left, "RIGHT", 0, 0)
    local right = button:CreateTexture(nil, "BACKGROUND")
    ns.SetTex(right, "questLogTabRight")
    right:SetSize(8, 32)
    right:SetPoint("LEFT", middle, "RIGHT", 0, 0)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", button, "LEFT", 3, 0)
    icon:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
    local glow = button:CreateTexture(nil, "HIGHLIGHT")
    glow:SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
    glow:SetBlendMode("ADD")
    glow:SetAllPoints(icon)
    local text = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("LEFT", button, "LEFT", 20, 0)
    text:SetText(ALL or "All")
    text:SetTextColor(ns.QuestYellow())
    button:SetScript("OnClick", function()
        if frame.allCollapsed then
            ns.QuestLogSetAllCollapsed(false)
            PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN)
        else
            ns.QuestLogSetAllCollapsed(true)
            PlaySound(SOUNDKIT.IG_QUEST_LIST_CLOSE)
        end
        UpdateAll()
    end)
    holder.icon = icon
    return holder
end

-- A radio-style check with a label beside the All tab: Track Quest,
-- and under it the switch to the double pane.
local function RadioCheck(parent, anchor, y, text)
    local button = CreateFrame("CheckButton", nil, parent)
    button:SetSize(20, 20)
    button:SetPoint("LEFT", anchor, "RIGHT", 5, y)
    button:SetNormalTexture("Interface\\Buttons\\UI-RadioButton")
    button:GetNormalTexture():SetTexCoord(0, 0.25, 0, 1)
    button:SetHighlightTexture("Interface\\Buttons\\UI-RadioButton")
    button:GetHighlightTexture():SetTexCoord(0.5, 0.75, 0, 1)
    button:GetHighlightTexture():SetBlendMode("ADD")
    button:SetCheckedTexture("Interface\\Buttons\\UI-RadioButton")
    button:GetCheckedTexture():SetTexCoord(0.25, 0.5, 0, 1)
    local label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("LEFT", button, "RIGHT", 0, 0)
    label:SetText(text)
    return button
end

local function TrackButton(parent, anchor)
    local button = RadioCheck(parent, anchor, 17, TRACK_QUEST or "Track Quest")
    button:SetScript("OnClick", function(self)
        if not selectedID then self:SetChecked(false) return end
        SetWatched(selectedID, self:GetChecked())
        PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        UpdateAll()
    end)
    return button
end

local function EmptyPane(parent)
    local empty = CreateFrame("Frame", nil, parent)
    empty:SetSize(WIDTH, HEIGHT)
    empty:SetPoint("TOPLEFT", parent, "TOPLEFT", LIST_X, -73)
    empty.pieces = {
        Piece(empty, "questLogEmptyTopLeft", 256, 256, "TOPLEFT", 0, 0),
        Piece(empty, "questLogEmptyTopRight", 64, 256, "TOPRIGHT", -64, 0),
        Piece(empty, "questLogEmptyBotLeft", 256, 128, "BOTTOMLEFT", 0, 128),
        Piece(empty, "questLogEmptyBotRight", 64, 128, "BOTTOMRIGHT", -64, 128),
    }
    local text = empty:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetWidth(200)
    text:SetPoint("TOP", parent, "TOP", -20, -105)
    empty.text = text
    text:SetText(QUESTLOG_NO_QUESTS_TEXT or "You have no quests. Look for exclamation marks over the heads of characters to find quests.")
    empty:Hide()
    return empty
end

-- One window, two shapes: the 1.x single pane (list over parchment) or
-- the 3.x double pane (list beside parchment). Everything is re-anchored
-- for the shape; the rows, scroll bars and detail pool are shared.
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
    -- The right pane's bar rides the track drawn on the right sheet: 8px
    -- out from the parchment, its arrows 12px past the parchment's top
    -- and bottom, all three on one vertical line.
    frame.detailBar:ClearAllPoints()
    frame.listBar:ClearAllPoints()
    if dual then
        frame.detailBar:SetPoint("TOPLEFT", frame.detail, "TOPRIGHT", 12, -10)
        frame.detailBar:SetPoint("BOTTOMLEFT", frame.detail, "BOTTOMRIGHT", 12, 14)
        -- The list's bar on the left sheet's track: the arrows sit a
        -- little further out than on the single sheet.
        frame.listBar:SetPoint("TOPLEFT", frame.listArea, "TOPRIGHT", 10, -14)
        frame.listBar:SetPoint("BOTTOMLEFT", frame.listArea, "BOTTOMRIGHT", 10, 14)
    else
        frame.detailBar:SetPoint("TOPLEFT", frame.detail, "TOPRIGHT", 7, -16)
        frame.detailBar:SetPoint("BOTTOMLEFT", frame.detail, "BOTTOMRIGHT", 7, 16)
        frame.listBar:SetPoint("TOPLEFT", frame.listArea, "TOPRIGHT", 7, -16)
        frame.listBar:SetPoint("BOTTOMLEFT", frame.listArea, "BOTTOMRIGHT", 7, 16)
    end
    frame.book:ClearAllPoints()
    frame.book:SetPoint("TOPLEFT", frame, "TOPLEFT", dual and 6 or 4, dual and -6 or -4)
    frame.title:ClearAllPoints()
    frame.title:SetPoint("TOP", frame, "TOP", 0, dual and -19 or -17)
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
    -- The same switch in both shapes: under Track Quest in the single
    -- pane, beside the quest count in the double.
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
        frame.trackButton:ClearAllPoints()
        frame.trackButton:SetPoint("LEFT", frame.share, "RIGHT", 2, 0)
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
    -- No quests: the old empty parchment in the single pane; in the
    -- double pane the well is empty and the words sit in it.
    for _, tex in ipairs(frame.empty.pieces) do tex:SetShown(not dual) end
    frame.empty.text:ClearAllPoints()
    if dual then
        frame.empty.text:SetPoint("TOP", frame.listArea, "TOP", 0, -30)
    else
        frame.empty.text:SetPoint("TOP", frame, "TOP", -20, -105)
    end
end

function ns.QuestLogSetDual(on)
    if not frame then return end
    frame.dual = on and true or false
    Layout()
    if frame:IsShown() then UpdateAll() end
end

local function Build()
    frame = CreateFrame("Frame", FRAME_NAME, UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
    frame:SetToplevel(true)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    ns.RegisterClassicWindow(frame)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint(1)
        ns.db.questLogPos = { point, relPoint, x, y }
    end)
    frame:Hide()
    local pos = ns.db.questLogPos
    if pos then
        frame:ClearAllPoints()
        frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    end

    frame.singleArt = {
        Piece(frame, "questLogTopLeft", 256, 256, "TOPLEFT", 0, 0),
        Piece(frame, "questLogTopRight", 128, 256, "TOPRIGHT", 0, 0),
        Piece(frame, "questLogBotLeft", 256, 256, "BOTTOMLEFT", 0, 0),
        Piece(frame, "questLogBotRight", 128, 256, "BOTTOMRIGHT", 0, 0),
    }
    frame.dualArt = {
        Piece(frame, "questLogDualLeft", 512, 512, "TOPLEFT", 0, 0),
        Piece(frame, "questLogDualRight", 256, 512, "TOPLEFT", 512, 0),
    }
    local book = frame:CreateTexture(nil, "ARTWORK")
    ns.SetTex(book, "questLogBook")
    book:SetSize(64, 64)
    book:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    frame.book = book

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", frame, "TOP", 0, -17)
    title:SetText(QUEST_LOG or "Quest Log")
    frame.title = title

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -8)
    if ns.SkinCloseButton then ns.SkinCloseButton(close, true) end
    close:SetScript("OnClick", function() ns.HideQuestLog() end)
    frame.close = close

    frame.count, frame.countMiddle, frame.countRight = CountBox(frame)
    frame.allTab = AllTab(frame)
    frame.allIcon = frame.allTab.icon
    frame.track = TrackButton(frame, frame.allTab)
    -- The double pane can be switched to from here as well as from the
    -- options; the two stay one setting.
    frame.dualToggle = RadioCheck(frame, frame.allTab, 0, "Double pane")
    frame.dualToggle:SetScript("OnClick", function(self)
        PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        ns.db.questLogDual = self:GetChecked() and true or false
        ns.ApplyAll()
        if ns.RefreshOptionsWindow then ns.RefreshOptionsWindow() end
    end)
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
    frame.listBar = ScrollBar(frame, listArea, function() UpdateList() end)

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
    frame.detailBar = ScrollBar(frame, detail, function(value) detail:SetVerticalScroll(value) end)

    frame.empty = EmptyPane(frame)

    frame.abandon = ns.PanelButton(frame, ABANDON_QUEST or "Abandon Quest", 125)
    frame.abandon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 17, 54)
    frame.abandon:SetScript("OnClick", function()
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
    end)
    frame.exit = ns.PanelButton(frame, EXIT or "Exit", 77)
    frame.exit:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -43, 54)
    frame.exit:SetScript("OnClick", function() ns.HideQuestLog() end)
    frame.share = ns.PanelButton(frame, SHARE_QUEST or "Share Quest", 123)
    frame.share:SetPoint("RIGHT", frame.exit, "LEFT", 0, 0)
    -- The double pane tracks with a button along the foot, as 3.x did,
    -- in place of the single pane's Track Quest check.
    frame.trackButton = ns.PanelButton(frame, TRACK_QUEST_ABBREV or "Track", 76)
    frame.trackButton:SetScript("OnClick", function()
        if not selectedID then return end
        SetWatched(selectedID, not IsWatched(selectedID))
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        UpdateAll()
    end)
    frame.share:SetScript("OnClick", function()
        local info = selectedID and QuestInLog(selectedID)
        if not info or not QuestLogPushQuest then return end
        if not IsInGroup() then
            UIErrorsFrame:AddMessage(ERR_QUEST_PUSH_NOT_IN_PARTY_S and "You are not in a party." or "You are not in a party.", 1, 0.1, 0.1)
            return
        end
        if C_QuestLog.IsPushableQuest(info.questID) then QuestLogPushQuest(info.questLogIndex) end
    end)

    frame:RegisterEvent("QUEST_LOG_UPDATE")
    frame:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
    frame:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_MONEY")
    -- A quest giver's window takes the log's place, as the old panels did.
    for _, event in ipairs({ "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "GOSSIP_SHOW" }) do
        pcall(frame.RegisterEvent, frame, event)
    end
    local GIVER = { QUEST_DETAIL = true, QUEST_PROGRESS = true, QUEST_COMPLETE = true, QUEST_GREETING = true, GOSSIP_SHOW = true }
    frame:SetScript("OnEvent", function(self, event, unit)
        if GIVER[event] then
            if self:IsShown() then self:Hide() end
            return
        end
        if event == "UNIT_QUEST_LOG_CHANGED" and unit ~= "player" then return end
        if self:IsShown() then UpdateAll() end
    end)
    -- Timed quests count down once a second.
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, dt)
        if not self.hasTimer then return end
        elapsed = elapsed + dt
        if elapsed >= 1 then
            elapsed = 0
            UpdateDetail()
        end
    end)
    frame:HookScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN)
        UpdateAll()
        ns.RefreshMicroButtons()
    end)
    frame:HookScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_QUEST_LOG_CLOSE)
        GameTooltip:Hide()
        ns.RefreshMicroButtons()
    end)
    if ns.MicroButtonFollows then
        ns.MicroButtonFollows(QuestLogMicroButton, function() return active and frame:IsShown() end)
    end
    frame.dual = ns.db.questLogDual == true
    Layout()
end

function ns.ShowQuestLog(questID)
    if not active then return end
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

-- The quest log key: an override binding on a button of ours, refreshed
-- when bindings change and combat allows.
local function UpdateBinding()
    if not bindButton or InCombatLockdown() then return end
    ClearOverrideBindings(bindButton)
    if not active then return end
    local key = GetBindingKey("TOGGLEQUESTLOG")
    if key then SetOverrideBindingClick(bindButton, true, key, BIND_NAME, "LeftButton") end
end

local hooked = false
local function Init()
    if hooked then return end
    hooked = true
    bindButton = CreateFrame("Button", BIND_NAME, UIParent, "SecureActionButtonTemplate")
    bindButton:SetScript("OnClick", function() if active then ns.ToggleQuestLog() end end)
    bindButton:RegisterEvent("UPDATE_BINDINGS")
    bindButton:RegisterEvent("PLAYER_REGEN_ENABLED")
    bindButton:RegisterEvent("PLAYER_ENTERING_WORLD")
    bindButton:SetScript("OnEvent", UpdateBinding)
    -- Quest headers in the tracker open this log rather than the map.
    for _, name in ipairs({ "QuestObjectiveTracker", "CampaignQuestObjectiveTracker" }) do
        local tracker = _G[name]
        if tracker then
            ns.HookMethod(tracker, "OnBlockHeaderClick", function(_, block, button)
                if not active or button == "RightButton" then return end
                if IsModifiedClick("CHATLINK") or IsModifiedClick("QUESTWATCHTOGGLE") then return end
                if WorldMapFrame and WorldMapFrame:IsShown() then HideUIPanel(WorldMapFrame) end
                ns.ShowQuestLog(block and block.id)
            end)
        end
    end
    -- The map opens on its own; the quest panel belongs to this window
    -- now. Whether the map opens with its panel is a setting the map
    -- reads as it opens, and that setting is all that is touched: the
    -- map's own toggle, called from here, ran the whole of the map's
    -- layout in the addon's name, and the map key pressed in a later
    -- fight was blocked for it.
    local mapWatch = CreateFrame("Frame")
    mapWatch:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 0.5 then return end
        self.since = 0
        if active and C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("questLogOpen") then
            C_CVar.SetCVar("questLogOpen", "0")
        end
    end)
    -- Escape closes the log the way it closes the old panels.
    if GameMenuFrame then
        GameMenuFrame:HookScript("OnShow", function(menu)
            if frame and frame:IsShown() then
                ns.HideQuestLog()
                HideUIPanel(menu)
            end
        end)
    end
end

local function Apply()
    active = true
    if QuestLogMicroButton then
        if not originalMicroClick then originalMicroClick = QuestLogMicroButton:GetScript("OnClick") end
        QuestLogMicroButton:SetScript("OnClick", function()
            ns.ToggleQuestLog()
        end)
    end
    UpdateBinding()
end

local function Restore()
    active = false
    ns.HideQuestLog()
    if QuestLogMicroButton and originalMicroClick then
        QuestLogMicroButton:SetScript("OnClick", originalMicroClick)
        originalMicroClick = nil
    end
    UpdateBinding()
end

ns.RegisterModule("questLog", { init = Init, apply = Apply, restore = Restore })
-- The double pane is a shape of the same window; its toggle relays it.
ns.RegisterModule("questLogDual", {
    apply = function() ns.QuestLogSetDual(true) end,
    restore = function() ns.QuestLogSetDual(false) end,
})
