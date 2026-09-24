local _, ns = ...

-- Raid manager panel at the left edge (1.x had none): collapsed, its backing fades and the arrow
-- sits at the top below the player frame; expanded, it is the client's.

local UF = ns.UF
local STATES = ns.KEYS.STATES

local managerState

-- Collapsed: the back tab turned over (flat side on the screen edge, arrow right). Expanded: the back tab as drawn.
local TAB_FORWARD = { "gm-btnback-normal", "gm-btnback-hover", mirror = true }
local TAB_BACK = { "gm-btnback-normal", "gm-btnback-hover" }
-- Forever maps these atlases to bronze copies; the mainline sheet keeps the grey rim and gold arrow.
local MAINLINE_TAB_SHEET = 5524935
local MAINLINE_TAB = {
    ["gm-btnback-normal"] = { 449, 465, 986, 1021 },
    ["gm-btnback-hover"] = { 449, 465, 949, 984 },
}

local tabs = setmetatable({}, { __mode = "k" })

local function SetStateAlpha(tex, _, alpha) tex:SetAlpha(alpha) end

local function ClientTabArt(button, on)
    ns.EachState(button, STATES, SetStateAlpha, on and 1 or 0)
end

local function MainlineTab(tex, atlas, mirror)
    local px = MAINLINE_TAB[atlas]
    if not px or tex:SetTexture(MAINLINE_TAB_SHEET) == false then return false end
    local l, r = px[1] / 1024, px[2] / 1024
    if mirror then l, r = r, l end
    tex:SetTexCoord(l, r, px[3] / 1024, px[4] / 1024)
    return true
end

-- Theme on: Forever's bronze tab; off: the mainline one, or the bronze drained when that sheet is missing.
local function MirroredAtlas(tex, atlas, mirror)
    local on = ns.ThemeLook() ~= "classic"
    ns.UndrainBronze(tex)
    if not on and MainlineTab(tex, atlas, mirror) then return true end
    local info = on and C_Texture.GetAtlasInfo(atlas .. "-c60") or C_Texture.GetAtlasInfo(atlas)
    if not info or not info.file then return false end
    tex:SetTexture(info.file)
    local l, r = info.leftTexCoord, info.rightTexCoord
    if mirror then l, r = r, l end
    tex:SetTexCoord(l, r, info.topTexCoord, info.bottomTexCoord)
    if not on then ns.DrainBronze(tex) end
    return true
end

-- The client's hover repaint (SetAtlas) keeps the alpha, so its art stays hidden without a hook.
local function MirrorTab(button, art)
    if not C_Texture or not C_Texture.GetAtlasInfo then return end
    local tab = tabs[button]
    if not tab then
        tab = { back = button:CreateTexture(nil, "BACKGROUND"), glow = button:CreateTexture(nil, "HIGHLIGHT") }
        tab.back:SetAllPoints(button)
        tab.glow:SetAllPoints(button)
        tabs[button] = tab
    end
    if not MirroredAtlas(tab.back, art[1], art.mirror) then
        tab.back:Hide()
        tab.glow:Hide()
        ClientTabArt(button, true)
        return
    end
    if not MirroredAtlas(tab.glow, art[2], art.mirror) then tab.glow:SetColorTexture(1, 1, 1, 0.12) end
    ClientTabArt(button, false)
    tab.back:Show()
    tab.glow:Show()
end

local function PlainTab(button)
    local tab = button and tabs[button]
    if not tab then return end
    tab.back:Hide()
    tab.glow:Hide()
    ClientTabArt(button, true)
end

-- Party and raid group borders wear Forever's bronze frame: drained silver without the theme.
local GROUP_FRAMES = { "CompactPartyFrame" }
for i = 1, 8 do GROUP_FRAMES[#GROUP_FRAMES + 1] = "CompactRaidGroup" .. i end
-- The flat raid container's border is its own grey file: silver off, tinted bronze on.
local CONTAINER_BORDER = { "TopLeft", "TopRight", "BottomLeft", "BottomRight", "Top", "Bottom", "Left", "Right" }
local CONTAINER_PREFIX = "CompactRaidFrameContainerBorderFrameBorder"

local bordersSeen = {}
local bordersLeft = #GROUP_FRAMES + 1
local drainedBorders = setmetatable({}, { __mode = "k" })
local tintedBorders = setmetatable({}, { __mode = "k" })

-- Texture calls only, so groups made mid-fight are dressed on the next beat. Groups not made yet cost one lookup.
local function WatchGroupBorders()
    if bordersLeft == 0 then return end
    for i = 1, #GROUP_FRAMES do
        local name = GROUP_FRAMES[i]
        local group = not bordersSeen[name] and _G[name]
        local bg = group and ns.Path(group, "borderFrame", "Background")
        if bg then
            bordersSeen[name] = true
            bordersLeft = bordersLeft - 1
            drainedBorders[bg] = true
            ns.DrainBronze(bg)
        end
    end
    if not bordersSeen.container and _G[CONTAINER_PREFIX .. CONTAINER_BORDER[1]] then
        bordersSeen.container = true
        bordersLeft = bordersLeft - 1
        for i = 1, #CONTAINER_BORDER do
            local tex = _G[CONTAINER_PREFIX .. CONTAINER_BORDER[i]]
            if tex then
                tintedBorders[tex] = true
                ns.BronzeTint(tex, nil, true)
            end
        end
    end
end

local function PlainGroupBorders()
    for bg in pairs(drainedBorders) do ns.UndrainBronze(bg) end
    for tex in pairs(tintedBorders) do ns.UntintBronze(tex) end
    wipe(drainedBorders)
    wipe(tintedBorders)
    wipe(bordersSeen)
    bordersLeft = #GROUP_FRAMES + 1
end

local function LayoutRaidManager()
    if not UF.active then PlainGroupBorders() end
    local manager = CompactRaidFrameManager
    if not manager then return end
    local arrow = manager.toggleButtonForward
    if UF.active then
        if manager.Background then manager.Background:SetAlpha(manager.collapsed and 0 or 1) end
        if arrow then
            ns.SetPointOnce(arrow, "TOPRIGHT", manager, "TOPRIGHT", -7, 0)
            MirrorTab(arrow, TAB_FORWARD)
        end
        if manager.toggleButtonBack then MirrorTab(manager.toggleButtonBack, TAB_BACK) end
    else
        if manager.Background then manager.Background:SetAlpha(1) end
        if arrow then
            ns.SetPointOnce(arrow, "RIGHT", manager, "RIGHT", -7, 0)
            PlainTab(arrow)
        end
        PlainTab(manager.toggleButtonBack)
    end
end

-- Watched, not hooked: the collapse pass also sets up the raid frames, and a pass our code joins is refused their health.
local function WatchRaidManager()
    WatchGroupBorders()
    local manager = CompactRaidFrameManager
    if not manager then return end
    local state = manager.collapsed and true or false
    if state == managerState then return end
    managerState = state
    LayoutRaidManager()
end

local function SkinRaidManager()
    managerState = nil
    WatchRaidManager()
end

UF.LayoutRaidManager, UF.WatchRaidManager, UF.SkinRaidManager = LayoutRaidManager, WatchRaidManager, SkinRaidManager
