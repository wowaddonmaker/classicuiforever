local _, ns = ...
local B = ns.band

-- Pins: the client's bottom/right bar pass (on target change, in fights too) sends "default" bars home but leaves
-- ones the layout holds a spot for, so band bars are written in at band spots; told from a player drag by shape and
-- per-layout record. Layout writes only as the session ends (ns.sessionEnding): mid-game one taints every piece.

local PIN_NAMES, HAND_BACK, CAP_KEYS = B.PIN_NAMES, B.HAND_BACK, B.CAP_KEYS
local CapMoved = B.CapMoved
local InDefaultPosition = ns.InDefaultPosition

-- Memoized per lane pass (B.inLane): nothing in a pass switches layouts; outside the lane every call asks.
local memo = { name = nil, known = false }
B.layoutMemo = memo
local function ActiveLayoutName()
    if memo.known then return memo.name end
    local info = ns.ActiveLayoutInfo()
    local name = info and info.layoutName or nil
    if B.inLane then memo.name, memo.known = name, true end
    return name
end

function B.ForgetLayout()
    memo.name, memo.known = nil, false
end

local function PinnedByUs(frame, info)
    local pins = ns.db and ns.db.barPins
    local layout = pins and pins[ActiveLayoutName() or ""]
    local name = frame.GetName and frame:GetName()
    local pin = layout and name and layout[name]
    if not info then return false end
    local relativeTo = info.relativeTo
    if type(relativeTo) == "table" then relativeTo = relativeTo.GetName and relativeTo:GetName() end
    -- By shape too (records made before a layout reset may be gone): no edit mode drop, snap or nudge holds BOTTOMLEFT to
    -- screen BOTTOM.
    if relativeTo == "UIParent" and info.point == "BOTTOMLEFT" and info.relativePoint == "BOTTOM" then return true end
    if not pin then return false end
    return info.point == pin.point and info.relativePoint == pin.relativePoint and relativeTo == "UIParent"
        and math.abs((info.offsetX or 0) - (pin.offsetX or 0)) < 0.5
        and math.abs((info.offsetY or 0) - (pin.offsetY or 0)) < 0.5
end

local function PresetAnchor(mgr, system, index)
    return mgr and mgr:GetDefaultSystemAnchorInfo(system, index)
end

-- Whether edit mode holds this frame at a player's spot: not its default (layouts can carry a stale flag,
-- so the spot is checked against the preset) and not our pin.
local function SystemMoved(frame)
    if not frame or type(frame.IsInDefaultPosition) ~= "function" then return false end
    if not (frame.IsInitialized and frame:IsInitialized()) then return false end
    local ok, isDefault = pcall(frame.IsInDefaultPosition, frame)
    if not ok or isDefault then return false end
    local info = frame.systemInfo and frame.systemInfo.anchorInfo
    if PinnedByUs(frame, info) then return false end
    local okDefault, preset = pcall(PresetAnchor, EditModePresetLayoutManager, frame.system, frame.systemIndex)
    if not okDefault or not info or not preset then return true end
    local same = info.point == preset.point and info.relativeTo == preset.relativeTo and info.relativePoint == preset.relativePoint
        and math.abs((info.offsetX or 0) - (preset.offsetX or 0)) < 0.5 and math.abs((info.offsetY or 0) - (preset.offsetY or 0)) < 0.5
    return not same
end
B.SystemMoved = SystemMoved
ns.SystemMoved = SystemMoved

-- Band bars the active layout still holds as the client's own, into list; withPins adds ours (re-pinned for the band's current length).
local function CollectBandBars(list, withPins)
    if not B.active or not B.art then return list end
    for _, name in ipairs(PIN_NAMES) do
        local frame = _G[name]
        if frame and frame.system and frame:IsShown() and type(frame.IsInDefaultPosition) == "function" then
            local isDefault = InDefaultPosition(frame)
            if withPins then
                local info = frame.systemInfo and frame.systemInfo.anchorInfo
                if isDefault ~= nil and (isDefault or PinnedByUs(frame, info)) then list[#list + 1] = frame end
            elseif isDefault then
                list[#list + 1] = frame
            end
        end
    end
    return list
end

function ns.BandBarsToUnpinned() return CollectBandBars({}, false) end

-- Same, for the band's in-fight scan, into one reused list.
local unpinned = {}
function B.UnpinnedBars()
    wipe(unpinned)
    return CollectBandBars(unpinned, false)
end

function ns.BandBarsToPin() return CollectBandBars({}, true) end

-- A frame's bottom-left relative to the screen's bottom-centre, in its own scale: how our pin holds it.
local function PinSpot(frame)
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    if not left or not bottom then return nil end
    local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if not ratio or ratio <= 0 then return nil end
    return left - UIParent:GetWidth() / 2 / ratio, bottom
end

-- Anchor a bar's band spot to the screen, not the band: the layout is read before the band exists and outlives it.
local function AnchorToScreen(frame)
    local point, relativeTo, relativePoint = frame:GetPoint(1)
    if relativeTo == UIParent and point == "BOTTOMLEFT" and relativePoint == "BOTTOM" then return true end
    local x, y = PinSpot(frame)
    if not x then return false end
    ns.SetPointOnce(frame, "BOTTOMLEFT", UIParent, "BOTTOM", x, y)
    return true
end

-- Reset to default when edit mode holds it elsewhere and allow (if given) agrees; returns whether it moved.
local function ResetIfMoved(frame, allow, arg)
    if not (frame and frame.system and type(frame.IsInDefaultPosition) == "function"
        and type(frame.ResetToDefaultPosition) == "function") then
        return false
    end
    local ok, isDefault = pcall(frame.IsInDefaultPosition, frame)
    if not ok or isDefault then return false end
    if allow and not allow(frame, arg) then return false end
    return pcall(frame.ResetToDefaultPosition, frame) and true or false
end

-- A cap the player dragged keeps its spot.
local function CapFree(_, key) return not (B.active and CapMoved(key)) end

-- On Forever the gryphons are edit mode pieces snapped to the main bar; the client turns the snap into a fixed spot
-- whenever the bar moves or hides, and a save keeps it (unseen under the band). Reset to default (the snap) before any save.
local function ResetEndCaps()
    local bar = ns.GetMainBar()
    local caps = bar and bar.EndCaps
    if not caps then return false end
    local changed = false
    for _, key in ipairs(CAP_KEYS) do
        if ResetIfMoved(caps[key], CapFree, key) then changed = true end
    end
    return changed
end

-- A tracking bar holder on the band is drawn at band length, so its Width is written back to 100%.
local function WidthsToBand(mgr)
    local size = Enum and Enum.EditModeStatusTrackingBarSetting and Enum.EditModeStatusTrackingBarSetting.Size
    if size == nil or not mgr.OnSystemSettingChange then return false end
    local changed = false
    for _, holder in ipairs(B.StatusPair()) do
        if holder and holder.system and holder.GetSettingValue and not SystemMoved(holder) then
            local ok, now = pcall(holder.GetSettingValue, holder, size)
            -- 0 is a holder without the setting.
            if ok and type(now) == "number" and now > 0 and now ~= 100
                and pcall(mgr.OnSystemSettingChange, mgr, holder, size, 100) then
                changed = true
            end
        end
    end
    return changed
end

-- Write band bars into the active layout at band spots, on any layout (the client re-lays a "default" bar mid-fight
-- on any layout); player-placed bars are left alone; presets can't be written. Called from ns.ReloadForLayout
-- (the reload press), never at logout: edit mode is shut then and keeps nothing.
function ns.PinBandBars()
    if not ns.sessionEnding then return false end
    if not B.active or not B.art or InCombatLockdown() then return false end
    if not (ns.LayoutWritable and ns.LayoutWritable()) then return false end
    local mgr = EditModeManagerFrame
    if not mgr or not mgr.UpdateSystemAnchorInfo or not mgr.SaveLayouts then return false end
    local layoutName = ActiveLayoutName()
    if not layoutName then return false end
    local changed = false
    B.applying = true
    -- Unstacked (sessionEnding) first, or the second holder would be pinned on the XP bar's home.
    if B.LayoutStatusBars then pcall(B.LayoutStatusBars) end
    for _, frame in ipairs(ns.BandBarsToPin()) do
        if AnchorToScreen(frame) then
            local ok, did = pcall(mgr.UpdateSystemAnchorInfo, mgr, frame)
            -- Read back from the layout: what the bar gets after the reload.
            local held = mgr.GetActiveLayoutSystemInfo and mgr:GetActiveLayoutSystemInfo(frame.system, frame.systemIndex)
            local info = (held and held.anchorInfo) or (frame.systemInfo and frame.systemInfo.anchorInfo)
            if ok and did and info then
                ns.DbTable("barPins")
                ns.db.barPins[layoutName] = ns.db.barPins[layoutName] or {}
                ns.db.barPins[layoutName][frame:GetName()] = {
                    point = info.point, relativePoint = info.relativePoint,
                    offsetX = info.offsetX, offsetY = info.offsetY,
                }
                changed = true
            end
        end
    end
    if WidthsToBand(mgr) then changed = true end
    B.applying = false
    if ResetEndCaps() then changed = true end
    if changed then pcall(mgr.SaveLayouts, mgr) end
    return changed
end

-- Band spot per bar as a layout anchor, touching no frame or layout: for a layout that is not live.
function ns.BandPinAnchors()
    local out = {}
    for _, frame in ipairs(ns.BandBarsToPin()) do
        local x, y = PinSpot(frame)
        local scale = frame:GetScale()
        if x and scale and scale > 0 then
            out[#out + 1] = {
                name = frame:GetName(), system = frame.system, systemIndex = frame.systemIndex,
                anchorInfo = {
                    point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOM",
                    offsetX = x * scale, offsetY = y * scale,
                },
            }
        end
    end
    return out
end

local function OursOrPinned(frame, ours)
    return ours or PinnedByUs(frame, frame.systemInfo and frame.systemInfo.anchorInfo)
end

-- Turning the band off hands the bar region back whole: on the addon's layout every piece it placed goes to default
-- (spots built around the stone bar); on a player's layout only our pins. Once per turn-off, so later moves are the player's.
function ns.UnpinBandBars()
    if not ns.sessionEnding then return false end
    if InCombatLockdown() then return false end
    if not (ns.LayoutWritable and ns.LayoutWritable()) then return false end
    local mgr = EditModeManagerFrame
    if not mgr or not mgr.SaveLayouts then return false end
    local layoutName = ActiveLayoutName()
    local ours = ns.ClassicLayoutActive and ns.ClassicLayoutActive()
    local changed = false
    for _, name in ipairs(HAND_BACK) do
        if ResetIfMoved(_G[name], OursOrPinned, ours) then changed = true end
    end
    if ResetEndCaps() then changed = true end
    if layoutName and ns.db.barPins then ns.db.barPins[layoutName] = nil end
    ns.db.barDragged = false
    ns.db.bandHandedBack = true
    if changed then
        -- Bars held as default again are the client's to stack.
        if mgr.UpdateActionBarPositions then pcall(mgr.UpdateActionBarPositions, mgr) end
        pcall(mgr.SaveLayouts, mgr)
    end
    return changed
end

-- Settings lost while the layout kept its pins make every pinned bar read as player-placed, so the band leaves them;
-- on the addon's layout this takes them back: default, laid by the band, pinned afresh.
function ns.AdoptBandBars()
    if not ns.sessionEnding then return false end
    if InCombatLockdown() or not B.active then return false end
    if not (ns.ClassicLayoutActive and ns.ClassicLayoutActive()) then return false end
    local count = 0
    for _, name in ipairs(PIN_NAMES) do
        if ResetIfMoved(_G[name]) then count = count + 1 end
    end
    ns.db.barDragged = false
    -- Laid at once; ReloadForLayout pins next.
    ns.ApplyAll()
    return count
end
