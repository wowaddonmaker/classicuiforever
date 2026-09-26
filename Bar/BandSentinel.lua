local _, ns = ...
local B = ns.band

-- The band lane dozes at rest (BandWatch.lua). What wakes it, beside its own and the hot and status events.

-- Back on the frame loop from a doze.
function B.WakeLane()
    local lane = B.lane
    if not (lane and lane.dozing and B.active) then return end
    lane.dozing = false
    lane:Show()
end

-- One lane pass now, at most once a frame: a watched frame moved while it dozed.
local laneNowAt
function B.LaneNow()
    local lane = B.lane
    local now = GetTime()
    if not lane or laneNowAt == now or B.inLane then return end
    laneNowAt = now
    B.WakeLane()
    local tick = lane:GetScript("OnUpdate")
    if tick then tick(lane, 0) end
end

-- A bag window up keeps the lane awake to hang it.
function B.BagsUp()
    local combined = ContainerFrameCombinedBags
    if combined and combined:IsShown() then return true end
    local shown = ContainerFrameSettingsManager and ContainerFrameSettingsManager.bagsShown
    return type(shown) == "table" and shown[1] ~= nil
end

-- Every frame the lane checks.
local function WatchFrames()
    local list = {}
    for _, frame in ipairs(B.WatchList()) do list[#list + 1] = frame end
    for _, frame in ipairs(B.RowFrames()) do list[#list + 1] = frame end
    for _, frame in ipairs(B.StatusPair()) do list[#list + 1] = frame end
    return list
end

-- A watched frame moving is heard in that layout pass, before a draw (ns.Sched.OnMove).
local watched = setmetatable({}, { __mode = "k" })

-- Hot, so the lane lays a moved bar the next frame, not on its beat.
local function OnMoved()
    local lane = B.lane
    if not (B.active and lane and lane.dozing) then return end
    -- Short: every further move comes back here.
    B.hot.MakeShort()
    B.LaneNow()
end

-- Shown or hidden in place (a micro or bag button, a bar toggled): hot, so the lane lays it before the next draw.
-- Runs inside the client's show pass: it only marks hot and shows our lane.
local function OnShownOrHidden()
    local lane = B.lane
    if B.active and lane and lane.dozing then B.hot.MakeShort() end
end

local function Watch(frame)
    if type(frame) ~= "table" or not frame.GetPoint or watched[frame] then return end
    watched[frame] = true
    ns.Sched.OnMove(frame, OnMoved)
    -- Buttons only: a child under a client layout frame (bars, containers, the micro menu) taints its layout pass.
    if not frame.Layout then ns.Sched.OnVisible(frame, "band.shown", OnShownOrHidden) end
end

-- Edit mode (our child under its manager's Border, ignoreInLayout), a cast, open bag windows: awake while they show.
local function Awake()
    if B.active then B.WakeLane() end
end

local function KeepAwake(host, name)
    if host then ns.Sched.Attach(host, { name = name, every = 0, fn = Awake }) end
end

-- A bag window opening: the client shows it, then lays it at the screen corner (ContainerFrame_GenerateFrame), and a
-- woken lane first runs a frame later. Our pass goes in this frame's driver pass, after that corner lay, before a draw.
local function BagsNow()
    if B.active then B.LaneNow() end
end
local function BagShown(shown)
    if shown then ns.Sched.Soon("band.bagsNow", BagsNow) end
end
local function WakeBags(host)
    if not host then return end
    KeepAwake(host, "band.bagsWake")
    ns.Sched.OnVisible(host, "band.bagsShown", BagShown)
end

local wakersMade = false
local function MakeWakers()
    wakersMade = true
    KeepAwake(EditModeManagerFrame and EditModeManagerFrame.Border, "band.editWake")
    KeepAwake(PlayerCastingBarFrame, "band.castWake")
    WakeBags(ContainerFrameCombinedBags)
    for i = 1, _G.NUM_CONTAINER_FRAMES or 13 do WakeBags(_G["ContainerFrame" .. i]) end
end

-- Helpers and wakers in place before each doze (false: none yet, stay awake); frames made since get theirs.
function B.PrepareDoze()
    if not B.WatchList then return false end
    if not wakersMade then MakeWakers() end
    local frames = WatchFrames()
    for i = 1, #frames do Watch(frames[i]) end
    return #frames > 0
end

-- Our fight listener stays last: re-registered each second out of combat, the lane dozing or not.
ns.Sched.Job({ name = "band.lastWord", every = 1, fn = function()
    if B.active and B.LastWord then B.LastWord() end
end })
