local _, ns = ...

-- The old window chrome on Blizzard's panel frames: the metal nine-slice
-- border with the round portrait, the small X close button, the stone
-- title strip, and the character-sheet style tabs along the bottom.
-- Frames are reskinned in place when they exist; load-on-demand windows
-- are skinned when their Blizzard addon loads.

local CORNER, EDGE = 132, 128
local BOTTOM_LIFT = 10
local METAL = "frameMetal"

-- Corner cuts from the UIFrameMetal sheet: with a portrait ring on the
-- top left, or a plain top left, and the minimised (no bottom left ring).
local CORNERS = {
    portrait = {
        TopLeftCorner = { 0.263671875, 0.521484375, 0.263671875, 0.521484375 },
        TopRightCorner = { 0.001953125, 0.259765625, 0.263671875, 0.521484375 },
        BottomLeftCorner = { 0.001953125, 0.259765625, 0.001953125, 0.259765625 },
        BottomRightCorner = { 0.263671875, 0.521484375, 0.001953125, 0.259765625 },
    },
    plain = {
        TopLeftCorner = { 0.525390625, 0.783203125, 0.001953125, 0.259765625 },
        TopRightCorner = { 0.001953125, 0.259765625, 0.263671875, 0.521484375 },
        BottomLeftCorner = { 0.001953125, 0.259765625, 0.001953125, 0.259765625 },
        BottomRightCorner = { 0.263671875, 0.521484375, 0.001953125, 0.259765625 },
    },
}
local EDGES = {
    TopEdge = { key = "frameMetalH", coords = { 0, 1, 0.263671875, 0.521484375 }, w = EDGE, h = CORNER, tileH = true },
    BottomEdge = { key = "frameMetalH", coords = { 0, 1, 0.001953125, 0.259765625 }, w = EDGE, h = CORNER, tileH = true },
    LeftEdge = { key = "frameMetalV", coords = { 0.001953125, 0.259765625, 0, 1 }, w = CORNER, h = EDGE, tileV = true },
    RightEdge = { key = "frameMetalV", coords = { 0.263671875, 0.521484375, 0, 1 }, w = CORNER, h = EDGE, tileV = true },
}

local active = false
local skinnedWindows = {}

local WINDOW_AFTER = setmetatable({}, { __mode = "k" })

local function NineSlice(frame, style)
    local slice = frame.NineSlice
    if not slice then return false end
    local corners = CORNERS[style] or CORNERS.portrait
    for key, coords in pairs(corners) do
        local tex = slice[key]
        if tex then
            ns.SetTex(tex, METAL)
            tex:SetSize(CORNER, CORNER)
            tex:SetTexCoord(unpack(coords))
            -- Blizzard hangs its bottom corners 3px under the frame for
            -- its thin border; the old metal's border line sits at the
            -- bottom of a much taller piece, so it landed below where the
            -- window's content stops. The bottom pieces are lifted to meet
            -- it; the bottom edge is anchored to the corners and follows.
            if key == "BottomLeftCorner" or key == "BottomRightCorner" then
                local point, rel, relPoint, x, y = tex:GetPoint(1)
                if point then
                    if tex.fcuiBaseY == nil then tex.fcuiBaseY = y or 0 end
                    tex:SetPoint(point, rel, relPoint, x or 0, tex.fcuiBaseY + BOTTOM_LIFT)
                end
            end
        end
    end
    for key, edge in pairs(EDGES) do
        local tex = slice[key]
        if tex then
            local primary, fallback = ns.TexPath(edge.key)
            local ok = tex:SetTexture(primary, edge.tileH, edge.tileV)
            if ok == false then tex:SetTexture(fallback, edge.tileH, edge.tileV) end
            tex:SetSize(edge.w, edge.h)
            tex:SetTexCoord(unpack(edge.coords))
        end
    end
    return true
end

function ns.SkinCloseButton(button, keepPosition)
    if not button then return end
    button:SetSize(32, 32)
    ns.SetButtonTex(button, "Normal", "closeUp")
    ns.SetButtonTex(button, "Pushed", "closeDown")
    ns.SetButtonTex(button, "Disabled", "closeDisabled")
    ns.SetButtonTex(button, "Highlight", "closeHighlight")
    for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
        local tex = button["Get" .. state .. "Texture"](button)
        if tex then
            tex:SetTexCoord(0, 1, 0, 1)
            tex:ClearAllPoints()
            tex:SetAllPoints(button)
            if state == "Highlight" then tex:SetBlendMode("ADD") end
        end
    end
    if not keepPosition then
        button:ClearAllPoints()
        button:SetPoint("TOPRIGHT", button:GetParent(), "TOPRIGHT", 5.6, 5)
    end
end

-- Character-sheet tabs along a window's bottom edge.
function ns.SkinBottomTab(tab)
    if not tab or not tab.Left then return end
    local pieces = {
        { tab.LeftActive, "tabActive", { 0, 0.15625, 0, 0.546875 }, 20, 35, "TOPLEFT", 0, 0 },
        { tab.RightActive, "tabActive", { 0.84375, 1, 0, 0.546875 }, 20, 35, "TOPRIGHT", 0, 0 },
        { tab.MiddleActive, "tabActive", { 0.15625, 0.84375, 0, 0.546875 }, 88, 35 },
        { tab.Left, "tabInactive", { 0, 0.15625, 0, 1 }, 20, 32, "TOPLEFT", 0, -1 },
        { tab.Right, "tabInactive", { 0.84375, 1, 0, 1 }, 20, 32, "TOPRIGHT", 0, -1 },
        { tab.Middle, "tabInactive", { 0.15625, 0.84375, 0, 1 }, 88, 32 },
    }
    for _, p in ipairs(pieces) do
        local tex = p[1]
        if tex then
            ns.SetTex(tex, p[2])
            tex:SetTexCoord(unpack(p[3]))
            tex:SetSize(p[4], p[5])
            if tex.SetHorizTile then tex:SetHorizTile(false) end
            if p[6] then
                tex:ClearAllPoints()
                tex:SetPoint(p[6], tab, p[6], p[7], p[8])
            end
        end
    end
    for _, key in ipairs({ "LeftHighlight", "MiddleHighlight", "RightHighlight" }) do
        if tab[key] then tab[key]:SetAlpha(0) end
    end
    ns.SetButtonTex(tab, "Highlight", "tabHighlight")
    local hl = tab:GetHighlightTexture()
    if hl then
        hl:SetTexCoord(0, 1, 0, 1)
        hl:ClearAllPoints()
        hl:SetPoint("TOPLEFT", tab, "TOPLEFT", 3, 5)
        hl:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -3, 0)
        hl:SetBlendMode("ADD")
    end
end

local function SkinMaxMin(button)
    if not button or not button.MaximizeButton then return end
    local pairs_ = { { button.MaximizeButton, "bigger" }, { button.MinimizeButton, "smaller" } }
    for _, p in ipairs(pairs_) do
        local b, key = p[1], p[2]
        if b then
            ns.SetButtonTex(b, "Normal", key .. "Up")
            ns.SetButtonTex(b, "Pushed", key .. "Down")
            ns.SetButtonTex(b, "Disabled", key .. "Disabled")
            ns.SetButtonTex(b, "Highlight", "closeHighlight")
            for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
                local tex = b["Get" .. state .. "Texture"](b)
                if tex then tex:SetTexCoord(0, 1, 0, 1); tex:ClearAllPoints(); tex:SetAllPoints(b) end
            end
            b:SetHitRectInsets(5, 5, 5, 5)
        end
    end
end

-- One portrait window: border, portrait ring, title strip, close button, tabs.
function ns.SkinWindow(frame, opts)
    if not frame or not active then return end
    opts = opts or {}
    local name = frame:GetName()
    if not NineSlice(frame, opts.portrait == false and "plain" or "portrait") then return end
    frame.fcui = frame.fcui or {}
    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait or (name and _G[name .. "Portrait"])
    if portrait and opts.portrait ~= false then
        portrait:SetSize(61, 61)
        portrait:ClearAllPoints()
        portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", -6, 8)
    end
    if frame.TitleContainer then
        frame.TitleContainer:ClearAllPoints()
        frame.TitleContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", opts.portrait == false and 6 or 58, 0)
        frame.TitleContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -58, 0)
    end
    -- Our own dark backing under everything, out to the metal: the
    -- window's own backing stops at its thinner border and left a strip
    -- of world showing under ours. Same stone as the window uses.
    -- Not on a border that sits over its window's content (the map).
    if opts.backing ~= false then
        local backing = ns.OwnTexture(frame, "backing", "BACKGROUND", -2)
        local bgAtlas = frame.Bg and frame.Bg.GetAtlas and frame.Bg:GetAtlas()
        if bgAtlas and bgAtlas ~= "" then
            backing:SetAtlas(bgAtlas, false)
            pcall(backing.SetHorizTile, backing, true)
            pcall(backing.SetVertTile, backing, true)
        else
            backing:SetColorTexture(0.06, 0.05, 0.04, 1)
        end
        backing:ClearAllPoints()
        backing:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
        backing:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
        backing:Show()
    elseif frame.fcui and frame.fcui.backing then
        frame.fcui.backing:Hide()
    end
    local strip = ns.OwnTexture(frame, "titleStrip", "BACKGROUND")
    strip:SetAtlas("_UI-Frame-TitleTileBg", true)
    strip:ClearAllPoints()
    strip:SetPoint("TOPLEFT", frame, "TOPLEFT", opts.portrait == false and 6 or 2, -3)
    strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -25, -3)
    strip:Show()
    ns.SkinCloseButton(frame.CloseButton or (name and _G[name .. "CloseButton"]))
    if frame.MaximizeMinimizeButton then
        SkinMaxMin(frame.MaximizeMinimizeButton)
        frame.MaximizeMinimizeButton:SetSize(32, 32)
        local close = frame.CloseButton or (name and _G[name .. "CloseButton"])
        if close then
            frame.MaximizeMinimizeButton:ClearAllPoints()
            frame.MaximizeMinimizeButton:SetPoint("RIGHT", close, "LEFT", 8.5, 0)
        end
    end
    -- Tabs: a tab system, or the classic numbered globals.
    if frame.TabSystem then
        for _, tab in ipairs({ frame.TabSystem:GetChildren() }) do ns.SkinBottomTab(tab) end
    end
    if name then
        local i = 1
        while _G[name .. "Tab" .. i] do
            ns.SkinBottomTab(_G[name .. "Tab" .. i])
            i = i + 1
        end
    end
    if opts.after then opts.after(frame) end
    skinnedWindows[frame] = true
end

-- The loot window in the 1.x manner: the portrait window with the loot
-- icon and the dead-target skull in the ring, and each row an icon
-- with the old name box beside it. The client's card art, quality
-- stripe and tag are faded; the list and its rows are Blizzard's.
local function SkinLootElement(element)
    if element.fcuiLoot then return end
    element.fcuiLoot = true
    for _, key in ipairs({ "NameFrame", "BorderFrame", "HighlightNameFrame", "PushedNameFrame", "QualityStripe", "QualityText" }) do
        if element[key] then element[key]:SetAlpha(0) end
    end
    local box = ns.OwnTexture(element, "nameBox", "BACKGROUND", 1)
    ns.SetTex(box, "lootNameFrame")
    box:SetTexCoord(0, 1, 0, 1)
    box:SetSize(130, 62)
    box:ClearAllPoints()
    if element.Item then
        box:SetPoint("LEFT", element.Item, "LEFT", 30, 0)
    else
        box:SetPoint("LEFT", element, "LEFT", 35, 0)
    end
    box:Show()
    if element.Text and element.Item then
        element.Text:ClearAllPoints()
        element.Text:SetPoint("LEFT", element.Item, "RIGHT", 8, 0)
        element.Text:SetSize(93, 38)
        element.Text:SetJustifyV("MIDDLE")
    end
end

-- The 1.x loot panel is one sheet: ring, title strip and the dark body
-- in a single 256x256 file, drawn over a 170x240 window with four rows.
-- Everything Blizzard draws outside the list is faded; the list and its
-- rows stay Blizzard's, at the old row height.
local LOOT_W, LOOT_H, LOOT_ROW = 170, 240, 41

local function FadeBlizzardArt(frame, keep)
    for _, region in ipairs({ frame:GetRegions() }) do
        local ours = frame.fcui and (function()
            for _, tex in pairs(frame.fcui) do if tex == region then return true end end
        end)()
        if not ours then
            if region:IsObjectType("Texture") then
                region:SetAlpha(0)
            elseif region:IsObjectType("FontString") and not keep[region] then
                region:SetAlpha(0)
            end
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        if not keep[child] then FadeBlizzardArt(child, keep) end
    end
end

-- More loot than four rows: 1.x showed three and paged with the two
-- arrows at the bottom. The arrows move the scroll box a page at a
-- time; the wheel still works between them.
local LOOT_ROWS, LOOT_PAGE_ROWS = 4, 3
local LootPager
local function LootPageStep(box, rows)
    local range = box.GetDerivedScrollRange and box:GetDerivedScrollRange() or 0
    if range <= 0 then return 1 end
    return (rows * LOOT_ROW) / range
end

local function UpdateLootPages(frame)
    local box, pager = frame.ScrollBox, frame.fcuiPager
    if not box or not pager then return end
    local total = box.GetDataProviderSize and box:GetDataProviderSize() or 0
    local paged = total > LOOT_ROWS
    pager:SetShown(paged)
    box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 10, paged and (LOOT_H - 71 - LOOT_PAGE_ROWS * LOOT_ROW) or 8)
    if paged then
        local pct = box.GetScrollPercentage and box:GetScrollPercentage() or 0
        pager.up:SetEnabled(pct > 0.001)
        pager.down:SetEnabled(pct < 0.999)
    end
end

LootPager = function(frame)
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
        button:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-Scroll" .. kind .. "-Up")
        button:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-Scroll" .. kind .. "-Down")
        button:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-Scroll" .. kind .. "-Disabled")
        button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        return button
    end
    pager.up = Arrow("Up", 8)
    pager.down = Arrow("Down", 130)
    local prev = pager:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    prev:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 45, 18)
    prev:SetText(PREV or "Prev")
    local nxt = pager:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nxt:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 127, 18)
    nxt:SetText(NEXT or "Next")
    local function Page(direction)
        if not box.GetScrollPercentage or not box.SetScrollPercentage then return end
        local pct = box:GetScrollPercentage() + direction * LootPageStep(box, LOOT_PAGE_ROWS)
        box:SetScrollPercentage(math.max(0, math.min(1, pct)))
        PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
        UpdateLootPages(frame)
    end
    pager.up:SetScript("OnClick", function() Page(-1) end)
    pager.down:SetScript("OnClick", function() Page(1) end)
    if box.RegisterCallback and ScrollBoxListMixin and ScrollBoxListMixin.Event then
        box:RegisterCallback(ScrollBoxListMixin.Event.OnScroll, function() UpdateLootPages(frame) end, pager)
        if ScrollBoxListMixin.Event.OnDataRangeChanged then
            box:RegisterCallback(ScrollBoxListMixin.Event.OnDataRangeChanged, function() UpdateLootPages(frame) end, pager)
        end
    end
    frame:HookScript("OnShow", function() UpdateLootPages(frame) end)
    UpdateLootPages(frame)
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
    -- The window holds its old size whatever the list wants.
    frame.GetPanelMaxHeight = function() return LOOT_H end
    frame.Resize = function(self) self:SetSize(LOOT_W, LOOT_H) end
    frame:SetSize(LOOT_W, LOOT_H)
    local art = ns.OwnTexture(frame, "lootPanel", "BACKGROUND", -2)
    ns.SetTex(art, "lootPanel")
    art:SetTexCoord(0, 1, 0, 1)
    art:SetSize(256, 256)
    art:ClearAllPoints()
    art:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 4)
    art:Show()
    local icon = ns.OwnTexture(frame, "lootIcon", "BACKGROUND", -1)
    ns.SetTex(icon, "lootIcon")
    icon:SetSize(58, 58)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -5)
    icon:Show()
    local skull = ns.OwnTexture(frame, "lootSkull", "ARTWORK", 0)
    ns.SetTex(skull, "lootSkull")
    skull:SetSize(58, 58)
    skull:ClearAllPoints()
    skull:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -5)
    skull:Show()
    if title then
        title:ClearAllPoints()
        title:SetPoint("CENTER", frame, "TOPLEFT", 115, -24)
    end
    if close then
        ns.SkinCloseButton(close)
        close:ClearAllPoints()
        close:SetPoint("CENTER", frame, "TOPLEFT", 177, -21)
    end
    local box = frame.ScrollBox
    if box then
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", frame, "TOPLEFT", 21, -71)
        box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 10, 8)
        local view = box.GetView and box:GetView()
        if view and not view.fcuiLoot then
            view.fcuiLoot = true
            if view.SetElementExtent then view:SetElementExtent(LOOT_ROW) end
            if view.SetPadding then view:SetPadding(0, 0, 0, 0, 0) end
            if box.FullUpdate then box:FullUpdate(ScrollBoxConstants and ScrollBoxConstants.UpdateImmediately) end
        end
        if not frame.fcuiLootHooked and box.RegisterCallback and ScrollBoxListMixin and ScrollBoxListMixin.Event then
            frame.fcuiLootHooked = true
            box:RegisterCallback(ScrollBoxListMixin.Event.OnAcquiredFrame, function(_, element) SkinLootElement(element) end, frame)
        end
        if box.ForEachFrame then box:ForEachFrame(SkinLootElement) end
    end
    -- The thin scroll bar goes; the wheel still scrolls.
    if frame.ScrollBar then frame.ScrollBar:SetAlpha(0) end
    LootPager(frame)
end

-- Windows and the Blizzard addon that brings each one.
local WINDOWS = {
    { "WorldMapFrame", child = "BorderFrame", portrait = false, backing = false, after = function(border)
        -- Blizzard swaps the map's border and portrait on every minimize
        -- and maximize; put ours back each time.
        -- Keep Blizzard's portrait header height (the map's canvas is laid
        -- out under it); only the portrait itself goes.
        local portrait = border.PortraitContainer and border.PortraitContainer.portrait
        if portrait then portrait:SetAlpha(0) end
        -- The close button sits inside the header, the size button beside it.
        local close = border.CloseButton
        if close then
            close:ClearAllPoints()
            -- Blizzard's own spot is the corner at (1, 0) for a 24px button;
            -- the 32px old art lands on the same centre from (5, 4).
            close:SetPoint("TOPRIGHT", border, "TOPRIGHT", 4, 4)
        end
        local sizer = border.MaximizeMinimizeFrame
        if sizer and sizer.MaximizeButton then
            SkinMaxMin(sizer)
            sizer:SetSize(32, 32)
            if close then
                sizer:ClearAllPoints()
                sizer:SetPoint("RIGHT", close, "LEFT", 8, 0)
            end
        end
        if not border.fcuiMapHooked and WorldMapFrame then
            border.fcuiMapHooked = true
            for _, method in ipairs({ "Minimize", "Maximize" }) do
                ns.HookMethod(WorldMapFrame, method, function()
                    if active then C_Timer.After(0, function() ns.SkinWindow(border, { portrait = false, backing = false, after = WINDOW_AFTER[border] }) end) end
                end)
            end
        end
    end },
    { "MerchantFrame" },
    { "MailFrame" },
    { "FriendsFrame" },
    { "QuestFrame" },
    { "GossipFrame" },
    { "TradeFrame" },
    { "TaxiFrame" },
    { "DressUpFrame" },
    { "PetStableFrame" },
    { "ItemTextFrame" },
    { "TabardFrame" },
    { "GuildRegistrarFrame" },
    { "PetitionFrame" },
    { "BankFrame" },
    { "LootFrame", backing = false, after = SkinLoot },
    { "InspectFrame", addon = "Blizzard_InspectUI" },
    { "MacroFrame", addon = "Blizzard_MacroUI" },
    { "ClassTrainerFrame", addon = "Blizzard_TrainerUI" },
    { "AuctionHouseFrame", addon = "Blizzard_AuctionHouseUI" },
    { "CommunitiesFrame", addon = "Blizzard_Communities" },
    { "CollectionsJournal", addon = "Blizzard_Collections", after = function(frame)
        -- Its border art runs a few pixels past the frame; the X sits in.
        local close = frame.CloseButton
        if close then
            close:ClearAllPoints()
            close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1.6, 5)
        end
    end },
    { "EncounterJournal", addon = "Blizzard_EncounterJournal" },
    { "AchievementFrame", addon = "Blizzard_AchievementUI" },
    { "ProfessionsFrame", addon = "Blizzard_Professions" },
    { "ProfessionsBookFrame", addon = "Blizzard_ProfessionsBook", after = function(frame)
        local close = frame.CloseButton
        if close then
            close:ClearAllPoints()
            close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0.6, 5)
        end
    end },
    { "GuildBankFrame", addon = "Blizzard_GuildBankUI" },
    { "CalendarFrame", addon = "Blizzard_Calendar", portrait = false },
    { "ItemSocketingFrame", addon = "Blizzard_ItemSocketingUI" },
}

local watcher

local function SkinKnown()
    for _, entry in ipairs(WINDOWS) do
        local frame = _G[entry[1]]
        if frame and entry.child then frame = frame[entry.child] end
        if frame and not skinnedWindows[frame] then
            WINDOW_AFTER[frame] = entry.after
            ns.SkinWindow(frame, { portrait = entry.portrait, backing = entry.backing, after = entry.after })
        end
    end
end

local function Apply()
    active = true
    SkinKnown()
    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:RegisterEvent("ADDON_LOADED")
        watcher:SetScript("OnEvent", function() if active then SkinKnown() end end)
    end
end

local function Restore()
    active = false
    for frame in pairs(skinnedWindows) do
        if frame.fcui and frame.fcui.titleStrip then frame.fcui.titleStrip:Hide() end
    end
    ns.needsReload = true
end

ns.RegisterModule("panels", { apply = Apply, restore = Restore })
