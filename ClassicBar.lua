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
local UPPER_ROW_Y = 55                      -- bars 2 and 3: 3px above the experience strip inside the band top
local PET_ROW_Y = 104                       -- stance, pet and possess bars above those
local STANCE_X, PET_X = 30, 36
local SMALL_PITCH, SMALL_BUTTON = 33, 30    -- 30px buttons on the pet and stance bars
local SIDE_BAR_X, SIDE_BAR_Y, SIDE_BAR_GAP = -2, 98, 6   -- right bars hang from the bottom right corner
local PAGE_X, PAGE_UP_Y, PAGE_DOWN_Y = 522, -22, -42
local PAGE_X_ONE = 622                      -- one-bar mode: just past the right gryphon
-- One-bar mode has no right half of the band to carry the micro menu and
-- the bags, so they take the screen's bottom right corner instead, in
-- their old art: the micro row along the corner, the bags above it.
local CORNER_BAGS_X, CORNER_BAGS_Y = -4, 42
local CORNER_MICRO_X, CORNER_MICRO_Y = -4, 2
-- The 1.x overlap of 3px; more than that and the drawn buttons crowd.
-- With the shop button out the row scales to about nine tenths.
local MICRO_X, MICRO_Y, MICRO_W, MICRO_H, MICRO_STEP = 557, 5, 28, 38, -3
-- The shop is in the Escape menu; its button never fit the old row.
local MICRO_SKIP = { StoreMicroButton = true }
-- Which micro buttons give way first when the row cannot hold them all
-- (the band was drawn for ten). Lower keeps its place longer.
local hiddenMicro = {}
-- Measured from the band sheet: the four bag sockets sit at a 34px pitch
-- with 28px interiors, the backpack socket is wider and 38px from the last
-- bag, the key ring hole is 15px wide, all centered 22px up. 36px buttons
-- overlap each other by 2px and sit 2px clear of the backpack.
-- 30px buttons 2px apart, the backpack 4px in from the corner and 6px up:
-- the icons then sit inside the sockets with the stone showing around them.
local BAG_SIZE, BAG_OVERLAP, BACKPACK_GAP, BAGS_X, BAGS_Y = 30, -2, -2, -4, 6
local KEYRING_W, KEYRING_H, KEYRING_GAP = 18, 39, -5
local PERF_W, PERF_H, PERF_GAP = 8, 20, 6

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

-- The band is drawn for two bars side by side. In one-bar mode it stops
-- after the twelve main slots, the right gryphon beside them, and the
-- bottom right bar, micro menu and bags stay where edit mode puts them.
local function OneBar() return ns.db and ns.db.oneBar == true end
local function ArtWidth() return OneBar() and (ART_W / 2) or ART_W end

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
    -- The right hand columns hang from the screen's own corner rather
    -- than from the band or from their bars, so they keep their 1.x spot
    -- whatever edit mode does to those bars.
    art.sideAnchor = CreateFrame("Frame", nil, UIParent)
    art.sideAnchor:SetSize(1, 1)
    art.sideAnchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    for _, index in ipairs({ 7, 8 }) do
        local row = CreateFrame("Frame", nil, art.sideAnchor)
        row:SetSize(1, 1)
        art.rows[index] = row
    end
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

-- The band's width and what of it shows: the right half goes in one-bar
-- mode, and the gryphons go while edit mode's Hide Bar Art is on for
-- Action Bar 1, as it takes the client's own end caps away; the band
-- itself stays, being the bar's floor rather than its art.
local function ApplyArtShape(bar)
    local hide = bar and bar.hideBarArt == true
    local w = ArtWidth()
    art:SetSize(w, ART_H)
    art.artHidden = hide
    for i, tex in ipairs(art.pieces) do
        tex:SetShown(PIECES[i].x < w)
    end
    art.leftCap:ClearAllPoints()
    art.leftCap:SetPoint("BOTTOM", art, "BOTTOM", -(w / 2 + 32), 0)
    art.rightCap:ClearAllPoints()
    art.rightCap:SetPoint("BOTTOM", art, "BOTTOM", w / 2 + 32, 0)
    art.leftCap:SetShown(not hide)
    art.rightCap:SetShown(not hide)
    for i, tex in ipairs(art.maxLevel) do
        tex:ClearAllPoints()
        tex:SetPoint("BOTTOM", art, "TOP", -(w / 2) + 128 + (i - 1) * 256, -11)
        tex.fcuiInBand = (i - 1) * 256 < w
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
            if saved[container].parent and container:GetParent() ~= saved[container].parent then
                container:SetParent(saved[container].parent)
            end
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
    local pageX = OneBar() and PAGE_X_ONE or PAGE_X
    pn:ClearAllPoints()
    pn:SetPoint("CENTER", art, "TOPLEFT", pageX, (PAGE_UP_Y + PAGE_DOWN_Y) / 2)
    pn:SetSize(32, 76)
    pn:SetScale(1)
    pn:Show()
    for _, entry in ipairs({ { pn.UpButton, PAGE_UP_Y }, { pn.DownButton, PAGE_DOWN_Y } }) do
        local button, y = entry[1], entry[2]
        if button then
            button:SetSize(32, 32)
            button:SetHitRectInsets(6, 6, 7, 7)
            button:ClearAllPoints()
            button:SetPoint("CENTER", art, "TOPLEFT", pageX, y)
        end
    end
    if pn.Text then
        -- Beside the arrows, not at the band's middle: the half band of
        -- one-bar mode has its middle somewhere else entirely.
        pn.Text:SetFontObject("GameFontNormalSmall")
        pn.Text:ClearAllPoints()
        pn.Text:SetPoint("CENTER", art, "TOPLEFT", pageX + 20, (PAGE_UP_Y + PAGE_DOWN_Y) / 2 + 0.5)
    end
end

-- Bag buttons chained right to left from the band's corner: backpack first,
-- then the four bags, the reagent bag tucked below, the keyring (Forever) on
-- the far right where its slot in the band art is.
-- Any anchor set on a bag button by someone else (Blizzard's bag bar
-- laying itself out, edit mode, the expand toggle) is undone on the next
-- frame. Our own placement sets the guard so it never re-triggers.
local layingBags, bagRelayoutQueued = false, false
local function OnBagButtonMoved()
    if not active or applying or layingBags or bagRelayoutQueued then return end
    bagRelayoutQueued = true
    C_Timer.After(0, function()
        bagRelayoutQueued = false
        if active and not applying and not InCombatLockdown() then ns.RelayoutBags() end
    end)
end

local watchedBag = {}
local function WatchBag(button)
    if watchedBag[button] then return end
    watchedBag[button] = true
    hooksecurefunc(button, "SetPoint", OnBagButtonMoved)
    hooksecurefunc(button, "SetParent", OnBagButtonMoved)
end

local function LayoutBags()
    local backpack = MainMenuBarBackpackButton
    if not backpack then return end
    local home = OneBar() and art.sideAnchor or art
    local homeX = OneBar() and CORNER_BAGS_X or BAGS_X
    local homeY = OneBar() and CORNER_BAGS_Y or BAGS_Y
    layingBags = true
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
                button:SetPoint("BOTTOMRIGHT", home, "BOTTOMRIGHT", homeX, homeY)
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
    -- The client's own bag bar carries art of its own behind the slots,
    -- which showed around the key ring where the band's sockets are; all
    -- of it goes, ours is drawn on the band.
    if BagsBar then
        for _, region in ipairs({ BagsBar:GetRegions() }) do
            if region:IsObjectType("Texture") then region:SetAlpha(0) end
        end
        for _, child in ipairs({ BagsBar:GetChildren() }) do
            if not child.GetBagID and not child.GetID then
                for _, region in ipairs({ child:GetRegions() }) do
                    if region:IsObjectType("Texture") then region:SetAlpha(0) end
                end
            end
        end
    end
    for _, name in ipairs(BAG_BUTTONS) do
        if _G[name] then WatchBag(_G[name]) end
    end
    if KeyRingButton then WatchBag(KeyRingButton) end
    if CharacterReagentBag0Slot then WatchBag(CharacterReagentBag0Slot) end
    layingBags = false
end


-- Micro buttons chained left to right from their 1.x spot, scaled as a
-- group to fit between that spot and the bags (Forever has more buttons
-- than the ten the band was drawn for).
-- The micro buttons this client actually has, in Blizzard's order: read
-- once from the micro menu before anything is reparented, so retail's
-- thirteen and Forever's fourteen both come out right.
local microButtons
-- 1.x had a world map button in the row; the modern menu has none, so
-- the band adds its own beside the quest button.
local function WorldMapMicroButton()
    if ns.WorldMapMicroButton then return ns.WorldMapMicroButton end
    -- The list is built before the band art exists; the row layout
    -- reparents every button onto the band later.
    local button = CreateFrame("Button", "ForeverClassicUIWorldMapMicroButton", art or UIParent)
    button:SetSize(MICRO_W, MICRO_H)
    button:SetNormalTexture((ns.TexPath("microWorldUp")))
    button:SetPushedTexture((ns.TexPath("microWorldDown")))
    button:SetHighlightTexture((ns.TexPath("microHighlight")))
    button:SetScript("OnClick", function()
        if ToggleWorldMap then ToggleWorldMap() end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local key = GetBindingKey("TOGGLEWORLDMAP")
        GameTooltip:SetText((WORLDMAP_BUTTON or "World Map") .. (key and (" (" .. key .. ")") or ""), 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function() button:SetButtonState("PUSHED", true) end)
        WorldMapFrame:HookScript("OnHide", function() button:SetButtonState("NORMAL") end)
    end
    ns.WorldMapMicroButton = button
    return button
end

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
    local map = WorldMapMicroButton()
    if map then
        local at = #found + 1
        for i, button in ipairs(found) do
            if button == QuestLogMicroButton then at = i + 1 break end
        end
        table.insert(found, at, map)
    end
    microButtons = found
    return found
end

-- The band was drawn for ten micro buttons; later clients have thirteen
-- or fourteen. Every button stays; the row starts at x 556 with the 1.x
-- overlap and is scaled down as a whole so it ends just before the
-- latency bar and the key ring slot, as the classic look does today.
local function MicroRoomLeft()
    local left = ART_W + BAGS_X - BAG_SIZE                 -- backpack
    left = left + BACKPACK_GAP - BAG_SIZE                  -- bag 0
    left = left + (BAG_OVERLAP - BAG_SIZE) * 3             -- bags 1 to 3
    if KeyRingButton or CharacterReagentBag0Slot then left = left + KEYRING_GAP - KEYRING_W end
    if KeyRingButton and CharacterReagentBag0Slot then left = left + BACKPACK_GAP - BAG_SIZE end
    return left - PERF_GAP - MICRO_X
end

local function MicroScale(count)
    local need = count * (MICRO_W + MICRO_STEP) - MICRO_STEP
    if need <= 0 then return 1 end
    return math.min(1, MicroRoomLeft() / need)
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
        if MICRO_SKIP[button:GetName() or ""] then
            button:ClearAllPoints()
            button:SetAlpha(0)
        elseif button:IsShown() or hiddenMicro[button] then
            wanted[#wanted + 1] = button
        end
    end
    if #wanted == 0 then microBusy = false return end
    local scale = OneBar() and 1 or MicroScale(#wanted)
    local rowWidth = #wanted * (MICRO_W + MICRO_STEP) - MICRO_STEP
    local level = ButtonLevel()
    local prev
    for _, button in ipairs(wanted) do
        Remember(button)
        button:SetParent(art)
        button:SetSize(MICRO_W, MICRO_H)
        button:SetScale(scale)
        button:SetFrameLevel(level)
        if hiddenMicro[button] then
            hiddenMicro[button] = nil
            button:Show()
        end
        button:ClearAllPoints()
        if prev then
            button:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", MICRO_STEP, 0)
        elseif OneBar() then
            -- Point offsets are in the button's own scale.
            button:SetPoint("BOTTOMLEFT", art.sideAnchor, "BOTTOMRIGHT", (CORNER_MICRO_X - rowWidth) / scale, CORNER_MICRO_Y / scale)
        else
            button:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", MICRO_X / scale, MICRO_Y / scale)
        end
        ns.SkinMicroButton(button)
        prev = button
    end
    if MicroMenu then
        if MicroMenu.BorderArt then MicroMenu.BorderArt:SetAlpha(0) end
        if MicroMenu.BackgroundArt then MicroMenu.BackgroundArt:SetAlpha(0) end
    end
    microBusy = false
end

function ns.RelayoutBags()
    LayoutBags()
    LayoutMicroButtons()
end

-- Whether edit mode holds a spot for this frame that is not its default,
-- which means the user dragged it there. The flag alone is not enough:
-- a layout can carry a stale one, so the spot it holds is compared with
-- the preset's before the frame is left alone.
local function SystemMoved(frame)
    if not frame or type(frame.IsInDefaultPosition) ~= "function" then return false end
    if not (frame.IsInitialized and frame:IsInitialized()) then return false end
    local ok, isDefault = pcall(frame.IsInDefaultPosition, frame)
    if not ok or isDefault then return false end
    local info = frame.systemInfo and frame.systemInfo.anchorInfo
    local mgr = EditModePresetLayoutManager
    local okDefault, preset = pcall(function() return mgr and mgr:GetDefaultSystemAnchorInfo(frame.system, frame.systemIndex) end)
    if not okDefault or not info or not preset then return true end
    local same = info.point == preset.point and info.relativeTo == preset.relativeTo and info.relativePoint == preset.relativePoint
        and math.abs((info.offsetX or 0) - (preset.offsetX or 0)) < 0.5 and math.abs((info.offsetY or 0) - (preset.offsetY or 0)) < 0.5
    return not same
end
ns.SystemMoved = SystemMoved

-- A row of buttons on the band: at the 1.x spot for a bar still in its
-- default place, on the bar itself for one the user moved in edit mode,
-- which is then left where they put it.
local function BandRow(bar, rowIndex, x, y, pitch, target)
    if not bar then return false end
    if SystemMoved(bar) then
        LayoutButtons(bar, rowIndex, "BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0, false, pitch, target)
        return false
    end
    Anchor(bar, "BOTTOMLEFT", "BOTTOMLEFT", x, y, 1)
    LayoutButtons(bar, rowIndex, "BOTTOMLEFT", art, "BOTTOMLEFT", x, y, false, pitch, target)
    return true
end

-- Stance (or possess) bar at the left, the pet bar beside it, both above
-- bars 2 and 3 where 1.x kept them.
local function LayoutPetRow(lift)
    local x = STANCE_X
    local y = PET_ROW_Y + (lift or 0)
    for _, bar in ipairs({ StanceBar, PossessActionBar }) do
        if bar then
            local pinned = BandRow(bar, bar == StanceBar and 4 or 5, x, y, SMALL_PITCH, SMALL_BUTTON)
            if pinned and bar:IsShown() and bar.actionButtons then
                x = x + #bar.actionButtons * SMALL_PITCH + 8
            end
        end
    end
    if PetActionBar then
        BandRow(PetActionBar, 6, math.max(PET_X, x), y, SMALL_PITCH, SMALL_BUTTON)
    end
end

-- Bars 4 and 5 down the right edge of the screen, the way 1.x stacked them.
-- 1.x hung the right bars from the bottom right corner, 98px up, so the
-- column ends well below the minimap. The buttons are hung from that
-- corner rather than from the bar: edit mode re-anchors and rescales a
-- right bar whenever the room beside the minimap changes, which happens
-- on entering combat, when nothing of ours may move a protected frame,
-- and the column used to jump with it. A bar the user has placed in
-- edit mode keeps its own spot and the buttons hang on it.
local SIDE_COL_H = 12 * BUTTON_PITCH

local function SideColumn(bar, rowIndex, x)
    if not bar then return false end
    if SystemMoved(bar) then
        LayoutButtons(bar, rowIndex, "TOPLEFT", bar, "TOPLEFT", 0, 0, true)
        return false
    end
    Remember(bar)
    bar:SetScale(1)
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", x, SIDE_BAR_Y)
    bar:SetSize(BUTTON_SIZE, SIDE_COL_H)
    LayoutButtons(bar, rowIndex, "TOPLEFT", UIParent, "BOTTOMRIGHT", x - BUTTON_SIZE, SIDE_BAR_Y + SIDE_COL_H, true)
    return true
end

local function LayoutSideBars()
    local right, left = MultiBarRight, MultiBarLeft
    local rightPinned = SideColumn(right, 7, SIDE_BAR_X)
    local leftX = SIDE_BAR_X
    if rightPinned and right:IsShown() then
        leftX = SIDE_BAR_X - BUTTON_SIZE - SIDE_BAR_GAP
    end
    SideColumn(left, 8, leftX)
end

-- Bars 6 to 8 are enabled in the game's Settings (Action Bars page);
-- the game hides a disabled bar itself. Our toggle and those three
-- settings stay in step: the toggle on turns them off, and any of them
-- turned on in Settings turns the toggle off.
local EXTRA_SETTINGS = { "PROXY_SHOW_ACTIONBAR_6", "PROXY_SHOW_ACTIONBAR_7", "PROXY_SHOW_ACTIONBAR_8" }
local syncingExtra = false

local function ExtraBarsEnabledInSettings()
    if not Settings or not Settings.GetValue then return false end
    for _, var in ipairs(EXTRA_SETTINGS) do
        local ok, value = pcall(Settings.GetValue, var)
        if ok and value then return true end
    end
    return false
end

local function DisableExtraBarsInSettings()
    if InCombatLockdown() or not Settings or not Settings.SetValue then return end
    syncingExtra = true
    for _, var in ipairs(EXTRA_SETTINGS) do
        local ok, value = pcall(Settings.GetValue, var)
        if ok and value then pcall(Settings.SetValue, var, false) end
    end
    syncingExtra = false
end

local LayoutExtraBars

-- A bar enabled in Settings while our toggle hides them: the toggle
-- goes off: the bar was wanted.
local function FollowSettings()
    if not active or syncingExtra or not ns.db or not ns.db.hideExtraBars then return end
    if ExtraBarsEnabledInSettings() then
        ns.db.hideExtraBars = false
        LayoutExtraBars(false)
        if ns.RefreshOptionsWindow then ns.RefreshOptionsWindow() end
    end
end

LayoutExtraBars = function(hide)
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

-- Blizzard's fills are colored atlases; on the 1.x fill the color has
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
    if status.fcuiXP then
        -- The experience bar, known by its tick rather than by any atlas
        -- name: blue while rested. The client says so through
        -- UpdateStatusBarTextures(isRested), which the bar hook below
        -- records; before it has spoken, the rest state decides.
        -- Rested means rested experience waiting to be spent: the run
        -- to the tick is drawn from the same number. The rest state on
        -- this client reads Normal with rested experience still banked,
        -- so the amount itself is the first word, then the client's own
        -- fill choice, then the state.
        local rested = false
        -- The client draws the run to the tick only while rested
        -- experience is banked; its showing is the surest word.
        local run = status.fcuiRun
        if run and run:IsShown() and (run:GetWidth() or 0) > 0 then rested = true end
        if not rested and GetXPExhaustion then
            local amount = GetXPExhaustion()
            if amount and not (issecretvalue and issecretvalue(amount)) and amount > 0 then rested = true end
        end
        if not rested and status.fcuiRested then rested = true end
        if not rested and atlas and atlas:find("Rested", 1, true) then rested = true end
        if not rested and GetRestState then
            local state = GetRestState()
            if not (issecretvalue and issecretvalue(state)) and state == 1 then rested = true end
        end
        if rested then r, g, b = 0, 0.39, 0.88 end
    elseif atlas then
        for _, entry in ipairs(BAR_COLORS) do
            if atlas:find(entry[1], 1, true) then r, g, b = entry[2], entry[3], entry[4] break end
        end
    end
    status:SetStatusBarColor(r, g, b)
end

-- The client picks the experience bar's fill by the rest state through
-- this one method; the answer it gives is kept and the fill recoloured
-- from it, so the bar turns blue and back exactly when the client's
-- own would.
local function HookRestedState(bar, status)
    if not bar.UpdateStatusBarTextures then return end
    ns.HookMethod(bar, "UpdateStatusBarTextures", function(self, isRested)
        local sb = self.StatusBar or status
        if not sb then return end
        sb.fcuiRested = isRested and true or false
        RecolorStatus(sb)
    end)
end

-- The experience bar sits inside the band's top 10px; a second bar (rep,
-- honor) sits above it with the old reputation watch bar art.
local function LayoutStatusBar(container, isTop)
    if not container then return end
    Anchor(container, isTop and "BOTTOM" or "TOP", "TOP", 0, isTop and 0 or -1, 1)
    local h = isTop and 7 or STRIP_H
    local w = ArtWidth()
    container:SetSize(w, h)
    if container.BarFrameTexture then container.BarFrameTexture:SetAlpha(0) end
    -- 12.x lays a pool of segment posts over the container; the 1.x strip
    -- draws its own, so Blizzard's are faded each time it rebuilds them.
    local function FadeDividers(self)
        if not active or not self.HorizontalDividersPool then return end
        for divider in self.HorizontalDividersPool:EnumerateActive() do divider:SetAlpha(0) end
    end
    FadeDividers(container)
    ns.HookMethod(container, "UpdateDividers", FadeDividers)
    for _, bar in pairs(container.bars or {}) do
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        bar:SetSize(w, h)
        local status = bar.StatusBar
        if status then
            status:ClearAllPoints()
            status:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
            status:SetSize(w, h)
            status.fcuiXP = bar.ExhaustionTick ~= nil
            ns.HookMethod(status, "SetBarTexture", RecolorStatus)
            HookRestedState(bar, status)
            RecolorStatus(status)
            if status.Background then status.Background:SetAlpha(0) end
            -- Rested: the 1.x bar filled blue, and a paler blue ran on to
            -- the tick for the rested experience still to come. Blizzard
            -- draws that run on the bar frame, under the status bar; it
            -- moves onto the status bar, under the strips, in the old
            -- fill at a third strength, and the tick wears the old marker.
            local run = bar.ExhaustionLevelFillBar
            status.fcuiRun = run
            local tick = bar.ExhaustionTick
            if tick and tick.UpdateTickPosition then
                ns.HookMethod(tick, "UpdateTickPosition", function() RecolorStatus(status) end)
            end
            if run then
                if run.SetParent then run:SetParent(status) end
                -- Under the fill, as 1.x had it: the run shows only past
                -- the fill's end, out to the tick.
                run:SetDrawLayer("BACKGROUND", 0)
                run:SetVertexColor(1, 1, 1, 1)
                -- A flat faint blue, as the 1.x run was at 15%. The client
                -- re-cuts the run's texture coordinates by its width on
                -- every update, which on a sheet sampled other columns;
                -- a color texture has no columns to sample.
                run:SetColorTexture(0, 0.39, 0.88, 0.15)
                run:ClearAllPoints()
                run:SetPoint("BOTTOMLEFT", status, "BOTTOMLEFT", 0, 0)
                run:SetHeight(h)
            end
            tick = bar.ExhaustionTick
            if tick and not tick.fcuiSkinned then
                tick.fcuiSkinned = true
                tick:SetSize(32, 32)
                if tick.Normal then
                    ns.SetTex(tick.Normal, "exhaustionTick")
                    tick.Normal:SetTexCoord(0, 1, 0, 1)
                    tick.Normal:ClearAllPoints()
                    tick.Normal:SetAllPoints(tick)
                end
                if tick.Highlight then
                    ns.SetTex(tick.Highlight, "exhaustionTickHighlight")
                    tick.Highlight:SetTexCoord(0, 1, 0, 1)
                    tick.Highlight:ClearAllPoints()
                    tick.Highlight:SetAllPoints(tick)
                end
            end
            local strips = EnsureStrips(status)
            for i, tex in ipairs(strips) do
                tex:SetShown((i - 1) * PIECE_W < w)
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

local function HasVisibleBar(container)
    if not container then return false end
    for _, bar in pairs(container.bars or {}) do
        if bar:IsShown() then return true end
    end
    return false
end

-- The experience bar's fill checked against the rest state afresh: on
-- the rest events, and on entering the world, when the state is known.
local function RecolorExpBars()
    if not active then return end
    for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        for _, bar in pairs(container and container.bars or {}) do
            if bar.ExhaustionTick and bar.StatusBar then
                bar.StatusBar.fcuiRested = nil
                RecolorStatus(bar.StatusBar)
            end
        end
    end
end

local function LayoutStatusBars()
    local main, second = MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer
    LayoutStatusBar(main, false)
    LayoutStatusBar(second, true)
    for _, container in ipairs({ main, second }) do
        if container then container:SetAlpha(HasVisibleBar(container) and 1 or 0) end
    end
    local anyShown = (main and main:IsShown()) or (second and second:IsShown())
    for _, tex in ipairs(art.maxLevel) do tex:SetShown(not anyShown and tex.fcuiInBand == true) end
end

-- Whether the band should follow Action Bar 1 instead of centring itself.
-- Only a drag the user made in edit mode while the band was on counts
-- (ns.db.barDragged, cleared by the bar's reset-to-default button). The
-- edit mode flag alone is not enough: layouts saved by earlier builds, or
-- any anchor change edit mode noticed, leave the bar flagged as moved with
-- a stale anchor, which used to shift the whole band sideways.
local function BarMoved(bar)
    if not ns.db.barDragged then return false end
    return SystemMoved(bar)
end

-- A developer addon may look at the finished layout.
local function AfterLayout()
    if ns.OnBarLaid then ns.OnBarLaid() end
end
ns.MicroButtonList = MicroButtonList

local function Layout()
    local bar = ns.GetMainBar()
    if not bar then return end
    -- Edit mode owns Action Bar 1's scale and, once it has been dragged, its
    -- position. The band takes the same scale and anchors itself so that
    -- the bar's rectangle is exactly its twelve buttons: dragging the bar in
    -- edit mode moves the whole classic bar, and its own settings dialog
    -- keeps working. In the default position the band sits centered at the
    -- bottom and the bar is placed inside it.
    art:SetScale(bar:GetScale() or 1)
    art:ClearAllPoints()
    local moved = BarMoved(bar)
    ns.barMoved = moved
    if moved then
        art:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -ROW_X, -ROW_Y)
    else
        art:SetPoint("BOTTOM", UIParent, "BOTTOM", ns.db.barOffsetX or 0, ns.db.barOffsetY or 0)
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", ROW_X, ROW_Y)
    end
    art:Show()
    PaintArt()
    ApplyArtShape(bar)
    if bar.EndCaps then bar.EndCaps:Hide() end
    if bar.BorderArt then bar.BorderArt:SetAlpha(0) end
    if bar.HorizontalDividersPool then bar.HorizontalDividersPool:ReleaseAll() end
    if bar.VerticalDividersPool then bar.VerticalDividersPool:ReleaseAll() end
    LayoutButtons(bar, 1, "BOTTOMLEFT", art, "BOTTOMLEFT", ROW_X, ROW_Y)
    LayoutPageArrows(bar)

    local lower, upper = MultiBarBottomLeft, MultiBarBottomRight
    BandRow(lower, 2, ROW_X, UPPER_ROW_Y)
    -- Bar 3 sits beside bar 2 on the full band; on the half band it has
    -- no room there, so it stacks over bar 2 and the pet row moves up.
    if OneBar() then
        BandRow(upper, 3, ROW_X, UPPER_ROW_Y + BUTTON_PITCH)
    else
        BandRow(upper, 3, ROW_X + 12 * BUTTON_PITCH + 8, UPPER_ROW_Y)
    end
    LayoutPetRow(OneBar() and BUTTON_PITCH or 0)
    LayoutSideBars()
    if ns.db.hideExtraBars then DisableExtraBarsInSettings() end
    LayoutExtraBars(ns.db.hideExtraBars)
    ns.HookGlobal("MultiActionBar_Update", FollowSettings)
    LayoutBags()
    LayoutMicroButtons()
    LayoutStatusBars()
    AfterLayout()
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
    if ns.WorldMapMicroButton then ns.WorldMapMicroButton:Hide() end
    if bar then
        if bar.BorderArt then bar.BorderArt:SetAlpha(1) end
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
    for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        if container then
            container:SetAlpha(1)
            if container.BarFrameTexture then container.BarFrameTexture:SetAlpha(1) end
            if container.HorizontalDividersPool then
                for divider in container.HorizontalDividersPool:EnumerateActive() do divider:SetAlpha(1) end
            end
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
-- When a burst is cut off, one trailing pass runs after it settles, so
-- whatever Blizzard did last never stays on screen.
local lastHook, hookBurst, trailing = 0, 0, false
-- While edit mode is open the client relays out a system on every
-- setting the player touches; a pass of ours per call made the dialog
-- stutter, so those are gathered into one pass a quarter second later.
local editQueued = false
local function QueueEditPass()
    if editQueued then return end
    editQueued = true
    C_Timer.After(0.25, function()
        editQueued = false
        if active then ns.QueueApply() end
    end)
end

local function OnBlizzardLayout()
    if not active or applying then return end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        QueueEditPass()
        return
    end
    local now = GetTime()
    if now - lastHook < 0.5 then hookBurst = hookBurst + 1 else hookBurst = 0 end
    lastHook = now
    if hookBurst > 8 then
        if not trailing then
            trailing = true
            C_Timer.After(0.6, function()
                trailing = false
                if active then ns.QueueApply() end
            end)
        end
        return
    end
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
    -- A drag of bar 1 in edit mode is the one move the band follows; its
    -- reset-to-default button hands the placement back to the band.
    if EditModeManagerFrame then
        ns.HookMethod(EditModeManagerFrame, "OnSystemPositionChange", function(_, systemFrame)
            if active and systemFrame == bar and EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive() then
                ns.db.barDragged = true
            end
        end)
    end
    ns.HookMethod(bar, "ResetToDefaultPosition", function()
        if ns.db.barDragged then
            ns.db.barDragged = false
            ns.QueueApply()
        end
    end)
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
    -- The containers are not protected, so they go straight back into the
    -- band even in combat, on every Blizzard pass that resizes or moves
    -- them (12.x resizes the bar to its own 1192px on many updates).
    local function StatusBack()
        if active and not applying then
            applying = true
            pcall(LayoutStatusBars)
            applying = false
        end
    end
    for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        if container then
            for _, method in ipairs({ "ApplyPendingBarToShow", "ResizeContainerBars", "InitializeBars", "ApplySystemAnchor", "UpdateDividers" }) do
                if type(rawget(container, method)) == "function" or container[method] then
                    ns.HookMethod(container, method, StatusBack)
                end
            end
        end
    end
    if StatusTrackingBarManager and StatusTrackingBarManager.UpdateBarsShown then
        ns.HookMethod(StatusTrackingBarManager, "UpdateBarsShown", StatusBack)
    end
    -- Edit mode's bottom-bar pass anchors the container to Action Bar 1's
    -- corner on every managed-frame change (a target with combo points is
    -- one); it is answered in the same call, and any anchor set on the
    -- container by anyone else is undone at once.
    if EditModeManagerFrame then
        ns.HookMethod(EditModeManagerFrame, "UpdateBottomActionBarPositions", StatusBack)
    end
    for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        if container then
            hooksecurefunc(container, "SetPoint", function(_, _, relativeTo)
                if active and not applying and relativeTo ~= art then StatusBack() end
            end)
        end
    end
    for _, cap in ipairs({ bar.EndCaps and bar.EndCaps.LeftEndCap, bar.EndCaps and bar.EndCaps.RightEndCap }) do
        if cap then
            ns.HookMethod(cap, "UpdateVisibility", function(self) if active then self:Hide() end end)
            cap:HookScript("OnShow", function(self) if active then self:Hide() end end)
        end
    end
    if type(rawget(bar, "UpdateEndCaps")) == "function" then
        hooksecurefunc(bar, "UpdateEndCaps", function(self)
            if not active then return end
            if self.EndCaps then self.EndCaps:Hide() end
            -- Hide Bar Art flipped in edit mode: only the band's own art
            -- answers it, so the gryphons go without a whole layout pass,
            -- which stuttered while the setting was being flipped.
            if art and (self.hideBarArt == true) ~= (art.artHidden == true) then ApplyArtShape(self) end
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
    -- Blizzard's bag bar re-anchors the bag buttons every time it lays
    -- itself out (bag changes, the expand toggle, edit mode). Put them
    -- straight back, and the micro row with them, instead of waiting for
    -- a full pass that the burst cut-off above can swallow.
    local function ReflowBags()
        if active and not applying and not InCombatLockdown() then
            LayoutBags()
            LayoutMicroButtons()
        end
    end
    if BagsBar then
        for _, method in ipairs({ "Layout", "UpdateLayout", "SetBagsBarExpanded", "OnBagsBarExpandToggled" }) do
            if type(rawget(BagsBar, method)) == "function" then hooksecurefunc(BagsBar, method, ReflowBags) end
        end
        BagsBar:HookScript("OnShow", ReflowBags)
    end
    if BagBarExpandToggle then BagBarExpandToggle:HookScript("OnClick", ReflowBags) end
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
    watcher:RegisterEvent("UPDATE_EXHAUSTION")
    watcher:RegisterEvent("PLAYER_UPDATE_RESTING")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("PLAYER_XP_UPDATE")
    watcher:SetScript("OnEvent", function(_, event)
        if event ~= "PLAYER_REGEN_ENABLED" then
            RecolorExpBars()
            return
        end
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
