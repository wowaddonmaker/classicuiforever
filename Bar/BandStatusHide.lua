local _, ns = ...
local B = ns.band

-- Hide This Bar for either status bar: its bars unseen with no mouse, and a box of ours under edit mode's dialog.

local SetAlphaIf = ns.SetAlphaIf

-- Hide This Bar (the client has no such setting): per holder, kept in our settings.
local function HideKey(holder)
    if holder == nil then return nil end
    if holder == MainStatusTrackingBarContainer then return "hideStatusMain" end
    if holder == SecondaryStatusTrackingBarContainer then return "hideStatusSecond" end
    return nil
end

local function StatusHidden(holder)
    local key = HideKey(holder)
    return key ~= nil and ns.db ~= nil and ns.db[key] == true
end
B.StatusHidden = StatusHidden

-- A hidden holder's bars go unseen and take no mouse; the client fades only the holder, never its bars.
local barsHidden = setmetatable({}, { __mode = "k" })
function B.ShowHolderBars(container)
    local hide = StatusHidden(container)
    if not hide and not barsHidden[container] then return end
    for _, bar in pairs(container.bars or {}) do
        SetAlphaIf(bar, hide and 0 or 1)
        if bar.EnableMouse and bar:IsMouseEnabled() == hide then bar:EnableMouse(not hide) end
    end
    barsHidden[container] = hide or nil
end

-- Hide This Bar under the client's dialog: a frame of ours on UIParent, never a child of the dialog's layout.
local hideBox
local function HideClick(self)
    local key = HideKey(hideBox.holder)
    if not (key and ns.db) then return end
    ns.db[key] = self:GetChecked() and true or false
    ns.ToggleChanged(key)
    B.WakeBars()
end

local function HideBox()
    hideBox = hideBox or ns.CheckPanel(190, "Hide this bar", HideClick)
    return hideBox
end

function B.FollowHideBox(dialog, holder)
    local key = HideKey(holder)
    if not key then
        if hideBox and hideBox:IsShown() then hideBox:Hide() end
        return
    end
    local box = HideBox()
    box.holder = holder
    ns.SetLevelIf(box, math.min(dialog:GetFrameLevel() + 20, 9000))
    if not ns.IsAt(box, "TOP", dialog, "BOTTOM", 0, 4) then ns.SetPointOnce(box, "TOP", dialog, "BOTTOM", 0, 4) end
    local want = ns.db and ns.db[key] == true or false
    if box.check:GetChecked() ~= want then box.check:SetChecked(want) end
    if not box:IsShown() then box:Show() end
end

