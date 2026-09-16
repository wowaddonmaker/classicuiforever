local _, ns = ...

-- The 1.x main menu bar: a 1024x53 stone band centered at the bottom with
-- a gryphon on each end. Blizzard's action buttons, page arrows, micro
-- buttons, bags and experience bars are anchored onto it in their 2004
-- spots. Edit mode keeps working for everything else, and while edit mode
-- is open the bar hands everything back so the layout can be seen as is.

local ART_W, ART_H = 1024, 53
local PIECE_W, PIECE_H = 256, 43
local CAP_SIZE = 128
local BUTTON_SIZE, BUTTON_PITCH = 36, 42   -- 36px buttons, 6px apart
local ROW_X, ROW_Y = 8, 4                   -- first button from the band's corner
local UPPER_ROW_Y = 59                      -- bottom-left/right bars above the band
local XP_Y = 40                             -- experience bar sits on the band's top edge
local MICRO_X, MICRO_Y = 552, 2
local BAGS_X, BAGS_Y = -4, 6
local PAGE_X, PAGE_UP_Y, PAGE_DOWN_Y = 522, -22, -42

-- Rows of the 256x256 stone sheets as the 1.x bar sliced them (top, bottom).
local PIECES = {
    { x = -384, key = "barBody", top = 0.83203125, bottom = 1.0 },
    { x = -128, key = "barBody", top = 0.58203125, bottom = 0.75 },
    { x = 128, key = "barBody", top = 0.33203125, bottom = 0.5 },
    { x = 384, key = "barBody", top = 0.08203125, bottom = 0.25, keyringKey = "barKeyring", keyringTop = 0.1640625, keyringBottom = 0.33203125 },
}

local art
local active = false
local pending = false
local restoreQueued = false
local hooked = {}
local saved = {}   -- frame -> { scale = n }

local function InEditMode()
    return EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive()
end

local function Remember(frame)
    if not saved[frame] then
        saved[frame] = { scale = frame:GetScale() }
    end
end

local function BuildArt()
    art = CreateFrame("Frame", "ForeverClassicUIBar", UIParent)
    art:SetSize(ART_W, ART_H)
    art:SetFrameStrata("MEDIUM")
    art:SetFrameLevel(1)
    art.pieces = {}
    for i, piece in ipairs(PIECES) do
        local tex = art:CreateTexture(nil, "BACKGROUND")
        tex:SetSize(PIECE_W, PIECE_H)
        tex:SetPoint("BOTTOM", art, "BOTTOM", piece.x, 0)
        art.pieces[i] = tex
    end
    art.leftCap = art:CreateTexture(nil, "OVERLAY", nil, 5)
    art.leftCap:SetSize(CAP_SIZE, CAP_SIZE)
    art.leftCap:SetPoint("BOTTOM", art, "BOTTOM", -544, 0)
    art.rightCap = art:CreateTexture(nil, "OVERLAY", nil, 5)
    art.rightCap:SetSize(CAP_SIZE, CAP_SIZE)
    art.rightCap:SetPoint("BOTTOM", art, "BOTTOM", 544, 0)
    -- The thin bar drawn along the top when no experience bar is shown.
    art.maxLevel = {}
    for i = 1, 4 do
        local tex = art:CreateTexture(nil, "BACKGROUND")
        tex:SetSize(256, 7)
        tex:SetPoint("BOTTOM", art, "TOP", -384 + (i - 1) * 256, -11)
        art.maxLevel[i] = tex
    end
    -- Rows are scaled children so button offsets can be written in 1.x pixels.
    art.rows = {}
end

local function PaintArt()
    local hasKeyring = KeyRingButton ~= nil
    for i, piece in ipairs(PIECES) do
        local tex = art.pieces[i]
        if piece.keyringKey and hasKeyring then
            ns.SetTex(tex, piece.keyringKey)
            tex:SetTexCoord(0, 1, piece.keyringTop, piece.keyringBottom)
        else
            ns.SetTex(tex, piece.key)
            tex:SetTexCoord(0, 1, piece.top, piece.bottom)
        end
    end
    ns.SetTex(art.leftCap, "endCap")
    art.leftCap:SetTexCoord(0, 1, 0, 1)
    ns.SetTex(art.rightCap, "endCap")
    art.rightCap:SetTexCoord(1, 0, 0, 1)
    for i, tex in ipairs(art.maxLevel) do
        ns.SetTex(tex, "maxLevel")
        tex:SetTexCoord(0, 1, (i - 1) * 0.25, (i - 1) * 0.25 + 0.21875)
    end
end

local function Row(index)
    local row = art.rows[index]
    if not row then
        row = CreateFrame("Frame", nil, art)
        row:SetSize(1, 1)
        art.rows[index] = row
    end
    return row
end

-- A bar's 12 buttons in a 1.x row: containers re-anchored onto a scaled
-- row frame so the buttons come out at 36px, 6px apart.
local function LayoutButtons(bar, rowIndex, x, y)
    if not bar or not bar.actionButtons then return end
    local first = bar.actionButtons[1]
    local size = first and first:GetWidth() or 45
    if not size or size == 0 then size = 45 end
    local scale = BUTTON_SIZE / size
    local row = Row(rowIndex)
    row:SetScale(scale)
    row:ClearAllPoints()
    -- Offsets are read in the row's own scale, so convert from band pixels.
    row:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", x / scale, y / scale)
    for i, button in ipairs(bar.actionButtons) do
        local container = button.container
        if container then
            Remember(container)
            container:SetScale(scale)
            container:ClearAllPoints()
            container:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", (i - 1) * BUTTON_PITCH / scale, 0)
        end
    end
end

local function RestoreButtons(bar)
    if not bar or not bar.actionButtons then return end
    for _, button in ipairs(bar.actionButtons) do
        local container = button.container
        if container and saved[container] then
            container:SetScale(saved[container].scale)
            saved[container] = nil
        end
    end
    -- Blizzard lays the containers out again from its own settings.
    bar.oldGridSettings = nil
    if bar.UpdateGridLayout then bar:UpdateGridLayout() end
end

local function Anchor(frame, point, relPoint, x, y, scale)
    if not frame then return end
    Remember(frame)
    frame:ClearAllPoints()
    frame:SetPoint(point, art, relPoint, x, y)
    if scale then frame:SetScale(scale) end
end

local function LayoutPageArrows(bar)
    local pn = bar.ActionBarPageNumber
    if not pn then return end
    pn:ClearAllPoints()
    pn:SetPoint("CENTER", art, "TOPLEFT", PAGE_X, (PAGE_UP_Y + PAGE_DOWN_Y) / 2)
    pn:SetSize(32, 44)
    pn:SetScale(1)
    if pn.UpButton then
        pn.UpButton:ClearAllPoints()
        pn.UpButton:SetPoint("CENTER", art, "TOPLEFT", PAGE_X, PAGE_UP_Y)
    end
    if pn.DownButton then
        pn.DownButton:ClearAllPoints()
        pn.DownButton:SetPoint("CENTER", art, "TOPLEFT", PAGE_X, PAGE_DOWN_Y)
    end
    if pn.Text then
        pn.Text:ClearAllPoints()
        pn.Text:SetPoint("CENTER", art, "CENTER", 30, -5)
    end
end

-- Micro buttons and bags share the right half of the band. The modern
-- micro menu is wider than the ten 1.x buttons, so it is scaled to fit
-- between its 1.x spot and the bags.
local function LayoutMicroAndBags()
    local bags = BagsBar
    if bags then
        Anchor(bags, "BOTTOMRIGHT", "BOTTOMRIGHT", BAGS_X, BAGS_Y, 1)
        if bags.BorderArt then bags.BorderArt:SetAlpha(0) end
    end
    local micro = MicroMenuContainer or MicroMenu
    if micro then
        local bagsWidth = bags and bags:IsShown() and bags:GetWidth() or 0
        local avail = ART_W - MICRO_X + BAGS_X - bagsWidth - 6
        local width = micro:GetWidth()
        local scale = 1
        if width and width > 0 and width > avail then
            scale = avail / width
        end
        Anchor(micro, "BOTTOMLEFT", "BOTTOMLEFT", MICRO_X / scale, MICRO_Y / scale, scale)
        if MicroMenu then
            if MicroMenu.BorderArt then MicroMenu.BorderArt:SetAlpha(0) end
            if MicroMenu.BackgroundArt then MicroMenu.BackgroundArt:SetAlpha(0) end
        end
    end
end

local function LayoutStatusBars()
    local main = MainStatusTrackingBarContainer
    local second = SecondaryStatusTrackingBarContainer
    if main then
        Anchor(main, "BOTTOM", "BOTTOM", 0, XP_Y, 1)
        if main.BarFrameTexture then main.BarFrameTexture:SetAlpha(0) end
    end
    if second then
        Anchor(second, "BOTTOM", "BOTTOM", 0, XP_Y + (main and main:GetHeight() or 13), 1)
        if second.BarFrameTexture then second.BarFrameTexture:SetAlpha(0) end
    end
    local anyShown = (main and main:IsShown()) or (second and second:IsShown())
    for _, tex in ipairs(art.maxLevel) do tex:SetShown(not anyShown) end
end

local function Layout()
    local bar = ns.GetMainBar()
    if not bar then return end
    art:SetScale(ns.db.barScale or 1)
    art:ClearAllPoints()
    art:SetPoint("BOTTOM", UIParent, "BOTTOM", ns.db.barOffsetX or 0, ns.db.barOffsetY or 0)
    art:Show()
    PaintArt()

    -- The bars drop their edit-mode scale so band pixels and button pixels agree.
    Remember(bar)
    bar:SetScale(1)
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOM", art, "BOTTOM", 0, 0)
    bar:SetSize(ART_W, ART_H)
    if bar.EndCaps then bar.EndCaps:Hide() end
    if bar.BorderArt then bar.BorderArt:SetAlpha(0) end
    if bar.HorizontalDividersPool then bar.HorizontalDividersPool:ReleaseAll() end
    if bar.VerticalDividersPool then bar.VerticalDividersPool:ReleaseAll() end
    LayoutButtons(bar, 1, ROW_X, ROW_Y)
    LayoutPageArrows(bar)

    local lower, upper = MultiBarBottomLeft, MultiBarBottomRight
    if lower then
        Anchor(lower, "BOTTOMLEFT", "BOTTOMLEFT", ROW_X, UPPER_ROW_Y, 1)
        LayoutButtons(lower, 2, ROW_X, UPPER_ROW_Y)
    end
    if upper then
        Anchor(upper, "BOTTOMLEFT", "BOTTOMLEFT", ROW_X + 12 * BUTTON_PITCH + 8, UPPER_ROW_Y, 1)
        LayoutButtons(upper, 3, ROW_X + 12 * BUTTON_PITCH + 8, UPPER_ROW_Y)
    end
    LayoutMicroAndBags()
    LayoutStatusBars()
end

-- Everything here moves protected frames, so it only runs out of combat
-- and never while edit mode owns the screen.
local function Apply()
    if not art then BuildArt() end
    active = true
    if InEditMode() then
        art:Hide()
        return
    end
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    Layout()
end

local function Restore()
    if not active then return end
    if InCombatLockdown() then
        restoreQueued = true
        return
    end
    active = false
    restoreQueued = false
    if art then art:Hide() end
    local bar = ns.GetMainBar()
    for frame, state in pairs(saved) do
        frame:SetScale(state.scale)
    end
    wipe(saved)
    RestoreButtons(bar)
    RestoreButtons(MultiBarBottomLeft)
    RestoreButtons(MultiBarBottomRight)
    if bar then
        if bar.BorderArt then bar.BorderArt:SetAlpha(1) end
        if bar.UpdateEndCaps then bar:UpdateEndCaps(bar.hideBarArt) end
        if bar.UpdateDividers then bar:UpdateDividers() end
    end
    if MicroMenu then
        if MicroMenu.BorderArt then MicroMenu.BorderArt:SetAlpha(1) end
        if MicroMenu.BackgroundArt then MicroMenu.BackgroundArt:SetAlpha(1) end
    end
    if BagsBar and BagsBar.BorderArt then BagsBar.BorderArt:SetAlpha(1) end
    for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        if container and container.BarFrameTexture then container.BarFrameTexture:SetAlpha(1) end
    end
    -- Hand the anchors back to edit mode.
    for _, frame in ipairs({ bar, MultiBarBottomLeft, MultiBarBottomRight, MicroMenuContainer, BagsBar, MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        if frame and frame.ApplySystemAnchor then pcall(frame.ApplySystemAnchor, frame) end
    end
    if EditModeManagerFrame and EditModeManagerFrame.UpdateBottomActionBarPositions then
        pcall(EditModeManagerFrame.UpdateBottomActionBarPositions, EditModeManagerFrame)
    end
    if bar and bar.ActionBarPageNumber and bar.UpdateSystemSettingHideBarScrolling then
        pcall(bar.UpdateSystemSettingHideBarScrolling, bar)
    end
end

local function HookRelayout(frame, method)
    if not frame or hooked[frame] or type(rawget(frame, method)) ~= "function" then return end
    hooked[frame] = true
    hooksecurefunc(frame, method, function()
        if active and not InEditMode() then ns.QueueApply() end
    end)
end

local function Init()
    local bar = ns.GetMainBar()
    if not bar then return end
    -- Blizzard re-anchors these on every layout change; put them back after it.
    for _, frame in ipairs({ bar, MultiBarBottomLeft, MultiBarBottomRight, MicroMenuContainer, BagsBar, MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        HookRelayout(frame, "ApplySystemAnchor")
    end
    for _, frame in ipairs({ bar, MultiBarBottomLeft, MultiBarBottomRight }) do
        HookRelayout(frame, "UpdateGridLayout")
    end
    if EditModeManagerFrame then
        HookRelayout(EditModeManagerFrame, "UpdateBottomActionBarPositions")
    end
    if type(rawget(bar, "UpdateEndCaps")) == "function" then
        hooksecurefunc(bar, "UpdateEndCaps", function(self)
            if active and not InEditMode() and self.EndCaps then self.EndCaps:Hide() end
        end)
    end
    for _, frame in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer, BagsBar }) do
        if frame then
            frame:HookScript("OnShow", function() if active then ns.QueueApply() end end)
            frame:HookScript("OnHide", function() if active then ns.QueueApply() end end)
        end
    end
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:SetScript("OnEvent", function()
        if restoreQueued then
            Restore()
        elseif pending and active then
            ns.QueueApply()
        end
    end)
    if EventRegistry and EventRegistry.RegisterCallback then
        -- Edit mode gets the real layout while it is open.
        EventRegistry:RegisterCallback("EditMode.Enter", function()
            if active then
                local wasActive = active
                Restore()
                active = wasActive
            end
        end, watcher)
    end
end

function ns.ClassicBarInfo()
    if not art then return "not built" end
    return string.format("art shown=%s left=%.0f bottom=%.0f scale=%.2f pending=%s", tostring(art:IsShown()), art:GetLeft() or 0, art:GetBottom() or 0, art:GetScale(), tostring(pending))
end

ns.RegisterModule("classicBar", { init = Init, apply = Apply, restore = Restore })
