local _, ns = ...

-- 1.x bank: gravel floor, gold slot titles, rings over dark holes, the old bag on
-- empty bag slots (red while unbought), no shadows or divider, banker in the ring.
-- The client resets its art on every refresh and show, so ours goes back after each.

local IsSecret, AnySecret = ns.IsSecret, ns.AnySecret
local FULL = { 0, 1, 0, 1 }
-- Raw path and full tint: the quickslot file, not the slotNormal key.
local QUICK_RING = { set = "raw", tint = true, coords = FULL, point = "CENTER", y = -1 }
local FLOOR_TILE = { tint = false, coords = FULL }

local Near = ns.panels.Near    -- WindowChrome.lua, loaded first

local ringFile   -- the ring's file as the client reports it once set

-- Our ring still intact (file, full coords, size, spot)? The client's refresh
-- lays its atlas back over it.
local function RingInPlace(normal, button, size)
    if ringFile == nil then return false end
    local atlas = normal:GetAtlas()
    if IsSecret(atlas) or (atlas ~= nil and atlas ~= "") then return false end
    local file = normal:GetTexture()
    if IsSecret(file) or file ~= ringFile then return false end
    local ulx, uly, llx, lly, urx, ury, lrx, lry = normal:GetTexCoord()
    if AnySecret(ulx, uly, llx, lly, urx, ury, lrx, lry) then return false end
    if not (ulx == 0 and uly == 0 and llx == 0 and lly == 1 and urx == 1 and ury == 0 and lrx == 1 and lry == 1) then return false end
    local w, h = normal:GetSize()
    if AnySecret(w, h) or type(w) ~= "number" or type(h) ~= "number" or not Near(w, size) or not Near(h, size) then return false end
    return ns.IsAt(normal, "CENTER", button, "CENTER", 0, -1) == true
end

-- Old ring over a near-black hole, as the 1.x sheet cut each slot.
local function SlotArt(button)
    local normal = button:GetNormalTexture()
    if normal then
        local w = button:GetWidth()
        if not w or w < 1 then w = 37 end
        local size = w * 64 / 37
        if RingInPlace(normal, button, size) then
            ns.BronzeTint(normal)
        else
            ns.Dress(normal, ns.ART.QUICKSLOT, QUICK_RING, button, nil, nil, size, size)
            if ringFile == nil then
                local file = normal:GetTexture()
                if file ~= nil and not IsSecret(file) then ringFile = file end
            end
        end
    end
    local bg = button.Background
    if bg then
        bg:SetColorTexture(0.06, 0.06, 0.06, 1)
        bg:ClearAllPoints()
        bg:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        bg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        bg:SetAlpha(1)
    end
end

local function SkinSlot(button)
    if not button then return end
    if not button.fcuiBankSlot then
        button.fcuiBankSlot = true
        -- After the client's refresh, which puts its atlases back.
        if type(button.Refresh) == "function" then
            hooksecurefunc(button, "Refresh", SlotArt)
        end
        if type(button.UpdateBackgroundForBankType) == "function" then
            hooksecurefunc(button, "UpdateBackgroundForBankType", SlotArt)
        end
    end
    SlotArt(button)
end

local function SkinSlots(panel)
    if not panel or not panel.itemButtonPool then return end
    for button in panel.itemButtonPool:EnumerateActive() do SkinSlot(button) end
end

-- Bag slot: old ring, no lock, old bag icon when empty, red while unbought.
local function BagArt(button)
    SlotArt(button)
    if button.DisabledOverlay then button.DisabledOverlay:Hide() end
    local icon = button.icon
    if not icon then return end
    local unbought = button.tooltipText == BANK_BAG_PURCHASE
    if unbought or not icon:GetTexture() then
        icon:SetTexture(ns.TexPath("bagSlotIcon"))
        icon:SetTexCoord(0, 1, 0, 1)
        icon:Show()
        if unbought then icon:SetVertexColor(1, 0.1, 0.1) else icon:SetVertexColor(1, 1, 1) end
    else
        icon:SetVertexColor(1, 1, 1)
    end
end

local function SkinBagSlot(button)
    if not button then return end
    if not button.fcuiBankBag then
        button.fcuiBankBag = true
        if type(button.SetItemButtonTexture) == "function" then
            hooksecurefunc(button, "SetItemButtonTexture", BagArt)
        end
    end
    BagArt(button)
end

local function SkinBagSlots(frame)
    if not frame.itemButtonBagPool then return end
    for button in frame.itemButtonBagPool:EnumerateActive() do SkinBagSlot(button) end
end

-- Banker portrait fallback: when the client skips it, the ring shows a hole.
local function FillPortrait(frame)
    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    if not portrait or portrait:GetTexture() then return end
    if UnitExists("npc") then
        SetPortraitTexture(portrait, "npc")
    else
        SetPortraitTexture(portrait, "player")
    end
end

-- Everything the client may put back; on skin and every show.
local function DressWindow(frame)
    local panel = frame.BankPanel
    if frame.Background then frame.Background:SetAlpha(0) end
    ns.FadeAtlas(frame, "bank-divider", true)
    if frame.fcui and frame.fcui.insetFloor then frame.fcui.insetFloor:Hide() end
    if panel then
        ns.FadeTextures(panel.NineSlice)
        if panel.EdgeShadows then panel.EdgeShadows:Hide() end
        -- Gravel over the whole inside of the metal, above the client's stone (1.x).
        local floor = ns.TileTex(ns.OwnTexture(frame, "bankFloor", "BACKGROUND", 1), "bankFloor", FLOOR_TILE)
        floor:ClearAllPoints()
        floor:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -20)
        floor:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
        floor:Show()
        if panel.PurchaseButton then ns.SkinRedButton(panel.PurchaseButton) end
        local money = panel.MoneyFrame
        if money then
            if money.WithdrawButton then ns.SkinRedButton(money.WithdrawButton) end
            if money.DepositButton then ns.SkinRedButton(money.DepositButton) end
        end
        -- "Item Slots" over the grid, as in 1.x.
        local title = frame.fcui and frame.fcui.itemSlotsTitle
        if not title then
            title = frame:CreateFontString(nil, "ARTWORK")
            title:SetFontObject(ns.FONT_GOLD)
            title:SetText(ITEMSLOTTEXT or "Item Slots")
            frame.fcui.itemSlotsTitle = title
        end
        title:ClearAllPoints()
        title:SetPoint("TOP", panel, "TOP", 0, -46)
        title:Show()
        SkinSlots(panel)
    end
    if frame.BagText then frame.BagText:SetFontObject(ns.FONT_GOLD) end
    if frame.BagCost then frame.BagCost:SetFontObject(ns.FONT_GOLD) end
    SkinBagSlots(frame)
    FillPortrait(frame)
end

function ns.SkinBank(frame)
    frame.fcui = frame.fcui or {}
    DressWindow(frame)
    if frame.fcuiBank then return end
    frame.fcuiBank = true
    local panel = frame.BankPanel
    if panel then
        ns.HookMethod(panel, "GenerateItemSlotsForSelectedTab", SkinSlots)
        ns.HookMethod(panel, "RefreshBankPanel", SkinSlots)
    end
    ns.HookMethod(frame, "RefreshBagButtons", SkinBagSlots)
    frame:HookScript("OnShow", DressWindow)
end
