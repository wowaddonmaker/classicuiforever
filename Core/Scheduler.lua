local _, ns = ...

-- One OnUpdate driver for throttled watches, hidden when idle; between jobs due 0.04 s or more apart a client timer runs its pass.
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

-- A watcher child under a client frame. Never under a client layout frame: its layout reads every child's fields, and
-- one we wrote runs its pass in our name (protected calls refused in a fight).
local function Child(host)
    return CreateFrame("Frame", nil, host)
end
local Report = ns.Report
local runList, runCount = {}, 0  -- awake driver jobs by creation index; the pass walks only these
local cursor = 0                 -- runList slot the pass is at, 0 outside its job loop
local stale = false              -- a job slept inside the loop: compact after it
local nextDue = math.huge        -- earliest pass any awake driver job wants
local passAt                     -- time of the driver's last pass
local soonKeys, soonFns, soonCount = {}, {}, 0
local DOZE = 0.04                -- the next due at least this far off: off the frame loop, a timer runs the next pass
local dozeUntil                  -- when a dozing driver's timer runs its pass; nil when not dozing
local timerPass = false          -- the pass running now is the doze timer's, not the frame loop's

-- A pending client timer finds dozeUntil cleared and does nothing (no timer object to cancel).
local function CancelDoze()
    dozeUntil = nil
end

local function ShowDriver()
    CancelDoze()
    if not driver:IsShown() then driver:Show() end
end

-- Through the script, so the dev addon's wrap times it.
local function WakeDriver()
    -- A replaced doze's timer may run the pass early: it runs only due jobs, then books the next wake.
    if not dozeUntil then return end
    dozeUntil = nil
    local pass = driver:GetScript("OnUpdate")
    if not pass then return end
    timerPass = true
    pass(driver, 0)
    timerPass = false
end

-- Earlier than the timer a dozing driver waits on: back on the frame loop.
local function Lower(t)
    if t >= nextDue then return end
    nextDue = t
    if runCount > 0 and not driver:IsShown() then ShowDriver() end
end

-- End of a pass: on the frame loop for a due this close, else hidden till the timer (none for a job that waits on a kick).
local function Doze(now)
    if soonCount > 0 or runCount <= 0 then return end
    local gap = nextDue - now
    if gap < DOZE then
        ShowDriver()
        return
    end
    driver:Hide()
    if gap ~= math.huge then
        dozeUntil = now + gap
        C_Timer.After(gap, WakeDriver)
    end
end

-- Next wanted pass; 0 if kicked or bursting.
local function Want(job, now)
    if job.kicked or now < job.burstUntil then return 0 end
    return job.due
end

local function SettleDriver()
    if runCount > 0 or soonCount > 0 then return end
    CancelDoze()
    if driver:IsShown() then driver:Hide() end
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

-- Defaults live here, so a job table holds only what differs (126 jobs in a session).
local Job = { host = driver, awake = false, kicked = false, listed = false, last = 0, due = 0, burstUntil = 0,
    since = 0, burst = 0 }
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
    if self.host == driver then
        if self.awake then Lower(0) end
    elseif self.awake and not self.host:IsShown() then
        -- A dozing kick-only job back on the frame loop.
        self.host:Show()
    end
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
    local job = setmetatable({ name = spec.name or ("job " .. index), fn = spec.fn, every = every, index = index,
        pre = spec.pre }, JobMeta)
    if host ~= driver then job.host = host end
    if spec.first == "now" then job.kicked = true end
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
    -- Soon's promise is about the frame loop's pass, after the frame's events.
    if not timerPass then passAt = now end
    if soonCount > 0 then
        RunSoon()
        SettleDriver()
    end
    if now < nextDue then return Doze(now) end
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
    Doze(now)
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
            -- Kick-only with nothing asked: off the frame loop till the next Kick.
            if job.every == math.huge and not pre then frame:Hide() end
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
    job = Sched.OnFrame(Child(host), spec)
    byName[spec.name] = job
    return job, true
end

function Sched.Attached(host, name)
    local byName = attached[host]
    return byName and byName[name]
end

-- OnVisible(host, name, fn) -> child: fn(shown) on each visibility edge of host, from one pure child per host and name.
-- It runs inside the client's show pass: fn only notes, kicks or asks NextFrame.
local edgeChildren = setmetatable({}, { __mode = "k" })
function Sched.OnVisible(host, name, fn)
    -- Only a frame can hold a child (retail's bar end caps are textures): nil for anything else.
    if not (host and host.IsObjectType and host:IsObjectType("Frame")) then return nil end
    local byName = edgeChildren[host]
    if not byName then
        byName = {}
        edgeChildren[host] = byName
    end
    local child = byName[name]
    if child then return child end
    child = Child(host)
    child:SetScript("OnShow", function() fn(true) end)
    child:SetScript("OnHide", function() fn(false) end)
    byName[name] = child
    return child
end

-- AfterShow(host, name, fn) -> child: fn() once per showing of host, from a pure child whose OnShow (inside the client's
-- show pass) only arms its OnUpdate: after that pass, ahead of the frame's first draw.
local shownChildren = setmetatable({}, { __mode = "k" })
function Sched.AfterShow(host, name, fn)
    if not (host and host.IsObjectType and host:IsObjectType("Frame")) then return nil end
    local byName = shownChildren[host]
    if not byName then
        byName = {}
        shownChildren[host] = byName
    end
    if byName[name] then return byName[name] end
    local child = Child(host)
    local function Run(self)
        self:SetScript("OnUpdate", nil)
        xpcall(fn, Report)
    end
    child:SetScript("OnShow", function(self) self:SetScript("OnUpdate", Run) end)
    byName[name] = child
    return child
end

-- Every helper as { helper, pointA, relA, pointB, relB }. A frame anything outside it hangs on is dropped with no anchor by
-- the client's StartMoving/StopMovingOrSizing, so the helpers let go while edit mode (the only drags) is open.
local moveHelpers = {}
local helpersLoose, editHooked = false, false

-- Retail refuses an anchor that would join two anchor families (FriendsFrame): that helper stays loose and hears nothing.
local function PinHelper(entry)
    local helper = entry[1]
    if not (pcall(helper.SetPoint, helper, "TOPLEFT", entry[3], entry[2])
        and pcall(helper.SetPoint, helper, "BOTTOMRIGHT", entry[5], entry[4])) then
        helper:ClearAllPoints()
    end
end

-- On edit mode's edges: loose while open (the band is awake every frame then), pinned again as it closes (each fires once).
local function SyncHelpers()
    local loose = ns.EditMode.Live() and true or false
    if loose == helpersLoose then return end
    helpersLoose = loose
    for i = 1, #moveHelpers do
        local entry = moveHelpers[i]
        if loose then entry[1]:ClearAllPoints() else PinHelper(entry) end
    end
end

local function MoveHelper(pointA, relA, pointB, relB, fn)
    local helper = CreateFrame("Frame", nil, UIParent)
    local entry = { helper, pointA, relA, pointB, relB }
    moveHelpers[#moveHelpers + 1] = entry
    if not helpersLoose then PinHelper(entry) end
    helper:SetScript("OnSizeChanged", fn)
end

-- OnMove(frame, fn): fn() in the layout pass that moves or resizes frame, before a draw. Two unseen helpers, each from one
-- of its corners to the screen's far corner, so any move or resize changes one helper's size. Not heard in edit mode.
function Sched.OnMove(frame, fn)
    if not editHooked then
        editHooked = true
        ns.OnEditMode(SyncHelpers)
        helpersLoose = ns.EditMode.Live() and true or false
    end
    MoveHelper("TOPLEFT", frame, "BOTTOMRIGHT", UIParent, fn)
    MoveHelper("TOPLEFT", UIParent, "BOTTOMRIGHT", frame, fn)
end

-- LetGo(frame, loose): the helpers hung on frame let go for a drag of ours (StartMoving left it with no anchor, unseen)
-- and pin again after it.
function Sched.LetGo(frame, loose)
    if helpersLoose then return end
    for i = 1, #moveHelpers do
        local entry = moveHelpers[i]
        if entry[3] == frame or entry[5] == frame then
            if loose then entry[1]:ClearAllPoints() else PinHelper(entry) end
        end
    end
end

-- OnHover(host, fn, pad) -> true when set: fn(over) as the mouse enters or leaves host (grown by pad), from a child that
-- takes no clicks and passes its motion on to host, so host keeps its own hover. False: the client refused (poll instead).
function Sched.OnHover(host, fn, pad)
    local child = Child(host)
    pad = pad or 0
    child:SetPoint("TOPLEFT", host, "TOPLEFT", -pad, pad)
    child:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", pad, -pad)
    local ok = pcall(child.SetMouseClickEnabled, child, false) and pcall(child.SetMouseMotionEnabled, child, true)
        and pcall(child.SetPropagateMouseMotion, child, true)
    if not ok then
        child:EnableMouse(false)
        return false
    end
    child:SetScript("OnEnter", function() fn(true) end)
    child:SetScript("OnLeave", function() fn(false) end)
    return true
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
