local _, ns = ...

-- Custom theme on client art (chat buttons, NPC windows, auras): the theme's copies at the same sheet
-- coords when on, the client's art back when off. The client resets art at will, so a light watch keeps it.

local B = ns.bronze
local BronzeCopy = ns.BronzeCopy

-- Atlas sheets with a copy, by file id (BronzeCopy finds the theme's).
local SHEETS = {
    [1537274] = "QuickJoin-Atlas.tga",
    [1706035] = "ChatFrame-Atlas.tga",
    -- Inset and inner border corners, and the strips tiled across and down.
    [1723831] = "UIFrame-Inner-Atlas.tga",
    [1723832] = "UIFrame-VTile-Atlas.tga",
    [1723833] = "UIFrame-HTile-Atlas.tga",
}
-- Plain files with a copy, by file id.
local FILES = {
    [130949] = "UI-ChatIcon-Chat-Up.tga",
    [130948] = "UI-ChatIcon-Chat-Down.tga",
    [130947] = "UI-ChatIcon-Chat-Disabled.tga",
    -- Mail window: slot frames, bars, money boxes, slot backs, invoice line.
    [136383] = "MailItemBorder.tga",
    [130968] = "UI-ClassTrainer-HorizontalBar.tga",
    [130975] = "Common-Input-Border.tga",
    [130862] = "UI-Slot-Background.tga",
    [136387] = "UI-MailFrame-InvoiceLine.tga",
    -- Page arrows (mail inbox).
    [130864] = "UI-SpellbookIcon-NextPage-Disabled.tga",
    [130865] = "UI-SpellbookIcon-NextPage-Down.tga",
    [130866] = "UI-SpellbookIcon-NextPage-Up.tga",
    [130867] = "UI-SpellbookIcon-PrevPage-Disabled.tga",
    [130868] = "UI-SpellbookIcon-PrevPage-Down.tga",
    [130869] = "UI-SpellbookIcon-PrevPage-Up.tga",
    -- Trade, merchant and bank slots: ring, empty slot, name plate.
    [130841] = "UI-Quickslot2.tga",
    [130766] = "UI-EmptySlot.tga",
    [136796] = "UI-QuestItemNameFrame.tga",
    -- Red panel buttons, sliced from the old sheet.
    [130828] = "UI-Panel-Button-Up.tga",
    [130825] = "UI-Panel-Button-Down.tga",
    [130824] = "UI-Panel-Button-Disabled.tga",
    -- Trade window's empty "will not be traded" slot.
    [137072] = "UI-TradeFrame-EnchantIcon.tga",
}
local clientWas = setmetatable({}, { __mode = "k" })
local IsSecret = ns.IsSecret

-- Atlas info is static and GetAtlasInfo builds a table per call: per atlas, its info if its sheet has a copy, else false.
local atlasCopy = {}
-- Per texture, the copyless atlas it was last judged on.
local judged = setmetatable({}, { __mode = "k" })

local function AskCopy(atlas)
    local info = C_Texture.GetAtlasInfo(atlas)
    return info and SHEETS[info.file] and info or false
end

local function CopyInfo(atlas)
    local info = atlasCopy[atlas]
    if info == nil then
        info = AskCopy(atlas)
        atlasCopy[atlas] = info
    end
    return info
end

-- Reuses the texture's record: no table per client reset.
local function Remember(texture, was, atlas, file)
    was = was or {}
    was.atlas, was.file, was.copyID = atlas, file, texture:GetTexture()
    clientWas[texture] = was
end

local function BronzeClient(texture, off)
    if not texture or not texture.GetAtlas then return end
    -- Our own pieces: the theme already handles them.
    if B.tinted[texture] or B.swapped[texture] then return end
    local was = clientWas[texture]
    if off or not ns.BronzeOn() then
        if was then
            clientWas[texture] = nil
            -- Clear first: SetAtlas of the atlas a texture still names is a no-op and draws nothing.
            texture:SetTexture(nil)
            texture:SetTexCoord(0, 1, 0, 1)
            if was.atlas then texture:SetAtlas(was.atlas) else texture:SetTexture(was.file) end
        end
        return
    end
    -- Still on our copy: the client has not reset it.
    if was and texture:GetTexture() == was.copyID then return end
    local atlas = texture:GetAtlas()
    if atlas and C_Texture and C_Texture.GetAtlasInfo then
        -- A secret atlas is never a key: asked each time, as before.
        local secret = IsSecret(atlas)
        if not secret and judged[texture] == atlas then return end
        local info
        if secret then info = AskCopy(atlas) else info = CopyInfo(atlas) end
        if not info then
            if not secret then judged[texture] = atlas end
            return
        end
        -- Only if the copy loads (a failed load draws nothing); tiled strips stay tiled.
        local across, down = info.tilesHorizontally, info.tilesVertically
        local copy = BronzeCopy(SHEETS[info.file])
        if texture:SetTexture(copy, across and "REPEAT" or "CLAMP", down and "REPEAT" or "CLAMP") ~= false then
            texture:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)
            if texture.SetHorizTile then texture:SetHorizTile(across and true or false) end
            if texture.SetVertTile then texture:SetVertTile(down and true or false) end
            Remember(texture, was, atlas, nil)
        else
            texture:SetAtlas(atlas)
        end
        return
    end
    local file = texture:GetTexture()
    local copy = type(file) == "number" and BronzeCopy(FILES[file])
    if copy then
        if texture:SetTexture(copy) ~= false then
            Remember(texture, was, nil, file)
        else
            texture:SetTexture(file)
        end
    end
end

-- Re-gathered each pass (the client may give a button a new texture) into one reused table.
local CHAT_BUTTONS = { "ChatFrameChannelButton", "TextToSpeechButton", "ChatFrameMenuButton" }
local STATE_GETTERS = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }
local chatList, chatCount = {}, 0

local function ChatTextures()
    local list, n = chatList, 0
    local quick = _G["QuickJoinToastButton"]
    if quick and quick.FriendsButton then
        n = n + 1
        list[n] = quick.FriendsButton
    end
    for i = 1, #CHAT_BUTTONS do
        local button = _G[CHAT_BUTTONS[i]]
        if button and button.GetNormalTexture then
            for j = 1, #STATE_GETTERS do
                local tex = button[STATE_GETTERS[j]](button)
                if tex then
                    n = n + 1
                    list[n] = tex
                end
            end
        end
    end
    -- Drop stale entries past this pass's count.
    for i = n + 1, chatCount do list[i] = nil end
    chatCount = n
    return list, n
end

local CLIENT_WINDOWS = { "MailFrame", "TradeFrame", "MerchantFrame", "BankFrame", "GossipFrame", "QuestFrame",
    "ClassTrainerFrame", "LootFrame" }

-- Forbidden pieces (trade window money boxes) may not be asked for regions.
local Forbidden = ns.IsForbidden

-- pcall-guarded walk, no tables built, five levels deep at most.
local EachRegionProtected, EachChildProtected = ns.EachRegionProtected, ns.EachChildProtected

local function ClientRegion(region)
    if not Forbidden(region) and region.IsObjectType and region:IsObjectType("Texture") then
        pcall(BronzeClient, region)
    end
end

-- One client texture to the theme (off = back to the client's), for watchers of our own.
function ns.BronzeClientTexture(texture, off)
    if texture and not Forbidden(texture) then pcall(BronzeClient, texture, off) end
end

local WalkClient
local function ClientChild(child, depth)
    WalkClient(child, depth + 1)
end

WalkClient = function(frame, depth)
    if Forbidden(frame) or depth > 5 or not frame.GetRegions then return end
    EachRegionProtected(frame, ClientRegion)
    EachChildProtected(frame, ClientChild, depth)
end

-- Theme last seen by the client pass; turning it on wakes the aura rims.
local themeSeen = {}
local WakeAuras

-- Every 0.5 s, and every frame for 1 s after a client window opens; off, asleep once every copy is handed back.
local function ClientPass(job)
    if not ns.db then return end
    if ns.ThemeTurned(themeSeen) then
        -- One theme to another: every copy handed back so this pass puts on the new theme's.
        if themeSeen.was and themeSeen.on then
            for tex in pairs(clientWas) do BronzeClient(tex, true) end
        end
        if themeSeen.on then WakeAuras() end
    end
    if not ns.BronzeOn() then
        -- Restore everything on a copy, window open or not.
        for tex in pairs(clientWas) do BronzeClient(tex) end
        if next(clientWas) == nil then job:Sleep() end
        return
    end
    local list, n = ChatTextures()
    for i = 1, n do BronzeClient(list[i]) end
    -- Open client windows only.
    for _, name in ipairs(CLIENT_WINDOWS) do
        local window = _G[name]
        if window and window:IsShown() then WalkClient(window, 0) end
    end
end

local clientJob = ns.Sched.Job({ name = "bronze.client", every = 0.5, awake = true, fn = ClientPass })
ns.OnToggle(function(key)
    if not B.THEME_KEYS[key] then return end
    clientJob:Wake()
    clientJob:Kick()
end)

-- A pass the frame after a window opens (0.5 s later showed the trade window silver), then every frame for 1 s.
ns.EventFrame({ "TRADE_SHOW", "MAIL_SHOW", "MERCHANT_SHOW", "BANKFRAME_OPENED", "GOSSIP_SHOW",
    "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "TRAINER_SHOW", "LOOT_OPENED" }, function()
    clientJob:Kick()
    clientJob:Burst(1)
end)

-- Buffs have only the icon's grey bevel, so the theme adds the thin rim as on action buttons; debuff borders stay.
-- A rim stays and follows every toggle (ns.BronzeKeep), so only buttons made since the last pass need one.
local EachChild = ns.EachChild

local function AuraRim(button)
    if button == nil then return end
    local icon = button.Icon or button.icon
    if icon and icon.IsObjectType and icon:IsObjectType("Texture") and not button.fcuiBronzeRim then
        ns.BronzeRim(button, icon)
    end
end

local function AuraRims(container)
    if not container or not container.GetChildren then return end
    EachChild(container, AuraRim)
end

-- Looked up each pass, in order; a missing name ends its list.
local BUFF_FRAMES = { "BuffFrame", "DebuffFrame" }
local AURA_UNIT_FRAMES = { "TargetFrame", "FocusFrame" }
-- The player's buttons are made once (BuffFrame.lua AuraFrame_OnLoad): one pass with the theme on rims them all.
local rimmed = setmetatable({}, { __mode = "k" })
-- Passes left after the last trigger: a second one catches buttons made after the first.
local passesLeft = 0

local function AuraPass(job)
    if ns.BronzeOn() then
        for i = 1, #BUFF_FRAMES do
            local frame = _G[BUFF_FRAMES[i]]
            if frame == nil then break end
            local container = frame and (frame.AuraContainer or frame)
            if container and not rimmed[container] then
                AuraRims(container)
                rimmed[container] = true
            end
        end
        -- Target and focus buttons come from pools that grow on their aura changes.
        for i = 1, #AURA_UNIT_FRAMES do
            local unitFrame = _G[AURA_UNIT_FRAMES[i]]
            if unitFrame == nil then break end
            local auras = unitFrame and unitFrame.GetAuraContainer and unitFrame:GetAuraContainer()
            if auras then AuraRims(auras) end
        end
    end
    passesLeft = passesLeft - 1
    if passesLeft <= 0 then job:Sleep() end
end

local auraJob = ns.Sched.Job({ name = "bronze.auras", every = 0.5, awake = false, fn = AuraPass })

-- From asleep a pass at once; a stream of triggers keeps it at twice a second, as the old poll ran.
WakeAuras = function()
    if not ns.BronzeOn() then return end
    passesLeft = 2
    if auraJob:IsAwake() then return end
    auraJob:Wake()
    auraJob:Kick()
end

-- The pools grow on these; edit mode switches the aura source to its fakes.
local auraEvents = ns.EventFrame({ "UNIT_AURA" }, function() WakeAuras() end, "target", "focus")
ns.RegisterEvents(auraEvents, { "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "PLAYER_ENTERING_WORLD",
    "AURA_DATA_PROVIDER_SWITCH" })
