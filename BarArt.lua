local _, ns = ...

local BAND_HEIGHT = 43
local PIECE = 256
-- Rows of the 256x256 stone sheet as the 1.x bar sliced them (top, bottom).
local ROW_LEFT = { 0.83203125, 1.0 }
local ROW_MID = { 0.58203125, 0.75 }

local band
local pieces = {}
local active = false
local bordersFaded = false

local function BorderTextures()
    local bar = ns.GetMainBar()
    local list = {}
    local function add(tex)
        if tex then list[#list + 1] = tex end
    end
    add(bar and bar.BorderArt)
    add(MicroMenu and MicroMenu.BorderArt)
    add(MicroMenu and MicroMenu.BackgroundArt)
    add(BagsBar and BagsBar.BorderArt)
    return list
end

local function FadeBorders(fade)
    bordersFaded = fade
    for _, tex in ipairs(BorderTextures()) do
        tex:SetAlpha(fade and 0 or 1)
    end
end

local function ReleaseDividers(bar)
    if bar.HorizontalDividersPool then bar.HorizontalDividersPool:ReleaseAll() end
    if bar.VerticalDividersPool then bar.VerticalDividersPool:ReleaseAll() end
end

-- Right edge (in screen pixels) of a frame that sits on the same row as the
-- bar and extends past it, or nil when it has been moved elsewhere.
local function AlignedRight(bar, frame)
    if not frame or not frame:IsShown() then return end
    local fb, bb = frame:GetBottom(), bar:GetBottom()
    if not fb or not bb then return end
    local bs, fs = bar:GetEffectiveScale(), frame:GetEffectiveScale()
    if math.abs(fb * fs - bb * bs) > 20 then return end
    local right = frame:GetRight() * fs
    if right <= bar:GetRight() * bs then return end
    return right
end

-- The frame that ends the row: the bar itself, or the micro menu or bags
-- when they sit on the same row to its right. The gryphons and the band
-- both end there.
function ns.RowEnd()
    local bar = ns.GetMainBar()
    if not bar or not bar:GetLeft() then return bar end
    local endFrame, rightPx = bar, bar:GetRight() * bar:GetEffectiveScale()
    for _, frame in ipairs({ MicroMenuContainer, MicroMenu, BagsBar }) do
        local r = AlignedRight(bar, frame)
        if r and r > rightPx then
            endFrame, rightPx = frame, r
        end
    end
    return endFrame, rightPx
end

-- The 1.x band was drawn for 36px buttons; scale it with whatever size
-- the layout uses so the stone still shows above and below the icons.
function ns.ButtonScale()
    local bar = ns.GetMainBar()
    local button = bar and bar.actionButtons and bar.actionButtons[1] or ActionButton1
    local w = button and button:GetWidth() or 36
    if not w or w == 0 then w = 36 end
    return w / 36
end

local function Layout()
    local bar = ns.GetMainBar()
    if not bar or not bar:IsShown() or not bar:GetLeft() then
        if band then band:Hide() end
        return
    end
    if not band then
        band = CreateFrame("Frame", "ForeverClassicUIBarArt", UIParent)
        band:SetFrameStrata("MEDIUM")
        band:SetFrameLevel(1)
    end
    local bs = bar:GetEffectiveScale()
    band:SetScale(bs / UIParent:GetEffectiveScale())
    local _, rightPx = ns.RowEnd()
    local s = ns.ButtonScale()
    local width = (rightPx - bar:GetLeft() * bs) / bs + 16 * s
    band:ClearAllPoints()
    band:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -8 * s, -4 * s)
    band:SetSize(width, BAND_HEIGHT * s)

    local count = math.ceil(width / (PIECE * s))
    for i = 1, count do
        local tex = pieces[i]
        if not tex then
            tex = band:CreateTexture(nil, "BACKGROUND")
            pieces[i] = tex
        end
        ns.SetTex(tex, "barBody")
        local row = (i == 1) and ROW_LEFT or ROW_MID
        local w = math.min(PIECE * s, width - (i - 1) * PIECE * s)
        tex:SetTexCoord(0, w / (PIECE * s), row[1], row[2])
        tex:SetSize(w, BAND_HEIGHT * s)
        tex:ClearAllPoints()
        tex:SetPoint("BOTTOMLEFT", band, "BOTTOMLEFT", (i - 1) * PIECE * s, 0)
        tex:Show()
    end
    for i = count + 1, #pieces do
        pieces[i]:Hide()
    end
    band:Show()
end

local function Apply()
    active = true
    Layout()
    local bar = ns.GetMainBar()
    if bar then ReleaseDividers(bar) end
end

local function Restore()
    if not active then return end
    active = false
    if band then band:Hide() end
    local bar = ns.GetMainBar()
    if bar and bar.UpdateDividers then bar:UpdateDividers() end
end

local function Init()
    local bar = ns.GetMainBar()
    if not bar then return end
    local function Requeue()
        if active then ns.QueueApply() end
    end
    for _, frame in ipairs({ bar, MicroMenuContainer, MicroMenu, BagsBar }) do
        if frame then
            frame:HookScript("OnShow", Requeue)
            frame:HookScript("OnHide", Requeue)
            frame:HookScript("OnSizeChanged", Requeue)
        end
    end
    if type(rawget(bar, "UpdateDividers")) == "function" then
        hooksecurefunc(bar, "UpdateDividers", function(b)
            if active then ReleaseDividers(b) end
        end)
    end
end

ns.RegisterModule("barArt", { init = Init, apply = Apply, restore = Restore })
ns.RegisterModule("hideModernBorders", {
    apply = function() FadeBorders(true) end,
    restore = function() if bordersFaded then FadeBorders(false) end end,
})
