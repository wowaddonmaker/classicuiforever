-- The map's quest pane in 1.x style. Client rows, pools and text stay
-- theirs: their modern art is faded and ours laid under.
local _, ns = ...

local INK_R, INK_G, INK_B = 0.18, 0.12, 0.06   -- parchment ink
local CHECK_BOX = "Interface\\Buttons\\UI-CheckBox-Up"
local CHECK_MARK = "Interface\\Buttons\\UI-CheckBox-Check"
local CHECK_GLOW = "Interface\\Buttons\\UI-CheckBox-Highlight"
local REWARD_ART = { "Top", "Bottom", "Background" }

local active = false
local built = false
local floorTex, parchmentTex

------------------------------------------------------------------ list rows

local function HeaderText(button)
    return button.ButtonText or button:GetFontString()
end

local function Collapsed(button)
    if button.info and button.info.isCollapsed ~= nil then return button.info.isCollapsed end
    if button.questLogIndex and C_QuestLog and C_QuestLog.GetInfo then
        local info = C_QuestLog.GetInfo(button.questLogIndex)
        if info then return info.isCollapsed end
    end
    return false
end

-- Header: 1.x plus/minus and yellow name; the client's bar and arrow faded.
local function SkinHeader(button)
    if not button.fcuiHeader then
        button.fcuiHeader = true
        ns.FadeTextures(button)
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
        glow:SetTexture(ns.ART.PLUS_GLOW)
        glow:SetBlendMode("ADD")
        glow:SetSize(16, 16)
        glow:SetPoint("LEFT", button, "LEFT", 4, 0)
        local text = HeaderText(button)
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
        -- Only we write this texture, so the cached state is authoritative.
        local shut = Collapsed(button) and true or false
        if icon.fcuiShut ~= shut then
            icon.fcuiShut = shut
            ns.SetCollapseIcon(icon, shut)
        end
        icon:SetVertexColor(1, 1, 1)
    end
    -- The client recolours the name on every update.
    local text = HeaderText(button)
    if text then text:SetTextColor(1, 0.82, 0) end
end

-- 1.x difficulty colour; gold when the level is unknown.
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

-- Retexture the client's check box regions with the 1.x check.
local function DressCheckRegion(region, box)
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

-- 1.x row highlight and check box; storyline and task icons faded.
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
        if box then ns.EachTexture(box, DressCheckRegion, box) end
        -- The client restores its own colour on leave.
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

-- Ink all quest text; buttons are skipped so reward item names keep their colour.
local InkFrame

local function InkRegion(region)
    if region:IsObjectType("FontString") then region:SetTextColor(INK_R, INK_G, INK_B) end
end

local function InkChild(child)
    if not child:IsObjectType("Button") then InkFrame(child) end
end

function InkFrame(frame)
    if not frame then return end
    ns.EachRegion(frame, InkRegion)
    ns.EachChild(frame, InkChild)
end

local function SkinDetails()
    if not active or not QuestMapFrame then return end
    local details = QuestMapFrame.DetailsFrame
    if not details then return end
    local rewards = details.RewardsFrameContainer and details.RewardsFrameContainer.RewardsFrame
    if not details.fcuiSkinned then
        details.fcuiSkinned = true
        if details.Bg then details.Bg:SetAlpha(0) end
        ns.FadeTextures(details.BorderFrame)
        ns.FadeTextures(details.BackFrame)
        ns.FadeKeys(rewards, REWARD_ART)
    end
    if details.ScrollFrame then InkFrame(details.ScrollFrame.Contents) end
    if rewards then InkFrame(rewards) end
end

------------------------------------------------------------------ chrome

local function Build()
    if built or not QuestMapFrame then return end
    built = true
    local quests = QuestMapFrame.QuestsFrame
    local scroll = quests and quests.ScrollFrame
    -- Dark marble floor at the other lists' shade.
    floorTex = ns.OwnTexture(QuestMapFrame, "floor", "BACKGROUND", -3)
    ns.TileTex(floorTex, "marbleBg", nil, ns.PANE_SHADE or 0.9)
    floorTex:SetAllPoints(QuestMapFrame)
    if scroll then
        if scroll.Background then scroll.Background:SetAlpha(0) end
        if scroll.Edge then scroll.Edge:SetAlpha(0) end
        ns.FadeTextures(scroll.BorderFrame)
    end
    local details = QuestMapFrame.DetailsFrame
    if details then
        parchmentTex = ns.OwnTexture(details, "parchment", "BACKGROUND", -2)
        -- Parchment is the top-left 300x336 of the 512 sheet; the rest is dark.
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
