local _, ns = ...

-- The old window chrome on Blizzard's panel frames: the metal nine-slice
-- border with the round portrait, the small X close button, the stone
-- title strip, and the character-sheet style tabs along the bottom.
-- Frames are reskinned in place when they exist; load-on-demand windows
-- are skinned when their Blizzard addon loads.

local CORNER, EDGE = 132, 128
local BOTTOM_LIFT = 10
-- The map's border: the full lift ran through the coordinate line at
-- the map's foot, none left the gap under it.
local MAP_LIFT = 5
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

local function NineSlice(frame, style, lift)
    local slice = frame.NineSlice
    if not slice then return false end
    local corners = CORNERS[style] or CORNERS.portrait
    for key, coords in pairs(corners) do
        local tex = slice[key]
        if tex then
            ns.SetTex(tex, METAL)
            tex:SetSize(CORNER, CORNER)
            tex:SetTexCoord(unpack(coords))
            -- A plain corner on a layout made for the portrait corner:
            -- the portrait piece hangs 13px out, the plain one 8px.
            if style == "plain" and key == "TopLeftCorner" then
                local point, rel, relPoint, x, y = tex:GetPoint(1)
                if point and x and x < -8 then tex:SetPoint(point, rel, relPoint, -8, y) end
            end
            -- Blizzard hangs its bottom corners 3px under the frame for
            -- its thin border; the old metal's border line sits at the
            -- bottom of a much taller piece, so it landed below where the
            -- window's content stops. The bottom pieces are lifted to meet
            -- it; the bottom edge is anchored to the corners and follows.
            if key == "BottomLeftCorner" or key == "BottomRightCorner" then
                local point, rel, relPoint, x, y = tex:GetPoint(1)
                if point then
                    if tex.fcuiBaseY == nil then tex.fcuiBaseY = y or 0 end
                    tex:SetPoint(point, rel, relPoint, x or 0, tex.fcuiBaseY + (tonumber(lift) or BOTTOM_LIFT))
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
    -- The socket the X sits in is drawn on the border's top right corner
    -- piece, so the button hangs off that piece at one fixed offset; the
    -- corner's own offset from the frame differs per window layout and
    -- no longer matters.
    if not keepPosition then
        local parent = button:GetParent()
        local corner = parent and parent.NineSlice and parent.NineSlice.TopRightCorner
        button:ClearAllPoints()
        if corner then
            button:SetPoint("TOPRIGHT", corner, "TOPRIGHT", 0.6, -11)
        else
            button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 4.6, 5)
        end
    end
end

-- A tab anchored to its window's bottom meets the metal border, which
-- sits BOTTOM_LIFT above the frame's bottom; tabs anchored to other
-- tabs follow. Blizzard puts the anchor back at times, so this runs
-- with every fit.
local function LiftTab(tab)
    local point, rel, relPoint, x, y = tab:GetPoint(1)
    if not point or rel ~= tab:GetParent() then return end
    if tab.fcuiLiftedY == y then return end
    tab.fcuiLiftedY = (y or 0) + (tonumber(tab.fcuiLift) or BOTTOM_LIFT)
    tab:SetPoint(point, rel, relPoint, x or 0, tab.fcuiLiftedY)
end

-- A skinned tab takes its label's width plus the caps.
function ns.FitBottomTab(tab)
    LiftTab(tab)
    local text = tab.Text or (tab.GetFontString and tab:GetFontString())
    if not text then return end
    local width = math.ceil(text:GetStringWidth() or 0) + 50
    tab:SetWidth(width)
    if tab.Middle then tab.Middle:SetWidth(width - 40) end
    if tab.MiddleActive then tab.MiddleActive:SetWidth(width - 40) end
end
if type(PanelTemplates_TabResize) == "function" then
    hooksecurefunc("PanelTemplates_TabResize", function(tab) if tab and tab.fcuiTab then ns.FitBottomTab(tab) end end)
end

-- Character-sheet tabs along a window's bottom edge.
function ns.SkinBottomTab(tab)
    if not tab or not tab.Left then return end
    local pieces = {
        { tab.LeftActive, "tabActive", { 0, 0.15625, 0, 0.546875 }, 20, 35, "TOPLEFT", 0, 0 },
        { tab.RightActive, "tabActive", { 0.84375, 1, 0, 0.546875 }, 20, 35, "TOPRIGHT", 0, 0 },
        { tab.MiddleActive, "tabActive", { 0.15625, 0.84375, 0, 0.546875 }, 88, 35 },
        { tab.Left, "tabInactive", { 0, 0.15625, 0, 1 }, 20, 32, "TOPLEFT", 0, -4 },
        { tab.Right, "tabInactive", { 0.84375, 1, 0, 1 }, 20, 32, "TOPRIGHT", 0, -4 },
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
    tab.fcuiTab = true
    ns.FitBottomTab(tab)
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
    -- The lift closes the gap under a window's content; a border laid
    -- over its window's content (the map, with its coordinate line at
    -- the very bottom) takes a smaller lift of its own.
    if not NineSlice(frame, opts.portrait == false and "plain" or "portrait", opts.lift) then return end
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
    -- The old window: rock out to the metal, the streak band under the
    -- title, and marble as the floor of the inset alone (the old
    -- ButtonFrameTemplate: Bg rock, TopTileStreaks, Inset with marble).
    if opts.backing ~= false then
        local backing = ns.OwnTexture(frame, "backing", "BACKGROUND", -2)
        backing:SetTexture(ns.TexPath("rockBg"), "REPEAT", "REPEAT")
        backing:SetHorizTile(true)
        backing:SetVertTile(true)
        backing:SetTexCoord(0, 1, 0, 1)
        -- The window's own dark rock sits in the same layer above ours.
        -- A window whose background is parchment keeps it: the guild
        -- registrar and the charter are written on parchment as they
        -- were in 1.x, and hiding it left gold text on near black.
        local bg = frame.Bg or (frame:GetName() and _G[frame:GetName() .. "Bg"])
        if bg and bg.SetAlpha and bg.IsObjectType and bg:IsObjectType("Texture") then
            local atlas = bg.GetAtlas and bg:GetAtlas()
            local file = bg.GetTexture and bg:GetTexture()
            local parchment = (type(atlas) == "string" and atlas:lower():find("parchment", 1, true) ~= nil)
                or (type(file) == "string" and file:lower():find("parchment", 1, true) ~= nil)
            if parchment then bg:SetAlpha(1) else bg:SetAlpha(0) end
        end
        if frame.TopTileStreaks then frame.TopTileStreaks:SetAlpha(0) end
        backing:ClearAllPoints()
        -- Out to the frame's own edge: the metal's inner line sits within
        -- a few pixels of it, and a 4px inset left a strip of world down
        -- the left of the mail and collections windows.
        backing:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        -- A window whose metal stands a few pixels inside its right edge
        -- (the talk and quest windows) pulls the backing in by that much,
        -- or the rock showed past the border.
        backing:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(tonumber(opts.backingRight) or 0), tonumber(opts.backingBottom) or 0)
        backing:Show()
        local streaks = ns.OwnTexture(frame, "streaks", "BACKGROUND", -1)
        streaks:SetTexture(ns.TexPath("frameSheet"), "REPEAT", "CLAMP")
        streaks:SetHorizTile(true)
        streaks:SetTexCoord(0, 1, 0.671875, 0.9609375)
        streaks:SetHeight(37)
        streaks:ClearAllPoints()
        streaks:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -21)
        streaks:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -21)
        streaks:Show()
        local inset = frame.Inset or (name and _G[name .. "Inset"])
        local floor = ns.OwnTexture(frame, "insetFloor", "BACKGROUND", -1)
        if inset and inset.GetObjectType and inset:GetObjectType() == "Frame" then
            -- The inset's own thin inner border drew a dark line a few
            -- pixels in from the metal, which read as a gap down the
            -- left of the mail and collections windows.
            if inset.NineSlice then
                for _, region in ipairs({ inset.NineSlice:GetRegions() }) do
                    if region:IsObjectType("Texture") then region:SetAlpha(0) end
                end
            end
            if inset.Bg and inset.Bg.SetAlpha then inset.Bg:SetAlpha(0) end
            floor:SetTexture(ns.TexPath("marbleBg"), "REPEAT", "REPEAT")
            floor:SetHorizTile(true)
            floor:SetVertTile(true)
            floor:SetTexCoord(0, 1, 0, 1)
            floor:ClearAllPoints()
            floor:SetPoint("TOPLEFT", inset, "TOPLEFT", 0, 0)
            floor:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", 0, 0)
            floor:Show()
        else
            floor:Hide()
        end
    elseif frame.fcui and frame.fcui.backing then
        frame.fcui.backing:Hide()
        if frame.fcui.streaks then frame.fcui.streaks:Hide() end
        if frame.fcui.insetFloor then frame.fcui.insetFloor:Hide() end
    end
    local strip = ns.OwnTexture(frame, "titleStrip", "BACKGROUND")
    strip:SetTexture(ns.TexPath("frameSheet"), "REPEAT", "CLAMP")
    strip:SetHorizTile(true)
    strip:SetTexCoord(0, 1, 0.2890625, 0.421875)
    strip:SetHeight(17)
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
        for _, tab in ipairs({ frame.TabSystem:GetChildren() }) do
            tab.fcuiLift = opts.tabLift or opts.lift
            ns.SkinBottomTab(tab)
        end
    end
    if name then
        -- The numbers are not always a run: the social window has a first,
        -- a third and a fourth tab, so a walk that stopped at the gap left
        -- its Raid tab in the client's own art.
        for i = 1, 10 do
            local numbered = _G[name .. "Tab" .. i]
            if numbered then
                numbered.fcuiLift = opts.tabLift or opts.lift
                ns.SkinBottomTab(numbered)
            end
        end
    end
    -- The thin scroll bars inside the window wear the old knob and arrows.
    if ns.SkinScrollBarsUnder then ns.SkinScrollBarsUnder(frame, 5) end
    if opts.after then opts.after(frame) end
    skinnedWindows[frame] = true
end

-- A quest reward button in the old manner: the name box behind the
-- words, as the 1.x quest frame drew it. The client leaves that slot
-- bare and paints a thin border on the icon instead.
function ns.SkinQuestReward(button)
    if not button or button.fcuiReward then return end
    button.fcuiReward = true
    local box = ns.OwnTexture(button, "nameBox", "BACKGROUND", 1)
    ns.SetTex(box, "lootNameFrame")
    box:SetTexCoord(0, 1, 0, 1)
    local width = (button:GetWidth() or 143) - 40
    local height = math.max(36, (button:GetHeight() or 40) - 2)
    ns.FitNamePlate(box, button, 38, width, height)
    box:Show()
    if button.NameFrame then button.NameFrame:SetAlpha(0) end
    if button.IconBorder then button.IconBorder:SetAlpha(0) end
end

-- Every reward button the quest frames carry, wherever the client keeps
-- them: the quest giver's frame, the quest log's detail and the map's.
function ns.SkinQuestRewards()
    for _, name in ipairs({ "QuestInfoRewardsFrame", "MapQuestInfoRewardsFrame" }) do
        local frame = _G[name]
        if frame then
            for _, key in ipairs({ "RewardButtons", "SpellRewardButtons" }) do
                for _, button in ipairs(frame[key] or {}) do ns.SkinQuestReward(button) end
            end
        end
    end
    local i = 1
    while _G["QuestInfoItem" .. i] do
        ns.SkinQuestReward(_G["QuestInfoItem" .. i])
        i = i + 1
    end
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
-- The quest and gossip windows at their 1.x height. The client's are 496
-- tall with a text area of 403; the old ones held 334 of text, and at
-- the client's height the window stood a fifth too tall beside every
-- other old window. Sizes only, through the widget calls, set once: the
-- client gives these their size in its layout files and never again.
-- The buttons along the foot hang from the window's bottom edge and
-- come up with it; the parchment is shortened by as much.
local NPC_WINDOW_TRIM = 69
local function ShortenNpcWindow(frame, scrolls, panels, grounds)
    if not frame or frame.fcuiShort then return end
    local height = frame:GetHeight()
    -- Whatever height the client gives it, so long as it is the tall one.
    if not height or height < 470 then return end
    frame.fcuiShort = true
    frame:SetHeight(height - NPC_WINDOW_TRIM)
    local function Trim(region, atLeast)
        if type(region) == "string" then region = _G[region] end
        if not region or not region.GetHeight or not region.SetHeight then return end
        local tall = region:GetHeight()
        if tall and tall > atLeast then region:SetHeight(tall - NPC_WINDOW_TRIM) end
    end
    -- The parchment is sized by its art, and the client sets that art
    -- again when it themes the window, which puts the full height back:
    -- on the gossip window it hung out under the shortened frame. Held
    -- by its foot as well as its head it has no height of its own left
    -- to be given, and ends where the text area ends.
    local function Foot(ground)
        if not ground or not ground.SetPoint then return end
        local point, _, _, x = ground:GetPoint(1)
        if point ~= "TOPLEFT" then return end
        ground:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x or 7, 27)
    end
    for _, scroll in ipairs(scrolls or {}) do Trim(scroll, 200) end
    for _, panel in ipairs(panels or {}) do
        if type(panel) == "string" then panel = _G[panel] end
        Trim(panel, 400)
        if panel and panel.Bg then Foot(panel.Bg) end
    end
    for _, ground in ipairs(grounds or {}) do Foot(ground) end
end

local WINDOWS = {
    { "WorldMapFrame", child = "BorderFrame", portrait = false, backing = false, lift = MAP_LIFT, after = function(border)
        -- Blizzard swaps the map's border and portrait on every minimize
        -- and maximize; put ours back each time.
        -- Keep Blizzard's portrait header height (the map's canvas is laid
        -- out under it); only the portrait itself goes.
        local portrait = border.PortraitContainer and border.PortraitContainer.portrait
        if portrait then portrait:SetAlpha(0) end
        -- The close button sits inside the header, the size button beside it.
        local close = border.CloseButton
        local corner = border.NineSlice and border.NineSlice.TopRightCorner
        if close and corner then
            close:ClearAllPoints()
            close:SetPoint("TOPRIGHT", corner, "TOPRIGHT", 0.6, -11)
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
                    if active then C_Timer.After(0, function() ns.SkinWindow(border, { portrait = false, backing = false, lift = MAP_LIFT, after = WINDOW_AFTER[border] }) end) end
                end)
            end
        end
    end },
    { "MerchantFrame", lift = 5, after = function(frame)
        local function FadeFrame(f)
            if not f then return end
            for _, region in ipairs({ f:GetRegions() }) do
                if region:IsObjectType("Texture") then region:SetAlpha(0) end
            end
            for _, child in ipairs({ f:GetChildren() }) do FadeFrame(child) end
        end
        for _, region in ipairs({ frame:GetRegions() }) do
            if region:IsObjectType("Texture") then
                local ours = false
                for _, tex in pairs(frame.fcui or {}) do if tex == region then ours = true end end
                if not ours then region:SetAlpha(0) end
            end
        end
        FadeFrame(frame.Inset or _G["MerchantFrameInset"])
        FadeFrame(_G["MerchantExtraCurrencyInset"])
        FadeFrame(_G["MerchantExtraCurrencyBg"])
        FadeFrame(_G["MerchantMoneyInset"])
        -- The old bottom strip over the inset's foot: the stone with the
        -- repair slots on the left and its short right piece. Blizzard
        -- shows the left piece on the merchant tab and hides it for
        -- buyback; the right piece follows it.
        local left = _G["MerchantFrameBottomLeftBorder"]
        if left then
            ns.SetTex(left, "merchantBottom")
            left:SetTexCoord(0, 1, 0, 0.4765625)
            left:SetSize(256, 61)
            left:ClearAllPoints()
            left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 26)
            left:SetDrawLayer("OVERLAY", 0)
            left:SetAlpha(1)
            local right = ns.OwnTexture(frame, "bottomRight", "OVERLAY", 0)
            ns.SetTex(right, "merchantBottom")
            right:SetTexCoord(0, 0.296875, 0.4765625, 0.953125)
            right:SetSize(76, 61)
            right:ClearAllPoints()
            right:SetPoint("LEFT", left, "RIGHT", 0, 0)
            right:SetAlpha(1)
            if not frame.fcuiBottomHooked then
                frame.fcuiBottomHooked = true
                left:HookScript("OnShow", function() right:Show() end)
                left:HookScript("OnHide", function() right:Hide() end)
            end
            right:SetShown(left:IsShown())
        end
        -- The strip's divider stands at 165; the repair slots take the
        -- left box, the junk and buyback buttons the right one. Blizzard
        -- re-anchors the junk button with every repair update.
        local function PlaceBottomButtons()
            local junk = _G["MerchantSellAllJunkButton"]
            if junk then
                junk:ClearAllPoints()
                junk:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 176, 33)
            end
            local buyback, item10 = _G["MerchantBuyBackItem"], _G["MerchantItem10"]
            if buyback and item10 then
                buyback:ClearAllPoints()
                buyback:SetPoint("TOPLEFT", item10, "BOTTOMLEFT", 44, -53)
            end
        end
        PlaceBottomButtons()
        ns.HookGlobal("MerchantFrame_UpdateRepairButtons", PlaceBottomButtons)
        for i = 1, 12 do
            local slot = _G["MerchantItem" .. i .. "NameFrame"]
            if slot then
                ns.SetTex(slot, "merchantLabelSlots")
                slot:SetTexCoord(0, 1, 0, 1)
            end
        end
        local buyback = _G["MerchantBuyBackItemNameFrame"]
        if buyback then ns.SetTex(buyback, "merchantLabelSlots") end
    end },
    -- The send row and its buttons sit close to the frame's bottom edge:
    -- half the lift meets them without cutting through.
    { "MailFrame", lift = 5 },
    -- The social window's tabs meet its lowered border: the full lift
    -- pushed them up through it, none at all left them floating under it.
    { "FriendsFrame", lift = 5, tabLift = 3, after = function(frame)
        -- The 1.x social window was narrower than the client's; the lists
        -- inside are anchored to its edges and follow.
        if frame:GetWidth() and math.abs(frame:GetWidth() - 385) < 1 then frame:SetWidth(360) end
    end },
    -- The Goodbye, Accept and Decline buttons sit close to the frame's
    -- bottom edge, as the mail window's send row does: the same half lift.
    { "QuestFrame", lift = 5, backingRight = 5, after = function(frame)
        ShortenNpcWindow(frame, { "QuestDetailScrollFrame", "QuestProgressScrollFrame", "QuestRewardScrollFrame", "QuestGreetingScrollFrame" },
            { "QuestFrameDetailPanel", "QuestFrameProgressPanel", "QuestFrameRewardPanel", "QuestFrameGreetingPanel" })
        ns.SkinQuestRewards()
        ns.HookGlobal("QuestInfo_Display", ns.SkinQuestRewards)
        ns.HookGlobal("QuestInfo_ShowRewards", ns.SkinQuestRewards)
    end },
    { "GossipFrame", lift = 5, backingRight = 5, after = function(frame)
        local panel = frame.GreetingPanel
        ShortenNpcWindow(frame, { panel and panel.ScrollBox }, { panel }, { frame.Background })
    end },
    -- The trade window carries a second portrait for the other party in
    -- an overlay of its own, with the client's bronze corner piece behind
    -- it; that corner wears the same metal as the window's own.
    { "TradeFrame", lift = 5, after = function(frame)
        local overlay = frame.RecipientOverlay
        if not overlay or not overlay.portraitFrame then return end
        local ring = overlay.portraitFrame
        ns.SetTex(ring, METAL)
        ring:SetTexCoord(unpack(CORNERS.portrait.TopLeftCorner))
        ring:SetSize(CORNER, CORNER)
        local portrait = overlay.portrait
        if portrait then
            portrait:SetSize(61, 61)
            ring:ClearAllPoints()
            ring:SetPoint("TOPLEFT", portrait, "TOPLEFT", -7, 8)
        end
    end },
    { "TaxiFrame" },
    { "DressUpFrame" },
    { "PetStableFrame" },
    { "ItemTextFrame" },
    { "TabardFrame" },
    { "GuildRegistrarFrame" },
    { "PetitionFrame" },
    -- The guild control window: the client keeps its own permission
    -- logic, which greys what a rank may not change; only its art and
    -- its controls take the old look.
    { "GuildControlUI", addon = "Blizzard_GuildControlUI", portrait = false, after = function(frame)
        local function Dress(node, depth)
            if depth <= 0 or not node.GetChildren then return end
            for _, child in ipairs({ node:GetChildren() }) do
                local kind = child.GetObjectType and child:GetObjectType()
                if kind == "CheckButton" then
                    if ns.SkinCheckbox then ns.SkinCheckbox(child) end
                elseif kind == "Button" and child.Left and child.Middle and child.Right then
                    if ns.SkinRedButton then ns.SkinRedButton(child) end
                elseif child.Button and child.Text and child.Arrow then
                    if ns.SkinDropdown then ns.SkinDropdown(child) end
                end
                Dress(child, depth - 1)
            end
        end
        Dress(frame, 5)
        for _, region in ipairs({ frame:GetRegions() }) do
            if region:IsObjectType("FontString") and region.SetFontObject and ns.FONT_GOLD then
                region:SetFontObject(ns.FONT_GOLD)
            end
        end
    end },
    { "BankFrame", after = function(frame) if ns.SkinBank then ns.SkinBank(frame) end end },
    { "LootFrame", backing = false, after = SkinLoot },
    { "InspectFrame", addon = "Blizzard_InspectUI" },
    { "MacroFrame", addon = "Blizzard_MacroUI" },
    { "ClassTrainerFrame", addon = "Blizzard_TrainerUI" },
    -- The auction house's frame runs a few pixels past its own border on
    -- the right and below it; the backing stops at the border instead.
    { "AuctionHouseFrame", addon = "Blizzard_AuctionHouseUI", lift = 9, backingRight = 6, backingBottom = 8 },
    { "CommunitiesFrame", addon = "Blizzard_Communities" },
    { "CollectionsJournal", addon = "Blizzard_Collections", after = function(frame)
        local floor = frame.fcui and frame.fcui.insetFloor
        if floor then floor:SetVertexColor(0.45, 0.42, 0.38) end
    end },
    { "EncounterJournal", addon = "Blizzard_EncounterJournal" },
    { "AchievementFrame", addon = "Blizzard_AchievementUI" },
    { "ProfessionsFrame", addon = "Blizzard_Professions" },
    { "ProfessionsBookFrame", addon = "Blizzard_ProfessionsBook" },
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
            ns.SkinWindow(frame, { portrait = entry.portrait, backing = entry.backing, lift = entry.lift, tabLift = entry.tabLift, backingRight = entry.backingRight, backingBottom = entry.backingBottom, after = entry.after })
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
