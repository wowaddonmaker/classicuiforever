local _, ns = ...

-- Micro button, quest log key and tracker clicks open our log instead of the map's quest panel.

local QL = ns.QL

local BIND_NAME = "ForeverClassicUIQuestLogBind"   -- clicked by name via the override binding
local TRACKERS = { "QuestObjectiveTracker", "CampaignQuestObjectiveTracker" }

local bindButton
local originalMicroClick

-- Override binding for the quest log key: out of combat only, first key only.
local function UpdateBinding()
    if not bindButton or InCombatLockdown() then return end
    ClearOverrideBindings(bindButton)
    if not QL.active then return end
    local key = GetBindingKey("TOGGLEQUESTLOG")
    if key then SetOverrideBindingClick(bindButton, true, key, BIND_NAME, "LeftButton") end
end

local function BindClick()
    if QL.active then ns.ToggleQuestLog() end
end

-- Inside the client's click pass: add no work; hide the map, never toggle it.
local function TrackerHeaderClick(_, block, button)
    if not QL.active or button == "RightButton" then return end
    if IsModifiedClick("CHATLINK") or IsModifiedClick("QUESTWATCHTOGGLE") then return end
    if WorldMapFrame and WorldMapFrame:IsShown() then HideUIPanel(WorldMapFrame) end
    ns.ShowQuestLog(block and block.id)
end

local function MicroClick()
    ns.ToggleQuestLog()
end

-- Runs at login with the module on or off; handlers check QL.active.
local hooked = false
local function Init()
    if hooked then return end
    hooked = true
    bindButton = CreateFrame("Button", BIND_NAME, UIParent, "SecureActionButtonTemplate")
    bindButton:SetScript("OnClick", BindClick)
    bindButton:RegisterEvent("UPDATE_BINDINGS")
    bindButton:RegisterEvent("PLAYER_REGEN_ENABLED")
    bindButton:RegisterEvent("PLAYER_ENTERING_WORLD")
    bindButton:SetScript("OnEvent", UpdateBinding)
    -- Tracker quest headers open our log, not the map.
    for _, name in ipairs(TRACKERS) do
        local tracker = _G[name]
        if tracker then ns.HookMethod(tracker, "OnBlockHeaderClick", TrackerHeaderClick) end
    end
    -- Escape is handled in QuestLogWindow's Build.
    ns.CloseWithGameMenu(QL.Frame, ns.HideQuestLog)
end

local function Apply()
    QL.active = true
    if QuestLogMicroButton then
        if not originalMicroClick then originalMicroClick = QuestLogMicroButton:GetScript("OnClick") end
        QuestLogMicroButton:SetScript("OnClick", MicroClick)
    end
    UpdateBinding()
end

local function Restore()
    QL.active = false
    ns.HideQuestLog()
    if QuestLogMicroButton and originalMicroClick then
        QuestLogMicroButton:SetScript("OnClick", originalMicroClick)
        originalMicroClick = nil
    end
    UpdateBinding()
end

ns.RegisterModule("questLog", { init = Init, apply = Apply, restore = Restore })
-- Same window, other shape; must register after questLog.
ns.RegisterModule("questLogDual", {
    apply = function() ns.QuestLogSetDual(true) end,
    restore = function() ns.QuestLogSetDual(false) end,
})
