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
local Report = ns.Report
local runList, runCount = {}, 0  -- awake driver jobs by creation index; the pass walks only these
local cursor = 0                 -- runList slot the pass is at, 0 outside its job loop
local stale = false              -- a job slept inside the loop: compact after it
local nextDue = math.huge        -- earliest pass any awake driver job wants
local passAt                     -- time of the driver's last pass
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
    if runCount <= 0 and soonCount <= 0 and driver:IsShown() then driver:Hide() end
end

-- By index; a slot at or before the cursor moves the cursor, so the pass visits it only if it comes later.
local function Insert(job)
    local index, pos = job.index, runCount
    while pos > 0 and runList[pos].index > index do
        runList[pos + 1] = runList[pos]
        pos = pos - 1
    end
    runList[pos + 1] = job
    runCount = runCount + 1
    job.listed = true
    if pos + 1 <= cursor then cursor = cursor + 1 end
end

local function Remove(job)
    for i = 1, runCount do
        if runList[i] == job then
            for j = i, runCount - 1 do runList[j] = runList[j + 1] end
            runList[runCount] = nil
            runCount = runCount - 1
            job.listed = false
            return
        end
    end
end

local function Compact()
    stale = false
    local n = 0
    for i = 1, runCount do
        local job = runList[i]
        if job.awake then
            n = n + 1
            runList[n] = job
        else
            job.listed = false
        end
    end
    for i = n + 1, runCount do runList[i] = nil end
    runCount = n
    SettleDriver()
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
    -- Slept earlier in this pass: still listed until the compaction.
    if not self.listed then Insert(self) end
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
    -- Inside the loop the list may not shift under the cursor.
    if cursor > 0 then
        stale = true
        return
    end
    Remove(self)
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
        return xpcall(self.fn, Report, self, now, ...)
    end
    local since = self.since
    self.since = 0
    return xpcall(self.fn, Report, self, since, ...)
end

-- For an OnFrame job's pre: whether this frame's elapsed completes the period.
function Job:DueWith(elapsed)
    return self.since + elapsed >= self.every
end

local function NewJob(spec, host, level)
    if type(spec) ~= "table" or type(spec.fn) ~= "function" then
        error("ns.Sched: a job is made from a table with a function in fn", level)
    end
    local every = spec.every or 0
    if type(every) ~= "number" or every < 0 then
        error("ns.Sched: every is a number of seconds, 0 or more", level)
    end
    local index = #jobs + 1
    local job = setmetatable({
        name = spec.name or ("job " .. index),
        fn = spec.fn,
        every = every,
        host = host,
        pre = spec.pre,
        index = index,
        awake = false,
        kicked = spec.first == "now",
        last = 0, due = 0, burstUntil = 0, listed = false,   -- driver jobs
        since = 0, burst = 0,                                -- own-frame jobs
    }, JobMeta)
    jobs[index] = job
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
        if fn then xpcall(fn, Report) end
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
    -- A job made during the pass waits for the next one.
    local limit = #jobs
    cursor = 1
    while cursor <= runCount do
        local job = runList[cursor]
        if job.index > limit then break end
        if job.awake then
            if job.kicked or now >= job.due or now < job.burstUntil then
                job.kicked = false
                job.last = now
                job.due = now + job.every
                xpcall(job.fn, Report, job, now)
            end
            if job.awake then
                local want = (job.kicked or now < job.burstUntil) and 0 or job.due
                if want < nextDue then nextDue = want end
            end
        end
        cursor = cursor + 1
    end
    cursor = 0
    if stale then Compact() end
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
        xpcall(job.fn, Report, job, since)
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

-- Lane beat: state[key or "since"] gathers elapsed; due or forced resets it and returns the time gathered, else nil.
function Sched.Due(state, elapsed, every, force, key)
    key = key or "since"
    local since = state[key] + elapsed
    if since < every and not force then
        state[key] = since
        return nil
    end
    state[key] = 0
    return since
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
