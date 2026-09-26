local _, ns = ...

-- Secure pads: an unseen secure button over one of ours presses a client opener for the player, so the window opens in its name.
-- The map pad clicks the zone name button over the minimap (a map opened from our click taints its pins for later fights).
-- Hangs from UIParent, placed by measure out of combat: a frame a secure frame anchors to is locked in combat.
local mapPads = {}
local MapPad
local Report = ns.Report

-- Every pad's Place in creation order; one pad's error leaves the others placed.
local places = {}
local function PlaceAll()
    for i = 1, #places do xpcall(places[i], Report) end
end

-- Placed the frame after anything that moves, shows, hides, relevels or unlocks a button: its move and visibility, edit
-- mode, toggles, a fight's end, scale, and presses (a window raises itself on one).
local function QueuePlace()
    ns.Sched.NextFrame("pads", PlaceAll)
end

local PLACE_EVENTS = { "PLAYER_REGEN_ENABLED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "PLAYER_ENTERING_WORLD",
    "GLOBAL_MOUSE_DOWN" }
local edgesMade = false
local function MakeEdges()
    if edgesMade then return end
    edgesMade = true
    ns.EventFrame(PLACE_EVENTS, QueuePlace)
    ns.OnEditMode(QueuePlace)
    ns.OnToggle(QueuePlace)
end

-- target: the button pressed instead of the zone name, a macro text, or a function giving the macro text now (nil: no pad).
-- when(): whether the pad is wanted now. editMode: wanted only while edit mode is open (else never then).
MapPad = function(button, strata, after, target, when, editMode)
    local zone = target or (MinimapCluster and MinimapCluster.ZoneTextButton)
    local macroFn = type(target) == "function" and target
    if not button or mapPads[button] or not zone then return end
    -- Secure frames cannot be made in combat.
    if InCombatLockdown() then
        ns.EventFrame("PLAYER_REGEN_ENABLED", function(self)
            self:UnregisterAllEvents()
            MapPad(button, strata, after, target, when, editMode)
        end)
        return
    end
    local mapPad = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
    mapPads[button] = mapPad
    if macroFn or type(target) == "string" then
        mapPad:SetAttribute("type", "macro")
        mapPad:SetAttribute("macrotext", macroFn and "" or target)
    else
        mapPad:SetAttribute("type", "click")
        mapPad:SetAttribute("clickbutton", zone)
    end
    -- Fire on release regardless of cast-on-key-down.
    mapPad:SetAttribute("useOnKeyDown", false)
    mapPad:RegisterForClicks("AnyUp", "AnyDown")
    mapPad:SetFrameStrata(strata or "MEDIUM")
    mapPad:Hide()
    -- No art: the button under it shows the press and glow.
    mapPad:SetScript("OnMouseDown", function() button:SetButtonState("PUSHED") end)
    mapPad:SetScript("OnMouseUp", function()
        if after or target or not (WorldMapFrame and WorldMapFrame:IsShown()) then button:SetButtonState("NORMAL") end
    end)
    local Place
    mapPad:SetScript("PostClick", function(_, _, down)
        if down then return end
        if after then after() end
        -- Now, not on the next tick: a quick second click would press a pad no longer wanted.
        Place()
    end)
    -- The button's own enter and leave run for it: the client hides a micro button's icon on enter and shows it again on
    -- leave, and shows its tooltip only while the button itself has the mouse (the pad has it), so that is ours.
    mapPad:SetScript("OnEnter", function()
        button:LockHighlight()
        local enter = button:GetScript("OnEnter")
        if enter then enter(button) end
        local text = button.tooltipText
        if GameTooltip:GetOwner() ~= button and type(text) == "string" then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(text, 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    mapPad:SetScript("OnLeave", function()
        button:UnlockHighlight()
        local leave = button:GetScript("OnLeave")
        if leave then leave(button) end
        GameTooltip:Hide()
    end)
    local function HidePad()
        if mapPad:IsShown() then mapPad:Hide() end
    end
    -- The button's own click is never reached under the pad; it stays for clients without the zone button.
    -- A window's pad (one with after) hides as combat starts: if the window shut mid-fight the
    -- pad would stay, unseen, opening the map on world clicks. The micro button keeps its pad.
    if after then ns.EventFrame("PLAYER_REGEN_DISABLED", HidePad) end
    function Place()
        if InCombatLockdown() then return end
        local left, bottom = button:GetLeft(), button:GetBottom()
        -- Tested before the macro text: a pad not wanted builds none.
        if not button:IsVisible() or ns.EditMode.Live() ~= (editMode == true) or not left or not bottom
            or (when and not when()) then
            HidePad()
            return
        end
        local text = macroFn and macroFn()
        if macroFn and not text then
            HidePad()
            return
        end
        if text then ns.SetAttributeIf(mapPad, "macrotext", text) end
        -- The button's rectangle in UIParent units.
        local ratio = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local x, y, w, h = left * ratio, bottom * ratio, button:GetWidth() * ratio, button:GetHeight() * ratio
        if not mapPad:IsShown() or math.abs((mapPad.x or -1) - x) > 0.5 or math.abs((mapPad.y or -1) - y) > 0.5
            or math.abs((mapPad.w or -1) - w) > 0.5 or mapPad:GetFrameLevel() <= button:GetFrameLevel() then
            mapPad.x, mapPad.y, mapPad.w = x, y, w
            ns.SetPointOnce(mapPad, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
            mapPad:SetSize(w, h)
            mapPad:SetFrameLevel(button:GetFrameLevel() + 5)
            mapPad:Show()
        end
    end
    places[#places + 1] = Place
    MakeEdges()
    ns.Sched.OnMove(button, QueuePlace)
    ns.Sched.OnVisible(button, "pads", QueuePlace)
    -- A window's pad or one with a live macro also looks each 0.2 s while its button shows: what it clicks can change unseen.
    if after or macroFn then ns.Sched.Attach(button, { name = "pads", every = 0.2, fn = Place }) end
    QueuePlace()
    return mapPad
end
ns.MapPad = MapPad

-- A named secure button a pad's macro runs with /click, pressing its clickbutton; sized and placed off screen: a button
-- with neither is never clicked. Made out of combat.
function ns.ClickProxy(name)
    local proxy = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    proxy:SetSize(1, 1)
    proxy:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
    proxy:EnableMouse(false)
    proxy:RegisterForClicks("AnyUp", "AnyDown")
    proxy:SetAttribute("useOnKeyDown", false)
    proxy:SetAttribute("type", "click")
    return proxy
end

-- Read by the dev addon's probes: the pad over one of our buttons.
function ns.PadOf(button) return mapPads[button] end
