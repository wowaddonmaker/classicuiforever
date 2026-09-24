local _, ns = ...

-- The quest log's Share Quest: a secure pad presses the client's own share, our click only explains.

local QL = ns.QL

-- QuestLogPushQuest is protected: the pad clicks the quest's row in the hidden map's list, the map's Share, then Back.
local SHARE_ROW, SHARE_MAP, SHARE_BACK = "ForeverClassicUIQuestShare", "ForeverClassicUIQuestShareMap",
    "ForeverClassicUIQuestShareBack"
-- [nomod]: shift on a map row toggles tracking and the chat-link modifier links it.
local SHARE_MACRO = "/click [nomod] " .. SHARE_ROW .. "\n/click [nomod] " .. SHARE_MAP .. "\n/click [nomod] " .. SHARE_BACK
local shareProxies   -- row, map Share, map Back

-- The map's quest list left open re-folds every quest header when the hidden map moves to another zone.
local function MovesMap(questID)
    local uiMap = _G.GetQuestUiMapID
    if not uiMap or not (QuestMapFrame and QuestMapFrame:IsShown()) then return false end
    local mapID = uiMap(questID)
    return mapID ~= nil and mapID ~= 0 and mapID ~= WorldMapFrame:GetMapID()
end

-- The quest's row in the hidden map's list, with a questID only client code wrote; reads only.
local function MapRow(questID)
    local find = _G.QuestLogQuests_GetQuestButton
    if not find or not WorldMapFrame or WorldMapFrame:IsShown() or MovesMap(questID) then return nil end
    local row = find(questID)
    if row and issecurevariable(row, "questID") then return row end
    return nil
end

-- Named for /click; sized and placed off screen: a button with neither is never clicked.
local function ShareProxy(name)
    local proxy = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    proxy:SetSize(1, 1)
    proxy:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
    proxy:EnableMouse(false)
    proxy:RegisterForClicks("AnyUp", "AnyDown")
    proxy:SetAttribute("useOnKeyDown", false)
    proxy:SetAttribute("type", "click")
    return proxy
end

-- Aims all three out of combat, or clears all three so a stale pad presses nothing.
function QL.PointShare()
    if InCombatLockdown() then return nil end
    local frame, selectedID = QL.Frame(), QL.SelectedID()
    local details = QuestMapFrame and QuestMapFrame.DetailsFrame
    local share = details and details.ShareButton
    local back = details and details.BackFrame and details.BackFrame.BackButton
    local row = share and back and selectedID and frame.share:IsVisible() and frame.share:IsEnabled() and MapRow(selectedID)
    if not row and not shareProxies then return nil end
    shareProxies = shareProxies or { ShareProxy(SHARE_ROW), ShareProxy(SHARE_MAP), ShareProxy(SHARE_BACK) }
    ns.SetAttributeIf(shareProxies[1], "clickbutton", row or nil)
    ns.SetAttributeIf(shareProxies[2], "clickbutton", row and share or nil)
    ns.SetAttributeIf(shareProxies[3], "clickbutton", row and back or nil)
    return row
end

-- Called by the pad's placer; nil hides the pad so our own click explains.
function QL.ShareMacro()
    return QL.PointShare() and SHARE_MACRO or nil
end

-- A window pad (one with after) hides as combat starts, so a log shut mid-fight leaves none behind.
function QL.SharePadAfter() end

-- Reached only with the pad away: in combat, the map open, or no map row to press.
function QL.ShareClick()
    local selectedID = QL.SelectedID()
    local info = selectedID and QL.QuestInLog(selectedID)
    if not info then return end
    if not IsInGroup() then
        UIErrorsFrame:AddMessage("You are not in a party.", 1, 0.1, 0.1)
        return
    end
    if InCombatLockdown() then
        ns.SayNotInCombat()
    elseif WorldMapFrame and WorldMapFrame:IsShown() then
        -- Our log shares only with the map shut (both stay up only when opened in combat).
        UIErrorsFrame:AddMessage("Close the world map, then share again.", 1, 0.1, 0.1)
    elseif not MapRow(selectedID) then
        -- Rows are built only on an open map, under open headers; opening it also shuts a list left open.
        UIErrorsFrame:AddMessage("Open the world map, then share again.", 1, 0.1, 0.1)
    end
end
