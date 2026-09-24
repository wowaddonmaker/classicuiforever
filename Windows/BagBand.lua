local _, ns = ...

-- A band of the bag sheet as wide as the bag's columns (sheets are four wide):
-- right end (first column), left end (last two and ring), the second column
-- repeated between. It runs bar-middle to bar-middle, so it tiles seamlessly.

local STRIP_L, STRIP_R = 162, 204   -- the second column, on the 256 wide sheets

local Band = {}
Band.__index = Band

local function NewBand(frame)
    local band = setmetatable({ frame = frame, strips = {}, extra = 0, parts = {} }, Band)
    band.right = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    band.right:SetWidth(256 - STRIP_R)
    band.left = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    band.left:SetWidth(STRIP_L)
    band:SetColumns(4)
    return band
end

-- The ends carry three columns, so four still takes one strip. Re-laid only on a
-- count change: strips chain off the right end, which nothing else moves.
function Band:SetColumns(columns)
    local extra = math.max(1, (columns or 4) - 3)
    if extra == self.extra then return end
    self.extra = extra
    local last = self.right
    for i = 1, extra do
        local strip = self.strips[i]
        if not strip then
            strip = self.frame:CreateTexture(nil, "BACKGROUND", nil, -1)
            strip:SetWidth(STRIP_R - STRIP_L)
            self.strips[i] = strip
        end
        strip:ClearAllPoints()
        strip:SetPoint("TOPRIGHT", last, "TOPLEFT", 0, 0)
        last = strip
    end
    for i = extra + 1, #self.strips do self.strips[i]:Hide() end
    self.left:ClearAllPoints()
    self.left:SetPoint("TOPRIGHT", last, "TOPLEFT", 0, 0)
    local parts = self.parts
    parts[1], parts[2] = self.right, self.left
    for i = 1, extra do parts[i + 2] = self.strips[i] end
    for i = extra + 3, #parts do parts[i] = nil end
end

function Band:SetSheet(key)
    local parts = self.parts
    for i = 1, #parts do ns.SetTex(parts[i], key) end
end

-- Caller picks rows; each part keeps its own columns.
function Band:SetTexCoord(top, bottom)
    self.right:SetTexCoord(STRIP_R / 256, 1, top, bottom)
    self.left:SetTexCoord(0, STRIP_L / 256, top, bottom)
    for i = 1, self.extra do self.strips[i]:SetTexCoord(STRIP_L / 256, STRIP_R / 256, top, bottom) end
end

function Band:SetHeight(height)
    local parts = self.parts
    for i = 1, #parts do parts[i]:SetHeight(height) end
end

function Band:GetHeight() return self.right:GetHeight() end

function Band:ClearAllPoints() self.right:ClearAllPoints() end

-- Anchored by the right end: window top right, or the foot of the band above.
function Band:SetPoint(point, relativeTo, relativePoint, x, y)
    if getmetatable(relativeTo) == Band then
        self.right:SetPoint("TOPRIGHT", relativeTo.right, "BOTTOMRIGHT", x or 0, y or 0)
    else
        self.right:SetPoint(point, relativeTo, relativePoint, x or 0, y or 0)
    end
end

function Band:SetAlpha(alpha)
    local parts = self.parts
    for i = 1, #parts do parts[i]:SetAlpha(alpha) end
end

function Band:Show()
    local parts = self.parts
    for i = 1, #parts do parts[i]:Show() end
end

function Band:Hide()
    self.right:Hide()
    self.left:Hide()
    for _, strip in ipairs(self.strips) do strip:Hide() end
end

function Band:Owns(region)
    if region == self.right or region == self.left then return true end
    for _, strip in ipairs(self.strips) do if region == strip then return true end end
    return false
end

-- Shared with Bags.lua.
ns.bags = { NewBand = NewBand }
