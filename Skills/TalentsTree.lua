local _, ns = ...

-- The talent window's data: this client's single tree (three groups; nodes with position, ranks, edges)
-- read into three lists of talents on a grid, so added or moved talents land where it puts them.

local TL = ns.talents

-- unit: nil for the player, or the inspected unit (its own read-only config).
local function ConfigID(unit)
    if unit then
        return Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID or -1
    end
    local spec = C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup and C_SpecializationInfo.GetActiveSpecGroup()
    local id = spec and C_SpecializationInfo.GetCombatConfigIDForSpecGroup and C_SpecializationInfo.GetCombatConfigIDForSpecGroup(spec)
    if not id and C_ClassTalents and C_ClassTalents.GetActiveConfigID then id = C_ClassTalents.GetActiveConfigID() end
    return id
end

local function ByOrderIndex(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end

-- The tree read into three lists of talents on a grid.
function TL.ReadTree(unit)
    local configID = ConfigID(unit)
    if not configID or not C_Traits then return nil end
    local config = C_Traits.GetConfigInfo(configID)
    local treeID = config and config.treeIDs and config.treeIDs[1]
    if not treeID then return nil end
    local tree = { configID = configID, treeID = treeID, tabs = {}, points = 0 }
    local okGroups, groups = pcall(C_Traits.GetGroupDisplayInfoByTreeID, treeID)
    if not okGroups or type(groups) ~= "table" then return nil end
    table.sort(groups, ByOrderIndex)
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
                    -- canPurchaseRank ignores points left; without the check unspent talents lit green.
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
    -- Grid: a cell is the smallest step between nodes; a tree's leftmost node is column 0.
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
        local used = {}
        for _, talent in ipairs(tab.nodes) do
            talent.column = math.floor((talent.x - leftX) / 600 + 0.5)
            talent.tier = math.floor((talent.y - (topY or talent.y)) / 600 + 0.5)
            used[talent.tier] = true
        end
        -- Stop at a gap of more than two empty rows: the client can put a node far
        -- below its group, which stretched the page; such nodes are not drawn.
        local last = -1
        local tiers = {}
        for tier in pairs(used) do tiers[#tiers + 1] = tier end
        table.sort(tiers)
        for _, tier in ipairs(tiers) do
            if last >= 0 and tier - last > 3 then break end
            last = tier
        end
        tab.tiers = last + 1
        for i = #tab.nodes, 1, -1 do
            local talent = tab.nodes[i]
            if talent.tier > last then
                nodesByID[talent.nodeID] = nil
                table.remove(tab.nodes, i)
            end
        end
    end
    tree.nodesByID = nodesByID
    tree.inspect = unit ~= nil
    tree.staged = not tree.inspect and C_Traits.ConfigHasStagedChanges and C_Traits.ConfigHasStagedChanges(configID) and true or false
    return tree
end
