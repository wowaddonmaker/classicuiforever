local _, ns = ...

-- Classic art on Blizzard's bag and micro buttons. Each skin is applied
-- once, undone on demand, and put back after Blizzard's own state changes
-- (SetNormal, SetPushed, UpdateTextures) through hooks installed once.

local STATES = { "Normal", "Pushed", "Disabled", "Highlight" }

-- Micro button -> classic atlas name. Buttons with no 1.x counterpart keep
-- their modern art.
local MICRO_ART = {
    CharacterMicroButton = "Character", ProfessionMicroButton = "Abilities", SpellbookMicroButton = "Spellbook",
    TalentMicroButton = "Talents", PlayerSpellsMicroButton = "Talents", AchievementMicroButton = "Achievement",
    QuestLogMicroButton = "Quest", GuildMicroButton = "Socials", LFDMicroButton = "LFG",
    CollectionsMicroButton = "Mounts", EJMicroButton = "EJ", HelpMicroButton = "Help",
    StoreMicroButton = "BStore", MainMenuMicroButton = "MainMenu",
    -- The legacy adventure tree gets the old achievement sheet; housing
    -- keeps its modern art. The world map button is ours (ClassicBar).
    LegacyMicroButton = "Achievement",
    ForeverClassicUIWorldMapMicroButton = "World",
}
-- The classic sheets are 32x64 with the button art in the lower 42 rows.
local MICRO_CROP = 22 / 64
local PORTRAIT_W, PORTRAIT_H, PORTRAIT_Y = 18, 25, -7

local micro = {}   -- button -> { art, active, hooked }
local bags = {}    -- button -> { active, hooked, size }

local function StateTexture(button, state)
    local getter = button["Get" .. state .. "Texture"]
    return getter and getter(button)
end

---------------------------------------------------------------- micro buttons

local function ApplyMicroArt(button)
    local state = micro[button]
    if not state or not state.active then return end
    local art = state.art
    if art then
        -- The 1.x sheets are files the client still ships (and we bundle).
        ns.SetButtonTex(button, "Normal", "micro" .. art .. "Up")
        ns.SetButtonTex(button, "Pushed", "micro" .. art .. "Down")
        ns.SetButtonTex(button, "Disabled", "micro" .. art .. "Disabled")
        local highlight = StateTexture(button, "Highlight")
        if highlight then
            ns.SetTex(highlight, "microHighlight")
            highlight:SetBlendMode("ADD")
            highlight:SetAlpha(1)
        end
        for _, name in ipairs(STATES) do
            local tex = StateTexture(button, name)
            if tex then
                tex:SetTexCoord(0, 1, MICRO_CROP, 1)
                tex:ClearAllPoints()
                tex:SetAllPoints(button)
            end
        end
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
    -- Blizzard fades the normal texture out on mouseover because its
    -- highlight atlas is a whole button; the 1.x sheet stays put.
    button:HookScript("OnEnter", function(self)
        if state.active then
            local normal = self:GetNormalTexture()
            if normal then normal:SetAlpha(1) end
        end
    end)
    -- Some buttons swap their atlases straight from their own update code
    -- (latency colors, texture kits); put the 1.x art back right after.
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
        state = { art = MICRO_ART[button:GetName() or ""] }
        micro[button] = state
        HookMicro(button)
    end
    state.active = true
    ApplyMicroArt(button)
end

function ns.UnskinMicroButton(button)
    local state = micro[button]
    if not state or not state.active then return end
    state.active = false
    for _, name in ipairs(STATES) do
        local tex = StateTexture(button, name)
        if tex then
            tex:SetTexCoord(0, 1, 0, 1)
            tex:ClearAllPoints()
            tex:SetAllPoints(button)
        end
    end
    if button.textureName and type(LoadMicroButtonTextures) == "function" then
        LoadMicroButtonTextures(button, button.textureName)
    end
    if button.PortraitMask then button.PortraitMask:Show() end
    if button.Shadow then button.Shadow:Show() end
    if button.Portrait then
        button.Portrait:SetTexCoord(0, 1, 0, 1)
        button.Portrait:SetDrawLayer("ARTWORK", 0)
    end
    -- Blizzard's own state setter puts the background and portrait back.
    if button:GetButtonState() == "PUSHED" then
        if button.SetPushed then button:SetPushed() end
    elseif button.SetNormal then
        button:SetNormal()
    end
end

if type(LoadMicroButtonTextures) == "function" then
    hooksecurefunc("LoadMicroButtonTextures", function(button) ApplyMicroArt(button) end)
end

function ns.RefreshMicroButtons()
    if type(UpdateMicroButtons) == "function" and not InCombatLockdown() then UpdateMicroButtons() end
end
local function RefreshSoon() C_Timer.After(0, ns.RefreshMicroButtons) end
if type(ShowUIPanel) == "function" then hooksecurefunc("ShowUIPanel", RefreshSoon) end
if type(HideUIPanel) == "function" then hooksecurefunc("HideUIPanel", RefreshSoon) end

-- A micro button whose window is ours stays pressed while that window
-- is shown: Blizzard's own update runs first and sees its frame hidden,
-- then this puts the pressed state back.
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

local function ApplyBagArt(button)
    local state = bags[button]
    if not state or not state.active then return end
    local size = state.size
    local normal = StateTexture(button, "Normal")
    if normal then
        ns.SetTex(normal, "slotNormal")
        normal:SetTexCoord(0, 1, 0, 1)
        normal:ClearAllPoints()
        normal:SetSize(size * 50 / 30, size * 50 / 30)
        normal:SetPoint("CENTER", button, "CENTER", 0, -1)
        -- Not drawn. The band's art has a socket for every bag already,
        -- and the quickslot ring over it showed as brown slivers between
        -- the bags and against the key ring that the old bar never had.
        normal:SetAlpha(0)
    end
    local pushed = StateTexture(button, "Pushed")
    if pushed then
        ns.SetTex(pushed, "slotPushed")
        pushed:SetTexCoord(0, 1, 0, 1)
        pushed:ClearAllPoints()
        pushed:SetAllPoints(button)
        pushed:SetAlpha(1)
    end
    local highlight = StateTexture(button, "Highlight")
    if highlight then
        ns.SetTex(highlight, "highlight")
        highlight:SetTexCoord(0, 1, 0, 1)
        highlight:ClearAllPoints()
        highlight:SetAllPoints(button)
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(1)
    end
    if button.SlotHighlightTexture then
        ns.SetTex(button.SlotHighlightTexture, "checked")
        button.SlotHighlightTexture:SetTexCoord(0, 1, 0, 1)
        button.SlotHighlightTexture:SetBlendMode("ADD")
        button.SlotHighlightTexture:SetAlpha(1)
    end
    -- A round slot keeps the client's own circle over its icon and wears
    -- the small ring the minimap's round buttons wear.
    if button.CircleMask then button.CircleMask:SetShown(state.round == true) end
    if button.IconBorder then
        button.IconBorder:ClearAllPoints()
        if state.round then
            ns.SetTex(button.IconBorder, "trackingBorder")
            button.IconBorder:SetTexCoord(0, 1, 0, 1)
            -- The ring sits in the top left of its sheet, its hole about
            -- four tenths of the sheet across and centered three tenths
            -- in: drawn at two and a half times the button and hung a
            -- quarter of a button outside that corner, it lands round it.
            button.IconBorder:SetSize(size * 2.5, size * 2.5)
            button.IconBorder:SetPoint("TOPLEFT", button, "TOPLEFT", -size * 0.26, size * 0.26)
            button.IconBorder:SetVertexColor(1, 1, 1)
            button.IconBorder:SetAlpha(1)
            button.IconBorder:Show()
        else
            ns.SetTex(button.IconBorder, "iconFrame")
            button.IconBorder:SetTexCoord(0, 1, 0, 1)
            button.IconBorder:SetSize(size, size)
            button.IconBorder:SetPoint("CENTER", button, "CENTER", 0, 0)
        end
        button.IconBorder:SetDrawLayer("OVERLAY")
    end
    -- A slim slot shows the middle of its icon, like the old key ring.
    if state.slim and button.icon then
        local w = button:GetWidth()
        local inset = (1 - w / size) / 2
        button.icon:SetTexCoord(inset, 1 - inset, 0, 1)
        if normal then normal:SetSize(w * 50 / 30, size * 50 / 30) end
        if button.IconBorder then button.IconBorder:SetWidth(w) end
    elseif button.icon and not state.backpack then
        button.icon:SetTexCoord(0, 1, 0, 1)
    end
    -- An empty bag slot shows the old dim bag silhouette, not the
    -- client's empty-slot art: the reagent bag and the four bag slots.
    local bagSlot = button == CharacterReagentBag0Slot
    for i = 0, 3 do if button == _G["CharacterBag" .. i .. "Slot"] then bagSlot = true end end
    if bagSlot and button.icon and button.GetID then
        local empty = not GetInventoryItemTexture("player", button:GetID())
        if empty then button.icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag") end
        button.icon:SetDesaturated(empty)
        button.icon:SetAlpha(empty and 0.5 or 1)
        button.icon:SetTexCoord(0, 1, 0, 1)
        -- The round slot has no socket in the art to show a bag for it,
        -- and the client hides an empty slot's icon: its own is shown.
        if state.round then
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

function ns.SkinBagButton(button, size, isBackpack, slim, round)
    local state = bags[button]
    if not state then
        state = { backpack = isBackpack }
        bags[button] = state
        HookBag(button)
    end
    state.size = size
    state.slim = slim
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
    -- Blizzard's routine puts its own atlases and icon back.
    if button.UpdateTextures then button:UpdateTextures() end
    if button.Count then
        button.Count:ClearAllPoints()
        button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 4)
    end
end

--------------------------------------------------------------------- key ring

-- The 1.x key ring: an 18x39 key drawn from its own sheet. On a client
-- without a key ring the reagent bag wears it, so the slot still opens
-- something. Blizzard refreshes bag textures often; the hook puts it back.
local keyrings = {}

local function ApplyKeyRingArt(button)
    local state = keyrings[button]
    if not state or not state.active then return end
    for _, name in ipairs({ "Normal", "Pushed", "Highlight" }) do
        local tex = StateTexture(button, name)
        if tex then
            ns.SetTex(tex, name == "Normal" and "keyRingUp" or name == "Pushed" and "keyRingDown" or "keyRingHighlight")
            tex:SetTexCoord(0, 0.5625, 0, 0.609375)
            tex:ClearAllPoints()
            tex:SetAllPoints(button)
            tex:SetAlpha(1)
            if name == "Highlight" then tex:SetBlendMode("ADD") end
        end
    end
    local keep = { [StateTexture(button, "Normal") or 0] = true, [StateTexture(button, "Pushed") or 0] = true, [StateTexture(button, "Highlight") or 0] = true }
    for _, region in ipairs({ button:GetRegions() }) do
        if region:IsObjectType("Texture") and not keep[region] then region:SetAlpha(0) end
    end
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
    for _, name in ipairs({ "Normal", "Pushed", "Highlight" }) do
        local tex = StateTexture(button, name)
        if tex then
            tex:SetTexCoord(0, 1, 0, 1)
            tex:ClearAllPoints()
            tex:SetAllPoints(button)
        end
    end
    for _, region in ipairs({ button:GetRegions() }) do
        if region:IsObjectType("Texture") then region:SetAlpha(1) end
    end
    if button.Count then button.Count:SetAlpha(1) end
    if button.UpdateTextures then button:UpdateTextures() end
end
