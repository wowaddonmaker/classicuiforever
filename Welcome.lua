local _, ns = ...

-- The one-time welcome: a single dialog in the old dialog art saying the
-- addon is a work in progress and where to send feedback. Each link
-- opens a small box with the address selected, ready to copy, since the
-- game cannot open a browser.

local TITLE = "ClassicUI Forever"
local WIDTH = 420
local CURSEFORGE_URL = "https://www.curseforge.com/projects/1700043"
local GITHUB_URL = "https://github.com/wowaddonmaker/classicuiforever/issues"

local BODY = "This addon is a work in progress. Some pieces are still being measured against the old interface and will be finished before launch."
    .. "\n\nIf something looks wrong, say so. Every report helps. Reach us on CurseForge or on GitHub issues; the buttons below give you the address to copy."

StaticPopupDialogs["FCUI_COPY_LINK"] = {
    text = "%s\n\nPress Ctrl+C to copy",
    button1 = CLOSE or "Close",
    hasEditBox = 1,
    editBoxWidth = 360,
    OnShow = function(self, data)
        local box = self.EditBox or self.editBox or _G[self:GetName() .. "EditBox"]
        if box then
            box:SetText(data or "")
            box:HighlightText()
            box:SetFocus()
        end
    end,
    EditBoxOnTextChanged = function(self, data)
        if self:GetText() ~= (data or "") then
            self:SetText(data or "")
            self:HighlightText()
        end
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

local function CopyLink(label, url)
    StaticPopup_Show("FCUI_COPY_LINK", label, nil, url)
end

local window

local function Build()
    local frame = CreateFrame("Frame", "ForeverClassicUIWelcome", UIParent, "BackdropTemplate")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetFrameStrata("DIALOG")
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()

    local header = frame:CreateTexture(nil, "ARTWORK")
    header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    header:SetSize(256, 64)
    header:SetPoint("TOP", frame, "TOP", 0, 12)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", header, "TOP", 0, -14)
    title:SetText(TITLE)

    local body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -50)
    body:SetWidth(WIDTH - 48)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetSpacing(2)
    body:SetText(BODY)

    local curse = ns.PanelButton(frame, "CurseForge", 120)
    curse:SetScript("OnClick", function() CopyLink("ClassicUI Forever on CurseForge", CURSEFORGE_URL) end)
    local github = ns.PanelButton(frame, "GitHub issues", 120)
    github:SetScript("OnClick", function() CopyLink("ClassicUI Forever issues on GitHub", GITHUB_URL) end)
    local okay = ns.PanelButton(frame, "Okay", 90)
    okay:SetScript("OnClick", function() frame:Hide() end)

    curse:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 20)
    github:SetPoint("LEFT", curse, "RIGHT", 8, 0)
    okay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 20)

    frame:SetScript("OnHide", function()
        ns.db.welcomed = true
        -- The layout question follows the welcome, not the other way round.
        if ns.CheckLayoutPosition then ns.CheckLayoutPosition() end
    end)

    frame:SetSize(WIDTH, 50 + body:GetStringHeight() + 70)
    return frame
end

function ns.ShowWelcome()
    if not window then window = Build() end
    window:Show()
end

-- First time in with the addon: the welcome, then the layout question
-- once it is closed. Later logins go straight to the layout check.
function ns.FirstRun()
    if not ns.db then return end
    if ns.db.welcomed then
        if ns.CheckLayoutPosition then ns.CheckLayoutPosition() end
        return
    end
    ns.ShowWelcome()
end
