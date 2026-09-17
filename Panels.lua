local _, ns = ...

-- The old window chrome on Blizzard's panel frames: the metal nine-slice
-- border with the round portrait, the small X close button, the stone
-- title strip, and the character-sheet style tabs along the bottom.
-- Frames are reskinned in place when they exist; load-on-demand windows
-- are skinned when their Blizzard addon loads.

local CORNER, EDGE = 132, 128
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

-- Windows and the Blizzard addon that brings each one.
local WINDOWS = {
    { "WorldMapFrame", child = "BorderFrame", portrait = false, after = function(border)
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
            close:SetPoint("TOPRIGHT", border, "TOPRIGHT", 5, 4)
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
                    if active then C_Timer.After(0, function() ns.SkinWindow(border, { portrait = false, after = WINDOW_AFTER[border] }) end) end
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
    { "LootFrame", portrait = false },
    { "InspectFrame", addon = "Blizzard_InspectUI" },
    { "MacroFrame", addon = "Blizzard_MacroUI" },
    { "ClassTrainerFrame", addon = "Blizzard_TrainerUI" },
    { "AuctionHouseFrame", addon = "Blizzard_AuctionHouseUI" },
    { "CommunitiesFrame", addon = "Blizzard_Communities" },
    { "CollectionsJournal", addon = "Blizzard_Collections" },
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
            ns.SkinWindow(frame, { portrait = entry.portrait, after = entry.after })
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
