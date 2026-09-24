local _, ns = ...

-- Quest and gossip windows at 1.x height; the old name box behind quest rewards.

local P = ns.panels
local EMPTY = ns.EMPTY

local REWARD_BOX = { own = "nameBox", layer = "BACKGROUND", sublevel = 1, coords = { 0, 1, 0, 1 } }
local REWARD_FRAMES = { "QuestInfoRewardsFrame", "MapQuestInfoRewardsFrame" }
local REWARD_LISTS = { "RewardButtons", "SpellRewardButtons" }

-- 1.x name box behind the reward text; the client borders the icon instead.
function ns.SkinQuestReward(button)
    if not button or not ns.Once(button, "reward") then return end
    local box = ns.DressNew(button, "lootNameFrame", REWARD_BOX)
    local width = (button:GetWidth() or 143) - 40
    local height = math.max(36, (button:GetHeight() or 40) - 2)
    ns.FitNamePlate(box, button, 38, width, height)
    box:Show()
    if button.NameFrame then button.NameFrame:SetAlpha(0) end
    if button.IconBorder then button.IconBorder:SetAlpha(0) end
end

-- Reward buttons of the quest giver, the log's detail and the map's.
function ns.SkinQuestRewards()
    for _, name in ipairs(REWARD_FRAMES) do
        local frame = _G[name]
        if frame then
            for _, key in ipairs(REWARD_LISTS) do
                for _, button in ipairs(frame[key] or EMPTY) do ns.SkinQuestReward(button) end
            end
        end
    end
    local i = 1
    while _G["QuestInfoItem" .. i] do
        ns.SkinQuestReward(_G["QuestInfoItem" .. i])
        i = i + 1
    end
end

-- Client windows are 496 tall (text 403); 1.x held 334 of text. Trimmed once:
-- only the client's layout files size them. Foot buttons follow the bottom edge.
local NPC_WINDOW_TRIM = 69

-- A frame given by name or as itself.
local function Resolve(region)
    if type(region) == "string" then return _G[region] end
    return region
end

-- Cap each page at its scroll area (the tall fixed height scrolled short quests
-- over blank parchment); longer text still scrolls.
local function FitPages(scrolls)
    for _, scroll in ipairs(scrolls or EMPTY) do
        scroll = Resolve(scroll)
        local page = scroll and scroll.GetScrollChild and scroll:GetScrollChild()
        local room = scroll and scroll.GetHeight and scroll:GetHeight()
        if page and room and room > 0 and page.GetHeight and (page:GetHeight() or 0) > room + 0.5 then
            page:SetHeight(room)
            if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
        end
    end
end

local function Trim(region, atLeast)
    region = Resolve(region)
    if not region or not region.GetHeight or not region.SetHeight then return end
    local tall = region:GetHeight()
    if tall and tall > atLeast then region:SetHeight(tall - NPC_WINDOW_TRIM) end
end

-- Parchment sizes from its art, which the client re-sets when theming (it hung
-- below the gossip window): pin its foot to end with the text area.
local function Foot(ground, frame)
    if not ground or not ground.SetPoint then return end
    local point, _, _, x = ground:GetPoint(1)
    if point ~= "TOPLEFT" then return end
    ground:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x or 7, 27)
end

local function ShortenNpcWindow(frame, scrolls, panels, grounds)
    if not frame then return end
    if frame.fcuiShort then
        FitPages(scrolls)
        return
    end
    local height = frame:GetHeight()
    -- Any height, as long as it is the tall one.
    if not height or height < 470 then return end
    frame.fcuiShort = true
    frame:SetHeight(height - NPC_WINDOW_TRIM)
    for _, scroll in ipairs(scrolls or EMPTY) do Trim(scroll, 200) end
    FitPages(scrolls)
    for _, panel in ipairs(panels or EMPTY) do
        panel = Resolve(panel)
        Trim(panel, 400)
        if panel and panel.Bg then Foot(panel.Bg, frame) end
    end
    for _, ground in ipairs(grounds or EMPTY) do Foot(ground, frame) end
end

local QUEST_SCROLLS = { "QuestDetailScrollFrame", "QuestProgressScrollFrame", "QuestRewardScrollFrame", "QuestGreetingScrollFrame" }
local QUEST_PANELS = { "QuestFrameDetailPanel", "QuestFrameProgressPanel", "QuestFrameRewardPanel", "QuestFrameGreetingPanel" }

function P.after.QuestFrame(frame)
    ShortenNpcWindow(frame, QUEST_SCROLLS, QUEST_PANELS)
    ns.SkinQuestRewards()
    ns.HookGlobal("QuestInfo_Display", ns.SkinQuestRewards)
    ns.HookGlobal("QuestInfo_ShowRewards", ns.SkinQuestRewards)
end

function P.after.GossipFrame(frame)
    local panel = frame.GreetingPanel
    ShortenNpcWindow(frame, { panel and panel.ScrollBox }, { panel }, { frame.Background })
end
