local _, ns = ...

-- One OnUpdate driver for throttled watches, hidden when idle; an idle pass is one GetTime and one compare.
-- Made after Core.lua's event frame (which must stay first). A watch that must see a client move on its frame uses OnFrame.
-- Jobs are always called through their table so the dev addon can wrap fn for timing.

local Sched = {}
ns.Sched = Sched

-- Creation order, which is also the run order for jobs due together.
local jobs = {}
Sched.jobs = jobs

local driver = CreateFrame("Frame")
driver:Hide()

local GetTime = GetTime
local awakeCount = 0          -- awake driver jobs
local nextDue = math.huge     -- earliest pass any awake driver job wants
local passAt                  -- time of the driver's last pass
local soonKeys, soonFns, soonCount = {}, {}, 0

local function Lower(t)
    if t < nextDue then nextDue = t end
end

-- Next wanted pass; 0 if kicked or bursting.
local function Want(job, now)
    if job.kicked or now < job.burstUntil then return 0 end
    return job.due
end

local function ShowDriver()
    if not driver:IsShown() then driver:Show() end
end

local function SettleDriver()
    if awakeCount <= 0 and soonCount <= 0 and driver:IsShown() then driver:Hide() end
end

------------------------------------------------------------------ the job

local Job = {}
local JobMeta = { __index = Job }

-- Due one period after waking; kicked while asleep runs on the first pass. Own-frame jobs Show.
function Job:Wake()
    if self.host ~= driver then
        self.host:Show()
        self.awake = true
        return
    end
    if self.awake then return end
    self.awake = true
    awakeCount = awakeCount + 1
    local now = GetTime()
    self.last = now
    self.due = now + self.every
    Lower(Want(self, now))
    ShowDriver()
end

-- Own-frame jobs Hide, so their frames must be pure watchers (no regions or children).
function Job:Sleep()
    if self.host ~= driver then
        self.host:Hide()
        self.awake = false
        return
    end
    if not self.awake then return end
    self.awake = false
    awakeCount = awakeCount - 1
    SettleDriver()
end

-- An own-frame job's OnUpdate runs only while visible.
function Job:IsAwake()
    if self.host ~= driver then return self.host:IsVisible() and true or false end
    return self.awake
end

-- Run on the next pass.
function Job:Kick()
    self.kicked = true
    if self.host == driver and self.awake then Lower(0) end
end

-- Run every pass for seconds, then resume the period from the last run.
function Job:Burst(seconds)
    if self.host ~= driver then
        self.burst = seconds
        return
    end
    self.burstUntil = GetTime() + seconds
    if self.awake then Lower(0) end
end

-- New period, counted from the last run.
function Job:SetEvery(seconds)
    if type(seconds) ~= "number" or seconds < 0 then
        error("ns.Sched: every is a number of seconds, 0 or more", 2)
    end
    self.every = seconds
    if self.host == driver then
        self.due = self.last + seconds
        if self.awake then Lower(Want(self, GetTime())) end
    end
end

-- Call fn now whatever the state and restart the period; extra args follow (job, now|since).
function Job:RunNow(...)
    self.kicked = false
    if self.host == driver then
        local now = GetTime()
        self.last = now
        self.due = now + self.every
        return xpcall(self.fn, geterrorhandler(), self, now, ...)
    end
    local since = self.since
    self.since = 0
    return xpcall(self.fn, geterrorhandler(), self, since, ...)
end

local function NewJob(spec, host, level)
    if type(spec) ~= "table" or type(spec.fn) ~= "function" then
        error("ns.Sched: a job is made from a table with a function in fn", level)
    end
    local every = spec.every or 0
    if type(every) ~= "number" or every < 0 then
        error("ns.Sched: every is a number of seconds, 0 or more", level)
    end
    local job = setmetatable({
        name = spec.name or ("job " .. (#jobs + 1)),
        fn = spec.fn,
        every = every,
        host = host,
        pre = spec.pre,
        awake = false,
        kicked = spec.first == "now",
        last = 0, due = 0, burstUntil = 0,   -- driver jobs
        since = 0, burst = 0,                -- own-frame jobs
    }, JobMeta)
    jobs[#jobs + 1] = job
    return job
end

--------------------------------------------------------------- the driver

-- In request order; each key clears before its fn runs.
local function RunSoon()
    for i = 1, soonCount do
        local key = soonKeys[i]
        soonKeys[i] = nil
        local fn = soonFns[key]
        soonFns[key] = nil
        if fn then xpcall(fn, geterrorhandler()) end
    end
    soonCount = 0
end

-- Set once, never replaced: the dev addon wraps it and restores it by identity.
driver:SetScript("OnUpdate", function()
    local now = GetTime()
    passAt = now
    if soonCount > 0 then
        RunSoon()
        SettleDriver()
    end
    if now < nextDue then return end
    nextDue = math.huge
    for i = 1, #jobs do
        local job = jobs[i]
        if job.awake and job.host == driver then
            if job.kicked or now >= job.due or now < job.burstUntil then
                job.kicked = false
                job.last = now
                job.due = now + job.every
                xpcall(job.fn, geterrorhandler(), job, now)
            end
            if job.awake then Lower(Want(job, now)) end
        end
    end
end)

-------------------------------------------------------------------- the API

-- Job{ name, every = seconds (0 = every pass), fn(job, now), awake = true, first = "later"|"now" }.
-- Runs on the first pass at or past due, then one period later.
function Sched.Job(spec)
    local job = NewJob(spec, driver, 3)
    if spec.awake ~= false then job:Wake() end
    return job
end

-- OnFrame(frame, { name, every, fn(job, since), pre(job, elapsed), awake }): job on the caller's
-- frame, OnUpdate set once. pre runs every frame and true forces fn. awake = false hides the frame.
local hosted = setmetatable({}, { __mode = "k" })
function Sched.OnFrame(frame, spec)
    if type(frame) ~= "table" or type(frame.SetScript) ~= "function" then
        error("ns.Sched.OnFrame: the first argument is a frame", 2)
    end
    if hosted[frame] then error("ns.Sched.OnFrame: that frame runs a job already", 2) end
    local job = NewJob(spec, frame, 3)
    hosted[frame] = job
    if spec.awake == false then frame:Hide() end
    job.awake = frame:IsShown() and true or false
    frame:SetScript("OnUpdate", function(_, elapsed)
        local pre = job.pre
        local force = pre and pre(job, elapsed)
        local since = job.since + elapsed
        local burst = job.burst
        if burst > 0 then
            burst = burst - elapsed
            job.burst = burst
        end
        if since < job.every and burst <= 0 and not job.kicked and not force then
            job.since = since
            return
        end
        job.since = 0
        job.kicked = false
        xpcall(job.fn, geterrorhandler(), job, since)
    end)
    return job
end

-- Attach(host, spec) -> job, made: one pure child watcher per host and job name, made on the first call; kept here, not on host.
local attached = setmetatable({}, { __mode = "k" })
function Sched.Attach(host, spec)
    local byName = attached[host]
    if not byName then
        byName = {}
        attached[host] = byName
    end
    local job = byName[spec.name]
    if job then return job, false end
    job = Sched.OnFrame(CreateFrame("Frame", nil, host), spec)
    byName[spec.name] = job
    return job, true
end

function Sched.Attached(host, name)
    local byName = attached[host]
    return byName and byName[name]
end

-- Soon(key, fn): once in this frame's driver pass, deduped by key; runs at once if the pass already
-- ran this frame, never a frame late. Not for leaving a client pass: use NextFrame.
function Sched.Soon(key, fn)
    if passAt == GetTime() then
        soonFns[key] = nil
        return fn()
    end
    if soonFns[key] == nil then
        soonCount = soonCount + 1
        soonKeys[soonCount] = key
    end
    soonFns[key] = fn
    ShowDriver()
end

-- NextFrame(key, fn): C_Timer.After(0), one pending per key, newest fn wins; fn may re-ask.
local nextFns, nextWaiting, nextRunners = {}, {}, {}
function Sched.NextFrame(key, fn)
    nextFns[key] = fn
    if nextWaiting[key] then return end
    nextWaiting[key] = true
    local runner = nextRunners[key]
    if not runner then
        runner = function()
            nextWaiting[key] = nil
            local run = nextFns[key]
            if run then run() end
        end
        nextRunners[key] = runner
    end
    C_Timer.After(0, runner)
end

-- AfterPerFrame(key, seconds, fn): C_Timer.After, deduped per key and delay within one frame only,
-- so no later re-check is lost. The first fn in a frame is the one timed.
local afterStamps = {}
function Sched.AfterPerFrame(key, seconds, fn)
    local now = GetTime()
    local stamps = afterStamps[key]
    if not stamps then
        stamps = {}
        afterStamps[key] = stamps
    end
    if stamps[seconds] == now then return false end
    stamps[seconds] = now
    C_Timer.After(seconds, fn)
    return true
end
