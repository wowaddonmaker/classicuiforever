-- Offline test under Lua 5.4 for the guild member card (Social/GuildMemberCard.lua): our copy of the client's member
-- window opens from a row click in a fight only, and is never on screen with the client's window: it does not open
-- while that one is in sight, yields the frame it comes into sight, and the note bridge hides it before docking it.
-- Run from the addon root: lua tools/tests/guild_member_card_test.lua (CI runs every tools/tests/*_test.lua).
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
-- Template pieces a frame may lack, read as fields.
local PIECES = { NineSlice = true, Center = true, Bg = true }
-- Methods only (capitalized names): a field never set reads nil, as on a real frame.
Frame.__index = function(_, key)
    if Frame[key] then return Frame[key] end
    if type(key) == "string" and key:match("^%u") and not PIECES[key] then return function() end end
end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:IsShown() return self.shown end
function Frame:IsVisible()
    local f = self
    while f do
        if not f.shown then return false end
        f = f.parent
    end
    return true
end
function Frame:GetEffectiveAlpha()
    local a, f = 1, self
    while f do
        a = a * f.alpha
        f = f.parent
    end
    return a
end
function Frame:SetShown(on) self.shown = on and true or false end
function Frame:SetScript(name, fn) self.scripts[name] = fn end
function Frame:SetText(text) self.text = text end
function Frame:SetFormattedText(fmt, ...) self.text = string.format(fmt, ...) end
function Frame:SetEnabled(on) self.enabled = on end
function Frame:GetHeight() return 12 end
function Frame:GetParent() return self.parent end
function Frame:GetEffectiveScale() return 1 end
local function New(name, parent)
    local f = setmetatable({ shown = true, alpha = 1, scripts = {}, name = name, parent = parent }, Frame)
    if name then _G[name] = f end
    return f
end
function Frame:CreateFontString() return New(nil, self) end

UIParent = New("UIParent")
local host = New("FriendsFrame", UIParent)
local panel = New(nil, host)
local ghost = New("CommunitiesFrame", UIParent)
ghost.alpha = 0
local detail = New(nil, ghost)
detail.shown = false
ghost.GuildMemberDetailFrame = detail

local fight = false
InCombatLockdown = function() return fight end
UnitGUID = function() return "me" end
PlaySound = function() end
SOUNDKIT = {}
StaticPopup_Show = function() end
StaticPopupDialogs = {}
CanEditPublicNote = function() return false end
CanGuildRemove = function() return true end
C_GuildInfo = { CanViewOfficerNote = function() return true end, CanEditOfficerNote = function() return false end }
TOOLTIP_DEFAULT_BACKGROUND_COLOR = { GetRGB = function() return 0, 0, 0 end }

local watch
local ns = setmetatable({}, { __index = function() return function() end end })
ns.Safe = function(v, d) if v == nil then return d end return v end
ns.NewFrame = function(_, name, parent) return New(name, parent) end
ns.EachRegion = function() return 0 end
ns.Sched = { Attach = function(_, spec) watch = spec.fn end }
ns.social = { Invite = function() end }
local function Entry(name, guid, rankIndex)
    return { name = name, guid = guid, rankIndex = rankIndex, level = 20, class = "Mage", zone = "Elwynn",
        rank = "Member", note = "", officerNote = "", online = true }
end
local G = {
    panel = panel,
    roster = { Entry("Me", "me", 1), Entry("Amy", "amy", 3), Entry("Bob", "bob", 3) },
    EntryKey = function(entry) return entry.guid or entry.name end,
    LastOnline = function() return "Online" end,
}
ns.guild = G

assert(loadfile(ROOT .. "/Social/GuildMemberCard.lua"))("ClassicUIForever", ns)

------------------------------------------------------------------ checks

local function CardUp()
    local card = ClassicUIForeverGuildMemberCard
    return card ~= nil and card:IsShown()
end

G.selected = "amy"
G.ShowMemberCard()
Check(not CardUp(), "out of a fight a click leaves the member window to the client")

fight = true
G.ShowMemberCard()
local card = ClassicUIForeverGuildMemberCard
Check(CardUp() and card.Name.text == "Amy", "in a fight a click opens our card for the picked member")
Check(card.GroupInviteButton.enabled and card.RemoveButton.enabled, "invite and remove follow the client's rules")
watch()
Check(CardUp(), "the client's window on its unseen guild window does not close our card")

-- The client's window docked beside the roster, as the note bridge does.
detail.parent, detail.shown = UIParent, true
watch()
Check(not CardUp(), "the client's window in sight closes our card the next frame")
G.ShowMemberCard()
Check(not CardUp(), "our card never opens while the client's window is in sight")

detail.parent, detail.shown = ghost, false
G.ShowMemberCard()
Check(CardUp(), "our card opens again once the client's window is gone")
G.HideMemberCard()
Check(not CardUp(), "the bridge's dock hides our card")

G.ShowMemberCard()
G.roster[2].zone = "Westfall"
G.FillMemberCard()
Check(CardUp() and card.ZoneText.text == "Westfall", "a roster update refreshes the card")
G.selected = "bob"
G.FillMemberCard()
Check(not CardUp(), "another member picked closes the card until its click opens it")

G.selected = "me"
G.ShowMemberCard()
Check(CardUp() and not card.GroupInviteButton.enabled and not card.RemoveButton.enabled, "no invite or remove on oneself")

fight = false
G.selected = "amy"
G.ShowMemberCard()
Check(not CardUp(), "after the fight a click hands the member window back to the client")

-- The bridge hides our card before the client's window takes the spot.
local bridge = io.open(ROOT .. "/Social/GuildNoteBridge.lua"):read("a")
local hideAt = bridge:find("G.HideMemberCard()", 1, true)
local dockAt = bridge:find("G.DockMemberWindow(detail", 1, true)
local parentAt = bridge:find("detail:SetParent(UIParent)", 1, true)
Check(hideAt and dockAt and parentAt and hideAt < parentAt and hideAt < dockAt,
    "the note bridge hides our card before it docks the client's window")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("guild_member_card_test: ok")
