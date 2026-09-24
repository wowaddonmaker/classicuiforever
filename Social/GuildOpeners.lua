local _, ns = ...

-- Roster openers (Guild and Communities tabs, guild key, micro button, social opener) and the module switch.

local G, S = ns.guild, ns.social
local Build, Refresh, GuildTitle, DropGhost = G.Build, G.Refresh, G.GuildTitle, G.DropGhost
local HideBlizzardPanels, ShowBlizzardPanels = G.HideBlizzardPanels, G.ShowBlizzardPanels

local GUILD_ICON = "Interface\\FriendsFrame\\FriendsFrameScrollIcon"
local CLIENT_GUILD_WINDOWS = { "CommunitiesFrame", "GuildFrame" }
local GUILD_BINDINGS = { "TOGGLEGUILDTAB", "TOGGLEGUILDFRAME", "TOGGLEGUILD" }
local GUILD_EVENTS = { "PLAYER_GUILD_UPDATE", "GUILD_ROSTER_UPDATE" }
local tab
local togglingAt -- when a toggle ran, so one click never acts twice

---------------------------------------------------------------- the tab

-- White while up, gold otherwise, gray with no guild (KeepTabState).
-- Never judged by IsEnabled: a selected tab is disabled.
local function SelectOurTab(on)
    if not tab then return end
    S.SelectFriendsTab(tab, on)
    local text = tab.GetFontString and tab:GetFontString()
    if text and not tab.fcuiNoGuild then
        if on then text:SetTextColor(1, 1, 1) else text:SetTextColor(1, 0.82, 0) end
    end
end

-- Guild icon and rank title while the roster is up; the window's own after.
local function DressWindow(on)
    local icon = FriendsFrameIcon
    if icon then
        if on then
            if not icon.fcuiTexture then icon.fcuiTexture = icon:GetTexture() end
            icon:SetTexture(GUILD_ICON)
            icon:SetTexCoord(0, 1, 0, 1)
        elseif icon.fcuiTexture then
            icon:SetTexture(icon.fcuiTexture)
        end
    end
    if on and FriendsFrameTitleText then
        FriendsFrameTitleText:SetText(GuildTitle())
    elseif not on then
        ns.RestoreFriendsTitle()
    end
end

local function InGuild() return IsInGuild and IsInGuild() and true or false end

local function ShowGuild()
    if not G.panel then return end
    -- No guild, no roster: the tab is grayed and nothing else opens it.
    if not InGuild() then return end
    -- The who list first, or its ShowBlizzardPanels would bring the panels back.
    if ns.HideWhoList then ns.HideWhoList() end
    HideBlizzardPanels()
    G.panel:Show()
    SelectOurTab(true)
    DressWindow(true)
    Refresh()
    ns.RefreshMicroButtons()
end

local function HideGuild()
    if not G.panel then return end
    G.panel:Hide()
    DropGhost()
    SelectOurTab(false)
    DressWindow(false)
    ShowBlizzardPanels()
    ns.RefreshMicroButtons()
end
ns.HideGuildRoster = HideGuild

local function PlaceTab()
    if not tab then return end
    S.PlaceTabs()
end

-- Grayed out with no guild, as 1.x had it.
local function KeepTabState()
    if not tab then return end
    local text = tab.GetFontString and tab:GetFontString()
    if InGuild() then
        -- Re-enable only a tab disabled for no guild (a selected tab is disabled too).
        if tab.fcuiNoGuild then
            tab.fcuiNoGuild = false
            tab:Enable()
            if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab) end
            ns.FitBottomTab(tab)
        end
        -- The gray is on the label and survives Enable.
        local up = G.panel and G.panel:IsShown()
        if text then
            if up then text:SetTextColor(1, 1, 1) else text:SetTextColor(1, 0.82, 0) end
        end
    else
        -- Via HideGuild, which gives the window's panels back.
        if G.panel and G.panel:IsShown() then HideGuild() end
        tab.fcuiNoGuild = true
        tab:Disable()
        if text then text:SetTextColor(0.5, 0.5, 0.5) end
    end
end

-- The roster took the communities' key and button, so they get a tab that
-- opens the client's window in this one's place.
local communitiesTab
local function BuildCommunitiesTab(host)
    if communitiesTab or not C_Club then return end
    communitiesTab = S.NewTab(host, "ClassicUIForeverCommunitiesTab", 92, COMMUNITIES or "Communities")
    if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(communitiesTab) end
    communitiesTab:SetScript("OnClick", function()
        -- The client opens no window for an addon in a fight.
        if InCombatLockdown() then
            ns.SayNotInCombat()
            return
        end
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        -- Drop the ghost first, or the toggle would only close it.
        DropGhost()
        if G.panel and G.panel:IsShown() then HideGuild() end
        local frame = _G["CommunitiesFrame"]
        if frame and frame:IsShown() then return end
        if FriendsFrame and FriendsFrame:IsShown() then ns.HidePanel(FriendsFrame) end
        local open = G.clientToggleGuild or ToggleGuildFrame
        if type(open) == "function" then open() end
    end)
end

local function OnClientTab() if G.active then HideGuild() end end
local function Reassert()
    if G.active and G.panel and G.panel:IsShown() then
        HideBlizzardPanels()
        SelectOurTab(true)
        DressWindow(true)
    end
end
local function OnSocialShow() if G.active then PlaceTab() KeepTabState() end end
local function OnSocialHide() if G.panel then HideGuild() end end
local SOCIAL_HOOKS = { tabClick = OnClientTab, update = Reassert, onShow = OnSocialShow, onHide = OnSocialHide }

local function BuildTab()
    local host = FriendsFrame
    if not host or tab then return end
    BuildCommunitiesTab(host)
    tab = S.NewTab(host, "ClassicUIForeverGuildTab", 90, GUILD or "Guild")
    SelectOurTab(false)
    PlaceTab()
    tab:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        ShowGuild()
    end)
    S.HookFriendsFrame(host, SOCIAL_HOOKS)
    -- Guild events can come before IsInGuild agrees: rechecked 1 s and 4 s on.
    ns.EventFrame(GUILD_EVENTS, function()
        if not G.active then return end
        KeepTabState()
        ns.Sched.AfterPerFrame("guild.tabState", 1, KeepTabState)
        ns.Sched.AfterPerFrame("guild.tabState", 4, KeepTabState)
    end)
    KeepTabState()
end

---------------------------------------------------------------- openers

-- FriendsFrame has protected parts and won't open for us in combat: opened after it.
local wanted = false

function ns.OpenGuildRoster()
    if not G.active or not FriendsFrame then return false end
    if not G.panel then Build() end
    BuildTab()
    if not ns.ShowPanel(FriendsFrame) then
        wanted = true
        return false
    end
    wanted = false
    ShowGuild()
    return true
end

local afterFight = CreateFrame("Frame")
afterFight:RegisterEvent("PLAYER_REGEN_ENABLED")
afterFight:SetScript("OnEvent", function()
    if G.active and wanted then
        wanted = false
        ns.OpenGuildRoster()
    end
end)

-- 1.x's micro menu had Social, not Guild: the guild button does that job.
local function SocialShown() return FriendsFrame and FriendsFrame:IsShown() and true or false end

local function ToggleSocial()
    if not FriendsFrame then return end
    if SocialShown() then
        if G.panel and G.panel:IsShown() then G.panel:Hide() end
        ns.HidePanel(FriendsFrame)
    else
        ns.ShowPanel(FriendsFrame)
    end
    ns.RefreshMicroButtons()
end

local function CloseClientGuildWindows()
    DropGhost()
    for _, name in ipairs(CLIENT_GUILD_WINDOWS) do
        local frame = _G[name]
        if frame and frame:IsShown() then ns.HidePanel(frame) end
    end
end

-- ToggleGuildFrame callers get this roster; Guild Information uses the kept original.
local function WrapGuildToggle()
    if G.clientToggleGuild or type(ToggleGuildFrame) ~= "function" then return end
    G.clientToggleGuild = ToggleGuildFrame
    -- A window opened inside the client's pass is refused in combat: deferred a frame there.
    local function Run()
        togglingAt = GetTime()
        CloseClientGuildWindows()
        -- Decided by what is shown, not a flag a refused open left set.
        ToggleSocial()
    end

    ToggleGuildFrame = function(...)
        if not G.active then return G.clientToggleGuild(...) end
        if InCombatLockdown() and C_Timer and C_Timer.After then
            -- Marked now: the button's OnClick hook runs later this frame and must see it.
            togglingAt = GetTime()
            C_Timer.After(0, Run)
        else
            Run()
        end
    end
end

-- The guild key clicks our secure button. No secure snippets on this client,
-- so a window the client won't open in combat stays shut, no blocked box.
local GUILD_BIND = "ForeverClassicUIGuildBind"
local guildBind

local function UpdateGuildBinding()
    if not guildBind or InCombatLockdown() then return end
    ClearOverrideBindings(guildBind)
    if not G.active then return end
    for _, binding in ipairs(GUILD_BINDINGS) do
        local key, second = GetBindingKey(binding)
        for _, k in ipairs({ key, second }) do
            if k then SetOverrideBindingClick(guildBind, true, k, GUILD_BIND, "LeftButton") end
        end
    end
end
ns.UpdateGuildBinding = UpdateGuildBinding

-- The social window opens by a client opener: a counted panel (Escape closes it) that opens in combat.
-- No friends micro button, and /friends is not secure (it adds the target as a friend):
-- QuickJoinToastButton, clicked with no toast waiting, runs the client's ToggleFriendsFrame.
local socialOpen

-- After a press: the key also opens the roster, the button only the window.
-- Never selects the client's tab (it lit beside ours).
local function AfterSocialPress(toRoster)
    if not G.active then return end
    if SocialShown() then
        if toRoster then
            CloseClientGuildWindows()
            ShowGuild()
        end
    else
        HideGuild()
    end
    ns.RefreshMicroButtons()
end

-- A press that changed nothing (window up: the opener turns a page; toast
-- waiting: it does nothing) is toggled from here.
local function SettleSocialPress(was)
    local now = SocialShown()
    if was == now then ToggleSocial() end
end

local function BuildSocialOpener()
    if socialOpen or InCombatLockdown() then return end
    if not _G["QuickJoinToastButton"] then return end
    socialOpen = CreateFrame("Button", "ForeverClassicUISocialOpen", UIParent, "SecureActionButtonTemplate")
    -- Sized and placed off screen: a button with neither is never clicked.
    socialOpen:SetSize(1, 1)
    socialOpen:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
    socialOpen:EnableMouse(false)
    socialOpen:RegisterForClicks("AnyUp", "AnyDown")
    socialOpen:SetAttribute("useOnKeyDown", false)
    socialOpen:SetAttribute("type", "macro")
    socialOpen:SetAttribute("macrotext", "/click QuickJoinToastButton")
    socialOpen:SetScript("PreClick", function(self, _, down)
        if down then return end
        self.was = SocialShown()
    end)
    socialOpen:HookScript("OnClick", function(self, _, down)
        if down or not G.active then return end
        SettleSocialPress(self.was)
        self.was = nil
        AfterSocialPress(false)
    end)
    return socialOpen
end

local function BuildSecureOpener()
    if guildBind or InCombatLockdown() then return end
    if not G.panel then Build() end
    guildBind = CreateFrame("Button", GUILD_BIND, UIParent, "SecureActionButtonTemplate")
    -- A macro runs in the client's own pass, so the panel manager allows it in combat.
    guildBind:RegisterForClicks("AnyUp", "AnyDown")
    -- Once per press, on release (both key halves reach this button).
    guildBind:SetAttribute("useOnKeyDown", false)
    guildBind:SetAttribute("type", "macro")
    -- The toast, not /friends: not secure here, and it adds the target as a friend.
    guildBind:SetAttribute("macrotext", "/click QuickJoinToastButton")
    guildBind:SetScript("PreClick", function(self, _, down)
        if down then return end
        self.was = SocialShown()
    end)
    guildBind:HookScript("OnClick", function(self, _, down)
        if down or not G.active then return end
        SettleSocialPress(self.was)
        self.was = nil
        AfterSocialPress(true)
    end)
    guildBind:RegisterEvent("UPDATE_BINDINGS")
    guildBind:RegisterEvent("PLAYER_REGEN_ENABLED")
    -- Bindings may not be loaded yet on the first run.
    guildBind:RegisterEvent("PLAYER_ENTERING_WORLD")
    guildBind:SetScript("OnEvent", UpdateGuildBinding)
    -- Dressed here however the roster came up.
    G.panel:HookScript("OnShow", function()
        if not G.active then return end
        HideBlizzardPanels()
        SelectOurTab(true)
        DressWindow(true)
        Refresh()
        ns.RefreshMicroButtons()
    end)
    UpdateGuildBinding()
end

local function HookGuildOpeners()
    local button = GuildMicroButton
    if not button or not ns.Once(button, "guildHooked") then return end
    button:HookScript("OnClick", function()
        if not G.active then return end
        -- The click already went through the wrapped toggle in this frame.
        if togglingAt == GetTime() then return end
        togglingAt = GetTime()
        CloseClientGuildWindows()
        -- A second press closes it; what is on screen decides, not a stale flag.
        ToggleSocial()
    end)
    -- Pressed look while the social window is up.
    ns.MicroButtonFollows(button, SocialShown)
    -- The client's text is about guilds and communities; this button is Social.
    button:HookScript("OnEnter", function(self)
        if not G.active or not GameTooltip:IsOwned(self) then return end
        local title = SOCIAL_BUTTON or "Social"
        if type(MicroButtonTooltipText) == "function" then title = MicroButtonTooltipText(title, "TOGGLESOCIAL") end
        GameTooltip:SetText(title, 1, 1, 1)
        if NEWBIE_TOOLTIP_SOCIAL then GameTooltip:AddLine(NEWBIE_TOOLTIP_SOCIAL, 1, 0.82, 0, true) end
        GameTooltip:Show()
    end)
end

---------------------------------------------------------------- module

local function Apply()
    G.active = true
    if not FriendsFrame then ns.MissingPiece("FriendsFrame") return end
    -- Never during a fight: see ns.WhenCalm.
    ns.WhenCalm("guild", function()
        if not G.active then return end
        if not G.panel then Build() end
        BuildTab()
        HookGuildOpeners()
        WrapGuildToggle()
        BuildSecureOpener()
        -- The button presses the client's own opener, as the key does.
        if BuildSocialOpener() and GuildMicroButton then
            ns.MapPad(GuildMicroButton, nil, nil, socialOpen, function() return G.active end)
        end
        if communitiesTab then communitiesTab:Show() end
        if tab then tab:Show() PlaceTab() end
    end)
end

local function Restore()
    G.active = false
    ns.UpdateGuildBinding()
    HideGuild()
    if tab then tab:Hide() end
    if communitiesTab then communitiesTab:Hide() end
    S.PlaceTabs()
end

ns.RegisterModule("guildRoster", { apply = Apply, restore = Restore })
