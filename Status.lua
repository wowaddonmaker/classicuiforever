local ADDON, ns = ...

-- The status report: one window with everything a bug report needs to
-- begin with, read fresh each time it opens and kept nowhere. It is laid
-- out to be read in a screenshot, and the same lines stand in a box to be
-- copied out as text.

-- Settings that are the addon's own bookkeeping, not the player's choices.
local INTERNAL = {
    dbVersion = true, previousLayout = true, layoutSelectPending = true, layoutSelectTries = true,
    microPosText = true, welcomed = true, layoutPrompted = true, textureSource = true, barDragged = true,
}

local function Version()
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local ok, version = pcall(get, ADDON, "Version")
    return ok and version or "?"
end

local function OtherAddons()
    local names = {}
    local count = C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns() or 0
    for i = 1, count do
        local name = C_AddOns.GetAddOnInfo(i)
        local loaded = C_AddOns.IsAddOnLoaded(i)
        if loaded and name and name ~= ADDON and not name:find("^Blizzard_") then
            local ok, version = pcall(C_AddOns.GetAddOnMetadata, i, "Version")
            names[#names + 1] = (ok and version and version ~= "") and (name .. " " .. version) or name
        end
    end
    table.sort(names)
    return names
end

-- The player's settings that are not as the addon ships them.
local function ChangedSettings()
    local changed = {}
    for key, default in pairs(ns.DB_DEFAULTS or {}) do
        local kind = type(default)
        if not INTERNAL[key] and (kind == "boolean" or kind == "number" or kind == "string") then
            local value = ns.db and ns.db[key]
            if value ~= nil and value ~= default then
                changed[#changed + 1] = key .. "=" .. tostring(value)
            end
        end
    end
    -- Parts with no entry in the defaults are on unless switched off.
    for _, entry in ipairs(ns.TOGGLES or {}) do
        local key = entry[1]
        if ns.DB_DEFAULTS[key] == nil and ns.db and ns.db[key] == false then
            changed[#changed + 1] = key .. "=false"
        end
    end
    table.sort(changed)
    return changed
end

local function Wrapped(label, items, none)
    if #items == 0 then return { label .. none } end
    local lines, line = {}, label
    for i, item in ipairs(items) do
        local piece = item .. (i < #items and ", " or "")
        if #line + #piece > 78 and line ~= label then
            lines[#lines + 1] = line
            line = "    "
        end
        line = line .. piece
    end
    lines[#lines + 1] = line
    return lines
end

function ns.StatusText()
    local lines = {}
    local function Add(text) lines[#lines + 1] = text end
    local version, build, _, toc = GetBuildInfo()
    Add("ClassicUI Forever " .. Version())
    Add(string.format("Client: %s (%s), toc %s, %s", tostring(version), tostring(build), tostring(toc), GetLocale and GetLocale() or "?"))
    local width, height = GetPhysicalScreenSize()
    local windowed = C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("gxMaximize")
    Add(string.format("Display: %sx%s%s, UI scale %.2f", tostring(width), tostring(height),
        windowed == "0" and " windowed" or "", UIParent:GetEffectiveScale()))
    local _, class = UnitClass("player")
    local zone = GetRealZoneText and GetRealZoneText() or ""
    Add(string.format("Character: %s %s, %s%s", tostring(class), tostring(UnitLevel("player")), zone,
        InCombatLockdown() and ", in combat" or ""))
    for _, line in ipairs(Wrapped("Settings changed: ", ChangedSettings(), "none, all as shipped")) do Add(line) end
    local others = OtherAddons()
    for _, line in ipairs(Wrapped("Other addons on (" .. #others .. "): ", others, "none")) do Add(line) end
    local blocked = ns.blocked or {}
    if #blocked == 0 then
        Add("Blocked by the game this session: nothing")
    else
        Add("Blocked by the game this session:")
        for _, hit in ipairs(blocked) do
            Add(string.format("    %s %s %s%s%s", hit.when, hit.event == "ADDON_ACTION_FORBIDDEN" and "forbidden" or "blocked",
                hit.func, hit.combat and " (in combat)" or "", hit.editMode and " (edit mode)" or ""))
        end
    end
    return table.concat(lines, "\n")
end

local window

local function Build()
    local frame = CreateFrame("Frame", "ForeverClassicUIStatus", UIParent, "BackdropTemplate")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    ns.BronzeBackdrop(frame)
    frame:SetSize(560, 380)
    frame:SetFrameStrata("DIALOG")
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()

    local header = frame:CreateTexture(nil, "ARTWORK")
    ns.SetFile(header, "Interface\\DialogFrame\\UI-DialogBox-Header")
    header:SetSize(300, 64)
    header:SetPoint("TOP", frame, "TOP", 0, 12)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", header, "TOP", 0, -14)
    title:SetText("ClassicUI Forever status")

    local how = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    how:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -32)
    how:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -32)
    how:SetJustifyH("LEFT")
    how:SetText("Reporting a bug? Take a screenshot with this window and the problem both in it, or press Select all, "
        .. "copy with Ctrl+C, and paste the text into your report. Say what you did and what you expected. "
        .. "If it may be another addon, try once with only this one on.")

    local box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    box:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    box:SetBackdropColor(0, 0, 0, 0.7)
    box:SetBackdropBorderColor(0.6, 0.6, 0.6)
    box:SetPoint("TOPLEFT", how, "BOTTOMLEFT", -4, -8)
    box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 52)

    local scroll = CreateFrame("ScrollFrame", nil, box)
    scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 8)
    scroll:EnableMouseWheel(true)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(GameFontHighlightSmall)
    edit:SetWidth(500)
    scroll:SetScrollChild(edit)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local most = math.max(0, edit:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(most, math.max(0, self:GetVerticalScroll() - delta * 28)))
    end)
    -- The text is to be read and copied, not written: whatever is typed
    -- into it is put back.
    edit:SetScript("OnTextChanged", function(self, user)
        if user and frame.text then self:SetText(frame.text) self:HighlightText() end
    end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
    frame.edit = edit

    local select = ns.PanelButton(frame, "Select all", 100)
    select:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 20)
    select:SetScript("OnClick", function()
        edit:SetFocus()
        edit:HighlightText()
    end)
    local close = ns.PanelButton(frame, CLOSE or "Close", 100)
    close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 20)
    close:SetScript("OnClick", function() frame:Hide() end)
    local github = ns.PanelButton(frame, "GitHub issues", 120)
    github:SetPoint("RIGHT", close, "LEFT", -6, 0)
    github:SetScript("OnClick", function() ns.CopyLink("ClassicUI Forever issues on GitHub", ns.GITHUB_URL) end)
    local curse = ns.PanelButton(frame, "CurseForge", 120)
    curse:SetPoint("RIGHT", github, "LEFT", -6, 0)
    curse:SetScript("OnClick", function() ns.CopyLink("ClassicUI Forever on CurseForge", ns.CURSEFORGE_URL) end)

    frame:SetScript("OnShow", function(self)
        self.text = ns.StatusText()
        edit:SetText(self.text)
        edit:SetCursorPosition(0)
        scroll:SetVerticalScroll(0)
    end)
    if ns.CloseOnEscape then ns.CloseOnEscape(frame) end
    return frame
end

function ns.ShowStatus()
    if not window then window = Build() end
    if window:IsShown() then
        -- Asked for again while up: read afresh.
        window:Hide()
    end
    window:Show()
end

-- The game has just refused something this addon did. Once a session, one
-- line of chat offers the report with that refusal already in it; no
-- window opens by itself, least of all in a fight.
local offered = false
function ns.OfferStatus()
    if offered or not ns.ChatLink then return end
    offered = true
    ns.Print("the game blocked something this addon tried to do. If anything looks broken, "
        .. ns.ChatLink("status", "open the status report") .. " and send it with a note of what you were doing.")
end
