local _, ns = ...

-- The 1.x objective tracker look on Blizzard's tracker: the old stone
-- module headers, the small quest tracker collapse buttons, and the
-- parchment quest log background where the client still has it.

local active = false
local hooked = false

local SHEET_COORDS = {
    headerOpen = { 0.140625, 0.257812, 0.546875, 0.765625 },
    headerOpenPushed = { 0.0078125, 0.125, 0.546875, 0.765625 },
    headerClosed = { 0.273438, 0.390625, 0.765625, 0.984375 },
    headerClosedPushed = { 0.273438, 0.390625, 0.515625, 0.734375 },
    moduleOpen = { 0.273438, 0.390625, 0.265625, 0.484375 },
    moduleOpenPushed = { 0.273438, 0.390625, 0.015625, 0.234375 },
    moduleClosed = { 0.40625, 0.523438, 0.265625, 0.484375 },
    moduleClosedPushed = { 0.40625, 0.523438, 0.015625, 0.234375 },
}

local function SetCollapseButton(button, openKey, closedKey, collapsed)
    if not button then return end
    ns.SetButtonTex(button, "Normal", "questTrackerButtons")
    ns.SetButtonTex(button, "Pushed", "questTrackerButtons")
    local normal, pushed = button:GetNormalTexture(), button:GetPushedTexture()
    local key = collapsed and closedKey or openKey
    if normal then normal:SetTexCoord(unpack(SHEET_COORDS[key])) end
    if pushed then pushed:SetTexCoord(unpack(SHEET_COORDS[key .. "Pushed"])) end
    button:SetSize(15, 14)
end

local function SkinMainHeader(header)
    if not header or not active then return end
    if header.Background then ns.Fade(header.Background) end
    if header.Text then ns.Fade(header.Text) end
    local title = ns.OwnFontString(header, "title", "ARTWORK", "GameFontNormal")
    title:SetText(OBJECTIVES_TRACKER_LABEL or "Objectives")
    if header.MinimizeButton then
        ns.SetPointOnce(header.MinimizeButton, "RIGHT", header, "RIGHT", -10, 3)
        ns.SetPointOnce(title, "RIGHT", header.MinimizeButton, "LEFT", -3, 0)
        SetCollapseButton(header.MinimizeButton, "headerOpen", "headerClosed", ObjectiveTrackerFrame.isCollapsed)
    end
    title:SetShown(ObjectiveTrackerFrame.isCollapsed and true or false)
end

local function SkinModuleHeader(header, collapsed)
    if not header or not active then return end
    if header.Background then
        header.Background:SetAtlas("Objective-Header", true)
        ns.SetPointOnce(header.Background, "TOPLEFT", header, "TOPLEFT", -19, 14)
    end
    if header.Text then ns.SetPointOnce(header.Text, "LEFT", header, "LEFT", 14, 0) end
    if header.MinimizeButton then
        ns.SetPointOnce(header.MinimizeButton, "RIGHT", header, "RIGHT", -35, 0)
        SetCollapseButton(header.MinimizeButton, "moduleOpen", "moduleClosed", collapsed)
    end
end

local function SkinItemButton(button)
    if not button or button.fcuiSkinned then return end
    button.fcuiSkinned = true
    ns.SetButtonTex(button, "Normal", "slotNormal")
    ns.SetButtonTex(button, "Pushed", "slotPushed")
    local normal = button:GetNormalTexture()
    if normal then
        normal:SetTexCoord(0, 1, 0, 1)
        normal:ClearAllPoints()
        normal:SetPoint("CENTER", button, "CENTER", 0, -1)
        normal:SetSize(button:GetWidth() * 50 / 30, button:GetHeight() * 50 / 30)
    end
end

local function SkinModules()
    local tracker = ObjectiveTrackerFrame
    if not tracker or not tracker.modules then return end
    for _, module in ipairs(tracker.modules) do
        if module.Header then
            SkinModuleHeader(module.Header, module.Header.isCollapsed or tracker.isCollapsed)
            if not module.fcuiHooked then
                module.fcuiHooked = true
                ns.HookMethod(module.Header, "SetCollapsed", function(self, collapsed)
                    SkinModuleHeader(self, collapsed)
                end)
                ns.HookMethod(module, "AddBlock", function(_, block)
                    if active and block then
                        SkinItemButton(block.ItemButton or block.itemButton)
                    end
                end)
            end
        end
    end
end

local function SkinQuestLog()
    if not QuestScrollFrame then return end
    local function Background(self)
        if not active or not self.Background then return end
        local atlas = self.Background:GetAtlas()
        if atlas == "QuestLog-main-background" then
            self.Background:SetAtlas("QuestLogBackground")
        elseif atlas == "QuestLog-empty-quest-background" then
            self.Background:SetAtlas("NoQuestsBackground")
        end
    end
    ns.HookMethod(QuestScrollFrame, "UpdateBackground", Background)
    Background(QuestScrollFrame)
end

local function Apply()
    active = true
    if not ObjectiveTrackerFrame then ns.MissingPiece("ObjectiveTrackerFrame") return end
    SkinMainHeader(ObjectiveTrackerFrame.Header)
    SkinModules()
    SkinQuestLog()
    if not hooked then
        hooked = true
        if ObjectiveTrackerFrame.Header then
            ns.HookMethod(ObjectiveTrackerFrame.Header, "SetCollapsed", function(self) SkinMainHeader(self) end)
        end
        ns.HookMethod(ObjectiveTrackerFrame, "Update", function() if active then SkinModules() end end)
    end
end

local function Restore()
    active = false
    local header = ObjectiveTrackerFrame and ObjectiveTrackerFrame.Header
    if header then
        ns.Unfade(header.Background)
        ns.Unfade(header.Text)
        if header.fcui and header.fcui.title then header.fcui.title:Hide() end
    end
    ns.needsReload = true
end

ns.RegisterModule("questTracker", { apply = Apply, restore = Restore })
