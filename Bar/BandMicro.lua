local _, ns = ...
local B = ns.band

-- Micro menu on the band, or off it on our group frame dragged by an edit mode style handle, with its own size dialog.

local ART_W, BAND_H, CORNER_X = B.ART_W, B.BAND_H, B.CORNER_X
local MICRO_SKIP, MICRO_END_GAP, MICRO_LEAD, MICRO_REGION_MAX = B.MICRO_SKIP, B.MICRO_END_GAP, B.MICRO_LEAD, B.MICRO_REGION_MAX
local MICRO_BUTTONS, PIECES = B.MICRO_BUTTONS, B.PIECES
-- 1.x overlap of 3 px; without the shop button the row scales to about 0.9.
local MICRO_Y, MICRO_W, MICRO_H, MICRO_STEP = 2.5, 28, 38, -3
-- The group's rectangle starts a little before its first button.
local MICRO_GROUP_X, MICRO_ROW_IN, MICRO_NUDGE = 548, 7, 2
local Remember, Seat, BandNow, OneBar = B.Remember, B.Seat, B.BandNow, B.OneBar
local MicroUserScale, CurrentPlan, DropPlace, ButtonLevel = B.MicroUserScale, B.CurrentPlan, B.DropPlace, B.ButtonLevel
local Dress = ns.Dress

local POST_SHEET = PIECES[4]
-- End posts for a group off the band (a run cut from the middle has none).
local END_POST_LEFT = { tint = ns.BRONZE_SOFT, coords = B.POST_LEFT, w = B.POST_W, h = BAND_H, point = "BOTTOMLEFT", show = true }
local END_POST_RIGHT = { tint = ns.BRONZE_SOFT, coords = B.POST_RIGHT, w = B.POST_W, h = BAND_H, point = "BOTTOMRIGHT", show = true }
local RUN = {}   -- a floor run's coords, refilled per run
local HANDLE_TIP = { anchor = "ANCHOR_TOP", text = "Micro Menu", r = 1, g = 1, b = 1, lines = {
    { "Drag to move. Let go near the bar to put it back.", 1, 0.82, 0 },
    { "Click for its size and reset. The mouse wheel sizes it too.", 1, 0.82, 0 },
} }

-- This client's micro buttons in its order, read once before any is reparented (retail 13, Forever 14).
local microButtons

local function MapButtonTip()
    local key = GetBindingKey("TOGGLEWORLDMAP")
    return (WORLDMAP_BUTTON or "World Map") .. (key and (" (" .. key .. ")") or "")
end
local MAP_TIP = { text = MapButtonTip, r = 1, g = 1, b = 1 }

local function ToggleMap()
    if ToggleWorldMap then ToggleWorldMap() end
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

local function MicroButtonList()
    if microButtons then return microButtons end
    local found = {}
    if MicroMenu then
        for _, child in ipairs({ MicroMenu:GetChildren() }) do
            if child.layoutIndex and child.PostAddButtonCallback then found[#found + 1] = child end
        end
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
    microButtons = found
    return found
end
B.MicroButtonList = MicroButtonList
ns.MicroButtonList = MicroButtonList

-- The band was drawn for ten micro buttons, later clients have 13-14. All stay: the row starts at x 556
-- with the 1.x overlap, scaled as a whole to end at the post before the key ring.
local function MicroNeed(count)
    return count * (MICRO_W + MICRO_STEP) - MICRO_STEP
end

-- Row scale and region for this many buttons: fitted to the old art's room, times the player's size
-- (settable on the band too, even past the art); snapping the group back restores default size.
local function MicroPlan(count, userScale)
    local need = MicroNeed(count)
    if need <= 0 then return 1, MICRO_LEAD + MICRO_END_GAP end
    local room = MICRO_REGION_MAX - MICRO_LEAD - MICRO_END_GAP
    local scale = math.min(1, room / need) * (userScale or 1)
    local region = math.ceil(MICRO_LEAD + need * scale + MICRO_END_GAP)
    return scale, math.min(MICRO_REGION_MAX, region)
end
B.MicroPlan = MicroPlan

-- Copy of the client's edit mode box layout (local to its file): same nine pieces, same names.
local SELECTION_LAYOUT = {
    TopRightCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = 8 },
    TopLeftCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = 8 },
    BottomLeftCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = -8 },
    BottomRightCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = -8 },
    TopEdge = { atlas = "_%s-NineSlice-EdgeTop" },
    BottomEdge = { atlas = "_%s-NineSlice-EdgeBottom" },
    LeftEdge = { atlas = "!%s-NineSlice-EdgeLeft" },
    RightEdge = { atlas = "!%s-NineSlice-EdgeRight" },
    Center = { atlas = "%s-NineSlice-Center", x = -8, y = 8, x1 = 8, y1 = -8 },
}

local function Percent(value) return string.format("%d%%", value) end

local function RefreshMicroDialog()
    local dialog = B.art.microDialog
    if dialog and dialog:IsShown() then dialog:Refresh() end
end

-- Micro group settings shaped like the client's edit mode dialog (same templates); the client has none for a piece not its own.
local function MicroDialog()
    local art = B.art
    local dialog = art.microDialog
    if dialog then return dialog end
    dialog = CreateFrame("Frame", "ForeverClassicUIMicroDialog", UIParent)
    dialog:SetSize(383, 204)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(200)
    ns.MakeDraggable(dialog)
    dialog:Hide()
    art.microDialog = dialog
    B.PanelBorder(dialog)

    local title = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    title:SetPoint("TOP", dialog, "TOP", 0, -15)
    title:SetText("Micro Menu")

    local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() dialog:Hide() end)
    ns.EditModeClose(close)

    local label = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    label:SetSize(100, 32)
    label:SetJustifyH("LEFT")
    label:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -48)
    label:SetText(HUD_EDIT_MODE_SETTING_MICRO_MENU_SIZE or "Size")

    local slider, formatters = B.StepperSlider(dialog, 200, label, 5, Percent)
    if slider then
        dialog.slider = slider
        dialog.InitSlider = function()
            dialog.filling = true
            slider:Init(math.floor(MicroUserScale() * 100 + 0.5), 50, 200, 30, formatters)
            dialog.filling = false
        end
        B.OnSliderValue(slider, function(_, value)
            if dialog.filling or type(value) ~= "number" then return end
            ns.MicroTouched()
            ns.db.microScale = math.max(0.5, math.min(2, value / 100))
            ns.MirrorSave()
            ns.QueueApply()
        end, dialog)
    end

    local reset = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    reset:SetSize(330, 28)
    reset:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 22)
    reset:SetText(HUD_EDIT_MODE_RESET_POSITION or "Reset To Default Position")
    reset:SetScript("OnClick", function()
        -- Back in its place means default size too, so the pieces fit.
        ns.MicroTouched()
        ns.db.microPos, ns.db.microScale = nil, nil
        ns.MirrorSave()
        dialog:Refresh()
        ns.QueueApply()
    end)
    dialog.reset = reset
    ns.EditModeRed(reset)

    local resize = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    resize:SetSize(330, 28)
    resize:SetPoint("BOTTOM", reset, "TOP", 0, 6)
    resize:SetText("Reset To Default Size")
    resize:SetScript("OnClick", function()
        ns.MicroTouched()
        ns.db.microScale = nil
        ns.MirrorSave()
        dialog:Refresh()
        ns.QueueApply()
    end)
    dialog.resize = resize
    ns.EditModeRed(resize)

    function dialog:Refresh()
        if self.InitSlider then self.InitSlider() end
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

    -- Edit mode handle over it, in the client's strata for its own (inside the edit mode window's layer it covered that window).
    local handle = CreateFrame("Frame", nil, home)
    handle:SetAllPoints(home)
    handle:SetFrameStrata("MEDIUM")
    handle:SetFrameLevel(1010)
    handle:EnableMouse(true)
    handle:EnableMouseWheel(true)
    handle:RegisterForDrag("LeftButton")
    handle:Hide()
    -- The client's box for its own pieces: blue, yellow while held.
    local function DressBox(kit)
        if handle.kit == kit then return end
        handle.kit = kit
        if NineSliceUtil and NineSliceUtil.ApplyLayout then
            pcall(NineSliceUtil.ApplyLayout, handle, SELECTION_LAYOUT, kit)
        end
    end
    handle.Dress = DressBox
    DressBox("editmode-actionbar-highlight")
    local label = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    label:SetPoint("CENTER", handle, "CENTER", 0, 0)
    label:SetText("Micro Menu")
    local function Undrag() home.dragged = false end
    handle:SetScript("OnDragStart", function(self)
        -- Movable in a fight too while the group is free: it is ours and nothing protected hangs from it (rows are put back after).
        if InCombatLockdown() and home:IsProtected() then return end
        DressBox("editmode-actionbar-selected")
        home.moving, home.dragged = true, true
        home:StartMoving()
        -- The band redraws as the group crosses the snap-back line, so the drop's result shows first.
        self:SetScript("OnUpdate", function()
            if OneBar() then return end
            -- The full pass waits out a fight; the rows need not.
            if B.PreviewDrop("micro", home) then ns.MicroDroppedInFight() end
        end)
    end)
    handle:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        home:StopMovingOrSizing()
        home.moving = false
        C_Timer.After(0, Undrag)
        local dragPreview = B.dragPreview
        local place = DropPlace("micro", home, dragPreview.bagsFirst)
        dragPreview.micro, dragPreview.bagsFirst = nil, nil
        DressBox("editmode-actionbar-highlight")
        -- Dropped near its place on the bar: back onto the bar.
        if place ~= nil then
            ns.MicroTouched()
            ns.db.microPos, ns.db.microScale = nil, nil
            ns.db.bagsFirst = place
            ns.MirrorSave()
        else
            local point, _, relPoint, x, y = home:GetPoint(1)
            ns.MicroTouched()
            ns.db.microPos = { point = point, relPoint = relPoint, x = x, y = y }
            ns.MirrorSave()
        end
        RefreshMicroDialog()
        ns.QueueApply()
        ns.MicroDroppedInFight()
    end)
    handle:SetScript("OnMouseWheel", function(_, delta)
        ns.MicroTouched()
        ns.db.microScale = math.max(0.5, math.min(2, MicroUserScale() + 0.05 * delta))
        ns.MirrorSave()
        RefreshMicroDialog()
        ns.QueueApply()
    end)
    handle:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            ns.MicroTouched()
            ns.db.microPos, ns.db.microScale = nil, nil
            ns.MirrorSave()
            RefreshMicroDialog()
            ns.QueueApply()
            return
        end
        -- A click selects it and opens its settings, as edit mode does; the release ending a drag is not a click.
        if home.moving or home.dragged then return end
        local dialog = MicroDialog()
        DressBox("editmode-actionbar-selected")
        dialog:ClearAllPoints()
        dialog:SetPoint("BOTTOM", home, "TOP", 0, 40)
        dialog:Show()
    end)
    ns.AttachTip(handle, HANDLE_TIP)
    home.handle = handle
    return home
end

local microBusy = false
function B.LayoutMicroButtons()
    if microBusy then return end
    microBusy = true
    local art = B.art
    -- Every button leaves the client's menu, shown or not, so its layout never finds a lone child without a position.
    local wanted = {}
    for _, button in ipairs(MicroButtonList()) do
        Remember(button)
        if button:GetParent() ~= art then button:SetParent(art) end
        if MICRO_SKIP[button:GetName() or ""] then
            button:ClearAllPoints()
            button:SetAlpha(0)
        elseif button:IsShown() then
            wanted[#wanted + 1] = button
        end
    end
    if #wanted == 0 then microBusy = false return end
    -- Off the band (moved, or one-bar corner) the chosen size rides on the group frame with the band scale
    -- divided out; on it the row itself is drawn bigger or smaller.
    local out = (not B.shape.micro) or OneBar()
    local group = out and MicroUserScale() or 1
    local scale, region = MicroPlan(#wanted, out and 1 or MicroUserScale())
    -- The row at its own scale: what the band's sockets were drawn around.
    local baseScale = MicroPlan(#wanted, 1)
    local bandScale = BandNow()
    local homeScale = out and (group / bandScale) or 1
    local buttonScale = scale * homeScale
    local level = ButtonLevel()

    local home = MicroHome()
    local plan = CurrentPlan()
    local groupX, rowIn = MICRO_GROUP_X, MICRO_ROW_IN
    if not out and plan.microRow then
        -- Seen in game: the row reads 2 px right of its room, the left gap wider than the right.
        local row = plan.microRow - MICRO_NUDGE
        -- The box never reaches into the bag part before it (a row standing last sits close to it).
        groupX = math.max(plan.microStart, row - MICRO_ROW_IN)
        rowIn = row - groupX
    end
    local groupW = (not out and plan.microEnd) and (plan.microEnd - groupX) or ((ART_W / 2 + region) - MICRO_GROUP_X)
    home:SetSize(groupW, BAND_H)
    home:SetScale(homeScale)
    home:SetFrameLevel(math.max(0, level - 1))
    if not home.moving then
        home:ClearAllPoints()
        local pos = ns.db.microPos
        if pos then
            home:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or "CENTER", pos.x or 0, pos.y or 0)
        elseif OneBar() then
            home:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", CORNER_X, 0)
        else
            home:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", groupX, 0)
        end
    end
    home:Show()
    -- Off the band only, its floor: the third sheet's run it stood on, plus the dark start of the fourth where the row reaches it.
    local third = math.min(region, 256)
    local runs = {
        { 3, (MICRO_GROUP_X - 512) / 256, third / 256, third - (MICRO_GROUP_X - 512), 0 },
        { 4, 0, math.max(0, region - 256) / 256, math.max(0, region - 256), third - (MICRO_GROUP_X - 512) },
    }
    for i, tex in ipairs(home.floor) do
        local run = runs[i]
        if out and run[4] > 0 then
            local sheet = PIECES[run[1]]
            RUN[1], RUN[2], RUN[3], RUN[4] = run[2], run[3], sheet.band[1], sheet.band[2]
            Dress(tex, sheet.key, B.BAND_RUN, home, run[5], 0, run[4], BAND_H, RUN)
        else
            tex:Hide()
        end
    end
    for i, post in ipairs(home.posts) do
        if out then
            Dress(post, POST_SHEET.key, i == 1 and END_POST_LEFT or END_POST_RIGHT, home)
        else
            post:Hide()
        end
    end

    local prev
    for _, button in ipairs(wanted) do
        Seat(button, buttonScale, MICRO_W, MICRO_H, level)
        if prev then
            button:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", MICRO_STEP, 0)
        else
            -- From the group corner by band numbers, read in the button's scale. On the band the row stays centred
            -- on the sockets (hung from the floor, a resized row grew out of them); off it the whole group scales.
            local rowY = MICRO_Y
            if not out then rowY = MICRO_Y + MICRO_H * (baseScale - scale) / 2 end
            button:SetPoint("BOTTOMLEFT", home, "BOTTOMLEFT", rowIn / scale, rowY / scale)
        end
        ns.SkinMicroButton(button)
        prev = button
    end
    if MicroMenu then
        if MicroMenu.BorderArt then MicroMenu.BorderArt:SetAlpha(0) end
        if MicroMenu.BackgroundArt then MicroMenu.BackgroundArt:SetAlpha(0) end
    end
    microBusy = false
end
