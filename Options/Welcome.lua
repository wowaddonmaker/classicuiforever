local _, ns = ...

-- One-time welcome note. The game cannot open a browser, so links open a copy box.

local O = ns.options
local TITLE = O.TITLE
local WIDTH = 420
local CURSEFORGE_URL = "https://www.curseforge.com/projects/1700043"
local GITHUB_URL = "https://github.com/wowaddonmaker/classicuiforever/issues"

local BODY = "This addon is a work in progress. Some pieces are still being measured against the old interface and will be finished before launch."
    .. "\n\nIf something looks wrong, say so. Every report helps. Reach us on CurseForge or on GitHub issues; the buttons below give you the address to copy."
    .. "\n\nAny piece that misbehaves can be switched back to the modern look in the options window."

local OnForever = ns.OnForever

ns.Popup("FCUI_COPY_LINK", {
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
    -- Read-only: typed text is reverted.
    EditBoxOnTextChanged = function(self, data)
        if self:GetText() ~= (data or "") then
            self:SetText(data or "")
            self:HighlightText()
        end
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
})

local function CopyLink(label, url)
    StaticPopup_Show("FCUI_COPY_LINK", label, nil, url)
end
ns.CopyLink = CopyLink
ns.CURSEFORGE_URL = CURSEFORGE_URL
ns.GITHUB_URL = GITHUB_URL

local function CopyCurseForge() CopyLink(TITLE .. " on CurseForge", CURSEFORGE_URL) end
local function CopyGitHub() CopyLink(TITLE .. " issues on GitHub", GITHUB_URL) end
O.CopyCurseForge, O.CopyGitHub = CopyCurseForge, CopyGitHub

-- CurseForge and GitHub buttons; the caller anchors them.
function O.FeedbackButtons(parent, width)
    local curse = ns.PanelButton(parent, "CurseForge", width)
    curse:SetScript("OnClick", CopyCurseForge)
    local github = ns.PanelButton(parent, "GitHub issues", width)
    github:SetScript("OnClick", CopyGitHub)
    return curse, github
end

local window

local function Build()
    local frame = CreateFrame("Frame", "ForeverClassicUIWelcome", UIParent, "BackdropTemplate")
    ns.Backdrop(frame, ns.BACKDROP.DIALOG)
    frame:SetFrameStrata("DIALOG")
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    ns.MakeDraggable(frame)
    frame:Hide()

    ns.DialogHeader(frame, TITLE)

    local body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -50)
    body:SetWidth(WIDTH - 48)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetSpacing(2)
    body:SetText(BODY)
    local signoff = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    signoff:SetPoint("TOP", body, "BOTTOM", 0, -14)
    signoff:SetJustifyH("CENTER")
    signoff:SetText(OnForever() and "Enjoy WoW Forever!" or "")

    local curse, github = O.FeedbackButtons(frame, 120)
    local okay = ns.PanelButton(frame, "Okay", 90)
    okay:SetScript("OnClick", function() frame:Hide() end)

    curse:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -4, 50)
    github:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 4, 50)
    okay:SetPoint("BOTTOM", frame, "BOTTOM", 0, 20)

    frame:SetScript("OnHide", function()
        ns.db.welcomed = true
        -- The layout question follows; on Forever it has its own chat link.
        if not OnForever() then ns.CheckLayoutPosition() end
    end)

    frame:SetSize(WIDTH, 50 + body:GetStringHeight() + (OnForever() and 30 or 0) + 100)
    return frame
end

function ns.ShowWelcome()
    if not window then window = Build() end
    window:Show()
end

-- Chat link in the game's link blue, handled by OnItemRef.
local function Link(target, label)
    return "|cff70d6ff|Hfcui:" .. target .. "|h[" .. label .. "]|h|r"
end

-- Runs in every hyperlink click. Bronze leaves the click and waits out combat: it redresses the bars.
local function OnItemRef(link)
    local target = type(link) == "string" and link:match("^fcui:(%w+)")
    if target == "welcome" then
        ns.ShowWelcome()
    elseif target == "status" then
        if ns.ShowStatus then ns.ShowStatus() end
    elseif target == "bronze" then
        C_Timer.After(0, function()
            if InCombatLockdown() then ns.Print("the theme turns when this fight ends") end
            ns.WhenCalm("bronzeTheme", function()
                if not ns.db then return end
                ns.db.bronzeTheme = not ns.db.bronzeTheme
                ns.ToggleChanged("bronzeTheme")
                ns.Print("Bronze Forever theme " .. (ns.db.bronzeTheme and "on" or "off") .. ".")
            end)
        end)
    elseif target == "layout" then
        if ns.ClassicLayoutActive() then
            ns.Print("the ClassicUI Forever layout is already the active layout")
        else
            if ns.db then ns.db.layoutPrompted = true end
            StaticPopup_Show("FCUI_FIRST_LOGIN")
        end
    end
end

-- Hooked on first use, once.
local function HookLinks()
    ns.HookGlobal("SetItemRef", OnItemRef)
end

-- Chat link for any addon message; installs the click handler.
function ns.ChatLink(target, label)
    HookLinks()
    return Link(target, label)
end

-- First login: welcome, then the layout question on close. The Forever beta forgets
-- saved variables, so there nothing opens by itself; chat links offer both.
function ns.FirstRun()
    if not ns.db then return end
    local wantWelcome = ns.db.welcomeNote ~= false and not ns.db.welcomed
    if OnForever() then
        HookLinks()
        local parts = {}
        if wantWelcome then parts[#parts + 1] = "read the welcome note " .. Link("welcome", "here") end
        local classicActive = ns.ClassicLayoutActive()
        if not ns.db.layoutPrompted and ns.db.classicBar and not classicActive then parts[#parts + 1] = "set up the classic layout " .. Link("layout", "here") end
        if #parts > 0 then ns.Print(table.concat(parts, ", or ") .. ".") end
        -- Every login: the beta may not bring the setting back.
        ns.Print("BRONZE CLASSIC THEME NOW AVAILABLE. CLICK " .. Link("bronze", "HERE") .. " TO TOGGLE SINCE BETA ISSUE PREVENTS SETTING SAVE.")
        return
    end
    if not wantWelcome then
        ns.CheckLayoutPosition()
        return
    end
    ns.ShowWelcome()
end
