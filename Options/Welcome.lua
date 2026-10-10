local _, ns = ...
local L = ns.L

-- One-time welcome note. The game cannot open a browser, so links open a copy box.

local O = ns.options
local TITLE = O.TITLE
local WIDTH = 420
local CURSEFORGE_URL = "https://www.curseforge.com/projects/1700043"
local GITHUB_URL = "https://github.com/wowaddonmaker/classicuiforever/issues"

local BODY = L["WELCOME_BODY"]

local OnForever = ns.OnForever

ns.Popup("FCUI_COPY_LINK", {
    text = L["WELCOME_COPY_PROMPT"],
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
O.CopyCurseForge, O.CopyGitHub, O.CopyLink = CopyCurseForge, CopyGitHub, CopyLink

-- CurseForge and GitHub buttons; the caller anchors them.
function O.FeedbackButtons(parent, width)
    local curse = ns.PanelButton(parent, L["OPTWIN_CURSEFORGE"], width)
    curse:SetScript("OnClick", CopyCurseForge)
    local github = ns.PanelButton(parent, L["OPTWIN_GITHUB_ISSUES"], width)
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
    signoff:SetText(OnForever() and L["WELCOME_SIGNOFF"] or "")

    local curse, github = O.FeedbackButtons(frame, 120)
    local okay = ns.PanelButton(frame, L["OPTWIN_OKAY"], 90)
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
    elseif target == "bars" then
        ns.ShowBarsNote()
    elseif target == "look" then
        ns.ShowBarsLook()
    end
end

-- Hooked on first use, once.
local function HookLinks()
    ns.HookGlobal("SetItemRef", OnItemRef)
end

-- What's New: each version's changelog in short, most important first, similar fixes grouped. A player gets the chat
-- line once per new version, and the box shows only the versions since the one they saw last. An entry marked
-- on = "forever" or on = "retail" is that client's alone; unmarked is both.
local WHATSNEW = {
    { id = 29, version = "0.22.0",
        { L["WN29_1_TITLE"], L["WN29_1_TEXT"], on = "forever" },
        { L["WN29_2_TITLE"], L["WN29_2_TEXT"] },
        { L["WN29_3_TITLE"], L["WN29_3_TEXT"] },
        { L["WN29_4_TITLE"], L["WN29_4_TEXT"], on = "retail" },
    },
    { id = 28, version = "0.21.0",
        { L["WN28_1_TITLE"], L["WN28_1_TEXT"], on = "forever" },
        { L["WN28_2_TITLE"], L["WN28_2_TEXT"], on = "forever" },
        { L["WN28_3_TITLE"], L["WN28_3_TEXT"], on = "forever" },
        { L["WN28_4_TITLE"], L["WN28_4_TEXT"] },
    },
    { id = 27, version = "0.20.5",
        { L["WN27_1_TITLE"], L["WN27_1_TEXT"] },
    },
    { id = 26, version = "0.20.4",
        { L["WN26_1_TITLE"], L["WN26_1_TEXT"] },
        { L["WN26_2_TITLE"], L["WN26_2_TEXT"] },
        { L["WN26_3_TITLE"], L["WN26_3_TEXT"] },
    },
    { id = 25, version = "0.20.3",
        { L["WN25_1_TITLE"], L["WN25_1_TEXT"] },
    },
    { id = 24, version = "0.20.2",
        { L["WN24_1_TITLE"], L["WN24_1_TEXT"] },
    },
    { id = 23, version = "0.20.1",
        { L["WN23_1_TITLE"], L["WN23_1_TEXT"] },
    },
    { id = 22, version = "0.20.0",
        { L["WN22_1_TITLE"], L["WN22_1_TEXT"], on = "retail" },
        { L["WN22_2_TITLE"], L["WN22_2_TEXT"], on = "retail" },
        { L["WN22_3_TITLE"], L["WN22_3_TEXT"], on = "retail" },
        { L["WN22_4_TITLE"], L["WN22_4_TEXT"], on = "retail" },
        { L["WN22_5_TITLE"], L["WN22_5_TEXT"] },
        { L["WN22_6_TITLE"], L["WN22_6_TEXT"], on = "retail" },
        { L["WN22_7_TITLE"], L["WN22_7_TEXT"], on = "forever" },
        { L["WN22_8_TITLE"], L["WN22_8_TEXT"] },
        { L["WN22_9_TITLE"], L["WN22_9_TEXT"], on = "retail" },
        { L["WN22_10_TITLE"], L["WN22_10_TEXT"] },
        { L["WN22_11_TITLE"], L["WN22_11_TEXT"], on = "retail" },
    },
    { id = 21, version = "0.19.1",
        { L["WN21_1_TITLE"], L["WN21_1_TEXT"] },
        { L["WN21_2_TITLE"], L["WN21_2_TEXT"] },
        { L["WN21_3_TITLE"], L["WN21_3_TEXT"] },
    },
    { id = 20, version = "0.19.0",
        { L["WN20_1_TITLE"], L["WN20_1_TEXT"] },
        { L["WN20_2_TITLE"], L["WN20_2_TEXT"] },
        { L["WN20_3_TITLE"], L["WN20_3_TEXT"] },
    },
    { id = 19, version = "0.18.0",
        { L["WN19_1_TITLE"], L["WN19_1_TEXT"] },
        { L["WN19_2_TITLE"], L["WN19_2_TEXT"] },
        { L["WN19_3_TITLE"], L["WN19_3_TEXT"] },
        { L["WN19_4_TITLE"], L["WN19_4_TEXT"] },
        { L["WN19_5_TITLE"], L["WN19_5_TEXT"] },
        { L["WN19_6_TITLE"], L["WN19_6_TEXT"] },
    },
    { id = 18, version = "0.17.0",
        { L["WN18_1_TITLE"], L["WN18_1_TEXT"] },
        { L["WN18_2_TITLE"], L["WN18_2_TEXT"] },
        { L["WN18_3_TITLE"], L["WN18_3_TEXT"] },
        { L["WN18_4_TITLE"], L["WN18_4_TEXT"] },
        { L["WN18_5_TITLE"], L["WN18_5_TEXT"] },
        { L["WN18_6_TITLE"], L["WN18_6_TEXT"] },
        { L["WN18_7_TITLE"], L["WN18_7_TEXT"] },
        { L["WN18_8_TITLE"], L["WN18_8_TEXT"] },
    },
    { id = 17, version = "0.16.2",
        { L["WN17_1_TITLE"], L["WN17_1_TEXT"] },
        { L["WN17_2_TITLE"], L["WN17_2_TEXT"] },
        { L["WN17_3_TITLE"], L["WN17_3_TEXT"] },
    },
    { id = 16, version = "0.16.1",
        { L["WN16_1_TITLE"], L["WN16_1_TEXT"] },
        { L["WN16_2_TITLE"], L["WN16_2_TEXT"] },
        { L["WN16_3_TITLE"], L["WN16_3_TEXT"] },
    },
    { id = 15, version = "0.16.0",
        { L["WN15_1_TITLE"], L["WN15_1_TEXT"] },
        { L["WN15_2_TITLE"], L["WN15_2_TEXT"] },
        { L["WN15_3_TITLE"], L["WN15_3_TEXT"] },
        { L["WN15_4_TITLE"], L["WN15_4_TEXT"] },
        { L["WN15_5_TITLE"], L["WN15_5_TEXT"] },
        { L["WN15_6_TITLE"], L["WN15_6_TEXT"] },
        { L["WN15_7_TITLE"], L["WN15_7_TEXT"] },
        { L["WN15_8_TITLE"], L["WN15_8_TEXT"] },
        { L["WN15_9_TITLE"], L["WN15_9_TEXT"] },
        { L["WN15_10_TITLE"], L["WN15_10_TEXT"] },
    },
    { id = 14, version = "0.15.0",
        { L["WN14_1_TITLE"], L["WN14_1_TEXT"] },
        { L["WN14_2_TITLE"], L["WN14_2_TEXT"] },
        { L["WN14_3_TITLE"], L["WN14_3_TEXT"] },
        { L["WN14_4_TITLE"], L["WN14_4_TEXT"] },
        { L["WN14_5_TITLE"], L["WN14_5_TEXT"] },
        { L["WN14_6_TITLE"], L["WN14_6_TEXT"] },
        { L["WN14_7_TITLE"], L["WN14_7_TEXT"] },
    },
    { id = 13, version = "0.14.1",
        { L["WN13_1_TITLE"], L["WN13_1_TEXT"] },
        { L["WN13_2_TITLE"], L["WN13_2_TEXT"] },
        { L["WN13_3_TITLE"], L["WN13_3_TEXT"] },
        { L["WN13_4_TITLE"], L["WN13_4_TEXT"] },
        { L["WN13_5_TITLE"], L["WN13_5_TEXT"] },
        { L["WN13_6_TITLE"], L["WN13_6_TEXT"] },
        { L["WN13_7_TITLE"], L["WN13_7_TEXT"] },
    },
    { id = 12, version = "0.14.0",
        { L["WN12_1_TITLE"], L["WN12_1_TEXT"] },
        { L["WN12_2_TITLE"], L["WN12_2_TEXT"] },
        { L["WN12_3_TITLE"], L["WN12_3_TEXT"] },
        { L["WN12_4_TITLE"], L["WN12_4_TEXT"] },
        { L["WN12_5_TITLE"], L["WN12_5_TEXT"] },
        { L["WN12_6_TITLE"], L["WN12_6_TEXT"] },
        { L["WN12_7_TITLE"], L["WN12_7_TEXT"] },
        { L["WN12_8_TITLE"], L["WN12_8_TEXT"] },
        { L["WN12_9_TITLE"], L["WN12_9_TEXT"] },
        { L["WN12_10_TITLE"], L["WN12_10_TEXT"] },
        { L["WN12_11_TITLE"], L["WN12_11_TEXT"] },
        { L["WN12_12_TITLE"], L["WN12_12_TEXT"] },
    },
    { id = 11, version = "0.13.1",
        { L["WN11_1_TITLE"], L["WN11_1_TEXT"] },
        { L["WN11_2_TITLE"], L["WN11_2_TEXT"] },
        { L["WN11_3_TITLE"], L["WN11_3_TEXT"] },
        { L["WN11_4_TITLE"], L["WN11_4_TEXT"] },
    },
    { id = 10, version = "0.13.0",
        { L["WN10_1_TITLE"], L["WN10_1_TEXT"] },
        { L["WN10_2_TITLE"], L["WN10_2_TEXT"] },
        { L["WN10_3_TITLE"], L["WN10_3_TEXT"] },
        { L["WN10_4_TITLE"], L["WN10_4_TEXT"] },
        { L["WN10_5_TITLE"], L["WN10_5_TEXT"] },
        { L["WN10_6_TITLE"], L["WN10_6_TEXT"] },
    },
    { id = 9, version = "0.12.0",
        { L["WN9_1_TITLE"], L["WN9_1_TEXT"] },
        { L["WN9_2_TITLE"], L["WN9_2_TEXT"] },
        { L["WN9_3_TITLE"], L["WN9_3_TEXT"] },
        { L["WN9_4_TITLE"], L["WN9_4_TEXT"] },
        { L["WN9_5_TITLE"], L["WN9_5_TEXT"] },
        { L["WN9_6_TITLE"], L["WN9_6_TEXT"] },
        { L["WN9_7_TITLE"], L["WN9_7_TEXT"] },
    },
    { id = 8, version = "0.11.7",
        { L["WN8_1_TITLE"], L["WN8_1_TEXT"] },
        { L["WN8_2_TITLE"], L["WN8_2_TEXT"] },
        { L["WN8_3_TITLE"], L["WN8_3_TEXT"] },
    },
    { id = 7, version = "0.11.6",
        { L["WN7_1_TITLE"], L["WN7_1_TEXT"] },
        { L["WN7_2_TITLE"], L["WN7_2_TEXT"] },
    },
    { id = 6, version = "0.11.5",
        { L["WN6_1_TITLE"], L["WN6_1_TEXT"] },
    },
    { id = 5, version = "0.11.4",
        { L["WN5_1_TITLE"], L["WN5_1_TEXT"] },
    },
    { id = 4, version = "0.11.2",
        { L["WN4_1_TITLE"], L["WN4_1_TEXT"] },
    },
    { id = 3, version = "0.11.1",
        { L["WN3_1_TITLE"], L["WN3_1_TEXT"] },
    },
    { id = 2, version = "0.11.0",
        { L["WN2_1_TITLE"], L["WN2_1_TEXT"] },
        { L["WN2_2_TITLE"], L["WN2_2_TEXT"] },
        { L["WN2_3_TITLE"], L["WN2_3_TEXT"] },
        { L["WN2_4_TITLE"], L["WN2_4_TEXT"] },
        { L["WN2_5_TITLE"], L["WN2_5_TEXT"] },
        { L["WN2_6_TITLE"], L["WN2_6_TEXT"] },
        { L["WN2_7_TITLE"], L["WN2_7_TEXT"] },
    },
}
local LATEST = WHATSNEW[1].id
-- This client's list: a version with no entry for it is left out whole (no chat line there, a silent update).
local NEWS = {}
for _, section in ipairs(WHATSNEW) do
    local mine = { id = section.id, version = section.version }
    for _, entry in ipairs(section) do
        if not entry.on or (entry.on == "forever") == ns.OnForever() then mine[#mine + 1] = entry end
    end
    if #mine > 0 then NEWS[#NEWS + 1] = mine end
end
local GOLD, GREY = "|cffffd100", "|cffa0a0a0"
local CHANGELOG_URL = "https://github.com/wowaddonmaker/classicuiforever/blob/main/CHANGELOG.md"
-- The box fits the text up to NEWS_BODY_H; past that it stays that tall and the bar scrolls the rest.
local NEWS_WIDTH, NEWS_BODY_H, NEWS_WHEEL = 480, 280, 28
local NEWS_BAR_ROOM = 24
local NEWS_HEADER = { width = 320 }   -- the plate: "What's New in x.y.z" runs past the stock 256

local function CopyChangelog() CopyLink(string.format(L["WELCOME_CHANGELOG_LINK"], TITLE), CHANGELOG_URL) end

-- The entries of every version newer than seen, each version headed by its number when there is more than one.
local function NewsText(seen)
    local sections = {}
    for _, section in ipairs(NEWS) do
        if section.id > seen then sections[#sections + 1] = section end
    end
    if #sections == 0 then sections[1] = NEWS[1] end
    local lines = {}
    for _, section in ipairs(sections) do
        if #sections > 1 then lines[#lines + 1] = GREY .. section.version .. "|r" end
        for _, entry in ipairs(section) do lines[#lines + 1] = GOLD .. entry[1] .. ":|r " .. entry[2] end
    end
    return table.concat(lines, "\n")
end

local newsWindow
local function BuildNews()
    local frame = O.DialogWindow("ForeverClassicUIWhatsNew", 120)
    ns.DialogHeader(frame, string.format(L["WELCOME_WHATS_NEW_IN"], NEWS[1].version), NEWS_HEADER)
    -- The text in a fixed box, scrolled by the classic bar or the wheel.
    local fullW = NEWS_WIDTH - 48
    local scroll = ns.NewFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -50)
    scroll:EnableMouseWheel(true)
    local child = ns.NewFrame("Frame", nil, scroll)
    scroll:SetScrollChild(child)
    local body = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetSpacing(3)
    local bar = ns.ClassicScrollBar(frame, scroll, function(value) scroll:SetVerticalScroll(value or 0) end)
    bar.hideWhenIdle = true
    scroll:SetScript("OnMouseWheel", function(_, delta) bar:SetValue(bar:GetValue() - delta * NEWS_WHEEL) end)
    local changelog = ns.PanelButton(frame, L["OPTWIN_FULL_CHANGELOG"], 120)
    changelog:SetScript("OnClick", CopyChangelog)
    changelog:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -4, 20)
    local okay = ns.PanelButton(frame, L["OPTWIN_OKAY"], 90)
    okay:SetScript("OnClick", function() frame:Hide() end)
    okay:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 4, 20)
    -- Refilled on every show: the versions since the one the player saw last.
    frame.Fill = function(_, seen)
        -- Full width first; only text taller than the box gives up room for the bar.
        body:SetText(NewsText(seen))
        body:SetWidth(fullW)
        local height = math.ceil(body:GetStringHeight())
        local textW = fullW
        if height > NEWS_BODY_H then
            textW = fullW - NEWS_BAR_ROOM
            body:SetWidth(textW)
            height = math.ceil(body:GetStringHeight())
        end
        local boxH = math.min(height, NEWS_BODY_H)
        scroll:SetSize(textW, boxH)
        child:SetSize(textW, height)
        bar:SetValue(0)
        bar:SetRange(height - boxH, NEWS_WHEEL)
        scroll:SetVerticalScroll(0)
        scroll:EnableMouseWheel(height > boxH)
        frame:SetSize(NEWS_WIDTH, 50 + boxH + 16 + 22 + 20)
    end
    return frame
end

-- The versions the chat line offered (whatsNewFrom), else the newest one alone (a fresh install was offered none).
function ns.ShowWhatsNew()
    if not newsWindow then newsWindow = BuildNews() end
    local from = tonumber(ns.db and ns.db.whatsNewFrom) or 0
    if from <= 0 or from >= LATEST then from = LATEST - 1 end
    newsWindow:Fill(from)
    newsWindow:Show()
end

-- For players coming from 0.11.0 (list 2), whose bar pieces flipped back with 0.11.1.
local BARS_NOTE = L["WELCOME_BARS_NOTE"]

local barsWindow
function ns.ShowBarsNote()
    if not barsWindow then
        local frame = O.DialogWindow("ForeverClassicUIBarsNote", 120)
        ns.DialogHeader(frame, L["WELCOME_YOUR_BARS"])
        local body = BodyText(frame, BARS_NOTE)
        local check = ns.NewFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        check:SetSize(26, 26)
        check:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 18)
        ns.SkinCheckbox(check)
        local label = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", check, "RIGHT", 2, 0)
        label:SetText(L["OPTWIN_DON_T_SHOW_THIS_AGAIN"])
        check:SetScript("OnClick", function(self) ns.db.barsNoteOff = self:GetChecked() and true or false end)
        frame.check = check
        local okay = ns.PanelButton(frame, L["OPTWIN_OKAY"], 90)
        okay:SetScript("OnClick", function() frame:Hide() end)
        okay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 20)
        frame:SetSize(WIDTH, 50 + body:GetStringHeight() + 70)
        barsWindow = frame
    end
    barsWindow.check:SetChecked(ns.db.barsNoteOff == true)
    barsWindow:Show()
end

-- Every login for a player who came from 0.11.0, until the note's box is ticked; the Addon messages row hushes it.
function ns.AnnounceBarsNote()
    if not ns.db or not ns.db.barsNote or ns.db.barsNoteOff or ns.db.addonMessages == false then return end
    HookLinks()
    ns.Print(string.format(L["WELCOME_BARS_CHAT"], Link("bars", L["WELCOME_HERE"])))
end

-- 0.14.0's bar changes reached players from before it unasked: back as they were, the classic look, or kept as they are.
local LOOK_BUTTON_W = 128
local lookWindow
function ns.ShowBarsLook()
    if not lookWindow then
        local frame = O.DialogWindow("ForeverClassicUIBarsLook", 120)
        ns.DialogHeader(frame, L["WELCOME_YOUR_BARS"])
        local body = BodyText(frame, L["WELCOME_BARS_LOOK_TEXT"])
        local old = ns.PanelButton(frame, L["WELCOME_PRE_0140_LOOK"], LOOK_BUTTON_W)
        local classic = ns.PanelButton(frame, L["WELCOME_CLASSIC_LOOK"], LOOK_BUTTON_W)
        local keep = ns.PanelButton(frame, L["OPTWIN_KEEP_MINE"], LOOK_BUTTON_W)
        classic:SetPoint("BOTTOM", frame, "BOTTOM", 0, 20)
        old:SetPoint("RIGHT", classic, "LEFT", -6, 0)
        keep:SetPoint("LEFT", classic, "RIGHT", 6, 0)
        -- The switch runs from a game popup's button: from ours the game refused it, from its popups it never has.
        old:SetScript("OnClick", function() frame:Hide() StaticPopup_Show("FCUI_OLD_LOOK_CONFIRM") end)
        classic:SetScript("OnClick", function() frame:Hide() StaticPopup_Show("FCUI_CLASSIC_LOOK_OFFER") end)
        keep:SetScript("OnClick", function() frame:Hide() ns.ChooseBarsLook(nil) end)
        frame:SetSize(WIDTH, 50 + body:GetStringHeight() + 64)
        lookWindow = frame
    end
    lookWindow:Show()
end

-- Every login until they choose; the Addon messages row hushes it.
function ns.AnnounceBarsLook()
    if not ns.db or not ns.db.barsLookNote or ns.db.addonMessages == false then return end
    HookLinks()
    ns.Print(string.format(L["WELCOME_BARS_LOOK_CHAT"], Link("look", L["WELCOME_HERE"])))
end

-- Once per new version, as a chat line with a link; the dev addon clears the mark to see it again.
function ns.AnnounceWhatsNew()
    if not ns.db then return end
    local seen = tonumber(ns.db.whatsNewSeen) or 0
    if seen >= LATEST then return end
    ns.db.whatsNewFrom = seen
    ns.db.whatsNewSeen = LATEST
    if seen == 2 then ns.db.barsNote = true end
    -- Nothing in the new versions for this client: a silent update.
    if NEWS[1].id <= seen then return end
    if ns.db.addonMessages == false then return end
    HookLinks()
    local version = ns.AddonVersion and ns.AddonVersion() or ""
    ns.Print(string.format(L["WELCOME_UPDATED"], version, Link("news", L["WELCOME_HERE"])))
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
        ns.SafeCall(ns.AnnounceBarsNote)
        ns.SafeCall(ns.AnnounceBarsLook)
        ns.CheckLayoutPosition()
        return
    end
    -- The welcome stands in for this list.
    ns.db.whatsNewSeen = LATEST
    if ns.db.welcomeNote == false then
        ns.db.welcomed = true
        ns.CheckLayoutPosition()
        return
    end
    ns.ShowWelcome()
end
