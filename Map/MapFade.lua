local _, ns = ...

-- The toggle is the client's mapFade cvar; a change made elsewhere updates our setting.

local CVAR = "mapFade"
local active = false   -- toggle state, for the cvar watcher
local setting = false  -- our own write's CVAR_UPDATE is pending
local driver

local function EndSetting() setting = false end

-- Every ApplyAll. CVAR_UPDATE fires inside ns.SetCVar, which skips same-value writes: the echo guard is for real writes.
local function Write(value)
    local current = ns.GetCVar(CVAR)
    local writes = ns.IsSecret(current) or current == nil or tostring(current) ~= value
    if writes then setting = true end
    ns.SetCVar(CVAR, value)
    if writes then ns.Sched.NextFrame("mapFade.endSetting", EndSetting) end
end

local function Watch()
    if driver then return end
    driver = CreateFrame("Frame")
    driver:RegisterEvent("CVAR_UPDATE")
    driver:SetScript("OnEvent", function(_, _, name, value)
        if setting or name ~= CVAR then return end
        local on = value ~= "0" and value ~= 0 and value ~= false
        if ns.db.mapFade ~= on or active ~= on then
            ns.db.mapFade = on
            active = on
            if ns.RefreshOptionsWindow then ns.RefreshOptionsWindow() end
        end
    end)
end

local function Apply()
    active = true
    Watch()
    Write("1")
end

local function Restore()
    active = false
    Watch()
    Write("0")
end

ns.RegisterModule("mapFade", { apply = Apply, restore = Restore })
