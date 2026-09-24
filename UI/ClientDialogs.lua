local _, ns = ...

-- Chat settings, the colour picker, the report box and the icon pickers in the old dialog box on the game menu toggle,
-- bronze with the theme.
-- Our overlays, fades and the shared control skins only: no hooks, no fields of our own on client frames.

local weak = { __mode = "k" }

-- Painted as met: only the module's own passes meet pieces, and only while it is on.
local chrome = ns.DialogChrome()
local slices = setmetatable({}, weak)    -- chat settings inner box NineSlice -> true
local active = false
local dressed = {}                       -- dialog global -> true
local loadWatch, chatWatch

-- The report box draws its title and rock insets under its border frame: the old edge only, its own fill stays.
local REPORT_EDGE = ns.DialogEdge(32)
local NAME_EDGES = { "IconSelectorPopupNameLeft", "IconSelectorPopupNameMiddle", "IconSelectorPopupNameRight" }
local INPUT_EDGES = { "TopLeftTex", "TopRightTex", "TopTex", "BottomLeftTex", "BottomRightTex", "BottomTex",
    "LeftTex", "RightTex" }
local CHAT_REDS = { "ChatConfigFrameDefaultButton", "ChatConfigFrameRedockButton", "CombatLogDefaultButton",
    "TextToSpeechDefaultButton", "ChatConfigFrameCancelButton", "ChatConfigFrameOkayButton",
    "ChatConfigCombatSettingsFiltersDeleteButton", "ChatConfigCombatSettingsFiltersAddFilterButton",
    "ChatConfigCombatSettingsFiltersCopyFilterButton", "CombatConfigSettingsSaveButton" }
local CHAT_SCROLLS = { "ChatConfigCombatSettingsFilters", "ChatConfigTextToSpeechSettings",
    "ChatConfigTextToSpeechMessageSettingsScroll" }
local TTS_DROPDOWNS = { "TtsVoiceDropdown", "TtsVoiceAlternateDropdown" }
-- Radio buttons keep their round art.
local RADIOS = { CombatConfigColorsColorizeEntireLineBySource = true, CombatConfigColorsColorizeEntireLineByTarget = true }
-- Checkboxes sit up to seven frames down (combat colours); the text to speech pane a few more.
local CHAT_DEPTH = 10

------------------------------------------------------------------ pieces

-- A plain function for the walkers that pass (region, grey).
local function Drain(region, grey)
    chrome:Drain(region, grey)
end

------------------------------------------------------------ chat settings

-- Inner boxes wear Forever's tooltip rim; checkboxes are made on load and again as channels and panes change.
local Walk
local function WalkChild(child, depth)
    if child:IsObjectType("CheckButton") then
        local name = child:GetName()
        if not (name and RADIOS[name]) then ns.SkinCheckbox(child) end
    end
    local slice = rawget(child, "NineSlice")
    if type(slice) == "table" and not slices[slice] then
        slices[slice] = true
        ns.DrainSlice(slice, nil, Drain)
    end
    if depth > 0 then Walk(child, depth - 1) end
end
Walk = function(frame, depth)
    ns.EachChild(frame, WalkChild, depth)
end

-- The client retitles the header per chat window on open.
local function ChatPass(frame)
    if not active then return end
    ns.OldDialogHeader(frame.Header, frame, true)
    Walk(frame, CHAT_DEPTH)
end

-- A pure watcher under the settings window: first pass the frame after each open, then twice a second.
local function WatchChat(frame)
    if chatWatch then return end
    chatWatch = CreateFrame("Frame", nil, frame)
    local fresh = true
    chatWatch:SetScript("OnShow", function() fresh = true end)
    ns.Sched.OnFrame(chatWatch, { name = "chatConfig.look", every = 0.5,
        fn = function() ChatPass(frame) end,
        pre = function()
            if not fresh then return false end
            fresh = false
            return true
        end })
end

local function DressChat(frame)
    chrome:Border(frame.Border)
    chrome:Header(frame.Header, frame)
    for i = 1, #CHAT_REDS do ns.SkinRedButton(_G[CHAT_REDS[i]]) end
    for i = 1, #CHAT_SCROLLS do
        local host = _G[CHAT_SCROLLS[i]]
        if host then ns.QuietScrollBar(host.ScrollBar, "chatConfig.knob" .. i) end
    end
    ns.DrainInput(_G.CombatConfigSettingsNameEditBox, Drain)
    local tts = _G.TextToSpeechFrame
    if tts then ns.EachKey(tts.PanelContainer, TTS_DROPDOWNS, ns.SkinDropdown) end
    Walk(frame, CHAT_DEPTH)
    WatchChat(frame)
end

------------------------------------------------------------ colour picker

local function DressColorPicker(frame)
    chrome:Border(frame.Border)
    chrome:Header(frame.Header, frame)
    local footer = frame.Footer
    if footer then
        ns.SkinRedButton(footer.OkayButton)
        ns.SkinRedButton(footer.CancelButton)
    end
    local content = frame.Content
    if content then ns.DrainInput(content.HexBox, Drain) end
end

------------------------------------------------------------------ report

local function DressReport(frame)
    chrome:Border(frame.Border, REPORT_EDGE)
    Drain(frame.TopInsetEdge)
    Drain(frame.BottomInsetEdge)
    ns.SkinDropdown(frame.ReportingMajorCategoryDropdown)
    ns.SkinRedButton(frame.ReportButton)
    local shot = frame.ScreenshotReportingFrame
    if shot then ns.SkinRedButton(shot.TakeScreenshotButton) end
    ns.EachKey(frame.Comment, INPUT_EDGES, Drain)
    local close = frame.CloseButton
    if close then
        ns.EditModeClose(close)
        chrome:Fade(close.Border)
    end
end

------------------------------------------------------------ icon pickers

-- IconSelectorPopupFrameTemplate (SharedUIPanelTemplates.xml:1714): Forever's macropopup rim is the only border,
-- so the old edge goes on it; the popup's own dark fill stays (a fill at the BorderBox's level 50 would cover the grid).
local function DressIconPopup(popup, key)
    if ns.IsForbidden(popup) then return end
    local box = popup.BorderBox
    if box then
        chrome:Border(box, REPORT_EDGE)
        ns.EachKey(box.IconSelectorEditBox, NAME_EDGES, Drain, ns.INPUT_GREY)
        ns.SkinDropdown(box.IconTypeDropdown)
        ns.SkinRedButton(box.OkayButton)
        ns.SkinRedButton(box.CancelButton)
        local area = box.SelectedIconArea
        if area then ns.TintSelectorSlot(area.SelectedIconButton) end
    end
    local selector = popup.IconSelector
    if selector then
        ns.QuietScrollBar(selector.ScrollBar, "iconPopup.knob." .. key, true)
        ns.TintSelectorSlots(selector.ScrollBox, selector, "iconPopup.slots." .. key)
    end
end

-- The bank tab popup adds deposit checkboxes and an expansion drop down (BankFrameTemplates.xml:58).
local function DressBankPopup(frame)
    local panel = frame.BankPanel
    local popup = panel and panel.TabSettingsMenu
    DressIconPopup(popup, "bank")
    local deposit = popup and popup.DepositSettingsMenu
    if not deposit then return end
    local checks = deposit.DepositSettingsCheckboxes
    if checks then for i = 1, #checks do ns.SkinCheckbox(checks[i]) end end
    ns.SkinDropdown(deposit.ExpansionFilterDropdown)
end

local function DressTransmogPopup(frame)
    DressIconPopup(frame.OutfitPopup, "transmog")
end

local function DressIconPopupNamed(key)
    return function(frame) DressIconPopup(frame, key) end
end

------------------------------------------------------------------- apply

-- Blizzard_ChatFrame, Blizzard_ColorPickerFrame, Blizzard_ReportFrame; the icon pickers from
-- Blizzard_MacroUI, Blizzard_UIPanels_Game (gear sets, bank), Blizzard_GuildBankUI and Blizzard_Transmog.
local DIALOGS = {
    { "ChatConfigFrame", DressChat },
    { "ColorPickerFrame", DressColorPicker },
    { "ReportFrame", DressReport },
    { "MacroPopupFrame", DressIconPopupNamed("macro") },
    { "GearManagerPopupFrame", DressIconPopupNamed("gear") },
    { "GuildBankPopupFrame", DressIconPopupNamed("guildBank") },
    { "BankFrame", DressBankPopup },
    { "TransmogFrame", DressTransmogPopup },
}

-- True once every dialog is dressed.
local function DressAll()
    local all = true
    for i = 1, #DIALOGS do
        local name, dress = DIALOGS[i][1], DIALOGS[i][2]
        if not dressed[name] then
            local frame = _G[name]
            if frame then
                dressed[name] = true
                ns.SafeCall(dress, frame)
            else
                all = false
            end
        end
    end
    return all
end

-- Our own watch: a dialog whose addon loads later is dressed on its ADDON_LOADED.
local function OnAddonLoaded()
    if active and DressAll() then loadWatch:UnregisterEvent("ADDON_LOADED") end
end

-- Every pass calls these: work only on a change.
local function Apply()
    if active then return end
    active = true
    chrome:On()
    if DressAll() or loadWatch then return end
    loadWatch = ns.EventFrame("ADDON_LOADED", OnAddonLoaded)
end

-- The control skins stay until a reload, as the game menu's own buttons do.
local function Restore()
    if not active then return end
    active = false
    chrome:Off()
end

ns.RegisterModule("gameMenu", { apply = Apply, restore = Restore })
