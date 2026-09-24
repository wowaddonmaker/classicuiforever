local _, ns = ...

-- Guild roster data. ns.guild is the guild files' shared table: mutable state
-- (panel, active, selected, sort, clientToggleGuild) lives on it, beside exports.

local G = { active = false, sort = { field = "name", reverse = false } }
ns.guild = G

local IsSecret, Safe = ns.IsSecret, ns.Safe

-- One entry per listed member.
local roster = {}
G.roster = roster

local function ShowOffline()
    if GetGuildRosterShowOffline then
        local ok, value = pcall(GetGuildRosterShowOffline)
        if ok then return value and true or false end
    end
    return false
end
G.ShowOffline = ShowOffline

function G.CollectRoster()
    wipe(roster)
    if not IsInGuild or not IsInGuild() then return 0, 0 end
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
                roster[#roster + 1] = {
                    index = i,
                    name = Ambiguate and Ambiguate(name, "guild") or name,
                    rank = Safe(rank, ""),
                    rankIndex = Safe(rankIndex, 0),
                    level = Safe(level, 0),
                    class = Safe(class, ""),
                    classFile = Safe(classFile, nil),
                    zone = Safe(zone, ""),
                    note = Safe(note, ""),
                    officerNote = Safe(officerNote, ""),
                    online = isOnline,
                    status = Safe(status, 0),
                    guid = Safe(guid, nil),
                }
            end
        end
    end
    return total, online
end

-- Sorted here too, whatever order the client keeps.
function G.SortRoster()
    local key, reverse = G.sort.field, G.sort.reverse
    table.sort(roster, function(a, b)
        local x, y = a[key], b[key]
        if key == "rank" then
            x, y = tonumber(a.rankIndex) or 0, tonumber(b.rankIndex) or 0
        elseif key == "lastOnline" then
            x, y = a.online and 0 or 1, b.online and 0 or 1
        elseif key == "level" then
            x, y = tonumber(x) or 0, tonumber(y) or 0
        else
            x, y = tostring(x):lower(), tostring(y):lower()
        end
        if x == y then return tostring(a.name):lower() < tostring(b.name):lower() end
        if reverse then return x > y end
        return x < y
    end)
end

-- By client roster index, not by name.
function G.SelectedEntry()
    local selected = G.selected
    for _, entry in ipairs(roster) do
        if entry.index == selected then return entry end
    end
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
