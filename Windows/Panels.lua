local _, ns = ...

-- Client windows that get the old chrome, with per-window lifts and afters.
-- Load-on-demand windows are dressed when their Blizzard addon loads.

local P = ns.panels

-- Era's scroll on every social tab; the client writes its Battle.net portrait on each update.
local SCROLL_ICON = "Interface\\FriendsFrame\\FriendsFrameScrollIcon"
local function ScrollIconBack(icon, file)
    if file ~= SCROLL_ICON then
        icon:SetTexture(SCROLL_ICON)
        icon:SetTexCoord(0, 1, 0, 1)
    end
end
function ns.KeepScrollIcon(icon)
    if not icon then return end
    if ns.Once(icon, "scrollIcon") then ns.HookMethod(icon, "SetTexture", ScrollIconBack) end
    ScrollIconBack(icon)
end

local A = P.after
local SOCIAL_WIDTH = 338
-- Merchant tabs: up from the client's spot (+ up); 1 sets their tops on the metal line, as the social row's.
local MERCHANT_TAB_LIFT = 1
-- Mail tabs: the client's spot already has their tops on the line (+ up); Send Mail 8 into Inbox, as Era's.
local MAIL_TAB_LIFT = 0
local MAIL_TAB_STEP = -8

-- Era's inset border on the game's own social tabs (Friends, Raid); Who and Guild (ours) draw their own, and the skin
-- keeps every other inset border faded.
local INSET_EDGES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge",
    "LeftEdge", "RightEdge" }
local function GameSocialTabUp()
    local raid, header = _G.RaidFrame, _G.FriendsTabHeader
    if raid and raid:IsVisible() and raid:GetParent() == _G.FriendsFrame then return true end
    -- Shown only on Friends; our tabs fade it while they are up.
    return header ~= nil and header:IsVisible() and header:GetAlpha() > 0.5
end
function ns.SocialInsetBorder()
    local slice = _G.FriendsFrameInset and _G.FriendsFrameInset.NineSlice
    if not slice then return end
    local up = GameSocialTabUp()
    for _, key in ipairs(INSET_EDGES) do
        if slice[key] then ns.SetAlphaIf(slice[key], up and 1 or 0) end
    end
    if up then ns.DrainSlice(slice) end
end
local function InsetSoon() ns.Sched.NextFrame("social.inset", ns.SocialInsetBorder) end
local function GameSocialTabs()
    local raid, notInRaid = _G.RaidFrame, _G.RaidFrameNotInRaid
    if not raid or not ns.Once(raid, "classicRaidTab") then return end
    -- Its description panel comes with no box, so the text never lays out: it fills the raid frame, as its XML says.
    if notInRaid then notInRaid:SetAllPoints(raid) end
    ns.Sched.OnVisible(raid, "social.inset", InsetSoon)
    ns.Sched.OnVisible(_G.FriendsTabHeader, "social.inset", InsetSoon)
    ns.SocialInsetBorder()
end

local WINDOWS = {
    -- Its own row under Map (toggle): the pass skips it while that is off.
    { "WorldMapFrame", child = "BorderFrame", toggle = "worldMap", portrait = false, backing = false, lift = P.MAP_LIFT,
        left = P.MAP_LEFT, after = A.WorldMapFrame },
    { "MerchantFrame", lift = 5, tabLift = MERCHANT_TAB_LIFT, after = A.MerchantFrame },
    -- Half lift: the send row sits near the bottom edge.
    { "MailFrame", lift = 5, tabLift = MAIL_TAB_LIFT, after = function()
        ns.EraTabRow({ _G["MailFrameTab1"], _G["MailFrameTab2"] }, MAIL_TAB_STEP)
    end },
    -- Smaller tab lift: the full one pushed the tabs through the border.
    { "FriendsFrame", lift = 5, tabLift = 3, after = function(frame)
        -- Classic Era's width (measured 338, as its macro window); the lists hang from its edges.
        if frame:GetWidth() and math.abs(frame:GetWidth() - 385) < 1 then frame:SetWidth(SOCIAL_WIDTH) end
        P.ShadeFloor(frame)
        GameSocialTabs()
        if ns.PlaceRecentAllyRows then ns.PlaceRecentAllyRows() end
        ns.KeepScrollIcon(_G["FriendsFrameIcon"])
    end },
    -- The contacts tab's pop-out ignore list: no portrait, its button in the old red.
    { "FriendsFrame", child = "IgnoreListWindow", portrait = false, lift = 5, after = function(frame)
        ns.SkinRedButton(frame.UnignorePlayerButton)
        if frame.Inset then ns.DrainSlice(frame.Inset.NineSlice) end
    end },
    -- Voice chat button's window. Half lift: Add and Settings sit near the bottom edge.
    -- Its after dresses the scroll bars without client hooks.
    { "ChannelFrame", lift = 5, scrollBars = false, after = A.ChannelFrame },
    -- Half lift: Goodbye, Accept and Decline sit near the bottom edge.
    { "QuestFrame", lift = 5, after = A.QuestFrame },
    { "GossipFrame", lift = 5, after = A.GossipFrame },
    { "TradeFrame", lift = 5, after = A.TradeFrame },
    { "TaxiFrame" },
    { "DressUpFrame", after = A.DressUpFrame },
    { "PetStableFrame" },
    { "ItemTextFrame", after = A.ItemTextFrame },
    -- Half lift, as the vendor's: Accept, Purchase, Sign and Cancel sit 4 up from the bottom edge.
    { "TabardFrame", lift = 5 },
    { "GuildRegistrarFrame", lift = 5, after = A.GuildRegistrarFrame },
    { "PetitionFrame", lift = 5 },
    { "GuildControlUI", addon = "Blizzard_GuildControlUI", portrait = false, after = A.GuildControlUI },
    { "BankFrame", after = function(frame) if ns.SkinBank then ns.SkinBank(frame) end end },
    { "LootFrame", toggle = "lootWindow", backing = false, after = A.LootFrame },
    -- Social window's lift, so the two read as one window when they swap.
    { "LFGWhoListFrame", addon = "Blizzard_GroupFinder_VanillaStyle", lift = 5 },
    { "InspectFrame", addon = "Blizzard_InspectUI", after = A.InspectFrame },
    { "MacroFrame", addon = "Blizzard_MacroUI", topTabs = true, lift = 2, after = A.MacroFrame },
    { "ClassTrainerFrame", addon = "Blizzard_TrainerUI" },
    { "AuctionHouseFrame", addon = "Blizzard_AuctionHouseUI", lift = 9 },
    { "CommunitiesFrame", addon = "Blizzard_Communities", after = A.CommunitiesFrame },
    { "CollectionsJournal", addon = "Blizzard_Collections", after = A.CollectionsJournal },
    { "EncounterJournal", addon = "Blizzard_EncounterJournal" },
    { "AchievementFrame", addon = "Blizzard_AchievementUI" },
    { "ProfessionsFrame", addon = "Blizzard_Professions" },
    { "ProfessionsBookFrame", addon = "Blizzard_ProfessionsBook" },
    { "GuildBankFrame", addon = "Blizzard_GuildBankUI" },
    { "CalendarFrame", addon = "Blizzard_Calendar", portrait = false },
    { "ItemSocketingFrame", addon = "Blizzard_ItemSocketingUI" },
    -- scrollBars = false from here: no client hooks; the afters dress any bars they name.
    -- Half lift: its foot buttons sit 4 off the bottom edge.
    { "AddonList", portrait = false, lift = 5, scrollBars = false, after = A.AddonList },
    -- Support window. Half lift: the browser runs to 4 off the bottom edge.
    { "HelpFrame", portrait = false, lift = 5, scrollBars = false, after = A.HelpFrame },
    -- Half lift, as the map: its pages run to the bottom edge.
    { "LegacySystemFrame", addon = "Blizzard_LegacySystem", portrait = false, lift = 5, scrollBars = false,
        after = A.LegacySystemFrame },
    -- Its globe stands in the portrait ring.
    { "TimeManagerFrame", addon = "Blizzard_TimeManager", scrollBars = false, after = A.TimeManagerFrame },
    { "ClickBindingFrame", addon = "Blizzard_ClickBindingUI", lift = 5, scrollBars = false, after = A.ClickBindingFrame },
    { "CooldownViewerSettings", lift = 5, scrollBars = false, after = A.CooldownViewerSettings },
}

local watcher
local done = {}   -- WINDOWS index -> dressed (for good)

-- Each entry doubles as SkinWindow's opts (read only).
local function SkinKnown()
    local skinned = P.skinned
    for i = 1, #WINDOWS do
        local entry = WINDOWS[i]
        if not done[i] and not (entry.toggle and ns.db[entry.toggle] == false) then
            local frame = _G[entry[1]]
            if frame and entry.child then frame = frame[entry.child] end
            if frame then
                if not skinned[frame] then
                    P.windowAfter[frame] = entry.after
                    ns.SkinWindow(frame, entry)
                end
                if skinned[frame] then done[i] = true end
            end
        end
    end
end

local function Apply()
    P.active = true
    SkinKnown()
    if not watcher then
        watcher = ns.EventFrame("ADDON_LOADED", function() if P.active then SkinKnown() end end)
    end
end

local function Restore()
    P.active = false
    for frame in pairs(P.skinned) do
        if frame.fcui and frame.fcui.titleStrip then frame.fcui.titleStrip:Hide() end
    end
    ns.needsReload = true
end

ns.RegisterModule("panels", { apply = Apply, restore = Restore })

-- A window with its own row (the entry's toggle): dressed by the panels pass while on; off, the strip goes and the
-- rest waits for the reload, as Window frames off does. Frame() is the dressed frame, once it exists.
local stripOff = setmetatable({}, { __mode = "k" })   -- frame -> its row hid the strip (the loot skin hides its own)
local function WindowRow(key, Frame)
    local function Apply()
        if not P.active then return end
        local frame = Frame()
        if frame and stripOff[frame] then
            stripOff[frame] = nil
            if frame.fcui and frame.fcui.titleStrip then frame.fcui.titleStrip:Show() end
        end
        SkinKnown()
    end
    local function Restore()
        local frame = Frame()
        if not frame or not P.skinned[frame] then return end
        local strip = frame.fcui and frame.fcui.titleStrip
        if strip and strip:IsShown() then
            strip:Hide()
            stripOff[frame] = true
        end
        ns.needsReload = true
    end
    ns.RegisterModule(key, { apply = Apply, restore = Restore })
end

WindowRow("worldMap", function() return WorldMapFrame and WorldMapFrame.BorderFrame end)
WindowRow("lootWindow", function() return LootFrame end)
