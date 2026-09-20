local _, ns = ...

-- Shared helpers for the reskin modules. Every Blizzard frame stays alive
-- and keeps its logic; we only change textures, anchors and alpha, and we
-- hook the update methods that would undo that.

-- Alpha 0 instead of Hide: Blizzard's own code calls Show() on its regions
-- all the time and alpha survives that.
-- The 1.x quest difficulty colors by level against the player's:
-- red five or more above, orange three or four, pure yellow from two
-- above down to two below, green while the quest still gives
-- experience, gray past that. The client's own table uses gold for the
-- yellow band, which reads orange next to the old art.
local QUEST_COLOURS = {
    impossible = { 1, 0.1, 0.1 }, verydifficult = { 1, 0.5, 0.25 }, difficult = { 1, 0.92, 0 },
    standard = { 0.25, 0.75, 0.25 }, trivial = { 0.5, 0.5, 0.5 },
}
-- The quest log's own labels (All, the quest count) wear the same yellow.
function ns.QuestYellow()
    local c = QUEST_COLOURS.difficult
    return c[1], c[2], c[3]
end

function ns.QuestLevelColor(level)
    level = tonumber(level) or 0
    local player = UnitLevel("player") or 1
    local diff = level - player
    local key
    if level <= 0 then
        key = "difficult"
    elseif diff >= 5 then
        key = "impossible"
    elseif diff >= 3 then
        key = "verydifficult"
    elseif diff >= -2 then
        key = "difficult"
    else
        local range = 5
        if UnitQuestTrivialLevelRange then
            local ok, r = pcall(UnitQuestTrivialLevelRange, "player")
            if ok and tonumber(r) then range = r end
        elseif GetQuestGreenRange then
            local ok, r = pcall(GetQuestGreenRange)
            if ok and tonumber(r) then range = r end
        end
        key = (-diff <= range) and "standard" or "trivial"
    end
    local c = QUEST_COLOURS[key]
    return c[1], c[2], c[3]
end

-- The old gold (1, 0.82, 0) on the game's normal fonts, for text that
-- must read as the old yellow whatever the client's own color is.
local function GoldFont(name, base)
    local font = CreateFont(name)
    font:SetFontObject(base)
    font:SetTextColor(1, 0.82, 0)
    return font
end
ns.FONT_GOLD = GoldFont("ClassicUIForeverGold", "GameFontNormal")
ns.FONT_GOLD_SMALL = GoldFont("ClassicUIForeverGoldSmall", "GameFontNormalSmall")
ns.FONT_GOLD_LARGE = GoldFont("ClassicUIForeverGoldLarge", "GameFontNormalLarge")

-- 1.x showed a skull rather than a number for anything more than ten
-- levels above you: the server hid those levels and sent -1. This client
-- sends the real number, so the old rule is kept here. A level of -1,
-- which is what a boss still sends, is a skull as before.
function ns.SkullLevel(level)
    if level == nil then return false end
    if issecretvalue and issecretvalue(level) then return false end
    if level < 0 then return true end
    local mine = UnitLevel("player")
    if mine == nil or (issecretvalue and issecretvalue(mine)) then return false end
    return (level - mine) > 10
end

function ns.Fade(region)
    if region and region.SetAlpha then region:SetAlpha(0) end
end

function ns.Unfade(region)
    if region and region.SetAlpha then region:SetAlpha(1) end
end

local hooked = setmetatable({}, { __mode = "k" })

-- Hook a method on a frame once. Missing methods are skipped and reported
-- through the debug flush instead of erroring the module out.
function ns.HookMethod(frame, method, fn)
    if not frame then return false end
    if type(frame[method]) ~= "function" then
        ns.MissingPiece((frame.GetName and frame:GetName() or "?") .. ":" .. method)
        return false
    end
    hooked[frame] = hooked[frame] or {}
    if hooked[frame][method] then return true end
    hooked[frame][method] = true
    hooksecurefunc(frame, method, fn)
    return true
end

local hookedGlobals = {}
function ns.HookGlobal(name, fn)
    if type(_G[name]) ~= "function" then
        ns.MissingPiece(name)
        return false
    end
    if hookedGlobals[name] then return true end
    hookedGlobals[name] = true
    hooksecurefunc(name, fn)
    return true
end

-- The friends window carries more than the panels this UI knows by
-- name: a menu button, a status drop down, a quick join toggle, and
-- whatever the client adds next. While one of our tabs is up, anything
-- of the client's still showing on that window steps aside, and comes
-- back when ours goes. Our own frames, the tabs and the close button
-- are left alone, since the window still needs them.
-- Said once per sweep, on demand: what this actually reached and what
-- is still standing on that window.
local sweepSaid = false
function ns.SweepFriendsReport()
    sweepSaid = false
end

-- The title bar and the inset stay, since the window needs them, but
-- the client hangs controls inside both: the menu button and the status
-- line sit in the title, not on the window. Those go with the rest.
local function SweepInside(container, mark, hide)
    if not container or not container.GetChildren then return end
    for _, child in ipairs({ container:GetChildren() }) do
        local name = (child.GetName and child:GetName()) or ""
        if not name:find("ClassicUIForever", 1, true) then
            if hide then
                if not child[mark] then
                    child[mark] = true
                    -- What it was before anything of ours touched it. A
                    -- piece one of our tabs has already faded reads 0
                    -- here, and 0 kept as "how it was" put it back unseen
                    -- when the tab closed: the friends list came back
                    -- blank. Unseen is never what it is put back to.
                    local was = child:GetAlpha()
                    child.fcuiAlpha = (was and was > 0) and was or nil
                    child.fcuiMouse = child.IsMouseEnabled and child:IsMouseEnabled()
                end
                if child:GetAlpha() > 0 then child:SetAlpha(0) end
                if child.EnableMouse and not InCombatLockdown() and child.IsMouseEnabled and child:IsMouseEnabled() then
                    child:EnableMouse(false)
                end
            elseif child[mark] then
                child[mark] = nil
                child:SetAlpha(child.fcuiAlpha or 1)
                if child.EnableMouse and not InCombatLockdown() and child.fcuiMouse then child:EnableMouse(true) end
                child.fcuiAlpha, child.fcuiMouse = nil, nil
            end
        end
    end
end

-- The social window's title as the client would have it for the tab of
-- its own that is selected. Our Guild and Who tabs write their own title
-- while they are up, and write it again whenever the client updates the
-- window, which includes the update that answers a click on one of the
-- client's tabs: the client's title went on first and ours over it, and
-- the window kept saying Guild or Who List over the friends list. So the
-- title is put back by whichever of ours is closing.
function ns.RestoreFriendsTitle()
    local title = FriendsFrameTitleText
    local host = FriendsFrame
    if not title or not host then return end
    local selected = host.selectedTab or (PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(host)) or 1
    local text
    -- This client has no who tab of its own, and its raid tab is the
    -- second: a missing who number read as 2 put "Who List" over the
    -- raid tab. A number the client does not have matches nothing.
    if FRIEND_TAB_WHO and selected == FRIEND_TAB_WHO then
        text = WHO_LIST
    elseif selected == (FRIEND_TAB_RAID or 3) then
        text = RAID
    elseif selected == (FRIEND_TAB_QUICK_JOIN or 4) then
        text = QUICK_JOIN
    else
        local header = FriendsTabHeader
        local sub = header and header.GetTab and header:GetTab()
        if sub and header.recentAlliesTabID and sub == header.recentAlliesTabID then
            text = CONTACTS_RECENT_ALLIES_TITLE
        elseif sub and header.recruitAFriendTabID and sub == header.recruitAFriendTabID then
            text = RECRUIT_A_FRIEND
        else
            text = CONTACTS_LIST_TITLE or FRIENDS
        end
    end
    if text then title:SetText(text) end
end

function ns.SweepFriendsFrame(mark, hide)
    local host = FriendsFrame
    if not host or not host.GetChildren then return end
    SweepInside(host.TitleContainer, mark, hide)
    SweepInside(_G["FriendsFrameInset"], mark, hide)
    if hide and not sweepSaid and ns.db and ns.db.sweepTrace then
        sweepSaid = true
        local kept, hidden = {}, {}
        for _, child in ipairs({ host:GetChildren() }) do
            local name = (child.GetName and child:GetName()) or (child.GetDebugName and child:GetDebugName()) or "?"
            local shown = child:IsShown() and (child:GetAlpha() or 0) > 0
            table.insert(shown and kept or hidden, name)
        end
        ns.Print("friends window children still visible: " .. (next(kept) and table.concat(kept, ", ") or "none"))
        for _, container in ipairs({ host.TitleContainer, _G["FriendsFrameInset"] }) do
            if container and container.GetChildren then
                local inside = {}
                for _, child in ipairs({ container:GetChildren() }) do
                    if child:IsShown() and (child:GetAlpha() or 0) > 0 then
                        table.insert(inside, (child.GetName and child:GetName()) or (child.GetDebugName and child:GetDebugName()) or "?")
                    end
                end
                ns.Print("  inside " .. ((container.GetDebugName and container:GetDebugName()) or "?") .. ": "
                    .. (next(inside) and table.concat(inside, ", ") or "none"))
            end
        end
    end
    for _, child in ipairs({ host:GetChildren() }) do
        local name = (child.GetName and child:GetName()) or ""
        -- The border, the title bar and the inset are the window itself:
        -- the border frame carries the metal edge and the portrait's
        -- ring. What the client hangs inside the last two is swept above.
        local keep = name:find("ClassicUIForever", 1, true) or name:find("FriendsFrameTab", 1, true)
            or child == host.CloseButton or child == host.PortraitContainer
            or child == host.NineSlice or child == host.TitleContainer or child == _G["FriendsFrameInset"]
        if not keep then
            if hide then
                -- Whether it is showing right now is not the question:
                -- the client brings its own controls up while our tab is
                -- already open, so they are put down on sight and kept
                -- down for as long as ours is up.
                if not child[mark] then
                    child[mark] = true
                    -- What it was before anything of ours touched it. A
                    -- piece one of our tabs has already faded reads 0
                    -- here, and 0 kept as "how it was" put it back unseen
                    -- when the tab closed: the friends list came back
                    -- blank. Unseen is never what it is put back to.
                    local was = child:GetAlpha()
                    child.fcuiAlpha = (was and was > 0) and was or nil
                    child.fcuiMouse = child.IsMouseEnabled and child:IsMouseEnabled()
                end
                if child:GetAlpha() > 0 then child:SetAlpha(0) end
                if child.EnableMouse and not InCombatLockdown() and child.IsMouseEnabled and child:IsMouseEnabled() then
                    child:EnableMouse(false)
                end
            elseif child[mark] then
                child[mark] = nil
                child:SetAlpha(child.fcuiAlpha or 1)
                if child.EnableMouse and not InCombatLockdown() and child.fcuiMouse then child:EnableMouse(true) end
                child.fcuiAlpha, child.fcuiMouse = nil, nil
            end
        end
    end
end

-- The client puts its own controls back up on its own schedule, so the
-- sweep runs for as long as one of our tabs is on that window rather
-- than once as it opens.
local sweepers = {}
local sweepDriver
function ns.KeepFriendsSwept(panel, mark)
    if not panel then return end
    sweepers[panel] = mark
    if sweepDriver then return end
    sweepDriver = CreateFrame("Frame")
    sweepDriver:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 0.25 then return end
        self.since = 0
        for frame, tag in pairs(sweepers) do
            if frame:IsShown() then ns.SweepFriendsFrame(tag, true) end
        end
    end)
end

function ns.HookScriptOnce(frame, script, fn)
    if not frame or not frame.HookScript then return end
    hooked[frame] = hooked[frame] or {}
    if hooked[frame]["script:" .. script] then return end
    hooked[frame]["script:" .. script] = true
    frame:HookScript(script, fn)
end

-- Pieces the running client does not have are listed for /fcui debug.
ns.missing = {}
function ns.MissingPiece(name)
    if not ns.missing[name] then
        ns.missing[name] = true
        ns.missingCount = (ns.missingCount or 0) + 1
    end
end

-- The 12.x level and PvP circles: any texture on the frame drawn from a
-- "SmallCircle" atlas goes away, whatever key it hangs on.
function ns.FadeCircles(frame)
    if not frame or not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") and region.GetAtlas then
            local atlas = region:GetAtlas()
            if atlas and atlas:lower():find("smallcircle", 1, true) then region:SetAlpha(0) end
        end
    end
end

-- Walk a dotted path of keys from a frame, nil if any step is missing.
-- The old windows never stacked: opening one closed whatever was in its
-- place. The client does that for its own windows through the panel
-- system, and the windows this addon owns are deliberately outside that
-- system, since a window inside it cannot be opened during a fight. So
-- they keep the old manners here: one of ours opening closes the
-- client's, and one of the client's opening closes ours.
local classicWindows = {}
local WatchClientWindows

-- Windows the client keeps outside its own panel list; the map is the
-- one that matters, since it is opened and closed on its own terms.
local LOOSE_PANELS = { "WorldMapFrame" }

-- Never closed from here: the talents window. Its closing code clears
-- the note each action bar keeps about showing its empty slots, and
-- cleared by the addon that note is one the client will not act on
-- again, so empty slots stopped coming up for a dragged spell.
local LEAVE_OPEN = { PlayerSpellsFrame = true }

local function HideClientPanels(except)
    if InCombatLockdown() then return end
    for name in pairs(UIPanelWindows or {}) do
        local panel = _G[name]
        -- The guild window standing open unseen under our roster (the
        -- note bridge) is not one to close.
        local ghost = ns.guildGhost and name == "CommunitiesFrame"
        if panel and panel ~= except and not LEAVE_OPEN[name] and not ghost and panel:IsShown() and HideUIPanel then
            pcall(HideUIPanel, panel)
        end
    end
    for _, name in ipairs(LOOSE_PANELS) do
        local panel = _G[name]
        if panel and panel ~= except and panel:IsShown() and HideUIPanel then
            pcall(HideUIPanel, panel)
        end
    end
end

-- The windows an NPC opens, and the rest of the client's that take the
-- place the old windows shared. Not every one of these goes through the
-- client's panel call on this client: a quest giver's and a vendor's
-- came up with the spellbook still standing under them, its buttons
-- showing through. So they are not hooked, they are watched: on every
-- frame, from a frame of ours, each is asked whether it is up, and
-- one that has just come up sends ours away. A hook on the panel call
-- ran inside every window the client opened, in the client's own pass;
-- a watcher never does.
local NPC_WINDOWS = { "GossipFrame", "QuestFrame", "MerchantFrame", "MailFrame", "BankFrame", "ClassTrainerFrame",
    "AuctionHouseFrame", "AuctionFrame", "TradeFrame", "TaxiFrame", "FlightMapFrame", "PetStableFrame", "StableFrame",
    "ItemTextFrame", "TabardFrame", "GuildRegistrarFrame", "PetitionFrame", "CraftFrame", "TradeSkillFrame",
    "ProfessionsFrame", "BarberShopFrame", "GuildBankFrame", "InspectFrame", "LootFrame" }
local npcWindow = {}
for _, name in ipairs(NPC_WINDOWS) do npcWindow[name] = true end

local clientShown = {}
local windowWatch

local function ClientWindowOpened(name, panel)
    -- The talents window shares the screen with the spellbook and the
    -- social window, as it did; everything else takes their place.
    if LEAVE_OPEN[name] then return end
    ns.HideClassicWindows(panel)
    -- The social window is the client's own, and gave way to an NPC's
    -- window the way the spellbook did.
    if npcWindow[name] and FriendsFrame and FriendsFrame ~= panel and FriendsFrame:IsShown() then
        ns.HidePanel(FriendsFrame)
    end
end

function WatchClientWindows()
    if windowWatch then return end
    windowWatch = CreateFrame("Frame")
    -- Many of the client's windows come with a piece of the interface
    -- that is only loaded the first time it is wanted, the macro window
    -- for one, and only then joins the client's panel list. The list of
    -- names here is put together afresh the moment anything loads, or
    -- the first opening of such a window went unseen until the list's
    -- next turn, seconds later.
    windowWatch:RegisterEvent("ADDON_LOADED")
    windowWatch:SetScript("OnEvent", function(self) self.names = nil end)
    windowWatch:SetScript("OnUpdate", function(self, elapsed)
        -- Every frame: a window of ours has to be gone the instant the
        -- client's is up, and the look is a few dozen IsShown calls.
        -- The list of names is put together now and then, not on every
        -- look: the client adds to its panel list as its pieces load.
        self.since = (self.since or 0) + elapsed
        if not self.names or self.since > 5 then
            self.since = 0
            local names, have = {}, {}
            local function Add(name)
                if type(name) == "string" and not have[name] then
                    have[name] = true
                    names[#names + 1] = name
                end
            end
            for name in pairs(UIPanelWindows or {}) do Add(name) end
            for _, name in ipairs(LOOSE_PANELS) do Add(name) end
            for _, name in ipairs(NPC_WINDOWS) do Add(name) end
            self.names = names
        end
        for _, name in ipairs(self.names) do
            local panel = _G[name]
            if type(panel) == "table" and panel.IsShown then
                local shown = panel:IsShown() and true or false
                -- The guild window standing open unseen under our roster
                -- (the note bridge) is not a window the player opened.
                if shown and ns.guildGhost and name == "CommunitiesFrame" then shown = false end
                if shown and not clientShown[name] then ClientWindowOpened(name, panel) end
                clientShown[name] = shown
            end
        end
    end)
end

function ns.HideClassicWindows(except)
    for frame in pairs(classicWindows) do
        if frame ~= except and frame:IsShown() then
            frame:Hide()
        end
    end
end

function ns.RegisterClassicWindow(frame)
    if not frame or classicWindows[frame] then return end
    classicWindows[frame] = true
    frame:HookScript("OnShow", function(self)
        ns.HideClassicWindows(self)
        HideClientPanels()
    end)
    WatchClientWindows()
end

-- Opening and closing a window during a fight. The client's own opener
-- begins with "in combat and not secure? tell the player an action was
-- blocked and do nothing", so every window an addon opens is refused
-- there, and the box on screen is the client's, not an error of ours.
-- A window that protects nothing can simply be shown where it stands;
-- one that holds the client's own protected pieces cannot be shown at
-- all from here, and is left alone rather than raising that box.
function ns.ShowPanel(frame)
    if not frame or frame:IsShown() then return true end
    if not InCombatLockdown() then
        if ShowUIPanel then ShowUIPanel(frame) else frame:Show() end
        return true
    end
    if frame.IsProtected and frame:IsProtected() then return false end
    frame:Show()
    return true
end

function ns.HidePanel(frame)
    if not frame or not frame:IsShown() then return true end
    if not InCombatLockdown() then
        if HideUIPanel then HideUIPanel(frame) else frame:Hide() end
        return true
    end
    if frame.IsProtected and frame:IsProtected() then return false end
    frame:Hide()
    return true
end

-- Whisper a name: the box opens with the line already written and the
-- cursor after it, ready to type. The client's own opener adds to
-- whatever was half typed in the box, which turned a whisper into a
-- line that began with a stray letter, so the box is emptied first and
-- the whole line written at once.
function ns.Whisper(name)
    if type(name) ~= "string" or name == "" then return end
    local box = (ChatEdit_ChooseBoxForSend and ChatEdit_ChooseBoxForSend(DEFAULT_CHAT_FRAME)) or ChatFrame1EditBox
    if not box then
        if ChatFrame_SendTell then ChatFrame_SendTell(name) end
        return
    end
    box:SetText("")
    if ChatEdit_ActivateChat then ChatEdit_ActivateChat(box) else box:Show() end
    box:SetText("/w " .. name .. " ")
    if box.SetCursorPosition and box.GetNumLetters then box:SetCursorPosition(box:GetNumLetters()) end
    box:SetFocus()
end

function ns.Path(frame, ...)
    local node = frame
    for i = 1, select("#", ...) do
        if type(node) ~= "table" then return nil end
        node = node[(select(i, ...))]
    end
    return node
end

function ns.SetPointOnce(region, ...)
    if not region then return end
    region:ClearAllPoints()
    region:SetPoint(...)
end

-- A texture created once on a frame, keyed so re-applies reuse it.
function ns.OwnTexture(frame, key, layer, sublevel)
    frame.fcui = frame.fcui or {}
    local tex = frame.fcui[key]
    if not tex then
        tex = frame:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
        frame.fcui[key] = tex
    end
    return tex
end

function ns.OwnFontString(frame, key, layer, font)
    frame.fcui = frame.fcui or {}
    local fs = frame.fcui[key]
    if not fs then
        fs = frame:CreateFontString(nil, layer or "OVERLAY", font or "GameFontHighlightSmall")
        frame.fcui[key] = fs
    end
    return fs
end

-- 1.x power colors. Blizzard's PowerBarColor still exists on both
-- clients and is used for anything not listed here.
ns.POWER_COLORS = {
    MANA = { 0, 0, 1 }, RAGE = { 1, 0, 0 }, FOCUS = { 1, 0.5, 0.25 }, ENERGY = { 1, 1, 0 },
    RUNIC_POWER = { 0, 0.82, 1 }, LUNAR_POWER = { 0.3, 0.52, 0.9 }, MAELSTROM = { 0, 0.5, 1 },
    INSANITY = { 0.4, 0, 0.8 }, FURY = { 0.788, 0.259, 0.992 }, PAIN = { 1, 0.61, 0 },
    AMMOSLOT = { 0.8, 0.6, 0 }, FUEL = { 0, 0.55, 0.5 },
}

function ns.PowerColor(unit)
    local powerType, token, altR, altG, altB = UnitPowerType(unit)
    if issecretvalue and (issecretvalue(token) or issecretvalue(powerType)) then return 0, 0, 1 end
    local c = token and ns.POWER_COLORS[token]
    if c then return c[1], c[2], c[3] end
    if altR and not (issecretvalue and issecretvalue(altR)) then return altR, altG, altB end
    local info = PowerBarColor and (PowerBarColor[token] or PowerBarColor[powerType])
    if info then return info.r, info.g, info.b end
    return 0, 0, 1
end

-- Secret values (12.x combat data) never reach a StatusBar.
function ns.SafeNumber(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- A StatusBar we own with the 1.x fill, under no mouse.
function ns.CreateBar(parent, key, width, height)
    parent.fcui = parent.fcui or {}
    local bar = parent.fcui[key]
    if not bar then
        bar = CreateFrame("StatusBar", nil, parent)
        bar:EnableMouse(false)
        parent.fcui[key] = bar
    end
    bar:SetSize(width, height)
    bar:SetStatusBarTexture((ns.TexPath("statusBar")))
    bar:GetStatusBarTexture():SetTexCoord(0, 1, 0, 1)
    -- A restore hides the bar; the next apply reuses it, so it shows again.
    bar:Show()
    return bar
end

-- Unit values are secret on 12.x even for the player. A StatusBar accepts
-- secret numbers directly; we only avoid doing arithmetic on them.
local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

local function FillBar(bar, value, max)
    if value == nil or max == nil then return end
    if not IsSecret(max) and max <= 0 then
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        return
    end
    bar:SetMinMaxValues(0, max)
    bar:SetValue(value)
end

-- The health bar's color: the old green, or the unit's class color
-- when the toggle asks for it and the unit is a player.
function ns.HealthColor(unit)
    if ns.db and ns.db.classColorHealth and unit and UnitIsPlayer and UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if color then return color.r, color.g, color.b end
    end
    return 0, 1, 0
end

function ns.SetHealth(bar, unit)
    FillBar(bar, UnitHealth(unit), UnitHealthMax(unit))
    bar:SetStatusBarColor(ns.HealthColor(unit))
end

function ns.SetPower(bar, unit)
    FillBar(bar, UnitPower(unit), UnitPowerMax(unit))
    bar:SetStatusBarColor(ns.PowerColor(unit))
end

-- A slider dressed as the old scroll bar, with its two arrow buttons.
function ns.ClassicScrollBar(parent, anchorTo, onValue)
    local bar = CreateFrame("Slider", nil, parent)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(16)
    bar:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 6, -16)
    bar:SetPoint("BOTTOMLEFT", anchorTo, "BOTTOMRIGHT", 6, 16)
    local thumb = bar:CreateTexture(nil, "ARTWORK")
    ns.SetTex(thumb, "scrollKnob")
    thumb:SetSize(18, 24)
    thumb:SetTexCoord(0.2, 0.8, 0.125, 0.875)
    bar:SetThumbTexture(thumb)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)

    local function Arrow(kind, point, relPoint)
        local button = CreateFrame("Button", nil, bar)
        button:SetSize(16, 16)
        button:SetPoint(point, bar, relPoint, 0, 0)
        ns.SetButtonTex(button, "Normal", "scroll" .. kind .. "ButtonUp")
        ns.SetButtonTex(button, "Pushed", "scroll" .. kind .. "ButtonDown")
        ns.SetButtonTex(button, "Disabled", "scroll" .. kind .. "ButtonDisabled")
        ns.SetButtonTex(button, "Highlight", "scroll" .. kind .. "ButtonHighlight")
        button:GetHighlightTexture():SetBlendMode("ADD")
        -- The sheets are 32x32 with the 16x16 arrow in the middle.
        for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
            local tex = button["Get" .. state .. "Texture"](button)
            if tex then tex:SetTexCoord(0.25, 0.75, 0.25, 0.75) end
        end
        return button
    end
    bar.up = Arrow("Up", "BOTTOM", "TOP")
    bar.down = Arrow("Down", "TOP", "BOTTOM")
    bar.up:SetScript("OnClick", function() bar:SetValue(bar:GetValue() - bar.step) PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON) end)
    bar.down:SetScript("OnClick", function() bar:SetValue(bar:GetValue() + bar.step) PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON) end)
    bar.step = 1

    function bar:SetRange(max, step)
        self.step = step or 1
        max = math.max(0, max)
        local value = self:GetValue()
        self:SetMinMaxValues(0, max)
        self:SetValue(math.min(value, max))
        -- The arrows are always there, grayed when there is nothing to
        -- scroll; only the knob goes. A list that asks for it has no
        -- bar at all until there is something to scroll.
        self:SetShown(not self.hideWhenIdle or max > 0)
        local thumb = self:GetThumbTexture()
        if thumb then thumb:SetShown(max > 0) end
        self:Refresh()
    end
    function bar:Refresh()
        local _, max = self:GetMinMaxValues()
        local value = self:GetValue()
        self.up:SetEnabled(value > 0)
        self.down:SetEnabled(value < max)
    end
    bar:SetScript("OnValueChanged", function(self, value)
        self:Refresh()
        onValue(value)
    end)
    return bar
end
