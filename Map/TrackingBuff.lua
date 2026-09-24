local _, ns = ...

-- While the classic tracking icon shows the tracking spell, its buff leaves the buff bar, as in 1.x.
-- Watch only: after each client fill, hide that button and move each later one into the slot the
-- client gave the one before it (read from the client's own anchors), so no gap is left.

local MM = ns.MM
local IsSecret = ns.IsSecret
local C_UnitAuras = _G.C_UnitAuras

local buffs, frames, container  -- BuffFrame, its buttons in fill order, their container
local watch, job                -- pure watcher; also the container's stand-in in our anchors
local homes = {}                -- [k] = button k's anchor as the client set it
local spell, icon, auraID       -- tracking spell, its icon, its aura instance on the player
local at, last, layoutAt        -- hidden button, last moved button, layout they were placed in
local seenInfo, seenLayout      -- the client makes both tables anew on each fill and each layout
local seenExample               -- edit mode example flag; its edges refill without a new auraInfo

-- By aura instance; by icon on a permanent buff only while the instance is unknown or secret.
local function IsTracking(info)
    if not info then return false end
    local id = info.auraInstanceID
    if auraID and not IsSecret(id) and id ~= nil then return id == auraID end
    local tex, dur = info.texture, info.duration
    if icon == nil or IsSecret(tex) or IsSecret(dur) then return false end
    return tex == icon and dur == 0
end

-- Filled buttons are a prefix: the tracking one's index (or nil) and the prefix length.
-- Edit mode examples keep stale info, so they end it: the example grid stays whole.
local function Find()
    local mine = PlayerFrame and PlayerFrame.unit == "player"
    local t, n = nil, 0
    for i = 1, #frames do
        local b = frames[i]
        if not b.hasValidInfo or b.isExample then break end
        n = i
        if mine and not t and b.auraType == "Buff" and IsTracking(b.buttonInfo) then t = i end
    end
    return t, n
end

-- Kept when unreadable (auras can be restricted in a fight).
local function Resolve()
    local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if not get or spell == nil then return end
    local ok, aura = pcall(get, spell)
    if not ok or IsSecret(aura) or type(aura) ~= "table" then return end
    local id = aura.auraInstanceID
    if not IsSecret(id) and id ~= nil then auraID = id end
end

-- Button k's slot as the client set it: read live, or the stored one while k hangs on watch.
local function Home(k)
    local p, rel, rp, x, y = frames[k]:GetPoint(1)
    if ns.AnySecret(p, rel, rp, x, y) or p == nil then return nil end
    if rel == watch then return homes[k] end
    local h = homes[k]
    if not h then
        h = {}
        homes[k] = h
    end
    h[1], h[2], h[3], h[4], h[5] = p, rel, rp, x, y
    return h
end

-- Anchored through watch (same rect as the container) so ours are told from the client's.
local function Place(k)
    local h, b = homes[k - 1], frames[k]
    b:ClearAllPoints()
    b:SetPoint(h[1], watch, h[3], h[4], h[5])
end

local function Unshift(k)
    local b, h = frames[k], homes[k]
    local _, rel = b:GetPoint(1)
    if not h or IsSecret(rel) or rel ~= watch then return end
    b:ClearAllPoints()
    b:SetPoint(h[1], h[2], h[3], h[4], h[5])
end

local function Unhide(b)
    if (b.hasValidInfo or b.isExample) and not b:IsShown() then b:Show() end
end

-- Plain buttons in this client; should they turn protected, nothing moves in a fight.
local function Blocked()
    return InCombatLockdown() and frames[1]:IsProtected()
end

local function RestoreAll()
    if not at then return end
    if Blocked() then
        ns.WhenCalm("trackingBuff", RestoreAll)
        return
    end
    for k = at + 1, last do Unshift(k) end
    Unhide(frames[at])
    at, last, layoutAt = nil, nil, nil
end

-- After a client fill or layout: hide the tracking button and close its slot.
local function Pass()
    seenInfo, seenLayout = buffs.auraInfo, container.currentGridLayoutInfo
    seenExample = frames[1].isExample
    if Blocked() then return end
    local t, n = Find()
    if not t and spell ~= nil then
        local old = auraID
        Resolve()
        if auraID ~= old then t, n = Find() end
    end
    local same = seenLayout == layoutAt
    if t and t == at and n == last and same then
        if frames[t]:IsShown() then frames[t]:Hide() end
        return
    end
    -- Slots are read before anything moves; an unreadable one ends the shift there.
    if t then
        for k = t, n do
            if not Home(k) then
                n = k - 1
                break
            end
        end
        if n < t then t = nil end
    end
    local prevAt, prevLast = at, last
    if prevAt then
        for k = prevAt + 1, prevLast do
            if not t or k <= t or k > n then Unshift(k) end
        end
        if prevAt ~= t then Unhide(frames[prevAt]) end
    end
    at, last, layoutAt = nil, nil, nil
    if not t then return end
    -- Button k always goes to k-1's slot: one already there in this layout stays put.
    for k = t + 1, n do
        if not (same and prevAt and k > prevAt and k <= prevLast) then Place(k) end
    end
    at, last, layoutAt = t, n, seenLayout
    if frames[t]:IsShown() then frames[t]:Hide() end
end

-- Every frame, four reads: the client refilled, re-laid, entered or left the example grid,
-- or showed our hidden button again.
local function Changed()
    return buffs.auraInfo ~= seenInfo or container.currentGridLayoutInfo ~= seenLayout
        or frames[1].isExample ~= seenExample or (at ~= nil and frames[at]:IsShown())
end

local function Init()
    if frames then return true end
    local bf = BuffFrame
    if not (bf and bf.auraFrames and bf.auraFrames[1] and bf.AuraContainer) then return false end
    buffs, frames, container = bf, bf.auraFrames, bf.AuraContainer
    watch = CreateFrame("Frame", nil, UIParent)
    watch:SetAllPoints(container)
    job = ns.Sched.OnFrame(watch, { name = "minimap.trackingBuff", every = 1, pre = Changed, fn = Pass, awake = false })
    return true
end

-- Sole writer of the watch: awake exactly while a tracking buff is kept off the bar.
local function SetWatch(on)
    if on then
        if not Init() then return end
        job:Wake()
        Pass()
    elseif job then
        RestoreAll()
        job:Sleep()
    end
end

-- From Minimap.lua's tracking update: the active tracking spell while the classic icon shows it, else nil.
function MM.TrackingBuff(info)
    local newSpell = info and ns.Safe(info.spellID) or nil
    if newSpell ~= spell then auraID = nil end
    spell, icon = newSpell, info and ns.Safe(info.texture) or nil
    if spell == nil and icon == nil then
        SetWatch(false)
        return
    end
    if auraID == nil then Resolve() end
    SetWatch(true)
end
