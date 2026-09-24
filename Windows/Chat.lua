local ADDON, ns = ...

-- 1.x chat buttons: one column at the chat's left (friends, voice, menu, up,
-- down, bottom), the old square voice button, no scroll bar on any chat window.

local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\media\\"
local CHAT_ICON = "Interface\\ChatFrame\\UI-ChatIcon-"
local HILIGHT = ns.ART.HILIGHT
local BLINK = "Interface\\ChatFrame\\UI-ChatIcon-BlinkHilight"
local VOICE = MEDIA .. "UI-ChatIcon-Voice"
local SIZE = 32
-- Right edges without the bar, as in 1.x.
local BG_RIGHT, EDIT_RIGHT, QUICK_RIGHT = 2, 5, 0

local STATES = { "Normal", "Pushed", "Disabled" }
local FACES = { "Normal", "Pushed", "Disabled", "Highlight" }
local SUFFIX = { Normal = "-Up", Pushed = "-Down", Disabled = "-Disabled" }
local FULL = { 0, 1, 0, 1 }
-- Faces that follow the theme, or fixed once; both take the common highlight.
local FACE_SWAP = { set = "file", highlightSet = "raw", coords = FULL, fill = true, add = true }
local FACE_SET = { set = "raw", coords = FULL, fill = true, add = true }
local BLINK_FILL = { set = "raw", coords = FULL, fill = true }
local BLINK_SIZED = { set = "raw", coords = FULL, w = SIZE, h = SIZE }
local StateTexture = ns.StateTexture

-- A bare name is one of the client's UI-ChatIcon files; a path is used as given.
local function Prefix(name)
    if name:find("\\", 1, true) then return name end
    return CHAT_ICON .. name
end

local BronzeCopy = ns.BronzeCopy

-- Bronze only when every face of the set has a copy, or a column mixes metals.
local setBronze = {}
local function SetHasBronze(set)
    local known = setBronze[set]
    if known ~= nil then return known end
    known = true
    for _, name in ipairs(set) do
        local prefix = Prefix(name)
        for _, which in ipairs(STATES) do
            if not BronzeCopy(prefix .. SUFFIX[which]) then known = false end
        end
    end
    setBronze[set] = known
    return known
end

-- A state's file, or its bronze copy.
local function FacePath(prefix, which, copy)
    local path = prefix .. SUFFIX[which]
    return copy and BronzeCopy(path) or path
end

-- Old chat button faces (-Up/-Down/-Disabled, common highlight). fixed: theme
-- picked now, never registered for swapping (client buttons handed back later).
function ns.ChatIconButton(button, name, set, fixed)
    local prefix = Prefix(name)
    local bronze = SetHasBronze(set)
    local swap = bronze and not fixed
    local copy = not swap and bronze and ns.ThemeLook() == "bronze"
    ns.DressStates(button, FacePath(prefix, "Normal", copy), FacePath(prefix, "Pushed", copy),
        FacePath(prefix, "Disabled", copy), HILIGHT, swap and FACE_SWAP or FACE_SET)
end

local COLUMN = { "ScrollUp", "ScrollDown", "ScrollEnd", VOICE }
local VOICE_TOGGLES = { "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton" }
-- The client's strip behind the buttons; 1.x had none.
local STRIP = { "ButtonFrameBackground", "ButtonFrameTopLeftTexture", "ButtonFrameBottomLeftTexture",
    "ButtonFrameTopRightTexture", "ButtonFrameBottomRightTexture", "ButtonFrameLeftTexture",
    "ButtonFrameRightTexture", "ButtonFrameBottomTexture", "ButtonFrameTopTexture" }

local active, applied = false, false
local theme = {}            -- ThemeTurned state: the theme the client buttons were last dressed for
local columns = {}          -- chat frame -> our slots: up, down, bottom
local held = {}             -- client frame we reparented or raised -> parent, strata, level
local faces = {}            -- client button we dressed -> its own atlases
local hidden = {}           -- client textures we hid
local was = {}              -- client region -> its points and size before ours
local channelWas            -- the voice button's own flash atlas while dressed
local alertsAt, primaryTop  -- the slot the friends button stands on; ChatFrame1's top button
local primaryChat
local knownFrames = 0
local holder, watch
local WatchNextFrame

local function SavePoints(frame)
    if was[frame] then return end
    local saved = { w = frame:GetWidth(), h = frame:GetHeight(), n = frame:GetNumPoints() }
    for i = 1, saved.n do
        local point, rel, relPoint, x, y = frame:GetPoint(i)
        saved[i] = { point = point, rel = rel, relPoint = relPoint, x = x, y = y }
    end
    was[frame] = saved
end

local function RestorePoints(frame, saved)
    local _, clearPoints, setPoint = ns.BaseSetters(frame)
    clearPoints(frame)
    for i = 1, saved.n do
        local p = saved[i]
        setPoint(frame, p.point, p.rel or frame:GetParent(), p.relPoint, p.x, p.y)
    end
    frame:SetSize(saved.w, saved.h)
end

local function Place(frame, point, relative, relPoint, x, y)
    SavePoints(frame)
    ns.SetPointOnce(frame, point, relative, relPoint, x, y)
end

local function Hold(frame)
    if held[frame] then return end
    held[frame] = { parent = frame:GetParent(), strata = frame:GetFrameStrata(), level = frame:GetFrameLevel() }
end

-- Reparent into our hidden frame: the client re-shows it on every message.
local function SetAside(frame)
    if not frame or held[frame] then return end
    Hold(frame)
    frame:SetParent(holder)
end

-- A client button over our slot. Its click stays the client's: our code writing
-- its scroll fields would taint them.
local function Seat(button, slot, parent)
    Hold(button)
    SavePoints(button)
    if parent then button:SetParent(parent) end
    button:ClearAllPoints()
    button:SetAllPoints(slot)
    button:SetFrameStrata(slot:GetFrameStrata())
    button:SetFrameLevel(slot:GetFrameLevel() + 1)
end

local function IgnoreParentAlpha(tex, _, on) tex:SetIgnoreParentAlpha(on) end

-- Old face on a client button, full alpha whatever the client fades it or the bar to.
local function Face(button, name)
    local own = faces[button]
    if not own then
        own = {}
        for _, which in ipairs(FACES) do
            local tex = StateTexture(button, which)
            local atlas = tex and tex:GetAtlas()
            own[which] = atlas ~= nil and atlas ~= "" and atlas or false
        end
        faces[button] = own
    end
    ns.ChatIconButton(button, name, COLUMN, true)
    ns.EachState(button, FACES, IgnoreParentAlpha, true)
    return own
end

local function Unface(button, own)
    for _, which in ipairs(FACES) do
        local tex = StateTexture(button, which)
        if tex then tex:SetIgnoreParentAlpha(false) end
        local atlas = own[which]
        if atlas and which == "Highlight" then
            button:SetHighlightAtlas(atlas, "ADD")
        elseif atlas then
            button["Set" .. which .. "Atlas"](button, atlas)
        else
            local clear = button["Clear" .. which .. "Texture"]
            if clear then clear(button) end
        end
    end
    if own.texture then own.texture:SetAlpha(1) end
    local flash = own.flash ~= nil and button.Flash
    if flash then
        flash:SetIgnoreParentAlpha(false)
        if own.flash then flash:SetAtlas(own.flash, true) end
    end
end

-- The bar's arrow, moved into our slot; its press and held repeat are the bar's.
local function DressStepper(stepper, slot, name)
    if not stepper then return end
    Seat(stepper, slot, slot)
    local own = Face(stepper, name)
    -- The client only re-atlases its own arrow, so the alpha stays.
    if stepper.Texture then
        own.texture = stepper.Texture
        stepper.Texture:SetAlpha(0)
    end
end

-- Stays the chat's child (its click scrolls the parent); the client's
-- not-at-bottom blink plays on our art.
local function DressBottom(button, slot)
    if not button then return end
    Seat(button, slot)
    local own = Face(button, "ScrollEnd")
    local flash = button.Flash
    if not flash then return end
    if own.flash == nil then
        local atlas = flash:GetAtlas()
        own.flash = atlas ~= nil and atlas ~= "" and atlas or false
    end
    SavePoints(flash)
    ns.Dress(flash, BLINK, BLINK_FILL, button)
    flash:SetIgnoreParentAlpha(true)
end

-- The client hangs the bar's foot on the bottom button, now in our column.
local function AnchorBar(chat)
    local bar, bottom = chat.ScrollBar, chat.ScrollToBottomButton
    if not bar or not bottom then return end
    for i = 1, bar:GetNumPoints() do
        local _, rel = bar:GetPoint(i)
        if rel == bottom then
            SavePoints(bar)
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", chat, "TOPRIGHT", 0, 0)
            bar:SetPoint("BOTTOMLEFT", chat, "BOTTOMRIGHT", 0, 0)
            return
        end
    end
end

local function Edge(region, point, chat, relPoint, x)
    if not region then return end
    for i = 1, region:GetNumPoints() do
        local p, _, _, ox, oy = region:GetPoint(i)
        if p == point then
            if ns.Near(ox, x, 0.01) then return end
            SavePoints(region)
            region:SetPoint(point, chat, relPoint, x, oy)
            return
        end
    end
end

-- The room the client keeps on the right for the bar goes with it.
local function FitRight(chat)
    if not chat.ScrollBar then return end
    Edge(chat.Background, "TOPRIGHT", chat, "TOPRIGHT", BG_RIGHT)
    Edge(chat.Background, "BOTTOMRIGHT", chat, "BOTTOMRIGHT", BG_RIGHT)
    Edge(chat.editBox, "RIGHT", chat, "RIGHT", EDIT_RIGHT)
    Edge(chat.CombatLogQuickButtonFrame, "BOTTOMRIGHT", chat, "TOPRIGHT", QUICK_RIGHT)
end

-- Friends button follows the visible docked column (ChatFrame1's hide on other tabs), from our own frame's pass after
-- the client's tab pass, kicked by a column's show.
local function Follow(slot)
    if alertsAt == slot then return end
    local chat = slot.chat
    if chat ~= primaryChat and not chat.isDocked then return end
    local alerts = _G.ChatAlertFrame
    if not alerts then return end
    alertsAt = slot
    Place(alerts, "BOTTOM", chat == primaryChat and primaryTop or slot, "TOP", 0, 4)
end

local function FollowShown()
    for _, col in pairs(columns) do
        if col.up:IsVisible() then Follow(col.up) end
    end
end
local followJob = ns.Sched.OnFrame(CreateFrame("Frame"), { name = "chat.follow", every = math.huge, fn = FollowShown })

-- A column showing: the friends button may follow it, and an undocked window shown now is dressed.
local function ColumnShown(shown)
    if not shown or not active then return end
    followJob:Kick()
    WatchNextFrame()
end

local function Slot(chat, strata)
    local slot = CreateFrame("Frame", nil, chat.buttonFrame)
    slot:SetSize(SIZE, SIZE)
    slot:SetFrameStrata(strata)
    slot.chat = chat
    return slot
end

local function MakeColumn(chat)
    local menu = _G.ChatFrameMenuButton
    local strata = menu and menu:GetFrameStrata() or "MEDIUM"
    local col = { up = Slot(chat, strata), down = Slot(chat, strata), bottom = Slot(chat, strata) }
    -- Classic spacing: the button frame ends 6 above the chat's bottom edge.
    col.bottom:SetPoint("BOTTOM", chat.buttonFrame, "BOTTOM", 0, -6)
    col.down:SetPoint("BOTTOM", col.bottom, "TOP", 0, -2)
    col.up:SetPoint("BOTTOM", col.down, "TOP", 0, -2)
    ns.Sched.OnVisible(col.up, "chat.follow", ColumnShown)
    columns[chat] = col
    return col
end

-- The classic chat frame carries this column itself, in a layout frame.
local function OwnColumn(chat)
    return chat.buttonFrame.upButton ~= nil
end

local function DressChat(chat)
    if not chat or not chat.buttonFrame then return end
    FitRight(chat)
    if OwnColumn(chat) then return end
    local col = columns[chat] or MakeColumn(chat)
    col.up:Show()
    col.down:Show()
    col.bottom:Show()
    local bar = chat.ScrollBar
    if bar then
        SetAside(bar.Track)
        DressStepper(bar.Back, col.up, "ScrollUp")
        DressStepper(bar.Forward, col.down, "ScrollDown")
    end
    DressBottom(chat.ScrollToBottomButton, col.bottom)
    AnchorBar(chat)
    if col.stripped then return end
    col.stripped = true
    local name = chat:GetName()
    for _, key in ipairs(STRIP) do
        local tex = name and _G[name .. key]
        if tex and tex:IsShown() then
            tex:Hide()
            hidden[tex] = true
        end
    end
end

-- Every chat window, the temporary ones included.
local function DressAll()
    local list = _G.CHAT_FRAMES or ns.EMPTY
    for i = 1, #list do DressChat(_G[list[i]]) end
    knownFrames = #list
end

local function DressChannel(button)
    if not channelWas then channelWas = { flash = button.Flash and button.Flash:GetAtlas() } end
    ns.ChatIconButton(button, VOICE, COLUMN, true)
    if button.Icon then button.Icon:Hide() end
    ns.Dress(button.Flash, BLINK, BLINK_SIZED)
end

local function UndressChannel(button)
    if not channelWas or not button then return end
    button:SetNormalAtlas(button.normalAtlas or "chatframe-button-up")
    button:SetPushedAtlas(button.pushedAtlas or "chatframe-button-down")
    if button.ClearDisabledTexture then button:ClearDisabledTexture() end
    button:SetHighlightAtlas(button.highlightAtlas or "chatframe-button-highlight", "ADD")
    if button.Icon then button.Icon:Show() end
    if button.Flash and channelWas.flash then button.Flash:SetAtlas(channelWas.flash, true) end
    channelWas = nil
end

local function HasAtlas(tex)
    local atlas = tex and tex:GetAtlas()
    return atlas ~= nil and atlas ~= ""
end

-- The client re-sets atlases on voice state changes, and the theme hands back
-- the ones it bronzed before we dressed the button.
local function GuardChannel()
    local button = _G.ChatFrameChannelButton
    if not button or not channelWas then return end
    if HasAtlas(button:GetNormalTexture()) or HasAtlas(button:GetHighlightTexture())
        or (button.Icon and button.Icon:IsShown()) then
        DressChannel(button)
    end
end

-- ChatFrame1's own buttons over our slots, in the 1.x order and gaps.
local function DressPrimary()
    local chat = primaryChat
    local channel = _G.ChatFrameChannelButton
    if chat and chat.buttonFrame and OwnColumn(chat) then
        if channel then DressChannel(channel) end
        return
    end
    local col = chat and columns[chat]
    if not col then return end
    local top = col.up
    local menu = _G.ChatFrameMenuButton
    if menu then
        Place(menu, "BOTTOM", top, "TOP", 0, -2)
        top = menu
    end
    if channel then
        Place(channel, "BOTTOM", top, "TOP", 0, menu and 1 or -2)
        channel:SetSize(SIZE, SIZE)
        DressChannel(channel)
        top = channel
        -- Deafen and mute beside the voice button, away from the screen edge.
        local right = chat.buttonSide ~= "right"
        local last = channel
        for _, name in ipairs(VOICE_TOGGLES) do
            local button = _G[name]
            if button then
                Place(button, right and "LEFT" or "RIGHT", last, right and "RIGHT" or "LEFT", right and 2 or -2, 0)
                last = button
            end
        end
    end
    primaryTop = top
    -- The friends button anchors first in ChatAlertFrame: move the container, toasts follow.
    local alerts = _G.ChatAlertFrame
    if alerts then
        Place(alerts, "BOTTOM", top, "TOP", 0, 4)
        alerts:SetWidth(SIZE)
        alertsAt = col.up
    end
end

-- Faces are picked at dress time: a theme turn redresses, and every frame for 1 s catches
-- the theme handing the voice button its atlases back.
local burstUntil = 0
local function Redress(turned)
    DressAll()
    DressPrimary()
    if turned then
        burstUntil = GetTime() + 1
        watch:Wake()
    end
end

local function Watch()
    if not active then return end
    local list = _G.CHAT_FRAMES
    if ns.ThemeTurned(theme) then
        Redress(theme.was ~= nil)
    elseif list and #list ~= knownFrames then
        DressAll()
    end
    -- Hidden undocked windows (unused, closed) are caught once they show.
    for chat in pairs(columns) do
        if chat.isDocked or chat:IsShown() then AnchorBar(chat) end
    end
    -- The combat log re-sets its background anchors on every dock update.
    local log = _G.COMBATLOG
    if log then FitRight(log) end
    GuardChannel()
end

local function WatchBurst(job, now)
    Watch()
    if now >= burstUntil then job:Sleep() end
end
watch = ns.Sched.Job({ name = "chat.watch", every = 0, awake = false, fn = WatchBurst })

WatchNextFrame = function()
    if active then ns.Sched.NextFrame("chat.watch", Watch) end
end

-- Windows change on the client's chat window events, whispers (temporary windows), mouse releases (tabs, drags, docking,
-- the menu) and voice changes (atlases re-set): looked at in that frame's pass and the next.
local WATCH_EVENTS = { "UPDATE_CHAT_WINDOWS", "UPDATE_FLOATING_CHAT_WINDOWS", "PLAYER_ENTERING_WORLD", "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "GLOBAL_MOUSE_UP",
    "VOICE_CHAT_CHANNEL_ACTIVATED", "VOICE_CHAT_CHANNEL_DEACTIVATED" }
local function WatchSoon()
    if not active then return end
    ns.Sched.Soon("chat.watch", Watch)
    WatchNextFrame()
end

local function Apply()
    active, applied = true, true
    if not holder then
        holder = CreateFrame("Frame", nil, UIParent)
        holder:Hide()
        ns.EventFrame(WATCH_EVENTS, WatchSoon)
    end
    primaryChat = _G.ChatFrame1
    Redress(ns.ThemeTurned(theme) and theme.was ~= nil)
    WatchNextFrame()
end

local function Restore()
    active = false
    watch:Sleep()
    if not applied then return end
    applied = false
    for _, col in pairs(columns) do
        col.up:Hide()
        col.down:Hide()
        col.bottom:Hide()
        col.stripped = nil
    end
    alertsAt, primaryTop, theme.on = nil, nil, nil
    for button, own in pairs(faces) do Unface(button, own) end
    wipe(faces)
    for frame, info in pairs(held) do
        if frame:GetParent() ~= info.parent then frame:SetParent(info.parent) end
        frame:SetFrameStrata(info.strata)
        frame:SetFrameLevel(info.level)
    end
    wipe(held)
    for tex in pairs(hidden) do tex:Show() end
    wipe(hidden)
    UndressChannel(_G.ChatFrameChannelButton)
    for frame, saved in pairs(was) do RestorePoints(frame, saved) end
    wipe(was)
end

ns.RegisterModule("classicChat", { apply = Apply, restore = Restore })
