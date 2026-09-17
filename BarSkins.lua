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
    -- Forever only: the legacy adventure tree and housing get the two
    -- old sheets nothing else uses there.
    LegacyMicroButton = "Achievement", HousingMicroButton = "World",
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
    -- Some buttons swap their atlases straight from their own update code
    -- (latency colours, texture kits); put the 1.x art back right after.
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
        normal:SetAlpha(1)
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
    if button.CircleMask then button.CircleMask:Hide() end
    if button.IconBorder then
        ns.SetTex(button.IconBorder, "iconFrame")
        button.IconBorder:SetTexCoord(0, 1, 0, 1)
        button.IconBorder:ClearAllPoints()
        button.IconBorder:SetSize(size, size)
        button.IconBorder:SetPoint("CENTER", button, "CENTER", 0, 0)
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
    if state.backpack and button.icon then
        ns.SetTex(button.icon, "backpackIcon")
        button.icon:SetTexCoord(0, 1, 0, 1)
        if button.Count then
            button.Count:ClearAllPoints()
            button.Count:SetPoint("CENTER", button, "CENTER", 0, -10)
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

function ns.SkinBagButton(button, size, isBackpack, slim)
    local state = bags[button]
    if not state then
        state = { backpack = isBackpack }
        bags[button] = state
        HookBag(button)
    end
    state.size = size
    state.slim = slim
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

-- Forever's key ring is a bag-style button; 1.x drew it as a narrow key
-- icon on the band's right end.
function ns.SkinKeyRing(button)
    for _, name in ipairs({ "Normal", "Pushed", "Highlight" }) do
        local tex = StateTexture(button, name)
        if tex then
            ns.SetTex(tex, name == "Normal" and "keyRingUp" or name == "Pushed" and "keyRingDown" or "keyRingHighlight")
            tex:SetTexCoord(0, 0.5625, 0, 0.609375)
            tex:ClearAllPoints()
            tex:SetAllPoints(button)
            if name == "Highlight" then tex:SetBlendMode("ADD") end
        end
    end
    if button.icon then button.icon:Hide() end
    if button.IconBorder then button.IconBorder:Hide() end
    if button.SlotHighlightTexture then button.SlotHighlightTexture:SetAlpha(0) end
end

function ns.UnskinKeyRing(button)
    for _, name in ipairs({ "Normal", "Pushed", "Highlight" }) do
        local tex = StateTexture(button, name)
        if tex then
            tex:SetTexCoord(0, 1, 0, 1)
            tex:ClearAllPoints()
            tex:SetAllPoints(button)
        end
    end
    if button.icon then button.icon:Show() end
    if button.IconBorder then button.IconBorder:Show() end
    if button.SlotHighlightTexture then button.SlotHighlightTexture:SetAlpha(1) end
    if button.UpdateTextures then button:UpdateTextures() end
end
