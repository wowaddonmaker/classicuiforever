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
    if ns.SkinRedButton then ns.SkinRedButton(button) end
    if width then button:SetSize(width, height or 22) end
end

local function Hide(region)
    if region and region.SetAlpha then region:SetAlpha(0) end
end

-- Two red buttons in a page's foot corners.
local function FootPair(page, left, right)
    Red(left, 124)
    Red(right, 124)
    if left then
        left:ClearAllPoints()
        left:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 8, 9)
    end
    if right then
        right:ClearAllPoints()
        right:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 9)
    end
end

-- The options button where the Create Listing page has it.
local function PlaceOptions(page)
    if page.OptionsButton then
        page.OptionsButton:ClearAllPoints()
        page.OptionsButton:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -30)
    end
end

local function DressBrowse(page, width)
    Hide(page.BackgroundArt)
    if page.Inset then Hide(page.Inset.CustomBG) end
    local category, activity, refresh = page.CategoryDropdown, page.ActivityDropdown, page.RefreshButton
    if category and activity then
        category:ClearAllPoints()
        category:SetPoint("TOPLEFT", page, "TOPLEFT", 41, -52)
        category:SetWidth(100)
        activity:ClearAllPoints()
        activity:SetPoint("LEFT", category, "RIGHT", 8, 0)
        activity:SetWidth(width - 66 - 100 - 8 - 6 - 30 - 12)
        if refresh then
            refresh:ClearAllPoints()
            refresh:SetPoint("LEFT", activity, "RIGHT", 6, 0)
            refresh:SetSize(28, 28)
        end
        if ns.DressDropdown then
            ns.DressDropdown(category, 14)
            ns.DressDropdown(activity, 14)
        end
    end
    PlaceOptions(page)
    FootPair(page, page.SendMessageButton, page.GroupInviteButton)
    if ns.SkinScrollBarsUnder then ns.SkinScrollBarsUnder(page, 2) end
end

local function DressListing(page, width)
    FootPair(page, page.BackButton, page.PostButton)
    local group = page.GroupRoleButtons
    if group then
        Red(group.RolePollButton)
        if group.RoleDropdown and ns.DressDropdown then ns.DressDropdown(group.RoleDropdown, 14) end
    end
    -- The role row was laid out 100 wider (the new player box sat on the third role).
    local solo = page.SoloRoleButtons
    if solo then
        solo:ClearAllPoints()
        solo:SetPoint("TOPLEFT", page, "TOPLEFT", 46, -41)
        if solo.Tank and solo.Healer and solo.DPS then
            solo.Healer:ClearAllPoints()
            solo.Healer:SetPoint("LEFT", solo.Tank, "RIGHT", 10, 0)
            solo.DPS:ClearAllPoints()
            solo.DPS:SetPoint("LEFT", solo.Healer, "RIGHT", 10, 0)
        end
    end
    if group then
        group:ClearAllPoints()
        group:SetPoint("TOPLEFT", page, "TOPLEFT", 64, -41)
    end
    local friendly = page.NewPlayerFriendlyButton
    if friendly then
        friendly:ClearAllPoints()
        friendly:SetPoint("TOPRIGHT", page, "TOPRIGHT", -28, -41)
        if friendly.CheckButton and ns.SkinCheckbox then ns.SkinCheckbox(friendly.CheckButton) end
    end
    -- The roles' blue band art overhangs 250 for the wide window: cropped to its painted part.
    local band = page.RolesSection
    if band then
        for _, region in ipairs({ band:GetRegions() }) do
            if region.IsObjectType and region:IsObjectType("Texture") then
                region:ClearAllPoints()
                region:SetAllPoints(band)
                region:SetTexCoord(0, 454 / 704, 0, 102 / 144)
            end
        end
    end
    PlaceOptions(page)
    local view = page.ActivityView
    if view then
        if view.Comment then view.Comment:SetWidth(width - 40) end
        if ns.SkinScrollBarsUnder then ns.SkinScrollBarsUnder(view, 2) end
    end
end

-- The category bars are made as the page first shows, for the wider window: cut to this one each time.
local function FitCategories(page, width)
    local view = page.CategoryView
    local bars = view and view.CategoryButtons
    if type(bars) ~= "table" then return end
    local wide = width - 20
    -- The first bar stands 8 under the role band, not 20; the rest follow it.
    local first = bars[1]
    if first and not first.fcuiRaised then
        first.fcuiRaised = true
        first:ClearAllPoints()
        first:SetPoint("TOP", view, "TOP", 0, -8)
    end
    for _, bar in ipairs(bars) do
        if math.abs(bar:GetWidth() - wide) > 0.5 then
            bar:SetSize(wide, 52)
            for _, key in ipairs(BAR_TEXTURES) do
                if bar[key] then bar[key]:SetSize(wide - 14, 42) end
            end
            if bar.Label and bar.Label.SetFontObject then bar.Label:SetFontObject("GameFontNormal") end
        end
    end
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
        solo.RolesText:ClearAllPoints()
        solo.RolesText:SetPoint("RIGHT", solo, "RIGHT", -78, 0)
    end
    local all = display.Enumerate
    if all and all.Icon1 then
        all.Icon1:ClearAllPoints()
        all.Icon1:SetPoint("RIGHT", all, "RIGHT", -16, 0)
    end
end

local function DressRows(page)
    local box = page and page.ScrollBox
    if not (box and box.ForEachFrame and page:IsShown()) then return end
    pcall(box.ForEachFrame, box, DressRow)
end

local watcher
local function Fit()
    local parent = _G["LFGParentFrame"]
    if not active or not parent then return end
    local width, height = Size()
    if not InCombatLockdown() then
        if math.abs(parent:GetWidth() - width) > 0.5 or math.abs(parent:GetHeight() - height) > 0.5 then
            parent:SetSize(width, height)
            -- No width written: the manager counts the frame's own, so re-placing puts neighbours at the new edge.
            if parent:IsShown() and UpdateUIPanelPositions then pcall(UpdateUIPanelPositions, parent) end
        end
    end
    if not dressed then
        dressed = true
        if _G["LFGBrowseFrame"] then ns.SafeCall(DressBrowse, _G["LFGBrowseFrame"], width) end
        if _G["LFGListingFrame"] then ns.SafeCall(DressListing, _G["LFGListingFrame"], width) end
        S.BuildFinderSideTabs(parent)
    end
    ns.FadeKeys(parent, CLIENT_TABS, 0, QUIET)
    S.SyncFinderSideTabs(parent)
    if _G["LFGListingFrame"] then FitCategories(_G["LFGListingFrame"], width) end
    DressRows(_G["LFGBrowseFrame"])
end

local function Watch()
    if watcher then return end
    watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:SetScript("OnEvent", function(_, _, name)
        if name == ADDON_NAME then ns.SafeCall(Fit) end
    end)
    -- 10 Hz on its own frame, made after the who list's driver so it runs
    -- after it and sees the finder that driver sent away.
    ns.Sched.OnFrame(watcher, { name = "finder.fit", every = 0.1, fn = function()
        local parent = _G["LFGParentFrame"]
        if active and parent and parent:IsShown() then ns.SafeCall(Fit) end
    end })
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
    active = true
    Watch()
    ns.SafeCall(Fit)
end

local function Restore()
    active = false
    ns.needsReload = true
end

ns.RegisterModule("groupFinder", { apply = Apply, restore = Restore })
