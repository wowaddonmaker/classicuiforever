local _, ns = ...

local BAR_NAMES = { "MainActionBar", "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7" }
local BASE = 36 -- the 1.x button size the classic art was drawn around
local NORMAL_CROP = { 0.1875, 0.796875, 0.1875, 0.796875 }
local active = false

local function ButtonsOf(bar)
    if bar.actionButtons then return bar.actionButtons end
    local name = bar:GetName()
    local prefix = (name == "MainActionBar" or name == "MainMenuBar") and "ActionButton" or name .. "Button"
    local list = {}
    for i = 1, 12 do
        list[i] = _G[prefix .. i]
    end
    return list
end

local function ScaleOf(button)
    local w = button:GetWidth()
    if not w or w == 0 then w = 45 end
    return w / BASE, w
end

-- The 1.x look as Classic Era draws it: the open socket behind every
-- button at 40% and the bevelled ring over it at 50%, so both read as
-- recessed stone on the band instead of black squares.
local function SkinNormal(button)
    local s = ScaleOf(button)
    local tex = ns.SetButtonTex(button, "Normal", "slotNormal")
    if not tex then return end
    tex:ClearAllPoints()
    tex:SetPoint("CENTER")
    tex:SetTexCoord(NORMAL_CROP[1], NORMAL_CROP[2], NORMAL_CROP[3], NORMAL_CROP[4])
    tex:SetSize(40 * s, 40 * s)
    tex:SetDrawLayer("OVERLAY")
    tex:SetAlpha(0.5)
    local socket = button.SlotBackground
    if socket then
        ns.SetTex(socket, "slotEmpty")
        socket:SetTexCoord(0, 1, 0, 1)
        socket:ClearAllPoints()
        socket:SetPoint("CENTER")
        socket:SetSize(66 * s, 66 * s)
        socket:SetAlpha(0.4)
        -- Under the icon, and said so. The client keeps the socket and
        -- the icon on the same layer and the same sublevel, where the
        -- order two textures are drawn in is not promised: with the old
        -- socket art in place of the client's, the socket came out on
        -- top of the icon on some buttons, at random and differently
        -- from one moment to the next, and its four tenths of dark
        -- stone over a spell is what read as a dimmed icon.
        socket:SetDrawLayer("BACKGROUND", -1)
        socket:Show()
    end
end

local function Centered(tex, size)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER")
    tex:SetSize(size, size)
    tex:SetTexCoord(0, 1, 0, 1)
end

local function Skin(button)
    if not button then return end
    local s, w = ScaleOf(button)
    if button.SlotArt then button.SlotArt:SetAlpha(0) end
    SkinNormal(button)
    local pushed = ns.SetButtonTex(button, "Pushed", "slotPushed")
    if pushed then
        Centered(pushed, w)
        pushed:SetDrawLayer("OVERLAY")
    end
    local hl = ns.SetButtonTex(button, "Highlight", "highlight")
    if hl then
        Centered(hl, w)
        hl:SetBlendMode("ADD")
    end
    local ck = ns.SetButtonTex(button, "Checked", "checked")
    if ck then
        Centered(ck, w)
        ck:SetBlendMode("ADD")
    end
    if button.Flash then
        ns.SetTex(button.Flash, "slotFlash")
        Centered(button.Flash, w)
    end
    if button.Border then
        ns.SetTex(button.Border, "equippedBorder")
        Centered(button.Border, 62 * s)
        button.Border:SetBlendMode("ADD")
    end
    if button.icon and button.IconMask and button.icon.RemoveMaskTexture then
        if ns.db.squareIcons and not button.fcuiMaskRemoved then
            button.icon:RemoveMaskTexture(button.IconMask)
            button.fcuiMaskRemoved = true
        elseif not ns.db.squareIcons and button.fcuiMaskRemoved then
            button.icon:AddMaskTexture(button.IconMask)
            button.fcuiMaskRemoved = nil
        end
    end
end

local function Unskin(button)
    if not button then return end
    if button.SlotArt then button.SlotArt:SetAlpha(1) end
    if button.SlotBackground then
        button.SlotBackground:SetAlpha(1)
        button.SlotBackground:SetDrawLayer("BACKGROUND", 0)
        button.SlotBackground:SetTexCoord(0, 1, 0, 1)
        button.SlotBackground:SetAtlas("UI-HUD-ActionBar-IconFrame-Background")
        button.SlotBackground:ClearAllPoints()
        button.SlotBackground:SetAllPoints(button)
    end
    if button.fcuiMaskRemoved then
        button.icon:AddMaskTexture(button.IconMask)
        button.fcuiMaskRemoved = nil
    end
    for _, name in ipairs({ "Normal", "Pushed" }) do
        local tex = button["Get" .. name .. "Texture"](button)
        if tex then
            tex:SetTexCoord(0, 1, 0, 1)
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT")
        end
    end
    if button.UpdateButtonArt then button:UpdateButtonArt() end
    for _, name in ipairs({ "Highlight", "Checked" }) do
        local tex = button["Get" .. name .. "Texture"](button)
        if tex then
            tex:SetTexCoord(0, 1, 0, 1)
            tex:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT")
            tex:SetSize(46, 45)
        end
    end
    if button.Flash then
        button.Flash:SetTexCoord(0, 1, 0, 1)
        button.Flash:SetAtlas("UI-HUD-ActionBar-IconFrame-Flash", true)
        button.Flash:ClearAllPoints()
        button.Flash:SetPoint("TOPLEFT")
    end
    if button.Border then
        button.Border:SetTexCoord(0, 1, 0, 1)
        button.Border:SetAtlas("UI-HUD-ActionBar-IconFrame-Border", true)
        button.Border:SetBlendMode("BLEND")
        button.Border:ClearAllPoints()
        button.Border:SetPoint("TOPLEFT")
    end
end

local function ForEachButton(fn)
    for _, barName in ipairs(BAR_NAMES) do
        local bar = _G[barName]
        if bar then
            for _, button in ipairs(ButtonsOf(bar)) do
                fn(button)
            end
        end
    end
end

-- The client repaints a button's art on its own passes, and our code
-- may not be part of one: it lays its bars out in the same pass as the
-- party and raid frames, which it then refuses their own health. So the
-- art is watched instead. Our skin leaves the modern slot art hidden
-- and the socket at four tenths, so either one back up is the client
-- having repainted that button, and only that button is done again.
local function Repainted(button)
    local art = button.SlotArt
    if art and art:GetAlpha() > 0.01 then return true end
    local socket = button.SlotBackground
    if socket and math.abs(socket:GetAlpha() - 0.4) > 0.01 then return true end
    return false
end

local watch
local function StartWatch()
    if watch then return end
    watch = CreateFrame("Frame")
    watch:SetScript("OnUpdate", function(self, elapsed)
        if not active then return end
        self.since = (self.since or 0) + elapsed
        if self.since < 0.2 then return end
        self.since = 0
        ForEachButton(function(button)
            if button and Repainted(button) then Skin(button) end
        end)
    end)
end

-- Anything else that dresses an action button walks them from here.
ns.ForEachActionButton = ForEachButton

local function Apply()
    active = true
    ForEachButton(Skin)
    StartWatch()
end

local function Restore()
    if not active then return end
    active = false
    ForEachButton(Unskin)
end

ns.RegisterModule("buttons", { apply = Apply, restore = Restore })
