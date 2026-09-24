local _, ns = ...

-- While our Guild or Who tab is up, the client's friends window content steps aside;
-- our frames, the tabs and the close button stay.

-- The saved alpha is never 0: a piece another tab of ours had faded came back unseen (blank list).
local function StepAside(child, mark)
    if not child[mark] then
        child[mark] = true
        local was = child:GetAlpha()
        child.fcuiAlpha = (was and was > 0) and was or nil
        child.fcuiMouse = child.IsMouseEnabled and child:IsMouseEnabled()
    end
    ns.SetAlphaIf(child, 0)
    if child.EnableMouse and not InCombatLockdown() and child.IsMouseEnabled and child:IsMouseEnabled() then
        child:EnableMouse(false)
    end
end

-- Mouse only comes back out of combat.
local function StepBack(child, mark)
    child[mark] = nil
    child:SetAlpha(child.fcuiAlpha or 1)
    if child.EnableMouse and not InCombatLockdown() and child.fcuiMouse then child:EnableMouse(true) end
    child.fcuiAlpha, child.fcuiMouse = nil, nil
end

-- Title bar and inset stay, but the controls the client hangs in them (menu button, status line) go.
local function SweepInsideChild(child, mark, hide)
    local name = (child.GetName and child:GetName()) or ""
    if not name:find("ClassicUIForever", 1, true) then
        if hide then
            StepAside(child, mark)
        elseif child[mark] then
            StepBack(child, mark)
        end
    end
end

local function SweepInside(container, mark, hide)
    if not container or not container.GetChildren then return end
    ns.EachChild(container, SweepInsideChild, mark, hide)
end

-- Ours rewrite the title on every client update, including a click on a client tab,
-- so whichever of ours is closing puts the client's title back.
function ns.RestoreFriendsTitle()
    local title = FriendsFrameTitleText
    local host = FriendsFrame
    if not title or not host then return end
    local selected = host.selectedTab or (PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(host)) or 1
    local text
    -- No client who tab here and raid is tab 2: a missing FRIEND_TAB_WHO must not default to 2.
    if FRIEND_TAB_WHO and selected == FRIEND_TAB_WHO then
        text = WHO_LIST
    elseif selected == (FRIEND_TAB_RAID or 3) then
        text = RAID
    elseif selected == (FRIEND_TAB_QUICK_JOIN or 4) then
        text = QUICK_JOIN
    else
        local header = FriendsTabHeader
        local sub = header and header.GetTab and header:GetTab()
        if sub and header.recentAlliesTabID and sub == header.recentAlliesTabID then
            text = CONTACTS_RECENT_ALLIES_TITLE
        elseif sub and header.recruitAFriendTabID and sub == header.recruitAFriendTabID then
            text = RECRUIT_A_FRIEND
        else
            text = CONTACTS_LIST_TITLE or FRIENDS
        end
    end
    if text then title:SetText(text) end
end

-- EnableMouse(false) leaves children listening (the header's status drop down opened over
-- our lists): walk five levels down, never in combat.
local DeepMouseWalk
local function DeepMouseChild(child, key, off, depth)
    if off then
        if child.IsMouseEnabled and child:IsMouseEnabled() then
            child[key] = true
            child:EnableMouse(false)
        end
    elseif child[key] then
        child[key] = nil
        child:EnableMouse(true)
    end
    DeepMouseWalk(child, key, off, depth + 1)
end

DeepMouseWalk = function(frame, key, off, depth)
    if not frame or not frame.GetChildren or depth > 4 or InCombatLockdown() then return end
    ns.EachChild(frame, DeepMouseChild, key, off, depth)
end

local function DeepMouse(frame, mark, off)
    DeepMouseWalk(frame, mark .. "Mouse", off, 0)
end

local function SweepChild(child, host, mark, hide)
    local name = (child.GetName and child:GetName()) or ""
    -- Border, portrait, title bar and inset are the window; inside the last two is swept above.
    local keep = name:find("ClassicUIForever", 1, true) or name:find("FriendsFrameTab", 1, true)
        or child == host.CloseButton or child == host.PortraitContainer
        or child == host.NineSlice or child == host.TitleContainer or child == _G["FriendsFrameInset"]
    if not keep then
        if hide then
            -- Shown or not: the client raises its controls while our tab is open.
            StepAside(child, mark)
            if child == host.FriendsTabHeader then DeepMouse(child, mark, true) end
        elseif child[mark] then
            if child == host.FriendsTabHeader then DeepMouse(child, mark, false) end
            StepBack(child, mark)
        end
    end
end

function ns.SweepFriendsFrame(mark, hide)
    local host = FriendsFrame
    if not host or not host.GetChildren then return end
    -- The client puts the inset at -83 for friends, -60 otherwise; our floor is drawn for -83,
    -- so hold it there while ours is up (from the who tab it showed a dark band).
    local inset = _G["FriendsFrameInset"]
    if hide and inset and not InCombatLockdown() then
        local _, _, _, x, y = inset:GetPoint(1)
        if y and math.abs(y + 83) > 0.5 then
            inset:SetPoint("TOPLEFT", host, "TOPLEFT", x or 4, -83)
        end
    end
    SweepInside(host.TitleContainer, mark, hide)
    SweepInside(_G["FriendsFrameInset"], mark, hide)
    ns.EachChild(host, SweepChild, host, mark, hide)
end

-- The client raises its controls on its own schedule: re-swept by a watcher under each tab of ours, only while it shows.
function ns.KeepFriendsSwept(panel, mark)
    if not panel then return end
    ns.Sched.Attach(panel, { name = "friends.sweep", every = 0.25, fn = function() ns.SweepFriendsFrame(mark, true) end })
end

-- The client's opener appends to a half-typed line: empty the box, write "/w name " whole.
function ns.Whisper(name)
    if type(name) ~= "string" or name == "" then return end
    local box = (ChatEdit_ChooseBoxForSend and ChatEdit_ChooseBoxForSend(DEFAULT_CHAT_FRAME)) or ChatFrame1EditBox
    if not box then
        if ChatFrame_SendTell then ChatFrame_SendTell(name) end
        return
    end
    box:SetText("")
    if ChatEdit_ActivateChat then ChatEdit_ActivateChat(box) else box:Show() end
    box:SetText("/w " .. name .. " ")
    if box.SetCursorPosition and box.GetNumLetters then box:SetCursorPosition(box:GetNumLetters()) end
    box:SetFocus()
end
