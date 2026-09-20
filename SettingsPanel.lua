-- The settings window in the dress of the old options dialogs: the
-- dialog box with its header plate, the category list and the page
-- each in a thin-bordered inset, the old blue bar under the chosen
-- category, and every control in the old widget art. Blizzard's panel,
-- lists and controls keep their behavior; their art is faded and ours
-- laid under, and no field of Blizzard's is written.
local _, ns = ...

local DIALOG_BG = "Interface\\DialogFrame\\UI-DialogBox-Background"
local DIALOG_BORDER = "Interface\\DialogFrame\\UI-DialogBox-Border"
local DIALOG_HEADER = "Interface\\DialogFrame\\UI-DialogBox-Header"
local INSET_BG = "Interface\\Tooltips\\UI-Tooltip-Background"
local INSET_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"

local active = false

-- A thin-bordered inset of the old options, as a frame under `frame`.
local function Inset(parent, key, anchorTo, l, t, r, b)
    parent.fcui = parent.fcui or {}
    local inset = parent.fcui[key]
    if not inset then
        inset = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        inset:SetBackdrop({
            bgFile = INSET_BG, edgeFile = INSET_BORDER, tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        -- Gray over the dialog's stone rather than black: the old insets
        -- read as a lighter panel set into the window, not a hole in it.
        inset:SetBackdropColor(0.34, 0.32, 0.30, 0.55)
        inset:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
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

-- The old yellow on a label; the client's normal font runs to bronze.
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
            -- A section header that expands its bindings: the old list
            -- showed these as plain yellow titles, not buttons.
            if not button.fcuiHeader then
                button.fcuiHeader = true
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
    -- A section header inside the page: the old yellow.
    -- A section header inside the page (Mouse, Camera): white, apart from the gold rows.
    if row.Title and row.Title.SetFontObject and not row.Text then row.Title:SetFontObject("GameFontHighlightLarge") end
end

local function SkinCategoryRow(row)
    if not active or not row or row.fcuiCategory then return end
    row.fcuiCategory = true
    -- A group header (Gameplay, Accessibility, System): white, so it
    -- stands apart from the gold categories under it.
    if row.Background then
        row.Background:SetAlpha(0)
        if row.Label then row.Label:SetFontObject("GameFontHighlight") end
    end
    -- The chosen category wears the old yellow highlight; Blizzard puts
    -- its own atlas back on every selection, so ours follows each time.
    local tex = row.Texture
    if tex and row.IsObjectType and row:IsObjectType("Button") then
        if row.Label then
            Yellow(row.Label)
            hooksecurefunc(row.Label, "SetFontObject", function(label) if active then Yellow(label) end end)
        end
        local function Dress()
            ns.SetTex(tex, "questLogHighlight")
            tex:SetTexCoord(0, 1, 0, 1)
            -- The sheet is a white gradient, made to be tinted: the old
            -- options list tinted the chosen line's pure yellow, and left
            -- white it reads as a gray bar.
            tex:SetVertexColor(1, 1, 0)
            tex:SetBlendMode("ADD")
        end
        Dress()
        hooksecurefunc(tex, "SetAtlas", function() if active then Dress() end end)
    end
end

------------------------------------------------------------------ panel

local function SkinPanel()
    local panel = SettingsPanel
    if not panel or panel.fcuiSkinned then return end
    panel.fcuiSkinned = true
    panel.fcui = panel.fcui or {}
    -- The bronze border and backing fade; the old dialog box goes under.
    if panel.NineSlice then
        for _, region in ipairs({ panel.NineSlice:GetRegions() }) do
            if region:IsObjectType("Texture") then region:SetAlpha(0) end
        end
    end
    if panel.Bg then
        ns.FadeRegions(panel.Bg)
        for _, child in ipairs({ panel.Bg:GetChildren() }) do ns.FadeRegions(child) end
    end
    ns.FadeRegions(panel)
    local box = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    box:SetBackdrop({
        bgFile = DIALOG_BG, edgeFile = DIALOG_BORDER, tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    box:SetAllPoints(panel)
    box:SetFrameLevel(panel:GetFrameLevel())
    -- The old options dialog stood solid: its stone hid the world behind
    -- it rather than letting the ground read through the page.
    box:SetBackdropColor(1, 1, 1, 1)
    panel.fcui.box = box
    -- The header plate with Blizzard's title on it.
    local plate = ns.OwnTexture(panel, "plate", "ARTWORK", 0)
    plate:SetTexture(DIALOG_HEADER)
    plate:SetSize(256, 64)
    plate:ClearAllPoints()
    plate:SetPoint("TOP", panel, "TOP", 0, 12)
    plate:Show()
    local title = panel.NineSlice and panel.NineSlice.Text
    if title then
        title:SetFontObject(ns.FONT_GOLD)
        title:ClearAllPoints()
        title:SetPoint("TOP", plate, "TOP", 0, -14)
    end
    ns.SkinCloseButton(panel.ClosePanelButton, true)
    if panel.ClosePanelButton then
        panel.ClosePanelButton:ClearAllPoints()
        panel.ClosePanelButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
    end
    ns.SkinMinimalTab(panel.GameTab)
    ns.SkinMinimalTab(panel.AddOnsTab)
    ns.SkinRedButton(panel.CloseButton)
    ns.SkinRedButton(panel.ApplyButton)
    -- The category list and the page, each in a thin-bordered inset.
    local categories = panel.CategoryList
    if categories then
        -- The old dialog kept its list box well in from the window's edge.
        local listInset = Inset(panel, "listInset", categories, 0, 8, 8, -8)
        -- The tabs stand on that box: the active tab's open foot meets
        -- the box's top edge. The AddOns tab follows the Game tab.
        if panel.GameTab then
            panel.GameTab:ClearAllPoints()
            panel.GameTab:SetPoint("BOTTOMLEFT", listInset, "TOPLEFT", 10, -2)
        end
        ns.SkinMinimalScrollBar(categories.ScrollBar)
        if categories.ScrollBox and categories.ScrollBox.RegisterCallback and ScrollBoxListMixin and ScrollBoxListMixin.Event then
            categories.ScrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, function(_, row) SkinCategoryRow(row) end, panel)
            if categories.ScrollBox.ForEachFrame then categories.ScrollBox:ForEachFrame(SkinCategoryRow) end
        end
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
        if list.ScrollBox and list.ScrollBox.RegisterCallback and ScrollBoxListMixin and ScrollBoxListMixin.Event then
            list.ScrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, function(_, row) SkinSettingRow(row) end, panel)
            if list.ScrollBox.ForEachFrame then list.ScrollBox:ForEachFrame(SkinSettingRow) end
        end
    end
end

local hooked = false
local function Apply()
    active = true
    if not SettingsPanel then ns.MissingPiece("SettingsPanel") return end
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
