local _, ns = ...

-- Classic art on the client's bag and micro buttons: applied once, undone on demand, and reapplied after the
-- client's own state changes (SetNormal, SetPushed, UpdateTextures) via hooks installed once.

local STATES = ns.KEYS.STATES
local KEY_STATES = { "Normal", "Pushed", "Highlight" }
local StateTexture = ns.StateTexture
local Dress, FadeTextures = ns.Dress, ns.FadeTextures

-- Micro button -> classic atlas name; buttons with no 1.x counterpart keep their modern art.
local MICRO_ART = {
    CharacterMicroButton = "Character", ProfessionMicroButton = "Abilities", SpellbookMicroButton = "Spellbook",
    TalentMicroButton = "Talents", PlayerSpellsMicroButton = "Talents", AchievementMicroButton = "Achievement",
    QuestLogMicroButton = "Quest", GuildMicroButton = "Socials", LFDMicroButton = "LFG",
    CollectionsMicroButton = "Mounts", EJMicroButton = "EJ", HelpMicroButton = "Help",
    StoreMicroButton = "BStore", MainMenuMicroButton = "MainMenu",
    -- The legacy adventure tree gets the old achievement sheet; housing keeps its modern art. The world map button is ours (BandMicro).
    LegacyMicroButton = "Achievement",
    ForeverClassicUIWorldMapMicroButton = "World",
}
-- The classic sheets are 32x64 with the button art in the lower 42 rows.
local MICRO_CROP = 22 / 64
local PORTRAIT_W, PORTRAIT_H, PORTRAIT_Y = 18, 25, -7
local MICRO = { highlightSet = "tex", add = true, alpha = { Highlight = 1 }, coords = { 0, 1, MICRO_CROP, 1 }, fill = true }

local micro = {}   -- button -> { art, upKey, downKey, disabledKey, active, hooked }
local bags = {}    -- button -> { active, hooked, size, round, bagSlot }

-- A state texture back to the whole button.
local function ResetTex(tex, _, button)
    tex:SetTexCoord(0, 1, 0, 1)
    tex:ClearAllPoints()
    tex:SetAllPoints(button)
end

---------------------------------------------------------------- micro buttons

local function ApplyMicroArt(button)
    local state = micro[button]
    if not state or not state.active then return end
    if state.art then
        -- The 1.x sheets are files the client still ships (and we bundle).
        ns.DressStates(button, state.upKey, state.downKey, state.disabledKey, "microHighlight", MICRO)
        if button.Background then button.Background:Hide() end
        if button.PushedBackground then button.PushedBackground:Hide() end
    end
    if button.Portrait then
        if button.PortraitMask then button.PortraitMask:Hide() end
        if button.Shadow then button.Shadow:Hide() end
        if button.PushedShadow then button.PushedShadow:Hide() end
        local portrait = button.Portrait
        portrait:ClearAllPoints()
        portrait:SetSize(PORTRAIT_W, PORTRAIT_H)
        portrait:SetPoint("TOP", button, "TOP", 0, PORTRAIT_Y)
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
    -- Some buttons swap atlases in their own update (latency colours, texture kits): reapply the 1.x art right after.
    -- ApplyMicroArt never calls Set*Atlas itself; the guard stops the loop.
    for _, method in ipairs({ "SetNormalAtlas", "SetPushedAtlas", "SetDisabledAtlas", "SetHighlightAtlas" }) do
        hooksecurefunc(button, method, function(self)
            if not state.reapplying then
                state.reapplying = true
                ApplyMicroArt(self)
                state.reapplying = false
            end
        end)
    end
end

function ns.SkinMicroButton(button)
    local state = micro[button]
    if not state then
        -- A button's art never changes, so neither do its three sheets.
        local art = MICRO_ART[button:GetName() or ""]
        state = { art = art }
        if art then
            state.upKey = "micro" .. art .. "Up"
            state.downKey = "micro" .. art .. "Down"
            state.disabledKey = "micro" .. art .. "Disabled"
        end
        micro[button] = state
        HookMicro(button)
    end
    state.active = true
    ApplyMicroArt(button)
end

function ns.UnskinMicroButton(button)
    local state = micro[button]
    if not state or not state.active then return end
    -- Off first: LoadMicroButtonTextures below would re-skin it through the hook.
    state.active = false
    ns.EachState(button, STATES, ResetTex, button)
    if button.textureName and type(LoadMicroButtonTextures) == "function" then
        LoadMicroButtonTextures(button, button.textureName)
    end
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

local function WindowUp(name)
    for _, frameName in ipairs(MICRO_WINDOWS[name]) do
        local frame = _G[frameName]
        -- The guild window held open unseen under our roster is not up.
        local ghost = ns.guildGhost and frameName == "CommunitiesFrame"
        if frame and not ghost and frame.IsShown and frame:IsShown() and (frame:GetAlpha() or 1) > 0 then return true end
    end
    -- Where our window is off, the client's stands in: its spells/talents window, and the map (this client's quest log).
    local db = ns.db or {}
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
    if state.active and button.IsEnabled and button:IsEnabled() then
        local name = button.GetName and button:GetName()
        if name and MICRO_WINDOWS[name] then
            local want = (button == opening or WindowUp(name)) and "PUSHED" or "NORMAL"
            if button:GetButtonState() ~= want then
                -- Not while pressed: the press is the button's own. Only checked when there is a state to set.
                local held = button.IsMouseOver and button:IsMouseOver() and IsMouseButtonDown and IsMouseButtonDown("LeftButton")
                if not held then button:SetButtonState(want, want == "PUSHED") end
            end
        end
    end
end

local function SyncMicroButtons()
    for button, state in pairs(micro) do SyncMicroButton(button, state) end
end

function ns.RefreshMicroButtons() SyncMicroButtons() end

-- Windows whose button the client's update sets wrong while up: it lifts it for frames absent here (ProfessionsBookFrame,
-- PVEFrame) or ours it doesn't know, and presses the quest button for the map. Entry: window, button, wrong state, and a
-- setting that makes the client right.
local CONTESTED = {
    { "ProfessionsFrame", "ProfessionMicroButton", "NORMAL", shown = false },
    { "LFGParentFrame", "LFDMicroButton", "NORMAL", shown = false },
    { "ClassicUIForeverTalents", "TalentMicroButton", "NORMAL", shown = false },
    { "WorldMapFrame", "QuestLogMicroButton", "PUSHED", "questLog", shown = false },
}
-- Every frame: fix a contested button and follow its window's show/hide that frame (the client doesn't release them all on close).
local function ContestedButtons()
    local db = ns.db
    for i = 1, #CONTESTED do
        local entry = CONTESTED[i]
        local frame = _G[entry[1]]
        local shown = (frame and frame:IsShown()) and true or false
        local edge = shown ~= entry.shown
        if edge or shown then
            entry.shown = shown
            local button = _G[entry[2]]
            local state = button and micro[button]
            local agreed = entry[4] and db and db[entry[4]] == false
            if state and not agreed and (edge or button:GetButtonState() == entry[3]) then
                SyncMicroButton(button, state)
            end
        end
    end
end

-- The micro button a press landed on; a secure pad over one takes the focus and keeps its own states.
local function PressedMicro()
    for button, state in pairs(micro) do
        if state.active then
            local focus = button.IsMouseMotionFocus
            if focus then focus = focus(button) else focus = button:IsVisible() and button:IsMouseOver() end
            if focus then return button end
        end
    end
end

-- Only a press to open: one on an up window's button is a close, released on the hide.
local function MouseDown(_, _, mouse)
    -- Quick keybind mode: the click only binds a key, nothing opens.
    if KeybindFrames_InQuickKeybindMode and KeybindFrames_InQuickKeybindMode() then return end
    local button = PressedMicro()
    local name = button and button:GetName()
    if name and MICRO_WINDOWS[name] and button:IsEnabled() and not WindowUp(name) then
        opening, openingWith, openUntil = button, mouse or "LeftButton", nil
    end
end

-- While an open is pending: re-press what anything lifted this frame, before it is drawn.
local function HoldOpening()
    local button = opening
    local state = micro[button]
    if not state.active then
        opening = nil
        return
    end
    local now = GetTime()
    -- Let go off the button: no click, nothing opens.
    if not openUntil and not IsMouseButtonDown(openingWith) then
        openUntil = button:IsMouseOver() and now + OPEN_GRACE or 0
    end
    if WindowUp(button:GetName()) or (openUntil and now >= openUntil) then
        opening = nil
        SyncMicroButton(button, state)
    elseif button:IsEnabled() and button:GetButtonState() ~= "PUSHED" then
        button:SetButtonState("PUSHED", true)
    end
end

local function EachFrame()
    if opening then HoldOpening() end
    ContestedButtons()
end

-- micro.state on its own frame created here: frame order matters, so a window of ours the Escape watch (an earlier frame)
-- closes in a fight is seen the same frame. Full pass at 10 Hz, opening and contested windows every frame; always awake
-- since client windows come and go unannounced.
local stateWatch = CreateFrame("Frame")
pcall(stateWatch.RegisterEvent, stateWatch, "GLOBAL_MOUSE_DOWN")
stateWatch:SetScript("OnEvent", MouseDown)
ns.Sched.OnFrame(stateWatch, { name = "micro.state", every = 0.1, fn = SyncMicroButtons, pre = EachFrame })

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
        if button.Count then
            button.Count:ClearAllPoints()
            button.Count:SetPoint("BOTTOM", button, "BOTTOM", 0, 3)
            button.Count:SetFontObject("NumberFontNormalSmall")
        end
    end
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
    state.active = true
    ApplyBagArt(button)
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
    if button.Count then
        button.Count:ClearAllPoints()
        button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 4)
    end
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
