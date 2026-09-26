local _, ns = ...

-- The old talent window: one tree per foot tab on its old background, rank plates and arrows, points spent atop and left at the foot.
-- A click stages, Apply commits (old preview). Our own window like the spellbook, so it opens in combat; the client's window is untouched.

-- The talent window's private table; TalentsTree.lua reads the tree into it.
local TL = {}
ns.talents = TL

local active = false
local frame
-- Up only while someone's talents are shown.
local inspectWatch
local selectedTab = 1
-- nil for the player, or the inspected unit (its own read-only config).
local inspectUnit
local buttons, branchPool, arrowPool = {}, {}, {}
-- Last background drawn; reset only on change.
local backgroundName

local IsSecret = ns.IsSecret

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

-- The branch sheet: a lit row of pieces over a grey one.
local BRANCH = {
    vertical = { [true] = { 0, 0.125, 0, 0.484375 }, [false] = { 0, 0.125, 0.515625, 1 } },
    horizontal = { [true] = { 0.2578125, 0.3828125, 0, 0.5 }, [false] = { 0.2578125, 0.3828125, 0.5, 1 } },
}
local ARROW = {
    down = { [true] = { 0, 0.5, 0, 0.5 }, [false] = { 0, 0.5, 0.5, 1 } },
    right = { [true] = { 1, 0.5, 0, 0.5 }, [false] = { 1, 0.5, 0.5, 1 } },
    left = { [true] = { 0.5, 1, 0, 0.5 }, [false] = { 0.5, 1, 0.5, 1 } },
}

-- The talent sheet's top pieces are gone from this client; the character
-- window's general top is the same art.
local TALENT_QUARTERS = {
    { key = "charGeneralTopLeft", layer = "BORDER", w = 256, h = 256, point = "TOPLEFT" },
    { key = "charGeneralTopRight", layer = "BORDER", w = 128, h = 256, point = "TOPRIGHT" },
    { set = "file", key = ART .. "UI-TalentFrame-BotLeft", layer = "BORDER", w = 256, h = 256, point = "BOTTOMLEFT" },
    { set = "file", key = ART .. "UI-TalentFrame-BotRight", layer = "BORDER", w = 128, h = 256, point = "BOTTOMRIGHT" },
}
-- The skill bars' rim cut in three, so its round ends keep their shape at any length.
local CAP = 14
local RIM = { layer = "ARTWORK", key = "skillsBarBorder", cap = CAP, ox = 5, oy = 5,
    coords = { { 0, CAP / 256, 0, 1 }, { CAP / 256, 1 - CAP / 256, 0, 1 }, { 1 - CAP / 256, 1, 0, 1 } } }
local FOOT_ON = { layer = "BACKGROUND", key = "tabActive", cap = 20, height = 35, middle = "edge",
    coords = { { 0, 0.15625, 0, 0.546875 }, { 0.15625, 0.84375, 0, 0.546875 }, { 0.84375, 1, 0, 0.546875 } } }
local FOOT_OFF = { layer = "BACKGROUND", key = "tabInactive", cap = 20, height = 32, oy = -4, middle = "edge",
    coords = { { 0, 0.15625, 0, 1 }, { 0.15625, 0.84375, 0, 1 }, { 0.84375, 1, 0, 1 } } }
local TAB_HL = { coords = { 0, 1, 0, 1 }, point = "TOPLEFT", x = 3, y = 5, point2 = "BOTTOMRIGHT", x2 = -3, y2 = 0, blend = "ADD" }
local RESET_TIP = { text = function() return TALENT_FRAME_RESET_BUTTON_TOOLTIP_TITLE or "Reset Pending Changes" end }
local TREE_EVENTS = { "TRAIT_CONFIG_UPDATED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_NODE_CHANGED", "PLAYER_TALENT_UPDATE",
    "ACTIVE_COMBAT_CONFIG_CHANGED", "PLAYER_LEVEL_UP" }
local WORD_EVENTS = { "TOOLTIP_DATA_UPDATE" }

--------------------------------------------------------------- the pieces

-- Pieces are handed out in pool order and all taken back at once.
local function Acquire(pool, parent, file)
    local n = (pool.n or 0) + 1
    pool.n = n
    local tex = pool[n]
    if not tex then
        tex = parent:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(file)
        pool[n] = tex
    end
    return tex
end

local function ReleaseAll(pool)
    for _, tex in ipairs(pool) do tex:Hide() end
    pool.n = 0
end

local function CellX(column) return START_X + column * PITCH end
local function CellY(tier) return -(START_Y + tier * PITCH) end

local function BranchPiece(child, lit, kind, x, y, w, h)
    local tex = Acquire(branchPool, child, BRANCHES)
    tex:SetTexCoord(unpack(BRANCH[kind][lit]))
    ns.SetPointOnce(tex, "TOPLEFT", child, "TOPLEFT", x, y)
    tex:SetSize(w, h)
    tex:Show()
end

local function BranchArrow(child, lit, kind, x, y)
    local tex = Acquire(arrowPool, frame.arrows, ARROWS)
    tex:SetTexCoord(unpack(ARROW[kind][lit]))
    ns.SetPointOnce(tex, "TOPLEFT", child, "TOPLEFT", x, y)
    tex:SetSize(32, 32)
    tex:Show()
end

-- A run of branch between two places, and the arrow into the second.
local function DrawEdge(child, from, to, lit)
    local fx, fy, tx, ty = CellX(from.column), CellY(from.tier), CellX(to.column), CellY(to.tier)
    local half = BUTTON / 2
    if from.tier == to.tier then
        -- Along the row.
        local right = to.column > from.column
        local x1 = (right and fx + BUTTON or tx + BUTTON) - 2
        local x2 = (right and tx or fx) + 2
        BranchPiece(child, lit, "horizontal", x1, fy - half + 16, math.max(1, x2 - x1), 32)
        BranchArrow(child, lit, right and "right" or "left", right and (tx - 20) or (tx + BUTTON - 12), ty - half + 16)
    else
        -- Across first where the columns differ, then down.
        if from.column ~= to.column then
            local right = to.column > from.column
            local x1 = right and (fx + BUTTON - 2) or (tx + half - 16)
            local x2 = right and (tx + half + 16) or (fx + 2)
            BranchPiece(child, lit, "horizontal", x1, fy - half + 16, math.max(1, x2 - x1), 32)
            BranchPiece(child, lit, "vertical", tx + half - 16, fy - half, 32, math.max(1, (fy - half) - ty - 2))
        else
            BranchPiece(child, lit, "vertical", tx + half - 16, fy - BUTTON + 2, 32, math.max(1, (fy - BUTTON) - ty + 4))
        end
        BranchArrow(child, lit, "down", tx + half - 16, ty + 20)
    end
end

-- Old tooltip: name, rank, unmet needs in red, rank text, then "Next rank".
-- Text goes in as plain lines: passed as tooltip data, the client later redrew
-- the tooltip from that data alone and dropped the rest.
local function AddDescription(entryID, rank)
    if not (entryID and C_TooltipInfo and C_TooltipInfo.GetTraitEntry) then return false end
    local ok, data = pcall(C_TooltipInfo.GetTraitEntry, entryID, rank)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return false end
    for _, line in ipairs(data.lines) do
        local text, right = line.leftText, line.rightText
        if type(text) == "string" and text ~= "" and not IsSecret(text) then
            local color = line.leftColor
            local r, g, b = color and color.r or 1, color and color.g or 0.82, color and color.b or 0
            if type(right) == "string" and right ~= "" and not IsSecret(right) then
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

-- Talent text can arrive late: rewrite on TOOLTIP_DATA_UPDATE, registered only
-- while a talent tooltip can be up.
local words
local wordsOn = false
local function HearWords(on)
    if not words or wordsOn == on then return end
    if on then
        wordsOn = ns.RegisterEvents(words, WORD_EVENTS) > 0
    else
        wordsOn = false
        words:UnregisterEvent("TOOLTIP_DATA_UPDATE")
    end
end

local function Button_OnEnter(self)
    local talent = self.talent
    local tree = frame and frame.tree
    if not talent or not tree then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local name = talent.spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(talent.spellID)
    frame.hovered = self
    HearWords(true)
    if not name or not (C_TooltipInfo and C_TooltipInfo.GetTraitEntry) then
        -- A client without the talent text: the spell's own tooltip.
        if talent.spellID and GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(talent.spellID) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format(TOOLTIP_TALENT_RANK or "Rank %d/%d", talent.rank, talent.maxRank), 1, 1, 1)
    else
        GameTooltip:SetText(name, 1, 1, 1)
        GameTooltip:AddLine(string.format(TOOLTIP_TALENT_RANK or "Rank %d/%d", talent.rank, talent.maxRank), 1, 1, 1)
        -- Unmet needs: points in the tree first.
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
    -- A filled square under the icon: only its edge shows, tinted by state.
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
        HearWords(false)
    end)
    button:SetScript("OnClick", Button_OnClick)
    buttons[index] = button
    return button
end

-- One tab face as a list { left, right, middle }.
local function FootFace(tab, spec)
    local left, middle, right = ns.ThreeSlice(tab, nil, spec)
    return { left, right, middle }
end

-- Our own foot tab: the client template resizes and moves its tabs on every
-- pick (it cut ours to "B...").
local function FootTab(parent)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetHeight(32)
    tab.on = FootFace(tab, FOOT_ON)
    tab.off = FootFace(tab, FOOT_OFF)
    -- One point and no width: the label is always its whole text.
    tab.label = tab:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    tab.label:SetPoint("CENTER", tab, "CENTER", 0, -3)
    ns.Dress(ns.SetButtonTex(tab, "Highlight", "tabHighlight"), nil, TAB_HL, tab)
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
    local tree = TL.ReadTree(inspectUnit)
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
    -- Lower files are 128 tall but painted for 75 rows (the old cut); drawn whole
    -- they left the tree's foot bare.
    local top, bottom = height * 256 / 331, height * 75 / 331
    local art = frame.background
    for key, piece in pairs(art) do
        if name then
            if backgroundName ~= name then piece:SetTexture(ART .. name .. "-" .. key) end
            piece:Show()
        else
            piece:Hide()
        end
    end
    if name then backgroundName = name end
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
        ns.SetPointOnce(button, "TOPLEFT", child, "TOPLEFT", CellX(talent.column), CellY(talent.tier))
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

-- Next-frame refresh after a tree change.
local function RefreshIfShown()
    if frame:IsShown() then Refresh() end
end

local function Build()
    if frame then return frame end
    frame = CreateFrame("Frame", "ClassicUIForeverTalents", UIParent)
    frame:SetSize(WINDOW_W, WINDOW_H)
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    -- Movable like the quest log; the window placer leaves a moved window where it was put.
    ns.MakeDraggable(frame)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
    frame:Hide()
    ns.CloseWithGameMenu(frame)

    ns.DressPieces(frame, TALENT_QUARTERS)

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

    -- Points spent in the tree, on a dark bar with the old round-ended grey rim.
    local spentBar = CreateFrame("Frame", nil, frame)
    spentBar:SetSize(258, 13)
    spentBar:SetPoint("TOP", frame, "TOP", 12, -48)
    local spentFill = spentBar:CreateTexture(nil, "BACKGROUND")
    spentFill:SetColorTexture(0, 0, 0, 0.6)
    spentFill:SetPoint("TOPLEFT", spentBar, "TOPLEFT", 1, 0)
    spentFill:SetPoint("BOTTOMRIGHT", spentBar, "BOTTOMRIGHT", -1, 0)
    ns.ThreeSlice(spentBar, nil, RIM)
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
    ns.ScrollColumnOn(frame.bar)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        frame.bar:SetValue((frame.bar:GetValue() or 0) - delta * 30)
    end)

    -- Foot: undo, points-left box, Apply Changes, fixed sizes so nothing moves when
    -- a point is staged; buttons grey until needed; Escape and the X close. The old
    -- art's painted points box is covered with stone.
    local foot = CreateFrame("Frame", nil, frame)
    foot:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -409)
    -- To the border's inner edge (340 in the old art); 352 ran past the window's side.
    foot:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", 340, -435)
    local footStone = foot:CreateTexture(nil, "BACKGROUND")
    footStone:SetAllPoints(foot)
    ns.TileTex(footStone, "rockBg")

    -- Undo and Apply at opposite ends: side by side, a slip undid points meant to be applied.
    frame.reset = ns.PanelButton(foot, "", 28)
    frame.reset:SetPoint("TOPLEFT", frame, "TOPLEFT", 17, -411)
    -- The arrow, small enough to sit inside the button with room round it.
    local undo = frame.reset:CreateTexture(nil, "OVERLAY")
    undo:SetSize(13, 13)
    undo:SetPoint("CENTER", frame.reset, "CENTER", 0, 0)
    if not (undo.SetAtlas and pcall(undo.SetAtlas, undo, "talents-button-undo")) or not undo:GetAtlas() then
        ns.SetFile(undo, "Interface/Buttons/UI-RotationLeft-Button-Up")
    end
    frame.undoIcon = undo
    frame.reset:SetScript("OnClick", function()
        local tree = frame.tree
        if tree and C_Traits.RollbackConfig then pcall(C_Traits.RollbackConfig, tree.configID) end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        Refresh()
    end)
    frame.reset:SetMotionScriptsWhileDisabled(true)
    ns.AttachTip(frame.reset, RESET_TIP)

    local pointsBox = ns.SkillInsetBox(foot, 16, true, 0.55)
    pointsBox:SetPoint("LEFT", frame.reset, "RIGHT", 2, 0)
    pointsBox:SetSize(196, 24)
    frame.points = pointsBox:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.points:SetPoint("RIGHT", pointsBox, "RIGHT", -10, 0)

    frame.learn = ns.PanelButton(foot, "Apply Changes", 104)
    frame.learn:SetPoint("LEFT", pointsBox, "RIGHT", 1, 0)
    frame.learn:SetScript("OnClick", function()
        local tree = frame.tree
        if not tree or InCombatLockdown() then return end
        if C_ClassTalents and C_ClassTalents.CommitConfig then
            -- nil like the client's window with no loadout picked: commits the talents in
            -- use. Given the active config, the client refused and then applied anyway.
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
        -- Hidden and shown in one go (inspect to own) with a talent tooltip up: keep listening.
        if frame.hovered then HearWords(true) end
        if SetPortraitTexture then SetPortraitTexture(frame.portrait, inspectUnit or "player") end
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        Refresh()
    end)
    frame:SetScript("OnHide", function()
        inspectUnit = nil
        if inspectWatch then inspectWatch:Hide() end
        HearWords(false)
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    end)
    -- Inspect talents sit beside the inspect window and close with it: the client
    -- drops the data then.
    frame.fcuiKeep = function()
        return inspectUnit and _G["InspectFrame"] or nil
    end
    inspectWatch = CreateFrame("Frame", nil, frame)
    inspectWatch:Hide()
    ns.Sched.OnFrame(inspectWatch, { name = "talents.inspect", every = 0.2, fn = function()
        if not inspectUnit then return end
        local inspect = _G["InspectFrame"]
        if not (inspect and inspect:IsShown()) then frame:Hide() end
    end })
    -- After the window's own SetScripts, which wipe earlier hooks (it then opened
    -- over vendors, mail and the spellbook, and lost Escape).
    ns.RegisterClassicWindow(frame, true)
    -- Escape shuts the window before the client drops the target.
    ns.CloseOnEscape(frame)

    -- A change to the tree is a burst of events: one refresh, next frame.
    ns.EventFrame(TREE_EVENTS, function()
        if not frame:IsShown() then return end
        ns.Sched.NextFrame("talents.refresh", RefreshIfShown)
    end)
    -- Signed up for only while a talent's tooltip can be up (HearWords).
    words = CreateFrame("Frame")
    words:SetScript("OnEvent", function(self)
        local button = frame.hovered
        if not button or not frame:IsShown() or not GameTooltip:IsOwned(button) then return end
        local now = GetTime()
        if self.last and now - self.last < 0.2 then return end
        self.last = now
        Button_OnEnter(button)
    end)
    return frame
end

------------------------------------------------------------- the way in

local function Toggle()
    Build()
    if frame:IsShown() and inspectUnit then
        -- Up on someone else's talents: the key turns it to the player's.
        inspectUnit = nil
        inspectWatch:Hide()
        frame:Hide()
        frame:Show()
    elseif frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

-- Public API (Core/API.lua): the player's talents shown, on tree tab if given.
function ns.ShowTalents(tab)
    if not active then return false end
    Build()
    if inspectUnit then
        inspectUnit = nil
        if inspectWatch then inspectWatch:Hide() end
        frame:Hide()
    end
    if not frame:IsShown() then frame:Show() end
    local button = type(tab) == "number" and frame.tabs[tab]
    if button and button:IsShown() then button:Click() end
    return frame:IsShown()
end

-- The inspect window's Talents button, which opened the client's window.
local function ShowInspect(unit)
    if not unit then return end
    Build()
    if frame:IsShown() then frame:Hide() end
    inspectUnit = unit
    inspectWatch:Show()
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
ns.EventFrame("ADDON_LOADED", function(_, _, name)
    if name == "Blizzard_InspectUI" and active then TakeInspectButton(true) end
end)

-- Talents micro button and key open this window while on. Both client buttons:
-- this client shows TalentMicroButton; taking only PlayerSpellsMicroButton
-- (never shown) left the visible one opening the client's window.
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
        bindButton:SetScript("OnClick", function()
            -- Once a press, whichever half the game sends.
            local now = GetTime()
            if bindButton.last and now - bindButton.last < 0.2 then return end
            bindButton.last = now
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
