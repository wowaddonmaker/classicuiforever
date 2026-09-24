local _, ns = ...

-- 1.x slot art on every action button, watched against the client's repaints, handed back on restore.

local BAR_NAMES = { "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7" }
local BASE = 36 -- 1.x button size the classic art was drawn around
local PITCH = 42 -- 1.x button step: 36 and a 6 px gap
local CLIENT_PAD = 2 -- the client's least Icon Padding (ActionBar.lua minButtonPadding)
local NORMAL_CROP = { 0.1875, 0.796875, 0.1875, 0.796875 }
local NORMAL_PUSHED = { "Normal", "Pushed" }
local HIGHLIGHT_CHECKED = { "Highlight", "Checked" }
local active = false

local function ButtonsOf(bar)
    if bar.actionButtons then return bar.actionButtons end
    local name = bar:GetName()
    local prefix = (name == "MainActionBar" or name == "MainMenuBar") and "ActionButton" or name .. "Button"
    local list = {}
    for i = 1, 12 do
        list[i] = _G[prefix .. i]
    end
    return list
end

-- Whether the band lays the buttons out at the 1.x step (all bars while it is on), not the client.
local function BandLaid()
    return ns.ClassicBarActive() == true
end

-- Slot (icon) size in button units: the whole button on the band; off it (button + least padding) * 36/42, the 1.x ring gap.
local function Geometry(button, band)
    local w = button:GetWidth()
    if not w or w == 0 then w = 45 end
    local slot = band and w or (w + CLIENT_PAD) * BASE / PITCH
    return slot / BASE, slot, w
end

-- Icon, its mask and the game's slot art shrunk to the slot, centred; the button keeps its size, place and hit area.
-- Set once per size: the client never moves or sizes these.
local function FitSlot(button, slot, w)
    if button.fcuiFit == slot then return end
    local icon, mask, art = button.icon, button.IconMask, button.SlotArt
    if icon then
        ns.SetPointOnce(icon, "CENTER")
        icon:SetSize(slot, slot)
    end
    if mask then
        -- Sized by its atlas, it can read 0 before the first draw: fall back to the atlas, cache only a real size.
        if not button.fcuiMaskW then
            local mw, mh = mask:GetSize()
            if not (mw and mw > 0 and mh and mh > 0) then
                local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-ActionBar-IconFrame-Mask")
                if info then mw, mh = info.width, info.height end
            end
            if mw and mw > 0 and mh and mh > 0 then button.fcuiMaskW, button.fcuiMaskH = mw, mh end
        end
        local mw, mh = button.fcuiMaskW, button.fcuiMaskH
        if mw and mw > 0 and mh and mh > 0 then mask:SetSize(mw * slot / w, mh * slot / w) end
    end
    if art then
        ns.SetPointOnce(art, "CENTER")
        art:SetSize(slot, slot)
    end
    button.fcuiFit = slot
end

-- Back to the template: icon and slot art fill the button, the mask at its own size.
local function UnfitSlot(button)
    if not button.fcuiFit then return end
    button.fcuiFit = nil
    local icon, mask, art = button.icon, button.IconMask, button.SlotArt
    if icon then
        icon:ClearAllPoints()
        icon:SetAllPoints()
    end
    local mw, mh = button.fcuiMaskW, button.fcuiMaskH
    if mask and mw and mw > 0 and mh and mh > 0 then mask:SetSize(mw, mh) end
    if art then
        art:ClearAllPoints()
        art:SetAllPoints()
    end
end

-- The 1.x look as Classic Era draws it: open socket behind every button at 40%, bevelled ring over it at 50%;
-- recessed stone on the band rather than black squares.
local function SkinNormal(button, s)
    local tex = ns.SetButtonTex(button, "Normal", "slotNormal")
    if not tex then return end
    ns.SetPointOnce(tex, "CENTER")
    tex:SetTexCoord(NORMAL_CROP[1], NORMAL_CROP[2], NORMAL_CROP[3], NORMAL_CROP[4])
    tex:SetSize(40 * s, 40 * s)
    tex:SetDrawLayer("OVERLAY")
    tex:SetAlpha(0.5)
    local socket = button.SlotBackground
    if socket then
        ns.SetTex(socket, "slotEmpty")
        socket:SetTexCoord(0, 1, 0, 1)
        ns.SetPointOnce(socket, "CENTER")
        socket:SetSize(66 * s, 66 * s)
        socket:SetAlpha(0.4)
        -- Explicitly under the icon: the client keeps socket and icon on one layer and sublevel, where draw order
        -- isn't promised, and the socket randomly came out on top (a dimmed icon).
        socket:SetDrawLayer("BACKGROUND", -1)
        socket:Show()
    end
end

-- The clocks the client hangs off the icon, and their inset in its own art.
local COOLDOWNS = { "cooldown", "lossOfControlCooldown", "chargeCooldown" }
local COOLDOWN_INSET = 3

local function Centered(tex, size)
    ns.SetPointOnce(tex, "CENTER")
    tex:SetSize(size, size)
    tex:SetTexCoord(0, 1, 0, 1)
end

-- Whether a button is Action Bar 1's, by name (cached: a frame's name never changes).
local onBarOne = setmetatable({}, { __mode = "k" })
local function OnBarOne(button)
    local known = onBarOne[button]
    if known == nil then
        local name = button:GetName()
        known = name ~= nil and name:match("^ActionButton%d+$") ~= nil
        onBarOne[button] = known
    end
    return known
end

-- Band, classic bar setting and theme, read once per walk and per Apply; a button skinned for the other band layout is refitted.
local walkBand, walkKeepArt, walkBronze = false, false, false
local function ReadWalk()
    walkBand = BandLaid()
    walkKeepArt = ns.db ~= nil and ns.db.classicBar == false
    walkBronze = ns.ThemeLook() == "bronze"
end

-- A toggle in a fight holds its Apply until combat ends; the walk still follows it now.
local function SettingsMoved()
    return (ns.db ~= nil and ns.db.classicBar == false) ~= walkKeepArt or (ns.ThemeLook() == "bronze") ~= walkBronze
end

-- Classic bar off: Action Bar 1 keeps the game's slot art (faded it left bare slots; the game hides our socket there).
-- SlotArt is read each time: the client toggles it on every art repaint.
local function KeepsSlotArt(button)
    if not walkKeepArt then return false end
    local art = button.SlotArt
    if not art or not art:IsShown() then return false end
    return OnBarOne(button)
end

-- Forever's thin bronze frame round an ability icon with the bronze theme: over the grey bevel every icon carries
-- (a square icon shows it whole), under the slot ring, only where the slot holds something.
local function IconRim(button)
    local icon = button and button.icon
    if not icon then return end
    local rim = button.fcuiIconRim
    local want = active and walkBronze and icon:IsShown() and icon:GetTexture() ~= nil
    if not rim then
        if not want then return end
        rim = button:CreateTexture(nil, "ARTWORK", nil, 7)
        ns.SetTex(rim, "iconFrame")
        rim:SetAllPoints(icon)
        ns.BronzeTint(rim, ns.BRONZE_SOFT)
        button.fcuiIconRim = rim
    end
    ns.SetShownIf(rim, want)
end

-- The client's repaint of an emptied slot never hides its new-spell frame (ActionButton.lua Update): a lit one stays lit.
local function NewSpellFrameOff(button)
    local tex, icon = button and button.NewActionTexture, button and button.icon
    if tex and icon and tex:IsShown() and not icon:IsShown() then tex:Hide() end
end

local function Skin(button)
    if not button then return end
    local band = walkBand
    local s, slot, w = Geometry(button, band)
    button.fcuiBand = band
    if not band then
        FitSlot(button, slot, w)
    else
        UnfitSlot(button)
    end
    if button.SlotArt then
        button.SlotArt:SetAlpha(KeepsSlotArt(button) and 1 or 0)
        -- Under the icon, like the socket: the game's own bar (classic bar off) drew slot art over spells on some buttons.
        button.SlotArt:SetDrawLayer("BACKGROUND", -1)
    end
    SkinNormal(button, s)
    local pushed = ns.SetButtonTex(button, "Pushed", "slotPushed")
    if pushed then
        Centered(pushed, slot)
        pushed:SetDrawLayer("OVERLAY")
    end
    local hl = ns.SetButtonTex(button, "Highlight", "highlight")
    if hl then
        Centered(hl, slot)
        hl:SetBlendMode("ADD")
    end
    local ck = ns.SetButtonTex(button, "Checked", "checked")
    if ck then
        Centered(ck, slot)
        ck:SetBlendMode("ADD")
    end
    if button.Flash then
        ns.SetTex(button.Flash, "slotFlash")
        Centered(button.Flash, slot)
    end
    if button.Border then
        ns.SetTex(button.Border, "equippedBorder")
        Centered(button.Border, 62 * s)
        button.Border:SetBlendMode("ADD")
    end
    -- Cooldown clock over the whole icon: the client insets it 3 px (right for its rounded icons), and over a square one
    -- the rim stayed lit for the whole GCD.
    if button.icon then
        for _, key in ipairs(COOLDOWNS) do
            local clock = button[key]
            if clock and clock.SetAllPoints then
                clock:ClearAllPoints()
                clock:SetAllPoints(button.icon)
            end
        end
    end
    if button.icon and button.IconMask and button.icon.RemoveMaskTexture then
        if ns.db.squareIcons and not button.fcuiMaskRemoved then
            button.icon:RemoveMaskTexture(button.IconMask)
            button.fcuiMaskRemoved = true
        elseif not ns.db.squareIcons and button.fcuiMaskRemoved then
            button.icon:AddMaskTexture(button.IconMask)
            button.fcuiMaskRemoved = nil
        end
    end
    IconRim(button)
end

local function ToCorner(tex)
    tex:SetTexCoord(0, 1, 0, 1)
    ns.SetPointOnce(tex, "TOPLEFT")
end

local function ToMouseover(tex)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
    ns.SetPointOnce(tex, "TOPLEFT")
    tex:SetSize(46, 45)
end

local function Unskin(button)
    if not button then return end
    if button.fcuiIconRim then button.fcuiIconRim:Hide() end
    UnfitSlot(button)
    button.fcuiBand = nil
    if button.SlotArt then
        button.SlotArt:SetAlpha(1)
        button.SlotArt:SetDrawLayer("BACKGROUND", 0)
    end
    if button.SlotBackground then
        button.SlotBackground:SetAlpha(1)
        button.SlotBackground:SetDrawLayer("BACKGROUND", 0)
        button.SlotBackground:SetTexCoord(0, 1, 0, 1)
        button.SlotBackground:SetAtlas("UI-HUD-ActionBar-IconFrame-Background")
        button.SlotBackground:ClearAllPoints()
        button.SlotBackground:SetAllPoints(button)
    end
    if button.fcuiMaskRemoved then
        button.icon:AddMaskTexture(button.IconMask)
        button.fcuiMaskRemoved = nil
    end
    if button.icon then
        for _, key in ipairs(COOLDOWNS) do
            local clock = button[key]
            if clock and clock.SetPoint then
                clock:ClearAllPoints()
                clock:SetPoint("TOPLEFT", button.icon, "TOPLEFT", COOLDOWN_INSET, -COOLDOWN_INSET)
                clock:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", -COOLDOWN_INSET, COOLDOWN_INSET)
            end
        end
    end
    ns.EachState(button, NORMAL_PUSHED, ToCorner)
    if button.UpdateButtonArt then button:UpdateButtonArt() end
    ns.EachState(button, HIGHLIGHT_CHECKED, ToMouseover)
    if button.Flash then
        button.Flash:SetTexCoord(0, 1, 0, 1)
        button.Flash:SetAtlas("UI-HUD-ActionBar-IconFrame-Flash", true)
        ns.SetPointOnce(button.Flash, "TOPLEFT")
    end
    if button.Border then
        button.Border:SetTexCoord(0, 1, 0, 1)
        button.Border:SetAtlas("UI-HUD-ActionBar-IconFrame-Border", true)
        button.Border:SetBlendMode("BLEND")
        ns.SetPointOnce(button.Border, "TOPLEFT")
    end
end

-- One flat button list from the bars, rebuilt only when a bar name leads to another frame or button list.
-- The client fills actionButtons once at load (ActionBar.lua 7 and 41); a button under two bar names is listed once.
-- A bar without actionButtons is looked up by name each walk.
local BAR_COUNT = #BAR_NAMES
local flat, flatCount = {}, 0
local seenBar, seenList, seenCount = {}, {}, {}
local byName = false
local met = {}

local function Stale()
    if byName then return true end
    for i = 1, BAR_COUNT do
        local bar = _G[BAR_NAMES[i]]
        if (bar or false) ~= seenBar[i] then return true end
        if bar then
            local list = bar.actionButtons
            if list ~= seenList[i] then return true end
            local n = seenCount[i]
            if list[n + 1] ~= nil or (n > 0 and list[n] == nil) then return true end
        end
    end
    return false
end

-- Stale until complete and built from scratch: a rebuild cut short by an error leaves no button marked met, so the next walk redoes it.
local function Rebuild()
    wipe(met)
    byName = true
    local count, anyByName = 0, false
    for i = 1, BAR_COUNT do
        local bar = _G[BAR_NAMES[i]]
        seenBar[i], seenList[i], seenCount[i] = bar or false, nil, 0
        if bar then
            if bar.actionButtons then seenList[i] = bar.actionButtons else anyByName = true end
            local n = 0
            for _, button in ipairs(ButtonsOf(bar)) do
                n = n + 1
                if not met[button] then
                    met[button] = true
                    count = count + 1
                    flat[count] = button
                end
            end
            seenCount[i] = n
        end
    end
    for k = count + 1, flatCount do flat[k] = nil end
    flatCount = count
    byName = anyByName
    wipe(met)
end

local function ForEachButton(fn)
    if Stale() and not pcall(Rebuild) then
        -- A bar name leads to something no list can be built from: walk bar by bar as before, so the error is raised where it always was.
        for i = 1, BAR_COUNT do
            local bar = _G[BAR_NAMES[i]]
            if bar then
                for _, button in ipairs(ButtonsOf(bar)) do
                    fn(button)
                end
            end
        end
        return
    end
    for k = 1, flatCount do
        fn(flat[k])
    end
end

-- The client repaints button art in passes that also lay out party/raid frames and refuse them health values once our
-- code is inside: so watched, not hooked. Our skin leaves slot art hidden and the socket at 0.4; either changed means a repaint.
local function Repainted(button)
    if button.fcuiBand ~= walkBand then return true end
    local art = button.SlotArt
    -- The game's own bar keeps its slot art; its hidden socket there is the game's.
    if KeepsSlotArt(button) then return art:GetAlpha() < 0.99 end
    if art and art:GetAlpha() > 0.01 then return true end
    local socket = button.SlotBackground
    -- The client hides the socket outright on a bar with art on, leaving our fade. On the classic bar the band has the
    -- sockets; off it an empty slot was nothing at all.
    if socket and not socket:IsShown() and not walkBand then return true end
    if socket and math.abs(socket:GetAlpha() - 0.4) > 0.01 then return true end
    return false
end

-- Slot, page, bar and layout changes (a spec change re-applies the layout): the next frame checks every button.
-- Art is repainted only in UpdateButtonArt (load, layout applies, edit mode below).
local WATCH_EVENTS = { "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
    "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD",
    "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "EDIT_MODE_LAYOUTS_UPDATED", "PLAYER_SPECIALIZATION_CHANGED" }

local function RepaintVisit(button)
    if button and Repainted(button) then Skin(button) end
    -- A slot filled or emptied, or the theme changed.
    IconRim(button)
    NewSpellFrameOff(button)
end

-- Own frame, not a driver job, which would look a frame late and show the client's art that long.
-- No period: walks only on a kick or when the pre asks; asleep while the module is off.
local watch, watchJob
local function OnWatchEvent()
    watchJob:Kick()
end


local function RepaintPass()
    if not active then return end
    ReadWalk()
    ForEachButton(RepaintVisit)
end

-- Edit mode repaints slot art with no event (UpdateButtonArt, MarkBarArtDirty): walked every frame while it is open, by our
-- child under its manager's Border (ignoreInLayout; runs only while shown), and on the frame it shuts, by a watch it arms.
local function EditWatch()
    local host = EditModeManagerFrame and EditModeManagerFrame.Border
    if not host then return end
    local shutJob = ns.Sched.OnFrame(CreateFrame("Frame"), { name = "buttons.editShut", every = 0, awake = false, fn = function(job)
        if ns.EditMode.Live() then return end
        job:Sleep()
        -- On the frame it shuts, as the old per-frame look did.
        if active then RepaintPass() end
    end })
    ns.Sched.Attach(host, { name = "buttons.editWalk", every = 0, fn = function()
        if not active then return end
        shutJob:Wake()
        RepaintPass()
    end })
end

local function StartWatch()
    if watch then return end
    watch = ns.EventFrame(WATCH_EVENTS, OnWatchEvent)
    -- Kick-only: off the frame loop at rest.
    watchJob = ns.Sched.OnFrame(watch, { name = "buttons.repaint", every = math.huge, fn = RepaintPass })
    EditWatch()
    -- A classic bar or theme toggle in a fight holds its Apply; the walk follows it now.
    ns.OnToggle(function() if active and SettingsMoved() then watchJob:Kick() end end)
end

-- Anything else that dresses action buttons walks them from here.
ns.ForEachActionButton = ForEachButton

-- The watch is awake exactly while active is set (made awake by the first StartWatch).
local function Apply()
    active = true
    if watchJob then watchJob:Wake() end
    ReadWalk()
    ForEachButton(Skin)
    StartWatch()
end

local function Restore()
    if not active then return end
    active = false
    if watchJob then watchJob:Sleep() end
    ForEachButton(Unskin)
end

ns.RegisterModule("buttons", { apply = Apply, restore = Restore })
