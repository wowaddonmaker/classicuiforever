local _, ns = ...

-- List tabs (reputation, skills, currency, statistics, PvP) in the old art: each client
-- ScrollBox moved inside it, rows dressed as they get data, the bar given the old track.

local T = ns.sheet
local Take, Own, Fade = T.Take, T.Own, T.Fade

-- Reputation plate: rows 0-20 and 22-42 of the sheet, each 21 tall.
local PLATE_L = { 0, 1, 0, 0.328125 }
local PLATE_R = { 0, 0.0625, 0.34375, 0.671875 }
local BAR_W, BAR_H = 137, 13
local SKILL_BLUE = { 0, 0, 0.5 }
local SKILL_COORDS, REP_COORDS = { 0, 1, 0, 0.5 }, { 0, 1, 0, 1 }
-- Row pitch is not ours to set (SkinListFrame): lists scale to the old pitch, contents by 1/scale.
-- Skills 30+3 to 19+1, reputation 35 to 28.
local SKILL_LIST_SCALE = 20 / 33
local REP_LIST_SCALE = 0.76

local FULL = { 0, 1, 0, 1 }
local SKILL_BORDER = { own = "border", layer = "BORDER", coords = FULL, point = "LEFT", x = -5, point2 = "RIGHT", x2 = 5, h = 32, show = true }
-- Name plate and bar frame in one strip from 126 left of the bar; right cap cut above a stray mark.
local REP_PLATE = {
    { own = "plateLeft", layer = "BORDER", sublevel = 0, key = "repPlate", coords = PLATE_L, w = 256, h = 21, point = "TOPLEFT", x = -126, y = 4, show = true },
    { own = "plateRight", layer = "BORDER", sublevel = 0, key = "repPlate", coords = PLATE_R, w = 16, h = 21, point = "TOPLEFT", relPoint = "TOPRIGHT", chain = true, show = true },
}
local PLATE_PAIR = {}
local COLLAPSE_ICON = { w = 16, h = 16, point = "LEFT", x = 7, show = true }
local TOGGLE_FACES = { "Normal", "Pushed" }
local TOGGLE = { set = "raw", coords = FULL, fill = true, states = TOGGLE_FACES }
local TRACK_TOP = { own = "trackTop", layer = "BACKGROUND", coords = { 0, 0.484375, 0, 1 }, w = 31, h = 256, point = "TOPLEFT", x = -8, y = 9, show = true }
local TRACK_BOTTOM = { own = "trackBottom", layer = "BACKGROUND", sublevel = 1, coords = { 0.515625, 1, 0, 0.421875 }, w = 31, h = 108, point = "BOTTOMLEFT", x = -8, y = -8, show = true }
local ARROW = { own = "arrow", layer = "ARTWORK", coords = { 0.25, 0.75, 0.25, 0.75 }, fill = true, keep = true, show = true }

local function RepRowClick(row)
    if ns.ReputationRowClicked then ns.ReputationRowClicked(row) end
end

local function CurrencyRowClick(row)
    if ns.CurrencyRowClicked then ns.CurrencyRowClicked(row) end
end

-- The client sizes a bar's fill once, as a share of the width it had then; ours can be re-anchored wider after (the skill
-- detail bar), so the share is kept and the fill sized from it against the width now.
local fillShare = setmetatable({}, { __mode = "k" })
local function FitFill(bar)
    local share = fillShare[bar]
    if share and bar.Fill then
        bar.Fill:SetWidth(math.max(0, share * (bar:GetWidth() - (bar.fcuiInset or 0))))
    end
end
T.FitFill = FitFill

-- A row not laid out yet reads the template's narrower width: every bar refitted once the frame's layout is done.
local function FitAllFills()
    if not T.active then return end
    for bar in pairs(fillShare) do FitFill(bar) end
end

-- Reputation: old plate over a standing-coloured fill. Skills: full-row blue bar, name and rank
-- inside, old rounded border. Our name replaces the client's, above the art.
local function SkinListEntry(row, barKey)
    local content = row.Content
    -- A currency's row opens the old options box (it has no bar to dress).
    if row.currencyIndex ~= nil then ns.HookScriptOnce(row, "OnClick", CurrencyRowClick) end
    local bar = content and barKey and content[barKey]
    if not bar then return end
    local skills = barKey == "SkillsBar"
    if content.SetScale then
        Take(content, "scale")
        content:SetScale(1 / (skills and SKILL_LIST_SCALE or REP_LIST_SCALE))
    end
    -- A faction's row opens the old detail box.
    if not skills then ns.HookScriptOnce(row, "OnClick", RepRowClick) end
    ns.FadeAtlas(bar, "stat-bar-bg", false, Fade)
    ns.EachRegion(content.BackgroundHighlight, Fade)
    if content.AccountWideIcon then Fade(content.AccountWideIcon) end
    Take(bar, "size", "points")
    bar:ClearAllPoints()
    if skills then
        bar:SetPoint("LEFT", row, "LEFT", 20, 0)
        bar:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        bar:SetHeight(15)
    else
        bar:SetSize(BAR_W, BAR_H)
        bar:SetPoint("LEFT", row, "LEFT", 130, 0)
    end
    -- Old gradient fill under the art, in the client's colour or skill blue.
    local fill = bar.Fill
    if fill then
        Take(fill, "art", "layer", "size", "points", "masks")
        if bar.Mask and fill.RemoveMaskTexture then pcall(fill.RemoveMaskTexture, fill, bar.Mask) end
        ns.SetTex(fill, "skillsBar")
        fill:SetDrawLayer("BACKGROUND", 0)
        fill:ClearAllPoints()
        if skills then
            fill:SetHeight(15)
            fill:SetPoint("LEFT", bar, "LEFT", 0, 0)
        else
            fill:SetHeight(BAR_H - 2)
            fill:SetPoint("LEFT", bar, "LEFT", 1, 0)
        end
        bar.fcuiInset = skills and 0 or 2
        bar.fcuiCoords = skills and SKILL_COORDS or REP_COORDS
        -- These outlive the sheet, so each checks it is still on.
        if ns.Once(bar, "fill") then
            -- The percent comes before a new or reused row is laid out (the template's narrower width then): fitted
            -- again as the real width lands, before the draw.
            local watch = CreateFrame("Frame", nil, bar)
            watch:SetAllPoints(bar)
            watch:SetScript("OnSizeChanged", function() if T.active then FitFill(bar) end end)
            hooksecurefunc(bar, "SetFillWidth", function(self, width)
                if not T.active then return end
                if fillShare[self] then return FitFill(self) end
                self.Fill:SetWidth(math.max(0, math.min(width, self:GetWidth() - (self.fcuiInset or 0))))
            end)
            hooksecurefunc(bar, "SetFillTextureByColorType", function(self)
                if not T.active then return end
                ns.SetTex(self.Fill, "skillsBar")
                self.Fill:SetTexCoord(unpack(self.fcuiCoords))
            end)
            if bar.SetFillPercent then
                ns.HookMethod(bar, "SetFillPercent", function(self, percent)
                    if not T.active then return end
                    fillShare[self] = type(percent) == "number" and math.min(1, math.max(0, percent)) or nil
                    self.Fill:SetTexCoord(unpack(self.fcuiCoords))
                    FitFill(self)
                    ns.Sched.NextFrame("sheet.fills", FitAllFills)
                end)
            end
            if skills and bar.UpdateBarColor then
                hooksecurefunc(bar, "UpdateBarColor", function(self)
                    if T.active then self.Fill:SetVertexColor(SKILL_BLUE[1], SKILL_BLUE[2], SKILL_BLUE[3]) end
                end)
            end
            -- 1.x wrote the rank as 250/300.
            if skills and bar.SetText then
                hooksecurefunc(bar, "SetText", function(self, text)
                    if not T.active then return end
                    if type(text) == "string" and text:find(" / ", 1, true) then self.Text:SetText((text:gsub(" / ", "/"))) end
                end)
            end
        end
        fill:SetTexCoord(unpack(bar.fcuiCoords))
        if skills then fill:SetVertexColor(SKILL_BLUE[1], SKILL_BLUE[2], SKILL_BLUE[3]) end
        fill:SetWidth(math.max(0, math.min(fill:GetWidth(), bar:GetWidth() - bar.fcuiInset)))
    end
    local name = Own(ns.OwnFontString(bar, "name", "OVERLAY", skills and "GameFontNormalSmall" or "GameFontHighlightSmall"))
    name:SetFontObject(skills and "GameFontNormalSmall" or "GameFontHighlightSmall")
    name:SetText(content.Name and content.Name:GetText() or "")
    name:SetWordWrap(false)
    name:SetJustifyH("LEFT")
    name:ClearAllPoints()
    name:Show()
    if content.Name then Fade(content.Name) end
    if skills then
        name:SetPoint("LEFT", bar, "LEFT", 6, 1)
        name:SetWidth(0)
        Own(ns.DressNew(bar, "skillsBarBorder", SKILL_BORDER))
        if bar.Text then
            Take(bar.Text, "font", "width", "points", "justify")
            bar.Text:SetFontObject("GameFontHighlightSmall")
            ns.SetPointOnce(bar.Text, "LEFT", name, "RIGHT", 10, -1)
            bar.Text:SetWidth(128)
            bar.Text:SetJustifyH("LEFT")
            local text = bar.Text:GetText()
            if type(text) == "string" and text:find(" / ", 1, true) then bar.Text:SetText((text:gsub(" / ", "/"))) end
        end
    else
        name:SetPoint("LEFT", bar, "LEFT", -119, 0)
        name:SetWidth(104)
        if bar.Text then
            Take(bar.Text, "font")
            bar.Text:SetFontObject("GameFontHighlightSmall")
        end
        ns.DressPieces(bar, REP_PLATE, nil, PLATE_PAIR)
        Own(PLATE_PAIR[1])
        Own(PLATE_PAIR[2])
    end
    -- Collapse button becomes the old plus; a row child, not content, so scaled back alone.
    local toggle = row.ToggleCollapseButton
    if toggle then
        Take(toggle, "scale")
        T.TakeFaces(toggle)
        if toggle:GetParent() == row then toggle:SetScale(1 / (skills and SKILL_LIST_SCALE or REP_LIST_SCALE)) end
        toggle:SetSize(16, 16)
        toggle:ClearAllPoints()
        if skills then
            toggle:SetPoint("RIGHT", bar, "LEFT", -2, 0)
        else
            toggle:SetPoint("RIGHT", bar, "LEFT", -122, 0)
        end
        ns.DressStates(toggle, ns.ART.PLUS, ns.ART.PLUS_DOWN, nil, nil, TOGGLE)
    end
end
T.SkinListEntry = SkinListEntry

-- Header name and plus/minus on our own holder, scaled back up from the small row.
local function SkinSkillHeader(row, scale, font)
    ns.FadeAtlas(row, "collapseexpand", false, Fade)
    if row.StateIcon then Fade(row.StateIcon) end
    local holder = row.fcuiHolder
    if not holder then
        holder = CreateFrame("Frame", nil, row)
        holder:SetAllPoints(row)
        row.fcuiHolder = holder
    end
    Own(holder):Show()
    holder:SetScale(1 / (scale or SKILL_LIST_SCALE))
    local name = ns.OwnFontString(holder, "name", "OVERLAY", font or "GameFontHighlight")
    name:SetFontObject(font or "GameFontHighlight")
    name:SetText(row.Name and row.Name:GetText() or "")
    ns.SetPointOnce(name, "LEFT", holder, "LEFT", 26, 0)
    if row.Name then Fade(row.Name) end
    local icon = ns.OwnTexture(holder, "collapseIcon", "ARTWORK")
    ns.SetCollapseIcon(icon, row.IsCollapsed and row:IsCollapsed())
    ns.Dress(icon, nil, COLLAPSE_ICON, holder)
end

local function SkinRepHeader(row, barKey)
    if barKey == "SkillsBar" then return SkinSkillHeader(row) end
    -- Reputation headers in their own gold, on the same scaled frame.
    if barKey == "ReputationBar" then return SkinSkillHeader(row, REP_LIST_SCALE, "GameFontNormal") end
    ns.FadeAtlas(row, "collapseexpand", false, Fade)
    if row.Name then
        Take(row.Name, "font", "points")
        row.Name:SetFontObject("GameFontNormal")
        ns.SetPointOnce(row.Name, "LEFT", row, "LEFT", 26, 0)
    end
    if row.StateIcon then Fade(row.StateIcon) end
    local icon = Own(ns.OwnTexture(row, "collapseIcon", "ARTWORK"))
    ns.SetCollapseIcon(icon, row.IsCollapsed and row:IsCollapsed())
    ns.Dress(icon, nil, COLLAPSE_ICON, row)
end

local function SkinListRow(row, barKey)
    if not T.active then return end
    -- A row just acquired has no data; the header methods index it.
    if row.GetElementData and row:GetElementData() == nil then return end
    if row.Content then SkinListEntry(row, barKey) else SkinRepHeader(row, barKey) end
end

-- The shared knob reshows on every scroll, so with the sheet off it goes to alpha 0, not Hide.
local function KnobSeen(bar, seen)
    local track = bar and bar.Track
    local knob = track and track.fcui and track.fcui.knob
    if knob then knob:SetAlpha(seen and 1 or 0) end
end
T.KnobSeen = KnobSeen

local TakeAlpha = T.TakeAlpha

-- The thumb's three pieces, which the old knob fades.
function T.TakeThumb(track)
    local thumb = track and track.Thumb
    if not thumb then return end
    Take(thumb, "width")
    ns.EachKey(thumb, ns.KEYS.THUMB, TakeAlpha)
end

-- The 256-tall top piece overruns short bars (skills); cut to what the foot piece leaves.
local function FitTop(bar)
    local top = bar.fcui.trackTop
    local tall = math.max(1, math.min(256, (bar:GetHeight() or 256) + 17 - 108))
    top:SetHeight(tall)
    top:SetTexCoord(0, 0.484375, 0, tall / 256)
end

local function FadeFace(tex) Fade(tex) end
local function FadeUnless(region, keep)
    if region ~= keep then Fade(region) end
end

-- Only our arrow is drawn; the client's chevron would sit under it.
local function DressArrow(button, kind)
    if not button then return end
    Take(button, "size", "points")
    if button.Texture then Fade(button.Texture) end
    button:SetSize(16, 16)
    local tex = Own(ns.DressNew(button, "scroll" .. kind .. "ButtonUp", ARROW))
    ns.EachState(button, ns.KEYS.STATES, FadeFace)
    ns.EachTexture(button, FadeUnless, tex)
end

-- Client bar in the old track, knob and arrows; redressed each Apply, the hook added once.
local function SkinRepScrollBar(bar)
    if not bar then return end
    bar.fcuiTrackArt = true   -- the windows' general track art stays off
    Own(ns.DressNew(bar, "charScrollBar", TRACK_TOP))
    ns.HookScriptOnce(bar, "OnSizeChanged", FitTop)
    FitTop(bar)
    Own(ns.DressNew(bar, "charScrollBar", TRACK_BOTTOM))
    local track = bar.Track
    if track then
        ns.EachKey(track, ns.KEYS.THUMB, Fade)
        T.TakeThumb(track)
        if track.Thumb then track.Thumb:SetWidth(16) end
        -- The arrows stand 4 further out than the client's.
        bar.fcuiKnobReach = 7
        ns.ClassicKnob(bar)
        KnobSeen(bar, true)
    end
    DressArrow(bar.Back, "Up")
    DressArrow(bar.Forward, "Down")
    -- On the track art: 3 right of the bar, 4 past each end.
    ns.SetPointOnce(bar.Back, "TOP", bar, "TOP", 3, 4)
    ns.SetPointOnce(bar.Forward, "BOTTOM", bar, "BOTTOM", 3, -4)
end

-- Rows are polled, never registered for: a list registry callback runs inside the client's
-- row pass and taints the rows (clicks run as ours, health text then compares a secret).
-- Per list: its look frame, carrying the two visitors.
local listHooked = setmetatable({}, { __mode = "k" })

-- Every 0.05 s while up: the picked skill first (client's Refresh hook runs before ours),
-- then rows whose data changed.
local function LookTick(job)
    if not T.active then return end
    local look = job.host
    if look.pick and C_SkillInfo and C_SkillInfo.GetSelectedSkill then
        local ok, index = pcall(C_SkillInfo.GetSelectedSkill)
        if ok and index ~= look.index then
            look.index = index
            ns.SafeCall(T.SkinSkillDetail)
        end
    end
    local box = look.box
    if box.ForEachFrame then box:ForEachFrame(look.visit) end
end

local function Look(frame, box, barKey)
    local look = CreateFrame("Frame", nil, frame)
    look.box = box
    look.dress = function(row) SkinListRow(row, barKey) end
    look.visit = function(row)
        local data = row.GetElementData and row:GetElementData()
        if data ~= nil and row.fcuiDressedFor ~= data then
            row.fcuiDressedFor = data
            SkinListRow(row, barKey)
        end
    end
    ns.Sched.OnFrame(look, { name = "sheet.look", every = 0.05, fn = LookTick })
    return look
end

local function HideDetail(frame)
    if T.active and frame.SkillDetailFrame then frame.SkillDetailFrame:Hide() end
end

-- Offsets are in the list's own scale; no scale leaves the box's as is.
local function AnchorList(box, k, bottom)
    local s = k or 1
    if k then box:SetScale(k) end
    box:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 12 / s, -76 / s)
    box:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -66 / s, bottom / s)
end

local function FadeScrollLines(child, target)
    if child ~= target then ns.FadeAtlas(child, "scrollline", false, Fade) end
end

local function SkinListFrame(frame, barKey)
    local box = frame and frame.ScrollBox
    if not box then return end
    local look = listHooked[frame]
    if not look then
        look = Look(frame, box, barKey)
        listHooked[frame] = look
        -- The client re-initialises a row on every data change.
        if box.ForEachFrame and type(frame.Update) == "function" then
            ns.HookMethod(frame, "Update", function()
                if T.active and box.ForEachFrame then box:ForEachFrame(look.dress) end
            end)
        end
    end
    if not T.active then return end
    -- Keep the client's row heights and padding: ours would taint its layout pass and rows
    -- stop on secrets in combat. Pitch comes from the list's scale alone.
    Take(box, "scale", "points")
    box:ClearAllPoints()
    if barKey == "SkillsBar" then
        AnchorList(box, SKILL_LIST_SCALE, 86 + T.DETAIL_H + 14)
        T.SkinSkillDetail()
        local detail = frame.SkillDetailFrame
        if detail and ns.Once(detail, "skillDetailHooked") then
            ns.HookMethod(detail, "Refresh", T.SkinSkillDetail)
            look.pick = true
            frame:HookScript("OnShow", T.SkinSkillDetail)
            -- Reparented to the window, so it no longer hides with the tab.
            frame:HookScript("OnHide", HideDetail)
        end
    elseif barKey == "ReputationBar" then
        AnchorList(box, REP_LIST_SCALE, 86)
    else
        AnchorList(box, nil, 86)
    end
    ns.EachChild(box, FadeScrollLines, box.ScrollTarget)
    if frame.ScrollBar then
        Take(frame.ScrollBar, "points")
        SkinRepScrollBar(frame.ScrollBar)
        frame.ScrollBar:ClearAllPoints()
        frame.ScrollBar:SetPoint("TOPLEFT", box, "TOPRIGHT", 6, -4)
        frame.ScrollBar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 6, 4)
    end
    if box.ForEachFrame then box:ForEachFrame(look.dress) end
    if frame.filterDropdown then
        Take(frame.filterDropdown, "points")
        ns.SetPointOnce(frame.filterDropdown, "TOPRIGHT", CharacterFrame, "TOPRIGHT", -40, -62)
    end
end

local function SkinReputation()
    local rep = ReputationFrame
    SkinListFrame(rep, "ReputationBar")
    if rep and T.active then
        -- Clear of the portrait ring (it reaches 81 across), on Standing's line.
        local faction = Own(ns.OwnFontString(rep, "factionLabel", "ARTWORK", "GameFontHighlight"))
        faction:SetText(FACTION or "Faction")
        ns.SetPointOnce(faction, "TOPLEFT", CharacterFrame, "TOPLEFT", 86, -59)
        faction:Show()
        local standing = Own(ns.OwnFontString(rep, "standingLabel", "ARTWORK", "GameFontHighlight"))
        standing:SetText(STANDING or "Standing")
        ns.SetPointOnce(standing, "TOPLEFT", CharacterFrame, "TOPLEFT", 215, -59)
        standing:Show()
    end
end

local function SkinPvP()
    local pvp = PVPRankFrame
    local main = pvp and pvp.MainInfoFrame
    if not main or not T.active then return end
    Take(main, "points")
    main:ClearAllPoints()
    main:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 6, -70)
    main:SetPoint("BOTTOMRIGHT", CharacterFrame, "TOPRIGHT", -6, -205)
end

local LIST_TABS = { { "SkillsFrame", "SkillsBar" }, { "TokenFrame" }, { "StatisticsFrame" } }
function T.SkinListTabs()
    SkinReputation()
    SkinPvP()
    for _, entry in ipairs(LIST_TABS) do
        SkinListFrame(_G[entry[1]], entry[2])
    end
end

function T.HookListTabs()
    if ReputationFrame then ReputationFrame:HookScript("OnShow", SkinReputation) end
    if PVPRankFrame then PVPRankFrame:HookScript("OnShow", SkinPvP) end
    for _, entry in ipairs(LIST_TABS) do
        local frame = _G[entry[1]]
        if frame then
            local key = entry[2]
            frame:HookScript("OnShow", function(self) SkinListFrame(self, key) end)
        end
    end
end

-- Knobs kept unseen; every row dressed afresh when the sheet is next on.
local GIVE_BACK = { "ReputationFrame", "SkillsFrame", "TokenFrame", "StatisticsFrame" }
local function Undress(row) row.fcuiDressedFor = nil end
function T.ListsGiveBack()
    for _, name in ipairs(GIVE_BACK) do
        local list = _G[name]
        KnobSeen(list and list.ScrollBar, false)
        local box = list and list.ScrollBox
        if box and box.ForEachFrame then pcall(box.ForEachFrame, box, Undress) end
    end
end

