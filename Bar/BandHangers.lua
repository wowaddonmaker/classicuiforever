local _, ns = ...
local B = ns.band

-- Pieces the player snapped to a band bar the layout holds at the game's spot (the XP bar on bar 2). The game re-stacks
-- such bars on its own passes, fights included, and the band puts them back, so a piece hanging on one rode every move.
-- Outside edit mode it hangs on the screen where its snap puts it on the band; in edit mode on the snap again, as the game's.

local OWNED_SYSTEMS = B.OWNED_SYSTEMS
local EditModeLive = ns.EditMode.Live
local NONE = {}
local unhooked = setmetatable({}, { __mode = "k" })   -- piece -> true while it hangs on the screen
local bars = {}                                       -- band frame -> true while the band places it, refilled per pass

local function BandPlacedBars()
    wipe(bars)
    for _, name in ipairs(OWNED_SYSTEMS) do
        local frame = _G[name]
        if frame and not B.SystemMoved(frame) then bars[frame] = true end
    end
end

-- The layout's snap for a piece whose target is such a bar; one-point anchors only (two set a size too).
local function SnapOnBand(piece)
    if bars[piece] or not piece.systemInfo or ns.InDefaultPosition(piece) then return nil end
    local info = piece.systemInfo.anchorInfo
    if not info or piece.systemInfo.anchorInfo2 or type(info.relativeTo) ~= "string" then return nil end
    local target = _G[info.relativeTo]
    if target and bars[target] then return info, target end
end

-- As the client applies it: offsets saved at scale 1.
local function Hook(piece, info, target)
    local scale = piece:GetScale()
    ns.SetPointOnce(piece, info.point, target, info.relativePoint, info.offsetX / scale, info.offsetY / scale)
end

-- End of a band pass, bars on the band: each such piece onto the screen at the spot its snap gives there.
function B.UnhookPieces()
    if InCombatLockdown() or EditModeLive() then return end
    local mgr = EditModeManagerFrame
    BandPlacedBars()
    for _, piece in ipairs(mgr and mgr.registeredSystemFrames or NONE) do
        local info, target = SnapOnBand(piece)
        if info then
            Hook(piece, info, target)
            local left, bottom = ns.Safe(piece:GetLeft()), ns.Safe(piece:GetBottom())
            if left and bottom then
                ns.SetPointOnce(piece, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
                unhooked[piece] = true
            end
        else
            unhooked[piece] = nil
        end
    end
end

-- Edit mode open and the band off: back on their snaps, so drags and snaps work as the game's.
function B.RehookPieces()
    if InCombatLockdown() then return end
    for piece in pairs(unhooked) do
        local info = piece.systemInfo and piece.systemInfo.anchorInfo
        local target = info and type(info.relativeTo) == "string" and _G[info.relativeTo]
        if target then Hook(piece, info, target) end
        unhooked[piece] = nil
    end
end
