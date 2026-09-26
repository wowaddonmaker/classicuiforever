local _, ns = ...

-- The pet view laid out as 1.x's pet tab (its PetPaperDollFrame numbers; the doll page stands where that frame did):
-- model, rotate buttons, happiness, stat boxes, and the XP bar in the old main bar art. The character view's model spot too.

local T = ns.sheet
local Take, Own, Fade = T.Take, T.Own, T.Fade

-- Character view model: 233 wide; with stat panes on it ends above them, or the feet run under the dropdowns.
local CHAR_MODEL_X = 65
local CHAR_MODEL_Y = -78
local CHAR_ATTRS_Y = -291
-- Pet view: the model, the rotate buttons from its top left, the happiness face under the first of them, the stat boxes,
-- and the XP bar from the page's bottom left.
local PET_MODEL_X = 25
local PET_MODEL_Y = -78
local PET_MODEL_W = 318
local PET_MODEL_H = 224
local PET_ROTATE_X = -2
local PET_ROTATE_Y = 2
local PET_HAPPY_X = 7
local PET_HAPPY_Y = 0
local PET_ATTRS_X = 67
local PET_ATTRS_Y = -300
local PET_XP_X = 23
local PET_XP_Y = 105
local PET_XP_W = 319
local PET_XP_H = 11
-- The resistance column's top right (the character view's stands at 297, -77), the Close button's centre and the
-- training points line's right end (from the page's bottom right), as the pet tab's footer art has them.
local PET_RES_X = 347
local PET_RES_Y = -77
local PET_CLOSE_X = 305
local PET_CLOSE_Y = -422
local PET_TP_X = -135
local PET_TP_Y = 86

-- The old XP border: two 160-wide halves of the main bar's XP strip, 13 tall over the 11 tall bar.
local XP_EDGE = { 0.203125, 0.8046875, 0.2890625, 0.33984375 }
local XP_PURPLE = { 0.58, 0, 0.55 }

local function XPEdge(bar, key, width)
    local tex = ns.OwnTexture(bar, key, "OVERLAY", 7)
    tex:SetDrawLayer("OVERLAY", 7)
    ns.SetTex(tex, "barBody")
    tex:SetTexCoord(unpack(XP_EDGE))
    tex:SetSize(width, 13)
    return Own(tex)
end

local function XPText(bar, shown)
    if bar.Text then bar.Text:SetAlpha(shown and 1 or 0) end
end

-- The client's pet XP bar in 1.x's dress; its OnUpdate sets the fill each frame from its width, so only the look is ours.
local function DressXP(bar, doll)
    Take(bar, "size", "points")
    bar:SetSize(PET_XP_W, PET_XP_H)
    ns.SetPointOnce(bar, "BOTTOMLEFT", doll, "BOTTOMLEFT", PET_XP_X, PET_XP_Y)
    -- The client's art goes; the fill and our border (textures on the same bar) stay.
    ns.EachTexture(bar, function(region)
        if region ~= bar.Fill and not ns.IsOwnRegion(bar, region) then Fade(region) end
    end)
    local fill = bar.Fill
    if fill then
        Take(fill, "art", "masks")
        if bar.Mask and fill.RemoveMaskTexture then pcall(fill.RemoveMaskTexture, fill, bar.Mask) end
        ns.SetTex(fill, "statusBar")
        fill:SetVertexColor(XP_PURPLE[1], XP_PURPLE[2], XP_PURPLE[3])
    end
    local left = XPEdge(bar, "xpEdgeLeft", 160)
    ns.SetPointOnce(left, "TOPLEFT", bar, "TOPLEFT", 0, 0)
    local right = XPEdge(bar, "xpEdgeRight", 159)
    ns.SetPointOnce(right, "LEFT", left, "RIGHT", 0, 0)
    left:Show()
    right:Show()
    -- 1.x showed the numbers only under the mouse.
    if bar.Text then Take(bar.Text, "alpha") end
    XPText(bar, bar:IsMouseOver())
    if ns.Once(bar, "petXPText") then
        bar:HookScript("OnEnter", function(self) if T.active then XPText(self, true) end end)
        bar:HookScript("OnLeave", function(self) if T.active then XPText(self, false) end end)
    end
end

-- Off the Character page the client's pet tab is not there to lie under Pet: a secure pad presses the character micro
-- button (which turns the open window to its Character page) and then that pet tab, in the client's name, one click.
-- Pads move out of combat only, so it hides as a fight starts; then Pet opens the Character page first, as before.
local PET_PAD_MACRO = "/click CharacterMicroButton\n/click PaperDollSidebarTab3"
local function PetPadMacro()
    local tab = T.petTab
    if not (T.active and tab and tab:IsVisible()) or (PaperDollFrame and PaperDollFrame:IsShown()) then return nil end
    return PET_PAD_MACRO
end

function T.PetPad(tab)
    if not (ns.MapPad and _G["CharacterMicroButton"] and PaperDollSidebarTab3) then return end
    ns.MapPad(tab, "HIGH", function() end, PetPadMacro)
end

-- The pet tab's own lower half over the shared one (where that one stands on this page), with its footer: training points
-- at the left, Close at the right. Shown in the pet view only.
local footer
local function TrainingPoints()
    local get = _G["GetPetTrainingPoints"]
    if type(get) ~= "function" then return nil end
    local ok, total, spent = pcall(get)
    if not ok or type(total) ~= "number" or ns.IsSecret(total) then return nil end
    return total - (type(spent) == "number" and not ns.IsSecret(spent) and spent or 0)
end

local function CloseClick()
    if HideUIPanel and CharacterFrame then HideUIPanel(CharacterFrame) end
end

local function Footer(doll)
    if footer then return footer end
    footer = {}
    footer.left = ns.OwnTexture(doll, "petBotLeft", "BACKGROUND", -1)
    ns.SetTex(footer.left, "petBotLeft")
    footer.left:SetSize(256, 256)
    ns.SetPointOnce(footer.left, "TOPLEFT", doll, "TOPLEFT", 2, -257)
    footer.right = ns.OwnTexture(doll, "petBotRight", "BACKGROUND", -1)
    ns.SetTex(footer.right, "petBotRight")
    footer.right:SetSize(128, 256)
    ns.SetPointOnce(footer.right, "TOPLEFT", doll, "TOPLEFT", 258, -257)
    footer.close = ns.PanelButton(doll, CLOSE or "Close", 80)
    footer.close:SetHeight(22)
    footer.close:SetScript("OnClick", CloseClick)
    footer.value = ns.OwnFontString(doll, "petTrainingValue", "ARTWORK", "GameFontHighlightSmall")
    footer.label = ns.OwnFontString(doll, "petTrainingLabel", "ARTWORK", "GameFontNormalSmall")
    footer.label:SetText(((TRAINING_POINTS or "Training Points: %s"):gsub("%s*%%s", "")))
    ns.SetPointOnce(footer.label, "RIGHT", footer.value, "LEFT", -5, 0)
    ns.EventFrame("UNIT_PET_TRAINING_POINTS", function()
        if footer.value:IsVisible() then footer.value:SetText(TrainingPoints() or "") end
    end, "player", "pet")
    return footer
end

local function PlaceFooter(doll, pet)
    if not pet and not footer then return end
    local f = Footer(doll)
    -- Only a number: off the pet view, or on a client without them, no line at all.
    local points = pet and TrainingPoints() or nil
    for _, piece in ipairs({ f.left, f.right, f.close }) do ns.SetShownIf(Own(piece), pet) end
    ns.SetShownIf(Own(f.value), points ~= nil)
    ns.SetShownIf(Own(f.label), points ~= nil)
    if not pet then return end
    ns.SetPointOnce(f.close, "CENTER", doll, "TOPLEFT", PET_CLOSE_X, PET_CLOSE_Y)
    ns.SetPointOnce(f.value, "BOTTOMRIGHT", doll, "BOTTOMRIGHT", PET_TP_X, PET_TP_Y)
    if points then f.value:SetText(points) end
end

-- Every layout: the model, rotate buttons and stat boxes for the view up; the pet pieces in the pet view.
function T.PlaceModel(doll, pet)
    local scene = CharacterModelScene
    if not scene then return end
    Take(scene, "size", "points")
    if pet then
        ns.SetPointOnce(scene, "TOPLEFT", doll, "TOPLEFT", PET_MODEL_X, PET_MODEL_Y)
        ns.SetSizeIf(scene, PET_MODEL_W, PET_MODEL_H)
    else
        ns.SetPointOnce(scene, "TOPLEFT", doll, "TOPLEFT", CHAR_MODEL_X, CHAR_MODEL_Y)
        ns.SetSizeIf(scene, 233, (ns.db and ns.db.statPanes) and 213 or 224)
    end
    T.FitModelCamera()
    if T.rotateRight then
        ns.SetPointOnce(T.rotateRight, "TOPLEFT", scene, "TOPLEFT", pet and PET_ROTATE_X or 0, pet and PET_ROTATE_Y or 0)
    end
    if T.attrs then
        ns.SetPointOnce(T.attrs, "TOPLEFT", doll, "TOPLEFT", pet and PET_ATTRS_X or 67, pet and PET_ATTRS_Y or CHAR_ATTRS_Y)
    end
    local column = T.resistances and T.resistances[1] and T.resistances[1]:GetParent()
    if column then
        ns.SetPointOnce(column, "TOPRIGHT", doll, "TOPLEFT", pet and PET_RES_X or 297, pet and PET_RES_Y or -77)
    end
    PlaceFooter(doll, pet)
    T.PetStatRows(pet)
    -- The client leaves its happiness face up on the character view too.
    local happy = _G["PetPaperDollPetHappinessInfo"]
    if happy then
        Take(happy, "alpha", "mouse")
        ns.SetAlphaIf(happy, pet and 1 or 0)
        if happy:IsMouseEnabled() ~= pet then happy:EnableMouse(pet) end
    end
    if not pet then return end
    if happy and T.rotateRight then
        Take(happy, "points")
        ns.SetPointOnce(happy, "TOPLEFT", T.rotateRight, "BOTTOMLEFT", PET_HAPPY_X, PET_HAPPY_Y)
    end
    local xp = _G["PetPaperDollFrameExpBar"]
    if xp then DressXP(xp, doll) end
end
