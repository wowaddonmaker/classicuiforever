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
    local copy = not swap and bronze and ns.ThemeLook() == "themed"
    ns.DressStates(button, FacePath(prefix, "Normal", copy), FacePath(prefix, "Pushed", copy),
        FacePath(prefix, "Disabled", copy), HILIGHT, swap and FACE_SWAP or FACE_SET)
    if not swap then
        ns.PaintCopy(button:GetNormalTexture(), copy and FacePath(prefix, "Normal", true) or nil)
        ns.PaintCopy(button:GetPushedTexture(), copy and FacePath(prefix, "Pushed", true) or nil)
        ns.PaintCopy(button:GetDisabledTexture(), copy and FacePath(prefix, "Disabled", true) or nil)
    end
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
local buttonsOff = {}       -- client button -> faded by Hide chat buttons
local channelWas            -- the voice button's own flash atlas while dressed
local sharedAt              -- the column the menu, voice and friends buttons stand on
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

-- Onto a chat's button frame, layering kept: a child of a hidden chat hides with it.
local function Carry(button, chat)
    Hold(button)
    local parent = chat.buttonFrame
    if button:GetParent() == parent then return end
    local strata, level = button:GetFrameStrata(), button:GetFrameLevel()
    button:SetParent(parent)
    button:SetFrameStrata(strata)
    button:SetFrameLevel(level)
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

-- With the scroll bar kept, a stepper back on the bar in the old small arrow; the column keeps only its bottom button.
local function StepperToBar(stepper)
    if not stepper then return end
    local saved, info, own = was[stepper], held[stepper], faces[stepper]
    if buttonsOff[stepper] then
        buttonsOff[stepper] = nil
        stepper:SetAlpha(1)
        stepper:EnableMouse(true)
    end
    if own then
        Unface(stepper, own)
        faces[stepper] = nil
    end
    if saved then
        RestorePoints(stepper, saved)
        was[stepper] = nil
    end
    if info then
        stepper:SetParent(info.parent)
        stepper:SetFrameStrata(info.strata)
        stepper:SetFrameLevel(info.level)
        held[stepper] = nil
    end
end

-- The bar skin's small arrow on a stepper, shown only on the bar.
local function BarArrow(stepper, shown)
    local arrow = stepper and stepper.fcui and stepper.fcui.arrow
    if arrow then ns.SetShownIf(arrow, shown) end
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

-- Chat scroll bar keeps the client's bar track and its room on the right.
local function KeepBar() return ns.db and ns.db.chatScrollBar == true end
local RIGHT_REGIONS = { "Background", "editBox", "CombatLogQuickButtonFrame" }

local function UnfitRight(chat)
    for _, key in ipairs(RIGHT_REGIONS) do
        local region = chat[key]
        if region and was[region] then
            RestorePoints(region, was[region])
            was[region] = nil
        end
    end
end

local function BarBack(chat)
    local track = chat.ScrollBar and chat.ScrollBar.Track
    local info = track and held[track]
    if not info then return end
    track:SetParent(info.parent)
    held[track] = nil
end

-- The room the client keeps on the right for the bar goes with it.
local function FitRight(chat)
    if not chat.ScrollBar then return end
    if KeepBar() then UnfitRight(chat) return end
    Edge(chat.Background, "TOPRIGHT", chat, "TOPRIGHT", BG_RIGHT)
    Edge(chat.Background, "BOTTOMRIGHT", chat, "BOTTOMRIGHT", BG_RIGHT)
    Edge(chat.editBox, "RIGHT", chat, "RIGHT", EDIT_RIGHT)
    Edge(chat.CombatLogQuickButtonFrame, "BOTTOMRIGHT", chat, "TOPRIGHT", QUICK_RIGHT)
end

-- The alert container at rel with the friends button 4 above it: the container stacks its alerts from its foot, and an
-- unseen one under the button stood it 40 up; the button's measured rise is taken off.
local function PlaceAlerts(alerts, rel)
    local rise = 0
    local quick = _G["QuickJoinToastButton"]
    local qb, ab = quick and quick:IsShown() and quick:GetBottom(), alerts:GetBottom()
    if qb and ab and not ns.AnySecret(qb, ab) then
        rise = math.max(0, math.floor((qb * quick:GetEffectiveScale() - ab * alerts:GetEffectiveScale()) / alerts:GetEffectiveScale() + 0.5))
    end
    Place(alerts, "BOTTOM", rel, "TOP", 0, 4 - rise)
end

local function Slot(chat, strata)
    local slot = ns.NewFrame("Frame", nil, chat.buttonFrame)
    slot:SetSize(SIZE, SIZE)
    slot:SetFrameStrata(strata)
    slot.chat = chat
    return slot
end

-- Hide chat buttons: each part its own pick under it; "all" only when every part is picked.
local PARTS = { friends = "hideChatFriends", channels = "hideChatChannels", menu = "hideChatMenu",
    scroll = "hideChatScroll", bottom = "hideChatBottom" }
local PART_KEYS = {}
for _, key in pairs(PARTS) do PART_KEYS[key] = true end

local function Off(part)
    if not (active and ns.db.hideChatButtons) then return false end
    if part ~= "all" then return ns.db[PARTS[part]] ~= false end
    for key in pairs(PART_KEYS) do
        if ns.db[key] == false then return false end
    end
    return true
end

-- The 2 px overlap between old buttons; none on the column's foot.
local function Gap(col, below) return below == col.base and 0 or -2 end

-- A hidden part's slot sits under the next shown one, so the column closes up.
local function StackSlot(col, slot, below, off)
    ns.SetPointOnce(slot, "BOTTOM", below, "TOP", 0, Gap(col, below))
    return off and below or slot
end

-- With the scroll bar kept the arrow slots stay empty but keep their room.
local function Stack(col)
    local top = StackSlot(col, col.bottom, col.base, Off("bottom"))
    top = StackSlot(col, col.down, top, Off("scroll"))
    col.top = StackSlot(col, col.up, top, Off("scroll"))
end

-- Menu, voice and friends buttons on the docked column showing, in the 1.x order and gaps: the client hangs the
-- first two on ChatFrame1, which hides on other tabs.
local function StackShared(col)
    local chat = col.chat
    local top = col.top or col.up
    local menu, channel = _G.ChatFrameMenuButton, _G.ChatFrameChannelButton
    if menu then
        Carry(menu, chat)
        Place(menu, "BOTTOM", top, "TOP", 0, Gap(col, top))
        if not Off("menu") then top = menu end
    end
    if channel then
        Carry(channel, chat)
        Place(channel, "BOTTOM", top, "TOP", 0, top == menu and 1 or Gap(col, top))
        channel:SetSize(SIZE, SIZE)
        if not Off("channels") then top = channel end
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
    -- The friends button anchors first in ChatAlertFrame: move the container, toasts follow.
    local alerts = _G.ChatAlertFrame
    if alerts then
        alerts:SetWidth(SIZE)
        PlaceAlerts(alerts, top)
    end
    sharedAt = col
end

-- ChatFrame1's column, or another docked window's while its tab is picked.
local function ShownColumn()
    for chat, col in pairs(columns) do
        if chat ~= primaryChat and chat.isDocked and chat:IsVisible() then return col end
    end
    return columns[primaryChat]
end

-- From our own frame's pass after the client's tab pass, kicked by a column's show.
local function FollowShown()
    if not active then return end
    local col = ShownColumn()
    if col and col ~= sharedAt then StackShared(col) end
end
local followJob = ns.Sched.OnFrame(CreateFrame("Frame"), { name = "chat.follow", every = math.huge, fn = FollowShown })

-- A column showing: the shared buttons may follow it, and an undocked window shown now is dressed.
local function ColumnShown(shown)
    if not shown or not active then return end
    followJob:Kick()
    WatchNextFrame()
end

local function MakeColumn(chat)
    local menu = _G.ChatFrameMenuButton
    local strata = menu and menu:GetFrameStrata() or "MEDIUM"
    local col = { chat = chat, up = Slot(chat, strata), down = Slot(chat, strata), bottom = Slot(chat, strata),
        base = Slot(chat, strata) }
    -- Classic spacing: the button frame ends 6 above the chat's bottom edge.
    col.base:SetHeight(1)
    col.base:SetPoint("BOTTOM", chat.buttonFrame, "BOTTOM", 0, -7)
    -- The bottom slot, not up: with the scroll bar kept, the arrow slots stay hidden.
    ns.Sched.OnVisible(col.bottom, "chat.follow", ColumnShown)
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
    local bar = chat.ScrollBar
    local keep = bar and KeepBar()
    col.up:SetShown(not keep)
    col.down:SetShown(not keep)
    col.bottom:Show()
    Stack(col)
    if keep then
        BarBack(chat)
        StepperToBar(bar.Back)
        StepperToBar(bar.Forward)
        ns.SkinMinimalScrollBar(bar)
        BarArrow(bar.Back, true)
        BarArrow(bar.Forward, true)
    elseif bar then
        SetAside(bar.Track)
        BarArrow(bar.Back, false)
        BarArrow(bar.Forward, false)
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

-- ChatFrame1's own buttons, on the docked column showing.
local function DressPrimary()
    local chat = primaryChat
    local channel = _G.ChatFrameChannelButton
    if chat and chat.buttonFrame and OwnColumn(chat) then
        if channel then DressChannel(channel) end
        return
    end
    local col = ShownColumn()
    if not col then return end
    if channel then DressChannel(channel) end
    StackShared(col)
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

-- Hide chat buttons: the picked buttons left of the chat go; with all of them gone the chat can sit flush at the
-- screen's edge. The wheel still scrolls (Shift jumps to either end). Held every 0.25 s: the client fades these in
-- with the mouse.
local HIDE_NAMES = { ChatFrameMenuButton = "menu", ChatFrameChannelButton = "channels",
    ChatFrameToggleVoiceDeafenButton = "channels", ChatFrameToggleVoiceMuteButton = "channels",
    QuickJoinToastButton = "friends" }
local OWN_BUTTONS = { upButton = "scroll", downButton = "scroll", bottomButton = "bottom", minimizeButton = "all" }
local holdJob

-- fn(button, part) for every button left of any chat.
local function EachChatButton(fn)
    for name, part in pairs(HIDE_NAMES) do
        if _G[name] then fn(_G[name], part) end
    end
    local list = _G.CHAT_FRAMES or ns.EMPTY
    for i = 1, #list do
        local chat = _G[list[i]]
        if chat then
            -- On a kept scroll bar the arrows are the bar's, not the column's.
            local bar = chat.ScrollBar
            if bar and not KeepBar() then
                if bar.Back then fn(bar.Back, "scroll") end
                if bar.Forward then fn(bar.Forward, "scroll") end
            end
            if chat.ScrollToBottomButton then fn(chat.ScrollToBottomButton, "bottom") end
            local frame = chat.buttonFrame
            if frame then
                for key, part in pairs(OWN_BUTTONS) do
                    if frame[key] then fn(frame[key], part) end
                end
            end
        end
    end
end

-- Our faces ignore the button's alpha (the client fades it); while held they follow it again.
local function FacesFollow(button, follow)
    if not faces[button] then return end
    ns.EachState(button, FACES, IgnoreParentAlpha, not follow)
    if button.Flash then button.Flash:SetIgnoreParentAlpha(not follow) end
end

-- The client fades the scroll-to-bottom button's own alpha in as a chat scrolls up, which raced the alpha hold and
-- flashed it (#142): that one is held under a hidden frame of ours, its anchors on our slot unchanged.
local stash
local stashed = setmetatable({}, { __mode = "k" })   -- button -> { parent, strata, level } before the stash
local function Stash(button)
    if not stash then
        stash = CreateFrame("Frame", nil, UIParent)
        stash:Hide()
    end
    if button:GetParent() == stash then return end
    stashed[button] = { parent = button:GetParent(), strata = button:GetFrameStrata(), level = button:GetFrameLevel() }
    button:SetParent(stash)
end

local function HoldOne(button, part)
    ns.SetAlphaIf(button, 0)
    if button:IsMouseEnabled() then button:EnableMouse(false) end
    if part == "bottom" then Stash(button) end
    -- Each pass: a theme turn dresses the faces again.
    FacesFollow(button, true)
    buttonsOff[button] = true
end

local function Release(button)
    if not buttonsOff[button] then return end
    buttonsOff[button] = nil
    local info = stashed[button]
    if info then
        stashed[button] = nil
        button:SetParent(info.parent)
        button:SetFrameStrata(info.strata)
        button:SetFrameLevel(info.level)
    end
    button:SetAlpha(1)
    button:EnableMouse(true)
    FacesFollow(button, false)
end

local function HoldPicked(button, part)
    if Off(part) then HoldOne(button, part) else Release(button) end
end

-- Edit mode's box keeps 32 px left of the chat for the buttons (EditModeChatFrameSystemTemplate) and holds that box on
-- screen: with the buttons gone it starts at the chat's own edge, so the chat can sit flush.
local SELECTION_LEFT, SELECTION_TOP, SELECTION_FLUSH = -32, 60, -4
-- Another addon can zero the clamp edges (Prat), so the clamp alone may leave the buttons off screen: the chat slides
-- right by what they lack.
local function Reclamp(chat)
    pcall(chat.SetClampedToScreen, chat, true)
    if InCombatLockdown() then return end
    local left = chat:GetLeft()
    if not left or ns.IsSecret(left) then return end
    local short = -SELECTION_LEFT - left
    if short <= 0.5 then return end
    local n = chat:GetNumPoints()
    local points = {}
    for i = 1, n do points[i] = { chat:GetPoint(i) } end
    chat:ClearAllPoints()
    for i = 1, n do
        local p = points[i]
        chat:SetPoint(p[1], p[2], p[3], (p[4] or 0) + short, p[5] or 0)
    end
end

-- Read from the box itself: the client re-lays it on its own passes.
local function SelectionLeft(selection, chat)
    for i = 1, selection:GetNumPoints() do
        local point, rel, _, x = selection:GetPoint(i)
        if point == "TOPLEFT" and rel == chat then return x end
    end
end

local function SelectionEdge(flush)
    local chat = _G.ChatFrame1
    local selection = chat and chat.Selection
    if not selection or InCombatLockdown() then return end
    local want = flush and SELECTION_FLUSH or SELECTION_LEFT
    if SelectionLeft(selection, chat) == want then return end
    selection:SetPoint("TOPLEFT", chat, "TOPLEFT", want, SELECTION_TOP)
    if chat.UpdateClampOffsets then pcall(chat.UpdateClampOffsets, chat) end
    -- Back from flush: the client clamps the chat again, now counting the buttons' room, so they come back on screen.
    -- Clamp on again a frame later: off and on in one frame can be skipped.
    if not flush then
        pcall(chat.SetClampedToScreen, chat, false)
        ns.Sched.NextFrame("chat.reclamp", function() Reclamp(chat) end)
    end
end

local function Flushed()
    local chat = _G.ChatFrame1
    local selection = chat and chat.Selection
    return selection ~= nil and SelectionLeft(selection, chat) == SELECTION_FLUSH
end

local function HoldButtons()
    if active and ns.db.hideChatButtons then
        EachChatButton(HoldPicked)
        if Off("all") then
            SelectionEdge(true)
        elseif Flushed() then
            SelectionEdge(false)
        end
        return
    end
    if Flushed() then SelectionEdge(false) end
    for button in pairs(buttonsOff) do Release(button) end
    if holdJob then holdJob:Sleep() end
end

-- The column closes up round the hidden parts, then they are held.
local function ChatButtonsOption()
    if active then
        DressAll()
        DressPrimary()
    end
    if active and ns.db.hideChatButtons then
        holdJob = holdJob or ns.Sched.Job({ name = "chat.hideButtons", every = 0.25, awake = false, fn = HoldButtons })
        holdJob:Wake()
    end
    HoldButtons()
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
    ChatButtonsOption()
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
    sharedAt, theme.on = nil, nil
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
    HoldButtons()
end

ns.RegisterModule("classicChat", { apply = Apply, restore = Restore })

ns.OnToggle(function(key)
    if key == "hideChatButtons" or PART_KEYS[key] then ChatButtonsOption() end
    if key == "chatScrollBar" and active then DressAll() end
end)
