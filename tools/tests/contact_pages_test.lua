-- Offline test under Lua 5.4 for the friends page's sub-tabs (Social/ContactPages.lua): Friends, Recent Allies and Ignore
-- over the client's header tabs, our own lists for the last two. A page shows only on the friends page with no list
-- of ours over it; the client's list and foot buttons step aside under it; recent allies list online first.
-- Run from the addon root: lua tools/tests/contact_pages_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

------------------------------------------------------------------ the stub client and addon

local Frame = {}
-- Methods only (capitalized names): a field never set reads nil, as on a real frame.
Frame.__index = function(_, key)
    if Frame[key] then return Frame[key] end
    if type(key) == "string" and key:match("^%u") then return function() end end
end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:IsShown() return self.shown end
function Frame:SetAlpha(a) self.alpha = a end
function Frame:GetAlpha() return self.alpha end
function Frame:SetScript(name, fn) self.scripts[name] = fn end
function Frame:GetFrameLevel() return 1 end
function Frame:SetEnabled(on) self.enabled = on end
function Frame:SetText(text) self.text = text end
local function New(name)
    local f = setmetatable({ shown = true, alpha = 1, scripts = {}, name = name }, Frame)
    if name then _G[name] = f end
    return f
end
function Frame:CreateFontString() return New() end

FriendsFrame = New("FriendsFrame")
FriendsFrameInset = New("FriendsFrameInset")
FriendsTabHeader = New("FriendsTabHeader")
FriendsTabHeader.TabSystem = New()
local clientList, clientAdd, clientSend = New("FriendsListFrame"), New("FriendsFrameAddFriendButton"), New("FriendsFrameSendMessageButton")
PanelTemplates_SelectTab = function(tab) tab.picked = true end
PanelTemplates_DeselectTab = function(tab) tab.picked = false end
StaticPopup_Show = function() end
GameTooltip_Hide = function() end
PlaySound = function() end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
SOUNDKIT = {}
local covered, raid = false, false

local recent = {}
local requested = 0
C_RecentAllies = { GetRecentAllies = function() return recent end,
    TryRequestRecentAlliesData = function() requested = requested + 1 end }
C_CreatureInfo = { GetClassInfo = function(id) return { className = "Class" .. id, classFile = "CLASS" .. id } end }
C_FriendList = { GetNumIgnores = function() return 2 end, GetIgnoreName = function(i) return ({ "Bob", "Ann" })[i] end }

local ns = setmetatable({}, { __index = function() return function() end end })
ns.IsSecret = function() return false end
ns.Safe = function(v, d) if v == nil then return d end return v end
ns.SetAlphaIf = function(f, a) f:SetAlpha(a) end
ns.SetShownIf = function(f, on) if on then f:Show() else f:Hide() end end
ns.WhenCalm = function(_, fn) fn() end
ns.EachChild = function() end
ns.ListOffset = function() return 0 end
ns.NewFrame = function(_, name) return New(name) end
ns.PanelButton = function() return New() end
ns.RegisterEvents = function() end
ns.StoneBar = function() return New() end
format = string.format
WHO_NUM_RESULTS = "%d found"
ns.guild = { active = true }
local switch = true
ns.SocialUIOn = function() return switch end
local S = {
    whoTab = New(),
    OverlayUp = function() return covered end,
    OnRaidPage = function() return raid end,
    HeaderRow = function() return New() end,
    ListBox = function() return New() end,
    RowCount = function() return 30 end,
    HideRow = function(row) row.entry = nil end,
    Span = function() end,
    SearchLine = function(page)
        local box = New()
        box.text = ""
        function box:GetText() return self.text end
        page.query = box
        return box
    end,
    ShowRow = function(row, entry) row.entry = entry end,
}
-- As the real one: its scroll frame is page.list.
S.ScrollRows = function(page)
    page.list = New()
    page.bar = New()
    page.rows = {}
    for i = 1, 3 do
        local row = New()
        row.Name, row.Selected = New(), New()
        page.rows[i] = row
    end
end
ns.social = S

assert(loadfile(ROOT .. "/Social/ContactPages.lua"))("ClassicUIForever", ns)

------------------------------------------------------------------ checks

S.SyncContactPages()
local friends, allies, ignore = ClassicUIForeverContactTab1, ClassicUIForeverContactTab2, ClassicUIForeverContactTab3
Check(friends and allies and ignore, "three sub-tabs are made")
Check(FriendsTabHeader.TabSystem.alpha == 0, "the client's header tabs step aside")
Check(friends.picked and not allies.picked, "the window opens on Friends")
Check(not ClassicUIForeverAlliesPage.shown and not ClassicUIForeverIgnorePage.shown, "on Friends no page of ours shows")
Check(clientList.alpha == 1, "on Friends the client's list shows")

recent[1] = { characterData = { fullName = "Zed", level = 10, classID = 1 }, stateData = { isOnline = false } }
recent[2] = { characterData = { fullName = "Amy", level = 12, classID = 2 }, stateData = { isOnline = false } }
recent[3] = { characterData = { fullName = "Max", level = 11, classID = 3 }, stateData = { isOnline = true, currentLocation = "Goldshire" },
    interactionData = { interactions = { { description = "Grouped in Deadmines" } } } }
allies.scripts.OnClick(allies)
local page = ClassicUIForeverAlliesPage
Check(page.shown and allies.picked and not friends.picked, "Recent Allies shows our list")
Check(clientList.alpha == 0 and clientAdd.alpha == 0 and clientSend.alpha == 0, "the client's list and buttons step aside")
page.scripts.OnShow(page)
Check(requested == 0, "the data request stays the game's: it is forbidden to addons")
Check(page.rows[1].entry and page.rows[1].entry.name == "Max", "online allies first")
Check(page.rows[2].entry and page.rows[2].entry.name == "Amy", "then by name")
Check(page.rows[1].entry and page.rows[1].entry.zone == "Goldshire" and page.rows[1].entry.class == "Class3", "zone and class read")
Check(page.rows[1].entry and page.rows[1].entry.met == "Grouped in Deadmines", "the last meeting kept for the tooltip")
Check(page.found.text == "3 found", "the count under the list")
page.query.text = "gold"
page.scripts.OnShow(page)
Check(page.rows[1].entry and page.rows[1].entry.name == "Max" and page.rows[2].entry == nil, "the search line keeps matching allies")
page.query.text = ""
page.scripts.OnShow(page)

ignore.scripts.OnClick(ignore)
local ign = ClassicUIForeverIgnorePage
Check(ign.shown and not page.shown, "Ignore shows its list alone")
ign.scripts.OnShow(ign)
Check(ign.rows[1].entry and ign.rows[1].entry.name == "Bob", "ignored names listed")
Check(ign.insetFoot ~= nil and ign.insetFoot == ign.right and page.insetFoot == page.left,
    "both pages end their inset border at their buttons, as on Friends")

covered = true
S.SyncContactPages()
Check(not ign.shown and not ignore.shown, "under the who or guild list the sub-tabs and pages step aside")
covered, raid = false, true
S.SyncContactPages()
Check(not ign.shown and not friends.shown, "on the raid page too")
raid = false
S.SyncContactPages()
Check(ign.shown and ignore.picked, "back on the friends page the picked page returns")

FriendsFrame.shown = false
S.SyncContactPages()
FriendsFrame.shown = true
S.SyncContactPages()
Check(friends.picked and not ign.shown and clientList.alpha == 1, "a shut window opens on Friends again")

switch = false
S.SyncContactPages()
Check(not friends.shown and FriendsTabHeader.TabSystem.alpha == 1, "with the switch off the client's header tabs are back")
switch = true
S.SyncContactPages()
ns.guild.active, S.whoTab.shown = false, false
S.SyncContactPages()
Check(not friends.shown and FriendsTabHeader.TabSystem.alpha == 1, "with our window off the client's tabs come back")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("contact_pages_test: ok")
