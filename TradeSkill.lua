local _, ns = ...

-- A profession's own window as the old trade skill window: the rank bar
-- under the title, the recipe list in the upper half under headers that
-- fold, each recipe in the color of its difficulty, and the chosen
-- recipe in the lower half with its icon, what it requires and its
-- reagents; Create All, a count, Create and Exit along the foot.
--
-- The window stays the client's (ProfessionsFrame), with its title, its
-- close button and its profession tabs down the right. Its modern
-- crafting page is stood out of sight and kept running, since the window
-- opens and closes the trade skill around it; this page of ours is laid
-- in its place and reads the same trade skill through the client's
-- public calls. Nothing of the client's page is called or written to.

local active = false
local panel
local WINDOW_W, WINDOW_H = 362, 444
local ROW_H, LIST_ROWS = 16, 8
local REAGENTS_MAX = 8
-- How bright this window's dark marble is drawn. Over one: the same sheet
-- under the who list and the roster has the social window's own floor and
-- a wash of light beneath it, and here it has nothing, so at its plain
-- brightness it read as near black.
local MARBLE = 1.35

local selected          -- recipe id
local collapsed = {}    -- category id -> true
local lines = {}        -- the list as drawn: headers and recipes

local DIFFICULTY = {
    [0] = { 1.00, 0.50, 0.25 },   -- optimal: orange
    [1] = { 1.00, 1.00, 0.00 },   -- medium: yellow
    [2] = { 0.25, 0.75, 0.25 },   -- easy: green
    [3] = { 0.50, 0.50, 0.50 },   -- trivial: gray
}
local HEADER_COLOR = { 1, 0.82, 0 }

local function API() return C_TradeSkillUI end

function ns.TradeSkillActive() return active end

-- How many of a recipe can be made right now. The client's own figure
-- on a recipe comes back as nothing on this client, reagents in the bags
-- or not: a row never showed its count and Create stayed gray. So it is
-- worked out here from what the recipe needs and what is carried, as the
-- old window did it. What a recipe needs does not change, so that part
-- is kept; what is carried is counted fresh each time.
local needsOf = {}
-- What is in the bags, and only that. The bank was counted too, and a
-- recipe read as one you could make several of with materials that were
-- sitting in the bank, where crafting cannot reach them.
local function ItemCountOf(itemID)
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(itemID, false, false, false) or 0 end
    return GetItemCount and GetItemCount(itemID, false) or 0
end

local function Craftable(info)
    if not info or not info.recipeID then return 0 end
    local api = C_TradeSkillUI
    local best = info.numAvailable or 0
    local needs = needsOf[info.recipeID]
    if needs == nil then
        needs = false
        local ok, schematic = pcall(api.GetRecipeSchematic, info.recipeID, false)
        if ok and schematic and schematic.reagentSlotSchematics then
            needs = {}
            for _, slot in ipairs(schematic.reagentSlotSchematics) do
                local basic = not Enum or not Enum.CraftingReagentType or slot.reagentType == Enum.CraftingReagentType.Basic
                local reagent = slot.reagents and slot.reagents[1]
                if basic and reagent and reagent.itemID and (slot.quantityRequired or 0) > 0 then
                    needs[#needs + 1] = { reagent.itemID, slot.quantityRequired }
                end
            end
        end
        needsOf[info.recipeID] = needs
    end
    if not needs or #needs == 0 then return best end
    local count
    for _, need in ipairs(needs) do
        local makes = math.floor(ItemCountOf(need[1]) / need[2])
        if not count or makes < count then count = makes end
    end
    -- Our own count alone once the recipe's needs are known: the client's
    -- figure, where it gives one, may count the bank.
    return count or 0
end

---------------------------------------------------------------------------
-- The list
---------------------------------------------------------------------------

local function CategoryOf(id, cache)
    if cache[id] == nil then
        local info = API().GetCategoryInfo and API().GetCategoryInfo(id)
        cache[id] = info or false
    end
    return cache[id] or nil
end

-- What is typed in the search box: recipes whose name holds it are the
-- only ones listed, under their headers, folded or not.
local query = ""

local function Collect()
    wipe(lines)
    local api = API()
    if not api or not api.GetFilteredRecipeIDs then return end
    local ids = api.GetFilteredRecipeIDs() or {}
    local groups, order, cache = {}, {}, {}
    for _, id in ipairs(ids) do
        local info = api.GetRecipeInfo(id)
        local named = query == "" or (info and type(info.name) == "string" and info.name:lower():find(query, 1, true) ~= nil)
        if info and info.learned ~= false and named then
            local cat = info.categoryID or 0
            local group = groups[cat]
            if not group then
                local catInfo = CategoryOf(cat, cache)
                local parent = catInfo and catInfo.parentCategoryID and CategoryOf(catInfo.parentCategoryID, cache)
                group = {
                    id = cat,
                    name = catInfo and catInfo.name or (OTHER or "Other"),
                    sort = (parent and parent.uiOrder or 0) * 1000 + (catInfo and catInfo.uiOrder or 0),
                    recipes = {},
                }
                groups[cat] = group
                order[#order + 1] = group
            end
            group.recipes[#group.recipes + 1] = info
        end
    end
    table.sort(order, function(a, b)
        if a.sort ~= b.sort then return a.sort < b.sort end
        return a.name < b.name
    end)
    local first
    for _, group in ipairs(order) do
        table.sort(group.recipes, function(a, b)
            local da, db = a.relativeDifficulty or 3, b.relativeDifficulty or 3
            if da ~= db then return da < db end
            return (a.name or "") < (b.name or "")
        end)
        lines[#lines + 1] = { header = true, id = group.id, name = group.name }
        if query ~= "" or not collapsed[group.id] then
            for _, info in ipairs(group.recipes) do
                lines[#lines + 1] = { info = info }
                first = first or info.recipeID
            end
        end
    end
    -- The chosen recipe stays chosen while it is still listed.
    local still = false
    for _, line in ipairs(lines) do
        if line.info and line.info.recipeID == selected then still = true break end
    end
    if not still then selected = first end
end

local function AllCollapsed()
    local any = false
    for _, line in ipairs(lines) do
        if line.header then
            any = true
            if not collapsed[line.id] then return false end
        end
    end
    return any
end

local UpdateDetail

local function UpdateRows()
    if not panel then return end
    local offset = math.floor((panel.bar:GetValue() or 0) + 0.5)
    for i, row in ipairs(panel.rows) do
        local line = lines[offset + i]
        row.line = line
        if not line then
            row:Hide()
        else
            row:Show()
            if line.header then
                row.toggle:Show()
                row.toggle:SetTexture(collapsed[line.id] and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
                row.text:SetPoint("LEFT", row, "LEFT", 21, 0)
                row.text:SetText(line.name)
                row.text:SetTextColor(HEADER_COLOR[1], HEADER_COLOR[2], HEADER_COLOR[3])
                row.selectedTex:Hide()
            else
                local info = line.info
                row.toggle:Hide()
                row.text:SetPoint("LEFT", row, "LEFT", 26, 0)
                local name = info.name or ""
                local count = Craftable(info)
                if count > 0 then name = name .. " [" .. count .. "]" end
                row.text:SetText(name)
                local color = DIFFICULTY[info.relativeDifficulty or 3] or DIFFICULTY[3]
                local isSelected = info.recipeID == selected
                if isSelected then
                    row.text:SetTextColor(1, 1, 1)
                    row.selectedTex:SetVertexColor(color[1], color[2], color[3])
                    row.selectedTex:Show()
                else
                    row.text:SetTextColor(color[1], color[2], color[3])
                    row.selectedTex:Hide()
                end
            end
        end
    end
    panel.bar:SetRange(math.max(0, #lines - LIST_ROWS))
    if panel.collapseAll then
        panel.collapseAll.icon:SetTexture(AllCollapsed() and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
    end
end

local function Row_OnClick(self, button)
    local line = self.line
    if not line then return end
    if line.header then
        collapsed[line.id] = not collapsed[line.id] or nil
        Collect()
        UpdateRows()
        UpdateDetail()
        return
    end
    local info = line.info
    if button == "LeftButton" and IsModifiedClick and IsModifiedClick("CHATLINK") then
        local link = API().GetRecipeLink and API().GetRecipeLink(info.recipeID)
        if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
        return
    end
    selected = info.recipeID
    if panel.count then panel.count:SetNumber(1) end
    UpdateRows()
    UpdateDetail()
end

local function CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(index - 1) * ROW_H)
    row:RegisterForClicks("LeftButtonUp")
    local sel = row:CreateTexture(nil, "BACKGROUND")
    sel:SetAllPoints(row)
    sel:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    sel:SetAlpha(0.6)
    sel:Hide()
    row.selectedTex = sel
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.25)
    local toggle = row:CreateTexture(nil, "ARTWORK")
    toggle:SetSize(14, 14)
    toggle:SetPoint("LEFT", row, "LEFT", 3, 0)
    row.toggle = toggle
    local text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    row.text = text
    row:SetScript("OnClick", Row_OnClick)
    return row
end

---------------------------------------------------------------------------
-- The chosen recipe
---------------------------------------------------------------------------

local function ItemName(itemID)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    return name
end

local function ItemIcon(itemID)
    if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(itemID) end
    if GetItemIcon then return GetItemIcon(itemID) end
end

local function ItemCount(itemID)
    return ItemCountOf(itemID)
end

-- A reagent's name is only there once the client has the item on hand,
-- and asking for it is answered a moment later by the server: a recipe
-- picked for the first time showed its reagent plates blank and filled
-- them in after a beat. So every reagent of every listed recipe is asked
-- for as soon as a profession is up, a few recipes a frame, and by the
-- time a row is clicked its names are already here.
local warmed = {}
local warming
local function WarmReagents()
    local api = API()
    if warming or not (api and api.GetRecipeSchematic and C_Item and C_Item.RequestLoadItemDataByID) then return end
    local queue = {}
    for _, line in ipairs(lines) do
        local id = line.info and line.info.recipeID
        if id and not warmed[id] then
            warmed[id] = true
            queue[#queue + 1] = id
        end
    end
    if #queue == 0 then return end
    warming = C_Timer.NewTicker(0.02, function(ticker)
        for _ = 1, 10 do
            local id = table.remove(queue)
            if not id then
                ticker:Cancel()
                warming = nil
                return
            end
            local ok, schematic = pcall(api.GetRecipeSchematic, id, false)
            for _, slot in ipairs(ok and schematic and schematic.reagentSlotSchematics or {}) do
                local reagent = slot.reagents and slot.reagents[1]
                if reagent and reagent.itemID and not C_Item.GetItemNameByID(reagent.itemID) then
                    C_Item.RequestLoadItemDataByID(reagent.itemID)
                end
            end
        end
    end)
end

local function SelectedInfo()
    if not selected then return nil end
    return API().GetRecipeInfo(selected)
end

UpdateDetail = function()
    if not panel then return end
    local detail = panel.detail
    local info = SelectedInfo()
    detail:SetShown(info ~= nil)
    if not info then
        panel.create:Disable()
        panel.createAll:Disable()
        return
    end
    local api = API()
    local schematic = api.GetRecipeSchematic and api.GetRecipeSchematic(info.recipeID, false)
    detail.icon:SetTexture(info.icon or (schematic and schematic.icon))
    local name = info.name or ""
    local made = schematic and schematic.quantityMax or 1
    detail.made:SetText(made and made > 1 and made or "")
    detail.name:SetText(name)

    -- What it needs beside the reagents: tools, a forge, an anvil.
    local needs = {}
    local requirements = api.GetRecipeRequirements and api.GetRecipeRequirements(info.recipeID)
    for _, requirement in ipairs(requirements or {}) do
        local color = requirement.met and "|cffffffff" or "|cffff2020"
        needs[#needs + 1] = color .. (requirement.name or "") .. "|r"
    end
    if #needs > 0 then
        detail.requires:SetText((REQUIRES_LABEL or "Requires:") .. " " .. table.concat(needs, ", "))
        detail.requires:Show()
    else
        detail.requires:SetText("")
        detail.requires:Hide()
    end

    local cooldown = api.GetRecipeCooldown and api.GetRecipeCooldown(info.recipeID)
    if cooldown and cooldown > 0 then
        detail.cooldown:SetText((COOLDOWN_REMAINING or "Cooldown remaining:") .. " " .. SecondsToTime(cooldown))
        detail.cooldown:Show()
    else
        detail.cooldown:Hide()
    end

    local shown = 0
    for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or {}) do
        local basic = not Enum or not Enum.CraftingReagentType or slot.reagentType == Enum.CraftingReagentType.Basic
        local reagent = slot.reagents and slot.reagents[1]
        if basic and reagent and reagent.itemID and shown < REAGENTS_MAX then
            shown = shown + 1
            local button = detail.reagents[shown]
            local need = slot.quantityRequired or 1
            local have = ItemCount(reagent.itemID)
            button.itemID = reagent.itemID
            button.slotIndex = slot.dataSlotIndex or slot.slotIndex
            button.icon:SetTexture(ItemIcon(reagent.itemID))
            button.name:SetText(ItemName(reagent.itemID) or "")
            button.count:SetText(have .. "/" .. need)
            if have < need then
                button.icon:SetVertexColor(0.5, 0.5, 0.5)
                button.name:SetTextColor(0.5, 0.5, 0.5)
            else
                button.icon:SetVertexColor(1, 1, 1)
                button.name:SetTextColor(1, 1, 1)
            end
            button:Show()
        end
    end
    for i = shown + 1, REAGENTS_MAX do detail.reagents[i]:Hide() end
    detail.reagentLabel:SetShown(shown > 0)

    local can = Craftable(info) > 0 and not info.disabled
    panel.create:SetEnabled(can)
    panel.createAll:SetEnabled(can)
    panel.createAll:SetText((CREATE_ALL or "Create All"))
end

local function ReagentButton(parent, index)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(148, 41)
    local column, line = (index - 1) % 2, math.floor((index - 1) / 2)
    button:SetPoint("TOPLEFT", parent.reagentLabel, "BOTTOMLEFT", column * 152 - 2, -3 - line * 43)
    local plate = button:CreateTexture(nil, "BACKGROUND")
    ns.SetFile(plate, "Interface\\QuestFrame\\UI-QuestItemNameFrame")
    plate:SetSize(128, 64)
    plate:SetPoint("LEFT", button, "LEFT", 30, 0)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(39, 39)
    icon:SetPoint("LEFT", button, "LEFT", 0, 0)
    button.icon = icon
    local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
    button.count = count
    local name = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    name:SetSize(98, 36)
    name:SetJustifyH("LEFT")
    button.name = name
    button:SetScript("OnEnter", function(self)
        if not selected or not self.slotIndex then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        local ok = GameTooltip.SetRecipeReagentItem and pcall(GameTooltip.SetRecipeReagentItem, GameTooltip, selected, self.slotIndex)
        if not ok and self.itemID and GameTooltip.SetItemByID then GameTooltip:SetItemByID(self.itemID) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function(self)
        if not self.itemID or not (IsModifiedClick and IsModifiedClick()) then return end
        local _, link = C_Item.GetItemInfo(self.itemID)
        if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
    end)
    return button
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

-- The sunken panes of the old window: the dark marble the who list and
-- the guild roster lie on, a shade darker here as it was in this window,
-- inside the metal border the game menu wears. The border's weight is
-- the caller's: heavy round the two panes, lighter round the foot, and
-- none of the floor there, where the buttons stand on the window's stone.
local function InsetBox(parent, edge, bare)
    edge = edge or 16
    local inset = edge / 4
    local box = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    if not bare then
        local floor = box:CreateTexture(nil, "BACKGROUND")
        floor:SetTexture(ns.TexPath("marbleBg"), "REPEAT", "REPEAT")
        ns.BronzeTint(floor)
        floor:SetHorizTile(true)
        floor:SetVertTile(true)
        floor:SetTexCoord(0, 1, 0, 1)
        -- A shade under the marble's own brightness. At half it read as
        -- plain black and the stone's grain was gone.
        floor:SetVertexColor(MARBLE, MARBLE, MARBLE)
        floor:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -inset)
        floor:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset, inset)
        box.floor = floor
    end
    if box.SetBackdrop then
        box:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = edge,
            insets = { left = inset, right = inset, top = inset, bottom = inset },
        })
        ns.BronzeBackdrop(box)
    end
    return box
end

-- A strip of the window's own stone. The old window's upper pane shows
-- only a sliver of border along its top, and the "All" tab only a sliver
-- along its top and right: the rest of those edges is tucked under the
-- stone above and beside them. Here the stone is laid over them instead.
local function StoneStrip(parent, level)
    local strip = CreateFrame("Frame", nil, parent)
    strip:SetFrameLevel(level)
    local stone = strip:CreateTexture(nil, "ARTWORK")
    stone:SetAllPoints(strip)
    stone:SetTexture(ns.TexPath("rockBg"), "REPEAT", "REPEAT")
    ns.BronzeTint(stone)
    stone:SetHorizTile(true)
    stone:SetVertTile(true)
    return strip
end

local function Refresh()
    if not panel or not panel:IsShown() then return end
    local api = API()
    local prof = api.GetChildProfessionInfo and api.GetChildProfessionInfo()
    if not prof or not prof.maxSkillLevel or prof.maxSkillLevel == 0 then
        prof = api.GetBaseProfessionInfo and api.GetBaseProfessionInfo() or prof
    end
    Collect()
    -- Opened in a hurry (the client opening two professions at once as
    -- its window shows, during a fight above all) the trade skill can
    -- come up with its recipes and without its name or its rank: a blank
    -- title over a bar reading 0/0. The first recipe still says which
    -- skill it belongs to, and the skill says the rest.
    if (not prof or (prof.maxSkillLevel or 0) == 0) and api.GetTradeSkillLineForRecipe and GetProfessions and GetProfessionInfo then
        local first
        for _, line in ipairs(lines) do
            if line.info then first = line.info.recipeID break end
        end
        local lineID, _, parentID
        if first then lineID, _, parentID = api.GetTradeSkillLineForRecipe(first) end
        -- The list of professions has gaps in it for the ones not learned.
        local known = { GetProfessions() }
        for slot = 1, 8 do
            local index = known[slot]
            if index then
                local name, _, rank, maxRank, _, _, skillLine, modifier = GetProfessionInfo(index)
                if name and skillLine and (skillLine == lineID or skillLine == parentID) then
                    prof = { professionName = name, skillLevel = rank, maxSkillLevel = maxRank, skillModifier = modifier }
                    break
                end
            end
        end
    end
    local title = ProfessionsFrame and ProfessionsFrame.TitleContainer and ProfessionsFrame.TitleContainer.TitleText
    if title and prof and prof.professionName and (title:GetText() or "") == "" then title:SetText(prof.professionName) end
    if prof then
        local rank, maxRank = prof.skillLevel or 0, prof.maxSkillLevel or 0
        panel.rank:SetMinMaxValues(0, math.max(1, maxRank))
        panel.rank:SetValue(rank)
        local modifier = prof.skillModifier or 0
        if modifier > 0 then
            panel.rank.text:SetFormattedText("%d (+%d)/%d", rank, modifier, maxRank)
        else
            panel.rank.text:SetFormattedText("%d/%d", rank, maxRank)
        end
    end
    UpdateRows()
    UpdateDetail()
    WarmReagents()
end
ns.RefreshTradeSkill = Refresh

local function Craft(all)
    local info = SelectedInfo()
    if not info then return end
    local count = 1
    if all then
        count = Craftable(info)
    elseif panel.count then
        count = panel.count:GetNumber() or 1
    end
    count = math.max(1, math.min(count, math.max(1, Craftable(info))))
    panel.count:ClearFocus()
    -- The count in the box runs down as each one is made, as the old
    -- window's did: what is being made, and how many are still to come.
    panel.count:SetNumber(count)
    panel.making = { recipe = info.recipeID, left = count }
    API().CraftRecipe(info.recipeID, count)
end

-- One made: the box shows what is left. A run that ends, or is broken
-- off, leaves the box at one.
local function RunWatch()
    local watch = CreateFrame("Frame")
    watch:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    for _, event in ipairs({ "UPDATE_TRADESKILL_CAST_STOPPED", "UNIT_SPELLCAST_INTERRUPTED" }) do
        pcall(watch.RegisterEvent, watch, event)
    end
    watch:SetScript("OnEvent", function(_, event, unit, _, spellID)
        local making = panel and panel.making
        if not making then return end
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if (issecretvalue and issecretvalue(spellID)) or spellID ~= making.recipe then return end
            making.left = making.left - 1
            if making.left <= 0 then
                panel.making = nil
                panel.count:SetNumber(1)
            else
                panel.count:SetNumber(making.left)
            end
        elseif event == "UPDATE_TRADESKILL_CAST_STOPPED" or unit == "player" then
            panel.making = nil
            panel.count:SetNumber(1)
        end
    end)
end

ns.SkillInsetBox = InsetBox

-- The search box is a toggle of its own under the window; off, it goes
-- and any search with it.
local function SearchShown(on)
    if not panel or not panel.search then return end
    if not on then panel.search:SetText("") end
    panel.search:SetShown(on)
    panel.searchBox:SetShown(on)
end
ns.RegisterModule("tradeSkillSearch", {
    apply = function() SearchShown(true) end,
    restore = function() SearchShown(false) end,
})

-- The shell of the old skill windows, shared by the trade skill window
-- and the trainer's: the All tab drawn in one outline with the list, the
-- filter button, the list pane with its rows and scroll column, the pane
-- below it and the lighter border round the foot. What goes in the rows,
-- the lower pane and the foot is the caller's. opts: rows (how many the
-- list shows), createRow(list, index), onScroll().
function ns.OldSkillShell(panel, opts)
    local rowCount = opts.rows or LIST_ROWS
    -- Fold or unfold every header at once.
    local all = CreateFrame("Button", nil, panel)
    all:SetSize(60, 18)
    all:SetPoint("TOPLEFT", panel, "TOPLEFT", 17, -68)
    all.icon = all:CreateTexture(nil, "ARTWORK")
    all.icon:SetSize(14, 14)
    all.icon:SetPoint("LEFT", all, "LEFT", 0, 0)
    local allText = all:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    allText:SetPoint("LEFT", all.icon, "RIGHT", 4, 0)
    allText:SetText(ALL or "All")
    panel.collapseAll = all

    -- The old filter was a drop down: the dark label frame with the gold
    -- arrow button at its right end, the same one the character sheet's
    -- stat panes wear, with its word set against the arrow.
    local filter = CreateFrame("Button", nil, panel)
    filter:SetSize(118, 27)
    filter:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -9, -57)
    -- Over the strips of stone laid along the list's top edge below.
    filter:SetFrameLevel(panel:GetFrameLevel() + 12)
    local filterArrow = ns.DressDropdown(filter, 14)
    local filterText = filter:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    filterText:SetPoint("RIGHT", filterArrow, "LEFT", 1, 1)
    filterText:SetText(FILTER or "Filter")
    panel.filter = filter

    -- The list.
    -- Both panes run out to the window's own border on either side, and
    -- under it: the window's border is drawn above this page, so where
    -- the two meet the window's wins.
    local listBox = InsetBox(panel, 32)
    -- The window's border is drawn some way outside the window's own
    -- edge on the left, and a little outside it on the right, so that is
    -- how far the panes run to reach under it.
    listBox:SetPoint("TOPLEFT", panel, "TOPLEFT", -2, -75)
    -- On the right it runs in under the scroll column, whose own left
    -- edge is drawn over the pane's right one.
    listBox:SetPoint("RIGHT", panel, "RIGHT", -15, 0)
    listBox:SetHeight(rowCount * ROW_H + 25)
    -- The dark tab "All" stands on: the same floor, run down over the
    -- list's top edge so the two read as one piece.
    -- The tab is not a box of its own. It is the list's own left border
    -- carried on up, turned across the top and brought back down on the
    -- right to the list's top edge and no further: one outline round the
    -- tab and the list together, as the old window drew it. A box laid on
    -- the list left three things wrong: the list's top left corner piece
    -- showing beside the tab, the tab's left side standing in from the
    -- list's, and its right side running on down into the list.
    local EDGE = 32
    local BORDER_FILE = "Interface\\DialogFrame\\UI-DialogBox-Border"
    local V0, V1 = 0.0625, 0.9375
    local tab = CreateFrame("Frame", nil, panel)
    tab:SetSize(80, 22)
    tab:SetPoint("BOTTOMLEFT", listBox, "TOPLEFT", 0, 0)
    tab:SetFrameLevel(listBox:GetFrameLevel() + 3)
    local function Piece(layer)
        local tex = tab:CreateTexture(nil, layer or "BORDER")
        ns.SetFile(tex, BORDER_FILE)
        return tex
    end
    -- The list's own corner piece, which the tab's left side replaces.
    if listBox.TopLeftCorner then listBox.TopLeftCorner:SetAlpha(0) end
    local corner = Piece()
    corner:SetSize(EDGE, EDGE)
    corner:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
    corner:SetTexCoord(0.5078125, 0.6171875, V0, V1)
    local leftSide = Piece()
    leftSide:SetWidth(EDGE)
    leftSide:SetPoint("TOPLEFT", corner, "BOTTOMLEFT", 0, 0)
    leftSide:SetPoint("BOTTOM", listBox, "TOP", 0, -EDGE)
    leftSide:SetTexCoord(0.0078125, 0.1171875, V0, V1)
    local farCorner = Piece()
    farCorner:SetSize(EDGE, EDGE)
    farCorner:SetPoint("TOPRIGHT", tab, "TOPRIGHT", 0, 0)
    farCorner:SetTexCoord(0.6328125, 0.7421875, V0, V1)
    local top = Piece()
    top:SetHeight(EDGE)
    top:SetPoint("TOPLEFT", corner, "TOPRIGHT", 0, 0)
    top:SetPoint("TOPRIGHT", farCorner, "TOPLEFT", 0, 0)
    -- The edge pieces of a border sheet lie on their side in the file.
    top:SetTexCoord(0.2578125, V1, 0.3671875, V1, 0.2578125, V0, 0.3671875, V0)
    local rightSide = Piece()
    rightSide:SetWidth(EDGE)
    rightSide:SetPoint("TOPRIGHT", farCorner, "BOTTOMRIGHT", 0, 0)
    -- Down to the foot of the list's top edge, so the two slivers meet
    -- in a plain corner.
    rightSide:SetPoint("BOTTOM", listBox, "TOP", 0, -11)
    rightSide:SetTexCoord(0.1328125, 0.2421875, V0, V1)
    -- The floor, under the border's metal and down onto the list's own.
    local floor = tab:CreateTexture(nil, "BACKGROUND")
    floor:SetTexture(ns.TexPath("marbleBg"), "REPEAT", "REPEAT")
    ns.BronzeTint(floor)
    floor:SetHorizTile(true)
    floor:SetVertTile(true)
    floor:SetVertexColor(MARBLE, MARBLE, MARBLE)
    floor:SetPoint("TOPLEFT", tab, "TOPLEFT", 8, -8)
    floor:SetPoint("RIGHT", tab, "RIGHT", -8, 0)
    floor:SetPoint("BOTTOM", listBox, "TOP", 0, -13)
    all:SetFrameLevel(tab:GetFrameLevel() + 2)
    panel.allTab = tab
    panel.listBox = listBox
    local list = CreateFrame("Frame", nil, listBox)
    list:SetPoint("TOPLEFT", listBox, "TOPLEFT", 17, -17)
    list:SetPoint("BOTTOMRIGHT", listBox, "BOTTOMRIGHT", -14, 10)
    list:EnableMouseWheel(true)
    panel.list = list
    panel.rows = {}
    for i = 1, rowCount do panel.rows[i] = opts.createRow(list, i) end
    panel.bar = ns.ClassicScrollBar(panel, list, function() opts.onScroll() end)
    -- The old window kept its scroll column whether or not the list ran
    -- past it.
    panel.bar.hideWhenIdle = false
    panel.bar:ClearAllPoints()
    panel.bar:SetPoint("TOPLEFT", listBox, "TOPRIGHT", -9, -27)
    panel.bar:SetPoint("BOTTOMLEFT", listBox, "BOTTOMRIGHT", -9, 22)
    -- Above the pane, so the column's left edge covers the pane's right.
    panel.bar:SetFrameLevel(listBox:GetFrameLevel() + 6)
    if ns.ScrollColumnOn then ns.ScrollColumnOn(panel.bar) end
    -- The run the knob travels is the same dark marble as the panes, not
    -- the column's own gray: laid over the column's art, under the knob.
    local run = panel.bar:CreateTexture(nil, "BORDER")
    run:SetTexture(ns.TexPath("marbleBg"), "REPEAT", "REPEAT")
    ns.BronzeTint(run)
    run:SetHorizTile(true)
    run:SetVertTile(true)
    run:SetVertexColor(MARBLE, MARBLE, MARBLE)
    run:SetPoint("TOPLEFT", panel.bar, "TOPLEFT", 0, 0)
    run:SetPoint("BOTTOMRIGHT", panel.bar, "BOTTOMRIGHT", 0, 0)
    -- The slivers: stone over the outer part of the list's top edge,
    -- from the tab to the pane's right end, and over the outer part of
    -- the tab's top and right. Inside the panes' own rectangles, so
    -- nothing above the list (the filter button) is covered.
    local level = listBox:GetFrameLevel() + 4
    local overList = StoneStrip(panel, level)
    overList:SetPoint("TOPLEFT", panel.allTab, "BOTTOMRIGHT", 0, 0)
    overList:SetPoint("RIGHT", listBox, "RIGHT", 0, 0)
    overList:SetHeight(8)
    local overTab = StoneStrip(panel, level)
    overTab:SetPoint("TOPLEFT", panel.allTab, "TOPLEFT", 0, 0)
    overTab:SetPoint("TOPRIGHT", panel.allTab, "TOPRIGHT", 0, 0)
    overTab:SetHeight(8)
    local besideTab = StoneStrip(panel, level)
    besideTab:SetPoint("TOPRIGHT", panel.allTab, "TOPRIGHT", 0, 0)
    -- Down as far as the stone along the list's top goes. Stopping at
    -- the tab's foot left a small square of the border's metal bare in
    -- the angle between the two strips.
    besideTab:SetPoint("BOTTOMRIGHT", panel.allTab, "BOTTOMRIGHT", 0, -8)
    besideTab:SetWidth(8)
    list:SetScript("OnMouseWheel", function(_, delta)
        panel.bar:SetValue((panel.bar:GetValue() or 0) - delta * 2)
    end)

    -- The chosen recipe.
    -- One border between the two panes, not two with a gap: the lower
    -- pane is raised until its top edge lies on the upper one's bottom
    -- edge (the metal of this border runs from 4 to 11 in from the
    -- outside at this weight), and it is drawn above, so it is the one
    -- that shows.
    local detailBox = InsetBox(panel, 32)
    -- Close on it rather than dead on it: the old window's two edges
    -- read as one heavy line with a hair between them.
    detailBox:SetPoint("TOPLEFT", listBox, "BOTTOMLEFT", 0, 12)
    detailBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 33)
    detailBox:SetFrameLevel(listBox:GetFrameLevel() + 2)
    -- The foot: one lighter border round all of its buttons, out to the
    -- window's border as the panes are, and no floor of its own. Its
    -- top edge lies under the lower pane's bottom one in the same way.
    local footBox = InsetBox(panel, 20, true)
    footBox:SetPoint("TOPLEFT", detailBox, "BOTTOMLEFT", 0, 7)
    footBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 1, 2)
    footBox:SetFrameLevel(listBox:GetFrameLevel() + 1)
    local detail = CreateFrame("Frame", nil, detailBox)
    detail:SetAllPoints(detailBox)
    panel.detail = detail
    panel.detailBox, panel.footBox = detailBox, footBox
end

local function Build()
    local host = ProfessionsFrame
    if panel or not host then return panel end
    panel = CreateFrame("Frame", "ClassicUIForeverTradeSkill", host)
    panel:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
    panel:SetFrameLevel(host:GetFrameLevel() + 120)
    panel:Hide()

    -- The rank bar, under the title and beside the portrait.
    local rank = CreateFrame("StatusBar", nil, panel)
    rank:SetPoint("TOPLEFT", panel, "TOPLEFT", 72, -36)
    rank:SetPoint("RIGHT", panel, "RIGHT", -42, 0)
    rank:SetHeight(13)
    rank:SetStatusBarTexture((ns.TexPath("skillsBar")))
    rank:SetStatusBarColor(0.25, 0.25, 0.75)
    local rankBg = rank:CreateTexture(nil, "BACKGROUND")
    rankBg:SetAllPoints(rank)
    rankBg:SetColorTexture(0, 0, 0, 0.6)
    local rankBorder = rank:CreateTexture(nil, "OVERLAY")
    ns.SetTex(rankBorder, "skillsBarBorder")
    rankBorder:SetPoint("TOPLEFT", rank, "TOPLEFT", -5, 5)
    rankBorder:SetPoint("BOTTOMRIGHT", rank, "BOTTOMRIGHT", 5, -5)
    rank.text = rank:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rank.text:SetPoint("CENTER", rank, "CENTER", 0, 0)
    panel.rank = rank

    ns.OldSkillShell(panel, { rows = LIST_ROWS, createRow = CreateRow, onScroll = function() UpdateRows() end })
    local all, filter, detail = panel.collapseAll, panel.filter, panel.detail
    all:SetScript("OnClick", function()
        local fold = not AllCollapsed()
        for _, line in ipairs(lines) do
            if line.header then collapsed[line.id] = fold or nil end
        end
        Collect()
        UpdateRows()
        UpdateDetail()
    end)
    filter:SetScript("OnClick", function(self)
        if not panel.filterList then
            local api = API()
            panel.filterList = ns.DropList({
                { CRAFT_IS_MAKEABLE or "Have Materials", function()
                    api.SetOnlyShowMakeableRecipes(not api.GetOnlyShowMakeableRecipes())
                end, function() return api.GetOnlyShowMakeableRecipes() end },
                { TRADESKILL_FILTER_HAS_SKILL_UP or "Has Skill Up", function()
                    api.SetOnlyShowSkillUpRecipes(not api.GetOnlyShowSkillUpRecipes())
                end, function() return api.GetOnlyShowSkillUpRecipes() end },
            })
            panel.filterList:Follow(panel)
        end
        panel.filterList:Toggle(self)
    end)

    -- A search box, in the room between the All tab and the filter: the
    -- old window had none, and a long recipe list wants one. In the same
    -- thin iron border the foot's count wears.
    local search = CreateFrame("EditBox", nil, panel)
    search:SetPoint("LEFT", panel.allTab, "RIGHT", 16, -6)
    search:SetPoint("RIGHT", panel.filter, "LEFT", -14, 0)
    search:SetHeight(16)
    search:SetFrameLevel(panel:GetFrameLevel() + 13)
    search:SetAutoFocus(false)
    search:SetFontObject("GameFontHighlightSmall")
    search:SetMaxLetters(40)
    search:SetTextInsets(2, 14, 0, 0)
    local searchBox = InsetBox(panel, 16, true)
    searchBox:SetPoint("TOPLEFT", search, "TOPLEFT", -7, 5)
    searchBox:SetPoint("BOTTOMRIGHT", search, "BOTTOMRIGHT", 5, -5)
    searchBox:SetFrameLevel(panel:GetFrameLevel() + 12)
    local searchFloor = searchBox:CreateTexture(nil, "BACKGROUND")
    searchFloor:SetColorTexture(0, 0, 0, 0.5)
    searchFloor:SetPoint("TOPLEFT", searchBox, "TOPLEFT", 4, -4)
    searchFloor:SetPoint("BOTTOMRIGHT", searchBox, "BOTTOMRIGHT", -4, 4)
    local searchHint = search:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    searchHint:SetPoint("LEFT", search, "LEFT", 3, 0)
    searchHint:SetText(SEARCH or "Search")
    search:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:SetScript("OnTextChanged", function(self)
        local text = (self:GetText() or ""):lower()
        searchHint:SetShown(text == "")
        if text ~= query then
            query = text
            panel.bar:SetValue(0)
            Collect()
            panel.bar:SetRange(math.max(0, #lines - LIST_ROWS))
            UpdateRows()
            UpdateDetail()
        end
    end)
    local shown = not (ns.db and ns.db.tradeSkillSearch == false)
    search:SetShown(shown)
    searchBox:SetShown(shown)
    panel.search, panel.searchBox = search, searchBox

    local iconButton = CreateFrame("Button", nil, detail)
    iconButton:SetSize(37, 37)
    iconButton:SetPoint("TOPLEFT", detail, "TOPLEFT", 20, -18)
    detail.icon = iconButton:CreateTexture(nil, "ARTWORK")
    detail.icon:SetAllPoints(iconButton)
    detail.made = iconButton:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    detail.made:SetPoint("BOTTOMRIGHT", iconButton, "BOTTOMRIGHT", -2, 2)
    iconButton:SetScript("OnEnter", function(self)
        if not selected then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local ok = GameTooltip.SetRecipeResultItem and pcall(GameTooltip.SetRecipeResultItem, GameTooltip, selected, {}, nil, nil, nil)
        if not ok and GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(selected) end
        GameTooltip:Show()
    end)
    iconButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    iconButton:SetScript("OnClick", function()
        if not selected or not (IsModifiedClick and IsModifiedClick()) then return end
        local link = API().GetRecipeItemLink and API().GetRecipeItemLink(selected)
        if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
    end)

    detail.name = detail:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    detail.name:SetPoint("TOPLEFT", iconButton, "TOPRIGHT", 8, -2)
    detail.name:SetPoint("RIGHT", detail, "RIGHT", -14, 0)
    detail.name:SetJustifyH("LEFT")
    detail.requires = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail.requires:SetPoint("TOPLEFT", detail.name, "BOTTOMLEFT", 0, -3)
    detail.requires:SetPoint("RIGHT", detail, "RIGHT", -14, 0)
    detail.requires:SetJustifyH("LEFT")
    detail.cooldown = detail:CreateFontString(nil, "ARTWORK", "GameFontRedSmall")
    detail.cooldown:SetPoint("TOPLEFT", detail.requires, "BOTTOMLEFT", 0, -2)
    detail.reagentLabel = detail:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    detail.reagentLabel:SetText(SPELL_REAGENTS or "Reagents:")
    detail.reagentLabel:SetPoint("TOPLEFT", detail, "TOPLEFT", 19, -66)
    detail.reagents = {}
    for i = 1, REAGENTS_MAX do detail.reagents[i] = ReagentButton(detail, i) end

    -- The foot: Create All, the count between its arrows, Create, Exit.
    local createAll = ns.PanelButton(panel, CREATE_ALL or "Create All", 92)
    createAll:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 7, 11)
    createAll:SetScript("OnClick", function() Craft(true) end)
    panel.createAll = createAll

    local dec = CreateFrame("Button", nil, panel)
    dec:SetSize(20, 20)
    dec:SetPoint("LEFT", createAll, "RIGHT", 5, 0)
    ns.SetButtonFile(dec, "Normal", "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    ns.SetButtonFile(dec, "Pushed", "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    ns.SetButtonFile(dec, "Disabled", "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
    dec:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local count = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    count:SetSize(24, 20)
    count:SetPoint("LEFT", dec, "RIGHT", 5, 0)
    count:SetAutoFocus(false)
    count:SetNumeric(true)
    count:SetMaxLetters(3)
    count:SetNumber(1)
    count:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    count:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    panel.count = count
    local inc = CreateFrame("Button", nil, panel)
    inc:SetSize(20, 20)
    inc:SetPoint("LEFT", count, "RIGHT", 1, 0)
    -- The count and its two arrows stand in a thin border of their own.
    local countBox = InsetBox(panel, 16, true)
    countBox:SetPoint("TOPLEFT", dec, "TOPLEFT", -4, 4)
    countBox:SetPoint("BOTTOMRIGHT", inc, "BOTTOMRIGHT", 4, -4)
    countBox:SetFrameLevel(math.max(0, dec:GetFrameLevel() - 1))
    ns.SetButtonFile(inc, "Normal", "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    ns.SetButtonFile(inc, "Pushed", "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    ns.SetButtonFile(inc, "Disabled", "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
    inc:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    local function Step(by)
        local info = SelectedInfo()
        local most = math.max(1, Craftable(info))
        count:SetNumber(math.max(1, math.min(most, (count:GetNumber() or 1) + by)))
    end
    dec:SetScript("OnClick", function() Step(-1) end)
    inc:SetScript("OnClick", function() Step(1) end)

    local exit = ns.PanelButton(panel, EXIT or "Exit", 86)
    exit:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 11)
    exit:SetScript("OnClick", function()
        if HideUIPanel and ProfessionsFrame then HideUIPanel(ProfessionsFrame) end
    end)
    local create = ns.PanelButton(panel, CREATE_PROFESSION or CREATE or "Create", 93)
    create:SetPoint("RIGHT", exit, "LEFT", -2, 0)
    create:SetScript("OnClick", function() Craft(false) end)
    panel.create = create

    panel:SetScript("OnShow", Refresh)
    RunWatch()

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED",
        "TRADE_SKILL_DETAILS_UPDATE", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED", "SKILL_LINES_CHANGED",
        "UPDATE_TRADESKILL_CAST_STOPPED", "TRADE_SKILL_ITEM_CRAFTED_RESULT" }) do
        pcall(events.RegisterEvent, events, event)
    end
    local pending, detailOnly = false, true
    events:SetScript("OnEvent", function(_, event)
        if not active then return end
        -- An item's data arriving only ever changes the chosen recipe's
        -- plates; the list is not gone through again for it.
        if event ~= "GET_ITEM_INFO_RECEIVED" then detailOnly = false end
        if pending then return end
        pending = true
        C_Timer.After(0, function()
            pending = false
            if detailOnly then
                if panel and panel:IsShown() then UpdateDetail() end
            else
                Refresh()
            end
            detailOnly = true
        end)
    end)
    return panel
end

-- Called from the professions watcher: whether a profession's crafting
-- page is what the window is showing.
function ns.ShowTradeSkill(up)
    if not active then
        if panel then panel:Hide() end
        return
    end
    if not panel and ProfessionsFrame then Build() end
    if not panel then return end
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    -- As soon as there is a page, open or not: during a fight it may not
    -- be movable, and ours over a page still in place is both at once.
    if page and not page.fcuiAway and not (InCombatLockdown() and page:IsProtected()) then
        -- The client's page, out of sight and still running.
        page.fcuiAway = true
        local w, h = page:GetWidth(), page:GetHeight()
        page:ClearAllPoints()
        page:SetSize(math.max(600, w or 0), math.max(500, h or 0))
        page:SetPoint("TOPLEFT", ProfessionsFrame, "TOPLEFT", 6000, 0)
        page:SetAlpha(0)
    end
    local show = up and page and page.fcuiAway and true or false
    if panel:IsShown() ~= show then panel:SetShown(show) end
end

function ns.TradeSkillWindowSize() return WINDOW_W, WINDOW_H end

local function Apply()
    active = true
    if ns.StartProfessionsWatch then ns.StartProfessionsWatch() end
end

local function Restore()
    if not active then return end
    active = false
    if panel then panel:Hide() end
    ns.needsReload = true
end

ns.RegisterModule("tradeSkill", { apply = Apply, restore = Restore })
