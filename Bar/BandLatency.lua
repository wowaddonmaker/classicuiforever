local _, ns = ...
local B = ns.band

-- 1.x latency bar: a tube in the stone recess left of the key ring post, tinted by the worse of home and world
-- latency at the old 300 and 600 ms marks, read every 10 s while it shows.
local LOW, HIGH, EVERY = 300, 600, 10
-- The old 7x38 texel tube at its 1.25 x 1.03 stretch, 8 left of the key ring and centred with it.
local TUBE_W, TUBE_H, TUBE_GAP = 9, 39, -8

local tube, job

local function Latency()
    local _, _, home, world = GetNetStats()
    if ns.AnySecret(home, world) or type(home) ~= "number" or type(world) ~= "number" then return nil end
    return home, world
end

local function Paint(self)
    if not tube:IsVisible() then
        self:Sleep()
        return
    end
    local home, world = Latency()
    if not home then return end
    local worst = math.max(home, world)
    if worst > HIGH then
        tube.tex:SetVertexColor(1, 0, 0)
    elseif worst > LOW then
        tube.tex:SetVertexColor(1, 1, 0)
    else
        tube.tex:SetVertexColor(0, 1, 0)
    end
end

local function TipText()
    local home, world = Latency()
    if not home then return nil end
    local label = _G.MAINMENUBAR_LATENCY_LABEL
    if type(label) == "string" and label:find("%", 1, true) then return label:format(home, world) end
    return ("Latency: %d ms (home), %d ms (world)"):format(home, world)
end
local TUBE_TIP = { text = TipText, r = 1, g = 1, b = 1 }

local function MakeTube()
    tube = CreateFrame("Frame", nil, B.art)
    tube:SetSize(TUBE_W, TUBE_H)
    local tex = tube:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(tube)
    ns.SetTex(tex, "latencyBar")
    tex:SetTexCoord(0, 7 / 8, 0, 38 / 64)
    tex:SetVertexColor(0, 1, 0)
    tube.tex = tex
    tube:EnableMouse(true)
    ns.AttachTip(tube, TUBE_TIP)
    job = ns.Sched.Job({ name = "band.latency", every = EVERY, fn = Paint, awake = false })
end

-- Beside what fills the key ring hole while the bags stand on the band; nil hides it.
function B.LayLatency(beside, scale, level)
    if not beside then
        if tube then tube:Hide() end
        return
    end
    if not tube then MakeTube() end
    ns.SetScaleIf(tube, scale)
    ns.SetLevelIf(tube, level)
    ns.SetPointOnce(tube, "RIGHT", beside, "LEFT", TUBE_GAP, 0)
    if not tube:IsShown() then tube:Show() end
    if not job:IsAwake() then
        job:Wake()
        job:Kick()
    end
end
