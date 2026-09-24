local _, ns = ...

-- Buff collapse arrow (1.x had none): alpha 0, not hidden, no BuffFrame calls (it handles secret values).

local arrowHidden = false
local arrowJob, watch
-- The arrow's hover sensor took (Sched.OnHover): no mouse polling.
local sensed = false
-- The alpha we last wrote: the client only shows and hides the arrow (BuffFrame.lua 693, 705, 858), never its alpha.
local shownAlpha

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
    shownAlpha = alpha
end

-- Runs only while the arrow shows and is hidden: the mouse is all that changes.
local function ArrowPass()
    local button = Arrow()
    if not arrowHidden or not button or not button.IsMouseOver then return end
    local alpha = button:IsMouseOver(6, -6, -6, 6) and 1 or 0
    if alpha == shownAlpha then return end
    ns.SetAlphaIf(button, alpha, 0.01)
    shownAlpha = alpha
end

-- Sole writer of the job's wake: awake exactly while the arrow shows and is hidden.
local function Refresh()
    local button = Arrow()
    if arrowHidden and button and button:IsVisible() and not sensed then
        if arrowJob then
            arrowJob:Wake()
        else
            arrowJob = ns.Sched.Job({ name = "buffArrow", every = 0.05, fn = ArrowPass })
        end
    elseif arrowJob then
        arrowJob:Sleep()
    end
end

local function Settle()
    Refresh()
    if arrowHidden then SetBuffArrow(true) end
end

-- It shows and hides inside the client's aura pass: our part waits for the next frame.
local function Edge()
    ns.Sched.NextFrame("buffArrow", Settle)
end

-- Sole writer of arrowHidden.
local function SetArrowHidden(on)
    arrowHidden = on
    -- Still clicks in both modes; the client never writes its mouse.
    local button = Arrow()
    if button then
        button:EnableMouse(true)
        -- A pure child: its OnShow/OnHide run only on the arrow's own visibility edges.
        if not watch then
            watch = CreateFrame("Frame", nil, button)
            watch:SetScript("OnShow", Edge)
            watch:SetScript("OnHide", Edge)
            sensed = ns.Sched.OnHover(button, ArrowPass, 6)
        end
    end
    Refresh()
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
