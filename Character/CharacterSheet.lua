local _, ns = ...

-- 1.x character sheet over the client's frame; the client's slots and model keep their logic.
-- Forever: stats pane kept shut, mode tab column unseen, own level line and bottom tabs.
-- Loads last of the sheet files: the module registers after the unlearn popup exists.

local T = ns.sheet
local Take, Own, Fade, TakeFaces = T.Take, T.Own, T.Fade, T.TakeFaces
local EMPTY = ns.EMPTY

local SLOT_GAP = 4
local LEFT_SLOTS = { "CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot", "CharacterBackSlot",
    "CharacterChestSlot", "CharacterShirtSlot", "CharacterTabardSlot", "CharacterWristSlot" }
local RIGHT_SLOTS = { "CharacterHandsSlot", "CharacterWaistSlot", "CharacterLegsSlot", "CharacterFeetSlot",
    "CharacterFinger0Slot", "CharacterFinger1Slot", "CharacterTrinket0Slot", "CharacterTrinket1Slot" }
local WEAPON_SLOTS = { "CharacterMainHandSlot", "CharacterSecondaryHandSlot", "CharacterRangedSlot" }
local DOLL_BG = { "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft", "BackgroundBotRight", "BackgroundOverlay" }
local SIDE_PIECES = { "CharacterStatsPane", "CharacterStatsPaneScrollBox", "PaperDollSidebarTabs", "PaperDollLevelInfo" }

-- Short labels so six tabs fit the 384px window.
local TAB_LABELS = {
    PaperDollFrame = CHARACTER or "Character", ReputationFrame = REPUTATION or "Reputation",
    TokenFrame = CURRENCY or "Currency", PVPRankFrame = "PvP", SkillsFrame = SKILLS or "Skills",
    StatisticsFrame = "Stats",
}

-- "Level 20 Gnome Mage", gold, under the name as 1.x wrote it.
local function LevelLine()
    local level = UnitLevel("player")
    if ns.IsSecret(level) then level = "" end
    local race = UnitRace("player") or ""
    local class = UnitClass("player") or ""
    return string.format("%s %s %s %s", LEVEL or "Level", tostring(level), race, class)
end

---------------------------------------------------------------- the tabs

-- 1.x tab: caps and a stretched middle (32 tall inactive, 35 active); glow reuses them.
local TAB_MAX_WIDTH = 106
local CHAR_TAB_ON = { own = "ct", layer = "BACKGROUND", key = "tabActive", cap = 20, height = 35,
    coords = { { 0, 0.15625, 0, 0.546875 }, { 0.15625, 0.84375, 0, 0.546875 }, { 0.84375, 1, 0, 0.546875 } } }
local CHAR_TAB_OFF = { own = "ct", layer = "BACKGROUND", key = "tabInactive", cap = 20, height = 32,
    coords = { { 0, 0.15625, 0, 1 }, { 0.15625, 0.84375, 0, 1 }, { 0.84375, 1, 0, 1 } } }
local GLOW_KEYS = { "Left", "Middle", "Right" }

local function TabPieces(tab, selected)
    local spec = selected and CHAR_TAB_ON or CHAR_TAB_OFF
    tab.left, tab.middle, tab.right = ns.ThreeSlice(tab, nil, spec)
    local c = spec.coords
    ns.Dress(tab.glowLeft, spec.key, nil, nil, nil, nil, nil, nil, c[1])
    ns.Dress(tab.glowMiddle, spec.key, nil, nil, nil, nil, nil, nil, c[2])
    ns.Dress(tab.glowRight, spec.key, nil, nil, nil, nil, nil, nil, c[3])
end

local function SetLabel(tab, text)
    tab.text:SetWidth(0)
    tab.text:SetText(text)
    local width = math.min(TAB_MAX_WIDTH, math.ceil(tab.text:GetStringWidth()) + 30)
    tab:SetWidth(width)
    tab.text:SetWidth(width - 20)
end

local function SetSelected(tab, selected)
    TabPieces(tab, selected)
    tab.text:SetFontObject(selected and "GameFontHighlightSmall" or "GameFontNormalSmall")
end

local function ClassicTab(parent, index)
    local tab = CreateFrame("Button", "ForeverClassicUICharacterTab" .. index, parent)
    tab:SetHeight(32)
    tab.left, tab.middle, tab.right = ns.ThreeSlice(tab, nil, CHAR_TAB_OFF)
    tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.text:SetPoint("CENTER", tab, "CENTER", 0, -3)
    tab.text:SetWordWrap(false)
    tab.text:SetJustifyH("CENTER")
    for _, key in ipairs(GLOW_KEYS) do
        local glow = tab:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints(tab[key:lower()])
        glow:SetBlendMode("ADD")
        glow:SetAlpha(0.35)
        tab["glow" .. key] = glow
    end
    tab.SetLabel, tab.SetSelected = SetLabel, SetSelected
    TabPieces(tab, false)
    return tab
end

-- Keeps the client's tab over our drawn one; the client re-lays its column, so rechecked while up.
local function OverTab(tab)
    local mode = tab and tab.mode
    if not mode or not mode.SetAllPoints then return end
    Take(mode, "points", "level", "hit", "mouse")
    local _, relativeTo = mode:GetPoint(1)
    if relativeTo ~= tab or mode:GetNumPoints() ~= 2 then
        mode:ClearAllPoints()
        mode:SetAllPoints(tab)
    end
    if mode:GetFrameLevel() <= tab:GetFrameLevel() then mode:SetFrameLevel(tab:GetFrameLevel() + 2) end
    if mode.SetHitRectInsets then
        local l, r, t, b = mode:GetHitRectInsets()
        if ns.AnySecret(l, r, t, b) or l ~= 0 or r ~= 0 or t ~= 0 or b ~= 0 then mode:SetHitRectInsets(0, 0, 0, 0) end
    end
    if not mode:IsMouseEnabled() then mode:EnableMouse(true) end
end

local function PlaceTab(tab, prev, strip)
    tab:ClearAllPoints()
    if prev then
        tab:SetPoint("LEFT", prev, "RIGHT", -15, 0)
    else
        tab:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 14, 46)
    end
    return tab
end

-- Picture only: our click opens the tab tainted and in combat it is refused its numbers.
-- The client's own tab lies over it, unseen.
local function NewTab(frame, i, mode)
    local tab = ClassicTab(frame, i)
    tab:EnableMouse(false)
    if mode.HookScript then
        -- Hide its tooltip only while the sheet is on, or the retail tabs lose their names.
        mode:HookScript("OnEnter", function(self)
            if not T.active then return end
            tab:LockHighlight()
            if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
        end)
        mode:HookScript("OnLeave", function() tab:UnlockHighlight() end)
    end
    return tab
end

------------------------------------------------------------- the window

-- Title and close button follow the side panel's title bar.
local function PlaceChrome()
    local frame = CharacterFrame
    local extra = ns.EquipmentPaneExtent and ns.EquipmentPaneExtent() or 0
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    if title then
        Take(title, "points")
        title:ClearAllPoints()
        title:SetPoint("CENTER", frame, "TOP", 6 + extra / 2, -24)
    end
    local close = frame.CloseButton
    if close then
        TakeFaces(close)
        close:ClearAllPoints()
        close:SetPoint("CENTER", frame, "TOPRIGHT", -44 + extra, -25)
    end
end

function ns.PlaceSheetChrome()
    if T.active and T.built then PlaceChrome() end
end

-- Old bronze slot rim, owned so it hides with the sheet.
local function Rim(slot)
    ns.BronzeRim(slot, nil, 3)
    local rim = Own(slot.fcuiBronzeRim)
    if rim then rim:Show() end
end

local function DressSlot(slot, name)
    Fade(_G[name .. "Frame"])
    Fade(slot.BorderFrame)
    Rim(slot)
end

-- Each slot off the previous (nextPoint, dx, dy); the first at relPoint, x, y on the doll.
local function ChainSlots(names, doll, relPoint, x, y, nextPoint, dx, dy)
    local prev
    for _, name in ipairs(names) do
        local slot = _G[name]
        if slot then
            Take(slot, "points")
            slot:ClearAllPoints()
            if prev then
                slot:SetPoint("TOPLEFT", prev, nextPoint, dx, dy)
            else
                slot:SetPoint("TOPLEFT", doll, relPoint, x, y)
            end
            DressSlot(slot, name)
            prev = slot
        end
    end
end

local function FadeGearArt(frame) ns.FadeAtlas(frame, "gearslot", false, Fade) end

local function HideControls(self)
    if T.active then self:Hide() end
end

-- Runs after the client sizes or retabs the frame. Nothing here is protected, so combat opens lay out too.
local function LayoutNow()
    if not T.active or not T.built then return end
    local frame, doll = CharacterFrame, PaperDollFrame
    Take(frame, "size")
    frame:SetSize(T.WIDTH, T.HEIGHT)
    -- Never a panel attribute: the panel manager reads it mid-pass and party/raid frames then
    -- error on secrets for the session. Windows opened beside it stand off by the old width.
    Fade(frame.NineSlice)
    Fade(frame.Bg)
    Fade(frame.TopTileStreaks)
    Fade(frame.Inset)
    Fade(frame.InsetRight)
    ns.EachKey(doll, DOLL_BG, Fade)
    ns.EachKey(CharacterModelScene, DOLL_BG, Fade)
    -- Client zoom/rotate controls give way to the old buttons; the client reshows them with the doll.
    local controls = CharacterModelScene and CharacterModelScene.ControlFrame
    if controls then
        Take(controls, "mouse")
        Fade(controls)
        controls:Hide()
        controls:EnableMouse(false)
        ns.HookScriptOnce(controls, "OnShow", HideControls)
    end
    -- Forever: every tab hangs off the left pane, wider than the old window; squeezed into
    -- the art, else the stats pane (off its right edge) lands outside the window.
    local pane = frame.LeftPaneHost
    if pane then
        Take(pane, "size", "points")
        pane:ClearAllPoints()
        pane:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -60)
        pane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 82)
        ns.EachTexture(pane, Fade)
    end
    -- Forever: stats pane, its toggle and the mode tab column; the tabs stay live under ours.
    Fade(frame.RightPaneHost)
    if frame.RightPaneToggleButton then
        Take(frame.RightPaneToggleButton, "mouse")
        Fade(frame.RightPaneToggleButton)
        frame.RightPaneToggleButton:EnableMouse(false)
    end
    if frame.ModeTabs then
        Take(frame.ModeTabs, "mouse")
        Fade(frame.ModeTabs)
        frame.ModeTabs:EnableMouse(false)
    end

    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    if portrait then
        Take(portrait, "size", "points")
        portrait:SetSize(62, 62)
        portrait:ClearAllPoints()
        portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 9, -6)
        ns.WatchPortrait(portrait)
        T.portrait = portrait
    end
    PlaceChrome()
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    if title then
        Take(title, "font")
        title:SetFontObject("GameFontNormal")
        -- On the title's frame, over the side panel's art.
        if not T.level then
            T.level = frame.TitleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        end
        T.level:ClearAllPoints()
        T.level:SetPoint("TOP", title, "BOTTOM", 0, -6)
        T.level:SetText(LevelLine())
        T.level:Show()
        if CharacterLevelText then Fade(CharacterLevelText) end
    end
    if frame.CloseButton then ns.SkinCloseButton(frame.CloseButton, true) end

    ChainSlots(LEFT_SLOTS, doll, "TOPLEFT", 21, -74, "BOTTOMLEFT", 0, -SLOT_GAP)
    ChainSlots(RIGHT_SLOTS, doll, "TOPLEFT", 306, -74, "BOTTOMLEFT", 0, -SLOT_GAP)
    ChainSlots(WEAPON_SLOTS, doll, "BOTTOMLEFT", 122, 127, "TOPRIGHT", 5, 0)
    local ammo = _G["CharacterAmmoSlot"]
    if ammo then
        DressSlot(ammo, "CharacterAmmoSlot")
        FadeGearArt(ammo)
        ns.EachChild(ammo, FadeGearArt)
    end

    if CharacterModelScene then
        Take(CharacterModelScene, "size", "points")
        CharacterModelScene:ClearAllPoints()
        CharacterModelScene:SetPoint("TOPLEFT", doll, "TOPLEFT", 65, -78)
        -- With stat panes on the model ends above them, or the figure's feet run under the dropdowns.
        CharacterModelScene:SetSize(233, (ns.db and ns.db.statPanes) and 213 or 224)
        T.FitModelCamera()
    end

    -- Bottom strip tabs: label width (capped), overlapping by 15, the first 14 in.
    local strip = T.general[3]
    local tabPrev
    if frame.ModeTabs and frame.ModeTabs.Tabs then
        T.tabs = T.tabs or {}
        for i, mode in ipairs(frame.ModeTabs.Tabs) do
            local tab = T.tabs[i]
            if not tab then
                tab = NewTab(frame, i, mode)
                T.tabs[i] = tab
            end
            tab.mode = mode
            tab.frameName = mode.frameName
            tab:SetLabel(TAB_LABELS[mode.frameName or ""] or mode.frameName or "")
            tab:SetSelected(mode.frameName == frame.activeSubframe)
            tab:SetShown(mode:IsShown())
            if mode:IsShown() then tabPrev = PlaceTab(tab, tabPrev, strip) end
            OverTab(tab)
        end
    else
        for i = 1, 6 do
            local tab = _G["CharacterFrameTab" .. i]
            if tab and tab:IsShown() then
                ns.SkinBottomTab(tab)
                tabPrev = PlaceTab(tab, tabPrev, strip)
            end
        end
    end
    -- One stat pane pass per layout: UpdateStats ran it unless the doll is hidden.
    local panesDone = T.UpdateStats()
    if ns.StatPanesHost then ns.StatPanesHost(doll) end
    if not panesDone and ns.UpdateStatPanes then ns.UpdateStatPanes() end
    -- Docked addons re-lay after us, synchronously.
    if frame:IsShown() then ns.SignalSheetLaid() end
end

-- The client resizes the pane behind us; a nested pass would chase itself, so one at a time.
local laying = false
local function Layout()
    if laying then return end
    laying = true
    ns.SafeCall(LayoutNow)
    laying = false
end

local function Build()
    T.built = true
    local frame, doll = CharacterFrame, PaperDollFrame
    T.BuildArt(frame, doll)
    T.BuildStats(doll)
    T.BuildRotate(doll)
    T.WatchStats(doll)
end

------------------------------------------------------------ the side pane

-- Alpha 0 and no mouse, never Hide: this runs inside client passes (RefreshRightPane) and a
-- Hide runs the pieces' close code tainted (health text then compares a secret).
-- A faction or skill click expands the pane for good.
local quieted = {}
local function QuietMouse(frame, depth)
    -- Skip panes kept live (equipment manager, skill detail).
    if frame.fcuiKept then return end
    if frame.IsMouseEnabled and frame:IsMouseEnabled() then
        frame.fcuiMouseWas = true
        pcall(frame.EnableMouse, frame, false)
    end
    -- The wheel too: the unseen stats list under the side panel took the set list's scrolls.
    if frame.IsMouseWheelEnabled and frame:IsMouseWheelEnabled() then
        frame.fcuiWheelWas = true
        pcall(frame.EnableMouseWheel, frame, false)
    end
    if depth < 10 then ns.EachChild(frame, QuietMouse, depth + 1) end
end
local function LoudMouse(frame, depth)
    if frame.fcuiMouseWas then
        frame.fcuiMouseWas = nil
        pcall(frame.EnableMouse, frame, true)
    end
    if frame.fcuiWheelWas then
        frame.fcuiWheelWas = nil
        pcall(frame.EnableMouseWheel, frame, true)
    end
    if depth < 10 then ns.EachChild(frame, LoudMouse, depth + 1) end
end
local function Quiet(frame)
    if not frame or not frame.SetAlpha then return end
    Take(frame, "alpha", "mouse")
    frame.fcuiKept = nil
    if frame:GetAlpha() > 0 then frame:SetAlpha(0) end
    if not frame.fcuiQuiet or (frame.IsMouseEnabled and frame:IsMouseEnabled()) then
        frame.fcuiQuiet = true
        quieted[frame] = true
        QuietMouse(frame, 0)
    end
end
-- The stats list builds lines a beat after quieting, each taking the mouse unseen.
local function Requiet()
    for frame in pairs(quieted) do
        if frame.fcuiQuiet and frame:IsShown() then QuietMouse(frame, 0) end
    end
end
local function Loud(frame)
    if not frame or not frame.fcuiQuiet then return end
    frame.fcuiQuiet = nil
    frame:SetAlpha(1)
    LoudMouse(frame, 0)
end
-- Held open: visible and clickable, skipped by QuietMouse until quieted again.
local function Keep(frame)
    if not frame or not frame.SetAlpha then return end
    if frame:GetAlpha() < 1 then
        Take(frame, "alpha")
        frame:SetAlpha(1)
    end
    if frame.fcuiKept and not frame.fcuiQuiet then return end
    frame.fcuiKept = true
    frame.fcuiQuiet = nil
    quieted[frame] = true   -- so GiveBack clears the mark
    -- A parent's walk may have taken its mouse without quieting it.
    LoudMouse(frame, 0)
end

-- For a pane another file holds open (the side panel's equipment tab).
function ns.KeepSidePane(frame)
    if T.active then Keep(frame) end
end

local function HideSidePane(frame)
    Quiet(frame.RightPaneHost)
    for _, pane in ipairs(frame.SidePanes or EMPTY) do
        -- The skill detail is ours while the skills tab is up.
        local keep = SkillsFrame and pane == SkillsFrame.SkillDetailFrame and SkillsFrame:IsShown()
        if keep then Keep(pane) else Quiet(pane) end
    end
    for _, name in ipairs(SIDE_PIECES) do
        Quiet(_G[name])
    end
    if type(GetPaperDollSideBarFrame) == "function" and type(PAPERDOLL_SIDEBARS) == "table" then
        for i = 1, #PAPERDOLL_SIDEBARS do
            local bar = GetPaperDollSideBarFrame(i)
            -- The equipment manager stays while the side panel holds it.
            local keep = bar == (PaperDollFrame and PaperDollFrame.EquipmentManagerPane) and ns.EquipmentPaneOpen and ns.EquipmentPaneOpen()
            if bar then
                if keep then Keep(bar) else Quiet(bar) end
            end
        end
    end
    -- The mode tab column stays up, unseen: its tabs take our clicks.
    if frame.ModeTabs then
        Take(frame.ModeTabs, "alpha", "shown")
        frame.ModeTabs:SetAlpha(0)
        if not frame.ModeTabs:IsShown() then frame.ModeTabs:Show() end
    end
    Quiet(frame.RightPaneToggleButton)
    -- Expanded, the window outgrows the sheet; the bare part must pass clicks through.
    if frame.SetHitRectInsets and frame.GetWidth then
        local spare = math.max(0, math.floor((frame:GetWidth() or 0) - 384))
        if frame.fcuiSpare ~= spare then
            Take(frame, "hit")
            frame.fcuiSpare = spare
            frame:SetHitRectInsets(0, spare, 0, 0)
        end
    end
end

-- The client reshows side pane pieces by too many paths to follow, so poll while up.
local function SideWatch(self, elapsed)
    if not T.active then return end
    self.since = (self.since or 0) + elapsed
    if self.since > 0.25 then
        self.since = 0
        Requiet()
    end
    local tabs = PaperDollSidebarTabs
    local host = CharacterFrame.RightPaneHost
    -- Only when visible: quieted pieces stay shown at alpha 0.
    if (tabs and tabs:IsShown() and tabs:GetAlpha() > 0) or (host and host:IsShown() and host:GetAlpha() > 0) then
        HideSidePane(CharacterFrame)
    end
    for _, tab in ipairs(T.tabs or EMPTY) do OverTab(tab) end
end

-- The stats pane follows the client's own collapsed flag: read here, never set.
local function GiveBack()
    if not T.dressed then return end
    T.dressed = nil
    local frame = CharacterFrame
    for pane in pairs(quieted) do
        pane.fcuiKept = nil
        pcall(Loud, pane)
    end
    wipe(quieted)
    T.PutAllBack(frame.CloseButton)
    frame.fcuiSpare = nil
    -- The client's width for the pane's current state.
    local wide, narrow, tall = _G["CHARACTER_FRAME_WIDTH"], _G["CHARACTER_FRAME_COLLAPSED_WIDTH"], _G["CHARACTER_FRAME_HEIGHT"]
    if wide and narrow and tall then frame:SetSize(frame.rightPaneCollapsed == true and narrow or wide, tall) end
    -- Re-lay the mode tabs as the client does, hidden ones skipped: one shown under the sheet has no spot.
    local tabs = frame.ModeTabs and frame.ModeTabs.Tabs
    if type(tabs) == "table" then
        local prev
        for _, tab in ipairs(tabs) do
            tab:ClearAllPoints()
            if tab:IsShown() then
                if prev then
                    tab:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -2)
                else
                    tab:SetPoint("TOPLEFT", frame.ModeTabs, "TOPLEFT")
                end
                prev = tab
            end
        end
    end
    T.ListsGiveBack()
    if T.descBar then
        T.KnobSeen(T.descBar, false)
        T.descBar.fcuiSkinned = nil
    end
    if T.portrait and ns.UnwatchPortrait then ns.UnwatchPortrait(T.portrait) end
    T.UnfitModelCamera()
    T.HideRepDetail()
    -- The player's pre-Apply stats pane cvar, back for the next login.
    local was = ns.db and ns.db.cvarWas and ns.db.cvarWas.characterFrameCollapsed
    if was ~= nil and C_CVar and C_CVar.SetCVar and not InCombatLockdown()
        and pcall(C_CVar.SetCVar, "characterFrameCollapsed", was) then
        ns.db.cvarWas.characterFrameCollapsed = nil
    end
end

local function LayoutIfActive() if T.active then Layout() end end
local function LayoutIfShown()
    if T.active and CharacterFrame and CharacterFrame:IsShown() then Layout() end
end
local function HideSidePaneIfActive(self) if T.active then HideSidePane(self) end end
local function LayoutNextFrame() if T.active then C_Timer.After(0, Layout) end end

local hooked = false
local function Apply()
    T.active = true
    if not CharacterFrame or not PaperDollFrame then ns.MissingPiece("CharacterFrame") return end
    if not T.built then Build() end
    T.dressed = true
    T.KeepShownLater()
    if not hooked then
        hooked = true
        ns.HookMethod(CharacterFrame, "UpdateSize", Layout)
        ns.HookMethod(CharacterFrame, "UpdateTabBounds", Layout)
        -- The client resizes the pane on its own (e.g. opening in combat); re-lay then and
        -- after combat, when the panel system re-places it.
        if PaperDollFrame then PaperDollFrame:HookScript("OnSizeChanged", LayoutIfActive) end
        local watcher = CreateFrame("Frame")
        watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        watcher:SetScript("OnEvent", LayoutIfShown)
        -- Put away the side panel's frames, never its state: writing the collapsed flag taints
        -- the client's show path (status text then compares a secret).
        ns.HookMethod(CharacterFrame, "Expand", HideSidePaneIfActive)
        T.HookListTabs()
        if CharacterFrame.RefreshRightPane then
            ns.HookMethod(CharacterFrame, "RefreshRightPane", HideSidePaneIfActive)
            ns.HookMethod(CharacterFrame, "ShowSubFrame", LayoutNextFrame)
        end
        if type(PaperDollFrame_UpdateSidebarTabs) == "function" then
            ns.HookGlobal("PaperDollFrame_UpdateSidebarTabs", function() if T.active then HideSidePane(CharacterFrame) end end)
        end
        CharacterFrame:HookScript("OnShow", LayoutIfActive)
        CreateFrame("Frame", nil, CharacterFrame):SetScript("OnUpdate", SideWatch)
        T.HookModel()
        ns.CharacterCameraInfo = T.CameraInfo
    end
    HideSidePane(CharacterFrame)
    if ns.EquipmentPaneApply then ns.EquipmentPaneApply() end
    -- The client loads the pane collapsed next login, from its cvar.
    ns.SetCVar("characterFrameCollapsed", "1")
    T.SkinListTabs()
    -- For addons that dock onto the character frame.
    ForeverClassicUI_CharacterSheetActive = true
    for _, tex in ipairs(T.general) do tex:Show() end
    if T.ringOver then
        T.ringOver:Show()
        if T.ringOver.doll then T.ringOver.doll:Show() end
    end
    for _, tex in ipairs(T.doll) do tex:Show() end
    -- The 2.x stat panes take this spot when toggled on.
    T.attrs:SetShown(not (ns.db and ns.db.statPanes))
    Layout()
end

local function Restore()
    T.active = false
    ForeverClassicUI_CharacterSheetActive = false
    if not T.built then return end
    if T.level then T.level:Hide() end
    for _, tab in ipairs(T.tabs or EMPTY) do tab:Hide() end
    for _, tex in ipairs(T.general) do tex:Hide() end
    if T.ringOver then
        T.ringOver:Hide()
        if T.ringOver.doll then T.ringOver.doll:Hide() end
    end
    for _, tex in ipairs(T.doll) do tex:Hide() end
    T.attrs:Hide()
    for _, row in ipairs(T.resistances) do row:Hide() end
    if T.rotateLeft then T.rotateLeft:Hide() end
    if T.rotateRight then T.rotateRight:Hide() end
    if ns.EquipmentPaneRestore then ns.EquipmentPaneRestore() end
    if PaperDollSidebarTabs then PaperDollSidebarTabs:SetAlpha(1) end
    GiveBack()
    ns.needsReload = true
end

ns.RegisterModule("characterSheet", { apply = Apply, restore = Restore })
