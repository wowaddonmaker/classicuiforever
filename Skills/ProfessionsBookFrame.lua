local _, ns = ...

-- The small professions book in the spellbook's own frame: the spellbook's art over the window's generic chrome, laid
-- so its border lands on the spellbook's (that window stands 12 left and 14 up of this one), with the portrait, title
-- and close on the spellbook's spots. The full book and the trade skill page get the chrome back.

local T = ns.prof
local ART_X, ART_Y, ART_W, ART_H = -12, 14, 384, 512
-- The spellbook's spots, from its frame's corner, less that 12 and 14.
local PORTRAIT = { x = -2, y = 6, size = 58 }
local TITLE = { x = 186, y = -12 }
local CLOSE = { x = -11, y = -11 }

local holder, ringFrame
local saved   -- the chrome's own points, put back when the spellbook frame comes off

local function Points(region)
    local list = {}
    for i = 1, region:GetNumPoints() do list[i] = { region:GetPoint(i) } end
    return list
end

local function Restore(region, list)
    if not (region and list) then return end
    region:ClearAllPoints()
    for _, p in ipairs(list) do region:SetPoint(unpack(p)) end
end

local function Holder(frame)
    if holder then return holder end
    holder = ns.NewFrame("Frame", nil, frame)
    holder:SetSize(ART_W, ART_H)
    holder:SetPoint("TOPLEFT", frame, "TOPLEFT", ART_X, ART_Y)
    ns.DressPieces(holder, ns.SPELLBOOK_QUARTERS)
    holder:Hide()
    -- The portrait ring again over the page, whose bands reach under it.
    ringFrame = ns.NewFrame("Frame", nil, frame)
    ringFrame:SetSize(96, 96)
    ringFrame:SetPoint("TOPLEFT", holder, "TOPLEFT")
    local ring = ringFrame:CreateTexture(nil, "OVERLAY")
    ring:SetAllPoints(ringFrame)
    ns.SetTex(ring, "sbRing")
    ringFrame:Hide()
    return holder
end

-- on: the book page up at the small size. Out of combat only (the close button's window is protected).
function T.SmallFrame(on)
    local frame = ProfessionsFrame
    if not frame or not ns.SPELLBOOK_QUARTERS or InCombatLockdown() then return end
    local art = Holder(frame)
    -- Under every piece of the window, the chrome's textures included.
    ns.SetLevelIf(art, frame:GetFrameLevel())
    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    local close = frame.CloseButton
    if on then
        if not saved then
            saved = { portrait = portrait and Points(portrait), portraitSize = portrait and { portrait:GetSize() },
                title = title and Points(title), close = close and Points(close) }
        end
        ns.SetShownIf(art, true)
        local page = T.Page and T.Page()
        local portraitHost = frame.PortraitContainer
        ns.SetLevelIf(ringFrame, math.max(page and page:GetFrameLevel() or 0, portraitHost and portraitHost:GetFrameLevel() or 0) + 5)
        ns.SetShownIf(ringFrame, true)
        if frame.NineSlice then ns.SetAlphaIf(frame.NineSlice, 0) end
        if portrait then
            portrait:SetSize(PORTRAIT.size, PORTRAIT.size)
            ns.SetPointOnce(portrait, "TOPLEFT", frame, "TOPLEFT", PORTRAIT.x, PORTRAIT.y)
        end
        if title then ns.SetPointOnce(title, "CENTER", frame, "TOPLEFT", TITLE.x, TITLE.y) end
        if close then ns.SetPointOnce(close, "CENTER", frame, "TOPRIGHT", CLOSE.x, CLOSE.y) end
    elseif art:IsShown() then
        art:Hide()
        ringFrame:Hide()
        if frame.NineSlice then ns.SetAlphaIf(frame.NineSlice, 1) end
        if saved then
            Restore(portrait, saved.portrait)
            if portrait and saved.portraitSize then portrait:SetSize(unpack(saved.portraitSize)) end
            Restore(title, saved.title)
            Restore(close, saved.close)
            saved = nil
        end
    end
end
