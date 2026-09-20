local _, ns = ...

-- The 1.x bag windows on the client's container frames: the old bag
-- sheet drawn in the three pieces the Classic client used (a top with
-- the portrait ring and name, one middle piece per row, a bottom lip),
-- the backpack's own sheet with the money strip, the slots re-laid on
-- the old 41 pixel row pitch so they sit in the sheet's cells, and the
-- old slot border under each icon. The client's flat window art, title
-- bar and streaks are faded. The combined bag window, which 1.x never
-- had, is drawn as one tall backpack: the backpack's sheet with as many
-- extra rows as the slots need, four across like every old bag.

local WIDTH = 192
local COLUMNS = 4
ns.ONE_BAG_COLUMNS_MIN, ns.ONE_BAG_COLUMNS_MAX = 4, 16
local ROW = 41                   -- row pitch; the old slot was 37 tall with 4 between
local COL = 42                   -- column pitch; 37 wide with 5 between
local FIRST_X, FIRST_Y = -12, 9  -- the first slot's bottom right corner, from the frame's
local ROWS_PER_PIECE = 6         -- rows one middle piece of the sheet covers
local BACKPACK_ROWS_PER_PIECE = 5   -- whole rows the sheet holds below the backpack's band start
local ROW_BAR_TOP = 213 / 512    -- where a whole row starts on the sheet: a lattice bar's top edge
local SHEET_H = 512
local MIDDLE_TOP = 0.353515625   -- where a row band starts on the sheet
local FIRST_ROW_PIXELS = 9       -- the first row band is cut this much shorter
local BOTTOM_TOP, BOTTOM_BOTTOM, BOTTOM_H = 0.330078125, 0.349609375, 10
local BACKPACK_ROWS = 4          -- the backpack sheet carries four rows and the money strip
local BACKPACK_TOP, BACKPACK_SPLIT = 255, 210   -- the sheet's height, and where it splits when rows are added
local BACKPACK_BASE_H = 240
local BACKPACK_FIRST_Y = -211    -- the first backpack slot's bottom, from the top, with four rows
local BACKPACK_MIDDLE_TOP = 215 / 512   -- the backpack's extra-row band starts lower on the sheet than a bag's
local MONEY_Y = -215

local active = false
local hooked = setmetatable({}, { __mode = "k" })

-- A band of the sheet, as wide as the bag has columns. The sheets are
-- drawn four columns wide. The one bag window can have more, so a band
-- is three kinds of texture side by side: the sheet's right end with
-- its first column, the sheet's left end with its last two columns and
-- the portrait ring, and between them the sheet's second column over
-- once for the old four columns and once more for every column past them. That column runs from the
-- middle of one bar of the lattice to the middle of the next, so it
-- meets itself and both ends without a seam, title strip and money
-- strip included. With four columns there is none of it, and the band
-- is the sheet as it always was.
local STRIP_L, STRIP_R = 162, 204   -- the second column, on the 256 wide sheets

local Band = {}
Band.__index = Band

local function NewBand(frame)
    local band = setmetatable({ frame = frame, strips = {}, extra = 0 }, Band)
    band.right = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    band.right:SetWidth(256 - STRIP_R)
    band.left = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    band.left:SetWidth(STRIP_L)
    band:SetColumns(4)
    return band
end

function Band:Parts()
    local parts = { self.right, self.left }
    for i = 1, self.extra do parts[#parts + 1] = self.strips[i] end
    return parts
end

function Band:SetColumns(columns)
    -- The sheet's two ends carry three of its columns between them, so
    -- even the old four want the middle column once.
    self.extra = math.max(1, (columns or 4) - 3)
    local last = self.right
    for i = 1, self.extra do
        local strip = self.strips[i]
        if not strip then
            strip = self.frame:CreateTexture(nil, "BACKGROUND", nil, -1)
            strip:SetWidth(STRIP_R - STRIP_L)
            self.strips[i] = strip
        end
        strip:ClearAllPoints()
        strip:SetPoint("TOPRIGHT", last, "TOPLEFT", 0, 0)
        last = strip
    end
    for i = self.extra + 1, #self.strips do self.strips[i]:Hide() end
    self.left:ClearAllPoints()
    self.left:SetPoint("TOPRIGHT", last, "TOPLEFT", 0, 0)
end

function Band:SetSheet(key)
    for _, part in ipairs(self:Parts()) do ns.SetTex(part, key) end
end

-- Only the rows of the sheet are the caller's to say; across, each part
-- keeps to its own columns.
function Band:SetTexCoord(_, _, top, bottom)
    self.right:SetTexCoord(STRIP_R / 256, 1, top, bottom)
    self.left:SetTexCoord(0, STRIP_L / 256, top, bottom)
    for i = 1, self.extra do self.strips[i]:SetTexCoord(STRIP_L / 256, STRIP_R / 256, top, bottom) end
end

-- The width is the columns' to decide, not the caller's.
Band.SetWidth = function() end

function Band:SetHeight(height)
    for _, part in ipairs(self:Parts()) do part:SetHeight(height) end
end

function Band:GetHeight() return self.right:GetHeight() end

function Band:ClearAllPoints() self.right:ClearAllPoints() end

-- A band hangs by its right end: from the window's top right corner, or
-- from the foot of the band above it.
function Band:SetPoint(point, relativeTo, relativePoint, x, y)
    if getmetatable(relativeTo) == Band then
        self.right:SetPoint("TOPRIGHT", relativeTo.right, "BOTTOMRIGHT", x or 0, y or 0)
    else
        self.right:SetPoint(point, relativeTo, relativePoint, x or 0, y or 0)
    end
end

function Band:SetAlpha(alpha)
    for _, part in ipairs(self:Parts()) do part:SetAlpha(alpha) end
end

function Band:Show()
    for _, part in ipairs(self:Parts()) do part:Show() end
end

function Band:Hide()
    self.right:Hide()
    self.left:Hide()
    for _, strip in ipairs(self.strips) do strip:Hide() end
end

function Band:Owns(region)
    if region == self.right or region == self.left then return true end
    for _, strip in ipairs(self.strips) do if region == strip then return true end end
    return false
end

local function Pieces(frame)
    frame.fcui = frame.fcui or {}
    if not frame.fcui.bagTop then
        frame.fcui.bagTop = NewBand(frame)
        frame.fcui.bagMiddle = {}
        frame.fcui.bagBottom = NewBand(frame)
    end
    return frame.fcui
end

local function Middle(frame, i)
    local list = Pieces(frame).bagMiddle
    if not list[i] then list[i] = NewBand(frame) end
    return list[i]
end

-- How many columns a window has: the one bag window as many as the
-- player chose, every other bag the old four.
local function ColumnsOf(frame)
    local combined = frame.IsCombinedBagContainer and frame:IsCombinedBagContainer()
    if not combined then return COLUMNS end
    local chosen = ns.db and tonumber(ns.db.oneBagColumns) or COLUMNS
    return math.max(ns.ONE_BAG_COLUMNS_MIN, math.min(ns.ONE_BAG_COLUMNS_MAX, math.floor(chosen + 0.5)))
end

local function SetBandColumns(frame, columns)
    local p = Pieces(frame)
    p.bagTop:SetColumns(columns)
    p.bagBottom:SetColumns(columns)
    for _, band in ipairs(p.bagMiddle) do band:SetColumns(columns) end
    p.columns = columns
end

-- Our own textures on the frame, so the sweep leaves them alone.
local function IsOurs(frame, region)
    local p = frame.fcui
    if not p then return false end
    if p.bagTop and (p.bagTop:Owns(region) or p.bagBottom:Owns(region)) then return true end
    for _, piece in ipairs(p.bagMiddle or {}) do if piece:Owns(region) then return true end end
    for _, piece in ipairs(p.blanks or {}) do if region == piece then return true end end
    return false
end

-- Everything the client draws on the window goes, except the portrait,
-- the slots and the controls: the frame's own textures and those of
-- every child that is not a slot button or a control frame.
local KEEP_CHILD = { PortraitButton = true, MoneyFrame = true, CloseButton = true, FilterIcon = true }
local function FadeArt(frame)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") and not IsOurs(frame, region) then region:SetAlpha(0) end
    end
    local keep = {}
    for key in pairs(KEEP_CHILD) do if frame[key] then keep[frame[key]] = true end end
    if BagItemSearchBox then keep[BagItemSearchBox] = true end
    if BagItemAutoSortButton then keep[BagItemAutoSortButton] = true end
    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    for _, child in ipairs({ frame:GetChildren() }) do
        if not keep[child] and not child.GetBagID and not child.GetSlotAndBagID then
            for _, region in ipairs({ child:GetRegions() }) do
                if region:IsObjectType("Texture") and region ~= portrait then region:SetAlpha(0) end
            end
        end
    end
    if frame.Bg and frame.Bg.SetAlpha and frame.Bg.IsObjectType and frame.Bg:IsObjectType("Texture") then frame.Bg:SetAlpha(0) end
end

-- The sheet pieces for a bag of the given rows, the way the Classic
-- client cut them.
local function DrawBag(frame, rows, plusTwo)
    local p = Pieces(frame)
    local top, bottom = p.bagTop, p.bagBottom
    top:SetSheet("bagComponents")
    top:SetWidth(256)
    top:ClearAllPoints()
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    if plusTwo then
        top:SetTexCoord(0, 1, 0.189453125, 0.330078125)
        top:SetHeight(72)
    elseif rows == 1 then
        top:SetTexCoord(0, 1, 0.00390625, 0.16796875)
        top:SetHeight(86)
    else
        top:SetTexCoord(0, 1, 0.00390625, 0.18359375)
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
        local piece = Middle(frame, i)
        piece:SetColumns(p.columns or COLUMNS)
        piece:SetSheet("bagComponents")
        piece:SetWidth(256)
        piece:ClearAllPoints()
        piece:SetPoint("TOP", last, "BOTTOM", 0, 0)
        local n = math.min(remaining, ROWS_PER_PIECE)
        -- A bag's row band is cut 9px short and drawn at that height,
        -- unlike the backpack's; the Classic client did the same. That
        -- is the first piece only: its short first row finishes the row
        -- the top piece began. A piece after it starts on a whole row,
        -- at the lattice bar the one before it ended on, or the bars
        -- break at the join.
        local pixels = n * ROW - (i == 1 and FIRST_ROW_PIXELS or 0)
        local from = i == 1 and MIDDLE_TOP or ROW_BAR_TOP
        piece:SetHeight(pixels)
        piece:SetTexCoord(0, 1, from, pixels / SHEET_H + from)
        piece:SetAlpha(1)
        piece:Show()
        middleHeight = middleHeight + pixels
        remaining = remaining - n
        last = piece
    end
    for j = i + 1, #p.bagMiddle do p.bagMiddle[j]:Hide() end
    bottom:SetSheet("bagComponents")
    bottom:SetWidth(256)
    bottom:SetHeight(BOTTOM_H)
    bottom:SetTexCoord(0, 1, BOTTOM_TOP, BOTTOM_BOTTOM)
    bottom:ClearAllPoints()
    bottom:SetPoint("TOP", last, "BOTTOM", 0, 0)
    bottom:SetAlpha(1)
    bottom:Show()
    return top:GetHeight() + middleHeight + BOTTOM_H
end

-- The backpack sheet: four rows and the money strip; extra rows go in
-- as middle pieces between the sheet's two halves.
local function DrawBackpack(frame, rows)
    local p = Pieces(frame)
    local top, bottom = p.bagTop, p.bagBottom
    local extra = math.max(0, rows - BACKPACK_ROWS)
    top:SetSheet("backpackBg")
    top:SetWidth(256)
    top:ClearAllPoints()
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    local middleHeight = 0
    if extra > 0 then
        top:SetHeight(BACKPACK_SPLIT)
        top:SetTexCoord(0, 1, 0, BACKPACK_SPLIT / BACKPACK_TOP)
        local last = top
        local remaining = extra
        local i = 0
        while remaining > 0 do
            i = i + 1
            local piece = Middle(frame, i)
            piece:SetColumns(p.columns or COLUMNS)
        piece:SetSheet("bagComponents")
            piece:SetWidth(256)
            piece:ClearAllPoints()
            piece:SetPoint("TOP", last, "BOTTOM", 0, 0)
            -- Whole rows, drawn at their own height: so many rows of
            -- the sheet for so many rows of slots, five at most, which
            -- is what the sheet holds from where this band starts. Each
            -- piece then ends on the same line of the lattice the next
            -- one starts on. Six rows cut nine pixels short and pulled
            -- out to length drifted off the slots down the piece and
            -- broke the lattice where a second piece began: the one bag
            -- window with enough bags showed a gap across it.
            local n = math.min(remaining, BACKPACK_ROWS_PER_PIECE)
            local pixels = n * ROW
            piece:SetHeight(pixels)
            piece:SetTexCoord(0, 1, BACKPACK_MIDDLE_TOP, pixels / SHEET_H + BACKPACK_MIDDLE_TOP)
            piece:SetAlpha(1)
            piece:Show()
            middleHeight = middleHeight + n * ROW
            remaining = remaining - n
            last = piece
        end
        for j = i + 1, #p.bagMiddle do p.bagMiddle[j]:Hide() end
        bottom:SetSheet("backpackBg")
        bottom:SetWidth(256)
        bottom:SetHeight(BACKPACK_TOP - BACKPACK_SPLIT)
        bottom:SetTexCoord(0, 1, BACKPACK_SPLIT / BACKPACK_TOP, 1)
        bottom:ClearAllPoints()
        bottom:SetPoint("TOP", last, "BOTTOM", 0, 0)
        bottom:SetAlpha(1)
        bottom:Show()
    else
        top:SetHeight(BACKPACK_TOP)
        top:SetTexCoord(0, 1, 0, 1)
        for _, piece in ipairs(p.bagMiddle) do piece:Hide() end
        bottom:Hide()
    end
    top:SetAlpha(1)
    top:Show()
    return BACKPACK_BASE_H + middleHeight, extra
end

local function EmptyLook(button)
    if button.icon then button.icon:SetAlpha(button.hasItem and 1 or 0) end
end

local function SlotArt(button)
    if button.fcuiSlot then
        EmptyLook(button)
        return
    end
    button.fcuiSlot = true
    if type(rawget(button, "SetItemButtonTexture")) == "function" or button.SetItemButtonTexture then
        hooksecurefunc(button, "SetItemButtonTexture", function(self) EmptyLook(self) end)
    end
    EmptyLook(button)
    local normal = button:GetNormalTexture()
    if normal then
        normal:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        normal:SetTexCoord(0, 1, 0, 1)
        normal:ClearAllPoints()
        normal:SetSize(64, 64)
        normal:SetPoint("CENTER", button, "CENTER", 0, -1)
    end
end

-- The sheet has a socket drawn in every place of the grid, and a bag
-- whose slots do not fill its last row would show sockets that hold
-- nothing. The run of such places gets one patch of the sheet's plain
-- leather laid over it, sockets and the bars between them both, so only
-- real slots look like slots. It stops short of the bar under the row
-- above and of the bar beside the last real slot.
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

-- The slots on the old grid at 42 across and 41 up. A bag fills from
-- the bottom right, leftward then upward, as the old bags did. The one
-- bag window reads like a page instead: the same order of slots, but
-- the short row is the last one, and the places with no slot are at
-- the bottom right.
local function LayoutItems(frame, backpackExtra, combined, plusTwo)
    if not frame.EnumerateValidItems then return end
    local firstY = FIRST_Y
    local list = {}
    for _, button in frame:EnumerateValidItems() do list[#list + 1] = button end
    local count = #list
    local COLUMNS = ColumnsOf(frame)
    local rows = math.ceil(count / COLUMNS)
    local function Place(region, index, dx, dy)
        local column, row
        if combined then
            local k = count - 1 - index
            column = COLUMNS - 1 - (k % COLUMNS)
            row = rows - 1 - math.floor(k / COLUMNS)
        else
            column = index % COLUMNS
            row = math.floor(index / COLUMNS)
        end
        region:ClearAllPoints()
        if backpackExtra then
            region:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", FIRST_X - column * COL + dx, BACKPACK_FIRST_Y - ROW * backpackExtra + row * ROW + dy)
        else
            region:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", FIRST_X - column * COL + dx, firstY + row * ROW + dy)
        end
    end
    for i, button in ipairs(list) do
        SlotArt(button)
        Place(button, i - 1, 0, 0)
    end
    -- The places past the last slot. A bag two over a full row has a
    -- top piece cut for it on the sheet already.
    local blanks = 0
    local missing = rows * COLUMNS - count
    if not plusTwo and missing > 0 then
        blanks = 1
        local tex = Blank(frame, 1)
        tex:SetSize(missing * COL - 3, BLANK_H)
        -- Hung by its right end. In the page order that is the grid's
        -- very last place, which read backwards is before the count's
        -- start; in a bag's order it is the first place past the slots.
        Place(tex, combined and (count - rows * COLUMNS) or count, 1, -1)
        tex:Show()
    end
    local made = Pieces(frame).blanks
    if made then for j = blanks + 1, #made do made[j]:Hide() end end
end

local function Skin(frame)
    if not active or not frame or not frame.GetBagSize then
        ns.Persist(string.format("bags: skip %s active %s hasSize %s", tostring(frame and frame:GetName()), tostring(active), tostring(frame and frame.GetBagSize ~= nil)))
        return
    end
    local combined = frame.IsCombinedBagContainer and frame:IsCombinedBagContainer() and true or false
    local size = frame:GetBagSize() or 0
    if size <= 1 then return end
    local columns = ColumnsOf(frame)
    local rows = math.ceil(size / columns)
    SetBandColumns(frame, columns)
    ns.Persist(string.format("bags: skin %s size %d rows %d backpack %s", tostring(frame:GetName()), size, rows, tostring(frame.IsBackpack and frame:IsBackpack())))
    FadeArt(frame)
    local height, extra
    local plusTwo = false
    if combined or (frame.IsBackpack and frame:IsBackpack()) then
        height, extra = DrawBackpack(frame, rows)
    else
        plusTwo = size % COLUMNS == 2
        height = DrawBag(frame, rows, plusTwo)
    end
    local wider = (columns - COLUMNS) * COL
    frame:SetSize(WIDTH + wider, height)
    LayoutItems(frame, extra, combined, plusTwo)
    -- Portrait, name, close, money and search in their old spots.
    -- The portrait moves with its container so its round mask stays on
    -- it; the backpack wears the old bag button art, not the hi-res icon.
    local pc = frame.PortraitContainer
    local portrait = pc and pc.portrait
    if pc then
        pc:ClearAllPoints()
        pc:SetSize(40, 40)
        pc:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
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
        title:ClearAllPoints()
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", 47, -10)
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
    -- The money sits on the sheet's own strip; the client's pill goes.
    if frame.MoneyFrame and extra then
        local money = frame.MoneyFrame
        money:ClearAllPoints()
        money:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, MONEY_Y - ROW * extra)
        if money.Border then
            for _, region in ipairs({ money.Border:GetRegions() }) do
                if region:IsObjectType("Texture") then region:SetAlpha(0) end
            end
        end
    end
    if BagItemSearchBox and BagItemSearchBox:GetParent() == frame then
        BagItemSearchBox:ClearAllPoints()
        BagItemSearchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 52, -31)
        BagItemSearchBox:SetSize(104, 16)
    end
    if BagItemAutoSortButton and BagItemAutoSortButton:GetParent() == frame then
        BagItemAutoSortButton:ClearAllPoints()
        BagItemAutoSortButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -28)
    end
end

local function Hook(frame)
    if hooked[frame] then return end
    hooked[frame] = true
    for _, method in ipairs({ "UpdateFrameSize", "UpdateItemLayout", "UpdateSearchBox", "UpdateMiscellaneousFrames" }) do
        if type(rawget(frame, method)) == "function" then
            hooksecurefunc(frame, method, function(self) Skin(self) end)
        end
    end
    frame:HookScript("OnShow", function(self) Skin(self) end)
end

-- The one bag window's columns, from the settings window or from the
-- bags dialog in edit mode. Applies at once if the window is up.
function ns.SetOneBagColumns(columns)
    columns = math.floor((tonumber(columns) or COLUMNS) + 0.5)
    columns = math.max(ns.ONE_BAG_COLUMNS_MIN, math.min(ns.ONE_BAG_COLUMNS_MAX, columns))
    if not ns.db then return columns end
    ns.db.oneBagColumns = columns
    local frame = ContainerFrameCombinedBags
    if active and frame and frame:IsShown() then ns.SafeCall(Skin, frame) end
    return columns
end

local function Frames()
    local list = {}
    local container = ContainerFrameContainer
    if container and container.ContainerFrames then
        for _, frame in ipairs(container.ContainerFrames) do list[#list + 1] = frame end
    end
    for i = 1, 13 do
        local frame = _G["ContainerFrame" .. i]
        if frame then list[#list + 1] = frame end
    end
    if ContainerFrameCombinedBags then list[#list + 1] = ContainerFrameCombinedBags end
    return list
end

-- One bag: the client's own Combine Bags setting, offered where people
-- look for it. The game's setting is the one truth: ticking or unticking
-- ours writes it (in ns.ToggleChanged), and on every pass ours is read
-- back from it, so the two cannot disagree and a change made in the
-- game's own options shows here too. The first version only undid a
-- change it remembered making itself, and unticking did nothing for
-- anyone whose setting was already on.
local function ReadOneBag()
    if not (ns.db and C_CVar and C_CVar.GetCVar) then return end
    local ok, value = pcall(C_CVar.GetCVar, "combinedBags")
    if ok and value ~= nil then ns.db.oneBag = tostring(value) == "1" end
end
ns.RegisterModule("oneBag", { apply = ReadOneBag, restore = ReadOneBag })

local function Apply()
    active = true
    ns.Persist("bags: apply, frames " .. #Frames())
    for _, frame in ipairs(Frames()) do
        Hook(frame)
        if frame:IsShown() then Skin(frame) end
    end
end

local function Restore()
    active = false
    ns.needsReload = true
end

ns.RegisterModule("bags", { apply = Apply, restore = Restore })
