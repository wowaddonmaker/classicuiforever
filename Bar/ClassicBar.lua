local _, ns = ...
local B = ns.band

-- The band's pass and module: what is still on the band, the layout, and the hand-back when turned off.

local BUTTON_PITCH, ROW_X, ROW_Y, PET_ROW_Y = B.BUTTON_PITCH, B.ROW_X, B.ROW_Y, B.PET_ROW_Y
local MICRO_END_GAP, MICRO_LEAD, MICRO_REGION_MAX = B.MICRO_END_GAP, B.MICRO_LEAD, B.MICRO_REGION_MAX
local OWNED_SYSTEMS, EXTRA_BARS = B.OWNED_SYSTEMS, B.EXTRA_BARS
local MICRO_BUTTONS, BAG_BUTTONS, CAP_KEYS = B.MICRO_BUTTONS, B.BAG_BUTTONS, B.CAP_KEYS
local UPPER_ROW_Y = 55 -- bars 2 and 3: 3 px over the XP strip, inside the band's top
local TWO_BAR_LIFT = 9 -- lift for everything over the band while a second bar sits over XP
local BarSetting, BarVertical, BarRows, IconScale = B.BarSetting, B.BarVertical, B.BarRows, B.IconScale
local BandScale, BandNow, StatusPair = B.BandScale, B.BandNow, B.StatusPair
local OneBar, MicroOut, MicroUserScale, BandPlan = B.OneBar, B.MicroOut, B.MicroUserScale, B.BandPlan
local OnBandMicro, OnBandBags, ArtWidth, HomeSpot, DropPlace = B.OnBandMicro, B.OnBandBags, B.ArtWidth, B.HomeSpot, B.DropPlace
local CurrentPlan = B.CurrentPlan
local BuildArt, PaintArt, ApplyArtShape, CapFrame = B.BuildArt, B.PaintArt, B.ApplyArtShape, B.CapFrame
local LayoutButtons, LayoutOnOwnBar, BandRow, LayoutPetRow = B.LayoutButtons, B.LayoutOnOwnBar, B.BandRow, B.LayoutPetRow
local LayoutSideBars, LayoutExtraBars, LayoutPageArrows = B.LayoutSideBars, B.LayoutExtraBars, B.LayoutPageArrows
local RestoreSelections, PlacePageArrows = B.RestoreSelections, B.PlacePageArrows
local Remember, BaseSetters = B.Remember, ns.BaseSetters
local LayoutBags, MicroButtonList, MicroPlan, LayoutMicroButtons = B.LayoutBags, B.MicroButtonList, B.MicroPlan, B.LayoutMicroButtons
local HasVisibleBar, LayoutStatusBars, SetDividers, RecolorExpBars = B.HasVisibleBar, B.LayoutStatusBars, B.SetDividers, B.RecolorExpBars
local SystemMoved, Snapshot, StartWatch, SetLane = B.SystemMoved, B.Snapshot, B.StartWatch, B.SetLane
local FadeTextures = ns.FadeTextures

-- Whether the bags were off the bar at the last pass; nil before the first.
local bagsWereOut

-- The band follows Action Bar 1 instead of centring only after a player drag in edit mode with the band on
-- (ns.db.barDragged, cleared by the bar's reset); edit mode's flag alone shifted the band, since old layouts
-- or any anchor change leave the bar flagged with a stale anchor.
local function BarMoved(bar)
    if not ns.db.barDragged then return false end
    return SystemMoved(bar)
end

-- Hook point for the dev addon to inspect the finished layout.
local function AfterLayout()
    if ns.OnBarLaid then ns.OnBarLaid() end
end

-- What is still on the band, read at the head of every pass.
local function ReadShape()
    local shape, dragPreview = B.shape, B.dragPreview
    shape.micro = not MicroOut()
    -- On the band when the layout has them at default, or dropped on the band and held there by our record.
    local bagsMoved = BagsBar and SystemMoved(BagsBar)
    if not bagsMoved and ns.db.bagsHeld then ns.db.bagsHeld = false end
    shape.bags = (not bagsMoved) or ns.db.bagsHeld == true
    local count, sized = B.MicroCounts()
    local _, region = MicroPlan(count, MicroUserScale(), sized)
    local raw = math.max(MICRO_LEAD + MICRO_END_GAP, math.min(MICRO_REGION_MAX, region))
    -- A new row size is measured again (BandMicro FitRegion).
    if shape.regionRaw ~= raw then shape.regionRaw, shape.microTrim = raw, 0 end
    shape.region = math.max(MICRO_LEAD + MICRO_END_GAP, raw - (shape.microTrim or 0))
    shape.bagsReal, shape.microReal = shape.bags, shape.micro
    shape.noPages = BarSetting(ns.GetMainBar(), "HideBarScrolling") == 1
    local icons = BarSetting(ns.GetMainBar(), "NumIcons")
    if not icons or icons < 1 or icons > 12 then icons = 12 end
    shape.cut = (12 - math.floor(icons + 0.5)) * BUTTON_PITCH
    -- Bags dropped near a band spot go into it, judged before any preview. No layout write (it marks every piece as
    -- ours): our record holds them, and the size they wore reads as socket size.
    if B.bagsDropped then
        B.bagsDropped = false
        local showing = dragPreview.bagsFirst
        dragPreview.bags, dragPreview.bagsFirst = nil, nil
        -- Only when the bags were the piece in hand.
        if B.bagsInHand and BagsBar and not InCombatLockdown() then
            local place = DropPlace("bags", BagsBar, showing)
            if place ~= nil then
                ns.db.bagsHeld = true
                ns.db.bagsSnapScale = BagsBar:GetScale() or 1
                shape.bags, shape.bagsReal = true, true
                ns.MicroTouched()
                ns.db.bagsFirst = place
            else
                ns.db.bagsHeld = false
                ns.db.bagsSnapScale = 0
                shape.bags = not SystemMoved(BagsBar)
                shape.bagsReal = shape.bags
            end
        end
        B.bagsInHand = false
    end
    -- Back on the bar by any route (Reset To Default Position keeps their Size): the size they return with reads as
    -- socket size, without a write; an oversized row was squeezed into the sockets.
    if shape.bagsReal and bagsWereOut and BagsBar and math.abs((BagsBar:GetScale() or 1) - 1) > 0.001 then
        ns.db.bagsSnapScale = BagsBar:GetScale() or 1
    end
    bagsWereOut = not shape.bagsReal
    local bagsFirst = ns.db and ns.db.bagsFirst
    if dragPreview.micro ~= nil then shape.micro = dragPreview.micro end
    if dragPreview.bags ~= nil then shape.bags = dragPreview.bags end
    if dragPreview.bagsFirst ~= nil then bagsFirst = dragPreview.bagsFirst end
    shape.plan = BandPlan(OnBandMicro(), OnBandBags(), bagsFirst, shape.region)
end
B.ReadShape = ReadShape

local function Layout()
    local bar = ns.GetMainBar()
    if not bar then return end
    local art = B.art
    ReadShape()
    -- Edit mode owns Action Bar 1's scale and, once dragged, its spot; the band takes the same scale and anchors so
    -- the bar's rectangle is its twelve buttons: a drag moves the whole band and its dialog works.
    art:SetScale(BandScale(bar))
    art:ClearAllPoints()
    local moved = BarMoved(bar)
    ns.barMoved = moved
    -- At its default place the bar goes where the band's centred spot needs it (offsets in screen px: it keeps scale 1).
    if not moved then
        -- The client's own anchor, kept for the hand-back.
        Remember(bar)
        ns.SetPointOnce(bar, "BOTTOMLEFT", UIParent, "BOTTOM", HomeSpot(BandNow()))
    end
    -- Default place: the band stands on the screen (the client carries bar 1 off mid-fight; its buttons hang on the band);
    -- it follows bar 1 only while dragged or once placed.
    if moved or bar.isDragging then
        art:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -ROW_X, -ROW_Y)
    else
        art:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", (ns.db.barOffsetX or 0) - ArtWidth() / 2, ns.db.barOffsetY or 0)
    end
    art:Show()
    PaintArt()
    ApplyArtShape(bar)
    -- The client's end caps stay up as edit mode handles, their art faded.
    if bar.BorderArt then bar.BorderArt:SetAlpha(0) end
    if bar.HorizontalDividersPool then bar.HorizontalDividersPool:ReleaseAll() end
    if bar.VerticalDividersPool then bar.VerticalDividersPool:ReleaseAll() end
    LayoutButtons(bar, 1, "BOTTOMLEFT", art, "BOTTOMLEFT", ROW_X, ROW_Y)
    LayoutPageArrows(bar)

    local lower, upper = MultiBarBottomLeft, MultiBarBottomRight
    -- A faction bar over XP lifts everything over the band by 9, as 1.x did; only while both stand on the band.
    local twoBars = HasVisibleBar(MainStatusTrackingBarContainer) and HasVisibleBar(SecondaryStatusTrackingBarContainer)
        and not SystemMoved(MainStatusTrackingBarContainer) and not SystemMoved(SecondaryStatusTrackingBarContainer)
    local barLift = twoBars and TWO_BAR_LIFT or 0
    -- 1.x spots are band px; a row larger than the band pushes the next out by its growth, as the client stacks by
    -- real sizes. Band size comes from the setting like the rows', so equal compares equal.
    local band = BandScale(bar)
    local lowerY = UPPER_ROW_Y + barLift
    local lowerOn = BandRow(lower, 2, ROW_X, lowerY) and lower:IsShown()
    local lowerRatio = IconScale(lower) / band
    local upperY, upperOn
    -- Bar 3 beside bar 2 on the full band; over it on the half band, the pet row moving up.
    if OneBar() then
        upperY = UPPER_ROW_Y + BUTTON_PITCH + barLift
        if lowerOn then upperY = math.max(upperY, lowerY + BUTTON_PITCH * lowerRatio) end
        upperOn = BandRow(upper, 3, ROW_X, upperY)
    else
        local upperX = CurrentPlan().base + 8
        -- Only a bar 2 larger than the band pushes bar 3 on: its slots plus the 1.x gap after its last, at its own size.
        if lowerOn and lowerRatio > 1 then
            local count = #(lower.actionButtons or {})
            local slots = BarSetting(lower, "NumIcons")
            if slots and slots > 0 then count = math.min(count, slots) end
            upperX = math.max(upperX, ROW_X + (count * BUTTON_PITCH + 8) * lowerRatio)
        end
        upperY = lowerY
        upperOn = BandRow(upper, 3, upperX, upperY)
    end
    -- The stance and pet row keeps its 1.x distance over the taller row under it.
    local petLift = (OneBar() and BUTTON_PITCH or 0) + barLift
    local rise = PET_ROW_Y - UPPER_ROW_Y
    if lowerOn then petLift = math.max(petLift, lowerY + rise * lowerRatio - PET_ROW_Y) end
    if upperOn and upper:IsShown() then
        petLift = math.max(petLift, upperY + rise * IconScale(upper) / band - PET_ROW_Y)
    end
    LayoutPetRow(petLift)
    LayoutSideBars()
    -- Bars 6-8 have no band spot. Left to the client they were spaced by its Icon Padding (2 between 45) and the 1.x rings
    -- (drawn for 6 between 36) overlapped at any size: laid out on their own frames like a placed bar, at their own size and 1.x spacing.
    for i, name in ipairs(EXTRA_BARS) do
        local extra = _G[name]
        if extra and extra.actionButtons then
            LayoutOnOwnBar(extra, 8 + i, BarVertical(extra) == true, BarRows(extra))
        end
    end
    LayoutExtraBars(ns.db.hideExtraBars)
    ns.HookGlobal("MultiActionBar_Update", B.FollowSettings)
    LayoutBags()
    LayoutMicroButtons()
    LayoutStatusBars()
    B.PlaceBottomContainer()
    AfterLayout()
end

-- Moves protected frames: out of combat only (every caller already checks). Stays applied in edit mode so its preview is the classic bar.
local function Apply()
    if InCombatLockdown() then return end
    if not B.art then
        BuildArt()
        B.WatchRolls()
    end
    B.active = true
    ns.db.bandHandedBack = nil
    SetLane(true)
    B.applying = true
    ns.bandPasses = (ns.bandPasses or 0) + 1
    local ok, err = pcall(Layout)
    B.applying = false
    Snapshot()
    if not ok then geterrorhandler()(err) end
end
B.Apply = Apply

function ns.ClassicBarActive() return B.active end

-- Base calls only: the client's wrappers write a snap note its own passes read back in our name.
local function PutBackSaved(art)
    local saved = B.saved
    -- State layout: Remember in Band.lua.
    for frame, state in pairs(saved) do
        local setScale = BaseSetters(frame)
        if state[1] then setScale(frame, state[1]) end
        if frame:GetParent() == art and state[2] then
            -- One pcall per button: the menu re-lays as each returns and a placeless one errored, cutting the hand-back short.
            pcall(frame.SetParent, frame, state[2])
        end
        if state[3] and state[3] > 0 then frame:SetSize(state[3], state[4]) end
    end
    -- All lifted before any goes back: a frame hung on another still on our anchors could loop.
    for frame, state in pairs(saved) do
        if state[5] ~= nil then
            local _, clearPoints = BaseSetters(frame)
            clearPoints(frame)
        end
    end
    -- Back on the client's own anchors, one pcall each: two saved at different times could loop and leave the rest unanchored.
    for frame, state in pairs(saved) do
        local _, _, setPoint = BaseSetters(frame)
        for i = 5, #state, 5 do
            pcall(setPoint, frame, state[i], state[i + 1] or nil, state[i + 2], state[i + 3], state[i + 4])
        end
    end
    wipe(saved)
end

-- Row buttons in their own skins again.
local function UnskinRows()
    for _, button in ipairs(MicroButtonList()) do
        ns.UnskinMicroButton(button)
    end
    for _, name in ipairs(BAG_BUTTONS) do
        if _G[name] then ns.UnskinBagButton(_G[name]) end
    end
    if CharacterReagentBag0Slot then
        ns.UnskinBagButton(CharacterReagentBag0Slot)
        ns.UnskinKeyRing(CharacterReagentBag0Slot)
        -- Unseen on our row (frame alpha, and the regions its own SetAlpha fans out to); the client's bar shows it always.
        CharacterReagentBag0Slot:SetAlpha(1)
        ns.SetFrameAlphaIf(CharacterReagentBag0Slot, 1)
        CharacterReagentBag0Slot:EnableMouse(true)
    end
    if KeyRingButton then ns.UnskinKeyRing(KeyRingButton) end
    B.KeyRingBack()
    B.BagDividers(1)
    -- Give every micro button a place before any goes home: the client re-lays its menu as each returns, measuring from its
    -- end buttons, and one with no place (the help button 1.x never showed) errored ("attempt to compare nil with number").
    for _, name in ipairs(MICRO_BUTTONS) do
        local button = _G[name]
        if button and button.GetCenter and not button:GetCenter() then
            ns.SetPointOnce(button, "CENTER", MicroMenu or UIParent, "CENTER", 0, 0)
        end
    end
end

-- The client's own art on bar 1, the micro menu, the bags and the tracking bars.
local function ClientArtBack(bar)
    if ns.WorldMapMicroButton then ns.WorldMapMicroButton:Hide() end
    if bar then
        if bar.BorderArt then bar.BorderArt:SetAlpha(1) end
        for _, key in ipairs(CAP_KEYS) do
            local cap = CapFrame(bar, key)
            if cap then FadeTextures(cap, 1) end
            local client = B.ClientCapTexture(bar, key)
            if client then client:SetAlpha(1) end
        end
        if bar.UpdateEndCaps then bar:UpdateEndCaps(bar.hideBarArt) end
        if bar.UpdateDividers then bar:UpdateDividers() end
    end
    if StoreMicroButton then StoreMicroButton:SetAlpha(1) end
    if MicroMenu then
        if MicroMenu.BorderArt then MicroMenu.BorderArt:SetAlpha(1) end
        if MicroMenu.BackgroundArt then MicroMenu.BackgroundArt:SetAlpha(1) end
        if MicroMenu.Layout then pcall(MicroMenu.Layout, MicroMenu) end
    end
    if BagsBar then
        if BagsBar.BorderArt then BagsBar.BorderArt:SetAlpha(1) end
        if BagsBar.Layout then pcall(BagsBar.Layout, BagsBar) end
    end
    if BagBarExpandToggle then BagBarExpandToggle:Show() end
    for _, container in ipairs(StatusPair()) do
        if container then
            container:SetAlpha(1)
            if container.BarFrameTexture then container.BarFrameTexture:SetAlpha(1) end
            SetDividers(container, 1)
            for _, b in pairs(container.bars or {}) do
                if b.StatusBar and b.StatusBar.fcuiStrips then
                    for _, tex in ipairs(b.StatusBar.fcuiStrips) do tex:Hide() end
                end
            end
        end
    end
end

-- Page number and arrows back where the client's file has them, off bar 1's left end (left on the band corner they sat
-- over bar 1's last buttons, half below the screen).
local function PageNumberBack(bar)
    local pn = bar and bar.ActionBarPageNumber
    if not pn then return end
    pn:SetFrameStrata(bar:GetFrameStrata())
    pn:SetScale(1)
    ns.SetPointOnce(pn, "BOTTOMRIGHT", bar, "BOTTOMLEFT", -4, 9)
    PlacePageArrows(pn, 17, 14, 0, 0, pn, "CENTER", 0, 10, -10, "GameFontNormal", -1, 0)
    if pn.Layout then pcall(pn.Layout, pn) end
    -- As the setting says, not by the client's method: that marks bar 1's art dirty in our name.
    pn:SetShown(BarSetting(bar, "HideBarScrolling") ~= 1)
end

-- The layout still holds bars at band spots and isn't written mid-game (pins come out as the session ends); until then
-- each bar stands where the client's own layout would put it, by anchor alone, for whoever answers "Later".
local function DefaultSpots()
    local presets = EditModePresetLayoutManager
    for _, name in ipairs(OWNED_SYSTEMS) do
        local frame = _G[name]
        if frame and frame.system and presets and presets.GetDefaultSystemAnchorInfo then
            -- Unknown (no method, failed call, secret, not a boolean) skips the bar.
            local isDefault = ns.InDefaultPosition(frame)
            local ok, info = pcall(presets.GetDefaultSystemAnchorInfo, presets, frame.system, frame.systemIndex)
            local relativeTo = ok and info and (type(info.relativeTo) == "string" and _G[info.relativeTo] or info.relativeTo)
            if isDefault == false and relativeTo and info.point then
                local scale = frame:GetScale()
                if not scale or scale <= 0 then scale = 1 end
                local _, clearPoints, setPoint = BaseSetters(frame)
                clearPoints(frame)
                setPoint(frame, info.point, relativeTo, info.relativePoint or info.point, (info.offsetX or 0) / scale, (info.offsetY or 0) / scale)
            end
        end
    end
end

local function Restore()
    if not B.active then
        SetLane(false)
        return
    end
    if InCombatLockdown() then return end
    B.active = false
    B.bottomWant = nil
    B.RollsBack()
    SetLane(false)
    RestoreSelections()
    local art = B.art
    if art then
        art:Hide()
        if art.bagFloor then art.bagFloor:Hide() end
    end
    LayoutExtraBars(false)
    B.ButtonsHome()
    UnskinRows()
    -- Nothing stacked before the anchors go back.
    B.StatusRestore()
    PutBackSaved(art)
    local bar = ns.GetMainBar()
    ClientArtBack(bar)
    PageNumberBack(bar)
    DefaultSpots()
    ns.needsReload = true
end

local function QueueIfActive()
    if B.active then ns.QueueApply() end
end

local function Init()
    local bar = ns.GetMainBar()
    if not bar then return end
    -- Everything the client does to a bar, holder, micro row or bags is answered from one watch, on a short beat while
    -- edit mode is open (the client draws its box on the bar it just laid out, and ours moves it).
    StartWatch()
    -- The support ticket button hangs off the game menu button, as 1.x did.
    if HelpOpenWebTicketButton and MainMenuMicroButton and MicroMenu then
        ns.HookMethod(MicroMenu, "UpdateHelpTicketButtonAnchor", function()
            if B.active then
                ns.SetPointOnce(HelpOpenWebTicketButton, "CENTER", MainMenuMicroButton, "TOPRIGHT", -3, -5)
            end
        end)
    end

    local watcher = CreateFrame("Frame")
    ns.RegisterEvents(watcher, { "UPDATE_EXHAUSTION", "PLAYER_UPDATE_RESTING", "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE" })
    watcher:SetScript("OnEvent", function(_, event)
        RecolorExpBars()
        if event == "PLAYER_ENTERING_WORLD" then
            -- The client hands the holders their bars for a while after this, and one arriving at its built
            -- size moves nothing the watch sees.
            for _, wait in ipairs({ 0.5, 1.5, 3 }) do
                C_Timer.After(wait, QueueIfActive)
            end
        end
    end)
    -- Edit mode shows the band as it is; a fresh pass puts the boxes right.
    ns.OnEditMode(function()
        B.dragging = false
        if B.active then ns.QueueApply() end
    end)
end

function ns.ClassicBarInfo()
    local art = B.art
    if not art then return "not built" end
    -- Apply never runs in a fight, so nothing is ever pending.
    return string.format("art shown=%s left=%.0f bottom=%.0f scale=%.2f pending=false", tostring(art:IsShown()), art:GetLeft() or 0, art:GetBottom() or 0, art:GetScale())
end

ns.RegisterModule("classicBar", { init = Init, apply = Apply, restore = Restore })
