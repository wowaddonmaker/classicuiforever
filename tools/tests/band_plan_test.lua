-- Offline test for the band plan (Bar/BandShape.lua) under Lua 5.4.
-- Run from the addon root: lua tools/tests/band_plan_test.lua (CI runs every tools/tests/*_test.lua).
-- The latency and key ring section may drop its own left post only right after a real post (the micro row's, the
-- bags' end); what follows the page number slot starts at its post, not past the dark stone beside the box.
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

-- Any method on a stub frame does nothing.
local function Stub()
    return setmetatable({}, { __index = function() return function() end end })
end
function CreateFrame() return Stub() end
function GetTime() return 0 end
KeyRingButton = Stub()
CharacterReagentBag0Slot = Stub()

-- Other addon helpers the band files touch at load: callable, indexable, doing nothing.
local Loose = {}
setmetatable(Loose, { __index = function() return Loose end, __call = function() return Loose end })
local ns = setmetatable({
    L = setmetatable({}, { __index = function(_, k) return k end }),
    ValidPlace = function(p) return type(p) == "table" and p.point ~= nil end,
    db = {},
}, { __index = function() return Loose end })
for _, file in ipairs({ "Bar/Band.lua", "Bar/BandShape.lua" }) do
    local chunk = assert(loadfile(ROOT .. "/" .. file))
    chunk("ClassicUIForever", ns)
end
local B = ns.band

-- Section starts that leave out its own left post (B.TailSpan: latency after a post 7, key ring alone after one 23).
local POSTLESS = { [7] = true, [23] = true }

local failures, cases = 0, 0
for _, micro in ipairs({ true, false }) do
for _, bags in ipairs({ true, false }) do
for _, bagsFirst in ipairs({ true, false }) do
for _, noPages in ipairs({ true, false }) do
for _, hideLatency in ipairs({ true, false }) do
for _, hideKey in ipairs({ true, false }) do
for _, reagent in ipairs({ true, false }) do
for _, eraBags in ipairs({ true, false }) do
    ns.db.hideLatencyBar, ns.db.hideKeyRing = hideLatency, hideKey
    ns.db.reagentBagSlot, ns.db.eraBagSize = reagent, eraBags
    B.shape.noPages = noPages
    local plan = B.BandPlan(micro, bags, bagsFirst, B.MICRO_REGION_MAX)
    cases = cases + 1
    -- A piece after the page number slot starts at its post, under the box's edge: no dark stone between.
    local after = not plan.microFirst and not noPages and (plan.tailStart or plan.bagsStart)
    local edge = plan.base + B.PAGE_POST
    if after and not (plan.pageEdge == edge and (plan.tailStart == edge or plan.bagsStart == edge)) then
        failures = failures + 1
        print(string.format("FAIL dark stone after the page number post: micro=%s bags=%s bagsFirst=%s start=%s edge=%s",
            tostring(micro), tostring(bags), tostring(bagsFirst), tostring(after), tostring(plan.pageEdge)))
    end
    if plan.tailStart and POSTLESS[plan.tailU0] then
        local afterMicroPost = plan.microPost ~= nil and plan.tailStart == plan.microPost + B.POST_W
        local afterBags = plan.bagsEnd ~= nil and plan.tailStart == plan.bagsEnd
        if not (afterMicroPost or afterBags) then
            failures = failures + 1
            print(string.format("FAIL section drops its left post with no post before it: micro=%s bags=%s bagsFirst=%s"
                .. " noPages=%s hideLatency=%s hideKey=%s tailStart=%s tailU0=%s", tostring(micro), tostring(bags),
                tostring(bagsFirst), tostring(noPages), tostring(hideLatency), tostring(hideKey),
                tostring(plan.tailStart), tostring(plan.tailU0)))
        end
    end
end end end end end end end end

print(string.format("band plan: %d cases, %d failures", cases, failures))
if failures > 0 then os.exit(1) end
