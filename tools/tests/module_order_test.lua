-- Every module registered in a .toc file is listed in ns.MODULE_ORDER (an unlisted one runs last, out of its place).
-- Run from the addon root: lua tools/tests/module_order_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 121

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local ns = {}
GetLocale = GetLocale or function() return "enUS" end
assert(loadfile(ROOT .. "/Core/Localization.lua"))("ClassicUIForever", ns)
assert(loadfile(ROOT .. "/Locales/enUS.lua"))("ClassicUIForever", ns)
assert(loadfile(ROOT .. "/Core/Defaults.lua"))("ClassicUIForever", ns)

local listed = {}
for _, id in ipairs(ns.MODULE_ORDER) do listed[id] = true end

local toc = assert(io.open(ROOT .. "/ClassicUIForever.toc"))
local missing, registered = {}, 0
for line in toc:lines() do
    local path = line:match("^([%w_/\\]+%.lua)%s*$")
    if path then
        local f = assert(io.open(ROOT .. "/" .. path:gsub("\\", "/")))
        local text = f:read("a")
        f:close()
        for key in text:gmatch("ns%.RegisterModule%(%s*[\"']([%w_]+)[\"']") do
            registered = registered + 1
            if not listed[key] then missing[#missing + 1] = key .. " (" .. path .. ")" end
        end
    end
end
toc:close()

if #missing > 0 then
    print("FAIL: modules not in ns.MODULE_ORDER (Core/Defaults.lua): " .. table.concat(missing, ", "))
    os.exit(1)
end
print(string.format("module order: %d registered, all listed", registered))
