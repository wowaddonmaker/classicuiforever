local _, ns = ...

-- Every client menu (drop downs, right-click menus) in the 1.x dialog rim; the bronze theme gives back Forever's own.
-- Watch only: menu frames are pooled and discard their keys on close, so all state lives here in weak tables.

local ART = ns.ART
local pairs, rawget, select = pairs, rawget, select
local EnumerateFrames = _G.EnumerateFrames

local ATLAS = "common-dropdown-bg"
local BG_ALPHA = 0.925       -- MenuStyle1Mixin:Generate
local SCAN_BUDGET = 500      -- frames walked per tick while catching up
local GRACE = 3              -- ticks a click keeps the watch up with no menu open yet

local weak = { __mode = "k" }
local known = setmetatable({}, weak)   -- menu frame -> true
local backs = setmetatable({}, weak)   -- menu frame -> its background texture last seen
local rims = setmetatable({}, weak)    -- menu frame -> our rim

local active = false
local theme = {}             -- theme.on: last painted, true bronze, false classic
local cursor, caught         -- EnumerateFrames position; caught once it reached the end
local first, head, swept     -- first menu frame seen; sweep from the start up to it, once
local grace = 0
local events, host, job

local function Manager()
    return Menu and Menu.GetManager and Menu.GetManager()
end

-- rawget only: an open menu's metatable caches any key read through it.
local function IsMenuFrame(f)
    local mixin = _G.MenuProxyMixin
    return mixin and type(f) == "table" and f.IsForbidden and not f:IsForbidden()
        and rawget(f, "InitScrollLayout") == mixin.InitScrollLayout
end

local function Learn(f)
    if known[f] then return end
    known[f] = true
    if not cursor then cursor, first = f, f end
end

-- New pool frames come after the first one we saw; the pool can hand out an older one first.
local function Scan()
    if not cursor or not EnumerateFrames then return end
    local budget = SCAN_BUDGET
    while budget > 0 do
        budget = budget - 1
        local f = EnumerateFrames(cursor)
        if not f then
            caught = true
            break
        end
        cursor = f
        if IsMenuFrame(f) then Learn(f) end
    end
    while budget > 0 and not swept do
        budget = budget - 1
        local f = EnumerateFrames(head)
        if not f or f == first then
            swept = true
            break
        end
        head = f
        if IsMenuFrame(f) then Learn(f) end
    end
end

-- Until the scan catches up, a hovered submenu is found from the mouse.
local function UnderMouse()
    local foci = GetMouseFoci and GetMouseFoci()
    local f = foci and foci[1]
    for _ = 1, 6 do
        if type(f) ~= "table" or not f.GetParent then return end
        if IsMenuFrame(f) then
            Learn(f)
            return
        end
        f = f:GetParent()
    end
end

local function IsBack(region)
    local atlas = region.GetAtlas and region:GetAtlas()
    return atlas == ATLAS
end

local function FindBack(...)
    for i = 1, select("#", ...) do
        local region = select(i, ...)
        if IsBack(region) then return region end
    end
end

-- The client's background while it is still this menu's (a fresh one comes on every open).
local function Back(frame)
    local bg = backs[frame]
    if bg and bg:GetParent() == frame and IsBack(bg) then return bg end
    bg = FindBack(frame:GetRegions())
    backs[frame] = bg
    return bg
end

local function MakeRim(frame)
    local rim = CreateFrame("Frame", nil, frame, ns.BACKDROP_TEMPLATE)
    rim:SetPoint("TOPLEFT", frame, "TOPLEFT", -7, 6)
    rim:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 7, 1)
    -- At the menu's level so its rows draw over the rim.
    if rim.SetUsingParentLevel then rim:SetUsingParentLevel(true) else rim:SetFrameLevel(frame:GetFrameLevel()) end
    ns.Backdrop(rim, ns.BACKDROP.TIP16, ns.MENU_LOOK)
    -- Under the rows' highlight, which the client draws on BACKGROUND.
    if rim.Center then rim.Center:SetDrawLayer("BACKGROUND", -8) end
    rims[frame] = rim
    return rim
end

-- The client clamped the menu as it opened, before our rim; new insets don't re-clamp, so shift it by what sticks out.
local function OnScreen(frame, rim)
    local left, right, top, bottom = rim:GetLeft(), rim:GetRight(), rim:GetTop(), rim:GetBottom()
    if not (left and right and top and bottom) then return end
    local k = rim:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    local dx, dy = 0, 0
    if top * k > height then dy = height - top * k elseif bottom * k < 0 then dy = -bottom * k end
    if right * k > width then dx = width - right * k elseif left * k < 0 then dx = -left * k end
    if dx == 0 and dy == 0 then return end
    local point, rel, relPoint, x, y = frame:GetPoint(1)
    if not point then return end
    local f = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    frame:SetPoint(point, rel, relPoint, (x or 0) + dx * f, (y or 0) + dy * f)
end

local function Dress(frame)
    local bg = Back(frame)
    local rim = rims[frame]
    -- Other menu styles (the barber shop's) stay as drawn.
    if not bg then
        if rim and rim:IsShown() then rim:Hide() end
        return
    end
    -- Exact: Undress restores only an alpha of exactly 0.
    ns.SetAlphaIf(bg, 0, 0)
    rim = rim or MakeRim(frame)
    if not rim:IsShown() then rim:Show() end
    -- The client clamps the menu frame and resets its insets per open; our rim hangs out, so the clamp counts it.
    local ok, l, r, t, b = pcall(frame.GetClampRectInsets, frame)
    if not ok or l ~= -7 or r ~= 7 or t ~= 6 or b ~= -1 then pcall(frame.SetClampRectInsets, frame, -7, 7, 6, -1) end
    OnScreen(frame, rim)
end

local function Undress(frame)
    local bg = Back(frame)
    if bg and bg:GetAlpha() == 0 then bg:SetAlpha(BG_ALPHA) end
    local rim = rims[frame]
    if rim and rim:IsShown() then
        rim:Hide()
        pcall(frame.SetClampRectInsets, frame, 0, 0, 0, 0)
    end
end

local function UndressAll()
    for frame in pairs(known) do ns.SafeCall(Undress, frame) end
end

local function Tick()
    local m = Manager()
    if theme.on ~= false or not m or not m:IsAnyMenuOpen() then
        grace = grace - 1
        if grace <= 0 then job:Sleep() end
        return
    end
    grace = GRACE
    local root = m:GetOpenMenu()
    if IsMenuFrame(root) then Learn(root) end
    Scan()
    if not (caught and swept) then UnderMouse() end
    for frame in pairs(known) do
        if frame:IsShown() then Dress(frame) end
    end
end

local function Wake()
    if not active or theme.on ~= false then return end
    grace = GRACE
    job:Wake()
end

-------------------------------------------------- social window buttons

local CLASSIC_ARROW = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-"
local CLIENT_SQUARE = "Interface\\Buttons\\UI-SquareButton-"
local CLASSIC_STATES = { set = "file", highlightSet = "raw", coords = { 0, 1, 0, 1 }, center = { 24, 24 }, add = true }
-- IconButtonTemplate.xml's art, filling the button.
local CLIENT_STATES = { set = "file", highlightSet = "raw", coords = { 0, 1, 0, 1 }, fill = true, add = true }
local DD_PIECES = { "ddLeft", "ddMiddle", "ddRight", "ddArrow", "ddArrowGlow" }
local buttonsPainted         -- "classic", "client" or nil (never touched)

local function StatusDropdown()
    return _G.FriendsFrameStatusDropdown
end

local function ContactsButton()
    local bnet = _G.FriendsFrameBattlenetFrame
    return bnet and bnet.ContactsMenuButton
end

local function PaintStatus(dd, classic)
    if classic then ns.DressDropdown(dd) end
    local own = dd.fcui
    if own then
        for i = 1, #DD_PIECES do
            local piece = own[DD_PIECES[i]]
            if piece then piece:SetShown(classic) end
        end
    end
    if dd.Background then dd.Background:SetAlpha(classic and 0 or 1) end
    if dd.Arrow then dd.Arrow:SetAlpha(classic and 0 or 1) end
end

local function PaintContacts(btn, classic)
    if classic then
        ns.DressStates(btn, CLASSIC_ARROW .. "Up", CLASSIC_ARROW .. "Down", CLASSIC_ARROW .. "Disabled", ART.HILIGHT,
            CLASSIC_STATES)
    else
        ns.DressStates(btn, CLIENT_SQUARE .. "Up", CLIENT_SQUARE .. "Down", CLIENT_SQUARE .. "Disabled", ART.HILIGHT,
            CLIENT_STATES)
    end
    if btn.Icon then btn.Icon:SetAlpha(classic and 0 or 1) end
end

-- Classic only while the social window wears the old chrome; client art otherwise.
local function PaintButtons()
    local want
    if active and ns.db and ns.db.panels ~= false then
        want = ns.ThemeLook(true)
    elseif buttonsPainted then
        want = "client"
    end
    if not want or want == buttonsPainted then return end
    local dd, btn = StatusDropdown(), ContactsButton()
    if not dd and not btn then return end
    buttonsPainted = want
    local classic = want == "classic"
    if dd then ns.SafeCall(PaintStatus, dd, classic) end
    if btn then ns.SafeCall(PaintContacts, btn, classic) end
end

------------------------------------------------------------------ module

local CLICKS = { "GLOBAL_MOUSE_DOWN", "GLOBAL_MOUSE_UP" }

-- Every pass calls these: work only on a change.
local function Apply()
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", Wake)
        host = CreateFrame("Frame")
        job = ns.Sched.OnFrame(host, { name = "clientMenus.watch", every = 0, fn = Tick, awake = false })
    end
    if not active then
        active = true
        ns.RegisterEvents(events, CLICKS)
    end
    if ns.ThemeTurned(theme) then
        if theme.on then UndressAll() else Wake() end
    end
    PaintButtons()
end

local function Restore()
    if not active then return end
    active, theme.on = false, nil
    events:UnregisterAllEvents()
    job:Sleep()
    UndressAll()
    PaintButtons()
end

ns.RegisterModule("clientMenus", { apply = Apply, restore = Restore })
