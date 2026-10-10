local _, ns = ...

-- Per-window extras past the common chrome, by window name; Panels' WINDOWS
-- reads these at load.

local P = ns.panels
local A = P.after
local EMPTY = ns.EMPTY
local IsSecret = ns.IsSecret

-- Client frames by name, looked up until found, then cached.
local named = {}
local function Named(name)
    local frame = named[name]
    if frame == nil then
        frame = _G[name]
        named[name] = frame
    end
    return frame
end

---------------------------------------------------------------- dressing room

-- Race background: 256 art rows on top, 76 of the bottom files' 128 (the rest empty). Fitted to the scene together,
-- the bottom cut to its art; the client's fixed 348 + 175 ran past the small window's foot.
local DRESS_BG_TOP_ROWS, DRESS_BG_BOTTOM_ROWS, DRESS_BG_BOTTOM_FILE_ROWS = 256, 76, 128
local DRESS_BG_TOPS = { "BGTopLeft", "BGTopRight" }
local DRESS_BG_BOTTOMS = { "BGBottomLeft", "BGBottomRight" }
-- Dressing room title buttons: close from the top right corner, the size button's gap left of it.
local DRESS_CLOSE_BUTTON_X = -0.4
local DRESS_CLOSE_BUTTON_Y = -11
local DRESS_SIZE_BUTTON_GAP = 8

local function Fit(scene, keys, h, coordBottom)
    for _, key in ipairs(keys) do
        local tex = scene[key]
        if tex then
            tex:SetHeight(h)
            tex:SetTexCoord(0, 1, 0, coordBottom)
        end
    end
end

local function FitDressBackground(frame)
    local scene = frame.ModelScene
    local h = scene and ns.Safe(scene:GetHeight())
    local first, foot = scene and scene.BGTopLeft, scene and scene.BGBottomLeft
    if not (h and first and foot) then return end
    local k = h / (DRESS_BG_TOP_ROWS + DRESS_BG_BOTTOM_ROWS)
    local top, bottom = DRESS_BG_TOP_ROWS * k, DRESS_BG_BOTTOM_ROWS * k
    local footCoord = DRESS_BG_BOTTOM_ROWS / DRESS_BG_BOTTOM_FILE_ROWS
    -- Read back from the art: a new race's texture may bring its own coords.
    local _, _, _, footEnd = foot:GetTexCoord()
    if ns.Near(first:GetHeight(), top) and ns.Near(foot:GetHeight(), bottom) and ns.Near(footEnd, footCoord) then return end
    Fit(scene, DRESS_BG_TOPS, top, 1)
    Fit(scene, DRESS_BG_BOTTOMS, bottom, footCoord)
end

-- The client lays the title buttons again on each size swap: placed every pass, only when moved.
local function PlaceDressTitleButtons(frame)
    local close, sizer = frame.CloseButton, frame.MaximizeMinimizeFrame
    local corner = frame.NineSlice and frame.NineSlice.TopRightCorner
    if close and corner then
        ns.SetPointIf(close, "TOPRIGHT", corner, "TOPRIGHT", DRESS_CLOSE_BUTTON_X, DRESS_CLOSE_BUTTON_Y)
    end
    if sizer and close then ns.SetPointIf(sizer, "RIGHT", close, "LEFT", DRESS_SIZE_BUTTON_GAP, 0) end
end

-- Footer 2 up off the lifted bottom edge: Close (Reset hangs from it) and Link.
function A.DressUpFrame(frame)
    local close, link = Named("DressUpFrameCancelButton"), frame.LinkButton
    if close then ns.SetPointIf(close, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -7, 6) end
    if link then ns.SetPointIf(link, "BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 6) end
    -- The size button in the classic look and size the map's has.
    if frame.MaximizeMinimizeFrame then P.MaxMinBeside(frame.MaximizeMinimizeFrame, frame.CloseButton, DRESS_SIZE_BUTTON_GAP) end
    -- The small and full size swap the scene's height and the title buttons while the window shows.
    ns.Sched.Attach(frame, { name = "dressup.background", every = 0, fn = function()
        FitDressBackground(frame)
        PlaceDressTitleButtons(frame)
    end })
end

---------------------------------------------------------------- world map

local MAP_METHODS = { "Minimize", "Maximize" }

function A.WorldMapFrame(border)
    -- Header keeps its height (the canvas is laid out under it); only the portrait goes.
    local portrait = border.PortraitContainer and border.PortraitContainer.portrait
    if portrait then portrait:SetAlpha(0) end
    -- Close button inside the header, the size button beside it.
    local close = border.CloseButton
    local corner = border.NineSlice and border.NineSlice.TopRightCorner
    if close and corner then P.PlaceInSocket(close, border) end
    local sizer = border.MaximizeMinimizeFrame
    if sizer and sizer.MaximizeButton then P.MaxMinBeside(sizer, close, 8) end
    -- The client swaps border and portrait on minimise/maximise: re-skin next
    -- frame, outside the client's pass.
    if WorldMapFrame and ns.Once(border, "mapHooked") then
        local opts = { portrait = false, backing = false, lift = P.MAP_LIFT, left = P.MAP_LEFT, after = P.windowAfter[border] }
        local function Reskin() ns.SkinWindow(border, opts) end
        local function Resized() if P.active and ns.db.worldMap ~= false then ns.Sched.NextFrame("map.reskin", Reskin) end end
        for _, method in ipairs(MAP_METHODS) do ns.HookMethod(WorldMapFrame, method, Resized) end
    end
end

----------------------------------------------------------------- merchant

local BOTTOM_LEFT = { coords = { 0, 1, 0, 0.4765625 }, w = 256, h = 61, point = "BOTTOMLEFT", x = 1, y = 26, layer = "OVERLAY", sublevel = 0, alpha = 1 }
local BOTTOM_RIGHT = { own = "bottomRight", layer = "OVERLAY", sublevel = 0, coords = { 0, 0.296875, 0.4765625, 0.953125 },
    w = 76, h = 61, point = "LEFT", relPoint = "RIGHT", alpha = 1 }
local MERCHANT_SLOT = { coords = { 0, 1, 0, 1 } }
local OWN_ONLY = { own = true }
-- Buyback slot's x from item10's left, clear of the junk button (client 30).
local BUYBACK_X = 44
-- Buyback name's left from the slot's: client 64 wide slot art at -13, name anchored 5 back into it.
local BUYBACK_NAME_X = -13 + 64 - 5

-- Every texture down the tree.
local function FadeTree(frame)
    if not frame then return end
    ns.FadeTextures(frame)
    ns.EachChild(frame, FadeTree)
end

function A.MerchantFrame(frame)
    ns.FadeTextures(frame, 0, OWN_ONLY)
    ns.EraTabRow({ _G["MerchantFrameTab1"], _G["MerchantFrameTab2"] })
    -- Era's inset border round the goods, as the Raid tab's; its fill stays faded over our floor.
    local inset = frame.Inset or _G["MerchantFrameInset"]
    if inset then
        ns.FadeTextures(inset)
        ns.ShowInsetBorder(inset.NineSlice, true)
    end
    FadeTree(_G["MerchantExtraCurrencyInset"])
    FadeTree(_G["MerchantExtraCurrencyBg"])
    -- Era's dark money box: the inset's own fill, its border as the goods'.
    local money = _G["MerchantMoneyInset"]
    if money then ns.ShowInsetBorder(money.NineSlice, true) end
    -- Old stone strip at the inset's foot, repair slots left. The client shows the
    -- left piece only on the merchant tab; our right piece follows it.
    local left = _G["MerchantFrameBottomLeftBorder"]
    if left then
        ns.Dress(left, "merchantBottom", BOTTOM_LEFT, frame)
        local right = ns.DressNew(frame, "merchantBottom", BOTTOM_RIGHT, left)
        if ns.Once(frame, "bottomHooked") then
            left:HookScript("OnShow", function() right:Show() end)
            left:HookScript("OnHide", function() right:Hide() end)
        end
        right:SetShown(left:IsShown())
    end
    -- Divider at x 165: repair slots left, junk and buyback right. The client
    -- re-anchors junk on every repair update.
    local function PlaceBottomButtons()
        ns.SetPointOnce(_G["MerchantSellAllJunkButton"], "BOTTOMLEFT", frame, "BOTTOMLEFT", 176, 33)
        local buyback, item10 = _G["MerchantBuyBackItem"], _G["MerchantItem10"]
        if buyback and item10 then ns.SetPointOnce(buyback, "TOPLEFT", item10, "BOTTOMLEFT", BUYBACK_X, -53) end
    end
    PlaceBottomButtons()
    ns.HookGlobal("MerchantFrame_UpdateRepairButtons", PlaceBottomButtons)
    for i = 1, 12 do ns.Dress(_G["MerchantItem" .. i .. "NameFrame"], "merchantLabelSlots", MERCHANT_SLOT) end
    local buyback = _G["MerchantBuyBackItemNameFrame"]
    if buyback then ns.SetTex(buyback, "merchantLabelSlots") end
    -- Buyback name: one line cut with "...", ending 3 inside the right column's edge (the stone field's).
    local name, item10 = _G["MerchantBuyBackItemName"], _G["MerchantItem10"]
    if name and item10 then
        name:SetWordWrap(false)
        name:SetMaxLines(1)
        name:SetWidth(item10:GetWidth() - BUYBACK_X - BUYBACK_NAME_X - 3)
    end
end

-------------------------------------------------------------------- trade

local TRADE_PAIRS = {
    { "TradeRecipientItemsInset", "TradePlayerItemsInset" },
    { "TradeRecipientEnchantInset", "TradePlayerEnchantInset" },
}

-- Every frame (cheap): the client re-sets the other side as details arrive, and
-- a slower watch let its light wash show first.
local function HoldRecipientShade()
    -- The client's plain light fill over that whole side.
    local wash = Named("TradeRecipientBG")
    if wash then ns.SetAlphaIf(wash, 0) end
    for i = 1, #TRADE_PAIRS do
        local pair = TRADE_PAIRS[i]
        local theirs, ours = Named(pair[1]), Named(pair[2])
        local want = ours and ours.Bg and ours.Bg:GetAlpha() or 1
        if theirs and theirs.Bg then ns.SetAlphaIf(theirs.Bg, want, 0.01) end
    end
end

-- The other party's portrait sits in its own overlay; its corner gets our metal.
function A.TradeFrame(frame)
    -- Client draws their panels at 0.1 alpha over our stone: hold the player's shade.
    ns.Sched.Attach(frame, { name = "trade.shade", every = 0, fn = HoldRecipientShade })
    local overlay = frame.RecipientOverlay
    if not overlay or not overlay.portraitFrame then return end
    local ring = overlay.portraitFrame
    P.PortraitRing(ring)
    local portrait = overlay.portrait
    if portrait then
        portrait:SetSize(61, 61)
        -- 9, not 8: a pixel lower, the ring's top bar split the trader's name.
        ns.SetPointOnce(ring, "TOPLEFT", portrait, "TOPLEFT", -7, 9)
    end
end

----------------------------------------------------------------- guild charter

-- Escape in the guild name box: the client only moves focus to chat, so the window never closed from it.
function A.GuildRegistrarFrame(frame)
    local box = _G["GuildRegistrarFrameEditBox"]
    if box and ns.Once(box, "escapeCloses") then
        box:HookScript("OnEscapePressed", function(self)
            self:ClearFocus()
            ns.HidePanel(frame)
        end)
    end
end

---------------------------------------------------------------- item text

-- Book, plaque or letter: scroll column only while the page overflows (1.x), on
-- a dark floor of its own (the column art is hollow).
function A.ItemTextFrame(frame)
    local scroll = ItemTextScrollFrame
    local bar = scroll and scroll.ScrollBar
    if not bar or not bar.Track then return end
    ns.SkinMinimalScrollBar(bar)
    ns.ScrollTrackArt(bar)
    local art = bar.fcui
    if art and art.trackTop and art.trackBottom and not art.trackFloor then
        local floor = ns.OwnTexture(bar, "trackFloor", "BACKGROUND", -1)
        floor:SetColorTexture(0.04, 0.04, 0.04, 1)
        floor:ClearAllPoints()
        floor:SetPoint("TOPLEFT", art.trackTop, "TOPLEFT", 5, -4)
        floor:SetPoint("BOTTOMRIGHT", art.trackBottom, "BOTTOMRIGHT", -5, 4)
        floor:Show()
    end
    local function Sync()
        local can = true
        if bar.HasScrollableExtent then
            local ok, result = pcall(bar.HasScrollableExtent, bar)
            if ok then can = result and true or false end
        end
        local alpha = can and 1 or 0
        ns.SetAlphaIf(bar, alpha, 0.01)
    end
    local job, made = ns.Sched.Attach(frame, { name = "itemText.bar", every = 0.05, fn = Sync })
    if not made then return end
    job.host:SetScript("OnShow", Sync)
    Sync()
end

------------------------------------------------------------ guild control

-- Client keeps its permission logic (greys what a rank can't change); art only.
local DressControls
local function DressControl(child, depth)
    local kind = child.GetObjectType and child:GetObjectType()
    if kind == "CheckButton" then
        ns.SkinCheckbox(child)
    elseif kind == "Button" and child.Left and child.Middle and child.Right then
        ns.SkinRedButton(child)
    elseif child.Button and child.Text and child.Arrow then
        ns.SkinDropdown(child)
    end
    DressControls(child, depth - 1)
end
DressControls = function(node, depth)
    if depth <= 0 or not node.GetChildren then return end
    ns.EachChild(node, DressControl, depth)
end

local function GoldWords(region)
    if region:IsObjectType("FontString") and region.SetFontObject and ns.FONT_GOLD then
        region:SetFontObject(ns.FONT_GOLD)
    end
end

function A.GuildControlUI(frame)
    DressControls(frame, 5)
    ns.EachRegion(frame, GoldWords)
end

------------------------------------------------------------------ inspect

-- Every frame: side tabs stay hidden; the old foot tabs show only while there is
-- a guild tab (none for a lone player).
local function HoldInspectTabs(side)
    ns.SetAlphaIf(side, 0)
    for _, tab in ipairs(side.Tabs or EMPTY) do
        if tab:IsMouseEnabled() then tab:EnableMouse(false) end
    end
    local guild = side.GuildTab and side.GuildTab:IsShown() and true or false
    local first, second = Named("InspectFrameTab1"), Named("InspectFrameTab2")
    if first then ns.SetShownIf(first, guild) end
    if second then ns.SetShownIf(second, guild) end
end

function A.InspectFrame(frame)
    -- No bronze slot surround (as on the player's sheet); the bronze theme adds a thin rim.
    for _, name in ipairs(INSPECTPAPERDOLLFRAME_SLOTS or EMPTY) do
        local slot = _G[name]
        if slot and slot.BorderFrame then slot.BorderFrame:SetAlpha(0) end
        if slot then ns.BronzeRim(slot, nil, 3) end
    end
    local side = frame.ModeTabs
    if side then ns.Sched.Attach(frame, { name = "inspect.tabs", every = 0, fn = function() HoldInspectTabs(side) end }) end
end

-------------------------------------------------------------------- macro

local function SwapBarPiece(region, barFile)
    if region.IsObjectType and region:IsObjectType("Texture") and region:GetTexture() == barFile then
        ns.SetFile(region, "Interface\\ClassTrainerFrame\\UI-ClassTrainer-HorizontalBar")
    end
end

-- Era's tabs, silver text box, the foot row in an iron box (as professions),
-- bottom border low under it.
function A.MacroFrame(frame)
    local first, second = _G["MacroFrameTab1"], _G["MacroFrameTab2"]
    if first and second then
        -- Era's spots (its Blizzard_MacroUI.xml); the character tab's label gives up 15 and stops at 130.
        ns.SetPointOnce(first, "TOPLEFT", frame, "TOPLEFT", 51, -28)
        ns.SetPointOnce(second, "LEFT", first, "RIGHT", 0, 0)
        ns.SkinTopTab(second, -15, 130)
    end
    -- Slots 5 left; their bar 5 right and 8 taller at the top (it hung free of the
    -- border). The bar hangs from the slots' frame, so it offsets that 5 plus 5.
    local selector = frame.MacroSelector
    if selector then
        ns.SetPointOnce(selector, "TOPLEFT", frame, "TOPLEFT", 7, -63)
        local bar = selector.ScrollBar
        if bar then
            bar:ClearAllPoints()
            bar:SetPoint("TOPRIGHT", selector, "TOPRIGHT", -4, 0)
            bar:SetPoint("BOTTOMRIGHT", selector, "BOTTOMRIGHT", -4, 2)
        end
    end
    -- Text box border is bronze on this client: drain to silver, keep the dark middle.
    local box = _G["MacroFrameTextBackground"]
    local slice = box and box.NineSlice
    if slice then ns.DrainSlice(slice, ns.INPUT_GREY) end
    -- Trainer's bar between slots and macro; the unnamed right piece is found by
    -- the left's file.
    local barLeft = _G["MacroHorizontalBarLeft"]
    local barFile = barLeft and barLeft:GetTexture()
    if barFile then ns.EachRegion(frame, SwapBarPiece, barFile) end
    -- Slot inset and slot frames are silver: bronze with the theme.
    local slotBox = frame.Inset or _G["MacroFrameInset"]
    if slotBox then ns.TintSlice(slotBox.NineSlice) end
    ns.TintSelectorSlots(selector and selector.ScrollBox, frame, "macro.slots")
    -- Delete, New and Exit in an iron box along the foot.
    if ns.SkillInsetBox and not frame.fcuiFoot then
        local foot = ns.SkillInsetBox(frame, 20, true)
        foot:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -1, 34)
        foot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, 0)
        foot:SetFrameLevel(frame:GetFrameLevel())
        frame.fcuiFoot = foot
    end
end

------------------------------------------------------------ chat channels

-- Pane marble off so our floor shows, shaded as the social window's list; thin borders
-- stay (they split the lists) and go bronze with the theme.
local function DressChannelPane(pane)
    if not pane then return end
    if pane.Bg and pane.Bg.SetAlpha then pane.Bg:SetAlpha(0) end
    ns.TintSlice(pane.NineSlice)
end

function A.ChannelFrame(frame)
    P.ShadeFloor(frame)
    DressChannelPane(frame.LeftInset)
    DressChannelPane(frame.RightInset)
    ns.QuietScrollBar(frame.ChannelList and frame.ChannelList.ScrollBar, "channels.listKnob", true)
    ns.QuietScrollBar(frame.ChannelRoster and frame.ChannelRoster.ScrollBar, "channels.rosterKnob", true)
end

------------------------------------------------------------- communities

local COMMUNITY_TABS = { "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab", "GuildPreferredPlaySettingsTab" }
local FINDERS = { "GuildFinderFrame", "CommunityFinderFrame" }
local FINDER_TABS = { "ClubFinderSearchTab", "ClubFinderPendingTab" }

-- Side tab plate (its only BORDER texture): the old skill tab, bronze copy with the theme.
local function PlateTab(region)
    if not region:IsObjectType("Texture") then return end
    local layer, sub = region:GetDrawLayer()
    if not ns.AnySecret(layer, sub) and layer == "BORDER" then ns.SetTex(region, "sbSkillTab") end
end

local function PlateTabs(owner, keys)
    for _, key in ipairs(keys) do
        local tab = owner and owner[key]
        if tab then ns.EachRegion(tab, PlateTab) end
    end
end

-- Thin inner borders bronze with the theme (as channels); the note bridge's member frame is its own.
local TintInner
local function TintInnerChild(child, depth, skip)
    if child ~= skip then TintInner(child, depth - 1, skip) end
end
TintInner = function(frame, depth, skip)
    if depth <= 0 then return end
    ns.FadeAtlas(frame, "ui-frame-inner", false, ns.BronzeTint)
    ns.EachChild(frame, TintInnerChild, depth, skip)
end

-- The client re-lays its bronze border on each open and size toggle: ours again the frame after.
local function WatchBorder(frame, sizer)
    local edge = frame.NineSlice and frame.NineSlice.TopEdge
    if not edge then return end
    local fresh, plain, ours = true, nil, nil
    local job, made = ns.Sched.Attach(frame, { name = "communities.border", every = 0, fn = function()
        if not P.active then return end
        local mini = sizer and sizer:IsMinimized() and true or false
        local now = edge:GetTexture()
        local relaid = ours ~= nil and not IsSecret(now) and now ~= ours
        if not fresh and mini == plain and not relaid then return end
        if P.Reborder(frame, mini) then
            fresh, plain = false, mini
            now = edge:GetTexture()
            ours = not IsSecret(now) and now or nil
        end
    end })
    if made then job.host:SetScript("OnShow", function() fresh = true end) end
end

function A.CommunitiesFrame(frame)
    -- Size button beside the X, as on the map.
    local sizer = frame.MaximizeMinimizeFrame
    if sizer and sizer.MaximizeButton then P.MaxMinBeside(sizer, frame.CloseButton, 8.5) end
    WatchBorder(frame, sizer)
    PlateTabs(frame, COMMUNITY_TABS)
    for _, key in ipairs(FINDERS) do PlateTabs(frame[key], FINDER_TABS) end
    TintInner(frame, 6, frame.GuildMemberDetailFrame)
end

----------------------------------------------------------- spells window

local TALENT_BUTTONS = { "ApplyButton", "InspectCopyButton" }
local FOOT_STONE = { coords = { 0, 1, 0, 1 } }

-- The Activate buttons come from a pool filled as the tab first shows.
local function DressSpecButtons()
    local window = Named("PlayerSpellsFrame")
    local pool = window and window.SpecFrame and window.SpecFrame.SpecContentFramePool
    if not pool or not P.active then return end
    for content in pool:EnumerateActive() do ns.SkinRedButton(content.ActivateButton) end
end

local function SpecShown(shown)
    if shown then ns.Sched.NextFrame("spells.spec", DressSpecButtons) end
end

-- Our spellbook on: the dressed window's own Spellbook tab, last in its row, goes unseen. Alpha and mouse only; the
-- row's layout stays the client's.
function ns.GameBookTab()
    local window = Named("PlayerSpellsFrame")
    if not window or not P.skinned[window] then return end
    local tab = window.spellBookTabID and window:GetTabButton(window.spellBookTabID)
    if not tab then return end
    local ours = ns.SpellBookActive()
    ns.SetAlphaIf(tab, ours and 0 or 1)
    tab:EnableMouse(not ours)
end

-- Retail's talents stay the game's window: old buttons, drop down and search box, stone under the foot row.
function A.PlayerSpellsFrame(frame)
    local talents = frame.TalentsFrame
    if talents then
        ns.EachKey(talents, TALENT_BUTTONS, ns.SkinRedButton)
        ns.SkinDropdown(talents.LoadSystem and talents.LoadSystem.Dropdown)
        ns.DrainInput(talents.SearchBox)
        local bar = talents.BottomBar
        if bar then
            local stone = ns.TileTex(ns.OwnTexture(talents, "footStone", "BACKGROUND", 1), "rockBg", FOOT_STONE)
            stone:SetAllPoints(bar)
            stone:Show()
            bar:SetAlpha(0)
        end
    end
    ns.Sched.OnVisible(frame.SpecFrame, "spells.spec", SpecShown)
    -- After the skin marks the window dressed.
    ns.Sched.NextFrame("spells.bookTab", ns.GameBookTab)
end

------------------------------------------------------------- collections

function A.CollectionsJournal(frame)
    local floor = frame.fcui and frame.fcui.insetFloor
    if floor then floor:SetVertexColor(0.45, 0.42, 0.38) end
end

------------------------------------------------------------------ addons

local ADDON_BUTTONS = { "EnableAllButton", "DisableAllButton", "OkayButton", "CancelButton" }

local function DressAddonRow(row)
    if row.Enabled then ns.SkinCheckbox(row.Enabled) end
    if row.LoadAddonButton then ns.SkinRedButton(row.LoadAddonButton) end
end

-- Old controls over the bronze ones; rows are pooled on scroll, so poll while the list is up.
function A.AddonList(frame)
    P.ShadeFloor(frame)
    ns.SkinDropdown(frame.Dropdown)
    ns.SkinCheckbox(frame.ForceLoad)
    ns.DrainInput(frame.SearchBox)
    if frame.Performance and frame.Performance.Divider then ns.DrainBronze(frame.Performance.Divider) end
    ns.EachKey(frame, ADDON_BUTTONS, ns.SkinRedButton)
    ns.QuietScrollBar(frame.ScrollBar, "addons.knob", true)
    local scroll = frame.ScrollBox
    if scroll and scroll.EnumerateFrames then
        ns.Sched.Attach(frame, { name = "addons.rows", every = 0.05, fn = function()
            if not P.active then return end
            for _, row in scroll:EnumerateFrames() do DressAddonRow(row) end
        end })
    end
end

------------------------------------------------------------------ support

-- Browser's thin inset border as drawn, bronze with the theme; the cheat report in the old dialog box.
function A.HelpFrame(frame)
    local inset = frame.Browser and frame.Browser.BrowserInset
    local slice = inset and inset.NineSlice
    ns.TintSlice(slice)
    local report = _G.ReportCheatingDialog
    if report then
        ns.OldDialogBorder(report.Border, true)
        ns.SkinRedButton(report.reportButton)
        ns.SkinRedButton(_G.ReportCheatingDialogCancelButton)
    end
end

------------------------------------------------------------------- legacy

-- Its emblem stood over the top left corner, under the metal: hidden beside the plain corner.
function A.LegacySystemFrame(frame)
    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    if portrait then portrait:SetAlpha(0) end
end

------------------------------------------------------------- time manager

local TIME_CHECKS = { "TimeManagerAlarmEnabledButton", "TimeManagerMilitaryTimeCheck", "TimeManagerLocalTimeCheck" }
local TIME_DROPDOWNS = { "HourDropdown", "MinuteDropdown", "AMPMDropdown" }

function A.TimeManagerFrame(frame)
    for _, name in ipairs(TIME_CHECKS) do ns.SkinCheckbox(_G[name]) end
    ns.EachKey(frame.AlarmTimeFrame, TIME_DROPDOWNS, ns.SkinDropdown)
    ns.DrainInput(_G.TimeManagerAlarmMessageEditBox)
end

------------------------------------------------------------ click binding

local CLICK_BUTTONS = { "SaveButton", "AddBindingButton", "ResetButton" }
local CLICK_TUTORIAL = { portrait = false, scrollBars = false }

function A.ClickBindingFrame(frame)
    ns.EachKey(frame, CLICK_BUTTONS, ns.SkinRedButton)
    ns.SkinCheckbox(frame.EnableMouseoverCastCheckbox)
    ns.SkinDropdown(frame.MouseoverCastKeyDropdown)
    ns.QuietScrollBar(frame.ScrollBar, "clickBinding.knob", true)
    -- The first-open tutorial is a window of its own over the list.
    if frame.TutorialFrame then ns.SkinWindow(frame.TutorialFrame, CLICK_TUTORIAL) end
end

-------------------------------------------------------- cooldown settings

function A.CooldownViewerSettings(frame)
    -- The client's panel art covered the inset's marble.
    if frame.Background then frame.Background:SetAlpha(0) end
    ns.DrainInput(frame.SearchBox)
    ns.SkinDropdown(frame.LayoutDropdown)
    ns.SkinRedButton(frame.UndoButton)
    ns.QuietScrollBar(frame.CooldownScroll and frame.CooldownScroll.ScrollBar, "cooldownSettings.knob", true)
end
