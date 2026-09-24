local _, ns = ...

-- Buff collapse arrow (1.x had none): alpha 0, not hidden, no BuffFrame calls (it handles secret values).

local arrowHidden = false
local arrowJob

-- Still shows under the mouse and still clicks: already folded buffs would have no way back.
local function SetBuffArrow(hidden)
    local button = BuffFrame and BuffFrame.CollapseAndExpandButton
    if not button then return end
    local alpha = 1
    if hidden and not (button.IsMouseOver and button:IsMouseOver(6, -6, -6, 6)) then alpha = 0 end
    if math.abs((button:GetAlpha() or 1) - alpha) > 0.01 then button:SetAlpha(alpha) end
    if not button:IsMouseEnabled() then button:EnableMouse(true) end
end

-- The client's layout can bring it back: polled.
local function ArrowPass()
    if arrowHidden then SetBuffArrow(true) end
end

-- Sole writer of arrowHidden; the poll runs exactly while it is set.
local function SetArrowHidden(on)
    arrowHidden = on
    if on then
        if arrowJob then
            arrowJob:Wake()
        else
            arrowJob = ns.Sched.Job({ name = "buffArrow", every = 0.05, fn = ArrowPass })
        end
    elseif arrowJob then
        arrowJob:Sleep()
    end
end

ns.RegisterModule("hideBuffArrow", {
    apply = function()
        SetArrowHidden(true)
        SetBuffArrow(true)
    end,
    restore = function()
        SetArrowHidden(false)
        SetBuffArrow(false)
    end,
})
