local _, ns = ...

-- The member card: our copy of the client's member window for a fight, when its rows take no clicks (the pads are
-- down). Never on screen with the client's: it opens only while that one is off screen and closes as that one docks.

local G, S = ns.guild, ns.social
local Safe = ns.Safe

-- The client's member window (Blizzard_Communities GuildRoster.xml and .lua).
local CARD_W, CARD_H, CARD_OFFICER_H = 212, 175, 228
local NOTE_W, NOTE_H = 181, 40
local NOTE_FILL_ALPHA = 0.25
local NOTE_GREY = 0.65
local VALUE_ROWS = {
    { key = "Zone", label = ZONE_COLON or "Zone:", gap = -11, w = 147 },
    { key = "Rank", label = RANK_COLON or "Rank:", gap = -8 },
    { key = "Online", label = LAST_ONLINE_COLON or "Last Online:", gap = -8 },
}

local card

ns.Popup("FCUI_GUILD_REMOVE", {
    text = REMOVE_GUILDMEMBER_LABEL or "Remove %s from the guild?",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function(_, name)
        if name and C_GuildInfo and C_GuildInfo.Uninvite then C_GuildInfo.Uninvite(name) end
    end,
})

-- Where the member window stands beside the social window, the client's and ours alike.
function G.DockMemberWindow(frame, host)
    ns.SetPointOnce(frame, "TOPLEFT", host, "TOPRIGHT", -6, -70)
end

local function DrainPiece(region, fill)
    if region ~= fill then ns.DrainBronze(region) end
end

-- Note box rims go white per region, not via the boxes' backdrop calls (the client saves notes from those).
local function WhitenPiece(region, fill)
    if region ~= fill then ns.DrainBronze(region, 1, 1, 1) end
end

local function WhitenBox(box)
    if not box then return end
    ns.EachRegion(box, WhitenPiece, box.Center)
    if box.NineSlice then ns.EachRegion(box.NineSlice, WhitenPiece, box.NineSlice.Center) end
end

-- Classic art on a member window, the client's or ours: calls on its art pieces only.
function G.DressMemberWindow(frame)
    if frame.Border then ns.EachRegion(frame.Border, DrainPiece, frame.Border.Bg) end
    WhitenBox(frame.NoteBackground)
    WhitenBox(frame.OfficerNoteBackground)
    if ns.SkinCloseButton then pcall(ns.SkinCloseButton, frame.CloseButton, true) end
    if ns.SkinRedButton then
        pcall(ns.SkinRedButton, frame.RemoveButton)
        pcall(ns.SkinRedButton, frame.GroupInviteButton)
    end
end

-- The client's member window where the player sees it: docked, or on its own guild window (the ghost draws nothing).
local function ClientCardShown()
    local detail = CommunitiesFrame and CommunitiesFrame.GuildMemberDetailFrame
    if not (detail and detail:IsVisible()) then return false end
    return Safe(detail:GetEffectiveAlpha(), 1) > 0
end

local function HideCard()
    if card and card:IsShown() then card:Hide() end
end
G.HideMemberCard = HideCard

local function SelectedEntry()
    local key = G.selected
    if key == nil then return nil end
    for _, entry in ipairs(G.roster) do
        if G.EntryKey(entry) == key then return entry end
    end
end

-- The player's own roster line; GetGuildInfo is refused in a fight.
local function MyEntry()
    local guid = Safe(UnitGUID("player"), nil)
    if not guid then return nil end
    for _, entry in ipairs(G.roster) do
        if entry.guid == guid then return entry end
    end
end

local function Can(fn) return fn ~= nil and fn() and true or false end

local function NoteBox(parent, label)
    local box = ns.NewFrame("Frame", nil, parent, "TooltipBackdropTemplate")
    box:SetSize(NOTE_W, NOTE_H)
    box:SetPoint("TOPLEFT", label, "BOTTOMLEFT", -2, 0)
    local fill = TOOLTIP_DEFAULT_BACKGROUND_COLOR
    if fill and box.SetBackdropColor then
        local r, g, b = fill:GetRGB()
        box:SetBackdropColor(r, g, b, NOTE_FILL_ALPHA)
    end
    box.Text = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    box.Text:SetSize(NOTE_W - 16, NOTE_H - 8)
    box.Text:SetPoint("TOP", box, "TOP", 1, -6)
    box.Text:SetJustifyH("LEFT")
    box.Text:SetJustifyV("TOP")
    return box
end

local function FootButton(parent, text)
    local button = ns.NewFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(96, 22)
    button:SetText(text)
    return button
end

local function Card()
    if card then return card end
    card = ns.NewFrame("Frame", "ClassicUIForeverGuildMemberCard", G.panel)
    card:SetSize(CARD_W, CARD_H)
    card:SetFrameStrata("HIGH")
    card:EnableMouse(true)
    -- UIParent's scale, as the docked client window has, whatever the social window's own.
    card:SetIgnoreParentScale(true)
    card:Hide()

    card.Name = card:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    card.Name:SetWidth(165)
    card.Name:SetJustifyH("LEFT")
    card.Name:SetPoint("TOPLEFT", card, "TOPLEFT", 17, -18)
    card.Level = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    card.Level:SetPoint("TOPLEFT", card.Name, "BOTTOMLEFT", 0, -2)

    local above = card.Level
    for _, row in ipairs(VALUE_ROWS) do
        local label = card:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, row.gap)
        label:SetText(row.label)
        local value = card:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        value:SetPoint("LEFT", label, "RIGHT", 2, 0)
        value:SetJustifyH("LEFT")
        if row.w then value:SetSize(row.w, 12) end
        card[row.key .. "Label"], card[row.key .. "Text"] = label, value
        above = label
    end

    card.NoteLabel = card:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    card.NoteLabel:SetPoint("TOPLEFT", card.OnlineLabel, "BOTTOMLEFT", 0, -8)
    card.NoteLabel:SetText(NOTE_COLON or "Note:")
    card.OfficerNoteLabel = card:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    card.OfficerNoteLabel:SetPoint("TOPLEFT", card.NoteLabel, "BOTTOMLEFT", 0, -43)
    card.OfficerNoteLabel:SetText(OFFICER_NOTE_COLON or "Officer's Note:")
    card.NoteBackground = NoteBox(card, card.NoteLabel)
    card.OfficerNoteBackground = NoteBox(card, card.OfficerNoteLabel)

    card.Border = ns.NewFrame("Frame", nil, card, "DialogBorderDarkTemplate")
    card.Border:SetPoint("TOPLEFT", card, "TOPLEFT", 4, 0)
    card.Border:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 6, 1)

    card.CloseButton = ns.NewFrame("Button", nil, card, "UIPanelCloseButton")
    card.CloseButton:SetPoint("TOPRIGHT", card, "TOPRIGHT", 3, -4)
    card.CloseButton:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        HideCard()
    end)

    card.RemoveButton = FootButton(card, REMOVE or "Remove")
    card.RemoveButton:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 16, 12)
    card.RemoveButton:SetScript("OnClick", function()
        if card.name then StaticPopup_Show("FCUI_GUILD_REMOVE", card.name, nil, card.name) end
    end)
    card.GroupInviteButton = FootButton(card, GROUP_INVITE or "Group Invite")
    card.GroupInviteButton:SetPoint("LEFT", card.RemoveButton, "RIGHT", 1, 0)
    card.GroupInviteButton:SetScript("OnClick", function()
        if card.name then S.Invite(card.name) end
    end)

    G.DressMemberWindow(card)
    -- Only while it shows: it yields the moment the client's window is in sight.
    ns.Sched.Attach(card, { name = "guild.card", every = 0, fn = function()
        if ClientCardShown() then HideCard() end
    end })
    return card
end

local function NoteText(box, text, editable)
    box.Text:SetText(text)
    local shade = editable and 1 or NOTE_GREY
    box.Text:SetTextColor(shade, shade, shade)
end

local function Fill(entry)
    local me = MyEntry()
    local isMe = me == entry
    card.key, card.name = G.EntryKey(entry), entry.name
    card.Name:SetText(entry.name)
    card.Level:SetFormattedText(FRIENDS_LEVEL_TEMPLATE or "Level %d %s", entry.level, entry.class)
    card.ZoneText:SetText(entry.zone)
    card.RankText:SetText(entry.rank)
    card.OnlineText:SetText(G.LastOnline(entry))
    NoteText(card.NoteBackground, entry.note, isMe or Can(CanEditPublicNote))

    local officer = C_GuildInfo and Can(C_GuildInfo.CanViewOfficerNote)
    card.OfficerNoteLabel:SetShown(officer)
    card.OfficerNoteBackground:SetShown(officer)
    if officer then NoteText(card.OfficerNoteBackground, entry.officerNote, Can(C_GuildInfo.CanEditOfficerNote)) end
    card:SetHeight((officer and CARD_OFFICER_H or CARD_H) + card.Name:GetHeight() + card.RankLabel:GetHeight())

    card.RemoveButton:SetEnabled(not isMe and me ~= nil and Can(CanGuildRemove) and entry.rankIndex > me.rankIndex)
    card.GroupInviteButton:SetEnabled(not isMe and entry.online)
end

-- A row's left click: in a fight our card, out of one the client's window (the row's pad clicked it).
function G.ShowMemberCard()
    local entry = InCombatLockdown() and not ClientCardShown() and G.panel and G.panel:IsVisible() and SelectedEntry()
    if not entry then
        HideCard()
        return
    end
    Card()
    card:SetScale(UIParent:GetEffectiveScale())
    G.DockMemberWindow(card, G.panel:GetParent())
    Fill(entry)
    card:Show()
end

-- The roster redrew: the card keeps its member up to date, and closes once another is picked or it is gone.
function G.FillMemberCard()
    if not (card and card:IsShown()) then return end
    local entry = SelectedEntry()
    if not entry or G.EntryKey(entry) ~= card.key or ClientCardShown() then
        HideCard()
        return
    end
    Fill(entry)
end
