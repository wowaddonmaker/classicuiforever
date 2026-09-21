local _, ns = ...

-- The talent window as the old one: one tree at a time on its old
-- background, the trees on tabs along the foot, the talents on the old
-- grid with their rank plates and the arrows between them, the points
-- spent in the tree across the top and the points left along the foot.
--
-- This client's talents are not the old talents underneath. They are one
-- tree of the modern kind with three groups in it, every talent a node
-- with a place, ranks and the nodes it opens. The window is drawn from
-- that, whatever talents the tree holds, so a talent this client has
-- added or moved stands where the client has it. Points are staged and
-- then committed by the client's own rules: a click stages a point, and
-- Learn commits what is staged, as the old preview mode worked.
--
-- A window of our own, as the spellbook is: never the client's, so it
-- opens and shuts in a fight. The client's talents window is not touched.

local active = false
local frame
local selectedTab = 1
-- Whose talents: nil for the player's own, or the unit being inspected,
-- whose tree the client keeps under a config number of its own and which
-- is only looked at.
local inspectUnit
local buttons, branchPool, arrowPool = {}, {}, {}

local WINDOW_W, WINDOW_H = 384, 512
local VIEW_X, VIEW_Y, VIEW_W, VIEW_H = 22, -77, 296, 332
local BUTTON, START_X, START_Y, PITCH = 37, 35, 20, 63
local ART = "Interface\\TalentFrame\\"
local BRANCHES, ARROWS = ART .. "UI-TalentBranches", ART .. "UI-TalentArrows"

-- The old backgrounds, by class and by the tree's place in the row.
local BACKGROUNDS = {
    DRUID = { "DruidBalance", "DruidFeralCombat", "DruidRestoration" },
    HUNTER = { "HunterBeastMastery", "HunterMarksmanship", "HunterSurvival" },
    MAGE = { "MageArcane", "MageFire", "MageFrost" },
    PALADIN = { "PaladinHoly", "PaladinProtection", "PaladinCombat" },
    PRIEST = { "PriestDiscipline", "PriestHoly", "PriestShadow" },
    ROGUE = { "RogueAssassination", "RogueCombat", "RogueSubtlety" },
    SHAMAN = { "ShamanElementalCombat", "ShamanEnhancement", "ShamanRestoration" },
    WARLOCK = { "WarlockCurses", "WarlockSummoning", "WarlockDestruction" },
    WARRIOR = { "WarriorArms", "WarriorFury", "WarriorProtection" },
}

-- The branch sheet: a lit row of pieces over a gray one.
local BRANCH = {
    vertical = { [true] = { 0, 0.125, 0, 0.484375 }, [false] = { 0, 0.125, 0.515625, 1 } },
    horizontal = { [true] = { 0.2578125, 0.3828125, 0, 0.5 }, [false] = { 0.2578125, 0.3828125, 0.5, 1 } },
}
local ARROW = {
    down = { [true] = { 0, 0.5, 0, 0.5 }, [false] = { 0, 0.5, 0.5, 1 } },
    right = { [true] = { 1, 0.5, 0, 0.5 }, [false] = { 1, 0.5, 0.5, 1 } },
    left = { [true] = { 0.5, 1, 0, 0.5 }, [false] = { 0.5, 1, 0.5, 1 } },
}

---------------------------------------------------------------- the tree

local function ConfigID()
    if inspectUnit then
        return Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID or -1
    end
    local spec = C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup and C_SpecializationInfo.GetActiveSpecGroup()
    local id = spec and C_SpecializationInfo.GetCombatConfigIDForSpecGroup and C_SpecializationInfo.GetCombatConfigIDForSpecGroup(spec)
    if not id and C_ClassTalents and C_ClassTalents.GetActiveConfigID then id = C_ClassTalents.GetActiveConfigID() end
    return id
end

-- The tree read into three lists of talents on a grid.
local function ReadTree()
    local configID = ConfigID()
    if not configID or not C_Traits then return nil end
    local config = C_Traits.GetConfigInfo(configID)
    local treeID = config and config.treeIDs and config.treeIDs[1]
    if not treeID then return nil end
    local tree = { configID = configID, treeID = treeID, tabs = {}, points = 0 }
    local okGroups, groups = pcall(C_Traits.GetGroupDisplayInfoByTreeID, treeID)
    if not okGroups or type(groups) ~= "table" then return nil end
    table.sort(groups, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
    local byGroup, groupIDs = {}, {}
    for i, info in ipairs(groups) do
        local tab = { index = i, groupID = info.groupID, name = info.displayName or "", icon = info.icon, nodes = {}, spent = 0 }
        tree.tabs[i] = tab
        byGroup[info.groupID] = tab
        groupIDs[#groupIDs + 1] = info.groupID
    end
    local okSpent, spentInfos = pcall(C_Traits.GetGroupCurrencyInfo, configID, groupIDs)
    for _, info in ipairs(okSpent and spentInfos or {}) do
        local tab = byGroup[info.traitNodeGroupID]
        local currency = info.currencyInfos and info.currencyInfos[1]
        if tab and currency then tab.spent = currency.spent or 0 end
    end
    local okPoints, currencies = pcall(C_Traits.GetTreeCurrencyInfo, configID, treeID, false)
    local currency = okPoints and currencies and currencies[1]
    if currency then tree.points = currency.quantity or 0 end

    local nodesByID = {}
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
        local node = C_Traits.GetNodeInfo(configID, nodeID)
        if node and node.isVisible ~= false and node.posX then
            local tab
            for _, groupID in ipairs(node.groupIDs or {}) do
                if byGroup[groupID] then tab = byGroup[groupID] break end
            end
            if tab then
                local entryID = node.activeEntry and node.activeEntry.entryID or (node.entryIDs and node.entryIDs[1])
                local entry = entryID and C_Traits.GetEntryInfo(configID, entryID)
                local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
                local spellID = def and (def.overriddenSpellID or def.spellID)
                local talent = {
                    nodeID = nodeID, entryID = entryID, spellID = spellID, x = node.posX, y = node.posY,
                    rank = node.ranksPurchased or 0, maxRank = node.maxRanks or 1,
                    -- The client says a rank can be bought where the tree allows
                    -- it, points or no points: with none left to spend, a talent
                    -- nothing had been put into stood lit green as if one could be.
                    canBuy = node.canPurchaseRank and tree.points > 0 and true or false,
                    canRefund = node.canRefundRank and true or false,
                    available = node.isAvailable and true or false, edges = node.visibleEdges or {},
                    icon = def and def.overrideIcon or (spellID and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)),
                    conditions = node.conditionIDs or {},
                }
                tab.nodes[#tab.nodes + 1] = talent
                nodesByID[nodeID] = talent
            end
        end
    end
    -- Onto the grid: the smallest step between two places is a cell, and
    -- each tree's own leftmost place is its first column.
    local topY
    for _, tab in ipairs(tree.tabs) do
        for _, talent in ipairs(tab.nodes) do
            if not topY or talent.y < topY then topY = talent.y end
        end
    end
    for _, tab in ipairs(tree.tabs) do
        local leftX
        for _, talent in ipairs(tab.nodes) do
            if not leftX or talent.x < leftX then leftX = talent.x end
        end
        tab.tiers = 0
        for _, talent in ipairs(tab.nodes) do
            talent.column = math.floor((talent.x - leftX) / 600 + 0.5)
            talent.tier = math.floor((talent.y - (topY or talent.y)) / 600 + 0.5)
            if talent.tier + 1 > tab.tiers then tab.tiers = talent.tier + 1 end
        end
    end
    tree.nodesByID = nodesByID
    tree.inspect = inspectUnit ~= nil
    tree.staged = not tree.inspect and C_Traits.ConfigHasStagedChanges and C_Traits.ConfigHasStagedChanges(configID) and true or false
    return tree
end

--------------------------------------------------------------- the pieces

local function Acquire(pool, parent, file)
    for _, tex in ipairs(pool) do
        if not tex.used then
            tex.used = true
            return tex
        end
    end
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(file)
    tex.used = true
    pool[#pool + 1] = tex
    return tex
end

local function ReleaseAll(pool)
    for _, tex in ipairs(pool) do
        tex.used = false
        tex:Hide()
    end
end

local function CellX(column) return START_X + column * PITCH end
local function CellY(tier) return -(START_Y + tier * PITCH) end

-- A run of branch between two places, and the arrow into the second.
local function DrawEdge(child, from, to, lit)
    local fx, fy, tx, ty = CellX(from.column), CellY(from.tier), CellX(to.column), CellY(to.tier)
    local half = BUTTON / 2
    local function Piece(kind, x, y, w, h)
        local tex = Acquire(branchPool, child, BRANCHES)
        tex:SetTexCoord(unpack(BRANCH[kind][lit]))
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", child, "TOPLEFT", x, y)
        tex:SetSize(w, h)
        tex:Show()
    end
    local function Arrow(kind, x, y)
        local tex = Acquire(arrowPool, frame.arrows, ARROWS)
        tex:SetTexCoord(unpack(ARROW[kind][lit]))
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", child, "TOPLEFT", x, y)
        tex:SetSize(32, 32)
        tex:Show()
    end
    if from.tier == to.tier then
        -- Along the row.
        local right = to.column > from.column
        local x1 = (right and fx + BUTTON or tx + BUTTON) - 2
        local x2 = (right and tx or fx) + 2
        Piece("horizontal", x1, fy - half + 16, math.max(1, x2 - x1), 32)
        Arrow(right and "right" or "left", right and (tx - 20) or (tx + BUTTON - 12), ty - half + 16)
    else
        -- Across first, where the columns differ, then down.
        if from.column ~= to.column then
            local right = to.column > from.column
            local x1 = right and (fx + BUTTON - 2) or (tx + half - 16)
            local x2 = right and (tx + half + 16) or (fx + 2)
            Piece("horizontal", x1, fy - half + 16, math.max(1, x2 - x1), 32)
            Piece("vertical", tx + half - 16, fy - half, 32, math.max(1, (fy - half) - ty - 2))
        else
            Piece("vertical", tx + half - 16, fy - BUTTON + 2, 32, math.max(1, (fy - BUTTON) - ty + 4))
        end
        Arrow("down", tx + half - 16, ty + 20)
    end
end

-- The old tooltip: the talent's name, its rank, what it still needs in
-- red (points in the tree, points in the talent it hangs from), what the
-- rank held does, and under "Next rank" what one more would do.
-- The talent's own words are asked for and written in as plain lines. Handed
-- to the tooltip as a piece of the client's tooltip data instead, they came
-- with a catch: the client redraws a tooltip from its data alone whenever
-- that data is refreshed, and a moment after the tooltip came up it was
-- drawn again as that one piece, the name, rank and requirements gone.
local function AddDescription(entryID, rank)
    if not (entryID and C_TooltipInfo and C_TooltipInfo.GetTraitEntry) then return false end
    local ok, data = pcall(C_TooltipInfo.GetTraitEntry, entryID, rank)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return false end
    for _, line in ipairs(data.lines) do
        local text, right = line.leftText, line.rightText
        if type(text) == "string" and text ~= "" and not (issecretvalue and issecretvalue(text)) then
            local color = line.leftColor
            local r, g, b = color and color.r or 1, color and color.g or 0.82, color and color.b or 0
            if type(right) == "string" and right ~= "" and not (issecretvalue and issecretvalue(right)) then
                -- A line in two halves: "Instant" and "3 min cooldown".
                local other = line.rightColor
                GameTooltip:AddDoubleLine(text, right, r, g, b, other and other.r or 1, other and other.g or 1, other and other.b or 1)
            else
                GameTooltip:AddLine(text, r, g, b, line.wrapText ~= false)
            end
        end
    end
    return true
end

local function Button_OnEnter(self)
    local talent = self.talent
    local tree = frame and frame.tree
    if not talent or not tree then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local name = talent.spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(talent.spellID)
    if frame then frame.hovered = self end
    if not name or not (C_TooltipInfo and C_TooltipInfo.GetTraitEntry) then
        -- A client without the talent text: the spell's own tooltip.
        if talent.spellID and GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(talent.spellID) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format(TOOLTIP_TALENT_RANK or "Rank %d/%d", talent.rank, talent.maxRank), 1, 1, 1)
    else
        GameTooltip:SetText(name, 1, 1, 1)
        GameTooltip:AddLine(string.format(TOOLTIP_TALENT_RANK or "Rank %d/%d", talent.rank, talent.maxRank), 1, 1, 1)
        -- What it still needs. Points in the tree first.
        local tab = tree.tabs[selectedTab]
        for _, condID in ipairs(talent.conditions) do
            local ok, cond = pcall(C_Traits.GetConditionInfo, tree.configID, condID)
            if ok and cond and cond.isGate and not cond.isMet and cond.spentAmountRequired then
                GameTooltip:AddLine(string.format(TOOLTIP_TALENT_TIER_POINTS or "Requires %d points in %s Talents",
                    cond.spentAmountRequired, tab and tab.name or ""), 1, 0.1, 0.1, true)
            end
        end
        -- Then the talent it hangs from, which has to be full.
        for _, other in pairs(tree.nodesByID) do
            for _, edge in ipairs(other.edges) do
                if edge.targetNode == talent.nodeID and edge.type ~= 0 and other.rank < other.maxRank then
                    local otherName = other.spellID and C_Spell.GetSpellName(other.spellID) or "?"
                    local format = TOOLTIP_TALENT_PREREQ or (other.maxRank == 1 and "Requires %d point in %s" or "Requires %d points in %s")
                    GameTooltip:AddLine(string.format(format, other.maxRank, otherName), 1, 0.1, 0.1, true)
                end
            end
        end
        AddDescription(talent.entryID, math.max(talent.rank, 1))
        if talent.rank > 0 and talent.rank < talent.maxRank then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(TOOLTIP_TALENT_NEXT_RANK or "Next rank:", 1, 1, 1)
            AddDescription(talent.entryID, talent.rank + 1)
        end
    end
    if talent.canBuy and not inspectUnit then
        GameTooltip:AddLine(TOOLTIP_TALENT_LEARN or "Click to learn", 0.1, 1, 0.1)
    end
    GameTooltip:Show()
end

local Refresh

local function Button_OnClick(self, mouse)
    local talent, tree = self.talent, frame.tree
    if not talent or not tree or tree.inspect or InCombatLockdown() then return end
    if mouse == "RightButton" then
        if talent.canRefund then pcall(C_Traits.RefundRank, tree.configID, talent.nodeID) end
    elseif talent.canBuy then
        pcall(C_Traits.PurchaseRank, tree.configID, talent.nodeID)
    end
    Refresh()
    if GameTooltip:IsOwned(self) then Button_OnEnter(self) end
end

local function TalentButton(child, index)
    local button = buttons[index]
    if button then return button end
    button = CreateFrame("Button", nil, child)
    button:SetSize(BUTTON, BUTTON)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button.icon = button:CreateTexture(nil, "BORDER")
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    -- Under the icon, as the old button had it: the slot is a filled
    -- square, and laid over the icon it hid every one of them. Only its
    -- edge shows round the icon, in the talent's color.
    button.slot = button:CreateTexture(nil, "BACKGROUND")
    button.slot:SetTexture("Interface\\Buttons\\UI-EmptySlot-White")
    button.slot:SetSize(64, 64)
    button.slot:SetPoint("CENTER", button, "CENTER", 0, -1)
    button.rankBorder = button:CreateTexture(nil, "OVERLAY")
    button.rankBorder:SetTexture(ART .. "TalentFrame-RankBorder")
    button.rankBorder:SetSize(32, 32)
    button.rankBorder:SetPoint("CENTER", button, "BOTTOMRIGHT", -2, 2)
    button.rankText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.rankText:SetPoint("CENTER", button.rankBorder, "CENTER", 0, 0)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints(button.icon)
    button:SetScript("OnEnter", Button_OnEnter)
    button:SetScript("OnLeave", function(self)
        if frame and frame.hovered == self then frame.hovered = nil end
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", Button_OnClick)
    buttons[index] = button
    return button
end

-- A foot tab of our own make, in the old tab art. The client's tab
-- template was tried first: it sizes and places its tabs itself every
-- time one is picked, so ours were cut short to "B..." and moved about
-- under the window. Nothing but this file touches these.
local function FootTab(parent)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetHeight(32)
    local function Set(key, coords, height, y)
        local left, right, middle = tab:CreateTexture(nil, "BACKGROUND"), tab:CreateTexture(nil, "BACKGROUND"), tab:CreateTexture(nil, "BACKGROUND")
        for i, tex in ipairs({ left, right, middle }) do
            ns.SetTex(tex, key)
            tex:SetTexCoord(coords[i][1], coords[i][2], 0, coords[i][3])
            tex:SetHeight(height)
        end
        left:SetWidth(20)
        right:SetWidth(20)
        left:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, y)
        right:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 0, y)
        middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
        middle:SetPoint("TOPRIGHT", right, "TOPLEFT", 0, 0)
        return { left, right, middle }
    end
    tab.on = Set("tabActive", { { 0, 0.15625, 0.546875 }, { 0.84375, 1, 0.546875 }, { 0.15625, 0.84375, 0.546875 } }, 35, 0)
    tab.off = Set("tabInactive", { { 0, 0.15625, 1 }, { 0.84375, 1, 1 }, { 0.15625, 0.84375, 1 } }, 32, -4)
    -- Anchored by one point and never given a width, so its own width
    -- is always the whole label's.
    tab.label = tab:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    tab.label:SetPoint("CENTER", tab, "CENTER", 0, -3)
    ns.SetButtonTex(tab, "Highlight", "tabHighlight")
    local hl = tab:GetHighlightTexture()
    if hl then
        hl:SetTexCoord(0, 1, 0, 1)
        hl:ClearAllPoints()
        hl:SetPoint("TOPLEFT", tab, "TOPLEFT", 3, 5)
        hl:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -3, 0)
        hl:SetBlendMode("ADD")
    end
    function tab:Set(text, picked)
        if self.text ~= text then
            self.text = text
            self.label:SetText(text)
            self:SetWidth(math.ceil(self.label:GetStringWidth() or 0) + 40)
        end
        if self.picked ~= picked then
            self.picked = picked
            for _, tex in ipairs(self.on) do tex:SetShown(picked) end
            for _, tex in ipairs(self.off) do tex:SetShown(not picked) end
            if picked then self.label:SetTextColor(1, 1, 1) else self.label:SetTextColor(1, 0.82, 0) end
            self.label:SetPoint("CENTER", self, "CENTER", 0, picked and -5 or -3)
        end
    end
    return tab
end

----------------------------------------------------------------- the view

Refresh = function()
    if not frame or not active then return end
    local tree = ReadTree()
    frame.tree = tree
    ReleaseAll(branchPool)
    ReleaseAll(arrowPool)
    for _, button in ipairs(buttons) do button:Hide() end
    if not tree or #tree.tabs == 0 then return end
    if selectedTab > #tree.tabs then selectedTab = 1 end
    local tab = tree.tabs[selectedTab]
    local child = frame.child

    -- The tabs along the foot.
    for i, tabButton in ipairs(frame.tabs) do
        local info = tree.tabs[i]
        tabButton:SetShown(info ~= nil)
        if info then tabButton:Set(info.name, i == selectedTab) end
    end

    -- The background, pulled to the tree's length.
    local _, class = UnitClass(inspectUnit or "player")
    local name = BACKGROUNDS[class] and BACKGROUNDS[class][selectedTab]
    local height = math.max(VIEW_H, START_Y + (tab.tiers - 1) * PITCH + BUTTON + START_Y)
    child:SetSize(VIEW_W, height)
    -- The lower files are 128 tall but painted for 75 rows only, the old
    -- window's own cut; the rest of each is blank, and drawn whole it
    -- left the tree's foot bare.
    local top, bottom = height * 256 / 331, height * 75 / 331
    local art = frame.background
    for key, piece in pairs(art) do
        if name then
            piece:SetTexture(ART .. name .. "-" .. key)
            piece:Show()
        else
            piece:Hide()
        end
    end
    art.TopLeft:SetSize(256, top)
    art.TopRight:SetSize(64, top)
    art.BottomLeft:SetSize(256, bottom)
    art.BottomRight:SetSize(64, bottom)
    art.BottomLeft:SetTexCoord(0, 1, 0, 75 / 128)
    art.BottomRight:SetTexCoord(0, 1, 0, 75 / 128)

    frame.spent:SetText(string.format("Points spent in %s Talents: ", tab.name) .. "|cffffffff" .. tab.spent .. "|r")
    frame.points:SetText(tree.inspect and "" or ((TALENT_POINTS or "Talent Points") .. ": |cffffffff" .. tree.points .. "|r"))
    frame.title:SetText(tree.inspect and (UnitName(inspectUnit) or TALENTS or "Talents") or (TALENTS or "Talents"))
    frame.learn:SetEnabled(tree.staged)
    frame.reset:SetEnabled(tree.staged)
    frame.undoIcon:SetDesaturated(not tree.staged)
    frame.undoIcon:SetAlpha(tree.staged and 1 or 0.5)

    for i, talent in ipairs(tab.nodes) do
        local button = TalentButton(child, i)
        button.talent = talent
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", child, "TOPLEFT", CellX(talent.column), CellY(talent.tier))
        button.icon:SetTexture(talent.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local ranked, maxed = talent.rank > 0, talent.rank >= talent.maxRank
        if maxed or (ranked and not talent.canBuy) then
            button.icon:SetDesaturated(false)
            button.slot:SetVertexColor(1, 0.82, 0)
            button.rankText:SetTextColor(1, 0.82, 0)
        elseif talent.canBuy or ranked then
            button.icon:SetDesaturated(false)
            button.slot:SetVertexColor(0.1, 1, 0.1)
            button.rankText:SetTextColor(0.1, 1, 0.1)
        else
            button.icon:SetDesaturated(true)
            button.slot:SetVertexColor(0.5, 0.5, 0.5)
            button.rankText:SetTextColor(0.5, 0.5, 0.5)
        end
        local showRank = ranked or talent.canBuy
        button.rankBorder:SetShown(showRank)
        button.rankText:SetShown(showRank)
        button.rankText:SetText(talent.rank)
        button:Show()
    end
    -- The arrows: from a talent to each one it opens.
    for _, talent in ipairs(tab.nodes) do
        for _, edge in ipairs(talent.edges) do
            local target = tree.nodesByID[edge.targetNode]
            if target and edge.type ~= 0 and target.column and target ~= talent then
                local lit = talent.rank >= talent.maxRank
                DrawEdge(child, talent, target, lit)
            end
        end
    end

    local over = math.max(0, height - VIEW_H)
    frame.bar:SetRange(over, 20)
    frame.scroll:SetVerticalScroll(math.min(frame.bar:GetValue() or 0, over))
end

local function Build()
    if frame then return frame end
    frame = CreateFrame("Frame", "ClassicUIForeverTalents", UIParent)
    frame:SetSize(WINDOW_W, WINDOW_H)
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
    frame:Hide()
    if GameMenuFrame then
        GameMenuFrame:HookScript("OnShow", function()
            if InCombatLockdown() then return end
            if frame:IsShown() then frame:Hide() end
        end)
    end

    -- The old window's art. The talent sheet's own top pieces are gone
    -- from this client; the character window's general top is the same
    -- frame, and the talent sheet's bottom pieces are still here.
    local function Piece(key, file, w, h, point)
        local tex = frame:CreateTexture(nil, "BORDER")
        if key then ns.SetTex(tex, key) else tex:SetTexture(file) end
        tex:SetSize(w, h)
        tex:SetPoint(point, frame, point, 0, 0)
        return tex
    end
    Piece("charGeneralTopLeft", nil, 256, 256, "TOPLEFT")
    Piece("charGeneralTopRight", nil, 128, 256, "TOPRIGHT")
    Piece(nil, ART .. "UI-TalentFrame-BotLeft", 256, 256, "BOTTOMLEFT")
    Piece(nil, ART .. "UI-TalentFrame-BotRight", 128, 256, "BOTTOMRIGHT")

    local portrait = frame:CreateTexture(nil, "BACKGROUND")
    portrait:SetSize(60, 60)
    portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -6)
    frame.portrait = portrait

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("CENTER", frame, "CENTER", 6, 232)
    title:SetText(TALENTS or "Talents")
    frame.title = title

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(32, 32)
    close:SetPoint("CENTER", frame, "TOPRIGHT", -46, -24)
    ns.SkinCloseButton(close, true)
    close:SetScript("OnClick", function() frame:Hide() end)

    -- Points spent in the tree, on its dark bar under the title.
    -- A dark bar with rounded ends in a thin gray rim, as the old window's
    -- art had it, not a plain rectangle: the skill bars' rim, cut in
    -- three so its ends keep their shape at this length.
    local spentBar = CreateFrame("Frame", nil, frame)
    spentBar:SetSize(258, 13)
    spentBar:SetPoint("TOP", frame, "TOP", 12, -48)
    local spentFill = spentBar:CreateTexture(nil, "BACKGROUND")
    spentFill:SetColorTexture(0, 0, 0, 0.6)
    spentFill:SetPoint("TOPLEFT", spentBar, "TOPLEFT", 1, 0)
    spentFill:SetPoint("BOTTOMRIGHT", spentBar, "BOTTOMRIGHT", -1, 0)
    local CAP = 14
    local function Rim(left, right)
        local tex = spentBar:CreateTexture(nil, "ARTWORK")
        ns.SetTex(tex, "skillsBarBorder")
        tex:SetTexCoord(left, right, 0, 1)
        return tex
    end
    local rimL, rimR, rimM = Rim(0, CAP / 256), Rim(1 - CAP / 256, 1), Rim(CAP / 256, 1 - CAP / 256)
    rimL:SetWidth(CAP)
    rimL:SetPoint("TOPLEFT", spentBar, "TOPLEFT", -5, 5)
    rimL:SetPoint("BOTTOMLEFT", spentBar, "BOTTOMLEFT", -5, -5)
    rimR:SetWidth(CAP)
    rimR:SetPoint("TOPRIGHT", spentBar, "TOPRIGHT", 5, 5)
    rimR:SetPoint("BOTTOMRIGHT", spentBar, "BOTTOMRIGHT", 5, -5)
    rimM:SetPoint("TOPLEFT", rimL, "TOPRIGHT", 0, 0)
    rimM:SetPoint("BOTTOMRIGHT", rimR, "BOTTOMLEFT", 0, 0)
    frame.spent = spentBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.spent:SetPoint("CENTER", spentBar, "CENTER", 0, 0)

    -- The tree, in a window that scrolls.
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", VIEW_X, VIEW_Y)
    scroll:SetSize(VIEW_W, VIEW_H)
    scroll:EnableMouseWheel(true)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(VIEW_W, VIEW_H)
    scroll:SetScrollChild(child)
    frame.scroll, frame.child = scroll, child
    -- The arrows stand over the talents they point into.
    frame.arrows = CreateFrame("Frame", nil, child)
    frame.arrows:SetAllPoints(child)
    frame.arrows:SetFrameLevel(child:GetFrameLevel() + 5)

    local background = {}
    for _, key in ipairs({ "TopLeft", "TopRight", "BottomLeft", "BottomRight" }) do
        background[key] = child:CreateTexture(nil, "BACKGROUND")
    end
    background.TopLeft:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    background.TopRight:SetPoint("TOPLEFT", background.TopLeft, "TOPRIGHT", 0, 0)
    background.BottomLeft:SetPoint("TOPLEFT", background.TopLeft, "BOTTOMLEFT", 0, 0)
    background.BottomRight:SetPoint("TOPLEFT", background.TopLeft, "BOTTOMRIGHT", 0, 0)
    frame.background = background

    frame.bar = ns.ClassicScrollBar(frame, scroll, function(value) scroll:SetVerticalScroll(value or 0) end)
    if ns.ScrollColumnOn then ns.ScrollColumnOn(frame.bar) end
    scroll:SetScript("OnMouseWheel", function(_, delta)
        frame.bar:SetValue((frame.bar:GetValue() or 0) - delta * 30)
    end)

    -- The foot: the points left in their box, the small button that
    -- takes staged points back, and Apply Changes. All three are always
    -- there and never change size, so nothing along the foot moves when
    -- a point is staged: the two buttons are simply gray until there is
    -- something to apply or take back. (Escape and the X shut the
    -- window; there is no Close button.)
    -- The old art has a points box painted into it, as wide as the old
    -- foot. It is laid over with stone, and a narrower box drawn, to
    -- make room for the pair.
    local foot = CreateFrame("Frame", nil, frame)
    foot:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -409)
    foot:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", 352, -435)
    local footStone = foot:CreateTexture(nil, "BACKGROUND")
    footStone:SetAllPoints(foot)
    footStone:SetTexture(ns.TexPath("rockBg"), "REPEAT", "REPEAT")
    footStone:SetHorizTile(true)
    footStone:SetVertTile(true)

    -- The undo button at one end of the row and Apply Changes at the
    -- other, the points between them: side by side, a slip of the mouse
    -- on so small a button took the points back when they were meant to
    -- be applied, or the other way about.
    frame.reset = ns.PanelButton(foot, "", 28)
    frame.reset:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -411)
    -- The arrow, small enough to sit inside the button with room round it.
    local undo = frame.reset:CreateTexture(nil, "OVERLAY")
    undo:SetSize(13, 13)
    undo:SetPoint("CENTER", frame.reset, "CENTER", 0, 0)
    if not (undo.SetAtlas and pcall(undo.SetAtlas, undo, "talents-button-undo")) or not undo:GetAtlas() then
        undo:SetTexture("Interface/Buttons/UI-RotationLeft-Button-Up")
    end
    undo:SetSize(13, 13)
    frame.undoIcon = undo
    frame.reset:SetScript("OnClick", function()
        local tree = frame.tree
        if tree and C_Traits.RollbackConfig then pcall(C_Traits.RollbackConfig, tree.configID) end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        Refresh()
    end)
    frame.reset:SetMotionScriptsWhileDisabled(true)
    frame.reset:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(TALENT_FRAME_RESET_BUTTON_TOOLTIP_TITLE or "Reset Pending Changes")
        GameTooltip:Show()
    end)
    frame.reset:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local pointsBox = ns.SkillInsetBox(foot, 16, true)
    pointsBox:SetPoint("LEFT", frame.reset, "RIGHT", 3, 0)
    pointsBox:SetSize(196, 24)
    local pointsFill = pointsBox:CreateTexture(nil, "BACKGROUND")
    pointsFill:SetColorTexture(0, 0, 0, 0.55)
    pointsFill:SetPoint("TOPLEFT", pointsBox, "TOPLEFT", 4, -4)
    pointsFill:SetPoint("BOTTOMRIGHT", pointsBox, "BOTTOMRIGHT", -4, 4)
    frame.points = pointsBox:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.points:SetPoint("RIGHT", pointsBox, "RIGHT", -10, 0)

    frame.learn = ns.PanelButton(foot, "Apply Changes", 104)
    frame.learn:SetPoint("LEFT", pointsBox, "RIGHT", 3, 0)
    frame.learn:SetScript("OnClick", function()
        local tree = frame.tree
        if not tree or InCombatLockdown() then return end
        if C_ClassTalents and C_ClassTalents.CommitConfig then
            -- What this takes is a saved loadout to write the change into
            -- as well, or nothing; it always commits the talents in use.
            -- Given the number of the talents in use as if it were a
            -- loadout, the client first said the talents could not be
            -- changed and then changed them. The client's own window
            -- passes its loadout picker's choice, which here is none.
            local ok, done = pcall(C_ClassTalents.CommitConfig, nil)
            ns.Persist("talents: commit called=" .. tostring(ok) .. " result=" .. tostring(done))
            if ok and done == false and UIErrorsFrame and TALENT_FRAME_CONFIG_OPERATION_TOO_FAST then
                UIErrorsFrame:AddMessage(TALENT_FRAME_CONFIG_OPERATION_TOO_FAST, 1, 0.1, 0.1)
            end
        elseif C_Traits.CommitConfig then
            pcall(C_Traits.CommitConfig, tree.configID)
        end
        Refresh()
    end)

    frame.tabs = {}
    for i = 1, 3 do
        local tab = FootTab(frame)
        if i == 1 then
            tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 15, 78)
        else
            tab:SetPoint("TOPLEFT", frame.tabs[i - 1], "TOPRIGHT", -15, 0)
        end
        tab:SetScript("OnClick", function()
            if selectedTab == i then return end
            selectedTab = i
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            frame.bar:SetValue(0)
            Refresh()
        end)
        frame.tabs[i] = tab
    end

    frame:SetScript("OnShow", function()
        if SetPortraitTexture then SetPortraitTexture(frame.portrait, inspectUnit or "player") end
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        Refresh()
    end)
    frame:SetScript("OnHide", function()
        inspectUnit = nil
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    end)
    -- Someone's talents stand beside the inspect window, which stays up,
    -- and go when it goes: the client drops what it knew of them then.
    frame.fcuiKeep = function()
        return inspectUnit and _G["InspectFrame"] or nil
    end
    frame:SetScript("OnUpdate", function(self, elapsed)
        if not inspectUnit then return end
        self.since = (self.since or 0) + elapsed
        if self.since < 0.2 then return end
        self.since = 0
        local inspect = _G["InspectFrame"]
        if not (inspect and inspect:IsShown()) then self:Hide() end
    end)
    -- After the window's own scripts are set, not before: setting a
    -- script throws away whatever was hooked onto it, and registered
    -- first the window never learned the manners the others keep. It
    -- opened over a vendor, a mailbox, the spellbook, and stayed there.
    ns.RegisterClassicWindow(frame, true)
    -- Escape shuts the window before the client drops the target (see
    -- the spellbook). Signed up after the window's own show and hide
    -- scripts are set: setting a script wipes what was hooked before it,
    -- and signed up ahead of them this was lost.
    if ns.CloseOnEscape then ns.CloseOnEscape(frame) end

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "TRAIT_CONFIG_UPDATED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_NODE_CHANGED", "PLAYER_TALENT_UPDATE",
        "ACTIVE_COMBAT_CONFIG_CHANGED", "PLAYER_LEVEL_UP" }) do
        pcall(events.RegisterEvent, events, event)
    end
    -- A talent's words may not be to hand the first time they are asked
    -- for; when the client says its tooltip data has come, the tooltip
    -- under the mouse is written again, whole.
    local words = CreateFrame("Frame")
    pcall(words.RegisterEvent, words, "TOOLTIP_DATA_UPDATE")
    words:SetScript("OnEvent", function(self)
        local button = frame.hovered
        if not button or not frame:IsShown() or not GameTooltip:IsOwned(button) then return end
        local now = GetTime()
        if self.last and now - self.last < 0.2 then return end
        self.last = now
        Button_OnEnter(button)
    end)
    local pending = false
    events:SetScript("OnEvent", function()
        if pending or not frame:IsShown() then return end
        pending = true
        C_Timer.After(0, function()
            pending = false
            if frame:IsShown() then Refresh() end
        end)
    end)
    return frame
end

------------------------------------------------------------- the way in

local function Toggle()
    Build()
    if frame:IsShown() and inspectUnit then
        -- Up on someone else's talents: the key turns it to the player's.
        inspectUnit = nil
        frame:Hide()
        frame:Show()
    elseif frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

-- The inspect window's Talents button, which opened the client's window.
local function ShowInspect(unit)
    if not unit then return end
    Build()
    if frame:IsShown() then frame:Hide() end
    inspectUnit = unit
    selectedTab = 1
    frame:Show()
end

local inspectClick
local function TakeInspectButton(on)
    local doll = _G["InspectPaperDollFrame"]
    local button = doll and doll.InspectTalents
    if not button then return end
    if on then
        if inspectClick == nil then inspectClick = button:GetScript("OnClick") or false end
        button:SetScript("OnClick", function()
            if C_Traits and C_Traits.HasValidInspectData and not C_Traits.HasValidInspectData() then return end
            local inspect = _G["InspectFrame"]
            ShowInspect(inspect and inspect.unit or "target")
        end)
    elseif inspectClick then
        button:SetScript("OnClick", inspectClick)
        inspectClick = nil
    end
end
-- The inspect window is a piece the client loads when first wanted.
local inspectLoad = CreateFrame("Frame")
inspectLoad:RegisterEvent("ADDON_LOADED")
inspectLoad:SetScript("OnEvent", function(_, _, name)
    if name == "Blizzard_InspectUI" and active then TakeInspectButton(true) end
end)

function ns.ToggleTalents()
    if not active then return false end
    Toggle()
    return true
end

-- The talents micro button and the talents key open this window while it
-- is on, and are the client's own again when it is off.
-- Both of the client's buttons, since it has both: the talents button the
-- micro menu shows on this client, and the one that stands for spells and
-- talents together on others. Taking only the second, which is there but
-- never shown here, left the button on screen opening the client's window.
local microClicks = {}
local function TakeButton(on)
    for _, name in ipairs({ "TalentMicroButton", "PlayerSpellsMicroButton" }) do
        local button = _G[name]
        if button and button.GetScript then
            if on then
                if microClicks[name] == nil then microClicks[name] = button:GetScript("OnClick") or false end
                button:SetScript("OnClick", function()
                    if KeybindFrames_InQuickKeybindMode and KeybindFrames_InQuickKeybindMode() then return end
                    if InCombatLockdown() and C_Timer and C_Timer.After then C_Timer.After(0, Toggle) else Toggle() end
                end)
            elseif microClicks[name] then
                button:SetScript("OnClick", microClicks[name])
            end
        end
    end
end

local BIND_NAME = "ClassicUIForeverTalentsBind"
local bindButton
local function UpdateBinding()
    if not bindButton or InCombatLockdown() then return end
    ClearOverrideBindings(bindButton)
    if not active then return end
    local key, second = GetBindingKey("TOGGLETALENTS")
    for _, k in ipairs({ key, second }) do
        if k then SetOverrideBindingClick(bindButton, true, k, BIND_NAME, "LeftButton") end
    end
end

local function Apply()
    active = true
    if not bindButton then
        bindButton = CreateFrame("Button", BIND_NAME, UIParent)
        bindButton:RegisterForClicks("AnyDown", "AnyUp")
        bindButton:SetScript("OnClick", function(_, _, down)
            -- Once to a press, whichever half of it the game sends.
            local now = GetTime()
            if bindButton.last and now - bindButton.last < 0.2 then return end
            bindButton.last = now
            local _ = down
            Toggle()
        end)
        bindButton:RegisterEvent("UPDATE_BINDINGS")
        bindButton:RegisterEvent("PLAYER_REGEN_ENABLED")
        bindButton:RegisterEvent("PLAYER_ENTERING_WORLD")
        bindButton:SetScript("OnEvent", UpdateBinding)
    end
    TakeButton(true)
    TakeInspectButton(true)
    UpdateBinding()
end

local function Restore()
    active = false
    TakeButton(false)
    TakeInspectButton(false)
    UpdateBinding()
    if frame then frame:Hide() end
end

ns.RegisterModule("talents", { apply = Apply, restore = Restore })
