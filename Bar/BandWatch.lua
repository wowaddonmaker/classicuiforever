local _, ns = ...
local B = ns.band

-- Watch, never hook: our code inside the client's layout pass taints that pass for the session.
-- What the band owns is sampled after our pass; a changed sample means the client moved it.

local CAP_SIZE, ROW_X, ROW_Y = B.CAP_SIZE, B.ROW_X, B.ROW_Y
local OWNED_SYSTEMS, EXTRA_BARS, BAG_BUTTONS, CAP_KEYS = B.OWNED_SYSTEMS, B.EXTRA_BARS, B.BAG_BUTTONS, B.CAP_KEYS
local Record, Differs, Drifted, Due, BarSetting, StatusPair = B.Record, B.Differs, B.Drifted, B.Due, B.BarSetting, B.StatusPair
local BandNow, OneBar, ArtWidth, HomeSpot, NearBandSlot = B.BandNow, B.OneBar, B.ArtWidth, B.HomeSpot, B.NearBandSlot
local PaintArt, CapFrame, CapHeldKey, CapMoved, CapSlot = B.PaintArt, B.CapFrame, B.CapHeldKey, B.CapMoved, B.CapSlot
local HideSelections, KeepBarShape = B.HideSelections, B.KeepBarShape
local LayoutBags, FollowBagsDialog, MicroButtonList, LayoutMicroButtons = B.LayoutBags, B.FollowBagsDialog, B.MicroButtonList, B.LayoutMicroButtons
local LayoutStatusBars, MarkStatus, StatusMoved, StatusBack = B.LayoutStatusBars, B.MarkStatus, B.StatusMoved, B.StatusBack
local FadeNewDividers = B.FadeNewDividers
local BarVertical, BarRows, SideBarPair, UnpinnedBars, ForgetLayout = B.BarVertical, B.BarRows, B.SideBarPair, B.UnpinnedBars, B.ForgetLayout
local EDIT_MARK = B.EDIT_MARK
local EditModeLive = ns.EditMode.Live
local SafeCall = ns.SafeCall

-- dragging: left button held in edit mode; bagsDropped: the next pass checks where the bags went; bagsInHand: bags held.
B.dragging = false
B.bagsDropped = false
B.bagsInHand = false

local watchList, baseline = {}, {}
-- A bar seen moved by the client during a fight.
local shiftSeen = false

local function WatchList()
    if #watchList > 0 then return watchList end
    -- BagsBar comes in with the owned systems.
    local names = { "BottomManagedFrameContainer", "RightManagedFrameContainer", "MicroMenu" }
    for _, name in ipairs(OWNED_SYSTEMS) do names[#names + 1] = name end
    -- Bars 6-8 too: the client re-lays their buttons on a setting change, which shows as a size change.
    for _, name in ipairs(EXTRA_BARS) do names[#names + 1] = name end
    names[#names + 1] = BAG_BUTTONS[1]
    for _, name in ipairs(names) do
        local frame = _G[name]
        if frame and frame.GetPoint then watchList[#watchList + 1] = frame end
    end
    local micro = MicroButtonList()[1]
    if micro then watchList[#watchList + 1] = micro end
    -- End caps: the client snaps them back to bar 1's own ends.
    for _, key in ipairs(CAP_KEYS) do
        local cap = CapFrame(ns.GetMainBar(), key)
        if cap and cap.GetPoint then watchList[#watchList + 1] = cap end
    end
    return watchList
end

-- A button leaving the middle of a row moves nothing sampled, so rows are counted.
local function Census()
    local micro, bags = 0, 0
    local list = MicroButtonList()
    for i = 1, #list do
        if list[i]:IsShown() then micro = micro + 1 end
    end
    for i = 1, #BAG_BUTTONS do
        local button = _G[BAG_BUTTONS[i]]
        if button and button:IsShown() then bags = bags + 1 end
    end
    return micro, bags
end

-- Bag and micro rows button by button: the client re-lays both and may leave a row's first button; unprotected, so back mid-fight.
local rowList
local rowBase = {}
local function RowFrames()
    if rowList then return rowList end
    local list = {}
    for _, name in ipairs(BAG_BUTTONS) do
        if _G[name] then list[#list + 1] = _G[name] end
    end
    for _, extra in ipairs({ KeyRingButton, CharacterReagentBag0Slot }) do
        if extra then list[#list + 1] = extra end
    end
    local micro = MicroButtonList()
    for _, button in ipairs(micro) do list[#list + 1] = button end
    -- Cached once the micro menu has been read (not before the first pass).
    if #micro > 0 then rowList = list end
    return list
end

local function MarkRows()
    for _, frame in ipairs(RowFrames()) do rowBase[frame] = Record(frame, rowBase[frame]) end
end

local function RowsMoved()
    local list = RowFrames()
    for i = 1, #list do
        local frame = list[i]
        local b = rowBase[frame]
        if b and Differs(frame, b) then return true end
    end
    return false
end
B.RowsMoved = RowsMoved

-- Per-frame tripwire between beats: row ends vs our last pass (the bag bar re-lays on cursor change: each pickup and drop).
function B.hot.Trip()
    local hot = B.hot
    local ends = hot.ends
    if not ends then
        if not rowList then return false end
        ends = {}
        for _, name in ipairs({ BAG_BUTTONS[1], BAG_BUTTONS[#BAG_BUTTONS], "KeyRingButton", "CharacterReagentBag0Slot" }) do
            if _G[name] then ends[#ends + 1] = _G[name] end
        end
        local micro = MicroButtonList()
        if micro[1] then ends[#ends + 1] = micro[1] end
        if #micro > 1 then ends[#ends + 1] = micro[#micro] end
        hot.ends = ends
    end
    for i = 1, #ends do
        local frame = ends[i]
        local b = rowBase[frame]
        if b and Drifted(frame, b) then return true end
    end
    return false
end

-- Whether every row button may move in a fight (plain buttons here); a protected one makes the rows wait like the bars.
local function RowsFree()
    for _, frame in ipairs(RowFrames()) do
        if frame.IsProtected and frame:IsProtected() then return false end
    end
    return true
end

local function LayRows()
    LayoutBags()
    LayoutMicroButtons()
end

local function RowsBack()
    B.WhileApplying(LayRows)
    MarkRows()
end

-- Tripwire answer: rows only, outside the burst guard (the bag bar re-lays on the player's cursor, not in answer to us).
function B.hot.RowsFix()
    if B.applying or not RowsFree() then return false end
    RowsBack()
    return true
end

-- Our pass just placed everything: the baseline the client must change for the watch to answer.
function B.Snapshot()
    for _, frame in ipairs(WatchList()) do baseline[frame] = Record(frame, baseline[frame]) end
    MarkRows()
    baseline.micro, baseline.bags = Census()
    MarkStatus()
end

local function RowsInFight()
    B.ReadShape()
    LayRows()
end

-- In a fight an unmoved cap rides the art's new end (its frame stays put); back on its frame at the next full pass.
local function CapsInFight()
    local art = B.art
    local w = ArtWidth()
    for _, key in ipairs(CAP_KEYS) do
        if not CapMoved(key) then
            ns.SetPointOnce(B.CapTexture(key), "BOTTOM", art, "BOTTOMLEFT", w / 2 + CapSlot(key, w), 0)
        end
    end
end

-- Micro group dropped in a fight: the full pass waits for the fight's end (it moves bars); floor, bags, art and
-- tracking bars follow now (a locked holder waits for the fight's end). The band frame keeps its length.
function ns.MicroDroppedInFight()
    if not InCombatLockdown() or not RowsFree() then return end
    B.WhileApplying(RowsInFight)
    B.WhileApplying(PaintArt)
    B.WhileApplying(LayoutStatusBars)
    B.WhileApplying(CapsInFight)
    MarkRows()
    MarkStatus()
end

local function Moved(list)
    local frames = list or WatchList()
    for i = 1, #frames do
        local frame = frames[i]
        if Differs(frame, baseline[frame]) then return true end
    end
    if not list then
        local micro, bags = Census()
        if micro ~= baseline.micro or bags ~= baseline.bags then return true end
    end
    return false
end
B.Moved = Moved

-- Dragging bar 1 in edit mode is the one move the band follows; its reset-to-default hands placement back.
local function ReadBarPlacement()
    local bar = ns.GetMainBar()
    if not bar then return end
    local info = bar.systemInfo
    if ns.db.barDragged then
        if info and info.isInDefaultPosition then
            ns.db.barDragged = false
            ns.QueueApply()
        end
        return
    end
    if baseline[bar] and Differs(bar, baseline[bar]) then ns.db.barDragged = true end
end

-- Bar 1 dropped near the centred spot goes exactly home (the client snaps its buttons, not the band, to the centre line);
-- by our record, never a layout write (that marks every piece as ours).
local HOME_REACH = 40
local function SnapBarHome()
    local bar = ns.GetMainBar()
    if not bar or not B.art or not ns.db.barDragged or InCombatLockdown() then return end
    local left, bottom = bar:GetLeft(), bar:GetBottom()
    local screen = UIParent:GetWidth()
    if not left or not bottom or not screen then return end
    -- Bar 1 keeps scale 1: its edges are in screen units.
    local homeX, homeY = HomeSpot(BandNow())
    local wantLeft = screen / 2 + homeX
    local wantBottom = homeY
    if math.abs(left - wantLeft) > HOME_REACH or math.abs(bottom - wantBottom) > HOME_REACH then return end
    ns.db.barDragged = false
    ns.MirrorSave()
end

-- The edit watch's slower beat: in edit mode, and out of it.
local WATCH_EDIT, WATCH_IDLE = 0.05, 0.2
local SAVE_REVERT = { "SaveChangesButton", "RevertAllChangesButton" }
-- Set while a band piece is, or has just been, in the player's hand.
local handHeld = false
local handIdle = 0
-- The end cap last seen in hand, read on release.
local capInHand
-- Burst guard: cuts off a burst of changes (the client answering our own move) so the two never chase each other.
local burst, burstAt, hold = 0, 0, 0
-- Edit watch beats, and settings last read in edit mode, one entry per EDIT_MARK bar.
local edit = { cool = 0, since = 0, marked = false, live = false, followed = false }
local marks = {}
for i = 1, #EDIT_MARK do marks[i] = {} end
-- The band's systems and bars 6-8, cached once all exist.
local handFrames, handWhole = {}, false

-- The lane runs only while the band is on; shown by Apply out of combat, it re-registers at once to stay the last fight listener.
function B.SetLane(on)
    local lane = B.lane
    if not lane then return end
    lane.dozing = false
    if on then
        if not lane:IsShown() then
            lane:Show()
            lane:UnregisterEvent("PLAYER_REGEN_DISABLED")
            lane:RegisterEvent("PLAYER_REGEN_DISABLED")
        end
    elseif lane:IsShown() then
        lane:Hide()
    end
end

local function HandFrames()
    if handWhole then return handFrames end
    wipe(handFrames)
    handWhole = true
    for _, name in ipairs(OWNED_SYSTEMS) do
        local frame = _G[name]
        if frame then handFrames[#handFrames + 1] = frame else handWhole = false end
    end
    for _, name in ipairs(EXTRA_BARS) do
        local frame = _G[name]
        if frame then handFrames[#handFrames + 1] = frame else handWhole = false end
    end
    return handFrames
end

-- A band piece in the player's hand (client drag flags, our micro group's own): a pass of ours mid-drag became the drop.
-- A held mouse alone is not a drag: a size slider is followed as it moves.
local function PieceInHand()
    local frames = HandFrames()
    for i = 1, #frames do
        if frames[i].isDragging then return true end
    end
    local bar = ns.GetMainBar()
    for _, key in ipairs(CAP_KEYS) do
        local cap = CapFrame(bar, key)
        if cap and cap.isDragging then
            capInHand = key
            return true
        end
    end
    local home = B.art and B.art.microHome
    return (home and home.moving) and true or false
end

-- The client re-stands its bottom container on many passes, fights included: put back alone, no full pass for it.
local function KeepContainer()
    local kept = B.KeepBottomContainer()
    if kept and baseline[kept] then baseline[kept] = Record(kept, baseline[kept]) end
end
B.KeepContainer = KeepContainer

-- The client re-lays bars on its own (e.g. a new target): checked every frame and laid on the spot, so it lives a frame at
-- most; in a fight the bars are the client's. fromLane: the lane kept the container this frame, no client code since.
local function PlaceNow(fromLane)
    if not B.active or B.applying then return end
    if not fromLane then KeepContainer() end
    -- A piece in hand blocks us until the beat reads the drop: the pass at release took bar 1 as unmoved and put it back.
    if PieceInHand() then
        -- Bar 1 picked up from its default place: the band (ours) hangs on it for the drag.
        local bar = ns.GetMainBar()
        local art = B.art
        if bar and bar.isDragging and art and not handHeld then
            ns.SetPointOnce(art, "BOTTOMLEFT", bar, "BOTTOMLEFT", -ROW_X, -ROW_Y)
        end
        -- Any other bar picked up off the band: its buttons hang on a band row (so the client can't carry them off in a fight)
        -- and stayed behind while its box followed the mouse. Our row hangs on the bar for the drag; the drop's pass lays it.
        for other, hung in pairs(B.rowOf) do
            if other ~= bar and other.isDragging and not hung.onBar and not InCombatLockdown() then
                hung.onBar = true
                hung.row:ClearAllPoints()
                if hung.vertical then
                    hung.row:SetPoint("TOPLEFT", other, "TOPLEFT", 0, 0)
                else
                    hung.row:SetPoint("BOTTOMLEFT", other, "BOTTOMLEFT", 0, 0)
                end
            end
        end
        handHeld = true
        return
    end
    if handHeld then
        -- The beat clears this as it reads the drop; failing that, 30 frames of mouse up with nothing in hand frees the band.
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            handIdle = (handIdle or 0) + 1
            if handIdle > 30 then handHeld, handIdle = false, 0 end
        end
        if handHeld then return end
    end
    handIdle = 0
    local rows = RowsMoved()
    -- The bars are the client's to move in a fight; the bag and micro rows are not and go straight back.
    local fight = InCombatLockdown()
    if fight then
        -- A fight with edit mode up at any point isn't judged: the player is moving things and the client re-lays as they do.
        if EditModeLive() then
            ns.fightEdited = true
            shiftSeen = false
        end
        if not shiftSeen and not ns.fightEdited then
            for _, frame in ipairs(UnpinnedBars()) do
                -- Only a bar the band has a recorded place for.
                if baseline[frame] and Differs(frame, baseline[frame]) then
                    shiftSeen = true
                    -- Dev log: which bar, when, from where to where; built only with a dev sink attached (ns.Persist drops it otherwise).
                    if ns.debugSink then
                        local b = baseline[frame]
                        local point, rel, relPoint, x, y = frame:GetPoint(1)
                        ns.Persist(string.format("bars: %s off its place %.2f s into the fight: was %s>%s.%s %.0f,%.0f scale %.2f shown %s; now %s>%s.%s %.0f,%.0f scale %.2f shown %s",
                            tostring(frame:GetName()), GetTime() - (ns.fightBeganAt or GetTime()),
                            tostring(b.point), tostring(b.rel and b.rel.GetName and b.rel:GetName()), tostring(b.relPoint), b.x or 0, b.y or 0, b.scale or 1, tostring(b.shown),
                            tostring(point), tostring(rel and rel.GetName and rel:GetName()), tostring(relPoint), x or 0, y or 0, frame:GetScale() or 1, tostring(frame:IsShown())))
                    end
                    break
                end
            end
        end
        if not (rows and RowsFree()) then return end
    elseif ns.fightEdited then
        ns.fightEdited = nil
        shiftSeen = false
    elseif shiftSeen then
        -- One pass after a fight in which the client moved a bar (the frames come back; nothing drawn went with them).
        shiftSeen = false
        ns.Persist("bars: moved by the client during a fight; put back, nobody asked")
    elseif not rows and not Moved() then
        return
    end
    -- The burst guard is for the client answering our moves; a held mouse in edit mode is the player's (a slider), always followed.
    local byHand = EditModeLive() and IsMouseButtonDown and IsMouseButtonDown("LeftButton")
    -- A held-off pass still puts moved rows back (they re-lay on the cursor, not for us); in a fight RowsFree was checked above.
    if not byHand then
        local now = GetTime()
        if now < hold then
            if rows then RowsBack() end
            return
        end
        if now - burstAt < 1 then burst = burst + 1 else burst = 0 end
        burstAt = now
        if burst > 8 then
            burst, hold = 0, now + 0.6
            if rows then RowsBack() end
            return
        end
    end
    if fight then RowsBack() else ns.SafeCall(B.Apply) end
end

-- Bag windows open from the screen corner but belong over the bags: the first hangs from the backpack, the client chains
-- the rest. Every frame, so none shows in the corner first; with the option and the row off the bar, at the row's size.
local scaledWindows = false
-- How far in from the screen's right edge bags start, beside the right bars (the client does so only for default bars, and
-- one locked into the classic layout is not); a bar counts by what it is on screen: standing, shown, at the right edge.
local function RightColumnsWidth()
    if ns.db and ns.db.bagsBesideBars == false then return 0 end
    local screenRight = UIParent:GetRight()
    if not screenRight then return 0 end
    local leftmost
    for _, bar in ipairs(SideBarPair()) do
        if bar and bar:IsVisible() and (bar:GetAlpha() or 1) > 0 then
            local s = bar:GetEffectiveScale() / UIParent:GetEffectiveScale()
            local l, r, w, h = bar:GetLeft(), bar:GetRight(), bar:GetWidth(), bar:GetHeight()
            if l and r and w and h and h > w * 2 and (screenRight - r * s) < 100 then
                if not leftmost or l * s < leftmost then leftmost = l * s end
            end
        end
    end
    return leftmost and math.max(0, screenRight - leftmost) or 0
end
local besideSet = false
-- The client wraps bag columns ignoring gaps and the minimap; ours measures the windows at their scale and wraps below the
-- screen top or the minimap cluster, on the client's anchors (8 up, 11 across), set only on change.
local function WrapOpenBags(shown)
    local first = shown[1]
    local ui = UIParent:GetEffectiveScale()
    local top = UIParent:GetTop()
    local bottom, right = first:GetBottom(), first:GetRight()
    if not (top and bottom and right and ui and ui > 0) then return end
    local k = first:GetEffectiveScale() / ui
    bottom, right = bottom * k, right * k
    local mapL, mapR, mapB
    local cluster = MinimapCluster
    if cluster and cluster:IsVisible() then
        local c = cluster:GetEffectiveScale() / ui
        local l, r, b = cluster:GetLeft(), cluster:GetRight(), cluster:GetBottom()
        if l and r and b and b * c > bottom then mapL, mapR, mapB = l * c, r * c, b * c end
    end
    local head, headLeft = first, right - first:GetWidth() * k
    local reach = bottom + first:GetHeight() * k
    local prev = first
    for i = 2, #shown do
        local frame = shown[i]
        k = frame:GetEffectiveScale() / ui
        local w, h = frame:GetWidth() * k, frame:GetHeight() * k
        local wrap = prev.IsCombinedBagContainer and prev:IsCombinedBagContainer()
        if not wrap then
            local limit = top
            if mapB and right > mapL and right - w < mapR and mapB < limit then limit = mapB end
            wrap = reach + 8 * k + h > limit
        end
        local rel, relPoint, x, y
        if wrap then
            right = headLeft - 11 * k
            headLeft, reach = right - w, bottom + h
            rel, relPoint, x, y = head, "BOTTOMLEFT", -11, 0
            head = frame
        else
            reach = reach + 8 * k + h
            rel, relPoint, x, y = prev, "TOPRIGHT", 0, 8
        end
        -- Per frame while bags are open: a plain read, no secret values here.
        local p, r, rp, px, py = frame:GetPoint(1)
        if p ~= "BOTTOMRIGHT" or r ~= rel or rp ~= relPoint or math.abs((px or 0) - x) > 0.01 or math.abs((py or 0) - y) > 0.01 then
            ns.SetPointOnce(frame, "BOTTOMRIGHT", rel, relPoint, x, y)
        end
        prev = frame
    end
end
local function AnchorOpenBags()
    local manager = ContainerFrameSettingsManager
    if not manager then return end
    -- The client's list, rebuilt by it on every open and close; rebuilt here only when dirty with a window up.
    local shown = manager.bagsShown
    if shown ~= nil and (type(shown) ~= "table" or shown[1] == nil) then return end
    local backpack = MainMenuBarBackpackButton
    if not backpack or not backpack:IsVisible() then return end
    if shown == nil then
        local combined, single = ContainerFrameCombinedBags, _G.ContainerFrame1
        if not ((combined and combined:IsShown()) or (single and single:IsShown())) then return end
        if not manager.GetBagsShown then return end
        local ok, list = pcall(manager.GetBagsShown, manager)
        shown = ok and list
    end
    local first = type(shown) == "table" and shown[1]
    if not first or not first.GetPoint then return end
    local _, relativeTo = first:GetPoint(1)
    if not (ns.db and ns.db.bagsAboveRow == true) then
        -- Default placement: a window still hanging from the backpack is one we hung, so the client re-lays them.
        if relativeTo == backpack and type(UpdateContainerFrameAnchors) == "function" then
            pcall(UpdateContainerFrameAnchors)
        end
        -- The first window starts the stack from the screen corner and the rest hang from it; only its inset is ours,
        -- read every frame since the client re-lays them as one opens or shuts.
        local point, rel, relPoint, x, y = first:GetPoint(1)
        if point == "BOTTOMRIGHT" and relPoint == "BOTTOMRIGHT" and rel and rel == first:GetParent() then
            local width = RightColumnsWidth()
            if width > 0 then
                local scale = first:GetScale() or 1
                if scale <= 0 then scale = 1 end
                local target = -(width + 10) / scale
                if math.abs((x or 0) - target) > 0.5 then
                    first:SetPoint(point, rel, relPoint, target, y or 0)
                end
                besideSet = true
            elseif besideSet then
                besideSet = false
                if type(UpdateContainerFrameAnchors) == "function" then pcall(UpdateContainerFrameAnchors) end
            end
        end
    elseif relativeTo ~= backpack then
        ns.SetPointOnce(first, "BOTTOMRIGHT", backpack, "TOPRIGHT", 0, 10)
    end
    local piece = BagsBar
    local follow = ns.db and ns.db.bagWindowsFollow and piece and ((B.shape.bagsReal == false) or OneBar())
    if follow or scaledWindows then
        local base = 1
        if type(GetContainerScale) == "function" then
            local okScale, value = pcall(GetContainerScale)
            if okScale and type(value) == "number" and value > 0 then base = value end
        end
        local want = follow and base * (piece:GetScale() or 1) or base
        for _, frame in ipairs(shown) do ns.SetScaleIf(frame, want, 0.001) end
        scaledWindows = follow and true or false
    end
    WrapOpenBags(shown)
end

-- Edit mode just closed: the client re-laid every system (caps included); answered before this frame draws.
local function EditEdge(editing)
    if editing == edit.live then return end
    edit.live = editing
    if not editing and B.active then
        B.dragging, capInHand, handHeld = false, nil, false
        B.hot.Make()
        if InCombatLockdown() then pcall(CapsInFight) else ns.SafeCall(B.Apply) end
    end
end

-- A cap let go near its place goes back on the band by our record alone (a layout write marks every piece as ours).
local function DropCap()
    local key, bar = capInHand, ns.GetMainBar()
    local cap = CapFrame(bar, key)
    ns.db.capMoved = ns.db.capMoved or {}
    local slotX = ArtWidth() / 2 + CapSlot(key, ArtWidth()) - CAP_SIZE / 2
    if cap and NearBandSlot(cap, slotX, 0, "BOTTOMLEFT") then
        ns.db[CapHeldKey(key)] = true
        ns.db.capMoved[key] = nil
    else
        ns.db[CapHeldKey(key)] = false
        ns.db.capMoved[key] = true
    end
    ns.MirrorSave()
end

-- A held button in edit mode is a drag: the client re-anchors on every mouse move and the snap answers ours, so nothing of
-- ours runs until release. Read every hot frame: the client re-lays its bottom stack on release, answered that frame.
local function ReadDrop(editing)
    local held = B.active and editing and IsMouseButtonDown and IsMouseButtonDown("LeftButton") and true or false
    if not B.active or held == B.dragging then return end
    B.dragging = held
    if held then return end
    if editing then
        ReadBarPlacement()
        SnapBarHome()
        B.bagsDropped = true
        if capInHand then DropCap() end
    end
    capInHand = nil
    handHeld = false
    if not InCombatLockdown() then ns.SafeCall(B.Apply) end
    ns.QueueApply()
end

-- Micro moves light Save/Revert All by the plain widget Enable (no client field); the client may dim them, so relit while noted.
local function RelightSaveRevert(editing)
    local mgr = EditModeManagerFrame
    if editing and ns.microDirty and mgr then
        for _, key in ipairs(SAVE_REVERT) do
            local button = mgr[key]
            if button then
                if not button:IsEnabled() then
                    local raw = getmetatable(button)
                    raw = raw and raw.__index
                    if type(raw) == "table" and raw.Enable then raw.Enable(button) else button:Enable() end
                end
                if ns.Once(button, "microHooked") then
                    button:HookScript("OnClick", function()
                        if not ns.microDirty then return end
                        local before = ns.microBefore
                        ns.microDirty, ns.microBefore = false, nil
                        if key == "RevertAllChangesButton" and before and ns.db then
                            ns.db.microPos, ns.db.microScale, ns.db.bagsFirst = before.pos, before.scale, before.bagsFirst
                            ns.MirrorSave()
                            ns.QueueApply()
                        end
                    end)
                end
            end
        end
    elseif not editing and ns.microDirty then
        -- Edit mode left without either: the move is kept.
        ns.microDirty, ns.microBefore = false, nil
    end
end

-- Turning or folding a bar in edit mode fires nothing: its settings are read while edit mode is up, re-laid on a change.
local function ScanEditMarks(editing)
    if not editing then
        edit.marked = false
        return
    end
    local changed = false
    for i = 1, #EDIT_MARK do
        local bar = _G[EDIT_MARK[i]]
        local mark = marks[i]
        local has, vertical, rows, icons = bar ~= nil, nil, nil, nil
        if bar then vertical, rows, icons = BarVertical(bar), BarRows(bar), BarSetting(bar, "NumIcons") end
        if edit.marked and (has ~= mark.has or vertical ~= mark.vertical or rows ~= mark.rows or icons ~= mark.icons) then
            changed = true
        end
        mark.has, mark.vertical, mark.rows, mark.icons = has, vertical, rows, icons
    end
    if changed then ns.QueueApply() end
    edit.marked = true
end

-- The bags are dragged by the client's own box; the same preview runs while it is held.
local function PreviewBags()
    local bagsPiece = BagsBar
    if bagsPiece and bagsPiece.isDragging then B.bagsInHand = true end
    if bagsPiece and bagsPiece.isDragging and not OneBar() then
        B.PreviewDrop("bags", bagsPiece)
    elseif B.dragPreview.bags ~= nil then
        B.dragPreview.bags, B.dragPreview.bagsFirst = nil, nil
    end
end

-- Posts remade on every client layout (checked here, never hooked there), then the micro handle, our dialogs, the gryphons.
local function DividersAndDialogs(art, editing)
    local holders = StatusPair()
    for i = 1, #holders do FadeNewDividers(holders[i]) end
    local handle = art and art.microHome and art.microHome.handle
    if handle and handle:IsShown() ~= editing then
        -- The group's level moves with the buttons' and takes the handle along.
        if editing then handle:SetFrameLevel(1010) end
        handle:SetShown(editing)
    end
    if not editing and art and art.microDialog and art.microDialog:IsShown() then art.microDialog:Hide() end
    -- Out of edit mode a repeat call writes nothing: once on the way out, then only while editing.
    if editing or edit.followed then
        edit.followed = editing
        if art then FollowBagsDialog(editing) end
        B.FollowStatusDialog(editing)
    end
    if not B.dragging and not InCombatLockdown() then KeepBarShape() end
end

-- Edit watch: bag windows and holders every frame, the rest on the hot or 0.25 s beat, edit mode settings on a slower one.
local function EditTick(elapsed, isHot, editing)
    EditEdge(editing)
    if B.active then
        AnchorOpenBags()
        -- Holders moved or resized by the client (fade ends, managed frame changes): answered on the frame.
        if not B.applying and B.hot.StatusTrip() then StatusBack() end
    end
    -- Time since the last beat, skipped frames included, for the slower beat below.
    elapsed = Due(edit, elapsed, B.hot.BEAT, isHot, "cool")
    if not elapsed then return end
    -- Full check on the beat: shown state, bar count and sizes.
    if B.active and not B.applying and StatusMoved() then StatusBack() end
    ReadDrop(editing)
    if not Due(edit, elapsed, editing and WATCH_EDIT or WATCH_IDLE, nil, "since") then return end
    if not B.active then return end
    local art = B.art
    -- Hide Bar Art toggled: the band goes or comes back.
    local mainBar = ns.GetMainBar()
    if editing and mainBar and (mainBar.hideBarArt == true) ~= (art.artHidden == true) then ns.QueueApply() end
    -- Hide Bar Scrolling toggled: the band is re-cut.
    if editing and (BarSetting(ns.GetMainBar(), "HideBarScrolling") == 1) ~= (B.shape.noPages and true or false) then
        ns.QueueApply()
    end
    if editing then HideSelections() end
    RelightSaveRevert(editing)
    ScanEditMarks(editing)
    PreviewBags()
    DividersAndDialogs(art, editing)
end

function B.StartWatch()
    if B.lane then return end
    local placer = CreateFrame("Frame")
    B.lane = placer

    -- Every frame while hot, a piece in hand or after a held-off pass; else on the beat, the row tripwire in between.
    local place = { since = 0 }
    local function PlaceTick(elapsed, isHot)
        local hot = B.hot
        if not Due(place, elapsed, hot.BEAT, handHeld or isHot) then
            if B.active and hot.Trip() and not hot.RowsFix() then PlaceNow(true) end
            return
        end
        PlaceNow(true)
    end

    -- Listeners hear an event in registration order and ours must be last: the first fight of a session showed the bars
    -- put back, then re-laid by a client listener registered after us. So out of combat we re-register every second.
    function B.LastWord()
        if InCombatLockdown() then return end
        placer:UnregisterEvent("PLAYER_REGEN_DISABLED")
        placer:RegisterEvent("PLAYER_REGEN_DISABLED")
    end

    -- The band's watches as one lane (container, status bars, cast bar, edit, place, last word), each gated here, then under
    -- its own error guard so one failure stops no other. Hot read once, re-read if an event moves it mid-pass.
    local BarsTick, CastTick, WakeBars = B.BarsTick, B.CastTick, B.WakeBars
    local barsWatch, castWatch, layoutMemo = B.barsWatch, B.castWatch, B.layoutMemo
    local castBar
    local rest = { since = 0 }
    placer:SetScript("OnUpdate", function(_, elapsed)
        local hot = B.hot
        local live = EditModeLive()
        local untilAt = hot.untilAt
        local isHot = GetTime() < untilAt or live
        B.inLane = true
        -- Every frame, not on the beat: the stack on a re-stood container moves until it is put back.
        SafeCall(KeepContainer)
        -- The status watch never sleeps through edit mode or the session's end (its stack plan changes there).
        if live or ns.sessionEnding then WakeBars() end
        if not barsWatch.asleep and Due(barsWatch, elapsed, 0.05) then SafeCall(BarsTick) end
        if hot.untilAt ~= untilAt then untilAt = hot.untilAt isHot = GetTime() < untilAt or live end
        -- CastTick's own early branch, taken here.
        if not castBar then castBar = PlayerCastingBarFrame end
        if B.active and B.art and castBar and castBar:IsShown() then
            SafeCall(CastTick, elapsed, isHot)
        else
            castWatch.want = nil
        end
        if hot.untilAt ~= untilAt then untilAt = hot.untilAt isHot = GetTime() < untilAt or live end
        SafeCall(EditTick, elapsed, isHot, live)
        if hot.untilAt ~= untilAt then untilAt = hot.untilAt isHot = GetTime() < untilAt or live end
        SafeCall(PlaceTick, elapsed, isHot)
        B.inLane = false
        if layoutMemo.known then ForgetLayout() end
        -- At rest a second: off the frame loop till something wakes it (B.WakeLane, BandSentinel.lua).
        if live or isHot or handHeld or B.dragging or not barsWatch.asleep or (castBar and castBar:IsShown())
            or edit.followed or B.BagsUp() then
            rest.since = 0
        elseif Due(rest, elapsed, 1) and B.PrepareDoze() then
            placer.dozing = true
            placer:Hide()
        end
    end)
    -- The client moves unpinned bars on a new target; heard after its handlers, our answer lands before anything is drawn
    -- (our own handler, not a hook in the client's).
    placer:RegisterEvent("PLAYER_TARGET_CHANGED")
    placer:RegisterEvent("PLAYER_FOCUS_CHANGED")
    -- Same for fight start (not yet locked while this event dispatches), fight end, and pet/stance bars: the client's
    -- re-laid stack is put back before a frame is drawn, nothing written.
    for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PET_BAR_UPDATE", "UPDATE_SHAPESHIFT_FORMS",
        "UPDATE_BONUS_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR", "UPDATE_OVERRIDE_ACTIONBAR" }) do
        pcall(placer.RegisterEvent, placer, event)
    end
    pcall(placer.RegisterUnitEvent, placer, "UNIT_PET", "player")
    -- The client's bag bar re-lays in its own CURSOR_CHANGED handler; ours runs after it, before the frame is drawn.
    -- Tripwire only: it fires often.
    pcall(placer.RegisterEvent, placer, "CURSOR_CHANGED")
    placer:SetScript("OnEvent", function(_, event)
        B.WakeLane()
        if event == "CURSOR_CHANGED" then
            -- Rows only; the full pass in edit mode, where a piece may be in hand.
            if B.active and B.hot.Trip() then
                if handHeld or EditModeLive() or not B.hot.RowsFix() then PlaceNow() end
            end
            return
        end
        if event == "PLAYER_REGEN_DISABLED" then
            -- Dev log only (built while a sink is attached); the first Moved() also builds the watch list and the world map
            -- button, so it always runs.
            local ok, moved = pcall(Moved)
            ns.fightBeganAt = GetTime()
            if ns.debugSink then
                ns.Persist("bars: fight beginning; moved by the client " .. tostring(ok and moved) .. ", locked " .. tostring(InCombatLockdown()))
            end
            PlaceNow()
            if ns.debugSink then
                local okAfter, movedAfter = pcall(Moved)
                ns.Persist("bars: after our pass, still moved " .. tostring(okAfter and movedAfter) .. ", locked " .. tostring(InCombatLockdown()) .. ", passes " .. tostring(ns.bandPasses))
            end
            pcall(B.HoldBandBoxes, true)
            return
        end
        if event == "PLAYER_REGEN_ENABLED" then pcall(B.HoldBandBoxes, false) end
        PlaceNow()
    end)
end

-- For the move helpers (BandSentinel.lua).
B.WatchList, B.RowFrames = WatchList, RowFrames
