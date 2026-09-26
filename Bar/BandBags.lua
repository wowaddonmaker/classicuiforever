local _, ns = ...
local B = ns.band

-- Bag row: on the band's bag part, off it on the client's bags piece, or in one-bar mode's corner;
-- plus our panel under edit mode's Bags dialog.

local BAND_H, CORNER_X, BAG_PART = B.BAND_H, B.CORNER_X, B.BAG_PART
local BAG_BUTTONS, PIECES = B.BAG_BUTTONS, B.PIECES
-- The client's fourth sheet: five sockets repeating every 32 px after its bag post (walls peaking at u 124, 156, 188,
-- 220), all centred 22 up. 30 px buttons 2 apart sit centred on them; the backpack 5 in from the part's end and 6 up.
local BAG_SIZE, BAG_OVERLAP, BACKPACK_GAP, BAGS_X, BAGS_Y = 30, -2, -2, -5, 6
local KEYRING_W, KEYRING_H, KEYRING_GAP = 18, 39, -5
B.KEYRING_W, B.KEYRING_H = KEYRING_W, KEYRING_H
-- Round reagent bag (reagentBagSlot off): a small button at the top corner between key ring and last bag. On, it takes a
-- full slot left of the last bag (the band's extra socket) and the key ring moves out past it.
local REAGENT_SIZE = 17
local BandNow, Seat, OneBar, MicroOut = B.BandNow, B.Seat, B.OneBar, B.MicroOut
local MicroUserScale, CurrentPlan, ButtonLevel = B.MicroUserScale, B.CurrentPlan, B.ButtonLevel
local Dress, FadeTextures = ns.Dress, ns.FadeTextures

local FLOOR_SHEET = PIECES[4]
-- The bag part from its post as a floor (with the reagent slot: head, the extra socket, the rest).
local FLOOR_V0, FLOOR_V1 = FLOOR_SHEET.band[1], FLOOR_SHEET.band[2]
local FLOOR_TEX = { tint = ns.BRONZE_SOFT, coords = { (256 - BAG_PART) / 256, 1, FLOOR_V0, FLOOR_V1 } }

-- The client's bag bar draws art behind the slots that shows round the key ring; fade it except on the bag buttons.
local function KeepsBag(child) return child.GetBagID or child.GetID end
local BAGS_BAR_ART = { children = true, skipChild = KeepsBag }

-- Lay a client edit mode piece over a band rectangle given in band pixels; the piece's own scale reads the offsets.
function ns.OverlayOnBand(frame, point, bandPoint, x, y, w, h, relativeTo)
    local art = B.art
    if not frame or not art then return end
    local fs = frame:GetEffectiveScale() / art:GetEffectiveScale()
    if not fs or fs <= 0 then fs = 1 end
    ns.SetPointOnce(frame, point, relativeTo or art, bandPoint, x / fs, y / fs)
    frame:SetSize(w / fs, h / fs)
end

-- Off the band the row carries a floor of band art from the bags' own post (the key ring stays in the band's section).
-- With the reagent slot: head, the extra socket, then the rest.
local function FloorRun(floor, tex, x, width, u0, u1)
    Dress(tex, FLOOR_SHEET.key, FLOOR_TEX)
    ns.SetPointOnce(tex, "TOPLEFT", floor, "TOPLEFT", x, 0)
    tex:SetSize(width, BAND_H)
    tex:SetTexCoord(u0 / 256, u1 / 256, FLOOR_V0, FLOOR_V1)
    tex:Show()
end

local function LayFloor(art, square, floating, buttonScale, level, backpack)
    local floor = art.bagFloor
    if not floating then
        if floor then floor:Hide() end
        return
    end
    if not floor then
        floor = CreateFrame("Frame", nil, art)
        floor.tex = floor:CreateTexture(nil, "BACKGROUND")
        floor.socket = floor:CreateTexture(nil, "BACKGROUND")
        floor.rest = floor:CreateTexture(nil, "BACKGROUND")
        art.bagFloor = floor
    end
    floor:SetSize(B.BagPart() - B.BAG_TRIM, BAND_H)
    local u0 = 256 - BAG_PART + B.BAG_TRIM
    if square then
        local head, unit = B.SOCKET_U0 - u0, B.SOCKET_U1 - B.SOCKET_U0
        FloorRun(floor, floor.tex, 0, head, u0, B.SOCKET_U0)
        FloorRun(floor, floor.socket, head, unit, B.SOCKET_U0, B.SOCKET_U1)
        FloorRun(floor, floor.rest, head + unit, 256 - B.SOCKET_U0, B.SOCKET_U0, 256)
    else
        FloorRun(floor, floor.tex, 0, 256 - u0, u0, 256)
        floor.socket:Hide()
        floor.rest:Hide()
    end
    floor:SetScale(buttonScale)
    floor:SetFrameLevel(math.max(0, level - 1))
    ns.SetPointOnce(floor, "BOTTOMRIGHT", backpack, "BOTTOMRIGHT", -BAGS_X, -BAGS_Y)
    floor:Show()
end

-- A reagent bag equipped: off the full slot, the small round button shows only then (an empty one read as a lump).
local function ReagentHeld()
    local bag = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag or 5
    local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
    return ok and type(slots) == "number" and not ns.IsSecret(slots) and slots > 0 or false
end

local function ReagentSeen(reagent, seen)
    ns.SetAlphaIf(reagent, seen and 1 or 0)
    if reagent:IsMouseEnabled() ~= seen then reagent:EnableMouse(seen) end
end

-- What ends the bag row in its key ring hole: never the key ring (its own piece, BandSection.lua); on a client without
-- one, the round reagent bag.
local function RowSlim(square)
    if KeyRingButton then return nil end
    return (not square and CharacterReagentBag0Slot) or nil
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
    local square = B.ReagentSlot()
    local rowW = BAG_SIZE + (BAG_SIZE - BACKPACK_GAP) + 3 * (BAG_SIZE - BAG_OVERLAP)
    if square then rowW = rowW + BAG_SIZE - BAG_OVERLAP end
    local slim = RowSlim(square)
    if slim then rowW = rowW + KEYRING_W - KEYRING_GAP end
    -- On the band: socket size. Off it (moved, or one-bar corner): edit mode's Size with the band scale divided out.
    local band = BandNow()
    if piece and (out or OneBar()) then
        buttonScale = (piece:GetScale() or 1) / band
    elseif piece then
        -- The player's Size counts on the band too; snapping back resets it. The size worn when last snapped
        -- counts as socket size (no layout write); a Size picked later is theirs.
        buttonScale = piece:GetScale() or 1
        local snap = ns.db and ns.db.bagsSnapScale or 0
        if snap > 0 and ns.Near(buttonScale, snap, 0.001) then buttonScale = 1 end
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
            homePoint, homeX = "BOTTOMLEFT", (CurrentPlan().bagsEnd or CurrentPlan().width) + BAGS_X
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
    if square then
        local reagent = CharacterReagentBag0Slot
        Seat(reagent, buttonScale, BAG_SIZE, BAG_SIZE, level)
        reagent:SetPoint("RIGHT", prev, "LEFT", BAG_OVERLAP, 0)
        ns.SkinBagButton(reagent, BAG_SIZE, false, false)
        reagent:Show()
        ReagentSeen(reagent, true)
        prev = reagent
    end
    if slim then
        Seat(slim, buttonScale, KEYRING_W, KEYRING_H, level)
        slim:SetPoint("RIGHT", prev, "LEFT", KEYRING_GAP, 0)
        ns.SkinKeyRing(slim)
    end
    if not square and KeyRingButton and CharacterReagentBag0Slot then
        -- Both (Forever): the reagent bag is the small round one, centred level with the bags between key ring and last bag.
        local reagent = CharacterReagentBag0Slot
        Seat(reagent, buttonScale, REAGENT_SIZE, REAGENT_SIZE, level + 2)
        reagent:SetPoint("CENTER", lastBag, "LEFT", -2, 0)
        ns.SkinBagButton(reagent, REAGENT_SIZE, false, true)
        ReagentSeen(reagent, ReagentHeld())
    end
    -- Once moved, the piece is only sized to its row.
    if piece and out then piece:SetSize(rowW, KEYRING_H) end
    LayFloor(art, square, (out or OneBar()) and not ns.db.hideBagsArt, buttonScale, level, backpack)
    B.LaySection(level)
    if BagBarExpandToggle then BagBarExpandToggle:Hide() end
    if BagsBar then FadeTextures(BagsBar, 0, BAGS_BAR_ART) end
    B.BagDividers(0)
end

-- The client's dividers between its bag buttons (pooled frames on its bar) stood beside our row: faded, 1 gives them back.
local DIVIDER_POOLS = { "HorizontalDividersPool", "VerticalDividersPool" }
function B.BagDividers(alpha)
    for _, key in ipairs(DIVIDER_POOLS) do
        local pool = BagsBar and BagsBar[key]
        if pool and pool.EnumerateActive then
            for divider in pool:EnumerateActive() do ns.SetAlphaIf(divider, alpha) end
        end
    end
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

-- The one bag columns slider: its range, its write, and when it is live.
local function ColumnValues()
    local low, high = ns.ONE_BAG_COLUMNS_MIN or 4, ns.ONE_BAG_COLUMNS_MAX or 16
    return tonumber(ns.db.oneBagColumns) or low, low, high, high - low
end

local function OnColumns(value)
    if ns.SetOneBagColumns then ns.SetOneBagColumns(value) end
end

local function OneBagOn() return ns.db.oneBag == true end

-- Reset To Default Size (the client's dialog lacks it), beside Revert Changes: written as the interface reloads.
local function ResetBagsSize() ns.AskSizeReset("bagsSize", "bags") end

-- Our bag settings panel, hung under edit mode's Bags dialog while it is up: beside it, not in it
-- (the dialog would count a child into its size).
local function BagsExtra()
    local art = B.art
    local extra = art.bagsExtra
    if extra then return extra end
    extra = CreateFrame("Frame", "ForeverClassicUIBagsExtra", UIParent)
    extra:SetFrameStrata("DIALOG")
    extra:SetFrameLevel(200)
    extra:SetHeight(216)
    extra:Hide()
    art.bagsExtra = extra
    B.PanelBorder(extra)
    local check = BagsCheck(extra, extra, "TOPLEFT", 22, -14, "Opened bags take this size too", FollowClick)
    extra.check = check
    local above = BagsCheck(extra, check, "BOTTOMLEFT", 0, -2, "Opened bags above the bag buttons", AboveClick)
    extra.above = above
    local hideArt = BagsCheck(extra, above, "BOTTOMLEFT", 0, -2, HUD_EDIT_MODE_SETTING_ACTION_BAR_HIDE_BAR_ART or "Hide Bar Art",
        function(self)
            ns.MicroTouched()
            ns.db.hideBagsArt = self:GetChecked() and true or false
            ns.ToggleChanged("hideBagsArt")
        end)
    extra.art = hideArt
    local one = BagsCheck(extra, hideArt, "BOTTOMLEFT", 0, -2, "One bag: all bags open as one window", function(self)
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
        extra.InitColumns = B.GuardedSlider(slider, ColumnValues, OnColumns,
            { formatters = formatters, owner = extra, enabled = OneBagOn, label = colsLabel })
    end
    -- Addon settings save on click, outside Save/Revert, and say so (a dark Save reads as "nothing happened").
    local saved = extra:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    saved:SetPoint("BOTTOMLEFT", extra, "BOTTOMLEFT", 26, 14)
    saved:SetText("Bag window options apply and save the moment you change them.")
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
    if extra.art then extra.art:SetChecked(ns.db.hideBagsArt == true) end
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
