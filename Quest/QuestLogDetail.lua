local _, ns = ...

-- The quest log's detail pane: the selected quest's text and rewards down the parchment.

local QL = ns.QL

local TEXT_W = 285
-- Two reward buttons plus the gap span the text width.
local REWARD_GAP = 3
local REWARD_SCALE = (TEXT_W - REWARD_GAP) / 2 / 147

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
local INK_R, INK_G, INK_B = 0.18, 0.12, 0.06    -- parchment ink
local DONE_R, DONE_G, DONE_B = 0.2, 0.2, 0.2    -- a finished objective

-- The log window; FillDetail sets it before any piece is made.
local frame

-- Pooled font strings stacked down the parchment.
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
    ns.SetPointOnce(fs, "TOPLEFT", anchor or frame.detailChild, relPoint or "TOPLEFT", x or 0, y or 0)
    fs:SetTextColor(INK_R, INK_G, INK_B)
    fs:Show()
    return fs
end

local function RewardEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    pcall(GameTooltip.SetQuestLogItem, GameTooltip, self.rewardType, self.index, QL.SelectedID())
    GameTooltip:Show()
end

local function RewardClick(self)
    if IsModifiedClick("CHATLINK") and ChatFrameUtil and ChatFrameUtil.InsertLink then
        local ok, link = pcall(GetQuestLogItemLink, self.rewardType, self.index, QL.SelectedID())
        if ok and link then ChatFrameUtil.InsertLink(link) end
    end
end

-- The 1.x reward button at its native 147x41, scaled so two fit across the page.
local function RewardButton()
    rewardsUsed = rewardsUsed + 1
    local button = rewardButtons[rewardsUsed]
    if not button then
        button = CreateFrame("Button", nil, frame.detailChild)
        button:SetSize(147, 41)
        button:SetScale(REWARD_SCALE)
        button.icon = button:CreateTexture(nil, "BACKGROUND")
        button.icon:SetSize(39, 39)
        button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.nameBox = button:CreateTexture(nil, "BACKGROUND", nil, 1)
        ns.SetTex(button.nameBox, "lootNameFrame")
        button.nameBox:SetTexCoord(0, 1, 0, 1)
        button.nameBox:SetSize(128, 64)
        button.nameBox:SetPoint("LEFT", button.icon, "RIGHT", -10, 0)
        button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        button.count:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", -1, 1)
        button.name = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        button.name:SetSize(90, 36)
        button.name:SetPoint("LEFT", button.nameBox, "LEFT", 15, 0)
        button.name:SetJustifyH("LEFT")
        button.name:SetWordWrap(true)
        button.name:SetMaxLines(3)
        button:SetScript("OnEnter", RewardEnter)
        button:SetScript("OnLeave", ns.HideTip)
        button:SetScript("OnClick", RewardClick)
        rewardButtons[rewardsUsed] = button
    end
    button:Show()
    return button
end

function QL.ResetDetail()
    for i = 1, detailUsed do detailStrings[i]:Hide() end
    for i = 1, rewardsUsed do rewardButtons[i]:Hide() end
    detailUsed, rewardsUsed = 0, 0
end

local function Coins(copper)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then return C_CurrencyInfo.GetCoinTextureString(copper) end
    return GetCoinTextureString and GetCoinTextureString(copper) or tostring(copper)
end

-- Rewards under `last`, two per row, coins after the header (money alone still gets one).
local function RewardGrid(questID, last, kind, count, header, coins)
    if count <= 0 and not coins then return last end
    local label = DetailString(FONT_SMALL, TEXT_W, 0, -5, last, "BOTTOMLEFT")
    label:SetText(header)
    last = label
    if coins then
        local line = DetailString(FONT_SMALL, TEXT_W, 0, 0, label, "TOPLEFT")
        ns.SetPointOnce(line, "LEFT", label, "LEFT", (label:GetStringWidth() or 0) + 15, 0)
        line:SetText(coins)
    end
    local rowAnchor = last
    for i = 1, count do
        local button = RewardButton()
        button.rewardType, button.index = kind, i
        local name, texture, count2, _, itemID
        if kind == "choice" then
            name, texture, count2, _, _, itemID = GetQuestLogChoiceInfo(i, questID)
        else
            name, texture, count2, _, _, itemID = GetQuestLogRewardInfo(i, questID)
        end
        button.icon:SetTexture(texture)
        button.count:SetText((count2 or 0) > 1 and count2 or "")
        button.name:SetText(name or (itemID and ("item " .. itemID)) or "")
        -- 1.x showed reward names in white regardless of quality.
        button.name:SetTextColor(1, 1, 1)
        button:ClearAllPoints()
        -- Offsets are in the button's scaled units.
        if i % 2 == 1 then
            button:SetPoint("TOPLEFT", rowAnchor, "BOTTOMLEFT", 0, -4 / REWARD_SCALE)
            rowAnchor = button
            last = button
        else
            button:SetPoint("TOPLEFT", rowAnchor, "TOPRIGHT", REWARD_GAP / REWARD_SCALE, 0)
        end
    end
    return last
end

-- Rewards after `last`: choices, fixed items with money, then experience.
local function LayoutRewards(last, questID)
    local numChoices = GetNumQuestLogChoices(questID, true) or 0
    local numRewards = GetNumQuestLogRewards(questID) or 0
    local money = GetQuestLogRewardMoney(questID) or 0
    local xp = GetQuestLogRewardXP and GetQuestLogRewardXP(questID) or 0
    if numChoices + numRewards + money + xp <= 0 then return last end

    local title = DetailString(FONT_TITLE, TEXT_W, 0, -10, last, "BOTTOMLEFT")
    title:SetText(QUEST_REWARDS or "Rewards")
    last = title
    last = RewardGrid(questID, last, "choice", numChoices, REWARD_CHOICES or "Choose one of the following rewards:")
    last = RewardGrid(questID, last, "reward", numRewards,
        numChoices > 0 and (REWARD_ITEMS or "You will also receive:") or (REWARD_ITEMS_ONLY or "You will receive:"),
        money > 0 and Coins(money) or nil)
    if xp > 0 then
        local line = DetailString(FONT_SMALL, TEXT_W, 0, -4, last, "BOTTOMLEFT")
        line:SetText(string.format("%s: %s", REWARD_XP or "Experience", BreakUpLargeNumbers and BreakUpLargeNumbers(xp) or xp))
        last = line
    end
    return last
end

-- Writes the page for info, a quest in the log; setHasTimer is the window's timer switch, called where the timer is read.
function QL.FillDetail(window, info, detailH, setHasTimer)
    frame = window
    local child = frame.detailChild
    local selectedID = info.questID
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
    setHasTimer(timeLeft ~= nil)
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
            line:SetTextColor(DONE_R, DONE_G, DONE_B)
            text = text .. " (" .. (COMPLETE or "Complete") .. ")"
        end
        line:SetText(text)
        last = line
    end

    local required = C_QuestLog.GetRequiredMoney and C_QuestLog.GetRequiredMoney(selectedID) or 0
    if required > 0 then
        local line = DetailString(FONT_SMALL, TEXT_W, 0, numObjectives > 0 and -4 or -10, last, "BOTTOMLEFT")
        line:SetText((REQUIRED_MONEY or "Required Money:") .. " " .. Coins(required))
        if required > GetMoney() then line:SetTextColor(1, 0.1, 0.1) else line:SetTextColor(DONE_R, DONE_G, DONE_B) end
        last = line
    end

    if description and description ~= "" then
        local header = DetailString(FONT_TITLE, TEXT_W, 0, -10, last, "BOTTOMLEFT")
        header:SetText(QUEST_DESCRIPTION or "Description")
        local body = DetailString(FONT_BODY, TEXT_W - 10, 0, -5, header, "BOTTOMLEFT")
        body:SetText(description)
        last = body
    end

    last = LayoutRewards(last, selectedID)

    -- Scroll child spans the pane top to the last piece.
    local top, bottom = child:GetTop(), last:GetBottom()
    local height = (top and bottom) and (top - bottom + 12) or detailH
    child:SetHeight(math.max(height, detailH))
    frame.detailBar:SetRange(math.max(0, height - detailH), 20)
end
