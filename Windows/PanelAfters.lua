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

---------------------------------------------------------------- world map

local MAP_METHODS = { "Minimize", "Maximize" }

function A.WorldMapFrame(border)
    -- Header keeps its height (the canvas is laid out under it); only the portrait goes.
    local portrait = border.PortraitContainer and border.PortraitContainer.portrait
    if portrait then portrait:SetAlpha(0) end
    -- Close button inside the header, the size button beside it.
    local close = border.CloseButton
    local corner = border.NineSlice and border.NineSlice.TopRightCorner
    if close and corner then
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", corner, "TOPRIGHT", 0.6, -11)
    end
    local sizer = border.MaximizeMinimizeFrame
    if sizer and sizer.MaximizeButton then
        P.SkinMaxMin(sizer)
        sizer:SetSize(32, 32)
        if close then
            sizer:ClearAllPoints()
            sizer:SetPoint("RIGHT", close, "LEFT", 8, 0)
        end
    end
    -- The client swaps border and portrait on minimise/maximise: re-skin next
    -- frame, outside the client's pass.
    if not border.fcuiMapHooked and WorldMapFrame then
        border.fcuiMapHooked = true
        local opts = { portrait = false, backing = false, lift = P.MAP_LIFT, after = P.windowAfter[border] }
        local function Reskin() ns.SkinWindow(border, opts) end
        local function Resized() if P.active then C_Timer.After(0, Reskin) end end
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
    FadeTree(frame.Inset or _G["MerchantFrameInset"])
    FadeTree(_G["MerchantExtraCurrencyInset"])
    FadeTree(_G["MerchantExtraCurrencyBg"])
    FadeTree(_G["MerchantMoneyInset"])
    -- Old stone strip at the inset's foot, repair slots left. The client shows the
    -- left piece only on the merchant tab; our right piece follows it.
    local left = _G["MerchantFrameBottomLeftBorder"]
    if left then
        ns.Dress(left, "merchantBottom", BOTTOM_LEFT, frame)
        local right = ns.DressNew(frame, "merchantBottom", BOTTOM_RIGHT, left)
        if not frame.fcuiBottomHooked then
            frame.fcuiBottomHooked = true
            left:HookScript("OnShow", function() right:Show() end)
            left:HookScript("OnHide", function() right:Hide() end)
        end
        right:SetShown(left:IsShown())
    end
    -- Divider at x 165: repair slots left, junk and buyback right. The client
    -- re-anchors junk on every repair update.
    local function PlaceBottomButtons()
        local junk = _G["MerchantSellAllJunkButton"]
        if junk then
            junk:ClearAllPoints()
            junk:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 176, 33)
        end
        local buyback, item10 = _G["MerchantBuyBackItem"], _G["MerchantItem10"]
        if buyback and item10 then
            buyback:ClearAllPoints()
            buyback:SetPoint("TOPLEFT", item10, "BOTTOMLEFT", BUYBACK_X, -53)
        end
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
    if wash and wash:GetAlpha() > 0 then wash:SetAlpha(0) end
    for i = 1, #TRADE_PAIRS do
        local pair = TRADE_PAIRS[i]
        local theirs, ours = Named(pair[1]), Named(pair[2])
        local want = ours and ours.Bg and ours.Bg:GetAlpha() or 1
        if theirs and theirs.Bg and math.abs(theirs.Bg:GetAlpha() - want) > 0.01 then theirs.Bg:SetAlpha(want) end
    end
end

-- The other party's portrait sits in its own overlay; its corner gets our metal.
function A.TradeFrame(frame)
    -- Client draws their panels at 0.1 alpha over our stone: hold the player's shade.
    if not frame.fcuiRecipientShade then
        local shade = CreateFrame("Frame", nil, frame)
        frame.fcuiRecipientShade = shade
        ns.Sched.OnFrame(shade, { name = "trade.shade", every = 0, fn = HoldRecipientShade })
    end
    local overlay = frame.RecipientOverlay
    if not overlay or not overlay.portraitFrame then return end
    local ring = overlay.portraitFrame
    P.PortraitRing(ring)
    local portrait = overlay.portrait
    if portrait then
        portrait:SetSize(61, 61)
        ring:ClearAllPoints()
        -- 9, not 8: a pixel lower, the ring's top bar split the trader's name.
        ring:SetPoint("TOPLEFT", portrait, "TOPLEFT", -7, 9)
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
    if frame.fcuiBarWatch then return end
    local watch = CreateFrame("Frame", nil, frame)
    frame.fcuiBarWatch = watch
    local function Sync()
        local can = true
        if bar.HasScrollableExtent then
            local ok, result = pcall(bar.HasScrollableExtent, bar)
            if ok then can = result and true or false end
        end
        local alpha = can and 1 or 0
        if math.abs((bar:GetAlpha() or 1) - alpha) > 0.01 then bar:SetAlpha(alpha) end
    end
    ns.Sched.OnFrame(watch, { name = "itemText.bar", every = 0.05, fn = Sync })
    watch:SetScript("OnShow", Sync)
    Sync()
end

------------------------------------------------------------ guild control

-- Client keeps its permission logic (greys what a rank can't change); art only.
local DressControls
local function DressControl(child, depth)
    local kind = child.GetObjectType and child:GetObjectType()
    if kind == "CheckButton" then
        if ns.SkinCheckbox then ns.SkinCheckbox(child) end
    elseif kind == "Button" and child.Left and child.Middle and child.Right then
        if ns.SkinRedButton then ns.SkinRedButton(child) end
    elseif child.Button and child.Text and child.Arrow then
        if ns.SkinDropdown then ns.SkinDropdown(child) end
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

------------------------------------------------------------- group finder

-- Both pages share one bare parent, which owns the close button.
function A.LFGListingFrame(frame)
    local close = _G["LFGParentFrameCloseButton"]
    if close then
        ns.SkinCloseButton(close, true)
        -- In the corner socket; either page's corner works.
        P.PlaceInSocket(close, frame)
        close:SetFrameLevel(frame:GetFrameLevel() + 20)
    end
end

------------------------------------------------------------------ inspect

-- Every frame: side tabs stay hidden; the old foot tabs show only while there is
-- a guild tab (none for a lone player).
local function HoldInspectTabs(side)
    if side:GetAlpha() > 0 then side:SetAlpha(0) end
    for _, tab in ipairs(side.Tabs or EMPTY) do
        if tab:IsMouseEnabled() then tab:EnableMouse(false) end
    end
    local guild = side.GuildTab and side.GuildTab:IsShown() and true or false
    local first, second = Named("InspectFrameTab1"), Named("InspectFrameTab2")
    if first and first:IsShown() ~= guild then first:SetShown(guild) end
    if second and second:IsShown() ~= guild then second:SetShown(guild) end
end

function A.InspectFrame(frame)
    -- No bronze slot surround (as on the player's sheet); the bronze theme adds a thin rim.
    for _, name in ipairs(INSPECTPAPERDOLLFRAME_SLOTS or EMPTY) do
        local slot = _G[name]
        if slot and slot.BorderFrame then slot.BorderFrame:SetAlpha(0) end
        if slot then ns.BronzeRim(slot, nil, 3) end
    end
    local side = frame.ModeTabs
    if side and not frame.fcuiTabWatch then
        local watch = CreateFrame("Frame", nil, frame)
        frame.fcuiTabWatch = watch
        ns.Sched.OnFrame(watch, { name = "inspect.tabs", every = 0, fn = function() HoldInspectTabs(side) end })
    end
end

-------------------------------------------------------------------- macro

local function DrainTextBox(region, center)
    if region ~= center then ns.DrainBronze(region, 0.85) end
end

local function SwapBarPiece(region, barFile)
    if region.IsObjectType and region:IsObjectType("Texture") and region:GetTexture() == barFile then
        ns.SetFile(region, "Interface\\ClassTrainerFrame\\UI-ClassTrainer-HorizontalBar")
    end
end

local function TintInset(region, center)
    if region ~= center and region.IsObjectType and region:IsObjectType("Texture") then ns.BronzeTint(region) end
end

-- Tabs on the list, silver text box, the foot row in an iron box (as professions),
-- bottom border low under it.
function A.MacroFrame(frame)
    local first, second = _G["MacroFrameTab1"], _G["MacroFrameTab2"]
    local inset = frame.Inset or _G["MacroFrameInset"]
    if first and inset then
        first:ClearAllPoints()
        first:SetPoint("BOTTOMLEFT", inset, "TOPLEFT", 50, -2)
        if second then
            second:ClearAllPoints()
            -- 10 in from the client's spot, against the first.
            second:SetPoint("BOTTOMLEFT", first, "BOTTOMRIGHT", -8, 0)
        end
    end
    -- Slots 5 left; their bar 5 right and 8 taller at the top (it hung free of the
    -- border). The bar hangs from the slots' frame, so it offsets that 5 plus 5.
    local selector = frame.MacroSelector
    if selector then
        selector:ClearAllPoints()
        selector:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -63)
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
    if slice then ns.EachRegion(slice, DrainTextBox, slice.Center) end
    -- Trainer's bar between slots and macro; the unnamed right piece is found by
    -- the left's file.
    local barLeft = _G["MacroHorizontalBarLeft"]
    local barFile = barLeft and barLeft:GetTexture()
    if barFile then ns.EachRegion(frame, SwapBarPiece, barFile) end
    -- Slot inset and slot frames are silver: bronze with the theme.
    local slotBox = frame.Inset or _G["MacroFrameInset"]
    if slotBox and slotBox.NineSlice then ns.EachRegion(slotBox.NineSlice, TintInset, slotBox.NineSlice.Center) end
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
    local slice = pane.NineSlice
    if slice then ns.EachRegion(slice, TintInset, slice.Center) end
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
    if region:IsObjectType("Texture") and region:GetDrawLayer() == "BORDER" then ns.SetTex(region, "sbSkillTab") end
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
    if not edge or frame.fcuiBorderWatch then return end
    local watch = CreateFrame("Frame", nil, frame)
    frame.fcuiBorderWatch = watch
    local fresh, plain, ours = true, nil, nil
    watch:SetScript("OnShow", function() fresh = true end)
    ns.Sched.OnFrame(watch, { name = "communities.border", every = 0, fn = function()
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
end

function A.CommunitiesFrame(frame)
    -- Size button beside the X, as on the map.
    local sizer = frame.MaximizeMinimizeFrame
    if sizer and sizer.MaximizeButton then
        P.SkinMaxMin(sizer)
        sizer:SetSize(32, 32)
        if frame.CloseButton then
            sizer:ClearAllPoints()
            sizer:SetPoint("RIGHT", frame.CloseButton, "LEFT", 8.5, 0)
        end
    end
    WatchBorder(frame, sizer)
    PlateTabs(frame, COMMUNITY_TABS)
    for _, key in ipairs(FINDERS) do PlateTabs(frame[key], FINDER_TABS) end
    TintInner(frame, 6, frame.GuildMemberDetailFrame)
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
    ns.EachKey(frame.SearchBox, ns.KEYS.LMR, ns.DrainBronze, 0.85)
    if frame.Performance and frame.Performance.Divider then ns.DrainBronze(frame.Performance.Divider) end
    ns.EachKey(frame, ADDON_BUTTONS, ns.SkinRedButton)
    ns.QuietScrollBar(frame.ScrollBar, "addons.knob", true)
    local scroll = frame.ScrollBox
    if scroll and scroll.EnumerateFrames and not frame.fcuiRowWatch then
        local watch = CreateFrame("Frame", nil, frame)
        frame.fcuiRowWatch = watch
        ns.Sched.OnFrame(watch, { name = "addons.rows", every = 0.05, fn = function()
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
    if slice then ns.EachRegion(slice, TintInset, slice.Center) end
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
    ns.EachKey(_G.TimeManagerAlarmMessageEditBox, ns.KEYS.LMR, ns.DrainBronze, 0.85)
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
    ns.EachKey(frame.SearchBox, ns.KEYS.LMR, ns.DrainBronze, 0.85)
    ns.SkinDropdown(frame.LayoutDropdown)
    ns.SkinRedButton(frame.UndoButton)
    ns.QuietScrollBar(frame.CooldownScroll and frame.CooldownScroll.ScrollBar, "cooldownSettings.knob", true)
end
