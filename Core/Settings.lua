local _, ns = ...

-- Saved settings: defaults and all our cvar writes.

-- A saved table of ours, made (or replaced if anything else stands there) on first use.
function ns.DbTable(key)
    local list = ns.db[key]
    if type(list) ~= "table" then
        list = {}
        ns.db[key] = list
    end
    return list
end

function ns.CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = v
        end
    end
end

-- The game's floating damage option lives in its cvars; db.gameDamageNumbers mirrors them.
local DAMAGE_CVARS = { "floatingCombatTextCombatDamage", "floatingCombatTextCombatDamage_v2" }
function ns.ReadGameDamageNumbers()
    if not (ns.db and C_CVar and C_CVar.GetCVar) then return end
    local shown
    for _, name in ipairs(DAMAGE_CVARS) do
        local value = ns.GetCVar(name)
        if value ~= nil then shown = shown or value == "1" end
    end
    if shown ~= nil then ns.db.gameDamageNumbers = shown end
end

-- Raw write for the player's own value or a hand-back: never recorded in cvarWas, no combat refusal, no same-value skip.
function ns.WriteCVar(name, value)
    if not (C_CVar and C_CVar.SetCVar) then return false end
    return pcall(C_CVar.SetCVar, name, value)
end

-- Only ever turns a setting back on: a 0 goes to back (or the shipped default); any other value is the player's and stays.
function ns.TurnCVarBackOn(name, back)
    back = back or ns.GetCVarDefault(name)
    if back == nil or back == "0" or ns.GetCVar(name) ~= "0" then return false end
    return ns.WriteCVar(name, back)
end

-- Once per player, at logout: an early version zeroed the game's damage numbers for its own and never gave them back.
function ns.RepairDamageNumbers()
    if not ns.db or ns.db.damageNumbersRepaired then return end
    ns.db.damageNumbersRepaired = true
    local on = false
    for _, name in ipairs(DAMAGE_CVARS) do
        if ns.TurnCVarBackOn(name) then on = true end
    end
    if on then ns.db.gameDamageNumbers = true end
end

-- Not ns.SetCVar: the player's own choice, never handed back at turn-off.
function ns.WriteGameDamageNumbers()
    for _, name in ipairs(DAMAGE_CVARS) do
        ns.WriteCVar(name, ns.db.gameDamageNumbers and "1" or "0")
    end
end

-- Guarded cvars (the nameplate family) block any addon write in combat, same-value included.
function ns.SetCVar(name, value)
    if not name or value == nil then return false end
    if InCombatLockdown() then return false end
    if not (C_CVar and C_CVar.SetCVar and C_CVar.GetCVar) then return false end
    local ok, current = pcall(C_CVar.GetCVar, name)
    if ok and current ~= nil and tostring(current) == tostring(value) then return true end
    -- Keep the pre-change value to hand back at turn-off.
    if ok and current ~= nil and ns.db and not ns.handingBack then
        ns.DbTable("cvarWas")
        if ns.db.cvarWas[name] == nil then ns.db.cvarWas[name] = tostring(current) end
    end
    local wrote = pcall(C_CVar.SetCVar, name, value)
    return wrote
end
