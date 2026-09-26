local _, ns = ...

-- Need and greed rolls (GroupLootFrame1-4) in the 1.x roll box; the gamepad cards stay the client's.
-- Widget calls only: no hooks, no fields on client frames. A pure watcher per frame picks each roll's box.

local weak = { __mode = "k" }
local looks = setmetatable({}, weak)      -- roll frame -> { plain, gold, edge, job }
local seenRoll = setmetatable({}, weak)   -- roll frame -> rollID last dressed for
local seenLevel = setmetatable({}, weak)  -- roll frame -> Timer level last dressed for
local previews = setmetatable({}, weak)   -- the dev addon's copy -> its bind on pickup flag
local active = false

-- NUM_GROUP_LOOT_FRAMES is local to the client file.
local ROLL_FRAMES = 4
local PARTS = { "Background", "IconFrame", "Name", "Timer", "LootButtonContainer" }
local SIZE_1X, SIZE_CLIENT = { 243, 84 }, { 277, 67 }
local CLIENT_ART = { "Background", "Border" }
local ICON_RING = { "Border" }
local DICE = "Interface\\Buttons\\UI-GroupLoot-Dice-"
local COIN_UP = "Interface\\Buttons\\UI-GroupLoot-Coin-Up"
-- By file id: no client code names these by path, so a path lookup could miss.
local CORNER_FILE, GOLD_CORNER_FILE, DRAGON_FILE = 131073, 131077, 131078
local COIN_DOWN, COIN_HIGHLIGHT = 130767, 130768
local EMPTY_SLOT = "Interface\\Buttons\\UI-EmptySlot"
local NO_BRONZE = { bronze = false }
-- Forever's need roll flourish (1.x had none), cleared while classic; the roll number stays.
local ROLL_FX = {
    DiceRoll = "lootroll-animdice", DiceGlow = "lootroll-animdiceglow", FX_RevealA = "lootroll-animreveal-a",
    FX_RevealB1 = "lootroll-animreveal-b", FX_RevealB2 = "lootroll-animreveal-b", FX_RevealFade = "lootroll-animrevealfade",
}

-- key, point, relative key (nil: the owner), relative point, 1.x x and y (LootFrame.xml), the client's (GroupLootFrame.xml).
local FRAME_SPOTS = {
    { "IconFrame", "TOPLEFT", "Background", "TOPLEFT", 18, -18, 10, -11 },
    { "Name", "TOPLEFT", "Background", "TOPLEFT", 62, -15, 60, -15 },
    { "Timer", "BOTTOMLEFT", nil, "BOTTOMLEFT", 16, 17, 3, 2 },
}
local ICON_SPOTS = { { "Count", "BOTTOMRIGHT", nil, "BOTTOMRIGHT", -5, 2, -5, 0 } }
-- The container starts 3 right of the name, which puts Need at the 1.x TOPRIGHT -37, -14.
local BUTTON_SPOTS = {
    { "NeedButton", "TOPLEFT", nil, "TOPLEFT", 19, -14, 14, -7 },
    { "GreedButton", "TOP", "NeedButton", "BOTTOM", -2, 2, 0, 5 },
    { "PassButton", "LEFT", "NeedButton", "RIGHT", 4, 12, 6, 2 },
}
-- key, 1.x width and height, the client's.
local SIZES = { { "Name", 90, 30, 125, 30 }, { "Timer", 152, 10, 190, 8 } }

-- Our pieces, at the 1.x template's offsets; the boxes cover the roll frame.
local SLOT = { set = "file", w = 64, h = 64, point = "TOPLEFT", x = 3, y = -3, layer = "ARTWORK" }
local PLATE = { w = 128, h = 64, point = "TOPLEFT", x = 58, y = -13, layer = "ARTWORK" }
-- No bronze copy of the silver corner: tinted with the theme.
local CORNER = { set = "raw", tint = true, w = 32, h = 32, point = "TOPRIGHT", x = -6, y = -7, layer = "OVERLAY" }
local GOLD_CORNER = { set = "raw", w = 32, h = 32, point = "TOPRIGHT", x = -6, y = -7, layer = "OVERLAY" }
-- 1.x marked bind on pickup with the gold box and this dragon, hung past the top left.
local DRAGON = { set = "raw", w = 120, h = 120, point = "TOPLEFT", x = -30, y = 15, layer = "OVERLAY" }
local BAR_EDGE = { w = 156, h = 20, point = "TOP", x = 0, y = 5, layer = "OVERLAY" }

local FULL = { 0, 1, 0, 1 }
local ROLL_STATES = { set = "file", coords = FULL, fill = true, add = true }
local CLOSE_STATES = { coords = FULL, fill = true, add = true }
-- The client's atlases, put back on restore; GetAtlas may be secret.
local ATLAS = {
    NeedButton = "lootroll-toast-icon-need-", GreedButton = "lootroll-toast-icon-greed-",
    PassButton = "lootroll-toast-icon-pass-",
}
local ATLAS_STATE = { Normal = "up", Pushed = "down", Highlight = "highlight" }

------------------------------------------------------------------ the boxes

local function NewBox(frame, gold)
    local box = ns.DialogBacking(frame, gold and ns.BACKDROP.DIALOG_GOLD or nil, gold and NO_BRONZE or nil)
    ns.DressNew(box, EMPTY_SLOT, SLOT)
    ns.DressNew(box, "merchantLabelSlots", PLATE)
    if gold then
        ns.DressNew(box, GOLD_CORNER_FILE, GOLD_CORNER)
        ns.DressNew(box, DRAGON_FILE, DRAGON)
    else
        ns.DressNew(box, CORNER_FILE, CORNER)
    end
    box:Hide()
    return box
end

-- The 1.x bar border, on its own frame so it can sit a level over the Timer.
local function NewEdge(frame)
    local edge = CreateFrame("Frame", nil, frame)
    edge:SetAllPoints(frame.Timer)
    ns.DressNew(edge, "skillsBarBorder", BAR_EDGE)
    return edge
end

-- 1.x order: boxes under the frame, the Timer over it (the client drops it under on each show), the bar edge on top.
local function Level(frame, look)
    local level = ns.Safe(frame:GetFrameLevel(), 1)
    local under = math.max(0, level - 1)
    ns.SetLevelIf(look.plain, under)
    ns.SetLevelIf(look.gold, under)
    ns.SetLevelIf(frame.Timer, level + 1)
    ns.SetLevelIf(look.edge, level + 2)
    return level + 1
end

local function BindOnPickup(frame, id)
    local forced = previews[frame]
    if forced ~= nil then return forced end
    if id == nil then return false end
    local _, _, _, _, bop = _G.GetLootRollItemInfo(id)
    return not ns.IsSecret(bop) and bop and true or false
end

local function Look(job)
    local frame = job.rollFrame
    local look = looks[frame]
    local id = frame.rollID
    if not active or not look or ns.IsSecret(id) then return end
    seenRoll[frame] = id
    seenLevel[frame] = Level(frame, look)
    local gold = BindOnPickup(frame, id)
    ns.SetShownIf(look.plain, not gold)
    ns.SetShownIf(look.gold, gold)
end

-- Every frame while shown: a new roll or a moved Timer is dressed before the frame draws.
local function Fresh(job)
    local frame = job.rollFrame
    local id = frame.rollID
    if ns.IsSecret(id) then return false end
    return id ~= seenRoll[frame] or frame.Timer:GetFrameLevel() ~= seenLevel[frame]
end

local function Build(frame, name)
    local look = { plain = NewBox(frame, false), gold = NewBox(frame, true), edge = NewEdge(frame) }
    looks[frame] = look
    -- A pure child, run only while its roll frame is shown and only when pre sees a change.
    local job = ns.Sched.OnFrame(CreateFrame("Frame", nil, frame),
        { name = "lootRoll." .. name, every = math.huge, fn = Look, pre = Fresh })
    job.rollFrame = frame
    look.job = job
    return look
end

---------------------------------------------------------- the client's pieces

local function Spot(owner, spots, classic)
    if not owner then return end
    for i = 1, #spots do
        local spot = spots[i]
        local region, rel = owner[spot[1]], spot[3] and owner[spot[3]] or owner
        if region and rel then
            local x, y = spot[5], spot[6]
            if not classic then x, y = spot[7], spot[8] end
            ns.SetPointIf(region, spot[2], rel, spot[4], x, y)
        end
    end
end

-- SetFontObject takes back the quality colour the client gave the name on show.
local function Recolor(frame)
    local id = frame.rollID
    if id == nil or ns.IsSecret(id) or not frame:IsShown() then return end
    local _, _, _, quality = _G.GetLootRollItemInfo(id)
    local color = not ns.IsSecret(quality) and quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then frame.Name:SetVertexColor(color.r, color.g, color.b) end
end

-- Sizes, anchors and the name's font; the container keeps the stacking slot centred.
local function Place(frame, classic)
    local size = classic and SIZE_1X or SIZE_CLIENT
    frame:SetSize(size[1], size[2])
    Spot(frame, FRAME_SPOTS, classic)
    Spot(frame.IconFrame, ICON_SPOTS, classic)
    Spot(frame.LootButtonContainer, BUTTON_SPOTS, classic)
    for i = 1, #SIZES do
        local entry = SIZES[i]
        local region = frame[entry[1]]
        if region and classic then
            region:SetSize(entry[2], entry[3])
        elseif region then
            region:SetSize(entry[4], entry[5])
        end
    end
    local name = frame.Name
    name:SetFontObject(classic and "GameFontNormalSmall" or "GameFontNormal")
    name:SetJustifyH("LEFT")
    name:SetJustifyV("MIDDLE")
    Recolor(frame)
end

-- No disabled art: the client greys by desaturating the normal texture, and an added one could not be taken off.
local function ButtonArt(box)
    ns.DressStates(box.NeedButton, DICE .. "Up", DICE .. "Down", nil, DICE .. "Highlight", ROLL_STATES)
    ns.DressStates(box.GreedButton, COIN_UP, COIN_DOWN, nil, COIN_HIGHLIGHT, ROLL_STATES)
    ns.DressStates(box.PassButton, "closeUp", "closeDown", nil, "closeHighlight", CLOSE_STATES)
end

-- Cleared first: SetAtlas of the atlas a texture still names draws nothing.
local function ClientButtonArt(box)
    for key, stem in pairs(ATLAS) do
        local button = box[key]
        for state, suffix in pairs(ATLAS_STATE) do
            local tex = button and ns.StateTexture(button, state)
            if tex then
                ns.UnswapBronze(tex)
                tex:SetTexture(nil)
                tex:SetAtlas(stem .. suffix)
            end
        end
    end
end

-- Cleared, not faded: the animation drives their alpha. The client sets these atlases only at load.
local function RollFx(anim, classic)
    if not anim then return end
    for key, atlas in pairs(ROLL_FX) do
        local tex = anim[key]
        if tex then
            tex:SetTexture(nil)
            if not classic then tex:SetAtlas(atlas) end
        end
    end
end

-- Forever's toast art and quality ring faded (1.x had neither); the client's Timer already has the 1.x fill and black ground.
local function Paint(frame, classic)
    local alpha = classic and 0 or 1
    ns.FadeKeys(frame, CLIENT_ART, alpha)
    ns.FadeKeys(frame.IconFrame, ICON_RING, alpha)
    if classic then ButtonArt(frame.LootButtonContainer) else ClientButtonArt(frame.LootButtonContainer) end
    RollFx(frame.NeedRollAnim, classic)
end

------------------------------------------------------------------- the module

local function Whole(frame, name)
    for i = 1, #PARTS do
        if not frame[PARTS[i]] then
            ns.MissingPiece(name .. "." .. PARTS[i])
            return false
        end
    end
    return true
end

local function Dress(frame, name)
    if not Whole(frame, name) then return end
    local look = looks[frame] or Build(frame, name)
    Place(frame, true)
    Paint(frame, true)
    look.edge:Show()
    look.job:Wake()
    seenLevel[frame] = nil
    Look(look.job)
end

local function Undress(frame)
    local look = looks[frame]
    if not look then return end
    look.job:Sleep()
    look.plain:Hide()
    look.gold:Hide()
    look.edge:Hide()
    seenRoll[frame], seenLevel[frame] = nil, nil
    -- The client's own per-show level.
    ns.SetLevelIf(frame.Timer, math.max(0, ns.Safe(frame:GetFrameLevel(), 1) - 1))
    Place(frame, false)
    Paint(frame, false)
end

local function EachRoll(fn)
    for i = 1, ROLL_FRAMES do
        local name = "GroupLootFrame" .. i
        local frame = _G[name]
        if frame then ns.SafeCall(fn, frame, name) else ns.MissingPiece(name) end
    end
    for frame in pairs(previews) do ns.SafeCall(fn, frame, "preview") end
end

-- Every pass calls these: work only on a change.
local function Apply()
    if active then return end
    active = true
    EachRoll(Dress)
end

local function Restore()
    if not active then return end
    active = false
    EachRoll(Undress)
end

ns.RegisterModule("lootRoll", { apply = Apply, restore = Restore })

local function IsClientRoll(frame)
    for i = 1, ROLL_FRAMES do
        if _G["GroupLootFrame" .. i] == frame then return true end
    end
    return false
end

-- The dev addon's copy of the roll template, dressed like the real frames and kept in step with the toggle.
function ns.DressLootRoll(frame, bop)
    if type(frame) ~= "table" or not frame.LootButtonContainer or IsClientRoll(frame) then return false end
    previews[frame] = bop and true or false
    if active then Dress(frame, "preview") end
    return active
end
