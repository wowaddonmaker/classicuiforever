local _, ns = ...

-- Quest log data for QuestLogWindow.lua; ns.QL is the quest log's private table.

local QL = {}
ns.QL = QL

QL.active = false        -- questLog module on; written by QuestLog.lua

local entries = {}       -- visible headers and quests, in log order
local collapsed = {}     -- header key -> true while shut in our list

local function HeaderKey(info)
    return info.headerSortKey or info.title or info.questLogIndex
end

-- Count re-read each pass: ExpandQuestHeader grows the log mid-walk.
function QL.CollectEntries()
    wipe(entries)
    local skipping = false
    local i = 1
    while i <= (C_QuestLog.GetNumQuestLogEntries() or 0) do
        local info = C_QuestLog.GetInfo(i)
        if info and info.isHeader then
            -- A client-collapsed header hides its quests: expand it, collapse in our list instead.
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

function QL.SetAllCollapsed(shut)
    wipe(collapsed)
    if shut then
        for _, info in ipairs(entries) do
            if info.isHeader then collapsed[HeaderKey(info)] = true end
        end
    end
end

-- True when the header is now shut.
function QL.ToggleHeader(info)
    local key = HeaderKey(info)
    if collapsed[key] then
        collapsed[key] = nil
        return false
    end
    collapsed[key] = true
    return true
end

function QL.QuestInLog(questID)
    for _, info in ipairs(entries) do
        if not info.isHeader and info.questID == questID then return info end
    end
end

function QL.FirstQuest()
    for _, info in ipairs(entries) do
        if not info.isHeader then return info.questID end
    end
end

function QL.TagFor(info)
    if C_QuestLog.IsFailed and C_QuestLog.IsFailed(info.questID) then return FAILED or "Failed" end
    if C_QuestLog.IsComplete(info.questID) then return COMPLETE or "Complete" end
    if info.frequency == Enum.QuestFrequency.Daily then return DAILY or "Daily" end
    if info.frequency == Enum.QuestFrequency.Weekly then return WEEKLY or "Weekly" end
    local tag = C_QuestLog.GetQuestTagInfo and C_QuestLog.GetQuestTagInfo(info.questID)
    if tag and tag.tagName and tag.tagName ~= "" then return tag.tagName end
    if info.suggestedGroup and info.suggestedGroup > 0 then return (GROUP or "Group") end
    return nil
end

-- Forever's titles carry the game's level prefix whatever Show Quest Levels says (build 70291, #140): taken off here
-- while Quest levels is off. "[17] " or "[17+] ", inside a colour code too.
function ns.StripQuestLevel(text)
    if not text or ns.db.questLevels or not ns.OnForever() then return end
    local title = text:GetText()
    if ns.IsSecret(title) or type(title) ~= "string" then return end
    local bare = title:gsub("^(|c%x%x%x%x%x%x%x%x)%[%d+%+?%] ", "%1", 1)
    if bare == title then bare = title:gsub("^%[%d+%+?%] ", "", 1) end
    if bare ~= title then text:SetText(bare) end
end

-- Headers: the client's header colour or grey; quests: the 1.x difficulty colour.
function QL.LevelColor(info)
    if info.isHeader then
        local header = QuestDifficultyColors and QuestDifficultyColors["header"]
        if header then return header.r, header.g, header.b end
        return 0.7, 0.7, 0.7
    end
    local level = info.difficultyLevel or info.level or 0
    return ns.QuestLevelColor(level)
end

function QL.IsWatched(questID)
    return C_QuestLog.GetQuestWatchType(questID) ~= nil
end

function QL.SetWatched(questID, watched)
    if watched then
        C_QuestLog.AddQuestWatch(questID, Enum.QuestWatchType and Enum.QuestWatchType.Manual)
    elseif not QuestUtil or not QuestUtil.CanRemoveQuestWatch or QuestUtil.CanRemoveQuestWatch() then
        C_QuestLog.RemoveQuestWatch(questID)
    end
end

-- The game's own abandon prompt for a quest in the log, naming the items it takes with it.
function QL.AbandonPrompt(questID)
    if not questID then return end
    C_QuestLog.SetSelectedQuest(questID)
    C_QuestLog.SetAbandonQuest()
    local info = QL.QuestInLog(questID)
    local name = C_QuestLog.GetAbandonQuestName and C_QuestLog.GetAbandonQuestName() or info and info.title or ""
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

-- Party members on the quest; solo returns the shared ns.EMPTY, no allocation.
function QL.PartyOnQuest(questID)
    if not questID or not IsInGroup or not IsInGroup() then return ns.EMPTY end
    if not (C_QuestLog and C_QuestLog.IsUnitOnQuest) then return ns.EMPTY end
    local names = {}
    for i = 1, (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0) do
        local unit = "party" .. i
        local ok, on = pcall(C_QuestLog.IsUnitOnQuest, unit, questID)
        if ok and on == true then
            -- Names are secret in dungeons (no test, no concat): use the unit token.
            names[#names + 1] = ns.Safe(UnitName(unit), unit)
        end
    end
    return names
end
