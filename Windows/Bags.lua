local _, ns = ...

-- 1.x bags on the client's containers: bag sheet in Classic's three cuts (top with ring and name, middles per rows, bottom lip),
-- backpack sheet with its money strip, slots on the 41px pitch, the old ring per icon; client art faded.
-- Combined bags (not in 1.x) are one tall backpack, four across unless picked.

local NewBand = ns.bags.NewBand

local WIDTH = 192
local COLUMNS = 4
ns.ONE_BAG_COLUMNS_MIN, ns.ONE_BAG_COLUMNS_MAX = 4, 16
local ROW = 41                   -- row pitch: 37 slot + 4 gap
local COL = 42                   -- column pitch: 37 slot + 5 gap
local FIRST_X, FIRST_Y = -12, 9  -- first slot's bottom right, from the frame's
local ROWS_PER_PIECE = 6         -- rows one middle piece of the sheet covers
local BACKPACK_ROWS_PER_PIECE = 5   -- whole rows the sheet holds below the backpack's band start
local ROW_BAR_TOP = 213 / 512    -- a whole row's start on the sheet (lattice bar top)
local SHEET_H = 512
local MIDDLE_TOP = 0.353515625   -- where a row band starts on the sheet
local FIRST_ROW_PIXELS = 9       -- the first row band is cut this much shorter
local BOTTOM_TOP, BOTTOM_BOTTOM, BOTTOM_H = 0.330078125, 0.349609375, 10
local BACKPACK_ROWS = 4          -- the backpack sheet carries four rows and the money strip
local BACKPACK_TOP, BACKPACK_SPLIT = 255, 210   -- the sheet's height, and where it splits when rows are added
local BACKPACK_BASE_H = 240
local BACKPACK_FIRST_Y = -211    -- the first backpack slot's bottom, from the top, with four rows
local BACKPACK_MIDDLE_TOP = 215 / 512   -- backpack extra rows start lower on the sheet than a bag's
local MONEY_Y = -215
-- The money strip on the backpack sheet (its top line to its bottom line) and the rim under it; a watched
-- currency row gets a second strip cut the same, and the window grows by one strip.
local STRIP_TOP, STRIP_END = 209, 232
local STRIP_H = STRIP_END - STRIP_TOP
-- The strip's inside from the window's left and right edges (the sheet hangs 64 past the left), and the row's inset.
local STRIP_LEFT, STRIP_RIGHT, TOKEN_INSET = 21, -14, 3
local EMPTY = ns.EMPTY
local QUICK_RING_64 = { set = "raw", tint = true, coords = { 0, 1, 0, 1 }, w = 64, h = 64, point = "CENTER", y = -1 }

local active = false
local hooked = setmetatable({}, { __mode = "k" })

local function Pieces(frame)
    frame.fcui = frame.fcui or {}
    if not frame.fcui.bagTop then
        frame.fcui.bagTop = NewBand(frame)
        frame.fcui.bagMiddle = {}
        frame.fcui.bagBottom = NewBand(frame)
        frame.fcui.tokenStrip = NewBand(frame)
        frame.fcui.tokenFoot = NewBand(frame)
    end
    return frame.fcui
end

local function Middle(frame, i)
    local list = Pieces(frame).bagMiddle
    if not list[i] then list[i] = NewBand(frame) end
    return list[i]
end

local function ClampColumns(n)
    return math.max(ns.ONE_BAG_COLUMNS_MIN, math.min(ns.ONE_BAG_COLUMNS_MAX, math.floor(n + 0.5)))
end

-- Combined bag: the player's column count; every other bag: four.
local function ColumnsOf(frame)
    local combined = frame.IsCombinedBagContainer and frame:IsCombinedBagContainer()
    if not combined then return COLUMNS end
    return ClampColumns(ns.db and tonumber(ns.db.oneBagColumns) or COLUMNS)
end

local function SetBandColumns(frame, columns)
    local p = Pieces(frame)
    p.bagTop:SetColumns(columns)
    p.bagBottom:SetColumns(columns)
    for _, band in ipairs(p.bagMiddle) do band:SetColumns(columns) end
    p.columns = columns
end

-- Our textures, which the fade skips.
local function IsOurs(frame, region)
    local p = frame.fcui
    if not p then return false end
    if p.bagTop and (p.bagTop:Owns(region) or p.bagBottom:Owns(region)) then return true end
    if p.tokenStrip and (p.tokenStrip:Owns(region) or p.tokenFoot:Owns(region)) then return true end
    for _, piece in ipairs(p.bagMiddle or EMPTY) do if piece:Owns(region) then return true end end
    for _, piece in ipairs(p.blanks or EMPTY) do if region == piece then return true end end
    return false
end

-- Fade every client texture but the portrait, slots and controls.
local function FadeFrameRegion(region, frame)
    if region:IsObjectType("Texture") and not IsOurs(frame, region) then region:SetAlpha(0) end
end

local function FadeChildRegion(region, portrait)
    if region:IsObjectType("Texture") and region ~= portrait then region:SetAlpha(0) end
end

local function Kept(frame, child)
    return child == frame.PortraitButton or child == frame.MoneyFrame or child == frame.CloseButton
        or child == frame.FilterIcon or child == BagItemSearchBox or child == BagItemAutoSortButton
end

local function FadeChild(child, frame, portrait)
    if not Kept(frame, child) and not child.GetBagID and not child.GetSlotAndBagID then
        ns.EachRegion(child, FadeChildRegion, portrait)
    end
end

local function FadeArt(frame)
    ns.EachRegion(frame, FadeFrameRegion, frame)
    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    ns.EachChild(frame, FadeChild, frame, portrait)
    if frame.Bg and frame.Bg.SetAlpha and frame.Bg.IsObjectType and frame.Bg:IsObjectType("Texture") then frame.Bg:SetAlpha(0) end
end

-- Middle band i under last: pixels tall, cut from the sheet at from.
local function DrawMiddle(frame, p, i, last, pixels, from)
    local piece = Middle(frame, i)
    piece:SetColumns(p.columns or COLUMNS)
    piece:SetSheet("bagComponents")
    ns.SetPointOnce(piece, "TOP", last, "BOTTOM", 0, 0)
    piece:SetHeight(pixels)
    piece:SetTexCoord(from, pixels / SHEET_H + from)
    piece:SetAlpha(1)
    piece:Show()
    return piece
end

local function HideMiddles(p, used)
    for j = used + 1, #p.bagMiddle do p.bagMiddle[j]:Hide() end
end

local function DrawBottom(bottom, key, height, from, to, last)
    bottom:SetSheet(key)
    bottom:SetHeight(height)
    bottom:SetTexCoord(from, to)
    ns.SetPointOnce(bottom, "TOP", last, "BOTTOM", 0, 0)
    bottom:SetAlpha(1)
    bottom:Show()
end

-- Sheet pieces for a bag of this many rows, cut as the Classic client did.
local function DrawBag(frame, rows, plusTwo)
    local p = Pieces(frame)
    local top, bottom = p.bagTop, p.bagBottom
    top:SetSheet("bagComponents")
    ns.SetPointOnce(top, "TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    if plusTwo then
        top:SetTexCoord(0.189453125, 0.330078125)
        top:SetHeight(72)
    elseif rows == 1 then
        top:SetTexCoord(0.00390625, 0.16796875)
        top:SetHeight(86)
    else
        top:SetTexCoord(0.00390625, 0.18359375)
        top:SetHeight(94)
    end
    top:SetAlpha(1)
    top:Show()
    local remaining = rows - 1
    local last = top
    local middleHeight = 0
    local i = 0
    while remaining > 0 do
        i = i + 1
        local n = math.min(remaining, ROWS_PER_PIECE)
        -- First piece 9px short (as Classic's) to finish the row the top began;
        -- later ones start on a lattice bar, or the bars break at the join.
        local pixels = n * ROW - (i == 1 and FIRST_ROW_PIXELS or 0)
        last = DrawMiddle(frame, p, i, last, pixels, i == 1 and MIDDLE_TOP or ROW_BAR_TOP)
        middleHeight = middleHeight + pixels
        remaining = remaining - n
    end
    HideMiddles(p, i)
    DrawBottom(bottom, "bagComponents", BOTTOM_H, BOTTOM_TOP, BOTTOM_BOTTOM, last)
    return top:GetHeight() + middleHeight + BOTTOM_H
end

-- A second money strip and the rim under last, for the watched currency row; hidden without one.
local function DrawTokenStrip(p, last, on)
    local strip, foot = p.tokenStrip, p.tokenFoot
    if not on then
        strip:Hide()
        foot:Hide()
        return 0
    end
    strip:SetColumns(p.columns or COLUMNS)
    foot:SetColumns(p.columns or COLUMNS)
    DrawBottom(strip, "backpackBg", STRIP_H, STRIP_TOP / BACKPACK_TOP, STRIP_END / BACKPACK_TOP, last)
    DrawBottom(foot, "backpackBg", BACKPACK_TOP - STRIP_END, STRIP_END / BACKPACK_TOP, 1, strip)
    return STRIP_H
end

-- Backpack sheet: four rows plus money strip; extra rows go between its halves, a currency strip under the money.
local function DrawBackpack(frame, rows, token)
    local p = Pieces(frame)
    local top, bottom = p.bagTop, p.bagBottom
    local extra = math.max(0, rows - BACKPACK_ROWS)
    top:SetSheet("backpackBg")
    ns.SetPointOnce(top, "TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    local middleHeight = 0
    -- With a currency strip the sheet stops at the money strip's foot; the strip and the rim follow.
    local sheetEnd = token and STRIP_END or BACKPACK_TOP
    if extra > 0 then
        top:SetHeight(BACKPACK_SPLIT)
        top:SetTexCoord(0, BACKPACK_SPLIT / BACKPACK_TOP)
        local last = top
        local remaining = extra
        local i = 0
        while remaining > 0 do
            i = i + 1
            -- Whole rows at true height, at most five (all the sheet holds from here),
            -- each piece ending on the next one's lattice line; stretched rows drifted.
            local n = math.min(remaining, BACKPACK_ROWS_PER_PIECE)
            last = DrawMiddle(frame, p, i, last, n * ROW, BACKPACK_MIDDLE_TOP)
            middleHeight = middleHeight + n * ROW
            remaining = remaining - n
        end
        HideMiddles(p, i)
        DrawBottom(bottom, "backpackBg", sheetEnd - BACKPACK_SPLIT, BACKPACK_SPLIT / BACKPACK_TOP, sheetEnd / BACKPACK_TOP, last)
        middleHeight = middleHeight + DrawTokenStrip(p, bottom, token)
    else
        top:SetHeight(sheetEnd)
        top:SetTexCoord(0, sheetEnd / BACKPACK_TOP)
        HideMiddles(p, 0)
        bottom:Hide()
        middleHeight = DrawTokenStrip(p, top, token)
    end
    top:SetAlpha(1)
    top:Show()
    return BACKPACK_BASE_H + middleHeight, extra
end

-- The client's watched currency row, when it hangs on this window and shows (widget reads only).
local function TokenRow(frame)
    local row = _G.BackpackTokenFrame
    if row and row:GetParent() == frame and row:IsShown() then return row end
end

local function EmptyLook(button)
    if button.icon then button.icon:SetAlpha(button.hasItem and 1 or 0) end
end

local function SlotArt(button)
    if not ns.Once(button, "slot") then
        EmptyLook(button)
        return
    end
    if button.SetItemButtonTexture then hooksecurefunc(button, "SetItemButtonTexture", EmptyLook) end
    EmptyLook(button)
    -- Old ring; bronze with the bronze theme.
    ns.Dress(button:GetNormalTexture(), ns.ART.QUICKSLOT, QUICK_RING_64, button)
end

-- The sheet has a socket in every grid place: a short last row gets one patch of
-- plain leather over the empty ones, short of the bars above and beside.
local BLANK_L, BLANK_R, BLANK_T, BLANK_B = 110 / 256, 158 / 256, 126 / 512, 160 / 512
local BLANK_H = 37

local function Blank(frame, i)
    local p = Pieces(frame)
    p.blanks = p.blanks or {}
    if not p.blanks[i] then
        local tex = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
        ns.SetTex(tex, "bagComponents")
        tex:SetTexCoord(BLANK_L, BLANK_R, BLANK_T, BLANK_B)
        p.blanks[i] = tex
    end
    return p.blanks[i]
end

-- Bags fill from the bottom right, leftward then up (1.x); the combined bag reads
-- like a page, gaps at the bottom right. Anchors are written only when they differ.
local function Place(region, index, dx, dy, frame, columns, rows, count, combined, backpackExtra)
    local column, row
    if combined then
        local k = count - 1 - index
        column = columns - 1 - (k % columns)
        row = rows - 1 - math.floor(k / columns)
    else
        column = index % columns
        row = math.floor(index / columns)
    end
    if backpackExtra then
        ns.SetPointIf(region, "BOTTOMRIGHT", frame, "TOPRIGHT", FIRST_X - column * COL + dx, BACKPACK_FIRST_Y - ROW * backpackExtra + row * ROW + dy)
    else
        ns.SetPointIf(region, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", FIRST_X - column * COL + dx, FIRST_Y + row * ROW + dy)
    end
end

local spare = {}   -- the slot list, reused; a nested pass takes a new one

local function LayoutItems(frame, backpackExtra, combined, plusTwo)
    if not frame.EnumerateValidItems then return end
    local list = spare or {}
    spare = nil
    local count = 0
    for _, button in frame:EnumerateValidItems() do
        count = count + 1
        list[count] = button
    end
    -- Shadows the file's COLUMNS with this window's count (Skin's plusTwo uses four).
    local COLUMNS = ColumnsOf(frame)
    local rows = math.ceil(count / COLUMNS)
    for i = 1, count do
        local button = list[i]
        list[i] = nil
        SlotArt(button)
        Place(button, i - 1, 0, 0, frame, COLUMNS, rows, count, combined, backpackExtra)
    end
    spare = list
    -- Blank the places past the last slot; plusTwo bags have a top cut for it.
    local blanks = 0
    local missing = rows * COLUMNS - count
    if not plusTwo and missing > 0 then
        blanks = 1
        local tex = Blank(frame, 1)
        tex:SetSize(missing * COL - 3, BLANK_H)
        -- Right end at the grid's last place in page order (combined), else the
        -- first place past the slots.
        Place(tex, combined and (count - rows * COLUMNS) or count, 1, -1, frame, COLUMNS, rows, count, combined, backpackExtra)
        tex:Show()
    end
    local made = Pieces(frame).blanks
    if made then for j = blanks + 1, #made do made[j]:Hide() end end
end

-- Runs inside the client's layout pass: it stacks bags by height, so a deferred
-- pass would misplace them or flash the client's layout.
local function Skin(frame)
    if not active or not frame or not frame.GetBagSize then
        if ns.debugSink then
            ns.Persist(string.format("bags: skip %s active %s hasSize %s", tostring(frame and frame:GetName()), tostring(active), tostring(frame and frame.GetBagSize ~= nil)))
        end
        return
    end
    local combined = frame.IsCombinedBagContainer and frame:IsCombinedBagContainer() and true or false
    local size = frame:GetBagSize() or 0
    if size <= 1 then return end
    local columns = ColumnsOf(frame)
    local rows = math.ceil(size / columns)
    SetBandColumns(frame, columns)
    if ns.debugSink then
        ns.Persist(string.format("bags: skin %s size %d rows %d backpack %s", tostring(frame:GetName()), size, rows, tostring(frame.IsBackpack and frame:IsBackpack())))
    end
    FadeArt(frame)
    local height, extra
    local plusTwo = false
    local tokenRow = (combined or (frame.IsBackpack and frame:IsBackpack())) and TokenRow(frame)
    if combined or (frame.IsBackpack and frame:IsBackpack()) then
        height, extra = DrawBackpack(frame, rows, tokenRow ~= nil)
    else
        plusTwo = size % COLUMNS == 2
        height = DrawBag(frame, rows, plusTwo)
    end
    local wider = (columns - COLUMNS) * COL
    frame:SetSize(WIDTH + wider, height)
    LayoutItems(frame, extra, combined, plusTwo)
    -- Old spots for portrait, name, close, money, search. Move the portrait's
    -- container so its round mask follows; the backpack gets the old bag icon.
    local pc = frame.PortraitContainer
    local portrait = pc and pc.portrait
    if pc then
        pc:SetSize(40, 40)
        ns.SetPointOnce(pc, "TOPLEFT", frame, "TOPLEFT", 4, -4)
        pc:SetFrameLevel(frame:GetFrameLevel())
    end
    if portrait then
        portrait:ClearAllPoints()
        portrait:SetAllPoints(pc)
        portrait:SetDrawLayer("BACKGROUND", -8)
        if combined or (frame.IsBackpack and frame:IsBackpack()) then
            ns.SetTex(portrait, "backpackIcon")
            portrait:SetTexCoord(0, 1, 0, 1)
        end
    end
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    if title then
        title:SetFontObject("GameFontHighlight")
        ns.SetPointOnce(title, "TOPLEFT", frame, "TOPLEFT", 47, -10)
        title:SetWidth(112 + wider)
        title:SetJustifyH("CENTER")
    end
    local close = frame.CloseButton
    if close then
        ns.SkinCloseButton(close, true)
        close:ClearAllPoints()
        if extra then
            close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, -2)
        else
            close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, 0)
        end
    end
    -- Money on the sheet's own strip; the client's pill goes.
    if frame.MoneyFrame and extra then
        local money = frame.MoneyFrame
        ns.SetPointOnce(money, "TOPRIGHT", frame, "TOPRIGHT", -6, MONEY_Y - ROW * extra)
        ns.FadeTextures(money.Border)
    end
    -- The currency row inside the strip under the money, as wide as the money strip's inside.
    if tokenRow and extra then
        local y = -(STRIP_END + ROW * extra + TOKEN_INSET)
        tokenRow:ClearAllPoints()
        tokenRow:SetPoint("TOPLEFT", frame, "TOPLEFT", STRIP_LEFT, y)
        tokenRow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", STRIP_RIGHT, y)
        if tokenRow.Border then ns.FadeTextures(tokenRow.Border) end
    end
    if BagItemSearchBox and BagItemSearchBox:GetParent() == frame then
        ns.SetPointOnce(BagItemSearchBox, "TOPLEFT", frame, "TOPLEFT", 52, -31)
        BagItemSearchBox:SetSize(104, 16)
    end
    if BagItemAutoSortButton and BagItemAutoSortButton:GetParent() == frame then
        ns.SetPointOnce(BagItemAutoSortButton, "TOPRIGHT", frame, "TOPRIGHT", -10, -28)
    end
end

local LAYOUT_METHODS = { "UpdateFrameSize", "UpdateItemLayout", "UpdateSearchBox", "UpdateMiscellaneousFrames" }

local function Hook(frame)
    if hooked[frame] then return end
    hooked[frame] = true
    for _, method in ipairs(LAYOUT_METHODS) do
        if type(rawget(frame, method)) == "function" then
            hooksecurefunc(frame, method, function(self) Skin(self) end)
        end
    end
    frame:HookScript("OnShow", function(self) Skin(self) end)
end

-- Combined bag columns (settings, or the edit mode bags dialog); applies live.
function ns.SetOneBagColumns(columns)
    columns = ClampColumns(tonumber(columns) or COLUMNS)
    if not ns.db then return columns end
    ns.db.oneBagColumns = columns
    local frame = ContainerFrameCombinedBags
    if active and frame and frame:IsShown() then ns.SafeCall(Skin, frame) end
    return columns
end

-- Every container frame once, in the order the client lists them.
local frameList, frameSeen = {}, {}
local function AddFrame(frame)
    if frame and not frameSeen[frame] then
        frameSeen[frame] = true
        frameList[#frameList + 1] = frame
    end
end

local function Frames()
    wipe(frameList)
    wipe(frameSeen)
    local container = ContainerFrameContainer
    if container and container.ContainerFrames then
        for _, frame in ipairs(container.ContainerFrames) do AddFrame(frame) end
    end
    for i = 1, 13 do AddFrame(_G["ContainerFrame" .. i]) end
    AddFrame(ContainerFrameCombinedBags)
    return frameList
end

-- oneBag mirrors the client's combinedBags CVar (ns.ToggleChanged writes it), so
-- a change in the game's options shows here too.
local function ReadOneBag()
    if not (ns.db and C_CVar and C_CVar.GetCVar) then return end
    local value = ns.GetCVar("combinedBags")
    if value ~= nil then ns.db.oneBag = tostring(value) == "1" end
end
ns.RegisterModule("oneBag", { apply = ReadOneBag, restore = ReadOneBag })

local function Apply()
    active = true
    local frames = Frames()
    if ns.debugSink then ns.Persist("bags: apply, frames " .. #frames) end
    for _, frame in ipairs(frames) do
        Hook(frame)
        if frame:IsShown() then Skin(frame) end
    end
end

local function Restore()
    active = false
    ns.needsReload = true
end

ns.RegisterModule("bags", { apply = Apply, restore = Restore })
