-- Settings window in Classic Era's look. Its layout and controls are the client's (Era runs the same settings code);
-- the art Forever redrew is drawn from Era's again: each atlas re-pointed to Era's file and coords, Era's frame border.
local _, ns = ...

-- Generated from Classic Era's UiTextureAtlas tables (1.15.9): every atlas on the Era sheets the settings window
-- draws, keyed by lowercase name: { art, left, right, top, bottom }.
local ERA_ART = {
    ["options_categoryheader_1"] = { "eraOptions", 0.00098, 0.19531, 0.00098, 0.14160 },
    ["options_categoryheader_2"] = { "eraOptions", 0.39355, 0.58789, 0.00098, 0.14160 },
    ["options_categoryheader_3"] = { "eraOptions", 0.19727, 0.39160, 0.00098, 0.14160 },
    ["options_frame_child"] = { "eraOptions", 0.60156, 0.62891, 0.02344, 0.04883 },
    ["options_horizontaldivider"] = { "eraOptions", 0.00098, 0.61621, 0.14355, 0.14453 },
    ["options_innerframe"] = { "eraOptions", 0.00098, 0.86621, 0.14648, 0.75000 },
    ["options_list_active"] = { "eraOptions", 0.58984, 0.77246, 0.00098, 0.02148 },
    ["options_list_hover"] = { "eraOptions", 0.77441, 0.95703, 0.00098, 0.02148 },
    ["options_tab_active_left"] = { "eraOptions", 0.59277, 0.59961, 0.02344, 0.04883 },
    ["options_tab_active_middle"] = { "eraOptions", 0.58984, 0.59082, 0.04785, 0.07324 },
    ["options_tab_active_right"] = { "eraOptions", 0.59277, 0.59961, 0.07520, 0.10059 },
    ["options_tab_left"] = { "eraOptions", 0.59277, 0.59961, 0.05078, 0.07324 },
    ["options_tab_middle"] = { "eraOptions", 0.58984, 0.59082, 0.02344, 0.04590 },
    ["options_tab_right"] = { "eraOptions", 0.59277, 0.59961, 0.10254, 0.12500 },
    ["common-search-border-left"] = { "eraSearchBox", 0.88672, 0.94922, 0.00781, 0.32031 },
    ["common-search-border-middle"] = { "eraSearchBox", 0.00391, 0.87891, 0.00781, 0.32031 },
    ["common-search-border-right"] = { "eraSearchBox", 0.00391, 0.06641, 0.33594, 0.64844 },
    ["common-search-clearbutton"] = { "eraSearchBox", 0.07422, 0.15234, 0.53906, 0.69531 },
    ["common-search-magnifyingglass"] = { "eraSearchBox", 0.07422, 0.16797, 0.33594, 0.52344 },
    ["minimal-scrollbar-arrow-bottom"] = { "eraScrollBarArrows", 0.68750, 0.82031, 0.01562, 0.18750 },
    ["minimal-scrollbar-arrow-bottom-down"] = { "eraScrollBarArrows", 0.24219, 0.37500, 0.81250, 0.98438 },
    ["minimal-scrollbar-arrow-bottom-over"] = { "eraScrollBarArrows", 0.39062, 0.52344, 0.01562, 0.18750 },
    ["minimal-scrollbar-arrow-bottom-over_alt"] = { "eraScrollBarArrows", 0.53906, 0.67188, 0.01562, 0.18750 },
    ["minimal-scrollbar-arrow-returntobottom"] = { "eraScrollBarArrows", 0.24219, 0.37500, 0.54688, 0.78125 },
    ["minimal-scrollbar-arrow-returntobottom-down"] = { "eraScrollBarArrows", 0.24219, 0.37500, 0.01562, 0.25000 },
    ["minimal-scrollbar-arrow-returntobottom-over"] = { "eraScrollBarArrows", 0.24219, 0.37500, 0.28125, 0.51562 },
    ["minimal-scrollbar-arrow-top"] = { "eraScrollBarArrows", 0.39062, 0.52344, 0.42188, 0.59375 },
    ["minimal-scrollbar-arrow-top-down"] = { "eraScrollBarArrows", 0.83594, 0.96875, 0.01562, 0.18750 },
    ["minimal-scrollbar-arrow-top-over"] = { "eraScrollBarArrows", 0.39062, 0.52344, 0.21875, 0.39062 },
    ["minimal-scrollbar-thumb-bottom"] = { "eraScrollBarArrows", 0.16406, 0.22656, 0.01562, 0.57812 },
    ["minimal-scrollbar-thumb-bottom-down"] = { "eraScrollBarArrows", 0.00781, 0.07031, 0.01562, 0.57812 },
    ["minimal-scrollbar-thumb-bottom-over"] = { "eraScrollBarArrows", 0.08594, 0.14844, 0.01562, 0.57812 },
    ["minimal-scrollbar-thumb-top"] = { "eraScrollBarArrows", 0.08594, 0.14844, 0.60938, 0.73438 },
    ["minimal-scrollbar-thumb-top-down"] = { "eraScrollBarArrows", 0.00781, 0.07031, 0.60938, 0.73438 },
    ["minimal-scrollbar-thumb-top-over"] = { "eraScrollBarArrows", 0.00781, 0.07031, 0.76562, 0.89062 },
    ["minimal-scrollbar-track-bottom"] = { "eraScrollBarArrows", 0.08594, 0.14844, 0.76562, 0.89062 },
    ["minimal-scrollbar-track-top"] = { "eraScrollBarArrows", 0.16406, 0.22656, 0.60938, 0.73438 },
    ["!minimal-scrollbar-track-middle"] = { "eraScrollBarTrack", 0.01562, 0.14062, 0.00000, 0.00098 },
    ["minimal-scrollbar-thumb-middle"] = { "eraScrollBarTrack", 0.48438, 0.60938, 0.00098, 0.69922 },
    ["minimal-scrollbar-thumb-middle-down"] = { "eraScrollBarTrack", 0.17188, 0.29688, 0.00098, 0.69922 },
    ["minimal-scrollbar-thumb-middle-over"] = { "eraScrollBarTrack", 0.32812, 0.45312, 0.00098, 0.69922 },
    ["_minimal_sliderbar_middle"] = { 4567914, 0.00000, 0.03125, 0.00781, 0.14062 },
    ["minimal_sliderbar_button"] = { 4567914, 0.03125, 0.65625, 0.15625, 0.30469 },
    ["minimal_sliderbar_button_left"] = { 4567914, 0.03125, 0.37500, 0.32031, 0.46875 },
    ["minimal_sliderbar_button_right"] = { 4567914, 0.03125, 0.31250, 0.63281, 0.77344 },
    ["minimal_sliderbar_left"] = { 4567914, 0.43750, 0.78125, 0.32031, 0.45312 },
    ["minimal_sliderbar_right"] = { 4567914, 0.03125, 0.37500, 0.48438, 0.61719 },
    ["_options_listexpand_middle"] = { "eraOptionsListExpand", 0.00000, 0.03125, 0.00781, 0.21094 },
    ["options_listexpand_left"] = { "eraOptionsListExpand", 0.03125, 0.40625, 0.66406, 0.86719 },
    ["options_listexpand_right"] = { "eraOptionsListExpand", 0.03125, 0.90625, 0.22656, 0.42969 },
    ["options_listexpand_right_expanded"] = { "eraOptionsListExpand", 0.03125, 0.90625, 0.44531, 0.64844 },
    ["checkbox-minimal"] = { 4614134, 0.01562, 0.48438, 0.01562, 0.46875 },
    ["checkmark-minimal"] = { 4614134, 0.01562, 0.48438, 0.50000, 0.95312 },
    ["checkmark-minimal-disabled"] = { 4614134, 0.51562, 0.98438, 0.01562, 0.46875 },
    ["!minimal-scrollbar-small-track-middle"] = { 5142784, 0.01562, 0.14062, 0.00000, 0.00098 },
    ["minimal-scrollbar-small-thumb-middle"] = { 5142784, 0.48438, 0.60938, 0.00098, 0.69922 },
    ["minimal-scrollbar-small-thumb-middle-down"] = { 5142784, 0.17188, 0.29688, 0.00098, 0.69922 },
    ["minimal-scrollbar-small-thumb-middle-over"] = { 5142784, 0.32812, 0.45312, 0.00098, 0.69922 },
    ["minimal-scrollbar-small-arrow-bottom"] = { "eraScrollBarThumbCaps", 0.60938, 0.87500, 0.28125, 0.45312 },
    ["minimal-scrollbar-small-arrow-bottom-down"] = { "eraScrollBarThumbCaps", 0.01562, 0.28125, 0.28125, 0.45312 },
    ["minimal-scrollbar-small-arrow-bottom-over"] = { "eraScrollBarThumbCaps", 0.31250, 0.57812, 0.28125, 0.45312 },
    ["minimal-scrollbar-small-arrow-returntobottom"] = { "eraScrollBarThumbCaps", 0.60938, 0.87500, 0.01562, 0.25000 },
    ["minimal-scrollbar-small-arrow-returntobottom-down"] = { "eraScrollBarThumbCaps", 0.01562, 0.28125, 0.01562, 0.25000 },
    ["minimal-scrollbar-small-arrow-returntobottom-over"] = { "eraScrollBarThumbCaps", 0.31250, 0.57812, 0.01562, 0.25000 },
    ["minimal-scrollbar-small-arrow-top"] = { "eraScrollBarThumbCaps", 0.31250, 0.57812, 0.48438, 0.65625 },
    ["minimal-scrollbar-small-arrow-top-down"] = { "eraScrollBarThumbCaps", 0.01562, 0.28125, 0.48438, 0.65625 },
    ["minimal-scrollbar-small-arrow-top-over"] = { "eraScrollBarThumbCaps", 0.01562, 0.28125, 0.68750, 0.85938 },
    ["minimal-scrollbar-small-thumb-bottom"] = { "eraScrollBarThumbCaps", 0.31250, 0.43750, 0.68750, 0.81250 },
    ["minimal-scrollbar-small-thumb-bottom-down"] = { "eraScrollBarThumbCaps", 0.60938, 0.73438, 0.48438, 0.60938 },
    ["minimal-scrollbar-small-thumb-bottom-over"] = { "eraScrollBarThumbCaps", 0.76562, 0.89062, 0.48438, 0.60938 },
    ["minimal-scrollbar-small-thumb-top"] = { "eraScrollBarThumbCaps", 0.46875, 0.59375, 0.84375, 0.96875 },
    ["minimal-scrollbar-small-thumb-top-down"] = { "eraScrollBarThumbCaps", 0.31250, 0.43750, 0.84375, 0.96875 },
    ["minimal-scrollbar-small-thumb-top-over"] = { "eraScrollBarThumbCaps", 0.46875, 0.59375, 0.68750, 0.81250 },
    ["minimal-scrollbar-small-track-bottom"] = { "eraScrollBarThumbCaps", 0.62500, 0.75000, 0.68750, 0.81250 },
    ["minimal-scrollbar-small-track-top"] = { "eraScrollBarThumbCaps", 0.62500, 0.75000, 0.84375, 0.96875 },
    ["common-dropdown-a-button"] = { "eraDropdownC", 0.00391, 0.10938, 0.22656, 0.33203 },
    ["common-dropdown-a-button-disabled"] = { "eraDropdownC", 0.00391, 0.10938, 0.11328, 0.21875 },
    ["common-dropdown-a-button-hover"] = { "eraDropdownC", 0.00391, 0.10938, 0.33984, 0.44531 },
    ["common-dropdown-a-button-open"] = { "eraDropdownC", 0.00391, 0.10938, 0.56641, 0.67188 },
    ["common-dropdown-a-button-pressed"] = { "eraDropdownC", 0.00391, 0.10938, 0.67969, 0.78516 },
    ["common-dropdown-a-button-pressedhover"] = { "eraDropdownC", 0.00391, 0.10938, 0.45312, 0.55859 },
    ["common-dropdown-b-button"] = { "eraDropdownC", 0.39062, 0.76953, 0.00391, 0.10547 },
    ["common-dropdown-b-button-disabled"] = { "eraDropdownC", 0.50391, 0.88281, 0.11328, 0.21484 },
    ["common-dropdown-b-button-hover"] = { "eraDropdownC", 0.11719, 0.49609, 0.11328, 0.21484 },
    ["common-dropdown-b-button-open"] = { "eraDropdownC", 0.11719, 0.49609, 0.22266, 0.32422 },
    ["common-dropdown-b-button-pressed"] = { "eraDropdownC", 0.50391, 0.88281, 0.22266, 0.32422 },
    ["common-dropdown-b-button-pressedhover"] = { "eraDropdownC", 0.00391, 0.38281, 0.00391, 0.10547 },
    ["common-dropdown-bg"] = { "eraDropdownC", 0.43750, 0.70312, 0.69141, 0.95703 },
    ["common-dropdown-c-bg"] = { "eraDropdownC", 0.43750, 0.78906, 0.33203, 0.68359 },
    ["common-dropdown-c-button"] = { "eraDropdownC", 0.11719, 0.26953, 0.33203, 0.48438 },
    ["common-dropdown-c-button-disabled"] = { "eraDropdownC", 0.11719, 0.26953, 0.49219, 0.64453 },
    ["common-dropdown-c-button-hover-1"] = { "eraDropdownC", 0.11719, 0.26953, 0.65234, 0.80469 },
    ["common-dropdown-c-button-hover-2"] = { "eraDropdownC", 0.27734, 0.42969, 0.65234, 0.80469 },
    ["common-dropdown-c-button-hover-arrow"] = { "eraDropdownC", 0.77734, 0.82422, 0.07812, 0.09766 },
    ["common-dropdown-c-button-open"] = { "eraDropdownC", 0.11719, 0.26953, 0.81250, 0.96484 },
    ["common-dropdown-c-button-pressed-1"] = { "eraDropdownC", 0.27734, 0.42969, 0.49219, 0.64453 },
    ["common-dropdown-c-button-pressed-2"] = { "eraDropdownC", 0.27734, 0.42969, 0.33203, 0.48438 },
    ["common-dropdown-c-button-pressedhover-1"] = { "eraDropdownC", 0.79688, 0.94922, 0.33203, 0.48438 },
    ["common-dropdown-c-button-pressedhover-2"] = { "eraDropdownC", 0.27734, 0.42969, 0.81250, 0.96484 },
    ["common-dropdown-customize-mouseover"] = { "eraDropdownC", 0.00391, 0.08203, 0.79297, 0.87109 },
    ["common-dropdown-icon-back"] = { "eraDropdownC", 0.85156, 0.91797, 0.00391, 0.07031 },
    ["common-dropdown-icon-back-disabled"] = { "eraDropdownC", 0.89062, 0.95703, 0.11328, 0.17969 },
    ["common-dropdown-icon-checkmark-yellow"] = { "eraDropdownC", 0.89062, 0.94922, 0.22266, 0.27734 },
    ["common-dropdown-icon-next"] = { "eraDropdownC", 0.79688, 0.86328, 0.49219, 0.55859 },
    ["common-dropdown-icon-next-disabled"] = { "eraDropdownC", 0.77734, 0.84375, 0.00391, 0.07031 },
    ["common-dropdown-icon-play"] = { "eraDropdownC", 0.00391, 0.07031, 0.87891, 0.94531 },
    ["common-dropdown-icon-radialtick-yellow"] = { "eraDropdownC", 0.92578, 0.99609, 0.00391, 0.07422 },
    ["common-dropdown-icon-sound-off"] = { "eraDropdownC", 0.87109, 0.93750, 0.56641, 0.63281 },
    ["common-dropdown-icon-sound-on"] = { "eraDropdownC", 0.79688, 0.86328, 0.56641, 0.63281 },
    ["common-dropdown-icon-stop"] = { "eraDropdownC", 0.87109, 0.93750, 0.49219, 0.55859 },
    ["common-dropdown-textholder"] = { "eraDropdownC", 0.71094, 0.92188, 0.76953, 0.92969 },
    ["common-dropdown-tickradial"] = { "eraDropdownC", 0.71094, 0.78125, 0.69141, 0.76172 },
    ["common-dropdown-ticksquare"] = { "eraDropdownC", 0.94531, 0.99219, 0.49219, 0.53906 },
}

-- Era's frame border (ButtonFrameTemplateNoPortrait): piece, atlas, size, and its anchors from the frame and corners.
local BORDER = {
    { "TopLeftCorner", "UI-Frame-TopLeftCornerNoPortrait", 34, 33 },
    { "TopRightCorner", "UI-Frame-TopCornerRight", 33, 33 },
    { "BottomLeftCorner", "UI-Frame-BotCornerLeft", 14, 14 },
    { "BottomRightCorner", "UI-Frame-BotCornerRight", 11, 11 },
    { "TopEdge", "_UI-Frame-TitleTile", nil, 28 },
    { "BottomEdge", "_UI-Frame-Bot", nil, 9 },
    { "LeftEdge", "!UI-Frame-LeftTile", 16, nil },
    { "RightEdge", "!UI-Frame-RightTile", 10, nil },
}
local CORNER_POINTS = { TopLeftCorner = "TOPLEFT", TopRightCorner = "TOPRIGHT", BottomLeftCorner = "BOTTOMLEFT",
    BottomRightCorner = "BOTTOMRIGHT" }
-- Edge piece -> its two anchors: point, corner piece, corner point.
local EDGE_POINTS = {
    TopEdge = { "TOPLEFT", "TopLeftCorner", "TOPRIGHT", "TOPRIGHT", "TopRightCorner", "TOPLEFT" },
    BottomEdge = { "BOTTOMLEFT", "BottomLeftCorner", "BOTTOMRIGHT", "BOTTOMRIGHT", "BottomRightCorner", "BOTTOMLEFT" },
    LeftEdge = { "TOPLEFT", "TopLeftCorner", "BOTTOMLEFT", "BOTTOMLEFT", "BottomLeftCorner", "TOPLEFT" },
    RightEdge = { "TOPRIGHT", "TopRightCorner", "BOTTOMRIGHT", "BOTTOMRIGHT", "BottomRightCorner", "TOPRIGHT" },
}

-- Era's spots against this client's: title strip, title text, close button, the Game tab (AddOns follows it).
local TITLE_STRIP_LEFT, TITLE_STRIP_TOP, TITLE_STRIP_RIGHT, TITLE_STRIP_HEIGHT = 8, -3, -8, 17
local TITLE_STRIP = { vert = false, coords = { 0, 1, 0.2890625, 0.421875 } }
local TITLE_TEXT_Y = -5
local CLOSE_X, CLOSE_Y = 4, 4
local GAME_TAB_X, GAME_TAB_Y = 32, -27

local active = false
local lookJob

local function SetArt(tex, art)
    if type(art[1]) == "string" then ns.SetTex(tex, art[1]) else tex:SetTexture(art[1]) end
end

-- A scroll thumb piece keeps the client's atlas (its resize reads the middle's size) and goes unseen; Era's art rides
-- over it, the middle cut as the client cuts its own.
local thumbCopies = setmetatable({}, { __mode = "k" })   -- client piece -> our copy over it
local function ThumbPiece(region, art)
    local owner = region:GetParent()
    if not (owner and owner.upMiddleTexture and (owner.Middle == region or owner.Begin == region
        or owner.End == region)) then
        return false
    end
    local copy = thumbCopies[region]
    if not copy then
        local layer, sub = region:GetDrawLayer()
        copy = owner:CreateTexture(nil, layer, nil, sub)
        copy:SetAllPoints(region)
        thumbCopies[region] = copy
    end
    local bottom = art[5]
    if region == owner.Middle then bottom = art[4] + (art[5] - art[4]) * (select(4, region:GetTexCoord()) or 1) end
    SetArt(copy, art)
    copy:SetTexCoord(art[2], art[3], art[4], bottom)
    ns.SetAlphaIf(region, 0)
    return true
end

-- A texture whose atlas Era draws otherwise: Era's file and coords (the atlas name is gone until the client sets it).
local function EraArt(region)
    if not (region.IsObjectType and region:IsObjectType("Texture")) then return end
    local atlas = region:GetAtlas()
    local art = atlas and ERA_ART[atlas:lower()]
    if not art then return end
    if ThumbPiece(region, art) then return end
    SetArt(region, art)
    -- A tiled atlas ("_" and "!" slices) would repeat the whole sheet: stretched instead, its 1 px slice unchanged.
    region:SetHorizTile(false)
    region:SetVertTile(false)
    region:SetTexCoord(art[2], art[3], art[4], art[5])
end

local function EraTree(frame, depth)
    if depth > 9 or ns.IsForbidden(frame) then return end
    ns.EachRegion(frame, EraArt)
    ns.EachChild(frame, EraTree, depth + 1)
end

local function EraBorder(panel)
    local slice = panel.NineSlice
    if not slice then return end
    for _, piece in ipairs(BORDER) do
        local tex = slice[piece[1]]
        if tex then
            tex:SetAtlas(piece[2])
            if piece[3] then tex:SetWidth(piece[3]) end
            if piece[4] then tex:SetHeight(piece[4]) end
        end
    end
    for key, point in pairs(CORNER_POINTS) do
        if slice[key] then ns.SetPointOnce(slice[key], point, panel, point, 0, 0) end
    end
    for key, p in pairs(EDGE_POINTS) do
        local tex = slice[key]
        if tex and slice[p[2]] and slice[p[5]] then
            ns.SetTwoPointsIf(tex, p[1], slice[p[2]], p[3], 0, 0, p[4], slice[p[5]], p[6], 0, 0)
        end
    end
end

-- Title strip under the title, as Era's TitleBg.
local function TitleStrip(panel)
    local strip = ns.TileTex(ns.OwnTexture(panel, "eraTitleStrip", "BACKGROUND", -6), "frameSheet", TITLE_STRIP)
    strip:SetHeight(TITLE_STRIP_HEIGHT)
    ns.SetTwoPointsIf(strip, "TOPLEFT", panel, "TOPLEFT", TITLE_STRIP_LEFT, TITLE_STRIP_TOP,
        "TOPRIGHT", panel, "TOPRIGHT", TITLE_STRIP_RIGHT, TITLE_STRIP_TOP)
    strip:Show()
end

local function Place(panel)
    local title = panel.NineSlice and panel.NineSlice.Text
    if title then ns.SetPointIf(title, "TOP", panel, "TOP", 0, TITLE_TEXT_Y) end
    if panel.ClosePanelButton then ns.SetPointIf(panel.ClosePanelButton, "TOPRIGHT", panel, "TOPRIGHT", CLOSE_X, CLOSE_Y) end
    if panel.GameTab then ns.SetPointIf(panel.GameTab, "TOPLEFT", panel, "TOPLEFT", GAME_TAB_X, GAME_TAB_Y) end
end

-- The client sets its atlas on a click, a hover state or a reused row: walked every frame while the window shows, so
-- Era's art is in before the frame draws (a 0.1 s beat flashed this client's art on each click).
local function LookPass()
    if not active then return end
    local panel = SettingsPanel
    EraTree(panel, 0)
    Place(panel)
end

local function SkinPanel()
    local panel = SettingsPanel
    if not panel then return end
    if ns.Once(panel, "settingsPanelEra") then
        EraBorder(panel)
        TitleStrip(panel)
        ns.SkinCloseButton(panel.ClosePanelButton, true)
    end
    LookPass()
    if not lookJob then
        lookJob = ns.Sched.OnFrame(ns.NewFrame("Frame", nil, panel), { name = "settings.look", every = 0, fn = LookPass })
    end
end

local hooked = false
local function Apply()
    active = true
    if not SettingsPanel then ns.MissingPiece("SettingsPanel") return end
    -- Re-enabled with the window up: polled at once.
    if lookJob then lookJob:Kick() end
    if not hooked then
        hooked = true
        SettingsPanel:HookScript("OnShow", function() if active then SkinPanel() end end)
    end
    if SettingsPanel:IsShown() then SkinPanel() end
end

local function Restore()
    active = false
    ns.needsReload = true
end

ns.RegisterModule("settingsPanel", { apply = Apply, restore = Restore })
