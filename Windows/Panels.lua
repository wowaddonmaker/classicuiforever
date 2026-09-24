local _, ns = ...

-- Client windows that get the old chrome, with per-window lifts and afters.
-- Load-on-demand windows are dressed when their Blizzard addon loads.

local P = ns.panels
local A = P.after

local WINDOWS = {
    { "WorldMapFrame", child = "BorderFrame", portrait = false, backing = false, lift = P.MAP_LIFT, after = A.WorldMapFrame },
    { "MerchantFrame", lift = 5, after = A.MerchantFrame },
    -- Half lift: the send row sits near the bottom edge.
    { "MailFrame", lift = 5 },
    -- Smaller tab lift: the full one pushed the tabs through the border.
    { "FriendsFrame", lift = 5, tabLift = 3, after = function(frame)
        -- Narrower, as in 1.x; the lists hang from its edges.
        if frame:GetWidth() and math.abs(frame:GetWidth() - 385) < 1 then frame:SetWidth(360) end
        P.ShadeFloor(frame)
        if ns.PlaceRecentAllyRows then ns.PlaceRecentAllyRows() end
    end },
    -- Voice chat button's window. Half lift: Add and Settings sit near the bottom edge.
    -- Its after dresses the scroll bars without client hooks.
    { "ChannelFrame", lift = 5, scrollBars = false, after = A.ChannelFrame },
    -- Half lift: Goodbye, Accept and Decline sit near the bottom edge.
    { "QuestFrame", lift = 5, after = A.QuestFrame },
    { "GossipFrame", lift = 5, after = A.GossipFrame },
    { "TradeFrame", lift = 5, after = A.TradeFrame },
    { "TaxiFrame" },
    { "DressUpFrame" },
    { "PetStableFrame" },
    { "ItemTextFrame", after = A.ItemTextFrame },
    { "TabardFrame" },
    { "GuildRegistrarFrame" },
    { "PetitionFrame" },
    { "GuildControlUI", addon = "Blizzard_GuildControlUI", portrait = false, after = A.GuildControlUI },
    { "BankFrame", after = function(frame) if ns.SkinBank then ns.SkinBank(frame) end end },
    { "LootFrame", backing = false, after = A.LootFrame },
    -- Social window's lift, so the two read as one window when they swap.
    { "LFGListingFrame", addon = "Blizzard_GroupFinder_VanillaStyle", lift = 5, after = A.LFGListingFrame },
    { "LFGBrowseFrame", addon = "Blizzard_GroupFinder_VanillaStyle", lift = 5 },
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
        if not done[i] then
            local entry = WINDOWS[i]
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
