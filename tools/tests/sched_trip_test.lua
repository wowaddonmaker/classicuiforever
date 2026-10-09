-- Offline test under Lua 5.4 for the scheduler's stop after repeated errors (Core/Scheduler.lua). A job whose fn failed
-- every frame was reported every frame (#139: 779 errors from the settings window's look pass). Now 5 errors within
-- 10 s stop it for the session with one note; a job that errors now and then keeps running.
-- Run from the addon root: lua tools/tests/sched_trip_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

------------------------------------------------------------------ the stub client

local frames = {}
local function Frame(parent)
    local frame = { shown = true, parent = parent, scripts = {} }
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function frame:SetScript(name, fn) self.scripts[name] = fn end
    function frame:GetScript(name) return self.scripts[name] end
    frames[#frames + 1] = frame
    return frame
end
function CreateFrame(_, _, parent) return Frame(parent) end
local clock = 0
function GetTime() return clock end
C_Timer = { After = function() end }

local reported, notes = 0, {}
local ns = { Report = function() reported = reported + 1 end }
ns.NoteStopped = function(name, err) notes[#notes + 1] = { name = name, err = err } end
assert(loadfile(ROOT .. "/Core/Scheduler.lua"))("ClassicUIForever", ns)
local driver = frames[1]

local function Draw(count)
    for _ = 1, count do
        clock = clock + 0.1
        for _, frame in ipairs(frames) do
            local onUpdate = frame.scripts.OnUpdate
            if onUpdate and frame:IsVisible() then onUpdate(frame, 0.1) end
        end
    end
end

------------------------------------------------------------------ an error every frame

local calls = 0
local broken = ns.Sched.Job({ name = "test.broken", every = 0, fn = function()
    calls = calls + 1
    error("broken pass")
end })
Draw(20)
Check(calls == 5 and reported == 5, "an error every frame: run and reported 5 times, then stopped (ran " .. calls .. ")")
Check(not broken:IsAwake(), "the stopped job sleeps")
Check(#notes == 1 and notes[1].name == "test.broken" and tostring(notes[1].err):find("broken pass", 1, true),
    "one note names the job and its error")
broken:Wake()
broken:Kick()
Check(broken:RunNow() == false and calls == 5, "Wake, Kick and RunNow leave a stopped job alone")
Draw(5)
Check(calls == 5, "it stays stopped")

------------------------------------------------------------------ now and then, or a few then fine

local rare = ns.Sched.Job({ name = "test.rare", every = math.huge, awake = false, fn = function() error("rare") end })
for _ = 1, 8 do
    clock = clock + 20
    rare:RunNow()
end
Check(not rare.stopped and #notes == 1, "an error every 20 s never stops the job")

local runs = 0
local flaky = ns.Sched.Job({ name = "test.flaky", every = 0, fn = function()
    runs = runs + 1
    if runs <= 4 then error("settling") end
end })
Draw(10)
Check(not flaky.stopped and flaky:IsAwake() and runs >= 10, "4 errors then fine: the job keeps running")

------------------------------------------------------------------ a job on its own frame

local host = Frame()
local onFrameCalls = 0
local own = ns.Sched.OnFrame(host, { name = "test.own", every = 0, fn = function()
    onFrameCalls = onFrameCalls + 1
    error("own frame")
end })
Draw(10)
Check(onFrameCalls == 5 and own.stopped and not host:IsShown(), "an own-frame job stops and its frame hides")
host:Show()
Draw(3)
Check(onFrameCalls == 5 and not host:IsShown(), "shown again by other code, it stays idle")
Check(driver ~= nil, "the driver frame was made")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("sched_trip_test: ok")
