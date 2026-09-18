local _, ns = ...

-- The 1.x bag windows on the client's container frames: the old bag
-- sheet drawn in the three pieces the Classic client used (a top with
-- the portrait ring and name, one middle piece per row, a bottom lip),
-- the backpack's own sheet with the money strip, the slots re-laid on
-- the old 41 pixel row pitch so they sit in the sheet's cells, and the
-- old slot border under each icon. The client's flat window art, title
-- bar and streaks are faded. The combined bag window keeps its modern
-- look; 1.x had no such window.

local WIDTH = 192
local COLUMNS = 4
local ROW = 41                   -- row pitch; the old slot was 37 tall with 4 between
local COL = 42                   -- column pitch; 37 wide with 5 between
local FIRST_X, FIRST_Y = -12, 9  -- the first slot's bottom right corner, from the frame's
local ROWS_PER_PIECE = 6         -- rows one middle piece of the sheet covers
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

local function Pieces(frame)
    frame.fcui = frame.fcui or {}
    if not frame.fcui.bagTop then
        frame.fcui.bagTop = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
        frame.fcui.bagMiddle = {}
        frame.fcui.bagBottom = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    end
    return frame.fcui
end

local function Middle(frame, i)
    local list = Pieces(frame).bagMiddle
    if not list[i] then
        list[i] = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    end
    return list[i]
end

-- Our own textures on the frame, so the sweep leaves them alone.
local function IsOurs(frame, region)
    local p = frame.fcui
    if not p then return false end
    if region == p.bagTop or region == p.bagBottom then return true end
    for _, piece in ipairs(p.bagMiddle or {}) do if region == piece then return true end end
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
    ns.SetTex(top, "bagComponents")
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
        ns.SetTex(piece, "bagComponents")
        piece:SetWidth(256)
        piece:ClearAllPoints()
        piece:SetPoint("TOP", last, "BOTTOM", 0, 0)
        local n = math.min(remaining, ROWS_PER_PIECE)
        local pixels = n * ROW - FIRST_ROW_PIXELS
        piece:SetHeight(n * ROW)
        piece:SetTexCoord(0, 1, MIDDLE_TOP, pixels / SHEET_H + MIDDLE_TOP)
        piece:SetAlpha(1)
        piece:Show()
        middleHeight = middleHeight + n * ROW
        remaining = remaining - n
        last = piece
    end
    for j = i + 1, #p.bagMiddle do p.bagMiddle[j]:Hide() end
    ns.SetTex(bottom, "bagComponents")
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
    ns.SetTex(top, "backpackBg")
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
            ns.SetTex(piece, "bagComponents")
            piece:SetWidth(256)
            piece:ClearAllPoints()
            piece:SetPoint("TOP", last, "BOTTOM", 0, 0)
            local n = math.min(remaining, ROWS_PER_PIECE)
            local pixels = n * ROW - FIRST_ROW_PIXELS
            piece:SetHeight(n * ROW)
            piece:SetTexCoord(0, 1, BACKPACK_MIDDLE_TOP, pixels / SHEET_H + BACKPACK_MIDDLE_TOP)
            piece:SetAlpha(1)
            piece:Show()
            middleHeight = middleHeight + n * ROW
            remaining = remaining - n
            last = piece
        end
        for j = i + 1, #p.bagMiddle do p.bagMiddle[j]:Hide() end
        ns.SetTex(bottom, "backpackBg")
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

-- The slots on the old grid, first one bottom right, filling leftward
-- then upward, at 42 across and 41 up.
local function LayoutItems(frame, backpackExtra)
    if not frame.EnumerateValidItems then return end
    local firstY = FIRST_Y
    local list = {}
    for _, button in frame:EnumerateValidItems() do list[#list + 1] = button end
    for i, button in ipairs(list) do
        SlotArt(button)
        local index = i - 1
        local column = index % COLUMNS
        local row = math.floor(index / COLUMNS)
        button:ClearAllPoints()
        if backpackExtra then
            button:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", FIRST_X - column * COL, BACKPACK_FIRST_Y - ROW * backpackExtra + row * ROW)
        else
            button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", FIRST_X - column * COL, firstY + row * ROW)
        end
    end
end

local function Skin(frame)
    if not active or not frame or not frame.GetBagSize then
        ns.Persist(string.format("bags: skip %s active %s hasSize %s", tostring(frame and frame:GetName()), tostring(active), tostring(frame and frame.GetBagSize ~= nil)))
        return
    end
    if frame.IsCombinedBagContainer and frame:IsCombinedBagContainer() then return end
    local size = frame:GetBagSize() or 0
    if size <= 1 then return end
    local rows = math.ceil(size / COLUMNS)
    ns.Persist(string.format("bags: skin %s size %d rows %d backpack %s", tostring(frame:GetName()), size, rows, tostring(frame.IsBackpack and frame:IsBackpack())))
    FadeArt(frame)
    local height, extra
    if frame.IsBackpack and frame:IsBackpack() then
        height, extra = DrawBackpack(frame, rows)
    else
        height = DrawBag(frame, rows, size % COLUMNS == 2)
    end
    frame:SetSize(WIDTH, height)
    LayoutItems(frame, extra)
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
        if frame.IsBackpack and frame:IsBackpack() then
            ns.SetTex(portrait, "backpackIcon")
            portrait:SetTexCoord(0, 1, 0, 1)
        end
    end
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    if title then
        title:SetFontObject("GameFontHighlight")
        title:ClearAllPoints()
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", 47, -10)
        title:SetWidth(112)
        title:SetJustifyH("CENTER")
    end
    local close = frame.CloseButton
    if close then
        ns.SkinCloseButton(close, true)
        close:ClearAllPoints()
        if extra then
            close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, -2)
        else
            close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 4)
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
    return list
end

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
