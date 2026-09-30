local _, ns = ...

-- One-time welcome note. The game cannot open a browser, so links open a copy box.

local O = ns.options
local TITLE = O.TITLE
local WIDTH = 420
local CURSEFORGE_URL = "https://www.curseforge.com/projects/1700043"
local GITHUB_URL = "https://github.com/wowaddonmaker/classicuiforever/issues"

local BODY = "ClassicUI Forever brings back the look of the original interface. It is still a work in progress, and some pieces are still being matched to the old one."
    .. "\n\nIf something looks wrong or stops working, please report it on CurseForge or GitHub. The buttons below give you the address to copy."
    .. "\n\nClassic had no professions button and no reagent bag. Here, professions open from the spellbook, and the reagent bag shows as a small round button when you hover over your bags. Both can be changed under Classic bar in the options."
    .. "\n\nAny piece that misbehaves can be switched back to the game's own look in the options."

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
    elseif target == "bars" then
        ns.ShowBarsNote()
    end
end

-- Hooked on first use, once.
local function HookLinks()
    ns.HookGlobal("SetItemRef", OnItemRef)
end

-- What's New: each version's changelog in short, most important first, similar fixes grouped. A player gets the chat
-- line once per new version, and the box shows only the versions since the one they saw last.
local WHATSNEW = {
    { id = 11, version = "0.13.1",
        { "Chat", "Hide chat buttons lets the chat sit at the screen's edge, and Chat scroll bar keeps WoW Forever's scroll bar (Chat buttons)." },
        { "Quest levels", "Quest levels (Quests) shows each quest's level on the map, in the tracker and in the quest log, in step with the map's own filter." },
        { "Dark theme", "Right-click menus, addon minimap buttons, the zoom buttons, clock and day and night icon take the theme, and action icons show no light edge." },
        { "Fixes", "No double quest level in the tracker, no errors from right-click menus in dungeons, and the target's menu stays on screen." },
    },
    { id = 10, version = "0.13.0",
        { "Minimap", "Each minimap piece can show, show only on hover, or hide (Minimap in the options), and zoom in and out move around the ring on their own in ClassicUI Forever Windows." },
        { "Micro menu", "Classic Era's descriptions in the micro button tooltips, and Hide micro buttons takes single buttons off the menu (Classic bar)." },
        { "Key ring", "Opens with no keys, in its own window, in Classic Era's art." },
        { "New options", "Hide stance bar (Classic bar), Name text size (Nameplates) and Unit tooltip on bars (Unit frames)." },
        { "Fixes", "Scroll arrows grey out with nothing to scroll, the quest log highlights as in Classic Era, guild Last Online sorts properly and the macro window opens beside the spellbook." },
        { "Smaller fixes", "Talent arrows, the guild tab without a guild, page arrows over the map, the addon buttons bag and shorter layout prompts." },
    },
    { id = 9, version = "0.12.0",
        { "Classic world map", "Classic Era's small map, with the map's quest list in its own pane beside it and rewards after the quest text. Map navigation bar under Map in the options brings back the game's map layout." },
        { "New options", "Hide map quest button (Map), Classic-sized bars (Classic bar) and Shake on interrupt (Cast bars)." },
        { "Classic look", "Right-click menus, drop down lists, the social window, group finder, Who list and guild roster follow Classic Era; the settings window takes today's Classic Era client look, and the Ignore List and dressing room the classic look." },
        { "Edit mode", "The spellbook can be moved and sized in ClassicUI Forever Windows." },
        { "Bars and tracker", "Bars 4 and 5 keep their place at the screen's edge, and the quest tracker no longer sits over them." },
        { "Fixes", "Neutral NPCs show their level instead of a skull, and clicking a unit frame's bars targets again." },
        { "Windows and tabs", "Vendor, mail, guild charter and tabard windows, and many other windows and tabs, line up with Classic Era; Escape closes the guild charter window." },
    },
    { id = 8, version = "0.11.7",
        { "Gryphons over bars", "Tick Gryphons over bars under Classic bar in the options to draw the gryphons in front of bars 2 and 3." },
        { "Windows open on key press", "The spellbook, professions, talents, guild and quest log keys and Escape act on the press, as the game's own windows do." },
        { "Fixes", "Spells drag onto Action Bar 1 again, the zone name is centred on the minimap bar wherever the calendar sits, and the spellbook's tabs and pet commands look right." },
    },
    { id = 7, version = "0.11.6",
        { "Classic key text", "Key names on the action buttons are Classic Era's size and outline. Key text size under Button style in the options makes them bigger or smaller." },
        { "Calendar spots", "The calendar is a small square by the zone name; put it on the ring or behind the day and night icon under Calendar button in the options. Tick Calendar under Minimap in ClassicUI Forever Windows in edit mode to move or resize it." },
    },
    { id = 6, version = "0.11.5",
        { "Calendar button", "The calendar sits under the day and night icon on the minimap. To hide it, untick Calendar button under Minimap in the options." },
    },
    { id = 5, version = "0.11.4",
        { "Fixes", "The group finder's new player friendly flag lines up with the role icons. Details in the full changelog." },
    },
    { id = 4, version = "0.11.2",
        { "Fixes", "Tabs take the mouse on the tab itself, a profession cast from the spellbook closes the book in a fight, and the loot window's header is clean. Details in the full changelog." },
    },
    { id = 3, version = "0.11.1",
        { "Classic bar pieces", "Classic had no professions button and no reagent bag, so the professions button is off the micro menu (professions open from the spellbook) and the reagent bag is a small round button on hover. Bars 2 and 3 fit between the gryphons again. Both are rows under Classic bar in the options." },
    },
    { id = 2, version = "0.11.0",
        { "Windows edit mode", "Tick Windows in edit mode to move and resize the character sheet, spellbook, talents, quest log, professions and map." },
        { "Profiles", "A Profiles tab in the options keeps named settings per character." },
        { "Bronze or Dark", "The custom theme comes in Forever's bronze or a dark charcoal. See the Custom theme toggle in the options." },
        { "Classic bar", "The bars are no longer reduced in size by default. The bar now carries the latency bar, key ring and reagent bag as classic did; each can be moved in edit mode or hidden under Classic bar in the options." },
        { "Minimap buttons", "Other addons' minimap buttons can gather behind one button on the ring. See the Collect addon buttons toggle in the options." },
        { "Options", "Quests and Map sections, and new rows for the map frame, loot window, loot rolls, hiding the game's tracker, the professions button and the key text." },
        { "Reset classic layout", "Puts the windows, tracker, gryphons, bar pieces and layout settings back at once." },
    },
}
local LATEST = WHATSNEW[1].id
local GOLD, GREY = "|cffffd100", "|cffa0a0a0"
local CHANGELOG_URL = "https://github.com/wowaddonmaker/classicuiforever/blob/main/CHANGELOG.md"
-- The box fits the text up to NEWS_BODY_H; past that it stays that tall and the bar scrolls the rest.
local NEWS_WIDTH, NEWS_BODY_H, NEWS_WHEEL = 480, 280, 28
local NEWS_BAR_ROOM = 24
local NEWS_HEADER = { width = 320 }   -- the plate: "What's New in x.y.z" runs past the stock 256

local function CopyChangelog() CopyLink(TITLE .. " changelog on GitHub", CHANGELOG_URL) end

-- The entries of every version newer than seen, each version headed by its number when there is more than one.
local function NewsText(seen)
    local sections = {}
    for _, section in ipairs(WHATSNEW) do
        if section.id > seen then sections[#sections + 1] = section end
    end
    if #sections == 0 then sections[1] = WHATSNEW[1] end
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
    ns.DialogHeader(frame, "What's New in " .. WHATSNEW[1].version, NEWS_HEADER)
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
    local changelog = ns.PanelButton(frame, "Full changelog", 120)
    changelog:SetScript("OnClick", CopyChangelog)
    changelog:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -4, 20)
    local okay = ns.PanelButton(frame, "Okay", 90)
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
local BARS_NOTE = "0.11.0 put a professions button and a full-size reagent bag on the classic bar, which made it too wide for bars 2 and 3. 0.11.1 takes both off the bar, as classic had neither: professions open from the spellbook, and the reagent bag is a small round button on hover."
    .. "\n\nIf you moved bars 2 and 3 to work around it, they now sit centred between the gryphons on their own: select one in edit mode and press Reset To Default Position, or drag it back. Every piece can be switched either way under Classic bar in the addon settings."

local barsWindow
function ns.ShowBarsNote()
    if not barsWindow then
        local frame = O.DialogWindow("ForeverClassicUIBarsNote", 120)
        ns.DialogHeader(frame, "Your bars")
        local body = BodyText(frame, BARS_NOTE)
        local check = ns.NewFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        check:SetSize(26, 26)
        check:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 18)
        ns.SkinCheckbox(check)
        local label = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", check, "RIGHT", 2, 0)
        label:SetText("Don't show this again")
        check:SetScript("OnClick", function(self) ns.db.barsNoteOff = self:GetChecked() and true or false end)
        frame.check = check
        local okay = ns.PanelButton(frame, "Okay", 90)
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
    ns.Print("Bars not where you expect? See " .. Link("bars", "here") .. ".")
end

-- Once per new version, as a chat line with a link; the dev addon clears the mark to see it again.
function ns.AnnounceWhatsNew()
    if not ns.db then return end
    local seen = tonumber(ns.db.whatsNewSeen) or 0
    if seen >= LATEST then return end
    ns.db.whatsNewFrom = seen
    ns.db.whatsNewSeen = LATEST
    if seen == 2 then ns.db.barsNote = true end
    if ns.db.addonMessages == false then return end
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
        ns.SafeCall(ns.AnnounceBarsNote)
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
