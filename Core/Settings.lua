local _, ns = ...

-- Saved settings: defaults, the cvar mirror, and all our cvar writes.

function ns.CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = v
        end
    end
end

-- Forever writes saved variables at logout but never loads them; cvars persist. Non-default
-- scalars are mirrored into one cvar and read back over the table at load. Retail uses the file.
local MIRROR_CVAR = "ClassicUIForeverSettings"
local function MirrorReady()
    return ns.OnForever() and C_CVar and C_CVar.RegisterCVar and C_CVar.SetCVar and C_CVar.GetCVar
end

-- Always written: logout is the last chance to restore toggles reset mid-session.
-- Unknown whether a same-value write fires CVAR_UPDATE (which re-lays every nameplate).
function ns.MirrorSave()
    if not ns.db or not MirrorReady() then return end
    local pos = ns.db.microPos
    if type(pos) == "table" and pos.point then
        ns.db.microPosText = string.format("%s,%s,%.1f,%.1f", pos.point, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        ns.db.microPosText = ""
    end
    local parts = {}
    -- Walk the defaults, not db: a probe may hide db's keys behind a metatable.
    for k in pairs(ns.DB_DEFAULTS) do
        local v = ns.db[k]
        local t = type(v)
        if (t == "boolean" or t == "number" or t == "string") and ns.DB_DEFAULTS[k] ~= v and not tostring(v):find("[;=]") then
            parts[#parts + 1] = k .. "=" .. (t == "boolean" and (v and "b1" or "b0") or t == "number" and ("n" .. v) or ("s" .. v))
        end
    end
    table.sort(parts)
    pcall(C_CVar.SetCVar, MIRROR_CVAR, table.concat(parts, ";"))
end

function ns.MirrorLoad()
    if not ns.db or not MirrorReady() then return end
    -- Read before RegisterCVar, which resets last session's value.
    local ok, text = pcall(C_CVar.GetCVar, MIRROR_CVAR)
    if not ok or text == nil then
        pcall(C_CVar.RegisterCVar, MIRROR_CVAR, "")
        ok, text = pcall(C_CVar.GetCVar, MIRROR_CVAR)
    end
    ns.mirrorLoaded = ok and text or nil
    if not ok or not text or text == "" then return end
    for pair in text:gmatch("[^;]+") do
        local k, kind, raw = pair:match("^([%w_]+)=([bns])(.*)$")
        if k then
            if kind == "b" then ns.db[k] = raw == "1"
            elseif kind == "n" then ns.db[k] = tonumber(raw)
            else ns.db[k] = raw end
        end
    end
    if ns.db.microPos == nil and type(ns.db.microPosText) == "string" and ns.db.microPosText ~= "" then
        local point, relPoint, x, y = ns.db.microPosText:match("^(%a+),(%a+),([%-%d%.]+),([%-%d%.]+)$")
        if point then ns.db.microPos = { point = point, relPoint = relPoint, x = tonumber(x) or 0, y = tonumber(y) or 0 } end
    end
end

-- The game's floating damage option lives in its cvars; db.gameDamageNumbers mirrors them.
local DAMAGE_CVARS = { "floatingCombatTextCombatDamage", "floatingCombatTextCombatDamage_v2" }
function ns.ReadGameDamageNumbers()
    if not (ns.db and C_CVar and C_CVar.GetCVar) then return end
    local shown
    for _, name in ipairs(DAMAGE_CVARS) do
        local ok, value = pcall(C_CVar.GetCVar, name)
        if ok and value ~= nil then shown = shown or value == "1" end
    end
    if shown ~= nil then ns.db.gameDamageNumbers = shown end
end

-- Not ns.SetCVar: the player's own choice, never handed back at turn-off.
function ns.WriteGameDamageNumbers()
    for _, name in ipairs(DAMAGE_CVARS) do
        if C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar, name, ns.db.gameDamageNumbers and "1" or "0") end
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
        ns.db.cvarWas = ns.db.cvarWas or {}
        if ns.db.cvarWas[name] == nil then ns.db.cvarWas[name] = tostring(current) end
    end
    local wrote = pcall(C_CVar.SetCVar, name, value)
    return wrote
end
