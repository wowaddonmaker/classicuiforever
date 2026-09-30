local _, ns = ...

-- Drop down lists and row right-click menus, on Classic Era's menu art and numbers (Blizzard_Menu Classic).

local MOUSE_DOWN = { "GLOBAL_MOUSE_DOWN" }
-- The client's own right-click menus wear the tooltip's thin rim and fill (UI/ClientMenus.lua).
local TIP_FILL = _G.TOOLTIP_DEFAULT_BACKGROUND_COLOR
ns.MENU_LOOK = { bronze = false, border = { 1, 1, 1, 1 },
    bg = TIP_FILL and { TIP_FILL.r, TIP_FILL.g, TIP_FILL.b, 1 } or { 0.09, 0.09, 0.19, 1 } }

-- Era's menu sheet (256 square): each box as left, top, right, bottom px.
local SHEET = 256
local IRON_BOX, IRON_MARGIN = { 1, 1, 97, 97 }, 32          -- common-dropdown-classic-bg: drop down lists
local RIM_BOX, RIM_MARGIN = { 99, 44, 147, 92 }, 16         -- common-dropdown-classic-b-bg: right-click menus
local RADIO_ON = { 208, 127, 224, 143 }                     -- common-dropdown-icon-radialtick-yellow-classic
local RADIO_OFF = { 226, 127, 242, 143 }                    -- common-dropdown-tickradial-classic
-- Era's styles: the art past the menu's edges (left, top, right, bottom), the black fill in from the art, the insets.
local IRON_OUT, IRON_FILL, IRON_INSET = { -3, 3, 3, -4 }, { 6, -6, -6, 6 }, { 16, 10, 16, 10 }
local RIM_OUT, RIM_FILL, RIM_INSET = { -3, 1, 3, -4 }, { 7, -4, -8, 8 }, { 14, 14, 14, 14 }
local FILL_ALPHA = 0.8
local MENU_ROW = 20             -- every text row
local MENU_DIVIDER = 13         -- divider row
local RADIO_SIZE, RADIO_GAP = 16, 2
local DROP_LIST_X = 0           -- drop down list: its top left from its owner's bottom left (+ right)
local DROP_LIST_Y = -2          -- (+ up)
local DIVIDER_FILE = "Interface\\Common\\UI-TooltipDivider-Transparent"
local HIGHLIGHT_FILE = "Interface\\QuestFrame\\UI-QuestTitleHighlight"

local function Coords(tex, box)
    tex:SetTexCoord(box[1] / SHEET, box[3] / SHEET, box[2] / SHEET, box[4] / SHEET)
end

-- One box of the sheet as nine stretched pieces over host's area.
local function Slice9(host, box, margin)
    local xs = { box[1], box[1] + margin, box[3] - margin, box[3] }
    local ys = { box[2], box[2] + margin, box[4] - margin, box[4] }
    local p = {}
    for row = 1, 3 do
        for col = 1, 3 do
            local tex = host:CreateTexture(nil, "BACKGROUND")
            ns.SetTex(tex, "dropdownClassic")
            Coords(tex, { xs[col], ys[row], xs[col + 1], ys[row + 1] })
            p[#p + 1] = tex
        end
    end
    for _, i in ipairs({ 1, 3, 7, 9 }) do p[i]:SetSize(margin, margin) end
    p[1]:SetPoint("TOPLEFT")
    p[3]:SetPoint("TOPRIGHT")
    p[7]:SetPoint("BOTTOMLEFT")
    p[9]:SetPoint("BOTTOMRIGHT")
    local spans = { [2] = { 1, 3, "TOPRIGHT", "BOTTOMLEFT" }, [8] = { 7, 9, "TOPRIGHT", "BOTTOMLEFT" },
        [4] = { 1, 7, "BOTTOMLEFT", "TOPRIGHT" }, [6] = { 3, 9, "BOTTOMLEFT", "TOPRIGHT" },
        [5] = { 1, 9, "BOTTOMRIGHT", "TOPLEFT" } }
    for i, s in pairs(spans) do
        p[i]:SetPoint("TOPLEFT", p[s[1]], s[3])
        p[i]:SetPoint("BOTTOMRIGHT", p[s[2]], s[4])
    end
end

-- The style's art and fill, under the menu's rows.
local function Dress(menu, box, margin, out, fill)
    local art = ns.NewFrame("Frame", nil, menu)
    art:SetPoint("TOPLEFT", menu, "TOPLEFT", out[1], out[2])
    art:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", out[3], out[4])
    art:SetFrameLevel(menu:GetFrameLevel())
    Slice9(art, box, margin)
    local black = art:CreateTexture(nil, "BACKGROUND", nil, -1)
    black:SetColorTexture(0, 0, 0, FILL_ALPHA)
    black:SetPoint("TOPLEFT", art, "TOPLEFT", fill[1], fill[2])
    black:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", fill[3], fill[4])
end

local function NewMenu(strata)
    local menu = CreateFrame("Frame", nil, UIParent)
    menu:SetFrameStrata(strata)
    menu:EnableMouse(true)
    menu:SetClampedToScreen(true)
    menu:Hide()
    return menu
end

local function Highlight(button)
    local hl = button:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(HIGHLIGHT_FILE)
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(button)
end

-- Hides with the frame it follows (always ours); one hook per frame.
local function Follow(self, frame)
    if not frame or self.following == frame then return end
    self.following = frame
    frame:HookScript("OnHide", function() self:Hide() end)
end

-- Entries are { text, onPick, isChosen }: Era's iron list, a radio per row.
function ns.DropList(entries)
    local list = NewMenu("FULLSCREEN_DIALOG")
    Dress(list, IRON_BOX, IRON_MARGIN, IRON_OUT, IRON_FILL)
    list.items = {}
    local widest = 0
    for i, entry in ipairs(entries) do
        local item = ns.NewFrame("Button", nil, list)
        item:SetHeight(MENU_ROW)
        item:SetPoint("TOPLEFT", list, "TOPLEFT", IRON_INSET[1], -IRON_INSET[2] - (i - 1) * MENU_ROW)
        item:SetPoint("TOPRIGHT", list, "TOPRIGHT", -IRON_INSET[3], -IRON_INSET[2] - (i - 1) * MENU_ROW)
        local mark = item:CreateTexture(nil, "ARTWORK")
        ns.SetTex(mark, "dropdownClassic")
        mark:SetSize(RADIO_SIZE, RADIO_SIZE)
        mark:SetPoint("LEFT", item, "LEFT", 0, 0)
        item.mark = mark
        local label = item:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", mark, "RIGHT", RADIO_GAP, 0)
        label:SetText(entry[1])
        widest = math.max(widest, label:GetStringWidth() or 0)
        Highlight(item)
        item:SetScript("OnClick", function()
            list:Hide()
            PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
            entry[2]()
        end)
        item.entry = entry
        list.items[i] = item
    end
    list:SetSize(math.ceil(widest) + RADIO_SIZE + RADIO_GAP + IRON_INSET[1] + IRON_INSET[3],
        #entries * MENU_ROW + IRON_INSET[2] + IRON_INSET[4])

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
            Coords(item.mark, chosen and RADIO_ON or RADIO_OFF)
        end
        ns.SetPointOnce(self, "TOPLEFT", owner, "BOTTOMLEFT", DROP_LIST_X, DROP_LIST_Y)
        self:Show()
        self:Raise()
    end
    ns.CloseOnEscape(list)
    return list
end

-- Entries are { text, onClick, allowed } rows and { section = label } heads, as Era's player menus: the name, then
-- each section with a shown row under a divider and its gold head.
function ns.RowMenu(entries)
    local menu = NewMenu("DIALOG")
    Dress(menu, RIM_BOX, RIM_MARGIN, RIM_OUT, RIM_FILL)

    local function Text(font)
        local text = menu:CreateFontString(nil, "ARTWORK", font)
        text:SetHeight(MENU_ROW)
        text:SetJustifyH("LEFT")
        return text
    end
    menu.title = Text("GameFontNormal")

    local sections = { { rows = {} } }
    for _, entry in ipairs(entries) do
        if entry.section then
            local divider = menu:CreateTexture(nil, "ARTWORK")
            divider:SetTexture(DIVIDER_FILE)
            divider:SetHeight(MENU_DIVIDER)
            local head = Text("GameFontNormal")
            head:SetText(entry.section)
            sections[#sections + 1] = { rows = {}, divider = divider, head = head }
        else
            local item = ns.NewFrame("Button", nil, menu)
            item:SetHeight(MENU_ROW)
            local label = item:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            label:SetPoint("LEFT", item, "LEFT", 0, 0)
            label:SetText(entry[1])
            item.Label = label
            Highlight(item)
            item.allowed = entry[3]
            item:SetScript("OnClick", function(self)
                menu:Hide()
                if self.entry then entry[2](self.entry) end
            end)
            local rows = sections[#sections].rows
            rows[#rows + 1] = item
        end
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

    -- Each shown piece down the menu from the top inset; y grows by its height.
    local y, placed
    local function Put(piece, height)
        ns.SetPointOnce(piece, "TOPLEFT", menu, "TOPLEFT", RIM_INSET[1], -y)
        placed[#placed + 1] = piece
        y = y + height
    end

    function menu:Open(entry, title)
        if self:IsShown() and self.entry == entry then self:Hide() return end
        if self.closedEntry == entry and GetTime() - (self.closedAt or 0) < 0.4 then
            self.closedEntry = nil
            return
        end
        self.closedEntry = nil
        self.entry = entry
        y, placed = RIM_INSET[2], {}
        local widest = 0
        self.title:SetText(title or "")
        self.title:SetShown(title ~= nil and title ~= "")
        if self.title:IsShown() then
            Put(self.title, MENU_ROW)
            widest = self.title:GetStringWidth() or 0
        end
        for _, section in ipairs(sections) do
            local shown = {}
            for _, item in ipairs(section.rows) do
                local allowed = (not item.allowed) or item.allowed(entry) and true or false
                item.entry = entry
                item:SetShown(allowed and true or false)
                if allowed then shown[#shown + 1] = item end
            end
            local open = #shown > 0
            if section.divider then
                section.divider:SetShown(open)
                section.head:SetShown(open)
                if open then
                    Put(section.divider, MENU_DIVIDER)
                    Put(section.head, MENU_ROW)
                    widest = math.max(widest, section.head:GetStringWidth() or 0)
                end
            end
            for _, item in ipairs(shown) do
                Put(item, MENU_ROW)
                widest = math.max(widest, item.Label:GetStringWidth() or 0)
            end
        end
        local inner = math.ceil(widest)
        for _, piece in ipairs(placed) do piece:SetWidth(inner) end
        self:SetSize(inner + RIM_INSET[1] + RIM_INSET[3], y + RIM_INSET[4])
        local scale = UIParent:GetEffectiveScale()
        local x, cy = GetCursorPosition()
        ns.SetPointOnce(self, "TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, cy / scale)
        self:Show()
    end
    return menu
end
