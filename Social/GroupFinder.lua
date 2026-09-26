local _, ns = ...

-- The group finder dressed as the social window: cut to its size, in its
-- place, with classic controls and the Who tab's side tabs. Widget calls only
-- (size, points, alpha, art); the pages stay the client's.

local S = ns.social

local ADDON_NAME = "Blizzard_GroupFinder_VanillaStyle"
-- The client's who side tab put away; its page tabs lie unseen over ours (FinderTabs.lua).
local CLIENT_TABS = { "WhoListingTab" }
local QUIET = { changed = true, mouseOff = true }
local BAR_TEXTURES = { "SelectedTexture", "HighlightTexture" }
local active = false
local dressed = false

local function Size()
    local social = FriendsFrame
    local width, height = social and social:GetWidth() or 0, social and social:GetHeight() or 0
    if width < 300 then width, height = 360, 424 end
    return math.floor(width + 0.5), math.floor(height + 0.5)
end

local function Red(button, width, height)
    if not button then return end
    ns.SkinRedButton(button)
    if width then button:SetSize(width, height or 22) end
end

local function Hide(region)
    if region and region.SetAlpha then region:SetAlpha(0) end
end

-- Two red buttons in a page's foot corners.
local function FootPair(page, left, right)
    Red(left, 124)
    Red(right, 124)
    ns.SetPointOnce(left, "BOTTOMLEFT", page, "BOTTOMLEFT", 8, 9)
    ns.SetPointOnce(right, "BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 9)
end

-- The options button where the Create Listing page has it.
local function PlaceOptions(page)
    ns.SetPointOnce(page.OptionsButton, "TOPRIGHT", page, "TOPRIGHT", -12, -30)
end

local function DressBrowse(page, width)
    Hide(page.BackgroundArt)
    if page.Inset then Hide(page.Inset.CustomBG) end
    local category, activity, refresh = page.CategoryDropdown, page.ActivityDropdown, page.RefreshButton
    if category and activity then
        ns.SetPointOnce(category, "TOPLEFT", page, "TOPLEFT", 41, -52)
        category:SetWidth(100)
        ns.SetPointOnce(activity, "LEFT", category, "RIGHT", 8, 0)
        activity:SetWidth(width - 66 - 100 - 8 - 6 - 30 - 12)
        if refresh then
            ns.SetPointOnce(refresh, "LEFT", activity, "RIGHT", 6, 0)
            refresh:SetSize(28, 28)
        end
        ns.DressDropdown(category, 14)
        ns.DressDropdown(activity, 14)
    end
    PlaceOptions(page)
    FootPair(page, page.SendMessageButton, page.GroupInviteButton)
    ns.SkinScrollBarsUnder(page, 2)
end

-- The roles' blue band art overhangs 250 for the wide window: cropped to its painted part.
local function CropRolesBand(region, band)
    if region.IsObjectType and region:IsObjectType("Texture") then
        region:ClearAllPoints()
        region:SetAllPoints(band)
        region:SetTexCoord(0, 454 / 704, 0, 102 / 144)
    end
end

local function DressListing(page, width)
    FootPair(page, page.BackButton, page.PostButton)
    -- Forever's divider under the roles (1.60.1 70009) is drawn for the client's wider window and sticks out of ours.
    Hide(page.DividerFrame)
    local group = page.GroupRoleButtons
    if group then
        Red(group.RolePollButton)
        if group.RoleDropdown then ns.DressDropdown(group.RoleDropdown, 14) end
    end
    -- The role row was laid out 100 wider (the new player box sat on the third role).
    local solo = page.SoloRoleButtons
    if solo then
        ns.SetPointOnce(solo, "TOPLEFT", page, "TOPLEFT", 46, -41)
        if solo.Tank and solo.Healer and solo.DPS then
            ns.SetPointOnce(solo.Healer, "LEFT", solo.Tank, "RIGHT", 10, 0)
            ns.SetPointOnce(solo.DPS, "LEFT", solo.Healer, "RIGHT", 10, 0)
        end
    end
    ns.SetPointOnce(group, "TOPLEFT", page, "TOPLEFT", 64, -41)
    local friendly = page.NewPlayerFriendlyButton
    if friendly then
        ns.SetPointOnce(friendly, "TOPRIGHT", page, "TOPRIGHT", -28, -41)
        if friendly.CheckButton then ns.SkinCheckbox(friendly.CheckButton) end
    end
    local band = page.RolesSection
    ns.EachRegion(band, CropRolesBand, band)
    PlaceOptions(page)
    local view = page.ActivityView
    if view then
        if view.Comment then view.Comment:SetWidth(width - 40) end
        ns.SkinScrollBarsUnder(view, 2)
    end
end

-- The category bars are made as the page first shows, for the wider window: cut to this one each time. Forever builds
-- them from the retail template (sized to its cover art, a pressed cover, a hover cover); Classic Era's has the cover
-- drawn to the bar and the PvP queue sheet's glow lines, 44 tall.
local BAR_H, GLOW_H = 44, 34
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

local function FitCategories(width)
    local bars, view = CategoryBars()
    if not bars then return end
    local wide = width - 20
    -- The first bar stands 8 under the role band, not 20; the rest follow it.
    local first = bars[1]
    if first and ns.Once(first, "finderRaised") then
        ns.SetPointOnce(first, "TOP", view, "TOP", 0, -8)
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
    local wide = Size() - 20
    for i = 1, #bars do
        local bar = bars[i]
        if bar:IsShown() and math.abs(bar:GetWidth() - wide) > 0.5 then return true end
    end
    return false
end

-- Wide-window rows put "Roles:" and the role icons over the name: moved to
-- the edge. Rows are made as the list scrolls, so each is dressed once.
local function DressRow(row)
    if row.fcuiRow then return end
    local display = row.DataDisplay
    if not display then return end
    row.fcuiRow = true
    if row.Name and row.Name.SetFontObject then row.Name:SetFontObject("GameFontNormal") end
    local solo = display.Solo
    if solo and solo.RolesText then
        ns.SetPointOnce(solo.RolesText, "RIGHT", solo, "RIGHT", -78, 0)
    end
    local all = display.Enumerate
    if all and all.Icon1 then
        ns.SetPointOnce(all.Icon1, "RIGHT", all, "RIGHT", -16, 0)
    end
end

local function DressRows(page)
    local box = page and page.ScrollBox
    if not (box and box.ForEachFrame and page:IsShown()) then return end
    pcall(box.ForEachFrame, box, DressRow)
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
    if not dressed then
        dressed = true
        if _G["LFGBrowseFrame"] then ns.SafeCall(DressBrowse, _G["LFGBrowseFrame"], width) end
        if _G["LFGListingFrame"] then ns.SafeCall(DressListing, _G["LFGListingFrame"], width) end
        S.BuildFinderSideTabs(parent)
    end
    ns.FadeKeys(parent, CLIENT_TABS, 0, QUIET)
    S.SyncFinderSideTabs(parent)
    FitCategories(width)
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

-- 10 Hz on a child of the finder (and at once for a category bar off size), so only while it shows; the finder exists
-- once its code loads.
local function AttachFit()
    local parent = _G["LFGParentFrame"]
    if not parent then return end
    ns.Sched.Attach(parent, { name = "finder.fit", every = 0.1, pre = CategoriesOff, fn = FitShown })
    ns.Sched.OnVisible(parent, "finder.shutFit", FinderShown)
end

local function Watch()
    if watcher then return end
    watcher = ns.EventFrame("ADDON_LOADED", function(_, _, name)
        if name ~= ADDON_NAME then return end
        AttachFit()
        ns.SafeCall(Fit)
    end)
    AttachFit()
    if FriendsFrame then ns.Sched.OnMove(FriendsFrame, FitShut) end
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
