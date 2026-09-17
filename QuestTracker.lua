local _, ns = ...

-- The old quest watch look on Blizzard's objective tracker: plain text,
-- no header plates or glows. Section titles small and gold, quest titles
-- in the level colour with the level in front, objectives one size
-- smaller in grey that turns white as they progress and green when done.
-- The small stone collapse buttons and the parchment quest log stay.

local active = false
local hooked = false

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local SIZE_SECTION, SIZE_TITLE, SIZE_LINE = 12, 11, 10
local GOLD = { 1, 0.82, 0 }
local GREY = { 0.8, 0.8, 0.8 }
local WHITE = { 0.93, 0.93, 0.93 }
local GREEN = { 0.4, 0.75, 0.25 }

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

local function PlainHeader(header, collapsed, openKey, closedKey)
    if not header or not active then return end
    for _, key in ipairs({ "Background", "Shine", "Glow" }) do
        if header[key] then ns.Fade(header[key]) end
    end
    if header.Text then
        header.Text:SetFont(FONT, SIZE_SECTION, "")
        header.Text:SetTextColor(unpack(GOLD))
        header.Text:SetShadowColor(0, 0, 0, 1)
        header.Text:SetShadowOffset(1, -1)
    end
    if header.MinimizeButton then
        SetCollapseButton(header.MinimizeButton, openKey, closedKey, collapsed)
    end
end

local function SkinMainHeader(header)
    PlainHeader(header, ObjectiveTrackerFrame.isCollapsed, "headerOpen", "headerClosed")
end

local function SkinModuleHeader(header, collapsed)
    PlainHeader(header, collapsed, "moduleOpen", "moduleClosed")
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

-- The level colour for a quest block, the way the quest log colours it.
local function QuestLevelAndColor(block)
    local questID = block and block.id
    if type(questID) ~= "number" or not C_QuestLog or not C_QuestLog.GetQuestDifficultyLevel then return nil end
    local ok, level = pcall(C_QuestLog.GetQuestDifficultyLevel, questID)
    if not ok or type(level) ~= "number" or level <= 0 then return nil end
    local color = GetQuestDifficultyColor and GetQuestDifficultyColor(level)
    return level, color
end

-- Objective progress from its own text: "3/5 Boars slain".
local function ProgressColor(text, colorStyle)
    if colorStyle and colorStyle == OBJECTIVE_TRACKER_COLOR["Failed"] then return nil end
    local have, need = tostring(text or ""):match("^%s*(%d+)%s*/%s*(%d+)")
    if have and need then
        have, need = tonumber(have), tonumber(need)
        if need > 0 and have >= need then return GREEN end
        if have > 0 then return WHITE end
        return GREY
    end
    if colorStyle and colorStyle == OBJECTIVE_TRACKER_COLOR["Complete"] then return GREEN end
    return GREY
end

-- Runs after Blizzard sets any text on a block: the title or a line.
local function StyleString(block, fontString, text, _, colorStyle)
    if not active or not fontString then return end
    fontString:SetShadowColor(0, 0, 0, 1)
    fontString:SetShadowOffset(1, -1)
    if fontString == block.HeaderText then
        fontString:SetFont(FONT, SIZE_TITLE, "")
        local level, color = QuestLevelAndColor(block)
        if color then
            fontString:SetTextColor(color.r, color.g, color.b)
            if level and text and not text:find("^%[") then
                local shown = "[" .. level .. "] " .. text
                fontString:SetText(shown)
                -- Only when it still fits on the line Blizzard measured.
                if fontString:GetStringWidth() > fontString:GetWidth() then fontString:SetText(text) end
            end
        else
            fontString:SetTextColor(unpack(GOLD))
        end
        return
    end
    fontString:SetFont(FONT, SIZE_LINE, "")
    local line = fontString:GetParent()
    if line and line.Dash then
        line.Dash:SetFont(FONT, SIZE_LINE, "")
        line.Dash:SetShadowColor(0, 0, 0, 1)
        line.Dash:SetShadowOffset(1, -1)
    end
    local color = ProgressColor(text, colorStyle)
    if color then
        fontString:SetTextColor(unpack(color))
        if line and line.Dash then line.Dash:SetTextColor(unpack(color)) end
    end
end

local styledBlocks = setmetatable({}, { __mode = "k" })
local function SkinBlock(block)
    if not block or not active then return end
    SkinItemButton(block.ItemButton or block.itemButton)
    if styledBlocks[block] then return end
    styledBlocks[block] = true
    ns.HookMethod(block, "SetStringText", StyleString)
    if block.HeaderText then StyleString(block, block.HeaderText, block.HeaderText:GetText()) end
    if block.ForEachUsedLine then
        block:ForEachUsedLine(function(line)
            if line.Text then StyleString(block, line.Text, line.Text:GetText()) end
        end)
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
                ns.HookMethod(module, "AddBlock", function(_, block) SkinBlock(block) end)
            end
            if module.usedBlocks then
                for _, blocks in pairs(module.usedBlocks) do
                    for _, block in pairs(blocks) do SkinBlock(block) end
                end
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
        for _, key in ipairs({ "Background", "Shine", "Glow" }) do ns.Unfade(header[key]) end
        if header.Text then header.Text:SetFontObject("ObjectiveTrackerHeaderFont") end
    end
    ns.needsReload = true
end

ns.RegisterModule("questTracker", { apply = Apply, restore = Restore })
