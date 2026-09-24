-- Settings window as the old options dialog. The client's panel and controls keep their
-- behavior; their art is faded and ours laid under. No client field is written.
local _, ns = ...

-- Gray, not black: a lighter inset, not a hole.
local INSET = { bg = { 0.34, 0.32, 0.30, 0.55 }, bgFirst = true, base = { 0.6, 0.6, 0.6, 1 } }
-- Opaque like the old dialog.
local SOLID = { bg = { 1, 1, 1, 1 } }
local PANEL_HEADER = { own = "plate", restyle = true, fontObject = ns.FONT_GOLD }
local CHILDREN = { children = true }

local active = false

-- A thin-bordered inset, kept in parent.fcui[key], over anchorTo's rect.
local function Inset(parent, key, anchorTo, l, t, r, b)
    parent.fcui = parent.fcui or {}
    local inset = parent.fcui[key]
    if not inset then
        inset = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        ns.Backdrop(inset, ns.BACKDROP.TIP16, INSET)
        inset:SetFrameLevel(parent:GetFrameLevel())
        parent.fcui[key] = inset
    end
    inset:ClearAllPoints()
    inset:SetPoint("TOPLEFT", anchorTo, "TOPLEFT", l, t)
    inset:SetPoint("BOTTOMRIGHT", anchorTo, "BOTTOMRIGHT", r, b)
    inset:Show()
    return inset
end

------------------------------------------------------------------ rows

-- The old yellow; the client's normal font runs to bronze.
local function Yellow(text)
    if text and text.SetTextColor then text:SetTextColor(1, 0.82, 0) end
end

local function SkinSettingRow(row)
    if not active or not row then return end
    Yellow(row.Text)
    if row.Checkbox then ns.SkinCheckbox(row.Checkbox) end
    if row.SliderWithSteppers then ns.SkinSliderWithSteppers(row.SliderWithSteppers) end
    if row.Control then
        if row.Control.Dropdown then ns.SkinDropdown(row.Control.Dropdown) end
        if row.Control.IncrementButton then ns.SkinStepper(row.Control.IncrementButton, true) end
        if row.Control.DecrementButton then ns.SkinStepper(row.Control.DecrementButton, false) end
    end
    local button = row.Button
    if button and button.IsObjectType and button:IsObjectType("Button") then
        local left = button.Left
        local atlas = left and left.GetAtlas and left:GetAtlas() or ""
        if atlas:find("ListExpand") then
            -- Keybinding group header: a plain yellow title, as the old list had.
            if ns.Once(button, "settingsHeader") then
                ns.FadeRegions(button)
                local hl = button:GetHighlightTexture()
                if hl then hl:SetAlpha(0) end
                if button.Text then
                    button.Text:SetFontObject(ns.FONT_GOLD)
                    Yellow(button.Text)
                    button.Text:SetJustifyH("LEFT")
                    button.Text:ClearAllPoints()
                    button.Text:SetPoint("LEFT", button, "LEFT", 8, 0)
                    button.Text:SetPoint("RIGHT", button, "RIGHT", -8, 0)
                end
                local glow = ns.OwnTexture(button, "headerGlow", "HIGHLIGHT")
                ns.SetTex(glow, "questLogHighlight")
                glow:SetTexCoord(0, 1, 0, 1)
                glow:SetBlendMode("ADD")
                glow:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -4)
                glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 4)
            end
        else
            ns.SkinRedButton(button)
        end
    end
    -- A section header in the page (Mouse, Camera): white.
    if row.Title and row.Title.SetFontObject and not row.Text then row.Title:SetFontObject("GameFontHighlightLarge") end
end

local function YellowWhileActive(label)
    if active then Yellow(label) end
end

-- White gradient tinted yellow, like the old selected line.
local function DressSelection(tex)
    ns.SetTex(tex, "questLogHighlight")
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetVertexColor(1, 1, 0)
    tex:SetBlendMode("ADD")
end

local function SelectionAtlasSet(tex)
    if active then DressSelection(tex) end
end

local function SkinCategoryRow(row)
    if not active or not row or not ns.Once(row, "settingsCategory") then return end
    -- Group headers (Gameplay, System...) white, apart from the gold categories.
    if row.Background then
        row.Background:SetAlpha(0)
        if row.Label then row.Label:SetFontObject("GameFontHighlight") end
    end
    -- The client resets its atlas on every selection; ours is reapplied after.
    local tex = row.Texture
    if tex and row.IsObjectType and row:IsObjectType("Button") then
        if row.Label then
            Yellow(row.Label)
            hooksecurefunc(row.Label, "SetFontObject", YellowWhileActive)
        end
        DressSelection(tex)
        hooksecurefunc(tex, "SetAtlas", SelectionAtlasSet)
    end
end

-- Pooled rows are reused on scroll; redress only when their data changes.
local function DressSettingRowOnChange(row)
    local data = row.GetElementData and row:GetElementData()
    if data == nil or row.fcuiDressedFor ~= data then
        row.fcuiDressedFor = data
        SkinSettingRow(row)
    end
end

------------------------------------------------------------------ panel

local lookJob

-- Rows polled from our own watcher, never client list callbacks: those taint the rest of the client's pass.
local function LookPass()
    if not active then return end
    local panel = SettingsPanel
    local cats = panel.CategoryList and panel.CategoryList.ScrollBox
    if cats and cats.ForEachFrame then cats:ForEachFrame(SkinCategoryRow) end
    local rows = panel.Container and panel.Container.SettingsList and panel.Container.SettingsList.ScrollBox
    if rows and rows.ForEachFrame then rows:ForEachFrame(DressSettingRowOnChange) end
end

local function SkinPanel()
    local panel = SettingsPanel
    if not panel or not ns.Once(panel, "settingsPanel") then return end
    panel.fcui = panel.fcui or {}
    -- Fade the bronze border and backing; the old dialog box goes under.
    ns.FadeTextures(panel.NineSlice)
    ns.FadeTextures(panel.Bg, 0, CHILDREN)
    ns.FadeTextures(panel)
    panel.fcui.box = ns.DialogBacking(panel, nil, SOLID)
    -- The header plate under the client's title.
    ns.DialogHeader(panel, nil, PANEL_HEADER, panel, panel.NineSlice and panel.NineSlice.Text)
    ns.SkinCloseButton(panel.ClosePanelButton, true)
    ns.SetPointOnce(panel.ClosePanelButton, "TOPRIGHT", panel, "TOPRIGHT", -4, -4)
    ns.SkinMinimalTab(panel.GameTab)
    ns.SkinMinimalTab(panel.AddOnsTab)
    ns.SkinRedButton(panel.CloseButton)
    ns.SkinRedButton(panel.ApplyButton)
    local categories = panel.CategoryList
    if categories then
        -- The old list box stood well in from the window's edge.
        local listInset = Inset(panel, "listInset", categories, 0, 8, 8, -8)
        -- The tabs stand on its top edge; the AddOns tab follows the Game tab.
        ns.SetPointOnce(panel.GameTab, "BOTTOMLEFT", listInset, "TOPLEFT", 10, -2)
        ns.SkinMinimalScrollBar(categories.ScrollBar)
        if categories.ScrollBox and categories.ScrollBox.ForEachFrame then categories.ScrollBox:ForEachFrame(SkinCategoryRow) end
    end
    if panel.Container then Inset(panel, "pageInset", panel.Container, -8, 8, 8, -8) end
    local list = panel.Container and panel.Container.SettingsList
    if list then
        if list.Header then
            ns.FadeRegions(list.Header)
            if list.Header.DefaultsButton then ns.SkinRedButton(list.Header.DefaultsButton) end
            if list.Header.Title then list.Header.Title:SetFontObject("GameFontHighlightLarge") end
        end
        ns.SkinMinimalScrollBar(list.ScrollBar)
        if list.ScrollBox and list.ScrollBox.ForEachFrame then list.ScrollBox:ForEachFrame(SkinSettingRow) end
    end
    if not lookJob then
        lookJob = ns.Sched.OnFrame(CreateFrame("Frame", nil, panel), { name = "settings.look", every = 0.05, fn = LookPass })
    end
end

local hooked = false
local function Apply()
    active = true
    if not SettingsPanel then ns.MissingPiece("SettingsPanel") return end
    -- Re-enabled with the window up: poll next frame, not 0.05s later.
    if lookJob then lookJob:Kick() end
    if not hooked then
        hooked = true
        SettingsPanel:HookScript("OnShow", function() if active then SkinPanel() end end)
    end
    if SettingsPanel:IsShown() then SkinPanel() end
end

local function Restore()
    active = false
    ns.needsReload = true
end

ns.RegisterModule("settingsPanel", { apply = Apply, restore = Restore })
