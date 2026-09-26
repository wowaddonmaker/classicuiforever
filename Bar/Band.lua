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
-- Past slot 12: the page arrows and the number slot through its post's right border (u 0-37 of the third sheet).
B.PAGE_ROOM = 38
-- One-bar mode: the micro group on the screen's floor, the bags over it.
B.CORNER_X = -6
-- The shop lives in the Escape menu; its button never fit the 1.x row.
B.MICRO_SKIP = { StoreMicroButton = true }
-- Gap before the latency and key ring section's first post (the 1.x button art has its own margin).
B.MICRO_END_GAP = 1
-- Micro region head (holds the page arrows), its max width, the bag part.
B.MICRO_LEAD, B.MICRO_REGION_MAX, B.BAG_PART = 45, 330, 182
-- The reagent bag in a slot of its own (reagentBagSlot, the default): one more socket, one 32 px period of the client's
-- fourth sheet (u 104-135; its sockets repeat every 32 from the bag post at 84) drawn again after the first socket.
B.REAGENT_SOCKET, B.SOCKET_U0, B.SOCKET_U1 = 32, 104, 136
function B.ReagentSlot()
    return CharacterReagentBag0Slot ~= nil and ns.db ~= nil and ns.db.reagentBagSlot ~= false
end
function B.BagPart()
    return B.BAG_PART + (B.ReagentSlot() and B.REAGENT_SOCKET or 0)
end
-- The client's fourth sheet has stone before its bag post (u 84-89): cut, whatever stands before the bags. Past the page
-- number slot's post, the bag post and the first socket's left frame (u 92-94) go too: that post is the socket's wall.
B.BAG_TRIM, B.BAG_POST_TRIM = 10, 21
-- Latency and key ring section, cut from the 1.x key ring sheet (Era's, the fifth piece): left post, the window the latency
-- tube shows through, shared post, key slot, post.
B.TAIL_WINDOW, B.TAIL_SLOT = 7, 30   -- window's left column, key slot's centre
-- Which halves stand on the band: not hidden, not moved off it (BandSection.lua).
function B.TailParts()
    local db = ns.db
    local latency = not (db and (db.hideLatencyBar == true or ns.ValidPlace(db.latencyPos)))
    local key = KeyRingButton ~= nil and not (db and (db.hideKeyRing == true or ns.ValidPlace(db.keyRingPos)))
    return latency, key
end
-- The section's u span on its sheet, or nil with both halves hidden: after a post (the bags' end, the page number slot's)
-- that post opens it, before the bags the client's bag post closes it, elsewhere it keeps its own posts.
function B.TailSpan(afterPost, beforeBags)
    local latency, key = B.TailParts()
    if not (latency or key) then return nil end
    local u0 = latency and (afterPost and 7 or 0) or (afterPost and 23 or 14)
    local u1 = key and (beforeBags and 38 or 45) or (beforeBags and 14 or 23)
    return u0, u1
end
-- The real post by the key ring on the client's fourth sheet (drawn, unlike the bundled one): u and width, for group ends off the band.
B.POST_U, B.POST_W = 82, 8

-- Edit mode systems; a field's number is the name's place in its list. owned: nailed in place by 1.x; back: handed back with the band off;
-- pin: moved by the client's two passes, placed by the band; restore: bars whose buttons the client lays out again on restore;
-- cast: what the cast bar stands on, after the art; mark: read in edit mode; extra: bars 6-8 (not 1.x), faded, mouse-off unless released.
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
    -- Not a run of the band's width: the latency and key ring section only.
    { key = "barKeyringClassic", band = { 0.1640625, 0.5 } },
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

-- The status bars' 20 Hz watch (BandStatus BarsTick) sleeps between status events; probe P8 reads asleep and wokeAt.
local barsWatch = { since = 0, asleep = false, wokeAt = 0 }
B.barsWatch = barsWatch

-- The only writer of barsWatch.asleep and wokeAt: wakes the watch, its first tick at once; WakeBars(true) is its own tick sleeping.
function B.WakeBars(asleep)
    if asleep then
        barsWatch.asleep = true
        return
    end
    if barsWatch.asleep then
        barsWatch.asleep = false
        barsWatch.since = 1
    end
    barsWatch.wokeAt = GetTime()
    if B.WakeLane then B.WakeLane() end
end

-- The client moves bars at known moments (target, fight edge, pet/stance, edit mode, scale): watches look every
-- frame for hot.FOR after each and all through edit mode, else every hot.BEAT; the lane reads it once a frame.
local hot = { FOR = 0.5, SHORT = 0.1, BEAT = 0.25, untilAt = 0 }
B.hot = hot
function hot.Make()
    hot.untilAt = GetTime() + hot.FOR
    B.WakeBars()
end
-- Target and focus come often and the placer answers them itself: a short look after, never cutting a longer one.
function hot.MakeShort()
    hot.untilAt = math.max(hot.untilAt, GetTime() + hot.SHORT)
    B.WakeBars()
end
local SHORT_EVENTS = { PLAYER_TARGET_CHANGED = true, PLAYER_FOCUS_CHANGED = true }
local HOT_EVENTS = { "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PET_BAR_UPDATE", "UPDATE_SHAPESHIFT_FORMS", "UPDATE_BONUS_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR",
    "UPDATE_OVERRIDE_ACTIONBAR", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
    "PLAYER_ENTERING_WORLD", "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "PLAYER_LEVEL_UP" }
-- The player's only: these come for every unit in the group.
local HOT_UNIT_EVENTS = { "UNIT_PET", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" }
hot.watch = CreateFrame("Frame")
ns.RegisterEvents(hot.watch, HOT_EVENTS)
ns.RegisterEvents(hot.watch, HOT_UNIT_EVENTS, "player")
hot.watch:SetScript("OnEvent", function(_, event)
    if SHORT_EVENTS[event] then hot.MakeShort() else hot.Make() end
end)
hot.Make()

-- The status manager's own events (StatusTrackingManagerOverrides.lua) and the XP ones: each may change which bars are up.
local STATUS_EVENTS = { "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "ENABLE_XP_GAIN", "DISABLE_XP_GAIN",
    "CVAR_UPDATE", "UPDATE_EXPANSION_LEVEL", "PLAYER_ENTERING_WORLD", "HONOR_XP_UPDATE", "ZONE_CHANGED",
    "ZONE_CHANGED_NEW_AREA", "UNIT_INVENTORY_CHANGED", "ARTIFACT_XP_UPDATE", "AZERITE_ITEM_EXPERIENCE_CHANGED",
    "PLAYER_EQUIPMENT_CHANGED", "TRACKED_HOUSE_CHANGED", "PLAYER_MAX_LEVEL_UPDATE", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP",
    "UPDATE_EXHAUSTION" }
local statusWake = CreateFrame("Frame")
ns.RegisterEvents(statusWake, STATUS_EVENTS)
ns.RegisterEvents(statusWake, { "UNIT_LEVEL" }, "player")
statusWake:SetScript("OnEvent", function() B.WakeBars() end)

-- frame -> flat { scale|false, parent|false, w, h, then point, relativeTo|false, relativePoint, x, y per point }
local saved = {}
B.saved = saved

-- placeOnly: a frame whose scale the band never sets (the player's edit mode Size) keeps none to put back.
local function Remember(frame, placeOnly)
    if saved[frame] then return end
    local state = { not placeOnly and frame:GetScale() or false, frame:GetParent() or false, frame:GetWidth(), frame:GetHeight() }
    for i = 1, frame:GetNumPoints() do
        local point, rel, relPoint, x, y = frame:GetPoint(i)
        local n = #state
        state[n + 1], state[n + 2], state[n + 3], state[n + 4], state[n + 5] = point, rel or false, relPoint, x or 0, y or 0
    end
    saved[frame] = state
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
    if ns.Near(frame:GetScale() or 1, scale, 0.005) then return end
    Remember(frame)
    ns.SetScaleIf(frame, scale, 0.005)
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

B.Due = ns.Sched.Due

-- Our own pass: the watches skip what it moves; an error in fn is swallowed as before (pcall).
function B.WhileApplying(fn, ...)
    B.applying = true
    local ok, err = pcall(fn, ...)
    B.applying = false
    return ok, err
end

-- Point, relative frame and x/y (0.05) against a Record mark; relPoint too when asked. Inline compares: runs every frame.
local function Drifted(frame, mark, withRelPoint)
    local point, rel, relPoint, x, y = frame:GetPoint(1)
    if point ~= mark.point or rel ~= mark.rel or (withRelPoint and relPoint ~= mark.relPoint) then return true end
    local d = (x or 0) - mark.x
    if d > 0.05 or d < -0.05 then return true end
    d = (y or 0) - mark.y
    return d > 0.05 or d < -0.05
end
B.Drifted = Drifted

function B.Differs(frame, b)
    if not b then return true end
    if Drifted(frame, b, true) then return true end
    local w, h = frame:GetSize()
    local d = (w or 0) - b.w
    if d > 0.05 or d < -0.05 then return true end
    d = (h or 0) - b.h
    if d > 0.05 or d < -0.05 then return true end
    -- An edit mode size slider changes a piece's scale and nothing else.
    d = (frame:GetScale() or 1) - (b.scale or 1)
    if d > 0.001 or d < -0.001 then return true end
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

-- Copy of the client's edit mode box layout (local to its file): same nine pieces, same names.
local SELECTION_LAYOUT = {
    TopRightCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = 8 },
    TopLeftCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = 8 },
    BottomLeftCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = -8 },
    BottomRightCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = -8 },
    TopEdge = { atlas = "_%s-NineSlice-EdgeTop" },
    BottomEdge = { atlas = "_%s-NineSlice-EdgeBottom" },
    LeftEdge = { atlas = "!%s-NineSlice-EdgeLeft" },
    RightEdge = { atlas = "!%s-NineSlice-EdgeRight" },
    Center = { atlas = "%s-NineSlice-Center", x = -8, y = 8, x1 = 8, y1 = -8 },
}

-- Edit mode handle over a piece of ours, in the client's strata for its own (inside the edit mode window's layer it covered
-- that window): the client's box, blue, yellow while held (handle.Dress(kit)), label centred when given.
function B.SelectionHandle(home, text, font)
    local handle = CreateFrame("Frame", nil, home)
    handle:SetAllPoints(home)
    handle:SetFrameStrata("MEDIUM")
    handle:SetFrameLevel(1010)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:Hide()
    function handle.Dress(kit)
        if handle.kit == kit then return end
        handle.kit = kit
        if NineSliceUtil and NineSliceUtil.ApplyLayout then
            pcall(NineSliceUtil.ApplyLayout, handle, SELECTION_LAYOUT, kit)
        end
    end
    handle.Dress("editmode-actionbar-highlight")
    if text then
        local label = handle:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightLarge")
        label:SetPoint("CENTER", handle, "CENTER", 0, 0)
        label:SetText(text)
        handle.label = label
        handle.label = label
        handle.label = label
    end
    return handle
end

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

-- Our settings dialog shaped like the client's edit mode one (same templates): border, title, close; hidden.
function B.EditDialog(name, width, height, text)
    local dialog = CreateFrame("Frame", name, UIParent)
    dialog:SetSize(width, height)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(200)
    ns.MakeDraggable(dialog)
    dialog:Hide()
    B.PanelBorder(dialog)
    local title = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    title:SetPoint("TOP", dialog, "TOP", 0, -15)
    if text then title:SetText(text) end
    dialog.title = title
    local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() dialog:Hide() end)
    ns.EditModeClose(close)
    dialog.close = close
    ns.CloseOnEscape(dialog, function() close:Click() end)
    return dialog
end

-- Its red Reset To Default Position along the foot.
function B.EditDialogReset(dialog, onClick)
    local reset = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    reset:SetSize(dialog:GetWidth() - 53, 28)
    reset:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 22)
    reset:SetText(HUD_EDIT_MODE_RESET_POSITION or "Reset To Default Position")
    reset:SetScript("OnClick", onClick)
    ns.EditModeRed(reset)
    return reset
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

-- A stepper slider filled from init() -> value, min, max, steps under a guard, so its own Init never reaches onChange(value).
-- opts: formatters, owner (the callback's), enabled() dims it and opts.label when false. Returns the fill function.
function B.GuardedSlider(slider, init, onChange, opts)
    opts = opts or ns.EMPTY
    local formatters, enabled, label = opts.formatters, opts.enabled, opts.label
    local filling = false
    B.OnSliderValue(slider, function(_, value)
        if filling or type(value) ~= "number" then return end
        onChange(value)
    end, opts.owner)
    return function()
        filling = true
        local value, low, high, steps = init()
        slider:Init(value, low, high, steps, formatters)
        filling = false
        if not enabled then return end
        local on = enabled()
        slider:SetAlpha(on and 1 or 0.4)
        if slider.SetEnabled then pcall(slider.SetEnabled, slider, on) end
        if label then label:SetFontObject(on and "GameFontHighlightMedium" or "GameFontDisableMed3") end
    end
end
