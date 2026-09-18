local _, ns = ...

-- The map dims itself while the player moves, through the client's own
-- mapFade setting. The toggle is that setting: on it fades, off it does
-- not, and a change made elsewhere is taken as the player's word.

local CVAR = "mapFade"
local active = false   -- the toggle's own state, kept for the cvar watcher
local setting = false
local driver

local function Write(value)
    if not (C_CVar and C_CVar.SetCVar) then return end
    setting = true
    ns.SetCVar(CVAR, value)
    C_Timer.After(0, function() setting = false end)
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
