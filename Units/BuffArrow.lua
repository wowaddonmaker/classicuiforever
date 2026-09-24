local _, ns = ...

-- Buff collapse arrow (1.x had none): alpha 0, not hidden, no BuffFrame calls (it handles secret values).

local arrowHidden = false
local arrowJob

local function Arrow()
    return BuffFrame and BuffFrame.CollapseAndExpandButton
end

-- Still shows under the mouse: already folded buffs would have no way back. Unseen, it has no hover to test.
local function SetBuffArrow(hidden)
    local button = Arrow()
    if not button then return end
    local alpha = 1
    if hidden and not (button:IsVisible() and button.IsMouseOver and button:IsMouseOver(6, -6, -6, 6)) then alpha = 0 end
    ns.SetAlphaIf(button, alpha, 0.01)
end

-- The client's layout can bring it back: polled.
local function ArrowPass()
    if arrowHidden then SetBuffArrow(true) end
end

-- Sole writer of arrowHidden; the poll runs exactly while it is set.
local function SetArrowHidden(on)
    arrowHidden = on
    -- Still clicks in both modes; the client never writes its mouse.
    local button = Arrow()
    if button then button:EnableMouse(true) end
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
