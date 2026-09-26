local _, ns = ...

-- The Profiles tab: the character's profile picked from a list, plus new, copy, rename and delete (Core/Profiles.lua).

local O = ns.options
local ROW = 24
local DEFAULT = ns.PROFILE_DEFAULT

local function Say(why)
    if why and UIErrorsFrame then UIErrorsFrame:AddMessage(why, 1, 0.1, 0.1) end
end

-- data: { mode = "new" | "copy" | "rename", old = name }. A refused name keeps the box open.
local ASK = {
    new = "Name the new profile. It starts from the default settings.",
    copy = "Name the new profile. It starts from the settings in use now.",
    rename = "A new name for the profile %s.",
}

local function Accept(dialog, data)
    local box = ns.PopupEditBox(dialog)
    local text = box and box:GetText()
    local name, why
    if data.mode == "rename" then
        name, why = ns.RenameProfile(data.old, text)
    else
        name, why = ns.NewProfile(text, data.mode == "copy")
    end
    if name then return false end
    Say(why)
    return true
end

ns.Popup("FCUI_PROFILE_NAME", {
    text = "%s",
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 32,
    OnShow = function(self, data)
        local box = ns.PopupEditBox(self)
        if not box then return end
        box:SetText(data and data.old or "")
        box:HighlightText()
        box:SetFocus()
    end,
    OnAccept = Accept,
    EditBoxOnEnterPressed = function(self, data)
        local dialog = self:GetParent()
        if not Accept(dialog, data) then dialog:Hide() end
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
})

ns.Popup("FCUI_PROFILE_DELETE", {
    text = "Delete the profile %s? Characters on it go back to Default.",
    button1 = _G.DELETE or "Delete",
    button2 = CANCEL,
    OnAccept = function(_, data) ns.DeleteProfile(data) end,
})

local function AskName(mode, old)
    local text = mode == "rename" and ASK.rename:format(old) or ASK[mode]
    StaticPopup_Show("FCUI_PROFILE_NAME", text, nil, { mode = mode, old = old })
end

local function RowClick(self)
    self:SetChecked(self.name == ns.ProfileName())
    ns.UseProfile(self.name)
end

local BUTTONS = {
    { "New", "A new profile from the default settings, used by this character.", function() AskName("new") end },
    { "Copy", "A new profile from the settings in use now, used by this character.", function() AskName("copy") end },
    { "Rename", "Renames the profile in use. Other characters on it follow.",
        function() AskName("rename", ns.ProfileName()) end, true },
    { "Delete", "Deletes the profile in use; its characters go back to Default.",
        function() StaticPopup_Show("FCUI_PROFILE_DELETE", ns.ProfileName(), nil, ns.ProfileName()) end, true },
}

-- On the options frame: caption over buttons where the search and bulk buttons stand; rows on their own scroll child
-- that the tab swaps into the list. setRange(height) sizes the list's scroll bar.
function O.ProfilesPane(frame, search, list, setRange, tip)
    local pane = CreateFrame("Frame", nil, frame)
    pane:SetAllPoints(frame)
    pane:Hide()
    local caption = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    caption:SetPoint("TOP", search, "TOP", 0, -3)
    local child = CreateFrame("Frame", nil, list)
    child:SetSize(list:GetWidth(), 1)
    child:Hide()
    pane.child = child
    local rows, named = {}, {}
    local x = -(#BUTTONS * 84 - 4) / 2
    for i, spec in ipairs(BUTTONS) do
        local button = ns.PanelButton(pane, spec[1], 80)
        button:SetPoint("TOPLEFT", search, "BOTTOM", x + (i - 1) * 84, -6)
        button:SetScript("OnClick", spec[3])
        button.label, button.tooltip = spec[1], spec[2]
        ns.AttachTip(button, tip)
        if spec[4] then named[#named + 1] = button end
    end

    local function Row(i)
        local row = rows[i]
        if row then return row end
        row = CreateFrame("CheckButton", nil, child)
        row:SetSize(24, 24)
        ns.DressStates(row, O.RADIO, nil, nil, O.RADIO, O.OPTION_RADIO)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("LEFT", row, "RIGHT", 2, 1)
        row:SetScript("OnClick", RowClick)
        ns.SetPointOnce(row, "TOPLEFT", child, "TOPLEFT", 0, -(i - 1) * ROW)
        rows[i] = row
        return row
    end

    function pane.Refresh()
        local names, current = ns.ProfileNames(), ns.ProfileName()
        for i, name in ipairs(names) do
            local row = Row(i)
            row.name = name
            row.text:SetText(name)
            row:SetChecked(name == current)
            row:Show()
        end
        for i = #names + 1, #rows do rows[i]:Hide() end
        child:SetHeight(math.max(1, #names * ROW))
        setRange(#names * ROW)
        local who = ns.Safe(UnitName("player"), nil) or "This character"
        caption:SetText(("%s uses the profile |cffffd100%s|r."):format(who, current))
        for _, button in ipairs(named) do button:SetEnabled(current ~= DEFAULT) end
    end
    return pane
end
