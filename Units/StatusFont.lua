local _, ns = ...

-- Health and power numbers in Classic Era's font: its TextStatusBarText is NumberFontNormal (Arial Narrow 14, outlined),
-- Forever's a small Friz outline. Every bar text inherits the style, so setting it once reaches them all.

local saved   -- the game's own font for the style, put back when the option goes off

-- Pet and party bars are 7 to 10 tall: their numbers take the style's face at 10 at most, or the rows crossed the frame.
local SMALL_MAX = 10
local small = CreateFont("ForeverClassicUISmallBarText")
local function SyncSmall()
    local style = _G.TextStatusBarText
    local file, size, flags
    if style then file, size, flags = style:GetFont() end
    if file then small:SetFont(file, math.min(size or SMALL_MAX, SMALL_MAX), flags) end
end
SyncSmall()

local function Apply()
    local style, classic = _G.TextStatusBarText, _G.NumberFontNormal
    if not (style and classic) then return end
    if not saved then saved = { style:GetFont() } end
    local file, size, flags = classic:GetFont()
    if file then style:SetFont(file, size, flags) end
    SyncSmall()
end

local function Restore()
    local style = _G.TextStatusBarText
    if style and saved and saved[1] then style:SetFont(saved[1], saved[2], saved[3]) end
    SyncSmall()
end

ns.RegisterModule("classicStatusFont", { apply = Apply, restore = Restore })

-- plainNumbers mirrors the game's breakUpLargeNumbers CVar (ns.ToggleChanged writes it).
local function ReadPlainNumbers()
    if not ns.db then return end
    local value = ns.GetCVar("breakUpLargeNumbers")
    if value ~= nil then ns.db.plainNumbers = tostring(value) == "0" end
end
ns.RegisterModule("plainNumbers", { apply = ReadPlainNumbers, restore = ReadPlainNumbers })
