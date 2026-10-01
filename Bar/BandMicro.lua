local _, ns = ...
local L = ns.L
local B = ns.band

-- Micro menu on the band, or off it on our group frame dragged by an edit mode style handle, with its own size dialog.

local ART_W, BAND_H, CORNER_X = B.ART_W, B.BAND_H, B.CORNER_X
local MICRO_SKIP, MICRO_END_GAP, MICRO_LEAD, MICRO_REGION_MAX = B.MICRO_SKIP, B.MICRO_END_GAP, B.MICRO_LEAD, B.MICRO_REGION_MAX
local MICRO_BUTTONS, PIECES = B.MICRO_BUTTONS, B.PIECES
-- Era: 29x37 buttons 3 px overlapped, 2 up.
local MICRO_Y, MICRO_W, MICRO_H, MICRO_STEP = 2, 29, 37, -3
-- The group's rectangle starts a little before its first button.
local MICRO_GROUP_X, MICRO_ROW_IN, MICRO_NUDGE = 548, 7, 4
local Remember, Seat, BandNow, OneBar = B.Remember, B.Seat, B.BandNow, B.OneBar
local MicroUserScale, CurrentPlan, DropPlace, ButtonLevel = B.MicroUserScale, B.CurrentPlan, B.DropPlace, B.ButtonLevel
local Dress = ns.Dress

local POST_SHEET = PIECES[4]
-- End posts for a group off the band (a run cut from the middle has none).
local END_POST_LEFT = { tint = ns.BRONZE_SOFT, coords = B.POST_LEFT, w = B.POST_W, h = BAND_H, point = "BOTTOMLEFT", show = true }
local END_POST_RIGHT = { tint = ns.BRONZE_SOFT, coords = B.POST_RIGHT, w = B.POST_W, h = BAND_H, point = "BOTTOMRIGHT", show = true }
local RUN = {}   -- a floor run's coords, refilled per run
local HANDLE_TIP = { anchor = "ANCHOR_TOP", text = L["BAR_MICRO_MENU"], r = 1, g = 1, b = 1, lines = {
    { L["BAR_DRAG_TO_MOVE_LET_GO"], 1, 0.82, 0 },
    { L["BAR_CLICK_FOR_ITS_SIZE_AND"], 1, 0.82, 0 },
} }

-- This client's micro buttons in its order, read once before any is reparented (retail 13, Forever 14).
local microButtons

-- The key in gold, as the client's micro buttons show theirs.
local function MapButtonTip()
    local name = WORLDMAP_BUTTON or "World Map"
    if MicroButtonTooltipText then return MicroButtonTooltipText(name, "TOGGLEWORLDMAP") end
    local key = GetBindingKey("TOGGLEWORLDMAP")
    return name .. (key and (" |cffffd100(" .. key .. ")|r") or "")
end
local MAP_TIP = { text = MapButtonTip, r = 1, g = 1, b = 1 }

local function ToggleMap()
    if ToggleWorldMap then ToggleWorldMap() end
end

-- 1.x's Help button, last in the row: Forever keeps its own hidden (the store button's update hides it), so ours
-- presses it through a secure pad and support opens as from the game menu.
local function HelpButtonTip()
    local name = _G.HELP_BUTTON or "Customer Support"
    return MicroButtonTooltipText and MicroButtonTooltipText(name, "TOGGLEHELP") or name
end
local HELP_TIP = { text = HelpButtonTip, r = 1, g = 1, b = 1 }

local function HelpMicroButton()
    if ns.HelpMicroButton then return ns.HelpMicroButton end
    local client = _G.HelpMicroButton
    if not client then return nil end
    local button = CreateFrame("Button", "ForeverClassicUIHelpMicroButton", B.art or UIParent)
    button:SetSize(MICRO_W, MICRO_H)
    button:SetNormalTexture((ns.TexPath("microHelpUp")))
    button:SetPushedTexture((ns.TexPath("microHelpDown")))
    button:SetHighlightTexture((ns.TexPath("microHighlight")))
    ns.AttachTip(button, HELP_TIP)
    ns.HelpMicroButton = button
    ns.MapPad(button, nil, nil, client)
    return button
end

-- 1.x had a world map button in the row; ours goes beside the quest button. Its click goes through a secure pad (UI/SecurePad.lua).
local function WorldMapMicroButton()
    if ns.WorldMapMicroButton then return ns.WorldMapMicroButton end
    -- Made before the band art exists; the row layout reparents it later.
    local button = CreateFrame("Button", "ForeverClassicUIWorldMapMicroButton", B.art or UIParent)
    button:SetSize(MICRO_W, MICRO_H)
    button:SetNormalTexture((ns.TexPath("microWorldUp")))
    button:SetPushedTexture((ns.TexPath("microWorldDown")))
    button:SetHighlightTexture((ns.TexPath("microHighlight")))
    button:SetScript("OnClick", ToggleMap)
    ns.AttachTip(button, MAP_TIP)
    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function() button:SetButtonState("PUSHED", true) end)
        WorldMapFrame:HookScript("OnHide", function() button:SetButtonState("NORMAL") end)
    end
    ns.WorldMapMicroButton = button
    ns.MapPad(button)
    return button
end

local function AddMicroChild(child, found)
    if child.layoutIndex and child.PostAddButtonCallback then found[#found + 1] = child end
end

local function MicroButtonList()
    if microButtons then return microButtons end
    local found = {}
    if MicroMenu then
        ns.EachChild(MicroMenu, AddMicroChild, found)
        table.sort(found, function(a, b) return a.layoutIndex < b.layoutIndex end)
    end
    if #found == 0 then
        for _, name in ipairs(MICRO_BUTTONS) do
            if _G[name] then found[#found + 1] = _G[name] end
        end
    end
    local map = WorldMapMicroButton()
    if map then
        local at = #found + 1
        for i, button in ipairs(found) do
            if button == QuestLogMicroButton then at = i + 1 break end
        end
        table.insert(found, at, map)
    end
    local help = HelpMicroButton()
    if help then found[#found + 1] = help end
    microButtons = found
    return found
end
B.MicroButtonList = MicroButtonList
ns.MicroButtonList = MicroButtonList

-- The band was drawn for ten micro buttons, later clients have 13-14. All stay: the row starts at x 556
-- with the 1.x overlap, scaled as a whole to end before the latency and key ring section.
local function MicroNeed(count)
    return count * (MICRO_W + MICRO_STEP) - MICRO_STEP
end

-- Row scale and region for this many buttons: fitted to the old art's room, times the player's size
-- (settable on the band too, even past the art); snapping the group back restores default size.
-- Fitted to the buttons on the row, so Era's set draws at Era's size; sizeCount (Keep button size) counts hidden ones too.
local function MicroPlan(count, userScale, sizeCount)
    local need = MicroNeed(count)
    if need <= 0 then return 1, MICRO_LEAD + MICRO_END_GAP end
    local room = MICRO_REGION_MAX - MICRO_LEAD - MICRO_END_GAP
    local scale = math.min(1, room / MicroNeed(math.max(count, sizeCount or count))) * (userScale or 1)
    local region = math.ceil(MICRO_LEAD + need * scale + MICRO_END_GAP)
    return scale, math.min(MICRO_REGION_MAX, region)
end
B.MicroPlan = MicroPlan

-- Buttons the player takes off one by one (Hide micro buttons); the row and its art close up.
local MICRO_HIDE = {
    CharacterMicroButton = "hideMicroCharacter", SpellbookMicroButton = "hideMicroSpellbook",
    TalentMicroButton = "hideMicroTalents", ProfessionMicroButton = "hideProfessionsButton",
    QuestLogMicroButton = "hideMicroQuestLog", ForeverClassicUIWorldMapMicroButton = "hideMicroWorldMap",
    ForeverClassicUIHelpMicroButton = "hideMicroHelp",
    GuildMicroButton = "hideMicroGuild", LFDMicroButton = "hideMicroGroupFinder",
    CollectionsMicroButton = "hideMicroCollections", MainMenuMicroButton = "hideMicroGameMenu",
    PlayerSpellsMicroButton = "hideMicroTalents", AchievementMicroButton = "hideMicroAchievements",
    LegacyMicroButton = "hideMicroLegacy",
    HelpMicroButton = "hideMicroHelp",
}

-- The collections button hidden by our option: the spellbook's foot gives it a tab instead.
function ns.CollectionsMicroHidden()
    local db = ns.db
    return B.active and db ~= nil and db.hideMicroButtons == true and db.hideMicroCollections == true
end

-- Off the row: the shop always; the ones picked under Hide micro buttons. Second value: left off by the option.
-- Help hides by its own row even with Hide micro buttons off: it came with 0.14.0, and older installs keep it off.
local function HiddenByOption(db, key)
    return db[key] == true and (db.hideMicroButtons == true or key == "hideMicroHelp")
end

local function MicroSkipped(button)
    local name = button:GetName() or ""
    if MICRO_SKIP[name] then return true, false end
    local key = MICRO_HIDE[name]
    local db = ns.db
    if key and db and HiddenByOption(db, key) and not db.hideMicroKeepWidth then return true, true end
    return false, false
end

-- Keep the menu's width: a hidden button keeps its seat, faded and unclickable, so the row and its art stay as wide.
local seatHidden = setmetatable({}, { __mode = "k" })
local function IsSeatHidden(button)
    local key = MICRO_HIDE[button:GetName() or ""]
    local db = ns.db
    return key and db and db.hideMicroKeepWidth == true and HiddenByOption(db, key) or false
end
local function SeatHidden(button)
    if IsSeatHidden(button) then
        ns.SetFrameAlphaIf(button, 0)
        if button:IsMouseEnabled() then button:EnableMouse(false) end
        seatHidden[button] = true
    elseif seatHidden[button] then
        ns.SetFrameAlphaIf(button, 1)
        button:EnableMouse(true)
        seatHidden[button] = nil
    end
end

-- 1.x's gold line under each button's name, from the client's own strings.
local MICRO_TIPS = {
    CharacterMicroButton = "NEWBIE_TOOLTIP_CHARACTER", SpellbookMicroButton = "NEWBIE_TOOLTIP_SPELLBOOK",
    TalentMicroButton = "NEWBIE_TOOLTIP_TALENTS", QuestLogMicroButton = "NEWBIE_TOOLTIP_QUESTLOG",
    ForeverClassicUIWorldMapMicroButton = "NEWBIE_TOOLTIP_WORLDMAP", GuildMicroButton = "NEWBIE_TOOLTIP_GUILDTAB",
    ForeverClassicUIHelpMicroButton = "NEWBIE_TOOLTIP_HELP",
    LFDMicroButton = "NEWBIE_TOOLTIP_LFGPARENT", CollectionsMicroButton = "NEWBIE_TOOLTIP_MOUNTS_AND_PETS",
    MainMenuMicroButton = "NEWBIE_TOOLTIP_MAINMENU", AchievementMicroButton = "NEWBIE_TOOLTIP_ACHIEVEMENT",
    EJMicroButton = "NEWBIE_TOOLTIP_ENCOUNTER_JOURNAL", HousingMicroButton = "NEWBIE_TOOLTIP_HOUSING",
}

-- Also from the pads over the buttons that open our windows (their enter runs the button's own, not its hooks).
local function MicroTip(button)
    if not (ns.db and ns.db.microTips) or GameTooltip:GetOwner() ~= button then return end
    local name = MICRO_TIPS[button:GetName() or ""]
    if name == "NEWBIE_TOOLTIP_GUILDTAB" and not (IsInGuild and IsInGuild()) then name = "NEWBIE_TOOLTIP_LOOKINGFORGUILDTAB" end
    local text = name and ns.EraText(name)
    if not text then return end
    -- Once per tooltip: a pad over a button of ours runs its enter, this hook included, then calls this again.
    local last = _G["GameTooltipTextLeft" .. GameTooltip:NumLines()]
    local shown = last and last:GetText()
    if not ns.IsSecret(shown) and shown == text then return end
    GameTooltip:AddLine(text, 1, 0.82, 0, true)
    GameTooltip:Show()
end
ns.MicroTip = MicroTip

local function SeatShown(button)
    ns.HookScriptOnce(button, "OnEnter", MicroTip)
    SeatHidden(button)
end

-- Buttons on the row, and with Keep button size the count their size is fitted to.
-- A hidden Help button takes no seat: it came with 0.14.0, and the rows before it were fitted without it.
function B.MicroCounts()
    local shown, sized = 0, 0
    for _, button in ipairs(MicroButtonList()) do
        if button:IsShown() then
            local skipped, byOption = MicroSkipped(button)
            if not skipped then shown = shown + 1 end
            if not skipped or (byOption and button:GetName() ~= "ForeverClassicUIHelpMicroButton") then sized = sized + 1 end
        end
    end
    return shown, (ns.db and ns.db.hideMicroKeepSize == true) and sized or nil
end

local function Percent(value) return string.format("%d%%", value) end

local function RefreshMicroDialog()
    local dialog = B.art.microDialog
    if dialog and dialog:IsShown() then dialog:Refresh() end
end

local function SaveMicro()
    RefreshMicroDialog()
    ns.QueueApply()
end

local function MicroSizeValues() return math.floor(MicroUserScale() * 100 + 0.5), 50, 200, 30 end

-- No dialog refresh here: that would re-fill the slider under the player's hand.
local function OnMicroSize(value)
    ns.MicroTouched()
    ns.db.microScale = math.max(0.5, math.min(2, value / 100))
    ns.QueueApply()
end

-- Micro group settings shaped like the client's edit mode dialog (same templates); the client has none for a piece not its own.
local function MicroDialog()
    local art = B.art
    local dialog = art.microDialog
    if dialog then return dialog end
    dialog = B.EditDialog("ForeverClassicUIMicroDialog", 383, 226, L["BAR_MICRO_MENU"])
    art.microDialog = dialog

    local label = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    label:SetSize(100, 32)
    label:SetJustifyH("LEFT")
    label:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -48)
    label:SetText(HUD_EDIT_MODE_SETTING_MICRO_MENU_SIZE or "Size")

    local slider, formatters = B.StepperSlider(dialog, 200, label, 5, Percent)
    if slider then
        dialog.slider = slider
        dialog.InitSlider = B.GuardedSlider(slider, MicroSizeValues, OnMicroSize, { formatters = formatters, owner = dialog })
    end

    local hideArt = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
    hideArt:SetSize(30, 30)
    hideArt:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    ns.EditModeCheck(hideArt)
    local hideLabel = hideArt:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    hideLabel:SetPoint("LEFT", hideArt, "RIGHT", 4, 0)
    hideLabel:SetText(HUD_EDIT_MODE_SETTING_ACTION_BAR_HIDE_BAR_ART or "Hide Bar Art")
    hideArt:SetScript("OnClick", function(self)
        ns.MicroTouched()
        ns.db.hideMicroArt = self:GetChecked() and true or false
        ns.ToggleChanged("hideMicroArt")
    end)
    dialog.hideArt = hideArt

    -- Back in its place means default size too, so the pieces fit.
    local reset = B.EditDialogReset(dialog, function()
        ns.MicroTouched()
        ns.db.microPos, ns.db.microScale = nil, nil
        SaveMicro()
    end)
    dialog.reset = reset

    local resize = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    resize:SetSize(330, 28)
    resize:SetPoint("BOTTOM", reset, "TOP", 0, 6)
    resize:SetText(L["BAR_RESET_TO_DEFAULT_SIZE"])
    resize:SetScript("OnClick", function()
        ns.MicroTouched()
        ns.db.microScale = nil
        SaveMicro()
    end)
    dialog.resize = resize
    ns.EditModeRed(resize)

    function dialog:Refresh()
        if self.InitSlider then self.InitSlider() end
        self.hideArt:SetChecked(ns.db.hideMicroArt == true)
        self.reset:SetEnabled(ns.db.microPos ~= nil)
        self.resize:SetEnabled(math.abs(MicroUserScale() - 1) > 0.001)
    end
    dialog:SetScript("OnShow", function(self) self:Refresh() end)
    dialog:SetScript("OnHide", function()
        local handle = art.microHome and art.microHome.handle
        if handle and handle.Dress then handle.Dress("editmode-actionbar-highlight") end
    end)
    return dialog
end

-- The micro group's frame: the row hangs from it on and off the band so a drag carries it; off the band
-- it wears its run of band art as a floor.
local function MicroHome()
    local art = B.art
    local home = art.microHome
    if home then return home end
    home = CreateFrame("Frame", "ForeverClassicUIMicroGroup", art)
    home:SetClampedToScreen(true)
    home:SetMovable(true)
    art.microHome = home
    home.floor = { home:CreateTexture(nil, "BACKGROUND"), home:CreateTexture(nil, "BACKGROUND") }
    home.posts = { home:CreateTexture(nil, "BORDER"), home:CreateTexture(nil, "BORDER") }

    local handle = B.SelectionHandle(home, L["BAR_MICRO_MENU"])
    handle:EnableMouseWheel(true)
    local DressBox = handle.Dress
    -- While dragged the band redraws as the group crosses the snap-back line, so the drop's result shows first.
    local follow = ns.Sched.OnFrame(CreateFrame("Frame", nil, handle), { name = "band.microDrag", every = 0, awake = false,
        fn = function()
            if OneBar() then return end
            -- The full pass waits out a fight; the rows need not.
            if B.PreviewDrop("micro", home) then ns.MicroDroppedInFight() end
        end })
    local function Undrag() home.dragged = false end
    handle:SetScript("OnDragStart", function()
        -- Movable in a fight too while the group is free: it is ours and nothing protected hangs from it (rows are put back after).
        if InCombatLockdown() and home:IsProtected() then return end
        DressBox("editmode-actionbar-selected")
        home.moving, home.dragged = true, true
        home:StartMoving()
        follow:Wake()
    end)
    handle:SetScript("OnDragStop", function()
        follow:Sleep()
        -- Read before the stop: StopMovingOrSizing leaves the group (its rows hang on it) with no anchor.
        local dragPreview = B.dragPreview
        local place = DropPlace("micro", home, dragPreview.bagsFirst)
        local left, bottom = home:GetLeft(), home:GetBottom()
        home:StopMovingOrSizing()
        home.moving = false
        ns.Sched.NextFrame("band.undrag", Undrag)
        dragPreview.micro, dragPreview.bagsFirst = nil, nil
        DressBox("editmode-actionbar-highlight")
        -- Dropped near its place on the bar: back onto the bar.
        if place ~= nil then
            ns.MicroTouched()
            ns.db.microPos, ns.db.microScale = nil, nil
            ns.db.bagsFirst = place
        elseif left and bottom then
            ns.MicroTouched()
            -- Read in its in-hand scale; stored in the one it takes off the band.
            local k = home:GetEffectiveScale() / (UIParent:GetEffectiveScale() * MicroUserScale())
            ns.db.microPos = { point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = left * k, y = bottom * k }
        end
        SaveMicro()
        ns.MicroDroppedInFight()
    end)
    handle:SetScript("OnMouseWheel", function(_, delta)
        ns.MicroTouched()
        ns.db.microScale = math.max(0.5, math.min(2, MicroUserScale() + 0.05 * delta))
        SaveMicro()
    end)
    handle:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            ns.MicroTouched()
            ns.db.microPos, ns.db.microScale = nil, nil
            SaveMicro()
            return
        end
        -- A click selects it and opens its settings, as edit mode does; the release ending a drag is not a click.
        if home.moving or home.dragged then return end
        ns.EditMode.TakePick()
        local dialog = MicroDialog()
        DressBox("editmode-actionbar-selected")
        ns.SetPointOnce(dialog, "BOTTOM", home, "TOP", 0, 40)
        dialog:Show()
    end)
    ns.AttachTip(handle, HANDLE_TIP)
    home.handle = handle
    return home
end

-- The region ends MICRO_END_GAP past the row as drawn: a row drawn short of its planned end (seen in game) trims it from
-- the next pass (B.shape.microTrim, read in ReadShape).
local TRIM_MAX = 80
local function FitRegion(last, art)
    local plan, shape = CurrentPlan(), B.shape
    if not plan.microFirst or not plan.microEnd then return end
    local right, left = last:GetRight(), art:GetLeft()
    if ns.AnySecret(right, left) or not right or not left then return end
    local rowEnd = right * last:GetEffectiveScale() / art:GetEffectiveScale() - left
    -- Room added under bars 2 and 3 (ReadShape) is wanted, not slack.
    local trim = (shape.microTrim or 0) + plan.microEnd - (shape.microGrow or 0) - MICRO_END_GAP - rowEnd
    trim = math.floor(math.max(0, math.min(TRIM_MAX, trim)) + 0.5)
    if trim ~= (shape.microTrim or 0) then
        shape.microTrim = trim
        ns.QueueApply()
    end
end

-- Spread the rest evenly: the shown buttons span the width all of them would, in button units, so any size fits.
local function SpreadStep(wanted)
    local db = ns.db
    if not (db.hideMicroButtons and db.hideMicroKeepWidth and db.hideMicroSpread) then return false, MICRO_STEP end
    local visible = 0
    for _, button in ipairs(wanted) do
        if not IsSeatHidden(button) then visible = visible + 1 end
    end
    if visible < 2 or visible >= #wanted then return false, MICRO_STEP end
    local span = #wanted * MICRO_W + (#wanted - 1) * MICRO_STEP
    return true, (span - visible * MICRO_W) / (visible - 1)
end

local microBusy = false
local offRow = setmetatable({}, { __mode = "k" })   -- buttons we took off the row, to give back
function B.LayoutMicroButtons()
    if microBusy then return end
    microBusy = true
    local art = B.art
    -- Every button leaves the client's menu, shown or not, so its layout never finds a lone child without a position.
    local wanted = {}
    for _, button in ipairs(MicroButtonList()) do
        Remember(button)
        if button:GetParent() ~= art then button:SetParent(art) end
        if MicroSkipped(button) then
            button:ClearAllPoints()
            button:SetAlpha(0)
            if button:IsMouseEnabled() then button:EnableMouse(false) end
            offRow[button] = true
        elseif button:IsShown() then
            -- Back from the option: seen and clickable again.
            if offRow[button] then
                offRow[button] = nil
                button:SetAlpha(1)
                button:EnableMouse(true)
            end
            wanted[#wanted + 1] = button
        end
    end
    if #wanted == 0 then microBusy = false return end
    -- Off the band (moved, or one-bar corner) the chosen size rides on the group frame with the band scale
    -- divided out; on it the row itself is drawn bigger or smaller.
    local out = (not B.shape.micro) or OneBar()
    local group = out and MicroUserScale() or 1
    local _, sized = B.MicroCounts()
    local scale, region = MicroPlan(#wanted, out and 1 or MicroUserScale(), sized)
    -- The row at its own scale: what the band's sockets were drawn around.
    local baseScale = MicroPlan(#wanted, 1, sized)
    local home = MicroHome()
    -- In hand it keeps its scale: a change mid-drag (the preview taking it off the band) threw it off the cursor, up.
    local homeScale = home.moving and home:GetScale() or (out and (group / BandNow()) or 1)
    local buttonScale = scale * homeScale
    local level = ButtonLevel()

    local plan = CurrentPlan()
    local groupX, rowIn = MICRO_GROUP_X, MICRO_ROW_IN
    if not out and plan.microRow then
        -- Seen in game: the row reads 4 px right of its room, the left gap wider than the right.
        local row = plan.microRow - MICRO_NUDGE
        -- The box never reaches into the bag part before it (a row standing last sits close to it).
        groupX = math.max(plan.microStart, row - MICRO_ROW_IN)
        rowIn = row - groupX
    end
    local groupW = (not out and plan.microEnd) and (plan.microEnd - groupX) or ((ART_W / 2 + region) - MICRO_GROUP_X)
    home:SetFrameLevel(math.max(0, level - 1))
    if not home.moving then
        home:SetSize(groupW, BAND_H)
        home:SetScale(homeScale)
        home:ClearAllPoints()
        local pos = ns.db.microPos
        if ns.ValidPlace(pos) then
            home:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
        elseif OneBar() then
            home:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", CORNER_X, 0)
        else
            home:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", groupX, 0)
        end
    end
    home:Show()
    -- Off the band only, its floor: the third sheet's run it stood on, plus the dark start of the fourth where the row reaches it.
    local floored = out and not ns.db.hideMicroArt
    local third = math.min(region, 256)
    local runs = {
        { 3, (MICRO_GROUP_X - 512) / 256, third / 256, third - (MICRO_GROUP_X - 512), 0 },
        { 4, 0, math.max(0, region - 256) / 256, math.max(0, region - 256), third - (MICRO_GROUP_X - 512) },
    }
    for i, tex in ipairs(home.floor) do
        local run = runs[i]
        if floored and run[4] > 0 then
            local sheet = PIECES[run[1]]
            RUN[1], RUN[2], RUN[3], RUN[4] = run[2], run[3], sheet.band[1], sheet.band[2]
            Dress(tex, sheet.key, B.BAND_RUN, home, run[5], 0, run[4], BAND_H, RUN)
        else
            tex:Hide()
        end
    end
    for i, post in ipairs(home.posts) do
        if floored then
            Dress(post, POST_SHEET.key, i == 1 and END_POST_LEFT or END_POST_RIGHT, home)
        else
            post:Hide()
        end
    end

    local spread, step = SpreadStep(wanted)
    local rowY = MICRO_Y
    if not out then rowY = MICRO_Y + MICRO_H * (baseScale - scale) / 2 end
    local prev
    for _, button in ipairs(wanted) do
        Seat(button, buttonScale, MICRO_W, MICRO_H, level)
        local parked = spread and IsSeatHidden(button)
        if prev and not parked then
            button:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", step, 0)
        else
            -- From the group corner by band numbers, read in the button's scale. On the band the row stays centred
            -- on the sockets (hung from the floor, a resized row grew out of them); off it the whole group scales.
            button:SetPoint("BOTTOMLEFT", home, "BOTTOMLEFT", rowIn / scale, rowY / scale)
        end
        ns.SkinMicroButton(button)
        SeatShown(button)
        if not parked then prev = button end
    end
    if not out and prev then FitRegion(prev, art) end
    if MicroMenu then
        if MicroMenu.BorderArt then MicroMenu.BorderArt:SetAlpha(0) end
        if MicroMenu.BackgroundArt then MicroMenu.BackgroundArt:SetAlpha(0) end
    end
    microBusy = false
end
