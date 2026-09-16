local _, ns = ...

local SIZE = 22
local ARROW_GAP = 11
local saved

local function Buttons()
    local bar = ns.GetMainBar()
    local pn = bar and bar.ActionBarPageNumber
    if not pn or not pn.UpButton or not pn.DownButton then return end
    return pn, pn.UpButton, pn.DownButton
end

local STATES = { "Normal", "Pushed", "Disabled", "Highlight" }

local function Apply()
    local pn, up, down = Buttons()
    if not pn then return end
    if not saved then
        local _, _, _, _, upY = up:GetPoint(1)
        local _, _, _, _, downY = down:GetPoint(1)
        saved = { w = up:GetWidth(), h = up:GetHeight(), upY = upY or 10, downY = downY or -10 }
    end
    for _, button in ipairs({ up, down }) do
        local dir = (button == up) and "Up" or "Down"
        ns.SetButtonTex(button, "Normal", "arrow" .. dir .. "Up")
        ns.SetButtonTex(button, "Pushed", "arrow" .. dir .. "Down")
        ns.SetButtonTex(button, "Disabled", "arrow" .. dir .. "Disabled")
        ns.SetButtonTex(button, "Highlight", "arrow" .. dir .. "Highlight")
        for _, state in ipairs(STATES) do
            local tex = button["Get" .. state .. "Texture"](button)
            if tex then
                tex:SetTexCoord(0, 1, 0, 1)
                tex:ClearAllPoints()
                tex:SetAllPoints(button)
                if state == "Highlight" then tex:SetBlendMode("ADD") end
            end
        end
        button:SetSize(SIZE, SIZE)
    end
    up:ClearAllPoints()
    up:SetPoint("CENTER", pn, "CENTER", 0, ARROW_GAP)
    down:ClearAllPoints()
    down:SetPoint("CENTER", pn, "CENTER", 0, -ARROW_GAP)
end

local MODERN = {
    Up = { Normal = "ui-hud-actionbar-pageuparrow-up", Pushed = "ui-hud-actionbar-pageuparrow-down", Disabled = "ui-hud-actionbar-pageuparrow-disabled", Highlight = "ui-hud-actionbar-pageuparrow-mouseover" },
    Down = { Normal = "ui-hud-actionbar-pagedownarrow-up", Pushed = "ui-hud-actionbar-pagedownarrow-down", Disabled = "ui-hud-actionbar-pagedownarrow-disabled", Highlight = "ui-hud-actionbar-pagedownarrow-mouseover" },
}

local function Restore()
    if not saved then return end
    local pn, up, down = Buttons()
    if not pn then return end
    for _, button in ipairs({ up, down }) do
        local atlases = MODERN[(button == up) and "Up" or "Down"]
        for _, state in ipairs(STATES) do
            button["Set" .. state .. "Atlas"](button, atlases[state])
            local tex = button["Get" .. state .. "Texture"](button)
            if tex then
                tex:ClearAllPoints()
                tex:SetAllPoints(button)
                if state == "Highlight" then tex:SetBlendMode("BLEND") end
            end
        end
        button:SetSize(saved.w, saved.h)
    end
    up:ClearAllPoints()
    up:SetPoint("CENTER", pn, "CENTER", 0, saved.upY)
    down:ClearAllPoints()
    down:SetPoint("CENTER", pn, "CENTER", 0, saved.downY)
    saved = nil
end

ns.RegisterModule("pageArrows", { apply = Apply, restore = Restore })
