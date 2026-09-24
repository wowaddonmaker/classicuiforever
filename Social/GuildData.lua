local _, ns = ...

-- Guild roster data. ns.guild is the guild files' shared table: mutable state
-- (panel, active, selected key, sort, clientToggleGuild) lives on it, beside exports.

local G = { active = false, sort = { field = "name", reverse = false } }
ns.guild = G

local IsSecret, Safe = ns.IsSecret, ns.Safe

-- One entry per listed member; entry tables are reused across refreshes (a big guild refreshes often).
local roster = {}
G.roster = roster
local pool = {}

local function ShowOffline()
    if GetGuildRosterShowOffline then
        local ok, value = pcall(GetGuildRosterShowOffline)
        if ok then return value and true or false end
    end
    return false
end
G.ShowOffline = ShowOffline

function G.CollectRoster()
    local n = 0
    if not IsInGuild or not IsInGuild() then
        for i = #roster, 1, -1 do roster[i] = nil end
        return 0, 0
    end
    local total, online = 0, 0
    if GetNumGuildMembers then
        local ok, a, b = pcall(GetNumGuildMembers)
        if ok then total, online = Safe(a, 0), Safe(b, 0) end
    end
    local showOffline = ShowOffline()
    for i = 1, total do
        local ok, name, rank, rankIndex, level, class, zone, note, officerNote, isOnline, status, classFile, _, _, _, _, _, guid = pcall(GetGuildRosterInfo, i)
        if ok and name and not IsSecret(name) then
            isOnline = Safe(isOnline, false) and true or false
            if showOffline or isOnline then
                n = n + 1
                local entry = pool[n]
                if not entry then
                    entry = {}
                    pool[n] = entry
                end
                entry.index = i
                entry.name = Ambiguate and Ambiguate(name, "guild") or name
                entry.rank, entry.rankIndex = Safe(rank, ""), Safe(rankIndex, 0)
                entry.level, entry.class, entry.classFile = Safe(level, 0), Safe(class, ""), Safe(classFile, nil)
                entry.zone, entry.note, entry.officerNote = Safe(zone, ""), Safe(note, ""), Safe(officerNote, "")
                entry.online, entry.status, entry.guid = isOnline, Safe(status, 0), Safe(guid, nil)
                roster[n] = entry
            end
        end
    end
    for i = #roster, n + 1, -1 do roster[i] = nil end
    return total, online
end

-- Sorted here too, whatever order the client keeps. Keys are made once per entry, not per comparison.
local reverse = false
local function Before(a, b)
    local x, y = a.sortKey, b.sortKey
    if x == y then return a.sortName < b.sortName end
    if reverse then return x > y end
    return x < y
end

function G.SortRoster()
    local key = G.sort.field
    reverse = G.sort.reverse
    for i = 1, #roster do
        local e = roster[i]
        local x
        if key == "rank" then
            x = tonumber(e.rankIndex) or 0
        elseif key == "lastOnline" then
            x = e.online and 0 or 1
        elseif key == "level" then
            x = tonumber(e.level) or 0
        else
            x = tostring(e[key]):lower()
        end
        e.sortKey, e.sortName = x, tostring(e.name):lower()
    end
    table.sort(roster, Before)
end

-- A member's lasting key (G.selected holds one): roster indices shift as members come and go.
function G.EntryKey(entry)
    return entry.guid or entry.name
end

-- MOTD and title reads raise the blocked-action box in combat: serve the last read.
local lastMOTD, lastTitle = "", nil

function G.GuildMOTD()
    if InCombatLockdown() then return lastMOTD end
    if C_GuildInfo and C_GuildInfo.GetMOTD then
        local ok, text = pcall(C_GuildInfo.GetMOTD)
        if ok and type(text) == "string" then lastMOTD = text return text end
    end
    if GetGuildRosterMOTD then
        local ok, text = pcall(GetGuildRosterMOTD)
        if ok and type(text) == "string" then lastMOTD = text return text end
    end
    return lastMOTD
end

-- Window title while the roster is up: rank and guild, as 1.x wrote it.
function G.GuildTitle()
    if InCombatLockdown() then return lastTitle or GUILD or "Guild" end
    if not GetGuildInfo then return GUILD or "Guild" end
    local ok, guildName, rankName = pcall(GetGuildInfo, "player")
    if not ok or not guildName or IsSecret(guildName) then return lastTitle or GUILD or "Guild" end
    if rankName and not IsSecret(rankName) then
        lastTitle = format(GUILD_TITLE_TEMPLATE or "%s of %s", rankName, guildName)
    else
        lastTitle = guildName
    end
    return lastTitle
end

-- Last-seen text in 1.x wording.
function G.LastOnline(entry)
    if entry.online then return GUILD_ONLINE_LABEL or "Online" end
    if not GetGuildRosterLastOnline then return "" end
    local ok, years, months, days, hours = pcall(GetGuildRosterLastOnline, entry.index)
    if not ok then return "" end
    years, months, days, hours = Safe(years, 0), Safe(months, 0), Safe(days, 0), Safe(hours, 0)
    if years and years > 0 then return format(LASTONLINE_YEARS or "%d years", years) end
    if months and months > 0 then return format(LASTONLINE_MONTHS or "%d months", months) end
    if days and days > 0 then return format(LASTONLINE_DAYS or "%d days", days) end
    if hours and hours > 0 then return format(LASTONLINE_HOURS or "%d hours", hours) end
    return LASTONLINE_MINS or "moments ago"
end
