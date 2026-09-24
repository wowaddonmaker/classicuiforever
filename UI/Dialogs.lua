local _, ns = ...

-- Dialog kit: backdrops, header plate, drag, close X, popups, the client's popups, tooltips.
-- Helpers from later files are looked up at call time.

local EMPTY = ns.EMPTY
local ART = ns.ART
local ApplyColor = ns.ApplyColor
local type, pairs = type, pairs

ns.BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

local function Insets(l, r, t, b)
    return { left = l, right = r, top = t, bottom = b }
end

-- Read only: SetBackdrop keeps these by reference (BronzeBackdrop copies).
ns.BACKDROP = {
    DIALOG = { bgFile = ART.DIALOG_BG, edgeFile = ART.DIALOG_BORDER, tile = true, tileSize = 32, edgeSize = 32,
        insets = Insets(11, 12, 12, 11) },
    DIALOG_DARK = { bgFile = ART.DIALOG_BG_DARK, edgeFile = ART.DIALOG_BORDER, tile = true, tileSize = 32, edgeSize = 32,
        insets = Insets(11, 12, 12, 11) },
    -- The 1.x bind on pickup box.
    DIALOG_GOLD = { bgFile = ART.DIALOG_BG_GOLD, edgeFile = ART.DIALOG_BORDER_GOLD, tile = true, tileSize = 32, edgeSize = 32,
        insets = Insets(11, 12, 12, 11) },
    DIALOG_INSET8 = { bgFile = ART.DIALOG_BG, edgeFile = ART.DIALOG_BORDER, tile = true, tileSize = 32, edgeSize = 32,
        insets = Insets(8, 8, 8, 8) },
    TIP12 = { bgFile = ART.TIP_BG, edgeFile = ART.TIP_BORDER, tile = true, tileSize = 16, edgeSize = 12,
        insets = Insets(3, 3, 3, 3) },
    TIP14 = { bgFile = ART.TIP_BG, edgeFile = ART.TIP_BORDER, tile = true, tileSize = 16, edgeSize = 14,
        insets = Insets(3, 3, 3, 3) },
    TIP16 = { bgFile = ART.TIP_BG, edgeFile = ART.TIP_BORDER, tile = true, tileSize = 16, edgeSize = 16,
        insets = Insets(4, 4, 4, 4) },
    FLAT12 = { bgFile = ART.WHITE, edgeFile = ART.TIP_BORDER, tile = false, edgeSize = 12, insets = Insets(3, 3, 3, 3) },
}

-- Border-only dialog backdrop, one table per edge size.
local edges = {}
function ns.DialogEdge(edge)
    local info = edges[edge]
    if not info then
        local inset = edge / 4
        info = { edgeFile = ART.DIALOG_BORDER, edgeSize = edge, insets = Insets(inset, inset, inset, inset) }
        edges[edge] = info
    end
    return info
end

-- how: bronze = false stays silver, base = {r, g, b, a} border grey for BronzeBackdrop,
-- bg and border colours applied after it, bgFirst sets bg before it.
function ns.Backdrop(frame, info, how)
    if not frame or not frame.SetBackdrop then return false end
    how = how or EMPTY
    frame:SetBackdrop(info)
    local bg = how.bg
    if bg and how.bgFirst then ApplyColor(frame, "SetBackdropColor", bg) end
    if how.bronze ~= false then
        local base = how.base
        if base then
            ns.BronzeBackdrop(frame, base[1], base[2], base[3], base[4])
        else
            ns.BronzeBackdrop(frame)
        end
    end
    if bg and not how.bgFirst then ApplyColor(frame, "SetBackdropColor", bg) end
    if how.border then ApplyColor(frame, "SetBackdropBorderColor", how.border) end
    return true
end

-- Backdrop on our own child, never on the client's frame.
function ns.DialogBacking(host, info, how)
    local backing = CreateFrame("Frame", nil, host, ns.BACKDROP_TEMPLATE)
    ns.Backdrop(backing, info or ns.BACKDROP.DIALOG, how)
    backing:SetAllPoints(host)
    backing:SetFrameLevel(host:GetFrameLevel())
    return backing
end

-- how: width, own (OwnTexture key on owner), layer, sublevel,
-- restyle (font is the title, none made), fontObject, keepTitle (keep its anchor).
function ns.DialogHeader(host, text, how, owner, font)
    how = how or EMPTY
    owner = owner or host
    local layer, sublevel = how.layer or "ARTWORK", how.sublevel or 0
    local plate
    if how.own then
        plate = ns.OwnTexture(owner, how.own, layer, sublevel)
    else
        plate = owner:CreateTexture(nil, layer, nil, sublevel)
    end
    ns.SetFile(plate, ART.DIALOG_HEADER)
    plate:SetSize(how.width or 256, 64)
    plate:ClearAllPoints()
    plate:SetPoint("TOP", host, "TOP", 0, 12)
    plate:Show()
    local title
    if how.restyle then
        title = font
        if not title then return plate, nil end
        if how.fontObject then title:SetFontObject(how.fontObject) end
        if not how.keepTitle then
            title:ClearAllPoints()
            title:SetPoint("TOP", plate, "TOP", 0, -14)
        end
    else
        title = host:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", plate, "TOP", 0, -14)
    end
    if text ~= nil then title:SetText(text) end
    return plate, title
end

local weak = { __mode = "k" }
local oldBorders = setmetatable({}, weak)  -- client DialogBorderTemplate -> our old dialog box
local oldPlates = setmetatable({}, weak)   -- client DialogHeaderTemplate -> our old header plate
local HEADER_BG = { "LeftBG", "RightBG", "CenterBG" }
-- The old plate's ends beside the title; never narrower than the 1.x 256.
local PLATE_PAD, PLATE_MIN = 160, 256

-- Forever's diamond border and fill faded under our old dialog box; off puts them back.
-- info: another backdrop for the first dress (ns.DialogEdge when the host's own fill stays).
function ns.OldDialogBorder(border, on, info)
    if not border then return end
    local overlay = oldBorders[border]
    if not overlay then
        if not on then return end
        overlay = ns.DialogBacking(border, info)
        oldBorders[border] = overlay
    end
    overlay:SetShown(on)
    ns.FadeTextures(border, on and 0 or 1)
end

local function PlateWidth(title)
    local width = title and title:GetStringWidth()
    if type(width) ~= "number" or ns.IsSecret(width) then width = 0 end
    return math.max(PLATE_MIN, width + PLATE_PAD)
end

-- Forever's diamond header pieces faded under our old plate on host; the client's title stays.
-- Each call with on refits the plate to the title, for hosts that retitle it.
function ns.OldDialogHeader(header, host, on)
    if not header then return end
    local plate = oldPlates[header]
    if not plate then
        if not on then return end
        plate = ns.DialogHeader(host, nil,
            { layer = "BACKGROUND", restyle = true, keepTitle = true, width = PlateWidth(header.Text) },
            header, header.Text)
        oldPlates[header] = plate
    elseif on then
        local width = PlateWidth(header.Text)
        if plate:GetWidth() ~= width then plate:SetWidth(width) end
    end
    plate:SetShown(on)
    ns.FadeKeys(header, HEADER_BG, on and 0 or 1)
end

local function DragStop(self)
    self:StopMovingOrSizing()
    local after = self.fcuiDragStop
    if after then after(self) end
end

-- Our own frames only; onStop(frame) runs after the move ends.
function ns.MakeDraggable(frame, onStop)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame.fcuiDragStop = onStop
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", DragStop)
    frame:SetClampedToScreen(true)
end

function ns.DialogClose(frame, onClick, x, y)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", x or -6, y or -6)
    close:SetScript("OnClick", onClick)
    if ns.SkinCloseButton then ns.SkinCloseButton(close, true) end
    return close
end

---------------------------------------------------------------- popups

-- nil takes the default; false leaves the field off.
local POPUP_DEFAULTS = { timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3 }

-- Keep names: several files show these popups by name.
function ns.Popup(name, def)
    for field, value in pairs(POPUP_DEFAULTS) do
        if def[field] == nil then
            def[field] = value
        elseif def[field] == false then
            def[field] = nil
        end
    end
    StaticPopupDialogs[name] = def
    return def
end

-- Late lookup: ReloadForLayout is defined after the popups.
local function Reload() ns.ReloadForLayout() end

function ns.ReloadPopup(name, text, button1, button2)
    return ns.Popup(name, { text = text, button1 = button1 or "Reload now", button2 = button2 or "Later", OnAccept = Reload })
end

-------------------------------------------------------- client popups

-- StaticPopup1-4 (logout box, our reload prompts) in the old dialog box, on the game menu toggle.
-- Dressed at apply, never on their show path.
-- Their Layout counts the backing like BG (same rect, no size change): keep it all-points, no layout fields.
local POPUPS = { "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4" }
local POPUP_BUTTONS = { "Button1", "Button2", "Button3", "Button4" }
local CLIENT_BUTTON = "Interface\\Buttons\\UI-DialogBox-Button-"
-- The game menu's red buttons (bronze copy with the theme); the client's user-scaled fonts stay.
local RED_STATES = { set = "file", highlightSet = "raw", coords = { 0, 0.625, 0, 0.6875 }, fill = true, add = true }
-- GameDialog.xml's art; a file with no bronze copy drops out of the theme repaint.
local CLIENT_STATES = { set = "file", highlightSet = "raw", coords = { 0, 1, 0, 0.71875 }, fill = true, add = true }
local popupBackings = {}
local popupsDressed = false

local function PopupButton(button, art, how)
    if button then ns.DressStates(button, art .. "Up", art .. "Down", art .. "Disabled", art .. "Highlight", how) end
end

local function PopupButtons(popup, art, how)
    local container = popup.ButtonContainer
    if container then
        for i = 1, #POPUP_BUTTONS do PopupButton(container[POPUP_BUTTONS[i]], art, how) end
    end
    PopupButton(popup.ExtraButton, art, how)
end

local function DressPopup(popup)
    local backing = popupBackings[popup]
    if not backing then
        backing = ns.DialogBacking(popup)
        -- Fill under the client's progress bar (BACKGROUND -6, -5).
        if backing.Center then backing.Center:SetDrawLayer("BACKGROUND", -8) end
        popupBackings[popup] = backing
    end
    backing:Show()
    -- Forever's bronze diamond border and dark fill; only OnLoad sets them.
    ns.FadeTextures(popup.BG)
    PopupButtons(popup, ART.PANEL_BUTTON, RED_STATES)
end

local function UndressPopup(popup)
    local backing = popupBackings[popup]
    if backing then backing:Hide() end
    ns.FadeTextures(popup.BG, 1)
    PopupButtons(popup, CLIENT_BUTTON, CLIENT_STATES)
end

local function EachPopup(fn)
    for i = 1, #POPUPS do
        local popup = _G[POPUPS[i]]
        if popup then fn(popup) else ns.MissingPiece(POPUPS[i]) end
    end
end

-- Every pass calls these: work only on a change.
local function ApplyPopups()
    if popupsDressed then return end
    popupsDressed = true
    EachPopup(DressPopup)
end

local function RestorePopups()
    if not popupsDressed then return end
    popupsDressed = false
    EachPopup(UndressPopup)
end

ns.RegisterModule("gameMenu", { apply = ApplyPopups, restore = RestorePopups })

-------------------------------------------------------------- tooltips

local function HideTip() GameTooltip:Hide() end
ns.HideTip = HideTip

-- fcuiTip: { text or fn, r, g, b, anchor, when = fn, lines = { { text or fn, r, g, b, wrap } } }.
-- A nil text or false when shows nothing; a nil line is skipped.
local function ShowTip(self)
    local spec = self.fcuiTip
    if not spec or (spec.when and not spec.when(self)) then return end
    local text = spec.text
    if type(text) == "function" then text = text(self) end
    if text == nil then return end
    GameTooltip:SetOwner(self, spec.anchor or "ANCHOR_RIGHT")
    if spec.r ~= nil then GameTooltip:SetText(text, spec.r, spec.g, spec.b) else GameTooltip:SetText(text) end
    local lines = spec.lines
    if lines then
        for i = 1, #lines do
            local line = lines[i]
            local lineText = line[1]
            if type(lineText) == "function" then lineText = lineText(self) end
            if lineText ~= nil then GameTooltip:AddLine(lineText, line[2], line[3], line[4], line[5]) end
        end
    end
    GameTooltip:Show()
end
ns.ShowTip = ShowTip

-- Our own widgets only: replaces OnEnter and OnLeave.
function ns.AttachTip(widget, spec)
    widget.fcuiTip = spec
    widget:SetScript("OnEnter", ShowTip)
    widget:SetScript("OnLeave", HideTip)
end

function ns.SayNotInCombat()
    if UIErrorsFrame and ERR_NOT_IN_COMBAT then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1) end
end
