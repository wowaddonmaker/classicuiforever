local _, ns = ...

-- Old currency options box off the sheet's right edge: name, count, description, Unused, Show on Backpack.
-- The two checks are the client's own, lent from its put-away right pane: a click on them runs its code
-- clean, so the list and the backpack follow as they do in the default UI.

local T = ns.sheet

local box
local lent = {}   -- check -> { parent, points, level }
local CHECKS = { "InactiveCheckbox", "BackpackCheckbox" }

local function Pane()
    return TokenFrame and TokenFrame.DetailFrame
end

-- The client's selection, which its own row click sets; nil when none or a header.
local function Selected()
    local index = TokenFrame and TokenFrame.selectedID
    if not index or not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyListInfo then return nil end
    local info = C_CurrencyInfo.GetCurrencyListInfo(index)
    if not info or info.isHeader then return nil end
    return info
end

local function Refresh()
    if not box or not box:IsShown() then return end
    local info = Selected()
    if not info then
        box:Hide()
        return
    end
    local icon = info.iconFileID and ("|T" .. info.iconFileID .. ":14:14|t ") or ""
    box.name:SetText(info.name or "")
    box.count:SetText(icon .. BreakUpLargeNumbers(info.quantity or 0))
    local text = info.currencyID and C_CurrencyInfo.GetCurrencyDescription and C_CurrencyInfo.GetCurrencyDescription(info.currencyID)
    box.text:SetText(text or "")
end

local function QueueRefresh()
    ns.Sched.NextFrame("sheet.currencyRefresh", Refresh)
end

-- The client's check into our box, in the old look; its own click and state stay the client's.
local function Lend(check, y)
    if not lent[check] then
        local points = {}
        for i = 1, check:GetNumPoints() do points[i] = { check:GetPoint(i) } end
        lent[check] = { parent = check:GetParent(), points = points }
        ns.SkinCheckbox(check)
        check:SetSize(24, 24)
        local label = check.Label
        if label then
            label:SetFontObject("GameFontNormalSmall")
            label:SetTextColor(1, 0.82, 0)
        end
        check:HookScript("OnClick", QueueRefresh)
    end
    check:SetParent(box.content)
    ns.SetPointOnce(check, "TOPLEFT", box, "TOPLEFT", 14, y)
    check:SetFrameLevel(box.content:GetFrameLevel() + 2)
    -- The put-away pane took its mouse; ours now.
    check:EnableMouse(true)
end

local function LendChecks()
    local pane = Pane()
    if not pane then return end
    for i, key in ipairs(CHECKS) do
        local check = pane[key]
        if check then Lend(check, -143 - (i - 1) * 24) end
    end
end

local function Build()
    if box then return box end
    box = T.NewDetailBox("ClassicUIForeverCurrencyDetail", TokenFrame)
    box.count = box.content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    box.count:SetPoint("TOPRIGHT", box, "TOPRIGHT", -34, -21)
    box.count:SetJustifyH("RIGHT")
    ns.SetPointOnce(box.text, "TOPLEFT", box.name, "BOTTOMLEFT", 0, -6)
    box:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    box:SetScript("OnEvent", QueueRefresh)
    return box
end

-- Read after the client's own click handler, which set its selection.
function ns.CurrencyRowClicked(row)
    if not T.active or not row or IsModifiedClick("CHATLINK") or IsModifiedClick("TOKENWATCHTOGGLE") then return end
    local data = row.elementData
    if not data or data.isHeader or row.currencyIndex == nil then return end
    Build()
    if box:IsShown() and box.index == row.currencyIndex then
        box:Hide()
        return
    end
    box.index = row.currencyIndex
    ns.SetPointOnce(box, "TOPLEFT", CharacterFrame, "TOPLEFT", T.ART_RIGHT_EDGE, -48)
    LendChecks()
    box:Show()
    Refresh()
end

-- The client's checks back in its pane, where it laid them.
function T.GiveBackCurrencyDetail()
    if box then box:Hide() end
    for check, was in pairs(lent) do
        check:SetParent(was.parent)
        check:ClearAllPoints()
        for _, point in ipairs(was.points) do check:SetPoint(unpack(point)) end
    end
    wipe(lent)
end
