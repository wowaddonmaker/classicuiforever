local _, ns = ...

-- The 1.x main menu bar: a 1024x53 stone band centered at the bottom with
-- a gryphon on each end. Blizzard's action buttons, page arrows, micro
-- buttons, bag buttons and experience bars are re-anchored onto it, one
-- by one, in their 2004 spots. Edit mode keeps working for everything
-- else, and while edit mode is open the bar hands everything back.

local ART_W, ART_H = 1024, 53
local BAND_H, STRIP_H = 43, 10
local CAP_SIZE = 128
local BUTTON_SIZE, BUTTON_PITCH = 36, 42   -- 36px buttons, 6px apart
local ROW_X, ROW_Y = 8, 4                   -- first button from the band's corner
local UPPER_ROW_Y = 55                      -- bars 2 and 3: 3px above the experience strip inside the band top
local PET_ROW_Y = 104                       -- stance, pet and possess bars above those
local TWO_BAR_LIFT = 9                      -- all of those, while a second bar stands over the experience bar
local STANCE_X, PET_X = 30, 36
local SMALL_PITCH, SMALL_BUTTON = 33, 30    -- 30px buttons on the pet and stance bars
local SIDE_BAR_X, SIDE_BAR_Y, SIDE_BAR_GAP = -2, 98, 6   -- right bars hang from the bottom right corner
local PAGE_X, PAGE_UP_Y, PAGE_DOWN_Y = 522, -22, -42
-- The page arrows and the page number stand just past the twelfth
-- button, and a band that ends at bar 1 still has to hold them: this
-- much of the third sheet stays, and the gryphon comes after it.
local PAGE_ROOM = 36
-- One-bar mode has no right half of the band to carry the micro menu and
-- the bags, so they take the screen's bottom right corner instead, in
-- their old art: the micro row along the corner, the bags above it.
-- One-bar mode keeps the micro menu and the bags off the band, stacked
-- in the screen's bottom right corner until the player moves them: the
-- micro group on the floor of the screen, the bags' piece of art on top
-- of it. The bag numbers are the backpack's corner, which sits 4 in and 6
-- up on its art.
local CORNER_X = -6
-- The 1.x overlap of 3px; more than that and the drawn buttons crowd.
-- With the shop button out the row scales to about nine tenths.
local MICRO_X, MICRO_Y, MICRO_W, MICRO_H, MICRO_STEP = 555, 2.5, 28, 38, -3
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
-- The latency bar's place in the art is the dark slot left of the key
-- ring: this far in from the key ring button, and this far up.
-- How far short of the key ring the micro row stops: the post between
-- the two. There is no latency bar: the game menu button already shows
-- latency by its color, so the old bar would say the same thing twice.
local MICRO_END_GAP = 5
-- 1.x had no reagent bag and the art has no socket for one, so it is a
-- small round button straddling the key ring and the last bag slot, up
-- at their top corner, rather than a slot of its own in the band.
local REAGENT_SIZE = 17

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
local Snapshot
local saved = {}   -- frame -> { scale, parent, w, h }

local function Remember(frame)
    if not saved[frame] then
        saved[frame] = { scale = frame:GetScale(), parent = frame:GetParent(), w = frame:GetWidth(), h = frame:GetHeight() }
    end
end

-- Edit mode's Icon Size, as a scale. The client applies that setting by
-- scaling each button's container, which this layout then overwrites
-- with the 1.x button size, so it is read here instead and carried by
-- the bar itself: every bar wears its own setting, and Action Bar 1's
-- is the size of the whole band, since the art, the bags, the micro
-- menu and the status bars all hang off the band and grow with it.
local function BarSetting(bar, key)
    if not bar or not bar.GetSettingValue or not Enum or not Enum.EditModeActionBarSetting then return nil end
    local setting = Enum.EditModeActionBarSetting[key]
    if setting == nil then return nil end
    local ok, value = pcall(bar.GetSettingValue, bar, setting)
    if ok and type(value) == "number" then return value end
    return nil
end

-- A bar's own orientation and rows, as set in edit mode. The old rows
-- and columns were laid out one way only, across on the band and down at
-- the screen's edge, and a bar turned the other way in edit mode, or
-- folded into more rows, stayed as it was: the setting changed and the
-- buttons did not.
local function BarVertical(bar)
    local value = BarSetting(bar, "Orientation")
    if value == nil then return nil end
    local vertical = Enum and Enum.ActionBarOrientation and Enum.ActionBarOrientation.Vertical or 1
    return value == vertical
end

local function BarRows(bar)
    return math.max(1, math.floor(BarSetting(bar, "NumRows") or 1))
end

local function IconScale(bar)
    local scale
    do
        local value = BarSetting(bar, "IconSize")
        if value and value > 0 then scale = value / 100 end
    end
    if not scale then scale = (bar and bar.GetScale and bar:GetScale()) or 1 end
    -- The band's own size is one of two: the true 1.x size, or with the
    -- toggle on the game's, whose buttons are 45 pixels to the old 36.
    -- The old free-form bar scale is no longer read: it was never
    -- offered anywhere but a test command, and a value left behind by
    -- that command multiplied with the toggle.
    local own = (ns.db and ns.db.defaultBarSize == true) and (45 / 36) or 1
    if own <= 0 then own = 1 end
    if scale <= 0 then scale = 1 end
    return scale * own
end

local function BandScale(bar) return IconScale(bar or ns.GetMainBar()) end
ns.BandScale = BandScale

-- The size the band is wearing right now. A frame that only hangs off
-- the band, rather than sitting inside it, is given this itself, or it
-- keeps screen size while the band grows and its offsets land short.
local function BandNow()
    local scale = art and art.GetScale and art:GetScale() or 1
    if not scale or scale <= 0 then scale = 1 end
    return scale
end

-- One bar of the band at the band's own size. A protected bar only takes
-- a scale out of combat, which is the only time this layout runs.
local function MatchScale(frame, scale)
    if not frame or not frame.SetScale or not frame.GetScale then return end
    if math.abs((frame:GetScale() or 1) - scale) < 0.005 then return end
    Remember(frame)
    frame:SetScale(scale)
end

-- The band is drawn for two bars side by side. In one-bar mode it stops
-- after the twelve main slots, the right gryphon beside them, and the
-- bottom right bar, micro menu and bags stay where edit mode puts them.
local function OneBar() return ns.db and ns.db.oneBar == true end

-- What the band is made of, left to right: bar 1's half (512), then the
-- micro menu's region, then the bags' part. The micro menu and the bags
-- are pieces of their own in edit mode, and the band is only as long as
-- what is still on it, with the right gryphon on the last thing left:
--   nothing moved     bar 1 + micro + bags
--   bags moved        bar 1 + micro
--   micro moved       bar 1 + bags: the bags close up against bar 1's
--                     page arrows, so there is never a gap to jump
--   both moved        bar 1 alone
-- The micro region is no wider than its row needs, up to the 300 the old
-- art gave it (the third piece and the dark start of the fourth).
-- Measured on screen, not from the bundled sheet: the client's own copy
-- of the fourth sheet, which is the one drawn, has no post left of the key
-- ring at all: the dark run goes right up to the key ring button, which
-- carries its own iron frame and starts 74 in. The one real post nearby
-- stands just right of the key ring, at about 82 to 90.
local MICRO_LEAD, MICRO_REGION_MAX, BAG_PART = 45, 330, 182
-- That post, for the ends of a group that has left the band: where it
-- starts in the fourth sheet and how wide it is.
local POST_U, POST_W = 82, 8
-- The micro group's own rectangle starts a little before its first button.
local MICRO_GROUP_X = 548
local shape = { micro = true, bags = true, region = MICRO_REGION_MAX, scale = 1 }

-- The micro menu is moved by a handle of ours, not by the client's edit
-- mode piece: the client lays that piece out again and again while edit
-- mode is open, and a box of its own would not stay the size of the row.
-- Where it was put, and how big, is kept in the saved settings.
local function MicroOut() return ns.db and ns.db.microPos ~= nil end

-- The micro menu is a piece of ours, not one of edit mode's, so moving it
-- never lit edit mode's Save: it was kept the moment it was let go, and
-- nothing on screen said so. Now the first change made to it in an edit
-- mode session is noted, with how things stood before it, and while the
-- note stands Save and Revert All Changes are lit (see the edit mode
-- watcher). Save settles it; Revert All Changes puts back what was noted.
function ns.MicroTouched()
    if ns.microDirty or not ns.db then return end
    local pos = ns.db.microPos
    ns.microBefore = {
        pos = type(pos) == "table" and { point = pos.point, relPoint = pos.relPoint, x = pos.x, y = pos.y } or nil,
        scale = ns.db.microScale,
        bagsFirst = ns.db.bagsFirst,
    }
    ns.microDirty = true
end
local function MicroUserScale()
    local value = tonumber(ns.db and ns.db.microScale) or 1
    return math.max(0.5, math.min(2, value))
end

-- While a group is being dragged the band shows what letting go would
-- do: held near its place the band is drawn with the group on it, held
-- away the band is drawn without. nil when nothing is being dragged.
local dragPreview = {}

local function OnBandMicro() return shape.micro and not OneBar() end
local function OnBandBags() return shape.bags and not OneBar() end

-- Where everything past bar 1 stands, for a given load. The two groups
-- can stand in either order, whichever the player snapped them into:
--   micro first   bar 1 | micro region (its head holds the page arrows) | bags
--   bags first    bar 1 | room for the page arrows | bags | micro region
-- The micro region standing second has no page arrows to make room for,
-- so its head is only a small margin. A group alone is always first.
local MICRO_SECOND_LEAD = 8
local MICRO_ROW_IN = 7      -- the group's own rectangle starts this far before its first button

-- Bar 1 set to fewer than twelve icons in edit mode takes the band in
-- from the left, as the client's own bar does: the slots it has lost come
-- off the band's left end, and the left gryphon and the experience bar
-- close in with it. The cut is whole slots, so the art is cut on a slot
-- line. Everything past bar 1 keeps its distance from bar 1's last slot.
local function BandPlan(microOn, bagsOn, bagsFirst, region)
    local plan = { bagsFirst = (bagsFirst and microOn and bagsOn) and true or false }
    plan.cut = shape.cut or 0
    local x = ART_W / 2 - plan.cut
    plan.base = x
    plan.microFirst = (microOn and not plan.bagsFirst) and true or false
    -- Edit mode's Hide Bar Scrolling: with the page arrows gone their
    -- place on the band goes too, and what follows closes up to bar 1.
    -- The micro region standing first is then drawn the way it is when
    -- it stands second, without the head that holds the arrows.
    plan.noPages = shape.noPages and true or false
    if plan.microFirst and plan.noPages then
        plan.microStart, plan.microRow = x, x + MICRO_SECOND_LEAD
        x = x + region - MICRO_LEAD + MICRO_SECOND_LEAD
        plan.microEnd = x
        if bagsOn then plan.bagsStart = x x = x + BAG_PART end
    elseif plan.microFirst then
        plan.microStart, plan.microRow = x, x + (MICRO_X - ART_W / 2)
        x = x + region
        plan.microEnd = x
        if bagsOn then plan.bagsStart = x x = x + BAG_PART end
    else
        if not plan.noPages then x = x + PAGE_ROOM end
        if bagsOn then plan.bagsStart = x x = x + BAG_PART end
        if microOn then
            plan.microStart, plan.microRow = x, x + MICRO_SECOND_LEAD
            x = x + region - MICRO_LEAD + MICRO_SECOND_LEAD
            plan.microEnd = x
        end
    end
    plan.width = x
    return plan
end

local function CurrentPlan()
    if not shape.plan then shape.plan = BandPlan(OnBandMicro(), OnBandBags(), ns.db and ns.db.bagsFirst, shape.region) end
    return shape.plan
end

local function ArtWidth() return CurrentPlan().width end

-- The art as runs of the four sheets: { x, width, sheet, u0, u1 }.
local function Segments()
    local plan = CurrentPlan()
    local cut = plan.cut
    local list = {}
    if cut < 256 then
        list[1] = { 0, 256 - cut, 1, cut / 256, 1 }
        list[2] = { 256 - cut, 256, 2, 0, 1 }
    else
        list[1] = { 0, 512 - cut, 2, (cut - 256) / 256, 1 }
    end
    local half = plan.base
    local headless = plan.microFirst and plan.noPages
    if plan.microFirst and not headless then
        local region = plan.microEnd - plan.microStart
        local third = math.min(region, 256)
        list[#list + 1] = { half, third, 3, 0, third / 256 }
        if region > 256 then list[#list + 1] = { half + 256, region - 256, 4, 0, (region - 256) / 256 } end
    elseif not plan.microFirst and not plan.noPages then
        list[#list + 1] = { half, PAGE_ROOM, 3, 0, PAGE_ROOM / 256 }
    end
    if plan.bagsStart then
        list[#list + 1] = { plan.bagsStart, BAG_PART, 4, (256 - BAG_PART) / 256, 1 }
    end
    if plan.microStart and (not plan.microFirst or headless) then
        -- The region standing second: the third sheet from past its page
        -- arrow head, and the dark start of the fourth if it runs long.
        local width = plan.microEnd - plan.microStart
        local u0 = MICRO_LEAD - MICRO_SECOND_LEAD
        local first = math.min(width, 256 - u0)
        list[#list + 1] = { plan.microStart, first, 3, u0 / 256, (u0 + first) / 256 }
        if width > first then
            list[#list + 1] = { plan.microStart + first, width - first, 4, 0, (width - first) / 256 }
        end
    end
    return list
end

local function BuildArt()
    art = CreateFrame("Frame", "ForeverClassicUIBar", UIParent)
    art:SetSize(ART_W, ART_H)
    art:SetFrameStrata("MEDIUM")
    art:SetFrameLevel(1)
    art.pieces = {}
    for i = 1, 7 do
        art.pieces[i] = art:CreateTexture(nil, "BACKGROUND")
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
    local segments = Segments()
    for i, tex in ipairs(art.pieces) do
        local seg = segments[i]
        if seg then
            local piece = PIECES[seg[3]]
            ns.SetTex(tex, piece.key)
            tex:SetTexCoord(seg[4], seg[5], piece.band[1], piece.band[2])
            tex:SetSize(seg[2], BAND_H)
            tex:ClearAllPoints()
            tex:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", seg[1], 0)
            tex:Show()
        else
            tex:Hide()
        end
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

-- The gryphons are pieces of their own, as the client makes its two end
-- caps: each can be dragged off in edit mode, hidden from its dialog, and
-- put back. The client's cap frames are the handles. Ours are only
-- pictures, hung from those frames, and the client's own cap art is
-- faded out of them. A cap the player has not moved is laid on its end
-- of the band, wherever that end now is; one they have moved stays put,
-- and let go near its end of the band it snaps back onto it.
--
-- "Moved" is only ever a drag we saw happen. The client also turns a
-- cap's place into a fixed spot by itself whenever bar 1 is moved or
-- hidden, and that stray spot must not count as the player's choice.
local CAP_KEYS = { "LeftEndCap", "RightEndCap" }

local function CapFrame(bar, key)
    local caps = bar and bar.EndCaps
    return caps and caps[key] or nil
end

-- Whether a cap is the player's, dragged off the band. The client is
-- asked, not our own note of it: the note is a table in the saved
-- settings, and this client drops those between sessions. With the note
-- gone, a cap dragged and saved was taken for the band's again at the
-- next login, stood back on the band, and then put back to its default
-- in the layout itself by the next press that reloaded the interface.
-- Nothing of ours ever moves a cap in the layout, only back to default,
-- so a cap the client says is off its default was put there by hand.
local function CapMoved(key)
    if ns.db and ns.db.capMoved and ns.db.capMoved[key] == true then return true end
    local bar = ns.GetMainBar and ns.GetMainBar()
    local cap = bar and bar.EndCaps and bar.EndCaps[key]
    if not cap or type(cap.IsInDefaultPosition) ~= "function" then return false end
    if cap.IsInitialized then
        local okInit, ready = pcall(cap.IsInitialized, cap)
        if not okInit or not ready then return false end
    end
    local ok, isDefault = pcall(cap.IsInDefaultPosition, cap)
    return ok and isDefault == false
end

local function CapHidden(cap)
    local setting = Enum and Enum.EditModeMainActionBarEndCapSetting and Enum.EditModeMainActionBarEndCapSetting.Hidden
    if not cap or setting == nil or not cap.GetSettingValueBool then return false end
    local ok, hidden = pcall(cap.GetSettingValueBool, cap, setting)
    return ok and hidden and true or false
end

-- Where a cap sits on the band: its bottom middle, from the band's.
local function CapSlot(key, w) return (key == "LeftEndCap" and -1 or 1) * (w / 2 + 32) end

local function PlaceCaps(bar, w, hideArt)
    local container = bar and bar.EndCaps
    if container and not container:IsShown() then container:Show() end
    for _, key in ipairs(CAP_KEYS) do
        local tex = key == "LeftEndCap" and art.leftCap or art.rightCap
        local cap = CapFrame(bar, key)
        tex:ClearAllPoints()
        if cap and cap.GetPoint then
            for _, region in ipairs({ cap:GetRegions() }) do
                if region:IsObjectType("Texture") and region:GetAlpha() > 0 then region:SetAlpha(0) end
            end
            -- Reset To Default Position from the cap's own dialog: it is
            -- the band's again.
            if CapMoved(key) and type(cap.IsInDefaultPosition) == "function" then
                local ok, isDefault = pcall(cap.IsInDefaultPosition, cap)
                if ok and isDefault then ns.db.capMoved[key] = nil end
            end
            if not CapMoved(key) and not cap.isDragging then
                ns.OverlayOnBand(cap, "BOTTOM", "BOTTOM", CapSlot(key, w), 0, CAP_SIZE, CAP_SIZE)
            end
            -- The picture rides the frame, at the band's size whatever
            -- size the frame itself is.
            tex:SetPoint("BOTTOM", cap, "BOTTOM", 0, 0)
            tex:SetShown(not hideArt and not CapHidden(cap))
        else
            tex:SetPoint("BOTTOM", art, "BOTTOM", CapSlot(key, w), 0)
            tex:SetShown(not hideArt)
        end
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
    PlaceCaps(bar, w, hide)
    for i, tex in ipairs(art.maxLevel) do
        -- Cut to the band's length, which is no longer a whole number
        -- of sheets.
        local seen = math.max(0, math.min(256, w - (i - 1) * 256))
        tex:ClearAllPoints()
        tex:SetPoint("BOTTOMLEFT", art, "TOPLEFT", (i - 1) * 256, -11)
        tex:SetWidth(math.max(seen, 1))
        tex:SetTexCoord(0, seen / 256, (i - 1) * 0.25, (i - 1) * 0.25 + 0.21875)
        tex.fcuiInBand = seen > 0
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
local function LayoutButtons(bar, rowIndex, point, relTo, relPoint, x, y, vertical, pitch, target, origin, rows)
    if not bar or not bar.actionButtons then return end
    local first = bar.actionButtons[1]
    local size = first and first:GetWidth() or 45
    if not size or size == 0 then size = 45 end
    -- Scale the buttons to their 1.x size: 36px on the action bars, 30px
    -- on the pet and stance bars.
    local scale = (target or BUTTON_SIZE) / size
    local step = (pitch or BUTTON_PITCH) / scale
    -- This bar's own Icon Size. The client puts that size on the buttons
    -- and leaves the bar frame alone, and the frame is what edit mode
    -- draws its box around; scaling the frame as well would count the
    -- setting twice and the box would come out larger than the buttons.
    -- So the size rides on the containers here too, and the bar keeps
    -- the plain scale with its rectangle set to what was drawn.
    local icon = IconScale(bar)
    MatchScale(bar, 1)
    local band = (art and art:GetScale()) or 1
    if band <= 0 then band = 1 end
    -- Where the row starts and how big its buttons are answer to two
    -- different sizes. A row on the band is placed in band pixels, so it
    -- keeps its line whatever size its own buttons take; a column at the
    -- screen's corner is placed at its own size. The buttons' step is
    -- read on the containers, which carry their bar's size already.
    origin = origin or band
    if origin <= 0 then origin = 1 end
    local row = Row(rowIndex)
    row:SetScale(origin / band)
    row:ClearAllPoints()
    row:SetPoint(point, relTo, relPoint, x, y)
    -- How many slots this bar is set to: edit mode's own number, or the
    -- buttons it has where the client does not say. The rectangle is
    -- drawn over those, so shortening a bar shortens its box with it.
    local slots = BarSetting(bar, "NumIcons")
    -- Folded into rows (columns, for a bar standing up): so many to a
    -- line, the lines stacked upward for a bar lying down and to the
    -- right for one standing up.
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
    -- The bar's own rectangle is exactly the buttons it now shows, so
    -- edit mode's box sits on them at any size. Whole pixels, and only
    -- when it has actually changed: the client lays the bar out again
    -- whenever its size moves, which calls us back, and a rectangle that
    -- differed by a hair each pass had the buttons drifting under it.
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
    local pageX = CurrentPlan().base + (PAGE_X - ART_W / 2)
    pn:ClearAllPoints()
    pn:SetPoint("CENTER", art, "TOPLEFT", pageX, (PAGE_UP_Y + PAGE_DOWN_Y) / 2)
    pn:SetSize(32, 76)
    pn:SetScale(BandNow())
    -- Edit mode's Hide Bar Scrolling for Action Bar 1: the client hides
    -- the arrows and the number for it, and showing them here regardless
    -- left the tick box doing nothing.
    pn:SetShown(BarSetting(bar, "HideBarScrolling") ~= 1)
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
-- laying itself out, edit mode, the expand toggle) is undone by the
-- layout watch further down, which is where every such answer lives now.
-- Lays one of the client's edit mode pieces over a rectangle of the
-- band, given in the band's own pixels. The piece has a scale of its
-- own, and an offset is read in the scale of the frame being placed.
function ns.OverlayOnBand(frame, point, bandPoint, x, y, w, h, relativeTo)
    if not frame or not art then return end
    local fs = frame:GetEffectiveScale() / art:GetEffectiveScale()
    if not fs or fs <= 0 then fs = 1 end
    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo or art, bandPoint, x / fs, y / fs)
    frame:SetSize(w / fs, h / fs)
end

local function LayoutBags()
    local backpack = MainMenuBarBackpackButton
    if not backpack then return end
    -- Where the row hangs. On the band: in the bag part's sockets. Moved
    -- in edit mode: on the client's own bags piece, wherever it was put.
    -- One-bar mode: the corner.
    local piece = BagsBar
    local out = piece and not shape.bags
    local lift = (KEYRING_H - BAG_SIZE) / 2
    local home, homePoint, homeY = art, "BOTTOMRIGHT", BAGS_Y
    local homeX
    local buttonScale = 1
    local rowW = BAG_SIZE + (BAG_SIZE - BACKPACK_GAP) + 3 * (BAG_SIZE - BAG_OVERLAP)
    if KeyRingButton or CharacterReagentBag0Slot then rowW = rowW + KEYRING_W - KEYRING_GAP end
    -- Off the bar, moved by hand or standing in one-bar mode's corner,
    -- the row is the size edit mode's Size says. On the bar it is always
    -- socket size.
    -- The row is the band's child, and the band's scale is bar 1's icon
    -- size. Only what is attached to the band sizes with bar 1: a row
    -- that is off it has the band's scale divided out of its own.
    local band = (art:GetScale() or 1)
    if band <= 0 then band = 1 end
    if piece and (out or OneBar()) then
        buttonScale = (piece:GetScale() or 1) / band
    elseif piece then
        -- On the band the row sizes with the band, times the player's own
        -- Size for the bags, which is theirs to set here too even though
        -- it no longer fits the sockets; snapping the bags back into
        -- place is what resets it.
        buttonScale = piece:GetScale() or 1
    end
    if out then
        home, homeX, homeY = piece, 0, lift
    else
        local relativeTo
        if OneBar() then
            -- Over the micro group while that still stands in the corner,
            -- on the floor of the screen once it has been moved away.
            local under = MicroOut() and 0 or BAND_H * MicroUserScale() / band
            relativeTo, homeX, homeY = art.sideAnchor, CORNER_X - 4 * buttonScale, under + 6 * buttonScale
        else
            -- By the plan, from the band's left: the bags are not always
            -- the last thing on it.
            local plan = CurrentPlan()
            homePoint, homeX = "BOTTOMLEFT", (plan.bagsStart or (plan.width - BAG_PART)) + BAG_PART + BAGS_X
        end
        -- Wherever the row stands by default it hangs from the client's
        -- bags piece, which is laid over it first: edit mode's box then
        -- sits on the bags, and a drag of it carries them as it goes.
        -- A piece in the middle of a drag is left in the player's hand.
        if piece then
            if not piece.isDragging then
                ns.OverlayOnBand(piece, "BOTTOMRIGHT", homePoint, homeX, homeY - lift * buttonScale, rowW * buttonScale, KEYRING_H * buttonScale, relativeTo)
            end
            home, homePoint, homeX, homeY = piece, "BOTTOMRIGHT", 0, lift
        elseif relativeTo then
            home = relativeTo
        end
    end
    local level = ButtonLevel()
    local prev
    -- Right to left into the band sockets: backpack in the corner, the
    -- four bags overlapping by 2px, then the key ring hole.
    for _, name in ipairs(BAG_BUTTONS) do
        local button = _G[name]
        if button then
            Remember(button)
            if button:GetParent() ~= art then button:SetParent(art) end
            button:SetScale(buttonScale)
            button:SetSize(BAG_SIZE, BAG_SIZE)
            button:SetFrameLevel(level)
            button:ClearAllPoints()
            if not prev then
                button:SetPoint("BOTTOMRIGHT", home, homePoint, homeX / buttonScale, homeY / buttonScale)
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
    local lastBag = prev
    -- The key ring hole takes the key ring where the client has one; a
    -- client without one puts its reagent bag there wearing the key ring art.
    local slim = KeyRingButton or CharacterReagentBag0Slot
    if slim then
        Remember(slim)
        if slim:GetParent() ~= art then slim:SetParent(art) end
        slim:SetScale(buttonScale)
        slim:SetSize(KEYRING_W, KEYRING_H)
        slim:SetFrameLevel(level)
        slim:ClearAllPoints()
        slim:SetPoint("RIGHT", prev, "LEFT", KEYRING_GAP, 0)
        ns.SkinKeyRing(slim)
        prev = slim
    end
    if KeyRingButton and CharacterReagentBag0Slot then
        -- Both exist (Forever): the reagent bag is the small round one.
        local reagent = CharacterReagentBag0Slot
        Remember(reagent)
        if reagent:GetParent() ~= art then reagent:SetParent(art) end
        reagent:SetScale(buttonScale)
        reagent:SetSize(REAGENT_SIZE, REAGENT_SIZE)
        reagent:SetFrameLevel(level + 2)
        reagent:ClearAllPoints()
        -- Its center level with the bags' own, on the line between the
        -- key ring and the last bag.
        reagent:SetPoint("CENTER", lastBag, "LEFT", -2, 0)
        ns.SkinBagButton(reagent, REAGENT_SIZE, false, false, true)
    end
    art.slimSlot = prev
    -- The client's bags piece is laid over the row so that edit mode's
    -- box for it sits on the bags and can be taken hold of there; once
    -- it has been moved, it is only sized to the row it now carries.
    if piece and out then piece:SetSize(rowW, KEYRING_H) end
    -- Off the band the row takes its piece of the band with it: the bag
    -- part of the art, sockets and all, as its floor. The empty slots
    -- get their old dim bag from that art, on the band and off it; with
    -- nothing behind them they were see-through.
    local floor = art.bagFloor
    local floating = (out or OneBar()) and true or false
    if floating then
        if not floor then
            floor = CreateFrame("Frame", nil, art)
            floor:SetSize(BAG_PART, BAND_H)
            floor.tex = floor:CreateTexture(nil, "BACKGROUND")
            floor.tex:SetAllPoints(floor)
            -- The art has nothing to end the group with on its left, the
            -- band having carried on there: an iron post, cut from the
            -- one beside the key ring, closes it.
            floor.post = floor:CreateTexture(nil, "BORDER")
            art.bagFloor = floor
        end
        local postSheet = PIECES[4]
        ns.SetTex(floor.post, postSheet.key)
        -- Mirrored, so it reads as a left end and not as the right side
        -- of something cut off, and standing just outside the key ring.
        floor.post:SetTexCoord((POST_U + POST_W) / 256, POST_U / 256, postSheet.band[1], postSheet.band[2])
        floor.post:SetSize(POST_W, BAND_H)
        floor.post:ClearAllPoints()
        floor.post:SetPoint("BOTTOMRIGHT", floor, "BOTTOMLEFT", 1, 0)
        floor.post:Show()
        local sheet = PIECES[4]
        ns.SetTex(floor.tex, sheet.key)
        floor.tex:SetTexCoord((256 - BAG_PART) / 256, 1, sheet.band[1], sheet.band[2])
        floor:SetScale(buttonScale)
        floor:SetFrameLevel(math.max(0, level - 1))
        floor:ClearAllPoints()
        floor:SetPoint("BOTTOMRIGHT", backpack, "BOTTOMRIGHT", -BAGS_X, -BAGS_Y)
        floor:Show()
    elseif floor then
        floor:Hide()
    end
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
-- The map button's click, during a fight. The button is ours, so a map
-- opened from its click is opened in the addon's name, and the client
-- refuses that in combat: "interface action failed". The client has one
-- button of its own that opens the map, the zone name over the minimap,
-- and a secure button may press another button for the player. So a
-- secure pad lies over ours and presses that one; the map key goes the
-- same road.
--
-- The pad hangs from the screen, never from our button or the band: a
-- frame a secure frame is anchored to is locked in combat along with
-- it, and the micro row has to stay free to be put back during a fight.
-- It is laid over the button by measure, out of combat, whenever the
-- button has moved.
-- One pad to a button of ours that opens the map: the micro button here,
-- and the quest log window's Show Map. A map opened from a click of ours
-- out of combat is no better than one refused in it: everything that
-- opening makes (the pins on the map, above all) is made in the addon's
-- name, and the map key pressed in a later fight was blocked on them.
local mapPads = {}
local MapPad
-- The same pad serves any button of ours whose work has to begin in a
-- secure click: `target` is the secure button pressed in place of the
-- zone name, and `when` says whether the pad is wanted at the moment.
MapPad = function(button, strata, after, target, when)
    local zone = target or (MinimapCluster and MinimapCluster.ZoneTextButton)
    if not button or mapPads[button] or not zone then return end
    -- A secure frame cannot be made during a fight; it waits for the end.
    if InCombatLockdown() then
        local wait = CreateFrame("Frame")
        wait:RegisterEvent("PLAYER_REGEN_ENABLED")
        wait:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            MapPad(button, strata, after, target, when)
        end)
        return
    end
    local mapPad = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    mapPads[button] = mapPad
    mapPad:SetAttribute("type", "click")
    mapPad:SetAttribute("clickbutton", zone)
    -- On the release, whatever the cast on key down setting says.
    mapPad:SetAttribute("useOnKeyDown", false)
    mapPad:RegisterForClicks("AnyUp", "AnyDown")
    mapPad:SetFrameStrata(strata or "MEDIUM")
    mapPad:Hide()
    -- The pad has no art: the button under it shows the press and the glow.
    mapPad:SetScript("OnMouseDown", function() button:SetButtonState("PUSHED") end)
    mapPad:SetScript("OnMouseUp", function()
        if after or target or not (WorldMapFrame and WorldMapFrame:IsShown()) then button:SetButtonState("NORMAL") end
    end)
    if after then
        mapPad:SetScript("PostClick", function(_, _, down)
            if not down then after() end
        end)
    end
    mapPad:SetScript("OnEnter", function()
        button:LockHighlight()
        local enter = button:GetScript("OnEnter")
        if enter then enter(button) end
    end)
    mapPad:SetScript("OnLeave", function()
        button:UnlockHighlight()
        GameTooltip:Hide()
    end)
    -- With the pad over it the button's own click is never reached; it
    -- stays as it was for a client without the zone name button.
    local watch = CreateFrame("Frame")
    -- A pad over a button in a window (one with something to do after
    -- the click) goes down as a fight begins, the last moment it can:
    -- the window may shut during the fight, the pad could not follow,
    -- and it would lie there unseen, opening the map at a click meant
    -- for the world. The micro button never leaves, and keeps its pad.
    if after then
        watch:RegisterEvent("PLAYER_REGEN_DISABLED")
        watch:SetScript("OnEvent", function()
            if mapPad:IsShown() then mapPad:Hide() end
        end)
    end
    watch:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 0.2 then return end
        self.since = 0
        if InCombatLockdown() then return end
        local mgr = EditModeManagerFrame
        local editing = mgr and mgr.IsEditModeActive and mgr:IsEditModeActive()
        local left, bottom = button:GetLeft(), button:GetBottom()
        if not button:IsVisible() or editing or not left or not bottom or (when and not when()) then
            if mapPad:IsShown() then mapPad:Hide() end
            return
        end
        -- The button's rectangle, in the screen's own units.
        local ratio = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local x, y, w, h = left * ratio, bottom * ratio, button:GetWidth() * ratio, button:GetHeight() * ratio
        if not mapPad:IsShown() or math.abs((mapPad.x or -1) - x) > 0.5 or math.abs((mapPad.y or -1) - y) > 0.5
            or math.abs((mapPad.w or -1) - w) > 0.5 then
            mapPad.x, mapPad.y, mapPad.w = x, y, w
            mapPad:ClearAllPoints()
            mapPad:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
            mapPad:SetSize(w, h)
            mapPad:SetFrameLevel(button:GetFrameLevel() + 5)
            mapPad:Show()
        end
    end)
end
ns.MapPad = MapPad

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
    MapPad(button)
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
-- overlap and is scaled down as a whole so that it, and the latency bar
-- after it, end at the post before the key ring. Edit mode's Size for
-- the micro menu makes it smaller still, and the region with it.
local function MicroNeed(count)
    return count * (MICRO_W + MICRO_STEP) - MICRO_STEP
end

-- The row's scale and the region it takes, for this many buttons: fitted
-- to the room the old art gave it, times the player's own size for the
-- group. That size is theirs to set on the band as well as off it, as
-- the client lets its own pieces be sized where they stand, even where
-- the result no longer fits the art. What puts it right is snapping the
-- group back into place, which gives it its default size again.
local function MicroPlan(count, userScale)
    local need = MicroNeed(count)
    if need <= 0 then return 1, MICRO_LEAD + MICRO_END_GAP end
    local room = MICRO_REGION_MAX - MICRO_LEAD - MICRO_END_GAP
    local scale = math.min(1, room / need) * (userScale or 1)
    local region = math.ceil(MICRO_LEAD + need * scale + MICRO_END_GAP)
    return scale, math.min(MICRO_REGION_MAX, region)
end

-- The client's own edit mode box, which is a table local to its file:
-- the same nine pieces, named the same way.
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

-- Whether a frame has been let go close to a spot on the band, given in
-- the band's own pixels from its bottom left: close enough that it was
-- meant to go back there. Measured on screen, where every scale agrees.
local SNAP_PX = 48
-- fullW is the band's length with the group on it. The band is centered,
-- so its left edge moves as its length changes, and the preview changes
-- its length while the group is held: measured against the band as it
-- stands, the spot would jump away each time the preview caught it.
-- Returns whether it is near, and how far off it is on screen.
local function NearBandSlot(frame, bandX, bandY, corner, fullW)
    if not frame or not art then return false end
    local artScale, scale = art:GetEffectiveScale(), frame:GetEffectiveScale()
    local left, bottom = art:GetLeft(), art:GetBottom()
    if not artScale or not scale or not left or not bottom then return false end
    if fullW and not ns.barMoved then left = left + (art:GetWidth() or fullW) / 2 - fullW / 2 end
    local wantX, wantY = (left + bandX) * artScale, (bottom + bandY) * artScale
    local hasX = corner == "BOTTOMRIGHT" and frame:GetRight() or frame:GetLeft()
    local hasY = frame:GetBottom()
    if not hasX or not hasY then return false end
    local reach = SNAP_PX * UIParent:GetEffectiveScale()
    local dx, dy = math.abs(hasX * scale - wantX), math.abs(hasY * scale - wantY)
    return dx < reach and dy < reach, dx + dy
end

-- Where a held group would go if it were let go now: nil for nowhere on
-- the band, else whether the bags would stand first.
--
-- Judged on what is on screen, the way the player aims: the group is "on
-- the band" when it is held level with it, anywhere along it past bar
-- 1's own slots, and its place is decided by which side of the other
-- group its middle is on. Measuring against where the group would stand
-- after the band had grown and re-centered put the target well to the
-- left of anything the player could see, so a group dropped plainly
-- between bar 1 and the bags went to the far side of them instead. Once
-- a side is showing in the preview it holds until the group is clearly
-- past the other's middle, so the band re-centering under a still hand
-- does not flip it back and forth.
local function DropPlace(which, frame, current)
    if OneBar() or not frame or not art then return nil end
    local artScale, scale = art:GetEffectiveScale(), frame:GetEffectiveScale()
    local aL, aR, aB = art:GetLeft(), art:GetRight(), art:GetBottom()
    local fL, fR, fB = frame:GetLeft(), frame:GetRight(), frame:GetBottom()
    if not (artScale and scale and aL and aR and aB and fL and fR and fB) then return nil end
    local unit = UIParent:GetEffectiveScale()
    local reach = SNAP_PX * unit
    local middle = (fL + fR) / 2 * scale
    if math.abs(fB * scale - aB * artScale) > reach then
        return nil
    end
    local barEnd = (aL + CurrentPlan().base) * artScale
    if middle < barEnd - reach or middle > aR * artScale + 2 * reach then
        return nil
    end
    local otherOn
    if which == "micro" then otherOn = shape.bagsReal ~= false else otherOn = shape.microReal ~= false end
    if not otherOn then return false end
    -- Which side: by which half of the stretch past bar 1 the group's
    -- middle is over, with both groups counted on the band. That stretch
    -- is the same whichever order they stand in, so the line between
    -- the halves stays put while the preview swaps them about. Judging
    -- by the other group's own middle did not: the other group jumps
    -- most of the stretch when the order flips, which left a dead zone
    -- that wide where the preview would not change at all.
    local both = BandPlan(true, true, false, shape.region)
    local left = aL
    if not ns.barMoved then left = (aL + aR) / 2 - both.width / 2 end
    local line = (left + (both.base + both.width) / 2) * artScale
    local rel = middle - line
    -- Right half: the micro menu stands second, so the bags are first.
    -- For the bags it is the other way about.
    if which == "bags" then rel = -rel end
    local margin = 16 * unit
    local answer
    if current == true then answer = rel > -margin
    elseif current == false then answer = rel > margin
    else answer = rel > 0 end
    return answer
end

-- The micro group's settings, in the shape of the client's own edit mode
-- dialog: the same border, title, size slider and reset button, built
-- from the same templates. The client has no such dialog for a piece
-- that is not its own.
local function MicroDialog()
    local dialog = art.microDialog
    if dialog then return dialog end
    dialog = CreateFrame("Frame", "ForeverClassicUIMicroDialog", UIParent)
    dialog:SetSize(383, 204)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(200)
    dialog:SetMovable(true)
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog:Hide()
    art.microDialog = dialog

    local okBorder, border = pcall(CreateFrame, "Frame", nil, dialog, "DialogBorderTranslucentTemplate")
    if okBorder and border then
        border:SetAllPoints(dialog)
    else
        local ground = dialog:CreateTexture(nil, "BACKGROUND")
        ground:SetAllPoints(dialog)
        ground:SetColorTexture(0, 0, 0, 0.85)
    end

    local title = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    title:SetPoint("TOP", dialog, "TOP", 0, -15)
    title:SetText("Micro Menu")

    local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", 0, 0)
    close:SetScript("OnClick", function() dialog:Hide() end)

    local label = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    label:SetSize(100, 32)
    label:SetJustifyH("LEFT")
    label:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -48)
    label:SetText(HUD_EDIT_MODE_SETTING_MICRO_MENU_SIZE or "Size")

    local okSlider, slider = pcall(CreateFrame, "Frame", nil, dialog, "MinimalSliderWithSteppersTemplate")
    if okSlider and slider and slider.Init then
        slider:SetSize(200, 32)
        slider:SetPoint("LEFT", label, "RIGHT", 5, 0)
        dialog.slider = slider
        local function Percent(value) return string.format("%d%%", value) end
        local formatters
        if CreateMinimalSliderFormatter and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
            formatters = { [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Right, Percent) }
        end
        dialog.InitSlider = function()
            dialog.filling = true
            slider:Init(math.floor(MicroUserScale() * 100 + 0.5), 50, 200, 30, formatters)
            dialog.filling = false
        end
        if slider.RegisterCallback and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Event then
            slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
                if dialog.filling or type(value) ~= "number" then return end
                ns.MicroTouched()
                ns.db.microScale = math.max(0.5, math.min(2, value / 100))
                if ns.MirrorSave then ns.MirrorSave() end
                ns.QueueApply()
            end, dialog)
        end
    end

    local reset = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    reset:SetSize(330, 28)
    reset:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 22)
    reset:SetText(HUD_EDIT_MODE_RESET_POSITION or "Reset To Default Position")
    reset:SetScript("OnClick", function()
        -- Back into its place means back to its default size as well,
        -- so the bar's pieces fit together again.
        ns.MicroTouched()
        ns.db.microPos, ns.db.microScale = nil, nil
        if ns.MirrorSave then ns.MirrorSave() end
        dialog:Refresh()
        ns.QueueApply()
    end)
    dialog.reset = reset

    local resize = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    resize:SetSize(330, 28)
    resize:SetPoint("BOTTOM", reset, "TOP", 0, 6)
    resize:SetText("Reset To Default Size")
    resize:SetScript("OnClick", function()
        ns.MicroTouched()
        ns.db.microScale = nil
        if ns.MirrorSave then ns.MirrorSave() end
        dialog:Refresh()
        ns.QueueApply()
    end)
    dialog.resize = resize

    function dialog:Refresh()
        if self.InitSlider then self.InitSlider() end
        self.reset:SetEnabled(ns.db.microPos ~= nil)
        self.resize:SetEnabled(math.abs(MicroUserScale() - 1) > 0.001)
    end
    dialog:SetScript("OnShow", function(self) self:Refresh() end)
    dialog:SetScript("OnHide", function()
        local handle = art.microHome and art.microHome.handle
        if handle and handle.Dress then handle.Dress("editmode-actionbar-highlight") end
    end)
    return dialog
end

-- The micro group's own frame: the row hangs from it on the band and off
-- it, so a drag carries the row as it goes. Off the band it wears its
-- run of the band's art as a floor, so the group is one piece, buttons
-- and background together.
local function MicroHome()
    local home = art.microHome
    if home then return home end
    home = CreateFrame("Frame", "ForeverClassicUIMicroGroup", art)
    home:SetClampedToScreen(true)
    home:SetMovable(true)
    art.microHome = home
    home.floor = { home:CreateTexture(nil, "BACKGROUND"), home:CreateTexture(nil, "BACKGROUND") }
    -- An iron post at each end, cut from the band's own: a run of art
    -- cut out of the middle of the band has no ends of its own.
    home.posts = { home:CreateTexture(nil, "BORDER"), home:CreateTexture(nil, "BORDER") }

    -- The handle edit mode shows over it.
    local handle = CreateFrame("Frame", nil, home)
    handle:SetAllPoints(home)
    -- Where the client keeps its own: under the edit mode window, which
    -- a handle in that window's own layer stood in front of.
    handle:SetFrameStrata("MEDIUM")
    handle:SetFrameLevel(1010)
    handle:EnableMouse(true)
    handle:EnableMouseWheel(true)
    handle:RegisterForDrag("LeftButton")
    handle:Hide()
    -- The same box the client draws round its own pieces in edit mode:
    -- its blue nine-slice, and the yellow one while it is being held.
    local function Dress(kit)
        if handle.kit == kit then return end
        handle.kit = kit
        if NineSliceUtil and NineSliceUtil.ApplyLayout then
            pcall(NineSliceUtil.ApplyLayout, handle, SELECTION_LAYOUT, kit)
        end
    end
    handle.Dress = Dress
    Dress("editmode-actionbar-highlight")
    local label = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    label:SetPoint("CENTER", handle, "CENTER", 0, 0)
    label:SetText("Micro Menu")
    handle:SetScript("OnDragStart", function(self)
        -- During a fight too, as long as the group's frame is free to
        -- move there: it is ours, and nothing protected hangs from it.
        -- (The rows on it are put back in order when the fight ends.)
        if InCombatLockdown() and home:IsProtected() then return end
        Dress("editmode-actionbar-selected")
        home.moving, home.dragged = true, true
        home:StartMoving()
        -- The band is redrawn each time the group crosses the line
        -- between "would go back onto the bar" and "would not", so what
        -- letting go will do is on screen before it is done.
        self:SetScript("OnUpdate", function()
            if OneBar() then return end
            local place = DropPlace("micro", home, dragPreview.bagsFirst)
            local near = place ~= nil
            if dragPreview.micro ~= near or (near and dragPreview.bagsFirst ~= place) then
                dragPreview.micro = near
                -- Not "near and place or nil": place is false for one of the two
                -- orders, and that idiom turns a false into nil, which
                -- read as "no preview" and fell back to the saved order.
                if near then dragPreview.bagsFirst = place else dragPreview.bagsFirst = nil end
                ns.QueueApply()
            end
        end)
    end)
    handle:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        home:StopMovingOrSizing()
        home.moving = false
        C_Timer.After(0, function() home.dragged = false end)
        local place = DropPlace("micro", home, dragPreview.bagsFirst)
        dragPreview.micro, dragPreview.bagsFirst = nil, nil
        Dress("editmode-actionbar-highlight")
        -- Let go near its place on the bar, it goes back onto the bar.
        if place ~= nil then
            ns.MicroTouched()
            ns.db.microPos, ns.db.microScale = nil, nil
            ns.db.bagsFirst = place
            if ns.MirrorSave then ns.MirrorSave() end
        else
            local point, _, relPoint, x, y = home:GetPoint(1)
            ns.MicroTouched()
            ns.db.microPos = { point = point, relPoint = relPoint, x = x, y = y }
            if ns.MirrorSave then ns.MirrorSave() end
        end
        if art.microDialog and art.microDialog:IsShown() then art.microDialog:Refresh() end
        ns.QueueApply()
        if ns.MicroDroppedInFight then ns.MicroDroppedInFight() end
    end)
    handle:SetScript("OnMouseWheel", function(_, delta)
        ns.MicroTouched()
        ns.db.microScale = math.max(0.5, math.min(2, MicroUserScale() + 0.05 * delta))
        if ns.MirrorSave then ns.MirrorSave() end
        if art.microDialog and art.microDialog:IsShown() then art.microDialog:Refresh() end
        ns.QueueApply()
    end)
    handle:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            ns.MicroTouched()
            ns.db.microPos, ns.db.microScale = nil, nil
            if ns.MirrorSave then ns.MirrorSave() end
            if art.microDialog and art.microDialog:IsShown() then art.microDialog:Refresh() end
            ns.QueueApply()
            return
        end
        -- A click, as on any piece in edit mode: it is selected and its
        -- settings come up beside it.
        -- The release that ends a drag is not a click.
        if home.moving or home.dragged then return end
        local dialog = MicroDialog()
        Dress("editmode-actionbar-selected")
        dialog:ClearAllPoints()
        dialog:SetPoint("BOTTOM", home, "TOP", 0, 40)
        dialog:Show()
    end)
    handle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Micro Menu", 1, 1, 1)
        GameTooltip:AddLine("Drag to move. Let go near the bar to put it back.", 1, 0.82, 0)
        GameTooltip:AddLine("Click for its size and reset. The mouse wheel sizes it too.", 1, 0.82, 0)
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    home.handle = handle
    return home
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
        if button:GetParent() ~= art then button:SetParent(art) end
        if MICRO_SKIP[button:GetName() or ""] then
            button:ClearAllPoints()
            button:SetAlpha(0)
        elseif button:IsShown() or hiddenMicro[button] then
            wanted[#wanted + 1] = button
        end
    end
    if #wanted == 0 then microBusy = false return end
    -- Off the band: moved by the player, or one-bar mode, where the
    -- group lives in the corner until it is moved.
    local out = (not shape.micro) or OneBar()
    local group = out and MicroUserScale() or 1
    -- Off the band the chosen size rides on the group's own frame; on it
    -- the row itself is drawn that much bigger or smaller.
    local scale, region = MicroPlan(#wanted, out and 1 or MicroUserScale())
    -- The buttons are the band's children, so a group drawn bigger or
    -- smaller off the band takes them with it through their own scale.
    -- Off the band the group does not size with bar 1: the band's scale,
    -- which is bar 1's icon size, is divided out of it.
    local bandScale = (art:GetScale() or 1)
    if bandScale <= 0 then bandScale = 1 end
    local homeScale = out and (group / bandScale) or 1
    local buttonScale = scale * homeScale
    local level = ButtonLevel()

    -- The group's frame: over its region of the band, or where it was put.
    local home = MicroHome()
    local plan = CurrentPlan()
    local groupX = (not out and plan.microRow) and (plan.microRow - MICRO_ROW_IN) or MICRO_GROUP_X
    local groupW = (not out and plan.microEnd) and (plan.microEnd - groupX) or ((ART_W / 2 + region) - MICRO_GROUP_X)
    home:SetSize(groupW, BAND_H)
    home:SetScale(homeScale)
    home:SetFrameLevel(math.max(0, level - 1))
    if not home.moving then
        home:ClearAllPoints()
        local pos = ns.db.microPos
        if pos then
            home:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or "CENTER", pos.x or 0, pos.y or 0)
        elseif OneBar() then
            home:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", CORNER_X, 0)
        else
            home:SetPoint("BOTTOMLEFT", art, "BOTTOMLEFT", groupX, 0)
        end
    end
    home:Show()
    -- Its floor: the run of the third sheet it stood on, and the dark
    -- start of the fourth where the row reaches that far. Only off the
    -- band; on it the band's own art is already there.
    local third = math.min(region, 256)
    local runs = {
        { 3, (MICRO_GROUP_X - 512) / 256, third / 256, third - (MICRO_GROUP_X - 512), 0 },
        { 4, 0, math.max(0, region - 256) / 256, math.max(0, region - 256), third - (MICRO_GROUP_X - 512) },
    }
    for i, tex in ipairs(home.floor) do
        local run = runs[i]
        if out and run[4] > 0 then
            local sheet = PIECES[run[1]]
            ns.SetTex(tex, sheet.key)
            tex:SetTexCoord(run[2], run[3], sheet.band[1], sheet.band[2])
            tex:SetSize(run[4], BAND_H)
            tex:ClearAllPoints()
            tex:SetPoint("BOTTOMLEFT", home, "BOTTOMLEFT", run[5], 0)
            tex:Show()
        else
            tex:Hide()
        end
    end

    for i, post in ipairs(home.posts) do
        if out then
            local sheet = PIECES[4]
            ns.SetTex(post, sheet.key)
            post:SetSize(POST_W, BAND_H)
            post:ClearAllPoints()
            if i == 1 then
                -- The left end is the right end seen in a mirror: drawn the
                -- same way round it read as the right side of something
                -- else that had been cut off.
                post:SetTexCoord((POST_U + POST_W) / 256, POST_U / 256, sheet.band[1], sheet.band[2])
                post:SetPoint("BOTTOMLEFT", home, "BOTTOMLEFT", 0, 0)
            else
                post:SetTexCoord(POST_U / 256, (POST_U + POST_W) / 256, sheet.band[1], sheet.band[2])
                post:SetPoint("BOTTOMRIGHT", home, "BOTTOMRIGHT", 0, 0)
            end
            post:Show()
        else
            post:Hide()
        end
    end

    local prev
    for _, button in ipairs(wanted) do
        Remember(button)
        if button:GetParent() ~= art then button:SetParent(art) end
        button:SetSize(MICRO_W, MICRO_H)
        button:SetScale(buttonScale)
        button:SetFrameLevel(level)
        if hiddenMicro[button] then
            hiddenMicro[button] = nil
            button:Show()
        end
        button:ClearAllPoints()
        if prev then
            button:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", MICRO_STEP, 0)
        else
            -- From the group's corner, by the same numbers as on the
            -- band. The offset is read in the button's scale; the
            -- group's pixels are its own scale times the band's.
            button:SetPoint("BOTTOMLEFT", home, "BOTTOMLEFT", MICRO_ROW_IN / scale, MICRO_Y / scale)
        end
        ns.SkinMicroButton(button)
        prev = button
    end
    if art.perfMeter then art.perfMeter:Hide() end
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

-- The client moves every bar it holds "in its default position" back to
-- its own spot whenever its bottom or right bar pass runs, and taking a
-- target runs it. Out of a fight the band put them back a frame later,
-- which showed as the bars and the chat hopping; in a fight the band may
-- not move them at all, so they stayed wrong until it ended. The pass
-- leaves alone any bar the layout holds a spot for, so the band's bars
-- are written into the classic layout at the band's own spots: pinned.
--
-- A pin has to be told apart from a bar the player dragged out of the
-- band, which also reads as "not default" and which the band leaves
-- alone. So the spot written for each pin is kept, by layout and bar,
-- and a bar whose held spot is still that one is a pinned bar. Drag it
-- and the spot changes, and it is the player's again.
local function ActiveLayoutName()
    local mgr = EditModeManagerFrame
    local info = mgr and mgr.GetActiveLayoutInfo and mgr:GetActiveLayoutInfo()
    return info and info.layoutName or nil
end

local function PinnedByUs(frame, info)
    local pins = ns.db and ns.db.barPins
    local layout = pins and pins[ActiveLayoutName() or ""]
    local name = frame.GetName and frame:GetName()
    local pin = layout and name and layout[name]
    if not info then return false end
    local relativeTo = info.relativeTo
    if type(relativeTo) == "table" then relativeTo = relativeTo.GetName and relativeTo:GetName() end
    -- A pin of ours is told by its shape, not only by the record of it:
    -- this client has lost the record between two sessions, and every
    -- pinned bar then read as one the player had placed, which the band
    -- leaves alone for good. Ours are held to the screen by two unlike
    -- points (the bar's bottom left to the screen's bottom middle); a
    -- bar let go in edit mode is always held by two alike.
    if relativeTo == "UIParent" and info.point and info.relativePoint and info.point ~= info.relativePoint then return true end
    -- Pins written before that shape was settled on are bottom middle to
    -- bottom middle. Until the pins have been written once in the new
    -- shape, those count as ours too, record or none.
    if not ns.db.pinShape and relativeTo == "UIParent" and info.point == "BOTTOM" and info.relativePoint == "BOTTOM" then return true end
    if not pin then return false end
    return info.point == pin.point and info.relativePoint == pin.relativePoint and relativeTo == "UIParent"
        and math.abs((info.offsetX or 0) - (pin.offsetX or 0)) < 0.5
        and math.abs((info.offsetY or 0) - (pin.offsetY or 0)) < 0.5
end

-- Whether edit mode holds a spot for this frame that is not its default,
-- which means the user dragged it there. The flag alone is not enough:
-- a layout can carry a stale one, so the spot it holds is compared with
-- the preset's before the frame is left alone, and with our own pin.
local function SystemMoved(frame)
    if not frame or type(frame.IsInDefaultPosition) ~= "function" then return false end
    if not (frame.IsInitialized and frame:IsInitialized()) then return false end
    local ok, isDefault = pcall(frame.IsInDefaultPosition, frame)
    if not ok or isDefault then return false end
    local info = frame.systemInfo and frame.systemInfo.anchorInfo
    if PinnedByUs(frame, info) then return false end
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
    -- A bar the player has moved, stood up or folded is theirs: it is
    -- laid out on itself, the way its own settings say.
    local vertical, rows = BarVertical(bar) == true, BarRows(bar)
    if SystemMoved(bar) or vertical or rows > 1 then
        if vertical then
            LayoutButtons(bar, rowIndex, "TOPLEFT", bar, "TOPLEFT", 0, 0, true, pitch, target, nil, rows)
        else
            LayoutButtons(bar, rowIndex, "BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0, false, pitch, target, nil, rows)
        end
        return false
    end
    local band = BandNow()
    Anchor(bar, "BOTTOMLEFT", "BOTTOMLEFT", x * band, y * band, 1)
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
    -- The same for a column: moved, laid down or folded, it is the
    -- player's and follows its own settings.
    local vertical, rows = BarVertical(bar) ~= false, BarRows(bar)
    if SystemMoved(bar) or not vertical or rows > 1 then
        if vertical then
            LayoutButtons(bar, rowIndex, "TOPLEFT", bar, "TOPLEFT", 0, 0, true, nil, nil, nil, rows)
        else
            LayoutButtons(bar, rowIndex, "BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0, false, nil, nil, nil, rows)
        end
        return false
    end
    Remember(bar)
    bar:SetScale(1)
    bar:ClearAllPoints()
    -- The frame starts where its first button does and is as long as the
    -- buttons drawn under it, so edit mode's box is the column itself.
    local icon = IconScale(bar)
    bar:SetPoint("TOPRIGHT", UIParent, "BOTTOMRIGHT", x * icon, (SIDE_BAR_Y + SIDE_COL_H) * icon)
    LayoutButtons(bar, rowIndex, "TOPLEFT", UIParent, "BOTTOMRIGHT", x - BUTTON_SIZE, SIDE_BAR_Y + SIDE_COL_H, true, nil, nil, icon)
    return true
end

local function LayoutSideBars()
    local right, left = MultiBarRight, MultiBarLeft
    local rightPinned = SideColumn(right, 7, SIDE_BAR_X)
    local leftX = SIDE_BAR_X
    if rightPinned and right:IsShown() then
        -- The second column stands beside the first. Each column is read
        -- at its own Icon Size, so the first one's width is converted
        -- into the second one's pixels before the gap is taken off.
        local ratio = IconScale(right) / IconScale(left)
        leftX = (SIDE_BAR_X - BUTTON_SIZE) * ratio - SIDE_BAR_GAP
    end
    SideColumn(left, 8, leftX)
end

-- Bars 6 to 8 are enabled in the game's Settings (Action Bars page);
-- the game hides a disabled bar itself. Our toggle and those three
-- settings stay in step: the toggle on turns them off, and any of them
-- turned on in Settings turns the toggle off.
local EXTRA_SETTINGS = { "PROXY_SHOW_ACTIONBAR_6", "PROXY_SHOW_ACTIONBAR_7", "PROXY_SHOW_ACTIONBAR_8" }

local function ExtraBarsEnabledInSettings()
    if not Settings or not Settings.GetValue then return false end
    for _, var in ipairs(EXTRA_SETTINGS) do
        local ok, value = pcall(Settings.GetValue, var)
        if ok and value then return true end
    end
    return false
end

-- Nothing here writes those three settings. The client applies one by
-- calling a function of its own that an addon may not reach, and the
-- call is refused with the blocked-action box on screen. The bars are
-- faded and take no clicks either way, and their keybinds still work,
-- which is what this toggle promises.

local LayoutExtraBars

-- A bar enabled in Settings while our toggle hides them: the toggle
-- goes off: the bar was wanted.
local function FollowSettings()
    if not active or not ns.db or not ns.db.hideExtraBars then return end
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
    for i = 1, 5 do
        strips[i] = statusBar:CreateTexture(nil, "ARTWORK", nil, 1)
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
    -- A fill shaded down its height only (see statusBarFlat). Cutting one
    -- column out of the old sheet by texture coordinates did not hold:
    -- the bar sets its fill's coordinates itself as the value changes,
    -- and the sheet's dark to light came back as blocks along the bar.
    status:SetStatusBarTexture((ns.TexPath("statusBarFlat")))
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
        -- The run to the tick is kept the faint wash 1.x drew. The client
        -- gives it its own texture and strength back on its updates, and
        -- at that strength it read as a shadow lying across the end of
        -- the fill, so it is put back every time the fill is.
        if run then
            run:SetColorTexture(0, 0.39, 0.88, 0.15)
            run:SetVertexColor(1, 1, 1, 1)
            run:SetAlpha(1)
            run:SetDrawLayer("BACKGROUND", 0)
        end
    elseif status.fcuiBar and status.fcuiBar.factionID and C_Reputation and C_Reputation.GetWatchedFactionData then
        -- The watched faction's bar in the old standing colors, read from
        -- the standing itself and not from the name of the client's art:
        -- red while hated or hostile, orange unfriendly, yellow neutral,
        -- green from friendly up. Left to the art's name it came out in
        -- the experience bar's purple.
        local ok, data = pcall(C_Reputation.GetWatchedFactionData)
        local reaction = ok and data and data.reaction
        if type(reaction) == "number" and not (issecretvalue and issecretvalue(reaction)) then
            if reaction <= 2 then r, g, b = 0.8, 0.3, 0.22
            elseif reaction == 3 then r, g, b = 0.75, 0.27, 0
            elseif reaction == 4 then r, g, b = 0.9, 0.7, 0
            else r, g, b = 0, 0.6, 0.1 end
        else
            r, g, b = 0, 0.6, 0.1
        end
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
    -- The upper bar stands 2 clear of the band: its art runs 2 under its
    -- fill, and hung level with the band's top that foot lay behind the
    -- band's own strip.
    Anchor(container, isTop and "BOTTOM" or "TOP", "TOP", 0, isTop and 2 or -1, BandNow())
    local h = isTop and 7 or STRIP_H
    local w = ArtWidth()
    container:SetSize(w, h)
    if container.BarFrameTexture then container.BarFrameTexture:SetAlpha(0) end
    -- The client fades a bar out and the next one in, and with two bars
    -- changing places it fades both out before either comes in: the best
    -- part of a second in which the old bars did nothing of the kind.
    -- Its bar manager does its swapping at the end of each fade, and asks
    -- a holder's strength (nothing, or not) which way to go next, so the
    -- fades are kept, from and to what they were, and only made as short
    -- as a fade can be and still run: a fiftieth of a second, a frame or
    -- two. A fade of no length at all never ran, and the swap hung on it.
    if not container.fcuiNoFade then
        container.fcuiNoFade = true
        for _, key in ipairs({ "FadeInAnimation", "FadeOutAnimation" }) do
            local group = container[key]
            if group and group.GetAnimations then
                for _, anim in ipairs({ group:GetAnimations() }) do
                    if anim.SetDuration then anim:SetDuration(0.02) end
                    if anim.SetStartDelay then anim:SetStartDelay(0) end
                end
            end
        end
    end
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
            status.fcuiBar = bar
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
            -- The strips are the bar's segment posts. The old art has a
            -- post every 51.2 across its 1024, the first one half a
            -- segment in, so that the band's two ends each cut a segment
            -- in half under a gryphon. Ours show a sliver of that half
            -- past the gryphon, and a band of another length cut one off
            -- anywhere. So the posts are fitted to what can be seen: a
            -- post just under each gryphon's edge, and between them as
            -- many whole segments as come nearest, all the same width.
            local strips = EnsureStrips(status)
            local segment, firstPost, under = 1024 / 20, 1024 / 40, 18
            local seenW = math.max(segment, w - 2 * under)
            local count = math.max(1, math.floor(seenW / segment + 0.5))
            local stretch = (seenW / count) / segment
            -- band x = under + (sheet x - firstPost) * stretch
            local sheetFrom = math.max(0, firstPost - under / stretch)
            local sheetTo = math.min(1024, firstPost + (w - under) / stretch)
            for i, tex in ipairs(strips) do
                local piece = PIECES[i]
                local from, to = math.max(sheetFrom, (i - 1) * 256), math.min(sheetTo, i * 256)
                if piece and to > from then
                    local u0, u1 = (from - (i - 1) * 256) / 256, (to - (i - 1) * 256) / 256
                    if isTop then
                        ns.SetTex(tex, "repBar")
                        tex:SetTexCoord(u0, u1, REP_ROWS[i][1], REP_ROWS[i][2])
                        tex:SetSize((to - from) * stretch, 11)
                    else
                        ns.SetTex(tex, piece.stripKey or piece.key)
                        tex:SetTexCoord(u0, u1, piece.strip[1], piece.strip[2])
                        tex:SetSize((to - from) * stretch, STRIP_H)
                    end
                    tex:ClearAllPoints()
                    -- The upper bar's art is 11 rows with its channel in
                    -- rows 2 to 8: it starts 2 over the 7 tall fill, which
                    -- then lies in the channel and not across the top rim.
                    tex:SetPoint("TOPLEFT", status, "TOPLEFT", under + (from - firstPost) * stretch, isTop and 2 or 0)
                    tex:Show()
                else
                    tex:Hide()
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

-- Whether one of the client's two bar holders is showing the experience bar.
local function ShowsExperience(container)
    for _, bar in pairs(container and container.bars or {}) do
        if bar:IsShown() and bar.ExhaustionTick then return true end
    end
    return false
end

local function LayoutStatusBars()
    local main, second = MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer
    -- With two bars up the experience bar keeps its place in the band and
    -- the other (a watched faction) stands over it, as it did. The client
    -- gives its first holder to the faction and its second to experience,
    -- which drew them the other way up.
    local swap = HasVisibleBar(main) and HasVisibleBar(second) and ShowsExperience(second) and not ShowsExperience(main)
    LayoutStatusBar(main, swap)
    LayoutStatusBar(second, not swap)
    -- A holder's strength is left to the client's own fades and to the
    -- watch below. It used to be set here, nothing for a holder with no
    -- bar up; but this runs part way through the client's swaps, where a
    -- holder is between bars, and ticking the watch box quickly left both
    -- holders at nothing with their bars up inside them.
    local anyShown = (main and main:IsShown()) or (second and second:IsShown())
    for _, tex in ipairs(art.maxLevel) do tex:SetShown(not anyShown and tex.fcuiInBand == true) end
end

-- A faction watched or let go changes which bars are up and which of the
-- two stands over the other: laid again a moment after the client has
-- made its own change.
local barsWatch = CreateFrame("Frame")
-- What is up and which way round, as one word.
local function BarsState()
    local main, second = MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer
    local mainUp, secondUp = HasVisibleBar(main), HasVisibleBar(second)
    local swap = mainUp and secondUp and ShowsExperience(second) and not ShowsExperience(main)
    return (mainUp and "1" or "0") .. (secondUp and "1" or "0") .. (swap and "s" or "-"), mainUp and secondUp
end

-- The bars are looked at steadily while the band is up, not at set
-- moments after a faction changes: the client swaps its bars over a fade
-- out and a fade in, a quick run of changes stacks those up, and any set
-- moment can fall in the middle of one. Whatever state they settle in is
-- laid, once; and a holder left at no strength with a bar up in it and
-- no fade running (a swap the client began and never finished) is
-- brought back. Nothing here calls into the client's code.
local function Playing(container)
    for _, key in ipairs({ "FadeInAnimation", "FadeOutAnimation", "MaxLevelFadeOutAnimation" }) do
        local group = container[key]
        if group and group.IsPlaying and group:IsPlaying() then return true end
    end
    return false
end
barsWatch:SetScript("OnUpdate", function(self, elapsed)
    self.since = (self.since or 0) + elapsed
    if self.since < 0.05 then return end
    self.since = 0
    if not (active and art) then return end
    local busy = false
    for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        if container then
            if Playing(container) then
                busy = true
            elseif HasVisibleBar(container) and (container:GetAlpha() or 1) < 1 then
                container:SetAlpha(1)
            end
        end
    end
    -- Laid once the client has finished moving, and out of a fight.
    if busy or InCombatLockdown() then return end
    local state, two = BarsState()
    if state ~= self.state then
        self.state = state
        pcall(LayoutStatusBars)
        -- The rows above the band rise and fall with the second bar.
        if two ~= self.two then
            self.two = two
            if ns.QueueApply then ns.QueueApply() end
        end
    end
end)

-- The player's cast bar, while it stands where the client put it. The
-- client stacks it over whichever of its bottom bars are still in their
-- default places, measured for its own flat bar: with bars 2 and 3 taken
-- off the band in edit mode it drops the cast bar to just over bar 1,
-- which on this band is in among the stance and pet row and the bars
-- over the experience strip. So it is stood over whatever is really up
-- on the band, as the old bar did. One the player has placed in edit mode
-- is theirs and is left alone, as is everything while edit mode is open.
-- Only the bar's own anchor is set; nothing of its state is written.
local CAST_GAP = 26
local castWatch = CreateFrame("Frame")
castWatch:SetScript("OnUpdate", function()
    local bar = _G["PlayerCastingBarFrame"]
    if not (active and art and bar and bar:IsShown()) then return end
    -- Edit mode included, where the client stands it over its own idea
    -- of the stack each time a piece is moved; only not while the cast
    -- bar itself is in the player's hand.
    if bar.isDragging then return end
    if bar.IsInDefaultPosition then
        local ok, default = pcall(bar.IsInDefaultPosition, bar)
        if ok and default == false then return end
    end
    local screen = UIParent:GetEffectiveScale()
    local centre = UIParent:GetWidth() / 2
    local top = 0
    -- Whatever stands under the screen's middle, where the cast bar is.
    for _, frame in ipairs({ art, MultiBarBottomLeft, MultiBarBottomRight, StanceBar, PetActionBar, PossessActionBar,
        MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        -- Only what is on the band. A bar the player has placed, or has
        -- in hand in edit mode, is not something to stand on wherever it
        -- is: the cast bar went along with bar 2 as it was dragged.
        local onBand = frame == art or (frame and not frame.isDragging and not SystemMoved(frame))
        if onBand and frame:IsShown() and (frame:GetAlpha() or 1) > 0 and frame:GetTop() and frame:GetLeft() then
            -- A bar is read on its buttons, which hang on the band: the
            -- bar's own frame is the client's to carry off in a fight.
            local from, to = frame, frame
            local buttons = frame.actionButtons
            if buttons and buttons[1] and buttons[1]:GetLeft() then
                from, to = buttons[1], buttons[1]
                for i = #buttons, 2, -1 do
                    if buttons[i]:IsShown() and buttons[i]:GetRight() then to = buttons[i] break end
                end
            end
            local k = from:GetEffectiveScale() / screen
            local left, right = math.min(from:GetLeft(), to:GetLeft()) * k, math.max(from:GetRight(), to:GetRight()) * k
            local up = math.max(from:GetTop(), to:GetTop()) * k
            -- Only what reaches up from the band: a bar dragged to the
            -- middle of the screen is not something to stand on.
            if left < centre + 110 and right > centre - 110 and up < 260 and up > top then top = up end
        end
    end
    if top <= 0 then return end
    local mine = bar:GetEffectiveScale() / screen
    local want = (top + CAST_GAP) / mine
    local bottom = bar:GetBottom()
    if bottom and math.abs(bottom - want) > 1 then
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, want)
    end
end)

-- Whether the bars are still on their way to what was last asked of them:
-- a fade of the client's running, or a settled state not laid yet. What
-- changes the bars (the reputation box's Show as Experience Bar) holds
-- its hand until this is over.
function ns.StatusBarsBusy()
    if not (active and art) then return false end
    for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        if container and Playing(container) then return true end
    end
    return (BarsState()) ~= barsWatch.state
end

-- Whether a watched faction's bar is up right now.
function ns.StatusBarsShowFaction()
    for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        for _, bar in pairs(container and container.bars or {}) do
            if bar:IsShown() and not bar.ExhaustionTick and bar.factionID then return true end
        end
    end
    return false
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

-- Set when a drag ends in edit mode: the next pass looks at where the
-- bags were let go.
local bagsDropped = false
-- Whether the bags were off the bar at the last pass; nil before the first.
local bagsWereOut

-- What is still on the band, read once at the head of every pass.
local function ReadShape()
    shape.micro = not MicroOut()
    shape.bags = not (BagsBar and SystemMoved(BagsBar))
    local count = 0
    for _, button in ipairs(MicroButtonList()) do
        if not MICRO_SKIP[button:GetName() or ""] and (button:IsShown() or hiddenMicro[button]) then count = count + 1 end
    end
    shape.scale, shape.region = MicroPlan(count, MicroUserScale())
    shape.region = math.max(MICRO_LEAD + MICRO_END_GAP, math.min(MICRO_REGION_MAX, shape.region))
    shape.bagsReal, shape.microReal = shape.bags, shape.micro
    shape.noPages = BarSetting(ns.GetMainBar(), "HideBarScrolling") == 1
    local icons = BarSetting(ns.GetMainBar(), "NumIcons")
    if not icons or icons < 1 or icons > 12 then icons = 12 end
    shape.cut = (12 - math.floor(icons + 0.5)) * BUTTON_PITCH
    -- Bags let go near a place on the band go into it: the piece is the
    -- client's, so it is handed its default place again, which is what
    -- the band reads as "on the bar", at socket size. Judged on where
    -- things really are, before any preview is laid over that.
    if bagsDropped then
        bagsDropped = false
        local showing = dragPreview.bagsFirst
        dragPreview.bags, dragPreview.bagsFirst = nil, nil
        if not shape.bags and not InCombatLockdown() then
            local place = DropPlace("bags", BagsBar, showing)
            if place ~= nil and type(BagsBar.ResetToDefaultPosition) == "function" and pcall(BagsBar.ResetToDefaultPosition, BagsBar) then
                ns.editWrote = true
                shape.bags, shape.bagsReal = true, true
                ns.MicroTouched()
                ns.db.bagsFirst = place
                if ns.MirrorSave then ns.MirrorSave() end
                local setting = Enum and Enum.EditModeBagsSetting and Enum.EditModeBagsSetting.Size
                local manager = EditModeManagerFrame
                if setting ~= nil and manager and manager.OnSystemSettingChange then
                    pcall(manager.OnSystemSettingChange, manager, BagsBar, setting, 100)
                end
            end
        end
    end
    -- Back onto the bar by any road, the bags go back to socket size.
    -- Dropping them near their place already did that; the client's own
    -- Reset To Default Position puts them back without touching their
    -- Size, and an oversized row was then squeezed into the sockets.
    if shape.bagsReal and bagsWereOut and not InCombatLockdown() and BagsBar then
        local setting = Enum and Enum.EditModeBagsSetting and Enum.EditModeBagsSetting.Size
        local manager = EditModeManagerFrame
        if setting ~= nil and manager and manager.OnSystemSettingChange and math.abs((BagsBar:GetScale() or 1) - 1) > 0.001 then
            pcall(manager.OnSystemSettingChange, manager, BagsBar, setting, 100)
            ns.editWrote = true
            local dialog = EditModeSystemSettingsDialog
            if dialog and dialog:IsShown() and dialog.attachedToSystem == BagsBar and dialog.UpdateDialog then
                pcall(dialog.UpdateDialog, dialog, BagsBar)
            end
        end
    end
    bagsWereOut = not shape.bagsReal
    local bagsFirst = ns.db and ns.db.bagsFirst
    if dragPreview.micro ~= nil then shape.micro = dragPreview.micro end
    if dragPreview.bags ~= nil then shape.bags = dragPreview.bags end
    if dragPreview.bagsFirst ~= nil then bagsFirst = dragPreview.bagsFirst end
    shape.plan = BandPlan(OnBandMicro(), OnBandBags(), bagsFirst, shape.region)
end

local function Layout()
    local bar = ns.GetMainBar()
    if not bar then return end
    ReadShape()
    -- Edit mode owns Action Bar 1's scale and, once it has been dragged, its
    -- position. The band takes the same scale and anchors itself so that
    -- the bar's rectangle is exactly its twelve buttons: dragging the bar in
    -- edit mode moves the whole classic bar, and its own settings dialog
    -- keeps working. In the default position the band sits centered at the
    -- bottom and the bar is placed inside it.
    art:SetScale(BandScale(bar))
    art:ClearAllPoints()
    local moved = BarMoved(bar)
    ns.barMoved = moved
    -- In edit mode, and once the bar has been placed by the player, the
    -- band hangs from the bar, never the bar from the band:
    -- a drag in edit mode moves the bar alone, and whatever hangs from it
    -- (the band, and with the band the page arrows, the rows, the micro
    -- menu, the bags and the experience bar) moves with it while it is
    -- being dragged, not only once it is let go. In its default place the
    -- bar itself is put where the band's centered spot needs it.
    if not moved then
        -- The bar frame keeps the plain scale, so its offsets are read
        -- in screen pixels: the band's size is spelled out.
        local band = BandNow()
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM",
            ((ns.db.barOffsetX or 0) - ArtWidth() / 2 + ROW_X) * band, ((ns.db.barOffsetY or 0) + ROW_Y) * band)
    end
    -- In its default place the bar is the client's to lay out again, and
    -- it does, in the middle of a fight, where nothing of ours may put a
    -- protected bar back: with the band hung from the bar, the band and
    -- every row, the micro menu and the bags on it hopped along. So there
    -- the band stands on the screen itself, at the very spot the bar was
    -- just given, and the bar's frame may be carried off without anything
    -- that is drawn going with it (its buttons hang on the band). The
    -- band follows the bar only while the bar itself is in the player's
    -- hand (the placer hangs it there as the drag begins), and once the
    -- player has placed it, where the client leaves it alone. Not for
    -- the whole of edit mode: the client lays the stack out again as any
    -- piece at all is moved there, and the band jumped each time.
    if moved or bar.isDragging then
        art:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -ROW_X, -ROW_Y)
    else
        art:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", (ns.db.barOffsetX or 0) - ArtWidth() / 2, ns.db.barOffsetY or 0)
    end
    art:Show()
    PaintArt()
    ApplyArtShape(bar)
    -- The client's end caps stay up as edit mode handles; PlaceCaps has
    -- faded their art.
    if bar.BorderArt then bar.BorderArt:SetAlpha(0) end
    if bar.HorizontalDividersPool then bar.HorizontalDividersPool:ReleaseAll() end
    if bar.VerticalDividersPool then bar.VerticalDividersPool:ReleaseAll() end
    LayoutButtons(bar, 1, "BOTTOMLEFT", art, "BOTTOMLEFT", ROW_X, ROW_Y)
    LayoutPageArrows(bar)

    local lower, upper = MultiBarBottomLeft, MultiBarBottomRight
    -- A watched faction's bar stands over the experience bar, and the old
    -- bar lifted everything above the band by 9 to clear it.
    local twoBars = HasVisibleBar(MainStatusTrackingBarContainer) and HasVisibleBar(SecondaryStatusTrackingBarContainer)
    local barLift = twoBars and TWO_BAR_LIFT or 0
    BandRow(lower, 2, ROW_X, UPPER_ROW_Y + barLift)
    -- Bar 3 sits beside bar 2 on the full band; on the half band it has
    -- no room there, so it stacks over bar 2 and the pet row moves up.
    if OneBar() then
        BandRow(upper, 3, ROW_X, UPPER_ROW_Y + BUTTON_PITCH + barLift)
    else
        BandRow(upper, 3, CurrentPlan().base + 8, UPPER_ROW_Y + barLift)
    end
    LayoutPetRow((OneBar() and BUTTON_PITCH or 0) + barLift)
    LayoutSideBars()
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
    ns.db.bandHandedBack = nil
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    applying = true
    ns.bandPasses = (ns.bandPasses or 0) + 1
    local ok, err = pcall(Layout)
    applying = false
    Snapshot()
    if not ok then geterrorhandler()(err) end
end

function ns.ClassicBarActive() return active end

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
        if art.perfMeter then art.perfMeter:Hide() end
        if art.bagFloor then art.bagFloor:Hide() end
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
    -- Every micro button stands somewhere before any of them goes home.
    -- The client lays its menu out the moment one comes back, measuring
    -- from the buttons at its ends, and one of those with no place at
    -- all, the help button the old row never showed, had no middle to
    -- measure: "attempt to compare nil with number", caught below but
    -- still put in front of anyone who has errors shown.
    for _, name in ipairs(MICRO_BUTTONS) do
        local button = _G[name]
        if button and button.GetCenter and not button:GetCenter() then
            button:ClearAllPoints()
            button:SetPoint("CENTER", MicroMenu or UIParent, "CENTER", 0, 0)
        end
    end
    for frame, state in pairs(saved) do
        frame:SetScale(state.scale)
        if frame:GetParent() == art and state.parent then
            -- The client lays its micro menu out each time a button comes
            -- back to it, and with the others still away that layout
            -- trips over a button with no place yet and raises an error
            -- of the client's own. It came up through this call and cut
            -- the rest of the hand-back short. Each button goes back on
            -- its own footing; the menu is laid out once, below, when
            -- they are all home.
            pcall(frame.SetParent, frame, state.parent)
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
        for _, key in ipairs(CAP_KEYS) do
            local cap = CapFrame(bar, key)
            if cap then
                for _, region in ipairs({ cap:GetRegions() }) do
                    if region:IsObjectType("Texture") then region:SetAlpha(1) end
                end
            end
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
    -- The page number and its arrows go back where the client's own file
    -- has them, off bar 1's left end. They had been left on the band's
    -- corner, which with the band gone is a spot over bar 1's last
    -- buttons and half below the screen.
    local pn = bar and bar.ActionBarPageNumber
    if pn then
        pn:SetScale(1)
        pn:ClearAllPoints()
        pn:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", -4, 9)
        for _, entry in ipairs({ { pn.UpButton, 10 }, { pn.DownButton, -10 } }) do
            local button, y = entry[1], entry[2]
            if button then
                button:SetSize(17, 14)
                button:SetHitRectInsets(0, 0, 0, 0)
                button:ClearAllPoints()
                button:SetPoint("CENTER", pn, "CENTER", 0, y)
            end
        end
        if pn.Text then
            pn.Text:SetFontObject("GameFontNormal")
            pn.Text:ClearAllPoints()
            pn.Text:SetPoint("CENTER", pn, "CENTER", -1, 0)
        end
        if pn.Layout then pcall(pn.Layout, pn) end
    end
    if bar and bar.ActionBarPageNumber and bar.UpdateSystemSettingHideBarScrolling then
        pcall(bar.UpdateSystemSettingHideBarScrolling, bar)
    end
    -- The layout still holds the bars where the band had them. It is not
    -- written from here, under a running game: the pins come out as the
    -- session ends, in the logout of the reload the toggle asks for.
    -- Until then each bar is only stood where the client's own layout
    -- would have it, by its anchor and nothing else, so the default
    -- interface reads right for whoever answers "Later".
    local presets = EditModePresetLayoutManager
    for _, name in ipairs(OWNED_SYSTEMS) do
        local frame = _G[name]
        if frame and frame.system and presets and presets.GetDefaultSystemAnchorInfo
            and type(frame.IsInDefaultPosition) == "function" then
            local okDefault, isDefault = pcall(frame.IsInDefaultPosition, frame)
            local ok, info = pcall(presets.GetDefaultSystemAnchorInfo, presets, frame.system, frame.systemIndex)
            local relativeTo = ok and info and (type(info.relativeTo) == "string" and _G[info.relativeTo] or info.relativeTo)
            if okDefault and not isDefault and relativeTo and info.point then
                local scale = frame:GetScale()
                if not scale or scale <= 0 then scale = 1 end
                frame:ClearAllPoints()
                frame:SetPoint(info.point, relativeTo, info.relativePoint or info.point, (info.offsetX or 0) / scale, (info.offsetY or 0) / scale)
            end
        end
    end
    ns.needsReload = true
end

-- The client lays every system in a layout out in one pass, and our code
-- cannot be part of that pass. Whatever the client does in it after us
-- it holds against us for the rest of the session, and the party and
-- raid frames are laid out in that same pass: they then report an error
-- on every health change, which is what the edit mode panel open on a
-- raid-style party looked like, an error a frame.
--
-- So the bars are watched rather than hooked. Every frame the band owns
-- is sampled at the end of our own pass; a sample that no longer matches
-- is the client having moved it, and ours runs again.
local dragging = false
local editWatch
ns.EditModeDragging = function() return dragging end

local watchList, baseline = {}, {}
-- Bars seen moved by the client during a fight, and whether the player
-- has been asked about it this session.
local shiftSeen = false
local MarkStatus
local function WatchList()
    if #watchList > 0 then return watchList end
    local names = { "BottomManagedFrameContainer", "RightManagedFrameContainer", "MicroMenu", "BagsBar" }
    for _, name in ipairs(OWNED_SYSTEMS) do names[#names + 1] = name end
    names[#names + 1] = BAG_BUTTONS[1]
    for _, name in ipairs(names) do
        local frame = _G[name]
        if frame and frame.GetPoint then watchList[#watchList + 1] = frame end
    end
    local micro = MicroButtonList()[1]
    if micro then watchList[#watchList + 1] = micro end
    -- The end caps: the client snaps them back to bar 1's own ends.
    for _, key in ipairs(CAP_KEYS) do
        local cap = CapFrame(ns.GetMainBar(), key)
        if cap and cap.GetPoint then watchList[#watchList + 1] = cap end
    end
    return watchList
end

-- A button leaving the middle of the micro row or the bag row moves
-- nothing the sampler holds, so the rows are counted as well.
local function Census()
    local micro, bags = 0, 0
    for _, button in ipairs(MicroButtonList()) do
        if button:IsShown() then micro = micro + 1 end
    end
    for _, name in ipairs(BAG_BUTTONS) do
        local button = _G[name]
        if button and button:IsShown() then bags = bags + 1 end
    end
    return micro, bags
end

-- A frame's place, written into the table it is compared against. The
-- check runs every frame, so nothing here builds a string or a table
-- once the first sample exists.
local function Record(frame, into)
    into = into or {}
    local point, rel, relPoint, x, y = frame:GetPoint(1)
    into.point, into.rel, into.relPoint = point, rel, relPoint
    into.x, into.y = x or 0, y or 0
    into.w, into.h = frame:GetWidth() or 0, frame:GetHeight() or 0
    into.scale = frame:GetScale() or 1
    into.shown = frame:IsShown() and true or false
    return into
end

local function Differs(frame, b)
    if not b then return true end
    local point, rel, relPoint, x, y = frame:GetPoint(1)
    if point ~= b.point or rel ~= b.rel or relPoint ~= b.relPoint then return true end
    if math.abs((x or 0) - b.x) > 0.05 or math.abs((y or 0) - b.y) > 0.05 then return true end
    if math.abs((frame:GetWidth() or 0) - b.w) > 0.05 then return true end
    if math.abs((frame:GetHeight() or 0) - b.h) > 0.05 then return true end
    -- A size slider in edit mode changes a piece's scale and nothing else.
    if math.abs((frame:GetScale() or 1) - (b.scale or 1)) > 0.001 then return true end
    return (frame:IsShown() and true or false) ~= b.shown
end

-- The bag row and the micro row, button by button. The client lays both
-- out again for reasons of its own (its bag bar chains every bag off the
-- backpack, its micro menu is a grid), and the watch above samples only
-- the first button of each, which the client can leave where it was
-- while it moves the rest. And none of these buttons is protected, so
-- unlike the bars they can be put back in the middle of a fight, which
-- is where they used to stay scattered until it ended.
local rowList
local rowBase = {}
local function RowFrames()
    if rowList then return rowList end
    local list = {}
    for _, name in ipairs(BAG_BUTTONS) do
        if _G[name] then list[#list + 1] = _G[name] end
    end
    for _, extra in ipairs({ KeyRingButton, CharacterReagentBag0Slot }) do
        if extra then list[#list + 1] = extra end
    end
    local micro = MicroButtonList()
    for _, button in ipairs(micro) do list[#list + 1] = button end
    -- Kept only once the micro menu has been read, which it is not
    -- before the first pass.
    if #micro > 0 then rowList = list end
    return list
end

local function MarkRows()
    for _, frame in ipairs(RowFrames()) do rowBase[frame] = Record(frame, rowBase[frame]) end
end

local function RowsMoved()
    for _, frame in ipairs(RowFrames()) do
        if rowBase[frame] and Differs(frame, rowBase[frame]) then return true end
    end
    return false
end

-- Whether every button of the rows may be moved during a fight. They
-- are plain buttons on this client; if one ever is not, the rows wait
-- for the fight to end like the bars do.
local function RowsFree()
    for _, frame in ipairs(RowFrames()) do
        if frame.IsProtected and frame:IsProtected() then return false end
    end
    return true
end

local function RowsBack()
    applying = true
    local ok, err = pcall(function()
        LayoutBags()
        LayoutMicroButtons()
    end)
    applying = false
    MarkRows()
    if not ok and ns.Debug then ns.Debug("rows: " .. tostring(err)) end
end

-- Our pass has just placed everything: this is the picture the client
-- has to change for the watch to answer.
Snapshot = function()
    for _, frame in ipairs(WatchList()) do baseline[frame] = Record(frame, baseline[frame]) end
    MarkRows()
    baseline.micro, baseline.bags = Census()
    if MarkStatus then MarkStatus() end
end

-- The micro group let go during a fight. The whole pass waits for the
-- fight's end, since it moves the bars, and until then the group stood
-- where it was dropped with nothing under it: its own floor and posts
-- are drawn by the micro layout, which touches nothing protected and
-- runs in a fight already. The band itself keeps its length until the
-- fight ends: bar 1 hangs from it, and a band drawn shorter would have
-- to be stood back on the screen's middle, bar and all.
function ns.MicroDroppedInFight()
    if not InCombatLockdown() or not RowsFree() then return end
    shape.micro = not MicroOut()
    applying = true
    pcall(LayoutMicroButtons)
    applying = false
    MarkRows()
end

local function Moved(list)
    for _, frame in ipairs(list or WatchList()) do
        if Differs(frame, baseline[frame]) then return true end
    end
    if not list then
        local micro, bags = Census()
        if micro ~= baseline.micro or bags ~= baseline.bags then return true end
    end
    return false
end

-- The tracking bars are not protected, so they go back into the band
-- even in a fight, which is when the client moves them most: a target
-- with combo points is one of its reasons.
local statusList
local function StatusFrames()
    if statusList then return statusList end
    statusList = {}
    for _, frame in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        if frame and frame.GetPoint then statusList[#statusList + 1] = frame end
    end
    return statusList
end

-- The container's own rectangle is not the whole story: the client
-- hands it the experience and reputation bars after login and resizes
-- them on its own, without the container moving at all, and those bars
-- are where our strips and colors live. So the sample counts them and
-- adds up their sizes; either changing is the client having been at
-- them. Their order is not ours to rely on, so nothing here depends on
-- it.
local statusMark = {}
local function BarSums(container)
    local count, width, height = 0, 0, 0
    for _, bar in pairs(container.bars or {}) do
        count = count + 1
        width = width + (bar:GetWidth() or 0)
        height = height + (bar:GetHeight() or 0)
        local status = bar.StatusBar
        if status then
            width = width + (status:GetWidth() or 0)
            height = height + (status:GetHeight() or 0)
        end
    end
    return count, width, height
end

MarkStatus = function()
    for _, frame in ipairs(StatusFrames()) do
        local mark = Record(frame, statusMark[frame])
        mark.count, mark.width, mark.height = BarSums(frame)
        statusMark[frame] = mark
    end
end

local function StatusMoved()
    for _, frame in ipairs(StatusFrames()) do
        local mark = statusMark[frame]
        if Differs(frame, mark) then return true end
        local count, width, height = BarSums(frame)
        if count ~= mark.count or math.abs(width - mark.width) > 0.05 or math.abs(height - mark.height) > 0.05 then
            return true
        end
    end
    return false
end

local function StatusBack()
    if not active or applying then return end
    ns.stripPasses = (ns.stripPasses or 0) + 1
    applying = true
    pcall(LayoutStatusBars)
    applying = false
    MarkStatus()
end

-- 1.x had no end caps on the bar itself; the band draws its own. Hide
-- Bar Art, flipped in edit mode, is answered here too: only the band's
-- own art has anything to say to it, so the gryphons go without a whole
-- layout pass, which stuttered while the setting was being flipped.
-- Pieces that are part of the band have no position of their own in
-- 1.x, so their edit mode selection boxes stay hidden while it is on.
-- The micro menu and the bags keep their boxes: they are pieces the
-- player can take off the band.
local BAND_SYSTEMS = { "MicroMenuContainer", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" }
local function HideSelections()
    for _, name in ipairs(BAND_SYSTEMS) do
        local system = _G[name]
        local selection = system and system.Selection
        if selection and selection:IsShown() then selection:Hide() end
    end
end

local function KeepBarShape()
    local bar = ns.GetMainBar()
    if not bar then return end
    -- The client paints its own gryphons back whenever it refreshes the
    -- bar's art; ours are the ones on show.
    for _, key in ipairs(CAP_KEYS) do
        local cap = CapFrame(bar, key)
        if cap then
            for _, region in ipairs({ cap:GetRegions() }) do
                if region:IsObjectType("Texture") and region:GetAlpha() > 0 then region:SetAlpha(0) end
            end
            local tex = key == "LeftEndCap" and art and art.leftCap or art and art.rightCap
            if tex then tex:SetShown(bar.hideBarArt ~= true and not CapHidden(cap)) end
        end
    end
    if art and (bar.hideBarArt == true) ~= (art.artHidden == true) then ApplyArtShape(bar) end
end

-- A drag of bar 1 in edit mode is the one move the band follows, and
-- the bar's reset-to-default button hands the placement back.
local function ReadBarPlacement()
    local bar = ns.GetMainBar()
    if not bar then return end
    local info = bar.systemInfo
    if ns.db.barDragged then
        if info and info.isInDefaultPosition then
            ns.db.barDragged = false
            ns.QueueApply()
        end
        return
    end
    if baseline[bar] and Differs(bar, baseline[bar]) then ns.db.barDragged = true end
end

-- Bar 1 let go close to where the centered band would have it goes back
-- to exactly there. The client's own snapping works on bar 1's rectangle,
-- which is the twelve buttons and not the band: with the band all but
-- centered, bar 1's right edge lies a few pixels from the screen's
-- center line, the client pulls it onto that line, and the band could
-- never be dropped dead center by hand. Handing the bar its default
-- place is what the band reads as "centered".
local HOME_REACH = 40
local function SnapBarHome()
    local bar = ns.GetMainBar()
    if not bar or not art or not ns.db.barDragged or InCombatLockdown() then return end
    local left, bottom = bar:GetLeft(), bar:GetBottom()
    local screen = UIParent:GetWidth()
    if not left or not bottom or not screen then return end
    -- Bar 1 keeps the plain scale, so its edges are in the screen's own
    -- units, and the band's numbers are spelled out in the band's scale.
    local band = BandNow()
    local wantLeft = screen / 2 + ((ns.db.barOffsetX or 0) - ArtWidth() / 2 + ROW_X) * band
    local wantBottom = ((ns.db.barOffsetY or 0) + ROW_Y) * band
    if math.abs(left - wantLeft) > HOME_REACH or math.abs(bottom - wantBottom) > HOME_REACH then return end
    -- Home by our own record, with nothing written to edit mode. The bar
    -- used to be handed its default place in the layout here, and any
    -- layout write from an addon marks the edit mode pieces as ours for
    -- the session: that was the box asking for an interface restart on
    -- leaving edit mode. The layout keeps the spot the bar was let go
    -- at, a few pixels off; the band reads the record below as "not
    -- dragged", stands at its centered place and puts the bar in it by
    -- a plain anchor, at every login too. A bar the layout holds as
    -- placed is also one the client never lays out again.
    ns.db.barDragged = false
    if ns.MirrorSave then ns.MirrorSave() end
end

-- A burst of changes (the client answering our own move) is cut off so
-- the two never chase each other frame after frame.
local WATCH_EDIT, WATCH_IDLE = 0.05, 0.2
-- Set while a piece of the band is, or has just been, in the player's hand.
local handHeld = false
local handIdle = 0
-- The end cap last seen in the player's hand, read when it is let go.
local capInHand
local burst, burstAt, hold = 0, 0, 0
local function StartWatch()
    if editWatch then return end
    -- The client opens its bag windows from the screen's bottom right
    -- corner, wherever the bag buttons are. They belong over the bags:
    -- the first window is hung from the backpack, and the client chains
    -- the rest off the first itself. Looked at every frame, so a window
    -- is not seen opening in the corner first.
    --
    -- With the option on, the windows also take the size the bag row was
    -- given in edit mode, while the row is off the bar; on the bar, and
    -- with the option off, they are the client's own size.
    local scaledWindows = false
    -- How far in from the screen's right edge the opened bags start, so
    -- they stand beside the action bars down that edge and not on them,
    -- as the old interface had it. The client does this too, but only for
    -- a bar it counts as in its default place, and a bar locked into the
    -- classic layout is not: there the bags opened over the columns.
    -- A bar counts here by what it is on screen: standing up, shown, and
    -- at the right edge. One laid down, or moved off elsewhere, does not.
    local function RightColumnsWidth()
        if ns.db and ns.db.bagsBesideBars == false then return 0 end
        local screenRight = UIParent:GetRight()
        if not screenRight then return 0 end
        local leftmost
        for _, bar in ipairs({ MultiBarRight, MultiBarLeft }) do
            if bar and bar:IsVisible() and (bar:GetAlpha() or 1) > 0 then
                local s = bar:GetEffectiveScale() / UIParent:GetEffectiveScale()
                local l, r, w, h = bar:GetLeft(), bar:GetRight(), bar:GetWidth(), bar:GetHeight()
                if l and r and w and h and h > w * 2 and (screenRight - r * s) < 100 then
                    if not leftmost or l * s < leftmost then leftmost = l * s end
                end
            end
        end
        return leftmost and math.max(0, screenRight - leftmost) or 0
    end
    local besideSet = false
    local function AnchorOpenBags()
        local manager = ContainerFrameSettingsManager
        local backpack = MainMenuBarBackpackButton
        if not manager or not manager.GetBagsShown or not backpack or not backpack:IsVisible() then return end
        local ok, shown = pcall(manager.GetBagsShown, manager)
        local first = ok and type(shown) == "table" and shown[1]
        if not first or not first.GetPoint then return end
        local _, relativeTo = first:GetPoint(1)
        if not (ns.db and ns.db.bagsAboveRow == true) then
            -- Where the default interface opens them. A window still
            -- hanging from the backpack is one we hung there: the
            -- client is asked to lay its windows out again.
            if relativeTo == backpack and type(UpdateContainerFrameAnchors) == "function" then
                pcall(UpdateContainerFrameAnchors)
            end
            -- The first window starts the stack, from the screen's
            -- bottom right corner; the rest hang from it. Only how far in
            -- it starts is ours, read again every frame since the client
            -- lays the windows out afresh whenever one opens or shuts.
            local point, rel, relPoint, x, y = first:GetPoint(1)
            if point == "BOTTOMRIGHT" and relPoint == "BOTTOMRIGHT" and rel and rel == first:GetParent() then
                local width = RightColumnsWidth()
                if width > 0 then
                    local scale = first:GetScale() or 1
                    if scale <= 0 then scale = 1 end
                    local target = -(width + 10) / scale
                    if math.abs((x or 0) - target) > 0.5 then
                        first:SetPoint(point, rel, relPoint, target, y or 0)
                    end
                    besideSet = true
                elseif besideSet then
                    besideSet = false
                    if type(UpdateContainerFrameAnchors) == "function" then pcall(UpdateContainerFrameAnchors) end
                end
            end
        elseif relativeTo ~= backpack then
            first:ClearAllPoints()
            first:SetPoint("BOTTOMRIGHT", backpack, "TOPRIGHT", 0, 10)
        end
        local piece = BagsBar
        local follow = ns.db and ns.db.bagWindowsFollow and piece and ((shape.bagsReal == false) or OneBar())
        if not follow and not scaledWindows then return end
        local base = 1
        if type(GetContainerScale) == "function" then
            local okScale, value = pcall(GetContainerScale)
            if okScale and type(value) == "number" and value > 0 then base = value end
        end
        local want = follow and base * (piece:GetScale() or 1) or base
        for _, frame in ipairs(shown) do
            if math.abs((frame:GetScale() or 1) - want) > 0.001 then frame:SetScale(want) end
        end
        scaledWindows = follow and true or false
    end

    -- The one setting of ours that belongs to the client's Bags dialog:
    -- a small panel of the same make, hung under that dialog while it is
    -- up for the bags. It is a frame of ours beside the dialog, not a
    -- child put into it, which the dialog would count into its own size.
    local function BagsExtra()
        local extra = art.bagsExtra
        if extra then return extra end
        extra = CreateFrame("Frame", "ForeverClassicUIBagsExtra", UIParent)
        extra:SetFrameStrata("DIALOG")
        extra:SetFrameLevel(200)
        extra:SetHeight(184)
        extra:Hide()
        art.bagsExtra = extra
        local okBorder, border = pcall(CreateFrame, "Frame", nil, extra, "DialogBorderTranslucentTemplate")
        if okBorder and border then
            border:SetAllPoints(extra)
        else
            local ground = extra:CreateTexture(nil, "BACKGROUND")
            ground:SetAllPoints(extra)
            ground:SetColorTexture(0, 0, 0, 0.85)
        end
        local check = CreateFrame("CheckButton", nil, extra, "UICheckButtonTemplate")
        check:SetSize(30, 30)
        check:SetPoint("TOPLEFT", extra, "TOPLEFT", 22, -14)
        check:SetScript("OnClick", function(self)
            ns.db.bagWindowsFollow = self:GetChecked() and true or false
        end)
        extra.check = check
        local text = extra:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
        text:SetPoint("LEFT", check, "RIGHT", 6, 0)
        text:SetText("Opened bags take this size too")
        -- Opened bags above the bag buttons: the same toggle the addon's
        -- own settings carry, read from the same place, so the two agree.
        local above = CreateFrame("CheckButton", nil, extra, "UICheckButtonTemplate")
        above:SetSize(30, 30)
        above:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 0, -2)
        above:SetScript("OnClick", function(self)
            ns.db.bagsAboveRow = self:GetChecked() and true or false
            if ns.ToggleChanged then ns.ToggleChanged("bagsAboveRow") end
        end)
        extra.above = above
        local aboveText = extra:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
        aboveText:SetPoint("LEFT", above, "RIGHT", 6, 0)
        aboveText:SetText("Opened bags above the bag buttons")
        -- One bag: the same toggle the addon's own settings carry.
        local one = CreateFrame("CheckButton", nil, extra, "UICheckButtonTemplate")
        one:SetSize(30, 30)
        one:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -2)
        one:SetScript("OnClick", function(self)
            ns.db.oneBag = self:GetChecked() and true or false
            if ns.ToggleChanged then ns.ToggleChanged("oneBag") end
            if extra.InitColumns then extra.InitColumns() end
        end)
        extra.one = one
        local oneText = extra:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
        oneText:SetPoint("LEFT", one, "RIGHT", 6, 0)
        oneText:SetText("One bag: all bags open as one window")
        -- How many slots across the one bag window is, for one bag only.
        local colsLabel = extra:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
        colsLabel:SetPoint("TOPLEFT", one, "BOTTOMLEFT", 6, -10)
        colsLabel:SetText("One bag columns")
        extra.colsLabel = colsLabel
        local okSlider, slider = pcall(CreateFrame, "Frame", nil, extra, "MinimalSliderWithSteppersTemplate")
        if okSlider and slider and slider.Init then
            slider:SetSize(180, 32)
            slider:SetPoint("LEFT", colsLabel, "RIGHT", 10, 0)
            extra.slider = slider
            local low, high = ns.ONE_BAG_COLUMNS_MIN or 4, ns.ONE_BAG_COLUMNS_MAX or 16
            local formatters
            if CreateMinimalSliderFormatter and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
                formatters = { [MinimalSliderWithSteppersMixin.Label.Right] = CreateMinimalSliderFormatter(
                    MinimalSliderWithSteppersMixin.Label.Right, function(value) return tostring(math.floor(value + 0.5)) end) }
            end
            extra.InitColumns = function()
                extra.filling = true
                slider:Init(tonumber(ns.db.oneBagColumns) or low, low, high, high - low, formatters)
                extra.filling = false
                local on = ns.db.oneBag == true
                slider:SetAlpha(on and 1 or 0.4)
                if slider.SetEnabled then pcall(slider.SetEnabled, slider, on) end
                colsLabel:SetFontObject(on and "GameFontHighlightMedium" or "GameFontDisableMed3")
            end
            if slider.RegisterCallback and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Event then
                slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
                    if extra.filling or type(value) ~= "number" or not ns.SetOneBagColumns then return end
                    ns.SetOneBagColumns(value)
                end, extra)
            end
        end
        -- These are the addon's own settings, not part of the layout:
        -- they take effect and are kept the moment they are ticked, and
        -- the dialog's Save and Revert neither need nor undo them. Said
        -- in so many words, since the Save button staying dark otherwise
        -- reads as "nothing happened".
        local saved = extra:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        saved:SetPoint("BOTTOMLEFT", extra, "BOTTOMLEFT", 26, 14)
        saved:SetText("These apply and save the moment you change them. No Save needed.")
        -- Reset To Default Size, which the client's dialog does not
        -- have: a button of ours laid beside its Revert Changes. The size
        -- is changed through the client's own entry point for a dialog
        -- setting, so it counts as an edit like any other and can be
        -- saved or reverted with the rest.
        local resize = CreateFrame("Button", nil, extra, "UIPanelButtonTemplate")
        resize:SetHeight(28)
        resize:SetText("Reset To Default Size")
        resize:SetFrameLevel(210)
        resize:SetScript("OnClick", function()
            local setting = Enum and Enum.EditModeBagsSetting and Enum.EditModeBagsSetting.Size
            local manager = EditModeManagerFrame
            if setting == nil or not manager or not manager.OnSystemSettingChange or not BagsBar then return end
            pcall(manager.OnSystemSettingChange, manager, BagsBar, setting, 100)
            ns.editWrote = true
            local dialog = EditModeSystemSettingsDialog
            if dialog and dialog.UpdateDialog then pcall(dialog.UpdateDialog, dialog, BagsBar) end
        end)
        extra.resize = resize
        return extra
    end

    local function FollowBagsDialog(editing)
        local dialog = EditModeSystemSettingsDialog
        local up = editing and dialog and dialog:IsShown() and dialog.attachedToSystem == BagsBar
        local extra = art and art.bagsExtra
        if not up then
            if extra and extra:IsShown() then extra:Hide() end
            return
        end
        extra = BagsExtra()
        extra:ClearAllPoints()
        extra:SetPoint("TOPLEFT", dialog, "BOTTOMLEFT", 0, 6)
        extra:SetPoint("TOPRIGHT", dialog, "BOTTOMRIGHT", 0, 6)
        extra.check:SetChecked(ns.db.bagWindowsFollow and true or false)
        if extra.one then extra.one:SetChecked(ns.db.oneBag == true) end
        if extra.above then extra.above:SetChecked(ns.db.bagsAboveRow == true) end
        if extra.InitColumns then extra.InitColumns() end
        local revert = dialog.Buttons and dialog.Buttons.RevertChangesButton
        if revert and extra.resize then
            extra.resize:ClearAllPoints()
            extra.resize:SetPoint("LEFT", revert, "RIGHT", 6, 0)
            extra.resize:SetPoint("RIGHT", dialog.Buttons, "RIGHT", 0, 0)
            extra.resize:Show()
        elseif extra.resize then
            extra.resize:Hide()
        end
        extra:Show()
    end

    editWatch = CreateFrame("Frame")
    editWatch:SetScript("OnUpdate", function(self, elapsed)
        if active then AnchorOpenBags() end
        -- The tracking bars are answered on the frame they move rather
        -- than on the beat. The client re-anchors them on every managed
        -- frame change, and taking a target is one, so a beat's wait is
        -- long enough to watch the experience bar hop out of the band
        -- and back. They are not protected and the check is two frames
        -- deep, so it costs nothing to do it every frame.
        if active and not applying and StatusMoved() then StatusBack() end
        local mgr = EditModeManagerFrame
        local editing = mgr and mgr.IsEditModeActive and mgr:IsEditModeActive() and true or false
        -- A held button in edit mode is a drag: the client re-anchors on
        -- every mouse move and the snap answers ours, so nothing of ours
        -- runs until it is let go. Read every frame, not on the beat: the
        -- client lays its bottom stack out again as a piece is let go,
        -- which carries the band's bars off, and the beat's wait and a
        -- queued pass after it were frames in which their boxes stood
        -- somewhere else. The drop is answered on the frame it happens.
        local held = active and editing and IsMouseButtonDown and IsMouseButtonDown("LeftButton") and true or false
        if active and held ~= dragging then
            dragging = held
            if not held then
                if editing then
                    ReadBarPlacement()
                    SnapBarHome()
                    bagsDropped = true
                    if capInHand then
                        local key, bar = capInHand, ns.GetMainBar()
                        local cap = CapFrame(bar, key)
                        ns.db.capMoved = ns.db.capMoved or {}
                        local slotX = ArtWidth() / 2 + CapSlot(key, ArtWidth()) - CAP_SIZE / 2
                        if cap and NearBandSlot(cap, slotX, 0, "BOTTOMLEFT")
                            and type(cap.ResetToDefaultPosition) == "function" and pcall(cap.ResetToDefaultPosition, cap) then
                            ns.editWrote = true
                            ns.db.capMoved[key] = nil
                        else
                            ns.db.capMoved[key] = true
                        end
                    end
                end
                capInHand = nil
                handHeld = false
                if not InCombatLockdown() then ns.SafeCall(Apply) end
                ns.QueueApply()
            end
        end
        self.since = (self.since or 0) + elapsed
        if self.since < (editing and WATCH_EDIT or WATCH_IDLE) then return end
        self.since = 0
        if not active then return end
        -- Hide Bar Scrolling ticked or cleared: the band is cut again.
        if editing and (BarSetting(ns.GetMainBar(), "HideBarScrolling") == 1) ~= (shape.noPages and true or false) then
            ns.QueueApply()
        end
        if editing then HideSelections() end
        if editing and ns.microDirty and mgr then
            -- By the buttons' plain widget call, which sets no field of
            -- the client's: the client's own count of changes is left
            -- as it is, and it may put the buttons out again at any
            -- time, so they are relit for as long as the note stands.
            for _, key in ipairs({ "SaveChangesButton", "RevertAllChangesButton" }) do
                local button = mgr[key]
                if button then
                    if not button:IsEnabled() then
                        local raw = getmetatable(button)
                        raw = raw and raw.__index
                        if type(raw) == "table" and raw.Enable then raw.Enable(button) else button:Enable() end
                    end
                    if not button.fcuiMicroHooked then
                        button.fcuiMicroHooked = true
                        button:HookScript("OnClick", function()
                            if not ns.microDirty then return end
                            local before = ns.microBefore
                            ns.microDirty, ns.microBefore = false, nil
                            if key == "RevertAllChangesButton" and before and ns.db then
                                ns.db.microPos, ns.db.microScale, ns.db.bagsFirst = before.pos, before.scale, before.bagsFirst
                                if ns.MirrorSave then ns.MirrorSave() end
                                ns.QueueApply()
                            end
                        end)
                    end
                end
            end
        elseif not editing and ns.microDirty then
            -- Edit mode left without either: the move is kept.
            ns.microDirty, ns.microBefore = false, nil
        end
        -- A bar turned or folded in its edit mode window: nothing tells
        -- us, so the settings are read while edit mode is up, and the
        -- bars laid out again the moment one of them changes.
        if editing then
            local mark = ""
            for _, name in ipairs({ "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "StanceBar", "PetActionBar" }) do
                local bar = _G[name]
                if bar then mark = mark .. tostring(BarVertical(bar)) .. BarRows(bar) .. tostring(BarSetting(bar, "NumIcons")) .. ";" end
            end
            if self.barMark and self.barMark ~= mark then ns.QueueApply() end
            self.barMark = mark
        else
            self.barMark = nil
        end
        -- The bags are dragged by the client's own box. While it is held
        -- the same preview runs: near the sockets the band is drawn with
        -- the bags on it, away from them without.
        local bagsPiece = BagsBar
        if bagsPiece and bagsPiece.isDragging and not OneBar() then
            local place = DropPlace("bags", bagsPiece, dragPreview.bagsFirst)
            local near = place ~= nil
            if dragPreview.bags ~= near or (near and dragPreview.bagsFirst ~= place) then
                dragPreview.bags = near
                -- Not "near and place or nil": place is false for one of the two
                -- orders, and that idiom turns a false into nil, which
                -- read as "no preview" and fell back to the saved order.
                if near then dragPreview.bagsFirst = place else dragPreview.bagsFirst = nil end
                ns.QueueApply()
            end
        elseif dragPreview.bags ~= nil then
            dragPreview.bags, dragPreview.bagsFirst = nil, nil
        end
        -- The client's own segment posts on the experience bar. It makes
        -- new ones whenever it lays the bar out, for its own width, and
        -- they showed beside the band's as a second, closer set of
        -- posts. They are looked for on the beat rather than from a hook
        -- in the client's layout, which is no place for our code.
        for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
            local pool = container and container.HorizontalDividersPool
            if pool and pool.EnumerateActive then
                for divider in pool:EnumerateActive() do
                    if divider:GetAlpha() > 0 then divider:SetAlpha(0) end
                end
            end
        end
        local handle = art and art.microHome and art.microHome.handle
        if handle and handle:IsShown() ~= editing then
            -- The group's own level moves with the buttons', and takes
            -- the handle's along with it.
            if editing then handle:SetFrameLevel(1010) end
            handle:SetShown(editing)
        end
        if not editing and art and art.microDialog and art.microDialog:IsShown() then art.microDialog:Hide() end
        if art then FollowBagsDialog(editing) end
        if not dragging and not InCombatLockdown() then KeepBarShape() end
    end)

    -- The client re-lays the bars on its own, a new target being one of
    -- its reasons, and whatever it drew stays on screen until ours runs.
    -- On a beat, and queued for the frame after, that was a visible jump
    -- of the chat and the side bars on every target. This runs every
    -- frame and lays the band out on the spot, so the client's version
    -- lives a frame at most. A fight still keeps the client's version:
    -- the bars are its to move there and not ours.
    -- Whether a piece of the band is in the player's hand right now. The
    -- client marks its own pieces while it drags them, and the micro
    -- group marks itself. A pass of ours in the middle of a drag put the
    -- dragged piece back on the band, and the client then wrote that spot
    -- down as where it was dropped. A held mouse alone is not a drag: it
    -- is also a size slider being pulled, and the pieces have to follow
    -- that as it moves, not once it is let go.
    local function PieceInHand()
        for _, name in ipairs(OWNED_SYSTEMS) do
            local frame = _G[name]
            if frame and frame.isDragging then return true end
        end
        local bar = ns.GetMainBar()
        for _, key in ipairs(CAP_KEYS) do
            local cap = CapFrame(bar, key)
            if cap and cap.isDragging then
                capInHand = key
                return true
            end
        end
        local home = art and art.microHome
        return (home and home.moving) and true or false
    end

    local function PlaceNow()
        if not active or applying then return end
        -- A piece in hand blocks us, and goes on blocking after it is
        -- let go until the beat has read where it was dropped. Without
        -- that, the pass that ran the moment bar 1 was let go still took
        -- it for unmoved, put it back, and the drop was never seen.
        if PieceInHand() then
            -- Bar 1 picked up from its default place: the band, which
            -- stands on the screen there, is hung on the bar for the drag
            -- to carry it. The band is a frame of our own.
            local bar = ns.GetMainBar()
            if bar and bar.isDragging and art and not handHeld then
                art:ClearAllPoints()
                art:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -ROW_X, -ROW_Y)
            end
            handHeld = true
            return
        end
        if handHeld then
            -- The beat clears this when it reads the drop. Should it ever
            -- miss one, a mouse that is up with nothing in hand is proof
            -- enough, and the band is not left frozen.
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                handIdle = (handIdle or 0) + 1
                if handIdle > 30 then handHeld, handIdle = false, 0 end
            end
            if handHeld then return end
        end
        handIdle = 0
        local rows = RowsMoved()
        -- The bars are the client's to move in a fight; the bag and the
        -- micro rows are not, and go straight back.
        local fight = InCombatLockdown()
        if fight then
            -- A bar the client has moved in a fight stays moved until the
            -- fight ends. Once a session, when it has just happened and
            -- the layout still holds bars of the band as the client's,
            -- the player is told why and what ends it.
            -- Not with edit mode up during the fight: there the player
            -- is moving things, and the client lays its pieces out again
            -- as they do. That was taken for the client shifting the bars
            -- and the question was put after the fight for nothing. A
            -- fight that had edit mode open at any point is not judged.
            local manager = EditModeManagerFrame
            if manager and manager.IsEditModeActive and manager:IsEditModeActive() then
                ns.fightEdited = true
                shiftSeen = false
            end
            if not shiftSeen and not ns.fightEdited then
                for _, frame in ipairs(ns.BandBarsToUnpinned()) do
                    -- Only a bar the band has a place on record for.
                    if baseline[frame] and Differs(frame, baseline[frame]) then
                        shiftSeen = true
                        -- For the development log: which bar, when, and from where to where.
                        local b = baseline[frame]
                        local point, rel, relPoint, x, y = frame:GetPoint(1)
                        ns.Persist(string.format("bars: %s off its place %.2f s into the fight: was %s>%s.%s %.0f,%.0f scale %.2f shown %s; now %s>%s.%s %.0f,%.0f scale %.2f shown %s",
                            tostring(frame:GetName()), GetTime() - (ns.fightBeganAt or GetTime()),
                            tostring(b.point), tostring(b.rel and b.rel.GetName and b.rel:GetName()), tostring(b.relPoint), b.x or 0, b.y or 0, b.scale or 1, tostring(b.shown),
                            tostring(point), tostring(rel and rel.GetName and rel:GetName()), tostring(relPoint), x or 0, y or 0, frame:GetScale() or 1, tostring(frame:IsShown())))
                        break
                    end
                end
            end
            if not (rows and RowsFree()) then return end
        elseif ns.fightEdited then
            ns.fightEdited = nil
            shiftSeen = false
        elseif shiftSeen then
            -- No window is put up about it any more. The bars' frames
            -- are back by now (the pass below), and nothing that is drawn
            -- went with them: the band stands on the screen and the
            -- buttons hang on the band. Every fight is judged afresh.
            shiftSeen = false
            ns.Persist("bars: moved by the client during a fight; put back, nobody asked")
        elseif not rows and not Moved() then
            return
        end
        -- The burst guard is for the client answering our own moves.
        -- With the mouse held in edit mode the changes are the player's,
        -- a slider being pulled, and every one of them is followed.
        local mgr = EditModeManagerFrame
        local byHand = mgr and mgr.IsEditModeActive and mgr:IsEditModeActive()
            and IsMouseButtonDown and IsMouseButtonDown("LeftButton")
        if not byHand then
            local now = GetTime()
            if now < hold then return end
            if now - burstAt < 1 then burst = burst + 1 else burst = 0 end
            burstAt = now
            if burst > 8 then
                burst, hold = 0, now + 0.6
                return
            end
        end
        if fight then RowsBack() else ns.SafeCall(Apply) end
    end
    local placer = CreateFrame("Frame")
    placer:SetScript("OnUpdate", PlaceNow)
    -- A bar the layout does not pin is still moved by the client on a
    -- new target, and the client does it while that event is being
    -- handed round. A frame of ours hears the event after the client's
    -- own, so the answer lands before anything is drawn. It is a
    -- handler of our own, not a hook in the client's.
    placer:RegisterEvent("PLAYER_TARGET_CHANGED")
    placer:RegisterEvent("PLAYER_FOCUS_CHANGED")
    -- The same for the start of a fight, which is where the bars were
    -- seen to hop. Every one of the client's action bars answers this
    -- event by laying the whole bottom stack out again, which takes any
    -- bar the layout does not pin off the band; and until now nothing of
    -- ours ran until the next frame, by when the fight had begun and the
    -- bars were out of reach until it ended. But the fight has not begun
    -- while this event is still being handed round: what an addon may
    -- not do in a fight it may still do here. Heard after the client's
    -- bars have heard it, the bars are put back in the same moment, before
    -- anything is drawn and before they are locked, on any layout, pinned
    -- or not, with nothing written to edit mode. The end of a fight and
    -- the pet and stance bars coming and going are heard the same way.
    for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PET_BAR_UPDATE", "UPDATE_SHAPESHIFT_FORMS",
        "UPDATE_BONUS_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR", "UPDATE_OVERRIDE_ACTIONBAR" }) do
        pcall(placer.RegisterEvent, placer, event)
    end
    pcall(placer.RegisterUnitEvent, placer, "UNIT_PET", "player")
    -- An event is handed round in the order its listeners signed up for
    -- it, and ours has to be the last word: the first fight of a session
    -- showed the bars put back and then, in the same moment, laid out
    -- again by a listener of the client's that had signed up after us.
    -- So out of a fight we keep signing up afresh for the start of one,
    -- which puts us at the end of the line each time.
    local lastWord = CreateFrame("Frame")
    lastWord:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 1 then return end
        self.since = 0
        if InCombatLockdown() then return end
        placer:UnregisterEvent("PLAYER_REGEN_DISABLED")
        placer:RegisterEvent("PLAYER_REGEN_DISABLED")
    end)
    placer:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            -- For the development log: whether the client had moved them
            -- by the time we heard, and whether they were still ours to move.
            local ok, moved = pcall(Moved)
            ns.fightBeganAt = GetTime()
            ns.Persist("bars: fight beginning; moved by the client " .. tostring(ok and moved) .. ", locked " .. tostring(InCombatLockdown()))
            PlaceNow()
            local okAfter, movedAfter = pcall(Moved)
            ns.Persist("bars: after our pass, still moved " .. tostring(okAfter and movedAfter) .. ", locked " .. tostring(InCombatLockdown()) .. ", passes " .. tostring(ns.bandPasses))
            return
        end
        PlaceNow()
    end)
end

local function Init()
    local bar = ns.GetMainBar()
    if not bar then return end
    -- Everything the client does to a bar, a container, the micro row or
    -- the bags is answered from this one watch: where it moved them, how
    -- big it made them and whether it showed them. Its beat is short
    -- while the edit mode panel is open, since the client draws its
    -- selection box on the bar it just laid out and ours moves that bar.
    StartWatch()
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
        if event == "PLAYER_ENTERING_WORLD" then
            RecolorExpBars()
            -- The client is still handing the tracking containers their
            -- bars for a while after this, and a bar that arrives with
            -- the size it was built at moves nothing the watch can see.
            -- A few passes over the first seconds catch it.
            for _, wait in ipairs({ 0.5, 1.5, 3 }) do
                C_Timer.After(wait, function() if active then ns.QueueApply() end end)
            end
            return
        end
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
    -- Edit mode shows the classic bar as it is; a fresh pass puts the
    -- selection boxes over the right spots.
    if ns.OnEditMode then
        ns.OnEditMode(function()
            dragging = false
            if active then ns.QueueApply() end
        end)
    end
end

-- The bars the client's two passes move and the band places.
local PIN_NAMES = { "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
    "MultiBarLeft", "StanceBar", "PetActionBar", "PossessActionBar", "MainStatusTrackingBarContainer",
    "SecondaryStatusTrackingBarContainer" }

-- Every bar still in the client's hands: shown, the band's to place,
-- and held "in default position" by the layout.
-- The band's bars the active layout still holds as the client's own.
function ns.BandBarsToUnpinned()
    local list = {}
    if not active or not art then return list end
    for _, name in ipairs(PIN_NAMES) do
        local frame = _G[name]
        if frame and frame.system and frame:IsShown() and type(frame.IsInDefaultPosition) == "function" then
            local ok, isDefault = pcall(frame.IsInDefaultPosition, frame)
            if ok and isDefault then list[#list + 1] = frame end
        end
    end
    return list
end

function ns.BandBarsToPin()
    local list = {}
    if not active or not art then return list end
    for _, name in ipairs(PIN_NAMES) do
        local frame = _G[name]
        if frame and frame.system and frame:IsShown() and type(frame.IsInDefaultPosition) == "function" then
            local ok, isDefault = pcall(frame.IsInDefaultPosition, frame)
            -- A bar already pinned is pinned again: the band is not
            -- always the same length now, and a pin written for one
            -- length is the wrong spot for another.
            local info = frame.systemInfo and frame.systemInfo.anchorInfo
            if ok and (isDefault or PinnedByUs(frame, info)) then list[#list + 1] = frame end
        end
    end
    return list
end

-- The spot the band gave a bar, said against the screen instead of the
-- band: the layout is read before the band exists, and outlives it.
local function AnchorToScreen(frame)
    local point, relativeTo, relativePoint = frame:GetPoint(1)
    -- Already held to the screen in the shape of a pin of ours.
    if relativeTo == UIParent and point ~= relativePoint then return true end
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    if not left or not bottom then return false end
    local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if not ratio or ratio <= 0 then return false end
    local half = UIParent:GetWidth() / 2 / ratio
    -- Two unlike points, which is how a pin of ours is known again (see
    -- PinnedByUs), and measured from the screen's middle, where the band
    -- stands whatever the screen's width.
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", left - half, bottom)
    return true
end

-- Writes the band's bars into the active layout where the band has
-- them, on any layout of the player's own, the addon's included. It was
-- once the addon's layout alone, on the thought that another layout's
-- bars are the player's to place. But a bar a layout holds as "in its
-- default place" is not the player's, it is the client's, which lays
-- the stack out again in the middle of a fight, where nothing of ours
-- may put it back: on any other layout the bars jumped about in combat.
-- A bar the player did place is not in its default place, is not in
-- this list, and is left alone. The client's presets cannot be written. The layout tables are
-- written by our call, so the session wants a reload afterwards, the
-- same as after the layout is switched.
local ResetEndCaps
function ns.PinBandBars()
    -- Only in the press that reloads the interface: a layout written
    -- under a game that goes on marks every edit mode piece as ours for
    -- the rest of it.
    if not ns.sessionEnding then return false end
    if not active or not art or InCombatLockdown() then return false end
    if not (ns.LayoutWritable and ns.LayoutWritable()) then return false end
    local mgr = EditModeManagerFrame
    if not mgr or not mgr.UpdateSystemAnchorInfo or not mgr.SaveLayouts then return false end
    local layoutName = ActiveLayoutName()
    if not layoutName then return false end
    local changed = false
    applying = true
    for _, frame in ipairs(ns.BandBarsToPin()) do
        if AnchorToScreen(frame) then
            local ok, did = pcall(mgr.UpdateSystemAnchorInfo, mgr, frame)
            -- Read back from the layout itself, which is what the client
            -- just wrote to and what it will hand the bar after a reload.
            local held = mgr.GetActiveLayoutSystemInfo and mgr:GetActiveLayoutSystemInfo(frame.system, frame.systemIndex)
            local info = (held and held.anchorInfo) or (frame.systemInfo and frame.systemInfo.anchorInfo)
            if ok and did and info then
                ns.db.barPins = ns.db.barPins or {}
                ns.db.barPins[layoutName] = ns.db.barPins[layoutName] or {}
                ns.db.barPins[layoutName][frame:GetName()] = {
                    point = info.point, relativePoint = info.relativePoint,
                    offsetX = info.offsetX, offsetY = info.offsetY,
                }
                changed = true
            end
        end
    end
    applying = false
    if ResetEndCaps() then changed = true end
    if changed then pcall(mgr.SaveLayouts, mgr) end
    -- Every pin of this layout is in the new shape from here on.
    ns.db.pinShape = true
    return changed
end

-- Where the band has each of its bars right now, said against the
-- screen the way the layout keeps an anchor, without touching a frame
-- or a layout: for a layout that is not the live one.
function ns.BandPinAnchors()
    local out = {}
    for _, frame in ipairs(ns.BandBarsToPin()) do
        local left, bottom = frame:GetLeft(), frame:GetBottom()
        local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local scale = frame:GetScale()
        if left and bottom and ratio and ratio > 0 and scale and scale > 0 then
            local half = UIParent:GetWidth() / 2 / ratio
            out[#out + 1] = {
                name = frame:GetName(), system = frame.system, systemIndex = frame.systemIndex,
                anchorInfo = {
                    point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOM",
                    offsetX = (left - half) * scale, offsetY = bottom * scale,
                },
            }
        end
    end
    return out
end

-- Bars the client still holds are pinned as the session ends, a reload
-- or a logout alike. A layout written from an addon's call leaves the
-- client wary of it until the interface loads again, and at this moment
-- there is no session left to be wary in: the next one reads the layout
-- fresh, pins and all. So nobody is asked anything, and a player who
-- updates has steady bars from their next login on.
-- On Forever the two gryphons are edit mode pieces of their own, snapped
-- to the main bar. Whenever the bar is moved or hidden the client turns
-- that snap into a fixed spot on screen, wherever the cap happened to
-- be, and a save then keeps it: the band hides the caps, so nobody saw,
-- until the band was turned off and a gryphon stood in the wrong place.
-- On the addon's own layout they go back to their default, which is the
-- snap, before anything is saved.
ResetEndCaps = function()
    local bar = ns.GetMainBar()
    local caps = bar and bar.EndCaps
    if not caps then return false end
    local changed = false
    for _, key in ipairs({ "LeftEndCap", "RightEndCap" }) do
        local cap = caps[key]
        -- A cap the player dragged is theirs, and keeps its spot.
        if cap and not (active and CapMoved(key)) and cap.system and type(cap.IsInDefaultPosition) == "function" and type(cap.ResetToDefaultPosition) == "function" then
            local ok, isDefault = pcall(cap.IsInDefaultPosition, cap)
            if ok and not isDefault and pcall(cap.ResetToDefaultPosition, cap) then changed = true end
        end
    end
    return changed
end

-- Turning the band off hands the client's bar region back whole. On the
-- addon's own layout every piece the band placed goes back to the
-- client's default: the bars, pinned or not, the bags and the micro menu
-- wherever they had been dragged, and the end caps. They were all placed
-- around the stone bar, and with the client's own bar back in its place
-- those spots are wrong: a micro menu across the middle of bar 1, bags on
-- top of its buttons, rows left hanging where the band used to be. Done
-- once per turning off, so a piece moved afterwards, with the band off,
-- is left where the player put it. Returns whether the layout changed.
local HAND_BACK = { "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight",
    "MultiBarLeft", "StanceBar", "PetActionBar", "PossessActionBar", "MainStatusTrackingBarContainer",
    "SecondaryStatusTrackingBarContainer", "BagsBar", "MicroMenuContainer" }

function ns.UnpinBandBars()
    if not ns.sessionEnding then return false end
    if InCombatLockdown() then return false end
    if not (ns.LayoutWritable and ns.LayoutWritable()) then return false end
    local mgr = EditModeManagerFrame
    if not mgr or not mgr.SaveLayouts then return false end
    local layoutName = ActiveLayoutName()
    -- The addon's own layout is reset piece by piece. On a layout of the
    -- player's only what we pinned goes back: anything else that is out
    -- of its default place is where the player put it.
    local ours = ns.ClassicLayoutActive and ns.ClassicLayoutActive()
    local changed = false
    for _, name in ipairs(HAND_BACK) do
        local frame = _G[name]
        if frame and frame.system and type(frame.IsInDefaultPosition) == "function" and type(frame.ResetToDefaultPosition) == "function" then
            local ok, isDefault = pcall(frame.IsInDefaultPosition, frame)
            local info = frame.systemInfo and frame.systemInfo.anchorInfo
            if ok and not isDefault and (ours or PinnedByUs(frame, info)) and pcall(frame.ResetToDefaultPosition, frame) then changed = true end
        end
    end
    if ResetEndCaps() then changed = true end
    if layoutName and ns.db.barPins then ns.db.barPins[layoutName] = nil end
    ns.db.barDragged = false
    ns.db.bandHandedBack = true
    if changed then
        -- Bars held as default again are the client's to stack.
        if mgr.UpdateActionBarPositions then pcall(mgr.UpdateActionBarPositions, mgr) end
        pcall(mgr.SaveLayouts, mgr)
    end
    return changed
end

-- The pins are written, and taken out, from ns.ReloadForLayout: the
-- press of any button of ours that reloads the interface. They used to
-- be written in the logout as well, so that nobody had to be asked; the
-- client's edit mode interface is shut by then, and nothing written
-- there was ever kept.

-- Bars the layout holds somewhere that is neither their default nor a
-- pin of ours read as dragged by the player, and the band leaves them
-- where they are. Settings lost while the layout kept its pins make
-- every pinned bar look like that. This takes them back: each goes to
-- its default, the band lays them, and they are pinned afresh.
function ns.AdoptBandBars()
    if not ns.sessionEnding then return false end
    if InCombatLockdown() or not active then return false end
    -- The addon's own layout only: on a layout of the player's a bar
    -- out of its default place with no pin of ours is one they placed.
    if not (ns.ClassicLayoutActive and ns.ClassicLayoutActive()) then return false end
    local count = 0
    for _, name in ipairs(PIN_NAMES) do
        local frame = _G[name]
        if frame and frame.system and type(frame.IsInDefaultPosition) == "function" and type(frame.ResetToDefaultPosition) == "function" then
            local ok, isDefault = pcall(frame.IsInDefaultPosition, frame)
            if ok and not isDefault and pcall(frame.ResetToDefaultPosition, frame) then count = count + 1 end
        end
    end
    ns.db.barDragged = false
    -- Laid at once; the logout's pin step follows.
    ns.ApplyAll()
    return count
end

function ns.ClassicBarInfo()
    if not art then return "not built" end
    return string.format("art shown=%s left=%.0f bottom=%.0f scale=%.2f pending=%s", tostring(art:IsShown()), art:GetLeft() or 0, art:GetBottom() or 0, art:GetScale(), tostring(pending))
end

ns.RegisterModule("classicBar", { init = Init, apply = Apply, restore = Restore })
