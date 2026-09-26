local _, ns = ...

-- Micro button, quest log key and tracker clicks open our log instead of the map's quest panel.

local QL = ns.QL

local BIND_NAME = "ForeverClassicUIQuestLogBind"   -- clicked by name via the override binding
local TRACKERS = { "QuestObjectiveTracker", "CampaignQuestObjectiveTracker" }

local bindButton
local originalMicroClick
-- The key and the micro button drop the spellbook's casting layer first (secure; our code cannot in a fight), else the
-- book, hidden under the log by the one-window rule, comes back over it.
local DROP_LAYER = "/click ForeverClassicUISpellBookLayerOff"

-- Override binding for the quest log key: out of combat only, first key only.
local function UpdateBinding()
    if not bindButton or InCombatLockdown() then return end
    ClearOverrideBindings(bindButton)
    if not QL.active then return end
    local key = GetBindingKey("TOGGLEQUESTLOG")
    if key then SetOverrideBindingClick(bindButton, true, key, BIND_NAME, "LeftButton") end
end

local function BindClick(_, _, down)
    if not down and QL.active then ns.ToggleQuestLog() end
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
    bindButton:RegisterForClicks("AnyDown", "AnyUp")
    bindButton:SetAttribute("useOnKeyDown", false)
    bindButton:SetAttribute("type", "macro")
    bindButton:SetAttribute("macrotext", DROP_LAYER)
    bindButton:SetScript("PostClick", BindClick)
    -- Opened in a fight: the key's and the pad's secure click bind Escape to ours (UI/Escape.lua). The events live on
    -- a side frame: a frame with registrations can be refused by the secure environment.
    if ns.EscArmOnClick then ns.EscArmOnClick(bindButton, "questlog") end
    if QuestLogMicroButton and ns.MapPad then
        local pad = ns.MapPad(QuestLogMicroButton, nil, MicroClick, DROP_LAYER, function() return QL.active end)
        if pad and ns.EscArmOnClick then ns.EscArmOnClick(pad, "questlog") end
    end
    ns.EventFrame({ "UPDATE_BINDINGS", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }, UpdateBinding)
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
    -- The button's own click opens the map's quest panel: ours stands in wherever the pad is not over it (a fight
    -- moves the micro row and the pad cannot follow there).
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
    -- Our own window, nothing protected in it: the toggle answers in a fight.
    inFight = true,
    apply = function() ns.QuestLogSetDual(true) end,
    restore = function() ns.QuestLogSetDual(false) end,
})
