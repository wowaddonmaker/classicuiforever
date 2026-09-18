-- The quest pane the map opens on its right, in the manner of the 1.x
-- quest log: the list on the dark floor with plus and minus headers,
-- yellow titles in the 1.x difficulty colours and the old check for a
-- tracked quest; a quest's details on the old parchment in the parchment
-- ink. Blizzard's rows, pools and quest text stay theirs; their modern
-- art is faded and ours laid under.
local _, ns = ...

local PARCHMENT_INK = { 0.18, 0.12, 0.06 }
local PLUS = "Interface\\Buttons\\UI-PlusButton-Up"
local MINUS = "Interface\\Buttons\\UI-MinusButton-Up"
local PLUS_GLOW = "Interface\\Buttons\\UI-PlusButton-Hilight"
local CHECK_BOX = "Interface\\Buttons\\UI-CheckBox-Up"
local CHECK_MARK = "Interface\\Buttons\\UI-CheckBox-Check"
local CHECK_GLOW = "Interface\\Buttons\\UI-CheckBox-Highlight"

local active = false
local built = false
local floorTex, parchmentTex

local function FadeTextures(frame)
    if not frame or not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then region:SetAlpha(0) end
    end
end

------------------------------------------------------------------ list rows

-- A header: the old plus or minus at its left, its name in the old
-- yellow, Blizzard's bar and arrow faded.
local function Collapsed(button)
    if button.info and button.info.isCollapsed ~= nil then return button.info.isCollapsed end
    if button.questLogIndex and C_QuestLog and C_QuestLog.GetInfo then
        local info = C_QuestLog.GetInfo(button.questLogIndex)
        if info then return info.isCollapsed end
    end
    return false
end

local function SkinHeader(button)
    if not button.fcuiHeader then
        button.fcuiHeader = true
        FadeTextures(button)
        local normal = button:GetNormalTexture()
        if normal then normal:SetAlpha(0) end
        local hl = button:GetHighlightTexture()
        if hl then hl:SetAlpha(0) end
        if button.CollapseButton then
            button.CollapseButton:SetAlpha(0)
            button.CollapseButton:EnableMouse(false)
        end
        local icon = ns.OwnTexture(button, "collapseIcon", "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("LEFT", button, "LEFT", 4, 0)
        local glow = ns.OwnTexture(button, "collapseGlow", "HIGHLIGHT")
        glow:SetTexture(PLUS_GLOW)
        glow:SetBlendMode("ADD")
        glow:SetSize(16, 16)
        glow:SetPoint("LEFT", button, "LEFT", 4, 0)
        local text = button.ButtonText or button:GetFontString()
        if text then
            text:SetFontObject("GameFontNormal")
            text:ClearAllPoints()
            text:SetPoint("LEFT", button, "LEFT", 24, 0)
            text:SetPoint("RIGHT", button, "RIGHT", -4, 0)
        end
        button:SetNormalFontObject("GameFontNormal")
        button:SetHighlightFontObject("GameFontHighlight")
    end
    local icon = button.fcui and button.fcui.collapseIcon
    if icon then
        icon:SetTexture(Collapsed(button) and PLUS or MINUS)
        icon:SetVertexColor(1, 1, 1)
    end
    -- Blizzard recolours the name with every update.
    local text = button.ButtonText or button:GetFontString()
    if text then text:SetTextColor(1, 0.82, 0) end
end

-- A quest: the 1.x difficulty colour, the old highlight across the row,
-- the old check box, the modern storyline and task icons faded.
local function TitleColor(button)
    local level = button.info and button.info.difficultyLevel
    if not level and button.questID and C_QuestLog and C_QuestLog.GetQuestDifficultyLevel then
        level = C_QuestLog.GetQuestDifficultyLevel(button.questID)
    end
    if level and ns.QuestLevelColor then return ns.QuestLevelColor(level) end
    return 1, 0.82, 0
end

local function ColorTitle(button)
    if not active then return end
    local r, g, b = TitleColor(button)
    if button.Text then button.Text:SetTextColor(r, g, b) end
    if button.TagText then button.TagText:SetTextColor(r, g, b) end
end

local function SkinTitle(button)
    if not button.fcuiTitle then
        button.fcuiTitle = true
        if button.StorylineTexture then button.StorylineTexture:SetAlpha(0) end
        if button.TaskIcon then button.TaskIcon:SetAlpha(0) end
        if button.HighlightTexture then
            local hl = button.HighlightTexture
            ns.SetTex(hl, "questLogHighlight")
            hl:SetTexCoord(0, 1, 0, 1)
            hl:SetBlendMode("ADD")
            hl:ClearAllPoints()
            hl:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -2)
            hl:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 2)
        end
        local box = button.Checkbox
        if box then
            for _, region in ipairs({ box:GetRegions() }) do
                if region:IsObjectType("Texture") then
                    if region == box.CheckMark then
                        region:SetTexture(CHECK_MARK)
                    elseif region:GetDrawLayer() == "HIGHLIGHT" then
                        region:SetTexture(CHECK_GLOW)
                        region:SetBlendMode("ADD")
                    else
                        region:SetTexture(CHECK_BOX)
                    end
                    region:SetTexCoord(0, 1, 0, 1)
                end
            end
        end
        -- Blizzard puts its own colour back when the mouse leaves.
        button:HookScript("OnLeave", ColorTitle)
    end
    ColorTitle(button)
end

local function SkinRows()
    if not active or not QuestScrollFrame then return end
    if QuestScrollFrame.headerFramePool then
        for button in QuestScrollFrame.headerFramePool:EnumerateActive() do SkinHeader(button) end
    end
    if QuestScrollFrame.titleFramePool then
        for button in QuestScrollFrame.titleFramePool:EnumerateActive() do SkinTitle(button) end
    end
end

------------------------------------------------------------------ details

-- Every line of quest text on the parchment takes the parchment ink;
-- the reward buttons keep their own item names.
local function InkFontStrings(frame)
    if not frame then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("FontString") then region:SetTextColor(unpack(PARCHMENT_INK)) end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        if not child:IsObjectType("Button") then InkFontStrings(child) end
    end
end

local function SkinDetails()
    if not active or not QuestMapFrame then return end
    local details = QuestMapFrame.DetailsFrame
    if not details then return end
    if not details.fcuiSkinned then
        details.fcuiSkinned = true
        if details.Bg then details.Bg:SetAlpha(0) end
        FadeTextures(details.BorderFrame)
        FadeTextures(details.BackFrame)
        local rewards = details.RewardsFrameContainer and details.RewardsFrameContainer.RewardsFrame
        if rewards then
            for _, key in ipairs({ "Top", "Bottom", "Background" }) do
                if rewards[key] then rewards[key]:SetAlpha(0) end
            end
        end
    end
    if details.ScrollFrame then InkFontStrings(details.ScrollFrame.Contents) end
    local rewards = details.RewardsFrameContainer and details.RewardsFrameContainer.RewardsFrame
    if rewards then InkFontStrings(rewards) end
end

------------------------------------------------------------------ chrome

local function Build()
    if built or not QuestMapFrame then return end
    built = true
    local quests = QuestMapFrame.QuestsFrame
    local scroll = quests and quests.ScrollFrame
    -- The pane's floor: the dark stone of the old list, under everything.
    floorTex = ns.OwnTexture(QuestMapFrame, "floor", "BACKGROUND", -3)
    floorTex:SetTexture(ns.TexPath("rockBg"), "REPEAT", "REPEAT")
    floorTex:SetHorizTile(true)
    floorTex:SetVertTile(true)
    floorTex:SetAllPoints(QuestMapFrame)
    if scroll then
        if scroll.Background then scroll.Background:SetAlpha(0) end
        if scroll.Edge then scroll.Edge:SetAlpha(0) end
        FadeTextures(scroll.BorderFrame)
    end
    -- The parchment under a quest's details.
    local details = QuestMapFrame.DetailsFrame
    if details then
        parchmentTex = ns.OwnTexture(details, "parchment", "BACKGROUND", -2)
        -- The parchment fills the top left 300 by 336 of its 512 sheet;
        -- the rest of the sheet is dark. Only the parchment is drawn.
        parchmentTex:SetTexture(ns.TexPath("questParchment"))
        parchmentTex:SetTexCoord(8 / 512, 300 / 512, 4 / 512, 336 / 512)
        parchmentTex:SetPoint("TOPLEFT", details, "TOPLEFT", 0, 0)
        parchmentTex:SetPoint("BOTTOMRIGHT", details, "BOTTOMRIGHT", 0, 0)
    end
    ns.HookGlobal("QuestLogQuests_Update", SkinRows)
    ns.HookGlobal("QuestMapFrame_ShowQuestDetails", SkinDetails)
end

local function Apply()
    active = true
    if not QuestMapFrame then ns.MissingPiece("QuestMapFrame") return end
    Build()
    if floorTex then floorTex:Show() end
    if parchmentTex then parchmentTex:Show() end
    SkinRows()
    if QuestMapFrame.DetailsFrame and QuestMapFrame.DetailsFrame:IsShown() then SkinDetails() end
end

local function Restore()
    active = false
    if floorTex then floorTex:Hide() end
    if parchmentTex then parchmentTex:Hide() end
    ns.needsReload = true
end

ns.RegisterModule("questMapPane", { apply = Apply, restore = Restore })
