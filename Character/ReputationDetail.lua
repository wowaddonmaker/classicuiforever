local _, ns = ...

-- Old reputation detail box off the sheet's right edge: description, At War, Inactive, Watch.
-- A faction click answers here: the client's right pane stays put away (closing it clears the selection).

local T = ns.sheet

local repDetail
local repFactionID
local MarkRepRows   -- assigned at the first build: it works on that box

local PAGE_COORDS = { 0, 0.58, 0, 0.3 }
local SEGMENT_BG = { bg = { 0, 0, 0, 1 } }
local REP_MARK = {
    -- Cut at row 27: cutting at the cap's top line (row 32) drew a faint dash.
    { key = "repHighlight", layer = "OVERLAY", coords = { 0, 1, 0, 27 / 64 }, w = 256, h = 27, blend = "ADD", point = "TOPLEFT", x = -2, y = 3 },
    { key = "repHighlight", layer = "OVERLAY", coords = { 0, 0.0625, 0.4375, 0.9375 }, w = 16, h = 32, blend = "ADD", point = "TOPLEFT", relPoint = "TOPRIGHT", chain = true },
}

local function RepIndexOf(factionID)
    if not factionID or not C_Reputation or not C_Reputation.GetNumFactions then return nil end
    for index = 1, C_Reputation.GetNumFactions() do
        local data = C_Reputation.GetFactionDataByIndex(index)
        if data and data.factionID == factionID then return index, data end
    end
end

local function RepCheck(parent, label, r, g, b)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    ns.SkinCheckbox(check)
    local text = check.Text or check.text
    if not text then
        text = check:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        text:SetPoint("LEFT", check, "RIGHT", 0, 1)
    end
    text:SetFontObject("GameFontNormalSmall")
    text:SetText(label)
    text:SetTextColor(r, g, b)
    check.label = text
    check:SetHitRectInsets(0, -math.min(120, (text:GetStringWidth() or 60)), 0, 0)
    return check
end

local function CheckSound(check)
    PlaySound(check:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
end

local function RefreshRepDetail()
    if not repDetail or not repDetail:IsShown() then return end
    local index, data = RepIndexOf(repFactionID)
    if not index then
        repDetail:Hide()
        return
    end
    repDetail.index = index
    repDetail.name:SetText(data.name or "")
    repDetail.text:SetText(data.description or "")
    local canWar = data.canToggleAtWar and not data.isHeader
    repDetail.war:SetEnabled(canWar and true or false)
    repDetail.war:SetChecked(data.atWarWith and true or false)
    if canWar then repDetail.war.label:SetTextColor(1, 0.1, 0.1) else repDetail.war.label:SetTextColor(0.5, 0.5, 0.5) end
    repDetail.inactive:SetEnabled(data.canSetInactive and true or false)
    repDetail.inactive:SetChecked(C_Reputation.IsFactionActive and not C_Reputation.IsFactionActive(index) or false)
    if data.canSetInactive then repDetail.inactive.label:SetTextColor(1, 0.82, 0) else repDetail.inactive.label:SetTextColor(0.5, 0.5, 0.5) end
    repDetail.watch:SetChecked(data.isWatched and true or false)
end

-- The watch box back in play once the bars have settled.
local function ReleaseWatch(box)
    box.watchHeldAt = nil
    box.watch:Enable()
    box.watch.label:SetTextColor(1, 0.82, 0)
    box.hold:Sleep()
end

-- Per frame while resting: settled once the wanted bar is up (or gone) and nothing moves;
-- idle alone released it before the client began. At most 3 s.
local function HoldTick(job)
    local box = job.host:GetParent()
    if not box.watchHeldAt then
        job:Sleep()
        return
    end
    local held = GetTime() - box.watchHeldAt
    local busy = ns.StatusBarsBusy()
    local there = ns.StatusBarsShowFaction() == box.watchWanted
    if held > 3 or (held > 0.1 and there and not busy) then
        ReleaseWatch(box)
        RefreshRepDetail()
    end
end

-- Gone with the reputation tab, and the row mark kept in step with the list.
local function BeatTick(job)
    local box = job.host:GetParent()
    if not (ReputationFrame and ReputationFrame:IsVisible()) then
        box:Hide()
        return
    end
    MarkRepRows()
end

-- The chosen row gets the old yellow line, cut like the plate (strip and cap).
local function MarkRow(row)
    local mark = row.fcuiRepMark
    local chosen = row.elementData and row.elementData.factionID == repFactionID
    local bar = row.Content and row.Content.ReputationBar
    local plate = bar and bar.fcui and bar.fcui.plateLeft
    if chosen and not mark and plate then
        mark = CreateFrame("Frame", nil, bar)
        mark:SetAllPoints(bar)
        mark:SetFrameLevel(bar:GetFrameLevel() + 3)
        ns.DressPieces(mark, REP_MARK, plate)
        row.fcuiRepMark = mark
    end
    if mark then mark:SetShown((chosen and repDetail:IsShown()) and true or false) end
end

local function HideMark(row)
    if row.fcuiRepMark then row.fcuiRepMark:Hide() end
end

-- Refresh on the client's update, not a fixed delay after a click (a box ticked itself back off).
-- Registered while shut too, so a reopened box is current.
local function FactionUpdate() ns.Sched.NextFrame("sheet.repRefresh", RefreshRepDetail) end

local function BoxHidden(box)
    -- Hidden mid-rest: release so it reopens ready.
    if box.watchHeldAt then ReleaseWatch(box) end
    local scrollBox = ReputationFrame and ReputationFrame.ScrollBox
    if scrollBox and scrollBox.ForEachFrame then pcall(scrollBox.ForEachFrame, scrollBox, HideMark) end
end

-- The old detail box: parchment above, stone below, name, words and a close button; content holds the checks.
function T.NewDetailBox(name, parent)
    local box = CreateFrame("Frame", name, parent, ns.BACKDROP_TEMPLATE)
    box:SetSize(212, 203)
    box:SetFrameLevel(parent:GetFrameLevel() + 30)
    box:EnableMouse(true)
    box:Hide()
    -- Two iron-bordered segments like the old box, overlapping.
    local function Segment(top, bottom, level)
        local part = CreateFrame("Frame", nil, box, ns.BACKDROP_TEMPLATE)
        part:SetPoint("TOPLEFT", box, "TOPLEFT", 0, top)
        part:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", 0, bottom)
        part:SetFrameLevel(box:GetFrameLevel() + level)
        ns.Backdrop(part, ns.BACKDROP.DIALOG_INSET8, SEGMENT_BG)
        return part
    end
    local upper = Segment(0, -146, 0)
    local page = upper:CreateTexture(nil, "BORDER")
    page:SetTexture("Interface\\QuestFrame\\QuestBG")
    page:SetTexCoord(unpack(PAGE_COORDS))
    page:SetVertexColor(0.55, 0.47, 0.35)
    page:SetPoint("TOPLEFT", upper, "TOPLEFT", 10, -10)
    page:SetPoint("BOTTOMRIGHT", upper, "BOTTOMRIGHT", -10, 10)
    Segment(-134, -203, 1)
    -- The words and checks stand over both segments.
    local content = CreateFrame("Frame", nil, box)
    content:SetAllPoints(box)
    content:SetFrameLevel(box:GetFrameLevel() + 5)
    box.content = content

    box.name = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    box.name:SetPoint("TOPLEFT", box, "TOPLEFT", 20, -21)
    box.name:SetWidth(150)
    box.name:SetJustifyH("LEFT")
    box.text = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    box.text:SetPoint("TOPLEFT", box.name, "BOTTOMLEFT", 0, -2)
    box.text:SetSize(172, 96)
    box.text:SetJustifyH("LEFT")
    box.text:SetJustifyV("TOP")

    local close = CreateFrame("Button", nil, content)
    close:SetSize(32, 32)
    close:SetPoint("TOPRIGHT", box, "TOPRIGHT", -3, -3)
    ns.SkinCloseButton(close, true)
    close:SetScript("OnClick", function() box:Hide() end)
    return box, content
end

local function BuildRepDetail()
    if repDetail then return repDetail end
    local box, content = T.NewDetailBox("ClassicUIForeverReputationDetail", CharacterFrame)

    box.war = RepCheck(content, AT_WAR or "At War", 1, 0.1, 0.1)
    box.war:SetPoint("TOPLEFT", box, "TOPLEFT", 14, -143)
    box.war:SetScript("OnClick", function(self)
        CheckSound(self)
        if box.index and C_Reputation.ToggleFactionAtWar then C_Reputation.ToggleFactionAtWar(box.index) end
        C_Timer.After(1, RefreshRepDetail)
    end)
    box.inactive = RepCheck(content, MOVE_TO_INACTIVE or "Move to Inactive", 1, 0.82, 0)
    box.inactive:SetPoint("LEFT", box.war, "RIGHT", 52, 0)
    box.inactive:SetScript("OnClick", function(self)
        CheckSound(self)
        if box.index and C_Reputation.SetFactionActive then C_Reputation.SetFactionActive(box.index, not self:GetChecked()) end
        C_Timer.After(1, RefreshRepDetail)
    end)
    box.watch = RepCheck(content, SHOW_FACTION_ON_MAINSCREEN or "Show as Experience Bar", 1, 0.82, 0)
    box.watch:SetPoint("TOPLEFT", box.war, "BOTTOMLEFT", 0, 0)
    box.watch:SetScript("OnClick", function(self)
        CheckSound(self)
        if C_Reputation.SetWatchedFactionByIndex then C_Reputation.SetWatchedFactionByIndex(self:GetChecked() and box.index or 0) end
        -- The bars cross-fade; a click mid-fade stacked a second change, so rest greyed until settled.
        box.watchHeldAt = GetTime()
        box.watchWanted = self:GetChecked() and true or false
        self:Disable()
        self.label:SetTextColor(0.5, 0.5, 0.5)
        box.hold:Wake()
        C_Timer.After(1, RefreshRepDetail)
    end)

    box.hold = ns.Sched.OnFrame(CreateFrame("Frame", nil, box), { name = "sheet.repHold", every = 0, fn = HoldTick, awake = false })
    ns.Sched.OnFrame(CreateFrame("Frame", nil, box), { name = "sheet.repBeat", every = 0.2, fn = BeatTick })
    box:RegisterEvent("UPDATE_FACTION")
    box:SetScript("OnEvent", FactionUpdate)
    box:SetScript("OnHide", BoxHidden)
    -- Also run at the click and on redraws: the beat alone lagged the click.
    MarkRepRows = function()
        local scrollBox = ReputationFrame and ReputationFrame.ScrollBox
        if scrollBox and scrollBox.ForEachFrame then pcall(scrollBox.ForEachFrame, scrollBox, MarkRow) end
    end
    repDetail = box
    return box
end

-- Read after the client's own click handler, so nothing of its runs after us.
function ns.ReputationRowClicked(row)
    if not T.active or not row then return end
    local data = row.elementData
    local factionID = data and data.factionID
    if not factionID or factionID <= 0 then return end
    local box = BuildRepDetail()
    if box:IsShown() and repFactionID == factionID then
        box:Hide()
        return
    end
    repFactionID = factionID
    -- Off the drawn right edge, a little under its top, where 1.x had it.
    ns.SetPointOnce(box, "TOPLEFT", CharacterFrame, "TOPLEFT", T.ART_RIGHT_EDGE, -48)
    box:Show()
    RefreshRepDetail()
    MarkRepRows()
    ns.Sched.NextFrame("sheet.repMark", MarkRepRows)
    C_Timer.After(0.1, MarkRepRows)
end

function T.HideRepDetail()
    if repDetail then repDetail:Hide() end
end
