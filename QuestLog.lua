local _, ns = ...

-- The 1.x quest log: its own window, nothing to do with the map. The old
-- four-piece art with the book in the portrait ring, the quest count box,
-- the All tab, Track Quest, six list rows over a parchment detail pane,
-- and Abandon, Share and Exit along the bottom. The quest micro button,
-- the quest log key and quest clicks in the tracker open it in place of
-- the map's quest panel. Built on the modern quest API, so it works on
-- both the Forever client and retail.

local WIDTH, HEIGHT = 384, 512
local ROWS, ROW_H = 6, 16
local LIST_X, LIST_Y, LIST_W = 19, -75, 300
local LIST_H = 93   -- the art's list track; the six rows run a little past it
local DETAIL_GAP, DETAIL_H = 7, 260
local TEXT_W = 285
local TITLE_TAG_ROOM = 275

local FRAME_NAME = "ForeverClassicUIQuestLog"
local BIND_NAME = "ForeverClassicUIQuestLogBind"

local active = false
local frame, bindButton
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

-- A slider dressed as the old scroll bar, with its two arrow buttons.
local function ScrollBar(parent, anchorTo, onValue)
    local bar = CreateFrame("Slider", nil, parent)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(16)
    bar:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 6, -16)
    bar:SetPoint("BOTTOMLEFT", anchorTo, "BOTTOMRIGHT", 6, 16)
    local thumb = bar:CreateTexture(nil, "ARTWORK")
    ns.SetTex(thumb, "scrollKnob")
    thumb:SetSize(18, 24)
    thumb:SetTexCoord(0.2, 0.8, 0.125, 0.875)
    bar:SetThumbTexture(thumb)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)

    local function Arrow(kind, point, relPoint)
        local button = CreateFrame("Button", nil, bar)
        button:SetSize(16, 16)
        button:SetPoint(point, bar, relPoint, 0, 0)
        ns.SetButtonTex(button, "Normal", "scroll" .. kind .. "ButtonUp")
        ns.SetButtonTex(button, "Pushed", "scroll" .. kind .. "ButtonDown")
        ns.SetButtonTex(button, "Disabled", "scroll" .. kind .. "ButtonDisabled")
        ns.SetButtonTex(button, "Highlight", "scroll" .. kind .. "ButtonHighlight")
        button:GetHighlightTexture():SetBlendMode("ADD")
        -- The sheets are 32x32 with the 16x16 arrow in the middle.
        for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
            local tex = button["Get" .. state .. "Texture"](button)
            if tex then tex:SetTexCoord(0.25, 0.75, 0.25, 0.75) end
        end
        return button
    end
    bar.up = Arrow("Up", "BOTTOM", "TOP")
    bar.down = Arrow("Down", "TOP", "BOTTOM")
    bar.up:SetScript("OnClick", function() bar:SetValue(bar:GetValue() - bar.step) PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON) end)
    bar.down:SetScript("OnClick", function() bar:SetValue(bar:GetValue() + bar.step) PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON) end)
    bar.step = 1

    function bar:SetRange(max, step)
        self.step = step or 1
        max = math.max(0, max)
        local value = self:GetValue()
        self:SetMinMaxValues(0, max)
        self:SetValue(math.min(value, max))
        self:SetShown(true)
        self:Refresh()
    end
    function bar:Refresh()
        local _, max = self:GetMinMaxValues()
        local value = self:GetValue()
        self.up:SetEnabled(value > 0)
        self.down:SetEnabled(value < max)
    end
    bar:SetScript("OnValueChanged", function(self, value)
        self:Refresh()
        onValue(value)
    end)
    return bar
end

-- Visible log entries: headers and real quests, in log order.
local function CollectEntries()
    wipe(entries)
    local count = C_QuestLog.GetNumQuestLogEntries() or 0
    for i = 1, count do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHidden and not info.isTask and not info.isBounty then
            entries[#entries + 1] = info
        end
    end
    return entries
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
    local color = GetQuestDifficultyColor(level)
    return color.r, color.g, color.b
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

local UpdateAll

-- One list row: the plus or minus for headers, the title, the tag on the
-- right, the check when the quest is tracked.
local function RowClick(row)
    local info = row.info
    if not info then return end
    if info.isHeader then
        if info.isCollapsed then
            ExpandQuestHeader(info.questLogIndex)
            PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN)
        else
            CollapseQuestHeader(info.questLogIndex)
            PlaySound(SOUNDKIT.IG_QUEST_LIST_CLOSE)
        end
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
    local row = CreateFrame("Button", nil, frame)
    row:SetSize(LIST_W, ROW_H)
    if index == 1 then
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", LIST_X, LIST_Y)
    else
        row:SetPoint("TOPLEFT", rows[index - 1], "BOTTOMLEFT", 0, -1)
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
    row.text:SetText("  " .. (info.title or ""))
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
    local offset = math.floor(frame.listBar:GetValue() + 0.5)
    frame.listBar:SetRange(#entries - ROWS)
    offset = math.min(offset, math.max(0, #entries - ROWS))
    for i = 1, ROWS do
        FillRow(rows[i], entries[i + offset])
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
    -- The buttons stay gold whatever the log holds, like the old window;
    -- their clicks check for a quest instead of greying out.
    frame.abandon:SetEnabled(true)
    frame.share:SetEnabled(true)
    frame.track:SetChecked(info ~= nil and IsWatched(selectedID))
    frame.track:SetEnabled(info ~= nil)
    if not info then
        child:SetHeight(1)
        frame.detailBar:SetRange(0)
        return
    end
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
    local height = (top and bottom) and (top - bottom + 12) or DETAIL_H
    child:SetHeight(math.max(height, DETAIL_H))
    frame.detailBar:SetRange(math.max(0, height - DETAIL_H), 20)
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
    frame.allTab:SetShown(not empty)
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
    text:SetPoint("RIGHT", right, "RIGHT", -6, 0)
    return text, middle
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
    button:SetScript("OnClick", function()
        if frame.allCollapsed then
            ExpandQuestHeader(0)
            PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN)
        else
            CollapseQuestHeader(0)
            PlaySound(SOUNDKIT.IG_QUEST_LIST_CLOSE)
        end
    end)
    holder.icon = icon
    return holder
end

local function TrackButton(parent, anchor)
    local button = CreateFrame("CheckButton", nil, parent)
    button:SetSize(20, 20)
    button:SetPoint("LEFT", anchor, "RIGHT", 5, 10)
    button:SetNormalTexture("Interface\\Buttons\\UI-RadioButton")
    button:GetNormalTexture():SetTexCoord(0, 0.25, 0, 1)
    button:SetHighlightTexture("Interface\\Buttons\\UI-RadioButton")
    button:GetHighlightTexture():SetTexCoord(0.5, 0.75, 0, 1)
    button:GetHighlightTexture():SetBlendMode("ADD")
    button:SetCheckedTexture("Interface\\Buttons\\UI-RadioButton")
    button:GetCheckedTexture():SetTexCoord(0.25, 0.5, 0, 1)
    local label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("LEFT", button, "RIGHT", 0, 0)
    label:SetText(TRACK_QUEST or "Track Quest")
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
    Piece(empty, "questLogEmptyTopLeft", 256, 256, "TOPLEFT", 0, 0)
    local tr = Piece(empty, "questLogEmptyTopRight", 64, 256, "TOPRIGHT", -64, 0)
    Piece(empty, "questLogEmptyBotLeft", 256, 128, "BOTTOMLEFT", 0, 128)
    Piece(empty, "questLogEmptyBotRight", 64, 128, "BOTTOMRIGHT", -64, 128)
    tr:SetDrawLayer("BACKGROUND")
    local text = empty:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetWidth(200)
    text:SetPoint("TOP", parent, "TOP", -20, -105)
    text:SetText(QUESTLOG_NO_QUESTS_TEXT or "You have no quests. Look for exclamation marks over the heads of characters to find quests.")
    empty:Hide()
    return empty
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

    Piece(frame, "questLogTopLeft", 256, 256, "TOPLEFT", 0, 0)
    Piece(frame, "questLogTopRight", 128, 256, "TOPRIGHT", 0, 0)
    Piece(frame, "questLogBotLeft", 256, 256, "BOTTOMLEFT", 0, 0)
    Piece(frame, "questLogBotRight", 128, 256, "BOTTOMRIGHT", 0, 0)
    local book = frame:CreateTexture(nil, "ARTWORK")
    ns.SetTex(book, "questLogBook")
    book:SetSize(64, 64)
    book:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", frame, "TOP", 0, -17)
    title:SetText(QUEST_LOG or "Quest Log")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -30, -8)
    if ns.SkinCloseButton then ns.SkinCloseButton(close, true) end
    close:SetScript("OnClick", function() ns.HideQuestLog() end)

    frame.count, frame.countMiddle = CountBox(frame)
    frame.allTab = AllTab(frame)
    frame.allIcon = frame.allTab.icon
    frame.track = TrackButton(frame, frame.allTab)

    for i = 1, ROWS do rows[i] = MakeRow(i) end
    local listArea = CreateFrame("Frame", nil, frame)
    listArea:SetPoint("TOPLEFT", frame, "TOPLEFT", LIST_X, LIST_Y)
    listArea:SetSize(LIST_W, LIST_H)
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
    frame:SetScript("OnShow", function()
        PlaySound(SOUNDKIT.IG_QUEST_LOG_OPEN)
        UpdateAll()
    end)
    frame:SetScript("OnHide", function()
        PlaySound(SOUNDKIT.IG_QUEST_LOG_CLOSE)
        GameTooltip:Hide()
    end)
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
    -- The map opens on its own; the quest panel belongs to this window now.
    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function()
            if not active then return end
            C_Timer.After(0, function()
                local map = WorldMapFrame
                if not active or not map or not map:IsShown() or map:IsMaximized() then return end
                -- Blizzard's own side-panel toggle: it shrinks the window
                -- with the panel; closing the panel alone leaves the map wide.
                if map.QuestLog and map.QuestLog:IsShown() and map.HandleUserActionToggleSidePanel then
                    map:HandleUserActionToggleSidePanel()
                end
            end)
        end)
    end
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
