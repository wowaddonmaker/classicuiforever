local _, ns = ...

-- Lower section of the old skills tab (bar, words, unlearn), moved from the dropped side pane.

local T = ns.sheet
local Take, Own, Fade = T.Take, T.Own, T.Fade
local SkinListEntry, KnobSeen, TakeThumb = T.SkinListEntry, T.KnobSeen, T.TakeThumb

local DETAIL_H = 124
T.DETAIL_H = DETAIL_H
local FOOT_H = 26          -- the grey strip with the Close button
local SCROLL_COLUMN = 22   -- the description's scroll bar column at the right
-- The description's bar in its column as the list's bar sits in its own art (column-relative; arrows bar-relative, our
-- arrow art stands 1 right of its button); the knob runs this far past the track's ends to meet the arrows.
local DESC_BAR_X = 12
local DESC_BAR_TOP = -9
local DESC_BAR_FOOT = 8
local DESC_UP_X = 2
local DESC_UP_Y = 4
local DESC_DOWN_X = 2
local DESC_DOWN_Y = -4
local DESC_KNOB_REACH = 7

local CANCEL = "Interface\\Buttons\\CancelButton-"
local CANCEL_UP, CANCEL_DOWN, CANCEL_HIGHLIGHT = CANCEL .. "Up", CANCEL .. "Down", CANCEL .. "Highlight"
-- The art is mostly margin: the mouse is taken over the square only.
local UNLEARN = { set = "raw", add = true, hit = { 9, 9, 9, 9 } }
local FOOT_STONE = { shade = { 1.25, 1.2, 1.1 } }

ns.Popup("FCUI_UNLEARN_SKILL", {
    text = UNLEARN_SKILL_PROMPT or "Unlearn %s?",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function(_, skillID)
        if C_SkillInfo and C_SkillInfo.AbandonSkill and skillID then pcall(C_SkillInfo.AbandonSkill, skillID) end
    end,
    showAlert = 1,
    preferredIndex = false,
})

-- The picked skill, as the client's own detail pane reads it.
local function SelectedSkill()
    if not (C_SkillInfo and C_SkillInfo.GetSelectedSkill and C_SkillInfo.GetSkillLineInfo) then return nil end
    local ok, index = pcall(C_SkillInfo.GetSelectedSkill)
    if not ok or not index or index <= 0 then return nil end
    local fine, info = pcall(C_SkillInfo.GetSkillLineInfo, index)
    if not fine or type(info) ~= "table" or info.isHeader then return nil end
    return info
end

-- Forever's weapon skill breakdown (its SkillsFrame.lua math and strings) under the words, where the client's own rows
-- overran the window: hit and crit against an equal-level enemy and a raid boss, glancing blows in melee.
local RANKS_PER_LEVEL, BOSS_LEVELS = 5, 3
-- Skill line -> ranged.
local WEAPON_LINES = { [43] = false, [44] = false, [45] = true, [46] = true, [54] = false, [55] = false, [136] = false,
    [160] = false, [172] = false, [173] = false, [176] = true, [226] = true, [228] = true, [229] = false, [162] = false,
    [3014] = false }

local function SkillGap(levels, skill)
    return ((UnitLevel("player") or 1) + levels) * RANKS_PER_LEVEL - skill
end

local function Signed(value)
    if value == 0 then value = 0 end
    local text = string.format("%.2f%%", value)
    return value > 0 and "+" .. text or text
end

local function GlancingChance(skill)
    skill = math.min((UnitLevel("player") or 1) * RANKS_PER_LEVEL, skill)
    return math.max(-100, math.min(100, (0.02 * SkillGap(BOSS_LEVELS, skill) + 0.1) * 100))
end

local function GlancingPenalty(skill)
    local gap = SkillGap(BOSS_LEVELS, skill)
    local low = 1.30 - 0.05 * gap + (gap > 10 and 0.1 or 0)
    low = math.max(0.01, math.min(low, 0.91))
    local high = 1.20 - 0.03 * gap + (gap > 10 and 0.1 or 0)
    high = math.min(0.99, math.max(high, 0.20))
    return 100 - math.max(0, math.min(1, (low + high) / 2)) * 100
end

local function Heading(text)
    return "|cffffffff" .. text .. "|r"
end

local function Row(text)
    return NORMAL_FONT_COLOR and NORMAL_FONT_COLOR:WrapTextInColorCode(text) or text
end

-- The lines under a weapon skill's words, or nil.
local function WeaponDetail(info)
    local ranged = info and WEAPON_LINES[info.skillID]
    if ranged == nil or not (ns.db and ns.db.weaponSkillDetail ~= false) then return nil end
    local skill = (info.rank or 0) + (info.modifier or 0)
    local same, boss = Signed(SkillGap(0, skill) * -0.04), Signed(SkillGap(BOSS_LEVELS, skill) * -0.04)
    local sameText = ranged and WEAPON_SKILL_DETAIL_SAME_LEVEL_RANGED or WEAPON_SKILL_DETAIL_SAME_LEVEL
    local bossText
    if ranged then
        bossText = WEAPON_SKILL_DETAIL_BOSS_RANGED and WEAPON_SKILL_DETAIL_BOSS_RANGED:format(boss, boss)
    else
        bossText = WEAPON_SKILL_DETAIL_BOSS and WEAPON_SKILL_DETAIL_BOSS:format(boss, boss,
            string.format("%.0f%%", GlancingChance(skill)), string.format("%.0f%%", GlancingPenalty(skill)))
    end
    if not (sameText and bossText and WEAPON_SKILL_DETAIL_SAME_LEVEL_HEADER and WEAPON_SKILL_DETAIL_BOSS_HEADER) then
        return nil
    end
    return table.concat({ Heading(WEAPON_SKILL_DETAIL_SAME_LEVEL_HEADER), Row(sameText:format(same, same)), "",
        Heading(WEAPON_SKILL_DETAIL_BOSS_HEADER), Row(bossText) }, "\n")
end

-- The old short line: the client's string of that name is now the whole warning.
local function UnlearnTip()
    local line = UNLEARN_SKILL_TOOLTIP
    if type(line) ~= "string" or #line > 40 then line = "Unlearn this profession" end
    return line
end
local UNLEARN_TIP = { text = UnlearnTip, r = 1, g = 0.82, b = 0 }

local function UnlearnClick()
    local picked = SelectedSkill()
    if picked and picked.isAbandonable and StaticPopup_Show then
        StaticPopup_Show("FCUI_UNLEARN_SKILL", picked.name, nil, picked.skillID)
    end
end

local function CloseClick()
    if HideUIPanel and CharacterFrame then HideUIPanel(CharacterFrame) end
end

local TakeAlpha = T.TakeAlpha
local function TakeButton(button)
    if not button then return end
    Take(button, "size", "points")
    Take(button.Texture, "alpha")
end
local function ShowArrow(button)
    local arrow = button and button.fcui and button.fcui.arrow
    if arrow then Own(arrow):Show() end
end

local function SkinSkillDetail()
    -- Also reached from the client's pane and tab, which outlive the sheet.
    if not T.active then return end
    local skills = SkillsFrame
    local detail = skills and skills.SkillDetailFrame
    if not detail or not CharacterFrame then return end
    local onSkills = skills:IsShown() and true or false
    -- Visibility is not taken: a Show from here would run the pane's refresh tainted.
    Take(detail, "parent", "size", "points", "level", "clips")
    detail:SetParent(CharacterFrame)
    detail:ClearAllPoints()
    -- Full width inside the art; 2 taller so the grey foot meets the window's bottom edge.
    detail:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMLEFT", 20, 84)
    detail:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -44, 84)
    detail:SetHeight(DETAIL_H + 2)
    detail:SetFrameLevel(CharacterFrame:GetFrameLevel() + 6)
    detail:SetClipsChildren(true)

    -- No fill: the window's own textured background shows, as in 1.x.
    local backing = ns.OwnTexture(detail, "backing", "BACKGROUND")
    backing:SetAllPoints(detail)
    backing:Hide()

    -- A stone bar between the list and the section.
    local divider = detail.fcuiDivider
    if not divider then
        divider = ns.StoneBar(CharacterFrame)
        detail.fcuiDivider = divider
    end
    if divider then
        Own(divider)
        divider:ClearAllPoints()
        divider:SetPoint("BOTTOM", detail, "TOP", 0, 6)
        divider:SetPoint("LEFT", detail, "LEFT", -2, 0)
        divider:SetPoint("RIGHT", detail, "RIGHT", -SCROLL_COLUMN - 2, 0)
        -- Up with the skills tab only; the pane's own shown state is set at the end.
        divider:SetShown(onSkills)
        if ns.Once(divider, "follows") then
            detail:HookScript("OnHide", function() divider:Hide() end)
        end
    end

    -- The name goes on the bar, as in the list above.
    if detail.Title then Fade(detail.Title) end
    if detail.Subtitle then Fade(detail.Subtitle) end

    local info = SelectedSkill()
    if detail.RankBar then
        local host = detail.fcuiBarHost
        if not host then
            host = CreateFrame("Frame", nil, detail)
            host.Content = { SkillsBar = detail.RankBar }
            detail.fcuiBarHost = host
        end
        SkinListEntry(host, "SkillsBar")
        local name = detail.RankBar.fcui and detail.RankBar.fcui.name
        if name then name:SetText(info and info.name or "") end
        -- Narrower than the list's bars: the unlearn button stands at its end.
        detail.RankBar:ClearAllPoints()
        detail.RankBar:SetPoint("TOPLEFT", detail, "TOPLEFT", 46, -12)
        detail.RankBar:SetPoint("RIGHT", detail, "RIGHT", -70, 0)
        -- Its fill was sized for the width it had before this move.
        T.FitFill(detail.RankBar)
    end

    -- Measure only, never drawn: the words' box, clear of the scroll column and grey foot.
    local box = ns.OwnTexture(detail, "descBox", "BACKGROUND", 1)
    box:SetColorTexture(0, 0, 0, 0)
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", detail, "TOPLEFT", 2, -38)
    box:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -SCROLL_COLUMN, FOOT_H + 2)
    box:Hide()
    if detail.Description then
        Take(detail.Description, "points", "font")
        detail.Description:ClearAllPoints()
        detail.Description:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -4)
        detail.Description:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6, 4)
        pcall(detail.Description.SetFontObject, detail.Description, "GameFontHighlightSmall")
        -- Wrapped at the whole pane's width and moving does not rewrap: give them the box's.
        local scroll = detail.Description.ScrollBox
        local holder = scroll and scroll.FontStringContainer
        local words = holder and holder.FontString
        if words then
            Take(words, "width")
            Take(holder, "size")
            -- The client's words again when the detail is off or the skill has none.
            local words0 = info and info.description
            if type(words0) == "string" and words0 ~= "" then
                local extra = WeaponDetail(info)
                words:SetText(extra and (words0 .. "\n\n" .. extra) or words0)
            end
            local width = (CharacterFrame:GetWidth() or 384) - 20 - 44 - 2 - SCROLL_COLUMN - 12
            words:SetWidth(width)
            holder:SetWidth(width)
            local tall = words:GetStringHeight()
            if tall and tall > 0 then holder:SetHeight(tall) end
            if scroll.FullUpdate then pcall(scroll.FullUpdate, scroll, ScrollBoxConstants and ScrollBoxConstants.UpdateImmediately) end
        end
    end
    -- The list's scroll column continues down to the grey foot; on the window, as the pane clips.
    local column = detail.fcuiColumn
    if not column then
        column = CreateFrame("Frame", nil, CharacterFrame)
        column:SetWidth(31)
        local top = column:CreateTexture(nil, "BACKGROUND", nil, 1)
        ns.SetTex(top, "charScrollBar")
        top:SetPoint("TOPLEFT", column, "TOPLEFT", 0, 0)
        top:SetPoint("TOPRIGHT", column, "TOPRIGHT", 0, 0)
        local bottom = column:CreateTexture(nil, "BACKGROUND", nil, 1)
        ns.SetTex(bottom, "charScrollBar")
        bottom:SetPoint("BOTTOMLEFT", column, "BOTTOMLEFT", 0, 0)
        bottom:SetPoint("BOTTOMRIGHT", column, "BOTTOMRIGHT", 0, 0)
        column.top, column.bottom = top, bottom
        detail.fcuiColumn = column
        detail:HookScript("OnShow", function() if T.active then column:Show() end end)
        detail:HookScript("OnHide", function() column:Hide() end)
    end
    Own(column)
    -- Grey foot up to the divider's top, meeting the list track's foot.
    local tall = DETAIL_H + 2 - FOOT_H + 10
    local half = math.floor(tall / 2)
    column:SetFrameLevel(detail:GetFrameLevel() + 1)
    column:ClearAllPoints()
    -- 8 left of the list's bar, measured: the list is a scaled frame.
    local x = -68
    local listBar = skills.ScrollBar
    local barLeft, right = listBar and listBar:GetLeft(), CharacterFrame:GetRight()
    if barLeft and right then x = barLeft - 8 - right end
    column:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMRIGHT", x, 84 + FOOT_H)
    column:SetHeight(tall)
    column.top:SetHeight(half)
    column.top:SetTexCoord(0, 0.484375, 0, half / 256)
    column.bottom:SetHeight(tall - half)
    column.bottom:SetTexCoord(0.515625, 1, (108 - (tall - half)) / 256, 108 / 256)
    column:SetShown(onSkills)
    local descBar = detail.DescriptionScrollBar
    if descBar then
        -- The shared thin bar dress, with what it takes kept first.
        local track = descBar.Track
        if track then
            ns.EachKey(track, ns.KEYS.THUMB, TakeAlpha)
            TakeThumb(track)
        end
        TakeButton(descBar.Back)
        TakeButton(descBar.Forward)
        T.descBar = descBar
        ns.SkinMinimalScrollBar(descBar)
        KnobSeen(descBar, true)
        ShowArrow(descBar.Back)
        ShowArrow(descBar.Forward)
        -- On the column, not the pane: the pane clips, and the up arrow stands above its top in the column's head.
        Take(descBar, "parent", "points", "level")
        descBar:SetParent(column)
        descBar:SetFrameLevel(column:GetFrameLevel() + 1)
        descBar:ClearAllPoints()
        descBar:SetPoint("TOP", column, "TOPLEFT", DESC_BAR_X, DESC_BAR_TOP)
        descBar:SetPoint("BOTTOM", column, "BOTTOMLEFT", DESC_BAR_X, DESC_BAR_FOOT)
        if descBar.Back then ns.SetPointOnce(descBar.Back, "TOP", descBar, "TOP", DESC_UP_X, DESC_UP_Y) end
        if descBar.Forward then ns.SetPointOnce(descBar.Forward, "BOTTOM", descBar, "BOTTOM", DESC_DOWN_X, DESC_DOWN_Y) end
        ns.KnobReach(descBar, DESC_KNOB_REACH)
    end

    -- The old skills window's foot: grey stone with Close at its right.
    local foot = detail.fcuiFoot
    if not foot then
        foot = CreateFrame("Frame", nil, detail)
        local stone = ns.TileTex(foot:CreateTexture(nil, "BACKGROUND", nil, 2), "rockBg", FOOT_STONE)
        stone:SetAllPoints(foot)
        local line = foot:CreateTexture(nil, "BORDER")
        line:SetColorTexture(0.52, 0.48, 0.40, 1)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", foot, "TOPLEFT", 0, 0)
        line:SetPoint("TOPRIGHT", foot, "TOPRIGHT", 0, 0)
        local close = ns.PanelButton(foot, CLOSE or "Close", 80)
        close:SetPoint("RIGHT", foot, "RIGHT", -2, 0)
        close:SetScript("OnClick", CloseClick)
        detail.fcuiFoot = foot
    end
    Own(foot):Show()
    foot:ClearAllPoints()
    foot:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", 0, 0)
    foot:SetHeight(FOOT_H)
    -- Weapon skill hit/crit tables: not in 1.x, and they overrun the window.
    if detail.Content then
        Take(detail.Content, "shown")
        detail.Content:Hide()
    end

    local unlearn = detail.fcuiUnlearn
    if not unlearn then
        unlearn = CreateFrame("Button", nil, detail)
        unlearn:SetSize(32, 32)
        ns.DressStates(unlearn, CANCEL_UP, CANCEL_DOWN, nil, CANCEL_HIGHLIGHT, UNLEARN)
        ns.AttachTip(unlearn, UNLEARN_TIP)
        unlearn:SetScript("OnClick", UnlearnClick)
        detail.fcuiUnlearn = unlearn
    end
    Own(unlearn)
    unlearn:ClearAllPoints()
    if detail.RankBar then
        unlearn:SetPoint("LEFT", detail.RankBar, "RIGHT", 0, 0)
    else
        unlearn:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -8, -10)
    end
    unlearn:SetShown(info ~= nil and info.isAbandonable == true)
    detail:SetShown(onSkills)
    -- The side pane sweep quiets it while the tab is shut and only runs again when the client reshows its pieces:
    -- held open here, on every open and pick.
    if onSkills then ns.KeepSidePane(detail) end
end
T.SkinSkillDetail = SkinSkillDetail
ns.OnToggle(function(key)
    if key == "weaponSkillDetail" then ns.SafeCall(SkinSkillDetail) end
end)
