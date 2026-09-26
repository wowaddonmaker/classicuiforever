local _, ns = ...
local B = ns.band

-- The latency bar and the key ring as pieces of their own: in the band's section (BandShape) until hidden (their options,
-- or the box's dialog) or dragged off the band by their edit mode box to stand alone in their own cut of the section art.
-- Dropped near the band they go back. Places are ours (db.latencyPos, db.keyRingPos), as the micro menu's.

local BAND_H, BAND_RUN = B.BAND_H, B.BAND_RUN
local Seat, CurrentPlan = B.Seat, B.CurrentPlan
local SHEET = B.PIECES[5]
local KEY_Y = 21
local RUN = {}

-- u0, u1: the piece standing alone. The shared post between window and slot is wider than the end posts: the latency bar
-- keeps 8 of its 9 columns, the key ring takes its own end post mirrored (cap, cap wide) on its left instead.
local ELEMENTS = {
    { label = "Latency Bar", hideKey = "hideLatencyBar", posKey = "latencyPos", u0 = 0, u1 = 22, cap = 0 },
    { label = "Key Ring", hideKey = "hideKeyRing", posKey = "keyRingPos", u0 = 23, u1 = 45, cap = 7 },
}
local LATENCY, KEYRING = ELEMENTS[1], ELEMENTS[2]

local function Hidden(el) return ns.db[el.hideKey] == true end
local function Moved(el) return ns.ValidPlace(ns.db[el.posKey]) end

-- Hidden, or with no place of ours this layout, the client's key ring is hidden (it lays it beside its bags at its own size:
-- the empty box left of the row). Hidden, not faded: an alpha animation on it undoes any fade. Given back as the band goes.
local keyOff, keyWasShown = false, false
local function KeyRingShown(shown)
    local keyRing = KeyRingButton
    if not keyRing then return end
    if not shown then
        if not keyOff then keyWasShown = keyRing:IsShown() end
        keyOff = true
        if keyRing:IsShown() then keyRing:Hide() end
        if keyRing:IsMouseEnabled() then keyRing:EnableMouse(false) end
    elseif keyOff then
        keyOff = false
        ns.SetAlphaIf(keyRing, 1)
        keyRing:EnableMouse(true)
        if keyWasShown then keyRing:Show() end
    end
end
function B.KeyRingBack() KeyRingShown(true) end

-- Shown by the client: hidden again the frame after, never inside its pass.
local function HideAgain()
    if keyOff and B.active then KeyRingShown(false) end
end
local function KeyRingSeen(shown)
    if shown and keyOff then ns.Sched.NextFrame("band.keyRingHide", HideAgain) end
end

-- Its band x and width inside the section, or nil when it is not there.
local function OnBand(el, plan)
    if not plan.tailStart then return nil end
    local latency, key = B.TailParts()
    local u0, u1 = plan.tailU0, plan.tailU1
    if el == LATENCY then
        if not latency then return nil end
        if key then u1 = 14 end
    else
        if not key then return nil end
        if latency then u0 = 14 end
    end
    return plan.tailStart + u0 - plan.tailU0, u1 - u0
end

-- Where a drop puts it back on the band: its place in the section, or where the section stands or would stand.
local function BandSpot(el)
    local plan = CurrentPlan()
    local x = OnBand(el, plan)
    if x then return x end
    if plan.tailStart then return el == LATENCY and plan.tailStart or plan.tailStart + plan.tailU1 - plan.tailU0 end
    if plan.microFirst then return plan.microEnd end
    if plan.bagsFirst then return plan.bagsEnd end
    return plan.bagsStart or plan.width
end

------------------------------------------------------------------ dialog

local dialog
local function RefreshDialog()
    if not (dialog and dialog:IsShown() and dialog.el) then return end
    dialog.title:SetText(dialog.el.label)
    dialog.check:SetChecked(Hidden(dialog.el))
    dialog.reset:SetEnabled(Moved(dialog.el))
end

local function Save()
    RefreshDialog()
    ns.QueueApply()
end

local function Dialog()
    if dialog then return dialog end
    dialog = B.EditDialog("ForeverClassicUISectionDialog", 300, 136)
    local check = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
    check:SetSize(30, 30)
    check:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -46)
    ns.EditModeCheck(check)
    local label = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    label:SetText("Hide")
    check:SetScript("OnClick", function(self)
        local key = dialog.el.hideKey
        ns.db[key] = self:GetChecked() and true or false
        ns.ToggleChanged(key)
        if ns.db[key] then dialog:Hide() end
    end)
    dialog.check = check
    dialog.reset = B.EditDialogReset(dialog, function()
        ns.db[dialog.el.posKey] = nil
        Save()
    end)
    dialog:SetScript("OnShow", RefreshDialog)
    dialog:SetScript("OnHide", function()
        local home = dialog.el and dialog.el.home
        if home then home.handle.Dress("editmode-actionbar-highlight") end
    end)
    return dialog
end

------------------------------------------------------------------ homes

local HANDLE_TIP = { anchor = "ANCHOR_TOP", text = function(self) return self.el.label end, r = 1, g = 1, b = 1, lines = {
    { "Drag off the bar to stand it alone. Let go near the bar to put it back.", 1, 0.82, 0 },
    { "Click to hide it or reset its place. Right-click puts it back.", 1, 0.82, 0 },
} }

local function Undrag()
    LATENCY.dragged, KEYRING.dragged = false, false
end

local function DragStart(handle)
    local home = handle.el.home
    if InCombatLockdown() and home:IsProtected() then return end
    handle.Dress("editmode-actionbar-selected")
    handle.el.moving, handle.el.dragged = true, true
    home:StartMoving()
end

-- Read before the stop: StopMovingOrSizing drops the anchors of a frame others hang on (the key ring on its home).
local function DragStop(handle)
    local el = handle.el
    if not el.moving then return end
    local home = el.home
    local left, bottom = home:GetLeft(), home:GetBottom()
    local spot = BandSpot(el)
    local near = spot and B.NearBandSlot(home, spot, 0, "BOTTOMLEFT")
    home:StopMovingOrSizing()
    el.moving = false
    ns.Sched.NextFrame("band.sectionUndrag", Undrag)
    handle.Dress("editmode-actionbar-highlight")
    local place = (not near and left and bottom) and { point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = left, y = bottom }
    ns.db[el.posKey] = place or nil
    Save()
end

local function MouseUp(handle, button)
    local el = handle.el
    if button == "RightButton" then
        ns.db[el.posKey] = nil
        Save()
        return
    end
    -- The release ending a drag is not a click.
    if el.moving or el.dragged then return end
    local d = Dialog()
    d.el = el
    handle.Dress("editmode-actionbar-selected")
    ns.SetPointOnce(d, "BOTTOM", el.home, "TOP", 0, 40)
    d:Show()
    RefreshDialog()
end

local function Home(el)
    if el.home then return el.home end
    local home = CreateFrame("Frame", nil, B.art)
    home:SetClampedToScreen(true)
    home:SetMovable(true)
    home.art = home:CreateTexture(nil, "BACKGROUND")
    if el.cap > 0 then home.cap = home:CreateTexture(nil, "BACKGROUND") end
    if el == LATENCY then home.tube = B.MakeTube(home) end
    local handle = B.SelectionHandle(home)
    handle.el = el
    handle:SetScript("OnDragStart", DragStart)
    handle:SetScript("OnDragStop", DragStop)
    handle:SetScript("OnMouseUp", MouseUp)
    ns.AttachTip(handle, HANDLE_TIP)
    home.handle = handle
    el.home = home
    return home
end

-- On the band over its piece of the section (the band draws the art), or alone at its place in its own cut.
local function Place(el, plan, level)
    local pos = not Hidden(el) and ns.db[el.posKey] or nil
    if pos ~= nil and not ns.ValidPlace(pos) then
        ns.db[el.posKey], pos = nil, nil
    end
    local x, w = OnBand(el, plan)
    if (not pos and not x) or (el == KEYRING and not KeyRingButton) then
        if el.home then el.home:Hide() end
        return false
    end
    local home = Home(el)
    ns.SetLevelIf(home, math.max(0, level - 1))
    local left   -- the sheet's u at the home's left edge
    if pos then
        left = el.u0 - el.cap
        home:SetSize(el.cap + el.u1 - el.u0, BAND_H)
        if not el.moving then ns.SetPointOnce(home, pos.point, UIParent, pos.relPoint, pos.x, pos.y) end
        RUN[1], RUN[2], RUN[3], RUN[4] = el.u0 / 256, el.u1 / 256, SHEET.band[1], SHEET.band[2]
        ns.Dress(home.art, SHEET.key, BAND_RUN, home, el.cap, 0, el.u1 - el.u0, BAND_H, RUN)
        if home.cap then
            RUN[1], RUN[2] = el.u1 / 256, (el.u1 - el.cap) / 256
            ns.Dress(home.cap, SHEET.key, BAND_RUN, home, 0, 0, el.cap, BAND_H, RUN)
        end
    else
        left = plan.tailU0 + x - plan.tailStart
        home:SetSize(w, BAND_H)
        if not ns.IsAt(home, "BOTTOMLEFT", B.art, "BOTTOMLEFT", x, 0) then
            ns.SetPointOnce(home, "BOTTOMLEFT", B.art, "BOTTOMLEFT", x, 0)
        end
        home.art:Hide()
        if home.cap then home.cap:Hide() end
    end
    if not home:IsShown() then home:Show() end
    if el == LATENCY then
        -- On the band the band's own tube shows (BandLatency).
        B.PlaceTube(home.tube, home, pos and (B.TAIL_WINDOW - left) or nil)
    else
        local keyRing = KeyRingButton
        Seat(keyRing, 1, B.KEYRING_W, B.KEYRING_H, level)
        keyRing:SetPoint("CENTER", home, "BOTTOMLEFT", B.TAIL_SLOT - left + 0.5, KEY_Y)
        ns.SkinKeyRing(keyRing)
    end
    return true
end

-- Every bag layout, after the row (which takes the key ring only when it has no place here).
local watched = false
function B.LaySection(level)
    if not ns.db then return end
    local plan = CurrentPlan()
    if KeyRingButton and not watched then
        watched = true
        ns.Sched.OnVisible(KeyRingButton, "band.keyRingSeen", KeyRingSeen)
        ns.Sched.Attach(KeyRingButton, { name = "band.keyRingOff", every = 0.1, fn = HideAgain })
    end
    Place(LATENCY, plan, level)
    local placed = Place(KEYRING, plan, level)
    KeyRingShown(not Hidden(KEYRING) and placed)
end

-- Our edit mode boxes (micro menu, latency bar, key ring) up while edit mode is open, their dialogs shut after (BandWatch).
-- A group's level moves with its buttons' and takes the box along: set again as it shows.
local function ShowHandle(home, want)
    local handle = home and home.handle
    if not handle or handle:IsShown() == want then return end
    if want then handle:SetFrameLevel(1010) end
    handle:SetShown(want)
end

function B.ShowEditHandles(art, editing)
    local micro = art and art.microHome
    ShowHandle(micro, editing)
    for _, el in ipairs(ELEMENTS) do
        if el.home then ShowHandle(el.home, editing and el.home:IsShown()) end
    end
    if editing then return end
    if art and art.microDialog and art.microDialog:IsShown() then art.microDialog:Hide() end
    if dialog and dialog:IsShown() then dialog:Hide() end
end
