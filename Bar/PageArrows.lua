local _, ns = ...

-- Stone page arrows ride with the classic bar; restore puts the modern atlases back.
local saved

local STATES = ns.KEYS.STATES
local ARROW = { coords = { 0, 1, 0, 1 }, fill = true, add = true }
local STONE = {
    Up = { "arrowUpUp", "arrowUpDown", "arrowUpDisabled", "arrowUpHighlight" },
    Down = { "arrowDownUp", "arrowDownDown", "arrowDownDisabled", "arrowDownHighlight" },
}
local MODERN = {
    Up = { Normal = "ui-hud-actionbar-pageuparrow-up", Pushed = "ui-hud-actionbar-pageuparrow-down", Disabled = "ui-hud-actionbar-pageuparrow-disabled", Highlight = "ui-hud-actionbar-pageuparrow-mouseover" },
    Down = { Normal = "ui-hud-actionbar-pagedownarrow-up", Pushed = "ui-hud-actionbar-pagedownarrow-down", Disabled = "ui-hud-actionbar-pagedownarrow-disabled", Highlight = "ui-hud-actionbar-pagedownarrow-mouseover" },
}
local ATLAS_SETTER = { Normal = "SetNormalAtlas", Pushed = "SetPushedAtlas", Disabled = "SetDisabledAtlas", Highlight = "SetHighlightAtlas" }

local function Buttons()
    local bar = ns.GetMainBar()
    local pn = bar and bar.ActionBarPageNumber
    if not pn or not pn.UpButton or not pn.DownButton then return end
    return pn, pn.UpButton, pn.DownButton
end

local function Apply()
    local pn, up, down = Buttons()
    if not pn then return end
    if not saved then
        local _, _, _, _, upY = up:GetPoint(1)
        local _, _, _, _, downY = down:GetPoint(1)
        saved = { w = up:GetWidth(), h = up:GetHeight(), upY = upY or 10, downY = downY or -10 }
    end
    for _, button in ipairs({ up, down }) do
        local keys = STONE[(button == up) and "Up" or "Down"]
        ns.DressStates(button, keys[1], keys[2], keys[3], keys[4], ARROW)
    end
end

local function Refill(tex, state, button)
    tex:ClearAllPoints()
    tex:SetAllPoints(button)
    if state == "Highlight" then tex:SetBlendMode("BLEND") end
end

local function Restore()
    if not saved then return end
    local pn, up, down = Buttons()
    if not pn then return end
    for _, button in ipairs({ up, down }) do
        local atlases = MODERN[(button == up) and "Up" or "Down"]
        for _, state in ipairs(STATES) do
            button[ATLAS_SETTER[state]](button, atlases[state])
        end
        ns.EachState(button, STATES, Refill, button)
        button:SetSize(saved.w, saved.h)
    end
    up:ClearAllPoints()
    up:SetPoint("CENTER", pn, "CENTER", 0, saved.upY)
    down:ClearAllPoints()
    down:SetPoint("CENTER", pn, "CENTER", 0, saved.downY)
    saved = nil
end

-- Own id for module order; classicBar is the toggle key.
ns.RegisterModule("classicBar", { id = "pageArrows", apply = Apply, restore = Restore })
