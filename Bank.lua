local _, ns = ...

-- The bank window in the old manner: the item and bag slots in the
-- old quickslot rings over the old dark holes, the marble floor under
-- them, the titles in gold, the modern shadows and divider gone, and
-- the banker in the portrait ring.

local QUICKSLOT = "Interface\\Buttons\\UI-Quickslot2"

-- The old ring around a slot, over the old hole; the client re-sets its
-- own atlases on every refresh, so the pieces go back on after each.
local function SlotArt(button)
    local normal = button:GetNormalTexture()
    if normal then
        normal:SetTexture(QUICKSLOT)
        normal:SetTexCoord(0, 1, 0, 1)
        normal:ClearAllPoints()
        local w = button:GetWidth()
        if not w or w < 1 then w = 37 end
        normal:SetSize(w * 64 / 37, w * 64 / 37)
        normal:SetPoint("CENTER", button, "CENTER", 0, -1)
    end
    local bg = button.Background
    if bg then
        ns.SetTex(bg, "bankParts")
        bg:SetTexCoord(0, 1, 0.5, 1)
        bg:ClearAllPoints()
        bg:SetAllPoints(button)
        bg:SetAlpha(1)
    end
end

local function SkinSlot(button)
    if not button or button.fcuiBankSlot then
        if button then SlotArt(button) end
        return
    end
    button.fcuiBankSlot = true
    SlotArt(button)
    -- After the client's own refresh, which puts its atlases back.
    if type(button.Refresh) == "function" then
        hooksecurefunc(button, "Refresh", SlotArt)
    end
    if type(button.UpdateBackgroundForBankType) == "function" then
        hooksecurefunc(button, "UpdateBackgroundForBankType", SlotArt)
    end
end

local function SkinSlots(panel)
    if not panel or not panel.itemButtonPool then return end
    for button in panel.itemButtonPool:EnumerateActive() do SkinSlot(button) end
end

local function SkinBagSlots(frame)
    if not frame.itemButtonBagPool then return end
    for button in frame.itemButtonBagPool:EnumerateActive() do SkinSlot(button) end
end

-- The banker in the ring. The client sets the portrait as the window
-- opens; when it did not, the ring showed its hole.
local function FillPortrait(frame)
    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    if not portrait or portrait:GetTexture() then return end
    if UnitExists("npc") then
        SetPortraitTexture(portrait, "npc")
    else
        SetPortraitTexture(portrait, "player")
    end
end

function ns.SkinBank(frame)
    if frame.fcuiBank then return end
    frame.fcuiBank = true
    local panel = frame.BankPanel
    -- The client's tiled stone, its divider and the panel's own inset
    -- border and corner shadows go; the marble floor goes under the
    -- slots where the panel's inset was.
    if frame.Background then frame.Background:SetAlpha(0) end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") and region.GetAtlas and region:GetAtlas() == "bank-divider" then
            region:SetAlpha(0)
        end
    end
    if panel then
        if panel.NineSlice then
            for _, region in ipairs({ panel.NineSlice:GetRegions() }) do
                if region:IsObjectType("Texture") then region:SetAlpha(0) end
            end
            local floor = ns.OwnTexture(frame, "insetFloor", "BACKGROUND", -1)
            floor:SetTexture(ns.TexPath("marbleBg"), "REPEAT", "REPEAT")
            floor:SetHorizTile(true)
            floor:SetVertTile(true)
            floor:SetTexCoord(0, 1, 0, 1)
            floor:ClearAllPoints()
            floor:SetPoint("TOPLEFT", panel.NineSlice, "TOPLEFT", 0, 0)
            floor:SetPoint("BOTTOMRIGHT", panel.NineSlice, "BOTTOMRIGHT", 0, 0)
            floor:Show()
        end
        if panel.EdgeShadows then panel.EdgeShadows:Hide() end
        if panel.PurchaseButton then ns.SkinRedButton(panel.PurchaseButton) end
        local money = panel.MoneyFrame
        if money then
            if money.WithdrawButton then ns.SkinRedButton(money.WithdrawButton) end
            if money.DepositButton then ns.SkinRedButton(money.DepositButton) end
        end
        SkinSlots(panel)
        ns.HookMethod(panel, "GenerateItemSlotsForSelectedTab", function(self) SkinSlots(self) end)
        ns.HookMethod(panel, "RefreshBankPanel", function(self) SkinSlots(self) end)
    end
    if frame.BagText then frame.BagText:SetFontObject(ns.FONT_GOLD) end
    if frame.BagCost then frame.BagCost:SetFontObject(ns.FONT_GOLD) end
    SkinBagSlots(frame)
    ns.HookMethod(frame, "RefreshBagButtons", SkinBagSlots)
    FillPortrait(frame)
    frame:HookScript("OnShow", FillPortrait)
end
