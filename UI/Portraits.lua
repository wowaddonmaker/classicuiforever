local _, ns = ...

-- Round portraits, kept fitted as the client swaps them.

local WEAK = { __mode = "k" }

-- Crop the icon's own square border (it showed inside the ring); ours also get a round mask.
local ICON_CROP = 0.1
function ns.RoundIcon(tex, inset)
    if not tex then return end
    tex:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
    local owner = tex:GetParent()
    if tex.fcuiMask or not (owner and owner.CreateMaskTexture and tex.AddMaskTexture) then return end
    local mask = owner:CreateMaskTexture()
    mask:SetTexture(ns.TexPath("portraitMask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetPoint("TOPLEFT", tex, "TOPLEFT", inset or 0, -(inset or 0))
    mask:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", -(inset or 0), inset or 0)
    tex:AddMaskTexture(mask)
    tex.fcuiMask = mask
end

-- A portrait switches between face, ring art and icon with the tabs; only icons are cropped.
-- Client-set sheet coords (class icons) are handled apart.
local function IsIconTexture(tex)
    local path = tex.GetTextureFilePath and tex:GetTextureFilePath()
    -- A texture set by file id (the spec icon) reports "FileData ID n" as its path.
    if type(path) == "string" and not path:find("^FileData ID") then
        return path:lower():find("icons", 1, true) ~= nil
    end
    local file = tex:GetTexture()
    if type(file) == "number" then return true end
    if type(file) == "string" then
        local lower = file:lower()
        if lower:find("^rt") or lower:find("^portrait") then return false end
        return lower:find("icons", 1, true) ~= nil
    end
    return false
end
local function Near(a, b) return math.abs((a or 0) - b) < 0.002 end
-- Corners (ulx, uly, lrx, lry) at l, t, r, b.
local function CornersAt(ulx, uly, lrx, lry, l, t, r, b)
    return Near(ulx, l) and Near(uly, t) and Near(lrx, r) and Near(lry, b)
end
local CROP_R = 1 - ICON_CROP
-- True when it wrote.
local function FitPortrait(tex)
    local ulx, uly, _, _, _, _, lrx, lry = tex:GetTexCoord()
    local full = CornersAt(ulx, uly, lrx, lry, 0, 0, 1, 1)
    local ours = CornersAt(ulx, uly, lrx, lry, ICON_CROP, ICON_CROP, CROP_R, CROP_R)
    if not full and not ours then
        -- Client sheet piece (class circles; their gold rim showed at the ring top): zoom once per coord set.
        local zoom = tex.fcuiZoom
        if zoom and CornersAt(ulx, uly, lrx, lry, zoom[1], zoom[2], zoom[3], zoom[4]) then return end
        if lrx <= ulx or lry <= uly then return end
        -- The client's mask is off centre (top 0, sides 2, bottom 4): cut more at the top.
        local dx, span = (lrx - ulx) * ICON_CROP, lry - uly
        zoom = { ulx + dx, uly + span * 0.16, lrx - dx, lry - span * 0.06 }
        tex.fcuiZoom = zoom
        tex.fcuiZoomFrom = { ulx, uly, lrx, lry }
        tex:SetTexCoord(zoom[1], zoom[3], zoom[2], zoom[4])
        return true
    end
    local icon = IsIconTexture(tex)
    if icon and full then
        tex:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
        return true
    elseif ours and not icon then
        tex:SetTexCoord(0, 1, 0, 1)
        return true
    end
end

-- FitPortrait reads only file, path, coords and fcuiZoom: skip an idle portrait until one changes.
-- Secret values are never compared, so a secret portrait is fitted every beat.
local fitSeen = setmetatable({}, WEAK)
local function FitWatched(tex)
    local file = tex:GetTexture()
    local path = tex.GetTextureFilePath and tex:GetTextureFilePath()
    local c1, c2, c3, c4, c5, c6, c7, c8 = tex:GetTexCoord()
    local readable = not ns.AnySecret(file, path, c1, c2, c3, c4, c5, c6, c7, c8)
    local seen = fitSeen[tex]
    if seen then
        if readable and seen.idle and seen[1] == file and seen[2] == path
            and seen[3] == c1 and seen[4] == c2 and seen[5] == c3 and seen[6] == c4
            and seen[7] == c5 and seen[8] == c6 and seen[9] == c7 and seen[10] == c8 then
            return
        end
        seen.idle = false
    end
    if FitPortrait(tex) or not readable then return end
    if not seen then
        seen = {}
        fitSeen[tex] = seen
    end
    seen[1], seen[2], seen[3], seen[4], seen[5] = file, path, c1, c2, c3
    seen[6], seen[7], seen[8], seen[9], seen[10] = c4, c5, c6, c7, c8
    seen.idle = true
end

-- Each window's portraits are fitted by a pure watcher under it, so a shut window costs nothing.
-- The spellbook's window, protected ones and portraits without a window share one driver job.
local watched = setmetatable({}, WEAK)     -- portrait -> the set it is fitted from; true until settled
local setJob = setmetatable({}, WEAK)      -- set -> the job walking it
local windowSet = setmetatable({}, WEAK)   -- window -> its set
local loose = setmetatable({}, WEAK)
local pending = {}

local function FitSet(set)
    for portrait in pairs(set) do
        if portrait:IsVisible() then pcall(FitWatched, portrait) end
    end
end

-- Its top frame under UIParent, or the root of a parentless window.
local function WindowOf(tex)
    local frame = tex:GetParent()
    if not frame or frame == UIParent then return nil end
    local parent = frame:GetParent()
    while parent and parent ~= UIParent do
        frame, parent = parent, parent:GetParent()
    end
    return frame
end

local function Hostable(window)
    if not window or window == _G.PlayerSpellsFrame then return false end
    local ok, protected = pcall(window.IsProtected, window)
    return ok and not protected
end

local function SetFor(tex)
    local window = WindowOf(tex)
    if not Hostable(window) then
        if not setJob[loose] then
            setJob[loose] = ns.Sched.Job({ name = "portraits", every = 0.05, fn = function() FitSet(loose) end })
        end
        return loose
    end
    local set = windowSet[window]
    if not set then
        set = setmetatable({}, WEAK)
        windowSet[window] = set
        setJob[set] = ns.Sched.Attach(window, { name = "portraits", every = 0.05, fn = function() FitSet(set) end })
    end
    return set
end

-- Watchers are made the next frame: the sheet's layout calls in from inside the client's pass.
local function SettlePending()
    for i = 1, #pending do
        local tex = pending[i]
        pending[i] = nil
        if watched[tex] == true then
            local set = SetFor(tex)
            watched[tex] = set
            set[tex] = true
            setJob[set]:Wake()
        end
    end
end

function ns.WatchPortrait(tex)
    if not tex or not tex.GetTexCoord then return end
    if not watched[tex] then
        watched[tex] = true
        pending[#pending + 1] = tex
        ns.Sched.NextFrame("portraits", SettlePending)
    end
    -- Fit now, past the idle cache.
    local seen = fitSeen[tex]
    if seen then seen.idle = false end
    pcall(FitPortrait, tex)
end

-- Sheet turned off: back to the client's coords.
function ns.UnwatchPortrait(tex)
    local set = tex and watched[tex]
    if not set then return end
    watched[tex] = nil
    if set ~= true then
        set[tex] = nil
        if next(set) == nil then setJob[set]:Sleep() end
    end
    fitSeen[tex] = nil   -- coords are rewritten below
    pcall(function()
        local ulx, uly, _, _, _, _, lrx, lry = tex:GetTexCoord()
        local zoom, from = tex.fcuiZoom, tex.fcuiZoomFrom
        if zoom and from and CornersAt(ulx, uly, lrx, lry, zoom[1], zoom[2], zoom[3], zoom[4]) then
            tex:SetTexCoord(from[1], from[3], from[2], from[4])
        elseif CornersAt(ulx, uly, lrx, lry, ICON_CROP, ICON_CROP, CROP_R, CROP_R) then
            tex:SetTexCoord(0, 1, 0, 1)
        end
    end)
    tex.fcuiZoom, tex.fcuiZoomFrom = nil, nil
end
