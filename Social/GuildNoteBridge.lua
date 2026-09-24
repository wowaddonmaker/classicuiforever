local _, ns = ...

-- The guild note bridge: taint-critical, do not touch. Roster state comes from ns.guild.

local G = ns.guild
local IsSecret, Safe = ns.IsSecret, ns.Safe
local ShowOffline, SelectedEntry = G.ShowOffline, G.SelectedEntry
local Row_OnClick, Row_OnDoubleClick = G.Row_OnClick, G.Row_OnDoubleClick
local DockNotes, SyncBridge

---------------------------------------------------------------- the note bridge

-- Note saves are the client's alone: refused by guid, and its own dialog
-- opened from here is refused at Accept. It saves when every step is its
-- own: its row clicked, its member frame shown, its note box clicked, its
-- dialog accepted. So, out of combat with the roster up, the client's guild
-- window stays open unseen (alpha 0, off screen, a row per member). A secure
-- pad over each of our rows clicks the client's row for that member; its
-- member frame is docked beside the roster in place of our pane, which shows
-- only in combat or for a member the window has no row for.
-- Pads hang from UIParent by measure: a secure child would make the roster
-- protected in combat.
local bridge = { pads = {}, rows = {} }
local GHOST_ROWS_MAX = 500     -- cap on the ghost window's rows
local CLIENT_ROW_H = 20        -- client member list row height

local function ClientDetail()
    return CommunitiesFrame and CommunitiesFrame.GuildMemberDetailFrame
end

local function HidePads()
    if InCombatLockdown() then return end
    for _, pad in ipairs(bridge.pads) do
        if pad:IsShown() then pad:Hide() end
    end
    if bridge.NotePad then bridge.NotePad:Hide() end
    if bridge.OfficerPad then bridge.OfficerPad:Hide() end
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
    detail:ClearAllPoints()
    detail:SetPoint("TOPLEFT", CommunitiesFrame, "TOPRIGHT", -8, -76)
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
    return GHOST_LIST_OVERHEAD + (math.min(members, GHOST_ROWS_MAX) + 12) * CLIENT_ROW_H
end

local function PlaceGhost(frame)
    local _, _, _, x = frame:GetPoint(1)
    if frame:GetNumPoints() ~= 1 or x ~= GHOST_X then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "TOPRIGHT", GHOST_X, 0)
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
ns.DropGuildGhost = DropGhost

-- The ghost window up on the guild's member list; false if the player has
-- that window open or the client refuses panels right now.
local function RaiseGhost()
    -- Never in combat: the client refuses to open its window for an addon
    -- and shows the blocked-action message. Notes wait for the fight's end.
    if InCombatLockdown() then return false end
    if not CommunitiesFrame and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_Communities")
    end
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
        if height > frame:GetHeight() + 1 then frame:SetHeight(height) end
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
    -- The window opens on the club this CVar names.
    if SetCVar then pcall(SetCVar, "lastSelectedClubId", clubId) end
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
    if not box or not box.ForEachFrame then return end
    if C_Club and frame.GetSelectedClubId and frame:GetSelectedClubId() ~= C_Club.GetGuildClubId() then return end
    box:ForEachFrame(function(row)
        if row.isInvitation or not row.GetMemberInfo then return end
        local info = row:GetMemberInfo()
        local guid = info and info.guid
        if guid and not IsSecret(guid) then bridge.rows[guid] = row end
    end)
end

local lastPadClick = {}
local function Pad(index)
    local pad = bridge.pads[index]
    if pad then return pad end
    pad = CreateFrame("Button", "ClassicUIForeverGuildRowPad" .. index, UIParent, "SecureActionButtonTemplate")
    pad:SetAttribute("type1", "click")
    pad:SetAttribute("useOnKeyDown", false)
    pad:RegisterForClicks("AnyUp", "AnyDown")
    pad:Hide()
    local highlight = pad:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(pad)
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
    highlight:SetBlendMode("ADD")
    highlight:SetVertexColor(1, 0.82, 0, 1)
    highlight:SetTexCoord(0, 0.97, 0, 1)
    -- The client's row is pressed by now; our row under the pad takes the click as usual.
    pad:SetScript("PostClick", function(_, button, down)
        if down then return end
        local row = G.panel and G.panel.rows[index]
        if not row or not row.entry then return end
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

-- A member picked before the client's rows came (a moment after the window
-- opens) or in combat leaves our pane up; a pad over each of our note boxes
-- clicks the client's row, and its member frame replaces our pane at once.
local function NotePad(key)
    local pad = bridge[key]
    if pad then return pad end
    pad = CreateFrame("Button", "ClassicUIForeverGuild" .. key, UIParent, "SecureActionButtonTemplate")
    pad:SetAttribute("type1", "click")
    pad:SetAttribute("useOnKeyDown", false)
    pad:RegisterForClicks("AnyUp", "AnyDown")
    pad:Hide()
    pad:SetScript("PostClick", function(_, _, down)
        if down then return end
        SyncBridge()
    end)
    bridge[key] = pad
    return pad
end

local function PlaceNotePads()
    local out = G.panel and G.panel.popout
    local entry = SelectedEntry()
    local theirs = out and out:IsVisible() and entry and entry.guid and not bridge.live and bridge.rows[entry.guid]
    local scale = UIParent:GetEffectiveScale()
    for key, box in pairs({ NotePad = out and out.noteBox, OfficerPad = out and out.officerBox }) do
        local left, bottom = box and box:GetLeft(), box and box:GetBottom()
        if theirs and box:IsVisible() and box.mayEdit and left and bottom then
            local pad = NotePad(key)
            if pad.target ~= theirs then
                pad:SetAttribute("clickbutton", theirs)
                pad.target = theirs
            end
            local ratio = box:GetEffectiveScale() / scale
            pad:SetFrameStrata("HIGH")
            pad:ClearAllPoints()
            pad:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * ratio, bottom * ratio)
            pad:SetSize(box:GetWidth() * ratio, box:GetHeight() * ratio)
            if not pad:IsShown() then pad:Show() end
        elseif bridge[key] and bridge[key]:IsShown() then
            bridge[key]:Hide()
        end
    end
end

local function PlacePads()
    if InCombatLockdown() or not G.panel then return end
    local scale = UIParent:GetEffectiveScale()
    for index, row in ipairs(G.panel.rows) do
        local entry = row:IsVisible() and row.entry
        local theirs = entry and entry.guid and bridge.rows[entry.guid]
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
            pad:ClearAllPoints()
            pad:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * ratio, bottom * ratio)
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

-- Docks the client's member frame beside the roster (our pane hidden) while
-- it shows our selected member, parks it otherwise. True when that changed.
DockNotes = function()
    local detail = ClientDetail()
    local out = G.panel and G.panel.popout
    local host = out and out:GetParent()
    local entry = SelectedEntry()
    local live
    if bridge.ghost and detail and host and detail:IsShown() and G.panel:IsVisible() and entry and entry.guid then
        local ok, info = pcall(detail.GetMemberInfo, detail)
        local guid = ok and info and info.guid
        if guid and not IsSecret(guid) and guid == entry.guid then live = guid end
    end
    local was = bridge.live
    if live then
        if not bridge.docked then
            bridge.docked = true
            -- Off the ghost window: left on it, it stays unseen and unclickable.
            detail:SetParent(UIParent)
            detail:SetFrameStrata("HIGH")
            detail:ClearAllPoints()
            detail:SetPoint("TOPLEFT", host, "TOPRIGHT", -6, -70)
            detail:SetAlpha(1)
            DressDetail(detail)
        end
        if out:IsShown() then out:Hide() end
    elseif bridge.docked then
        ParkDetail()
    end
    bridge.live = live
    return was ~= live
end

-- True when a note box click leads somewhere: the client's box or a pad lies over ours.
function ns.GuildNotesLive(entry)
    if bridge.live ~= nil then return true end
    return bridge.ghost and entry and entry.guid and bridge.rows[entry.guid] and not InCombatLockdown() and true or false
end

-- May the player write any note (by rank, or their own when selected)? The
-- ghost window is costly and only for notes, so it is raised only then.
local function MayWriteNotes()
    if CanEditPublicNote and CanEditPublicNote() then return true end
    if C_GuildInfo and C_GuildInfo.CanEditOfficerNote and C_GuildInfo.CanEditOfficerNote() then return true end
    if CanEditOfficerNote and CanEditOfficerNote() then return true end
    local entry = SelectedEntry()
    return entry ~= nil and entry.name == UnitName("player")
end

SyncBridge = function()
    local want = G.active and G.panel and G.panel:IsVisible() and IsInGuild and IsInGuild() and MayWriteNotes()
    if not want then
        if bridge.ghost then DropGhost() end
        return
    end
    if not InCombatLockdown() then
        if RaiseGhost() then
            -- Reread client rows when stale (roster changed, a row missed) or every 2 s.
            local now = GetTime()
            if bridge.stale or now - (bridge.readAt or 0) > 2 then
                bridge.stale, bridge.readAt = nil, now
                ReadClientRows()
            end
            PlacePads()
        else
            HidePads()
        end
    end
    if DockNotes() and ns.UpdateGuildPopout then ns.UpdateGuildPopout(true) end
    if not InCombatLockdown() and bridge.ghost then PlaceNotePads() end
end

local bridgeWatch = CreateFrame("Frame")
bridgeWatch:RegisterEvent("PLAYER_REGEN_DISABLED")
-- In combat the pads are the client's to hide; this fires just before, while they are ours.
bridgeWatch:SetScript("OnEvent", HidePads)
bridgeWatch:SetScript("OnUpdate", function(self, elapsed)
    -- The panel manager puts the window back on screen on each relayout: move it straight off.
    if bridge.ghost and CommunitiesFrame and CommunitiesFrame:IsShown() then PlaceGhost(CommunitiesFrame) end
    self.since = (self.since or 0) + elapsed
    if self.since < 0.25 then return end
    self.since = 0
    if bridge.ghost or (G.active and G.panel and G.panel:IsVisible()) then SyncBridge() end
end)

G.bridge, G.DropGhost, G.DockNotes, G.SyncBridge = bridge, DropGhost, DockNotes, SyncBridge

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
    -- 5 Hz on the scheduler.
    ns.Sched.Job({ name = "guild.motd", every = 0.2, fn = function()
        if InCombatLockdown() then return end
        local want = G.active and panel:IsVisible() and MayEdit()
        if want and not pad then
            -- The editor lives in a load-on-demand addon.
            if not EditButton() and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_Communities") end
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
        pad:ClearAllPoints()
        pad:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * ratio, bottom * ratio)
        pad:SetSize(box:GetWidth() * ratio, box:GetHeight() * ratio)
        if not pad:IsShown() then pad:Show() end
    end })
end
