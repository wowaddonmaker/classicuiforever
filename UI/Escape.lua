local _, ns = ...

-- Escape closes our windows without joining a client list: UISpecialFrames taints its pass,
-- an Escape-handler entry taints the whole walk (SpellStopCasting refused on every press).
-- Escape is bound to our button while a window is up; bindings are frozen in combat,
-- so there the button clears the target, as Escape does with nothing open.
-- The spellbook is left to the client's Escape, which closes it with the casting layer.
local escButton = CreateFrame("Button", "ForeverClassicUIEscButton", UIParent, "SecureActionButtonTemplate")
local escFrames = {}

-- Idle: clear the target in combat (out of combat the key is handed back).
-- Window up: arm the idle text for the next press; neither a binding nor Lua can in combat.
local ESC_IDLE = "/cleartarget [combat]"
local ESC_WINDOW = "/click ForeverClassicUIEscIdle"

local escIdle = CreateFrame("Button", "ForeverClassicUIEscIdle", UIParent, "SecureActionButtonTemplate")
escIdle:SetSize(1, 1)
escIdle:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
escIdle:EnableMouse(false)
escIdle:RegisterForClicks("AnyUp", "AnyDown")
escIdle:SetAttribute("useOnKeyDown", false)
escIdle:SetAttribute("type", "attribute")
escIdle:SetAttribute("attribute-frame", escButton)
escIdle:SetAttribute("attribute-name", "macrotext")
escIdle:SetAttribute("attribute-value", ESC_IDLE)

-- A bound button must be sized and placed or the key goes to the client; one pixel will do.
escButton:SetSize(1, 1)
escButton:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
escButton:EnableMouse(false)
escButton:Show()
-- Key clicks come on press or release per cast-on-key-down; listen to both.
escButton:RegisterForClicks("AnyDown", "AnyUp")
escButton:SetAttribute("useOnKeyDown", false)
escButton:SetAttribute("type", "macro")
escButton:SetAttribute("macrotext", "")

-- IsVisible skips lists left shown in closed windows; a faded window counts as closed;
-- fcuiEscSkip marks a window on a client panel, whose own Escape closes it.
local function IsOpen(frame)
    return frame:IsVisible() and frame:GetEffectiveAlpha() > 0 and not frame.fcuiEscSkip
end

-- Last shown goes first, as with the client's panels.
local function EscTop()
    local top
    for _, frame in ipairs(escFrames) do
        if IsOpen(frame) and (not top or (frame.fcuiEscAt or 0) >= (top.fcuiEscAt or 0)) then top = frame end
    end
    return top
end

-- Who holds the key: ours, the client (free) or another addon.
local function EscHolder()
    if not GetBindingAction then return "" end
    local ok, action = pcall(GetBindingAction, "ESCAPE", true)
    if not ok or type(action) ~= "string" then return "" end
    if action:find("ForeverClassicUIEscButton", 1, true) then return "ours" end
    if action == "" or action == "TOGGLEGAMEMENU" then return "free" end
    return "other"
end

local function EscUpdate()
    if InCombatLockdown() then return end
    local want = EscTop() ~= nil
    -- The spellbook's own close while its casting layer is up (Lua alone cannot close it).
    local text = (ns.SpellBookEscText and ns.SpellBookEscText())
        or (want and ESC_WINDOW or ESC_IDLE)
    if escButton:GetAttribute("macrotext") ~= text then
        escButton:SetAttribute("macrotext", text)
    end
    local holder = EscHolder()
    if not want then
        if holder == "ours" then ClearOverrideBindings(escButton) end
        return
    end
    if holder == "ours" then return end
    ClearOverrideBindings(escButton)
    SetOverrideBindingClick(escButton, true, "ESCAPE", "ForeverClassicUIEscButton")
end

-- One press closes all of ours, as the client's Escape closes all its panels.
local function EscCloseAll()
    local open = {}
    for _, frame in ipairs(escFrames) do
        if IsOpen(frame) then
            open[#open + 1] = frame
        end
    end
    for _, frame in ipairs(open) do
        if frame.fcuiEscClose then frame.fcuiEscClose(frame) else frame:Hide() end
    end
    -- The spellbook on the client's window may be closed from here.
    if ns.SpellBookEscClose then ns.SpellBookEscClose() end
end

escButton:SetScript("PostClick", function(_, _, down)
    -- Both halves arrive; close on the release.
    if down then return end
    EscCloseAll()
end)

-- Retake the key if something else grabbed it (show and hide alone missed that);
-- the frame catches the end of a fight.
local escWatch = CreateFrame("Frame")
escWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
escWatch:SetScript("OnEvent", EscUpdate)
ns.Sched.Job({ name = "esc.beat", every = 0.3, fn = EscUpdate })

-- In combat the key cannot be taken and the client's Escape clears the target first. So while
-- one of ours is up, the opacity box (hidden early in the walk, FrameworkPre) is kept shown,
-- unseen and deaf: the client hides its own frame untainted and our windows close with it.
local sentinelOurs = false

-- Client frames, looked up until found.
local sentinelBox, sentinelCatcher, sentinelSlider

local function Sentinel()
    local box = sentinelBox
    if box then return box end
    box = _G["OpacityFrame"]
    if not box or not box.IsShown then return nil end
    sentinelBox = box
    return box
end

local function SentinelSlider()
    local slider = sentinelSlider
    if not slider then
        slider = _G["OpacityFrameSlider"]
        sentinelSlider = slider
    end
    return slider
end

-- Showing the box raises a full-screen catcher that hides it on any click (reads as Escape):
-- keep it deaf and down while the box is ours. Only this sets its mouse, so the read is exact.
local function SentinelCatcher(ours)
    local catcher = sentinelCatcher
    if not catcher then
        catcher = _G["OpacityFrameCloseButton"]
        if not catcher then return end
        sentinelCatcher = catcher
    end
    local hears = not ours
    if catcher:IsMouseEnabled() ~= hears then catcher:EnableMouse(hears) end
    if ours and catcher:IsShown() then catcher:Hide() end
end

-- Back to the client's alpha and mouse.
local function SentinelRestore(box)
    box:SetAlpha(1)
    box:EnableMouse(true)
    local slider = SentinelSlider()
    if slider then slider:EnableMouse(true) end
    SentinelCatcher(false)
end

local function SentinelArm(on)
    local box = Sentinel()
    if not box then return end
    if on then
        -- A box someone else opened stays theirs.
        if box:IsShown() then return end
        box:SetAlpha(0)
        box:EnableMouse(false)
        local slider = SentinelSlider()
        if slider then slider:EnableMouse(false) end
        SentinelCatcher(true)
        box:Show()
        SentinelCatcher(true)
        sentinelOurs = true
    elseif sentinelOurs then
        sentinelOurs = false
        if box:IsShown() then box:Hide() end
        SentinelRestore(box)
    end
end

-- GetTime of the last pass that saw the box ours and up (GetTime is per frame).
local sentinelSeenAt = 0

-- top: the window Escape would close now.
local function SentinelPass(top)
    local box = Sentinel()
    if not box then return end
    if sentinelOurs and not box:IsShown() then
        -- Escape hid it: close all of ours, unless a mouse event came since the last pass saw it up (a click).
        sentinelOurs = false
        SentinelRestore(box)
        local clicked = (ns.lastMouseDownAt or 0) > sentinelSeenAt
        if not clicked then
            EscCloseAll()
            top = EscTop()
        end
    end
    SentinelArm(top ~= nil)
    if sentinelOurs then sentinelSeenAt = GetTime() end
end

-- Visible at all, faded or skipped included.
local function EscAnyVisible()
    for i = 1, #escFrames do
        if escFrames[i]:IsVisible() then return true end
    end
    return false
end

-- Runs while one of ours is visible or the box is ours, then sleeps; only SentinelWake
-- (show, hide, sign-up) wakes it. Mouse events still reach it asleep.
local sentinelWatch = CreateFrame("Frame")

local function SentinelWake()
    if not sentinelWatch:IsShown() then sentinelWatch:Show() end
end

local function SentinelUpdate()
    SentinelWake()
    SentinelPass(EscTop())
end

-- Mouse presses from events, not hooks.
pcall(sentinelWatch.RegisterEvent, sentinelWatch, "GLOBAL_MOUSE_DOWN")
pcall(sentinelWatch.RegisterEvent, sentinelWatch, "GLOBAL_MOUSE_UP")
sentinelWatch:SetScript("OnEvent", function() ns.lastMouseDownAt = GetTime() end)
sentinelWatch:SetScript("OnUpdate", function()
    -- Every frame, so the window closes on the press itself.
    if sentinelOurs then SentinelCatcher(true) end
    local top = EscTop()
    if sentinelOurs or top then SentinelPass(top) end
    -- A window found this pass keeps it awake at least one more.
    if not sentinelOurs and not top and not EscAnyVisible() then sentinelWatch:Hide() end
end)

local escShows = 0
function ns.CloseOnEscape(frame, closer)
    if not frame then return end
    frame.fcuiEscClose = closer
    escFrames[#escFrames + 1] = frame
    frame:HookScript("OnShow", function(self)
        escShows = escShows + 1
        self.fcuiEscAt = escShows
    end)
    frame:HookScript("OnShow", EscUpdate)
    frame:HookScript("OnHide", EscUpdate)
    frame:HookScript("OnShow", SentinelUpdate)
    frame:HookScript("OnHide", SentinelUpdate)
    -- Already shown when signed up: no OnShow will wake the watch.
    SentinelWake()
    EscUpdate()
end

-- Out of combat only: in a fight Escape belongs to the client.
-- frame may be a function (built lazily); one GameMenuFrame hook per call, installed now.
function ns.CloseWithGameMenu(frame, closer)
    if not GameMenuFrame then return end
    GameMenuFrame:HookScript("OnShow", function()
        if InCombatLockdown() then return end
        local window = frame
        if type(window) == "function" then window = window() end
        if not window or not window:IsShown() then return end
        if closer then closer(window) else window:Hide() end
    end)
end
