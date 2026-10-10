local _, ns = ...

-- The group finder dressed as the social window: cut to its size, in its
-- place, with classic controls and the Who tab's side tabs. Widget calls only
-- (size, points, alpha, art); the pages stay the client's.

local S = ns.social
local Plain = ns.Safe

local ADDON_NAME = "Blizzard_GroupFinder_VanillaStyle"
-- The client's who side tab put away; its page tabs lie unseen over ours (FinderTabs.lua).
local CLIENT_TABS = { "WhoListingTab" }
local PAGES = { "LFGBrowseFrame", "LFGListingFrame" }
local QUIET = { changed = true, mouseOff = true }
local BAR_TEXTURES = { "SelectedTexture", "HighlightTexture" }
local active = false
local dressed = false

-- Era's window, laid from its dump (frame units, top left): drawn size, sheets, and every piece's spot.
local ERA_W, ERA_H = 354, 440
-- Era's frame spot against the client's: Era stands this old-art window at 0, -104, the client at 16, -116.
local ERA_ORIGIN_X, ERA_ORIGIN_Y = -16, 12
local origin

-- Every Era number in this file counts from here.
local function Origin()
    if not origin then
        local parent = _G["LFGParentFrame"]
        origin = ns.NewFrame("Frame", nil, parent)
        origin:SetSize(ERA_W, ERA_H)
        origin:SetPoint("TOPLEFT", parent, "TOPLEFT", ERA_ORIGIN_X, ERA_ORIGIN_Y)
        -- The art's own strip left of the client's frame takes clicks too, not the world under it.
        origin:EnableMouse(true)
    end
    return origin
end
local LIST_X, LIST_Y, LIST_W, LIST_H = 22, 128, 324, 282
-- Era's comment box under a category's activities.
local ACTIVITY_COMMENT_WIDTH = 285
-- Group Browser list and dropdowns (frame units from the page's top left; the old column hangs 12.5 past the bar's right).
local GROUP_LIST_SCROLL_BAR_RIGHT = 333.5
local GROUP_LIST_SCROLL_BAR_TOP = 135
local GROUP_LIST_SCROLL_BAR_BOTTOM = 403
local GROUP_LIST_ROWS_RIGHT = 311
-- The empty list's "No groups found" text: down from the list's top, and its width (Era: 40, 240).
local GROUP_LIST_EMPTY_TEXT_Y = 40
local GROUP_LIST_EMPTY_TEXT_WIDTH = 240
-- A player row's "Roles:" label and a group row's member icons, from the row's right (its role icons follow the label).
local GROUP_ROW_ROLES_LABEL_RIGHT = -52
local GROUP_ROW_PARTY_ICONS_RIGHT = -16
-- What hangs off a row's name, the gap it keeps from the roles, and the least a name is cut to.
local NAME_TAIL = { "Name", "Level", "ClassIcon", "NewPlayerFriendlyIcon" }
local NAME_ROLES_GAP = 6
local NAME_MIN_WIDTH = 40
local CATEGORY_DROPDOWN_ARROW_X = -1
local CATEGORY_DROPDOWN_ARROW_Y = -1
local CATEGORY_DROPDOWN_LABEL_RIGHT = -24
local ACTIVITY_DROPDOWN_ARROW_X = -1
local ACTIVITY_DROPDOWN_ARROW_Y = -1
local ACTIVITY_DROPDOWN_LABEL_RIGHT = -24
local FOOT_Y, FOOT_H, FOOT_LEFT, FOOT_RIGHT = 411, 22, { 19, 111 }, { 235, 109 }
-- Create Listing is one sheet; the browser swaps the top for its own, rows 0 to 121.
local LISTING_SHEETS = { { key = "eraLfgFrame", tc = { 0, 1, 0, 1 }, x = 0, y = 0, w = 512, h = 512 } }
local BROWSE_SHEETS = {
    { key = "eraLfgBrowseTop", tc = { 0, 1, 0, 0.236 }, x = -1, y = 0, w = 512, h = 121 },
    { key = "eraLfgFrame", tc = { 0, 1, 0.236, 0.5 }, x = 0, y = -121, w = 512, h = 135 },
    { key = "eraLfgFrame", tc = { 0, 1, 0.5, 1 }, x = 0, y = -256, w = 512, h = 256 },
}
-- Era's classic dropdown on its sheet: the text holder round the button, the gold arrow at its right.
local HOLDER_COORDS = { 0.38672, 0.81641, 0.00391, 0.16406 }
local ARROW_COORDS = { 0.80078, 0.89063, 0.17188, 0.25781 }
-- Role buttons: Era's 48 at a 73 step, 60 down; this client's are 64 (the new player box 84).
local ROLE_SCALE, ROLE_STEP, ROLE_X, ROLE_Y = 48 / 64, 73, 67, 60
-- The new player flag drawn as big as a role (its 84 art to the roles' 85 drawn), centred one role step on.
local FRIENDLY_SCALE = ROLE_SCALE * 85 / 84
-- Era's portrait files, the same in this client's data: the eye sheet (8 x 4 frames) and its black backing.
local ERA_EYE, ERA_EYE_BACK = 136317, 337500
-- Where Era draws them in the window (its dump): eye 9, 5 and backing 12, 5, both 64 square.
local ERA_EYE_X, ERA_EYE_Y, ERA_EYE_BACK_X, ERA_EYE_BACK_Y = 9, 5, 12, 5
local eyeHost
local FRIENDLY_CX, ROLE_CY = ROLE_X + 24 + 3 * ROLE_STEP, ROLE_Y + 24

local function Size() return ERA_W, ERA_H end

local function Hide(region)
    if region and region.SetAlpha then region:SetAlpha(0) end
end

local function HideAll(frame)
    if frame then ns.EachRegion(frame, Hide) end
end

-- Only writes what moved: the layout is laid again on every pass (the client re-lays its lists).
local function PointIf(region, point, rel, relPoint, x, y)
    if region and not ns.IsAt(region, point, rel, relPoint, x, y) then ns.SetPointOnce(region, point, rel, relPoint, x, y) end
end

local function At(region, x, y, w, h)
    if not region then return end
    PointIf(region, "TOPLEFT", Origin(), "TOPLEFT", x, -y)
    if w then ns.SetSizeIf(region, w, h or region:GetHeight()) end
end

-- This client's chrome off, Era's sheets and list art on (once).
local function EraArtOnce(page, sheets)
    HideAll(page.NineSlice)
    HideAll(page.Inset)
    HideAll(page.RolesSection)
    Hide(page.DividerFrame)
    Hide(page.BackgroundArt)
    Hide(page.TopTileStreaks)
    Hide(page.Bg or (page:GetName() and _G[page:GetName() .. "Bg"]))
    for i, s in ipairs(sheets) do
        local tex = ns.OwnTexture(page, "eraSheet" .. i, "BACKGROUND", -1)
        ns.SetTex(tex, s.key)
        tex:SetTexCoord(unpack(s.tc))
        tex:SetSize(s.w, s.h)
        ns.SetPointOnce(tex, "TOPLEFT", Origin(), "TOPLEFT", s.x, s.y)
    end
    ns.OwnTexture(page, "eraArt", "BACKGROUND", 0):SetAtlas("groupfinder-background-classic")
end

-- This client's page art the sheets replace; the client redraws its border on every re-lay, so faded each pass.
local CLIENT_ART = { ["groupfinder-ScrollLine"] = true, ["groupfinder-Stat-StoneBG"] = true, ["_UI-Frame-TopTileStreaks"] = true }
local CLIENT_ROCK = 374155

local function ClientArtOff(region)
    if not (region.IsObjectType and region:IsObjectType("Texture")) then return end
    local atlas = region:GetAtlas()
    if (not ns.IsSecret(atlas) and atlas and CLIENT_ART[atlas]) or ns.Safe(region:GetTextureFileID()) == CLIENT_ROCK then
        ns.SetAlphaIf(region, 0)
    end
end

local function EraChrome(page, sheets, first)
    if first then EraArtOnce(page, sheets) end
    ns.SetAlphaIf(page.NineSlice, 0)
    ns.EachRegion(page, ClientArtOff)
    At(ns.OwnTexture(page, "eraArt", "BACKGROUND", 0), LIST_X, LIST_Y + 1, LIST_W, LIST_H)
    local title = page.TitleContainer
    if title then
        ns.SetTwoPointsIf(title, "TOPLEFT", Origin(), "TOPLEFT", 74, -14, "TOPRIGHT", Origin(), "TOPLEFT", 310, -14)
    end
    At(page.OptionsButton, 328, 44)
end

local function Red(button, width)
    if not button then return end
    ns.SkinRedButton(button)
    if width then button:SetSize(width, FOOT_H) end
end

-- Two red buttons in the sheet's left and right foot slots.
local function FootPair(left, right, first)
    if first then
        Red(left)
        Red(right)
    end
    At(left, FOOT_LEFT[1], FOOT_Y, FOOT_LEFT[2], FOOT_H)
    At(right, FOOT_RIGHT[1], FOOT_Y, FOOT_RIGHT[2], FOOT_H)
end

local function EraDropdown(dropdown, x, y, width, first, arrowX, arrowY, labelRight)
    if not dropdown then return end
    At(dropdown, x, y, width, 24)
    local holder = ns.OwnTexture(dropdown, "eraHolder", "BACKGROUND", 1)
    local arrow = ns.OwnTexture(dropdown, "eraArrow", "OVERLAY", 1)
    if first then
        Hide(dropdown.Background)
        Hide(dropdown.Arrow)
        ns.SetTex(holder, "dropdownClassic")
        holder:SetTexCoord(unpack(HOLDER_COORDS))
        ns.SetTex(arrow, "dropdownClassic")
        arrow:SetTexCoord(unpack(ARROW_COORDS))
        arrow:SetSize(23, 22)
    end
    ns.SetTwoPointsIf(holder, "TOPLEFT", dropdown, "TOPLEFT", -9, 8, "BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", 8, -9)
    PointIf(arrow, "TOPRIGHT", dropdown, "TOPRIGHT", arrowX, arrowY)
    -- Era's label: right-aligned against the arrow, 9 in from the left.
    local text = dropdown.Text
    if text then
        text:SetJustifyH("RIGHT")
        ns.SetTwoPointsIf(text, "LEFT", dropdown, "LEFT", 9, 0, "RIGHT", dropdown, "RIGHT", labelRight, 0)
    end
end

local function PlaceList(page)
    local box, bar = page.ScrollBox, page.ScrollBar
    if box then
        ns.SetTwoPointsIf(box, "TOPLEFT", Origin(), "TOPLEFT", LIST_X, -LIST_Y,
            "BOTTOMRIGHT", Origin(), "TOPLEFT", GROUP_LIST_ROWS_RIGHT, -(LIST_Y + LIST_H))
    end
    -- The old column (31 wide: 10.5 left of the 8 wide bar, 12.5 right, 7 over it) flush with the list box, as Era's Who.
    if bar then
        ns.SetTwoPointsIf(bar, "TOPRIGHT", Origin(), "TOPLEFT", GROUP_LIST_SCROLL_BAR_RIGHT, -GROUP_LIST_SCROLL_BAR_TOP,
            "BOTTOMRIGHT", Origin(), "TOPLEFT", GROUP_LIST_SCROLL_BAR_RIGHT, -GROUP_LIST_SCROLL_BAR_BOTTOM)
    end
end

local function DressBrowse(page, first)
    EraChrome(page, BROWSE_SHEETS, first)
    EraDropdown(page.CategoryDropdown, 26, 94, 118, first, CATEGORY_DROPDOWN_ARROW_X, CATEGORY_DROPDOWN_ARROW_Y,
        CATEGORY_DROPDOWN_LABEL_RIGHT)
    EraDropdown(page.ActivityDropdown, 149, 94, 167, first, ACTIVITY_DROPDOWN_ARROW_X, ACTIVITY_DROPDOWN_ARROW_Y,
        ACTIVITY_DROPDOWN_LABEL_RIGHT)
    At(page.RefreshButton, 315, 90, 32, 32)
    PlaceList(page)
    local empty = page.NoResultsFound
    if empty then
        PointIf(empty, "TOP", Origin(), "TOPLEFT", LIST_X + LIST_W / 2, -(LIST_Y + GROUP_LIST_EMPTY_TEXT_Y))
        if math.abs(empty:GetWidth() - GROUP_LIST_EMPTY_TEXT_WIDTH) > 0.5 then empty:SetWidth(GROUP_LIST_EMPTY_TEXT_WIDTH) end
    end
    FootPair(page.SendMessageButton, page.GroupInviteButton, first)
    if first then ns.SkinScrollBarsUnder(page, 2) end
end

-- The listing page's own fonts (headers, activities, their level ranges) at the comment box's small size.
local ACTIVITY_FONTS = { "LFGActivityHeader", "LFGActivityEntry", "LFGActivityEntryTrivial", "LFGActivityEntryDifficult" }
local function SmallActivityFonts()
    local _, size = GameFontHighlightSmall:GetFont()
    for _, name in ipairs(ACTIVITY_FONTS) do
        local font = _G[name]
        if font then
            local file, _, flags = font:GetFont()
            font:SetFont(file, size, flags)
        end
    end
end

-- The playstyle choice at the list's left; Show All Level Ranges at its right (the box hangs 28 past the frame); the
-- choice takes the room between, its holder art 8 past each side.
local STYLE_X, STYLE_Y, STYLE_GAP, RANGES_RIGHT = 10, -10, 14, -30
local function PlaceStyleRow(activity, first)
    local style, ranges = activity.PlayStyleDropdown, activity.LevelRangesCheckbox
    if ranges then PointIf(ranges, "TOPRIGHT", activity, "TOPRIGHT", RANGES_RIGHT, STYLE_Y) end
    if not style then return end
    if first and style.Text then style.Text:SetFontObject("GameFontHighlightSmall") end
    PointIf(style, "TOPLEFT", activity, "TOPLEFT", STYLE_X, STYLE_Y)
    local text = ranges and ranges.Text
    local room = LIST_W + RANGES_RIGHT - (text and text:GetStringWidth() or 0) - STYLE_GAP - STYLE_X
    if not ns.Near(style:GetWidth(), room) then style:SetWidth(room) end
end

local function DressListing(page, first)
    EraChrome(page, LISTING_SHEETS, first)
    FootPair(page.BackButton, page.PostButton, first)
    local group = page.GroupRoleButtons
    if group and first then
        Red(group.RolePollButton)
        if group.RoleDropdown then ns.DressDropdown(group.RoleDropdown, 14) end
    end
    -- Offsets count in the scaled frame's own units.
    local solo = page.SoloRoleButtons
    if solo then
        ns.SetScaleIf(solo, ROLE_SCALE)
        PointIf(solo, "TOPLEFT", Origin(), "TOPLEFT", ROLE_X / ROLE_SCALE, -ROLE_Y / ROLE_SCALE)
        if solo.Tank and solo.Healer and solo.DPS then
            local gap = ROLE_STEP / ROLE_SCALE - solo.Tank:GetWidth()
            PointIf(solo.Healer, "LEFT", solo.Tank, "RIGHT", gap, 0)
            PointIf(solo.DPS, "LEFT", solo.Healer, "RIGHT", gap, 0)
        end
    end
    PointIf(group, "TOPLEFT", Origin(), "TOPLEFT", 64, -41)
    local friendly = page.NewPlayerFriendlyButton
    if friendly then
        ns.SetScaleIf(friendly, FRIENDLY_SCALE)
        PointIf(friendly, "CENTER", Origin(), "TOPLEFT", FRIENDLY_CX / FRIENDLY_SCALE, -ROLE_CY / FRIENDLY_SCALE)
        if first and friendly.CheckButton then ns.SkinCheckbox(friendly.CheckButton) end
    end
    local view = page.CategoryView
    if view then
        ns.SetTwoPointsIf(view, "TOPLEFT", Origin(), "TOPLEFT", LIST_X, -LIST_Y,
            "BOTTOMRIGHT", Origin(), "TOPLEFT", LIST_X + LIST_W, -(LIST_Y + LIST_H))
    end
    -- A category's activities (and the comment box) in Era's list box, as its category bars.
    local activity = page.ActivityView
    if activity then
        ns.SetTwoPointsIf(activity, "TOPLEFT", Origin(), "TOPLEFT", LIST_X, -LIST_Y,
            "BOTTOMRIGHT", Origin(), "TOPLEFT", LIST_X + LIST_W, -(LIST_Y + LIST_H))
        local comment = activity.Comment
        if comment and not ns.Near(comment:GetWidth(), ACTIVITY_COMMENT_WIDTH) then comment:SetWidth(ACTIVITY_COMMENT_WIDTH) end
        PlaceStyleRow(activity, first)
        if first then
            ns.SkinScrollBarsUnder(activity, 2)
            SmallActivityFonts()
        end
    end
end

-- The shared parent's close button and portrait, in the sheet's socket and ring.
local function DressParent(parent, first)
    local close = _G["LFGParentFrameCloseButton"]
    if close then
        if first then ns.SkinCloseButton(close, true) end
        At(close, 326, 8, 32, 32)
        ns.SetLevelIf(close, parent:GetFrameLevel() + 20)
    end
    -- Era's eye (the first frame of its sheet) on its black backing, UNDER the pages: their ring overlaps it, as in Era.
    -- This client's own eye button is faded, not moved; it animates that one.
    local portrait = _G["LFGParentFramePortrait"]
    if portrait and first then Hide(portrait.texture) end
    local eyeFrame = eyeHost or ns.NewFrame("Frame", nil, parent)
    if not eyeHost then
        eyeHost = eyeFrame
        eyeFrame:SetSize(ERA_W, ERA_H)
        local back = eyeFrame:CreateTexture(nil, "BACKGROUND")
        ns.SetFile(back, ERA_EYE_BACK)
        back:SetSize(64, 64)
        back:SetPoint("TOPLEFT", eyeFrame, "TOPLEFT", ERA_EYE_BACK_X, -ERA_EYE_BACK_Y)
        local eye = eyeFrame:CreateTexture(nil, "ARTWORK")
        ns.SetFile(eye, ERA_EYE)
        eye:SetTexCoord(0, 0.125, 0, 0.25)
        eye:SetSize(64, 64)
        eye:SetPoint("TOPLEFT", eyeFrame, "TOPLEFT", ERA_EYE_X, -ERA_EYE_Y)
    end
    PointIf(eyeFrame, "TOPLEFT", Origin(), "TOPLEFT", 0, 0)
    ns.SetLevelIf(eyeFrame, parent:GetFrameLevel())
end

-- The category bars are made as the page first shows, for the wider window: cut to this one each time. Forever builds
-- them from the retail template (sized to its cover art, a pressed cover, a hover cover); Classic Era's has the cover
-- drawn to the bar and the PvP queue sheet's glow lines, 44 tall.
local BAR_W, BAR_H, GLOW_H = 287, 44, 34
local GLOW_FILE = "Interface\\PVPFrame\\PvPMegaQueue"
local GLOW_COORDS = { 0.00195313, 0.63867188, 0.70703125, 0.76757813 }

local function ClassicBar(bar)
    if bar.Cover then ns.SetTwoPointsIf(bar.Cover, "TOPLEFT", bar, "TOPLEFT", 0, 0, "BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0) end
    if bar.Icon then ns.SetTwoPointsIf(bar.Icon, "TOPLEFT", bar, "TOPLEFT", 5, -5, "BOTTOMRIGHT", bar, "BOTTOMRIGHT", -5, 5) end
    local pushed = bar.GetPushedTexture and bar:GetPushedTexture()
    if pushed then pushed:SetAlpha(0) end
    local glow = bar.HighlightTexture or bar:GetHighlightTexture()
    if glow then
        glow:SetTexture(GLOW_FILE)
        glow:SetTexCoord(unpack(GLOW_COORDS))
        glow:SetBlendMode("ADD")
    end
    if bar.Label and bar.Label.SetFontObject then bar.Label:SetFontObject("GameFontNormal") end
end

local function CategoryBars()
    local page = _G["LFGListingFrame"]
    local view = page and page.CategoryView
    local bars = view and view.CategoryButtons
    return type(bars) == "table" and bars or nil, view
end

local function FitCategories()
    local bars, view = CategoryBars()
    if not bars then return end
    local wide = BAR_W
    -- The first bar stands 15 into Era's list, as its dump has it; the rest follow it.
    local first = bars[1]
    if first and ns.Once(first, "finderRaised") then
        ns.SetPointOnce(first, "TOP", view, "TOP", 0, -15)
    end
    for _, bar in ipairs(bars) do
        if ns.Once(bar, "finderClassic") then ClassicBar(bar) end
        ns.SetSizeIf(bar, wide, BAR_H)
        for _, key in ipairs(BAR_TEXTURES) do
            if bar[key] then ns.SetSizeIf(bar[key], wide - 10, GLOW_H) end
        end
    end
end

-- Checked every frame while the finder shows: a bar made or re-laid out at the client's size is cut on the frame it
-- appears, not up to 0.1 s later.
local function CategoriesOff()
    local bars, view = CategoryBars()
    if not (bars and view:IsVisible()) then return false end
    local wide = BAR_W
    for i = 1, #bars do
        local bar = bars[i]
        if bar:IsShown() and math.abs(bar:GetWidth() - wide) > 0.5 then return true end
    end
    return false
end

local function EraFont(text, font)
    if text and text.SetFontObject then text:SetFontObject(font) end
end

-- Wide-window rows put "Roles:" and the role icons over the name: moved to
-- the edge. Rows are made as the list scrolls, so each is dressed once.
local function DressRow(row)
    if row.fcuiRow then return end
    local display = row.DataDisplay
    if not display then return end
    row.fcuiRow = true
    -- Era's rows are plain: no rounded plate.
    if row.ResultBG then row.ResultBG:SetAlpha(0) end
    -- Era's type and class icon: this client's are a size up, and a long name ran into the roles.
    EraFont(row.Name, "GameFontNormal")
    EraFont(row.Level, "GameFontDisableSmallLeft")
    EraFont(row.ActivityName, "GameFontDisableSmallLeft")
    EraFont(display.PlayerCount and display.PlayerCount.Count, "GameFontHighlightSmall")
    if row.ClassIcon and row.Level then
        row.ClassIcon:SetSize(18, 18)
        ns.SetPointOnce(row.ClassIcon, "BOTTOMLEFT", row.Level, "BOTTOMRIGHT", 3, -1)
    end
    local solo = display.Solo
    if solo and solo.RolesText then
        EraFont(solo.RolesText, "GameFontHighlightSmall")
        ns.SetPointOnce(solo.RolesText, "RIGHT", solo, "RIGHT", GROUP_ROW_ROLES_LABEL_RIGHT, 0)
    end
    local all = display.Enumerate
    if all and all.Icon1 then
        ns.SetPointOnce(all.Icon1, "RIGHT", all, "RIGHT", GROUP_ROW_PARTY_ICONS_RIGHT, 0)
    end
end

-- The roles block's left: a player's "Roles:", else a group's first member icon.
local function RolesLeft(display)
    local solo, all = display.Solo, display.Enumerate
    if solo and solo:IsShown() and solo.RolesText then return Plain(solo.RolesText:GetLeft()) end
    if not (all and all:IsShown() and all.Icons) then return nil end
    local left
    for _, icon in ipairs(all.Icons) do
        local x = icon:IsShown() and Plain(icon:GetLeft())
        if x and (not left or x < left) then left = x end
    end
    return left
end

-- A long name gives way, so what hangs off it stays clear of the roles (Era's names were short: it cut them at 176).
local function FitName(row)
    local display, name = row.DataDisplay, row.Name
    if not (display and name and name:IsShown()) then return end
    local limit = RolesLeft(display)
    if not limit then return end
    local right
    for _, key in ipairs(NAME_TAIL) do
        local piece = row[key]
        local x = piece and piece:IsShown() and Plain(piece:GetRight())
        if x and (not right or x > right) then right = x end
    end
    local over, width = right and right + NAME_ROLES_GAP - limit, Plain(name:GetWidth())
    if over and over > 0.5 and width then name:SetWidth(math.max(width - over, NAME_MIN_WIDTH)) end
end

local function DressAndFit(row)
    DressRow(row)
    FitName(row)
end

-- Every 0.1 s with Fit: the client sets each name's width afresh as a row fills.
local function DressRows(page)
    local box = page and page.ScrollBox
    if not (box and box.ForEachFrame and page:IsShown()) then return end
    pcall(box.ForEachFrame, box, DressAndFit)
end

-- The client puts the list back on its own wider anchors whenever its scroll bar comes or goes (every open, as the
-- search empties and refills it): ours again before that frame draws, with its new rows dressed.
local function WatchList(page)
    if page and page.ScrollBox then
        ns.Sched.OnMove(page.ScrollBox, function()
            if not active then return end
            ns.SafeCall(PlaceList, page)
            DressRows(page)
        end)
    end
end

-- Size only, never a manager pass from here: the client's own next show or hide places the neighbours by this width.
local function FitSize(parent, width, height)
    if InCombatLockdown() then return end
    if math.abs(parent:GetWidth() - width) > 0.5 or math.abs(parent:GetHeight() - height) > 0.5 then
        parent:SetSize(width, height)
    end
end

local watcher
local function Fit()
    local parent = _G["LFGParentFrame"]
    if not active or not parent then return end
    local width, height = Size()
    FitSize(parent, width, height)
    local first = not dressed
    dressed = true
    if _G["LFGBrowseFrame"] then ns.SafeCall(DressBrowse, _G["LFGBrowseFrame"], first) end
    if _G["LFGListingFrame"] then ns.SafeCall(DressListing, _G["LFGListingFrame"], first) end
    ns.SafeCall(DressParent, parent, first)
    if first then
        S.BuildFinderSideTabs(parent, Origin())
        WatchList(_G["LFGBrowseFrame"])
    end
    ns.FadeKeys(parent, CLIENT_TABS, 0, QUIET)
    S.SyncFinderSideTabs(parent)
    FitCategories()
    DressRows(_G["LFGBrowseFrame"])
end

local function FitShown()
    if active then ns.SafeCall(Fit) end
end

-- Shut too: the client's open then places it at the social window's size. Only we size it, so this follows the social
-- window's size and the finder's hide, once a fight ends.
local function FitShutNow()
    local parent = _G["LFGParentFrame"]
    if active and parent and not parent:IsVisible() then FitSize(parent, Size()) end
end

local function FitShut()
    ns.WhenCalm("finder.shutFit", FitShutNow)
end

local function FinderShown(shown)
    if not shown then ns.Sched.NextFrame("finder.shutFit", FitShut) end
end

-- In a fight we swap the finder and the social window raw, so the client's manager still holds the social window: its
-- own open of the finder (the tab over ours) stood it in the next slot, 386 over, and it stayed there for the fight. While
-- the social window is shut, the finder stands in its place.
local function SocialSpot()
    local social = FriendsFrame
    if not social or ns.Safe(social:GetNumPoints(), 0) ~= 1 then return nil end
    local point, rel, relPoint, x, y = social:GetPoint(1)
    if ns.AnySecret(point, rel, relPoint, x, y) or point ~= "TOPLEFT" or relPoint ~= "TOPLEFT" then return nil end
    if rel ~= nil and rel ~= UIParent then return nil end
    return x, y
end

local function FinderOnSocialSpot()
    local finder = _G["LFGParentFrame"]
    if not (active and InCombatLockdown() and finder and finder:IsShown()) then return end
    if FriendsFrame and FriendsFrame:IsShown() or ns.WindowLocked(finder) then return end
    local x, y = SocialSpot()
    if x then ns.SetPointIf(finder, "TOPLEFT", UIParent, "TOPLEFT", x, y) end
end

local function SocialShown(shown)
    if not shown then ns.Sched.NextFrame("finder.fightSpot", FinderOnSocialSpot) end
end

-- After the fight the manager's record is put right: a window it still holds but that we hid is let go.
local PANEL_SLOTS = { "left", "center", "right", "doublewide" }
local function ForgetHidden()
    local held = _G.GetUIPanel
    if not active or InCombatLockdown() or not held or not HideUIPanel then return end
    for _, frame in ipairs({ FriendsFrame, _G["LFGParentFrame"] }) do
        for _, slot in ipairs(PANEL_SLOTS) do
            -- ns.HidePanel passes a shut window by: the manager is told here.
            if frame and held(slot) == frame and not frame:IsShown() then HideUIPanel(frame) end
        end
    end
end

-- 10 Hz on a child of the finder (and at once for a category bar off size), so only while it shows; the finder exists
-- once its code loads.
local function AttachFit()
    local parent = _G["LFGParentFrame"]
    if not parent then return end
    ns.Sched.Attach(parent, { name = "finder.fit", every = 0.1, pre = CategoriesOff, fn = FitShown })
    -- A page shown by its tab is laid before it draws, not up to 0.1 s later (the flash of the client's layout).
    for _, name in ipairs(PAGES) do
        if _G[name] then ns.Sched.AfterShow(_G[name], "finder.pageFit", FitShown) end
    end
    ns.Sched.OnVisible(parent, "finder.shutFit", FinderShown)
    ns.Sched.AfterShow(parent, "finder.fightSpot", FinderOnSocialSpot)
end

local function Watch()
    if watcher then return end
    watcher = ns.EventFrame("ADDON_LOADED", function(_, _, name)
        if name ~= ADDON_NAME then return end
        AttachFit()
        ns.SafeCall(Fit)
    end)
    AttachFit()
    if FriendsFrame then
        ns.Sched.OnMove(FriendsFrame, FitShut)
        ns.Sched.OnVisible(FriendsFrame, "finder.fightSpot", SocialShown)
    end
    ns.EventFrame("PLAYER_REGEN_ENABLED", ForgetHidden)
end

-- The module's switch, its only writer.
local function SetActive(on)
    active = on
end

-- Preloads the finder's load-on-demand code (the first open was slow); the
-- Who tab calls this as its side tabs come out.
function ns.WarmGroupFinder()
    if not active or InCombatLockdown() then return end
    if C_AddOns and C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded(ADDON_NAME) then
        pcall(C_AddOns.LoadAddOn, ADDON_NAME)
    end
    ns.SafeCall(Fit)
end

local function Apply()
    SetActive(true)
    Watch()
    ns.SafeCall(Fit)
end

local function Restore()
    SetActive(false)
    ns.needsReload = true
end

ns.RegisterModule("groupFinder", { apply = Apply, restore = Restore })
