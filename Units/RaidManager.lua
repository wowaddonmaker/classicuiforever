local _, ns = ...

-- Raid manager panel at the left edge (1.x had none): collapsed, its backing fades and the arrow
-- sits at the top below the player frame; expanded, it is the client's.

local UF = ns.UF
local STATES = ns.KEYS.STATES

local managerState

-- Each button wears the other's art turned over: flat side on the screen edge, its own arrow kept.
local TAB_FORWARD = { "gm-btnback-normal", "gm-btnback-hover" }
local TAB_BACK = { "gm-btnforward-normal", "gm-btnforward-hover" }

local function SetStateAlpha(tex, _, alpha) tex:SetAlpha(alpha) end

local function ClientTabArt(button, on)
    ns.EachState(button, STATES, SetStateAlpha, on and 1 or 0)
end

local function MirroredAtlas(tex, atlas)
    local info = C_Texture.GetAtlasInfo(atlas)
    if not info or not info.file then return false end
    tex:SetTexture(info.file)
    tex:SetTexCoord(info.rightTexCoord, info.leftTexCoord, info.topTexCoord, info.bottomTexCoord)
    return true
end

-- The client's hover repaint (SetAtlas) keeps the alpha, so its art stays hidden without a hook.
local function MirrorTab(button, art)
    if not button.fcuiTab then
        if not C_Texture or not C_Texture.GetAtlasInfo then return end
        local back = button:CreateTexture(nil, "BACKGROUND")
        if not MirroredAtlas(back, art[1]) then return end
        back:SetAllPoints(button)
        local glow = button:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints(button)
        if not MirroredAtlas(glow, art[2]) then glow:SetColorTexture(1, 1, 1, 0.12) end
        button.fcuiTab = { back = back, glow = glow }
    end
    ClientTabArt(button, false)
    button.fcuiTab.back:Show()
    button.fcuiTab.glow:Show()
end

local function PlainTab(button)
    if not button or not button.fcuiTab then return end
    button.fcuiTab.back:Hide()
    button.fcuiTab.glow:Hide()
    ClientTabArt(button, true)
end

local function LayoutRaidManager()
    local manager = CompactRaidFrameManager
    if not manager then return end
    local arrow = manager.toggleButtonForward
    if UF.active then
        if manager.Background then manager.Background:SetAlpha(manager.collapsed and 0 or 1) end
        if arrow then
            arrow:ClearAllPoints()
            arrow:SetPoint("TOPRIGHT", manager, "TOPRIGHT", -7, 0)
            MirrorTab(arrow, TAB_FORWARD)
        end
        if manager.toggleButtonBack then MirrorTab(manager.toggleButtonBack, TAB_BACK) end
    else
        if manager.Background then manager.Background:SetAlpha(1) end
        if arrow then
            arrow:ClearAllPoints()
            arrow:SetPoint("RIGHT", manager, "RIGHT", -7, 0)
            PlainTab(arrow)
        end
        PlainTab(manager.toggleButtonBack)
    end
end

-- Watched, not hooked: the collapse pass also sets up the raid frames, and a pass our code joins is refused their health.
local function WatchRaidManager()
    local manager = CompactRaidFrameManager
    if not manager then return end
    local state = manager.collapsed and true or false
    if state == managerState then return end
    managerState = state
    LayoutRaidManager()
end

local function SkinRaidManager()
    if not CompactRaidFrameManager then return end
    managerState = nil
    WatchRaidManager()
end

UF.LayoutRaidManager, UF.WatchRaidManager, UF.SkinRaidManager = LayoutRaidManager, WatchRaidManager, SkinRaidManager
