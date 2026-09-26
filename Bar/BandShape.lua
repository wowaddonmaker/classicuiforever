local _, ns = ...
local B = ns.band

-- On the band, left to right: bar 1's half (512), the micro region (as wide as its row, up to the old art's room), the bag part.
-- Edit mode can take micro or bags off; the band ends at what remains, right gryphon on the last piece.
-- Micro moved: bags close up against bar 1's page arrows; both moved: bar 1 alone.

local ART_W, PAGE_ROOM, BAG_PART = B.ART_W, B.PAGE_ROOM, B.BAG_PART
local MICRO_LEAD, MICRO_REGION_MAX, MICRO_END_GAP = B.MICRO_LEAD, B.MICRO_REGION_MAX, B.MICRO_END_GAP
local POST_U, POST_W = B.POST_U, B.POST_W
local ROW_X, ROW_Y = B.ROW_X, B.ROW_Y
local MICRO_X = 555
-- Bar 1 alone: the page room through its number slot's post (u 36-37 of the third sheet); the right gryphon tucked in
-- over that post, its dark underside no gap after the slot.
local PAGE_ALONE, CAP_TUCK = 38, 6
-- A micro region standing second has no page arrows: only this margin.
local MICRO_SECOND_LEAD = 8
-- Dropped this close (screen px at UI scale) to a band spot: snaps back there.
local SNAP_PX = 48

-- One-bar mode: the band ends after the twelve main slots, right gryphon beside them; micro menu and bags stay off.
local function OneBar() return ns.db and ns.db.oneBar == true end
B.OneBar = OneBar

-- The micro menu moves by our handle, not the client's edit mode piece (re-laid constantly while edit mode is open);
-- its spot and size live in saved settings.
-- A broken saved place (a drag that left no anchor, before that was caught) counts as none and is dropped.
local function MicroOut()
    if not ns.db then return false end
    if ns.db.microPos ~= nil and not ns.ValidPlace(ns.db.microPos) then ns.db.microPos = nil end
    return ns.db.microPos ~= nil
end
B.MicroOut = MicroOut

-- Micro menu moves are ours, so they never light edit mode's Save: the first change per edit session snapshots the
-- state and lights Save/Revert All (the edit watch); Save settles it, Revert All restores the snapshot.
function ns.MicroTouched()
    if ns.microDirty or not ns.db then return end
    local pos = ns.db.microPos
    ns.microBefore = {
        pos = type(pos) == "table" and { point = pos.point, relPoint = pos.relPoint, x = pos.x, y = pos.y } or nil,
        scale = ns.db.microScale,
        bagsFirst = ns.db.bagsFirst,
    }
    ns.microDirty = true
end

local function MicroUserScale()
    local value = tonumber(ns.db and ns.db.microScale) or 1
    return math.max(0.5, math.min(2, value))
end
B.MicroUserScale = MicroUserScale

local shape = { micro = true, bags = true, region = MICRO_REGION_MAX }
B.shape = shape

-- While a group is dragged the band previews the drop: drawn with it when held near its place, without it when away.
B.dragPreview = {}

local function OnBandMicro() return shape.micro and not OneBar() end
local function OnBandBags() return shape.bags and not OneBar() end
B.OnBandMicro, B.OnBandBags = OnBandMicro, OnBandBags

-- The latency and key ring section at x (spans: B.TailSpan).
local function Tail(plan, x, afterBags, beforeBags)
    local u0, u1 = B.TailSpan(afterBags, beforeBags)
    if not u0 then return x end
    plan.tailStart, plan.tailU0, plan.tailU1 = x, u0, u1
    return x + u1 - u0
end

-- The bag part at x; trimmed of its leading stone when the section stands against it.
local function Bags(plan, x, trimmed)
    local trim = trimmed and B.BAG_TRIM or 0
    plan.bagsStart, plan.bagTrim = x, trim
    x = x + B.BagPart() - trim
    plan.bagsEnd = x
    return x
end

-- Past bar 1 in snap order, the latency and key ring section between the groups: micro region (its head holds the page
-- arrows) | section | bags, or page arrow room | bags | section | micro region; else on the bar 1 side of what stands.
-- Bar 1 with fewer than 12 icons trims the band from the left by whole slots, like the client's bar.
local function BandPlan(microOn, bagsOn, bagsFirst, region)
    local plan = { bagsFirst = (bagsFirst and microOn and bagsOn) and true or false }
    plan.cut = shape.cut or 0
    local x = ART_W / 2 - plan.cut
    plan.base = x
    plan.microFirst = (microOn and not plan.bagsFirst) and true or false
    -- Hide Bar Scrolling: the arrows' room goes and the rest closes up; a first micro region is then drawn as a second one.
    plan.noPages = shape.noPages and true or false
    if plan.microFirst then
        if plan.noPages then
            plan.microStart, plan.microRow = x, x + MICRO_SECOND_LEAD
            x = x + region - MICRO_LEAD + MICRO_SECOND_LEAD
        else
            plan.microStart, plan.microRow = x, x + (MICRO_X - ART_W / 2)
            x = x + region
        end
        plan.microEnd = x
        local before = x
        x = Tail(plan, x, false, bagsOn)
        -- Last on the band, the section's own post ends it; a micro region standing last leaves room for the end post.
        plan.ownEnd = plan.tailStart ~= nil and not bagsOn
        if bagsOn then
            x = Bags(plan, x, x ~= before)
        elseif x == before then
            x = x + POST_W
        end
    else
        if not plan.noPages then x = x + PAGE_ROOM end
        if bagsOn and microOn then
            x = Bags(plan, x, false)
            x = Tail(plan, x, true, false)
            plan.microStart = x
            x = x + region - MICRO_LEAD + MICRO_SECOND_LEAD
            plan.microEnd = x
            -- Last on the band: the row (region less lead and end gap) centred on the floor before the end post.
            local row = region - MICRO_LEAD - MICRO_END_GAP
            plan.microRow = plan.microStart + (plan.microEnd - POST_W - plan.microStart - row) / 2
        elseif bagsOn then
            local before = x
            x = Tail(plan, x, false, true)
            x = Bags(plan, x, x ~= before)
        else
            -- Neither group on the band: the section stays with bar 1, its own post ending the band.
            local before = x
            x = Tail(plan, x, false, false)
            if x ~= before then
                plan.ownEnd = true
            elseif not plan.noPages then
                -- Bar 1 alone: the page number slot's own post ends the band.
                plan.pageRoom, plan.ownEnd, plan.capTuck = PAGE_ALONE, true, CAP_TUCK
                x = x + PAGE_ALONE - PAGE_ROOM
            end
        end
    end
    plan.width = x
    return plan
end
B.BandPlan = BandPlan

local function CurrentPlan()
    if not shape.plan then shape.plan = BandPlan(OnBandMicro(), OnBandBags(), ns.db and ns.db.bagsFirst, shape.region) end
    return shape.plan
end
B.CurrentPlan = CurrentPlan

local function ArtWidth() return CurrentPlan().width end
B.ArtWidth = ArtWidth

-- The art as runs of the four sheets: { x, width, sheet, u0, u1 }.
function B.Segments()
    local plan = CurrentPlan()
    local cut = plan.cut
    local list = {}
    if cut < 256 then
        list[1] = { 0, 256 - cut, 1, cut / 256, 1 }
        list[2] = { 256 - cut, 256, 2, 0, 1 }
    else
        list[1] = { 0, 512 - cut, 2, (cut - 256) / 256, 1 }
    end
    local half = plan.base
    local headless = plan.microFirst and plan.noPages
    if plan.microFirst and not headless then
        local region = plan.microEnd - plan.microStart
        local third = math.min(region, 256)
        list[#list + 1] = { half, third, 3, 0, third / 256 }
        if region > 256 then list[#list + 1] = { half + 256, region - 256, 4, 0, (region - 256) / 256 } end
    elseif not plan.microFirst and not plan.noPages then
        local room = plan.pageRoom or PAGE_ROOM
        list[#list + 1] = { half, room, 3, 0, room / 256 }
    end
    if plan.bagsStart then
        local x, u0 = plan.bagsStart, 256 - BAG_PART + plan.bagTrim
        if B.ReagentSlot() then
            -- Up to the first socket's far wall, the wall-and-socket unit once more, then the rest from that wall.
            local head, unit = B.SOCKET_U0 - u0, B.SOCKET_U1 - B.SOCKET_U0
            list[#list + 1] = { x, head, 4, u0 / 256, B.SOCKET_U0 / 256 }
            list[#list + 1] = { x + head, unit, 4, B.SOCKET_U0 / 256, B.SOCKET_U1 / 256 }
            list[#list + 1] = { x + head + unit, 256 - B.SOCKET_U0, 4, B.SOCKET_U0 / 256, 1 }
        else
            list[#list + 1] = { x, 256 - u0, 4, u0 / 256, 1 }
        end
    end
    if plan.microStart and (not plan.microFirst or headless) then
        -- Standing second: the third sheet from past its page-arrow head, plus the dark start of the fourth if it runs long.
        local width = plan.microEnd - plan.microStart
        local u0 = MICRO_LEAD - MICRO_SECOND_LEAD
        local first = math.min(width, 256 - u0)
        list[#list + 1] = { plan.microStart, first, 3, u0 / 256, (u0 + first) / 256 }
        if width > first then
            list[#list + 1] = { plan.microStart + first, width - first, 4, 0, (width - first) / 256 }
        end
    end
    if plan.tailStart then
        list[#list + 1] = { plan.tailStart, plan.tailU1 - plan.tailU0, 5, plan.tailU0 / 256, plan.tailU1 / 256 }
    end
    -- Right end: with the bags off, the last run was a cut through a sheet and looked sliced; the moved groups'
    -- end post closes it, over the bag part's same pixels where present. A last piece with its own post needs none.
    if not plan.ownEnd then
        list[#list + 1] = { plan.width - POST_W, POST_W, 4, POST_U / 256, (POST_U + POST_W) / 256 }
    end
    return list
end

-- Bar 1's centred home: its bottom-left from the screen's bottom-centre.
function B.HomeSpot(band)
    return ((ns.db.barOffsetX or 0) - ArtWidth() / 2 + ROW_X) * band, ((ns.db.barOffsetY or 0) + ROW_Y) * band
end

-- Whether a frame was dropped near a band spot (band px from its bottom-left), measured on screen where scales agree; plus the distance.
function B.NearBandSlot(frame, bandX, bandY, corner)
    local art = B.art
    if not frame or not art then return false end
    local artScale, scale = art:GetEffectiveScale(), frame:GetEffectiveScale()
    local left, bottom = art:GetLeft(), art:GetBottom()
    if not artScale or not scale or not left or not bottom then return false end
    local wantX, wantY = (left + bandX) * artScale, (bottom + bandY) * artScale
    local hasX = corner == "BOTTOMRIGHT" and frame:GetRight() or frame:GetLeft()
    local hasY = frame:GetBottom()
    if not hasX or not hasY then return false end
    local reach = SNAP_PX * UIParent:GetEffectiveScale()
    local dx, dy = math.abs(hasX * scale - wantX), math.abs(hasY * scale - wantY)
    return dx < reach and dy < reach, dx + dy
end

-- Where a held group would land if dropped now: nil = off the band, else whether bags stand first. Judged on screen:
-- on the band when level with it past bar 1's slots; the side is which half of the stretch past bar 1 its centre is over
-- (both groups counted, so the line holds while the preview swaps them). A shown side holds until clearly past the line.
local function DropPlace(which, frame, current)
    local art = B.art
    if OneBar() or not frame or not art then return nil end
    local artScale, scale = art:GetEffectiveScale(), frame:GetEffectiveScale()
    local aL, aR, aB = art:GetLeft(), art:GetRight(), art:GetBottom()
    local fL, fR, fB = frame:GetLeft(), frame:GetRight(), frame:GetBottom()
    if not (artScale and scale and aL and aR and aB and fL and fR and fB) then return nil end
    local unit = UIParent:GetEffectiveScale()
    local reach = SNAP_PX * unit
    local middle = (fL + fR) / 2 * scale
    if math.abs(fB * scale - aB * artScale) > reach then
        return nil
    end
    local barEnd = (aL + CurrentPlan().base) * artScale
    if middle < barEnd - reach or middle > aR * artScale + 2 * reach then
        return nil
    end
    local otherOn
    if which == "micro" then otherOn = shape.bagsReal ~= false else otherOn = shape.microReal ~= false end
    if not otherOn then return false end
    local both = BandPlan(true, true, false, shape.region)
    local left = aL
    if not ns.barMoved then left = (aL + aR) / 2 - both.width / 2 end
    local line = (left + (both.base + both.width) / 2) * artScale
    local rel = middle - line
    -- Right half: micro second, so bags first; reversed for the bags.
    if which == "bags" then rel = -rel end
    local margin = 16 * unit
    local answer
    if current == true then answer = rel > -margin
    elseif current == false then answer = rel > margin
    else answer = rel > 0 end
    return answer
end
B.DropPlace = DropPlace

-- Re-lay the preview for a group in hand ("micro" or "bags") when it changes; true when it did.
function B.PreviewDrop(which, frame)
    local preview = B.dragPreview
    local place = DropPlace(which, frame, preview.bagsFirst)
    local near = place ~= nil
    if preview[which] == near and not (near and preview.bagsFirst ~= place) then return false end
    preview[which] = near
    -- Not "near and place or nil": place is false for one order and that idiom turns it into nil (no preview).
    if near then preview.bagsFirst = place else preview.bagsFirst = nil end
    ns.QueueApply()
    return true
end
