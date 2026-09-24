local _, ns = ...

-- Our windows stay outside the client's panel system so they can open in combat;
-- they close the client's and vice versa, and stand side by side clear of the client's.

local IsSecret = ns.IsSecret

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
local watchNames, spareNames, watchHave = {}, {}, {}
local namesAt   -- nil: rebuild on the next ask
local function AddWatchName(name)
    if type(name) == "string" and not watchHave[name] then
        watchHave[name] = true
        watchNames[#watchNames + 1] = name
    end
end
local function ClientWindowNames()
    local now = GetTime()
    if not namesAt or now - namesAt > 5 then
        namesAt = now
        watchNames, spareNames = spareNames, watchNames
        wipe(watchNames)
        wipe(watchHave)
        for name in pairs(UIPanelWindows or ns.EMPTY) do AddWatchName(name) end
        for _, name in ipairs(LOOSE_PANELS) do AddWatchName(name) end
        for _, name in ipairs(NPC_WINDOWS) do AddWatchName(name) end
    end
    return watchNames
end

-- Secret values read as nil for layout.
local function Plain(value)
    if value == nil or IsSecret(value) then return nil end
    return value
end

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
    for _, name in ipairs(ClientWindowNames()) do
        local panel = _G[name]
        if type(panel) == "table" and panel.IsShown and panel:IsShown() then
            local left, right = BlockSpan(name, panel)
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
    for _, name in ipairs(ClientWindowNames()) do
        local panel = _G[name]
        if type(panel) == "table" and panel.IsShown then clientShown[name] = ClientUp(name, panel) end
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

function WatchClientWindows()
    if windowWatch then return end
    windowWatch = CreateFrame("Frame")
    -- Rebuild names on any load, or a newly listed window goes unnoticed until the next rebuild.
    windowWatch:RegisterEvent("ADDON_LOADED")
    windowWatch:SetScript("OnEvent", function() namesAt = nil end)
    windowWatch:SetScript("OnUpdate", function(self, elapsed)
        -- Every frame while ours or the social window is up (ours must go the instant the client's
        -- shows), else every 0.25 s: walking 100+ windows every frame was the addon's second cost.
        self.beat = (self.beat or 0) + elapsed
        if self.beat < 0.25 then
            local any = FriendsFrame and FriendsFrame:IsShown()
            if not any then
                for frame in pairs(classicWindows) do
                    if frame:IsShown() then any = true break end
                end
            end
            if not any then return end
        end
        self.beat = 0
        local sig = 0
        for _, name in ipairs(ClientWindowNames()) do
            local panel = _G[name]
            if type(panel) == "table" and panel.IsShown then
                local shown = ClientUp(name, panel)
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
    end)
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

-- Our last anchor x per window; any other anchor means the player or a window mover moved it.
local placedX = setmetatable({}, { __mode = "k" })

-- Moved off its slot: left where it was put. Not the spellbook: its casting layer keeps the slot.
local function Moved(frame)
    local x = placedX[frame]
    if not x or frame.fcuiHoldX then return false end
    local count = frame:GetNumPoints()
    if IsSecret(count) then return false end
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
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, SLOT_Y)
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
local homeWatch = CreateFrame("Frame")
homeWatch:RegisterEvent("PLAYER_REGEN_DISABLED")
homeWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
homeWatch:SetScript("OnEvent", function(_, event)
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
    CreateFrame("Frame", nil, CharacterFrame):SetScript("OnUpdate", CloseSheetGap)
end

function ns.RegisterClassicWindow(frame, shares)
    if not frame or classicWindows[frame] then return end
    classicWindows[frame] = true
    -- Every classic window is built on the first slot (TOPLEFT 0, SLOT_Y).
    placedX[frame] = 0
    frame.fcuiShares = shares and true or false
    frame:HookScript("OnShow", function(self)
        -- The watch may be on its slow beat and not have seen them yet.
        RecordClientWindows()
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

-- In combat the client refuses addon opens: an unprotected window is shown raw (outside the
-- panel list, so the client's Escape skips it), a protected one is left alone. Windows that
-- must close in combat open by a secure press on the client's own opener instead.
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
