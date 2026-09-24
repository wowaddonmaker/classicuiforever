local _, ns = ...

-- Drop down lists and row right-click menus.

local MOUSE_DOWN = { "GLOBAL_MOUSE_DOWN" }
local DROP_BACKDROP = { bg = { 1, 1, 1, 1 }, border = { 1, 1, 1, 1 } }
-- 1.x right-click menus wear the tooltip's thin rim and fill (ours and the client's, UI/ClientMenus.lua).
local TIP_FILL = _G.TOOLTIP_DEFAULT_BACKGROUND_COLOR
ns.MENU_LOOK = { bronze = false, border = { 1, 1, 1, 1 },
    bg = TIP_FILL and { TIP_FILL.r, TIP_FILL.g, TIP_FILL.b, 1 } or { 0.09, 0.09, 0.19, 1 } }

-- Hides with the frame it follows (always ours); one hook per frame.
local function Follow(self, frame)
    if not frame or self.following == frame then return end
    self.following = frame
    frame:HookScript("OnHide", function() self:Hide() end)
end

-- Entries are { text, onPick, isChosen }.
local LIST_ROW, LIST_PAD_X, LIST_PAD_Y = 16, 15, 14
function ns.DropList(entries)
    local list = CreateFrame("Frame", nil, UIParent, ns.BACKDROP_TEMPLATE)
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:EnableMouse(true)
    list:SetClampedToScreen(true)
    list:Hide()
    ns.Backdrop(list, ns.BACKDROP.DIALOG_DARK, DROP_BACKDROP)
    list.items = {}
    local widest = 0
    for i, entry in ipairs(entries) do
        local item = CreateFrame("Button", nil, list)
        item:SetHeight(LIST_ROW)
        item:SetPoint("TOPLEFT", list, "TOPLEFT", LIST_PAD_X, -LIST_PAD_Y - (i - 1) * LIST_ROW)
        item:SetPoint("TOPRIGHT", list, "TOPRIGHT", -LIST_PAD_X, -LIST_PAD_Y - (i - 1) * LIST_ROW)
        local mark = item:CreateTexture(nil, "ARTWORK")
        mark:SetTexture("Interface\\Common\\UI-DropDownRadioChecks")
        mark:SetSize(16, 16)
        mark:SetPoint("LEFT", item, "LEFT", 0, 0)
        item.mark = mark
        local label = item:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("LEFT", mark, "RIGHT", 4, 0)
        label:SetText(entry[1])
        widest = math.max(widest, label:GetStringWidth() or 0)
        local highlight = item:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        highlight:SetBlendMode("ADD")
        highlight:SetAllPoints(item)
        item:SetScript("OnClick", function()
            list:Hide()
            PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
            entry[2]()
        end)
        item.entry = entry
        list.items[i] = item
    end
    list:SetSize(math.ceil(widest) + 20 + LIST_PAD_X * 2, #entries * LIST_ROW + LIST_PAD_Y * 2)

    ns.RegisterEvents(list, MOUSE_DOWN)
    list:SetScript("OnEvent", function(self)
        if not self:IsShown() or self:IsMouseOver() then return end
        -- Leave a press on the owner to the owner, or the list reopens at once.
        if self.owner and self.owner:IsMouseOver() then return end
        self:Hide()
    end)

    list.Follow = Follow

    function list:Toggle(owner)
        if self:IsShown() then self:Hide() return end
        self.owner = owner
        for _, item in ipairs(self.items) do
            local chosen = item.entry[3] and item.entry[3]() and true or false
            if chosen then item.mark:SetTexCoord(0, 0.5, 0.5, 1) else item.mark:SetTexCoord(0.5, 1, 0.5, 1) end
        end
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, 6)
        self:Show()
        self:Raise()
    end
    if ns.CloseOnEscape then ns.CloseOnEscape(list) end
    return list
end

local function NoOp() end

-- Entries are { text, onClick, allowed }; Cancel is appended as in the old menus.
function ns.RowMenu(entries)
    local menu = CreateFrame("Frame", nil, UIParent, ns.BACKDROP_TEMPLATE)
    ns.Backdrop(menu, ns.BACKDROP.TIP16, ns.MENU_LOOK)
    menu:SetSize(140, 32)
    menu:SetFrameStrata("DIALOG")
    menu:EnableMouse(true)
    menu:SetClampedToScreen(true)
    menu:Hide()

    menu.title = menu:CreateFontString(nil, "ARTWORK")
    menu.title:SetFontObject(ns.FONT_GOLD_SMALL or "GameFontNormalSmall")
    menu.title:SetPoint("TOP", menu, "TOP", 0, -8)

    local rows = {}
    for i, entry in ipairs(entries) do rows[i] = entry end
    rows[#rows + 1] = { CANCEL or "Cancel", NoOp }

    menu.items = {}
    for i, entry in ipairs(rows) do
        local item = CreateFrame("Button", nil, menu)
        item:SetHeight(15)
        item:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -22 - (i - 1) * 15)
        item:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -10, -22 - (i - 1) * 15)
        local label = item:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        label:SetPoint("LEFT", item, "LEFT", 4, 0)
        label:SetText(entry[1])
        item.Label = label
        local highlight = item:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(item)
        highlight:SetColorTexture(1, 0.82, 0, 0.16)
        item.allowed = entry[3]
        item:SetScript("OnClick", function(self)
            menu:Hide()
            if self.entry then entry[2](self.entry) end
        end)
        menu.items[i] = item
    end
    menu:SetScript("OnHide", function(self) self.entry = nil end)

    -- The closing press may be a right click on the same row, whose release
    -- would reopen it: remember the row for 0.4 s so that click just closes.
    ns.RegisterEvents(menu, MOUSE_DOWN)
    menu:SetScript("OnEvent", function(self)
        if not self:IsShown() or self:IsMouseOver() then return end
        self.closedEntry, self.closedAt = self.entry, GetTime()
        self:Hide()
    end)

    menu.Follow = Follow

    function menu:Open(entry, title)
        if self:IsShown() and self.entry == entry then self:Hide() return end
        if self.closedEntry == entry and GetTime() - (self.closedAt or 0) < 0.4 then
            self.closedEntry = nil
            return
        end
        self.closedEntry = nil
        self.entry = entry
        self.title:SetText(title or "")
        local shown = 0
        local widest = self.title:GetStringWidth() or 0
        for _, item in ipairs(self.items) do
            local allowed = (not item.allowed) or item.allowed(entry) and true or false
            item.entry = entry
            item:SetShown(allowed and true or false)
            if allowed then
                widest = math.max(widest, (item.Label:GetStringWidth() or 0) + 4)
                shown = shown + 1
                item:ClearAllPoints()
                item:SetPoint("TOPLEFT", self, "TOPLEFT", 10, -22 - (shown - 1) * 15)
                item:SetPoint("TOPRIGHT", self, "TOPRIGHT", -10, -22 - (shown - 1) * 15)
            end
        end
        -- Widest row plus the rows' 10 inset each side and a little air.
        self:SetSize(math.max(100, math.ceil(widest) + 32), 32 + shown * 15)
        local scale = UIParent:GetEffectiveScale()
        local x, y = GetCursorPosition()
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        self:Show()
    end
    return menu
end
