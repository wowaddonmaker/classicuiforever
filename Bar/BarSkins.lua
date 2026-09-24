local _, ns = ...

-- Classic art on the client's bag and micro buttons: applied once, undone on demand, and reapplied after the
-- client's own state changes (SetNormal, SetPushed, UpdateTextures) via hooks installed once.

local STATES = ns.KEYS.STATES
local KEY_STATES = { "Normal", "Pushed", "Highlight" }
local StateTexture = ns.StateTexture
local Dress, FadeTextures = ns.Dress, ns.FadeTextures

-- Micro button -> classic atlas name; buttons with no 1.x counterpart keep their modern art.
local MICRO_ART = {
    CharacterMicroButton = "Character", SpellbookMicroButton = "Spellbook",
    TalentMicroButton = "Talents", PlayerSpellsMicroButton = "Talents", AchievementMicroButton = "Achievement",
    QuestLogMicroButton = "Quest", GuildMicroButton = "Socials", LFDMicroButton = "LFG",
    CollectionsMicroButton = "Mounts", EJMicroButton = "EJ", HelpMicroButton = "Help",
    StoreMicroButton = "BStore", MainMenuMicroButton = "MainMenu",
    -- The legacy adventure tree gets the old achievement sheet; professions and housing keep Forever's art (1.x had neither).
    -- The world map button is ours (BandMicro).
    LegacyMicroButton = "Achievement",
    ForeverClassicUIWorldMapMicroButton = "World",
}
-- The classic sheets are 32x64 with the button art in the lower 42 rows.
local MICRO_CROP = 22 / 64
local PORTRAIT_W, PORTRAIT_H, PORTRAIT_Y = 18, 25, -7
-- The 1.x menu button has no latency bar: faded while ours is on (the client only tints it).
local function ShowPerfBar(button, shown)
    local bar = button.MainMenuBarPerformanceBar
    if bar then bar:SetAlpha(shown and 1 or 0) end
end
local MICRO = { highlightSet = "tex", add = true, alpha = { Highlight = 1 }, coords = { 0, 1, MICRO_CROP, 1 }, fill = true }
-- MICRO for one state only: an atlas call overwrites just its own state.
local MICRO_ONE = {}
for _, key in ipairs(STATES) do
    local one = { states = { key } }
    for k, v in pairs(MICRO) do one[k] = v end
    MICRO_ONE[key] = one
end
local ATLAS_STATE = { SetNormalAtlas = "Normal", SetPushedAtlas = "Pushed", SetDisabledAtlas = "Disabled", SetHighlightAtlas = "Highlight" }
-- The guild button's tabard emblem came with Cataclysm; 1.x's Socials never drew one.
local EMBLEMS = { "Emblem", "HighlightEmblem" }
local CHANGED = { changed = true }

local micro = {}   -- button -> { art, name, upKey, downKey, disabledKey, active, hooked }
local microButtons, microStates = {}, {}   -- the same pairs in skin order, for the passes
local bags = {}    -- button -> { active, hooked, size, round, bagSlot, backpack, count }

-- A state texture back to the whole button, out of the theme's file swap (a repaint would put our sheet back).
local function ResetTex(tex, _, button)
    ns.UnswapBronze(tex)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:ClearAllPoints()
    tex:SetAllPoints(button)
end

---------------------------------------------------------------- micro buttons

local function WhiteTex(tex) ns.SetVertexColorIf(tex, 1, 1, 1) end

-- The tabard colour the client tints its guild sheet with, while it shows the emblem.
local function ClientTint(button)
    local emblem = button.Emblem
    if not (emblem and emblem:IsShown()) then return nil end
    local info = C_GuildInfo and C_GuildInfo.GetGuildTabardInfo and C_GuildInfo.GetGuildTabardInfo("player")
    return info and info.backgroundColor
end

local function ApplyMicroArt(button)
    local state = micro[button]
    if not state or not state.active then return end
    if state.art then
        -- The 1.x sheets are files the client still ships (and we bundle).
        ns.DressStates(button, state.upKey, state.downKey, state.disabledKey, "microHighlight", MICRO)
        -- The client tints the guild sheet with the tabard colour; the 1.x sheet is drawn untinted.
        ns.EachState(button, STATES, WhiteTex)
        ns.FadeKeys(button, EMBLEMS, 0, CHANGED)
        if button.Background then button.Background:Hide() end
        if button.PushedBackground then button.PushedBackground:Hide() end
    end
    if button.Portrait then
        if button.PortraitMask then button.PortraitMask:Hide() end
        if button.Shadow then button.Shadow:Hide() end
        if button.PushedShadow then button.PushedShadow:Hide() end
        local portrait = button.Portrait
        portrait:SetSize(PORTRAIT_W, PORTRAIT_H)
        ns.SetPointOnce(portrait, "TOP", button, "TOP", 0, PORTRAIT_Y)
        portrait:SetDrawLayer("OVERLAY", 0)
        if button:GetButtonState() == "PUSHED" then
            portrait:SetTexCoord(0.2666, 0.8666, 0, 0.8333)
            portrait:SetAlpha(0.5)
        else
            portrait:SetTexCoord(0.2, 0.8, 0.0666, 0.9)
            portrait:SetAlpha(1)
        end
    end
end

-- ApplyMicroArt's dress of one state; the client's own state setters and texture loads still get the whole redress.
local function RedressState(button, state, which)
    if not state.active or not state.art then return end
    local how = MICRO_ONE[which]
    if which == "Normal" then
        ns.DressStates(button, state.upKey, nil, nil, nil, how)
    elseif which == "Pushed" then
        ns.DressStates(button, nil, state.downKey, nil, nil, how)
    elseif which == "Disabled" then
        ns.DressStates(button, nil, nil, state.disabledKey, nil, how)
    else
        ns.DressStates(button, nil, nil, nil, "microHighlight", how)
    end
    local tex = StateTexture(button, which)
    if tex then WhiteTex(tex) end
end

local function HookMicro(button)
    local state = micro[button]
    if state.hooked then return end
    state.hooked = true
    for _, method in ipairs({ "SetNormal", "SetPushed", "UpdateMicroButton" }) do
        if type(rawget(button, method)) == "function" then
            hooksecurefunc(button, method, ApplyMicroArt)
        end
    end
    -- The client fades the normal texture on hover (its highlight is the whole button); the 1.x sheet stays put.
    button:HookScript("OnEnter", function(self)
        if state.active then
            local normal = self:GetNormalTexture()
            if normal then normal:SetAlpha(1) end
        end
    end)
    -- An atlas call (the game menu button's 1 s streaming update, texture kits) overwrites one state: redress that one.
    -- Our dress never calls Set*Atlas; the guard stops a loop.
    for _, method in ipairs({ "SetNormalAtlas", "SetPushedAtlas", "SetDisabledAtlas", "SetHighlightAtlas" }) do
        local which = ATLAS_STATE[method]
        hooksecurefunc(button, method, function(self)
            if not state.reapplying then
                state.reapplying = true
                RedressState(self, state, which)
                state.reapplying = false
            end
        end)
    end
end

function ns.SkinMicroButton(button)
    local state = micro[button]
    if not state then
        -- A button's name and art never change, so neither do its three sheets.
        local name = button:GetName()
        local art = MICRO_ART[name or ""]
        state = { art = art, name = name }
        if art then
            state.upKey = "micro" .. art .. "Up"
            state.downKey = "micro" .. art .. "Down"
            state.disabledKey = "micro" .. art .. "Disabled"
        end
        micro[button] = state
        microButtons[#microButtons + 1] = button
        microStates[#microStates + 1] = state
        HookMicro(button)
    end
    state.active = true
    ApplyMicroArt(button)
    ShowPerfBar(button, false)
end

function ns.UnskinMicroButton(button)
    local state = micro[button]
    if not state or not state.active then return end
    -- Off first: LoadMicroButtonTextures below would re-skin it through the hook.
    state.active = false
    ns.EachState(button, STATES, ResetTex, button)
    ShowPerfBar(button, true)
    if button.textureName and type(LoadMicroButtonTextures) == "function" then
        -- Ours cleared the tabard tint; the client's GuildColor sheet needs it back.
        LoadMicroButtonTextures(button, button.textureName, ClientTint(button))
    end
    ns.FadeKeys(button, EMBLEMS, 1, CHANGED)
    if button.PortraitMask then button.PortraitMask:Show() end
    if button.Shadow then button.Shadow:Show() end
    if button.Portrait then
        button.Portrait:SetTexCoord(0, 1, 0, 1)
        button.Portrait:SetDrawLayer("ARTWORK", 0)
    end
    -- The client's own state setter puts the background and portrait back.
    if button:GetButtonState() == "PUSHED" then
        if button.SetPushed then button:SetPushed() end
    elseif button.SetNormal then
        button:SetNormal()
    end
end

if type(LoadMicroButtonTextures) == "function" then
    hooksecurefunc("LoadMicroButtonTextures", function(button) ApplyMicroArt(button) end)
end

-- A micro button is down while one of its windows (client's or ours) is up, kept by polling with the plain widget call:
-- the client's own logic ignores our windows, can't be asked in a fight, and asking ran its code in our name.
local MICRO_WINDOWS = {
    CharacterMicroButton = { "CharacterFrame" },
    ProfessionMicroButton = { "ProfessionsFrame", "ProfessionsBookFrame" },
    SpellbookMicroButton = { "ForeverClassicUISpellBook" },
    TalentMicroButton = { "ClassicUIForeverTalents" },
    PlayerSpellsMicroButton = { "ClassicUIForeverTalents" },
    AchievementMicroButton = { "AchievementFrame" },
    QuestLogMicroButton = { "ForeverClassicUIQuestLog" },
    GuildMicroButton = { "FriendsFrame", "CommunitiesFrame", "GuildFrame" },
    LFDMicroButton = { "LFGParentFrame", "PVEFrame" },
    CollectionsMicroButton = { "CollectionsJournal" },
    EJMicroButton = { "EncounterJournal" },
    HelpMicroButton = { "HelpFrame" },
    -- Matches the client's rule, or the two fight over it while settings are up.
    MainMenuMicroButton = { "GameMenuFrame", "SettingsPanel", "KeyBindingFrame", "MacroFrame" },
    ForeverClassicUIWorldMapMicroButton = { "WorldMapFrame" },
}
-- The client's one window for spells and talents, where ours is not on.
local SHARED = { SpellbookMicroButton = true, TalentMicroButton = true, PlayerSpellsMicroButton = true }
-- MICRO_WINDOWS as frames, kept once made; one not made yet (load on demand, ours on first open) is looked up each pass.
local windowFrames = {}
for name in pairs(MICRO_WINDOWS) do windowFrames[name] = {} end

local function WindowUp(name)
    local names, frames = MICRO_WINDOWS[name], windowFrames[name]
    for i = 1, #names do
        local frame = frames[i]
        if not frame then
            frame = _G[names[i]]
            frames[i] = frame
        end
        -- The guild window held open unseen under our roster is not up.
        local ghost = ns.guildGhost and names[i] == "CommunitiesFrame"
        if frame and not ghost and frame.IsShown and frame:IsShown() and (frame:GetAlpha() or 1) > 0 then return true end
    end
    -- Where our window is off, the client's stands in: its spells/talents window, and the map (this client's quest log).
    local db = ns.db or ns.EMPTY
    if SHARED[name] then
        local ours
        if name == "SpellbookMicroButton" then ours = db.spellBook else ours = db.talents end
        local shared = _G["PlayerSpellsFrame"]
        if ours == false and shared and shared:IsShown() then
            -- Each button follows its own half, as the client's update does.
            local half = (name == "SpellbookMicroButton" and shared.SpellBookFrame)
                or (name == "TalentMicroButton" and shared.TalentsFrame) or nil
            if not half or half:IsShown() then return true end
        end
    elseif name == "QuestLogMicroButton" and db.questLog == false then
        local map = _G["WorldMapFrame"]
        if map and map:IsShown() then return true end
    end
    return false
end

-- A press to open holds its button down until the window shows: the talents window shows a frame after
-- the click in combat (C_Timer), and there the pass or the client's update lifted it.
local OPEN_GRACE = 0.25
local opening, openingWith, openUntil   -- button, mouse button, nil while held

local function SyncMicroButton(button, state)
    local name = state.name
    if state.active and name and MICRO_WINDOWS[name] and button.IsEnabled and button:IsEnabled() then
        local want = (button == opening or WindowUp(name)) and "PUSHED" or "NORMAL"
        if button:GetButtonState() ~= want then
            -- Not while pressed: the press is the button's own. Only checked when there is a state to set.
            local held = button.IsMouseOver and button:IsMouseOver() and IsMouseButtonDown and IsMouseButtonDown("LeftButton")
            if not held then button:SetButtonState(want, want == "PUSHED") end
        end
    end
end

local function SyncMicroButtons()
    for i = 1, #microButtons do SyncMicroButton(microButtons[i], microStates[i]) end
end

function ns.RefreshMicroButtons() SyncMicroButtons() end

-- Each watched window's buttons: MICRO_WINDOWS turned round, plus the client windows standing in where ours are off.
local WINDOW_BUTTONS = {}
local function AddWindow(window, button)
    local list = WINDOW_BUTTONS[window]
    if not list then
        list = {}
        WINDOW_BUTTONS[window] = list
    end
    list[#list + 1] = button
end
for button, names in pairs(MICRO_WINDOWS) do
    for i = 1, #names do AddWindow(names[i], button) end
end
for button in pairs(SHARED) do AddWindow("PlayerSpellsFrame", button) end
AddWindow("WorldMapFrame", "QuestLogMicroButton")

local function SyncNamed(names)
    for i = 1, #names do
        local button = _G[names[i]]
        local state = button and micro[button]
        if state then SyncMicroButton(button, state) end
    end
end

-- Windows seen up, each with its buttons; the hide watch runs only while one is in it.
local up = {}
local hideJob = ns.Sched.OnFrame(CreateFrame("Frame"), { name = "micro.hide", every = 0, awake = false, fn = function(job)
    local left = false
    for frame, names in pairs(up) do
        if frame:IsVisible() then
            left = true
        else
            up[frame] = nil
            SyncNamed(names)
        end
    end
    if not left then job:Sleep() end
end })

-- Our child under a window runs only while it is visible: keeps its buttons right every frame (the client's update lifts
-- ours and presses the quest button for the map) and hands the hide to the watch above.
local function WindowSeen(job)
    local frame, names = job.window, job.buttons
    if not up[frame] then
        up[frame] = names
        hideJob:Wake()
    end
    SyncNamed(names)
end

-- Windows not made yet (load on demand, ours on first open) are looked for again on loads, presses and our window
-- registrations; nothing polls.
local missing = true
local function AttachWindows()
    missing = false
    for window, names in pairs(WINDOW_BUTTONS) do
        local frame = _G[window]
        if type(frame) == "table" and frame.GetObjectType then
            local job, made = ns.Sched.Attach(frame, { name = "micro.window", every = 0, fn = WindowSeen })
            if made then job.window, job.buttons = frame, names end
        else
            missing = true
        end
    end
    return missing
end
local function FindWindows()
    if missing then AttachWindows() end
end
ns.MicroWindowsChanged = FindWindows
ns.EventFrame({ "ADDON_LOADED", "PLAYER_ENTERING_WORLD" }, FindWindows)

-- The micro button a press landed on; a secure pad over one takes the focus and keeps its own states.
local function PressedMicro()
    for i = 1, #microButtons do
        if microStates[i].active then
            local button = microButtons[i]
            local focus = button.IsMouseMotionFocus
            if focus then focus = focus(button) else focus = button:IsVisible() and button:IsMouseOver() end
            if focus then return button end
        end
    end
end

-- While an open is pending: re-press what anything lifted this frame, before it is drawn.
local function HoldOpening(job)
    local button = opening
    local state = button and micro[button]
    if not state or not state.active then
        opening = nil
        job:Sleep()
        return
    end
    local now = GetTime()
    -- Let go off the button: no click, nothing opens.
    if not openUntil and not IsMouseButtonDown(openingWith) then
        openUntil = button:IsMouseOver() and now + OPEN_GRACE or 0
    end
    if WindowUp(state.name) or (openUntil and now >= openUntil) then
        opening = nil
        job:Sleep()
        SyncMicroButton(button, state)
    elseif button:IsEnabled() and button:GetButtonState() ~= "PUSHED" then
        button:SetButtonState("PUSHED", true)
    end
end
-- Own frame, every frame, and only while a press waits for its window.
local openJob = ns.Sched.OnFrame(CreateFrame("Frame"), { name = "micro.opening", every = 0, awake = false, fn = HoldOpening })

-- Only a press to open: one on an up window's button is a close, released on the hide.
local function MouseDown(_, _, mouse)
    if missing then AttachWindows() end
    -- Quick keybind mode: the click only binds a key, nothing opens.
    if KeybindFrames_InQuickKeybindMode and KeybindFrames_InQuickKeybindMode() then return end
    local button = PressedMicro()
    local name = button and micro[button].name
    if name and MICRO_WINDOWS[name] and button:IsEnabled() and not WindowUp(name) then
        opening, openingWith, openUntil = button, mouse or "LeftButton", nil
        openJob:Wake()
    end
end
ns.EventFrame("GLOBAL_MOUSE_DOWN", MouseDown)
AttachWindows()

-- A micro button whose window is ours stays pressed while it shows: the client's update runs first and sees
-- its frame hidden, then this presses it.
local followed = {}
function ns.MicroButtonFollows(button, isShown)
    if not button or followed[button] then return end
    followed[button] = true
    if type(rawget(button, "UpdateMicroButton")) == "function" then
        hooksecurefunc(button, "UpdateMicroButton", function(self)
            if isShown() and self:IsEnabled() then
                if self.SetPushed then self:SetPushed() else self:SetButtonState("PUSHED", true) end
            end
        end)
    end
end

------------------------------------------------------------------ bag buttons

-- A round slot's ring in buttons: size, and overhang past the top left.
local ROUND_RING, ROUND_RING_OFFSET = 2.5, 0.26
-- Its hover glow: a minimap button is 32 against its 52 ring.
local ROUND_HOVER = ROUND_RING * 32 / 52

local FULL = { 0, 1, 0, 1 }
-- The quickslot ring isn't drawn: the band has a socket per bag, and the ring showed brown slivers between them that 1.x never had.
local BAG_NORMAL = { coords = FULL, point = "CENTER", y = -1, alpha = 0 }
-- Square art; a round slot shows none, as the old minimap buttons.
local BAG_PUSHED = { coords = FULL, fill = true, alpha = 1 }
local BAG_PUSHED_ROUND = { coords = FULL, fill = true, alpha = 0 }
local BAG_HL = { coords = FULL, fill = true, blend = "ADD", alpha = 1 }
-- The old minimap button's hover glow, from the ring's corner.
local BAG_HL_ROUND = { coords = FULL, point = "TOPLEFT", blend = "ADD", alpha = 1 }
local BAG_CHECKED = { coords = FULL, fill = true, blend = "ADD", alpha = 1 }
-- The minimap's small round ring: hole ~0.4 across, 0.3 in, so at 2.5 buttons hung a quarter outside the corner it lands round.
local BAG_RING = { coords = FULL, point = "TOPLEFT", alpha = 1, show = true }

local function ApplyBagArt(button)
    local state = bags[button]
    if not state or not state.active then return end
    local size = state.size
    local round = state.round
    Dress(StateTexture(button, "Normal"), "slotNormal", BAG_NORMAL, button, nil, nil, size * 50 / 30, size * 50 / 30)
    Dress(StateTexture(button, "Pushed"), "slotPushed", round and BAG_PUSHED_ROUND or BAG_PUSHED, button)
    local highlight = StateTexture(button, "Highlight")
    if round then
        local off = size * ROUND_RING_OFFSET
        Dress(highlight, "zoomHighlight", BAG_HL_ROUND, button, -off, off, size * ROUND_HOVER, size * ROUND_HOVER)
    else
        Dress(highlight, "highlight", BAG_HL, button)
    end
    Dress(button.SlotHighlightTexture, round and "checkedRound" or "checked", BAG_CHECKED, button)
    -- A round slot keeps the client's circle over its icon.
    if button.CircleMask then button.CircleMask:SetShown(round == true) end
    if button.IconBorder then
        button.IconBorder:ClearAllPoints()
        if round then
            local off = size * ROUND_RING_OFFSET
            Dress(button.IconBorder, "trackingBorder", BAG_RING, button, -off, off, size * ROUND_RING, size * ROUND_RING)
            -- A gold sheet: grey like the bags beside it, bronze with the theme.
            ns.BronzeTint(button.IconBorder, nil, true)
        else
            ns.SetTex(button.IconBorder, "iconFrame")
            -- Thin frame round a bag's picture, bronze with the theme, and Forever's frame over the picture's grey bevel.
            ns.BronzeTint(button.IconBorder)
            ns.BronzeRim(button)
            button.IconBorder:SetTexCoord(0, 1, 0, 1)
            button.IconBorder:SetSize(size, size)
            button.IconBorder:SetPoint("CENTER", button, "CENTER", 0, 0)
        end
        button.IconBorder:SetDrawLayer("OVERLAY")
    end
    if button.icon and not state.backpack then
        button.icon:SetTexCoord(0, 1, 0, 1)
    end
    -- An empty bag slot (the four and the reagent bag) shows the old dim bag.
    if state.bagSlot and button.icon and button.GetID then
        local empty = not GetInventoryItemTexture("player", button:GetID())
        if empty then button.icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag") end
        button.icon:SetDesaturated(empty)
        button.icon:SetAlpha(empty and 0.5 or 1)
        button.icon:SetTexCoord(0, 1, 0, 1)
        -- The round slot has no socket to show a bag and the client hides an empty slot's icon: show its own.
        if round then
            button.icon:SetAlpha(1)
            button.icon:SetDesaturated(false)
            button.icon:Show()
        end
    end
    if state.backpack and button.icon then
        ns.SetTex(button.icon, "backpackIcon")
        button.icon:SetTexCoord(0, 1, 0, 1)
    end
end

-- The client's backpack Count also takes the ammo count (inventory slot 0 on every BAG_UPDATE): faded, ours shows free slots.
local FREE_SLOTS = "(%s)"
local FREE_EVENTS = { "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD" }
local freeWatch, freeWatching

local function ShowFreeSlots(button, state)
    local calc = C_Container and C_Container.CalculateTotalNumberOfFreeBagSlots
    state.count:SetText(FREE_SLOTS:format(calc and calc() or 0))
    -- That same client update tints and greys the icon by the ammo's state.
    local icon = button.icon
    if icon then
        ns.SetVertexColorIf(icon, 1, 1, 1)
        if ns.Safe(icon:IsDesaturated(), true) then icon:SetDesaturated(false) end
    end
end

local function OnFreeSlotsEvent()
    for button, state in pairs(bags) do
        if state.backpack and state.active and state.count then ShowFreeSlots(button, state) end
    end
end

local function SkinFreeSlots(button, state)
    if not state.count then
        state.count = button:CreateFontString(nil, "ARTWORK", "NumberFontNormalSmall")
        state.count:SetPoint("BOTTOM", button, "BOTTOM", 0, 3)
    end
    state.count:Show()
    if button.Count then ns.SetAlphaIf(button.Count, 0) end
    if not freeWatch then
        freeWatch = ns.EventFrame(FREE_EVENTS, OnFreeSlotsEvent)
        freeWatching = true
    elseif not freeWatching then
        freeWatching = true
        ns.RegisterEvents(freeWatch, FREE_EVENTS)
    end
    ShowFreeSlots(button, state)
end

local function UnskinFreeSlots(button, state)
    if state.count then state.count:Hide() end
    if button.Count then ns.SetAlphaIf(button.Count, 1) end
    if freeWatch then freeWatch:UnregisterAllEvents() end
    freeWatching = false
end

local function HookBag(button)
    local state = bags[button]
    if state.hooked then return end
    state.hooked = true
    for _, method in ipairs({ "UpdateTextures", "SetItemButtonQuality" }) do
        if type(rawget(button, method)) == "function" then
            hooksecurefunc(button, method, ApplyBagArt)
        end
    end
end

-- Reagent bag and the four bag slots, identified as the button is dressed (identity never changes), not per repaint.
local function IsBagSlot(button)
    local bagSlot = button == CharacterReagentBag0Slot
    for i = 0, 3 do if button == _G["CharacterBag" .. i .. "Slot"] then bagSlot = true end end
    return bagSlot
end

function ns.SkinBagButton(button, size, isBackpack, round)
    local state = bags[button]
    if not state then
        state = { backpack = isBackpack }
        bags[button] = state
        HookBag(button)
    end
    state.bagSlot = IsBagSlot(button)
    state.size = size
    state.round = round and true or false
    local fresh = not state.active
    state.active = true
    ApplyBagArt(button)
    if fresh and state.backpack then SkinFreeSlots(button, state) end
end

function ns.UnskinBagButton(button)
    local state = bags[button]
    if not state or not state.active then return end
    state.active = false
    if button.CircleMask then button.CircleMask:Show() end
    if button.IconBorder then
        button.IconBorder:ClearAllPoints()
        button.IconBorder:SetAllPoints(button)
    end
    local pushed = StateTexture(button, "Pushed")
    if pushed then pushed:SetAlpha(1) end
    -- The client's routine puts its own atlases and icon back.
    if button.UpdateTextures then button:UpdateTextures() end
    if state.backpack then UnskinFreeSlots(button, state) end
end

--------------------------------------------------------------------- key ring

-- 1.x key ring: an 18x39 key from its own sheet. Without a key ring it goes on the reagent bag so the slot still opens
-- something. The client refreshes bag textures often; the hook reapplies it.
local keyrings = {}
local KEY_RING = { set = "tex", highlightSet = "tex", coords = { 0, 0.5625, 0, 0.609375 }, fill = true, alpha = 1, add = true,
    states = KEY_STATES }

local function ApplyKeyRingArt(button)
    local state = keyrings[button]
    if not state or not state.active then return end
    ns.DressStates(button, "keyRingUp", "keyRingDown", nil, "keyRingHighlight", KEY_RING)
    -- Only the three state textures stay seen.
    FadeTextures(button, 0, nil, StateTexture(button, "Normal"), StateTexture(button, "Pushed"), StateTexture(button, "Highlight"))
    if button.CircleMask then button.CircleMask:Hide() end
    if button.Count then button.Count:SetAlpha(0) end
end

function ns.SkinKeyRing(button)
    local state = keyrings[button]
    if not state then
        state = {}
        keyrings[button] = state
        if type(rawget(button, "UpdateTextures")) == "function" then
            hooksecurefunc(button, "UpdateTextures", ApplyKeyRingArt)
        end
    end
    state.active = true
    ApplyKeyRingArt(button)
end

function ns.UnskinKeyRing(button)
    local state = keyrings[button]
    if not state or not state.active then return end
    state.active = false
    ns.EachState(button, KEY_STATES, ResetTex, button)
    FadeTextures(button, 1)
    if button.Count then button.Count:SetAlpha(1) end
    if button.UpdateTextures then button:UpdateTextures() end
end
