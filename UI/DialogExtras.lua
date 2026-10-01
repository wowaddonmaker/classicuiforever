local _, ns = ...

-- Our settings under the client's edit mode dialog for its own systems (swing timers, resource display): a panel
-- follows the dialog while one of those is picked. Our settings only; the client's are read, never written (a write
-- from our code taints every edit mode system).

local PANEL_W_PAD, ROW_H = 26, 36
local specs = {}     -- { match(system), title, build(panel), fill(panel) }
local panels = {}    -- spec -> its panel
local watching = false

local function Dialog() return _G.EditModeSystemSettingsDialog end

local function Panel(spec)
    local panel = panels[spec]
    if panel then return panel end
    local B = ns.band
    -- On UIParent, never the dialog: the dialog sizes itself to its children, and one pinned to its width grew it without end.
    panel = CreateFrame("Frame", nil, UIParent)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(200)
    B.PanelBorder(panel)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_W_PAD, -18)
    title:SetText(spec.title)
    panel.title = title
    panel.rows = 0
    spec.build(panel)
    panel:SetHeight(40 + panel.rows * ROW_H + (panel.extraH or 0))
    panels[spec] = panel
    return panel
end

local function Follow()
    local dialog = Dialog()
    local system = dialog and dialog:IsShown() and dialog.attachedToSystem
    for _, spec in ipairs(specs) do
        local up = system and spec.match(system)
        local panel = panels[spec]
        if up then
            panel = Panel(spec)
            ns.SetPointOnce(panel, "TOPLEFT", dialog, "BOTTOMLEFT", 0, 6)
            panel:SetPoint("TOPRIGHT", dialog, "BOTTOMRIGHT", 0, 6)
            if not panel:IsShown() then
                spec.fill(panel)
                panel:Show()
            end
        elseif panel and panel:IsShown() then
            panel:Hide()
        end
    end
end

local function Watch()
    local dialog = Dialog()
    if watching or not dialog then return end
    watching = true
    -- Watchers on the dialog's border, out of its layout: a child of the dialog itself stretched it to the screen.
    local host = dialog.Border or dialog
    ns.Sched.Attach(host, { name = "dialogExtras.follow", every = 0.1, fn = Follow })
    ns.Sched.OnVisible(host, "dialogExtras.shown", function(shown) if not shown then Follow() end end)
end

-- A labelled stepper slider row: init() -> value, low, high, steps; onChange(value). Returns its fill function.
function ns.DialogExtraSlider(panel, label, init, onChange)
    local B = ns.band
    local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    text:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -14 - panel.rows * ROW_H)
    text:SetWidth(130)
    text:SetJustifyH("LEFT")
    text:SetText(label)
    panel.rows = panel.rows + 1
    local slider, formatters = B.StepperSlider(panel, 180, text, 6, function(v) return tostring(math.floor(v + 0.5)) end)
    if not slider then return function() end end
    return B.GuardedSlider(slider, init, onChange, { formatters = formatters, owner = panel })
end

-- The client's default for each setting of a system, from the Modern preset, as the dialog shows them.
function ns.ClientDefaults(frame)
    local presets = _G.EditModePresetLayoutManager
    local ok, layouts = pcall(presets and presets.GetCopyOfPresetLayouts, presets)
    local layout = ok and type(layouts) == "table" and layouts[1]
    if not (layout and frame and frame.system) then return nil end
    local map = frame.settingDisplayInfoMap or ns.EMPTY
    for _, info in ipairs(layout.systems or ns.EMPTY) do
        if info.system == frame.system and (info.systemIndex == nil or info.systemIndex == frame.systemIndex) then
            local parts = {}
            for _, setting in ipairs(info.settings or ns.EMPTY) do
                local display = map[setting.setting]
                if display and display.name then
                    local value = setting.value
                    if display.options then
                        for _, option in ipairs(display.options) do
                            if option.value == value then value = option.text break end
                        end
                    elseif display.minValue and display.ConvertValueForDisplay then
                        local okShown, shown = pcall(display.ConvertValueForDisplay, display, value)
                        if okShown and type(shown) == "number" then value = math.floor(shown * 100 + 0.5) / 100 end
                    elseif value == 0 or value == 1 then
                        value = value == 1 and "on" or "off"
                    end
                    parts[#parts + 1] = display.name .. " " .. tostring(value)
                end
            end
            return table.concat(parts, ", ")
        end
    end
end

-- spec: { match(system), title, build(panel), fill(panel) }.
function ns.DialogExtra(spec)
    specs[#specs + 1] = spec
    Watch()
end

ns.EventFrame("PLAYER_LOGIN", Watch)
