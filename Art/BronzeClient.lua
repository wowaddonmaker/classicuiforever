local _, ns = ...

-- Bronze theme on client art (chat buttons, NPC windows, auras): our copies at the same sheet
-- coords when on, the client's art back when off. The client resets art at will, so a light watch keeps it.

local B = ns.bronze
local DIR = B.DIR

-- Atlas sheets with a copy, by file id.
local SHEETS = {
    [1537274] = DIR .. "QuickJoin-Atlas.tga",
    [1706035] = DIR .. "ChatFrame-Atlas.tga",
    -- Inset and inner border corners, and the strips tiled across and down.
    [1723831] = DIR .. "UIFrame-Inner-Atlas.tga",
    [1723832] = DIR .. "UIFrame-VTile-Atlas.tga",
    [1723833] = DIR .. "UIFrame-HTile-Atlas.tga",
}
-- Plain files with a copy, by file id.
local FILES = {
    [130949] = DIR .. "UI-ChatIcon-Chat-Up.tga",
    [130948] = DIR .. "UI-ChatIcon-Chat-Down.tga",
    [130947] = DIR .. "UI-ChatIcon-Chat-Disabled.tga",
    -- Mail window: slot frames, bars, money boxes, slot backs, invoice line.
    [136383] = DIR .. "MailItemBorder.tga",
    [130968] = DIR .. "UI-ClassTrainer-HorizontalBar.tga",
    [130975] = DIR .. "Common-Input-Border.tga",
    [130862] = DIR .. "UI-Slot-Background.tga",
    [136387] = DIR .. "UI-MailFrame-InvoiceLine.tga",
    -- Page arrows (mail inbox).
    [130864] = DIR .. "UI-SpellbookIcon-NextPage-Disabled.tga",
    [130865] = DIR .. "UI-SpellbookIcon-NextPage-Down.tga",
    [130866] = DIR .. "UI-SpellbookIcon-NextPage-Up.tga",
    [130867] = DIR .. "UI-SpellbookIcon-PrevPage-Disabled.tga",
    [130868] = DIR .. "UI-SpellbookIcon-PrevPage-Down.tga",
    [130869] = DIR .. "UI-SpellbookIcon-PrevPage-Up.tga",
    -- Trade, merchant and bank slots: ring, empty slot, name plate.
    [130841] = DIR .. "UI-Quickslot2.tga",
    [130766] = DIR .. "UI-EmptySlot.tga",
    [136796] = DIR .. "UI-QuestItemNameFrame.tga",
    -- Red panel buttons, sliced from the old sheet.
    [130828] = DIR .. "UI-Panel-Button-Up.tga",
    [130825] = DIR .. "UI-Panel-Button-Down.tga",
    [130824] = DIR .. "UI-Panel-Button-Disabled.tga",
    -- Trade window's empty "will not be traded" slot.
    [137072] = DIR .. "UI-TradeFrame-EnchantIcon.tga",
}
local clientWas = setmetatable({}, { __mode = "k" })

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
        local info = C_Texture.GetAtlasInfo(atlas)
        local copy = info and SHEETS[info.file]
        -- Only if the copy loads (a failed load draws nothing); tiled strips stay tiled.
        local across, down = info and info.tilesHorizontally, info and info.tilesVertically
        if copy and texture:SetTexture(copy, across and "REPEAT" or "CLAMP", down and "REPEAT" or "CLAMP") ~= false then
            texture:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)
            if texture.SetHorizTile then texture:SetHorizTile(across and true or false) end
            if texture.SetVertTile then texture:SetVertTile(down and true or false) end
            clientWas[texture] = { atlas = atlas, copyID = texture:GetTexture() }
        elseif copy then
            texture:SetAtlas(atlas)
        end
        return
    end
    local file = texture:GetTexture()
    local copy = type(file) == "number" and FILES[file]
    if copy then
        if texture:SetTexture(copy) ~= false then
            clientWas[texture] = { file = file, copyID = texture:GetTexture() }
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
local function Forbidden(object)
    return not object or (object.IsForbidden and object:IsForbidden())
end

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

-- Every 0.5 s, and every frame for 1 s after a client window opens.
local function ClientPass()
    if not ns.db then return end
    if not ns.BronzeOn() then
        -- Restore everything on a copy, window open or not.
        for tex in pairs(clientWas) do BronzeClient(tex) end
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

-- Dress a client window next frame (waiting 0.5 s showed the trade window silver), then every
-- frame for 1 s while the client fills and redraws its slots.
local chatWatch = CreateFrame("Frame")
ns.RegisterEvents(chatWatch, { "TRADE_SHOW", "MAIL_SHOW", "MERCHANT_SHOW", "BANKFRAME_OPENED", "GOSSIP_SHOW",
    "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "TRAINER_SHOW", "LOOT_OPENED" })
chatWatch:SetScript("OnEvent", function()
    clientJob:Kick()
    clientJob:Burst(1)
end)

-- Buffs have only the icon's grey bevel, so the theme adds the thin rim as on action buttons;
-- debuff borders stay. Aura buttons are pooled, so they are rechecked twice a second.
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

local function AuraPass()
    if not ns.BronzeOn() then return end
    for i = 1, #BUFF_FRAMES do
        local frame = _G[BUFF_FRAMES[i]]
        if frame == nil then break end
        if frame then AuraRims(frame.AuraContainer or frame) end
    end
    for i = 1, #AURA_UNIT_FRAMES do
        local unitFrame = _G[AURA_UNIT_FRAMES[i]]
        if unitFrame == nil then break end
        local auras = unitFrame and unitFrame.GetAuraContainer and unitFrame:GetAuraContainer()
        if auras then AuraRims(auras) end
    end
end

ns.Sched.Job({ name = "bronze.auras", every = 0.5, awake = true, fn = AuraPass })
