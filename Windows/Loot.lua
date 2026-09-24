local _, ns = ...

-- 1.x loot window: one 256x256 sheet over a 170x240 window, loot icon and skull
-- in the ring, old name box per row. List and rows stay the client's; the rest fades.

local P = ns.panels
local IsSecret, AnySecret = ns.IsSecret, ns.AnySecret
local Near = ns.Near

local LOOT_W, LOOT_H, LOOT_ROW = 170, 240, 41
-- List top from the window's top; the pager's room at the foot.
local LOOT_TOP, LOOT_ARROWS = 71, 40
local PAGER_ICONS = { "ScrollUp", "ScrollDown" }   -- the old chat buttons (Windows/Chat.lua)
local LOOT_EVENTS = { "LOOT_SLOT_CLEARED", "LOOT_SLOT_CHANGED", "LOOT_OPENED" }
local LOOT_HUSHED = { "NameFrame", "BorderFrame", "HighlightNameFrame", "PushedNameFrame", "QualityStripe", "QualityText" }
local FULL = { 0, 1, 0, 1 }
local NAME_BOX = { own = "nameBox", layer = "BACKGROUND", sublevel = 1, coords = FULL, w = 130, h = 62, point = "LEFT", show = true }
local SHEET = { own = "lootPanel", layer = "BACKGROUND", sublevel = -2, coords = FULL, w = 256, h = 256, point = "TOPLEFT", y = 4, show = true }
local ICON = { own = "lootIcon", layer = "BACKGROUND", sublevel = -1, w = 58, h = 58, point = "TOPLEFT", x = 10, y = -5, show = true }
local SKULL = { own = "lootSkull", layer = "ARTWORK", sublevel = 0, w = 58, h = 58, point = "TOPLEFT", x = 10, y = -5, show = true }
local CHANGED = { changed = true }

local function SkinLootElement(element)
    -- Every look: the client re-lights these as it fills a row, after dressing.
    ns.FadeKeys(element, LOOT_HUSHED, 0, CHANGED)
    if not ns.Once(element, "loot") then return end
    local item = element.Item
    ns.DressNew(element, "lootNameFrame", NAME_BOX, item or element, item and 30 or 35, 0)
    if element.Text and item then
        ns.SetPointOnce(element.Text, "LEFT", item, "RIGHT", 8, 0)
        element.Text:SetSize(93, 38)
        element.Text:SetJustifyV("MIDDLE")
    end
end

-- One walk over the rows per look; each visitor also measures the pitch.
local walkPitch

-- Real row height as drawn; LOOT_ROW until a row exists.
local function Measure(element)
    local height = element.GetHeight and element:GetHeight()
    if height and height > 1 and (not walkPitch or height < walkPitch) then walkPitch = height end
end

-- A looted row stays as an empty slot until close; hide its name box with it.
local function SyncBox(element)
    local nameBox = element.fcui and element.fcui.nameBox
    if not nameBox then return end
    local filled = element.Item == nil or element.Item:IsShown()
    if element.Text then
        local text = element.Text:GetText()
        if not IsSecret(text) and (text or "") == "" then filled = false end
    end
    nameBox:SetShown(filled and true or false)
end

local function PageRow(element)
    SyncBox(element)
    Measure(element)
end

-- The look's visitor: also hushes and dresses rows.
local function LookRow(element)
    SkinLootElement(element)
    SyncBox(element)
    Measure(element)
end

local function Walk(box, visit)
    walkPitch = nil
    if box.ForEachFrame then box:ForEachFrame(visit) end
    return walkPitch or LOOT_ROW
end

local function LootPitch(box)
    return Walk(box, Measure)
end

-- Whole rows only, as in 1.x.
local function LootRows(pitch, paged)
    local room = LOOT_H - LOOT_TOP - (paged and LOOT_ARROWS or 0)
    return math.max(1, math.floor(room / pitch))
end

-- Set the list's foot only if it moved (secret points count as moved); no
-- ClearAllPoints, the top left anchor stays.
local function KeepFoot(box, frame, y)
    local count = box:GetNumPoints()
    if not IsSecret(count) then
        for i = 1, count do
            local point, rel, relPoint, x, py = box:GetPoint(i)
            if AnySecret(point, rel, relPoint, x, py) then break end
            if point == "BOTTOMRIGHT" then
                if rel == frame and relPoint == "BOTTOMRIGHT" and type(x) == "number" and type(py) == "number"
                    and Near(x, 10) and Near(py, y) then return end
                break
            end
        end
    end
    box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 10, y)
end

local function EnableIf(button, on)
    if button:IsEnabled() ~= on then button:SetEnabled(on) end
end

-- Scroll by whole rows (wheel and arrows); free scrolling cut rows at each end.
local function LootScroll(box, rows)
    if not box.GetDerivedScrollRange or not box.SetScrollPercentage then return end
    local range = box:GetDerivedScrollRange() or 0
    if range <= 0 then return end
    local pitch = LootPitch(box)
    local offset = (box.GetDerivedScrollOffset and box:GetDerivedScrollOffset()) or 0
    local at = math.floor(offset / pitch + 0.5) + rows
    local last = math.floor(range / pitch + 0.01)
    at = math.max(0, math.min(last, at))
    box:SetScrollPercentage(math.min(1, (at * pitch) / range))
end

local function UpdateLootPages(frame, visit)
    local box = frame.ScrollBox
    if not box then return end
    local pitch = Walk(box, visit or PageRow)
    local pager = frame.fcuiPager
    if not pager then return end
    local total = box.GetDataProviderSize and box:GetDataProviderSize() or 0
    local paged = total > LootRows(pitch, false)
    ns.SetShownIf(pager, paged)
    local rows = LootRows(pitch, paged)
    frame.fcuiRows = rows
    KeepFoot(box, frame, LOOT_H - LOOT_TOP - rows * pitch)
    if paged then
        local pct = box.GetScrollPercentage and box:GetScrollPercentage() or 0
        EnableIf(pager.up, pct > 0.001)
        EnableIf(pager.down, pct < 0.999)
    end
end

-- Overflow pages with two arrows at the foot, as in 1.x.
local function LootPager(frame)
    if frame.fcuiPager then UpdateLootPages(frame) return end
    local box = frame.ScrollBox
    if not box then return end
    local pager = CreateFrame("Frame", nil, frame)
    pager:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    pager:SetSize(LOOT_W, 40)
    frame.fcuiPager = pager
    local function Arrow(kind, x)
        local button = CreateFrame("Button", nil, pager)
        button:SetSize(32, 32)
        button:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, 6)
        ns.ChatIconButton(button, "Scroll" .. kind, PAGER_ICONS)
        return button
    end
    -- Centred on the dark body (x 21-180), not the window; labels level with arrows.
    pager.up = Arrow("Up", 23)
    pager.down = Arrow("Down", 146)
    local prev = pager:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    prev:SetPoint("LEFT", pager.up, "RIGHT", 2, 0)
    prev:SetText(PREV or "Prev")
    local nxt = pager:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nxt:SetPoint("RIGHT", pager.down, "LEFT", -2, 0)
    nxt:SetText(NEXT or "Next")
    local function Page(direction)
        LootScroll(box, direction * (frame.fcuiRows or 1))
        PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
        UpdateLootPages(frame)
    end
    pager.up:SetScript("OnClick", function() Page(-1) end)
    pager.down:SetScript("OnClick", function() Page(1) end)
    -- The wheel steps a row at a time instead of free scrolling.
    box:SetScript("OnMouseWheel", function(_, delta)
        LootScroll(box, -delta)
        UpdateLootPages(frame)
    end)
    -- Polled from our own frame, never a callback on the client's list (that
    -- taints the rest of its pass). Not the pager's frame: it hides when all fits.
    local look = CreateFrame("Frame", nil, frame)
    local job = ns.Sched.OnFrame(look, { name = "loot.look", every = 0.02, fn = function() UpdateLootPages(frame, LookRow) end })
    -- First look on the frame the window opens.
    look:SetScript("OnShow", function() job:Kick() end)
    frame:HookScript("OnShow", function() UpdateLootPages(frame) end)
    -- Slot change: look next frame, after the client redraws the row.
    local slots = CreateFrame("Frame", nil, pager)
    ns.RegisterEvents(slots, LOOT_EVENTS)
    local function Redraw() if frame:IsShown() then UpdateLootPages(frame) end end
    slots:SetScript("OnEvent", function() ns.Sched.NextFrame("loot.update", Redraw) end)
    UpdateLootPages(frame)
end

-- Fade client textures and unused text on the window and each child not kept.
local FadeBlizzardArt
local function FadeArtRegion(region, frame, keep)
    if ns.IsOwnRegion(frame, region) then return end
    if region:IsObjectType("Texture") then
        region:SetAlpha(0)
    elseif region:IsObjectType("FontString") and not keep[region] then
        region:SetAlpha(0)
    end
end
local function FadeArtChild(child, keep)
    if not keep[child] then FadeBlizzardArt(child, keep) end
end
FadeBlizzardArt = function(frame, keep)
    ns.EachRegion(frame, FadeArtRegion, frame, keep)
    ns.EachChild(frame, FadeArtChild, keep)
end

local function SkinLoot(frame)
    local close = frame.ClosePanelButton or frame.CloseButton
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    local keep = {}
    if frame.ScrollBox then keep[frame.ScrollBox] = true end
    if close then keep[close] = true end
    if title then keep[title] = true end
    FadeBlizzardArt(frame, keep)
    if frame.fcui and frame.fcui.titleStrip then frame.fcui.titleStrip:Hide() end
    -- Old size whatever the list wants; overrides go in before SetSize.
    frame.GetPanelMaxHeight = function() return LOOT_H end
    frame.Resize = function(self) self:SetSize(LOOT_W, LOOT_H) end
    frame:SetSize(LOOT_W, LOOT_H)
    ns.DressNew(frame, "lootPanel", SHEET)
    ns.DressNew(frame, "lootIcon", ICON)
    ns.DressNew(frame, "lootSkull", SKULL)
    ns.SetPointOnce(title, "CENTER", frame, "TOPLEFT", 115, -24)
    if close then
        ns.SkinCloseButton(close)
        ns.SetPointOnce(close, "CENTER", frame, "TOPLEFT", 177, -21)
    end
    local box = frame.ScrollBox
    if box then
        ns.SetPointOnce(box, "TOPLEFT", frame, "TOPLEFT", 21, -LOOT_TOP)
        local pitch = LootPitch(box)
        box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 10, LOOT_H - LOOT_TOP - LootRows(pitch, false) * pitch)
        local view = box.GetView and box:GetView()
        if view and ns.Once(view, "loot") then
            if view.SetElementExtent then view:SetElementExtent(LOOT_ROW) end
            if view.SetPadding then view:SetPadding(0, 0, 0, 0, 0) end
            if box.FullUpdate then box:FullUpdate(ScrollBoxConstants and ScrollBoxConstants.UpdateImmediately) end
        end
        -- New rows are dressed by the pager's look, not a list callback.
        if box.ForEachFrame then box:ForEachFrame(SkinLootElement) end
    end
    -- The thin scroll bar goes; the wheel still scrolls.
    if frame.ScrollBar then frame.ScrollBar:SetAlpha(0) end
    LootPager(frame)
end
P.after.LootFrame = SkinLoot
