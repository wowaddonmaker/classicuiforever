local _, ns = ...
local L = ns.L

local W = ns.windowEdit
local Plain = ns.Safe

-- Each window's lock beside its close button (the map's beside maximize): the same switch as Movable anytime (the map's
-- Unlock map). Shown while the mouse is on the title bar, or always with windowLocksAlways.
local LOCK = "Interface\\Buttons\\LockButton-"
local LOCK_ZONE_H = 40
local locks, zones, resets, fits = {}, {}, {}, {}   -- entry key -> its lock, title bar zone, reset, reset face fitter
local RESET_TIP = { text = HUD_EDIT_MODE_RESET_POSITION or L["UI_RESET_POSITION"], r = 1, g = 1, b = 1, lines = { {
    L["UI_RESET_POSITION_TIP"], nil, nil, nil, true } } }
-- The reset's red face, as the lock's: the old red button's two ends butted into a square, cut inside its clear edge
-- (drawn from 1 to 79 across, 1 to 22 down, in a 128 x 32 file).
local FACE = "Interface\\Buttons\\UI-Panel-Button-"
local FACE_L, FACE_END, FACE_R, FACE_T, FACE_B = 1 / 128, 12 / 128, 79 / 128, 1 / 32, 22 / 32
-- The lock's and the X's red square in their 32 x 32 files (left, top, right, bottom margins): the face covers only that.
local ART_L, ART_T, ART_R, ART_B = 6 / 32, 7 / 32, 7 / 32, 7 / 32
local CLOSE_SIZE = 32       -- the X's size (Windows/WindowChrome.lua) when a window has none to read
local LIFT = 25     -- the lock and reset over the window's own art and the drag strip
-- Title row icons: sizes over the X's box; X and Y from the X's centre to theirs (at a 32 box: the sheet's 34 stretches X).
local LOCK_EXTRA_WIDTH = 0
local LOCK_EXTRA_HEIGHT = 0
local LOCK_X = -22
local LOCK_Y = 1
local RESET_EXTRA_WIDTH = 0
local RESET_EXTRA_HEIGHT = 0
local RESET_X = -44
local RESET_Y = 1
local RESET_ARROW_WIDTH = 12
local RESET_ARROW_HEIGHT = 12
local RESET_ARROW_X = 0
local RESET_ARROW_Y = 1

local function LockTip(entry)
    local map = entry.quests
    return { text = map and L["UI_MAP_LOCK"] or L["UI_WINDOW_LOCK"], r = 1, g = 1, b = 1, lines = { { function()
        if map then return W.IsFree(entry) and L["UI_UNLOCKED_DRAG_THE_MAP_BY"] or L["UI_LOCKED_CLICK_TO_DRAG_THE"] end
        return W.IsFree(entry) and L["UI_UNLOCKED_DRAG_THE_WINDOW_BY"] or L["UI_LOCKED_CLICK_TO_DRAG_THE_WINDOW"]
    end, nil, nil, nil, true } } }
end

-- Maximized, the map is the client's full screen and nothing of ours moves it: no lock then.
local function LockShown(entry)
    local lock = locks[entry.key]
    if not lock then return end
    local reset = resets[entry.key]
    -- A toplevel window is raised as it opens or is clicked; its drag strip, lock and reset follow it up.
    local frame = ns.WindowFrame(entry)
    local level = frame:GetFrameLevel()
    ns.SetLevelIf(lock, level + LIFT)
    ns.SetLevelIf(reset, level + LIFT)
    local strip = W.StripOf(frame)
    if strip then ns.SetLevelIf(strip, level + W.STRIP_LIFT) end
    local over = ns.db.windowLocksAlways or zones[entry.key]:IsMouseOver() or lock:IsMouseOver() or reset:IsMouseOver()
    local shown = over and not W.Full(entry, frame)
    ns.SetShownIf(lock, shown)
    -- Only a window with a place of its own has one to reset.
    ns.SetShownIf(reset, shown and W.PlaceOf(entry) ~= nil)
end

local function SyncLocks()
    for _, entry in ipairs(W.WINDOWS) do
        local lock = locks[entry.key]
        if lock then
            local state = W.IsFree(entry) and "Unlocked-" or "Locked-"
            lock:SetNormalTexture(LOCK .. state .. "Up")
            lock:SetPushedTexture(LOCK .. state .. "Down")
            -- Under the mouse, its tooltip says the new state at once.
            if GameTooltip:IsOwned(lock) then lock:GetScript("OnEnter")(lock) end
            LockShown(entry)
        end
    end
end

local function ToggleLock(entry)
    W.SetFree(entry, not W.IsFree(entry))
    -- An open edit mode dialog's Movable anytime follows.
    W.Refresh()
end

-- Beside the close button (the map's maximize), looked up while shown: our windows make theirs after they register, and
-- the character sheet sizes its X after the window shows.
local function PlaceLock(entry)
    local frame, lock, reset = ns.WindowFrame(entry), locks[entry.key], resets[entry.key]
    local close = frame.close or frame.Close or frame.CloseButton or _G[entry.name .. "CloseButton"]
    local beside = close
    if entry.quests then
        local border = frame.BorderFrame or frame
        close = border.CloseButton
        beside = border.MaximizeMinimizeFrame or close
    end
    -- The X's box, so the three red squares on the title row match.
    local size = close and Plain(close:GetWidth()) or CLOSE_SIZE
    local resetWidth, resetHeight = size + RESET_EXTRA_WIDTH, size + RESET_EXTRA_HEIGHT
    ns.SetSizeIf(lock, size + LOCK_EXTRA_WIDTH, size + LOCK_EXTRA_HEIGHT)
    if ns.SetSizeIf(reset, resetWidth, resetHeight) then fits[entry.key](resetWidth, resetHeight) end
    -- Centre on centre, so a size grows round it; the art sits alike in every box. Without an X, where one would be.
    local k = size / CLOSE_SIZE
    local rel, relPoint, x, y = beside, "CENTER", 0, 0
    if not beside then rel, relPoint, x, y = frame, "TOPRIGHT", -50, -18 end
    ns.SetPointIf(lock, "CENTER", rel, relPoint, x + LOCK_X * k, y + LOCK_Y)
    -- The reset outside the lock, so the lock stays put as the reset comes and goes.
    ns.SetPointIf(reset, "CENTER", rel, relPoint, x + RESET_X * k, y + RESET_Y)
end

-- The red face in halves (up or down) and the game's gold turning arrow over it, pressed a pixel down with the face.
-- Returns its fitter to a box size.
local function ResetFace(button)
    local left = button:CreateTexture(nil, "BACKGROUND")
    left:SetTexCoord(FACE_L, FACE_END, FACE_T, FACE_B)
    local right = button:CreateTexture(nil, "BACKGROUND")
    right:SetTexCoord(FACE_R - (FACE_END - FACE_L), FACE_R, FACE_T, FACE_B)
    local icon = button:CreateTexture(nil, "ARTWORK")
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-RefreshButton") then
        icon:SetAtlas("UI-RefreshButton")
    else
        icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
    end
    local mid = 0
    local function Press(down)
        left:SetTexture(FACE .. (down and "Down" or "Up"))
        right:SetTexture(FACE .. (down and "Down" or "Up"))
        icon:SetPoint("CENTER", button, "CENTER", mid + RESET_ARROW_X + (down and 1 or 0), RESET_ARROW_Y - (down and 1 or 0))
    end
    button:SetScript("OnMouseDown", function() Press(true) end)
    button:SetScript("OnMouseUp", function() Press(false) end)
    return function(width, height)
        local l, t, r, b = ART_L * width, ART_T * height, ART_R * width, ART_B * height
        mid = (l - r) / 2
        left:ClearAllPoints()
        left:SetPoint("TOPLEFT", l, -t)
        left:SetPoint("BOTTOMRIGHT", button, "BOTTOM", mid, b)
        right:ClearAllPoints()
        right:SetPoint("TOPRIGHT", -r, -t)
        right:SetPoint("BOTTOMLEFT", button, "BOTTOM", mid, b)
        icon:SetSize(RESET_ARROW_WIDTH, RESET_ARROW_HEIGHT)
        Press(false)
    end
end

-- The title bar is watched while the window shows: a hover sensor over it would take the close button's hover.
local function MakeLock(entry)
    local frame = ns.WindowFrame(entry)
    if entry.piece or locks[entry.key] or not frame then return end
    local parent = entry.quests and frame.BorderFrame or frame
    local lock = ns.NewFrame("Button", nil, parent)
    -- Over the drag strip, which reaches under it.
    lock:SetFrameLevel(frame:GetFrameLevel() + LIFT)
    lock:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    lock:SetScript("OnClick", function() ToggleLock(entry) end)
    ns.AttachTip(lock, LockTip(entry))
    -- The lock's size and red face, with a turning arrow: back where it was.
    local reset = ns.NewFrame("Button", nil, parent)
    reset:SetFrameLevel(frame:GetFrameLevel() + LIFT)
    fits[entry.key] = ResetFace(reset)
    reset:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    reset:SetScript("OnClick", function()
        W.Reset(entry)
        SyncLocks()
    end)
    ns.AttachTip(reset, RESET_TIP)
    reset:Hide()
    resets[entry.key] = reset
    local zone = ns.NewFrame("Frame", nil, parent)
    zone:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    zone:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, -LOCK_ZONE_H)
    locks[entry.key], zones[entry.key] = lock, zone
    PlaceLock(entry)
    local function Shown()
        LockShown(entry)
        if lock:IsShown() then PlaceLock(entry) end
    end
    ns.Sched.Attach(frame, { name = "windowLock", every = 0.1, fn = Shown })
    ns.Sched.AfterShow(frame, "windowLock", function()
        PlaceLock(entry)
        Shown()
    end)
    if entry.quests then ns.Sched.OnMove(frame, function() ns.Sched.NextFrame("windows.mapLock", Shown) end) end
end

ns.MakeWindowLock = MakeLock
ns.SyncWindowLocks = SyncLocks
-- For the dev addon's window test.
function ns.WindowLockButtons(key) return locks[key], resets[key] end
ns.OnToggle(function(key) if key == "windowLocksAlways" then SyncLocks() end end)
