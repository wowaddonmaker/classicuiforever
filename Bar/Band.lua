local _, ns = ...

-- 1.x main menu bar: a 1024x53 stone band holding the client's buttons, micro row, bags and tracking bars; edit mode still works.
-- Band files share ns.band (B): state is always B.field; a file aliases only earlier files' functions and constants.

local B = {}
ns.band = B

-- Constants shared by band files; the rest live in their file.
B.ART_W, B.BAND_H, B.CAP_SIZE = 1024, 43, 128
B.BUTTON_PITCH = 42              -- 36 px buttons, 6 apart
B.ROW_X, B.ROW_Y = 8, 4          -- first button from the band's corner
B.PET_ROW_Y = 104                -- stance, pet and possess bars, over bars 2 and 3
-- Past slot 12: room for the page arrows and number when the band ends at bar 1.
B.PAGE_ROOM = 36
-- One-bar mode: the micro group on the screen's floor, the bags over it.
B.CORNER_X = -6
-- The shop lives in the Escape menu; its button never fit the 1.x row.
B.MICRO_SKIP = { StoreMicroButton = true }
-- Gap before the key ring post. No latency bar: the menu button's colour shows it.
B.MICRO_END_GAP = 5
-- Micro region head (holds the page arrows), its max width, the bag part.
B.MICRO_LEAD, B.MICRO_REGION_MAX, B.BAG_PART = 45, 330, 182
-- The real post by the key ring on the client's fourth sheet (drawn, unlike the bundled one): u and width, for group ends off the band.
B.POST_U, B.POST_W = 82, 8

-- The band's edit mode systems; each field's list holds the names that have it, in that field's order:
--   owned    what the 1.x screen nailed in place
--   pin      the bars the client's two passes move and the band places
--   back     handed back to their defaults when the band is turned off
--   restore  bars whose buttons the client lays out again on restore
--   cast     what the cast bar stands on, after the band's own art
--   mark     settings read while edit mode is up
--   extra    bars 6 to 8: not in 1.x, faded and mouse-off unless released
local BAND_SYSTEMS = {
    { "MainActionBar",                       owned = 1,  pin = 1,  back = 1,  restore = 1 },
    { "MainMenuBar",                                     pin = 2,  back = 2 },
    { "MultiBarBottomLeft",                  owned = 2,  pin = 3,  back = 3,  restore = 2, cast = 1, mark = 1 },
    { "MultiBarBottomRight",                 owned = 3,  pin = 4,  back = 4,  restore = 3, cast = 2, mark = 2 },
    { "MultiBarRight",                       owned = 4,  pin = 5,  back = 5,  restore = 4,           mark = 3 },
    { "MultiBarLeft",                        owned = 5,  pin = 6,  back = 6,  restore = 5,           mark = 4 },
    { "StanceBar",                           owned = 6,  pin = 7,  back = 7,  restore = 6, cast = 3, mark = 5 },
    { "PetActionBar",                        owned = 7,  pin = 8,  back = 8,  restore = 7, cast = 4, mark = 6 },
    { "PossessActionBar",                    owned = 8,  pin = 9,  back = 9,  restore = 8, cast = 5 },
    { "MicroMenuContainer",                  owned = 9,            back = 13 },
    { "BagsBar",                             owned = 10,           back = 12 },
    { "MainStatusTrackingBarContainer",      owned = 11, pin = 10, back = 10,              cast = 6 },
    { "SecondaryStatusTrackingBarContainer", owned = 12, pin = 11, back = 11,              cast = 7 },
    { "MultiBar5",                                                                                    mark = 7, extra = 1 },
    { "MultiBar6",                                                                                    mark = 8, extra = 2 },
    { "MultiBar7",                                                                                    mark = 9, extra = 3 },
}
local function Derive(field)
    local list = {}
    for _, entry in ipairs(BAND_SYSTEMS) do
        local at = entry[field]
        if at then list[at] = entry[1] end
    end
    return list
end
B.OWNED_SYSTEMS = Derive("owned")
B.PIN_NAMES = Derive("pin")
B.HAND_BACK = Derive("back")
B.RESTORE_BARS = Derive("restore")
B.CAST_STAND = Derive("cast")
B.EDIT_MARK = Derive("mark")
B.EXTRA_BARS = Derive("extra")

-- Micro buttons in the 1.x order, whichever of them the client has.
B.MICRO_BUTTONS = { "CharacterMicroButton", "ProfessionMicroButton", "SpellbookMicroButton", "TalentMicroButton",
    "PlayerSpellsMicroButton", "AchievementMicroButton", "QuestLogMicroButton", "LegacyMicroButton", "GuildMicroButton",
    "LFDMicroButton", "CollectionsMicroButton", "EJMicroButton", "HousingMicroButton", "HelpMicroButton",
    "StoreMicroButton", "MainMenuMicroButton" }
B.BAG_BUTTONS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot" }

-- Rows of the 256x256 stone sheets as 1.x sliced them: the 43 px band and the 10 px xp-bar strip above;
-- the right half comes from the key ring sheet (256x128) for its notch, on every client.
B.PIECES = {
    { x = 0, key = "barBody", band = { 0.83203125, 1.0 }, strip = { 0.79296875, 0.83203125 } },
    { x = 256, key = "barBody", band = { 0.58203125, 0.75 }, strip = { 0.54296875, 0.58203125 } },
    { x = 512, key = "barKeyring", band = { 0.6640625, 1.0 }, strip = { 0.29296875, 0.33203125 }, stripKey = "barBody" },
    { x = 768, key = "barKeyring", band = { 0.1640625, 0.5 }, strip = { 0.04296875, 0.08203125 }, stripKey = "barBody" },
}
B.CAP_KEYS = { "LeftEndCap", "RightEndCap" }

-- A run of band sheet: bronze with the theme at the soft share, like the band.
B.BAND_RUN = { tint = ns.BRONZE_SOFT, point = "BOTTOMLEFT", show = true }
-- The post cut from the fourth sheet: mirrored it reads as a left end.
do
    local band = B.PIECES[4].band
    B.POST_LEFT = { (B.POST_U + B.POST_W) / 256, B.POST_U / 256, band[1], band[2] }
    B.POST_RIGHT = { B.POST_U / 256, (B.POST_U + B.POST_W) / 256, band[1], band[2] }
end

B.active = false
B.applying = false
-- B.art: ForeverClassicUIBar, made by the first Apply.

-- The client moves bars at known moments (target, fight edge, pet/stance, edit mode, scale): watches look every
-- frame for hot.FOR after each and all through edit mode, else every hot.BEAT; the lane reads it once a frame.
local hot = { FOR = 0.5, BEAT = 0.25, untilAt = 0 }
B.hot = hot
function hot.Make() hot.untilAt = GetTime() + hot.FOR end
local HOT_EVENTS = { "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PET_BAR_UPDATE", "UPDATE_SHAPESHIFT_FORMS", "UPDATE_BONUS_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR",
    "UPDATE_OVERRIDE_ACTIONBAR", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
    "PLAYER_ENTERING_WORLD", "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "PLAYER_LEVEL_UP" }
-- The player's only: these come for every unit in the group.
local HOT_UNIT_EVENTS = { "UNIT_PET", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" }
hot.watch = CreateFrame("Frame")
ns.RegisterEvents(hot.watch, HOT_EVENTS)
ns.RegisterEvents(hot.watch, HOT_UNIT_EVENTS, "player")
hot.watch:SetScript("OnEvent", hot.Make)
hot.Make()

local saved = {}   -- frame -> { scale, parent, w, h, points }
B.saved = saved

-- placeOnly: a frame whose scale the band never sets (the player's edit mode Size) keeps none to put back.
local function Remember(frame, placeOnly)
    if not saved[frame] then
        local points = {}
        for i = 1, frame:GetNumPoints() do points[i] = { frame:GetPoint(i) } end
        local scale = not placeOnly and frame:GetScale() or nil
        saved[frame] = { scale = scale, parent = frame:GetParent(), w = frame:GetWidth(), h = frame:GetHeight(), points = points }
    end
end
B.Remember = Remember

local function BarSetting(bar, key)
    if not bar or not bar.GetSettingValue or not Enum or not Enum.EditModeActionBarSetting then return nil end
    local setting = Enum.EditModeActionBarSetting[key]
    if setting == nil then return nil end
    local ok, value = pcall(bar.GetSettingValue, bar, setting)
    if ok and type(value) == "number" then return value end
    return nil
end
B.BarSetting = BarSetting

-- Edit mode orientation and rows, so a bar turned or folded there has its buttons follow.
local function BarVertical(bar)
    local value = BarSetting(bar, "Orientation")
    if value == nil then return nil end
    local vertical = Enum and Enum.ActionBarOrientation and Enum.ActionBarOrientation.Vertical or 1
    return value == vertical
end
B.BarVertical = BarVertical

local function BarRows(bar)
    return math.max(1, math.floor(BarSetting(bar, "NumRows") or 1))
end
B.BarRows = BarRows

-- Edit mode Icon Size as a scale: the client scales each button's container, which this layout overwrites,
-- so the bar carries it; Action Bar 1's sizes the whole band (art, bags, micro menu, status bars).
local function IconScale(bar)
    local scale
    do
        local value = BarSetting(bar, "IconSize")
        if value and value > 0 then scale = value / 100 end
    end
    if not scale then scale = (bar and bar.GetScale and bar:GetScale()) or 1 end
    -- 1.x size, or the game's (45 px buttons vs 36) with the toggle. The old free-form scale is ignored:
    -- a leftover test value multiplied with the toggle.
    local own = (ns.db and ns.db.defaultBarSize == true) and (45 / 36) or 1
    if own <= 0 then own = 1 end
    if scale <= 0 then scale = 1 end
    return scale * own
end
B.IconScale = IconScale

local function BandScale(bar) return IconScale(bar or ns.GetMainBar()) end
B.BandScale = BandScale
ns.BandScale = BandScale

-- A frame hung off the band (not in it) needs this scale itself, or its offsets fall short as the band grows.
local function BandNow()
    local art = B.art
    local scale = art and art.GetScale and art:GetScale() or 1
    if not scale or scale <= 0 then scale = 1 end
    return scale
end
B.BandNow = BandNow

-- A band bar at the band's size. Protected: only out of combat, as the layout runs.
function B.MatchScale(frame, scale)
    if not frame or not frame.SetScale or not frame.GetScale then return end
    if math.abs((frame:GetScale() or 1) - scale) < 0.005 then return end
    Remember(frame)
    frame:SetScale(scale)
end

-- Seat a client button on the band: remembered, reparented, scaled, sized, levelled, points cleared for the caller.
function B.Seat(button, scale, w, h, level)
    Remember(button)
    if button:GetParent() ~= B.art then button:SetParent(B.art) end
    button:SetScale(scale)
    button:SetSize(w, h)
    button:SetFrameLevel(level)
    button:ClearAllPoints()
end

-- Record a frame's place into its comparison table; runs every frame, so it allocates nothing once sampled.
function B.Record(frame, into)
    into = into or {}
    local point, rel, relPoint, x, y = frame:GetPoint(1)
    into.point, into.rel, into.relPoint = point, rel, relPoint
    into.x, into.y = x or 0, y or 0
    into.w, into.h = frame:GetWidth() or 0, frame:GetHeight() or 0
    into.scale = frame:GetScale() or 1
    into.shown = frame:IsShown() and true or false
    return into
end

function B.Differs(frame, b)
    if not b then return true end
    local point, rel, relPoint, x, y = frame:GetPoint(1)
    if point ~= b.point or rel ~= b.rel or relPoint ~= b.relPoint then return true end
    if math.abs((x or 0) - b.x) > 0.05 or math.abs((y or 0) - b.y) > 0.05 then return true end
    if math.abs((frame:GetWidth() or 0) - b.w) > 0.05 then return true end
    if math.abs((frame:GetHeight() or 0) - b.h) > 0.05 then return true end
    -- An edit mode size slider changes a piece's scale and nothing else.
    if math.abs((frame:GetScale() or 1) - (b.scale or 1)) > 0.001 then return true end
    return (frame:IsShown() and true or false) ~= b.shown
end

-- Two client frames as one list, cached once both exist (ipairs stops at a missing first).
local function PairOf(nameA, nameB)
    local kept
    return function()
        if kept then return kept end
        local a, b = _G[nameA], _G[nameB]
        if a and b then
            kept = { a, b }
            return kept
        end
        return { a, b }
    end
end
B.StatusPair = PairOf("MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer")
B.SideBarPair = PairOf("MultiBarRight", "MultiBarLeft")

-- Panels beside edit mode dialogs wear its translucent border, dressed like it, or a dark fill without the template.
function B.PanelBorder(frame)
    local okBorder, border = pcall(CreateFrame, "Frame", nil, frame, "DialogBorderTranslucentTemplate")
    if okBorder and border then
        border:SetAllPoints(frame)
        ns.EditModeBorder(border)
    else
        local ground = frame:CreateTexture(nil, "BACKGROUND")
        ground:SetAllPoints(frame)
        ground:SetColorTexture(0, 0, 0, 0.85)
    end
end

-- Client slider with steppers (32 high, beside anchor) and its right-label formatter; nil without the template.
function B.StepperSlider(parent, width, anchor, x, format)
    local okSlider, slider = pcall(CreateFrame, "Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
    if not (okSlider and slider and slider.Init) then return nil end
    slider:SetSize(width, 32)
    slider:SetPoint("LEFT", anchor, "RIGHT", x, 0)
    ns.EditModeSlider(slider)
    local formatters
    if CreateMinimalSliderFormatter and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
        local right = MinimalSliderWithSteppersMixin.Label.Right
        formatters = { [right] = CreateMinimalSliderFormatter(right, format) }
    end
    return slider, formatters
end

function B.OnSliderValue(slider, fn, owner)
    if slider.RegisterCallback and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Event then
        slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, fn, owner)
    end
end
