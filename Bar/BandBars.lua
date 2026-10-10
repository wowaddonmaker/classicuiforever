local _, ns = ...
local B = ns.band

-- Action bars on the band: button rows at their 1.x spots, page arrows, pet and stance row, right columns, bars 6-8.

local ART_W, BUTTON_PITCH, PET_ROW_Y, PAGE_ROOM = B.ART_W, B.BUTTON_PITCH, B.PET_ROW_Y, B.PAGE_ROOM
local BUTTON_SIZE = 36
local STANCE_X, PET_X = 30, 36
local SMALL_PITCH, SMALL_BUTTON = 33, 30    -- 30 px buttons on the pet and stance bars
local SIDE_BAR_X, SIDE_BAR_Y, SIDE_BAR_GAP = -2, 98, 6   -- right bars hang from the bottom right corner
local PAGE_X, PAGE_UP_Y, PAGE_DOWN_Y = 522, -22, -42
local PAGE_OVER_BUTTONS = 2
local Remember, BarSetting, BarVertical, BarRows = B.Remember, B.BarSetting, B.BarVertical, B.BarRows
local IconScale, BandScale, BandNow, MatchScale = B.IconScale, B.BandScale, B.BandNow, B.MatchScale
local CurrentPlan = B.CurrentPlan

-- Which row frame each bar's buttons hang on, and whether that row hangs on the bar or the band (or screen corner).
local rowOf = {}
B.rowOf = rowOf

-- Each button stands in a slot of ours under its bar, moved there once by a secure snippet: the client re-lays and
-- rescales its own containers (layout applies, stance count changes, in fights too) and never touches ours.
local slotOf = setmetatable({}, { __mode = "k" })
local mover
local MOVE = [[
    local button, home = self:GetFrameRef("button"), self:GetFrameRef("home")
    button:SetParent(home)
    button:SetFrameLevel(home:GetFrameLevel() + 1)
    button:ClearAllPoints()
    button:SetPoint("CENTER", home, "CENTER", 0, 0)
]]

local function Move(button, home)
    if not mover then mover = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate") end
    mover:SetFrameRef("button", button)
    mover:SetFrameRef("home", home)
    local ok, err = pcall(mover.Execute, mover, MOVE)
    if not ok then geterrorhandler()(err) end
end

-- Each bar's slots hang on a holder of ours on the screen, never on the bar: the client rescales, moves and hides its
-- bar frames (edit mode re-lays them on every grid show, in fights too). The holder copies the bar's show rules.
local holderOf, driverOf = {}, {}
local VISIBILITY = { InCombat = "[combat] show; hide", OutOfCombat = "[combat] hide; show" }

local function Driver(bar)
    if bar == PetActionBar then return "[petbattle][overridebar][vehicleui][possessbar] hide; [@pet,exists] show; hide" end
    if bar == PossessActionBar then return "[possessbar] show; hide" end
    if bar == StanceBar and ns.db and ns.db.hideStanceBar then return "hide" end
    local main = bar == ns.GetMainBar()
    local on = main or bar.isShownExternal
    if on == nil then on = bar:IsShown() end
    if not on or bar.visibility == "Hidden" then return "hide" end
    local lead = (main or bar == StanceBar) and "[petbattle][overridebar][vehicleui] hide; " or "[petbattle] hide; "
    return lead .. (VISIBILITY[bar.visibility] or "show")
end

-- Out of combat: strata and show rules follow the bar's as the layout runs.
-- Bars whose own mouse we turned off (given back on the band's hand-back).
local mouseOff = {}

local function Holder(bar)
    local holder = holderOf[bar]
    if not holder then
        holder = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
        holder:SetAllPoints(UIParent)
        holderOf[bar] = holder
    end
    -- At the bar's own alpha.
    holder:SetAlpha(bar:GetAlpha())
    if not InCombatLockdown() then
        -- A spell drag lifts the bar to TOOLTIP for the drop: never copied, and its frame takes no mouse, or the lifted empty
        -- frame over our slots eats the drop (bar 1 is mouse-enabled).
        local strata = bar:GetFrameStrata()
        if strata ~= "TOOLTIP" then ns.SetStrataIf(holder, strata) end
        if bar:IsMouseEnabled() then
            bar:EnableMouse(false)
            mouseOff[bar] = true
        end
        local driver = Driver(bar)
        if driverOf[bar] ~= driver then
            driverOf[bar] = driver
            RegisterStateDriver(holder, "visibility", driver)
        end
    end
    return holder
end

-- The button's slot, the button moved into it first; out of combat only, as the layout runs. Explicitly protected:
-- a snippet's SetParent takes no other frame as the new parent.
local function Slot(button, bar)
    local holder = Holder(bar)
    local slot = slotOf[button]
    if not slot then
        slot = CreateFrame("Frame", nil, holder, "SecureFrameTemplate")
        slot:SetSize(button:GetWidth(), button:GetHeight())
        slotOf[button] = slot
    elseif slot:GetParent() ~= holder then
        slot:SetParent(holder)
    end
    if button:GetParent() ~= slot then Move(button, slot) end
    -- The toggled border over the client's frame art: both on OVERLAY 0, the art could draw last and cut its top and
    -- left edges (bars 2 and 3's AddRow art hangs from the top left).
    local checked = button.GetCheckedTexture and button:GetCheckedTexture()
    if checked then checked:SetDrawLayer("OVERLAY", 1) end
    return slot
end

-- Band off (out of combat): every button back in the client's container, where its own layout has it. Plain calls:
-- the containers are not explicitly protected, so a snippet cannot parent to them.
function B.ButtonsHome()
    for button in pairs(slotOf) do
        local container = button.container
        if container and button:GetParent() ~= container then
            button:SetParent(container)
            button:SetFrameLevel(container:GetFrameLevel() + 1)
            ns.SetPointOnce(button, "CENTER", container, "CENTER", 0, 0)
        end
        local checked = button.GetCheckedTexture and button:GetCheckedTexture()
        if checked then checked:SetDrawLayer("OVERLAY", 0) end
    end
    for bar in pairs(mouseOff) do bar:EnableMouse(true) end
    wipe(mouseOff)
end

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
    -- Icon Size rides on the slots, as the client puts it on its containers; the bar keeps scale 1
    -- (edit mode boxes the frame and would count the size twice), and its rectangle is what is drawn.
    local icon = IconScale(bar)
    MatchScale(bar, 1)
    local band = BandNow()
    -- A row on the band is placed in band pixels, a column off it at its own size; the step is read on the slots.
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
    -- Over the gryphons and over this bar's own frame, which takes the mouse (edit mode lifts a bar's level and the
    -- stance and pet bars stand higher than bar 1): a slot under its bar hid its button from the mouse.
    local level = math.max(B.ButtonLevel(), bar:GetFrameLevel() + 2)
    for i, button in ipairs(bar.actionButtons) do
        count = i
        local slot = Slot(button, bar)
        ns.SetLevelIf(slot, level)
        slot:SetScale(scale * icon)
        slot:ClearAllPoints()
        local along, across = (i - 1) % per, math.floor((i - 1) / per)
        if vertical then
            slot:SetPoint("TOPLEFT", row, "TOPLEFT", across * step, -along * step)
        else
            slot:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", along * step, across * step)
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
        -- Edit mode's box stays on the bar: the client clamps the bar by the gap between them, and one hung
        -- elsewhere shoved the frame off its anchor. Action Bar 1's also covers the page arrows, which belong to it.
        local selection = bar.Selection
        if selection and selection.SetPoint and not InCombatLockdown() then
            local pages = 0
            if bar == ns.GetMainBar() and not vertical and not ns.barMoved
                and BarSetting(bar, "HideBarScrolling") ~= 1 then
                pages = PAGE_ROOM * band
            end
            if hung.boxed ~= pages then
                hung.boxed = pages
                selection:ClearAllPoints()
                selection:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
                selection:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", pages, 0)
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
    -- Over the band's buttons but in their layer: a window or the full map that covers the bars covers these too.
    ns.SetStrataIf(pn, "MEDIUM")
    ns.SetLevelIf(pn, B.ButtonLevel() + PAGE_OVER_BUTTONS)
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

-- The pet and stance row's top on the band (UIParent units), shown or not: the classic chat stands over it.
function B.PetRowTop()
    local top
    for _, bar in ipairs({ StanceBar, PetActionBar, PossessActionBar }) do
        local first, hung = bar and bar.actionButtons and bar.actionButtons[1], rowOf[bar]
        local slot = first and hung and not hung.onBar and slotOf[first]
        local t = slot and slot:GetTop()
        if t then
            t = t * slot:GetEffectiveScale() / UIParent:GetEffectiveScale()
            if not top or t > top then top = t end
        end
    end
    return top
end

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
-- Bottom managed frames stand over the (emptied) micro menu, mid bar 1, and took its mouse: stood over the band instead.
local BOTTOM_MARGIN = 15

-- A shown frame's top in UIParent units, or 0.
local function TopOf(frame)
    if not frame or not frame:IsShown() then return 0 end
    local top = frame:GetTop()
    if not top then return 0 end
    return top * frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

-- A band bar by its buttons' slot: the client carries the bar frame off (a fight, the totem bar) while they stay.
local function BarTop(bar)
    local first = bar.actionButtons and bar.actionButtons[1]
    local slot = first and slotOf[first]
    if slot and slot:IsVisible() then return TopOf(slot) end
    return TopOf(bar)
end

local function BandTop()
    local art = B.art
    local top = TopOf(art)
    for bar, hung in pairs(rowOf) do
        if hung.row and hung.row:GetParent() == art then top = math.max(top, BarTop(bar)) end
    end
    for _, holder in ipairs(B.StatusPair()) do
        if holder and B.OnBand(holder) then top = math.max(top, TopOf(holder)) end
    end
    -- A moved group keeps the band as parent: only one standing on it counts, or the stack rose with a moved menu.
    local shape = B.shape
    if shape.micro then
        for _, button in ipairs(B.MicroButtonList and B.MicroButtonList() or {}) do
            if button:GetParent() == art then top = math.max(top, TopOf(button)) end
        end
    end
    if shape.bags then
        for _, name in ipairs(B.BAG_BUTTONS) do
            local button = _G[name]
            if button and button:GetParent() == art then top = math.max(top, TopOf(button)) end
        end
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
        return
    end
    local top = BandTop()
    B.bottomWant = top > 0 and math.floor(top + BOTTOM_MARGIN + 0.5) or nil
    B.KeepBottomContainer()
end
