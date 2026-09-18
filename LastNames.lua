local _, ns = ...

-- The Forever client gives characters a last name and draws it under
-- the first. The toggle turns off every surname setting the client
-- carries, and stays in step with the game's own box for it: turning
-- that box back on turns the toggle off, and the other way about.

local CANDIDATES = { "UnitSurnameOwn", "UnitSurname", "UnitSurnameOther", "ShowSurnames", "showSurnames" }
local active = false
local setting = false
local driver

local function Known()
    local found = {}
    if not (C_CVar and C_CVar.GetCVar) then return found end
    for _, name in ipairs(CANDIDATES) do
        local ok, value = pcall(C_CVar.GetCVar, name)
        if ok and value ~= nil then found[#found + 1] = name end
    end
    return found
end

local function Apply()
    active = true
    if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return end
    ns.db.savedSurnames = ns.db.savedSurnames or {}
    setting = true
    for _, name in ipairs(Known()) do
        local ok, value = pcall(C_CVar.GetCVar, name)
        if ok and value ~= nil and value ~= "0" then
            if ns.db.savedSurnames[name] == nil then ns.db.savedSurnames[name] = value end
            pcall(C_CVar.SetCVar, name, "0")
        end
    end
    C_Timer.After(0, function() setting = false end)
    if not driver then
        driver = CreateFrame("Frame")
        driver:RegisterEvent("CVAR_UPDATE")
        driver:SetScript("OnEvent", function(_, _, name, value)
            if not active or setting or not name then return end
            for _, known in ipairs(CANDIDATES) do
                if name == known and value ~= "0" and value ~= 0 and value ~= false then
                    -- The player put surnames back from the game's own
                    -- settings: the toggle follows them.
                    ns.db.hideLastNames = false
                    ns.db.savedSurnames = nil
                    active = false
                    if ns.RefreshOptionsWindow then ns.RefreshOptionsWindow() end
                    return
                end
            end
        end)
    end
end

local function Restore()
    active = false
    local saved = ns.db.savedSurnames
    ns.db.savedSurnames = nil
    if not saved or not (C_CVar and C_CVar.SetCVar) then return end
    setting = true
    for name, value in pairs(saved) do pcall(C_CVar.SetCVar, name, value) end
    C_Timer.After(0, function() setting = false end)
end

ns.RegisterModule("hideLastNames", { apply = Apply, restore = Restore })
