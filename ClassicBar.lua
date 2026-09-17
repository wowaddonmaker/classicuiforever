local _, ns = ...

-- The 1.x main menu bar: a 1024x53 stone band centered at the bottom with
-- a gryphon on each end. Blizzard's action buttons, page arrows, micro
-- buttons, bag buttons and experience bars are re-anchored onto it, one
-- by one, in their 2004 spots. Edit mode keeps working for everything
-- else, and while edit mode is open the bar hands everything back.

local ART_W, ART_H = 1024, 53
local PIECE_W, BAND_H, STRIP_H = 256, 43, 10
local CAP_SIZE = 128
local BUTTON_SIZE, BUTTON_PITCH = 36, 42   -- 36px buttons, 6px apart
local ROW_X, ROW_Y = 8, 4                   -- first button from the band's corner
local UPPER_ROW_Y = 59                      -- bottom-left/right bars above the band
local PET_ROW_Y = 104                       -- stance, pet and possess bars above those
local STANCE_X, PET_X = 30, 36
local SMALL_PITCH, SMALL_BUTTON = 33, 30    -- 30px buttons on the pet and stance bars
local SIDE_BAR_X, SIDE_BAR_Y, SIDE_BAR_GAP = -2, 98, 6   -- right bars hang from the bottom right corner
local PAGE_X, PAGE_UP_Y, PAGE_DOWN_Y = 522, -22, -42
local MICRO_X, MICRO_Y, MICRO_W, MICRO_H, MICRO_STEP = 556, 2, 28, 38, -3
-- Which micro buttons give way first when the row cannot hold them all
-- (the band was drawn for ten). Lower keeps its place longer.
local MICRO_PRIORITY = {
    CharacterMicroButton = 1, SpellbookMicroButton = 2, PlayerSpellsMicroButton = 2, TalentMicroButton = 3,
    QuestLogMicroButton = 4, GuildMicroButton = 5, LFDMicroButton = 6, MainMenuMicroButton = 7,
    ProfessionMicroButton = 8, AchievementMicroButton = 9, LegacyMicroButton = 9, CollectionsMicroButton = 10,
    EJMicroButton = 11, HousingMicroButton = 12, StoreMicroButton = 13, HelpMicroButton = 14,
}
local hiddenMicro = {}
-- Measured from the band sheet: the four bag sockets sit at a 34px pitch
-- with 28px interiors, the backpack socket is wider and 38px from the last
-- bag, the key ring hole is 15px wide, all centred 22px up. 36px buttons
-- overlap each other by 2px and sit 2px clear of the backpack.
-- 34px buttons on the 34px socket pitch so icons touch without overlapping.
local BAG_SIZE, BAG_OVERLAP, BACKPACK_GAP, BAGS_X, BAGS_Y = 34, 0, -3, -9, 5
local KEYRING_W, KEYRING_H, KEYRING_GAP = 18, 39, -2
local PERF_W, PERF_H, PERF_GAP = 8, 20, 12

-- Everything the 1.x screen nailed in place. Only frames that exist on the
-- running client are touched.
local OWNED_SYSTEMS = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
    "StanceBar", "PetActionBar", "PossessActionBar", "MicroMenuContainer", "BagsBar",
    "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }

-- Micro buttons in the 1.x order, whichever of them the client has.
local MICRO_BUTTONS = { "CharacterMicroButton", "ProfessionMicroButton", "SpellbookMicroButton", "TalentMicroButton",
    "PlayerSpellsMicroButton", "AchievementMicroButton", "QuestLogMicroButton", "LegacyMicroButton", "GuildMicroButton",
    "LFDMicroButton", "CollectionsMicroButton", "EJMicroButton", "HousingMicroButton", "HelpMicroButton",
    "StoreMicroButton", "MainMenuMicroButton" }
local BAG_BUTTONS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot" }
-- Bars 6 to 8 did not exist in 1.x. They are faded out (and their buttons
-- stop taking the mouse) unless the option releases them to edit mode.
local EXTRA_BARS = { "MultiBar5", "MultiBar6", "MultiBar7" }

-- Rows of the 256x256 stone sheets as the 1.x bar sliced them: the 43px
-- band, and the 10px strip above it that frames the experience bar.
-- The right half is cut from the key ring sheet (256x128) so the band has
-- the key ring notch, on every client.
local PIECES = {
    { x = 0, key = "barBody", band = { 0.83203125, 1.0 }, strip = { 0.79296875, 0.83203125 } },
    { x = 256, key = "barBody", band = { 0.58203125, 0.75 }, strip = { 0.54296875, 0.58203125 } },
    { x = 512, key = "barKeyring", band = { 0.6640625, 1.0 }, strip = { 0.29296875, 0.33203125 }, stripKey = "barBody" },
    { x = 768, key = "barKeyring", band = { 0.1640625, 0.5 }, strip = { 0.04296875, 0.08203125 }, stripKey = "barBody" },
}
-- The reputation bar art when two bars are shown (rows of UI-ReputationWatchBar).
local REP_ROWS = { { 0, 0.171875 }, { 0.1875, 0.359375 }, { 0.375, 0.546875 }, { 0.5625, 0.734375 } }

local art
local active = false
local applying = false
local pending = false
local restoreQueued = false
local hooked = {}
local saved = {}   -- frame -> { scale, parent, w, h }

local function Remember(frame)
    if not saved[frame] then
        saved[frame] = { scale = frame:GetScale(), parent = frame:GetParent(), w = frame:GetWidth(), h = frame:GetHeight() }
    end
end

local function BuildArt()
    art = CreateFrame("Frame", "ForeverClassicUIBar", UIParent)
    art:SetSize(ART_W, ART_H)
    art:SetFrameStrata("MEDIUM")
    art:SetFrameLevel(1)
    art.pieces = {}
    for i, piece in ipairs(PIECES) do
        local tex = art:CreateTexture(nil, "BACKGROUND")
        tex:SetSize(PIECE_W, BAND_H)
        tex:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", piece.x, 0)
        art.pieces[i] = tex
    end
    art.leftCap = art:CreateTexture(nil, "OVERLAY", nil, 5)
    art.leftCap:SetSize(CAP_SIZE, CAP_SIZE)
    art.leftCap:SetPoint("BOTTOM", art, "BOTTOM", -544, 0)
    art.rightCap = art:CreateTexture(nil, "OVERLAY", nil, 5)
    art.rightCap:SetSize(CAP_SIZE, CAP_SIZE)
    art.rightCap:SetPoint("BOTTOM", art, "BOTTOM", 544, 0)
    -- The thin bar drawn along the top when no experience bar is shown.
    art.maxLevel = {}
    for i = 1, 4 do
        local tex = art:CreateTexture(nil, "BACKGROUND")
        tex:SetSize(256, 7)
        tex:SetPoint("BOTTOM", art, "TOP", -384 + (i - 1) * 256, -11)
        art.maxLevel[i] = tex
    end
    -- Rows are scaled children so button offsets can be written in 1.x pixels.
    art.rows = {}
end

local function PaintArt()
    for i, piece in ipairs(PIECES) do
        local tex = art.pieces[i]
        ns.SetTex(tex, piece.key)
        tex:SetTexCoord(0, 1, piece.band[1], piece.band[2])
    end
    ns.SetTex(art.leftCap, "endCap")
    art.leftCap:SetTexCoord(0, 1, 0, 1)
    ns.SetTex(art.rightCap, "endCap")
    art.rightCap:SetTexCoord(1, 0, 0, 1)
    for i, tex in ipairs(art.maxLevel) do
        ns.SetTex(tex, "maxLevel")
        tex:SetTexCoord(0, 1, (i - 1) * 0.25, (i - 1) * 0.25 + 0.21875)
    end
end

local function Row(index)
    local row = art.rows[index]
    if not row then
        row = CreateFrame("Frame", nil, art)
        row:SetSize(1, 1)
        art.rows[index] = row
    end
    return row
end

-- The buttons of one bar in a 1.x row or column: containers re-anchored
-- onto a scaled row frame so the buttons come out at 36px, 6px apart.
local function LayoutButtons(bar, rowIndex, point, relTo, relPoint, x, y, vertical, pitch, target)
    if not bar or not bar.actionButtons then return end
    local first = bar.actionButtons[1]
    local size = first and first:GetWidth() or 45
    if not size or size == 0 then size = 45 end
    -- Scale the buttons to their 1.x size: 36px on the action bars, 30px
    -- on the pet and stance bars.
    local scale = (target or BUTTON_SIZE) / size
    pitch = (pitch or BUTTON_PITCH) / scale
    local row = Row(rowIndex)
    row:SetScale(scale)
    row:ClearAllPoints()
    -- Offsets are read in the row scale, so convert from band pixels.
    row:SetPoint(point, relTo, relPoint, x / scale, y / scale)
    for i, button in ipairs(bar.actionButtons) do
        local container = button.container
        if container then
            Remember(container)
            container:SetScale(scale)
            container:ClearAllPoints()
            if vertical then
                container:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -(i - 1) * pitch)
            else
                container:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", (i - 1) * pitch, 0)
            end
        end
    end
end

local function RestoreButtons(bar)
    if not bar or not bar.actionButtons then return end
    for _, button in ipairs(bar.actionButtons) do
        local container = button.container
        if container and saved[container] then
            container:SetScale(saved[container].scale)
            saved[container] = nil
        end
    end
    -- Blizzard lays the containers out again from its own settings.
    bar.oldGridSettings = nil
    if bar.UpdateGridLayout then bar:UpdateGridLayout() end
end

-- Micro and bag buttons must sit above the main action bar frame, which
-- takes the mouse and can be raised to level 50 by edit mode.
local function ButtonLevel()
    local bar = ns.GetMainBar()
    return math.max(art:GetFrameLevel() + 20, (bar and bar:GetFrameLevel() or 0) + 10)
end

local function Anchor(frame, point, relPoint, x, y, scale)
    if not frame then return end
    Remember(frame)
    frame:ClearAllPoints()
    frame:SetPoint(point, art, relPoint, x, y)
    if scale then frame:SetScale(scale) end
end

-- Page number and arrows on the band's corner, 32px like 1.x.
local function LayoutPageArrows(bar)
    local pn = bar.ActionBarPageNumber
    if not pn then return end
    pn:ClearAllPoints()
    pn:SetPoint("CENTER", art, "TOPLEFT", PAGE_X, (PAGE_UP_Y + PAGE_DOWN_Y) / 2)
    pn:SetSize(32, 76)
    pn:SetScale(1)
    pn:Show()
    for _, entry in ipairs({ { pn.UpButton, PAGE_UP_Y }, { pn.DownButton, PAGE_DOWN_Y } }) do
        local button, y = entry[1], entry[2]
        if button then
            button:SetSize(32, 32)
            button:SetHitRectInsets(6, 6, 7, 7)
            button:ClearAllPoints()
            button:SetPoint("CENTER", art, "TOPLEFT", PAGE_X, y)
        end
    end
    if pn.Text then
        pn.Text:SetFontObject("GameFontNormalSmall")
        pn.Text:ClearAllPoints()
        pn.Text:SetPoint("CENTER", art, "CENTER", 30, -5)
    end
end

-- Bag buttons chained right to left from the band's corner: backpack first,
-- then the four bags, the reagent bag tucked below, the keyring (Forever) on
-- the far right where its slot in the band art is.
local function LayoutBags()
    local backpack = MainMenuBarBackpackButton
    if not backpack then return end
    local level = ButtonLevel()
    local prev
    -- Right to left into the band sockets: backpack in the corner, the
    -- four bags overlapping by 2px, then the key ring hole.
    for _, name in ipairs(BAG_BUTTONS) do
        local button = _G[name]
        if button then
            Remember(button)
            button:SetParent(art)
            button:SetScale(1)
            button:SetSize(BAG_SIZE, BAG_SIZE)
            button:SetFrameLevel(level)
            button:ClearAllPoints()
            if not prev then
                button:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", BAGS_X, BAGS_Y)
            elseif prev == backpack then
                button:SetPoint("RIGHT", prev, "LEFT", BACKPACK_GAP, 0)
            else
                button:SetPoint("RIGHT", prev, "LEFT", BAG_OVERLAP, 0)
            end
            ns.SkinBagButton(button, BAG_SIZE, name == "MainMenuBarBackpackButton")
            button:Show()
            prev = button
        end
    end
    -- The key ring hole takes the key ring where the client has one; a
    -- client without one puts its reagent bag there wearing the key ring art.
    local slim = KeyRingButton or CharacterReagentBag0Slot
    if slim then
        Remember(slim)
        slim:SetParent(art)
        slim:SetScale(1)
        slim:SetSize(KEYRING_W, KEYRING_H)
        slim:SetFrameLevel(level)
        slim:ClearAllPoints()
        slim:SetPoint("RIGHT", prev, "LEFT", KEYRING_GAP, 0)
        ns.SkinKeyRing(slim)
        prev = slim
    end
    if KeyRingButton and CharacterReagentBag0Slot then
        -- Both exist (Forever): the reagent bag keeps a full slot left of the key ring.
        local reagent = CharacterReagentBag0Slot
        Remember(reagent)
        reagent:SetParent(art)
        reagent:SetScale(1)
        reagent:SetSize(BAG_SIZE, BAG_SIZE)
        reagent:SetFrameLevel(level)
        reagent:ClearAllPoints()
        reagent:SetPoint("RIGHT", prev, "LEFT", BACKPACK_GAP, 0)
        ns.SkinBagButton(reagent, BAG_SIZE, false)
        prev = reagent
    end
    art.slimSlot = prev
    -- The 1.x latency bar: the small sheet drawn upright just left of the key ring.
    local perf = art.perfBar
    if not perf then
        perf = art:CreateTexture(nil, "OVERLAY", nil, 2)
        art.perfBar = perf
    end
    ns.SetTex(perf, "performanceBar")
    perf:SetSize(PERF_W, PERF_H)
    perf:SetTexCoord(0.625, 0, 0, 0, 0.625, 0.625, 0, 0.625)
    perf:ClearAllPoints()
    perf:SetPoint("BOTTOMRIGHT", prev, "BOTTOMLEFT", -2, 10)
    perf:Show()
    if BagBarExpandToggle then BagBarExpandToggle:Hide() end
    if BagsBar and BagsBar.BorderArt then BagsBar.BorderArt:SetAlpha(0) end
end

-- Micro buttons chained left to right from their 1.x spot, scaled as a
-- group to fit between that spot and the bags (Forever has more buttons
-- than the ten the band was drawn for).
-- The micro buttons this client actually has, in Blizzard's order: read
-- once from the micro menu before anything is reparented, so retail's
-- thirteen and Forever's fourteen both come out right.
local microButtons
local function MicroButtonList()
    if microButtons then return microButtons end
    local found = {}
    if MicroMenu then
        for _, child in ipairs({ MicroMenu:GetChildren() }) do
            if child.layoutIndex and child.PostAddButtonCallback then found[#found + 1] = child end
        end
        table.sort(found, function(a, b) return a.layoutIndex < b.layoutIndex end)
    end
    if #found == 0 then
        for _, name in ipairs(MICRO_BUTTONS) do
            if _G[name] then found[#found + 1] = _G[name] end
        end
    end
    microButtons = found
    return found
end

-- The band was drawn for ten micro buttons; later clients have thirteen
-- or fourteen. Buttons keep the 1.x size and 2px overlap from x 556, and
-- the ones with the lowest priority are hidden when the row would run
-- into the latency bar and the key ring slot.
local function MicroCapacity()
    local left = ART_W + BAGS_X - BAG_SIZE                 -- backpack
    left = left + BACKPACK_GAP - BAG_SIZE                  -- bag 0
    left = left + (BAG_OVERLAP - BAG_SIZE) * 3             -- bags 1 to 3
    if KeyRingButton or CharacterReagentBag0Slot then left = left + KEYRING_GAP - KEYRING_W end
    if KeyRingButton and CharacterReagentBag0Slot then left = left + BACKPACK_GAP - BAG_SIZE end
    local avail = left - PERF_GAP - MICRO_X
    return math.max(1, math.floor((avail - MICRO_STEP) / (MICRO_W + MICRO_STEP)))
end

local microBusy = false
local function LayoutMicroButtons()
    if microBusy then return end
    microBusy = true
    -- Every micro button leaves the Blizzard menu, shown or not, so its
    -- layout code never finds a lone child without a position.
    local wanted = {}
    for _, button in ipairs(MicroButtonList()) do
        Remember(button)
        button:SetParent(art)
        if button:IsShown() or hiddenMicro[button] then wanted[#wanted + 1] = button end
    end
    if #wanted == 0 then microBusy = false return end
    local capacity = MicroCapacity()
    local keep = {}
    for i, button in ipairs(wanted) do keep[i] = button end
    table.sort(keep, function(a, b)
        local pa, pb = MICRO_PRIORITY[a:GetName() or ""] or 99, MICRO_PRIORITY[b:GetName() or ""] or 99
        if pa ~= pb then return pa < pb end
        return (a.layoutIndex or 0) < (b.layoutIndex or 0)
    end)
    local shown = {}
    for i, button in ipairs(keep) do shown[button] = i <= capacity end
    local level = ButtonLevel()
    local prev
    for _, button in ipairs(wanted) do
        Remember(button)
        button:SetParent(art)
        button:SetSize(MICRO_W, MICRO_H)
        button:SetScale(1)
        button:SetFrameLevel(level)
        if shown[button] then
            if hiddenMicro[button] then
                hiddenMicro[button] = nil
                button:Show()
            end
            button:ClearAllPoints()
            if prev then
                button:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", MICRO_STEP, 0)
            else
                button:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", MICRO_X, MICRO_Y)
            end
            ns.SkinMicroButton(button)
            prev = button
        else
            hiddenMicro[button] = true
            button:Hide()
        end
    end
    if MicroMenu then
        if MicroMenu.BorderArt then MicroMenu.BorderArt:SetAlpha(0) end
        if MicroMenu.BackgroundArt then MicroMenu.BackgroundArt:SetAlpha(0) end
    end
    microBusy = false
end

-- Stance (or possess) bar at the left, the pet bar beside it, both above
-- bars 2 and 3 where 1.x kept them.
local function LayoutPetRow()
    local x = STANCE_X
    for _, bar in ipairs({ StanceBar, PossessActionBar }) do
        if bar then
            Anchor(bar, "BOTTOMLEFT", "BOTTOMLEFT", x, PET_ROW_Y, 1)
            LayoutButtons(bar, bar == StanceBar and 4 or 5, "BOTTOMLEFT", art, "BOTTOMLEFT", x, PET_ROW_Y, false, SMALL_PITCH, SMALL_BUTTON)
            if bar:IsShown() and bar.actionButtons then
                x = x + #bar.actionButtons * SMALL_PITCH + 8
            end
        end
    end
    if PetActionBar then
        local petX = math.max(PET_X, x)
        Anchor(PetActionBar, "BOTTOMLEFT", "BOTTOMLEFT", petX, PET_ROW_Y, 1)
        LayoutButtons(PetActionBar, 6, "BOTTOMLEFT", art, "BOTTOMLEFT", petX, PET_ROW_Y, false, SMALL_PITCH, SMALL_BUTTON)
    end
end

-- Bars 4 and 5 down the right edge of the screen, the way 1.x stacked them.
local function LayoutSideBars()
    local right, left = MultiBarRight, MultiBarLeft
    if right then
        Remember(right)
        right:SetScale(1)
        right:ClearAllPoints()
        -- 1.x hung the right bars from the bottom right corner, 98px up,
        -- so the column ends well below the minimap.
        right:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", SIDE_BAR_X, SIDE_BAR_Y)
        right:SetSize(BUTTON_SIZE, 12 * BUTTON_PITCH)
        LayoutButtons(right, 7, "TOPLEFT", right, "TOPLEFT", 0, 0, true)
    end
    if left then
        Remember(left)
        left:SetScale(1)
        left:ClearAllPoints()
        if right and right:IsShown() then
            left:SetPoint("TOPRIGHT", right, "TOPLEFT", -SIDE_BAR_GAP, 0)
        else
            left:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", SIDE_BAR_X, SIDE_BAR_Y)
        end
        left:SetSize(BUTTON_SIZE, 12 * BUTTON_PITCH)
        LayoutButtons(left, 8, "TOPLEFT", left, "TOPLEFT", 0, 0, true)
    end
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

-- Four strips of art laid over a status bar so it reads as part of the band.
local function EnsureStrips(statusBar)
    if statusBar.fcuiStrips then return statusBar.fcuiStrips end
    local strips = {}
    for i = 1, 4 do
        local tex = statusBar:CreateTexture(nil, "ARTWORK", nil, 1)
        tex:SetSize(PIECE_W, STRIP_H)
        tex:SetPoint("TOPLEFT", statusBar, "TOPLEFT", (i - 1) * PIECE_W, 0)
        strips[i] = tex
    end
    statusBar.fcuiStrips = strips
    return strips
end

-- Blizzard's fills are coloured atlases; on the 1.x fill the colour has
-- to come from us, picked from the atlas Blizzard asked for.
local BAR_COLORS = {
    { "Rested", 0, 0.39, 0.88 }, { "Experience", 0.58, 0, 0.55 },
    { "Faction-Red", 0.8, 0.13, 0.13 }, { "Faction-Orange", 1, 0.5, 0 }, { "Faction-Yellow", 1, 1, 0 },
    { "Faction-Green", 0, 0.6, 0.1 }, { "Faction-Blue", 0, 0.6, 1 },
    { "Honor", 1, 0.24, 0 }, { "Artifact", 0.9, 0.8, 0.6 }, { "Azerite", 1, 0.8, 0.2 },
}

local function RecolorStatus(status, atlas)
    if not active then return end
    if atlas then
        status.fcuiAtlas = atlas
    else
        local tex = status:GetStatusBarTexture()
        status.fcuiAtlas = status.fcuiAtlas or (tex and tex.GetAtlas and tex:GetAtlas())
        atlas = status.fcuiAtlas
    end
    status:SetStatusBarTexture((ns.TexPath("statusBar")))
    local tex = status:GetStatusBarTexture()
    if tex then tex:SetTexCoord(0, 0.16666667, 0, 1) end
    local r, g, b = 0.58, 0, 0.55
    if atlas then
        for _, entry in ipairs(BAR_COLORS) do
            if atlas:find(entry[1], 1, true) then r, g, b = entry[2], entry[3], entry[4] break end
        end
    end
    status:SetStatusBarColor(r, g, b)
end

-- The experience bar sits inside the band's top 10px; a second bar (rep,
-- honor) sits above it with the old reputation watch bar art.
local function LayoutStatusBar(container, isTop)
    if not container then return end
    Anchor(container, isTop and "BOTTOM" or "TOP", "TOP", 0, isTop and 0 or -1, 1)
    local h = isTop and 7 or STRIP_H
    container:SetSize(ART_W, h)
    if container.BarFrameTexture then container.BarFrameTexture:SetAlpha(0) end
    for _, bar in pairs(container.bars or {}) do
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        bar:SetSize(ART_W, h)
        local status = bar.StatusBar
        if status then
            status:ClearAllPoints()
            status:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
            status:SetSize(ART_W, h)
            ns.HookMethod(status, "SetBarTexture", RecolorStatus)
            RecolorStatus(status)
            if status.Background then status.Background:SetAlpha(0) end
            if bar.ExhaustionLevelFillBar then
                ns.SetTex(bar.ExhaustionLevelFillBar, "statusBar")
                bar.ExhaustionLevelFillBar:SetTexCoord(0, 0.16666667, 0, 1)
                bar.ExhaustionLevelFillBar:SetVertexColor(0, 0.39, 0.88, 0.3)
            end
            local strips = EnsureStrips(status)
            for i, tex in ipairs(strips) do
                tex:Show()
                if isTop then
                    ns.SetTex(tex, "repBar")
                    tex:SetTexCoord(0, 1, REP_ROWS[i][1], REP_ROWS[i][2])
                    tex:SetSize(PIECE_W, 11)
                else
                    ns.SetTex(tex, PIECES[i].stripKey or PIECES[i].key)
                    tex:SetTexCoord(0, 1, PIECES[i].strip[1], PIECES[i].strip[2])
                    tex:SetSize(PIECE_W, STRIP_H)
                end
            end
        end
    end
end

local function LayoutStatusBars()
    local main, second = MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer
    LayoutStatusBar(main, false)
    LayoutStatusBar(second, true)
    local anyShown = (main and main:IsShown()) or (second and second:IsShown())
    for _, tex in ipairs(art.maxLevel) do tex:SetShown(not anyShown) end
end

-- After every layout the real positions land in the saved output, so a
-- /reload alone is enough to see what the bar did.
local lastDump = 0
local function Rel(frame)
    local l, b = frame:GetLeft(), frame:GetBottom()
    local al, ab = art:GetLeft(), art:GetBottom()
    if not l or not al then return "norect" end
    return string.format("x=%.0f y=%.0f w=%.0f h=%.0f", l - al, b - ab, frame:GetWidth(), frame:GetHeight())
end

local function DumpLayout()
    if not ns.Persist or GetTime() - lastDump < 3 then return end
    lastDump = GetTime()
    ns.Persist(string.format("=== layout %s art %s capacity %d ===", date("%H:%M:%S"), Rel(art), MicroCapacity()))
    for _, button in ipairs(MicroButtonList()) do
        local normal = button:GetNormalTexture()
        local state = button:IsShown() and "shown" or (hiddenMicro[button] and "hidden-by-us" or "hidden")
        ns.Persist(string.format("micro %-24s %-13s %s parent %s tex %s", button:GetName(), state, Rel(button),
            tostring(button:GetParent() and button:GetParent():GetName()), tostring(normal and normal:GetTexture())))
    end
    for _, name in ipairs({ "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot", "CharacterReagentBag0Slot", "KeyRingButton" }) do
        local button = _G[name]
        if button then ns.Persist(string.format("bag %-26s %s %s", name, button:IsShown() and "shown" or "hidden", Rel(button))) end
    end
    if art.perfBar then ns.Persist("perf " .. Rel(art.perfBar) .. " shown " .. tostring(art.perfBar:IsShown())) end
    for i, tex in ipairs(art.pieces) do ns.Persist(string.format("piece %d tex %s", i, tostring(tex:GetTexture()))) end
    local bar = ns.GetMainBar()
    local first = bar and bar.actionButtons and bar.actionButtons[1]
    if first then ns.Persist("button1 " .. Rel(first) .. " scale " .. string.format("%.2f", first:GetEffectiveScale() / art:GetEffectiveScale())) end
    if bar and bar.ActionBarPageNumber and bar.ActionBarPageNumber.UpButton then ns.Persist("pageUp " .. Rel(bar.ActionBarPageNumber.UpButton)) end
    for _, name in ipairs({ "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "StanceBar", "PetActionBar" }) do
        local other = _G[name]
        if other then
            local b1 = other.actionButtons and other.actionButtons[1]
            local point, rel, relPoint, x, y = other:GetPoint(1)
            ns.Persist(string.format("bar %-20s %s default %s %s anchor %s %s %s %.0f %.0f button1 %s", name, other:IsShown() and "shown" or "hidden",
                tostring(other.IsInDefaultPosition and other:IsInDefaultPosition()), Rel(other), tostring(point), tostring(rel and rel.GetName and rel:GetName()),
                tostring(relPoint), x or 0, y or 0, b1 and Rel(b1) or "?"))
        end
    end
end

local function Layout()
    local bar = ns.GetMainBar()
    if not bar then return end
    -- Edit mode owns Action Bar 1's scale and, once it has been dragged, its
    -- position. The band takes the same scale and anchors itself so that
    -- the bar's rectangle is exactly its twelve buttons: dragging the bar in
    -- edit mode moves the whole classic bar, and its own settings dialog
    -- keeps working. In the default position the band sits centred at the
    -- bottom and the bar is placed inside it.
    art:SetScale(bar:GetScale() or 1)
    art:ClearAllPoints()
    local moved = bar.IsInDefaultPosition and not bar:IsInDefaultPosition()
    if moved then
        art:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -ROW_X, -ROW_Y)
    else
        art:SetPoint("BOTTOM", UIParent, "BOTTOM", ns.db.barOffsetX or 0, ns.db.barOffsetY or 0)
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", ROW_X, ROW_Y)
    end
    art:Show()
    PaintArt()
    if bar.EndCaps then bar.EndCaps:Hide() end
    if bar.BorderArt then bar.BorderArt:SetAlpha(0) end
    if bar.HorizontalDividersPool then bar.HorizontalDividersPool:ReleaseAll() end
    if bar.VerticalDividersPool then bar.VerticalDividersPool:ReleaseAll() end
    LayoutButtons(bar, 1, "BOTTOMLEFT", art, "BOTTOMLEFT", ROW_X, ROW_Y)
    LayoutPageArrows(bar)

    local lower, upper = MultiBarBottomLeft, MultiBarBottomRight
    local upperX = ROW_X + 12 * BUTTON_PITCH + 8
    if lower then
        Anchor(lower, "BOTTOMLEFT", "BOTTOMLEFT", ROW_X, UPPER_ROW_Y, 1)
        LayoutButtons(lower, 2, "BOTTOMLEFT", art, "BOTTOMLEFT", ROW_X, UPPER_ROW_Y)
    end
    if upper then
        Anchor(upper, "BOTTOMLEFT", "BOTTOMLEFT", upperX, UPPER_ROW_Y, 1)
        LayoutButtons(upper, 3, "BOTTOMLEFT", art, "BOTTOMLEFT", upperX, UPPER_ROW_Y)
    end
    LayoutPetRow()
    LayoutSideBars()
    LayoutExtraBars(ns.db.hideExtraBars)
    LayoutBags()
    LayoutMicroButtons()
    LayoutStatusBars()
    DumpLayout()
end

-- Everything here moves protected frames, so it only runs out of combat
-- and stays applied inside edit mode so the preview is the classic bar.
local function Apply()
    if not art then BuildArt() end
    active = true
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    applying = true
    local ok, err = pcall(Layout)
    applying = false
    if not ok then geterrorhandler()(err) end
end

local function Restore()
    if not active then return end
    if InCombatLockdown() then
        restoreQueued = true
        return
    end
    active = false
    restoreQueued = false
    if art then
        art:Hide()
        if art.perfBar then art.perfBar:Hide() end
    end
    LayoutExtraBars(false)
    local bar = ns.GetMainBar()
    for _, button in ipairs(MicroButtonList()) do
        ns.UnskinMicroButton(button)
        if hiddenMicro[button] then
            hiddenMicro[button] = nil
            button:Show()
        end
    end
    for _, name in ipairs(BAG_BUTTONS) do
        if _G[name] then ns.UnskinBagButton(_G[name]) end
    end
    if CharacterReagentBag0Slot then
        ns.UnskinBagButton(CharacterReagentBag0Slot)
        ns.UnskinKeyRing(CharacterReagentBag0Slot)
    end
    if KeyRingButton then ns.UnskinKeyRing(KeyRingButton) end
    for frame, state in pairs(saved) do
        frame:SetScale(state.scale)
        if frame:GetParent() == art and state.parent then
            frame:SetParent(state.parent)
            frame:SetSize(state.w, state.h)
        end
    end
    wipe(saved)
    for _, name in ipairs({ "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "StanceBar", "PetActionBar", "PossessActionBar" }) do
        RestoreButtons(_G[name])
    end
    if bar then
        if bar.BorderArt then bar.BorderArt:SetAlpha(1) end
        if bar.UpdateEndCaps then bar:UpdateEndCaps(bar.hideBarArt) end
        if bar.UpdateDividers then bar:UpdateDividers() end
    end
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
    for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        if container then
            if container.BarFrameTexture then container.BarFrameTexture:SetAlpha(1) end
            for _, b in pairs(container.bars or {}) do
                if b.StatusBar and b.StatusBar.fcuiStrips then
                    for _, tex in ipairs(b.StatusBar.fcuiStrips) do tex:Hide() end
                end
            end
        end
    end
    -- Hand the anchors back to edit mode.
    for _, name in ipairs(OWNED_SYSTEMS) do
        local frame = _G[name]
        if frame and frame.ApplySystemAnchor then pcall(frame.ApplySystemAnchor, frame) end
    end
    if EditModeManagerFrame and EditModeManagerFrame.UpdateBottomActionBarPositions then
        pcall(EditModeManagerFrame.UpdateBottomActionBarPositions, EditModeManagerFrame)
    end
    if StatusTrackingBarManager and StatusTrackingBarManager.UpdateBarsShown then
        pcall(StatusTrackingBarManager.UpdateBarsShown, StatusTrackingBarManager)
    end
    if bar and bar.ActionBarPageNumber and bar.UpdateSystemSettingHideBarScrolling then
        pcall(bar.UpdateSystemSettingHideBarScrolling, bar)
    end
end

-- Blizzard relayouts trigger one deferred pass of ours. A burst of them
-- (Blizzard reacting to our own moves) is cut off so the two never chase
-- each other frame after frame.
local lastHook, hookBurst = 0, 0
local function OnBlizzardLayout()
    if not active or applying then return end
    local now = GetTime()
    if now - lastHook < 0.5 then hookBurst = hookBurst + 1 else hookBurst = 0 end
    lastHook = now
    if hookBurst > 8 then return end
    ns.QueueApply()
end

local function HookRelayout(frame, method)
    if not frame or type(rawget(frame, method)) ~= "function" then return end
    hooked[frame] = hooked[frame] or {}
    if hooked[frame][method] then return end
    hooked[frame][method] = true
    hooksecurefunc(frame, method, OnBlizzardLayout)
end

local function Init()
    local bar = ns.GetMainBar()
    if not bar then return end
    -- Blizzard re-anchors these on every layout change; put them back after it.
    for _, name in ipairs(OWNED_SYSTEMS) do
        HookRelayout(_G[name], "ApplySystemAnchor")
        HookRelayout(_G[name], "UpdateGridLayout")
    end
    if EditModeManagerFrame then
        HookRelayout(EditModeManagerFrame, "UpdateBottomActionBarPositions")
        HookRelayout(EditModeManagerFrame, "UpdateRightActionBarPositions")
    end
    for _, name in ipairs({ "BottomManagedFrameContainer", "RightManagedFrameContainer", "MicroMenu", "BagsBar" }) do
        HookRelayout(_G[name], "Layout")
    end
    if StatusTrackingBarManager then
        HookRelayout(StatusTrackingBarManager, "UpdateBarsShown")
    end
    -- A container switching bars (login, level, reputation change) lays
    -- ours out in the same call so the retail layout never shows between.
    for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        if container then
            ns.HookMethod(container, "ApplyPendingBarToShow", function()
                if active and not applying and not InCombatLockdown() then LayoutStatusBars() end
            end)
        end
    end
    if type(rawget(bar, "UpdateEndCaps")) == "function" then
        hooksecurefunc(bar, "UpdateEndCaps", function(self)
            if active and self.EndCaps then self.EndCaps:Hide() end
        end)
    end
    for _, name in ipairs({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer", "BagsBar", "StanceBar", "PetActionBar", "PossessActionBar", "MultiBarRight", "MultiBarLeft" }) do
        local frame = _G[name]
        if frame then
            frame:HookScript("OnShow", OnBlizzardLayout)
            frame:HookScript("OnHide", OnBlizzardLayout)
        end
    end
    for _, name in ipairs(BAG_BUTTONS) do
        local button = _G[name]
        if button and type(rawget(button, "SetBarExpanded")) == "function" then
            hooksecurefunc(button, "SetBarExpanded", function(self)
                if active then self:Show() end
            end)
        end
    end
    -- A micro button appearing or going away reflows the row at once.
    local function ReflowMicro()
        if active and not applying and not InCombatLockdown() then LayoutMicroButtons() end
    end
    for _, button in ipairs(MicroButtonList()) do
        button:HookScript("OnShow", ReflowMicro)
        button:HookScript("OnHide", ReflowMicro)
    end
    if type(UpdateMicroButtons) == "function" then hooksecurefunc("UpdateMicroButtons", ReflowMicro) end
    -- The support ticket button hangs off the game menu button, as 1.x did.
    if HelpOpenWebTicketButton and MainMenuMicroButton and MicroMenu then
        ns.HookMethod(MicroMenu, "UpdateHelpTicketButtonAnchor", function()
            if active then
                HelpOpenWebTicketButton:ClearAllPoints()
                HelpOpenWebTicketButton:SetPoint("CENTER", MainMenuMicroButton, "TOPRIGHT", -3, -5)
            end
        end)
    end

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:SetScript("OnEvent", function()
        if restoreQueued then
            Restore()
        elseif pending and active then
            ns.QueueApply()
        end
    end)
    if EventRegistry and EventRegistry.RegisterCallback then
        -- Edit mode gets the real layout while it is open.
        -- Edit mode shows the classic bar as it is; a fresh pass puts the
        -- selection boxes over the right spots.
        EventRegistry:RegisterCallback("EditMode.Enter", function()
            if active then ns.QueueApply() end
        end, watcher)
    end
    -- Pieces that are part of the band have no position of their own in
    -- 1.x, so their edit mode selection boxes stay hidden while it is on.
    for _, name in ipairs({ "MicroMenuContainer", "BagsBar", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }) do
        local system = _G[name]
        if system and system.Selection then
            for _, method in ipairs({ "SetSelectionShown", "HighlightSystem", "SelectSystem", "OnEditModeEnter" }) do
                if type(rawget(system, method)) == "function" then
                    hooksecurefunc(system, method, function(self)
                        if active and self.Selection then self.Selection:Hide() end
                    end)
                end
            end
        end
    end
end

function ns.ClassicBarInfo()
    if not art then return "not built" end
    return string.format("art shown=%s left=%.0f bottom=%.0f scale=%.2f pending=%s", tostring(art:IsShown()), art:GetLeft() or 0, art:GetBottom() or 0, art:GetScale(), tostring(pending))
end

ns.RegisterModule("classicBar", { init = Init, apply = Apply, restore = Restore })
