local _, ns = ...

-- Our windows stay outside the client's panel system so they can open in combat;
-- they close the client's and vice versa, and stand side by side clear of the client's.

local classicWindows = {}
local WatchClientWindows   -- forward declared: must stay local

-- Client windows outside its panel list; the map opens on its own terms.
local LOOSE_PANELS = { "WorldMapFrame" }

-- Never closed by us: the talents close clears the bars' show-empty-slots note, and the
-- client never acts on a note we cleared.
local LEAVE_OPEN = { PlayerSpellsFrame = true }
-- Client windows that stand beside ours instead of replacing them.
local BESIDE = { CharacterFrame = true }
-- How much of the character window the old sheet's art fills.
local BESIDE_WIDTH = 352
-- Pieces a client window hangs past its right edge.
local SIDE_PIECES = { CharacterFrame = { "ModeTabs" } }
local PlaceClassicWindows   -- forward declared: must stay local

local function HideClientPanels(except)
    if InCombatLockdown() then return end
    for name in pairs(UIPanelWindows or {}) do
        local panel = _G[name]
        -- The guild window kept open unseen under our roster (note bridge).
        local ghost = ns.guildGhost and name == "CommunitiesFrame"
        if panel and panel ~= except and not LEAVE_OPEN[name] and not BESIDE[name] and not ghost and panel:IsShown() and HideUIPanel then
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

-- Windows that replace ours. Not all go through the panel call, so they are watched, never
-- hooked: a hook on the panel call ran inside the client's pass for every window it opened.
local NPC_WINDOWS = { "GossipFrame", "QuestFrame", "MerchantFrame", "MailFrame", "BankFrame", "ClassTrainerFrame",
    "AuctionHouseFrame", "AuctionFrame", "TradeFrame", "TaxiFrame", "FlightMapFrame", "PetStableFrame", "StableFrame",
    "ItemTextFrame", "TabardFrame", "GuildRegistrarFrame", "PetitionFrame", "CraftFrame", "TradeSkillFrame",
    "ProfessionsFrame", "BarberShopFrame", "GuildBankFrame", "InspectFrame", "LootFrame" }
local npcWindow = {}
for _, name in ipairs(NPC_WINDOWS) do npcWindow[name] = true end

local clientShown = {}
local windowWatch

-- Load-on-demand windows join the panel list as they load: rebuild on ADDON_LOADED and every 5 s.
-- Two tables in turn, so a rebuild mid-walk (a load set off by an opening) leaves the walked one whole.
-- watchFrames[i] is watchNames[i]'s frame, nil until it exists.
local watchNames, spareNames, watchHave = {}, {}, {}
local watchFrames, spareFrames = {}, {}
local namesAt   -- nil: rebuild on the next ask
local function IsWindow(panel)
    return type(panel) == "table" and panel.IsShown and true or false
end
local function AddWatchName(name)
    if type(name) == "string" and not watchHave[name] then
        watchHave[name] = true
        local n = #watchNames + 1
        watchNames[n] = name
        local panel = _G[name]
        if IsWindow(panel) then watchFrames[n] = panel end
    end
end
local function ClientWindows()
    local now = GetTime()
    if not namesAt or now - namesAt > 5 then
        namesAt = now
        watchNames, spareNames = spareNames, watchNames
        watchFrames, spareFrames = spareFrames, watchFrames
        wipe(watchNames)
        wipe(watchFrames)
        wipe(watchHave)
        for name in pairs(UIPanelWindows or ns.EMPTY) do AddWatchName(name) end
        for _, name in ipairs(LOOSE_PANELS) do AddWatchName(name) end
        for _, name in ipairs(NPC_WINDOWS) do AddWatchName(name) end
    end
    return watchNames, watchFrames
end

-- Slot i's frame; a window made later is looked up until it exists.
local function WindowAt(names, frames, i)
    local panel = frames[i]
    if panel then return panel end
    panel = _G[names[i]]
    if not IsWindow(panel) then return nil end
    frames[i] = panel
    return panel
end

-- Secret values read as nil for layout.
local Plain = ns.Safe

-- The spellbook's faded stand-in takes no room.
local function Seen(frame)
    if not frame:IsVisible() then return false end
    local alpha = frame.GetEffectiveAlpha and Plain(frame:GetEffectiveAlpha())
    return alpha == nil or alpha > 0
end

-- Left, right in UIParent units, plus the frame's scale ratio (client windows may have their own).
local function Span(frame)
    local left, right = Plain(frame:GetLeft()), Plain(frame:GetRight())
    local scale, screen = Plain(frame:GetEffectiveScale()), UIParent:GetEffectiveScale()
    if not left or not right or not scale or not screen or screen <= 0 then return nil end
    local k = scale / screen
    return left * k, right * k, k
end

-- A client window's drawn left and right edges.
local function ClientSpan(name, panel)
    if not Seen(panel) then return nil end
    local left, right, k = Span(panel)
    if not left then return nil end
    if name == "CharacterFrame" and ForeverClassicUI_CharacterSheetActive then
        -- The old sheet's art is narrower than its frame; the equipment dialog hangs off its edge.
        local extra = ns.EquipmentPaneExtent and ns.EquipmentPaneExtent() or 0
        return left, left + (BESIDE_WIDTH + extra) * k
    end
    local pieces = SIDE_PIECES[name]
    for i = 1, pieces and #pieces or 0 do
        local piece = panel[pieces[i]]
        if type(piece) == "table" and piece.IsVisible and Seen(piece) then
            -- Measure the column's tabs where present: its box is wider.
            local parts = type(piece.Tabs) == "table" and piece.Tabs or { piece }
            for _, part in ipairs(parts) do
                if part.IsVisible and part:IsVisible() then
                    local _, edge = Span(part)
                    if edge and edge > right then right = edge end
                end
            end
        end
    end
    return left, right
end

-- Ours stand around the sheet and talents, and in combat whatever stayed up (nothing can close);
-- centre and full-screen windows float over everything and are left out.
local function StandsBeside(name)
    if ns.guildGhost and name == "CommunitiesFrame" then return false end
    if BESIDE[name] or LEAVE_OPEN[name] then return true end
    local info = UIPanelWindows and UIPanelWindows[name]
    local area = type(info) == "table" and info.area
    return area ~= "center" and area ~= "full"
end

local function BlockSpan(name, panel)
    if not StandsBeside(name) then return nil end
    local ok, left, right = pcall(ClientSpan, name, panel)
    if ok and left and right then return left, right end
end

-- Signature of the client blocks at the last placing; a sum, so walk order cannot change it.
local placedSig
local function Tally(sig, left, right)
    return sig + math.floor(left + 0.5) * 7919 + math.floor(right + 0.5) * 104729 + 1
end

-- The client blocks as { left, right, true }.
local function ClientBlocks()
    local blocks, sig = {}, 0
    local names, frames = ClientWindows()
    for i = 1, #names do
        local panel = WindowAt(names, frames, i)
        if panel and panel:IsShown() then
            local left, right = BlockSpan(names[i], panel)
            if left then
                blocks[#blocks + 1] = { left, right, true }
                sig = Tally(sig, left, right)
            end
        end
    end
    return blocks, sig
end

-- First clear x at or right of x. A client block too wide to stand past (over half of ours
-- would run off screen, e.g. the full-screen map) is ignored.
local function FirstFree(x, width, blocks, drawn)
    local screen = UIParent:GetWidth()
    local half = (drawn or width) / 2
    local moved = true
    while moved do
        moved = false
        for _, block in ipairs(blocks) do
            local skip = block[3] and block[2] + half > screen
            if not skip and x < block[2] and block[1] < x + width then
                x = block[2]
                moved = true
            end
        end
    end
    return math.floor(x + 0.5)
end

-- The frame's own width when wider than its slot (the dual-pane quest log).
local function Drawn(frame, width)
    local drawn = Plain(frame:GetWidth())
    return (drawn and drawn > width) and drawn or width
end

-- Past the right edge: pull back to it if clear of ours (mine), else the first free place
-- from the left, over client windows rather than off screen.
local function OnScreen(x, width, drawn, mine)
    local screen = UIParent:GetWidth()
    if x + drawn <= screen then return x end
    local back = math.floor(screen - drawn)
    if back >= 0 and FirstFree(back, width, mine) == back then return back end
    local left = FirstFree(0, width, mine)
    if left + drawn <= screen then return left end
    return x
end

-- The note bridge's unseen guild window is not one the player opened.
local function ClientUp(name, panel)
    if not panel:IsShown() then return false end
    return not (ns.guildGhost and name == "CommunitiesFrame")
end

-- Marks client windows already up as seen, so they don't close ours.
local function RecordClientWindows()
    local names, frames = ClientWindows()
    for i = 1, #names do
        local panel = WindowAt(names, frames, i)
        if panel then clientShown[names[i]] = ClientUp(names[i], panel) end
    end
end

local function ClientWindowOpened(name, panel)
    -- Talents and the sheet share the screen with ours, in combat too; anything else replaces ours.
    if LEAVE_OPEN[name] or BESIDE[name] then
        PlaceClassicWindows()
        return
    end
    ns.HideClassicWindows(panel)
    -- The social window gives way to an NPC's window too.
    if npcWindow[name] and FriendsFrame and FriendsFrame ~= panel and FriendsFrame:IsShown() then
        ns.HidePanel(FriendsFrame)
    end
end

-- Every frame while ours or the social window is up (ours must go the instant the client's shows).
local function AnyOursUp()
    if FriendsFrame and FriendsFrame:IsShown() then return true end
    for frame in pairs(classicWindows) do
        if frame:IsShown() then return true end
    end
    return false
end

local function WindowPass()
    local sig = 0
    local names, frames = ClientWindows()
    for i = 1, #names do
        local name, panel = names[i], frames[i]
        if not panel then
            panel = _G[name]
            if IsWindow(panel) then frames[i] = panel else panel = nil end
        end
        if panel then
            -- ClientUp inline: one read per window.
            local shown = panel:IsShown() and not (name == "CommunitiesFrame" and ns.guildGhost)
            if shown and not clientShown[name] then ClientWindowOpened(name, panel) end
            if shown then
                local left, right = BlockSpan(name, panel)
                if left then sig = Tally(sig, left, right) end
            end
            clientShown[name] = shown
        end
    end
    -- A block came, went, moved or resized since the last placing.
    if sig ~= placedSig then PlaceClassicWindows() end
end

-- Rebuild names on any load, or a newly listed window goes unnoticed until the next rebuild.
local function NamesStale()
    namesAt = nil
end

-- Every frame while ours or the social window is up, else asleep: an opening of ours (its OnShow) or of the social
-- window (our child under it, run only while it shows) snapshots the client's windows and wakes it.
local windowJob
local function WatchPre(job)
    if AnyOursUp() then return true end
    job:Sleep()
    return false
end

local function WakeWindowWatch()
    if not windowJob or windowJob:IsAwake() then return end
    RecordClientWindows()
    windowJob:Wake()
end

function WatchClientWindows()
    if windowWatch then return end
    windowWatch = ns.EventFrame("ADDON_LOADED", NamesStale)
    -- Otherwise every 0.25 s: walking 100+ windows every frame was the addon's second cost.
    windowJob = ns.Sched.OnFrame(windowWatch, { name = "windows.watch", every = 0.25, pre = WatchPre, fn = WindowPass })
    if FriendsFrame then ns.Sched.Attach(FriendsFrame, { name = "windows.social", every = 0, fn = WakeWindowWatch }) end
end

function ns.HideClassicWindows(except)
    for frame in pairs(classicWindows) do
        if frame ~= except and frame:IsShown() then
            frame:Hide()
        end
    end
end

-- Sharing windows stand side by side in open order, shifting left as one shuts;
-- a non-sharing one (the quest log) has the place to itself.
local SLOT_Y, SLOT_STEP = -104, 352
local showCount = 0

-- Protected or anchor-restricted, asked under pcall.
local function Locked(frame)
    local ok, locked = pcall(frame.IsProtected, frame)
    if not (ok and locked) and frame.IsAnchoringRestricted then
        ok, locked = pcall(frame.IsAnchoringRestricted, frame)
    end
    return ok and locked
end
ns.WindowLocked = Locked

-- Our last anchor x per window; any other anchor means the player or a window mover moved it.
local placedX = setmetatable({}, { __mode = "k" })

-- Moved off its slot: left where it was put. Not the spellbook: its casting layer keeps the slot.
local function Moved(frame)
    local x = placedX[frame]
    if not x or frame.fcuiHoldX then return false end
    local count = frame:GetNumPoints()
    if ns.IsSecret(count) then return false end
    if count ~= 1 then return true end
    local point, rel, relPoint, ox, oy = frame:GetPoint(1)
    if ns.AnySecret(point, rel, relPoint, ox, oy) or not ox or not oy then return false end
    return point ~= "TOPLEFT" or relPoint ~= "TOPLEFT" or (rel ~= nil and rel ~= UIParent)
        or math.abs(ox - x) > 0.5 or math.abs(oy - SLOT_Y) > 0.5
end

-- Where a window must stay, or nil: its own fcuiHoldX (the spellbook under live casting
-- buttons), a moved window's place, or in combat a protected window's actual place.
local function HeldAt(frame)
    local at = frame.fcuiHoldX and frame:fcuiHoldX()
    if at then return at end
    if not Moved(frame) and not (InCombatLockdown() and Locked(frame)) then return nil end
    local left = Span(frame)
    return left and math.floor(left + 0.5) or frame.fcuiSlotX or 0
end

local function PlaceAt(frame, x)
    frame.fcuiSlotX = x
    placedX[frame] = x
    ns.SetPointOnce(frame, "TOPLEFT", UIParent, "TOPLEFT", x, SLOT_Y)
    if frame.OnClassicPlaced then frame:OnClassicPlaced(x, SLOT_Y) end
end

PlaceClassicWindows = function()
    local shown = {}
    for frame in pairs(classicWindows) do
        if frame:IsShown() then shown[#shown + 1] = frame end
    end
    table.sort(shown, function(a, b) return (a.fcuiShownAt or 0) < (b.fcuiShownAt or 0) end)
    -- Never tell the client's manager where to stand its windows: that write made its opening
    -- run as ours, and its health text then compared a secret.
    local blocks, sig = ClientBlocks()
    placedSig = sig
    -- fcuiSlotWidth includes side tabs. Held windows keep their place, the rest fill round;
    -- mine collects our own blocks for OnScreen.
    local held, mine = {}, {}
    for _, frame in ipairs(shown) do
        local at = HeldAt(frame)
        if at then
            held[frame] = at
            local block = { at, at + (frame.fcuiSlotWidth or SLOT_STEP) }
            blocks[#blocks + 1] = block
            mine[#mine + 1] = block
        end
    end
    local cursor = 0
    for _, frame in ipairs(shown) do
        local width = frame.fcuiSlotWidth or SLOT_STEP
        local x = held[frame]
        if x then
            -- Held: never moved, only the record updated.
            frame.fcuiSlotX = x
        else
            local keep = frame.fcuiKeep and frame:fcuiKeep()
            local right = keep and keep:IsShown() and keep:GetRight()
            if right then cursor = math.max(cursor, math.floor(right + 0.5)) end
            local drawn = Drawn(frame, width)
            x = OnScreen(FirstFree(cursor, width, blocks, drawn), width, drawn, mine)
            if frame.fcuiSlotX ~= x then PlaceAt(frame, x) end
            mine[#mine + 1] = { x, x + width }
            cursor = math.max(cursor, x + width)
        end
    end
end

-- A placed window's reset (WindowHandles.lua): ours back on the slots now; false for a client window.
function ns.ReturnClassicWindow(frame)
    if not classicWindows[frame] then return false end
    PlaceAt(frame, frame.fcuiSlotX or 0)
    PlaceClassicWindows()
    return true
end

-- Out of combat, closed windows not moved go home: first clear place from the left, else on screen.
-- A book opened in combat cannot move under its casting buttons, so it must already be home.
local function HomeClosedWindows()
    if InCombatLockdown() then return end
    local blocks, none
    for frame in pairs(classicWindows) do
        if not frame:IsShown() and not Moved(frame) then
            blocks, none = blocks or ClientBlocks(), none or {}
            local width = frame.fcuiSlotWidth or SLOT_STEP
            local drawn = Drawn(frame, width)
            local x = OnScreen(FirstFree(0, width, blocks, drawn), width, drawn, none)
            if (frame.fcuiSlotX or 0) ~= x then PlaceAt(frame, x) end
        end
    end
end
-- The last moment before combat anything may move, and the first after, to re-place what it held.
local HOME_EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
ns.EventFrame(HOME_EVENTS, function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        HomeClosedWindows()
    else
        PlaceClassicWindows()
        HomeClosedWindows()
    end
end)

-- The manager counts the sheet as frame + 82 (mode tabs) but we draw BESIDE_WIDTH,
-- so windows after it are stood at the drawn edge.
local SHEET_NEXT = { left = { "center", "right" }, center = { "right" } }
local sheetGap

-- Moves a client window's left edge to x on its manager's anchor, on screen; nil if it cannot move.
local function StandAt(panel, x)
    if InCombatLockdown() and Locked(panel) then return end
    local left, right, k = Span(panel)
    if not left then return end
    if x > left then x = math.max(left, math.min(x, UIParent:GetWidth() - (right - left))) end
    if math.abs(x - left) < 0.5 then return left end
    if Plain(panel:GetNumPoints()) ~= 1 then return end
    local point, rel, relPoint, ox, oy = panel:GetPoint(1)
    ox, oy = Plain(ox), Plain(oy)
    if not ox or not oy or Plain(point) ~= "TOPLEFT" or Plain(relPoint) ~= "TOPLEFT" then return end
    if rel ~= nil and Plain(rel) ~= UIParent then return end
    if not pcall(panel.SetPoint, panel, "TOPLEFT", UIParent, "TOPLEFT", ox + (x - left) / k, oy) then return end
    return x
end

local function CloseSheetGap()
    local getPanel, getWidth = _G.GetUIPanel, _G.GetUIPanelWidth
    if not ForeverClassicUI_CharacterSheetActive or not getPanel or not getWidth then return end
    local slot = (getPanel("left") == CharacterFrame and "left") or (getPanel("center") == CharacterFrame and "center")
    local keys = slot and SHEET_NEXT[slot]
    local first = keys and getPanel(keys[1])
    if not (first and first:IsShown()) then return end
    local ok, _, x = pcall(ClientSpan, "CharacterFrame", CharacterFrame)
    if not (ok and x) then return end
    if not sheetGap then
        local layout = _G.GetUIPanelLayoutAttribute
        local gap = layout and Plain(layout("PANEl_SPACING_X"))
        sheetGap = type(gap) == "number" and gap or 32
    end
    for _, key in ipairs(keys) do
        local panel = getPanel(key)
        -- A native center window is centred, not in the row.
        if not (panel and panel:IsShown()) or panel:GetAttribute("UIPanelLayout-area") == "center" then return end
        -- A faded one (the spellbook's stand-in) takes no room and stays put.
        if Seen(panel) then
            local at = StandAt(panel, x + (Plain(panel:GetAttribute("UIPanelLayout-xoffset")) or 0) + sheetGap)
            local okWidth, width = pcall(getWidth, panel)
            width = okWidth and Plain(width)
            -- One left where the manager put it keeps the next one in step.
            if not at or type(width) ~= "number" then return end
            x = at + width
        end
    end
end

-- Parented to the character window so it runs only while that is up.
if CharacterFrame then
    ns.Sched.OnFrame(CreateFrame("Frame", nil, CharacterFrame), { name = "windows.sheetGap", every = 0, fn = CloseSheetGap })
end

function ns.RegisterClassicWindow(frame, shares)
    if not frame or classicWindows[frame] then return end
    classicWindows[frame] = true
    -- A micro button's window made on first open; a place given in edit mode applies from now.
    if ns.MicroWindowsChanged then ns.MicroWindowsChanged() end
    if ns.PlaceSavedWindows then ns.PlaceSavedWindows() end
    -- Every classic window is built on the first slot (TOPLEFT 0, SLOT_Y).
    placedX[frame] = 0
    frame.fcuiShares = shares and true or false
    frame:HookScript("OnShow", function(self)
        -- The watch may be asleep or on its slow beat and not have seen them yet.
        RecordClientWindows()
        if windowJob then windowJob:Wake() end
        showCount = showCount + 1
        self.fcuiShownAt = showCount
        for other in pairs(classicWindows) do
            if other ~= self and other:IsShown() and not (self.fcuiShares and other.fcuiShares) then other:Hide() end
        end
        -- fcuiKeep names the client window it belongs beside (the inspect window's talents).
        HideClientPanels(self.fcuiKeep and self:fcuiKeep() or nil)
        PlaceClassicWindows()
    end)
    frame:HookScript("OnHide", function()
        PlaceClassicWindows()
        HomeClosedWindows()
    end)
    WatchClientWindows()
end

-- A window shown raw in a fight is off the client's panel list, so its Escape skips it. A child of ours signed up with
-- our Escape stands in, counted open while the window shows off that list (read each frame, not on show edges).
-- Never under a client layout frame (its layout pass would be ours).
local PANEL_SLOTS = { "left", "center", "right", "doublewide", "fullscreen" }
local escProxies = {}

local function OnPanelList(frame)
    local panelIn = _G.GetUIPanel
    if not panelIn then return true end
    for i = 1, #PANEL_SLOTS do
        if panelIn(PANEL_SLOTS[i]) == frame then return true end
    end
    return false
end

local function EscProxy(frame)
    if escProxies[frame] or frame.Layout then return end
    local proxy = CreateFrame("Frame", nil, frame)
    escProxies[frame] = proxy
    ns.CloseOnEscape(proxy, function() ns.HidePanel(frame) end, function() return not OnPanelList(frame) end, frame)
    if ns.debugSink then ns.Persist("esc: stand-in made for " .. tostring(frame:GetName())) end
end

-- In combat the client refuses addon opens: an unprotected window is shown raw (outside the
-- panel list; our Escape closes it), a protected one is left alone.
function ns.ShowPanel(frame)
    if not frame or frame:IsShown() then return true end
    if not InCombatLockdown() then
        if ShowUIPanel then ShowUIPanel(frame) else frame:Show() end
        return true
    end
    if frame.IsProtected and frame:IsProtected() then return false end
    -- No anchor until its panel call has opened it once: give it the client's left place.
    if frame.GetNumPoints and frame:GetNumPoints() == 0 then
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
    end
    frame:Show()
    EscProxy(frame)
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
