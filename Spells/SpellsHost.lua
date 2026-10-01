local _, ns = ...

-- Gamepad on at login: the classic spellbook and talents stand inside the game's spell window (PlayerSpellsFrame), one
-- per tab. The game opens, navigates and closes that window, so nothing of ours runs in its focus.
-- A view: frame and close (its X, under the window's own), game (that tab's frame), tab, clicks (secure layer), on().

local host
local pending = false
local views = {}
local art = {}         -- the window's own pieces -> the alpha they had
local artTaken = false
local closeSpot        -- the window's close button anchor, for the game's own pages

local function Say(text)
    if UIErrorsFrame then UIErrorsFrame:AddMessage(text, 1, 0.82, 0) end
end

-- Within: frame is piece or one of its children.
local function Within(frame, piece)
    while frame do
        if frame == piece then return true end
        frame = frame:GetParent()
    end
    return false
end

local function OnTab(view)
    local tabs = PlayerSpellsUtil and PlayerSpellsUtil.FrameTabs
    return host:IsShown() and tabs and host:IsFrameTabActive(tabs[view.tab]) or false
end

-- The view the window's shown tab holds, if its module is on.
local function LiveView()
    for _, view in ipairs(views) do
        if view.frame:IsShown() and view.on() and OnTab(view) then return view end
    end
end

------------------------------------------------------------ the gamepad keys

-- The game's own pick for a spell it teaches, never an override bar but its stance bar.
local PROBE = { IsSlotPending = function() return false end }
local function FreeBarSlot()
    local tracker = GamepadIconIntroTrackerMixin
    if not (tracker and tracker.FindFreeVisibleSlot and GamepadMainActionBarFrame) then return nil end
    local ok, slot = pcall(tracker.FindFreeVisibleSlot, PROBE)
    return ok and slot or nil
end

-- X on a spell: onto the first free gamepad bar slot the game would give it. Y (edit bars) moves it after.
local function AddToBar(btn)
    if InCombatLockdown() then return Say(ERR_NOT_IN_COMBAT) end
    local slot = FreeBarSlot()
    if not slot then return Say("No free gamepad bar slot on this page.") end
    ClearCursor()
    if not ns.SpellBookPickUp(btn) then return end
    PlaceAction(slot)
    local held = GetCursorInfo()
    ClearCursor()
    if held then return Say("That spell cannot go on the gamepad bar.") end
    PlaySound(SOUNDKIT.IG_ABILITY_ICON_DROP)
    Say("Added to the gamepad bar. Y moves it.")
end

-- The window's footers own the face buttons and act on the game's own pieces; these run after the game's press and
-- pass it to the live view (view.pads[key](current)), which says whether it took it.
local function Pass(key)
    return function(_, _, down)
        if not down or not SmartNavigation then return end
        local view = LiveView()
        local act = view and view.pads and view.pads[key]
        local current = act and SmartNavigation:GetCurrentButton()
        if current and Within(current, view.frame) or (current and view.clicks and Within(current, view.clicks)) then
            act(current)
        end
    end
end

local function HookPads()
    for _, key in ipairs({ "FACE_BOTTOM", "FACE_LEFT", "FACE_TOP" }) do
        local pad = _G["GAMEPAD_" .. key]
        if pad then ns.HookScriptOnce(_G["InputFunctionBindingButton_" .. pad], "PostClick", Pass(key)) end
    end
end

-- A plain piece of ours: secure ones would refuse a click from here, and the search box takes typing, not presses.
local function PressPlain(current, mouse)
    if current:IsProtected() or not current.Click or not current:IsEnabled() then return end
    current:Click(mouse)
end

------------------------------------------------------------------ syncing

local function FadeArt(faded)
    for piece, alpha in pairs(art) do piece:SetAlpha(faded and 0 or alpha) end
end

-- The window's close button stands on the live view's X, or goes home.
local function PlaceClose(view)
    local close = host.CloseButton
    if not close then return end
    if view then
        ns.SetPointOnce(close, "CENTER", view.close, "CENTER", 0, 0)
        ns.SetLevelIf(close, view.frame:GetFrameLevel() + 10)
    elseif closeSpot then
        ns.SetPointOnce(close, closeSpot[1], closeSpot[2], closeSpot[3], closeSpot[4], closeSpot[5])
    end
end

-- Each view shows on its own tab; with the window shut, all stay up so its read on opening finds them. A secure layer
-- (view.clicks) moves only out of combat: up in a fight, its view stays up with it.
local function Sync()
    local shown = host:IsShown()
    local fight = InCombatLockdown()
    for _, view in ipairs(views) do
        local want = view.on() and (OnTab(view) or not shown)
        if view.clicks then
            if not fight then view.clicks:SetShown(want) end
            want = want or (view.clicks:IsShown() and view.on())
        end
        if not fight or not view.frame:IsProtected() then view.frame:SetShown(want) end
    end
    local live = LiveView()
    -- The window spans the screen's middle: with ours up, its own body would take the world's clicks.
    if not fight then host:EnableMouse(live == nil) end
    if shown then HookPads() end
    FadeArt(live ~= nil)
    PlaceClose(live)
    if live and live.game and live.game:IsShown() then live.game:Hide() end
    if live and live.refresh then live.refresh() end
end

local function TakePiece(piece, keep)
    if not keep[piece] then art[piece] = piece:GetAlpha() end
end

-- The window's own pieces, faded under ours: all but the tab frames, the footers' prompts and our views.
local function TakeArt()
    if artTaken then return end
    artTaken = true
    local keep = { [host.CloseButton or host] = true, [host.SpellBookFrame or host] = true,
        [host.TalentsFrame or host] = true, [host.SpecFrame or host] = true }
    for _, name in ipairs({ "spellsFrameFooter", "classTalentsFrameFooter" }) do
        local footer = host[name]
        if footer and footer.inputLegend then keep[footer.inputLegend] = true end
    end
    for _, view in ipairs(views) do
        keep[view.frame] = true
        if view.clicks then keep[view.clicks] = true end
    end
    ns.EachRegion(host, TakePiece, keep)
    ns.EachChild(host, TakePiece, keep)
    if host.CloseButton then closeSpot = { host.CloseButton:GetPoint(1) } end
    ns.HookScriptOnce(host, "OnShow", Sync)
    ns.HookMethod(host, "SetTab", Sync)
end

-- Out of combat: a view joins the window before it ever opens, so the window's read finds it.
local function MoveIn(view)
    view.frame:SetParent(host)
    ns.SetPointOnce(view.frame, "TOPLEFT", host, "TOPLEFT", 0, 0)
    ns.SetLevelIf(view.frame, host:GetFrameLevel() + 20)
    -- On the window, never on the view: a secure frame anchored to the view would protect it.
    if view.clicks then
        view.clicks:SetParent(host)
        ns.SetPointOnce(view.clicks, "TOPLEFT", host, "TOPLEFT", 0, 0)
    end
    view.close:Hide()
    views[#views + 1] = view
end

------------------------------------------------------------------- views

local function BookView()
    local book = ns.SpellBookBuilt and ns.SpellBookBuilt()
    if not book or not book.Clicks or not book.Clicks.fcuiLinked then return nil end
    return {
        key = "book", frame = book, clicks = book.Clicks, close = book.Close, game = host.SpellBookFrame,
        tab = "SpellBook", on = ns.SpellBookActive, refresh = function() book:Refresh() end,
        pads = {
            -- A spell casts through its own binding (SpellBook.lua PAD_PICK).
            FACE_BOTTOM = function(current) if Within(current, book) then PressPlain(current) end end,
            FACE_LEFT = function(current) if Within(current, book.Clicks) then AddToBar(current) end end,
        },
    }
end

-- The talents footer's A already clicks a piece that is no talent of its own (ours): Y alone is passed, as a refund.
local function TalentsView()
    local frame = ns.TalentsBuilt and ns.TalentsBuilt()
    if not frame then return nil end
    return {
        key = "talents", frame = frame, close = frame.close, game = host.TalentsFrame,
        tab = "ClassTalents", on = ns.TalentsActive, refresh = ns.TalentsRefresh,
        pads = { FACE_TOP = function(current) if current.talent then PressPlain(current, "RightButton") end end },
    }
end

local function Has(key)
    for _, view in ipairs(views) do
        if view.key == key then return true end
    end
    return false
end

function ns.HostSpellsWindow()
    if ns.padSession ~= true then return end
    host = PlayerSpellsFrame
    -- The window loads on demand: its ADDON_LOADED calls again.
    if not host then return end
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    local added = false
    for key, make in pairs({ book = BookView, talents = TalentsView }) do
        local view = not Has(key) and make()
        if view then
            MoveIn(view)
            added = true
        end
    end
    -- Art is read once, after the first view is in.
    if added then TakeArt() end
    if #views > 0 then Sync() end
end

ns.EventFrame({ "ADDON_LOADED", "PLAYER_REGEN_ENABLED" }, function(_, event, name)
    if event == "ADDON_LOADED" and name ~= "Blizzard_PlayerSpells" then return end
    if event == "PLAYER_REGEN_ENABLED" and not pending then return end
    ns.HostSpellsWindow()
end)
