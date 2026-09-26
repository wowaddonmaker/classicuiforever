local _, ns = ...
local B = ns.band

-- 1.x latency bar: a tube behind the latency window (under the band art, so the window's frame and dividers draw over it),
-- tinted by the worse of home and world latency at the old 300 and 600 ms marks, read every 10 s while one shows.
-- One on the band's section, one on the latency bar moved off the band (BandSection.lua).
local LOW, HIGH, EVERY = 300, 600, 10
-- The window: 7 wide, open from 2 to 39 up the band.
local TUBE_W, TUBE_H, TUBE_Y = 7, 37, 2

local tubes = {}
local job, bandTube

local function Latency()
    local _, _, home, world = GetNetStats()
    if ns.AnySecret(home, world) or type(home) ~= "number" or type(world) ~= "number" then return nil end
    return home, world
end

local function Paint(self)
    local home, world = Latency()
    local worst = home and math.max(home, world)
    local r, g = 0, 1
    if worst and worst > HIGH then r, g = 1, 0 elseif worst and worst > LOW then r = 1 end
    local seen = false
    for i = 1, #tubes do
        local tube = tubes[i]
        if tube:IsVisible() then
            seen = true
            if worst then tube:SetVertexColor(r, g, 0) end
        end
    end
    if not seen then self:Sleep() end
end

local function TipText()
    local home, world = Latency()
    if not home then return nil end
    local label = _G.MAINMENUBAR_LATENCY_LABEL
    if type(label) == "string" and label:find("%", 1, true) then return label:format(home, world) end
    return ("Latency: %d ms (home), %d ms (world)"):format(home, world)
end
local TUBE_TIP = { text = TipText, r = 1, g = 1, b = 1 }

-- A tube on parent, under its band art; a bare frame over the window carries the tooltip (textures take no mouse).
function B.MakeTube(parent)
    local tube = parent:CreateTexture(nil, "BACKGROUND", nil, -8)
    ns.SetTex(tube, "latencyBar")
    -- From the tube art's second row: its first is nearly clear and left a gap under the window's frame.
    tube:SetTexCoord(0, 7 / 8, 1 / 64, 38 / 64)
    tube:SetVertexColor(0, 1, 0)
    tube:SetSize(TUBE_W, TUBE_H)
    local hover = CreateFrame("Frame", nil, parent)
    hover:SetPoint("TOPLEFT", tube, "TOPLEFT", -3, 2)
    hover:SetPoint("BOTTOMRIGHT", tube, "BOTTOMRIGHT", 3, -2)
    hover:EnableMouse(true)
    ns.AttachTip(hover, TUBE_TIP)
    tube.hover = hover
    tubes[#tubes + 1] = tube
    job = job or ns.Sched.Job({ name = "band.latency", every = EVERY, fn = Paint, awake = false })
    return tube
end

-- x: the window's left column on parent; nil hides it.
function B.PlaceTube(tube, parent, x)
    if not x then
        tube:Hide()
        tube.hover:Hide()
        return
    end
    if not ns.IsAt(tube, "BOTTOMLEFT", parent, "BOTTOMLEFT", x, TUBE_Y) then
        ns.SetPointOnce(tube, "BOTTOMLEFT", parent, "BOTTOMLEFT", x, TUBE_Y)
    end
    tube:Show()
    tube.hover:Show()
    if not job:IsAwake() then
        job:Wake()
        job:Kick()
    end
end

-- Each art paint: in the band section's window while it shows its latency half; bare (Hide Bar Art) hides it with the band.
function B.LayLatency(bare)
    local art, plan = B.art, B.CurrentPlan()
    local on = not bare and plan.tailStart ~= nil and (B.TailParts())
    if not on and not bandTube then return end
    bandTube = bandTube or B.MakeTube(art)
    B.PlaceTube(bandTube, art, on and (plan.tailStart + B.TAIL_WINDOW - plan.tailU0) or nil)
end
