local _, ns = ...

-- 1.x drew the main bar's empty slots but hid empty buttons on the other
-- bars unless a spell was being dragged. Blizzard now keeps them visible
-- per bar ("Always Show Buttons"); this fades the empties on the side
-- bars the old way and brings them back while the grid is shown.

local BARS = { "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft" }

local active = false
local gridShown = false
local driver

local DRAG_REASONS = 6   -- ACTION_BUTTON_SHOW_GRID_REASON_EVENT (2) or _SPELLBOOK (4)

local function HasSomething(button)
    if button.HasAction then return button:HasAction() end
    return button.action and HasAction(button.action)
end

local function Refresh()
    if not active then return end
    for _, name in ipairs(BARS) do
        local bar = _G[name]
        for _, button in ipairs(bar and bar.actionButtons or {}) do
            local reasons = button.GetAttribute and button:GetAttribute("showgrid") or 0
            local dragging = gridShown or (type(reasons) == "number" and bit.band(reasons, DRAG_REASONS) ~= 0)
            button:SetAlpha((dragging or HasSomething(button)) and 1 or 0)
        end
    end
end

local function OnEvent(_, event)
    if event == "ACTIONBAR_SHOWGRID" then
        gridShown = true
    elseif event == "ACTIONBAR_HIDEGRID" then
        gridShown = false
    end
    Refresh()
end

local function Apply()
    active = true
    if not driver then
        driver = CreateFrame("Frame")
        driver:SetScript("OnEvent", OnEvent)
        for _, event in ipairs({ "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "ACTIONBAR_SLOT_CHANGED", "PLAYER_ENTERING_WORLD", "UPDATE_BONUS_ACTIONBAR", "ACTIONBAR_PAGE_CHANGED" }) do
            pcall(driver.RegisterEvent, driver, event)
        end
    end
    Refresh()
end

local function Restore()
    active = false
    for _, name in ipairs(BARS) do
        local bar = _G[name]
        for _, button in ipairs(bar and bar.actionButtons or {}) do
            button:SetAlpha(1)
        end
    end
end

ns.RegisterModule("emptySlots", { apply = Apply, restore = Restore })
