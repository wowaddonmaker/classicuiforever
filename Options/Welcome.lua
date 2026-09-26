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
        local box = ns.PopupEditBox(self)
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

-- The note's text block under the header, as wide as the window allows.
local function BodyText(frame, text)
    local body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -50)
    body:SetWidth(WIDTH - 48)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetSpacing(2)
    body:SetText(text)
    return body
end

local function Build()
    local frame = O.DialogWindow("ForeverClassicUIWelcome", 120)
    ns.DialogHeader(frame, TITLE)

    local body = BodyText(frame, BODY)
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
        -- The layout question follows.
        ns.CheckLayoutPosition()
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

-- Runs in every hyperlink click.
local function OnItemRef(link)
    local target = type(link) == "string" and link:match("^fcui:(%w+)")
    if target == "status" then
        if ns.ShowStatus then ns.ShowStatus() end
    elseif target == "news" then
        ns.ShowWhatsNew()
    end
end

-- Hooked on first use, once.
local function HookLinks()
    ns.HookGlobal("SetItemRef", OnItemRef)
end

-- What's New: new features only (fixes are the changelog's, one button away); bump WHATSNEW_ID whenever the list
-- changes, and each player gets the chat line once per bump.
local WHATSNEW_ID = 2
local WHATSNEW = {
    { "Windows edit mode", "Tick Windows in edit mode to move and resize the character sheet, spellbook, talents, quest log, professions and map." },
    { "Profiles", "A Profiles tab in the options keeps named settings per character." },
    { "Bronze or Dark", "The custom theme comes in Forever's bronze or a dark charcoal. See the Custom theme toggle in the options." },
    { "Classic bar", "The bars are no longer reduced in size by default. The bar now carries the latency bar, key ring and reagent bag as classic did; each can be moved in edit mode or hidden under Classic bar in the options." },
    { "Minimap buttons", "Other addons' minimap buttons can gather behind one button on the ring. See the Collect addon buttons toggle in the options." },
    { "Options", "Quests and Map sections, and new rows for the map frame, loot window, loot rolls, hiding the game's tracker, the professions button and the key text." },
    { "Reset classic layout", "Puts the windows, tracker, gryphons, bar pieces and layout settings back at once." },
}
local GOLD = "|cffffd100"
local CHANGELOG_URL = "https://github.com/wowaddonmaker/classicuiforever/blob/main/CHANGELOG.md"
local NEWS_WIDTH, NEWS_BODY_MAX, NEWS_WHEEL = 480, 260, 28
local NEWS_HEADER = { width = 320 }   -- the plate: "What's New in x.y.z" runs past the stock 256

local function CopyChangelog() CopyLink(TITLE .. " changelog on GitHub", CHANGELOG_URL) end

local newsWindow
local function BuildNews()
    local frame = O.DialogWindow("ForeverClassicUIWhatsNew", 120)
    local version = ns.AddonVersion and ns.AddonVersion() or ""
    ns.DialogHeader(frame, version ~= "" and ("What's New in " .. version) or "What's New", NEWS_HEADER)
    -- The list in a clipped box that scrolls by wheel when it runs past NEWS_BODY_MAX.
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -50)
    scroll:SetWidth(NEWS_WIDTH - 48)
    scroll:EnableMouseWheel(true)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(NEWS_WIDTH - 48)
    scroll:SetScrollChild(child)
    local body = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    body:SetWidth(NEWS_WIDTH - 48)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetSpacing(3)
    local lines = {}
    for i = 1, #WHATSNEW do lines[i] = GOLD .. WHATSNEW[i][1] .. ":|r " .. WHATSNEW[i][2] end
    body:SetText(table.concat(lines, "\n"))
    local height = math.ceil(body:GetStringHeight())
    child:SetHeight(height)
    local shown = math.min(height, NEWS_BODY_MAX)
    scroll:SetHeight(shown)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local most = math.max(0, height - self:GetHeight())
        self:SetVerticalScroll(math.min(most, math.max(0, self:GetVerticalScroll() - delta * NEWS_WHEEL)))
    end)
    local note = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOP", scroll, "BOTTOM", 0, -10)
    note:SetText("Bug fixes are in the full changelog.")
    local changelog = ns.PanelButton(frame, "Full changelog", 120)
    changelog:SetScript("OnClick", CopyChangelog)
    changelog:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -4, 20)
    local okay = ns.PanelButton(frame, "Okay", 90)
    okay:SetScript("OnClick", function() frame:Hide() end)
    okay:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 4, 20)
    frame:SetSize(NEWS_WIDTH, 50 + shown + 10 + 14 + 16 + 22 + 20)
    return frame
end

function ns.ShowWhatsNew()
    if not newsWindow then newsWindow = BuildNews() end
    newsWindow:Show()
end

-- Once per WHATSNEW_ID, as a chat line with a link; the dev addon clears the mark to see it again.
function ns.AnnounceWhatsNew()
    if not ns.db or (tonumber(ns.db.whatsNewSeen) or 0) >= WHATSNEW_ID then return end
    ns.db.whatsNewSeen = WHATSNEW_ID
    HookLinks()
    local version = ns.AddonVersion and ns.AddonVersion() or ""
    ns.Print("updated to " .. version .. ". See what's new " .. Link("news", "here") .. ".")
end

-- Chat link for any addon message; installs the click handler.
function ns.ChatLink(target, label)
    HookLinks()
    return Link(target, label)
end

-- Ran the addon before the beta kept saved variables (1.60.1 70009): the classic layout survived.
local function Returning()
    return ns.ClassicLayoutActive()
end

-- A new player gets the welcome, then the layout question as it closes; everyone else the What's New, once per list.
function ns.FirstRun()
    if not ns.db then return end
    if not ns.db.welcomed and Returning() then ns.db.welcomed = true end
    if ns.db.welcomed then
        ns.SafeCall(ns.AnnounceWhatsNew)
        ns.CheckLayoutPosition()
        return
    end
    -- The welcome stands in for this list.
    ns.db.whatsNewSeen = WHATSNEW_ID
    if ns.db.welcomeNote == false then
        ns.db.welcomed = true
        ns.CheckLayoutPosition()
        return
    end
    ns.ShowWelcome()
end
