local _, ns = ...
local B = ns.band

-- The client's bottom stack over the band: its container is put back on our spot (KeepBottomContainer), and the loot
-- roll frames hang on a stand of ours at the spot the client gives them, so the client's container moves never reach them.

local ROLL_FRAMES = { "GroupLootFrame1", "GroupLootFrame2", "GroupLootFrame3", "GroupLootFrame4" }
-- Client passes that re-stand the container from these events' handlers; ours hears them after, before the frame is drawn.
local RESTAND_EVENTS = { "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_USABLE", "UPDATE_POSSESS_BAR", "ACTIONBAR_PAGE_CHANGED",
    "UPDATE_EXTRA_ACTIONBAR", "PET_BAR_UPDATE_USABLE", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
    "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_FARSIGHT_FOCUS_CHANGED", "UPDATE_INVENTORY_ALERTS", "UNIT_TARGETABLE_CHANGED",
    "INSTANCE_ENCOUNTER_ENGAGE_UNIT" }

-- Roll frames last hung on the stand (weak; nothing is written on the frames).
local onStand = setmetatable({}, { __mode = "k" })
local stand
local standAt = {}

local restand = CreateFrame("Frame")
ns.RegisterEvents(restand, RESTAND_EVENTS)
restand:SetScript("OnEvent", function()
    if B.active and B.KeepContainer then B.KeepContainer() end
end)

local function Units(frame)
    return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

-- Moves a roll frame between the client's container and our stand with the client's own point and offset.
local function Rehang(frame, from, to)
    local point, rel, relPoint, x, y = frame:GetPoint(1)
    onStand[frame] = (stand ~= nil and rel == stand) or nil
    if rel ~= from or frame:GetNumPoints() ~= 1 then return end
    if InCombatLockdown() and frame:IsProtected() then return end
    frame:ClearAllPoints()
    frame:SetPoint(point, to, relPoint, x, y)
    onStand[frame] = (to == stand) or nil
end

-- Band off or bar 1 placed: the roll frames go back on the client's container.
function B.RollsBack()
    local glc = _G.GroupLootContainer
    if not (glc and stand) then return end
    for frame in pairs(onStand) do Rehang(frame, stand, glc) end
end

local function PlaceStand(left, bottom, width, height)
    if not stand then
        stand = CreateFrame("Frame", nil, UIParent)
        B.rollStand = stand
    end
    local at = standAt
    if at.w == nil or math.abs(at.w - width) > 0.01 or math.abs(at.h - height) > 0.01 then
        at.w, at.h = width, height
        stand:SetSize(width, height)
    end
    if at.x == nil or math.abs(at.x - left) > 0.01 or math.abs(at.y - bottom) > 0.01 then
        at.x, at.y = left, bottom
        stand:ClearAllPoints()
        stand:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
    end
    return stand
end

-- Every lane frame while a roll is up: the stand where the roll container sits with the client's container on our spot.
function B.RollTick()
    local glc, host, want = _G.GroupLootContainer, BottomManagedFrameContainer, B.bottomWant
    if not (glc and host) then return end
    if not (B.active and want) then
        if next(onStand) then B.RollsBack() end
        return
    end
    if not glc:IsShown() then return end
    local left, bottom, hostBottom = glc:GetLeft(), glc:GetBottom(), host:GetBottom()
    if not (left and bottom and hostBottom) or ns.AnySecret(left, bottom, hostBottom) then return end
    local k = Units(glc)
    -- Protected in a fight (extra action button inside): the container stays where the client put it, and the stand with it.
    local lift = 0
    if not (InCombatLockdown() and host:IsProtected()) then lift = want - hostBottom * Units(host) end
    local frame = PlaceStand(left * k, bottom * k + lift, glc:GetWidth() * k, glc:GetHeight() * k)
    for i = 1, #ROLL_FRAMES do
        local roll = _G[ROLL_FRAMES[i]]
        if roll and roll:IsShown() then Rehang(roll, glc, frame) end
    end
end
