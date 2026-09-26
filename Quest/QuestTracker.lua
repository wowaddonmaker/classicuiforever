local _, ns = ...

-- The 1.x quest watch look on the objective tracker: plain text, no header plates or glows.

local active = false
local hooked = false

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local SIZE_SECTION, SIZE_TITLE, SIZE_LINE = 12, 11, 10
-- Edit mode's Text Size (12 to 20) sets the client's line font; ours are the 1.x sizes at 12 and grow as much.
local CLIENT_BASE_SIZE = 12
local GOLD = { 1, 0.82, 0 }
local GREY = { 0.8, 0.8, 0.8 }
local WHITE = { 0.93, 0.93, 0.93 }
local GREEN = { 0.4, 0.75, 0.25 }
local HEADER_ART = { "Background", "Shine", "Glow" }
local SLOT_RING = { coords = { 0, 1, 0, 1 }, point = "CENTER", y = -1 }

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

local function Shadow(fontString)
    fontString:SetShadowColor(0, 0, 0, 1)
    fontString:SetShadowOffset(1, -1)
end

-- Skip SetFont only when our last write still reads back (secret reads count as changed).
local function SetFontIf(fontString, size)
    if fontString.fcuiFontSize == size then
        local font, height, flags = fontString:GetFont()
        if not ns.AnySecret(font, height, flags) and font == FONT and ns.Near(height, size, 0.01)
            and (flags == "" or flags == nil) then
            return
        end
    end
    fontString:SetFont(FONT, size, "")
    fontString.fcuiFontSize = size
end

local function SizeStep()
    local font = _G.ObjectiveTrackerLineFont
    if not font then return 0 end
    local _, height = font:GetFont()
    if type(height) ~= "number" or ns.IsSecret(height) then return 0 end
    return math.max(0, math.floor(height + 0.5) - CLIENT_BASE_SIZE)
end

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
    for _, key in ipairs(HEADER_ART) do
        local tex = header[key]
        if tex then
            ns.Fade(tex)
            -- The first-show animation restores alpha, so clear the texture; atlas kept for Restore.
            local atlas = tex.GetAtlas and tex:GetAtlas()
            if atlas then
                header.fcuiAtlas = header.fcuiAtlas or {}
                header.fcuiAtlas[key] = atlas
                tex:SetTexture(nil)
            end
        end
    end
    if header.Text then
        SetFontIf(header.Text, SIZE_SECTION + SizeStep())
        header.Text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        Shadow(header.Text)
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

-- Slot ring at 50/30 of the button's live size.
local function SkinItemButton(button)
    if not button or not ns.Once(button, "questItemSlot") then return end
    ns.DressStates(button, "slotNormal", "slotPushed")
    ns.Dress(button:GetNormalTexture(), nil, SLOT_RING, button, nil, nil,
        button:GetWidth() * 50 / 30, button:GetHeight() * 50 / 30)
end

-- Level and quest log colour; nil (gold, no prefix) when unknown or 0.
local function QuestLevelAndColor(block)
    local questID = block and block.id
    if type(questID) ~= "number" or not C_QuestLog or not C_QuestLog.GetQuestDifficultyLevel then return nil end
    local ok, level = pcall(C_QuestLog.GetQuestDifficultyLevel, questID)
    if not ok or type(level) ~= "number" or level <= 0 then return nil end
    return level, ns.QuestLevelColor(level)
end

-- Colour from the objective's own text, e.g. "3/5 Boars slain".
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

-- Runs after the client sets a block's title or line text.
local function StyleString(block, fontString, text, _, colorStyle)
    if not active or not fontString then return end
    Shadow(fontString)
    if fontString == block.HeaderText then
        SetFontIf(fontString, SIZE_TITLE + SizeStep())
        local level, r, g, b = QuestLevelAndColor(block)
        if level then
            fontString:SetTextColor(r, g, b)
            if text and not text:find("^%[") then
                fontString:SetText("[" .. level .. "] " .. text)
                -- Drop the prefix if it overflows the client's measured width.
                if fontString:GetStringWidth() > fontString:GetWidth() then fontString:SetText(text) end
            end
        else
            fontString:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        end
        return
    end
    local lineSize = SIZE_LINE + SizeStep()
    SetFontIf(fontString, lineSize)
    local line = fontString:GetParent()
    local dash = line and line.Dash
    if dash then
        SetFontIf(dash, lineSize)
        Shadow(dash)
    end
    local color = ProgressColor(text, colorStyle)
    if color then
        fontString:SetTextColor(color[1], color[2], color[3])
        if dash then dash:SetTextColor(color[1], color[2], color[3]) end
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
            if ns.Once(module, "trackerHooked") then
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

-- Map quest list background; owned by this toggle though the map pane fades the same texture.
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

-- Quest timer box: the 1.x dialog box and plate (bronze copies with the theme, like our dialogs); the client's when off.
local function PaintTimerBox()
    local frame = QuestTimerFrame
    if not frame then return end
    local classic = active
    ns.OldDialogBorder(frame.Border, classic)
    ns.OldDialogHeader(frame.Header, frame, classic)
end

local function Apply()
    active = true
    ns.WhenCalm("questTimer.look", PaintTimerBox)
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

-- Only the main header is restored; module headers need a reload.
local function Restore()
    active = false
    ns.WhenCalm("questTimer.look", PaintTimerBox)
    local header = ObjectiveTrackerFrame and ObjectiveTrackerFrame.Header
    if header then
        for _, key in ipairs(HEADER_ART) do
            ns.Unfade(header[key])
            local atlas = header.fcuiAtlas and header.fcuiAtlas[key]
            if atlas and header[key] and header[key].SetAtlas then header[key]:SetAtlas(atlas, true) end
        end
        if header.Text then header.Text:SetFontObject("ObjectiveTrackerHeaderFont") end
    end
    ns.needsReload = true
end

ns.RegisterModule("questTracker", { apply = Apply, restore = Restore })

------------------------------------------------------------------ the client's tracker hidden

-- For a tracker from another addon. Under a hidden parent of ours, not Hide(): the client shows its tracker on every
-- update. Only out of a fight (it holds secure quest item buttons); its own parent comes back when the option goes off.
local hideHolder, trackerParent

local function HideTracker()
    local tracker = ObjectiveTrackerFrame
    if not tracker or not (ns.db and ns.db.hideObjectiveTracker) then return end
    if not hideHolder then
        hideHolder = CreateFrame("Frame")
        hideHolder:Hide()
    end
    if tracker:GetParent() == hideHolder then return end
    trackerParent = tracker:GetParent()
    tracker:SetParent(hideHolder)
end

local function ShowTracker()
    local tracker = ObjectiveTrackerFrame
    if not tracker or not hideHolder or tracker:GetParent() ~= hideHolder then return end
    tracker:SetParent(trackerParent or UIParent)
end

local function HideApply()
    if not ObjectiveTrackerFrame then ns.MissingPiece("ObjectiveTrackerFrame") return end
    ns.WhenCalm("tracker.hidden", HideTracker)
end

local function HideRestore()
    ns.WhenCalm("tracker.hidden", ShowTracker)
end

ns.RegisterModule("hideObjectiveTracker", { apply = HideApply, restore = HideRestore })
