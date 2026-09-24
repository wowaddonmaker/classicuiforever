local _, ns = ...

-- Secure pads: an unseen secure button over one of ours presses a client opener for the player, so the window opens in its name.
-- The map pad clicks the zone name button over the minimap (a map opened from our click taints its pins for later fights).
-- Hangs from UIParent, placed by measure out of combat: a frame a secure frame anchors to is locked in combat.
local mapPads = {}
local MapPad

-- target: the button pressed instead of the zone name, a macro text, or a function giving the macro text now (nil: no pad).
-- when(): whether the pad is wanted now.
MapPad = function(button, strata, after, target, when)
    local zone = target or (MinimapCluster and MinimapCluster.ZoneTextButton)
    local macroFn = type(target) == "function" and target
    if not button or mapPads[button] or not zone then return end
    -- Secure frames cannot be made in combat.
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
    mapPad:SetScript("OnEnter", function()
        button:LockHighlight()
        local enter = button:GetScript("OnEnter")
        if enter then enter(button) end
    end)
    mapPad:SetScript("OnLeave", function()
        button:UnlockHighlight()
        GameTooltip:Hide()
    end)
    -- The button's own click is never reached under the pad; it stays for clients without the zone button.
    local watch = CreateFrame("Frame")
    -- A window's pad (one with after) hides as combat starts: if the window shut mid-fight the
    -- pad would stay, unseen, opening the map on world clicks. The micro button keeps its pad.
    if after then
        watch:RegisterEvent("PLAYER_REGEN_DISABLED")
        watch:SetScript("OnEvent", function()
            if mapPad:IsShown() then mapPad:Hide() end
        end)
    end
    function Place()
        if InCombatLockdown() then return end
        local mgr = EditModeManagerFrame
        local editing = mgr and mgr.IsEditModeActive and mgr:IsEditModeActive()
        local left, bottom = button:GetLeft(), button:GetBottom()
        local text = macroFn and macroFn()
        if not button:IsVisible() or editing or not left or not bottom or (when and not when()) or (macroFn and not text) then
            if mapPad:IsShown() then mapPad:Hide() end
            return
        end
        if text then ns.SetAttributeIf(mapPad, "macrotext", text) end
        -- The button's rectangle in UIParent units.
        local ratio = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local x, y, w, h = left * ratio, bottom * ratio, button:GetWidth() * ratio, button:GetHeight() * ratio
        if not mapPad:IsShown() or math.abs((mapPad.x or -1) - x) > 0.5 or math.abs((mapPad.y or -1) - y) > 0.5
            or math.abs((mapPad.w or -1) - w) > 0.5 or mapPad:GetFrameLevel() <= button:GetFrameLevel() then
            mapPad.x, mapPad.y, mapPad.w = x, y, w
            mapPad:ClearAllPoints()
            mapPad:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
            mapPad:SetSize(w, h)
            mapPad:SetFrameLevel(button:GetFrameLevel() + 5)
            mapPad:Show()
        end
    end
    -- Own watch frame, never the scheduler's driver: it must run after our earlier-made movers
    -- (band placer, window watch) so a button moved this frame is followed this frame.
    ns.Sched.OnFrame(watch, { name = "pads", every = 0.2, fn = Place })
end
ns.MapPad = MapPad
