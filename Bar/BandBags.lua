local _, ns = ...
local B = ns.band

-- Bag row: on the band's bag part, off it on the client's bags piece, or in one-bar mode's corner;
-- plus our panel under edit mode's Bags dialog.

local BAND_H, CORNER_X, BAG_PART, POST_W = B.BAND_H, B.CORNER_X, B.BAG_PART, B.POST_W
local BAG_BUTTONS, PIECES = B.BAG_BUTTONS, B.PIECES
-- Band sheet sockets: bags at a 34 px pitch (28 inside), backpack wider and 38 past the last bag, key ring hole
-- 15 wide, all centred 22 up. 30 px buttons 2 apart sit inside; the backpack 4 in and 6 up.
local BAG_SIZE, BAG_OVERLAP, BACKPACK_GAP, BAGS_X, BAGS_Y = 30, -2, -2, -4, 6
local KEYRING_W, KEYRING_H, KEYRING_GAP = 18, 39, -5
-- No 1.x socket for the reagent bag: a small round button at the top corner between key ring and last bag.
local REAGENT_SIZE = 17
local BandNow, Seat, OneBar, MicroOut = B.BandNow, B.Seat, B.OneBar, B.MicroOut
local MicroUserScale, CurrentPlan, ButtonLevel = B.MicroUserScale, B.CurrentPlan, B.ButtonLevel
local Dress, FadeTextures = ns.Dress, ns.FadeTextures

local FLOOR_SHEET = PIECES[4]
-- The bag part as a floor, plus a post (mirrored: a left end) just outside the key ring.
local FLOOR_TEX = { tint = ns.BRONZE_SOFT, coords = { (256 - BAG_PART) / 256, 1, FLOOR_SHEET.band[1], FLOOR_SHEET.band[2] } }
local FLOOR_POST = { tint = ns.BRONZE_SOFT, coords = B.POST_LEFT, w = POST_W, h = BAND_H,
    point = "BOTTOMRIGHT", relPoint = "BOTTOMLEFT", x = 1, show = true }

-- The client's bag bar draws art behind the slots that shows round the key ring; fade it except on the bag buttons.
local function KeepsBag(child) return child.GetBagID or child.GetID end
local BAGS_BAR_ART = { children = true, skipChild = KeepsBag }

-- Lay a client edit mode piece over a band rectangle given in band pixels; the piece's own scale reads the offsets.
function ns.OverlayOnBand(frame, point, bandPoint, x, y, w, h, relativeTo)
    local art = B.art
    if not frame or not art then return end
    local fs = frame:GetEffectiveScale() / art:GetEffectiveScale()
    if not fs or fs <= 0 then fs = 1 end
    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo or art, bandPoint, x / fs, y / fs)
    frame:SetSize(w / fs, h / fs)
end

function B.LayoutBags()
    local backpack = MainMenuBarBackpackButton
    if not backpack then return end
    local art, shape = B.art, B.shape
    local piece = BagsBar
    local out = piece and not shape.bags
    local lift = (KEYRING_H - BAG_SIZE) / 2
    local home, homePoint, homeY = art, "BOTTOMRIGHT", BAGS_Y
    local homeX
    local buttonScale = 1
    local rowW = BAG_SIZE + (BAG_SIZE - BACKPACK_GAP) + 3 * (BAG_SIZE - BAG_OVERLAP)
    if KeyRingButton or CharacterReagentBag0Slot then rowW = rowW + KEYRING_W - KEYRING_GAP end
    -- On the band: socket size. Off it (moved, or one-bar corner): edit mode's Size with the band scale divided out.
    local band = BandNow()
    if piece and (out or OneBar()) then
        buttonScale = (piece:GetScale() or 1) / band
    elseif piece then
        -- The player's Size counts on the band too; snapping back resets it. The size worn when last snapped
        -- counts as socket size (no layout write); a Size picked later is theirs.
        buttonScale = piece:GetScale() or 1
        local snap = ns.db and ns.db.bagsSnapScale or 0
        if snap > 0 and math.abs(buttonScale - snap) < 0.001 then buttonScale = 1 end
    end
    if out then
        home, homeX, homeY = piece, 0, lift
    else
        local relativeTo
        if OneBar() then
            -- Over the micro group while it stands in the corner, else on the floor.
            local under = MicroOut() and 0 or BAND_H * MicroUserScale() / band
            relativeTo, homeX, homeY = art.sideAnchor, CORNER_X - 4 * buttonScale, under + 6 * buttonScale
        else
            -- By the plan: the bags are not always last on the band.
            local plan = CurrentPlan()
            homePoint, homeX = "BOTTOMLEFT", (plan.bagsStart or (plan.width - BAG_PART)) + BAG_PART + BAGS_X
        end
        -- The row hangs from the client's bags piece, laid over it first, so edit mode's box sits on the bags
        -- and a drag carries them. A piece mid-drag stays in the player's hand.
        if piece then
            if not piece.isDragging then
                -- Its own anchor kept: the hand-back puts it back without running edit mode's anchor pass.
                B.Remember(piece, true)
                ns.OverlayOnBand(piece, "BOTTOMRIGHT", homePoint, homeX, homeY - lift * buttonScale, rowW * buttonScale, KEYRING_H * buttonScale, relativeTo)
            end
            home, homePoint, homeX, homeY = piece, "BOTTOMRIGHT", 0, lift
        elseif relativeTo then
            home = relativeTo
        end
    end
    local level = ButtonLevel()
    local prev
    -- Right to left: backpack in the corner, four bags overlapping by 2, then the key ring hole.
    for _, name in ipairs(BAG_BUTTONS) do
        local button = _G[name]
        if button then
            Seat(button, buttonScale, BAG_SIZE, BAG_SIZE, level)
            if not prev then
                button:SetPoint("BOTTOMRIGHT", home, homePoint, homeX / buttonScale, homeY / buttonScale)
            elseif prev == backpack then
                button:SetPoint("RIGHT", prev, "LEFT", BACKPACK_GAP, 0)
            else
                button:SetPoint("RIGHT", prev, "LEFT", BAG_OVERLAP, 0)
            end
            ns.SkinBagButton(button, BAG_SIZE, name == "MainMenuBarBackpackButton")
            button:Show()
            prev = button
        end
    end
    local lastBag = prev
    -- The key ring hole holds the key ring, or on a client without one the reagent bag.
    local slim = KeyRingButton or CharacterReagentBag0Slot
    if slim then
        Seat(slim, buttonScale, KEYRING_W, KEYRING_H, level)
        slim:SetPoint("RIGHT", prev, "LEFT", KEYRING_GAP, 0)
        ns.SkinKeyRing(slim)
    end
    if KeyRingButton and CharacterReagentBag0Slot then
        -- Both (Forever): the reagent bag is the small round one, centred level with the bags between key ring and last bag.
        local reagent = CharacterReagentBag0Slot
        Seat(reagent, buttonScale, REAGENT_SIZE, REAGENT_SIZE, level + 2)
        reagent:SetPoint("CENTER", lastBag, "LEFT", -2, 0)
        ns.SkinBagButton(reagent, REAGENT_SIZE, false, true)
    end
    -- Once moved, the piece is only sized to its row.
    if piece and out then piece:SetSize(rowW, KEYRING_H) end
    -- Off the band the row carries a floor of band art: empty slots were see-through and show their dim bag
    -- from it; a post closes the group on the left.
    local floor = art.bagFloor
    local floating = (out or OneBar()) and true or false
    if floating then
        if not floor then
            floor = CreateFrame("Frame", nil, art)
            floor:SetSize(BAG_PART, BAND_H)
            floor.tex = floor:CreateTexture(nil, "BACKGROUND")
            floor.tex:SetAllPoints(floor)
            floor.post = floor:CreateTexture(nil, "BORDER")
            art.bagFloor = floor
        end
        Dress(floor.post, FLOOR_SHEET.key, FLOOR_POST, floor)
        Dress(floor.tex, FLOOR_SHEET.key, FLOOR_TEX)
        floor:SetScale(buttonScale)
        floor:SetFrameLevel(math.max(0, level - 1))
        floor:ClearAllPoints()
        floor:SetPoint("BOTTOMRIGHT", backpack, "BOTTOMRIGHT", -BAGS_X, -BAGS_Y)
        floor:Show()
    elseif floor then
        floor:Hide()
    end
    if BagBarExpandToggle then BagBarExpandToggle:Hide() end
    if BagsBar then FadeTextures(BagsBar, 0, BAGS_BAR_ART) end
end

local function BagsCheck(extra, rel, relPoint, x, y, label, onClick)
    local check = CreateFrame("CheckButton", nil, extra, "UICheckButtonTemplate")
    check:SetSize(30, 30)
    check:SetPoint("TOPLEFT", rel, relPoint, x, y)
    check:SetScript("OnClick", onClick)
    ns.EditModeCheck(check)
    local text = extra:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    text:SetPoint("LEFT", check, "RIGHT", 6, 0)
    text:SetText(label)
    return check
end

local function FollowClick(self)
    ns.db.bagWindowsFollow = self:GetChecked() and true or false
end

-- The addon's own "opened bags above the bag buttons" and "one bag" toggles.
local function AboveClick(self)
    ns.db.bagsAboveRow = self:GetChecked() and true or false
    ns.ToggleChanged("bagsAboveRow")
end

local function WholeNumber(value) return tostring(math.floor(value + 0.5)) end

-- Reset To Default Size (the client's dialog lacks it), beside Revert Changes; goes through the client's
-- dialog-setting entry point so it is an ordinary edit (saved or reverted with the rest).
local function ResetBagsSize()
    local setting = Enum and Enum.EditModeBagsSetting and Enum.EditModeBagsSetting.Size
    local manager = EditModeManagerFrame
    if setting == nil or not manager or not manager.OnSystemSettingChange or not BagsBar then return end
    pcall(manager.OnSystemSettingChange, manager, BagsBar, setting, 100)
    ns.editWrote = true
    local dialog = EditModeSystemSettingsDialog
    if dialog and dialog.UpdateDialog then pcall(dialog.UpdateDialog, dialog, BagsBar) end
end

-- Our bag settings panel, hung under edit mode's Bags dialog while it is up: beside it, not in it
-- (the dialog would count a child into its size).
local function BagsExtra()
    local art = B.art
    local extra = art.bagsExtra
    if extra then return extra end
    extra = CreateFrame("Frame", "ForeverClassicUIBagsExtra", UIParent)
    extra:SetFrameStrata("DIALOG")
    extra:SetFrameLevel(200)
    extra:SetHeight(184)
    extra:Hide()
    art.bagsExtra = extra
    B.PanelBorder(extra)
    local check = BagsCheck(extra, extra, "TOPLEFT", 22, -14, "Opened bags take this size too", FollowClick)
    extra.check = check
    local above = BagsCheck(extra, check, "BOTTOMLEFT", 0, -2, "Opened bags above the bag buttons", AboveClick)
    extra.above = above
    local one = BagsCheck(extra, above, "BOTTOMLEFT", 0, -2, "One bag: all bags open as one window", function(self)
        ns.db.oneBag = self:GetChecked() and true or false
        ns.ToggleChanged("oneBag")
        if extra.InitColumns then extra.InitColumns() end
    end)
    extra.one = one
    -- One bag window's width in slots; only with One bag on.
    local colsLabel = extra:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    colsLabel:SetPoint("TOPLEFT", one, "BOTTOMLEFT", 6, -10)
    colsLabel:SetText("One bag columns")
    extra.colsLabel = colsLabel
    local slider, formatters = B.StepperSlider(extra, 180, colsLabel, 10, WholeNumber)
    if slider then
        extra.slider = slider
        local low, high = ns.ONE_BAG_COLUMNS_MIN or 4, ns.ONE_BAG_COLUMNS_MAX or 16
        extra.InitColumns = function()
            extra.filling = true
            slider:Init(tonumber(ns.db.oneBagColumns) or low, low, high, high - low, formatters)
            extra.filling = false
            local on = ns.db.oneBag == true
            slider:SetAlpha(on and 1 or 0.4)
            if slider.SetEnabled then pcall(slider.SetEnabled, slider, on) end
            colsLabel:SetFontObject(on and "GameFontHighlightMedium" or "GameFontDisableMed3")
        end
        B.OnSliderValue(slider, function(_, value)
            if extra.filling or type(value) ~= "number" or not ns.SetOneBagColumns then return end
            ns.SetOneBagColumns(value)
        end, extra)
    end
    -- Addon settings save on click, outside Save/Revert, and say so (a dark Save reads as "nothing happened").
    local saved = extra:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    saved:SetPoint("BOTTOMLEFT", extra, "BOTTOMLEFT", 26, 14)
    saved:SetText("These apply and save the moment you change them. No Save needed.")
    local resize = CreateFrame("Button", nil, extra, "UIPanelButtonTemplate")
    resize:SetHeight(28)
    resize:SetText("Reset To Default Size")
    resize:SetFrameLevel(210)
    resize:SetScript("OnClick", ResetBagsSize)
    ns.EditModeRed(resize)
    extra.resize = resize
    return extra
end

function B.FollowBagsDialog(editing)
    local dialog = EditModeSystemSettingsDialog
    local up = editing and dialog and dialog:IsShown() and dialog.attachedToSystem == BagsBar
    local extra = B.art and B.art.bagsExtra
    if not up then
        if extra and extra:IsShown() then extra:Hide() end
        return
    end
    extra = BagsExtra()
    extra:ClearAllPoints()
    extra:SetPoint("TOPLEFT", dialog, "BOTTOMLEFT", 0, 6)
    extra:SetPoint("TOPRIGHT", dialog, "BOTTOMRIGHT", 0, 6)
    extra.check:SetChecked(ns.db.bagWindowsFollow and true or false)
    if extra.one then extra.one:SetChecked(ns.db.oneBag == true) end
    if extra.above then extra.above:SetChecked(ns.db.bagsAboveRow == true) end
    if extra.InitColumns then extra.InitColumns() end
    local revert = dialog.Buttons and dialog.Buttons.RevertChangesButton
    if revert and extra.resize then
        extra.resize:ClearAllPoints()
        extra.resize:SetPoint("LEFT", revert, "RIGHT", 6, 0)
        extra.resize:SetPoint("RIGHT", dialog.Buttons, "RIGHT", 0, 0)
        extra.resize:Show()
    elseif extra.resize then
        extra.resize:Hide()
    end
    extra:Show()
end
