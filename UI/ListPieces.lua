local _, ns = ...

-- Building pieces for the 1.x list windows.

-- The name plate art has 11 px of empty margin (128x64): scale the texture up to fit.
local PLATE_W, PLATE_H, PLATE_PAD = 106 / 128, 42 / 64, 11 / 128
-- The drawn plate's left edge leftInset from host's relPoint (default its LEFT).
function ns.FitNamePlate(box, host, leftInset, width, height, relPoint)
    local texW, texH = width / PLATE_W, height / PLATE_H
    box:SetSize(texW, texH)
    ns.SetPointOnce(box, "LEFT", host, relPoint or "LEFT", leftInset - PLATE_PAD * texW, 0)
end

local COLUMN_TABS = "Interface\\FriendsFrame\\WhoFrame-ColumnTabs"

-- List pane shade, shared by the social lists and the trade skill window.
ns.PANE_SHADE = 0.9

function ns.SectionBox(parent)
    local box = CreateFrame("Frame", nil, parent)
    -- Faint lift so neighbouring dark sections do not read as one.
    local lift = box:CreateTexture(nil, "BACKGROUND")
    lift:SetAllPoints(box)
    lift:SetColorTexture(1, 0.96, 0.88, 0.03)
    return box
end

local STONE_LIT = { coords = { 0, 1, 0, 1 }, shade = { 1.25, 1.2, 1.1 } }

function ns.StoneFill(frame, layer)
    return ns.TileTex(frame:CreateTexture(nil, layer or "ARTWORK"), "rockBg", STONE_LIT)
end

-- Section divider: stone with a lit top and a dark foot.
local STONE_EDGES = { { "TOP", 0.52, 0.48, 0.40 }, { "BOTTOM", 0.06, 0.05, 0.04 } }
function ns.StoneBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(6)
    local stone = ns.TileTex(bar:CreateTexture(nil, "ARTWORK"), "rockBg", STONE_LIT)
    stone:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -1)
    stone:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 1)
    for _, edge in ipairs(STONE_EDGES) do
        local line = bar:CreateTexture(nil, "OVERLAY")
        line:SetColorTexture(edge[2], edge[3], edge[4], 1)
        line:SetHeight(1)
        line:SetPoint(edge[1] .. "LEFT", bar, edge[1] .. "LEFT", 0, 0)
        line:SetPoint(edge[1] .. "RIGHT", bar, edge[1] .. "RIGHT", 0, 0)
    end
    return bar
end

-- The old who-list column tab in three slices, one per column.
local COLUMN = { layer = "BACKGROUND", set = "raw", key = COLUMN_TABS, capL = 5, capR = 4, height = 20,
    coords = { { 0, 0.078125, 0, 0.625 }, { 0.078125, 0.90625, 0, 0.625 }, { 0.90625, 0.96875, 0, 0.625 } } }
function ns.ColumnHeader(parent, column, previous, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(column.w, 20)
    if previous then
        button:SetPoint("LEFT", previous, "RIGHT", 0, 0)
    else
        button:SetPoint("LEFT", parent, "LEFT", 0, 0)
    end
    button.key = column.key

    ns.ThreeSlice(button, nil, COLUMN)

    local text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("LEFT", button, "LEFT", 8, 0)
    text:SetText(column.label)
    button.Text = text

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -2)
    highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 2)
    highlight:SetColorTexture(1, 0.82, 0, 0.12)
    button:SetScript("OnClick", onClick)
    return button
end

-- Icon picker slots (SelectorButtonTemplate) are the client's silver: bronze with the theme; icon, selection and highlight stay.
local tintedSlots = setmetatable({}, { __mode = "k" })
local slotWatches = setmetatable({}, { __mode = "k" })

local function TintSlotPiece(region, slot)
    if region.IsObjectType and region:IsObjectType("Texture") and region ~= slot.Icon
        and region ~= slot.SelectedTexture and region:GetDrawLayer() ~= "HIGHLIGHT" then
        ns.BronzeTint(region, ns.BRONZE_SOFT)
    end
end

function ns.TintSelectorSlot(slot)
    if not slot or tintedSlots[slot] then return end
    tintedSlots[slot] = true
    ns.EachRegion(slot, TintSlotPiece, slot)
end

-- Slots spawn on scroll: a watch under host tints new ones while host shows.
function ns.TintSelectorSlots(scroll, host, name)
    if not (scroll and scroll.EnumerateFrames and host) or slotWatches[scroll] then return end
    local watch = CreateFrame("Frame", nil, host)
    slotWatches[scroll] = watch
    ns.Sched.OnFrame(watch, { name = name, every = 0.3, fn = function()
        for _, slot in scroll:EnumerateFrames() do ns.TintSelectorSlot(slot) end
    end })
end
