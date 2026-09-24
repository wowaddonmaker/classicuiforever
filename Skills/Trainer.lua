local _, ns = ...

-- Trainer window as the old one, on the skill shell: greeting under the title,
-- All tab and filter, services under headers (green learnable, red not yet,
-- grey known), the chosen one below with needs and cost, money, Train and Exit
-- at the foot. The client window stays the host; its list, filter, button and
-- money are hidden under ours. Only the trainer functions are called.

local active = false
local panel
local LIST_ROWS = 9
local lines, collapsed = {}, {}
local selected

local SkillList = ns.SkillList
local SetAlphaIf, SetScaleIf, SetLevelIf, SetPointIf = ns.SetAlphaIf, ns.SetScaleIf, ns.SetLevelIf, ns.SetPointIf
local IsSecret = ns.IsSecret

local KIND_COLOR = {
    available = { 0.1, 1, 0.1 },
    unavailable = { 1, 0.1, 0.1 },
    used = { 0.5, 0.5, 0.5 },
}

-- The client's own pieces that ours stands in for.
local CLIENT_PIECES = { "FilterDropdown", "FilterInputHint", "TrainButton", "trainingPoints", "skillStepButton",
    "bottomInset", "BG", "Inset" }
local CLIENT_SHRUNK = { "ScrollBox", "ScrollBar" }
local FOOT_EDGE = { "TopEdge", "TopLeftCorner", "TopRightCorner" }
local TRAINER_EVENTS = { "TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED", "TRAINER_DESCRIPTION_UPDATE",
    "TRAINER_SERVICE_INFO_NAME_UPDATE", "PLAYER_MONEY" }

local function Services()
    local count = GetNumTrainerServices and GetNumTrainerServices() or 0
    local order, groups = {}, {}
    for index = 1, count do
        local name, kind, texture, level, sub, category = GetTrainerServiceInfo(index)
        if name then
            if not category or category == "" then category = OTHER or "Other" end
            if not groups[category] then
                groups[category] = {}
                order[#order + 1] = category
            end
            local group = groups[category]
            group[#group + 1] = { index = index, name = name, kind = kind, texture = texture, level = level, sub = sub }
        end
    end
    return order, groups
end

local function Collect()
    wipe(lines)
    local order, groups = Services()
    for _, category in ipairs(order) do
        lines[#lines + 1] = { header = true, id = category, name = category }
        if not collapsed[category] then
            for _, service in ipairs(groups[category]) do lines[#lines + 1] = service end
        end
    end
end

local function ServiceByIndex(index)
    for _, line in ipairs(lines) do
        if not line.header and line.index == index then return line end
    end
end

local UpdateDetail

-- Scroll column only when the list overflows, as the old window; else the pane
-- reaches the right edge.
local function FitList()
    local over = math.max(0, #lines - LIST_ROWS)
    panel.bar:SetRange(over)
    panel.listBox:SetPoint("RIGHT", panel, "RIGHT", over > 0 and panel.listRight or 0, 0)
end

local function DrawItem(row, line)
    row.toggle:Hide()
    row.text:SetPoint("LEFT", row, "LEFT", 33, 0)
    local label = line.name
    if line.sub and line.sub ~= "" then label = label .. " (" .. line.sub .. ")" end
    row.text:SetText(label)
    local color = KIND_COLOR[line.kind] or KIND_COLOR.used
    if line.index == selected then
        row.selectedTex:SetVertexColor(unpack(color))
        row.selectedTex:Show()
        row.text:SetTextColor(1, 1, 1)
    else
        row.selectedTex:Hide()
        row.text:SetTextColor(unpack(color))
    end
end

local function UpdateRows()
    if not panel then return end
    SkillList.Draw(panel, lines, collapsed, DrawItem)
    SkillList.FoldIcon(panel, lines, collapsed)
end

local function Select(index)
    selected = index
    if index and SelectTrainerService then pcall(SelectTrainerService, index) end
    UpdateRows()
    UpdateDetail()
end

local function Row_OnClick(self)
    local line = self.line
    if not line then return end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    if line.header then
        collapsed[line.id] = (not collapsed[line.id]) or nil
        -- All of it again: a folded header can take the chosen service with it.
        panel.refresh()
    else
        Select(line.index)
    end
end

local function CreateRow(parent, index)
    return ns.SkillListRow(parent, index, Row_OnClick)
end

-- Coins with their pictures; the old global is gone from this client.
local function Coins(amount)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then return C_CurrencyInfo.GetCoinTextureString(amount) end
    if GetCoinTextureString then return GetCoinTextureString(amount) end
    if GetMoneyString then return GetMoneyString(amount) end
    return tostring(amount)
end

local WHITE, RED = "|cffffffff", "|cffff2020"

-- The client's wording without its own colours.
local function Plain(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Old style: white text, only the number red while unmet ("Mining (50)", the 50 red).
local function AddNeed(parts, text, met)
    text = Plain(text)
    if not met then
        text = text:gsub("(%d+)", RED .. "%1|r" .. WHITE, 1)
    end
    parts[#parts + 1] = WHITE .. text .. "|r"
end

-- What a service needs, the unmet parts in red.
local function Requirements(line)
    local parts = {}
    if line.level and line.level > 1 then
        AddNeed(parts, string.format(TRAINER_REQ_LEVEL or "Level %d", line.level), (UnitLevel("player") or 0) >= line.level)
    end
    if GetTrainerServiceSkillReq then
        local ok, skill, rank, has = pcall(GetTrainerServiceSkillReq, line.index)
        if ok and skill and rank and rank > 0 then
            AddNeed(parts, string.format(TRAINER_REQ_SKILL_RANK or "%s (%d)", skill, rank), has and true or false)
        end
    end
    if GetTrainerServiceNumAbilityReq and GetTrainerServiceAbilityReq then
        local okCount, count = pcall(GetTrainerServiceNumAbilityReq, line.index)
        for i = 1, (okCount and count or 0) do
            local ok, ability, has = pcall(GetTrainerServiceAbilityReq, line.index, i)
            -- A spell needed first has no number to mark: all of it.
            if ok and ability then
                parts[#parts + 1] = ((has and WHITE) or RED) .. Plain(ability) .. "|r"
            end
        end
    end
    return table.concat(parts, ", ")
end

UpdateDetail = function()
    if not panel then return end
    local detail = panel.detail
    local line = selected and ServiceByIndex(selected)
    local money = GetMoney and GetMoney() or 0
    if not line then
        detail.iconButton:Hide()
        detail.name:SetText("")
        detail.sub:SetText("")
        detail.requires:SetText("")
        detail.cost:SetText("")
        detail.text:SetText("")
        panel.train:Disable()
        return
    end
    detail.iconButton:Show()
    detail.icon:SetTexture(line.texture)
    detail.name:SetText(line.name)
    detail.sub:SetText((line.sub and line.sub ~= "") and ("(" .. line.sub .. ")") or "")
    local needs = Requirements(line)
    detail.requires:SetText(needs ~= "" and ((REQUIRES_LABEL or "Requires:") .. " " .. needs) or "")
    local cost = 0
    if GetTrainerServiceCost then
        local ok, value = pcall(GetTrainerServiceCost, line.index)
        if ok and type(value) == "number" then cost = value end
    end
    if cost > 0 then
        local coins = Coins(cost)
        detail.cost:SetText((COSTS_LABEL or "Cost:") .. " " .. (cost > money and "|cffff2020" or "|cffffffff") .. coins .. "|r")
    else
        detail.cost:SetText("")
    end
    local words = ""
    if GetTrainerServiceDescription then
        local ok, text = pcall(GetTrainerServiceDescription, line.index)
        if ok and type(text) == "string" then words = text end
    end
    detail.text:SetText(words)
    panel.train:SetEnabled(line.kind == "available" and cost <= money)
end

local function Refresh()
    if not panel or not active then return end
    Collect()
    FitList()
    -- Keep the selection while listed; else the first learnable, as the old window
    -- opened, else the first.
    if not (selected and ServiceByIndex(selected)) then
        selected = nil
        for _, line in ipairs(lines) do
            if not line.header and line.kind == "available" then selected = line.index break end
        end
        if not selected then
            for _, line in ipairs(lines) do
                if not line.header then selected = line.index break end
            end
        end
        if selected and SelectTrainerService then pcall(SelectTrainerService, selected) end
    end
    local greeting = GetTrainerGreetingText and GetTrainerGreetingText() or ""
    panel.greeting:SetText(greeting or "")
    UpdateRows()
    UpdateDetail()
end

local function SetWidthIf(region, width)
    local current = region:GetWidth()
    if not IsSecret(current) and not IsSecret(width) and current == width then return end
    region:SetWidth(width)
end

local moneyBg
local function HideClientPieces(hide)
    local host = ClassTrainerFrame
    if not host then return end
    local alpha = hide and 0 or 1
    for _, key in ipairs(CLIENT_PIECES) do
        local piece = host[key]
        if piece and piece.SetAlpha then SetAlphaIf(piece, alpha) end
    end
    -- The client's rank bar, by name only; the old window had none.
    if ClassTrainerStatusBar then SetAlphaIf(ClassTrainerStatusBar, alpha) end
    -- Our skin's inset floor showed as an empty bar between the tab and the filter.
    local floor = host.fcui and host.fcui.insetFloor
    if floor then SetAlphaIf(floor, alpha) end
    -- The client's money oval and money stay, six higher, where the foot border has room.
    moneyBg = moneyBg or _G["ClassTrainerFrameMoneyBg"]
    local oval = moneyBg
    if oval then
        SetPointIf(oval, "BOTTOMLEFT", host, "BOTTOMLEFT", hide and 4 or 5, hide and -3 or -9)
        SetAlphaIf(oval, alpha)
        if hide and panel and panel.oval then
            local width = panel.oval:GetWidth()
            if width and width > 0 then SetWidthIf(oval, width) end
        elseif not hide then
            SetWidthIf(oval, 148)
        end
    end
    -- The client's money over our page, which is drawn above it.
    if host.money and panel then
        SetLevelIf(host.money, panel:GetFrameLevel() + (hide and 8 or 0))
    end
    -- The client list and bar sit above ours and relayout on every update: shrink, not move.
    for _, key in ipairs(CLIENT_SHRUNK) do
        local piece = host[key]
        if piece and piece.SetScale then
            SetScaleIf(piece, hide and 0.01 or 1)
            SetAlphaIf(piece, alpha)
        end
    end
end

local function Service_OnEnter(self)
    if not selected or not GameTooltip.SetTrainerService then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    pcall(GameTooltip.SetTrainerService, GameTooltip, selected)
    GameTooltip:Show()
end

local function Build()
    local host = ClassTrainerFrame
    if panel or not host then return panel end
    panel = ns.ShellPage("ClassicUIForeverTrainer", host)
    panel:EnableMouse(true)

    -- Greeting on its own frame above the stone, which cut off its second line.
    local words = CreateFrame("Frame", nil, panel)
    words:SetAllPoints(panel)
    words:SetFrameLevel(panel:GetFrameLevel() + 3)
    panel.greeting = words:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    panel.greeting:SetPoint("TOPLEFT", panel, "TOPLEFT", 72, -30)
    panel.greeting:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
    panel.greeting:SetHeight(36)
    panel.greeting:SetJustifyH("LEFT")
    panel.greeting:SetJustifyV("TOP")

    ns.OldSkillShell(panel, { rows = LIST_ROWS, createRow = CreateRow, onScroll = UpdateRows })
    -- Stone from the title band to the list's strip: bare, the darker backing read
    -- as a bar from the tab to the filter.
    local gap = CreateFrame("Frame", nil, panel)
    gap:SetFrameLevel(panel:GetFrameLevel() + 1)
    gap:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -50)
    gap:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
    gap:SetPoint("BOTTOM", panel.listBox, "TOP", 0, -8)
    local gapStone = gap:CreateTexture(nil, "BACKGROUND")
    gapStone:SetAllPoints(gap)
    ns.TileTex(gapStone, "rockBg")
    panel.collapseAll:SetScript("OnClick", function()
        SkillList.FoldAll(lines, collapsed)
        panel.refresh()
    end)
    panel.filter:SetScript("OnClick", function(self)
        if not panel.filterList then
            local function Item(label, kind)
                return { label, function()
                    local on = GetTrainerServiceTypeFilter and GetTrainerServiceTypeFilter(kind)
                    if SetTrainerServiceTypeFilter then SetTrainerServiceTypeFilter(kind, not on) end
                    Refresh()
                end, function() return GetTrainerServiceTypeFilter and GetTrainerServiceTypeFilter(kind) and true or false end }
            end
            panel.filterList = ns.DropList({
                Item(AVAILABLE or "Available", "available"),
                Item(UNAVAILABLE or "Unavailable", "unavailable"),
                Item(USED or "Already Known", "used"),
            })
            panel.filterList:Follow(panel)
        end
        panel.filterList:Toggle(self)
    end)

    -- The chosen service.
    local detail = panel.detail
    detail.iconButton = ns.ShellDetailHeader(detail, Service_OnEnter)
    detail.sub = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail.sub:SetPoint("LEFT", detail.name, "RIGHT", 4, 0)
    detail.cost = detail:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    detail.cost:SetPoint("TOPLEFT", detail, "TOPLEFT", 21, -62)
    detail.cost:SetJustifyH("LEFT")
    detail.text = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail.text:SetPoint("TOPLEFT", detail.cost, "BOTTOMLEFT", 0, -6)
    detail.text:SetPoint("RIGHT", detail, "RIGHT", -16, 0)
    detail.text:SetJustifyH("LEFT")
    detail.text:SetJustifyV("TOP")

    -- The foot: money in its own thin border, Train, Exit.
    local exit = ns.ShellExitButton(panel, "ClassTrainerFrame", 84)
    local train = ns.PanelButton(panel, TRAIN or "Train", 84)
    train:SetPoint("RIGHT", exit, "LEFT", -3, 0)
    train:SetScript("OnClick", function()
        if selected and BuyTrainerService then BuyTrainerService(selected) end
    end)
    panel.train = train
    -- The money's border, clear of its oval all the way round.
    local moneyBox = ns.SkillInsetBox(panel, 16, true)
    moneyBox:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 1, 4)
    moneyBox:SetPoint("RIGHT", train, "LEFT", 1, 0)
    moneyBox:SetHeight(32)
    -- Train and Exit in the same thin border, as tall as the money's and level with it.
    for _, button in ipairs({ train, exit }) do
        local box = ns.SkillInsetBox(panel, 16, true)
        box:SetPoint("TOP", moneyBox, "TOP", 0, 0)
        box:SetPoint("BOTTOM", moneyBox, "BOTTOM", 0, 0)
        box:SetPoint("LEFT", button, "LEFT", -4, 0)
        box:SetPoint("RIGHT", button, "RIGHT", 4, 0)
        box:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
    end
    -- Our own gold oval: the client's lies under the window's silver and came out
    -- dull. It stays unseen, as wide as ours, for its money to hang from.
    local oval = panel:CreateTexture(nil, "ARTWORK")
    oval:SetTexture("Interface\\MoneyFrame\\UI-MoneyFrame-Border")
    oval:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 4, -3)
    oval:SetPoint("RIGHT", train, "LEFT", -5, 0)
    oval:SetHeight(34)
    panel.oval = oval
    -- The detail pane's bottom edge runs under the foot's top one; side by side they read double.
    panel.detailBox:ClearAllPoints()
    panel.detailBox:SetPoint("TOPLEFT", panel.listBox, "BOTTOMLEFT", 0, 12)
    panel.detailBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 25)
    panel.footBox:ClearAllPoints()
    panel.footBox:SetPoint("TOPLEFT", panel.detailBox, "BOTTOMLEFT", 0, 11)
    panel.footBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 1, 2)
    panel.footBox:SetFrameLevel(panel.detailBox:GetFrameLevel() + 1)
    -- The foot keeps its sides and bottom; its top edge drew a double line.
    ns.FadeKeys(panel.footBox, FOOT_EDGE)

    panel.bar.hideWhenIdle = true
    panel.refresh = Refresh
    -- Re-hide client pieces at 5 Hz while up: some appear after opening (the inset
    -- floor showed as a dark bar beside the tab).
    panel:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 0.2 then return end
        self.since = 0
        if active then HideClientPieces(true) end
    end)
    panel:SetScript("OnShow", Refresh)
    return panel
end

local function Open()
    if not active or not ClassTrainerFrame then return end
    Build()
    HideClientPieces(true)
    -- A Show that makes the page visible has run Refresh through OnShow.
    local wasShown = panel:IsShown()
    panel:Show()
    if wasShown or not panel:IsVisible() then Refresh() end
end

-- Trainer events come in bursts: one Open in this frame's pass.
local openWanted = false
local function OpenNow()
    if not openWanted then return end
    openWanted = false
    Open()
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if not active then return end
    if event == "TRAINER_CLOSED" or event == "PLAYER_MONEY" then
        -- A pending Open lands first, as when it ran at once.
        OpenNow()
        if event == "TRAINER_CLOSED" then
            selected = nil
        elseif panel and panel:IsVisible() then
            UpdateDetail()
        end
        return
    end
    openWanted = true
    ns.Sched.Soon("trainer.open", OpenNow)
end)

local function Apply()
    active = true
    ns.RegisterEvents(events, TRAINER_EVENTS)
    if ClassTrainerFrame and ClassTrainerFrame:IsShown() then Open() end
end

local function Restore()
    active = false
    events:UnregisterAllEvents()
    if panel then panel:Hide() end
    HideClientPieces(false)
end

ns.RegisterModule("trainer", { apply = Apply, restore = Restore })
