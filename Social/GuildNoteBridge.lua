local _, ns = ...

-- The guild note bridge: taint-critical, do not touch. Roster state comes from ns.guild.

local G = ns.guild
local IsSecret, Safe = ns.IsSecret, ns.Safe
local ShowOffline = G.ShowOffline
local Row_OnClick, Row_OnDoubleClick = G.Row_OnClick, G.Row_OnDoubleClick
local DockNotes, SyncBridge

---------------------------------------------------------------- the note bridge

-- Note saves are the client's alone: refused by guid, and its own dialog
-- opened from here is refused at Accept. It saves when every step is its
-- own: its row clicked, its member frame shown, its note box clicked, its
-- dialog accepted. So, out of combat with the roster up, the client's guild
-- window stays open unseen (alpha 0, off screen, a row per member). A secure
-- pad over each of our rows clicks the client's row for that member; its
-- member frame, docked beside the roster, is the only member status window.
-- Pads hang from UIParent by measure: a secure child would make the roster
-- protected in combat.
local bridge = { pads = {}, rows = {} }
local GHOST_ROWS_MAX = 500     -- cap on the ghost window's rows
local CLIENT_ROW_H = 20        -- client member list row height

local function ClientDetail()
    return CommunitiesFrame and CommunitiesFrame.GuildMemberDetailFrame
end

local function HidePads()
    local rows = G.panel and G.panel.rows
    if rows then
        for _, row in ipairs(rows) do row:UnlockHighlight() end
    end
    if InCombatLockdown() then return end
    for _, pad in ipairs(bridge.pads) do
        if pad:IsShown() then pad:Hide() end
    end
end

-- The member a client row or member frame shows now; nil when unreadable.
local function ShownGuid(frame)
    local ok, info = pcall(frame.GetMemberInfo, frame)
    local guid = ok and info and info.guid
    if guid and not IsSecret(guid) then return guid end
end

-- Remade on each redraw of the client's list, which reassigns every row frame.
local function ClientProvider()
    local list = CommunitiesFrame and CommunitiesFrame.MemberList
    local box = list and list.ScrollBox
    if not box or not box.GetDataProvider then return end
    local ok, provider = pcall(box.GetDataProvider, box)
    return ok and provider or nil
end

-- Classic art on the client's member frame: calls on its art pieces only,
-- none of the frame's own fields read or written.
local function DressDetail(detail)
    if bridge.dressed then return end
    bridge.dressed = true
    local border = detail.Border
    if border and border.GetRegions then
        for _, region in ipairs({ border:GetRegions() }) do
            if region ~= border.Bg then ns.DrainBronze(region) end
        end
    end
    -- Note box borders go white per region, not via the boxes' backdrop
    -- calls, which would write on the frames a note is saved from.
    for _, box in ipairs({ detail.NoteBackground, detail.OfficerNoteBackground }) do
        for _, holder in ipairs({ box, box and box.NineSlice }) do
            if holder and holder.GetRegions then
                local center = holder.Center
                for _, region in ipairs({ holder:GetRegions() }) do
                    if region ~= center then ns.DrainBronze(region, 1, 1, 1) end
                end
            end
        end
    end
    if ns.SkinCloseButton then pcall(ns.SkinCloseButton, detail.CloseButton, true) end
    if ns.SkinRedButton then
        pcall(ns.SkinRedButton, detail.RemoveButton)
        pcall(ns.SkinRedButton, detail.GroupInviteButton)
    end
end

-- The member frame back on the client's window, as the client made it.
local function ParkDetail()
    local detail = ClientDetail()
    if not detail or not bridge.docked then return end
    bridge.docked = nil
    detail:Hide()
    detail:SetParent(CommunitiesFrame)
    detail:SetFrameStrata(CommunitiesFrame:GetFrameStrata())
    detail:SetFrameLevel(1000)
    ns.SetPointOnce(detail, "TOPLEFT", CommunitiesFrame, "TOPRIGHT", -8, -76)
end

-- Never taint the client's guild window: shown or club-picked by a plain
-- call, its fields become ours and its later protected calls are refused
-- (blocked-action errors in its community list; note saves too). Only the
-- panel manager's secure delegate leaves no mark, so the window is shown and
-- hidden only through ShowUIPanel/HideUIPanel, the guild is picked by the
-- CVar it reads as it opens, and nothing on it is called from here.
local GHOST_X = 4000           -- offset past the screen's right edge
local GHOST_LIST_OVERHEAD = 91 -- window height outside its member list

local function GhostHeight()
    -- Only the rows the client lists (online only unless Show Offline):
    -- each is a live client row, redrawn on every roster change.
    local members, online = 0, 0
    if GetNumGuildMembers then members, online = GetNumGuildMembers() end
    members, online = Safe(members, 0), Safe(online, 0)
    if not ShowOffline() then members = online end
    -- A row per member only while the mouse is on our rows (see Tall): the client redraws every one on each update.
    if not bridge.tall then members = 0 end
    return GHOST_LIST_OVERHEAD + (math.min(members, GHOST_ROWS_MAX) + 12) * CLIENT_ROW_H
end

local function PlaceGhost(frame)
    local _, _, _, x = frame:GetPoint(1)
    if frame:GetNumPoints() ~= 1 or x ~= GHOST_X then
        ns.SetPointOnce(frame, "TOPLEFT", UIParent, "TOPRIGHT", GHOST_X, 0)
    end
end

-- The client's window restored as found.
local function DropGhost()
    HidePads()
    if not bridge.ghost then return end
    local frame, keep = CommunitiesFrame, bridge.keep
    bridge.ghost, bridge.keep, bridge.live = nil, nil, nil
    wipe(bridge.rows)
    if frame and keep then
        ParkDetail()
        local detail = ClientDetail()
        if detail then detail:Hide() end
        if frame:IsShown() and HideUIPanel then pcall(HideUIPanel, frame) end
        frame:SetAttribute("UIPanelLayout-width", keep.widthAttr)
        frame:SetSize(keep.width, keep.height)
        frame:SetAlpha(keep.alpha)
    end
    ns.guildGhost = nil
end

-- The ghost window up on the guild's member list; false if the player has
-- that window open or the client refuses panels right now.
local function RaiseGhost()
    -- Never in combat: the client refuses to open its window for an addon
    -- and shows the blocked-action message. Notes wait for the fight's end.
    if InCombatLockdown() then return false end
    local frame = CommunitiesFrame
    if not frame or not frame.MemberList or not ClientDetail() or not ShowUIPanel then return false end
    if bridge.ghost then
        if not frame:IsShown() then
            -- Closed by something else: undo our changes.
            DropGhost()
            return false
        end
        PlaceGhost(frame)
        local height = GhostHeight()
        if math.abs(height - frame:GetHeight()) > 1 then
            frame:SetHeight(height)
            -- Its rows change with its height.
            bridge.stale = true
        end
        return true
    end
    if frame:IsShown() then return false end
    local now = GetTime()
    if bridge.retryAt and now < bridge.retryAt then return false end
    local clubId = C_Club and C_Club.GetGuildClubId and C_Club.GetGuildClubId()
    if not clubId then return false end
    bridge.keep = {
        alpha = frame:GetAlpha(), width = frame:GetWidth(), height = frame:GetHeight(),
        strata = frame:GetFrameStrata(), widthAttr = frame:GetAttribute("UIPanelLayout-width"),
    }
    bridge.ghost = true
    ns.guildGhost = true
    frame:SetAlpha(0)
    -- Tall before it opens, so the window's own opening makes every row.
    frame:SetHeight(GhostHeight())
    -- 1 wide: the manager stands it beside the social window instead of closing that.
    frame:SetAttribute("UIPanelLayout-width", 1)
    -- The window opens on the club this CVar names; written only when it names another.
    if tonumber(ns.GetCVar("lastSelectedClubId")) ~= clubId then
        if SetCVar then pcall(SetCVar, "lastSelectedClubId", clubId) end
    end
    pcall(ShowUIPanel, frame)
    if not frame:IsShown() then
        DropGhost()
        bridge.retryAt = now + 2
        return false
    end
    PlaceGhost(frame)
    return true
end

-- The client's rows keyed by member guid.
local function ReadClientRows()
    wipe(bridge.rows)
    local frame = CommunitiesFrame
    local box = frame.MemberList.ScrollBox
    bridge.provider = ClientProvider()
    if not box or not box.ForEachFrame then return end
    if C_Club and frame.GetSelectedClubId and frame:GetSelectedClubId() ~= C_Club.GetGuildClubId() then return end
    box:ForEachFrame(function(row)
        if row.isInvitation then return end
        local guid = ShownGuid(row)
        if guid then bridge.rows[guid] = row end
    end)
end

-- Tall while the mouse is on our rows or their pads; short a second after it leaves the list.
local function TallSync()
    if G.panel and G.panel:IsVisible() then SyncBridge() end
end
local function Tall(on)
    if bridge.tall == on then return end
    bridge.tall = on
    ns.Sched.NextFrame("guild.tall", TallSync)
end
local function RowsEntered() Tall(true) end
local function ShortIfGone()
    local list = G.panel and G.panel.list
    if not (list and list:IsVisible() and list:IsMouseOver()) then Tall(false) end
end
local function RowsLeft() ns.Sched.AfterPerFrame("guild.short", 1, ShortIfGone) end

local lastPadClick = {}
local function Pad(index)
    local pad = bridge.pads[index]
    if pad then return pad end
    pad = CreateFrame("Button", "ClassicUIForeverGuildRowPad" .. index, UIParent, "SecureActionButtonTemplate")
    pad:SetAttribute("type1", "click")
    pad:SetAttribute("useOnKeyDown", false)
    pad:RegisterForClicks("AnyUp", "AnyDown")
    pad:Hide()
    -- No art of its own: it lights our row, so a pad outliving the roster draws nothing.
    pad:SetScript("OnEnter", function()
        local row = G.panel and G.panel.rows[index]
        if row and row:IsVisible() then
            row:LockHighlight()
            RowsEntered()
        elseif not InCombatLockdown() then
            pad:Hide()
        end
    end)
    pad:SetScript("OnLeave", function()
        local row = G.panel and G.panel.rows[index]
        if row then row:UnlockHighlight() end
        RowsLeft()
    end)
    -- The client's row is pressed by now; our row under the pad takes the click as usual.
    pad:SetScript("PostClick", function(_, button, down)
        if down then return end
        local row = G.panel and G.panel.rows[index]
        if not row or not row.entry or not row:IsVisible() then return end
        local now = GetTime()
        if button == "LeftButton" and lastPadClick.entry == row.entry and now - (lastPadClick.at or 0) < 0.4 then
            lastPadClick.entry = nil
            Row_OnDoubleClick(row)
            return
        end
        lastPadClick.entry, lastPadClick.at = row.entry, now
        Row_OnClick(row, button)
    end)
    bridge.pads[index] = pad
    return pad
end

local function PlacePads()
    if InCombatLockdown() or not G.panel then return end
    local scale = UIParent:GetEffectiveScale()
    bridge.padLeft, bridge.padTop = G.panel.list:GetLeft(), G.panel.list:GetTop()
    for index, row in ipairs(G.panel.rows) do
        local entry = row:IsVisible() and row.entry
        local theirs = entry and entry.guid and bridge.rows[entry.guid]
        -- A client row redrawn for someone else since the read would open the wrong member.
        if theirs and ShownGuid(theirs) ~= entry.guid then theirs = nil end
        local left, bottom = row:GetLeft(), row:GetBottom()
        if theirs and left and bottom then
            local pad = Pad(index)
            if pad.target ~= theirs then
                pad:SetAttribute("clickbutton", theirs)
                pad.target = theirs
            end
            local ratio = row:GetEffectiveScale() / scale
            -- HIGH strata, not a level above the row: the social window raises
            -- itself in its strata on every click, over a level-matched pad.
            pad:SetFrameStrata("HIGH")
            ns.SetPointOnce(pad, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * ratio, bottom * ratio)
            pad:SetSize(row:GetWidth() * ratio, row:GetHeight() * ratio)
            if not pad:IsShown() then pad:Show() end
        else
            -- No client row yet for a visible member: reread next tick.
            if entry and entry.guid then bridge.stale = true end
            local pad = bridge.pads[index]
            if pad and pad:IsShown() then pad:Hide() end
        end
    end
end

-- Docks the client's member frame beside the roster while it shows our
-- selected member, parks it otherwise.
DockNotes = function()
    local detail = ClientDetail()
    local host = G.panel and G.panel:GetParent()
    local selected = G.selected
    local live
    if bridge.ghost and detail and host and selected and detail:IsShown() and G.panel:IsVisible() then
        local guid = ShownGuid(detail)
        -- Unreadable for a moment while the roster redraws: what is docked stays.
        if guid == selected or (guid == nil and bridge.live == selected) then live = selected end
    end
    if live then
        if not bridge.docked then
            bridge.docked = true
            -- Off the ghost window: left on it, it stays unseen and unclickable.
            detail:SetParent(UIParent)
            detail:SetFrameStrata("HIGH")
            ns.SetPointOnce(detail, "TOPLEFT", host, "TOPRIGHT", -6, -70)
            detail:SetAlpha(1)
            DressDetail(detail)
        end
    elseif bridge.docked then
        ParkDetail()
    end
    bridge.live = live
end

-- Up whenever the roster is, out of combat: the client's member frame is the only status window.
SyncBridge = function()
    local want = G.active and G.panel and G.panel:IsVisible() and IsInGuild and IsInGuild()
    if not want then
        if bridge.ghost then DropGhost() end
        return
    end
    if not InCombatLockdown() then
        if RaiseGhost() then
            -- Reread client rows when stale, redrawn (row frames reassigned) or every 2 s.
            local now = GetTime()
            if bridge.stale or ClientProvider() ~= bridge.provider or now - (bridge.readAt or 0) > 2 then
                bridge.stale, bridge.readAt = nil, now
                ReadClientRows()
            end
            PlacePads()
        else
            HidePads()
        end
    end
    DockNotes()
end

-- The client redrew its list or the roster moved: the pads must follow before the next click.
local function PadsDrifted()
    local list = G.panel and G.panel.list
    if not list or InCombatLockdown() then return false end
    return ClientProvider() ~= bridge.provider or list:GetLeft() ~= bridge.padLeft or list:GetTop() ~= bridge.padTop
end

-- In combat the pads are the client's to hide; this fires just before, while they are ours.
ns.EventFrame("PLAYER_REGEN_DISABLED", HidePads)

-- Every frame: the panel manager puts the window back on screen on each relayout (moved straight off), and a drift re-syncs.
local function BridgeFrame()
    if bridge.ghost and CommunitiesFrame and CommunitiesFrame:IsShown() then PlaceGhost(CommunitiesFrame) end
    return bridge.ghost and PadsDrifted()
end

local function BridgeBeat()
    if bridge.ghost or (G.active and G.panel and G.panel:IsVisible()) then SyncBridge() end
    if not (G.panel and G.panel:IsVisible()) then HidePads() end
end

-- Pads a fight kept up (the roster shut meanwhile) go as it ends.
ns.EventFrame("PLAYER_REGEN_ENABLED", function() ns.Sched.NextFrame("guild.bridge", BridgeBeat) end)

local function BridgeShown(shown)
    if not shown then ns.Sched.NextFrame("guild.bridge", BridgeBeat) end
end

-- Only while the roster shows, 0.25 s beat; its hide drops the ghost the frame after.
function G.WatchBridge(panel)
    ns.Sched.Attach(panel, { name = "guild.bridge", every = 0.25, pre = BridgeFrame, fn = BridgeBeat })
    for _, row in ipairs(panel.rows or {}) do
        ns.HookScriptOnce(row, "OnEnter", RowsEntered)
        ns.HookScriptOnce(row, "OnLeave", RowsLeft)
    end
    ns.Sched.OnVisible(panel, "guild.bridge", BridgeShown)
end

G.bridge, G.DropGhost, G.SyncBridge = bridge, DropGhost, SyncBridge

-- The MOTD pad; Build calls this at its place in the build order.
function G.BuildMotdPad(panel)
    -- Addons may not set the MOTD; the client's editor may when its own Edit
    -- button is pressed, so a secure pad over the message clicks that button.
    -- Hung from UIParent by measure (a secure child would protect the roster
    -- in combat); shown only with the roster up, out of combat, for editors.
    local pad
    local function EditButton()
        local frame = CommunitiesFrame
        local info = frame and frame.GuildDetailsFrame and frame.GuildDetailsFrame.Info
        return info and info.EditMOTDButton
    end
    local function MayEdit()
        if CanEditMOTD then return CanEditMOTD() and true or false end
        return C_GuildInfo and C_GuildInfo.CanEditMOTD and C_GuildInfo.CanEditMOTD() and true or false
    end
    local function MotdTick()
        if InCombatLockdown() then return end
        local want = G.active and panel:IsVisible() and MayEdit()
        if want and not pad then
            local button = EditButton()
            if not button then return end
            pad = CreateFrame("Button", "ClassicUIForeverMotdPad", UIParent, "SecureActionButtonTemplate")
            pad:SetAttribute("type", "click")
            pad:SetAttribute("clickbutton", button)
            pad:SetAttribute("useOnKeyDown", false)
            pad:RegisterForClicks("AnyUp", "AnyDown")
            pad:SetFrameStrata("HIGH")
            pad:Hide()
        end
        if not pad then return end
        if not want then
            if pad:IsShown() then pad:Hide() end
            return
        end
        local box = panel.motdBox
        local left, bottom = box:GetLeft(), box:GetBottom()
        if not left or not bottom then return end
        local ratio = box:GetEffectiveScale() / UIParent:GetEffectiveScale()
        ns.SetPointOnce(pad, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * ratio, bottom * ratio)
        pad:SetSize(box:GetWidth() * ratio, box:GetHeight() * ratio)
        if not pad:IsShown() then pad:Show() end
    end
    -- 5 Hz while the roster shows; its hide takes the pad down the frame after, or once a fight ends.
    ns.Sched.Attach(panel, { name = "guild.motd", every = 0.2, fn = MotdTick })
    ns.Sched.OnVisible(panel, "guild.motd", function(shown)
        if not shown then ns.Sched.NextFrame("guild.motd", function() ns.WhenCalm("guild.motd", MotdTick) end) end
    end)
end
