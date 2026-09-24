local _, ns = ...
local B = ns.band

-- Action bars on the band: button rows at their 1.x spots, page arrows, pet and stance row, right columns, bars 6-8.

local ART_W, BUTTON_PITCH, PET_ROW_Y, PAGE_ROOM = B.ART_W, B.BUTTON_PITCH, B.PET_ROW_Y, B.PAGE_ROOM
local EXTRA_BARS = B.EXTRA_BARS
local BUTTON_SIZE = 36
local STANCE_X, PET_X = 30, 36
local SMALL_PITCH, SMALL_BUTTON = 33, 30    -- 30 px buttons on the pet and stance bars
local SIDE_BAR_X, SIDE_BAR_Y, SIDE_BAR_GAP = -2, 98, 6   -- right bars hang from the bottom right corner
local PAGE_X, PAGE_UP_Y, PAGE_DOWN_Y = 522, -22, -42
local Remember, BarSetting, BarVertical, BarRows = B.Remember, B.BarSetting, B.BarVertical, B.BarRows
local IconScale, BandScale, BandNow, MatchScale = B.IconScale, B.BandScale, B.BandNow, B.MatchScale
local CurrentPlan = B.CurrentPlan

-- Which row frame each bar's buttons hang on, and whether that row hangs on the bar or the band (or screen corner).
local rowOf = {}
B.rowOf = rowOf

-- A row hangs on the band while its buttons stand on it, else on the screen (a column at the screen edge, scaled by bar 1's size).
local function Row(index, parent)
    local art = B.art
    local row = art.rows[index]
    if not row then
        row = CreateFrame("Frame", nil, art)
        row:SetSize(1, 1)
        art.rows[index] = row
    end
    parent = parent or art
    if row:GetParent() ~= parent then row:SetParent(parent) end
    return row
end

-- One bar's buttons in a 1.x row or column: containers on a scaled row frame, so buttons come out 36 px (30 on pet/stance), 6 apart.
local function LayoutButtons(bar, rowIndex, point, relTo, relPoint, x, y, vertical, pitch, target, origin, rows)
    if not bar or not bar.actionButtons then return end
    local art = B.art
    local first = bar.actionButtons[1]
    local size = first and first:GetWidth() or 45
    if not size or size == 0 then size = 45 end
    local scale = (target or BUTTON_SIZE) / size
    local step = (pitch or BUTTON_PITCH) / scale
    -- Icon Size rides on the containers, as the client puts it on the buttons; the bar keeps scale 1
    -- (edit mode boxes the frame and would count the size twice), and its rectangle is what is drawn.
    local icon = IconScale(bar)
    MatchScale(bar, 1)
    local band = BandNow()
    -- A row on the band is placed in band pixels, a column off it at its own size; the step is read on the containers.
    origin = origin or band
    if origin <= 0 then origin = 1 end
    local onBand = relTo == nil or relTo == art
    local row = Row(rowIndex, onBand and art or UIParent)
    row:SetScale(onBand and (origin / band) or origin)
    ns.SetPointOnce(row, point, relTo, relPoint, x, y)
    local hung = rowOf[bar]
    if not hung then
        hung = {}
        rowOf[bar] = hung
    end
    hung.row, hung.onBar, hung.vertical = row, relTo == bar, vertical and true or false
    -- The rectangle covers the slots the bar is set to (or the buttons it has). Folded rows stack upward
    -- when horizontal, rightward when vertical.
    local slots = BarSetting(bar, "NumIcons")
    rows = math.max(1, rows or 1)
    local shown = (slots and slots > 0) and math.min(slots, #bar.actionButtons) or #bar.actionButtons
    local per = math.max(1, math.ceil(shown / rows))
    local count = 0
    for i, button in ipairs(bar.actionButtons) do
        local container = button.container
        if container then
            count = i
            Remember(container)
            container:SetScale(scale * icon)
            container:ClearAllPoints()
            local along, across = (i - 1) % per, math.floor((i - 1) / per)
            if vertical then
                container:SetPoint("TOPLEFT", row, "TOPLEFT", across * step, -along * step)
            else
                container:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", along * step, across * step)
            end
        end
    end
    -- Bar rectangle = its buttons, in whole pixels, set only on change: a size change makes the client
    -- re-lay the bar and call us back, and sub-pixel drift each pass walked the buttons.
    if slots and slots > 0 then count = math.min(count, slots) end
    if count > 0 then
        local slot = math.floor((target or BUTTON_SIZE) * icon + 0.5)
        local lines = math.ceil(count / per)
        local along = math.floor((math.min(count, per) - 1) * (step * scale * icon) + slot + 0.5)
        local thick = math.floor((lines - 1) * (step * scale * icon) + slot + 0.5)
        local wide, tall = along, thick
        if vertical then wide, tall = thick, along end
        if math.abs((bar:GetWidth() or 0) - wide) > 0.5 or math.abs((bar:GetHeight() or 0) - tall) > 0.5 then
            Remember(bar)
            bar:SetSize(wide, tall)
        end
        -- Edit mode's box sits on the buttons (the client carries a default bar's frame off mid-fight): on our
        -- frame over them, two corners, no offsets, which the client reads as filling the bar.
        local selection = bar.Selection
        if selection and selection.SetPoint and not InCombatLockdown() then
            local box = hung.box
            if not box then
                box = CreateFrame("Frame", nil, UIParent)
                hung.box = box
            end
            local corner = vertical and "TOPLEFT" or "BOTTOMLEFT"
            -- Action Bar 1's box includes the page arrows, which belong to it.
            local boxW = wide
            if bar == ns.GetMainBar() and not vertical and not ns.barMoved
                and BarSetting(bar, "HideBarScrolling") ~= 1 then
                boxW = boxW + PAGE_ROOM * band
            end
            ns.SetPointOnce(box, corner, row, corner, 0, 0)
            box:SetSize(boxW, tall)
            if not hung.boxed then
                hung.boxed = true
                selection:ClearAllPoints()
                selection:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
                selection:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
            end
        end
    end
end
B.LayoutButtons = LayoutButtons

-- A bar the player moved, turned or folded is laid out on itself, at its own size and settings.
local function LayoutOnOwnBar(bar, rowIndex, vertical, rows, pitch, target)
    local own = IconScale(bar)
    if vertical then
        LayoutButtons(bar, rowIndex, "TOPLEFT", bar, "TOPLEFT", 0, 0, true, pitch, target, own, rows)
    else
        LayoutButtons(bar, rowIndex, "BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0, false, pitch, target, own, rows)
    end
end
B.LayoutOnOwnBar = LayoutOnOwnBar

-- Bars whose own click we turned off for a fight (the client's stance bar takes clicks), to hand back after.
local clickHeld = setmetatable({}, { __mode = "k" })

-- A default bar's frame is carried off in a fight while its buttons stay: its box would drag an unseen frame and a
-- frame that takes clicks (the stance bar, level 70) lands over bar 2. Both take no clicks in a fight; player-placed
-- bars stay as they are. Runs at fight start (still allowed) and end.
function B.HoldBandBoxes(fight)
    local main = ns.GetMainBar()
    local locked = InCombatLockdown()
    for bar, hung in pairs(rowOf) do
        local onBand
        if bar == main then onBand = not ns.barMoved else onBand = not hung.onBar end
        local selection = bar.Selection
        if selection and selection.EnableMouse and not (selection.IsProtected and selection:IsProtected() and locked) then
            local want = not (fight and onBand)
            if selection:IsMouseEnabled() ~= want then selection:EnableMouse(want) end
        end
        if bar.SetMouseClickEnabled and not (bar:IsProtected() and locked) then
            if fight and onBand and bar:IsMouseClickEnabled() then
                bar:SetMouseClickEnabled(false)
                clickHeld[bar] = true
            elseif not fight and clickHeld[bar] then
                bar:SetMouseClickEnabled(true)
                clickHeld[bar] = nil
            end
        end
    end
end

-- Boxes back on their bars, as the client has them.
function B.RestoreSelections()
    for bar in pairs(clickHeld) do
        if not (bar:IsProtected() and InCombatLockdown()) then
            bar:SetMouseClickEnabled(true)
            clickHeld[bar] = nil
        end
    end
    for bar, hung in pairs(rowOf) do
        if hung.boxed and bar.Selection then
            hung.boxed = nil
            bar.Selection:ClearAllPoints()
            bar.Selection:SetAllPoints(bar)
            if not bar.Selection:IsMouseEnabled() then bar.Selection:EnableMouse(true) end
        end
    end
end

-- Micro and bag buttons stand over the main bar frame, which takes the mouse and edit mode can raise to level 50.
function B.ButtonLevel()
    local bar = ns.GetMainBar()
    return math.max(B.art:GetFrameLevel() + 20, (bar and bar:GetFrameLevel() or 0) + 10)
end

local function Anchor(frame, point, relPoint, x, y, scale)
    -- A locked frame is the client's to move in a fight.
    if not frame or (InCombatLockdown() and frame:IsProtected()) then return end
    Remember(frame)
    ns.SetPointOnce(frame, point, B.art, relPoint, x, y)
    if scale then ns.SetScaleIf(frame, scale) end
end
B.Anchor = Anchor

local function PlaceArrow(button, w, h, hitX, hitY, rel, relPoint, x, y)
    button:SetSize(w, h)
    button:SetHitRectInsets(hitX, hitX, hitY, hitY)
    ns.SetPointOnce(button, "CENTER", rel, relPoint, x, y)
end

-- Page arrows (w x h, hit insets) centred on rel at x/upY/downY; page number text in font at textX, textY.
function B.PlacePageArrows(pn, w, h, hitX, hitY, rel, relPoint, x, upY, downY, font, textX, textY)
    if pn.UpButton then PlaceArrow(pn.UpButton, w, h, hitX, hitY, rel, relPoint, x, upY) end
    if pn.DownButton then PlaceArrow(pn.DownButton, w, h, hitX, hitY, rel, relPoint, x, downY) end
    if pn.Text then
        pn.Text:SetFontObject(font)
        ns.SetPointOnce(pn.Text, "CENTER", rel, relPoint, textX, textY)
    end
end

-- Page number and arrows on the band corner, 32 px like 1.x, number beside the arrows.
function B.LayoutPageArrows(bar)
    local pn = bar.ActionBarPageNumber
    if not pn then return end
    local art = B.art
    local pageX = CurrentPlan().base + (PAGE_X - ART_W / 2)
    local midY = (PAGE_UP_Y + PAGE_DOWN_Y) / 2
    ns.SetPointOnce(pn, "CENTER", art, "TOPLEFT", pageX, midY)
    pn:SetSize(32, 76)
    pn:SetScale(BandNow())
    -- Above the band, so its art never covers the number or arrows.
    pn:SetFrameStrata("HIGH")
    -- Hide Bar Scrolling: the client hides them for it.
    pn:SetShown(BarSetting(bar, "HideBarScrolling") ~= 1)
    B.PlacePageArrows(pn, 32, 32, 6, 7, art, "TOPLEFT", pageX, PAGE_UP_Y, PAGE_DOWN_Y, "GameFontNormalSmall",
        pageX + 20, midY + 0.5)
end

-- A default-placed bar gets its 1.x row; one the player moved, turned or folded is laid out on itself.
local function BandRow(bar, rowIndex, x, y, pitch, target)
    if not bar then return false end
    local vertical, rows = BarVertical(bar) == true, BarRows(bar)
    if B.SystemMoved(bar) or vertical or rows > 1 then
        LayoutOnOwnBar(bar, rowIndex, vertical, rows, pitch, target)
        return false
    end
    local band = BandNow()
    Anchor(bar, "BOTTOMLEFT", "BOTTOMLEFT", x * band, y * band, 1)
    LayoutButtons(bar, rowIndex, "BOTTOMLEFT", B.art, "BOTTOMLEFT", x, y, false, pitch, target)
    return true
end
B.BandRow = BandRow

-- Stance (or possess) bar at the left, pet bar beside it, both over bars 2 and 3 as in 1.x.
function B.LayoutPetRow(lift)
    local x = STANCE_X
    local y = PET_ROW_Y + (lift or 0)
    for _, bar in ipairs({ StanceBar, PossessActionBar }) do
        if bar then
            local pinned = BandRow(bar, bar == StanceBar and 4 or 5, x, y, SMALL_PITCH, SMALL_BUTTON)
            if pinned and bar:IsShown() and bar.actionButtons then
                -- A bar larger than the band pushes the next one out by its growth.
                local grown = math.max(1, IconScale(bar) / BandScale())
                x = x + (#bar.actionButtons * SMALL_PITCH + 8) * grown
            end
        end
    end
    if PetActionBar then
        BandRow(PetActionBar, 6, math.max(PET_X, x), y, SMALL_PITCH, SMALL_BUTTON)
    end
end

-- Bars 4 and 5 down the right edge, hung from the bottom-right corner 98 up as in 1.x (column ends below the minimap).
-- Buttons hang from the corner, not the bar: edit mode re-anchors right bars whenever the room by the minimap
-- changes (entering combat too) and the column jumped. A bar placed in edit mode keeps its spot and buttons.
local SIDE_COL_H = 12 * BUTTON_PITCH

local function SideColumn(bar, rowIndex, x)
    if not bar then return false end
    local vertical, rows = BarVertical(bar) ~= false, BarRows(bar)
    if B.SystemMoved(bar) or not vertical or rows > 1 then
        LayoutOnOwnBar(bar, rowIndex, vertical, rows)
        return false
    end
    Remember(bar)
    ns.SetScaleIf(bar, 1)
    -- Frame starts at the first button and spans the buttons, so edit mode's box is the column itself.
    local icon = IconScale(bar)
    ns.SetPointOnce(bar, "TOPRIGHT", UIParent, "BOTTOMRIGHT", x * icon, (SIDE_BAR_Y + SIDE_COL_H) * icon)
    LayoutButtons(bar, rowIndex, "TOPLEFT", UIParent, "BOTTOMRIGHT", x - BUTTON_SIZE, SIDE_BAR_Y + SIDE_COL_H, true, nil, nil, icon)
    return true
end

function B.LayoutSideBars()
    local right, left = MultiBarRight, MultiBarLeft
    local rightPinned = SideColumn(right, 7, SIDE_BAR_X)
    local leftX = SIDE_BAR_X
    if rightPinned and right:IsShown() then
        -- Beside the first: its width in the second's pixels, less the gap.
        local ratio = IconScale(right) / IconScale(left)
        leftX = (SIDE_BAR_X - BUTTON_SIZE) * ratio - SIDE_BAR_GAP
    end
    SideColumn(left, 8, leftX)
end

-- Bars 6-8 are enabled in the game's Settings (Action Bars). Our toggle hides them; enabling any there turns the
-- toggle off. Never written: the client's apply is refused to addons (blocked). Faded and click-free, keybinds still work.
local EXTRA_SETTINGS = { "PROXY_SHOW_ACTIONBAR_6", "PROXY_SHOW_ACTIONBAR_7", "PROXY_SHOW_ACTIONBAR_8" }

local function ExtraBarsEnabledInSettings()
    if not Settings or not Settings.GetValue then return false end
    for _, var in ipairs(EXTRA_SETTINGS) do
        local ok, value = pcall(Settings.GetValue, var)
        if ok and value then return true end
    end
    return false
end

local function LayoutExtraBars(hide)
    for _, name in ipairs(EXTRA_BARS) do
        local bar = _G[name]
        if bar then
            bar:SetAlpha(hide and 0 or 1)
            if not InCombatLockdown() then
                for _, button in ipairs(bar.actionButtons or {}) do
                    button:EnableMouse(not hide)
                end
            end
        end
    end
end
B.LayoutExtraBars = LayoutExtraBars

-- A bar enabled in Settings while the toggle hides them was wanted: toggle off.
function B.FollowSettings()
    if not B.active or not ns.db or not ns.db.hideExtraBars then return end
    if ExtraBarsEnabledInSettings() then
        ns.db.hideExtraBars = false
        LayoutExtraBars(false)
        if ns.RefreshOptionsWindow then ns.RefreshOptionsWindow() end
    end
end

-- Bottom managed frames stand over the (emptied) micro menu, mid bar 1, and took its mouse: stood over the band instead.
local BOTTOM_MARGIN = 15

-- A shown frame's top in UIParent units, or 0.
local function TopOf(frame)
    if not frame or not frame:IsShown() then return 0 end
    local top = frame:GetTop()
    if not top then return 0 end
    return top * frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function BandTop()
    local art = B.art
    local top = TopOf(art)
    for bar, hung in pairs(rowOf) do
        if hung.row and hung.row:GetParent() == art then top = math.max(top, TopOf(bar)) end
    end
    for _, holder in ipairs(B.StatusPair()) do
        if holder and B.OnBand(holder) then top = math.max(top, TopOf(holder)) end
    end
    for _, button in ipairs(B.MicroButtonList and B.MicroButtonList() or {}) do
        if button:GetParent() == art then top = math.max(top, TopOf(button)) end
    end
    for _, name in ipairs(B.BAG_BUTTONS) do
        local button = _G[name]
        if button and button:GetParent() == art then top = math.max(top, TopOf(button)) end
    end
    return top
end

-- Puts the container back on our spot if the client moved it; returns it when moved. Never in combat while protected.
function B.KeepBottomContainer()
    local want = B.bottomWant
    local frame = BottomManagedFrameContainer
    if not (want and B.active and frame) then return nil end
    if InCombatLockdown() and frame:IsProtected() then return nil end
    local scale = frame:GetScale() or 1
    if scale <= 0 then scale = 1 end
    local y = want / scale
    local point, rel, relPoint, x, py = frame:GetPoint(1)
    if frame:GetNumPoints() == 1 and point == "BOTTOM" and rel == UIParent and relPoint == "BOTTOM"
        and math.abs(x or 0) < 0.05 and math.abs((py or 0) - y) < 0.05 then
        return nil
    end
    ns.SetPointOnce(frame, "BOTTOM", UIParent, "BOTTOM", 0, y)
    return frame
end

-- End of the full pass: the container's spot from the band as laid.
function B.PlaceBottomContainer()
    if not B.active or not B.art or InCombatLockdown() then return end
    -- A placed bar 1 is out of the client's bottom stack too; a band dragged to the screen top would lift the container off screen.
    if ns.barMoved then
        B.bottomWant = nil
        -- The roll watch runs only while the rolls are up: they go back now.
        B.RollsBack()
        return
    end
    local top = BandTop()
    B.bottomWant = top > 0 and math.floor(top + BOTTOM_MARGIN + 0.5) or nil
    if not B.bottomWant then B.RollsBack() end
    B.KeepBottomContainer()
end
