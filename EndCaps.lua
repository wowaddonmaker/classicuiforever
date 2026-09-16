local _, ns = ...

local CAP_SIZE = 128
local saved = {}
local active = false

local function GetCaps()
    local bar = ns.GetMainBar()
    local caps = bar and bar.EndCaps
    if not caps or not caps.LeftEndCap or not caps.RightEndCap then return end
    return bar, caps.LeftEndCap, caps.RightEndCap
end

-- Forever wraps each cap in an edit-mode frame with a .Texture child;
-- retail-style clients expose the texture directly.
local function CapTexture(cap)
    if cap.Texture then return cap.Texture, cap end
    return cap, nil
end

local function Remember(tex)
    if saved[tex] then return end
    local point, rel, relPoint, x, y = tex:GetPoint(1)
    saved[tex] = { w = tex:GetWidth(), h = tex:GetHeight(), point = point, rel = rel, relPoint = relPoint, x = x, y = y }
end

local function ApplyCap(cap, side)
    local tex, holder = CapTexture(cap)
    Remember(tex)
    ns.SetTex(tex, "endCap")
    tex:SetSize(CAP_SIZE, CAP_SIZE)
    tex:ClearAllPoints()
    if holder then
        -- Leave the edit-mode holder where the layout put it (30px inside the bar
        -- edge, 154x95) and hang the 1.x art off its corner so the gryphon foot
        -- lands 3px below the bar the way the old bar drew it.
        if side == "left" then
            tex:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -2, 22)
        else
            tex:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 1, 22)
        end
    else
        local bar = ns.GetMainBar()
        if side == "left" then
            tex:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", 28, -3)
        else
            tex:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", -29, -3)
        end
    end
    -- One gryphon file, mirrored for the right side, exactly as the old bar did it.
    if side == "left" then
        tex:SetTexCoord(0, 1, 0, 1)
    else
        tex:SetTexCoord(1, 0, 0, 1)
    end
end

local function RestoreCap(cap)
    local tex, holder = CapTexture(cap)
    local s = saved[tex]
    if not s then return end
    tex:SetTexCoord(0, 1, 0, 1)
    tex:ClearAllPoints()
    if holder then
        tex:SetAllPoints(holder)
    elseif s.point then
        tex:SetPoint(s.point, s.rel, s.relPoint, s.x, s.y)
    end
    tex:SetSize(s.w, s.h)
    saved[tex] = nil
end

local function Apply()
    local bar, left, right = GetCaps()
    if not bar then return end
    active = true
    ApplyCap(left, "left")
    ApplyCap(right, "right")
    -- The gryphons are the point of this addon: show them even when the
    -- layout has "Hide Bar Art" on, which hides the whole end cap frame.
    bar.EndCaps:Show()
end

local function Restore()
    if not active then return end
    local bar, left, right = GetCaps()
    if not bar then return end
    active = false
    RestoreCap(left)
    RestoreCap(right)
    if bar.UpdateEndCaps then
        bar:UpdateEndCaps(bar.hideBarArt)
    end
end

local function Init()
    local bar = GetCaps()
    if not bar or type(rawget(bar, "UpdateEndCaps")) ~= "function" then return end
    -- Blizzard resets the atlas on faction and edit-mode changes; put the art back.
    hooksecurefunc(bar, "UpdateEndCaps", function()
        if active then Apply() end
    end)
end

function ns.EndCapShape()
    local bar, left = GetCaps()
    if not bar then return "none" end
    return left.Texture and "frame+texture (Forever)" or "texture (retail)"
end

ns.RegisterModule("endCaps", { init = Init, apply = Apply, restore = Restore })
